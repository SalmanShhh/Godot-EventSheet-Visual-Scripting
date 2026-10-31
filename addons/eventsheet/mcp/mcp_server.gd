# Godot EventSheets - MCP server (protocol core)
# A Model Context Protocol server exposing event sheets to AI assistants: list/read sheets (.tres and
# .gd), browse the ACE registry, compile (dry-run by default), lint GDScript blocks, explain a line,
# verify the round trip, and edit rows - insert, edit, delete, comments, variable properties and
# renames. JSON-RPC 2.0, transport-free: the stdio loop lives in run_mcp_server.gd and the editor's
# live link in mcp_live_link.gd, and both hand each message to handle_message here, so tests drive it
# directly.
#
# WHERE A SHEET COMES FROM, and where an edit goes. With `live_host` unset (the headless stdio server,
# CI, the tests) every tool reads the file on disk and every edit writes it: a `.tres` through
# ResourceSaver, a `.gd` only when the bytes it would write open as a sheet and save back unchanged.
# With `live_host` set (the running editor answering through its live link) a sheet open in a tab is
# read as the tab holds it, unsaved edits included, and an edit goes through the dock's own undo
# funnel - the open tab redraws, the step lands in the editor's history, Ctrl+Z takes it back, and
# the file is written when the person saves, as for any other edit.
@tool
class_name EventSheetMCPServer
extends RefCounted

const PROTOCOL_VERSION := "2024-11-05"
const ROW_EDITS := preload("res://addons/eventsheet/mcp/mcp_row_edits.gd")
const SHIPPED_PACKS := preload("res://addons/eventforge/shipped_pack_folders.gd")
const EVENT_SHEET_EDITOR_PATH := "res://addons/eventforge/editor/event_sheet_editor.gd"
## The contract gate behind `verify`, loaded by path when first asked: it reads the migration report,
## and naming it here would make the first answer of every session wait ten seconds for its compile.
const VERIFY_PATH := "res://addons/eventforge/verify.gd"
## The public API, for the Doctor - loaded by path for the same reason: it names most of the plugin.
const API_PATH := "res://addons/eventsheet/api/eventsheets.gd"

## Off-switch marker. The editor (View ▸ MCP Server) creates/removes this; the stdio server is a
## SEPARATE long-lived process, so it re-checks the file live per request rather than caching a
## setting. `user://` resolves to the same place for editor + server (same project), and the file is
## per-machine + uncommitted. Absent = ON (the default). The editor's live link reads it too.
const DISABLED_MARKER := "user://eventsheets_mcp_disabled"

## The folder the plugin's own behaviour packs live in. Its shipped folders are the plugin's code,
## not the project's, so list_sheets leaves them out the way it leaves out addons/.
const PACKS_ROOT := "res://eventsheet_addons/"

## The variable fields set by variable_properties: what the variable shows in the Inspector and how.
## Its name, type and starting value are the row's own edits (rename, edit_row), not export options.
const VARIABLE_ROW_FIELDS: PackedStringArray = ["exported", "export_hint", "options", "attributes", "description"]
const VARIABLE_ENTRY_FIELDS: PackedStringArray = ["exported", "options", "attributes", "description"]

## Test/override hook: null = consult the live marker; true/false force the state.
static var enabled_override: Variant = null

## The running editor, when this server answers through its live link: an object with
## `sheet_open_at(path) -> EventSheetResource` (the tab's live sheet, or null), `open_tabs() -> Array`
## ([{path, unsaved}]) and `edit_sheet(path, label, mutation) -> Dictionary` ({} or {"error"}). Null
## for the headless server, which reads and writes files.
var live_host: Object = null

## The workspace built only to read its vocabulary off, loaded by path when list_aces is first
## asked: naming its class here would compile the whole editor before the server answered anything.
var _registry_editor: Object = null
var _registry: EventSheetACERegistry = null


## Whether the server is currently allowed to serve tools. Live (re-read each call) so the
## editor toggle takes effect without the AI client reconnecting.
static func is_enabled() -> bool:
	if enabled_override != null:
		return bool(enabled_override)
	return not FileAccess.file_exists(DISABLED_MARKER)


## The tools that change a sheet. The live link opens the sheet such a call names in a tab before
## the call runs, so the edit has a tab to land in and an undo step to land as.
static func edits_sheet(tool_name: String) -> bool:
	return tool_name in ["apply_snippet", "edit_row", "delete_row", "comment", "rename", "variable_properties"]


## Handles one JSON-RPC message. Returns the response Dictionary, or null for
## notifications (which never get responses).
func handle_message(message: Dictionary) -> Variant:
	var method: String = str(message.get("method", ""))
	var has_id: bool = message.has("id")
	if method.begins_with("notifications/"):
		return null
	match method:
		"initialize":
			return _result(message, {
				"protocolVersion": PROTOCOL_VERSION,
				"capabilities": {"tools": {}},
				"serverInfo": {"name": "godot-eventsheets", "version": SheetCompiler.VERSION}
			})
		"ping":
			return _result(message, {})
		"tools/list":
			# Turned off → expose no tools (the AI sees nothing it can do).
			if not is_enabled():
				return _result(message, {"tools": []})
			return _result(message, {"tools": _tool_descriptors()})
		"tools/call":
			if not is_enabled():
				return _result(message, {
					"content": [{"type": "text", "text": "The EventSheets MCP server is turned OFF. Re-enable it in the EventSheets dock (View ▸ MCP Server (AI tools)), or delete user://eventsheets_mcp_disabled."}],
					"isError": true
				})
			return _handle_tool_call(message)
	if has_id:
		return _error(message, -32601, "Method not found: %s" % method)
	return null


func _handle_tool_call(message: Dictionary) -> Dictionary:
	var params: Dictionary = message.get("params", {}) if message.get("params") is Dictionary else {}
	var arguments: Dictionary = params.get("arguments", {}) if params.get("arguments") is Dictionary else {}
	var outcome: Dictionary
	match str(params.get("name", "")):
		"list_sheets":
			outcome = _tool_list_sheets()
		"read_sheet":
			outcome = _tool_read_sheet(arguments)
		"list_aces":
			outcome = _tool_list_aces(arguments)
		"compile_sheet":
			outcome = _tool_compile_sheet(arguments)
		"lint_block":
			outcome = _tool_lint_block(arguments)
		"apply_snippet":
			outcome = _tool_apply_snippet(arguments)
		"edit_row":
			outcome = _tool_edit_row(arguments)
		"delete_row":
			outcome = _tool_delete_row(arguments)
		"comment":
			outcome = _tool_comment(arguments)
		"variable_properties":
			outcome = _tool_variable_properties(arguments)
		"rename":
			outcome = _tool_rename(arguments)
		"explain":
			outcome = _tool_explain(arguments)
		"verify":
			outcome = _tool_verify(arguments)
		"run_doctor":
			outcome = _tool_run_doctor()
		_:
			outcome = {"error": "Unknown tool: %s" % str(params.get("name", ""))}
	if outcome.has("error"):
		return _result(message, {
			"content": [{"type": "text", "text": str(outcome.get("error"))}],
			"isError": true
		})
	return _result(message, {
		"content": [{"type": "text", "text": JSON.stringify(outcome, "  ")}]
	})

# ── Tools: reading ────────────────────────────────────────────────────────────


## Every event sheet in the project: each stored `.tres` sheet (header pre-filter) and each `.gd`
## script, since any script opens as a sheet and `.gd` is the default format. The plugin's own code
## (addons/ and the behaviour packs it ships) is left out; a pack the project made itself is listed.
## In the editor, the sheets open in its tabs are named too, with whether each has unsaved edits.
func _tool_list_sheets() -> Dictionary:
	var sheets: Array = []
	_scan_for_sheets("res://", sheets)
	# Path order, always - the directory walk hands files back in filesystem order (near-alphabetical
	# on NTFS, hash order on ext4), so an unsorted listing answers the same question differently per
	# platform.
	sheets.sort()
	var listing: Dictionary = {"sheets": sheets}
	if live_host != null:
		listing["open_in_editor"] = live_host.call("open_tabs")
	return listing


## A script of a pack this plugin ships, or one of the runtime scripts at the packs folder's root.
static func _is_plugin_pack_script(path: String) -> bool:
	if not path.begins_with(PACKS_ROOT):
		return false
	var below: String = path.trim_prefix(PACKS_ROOT)
	if not below.contains("/"):
		return true
	return SHIPPED_PACKS.FOLDERS.has(below.get_slice("/", 0))


func _scan_for_sheets(directory_path: String, into: Array) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		var full_path: String = directory_path.path_join(entry)
		if directory.current_is_dir():
			# A folder holding .gdignore is one Godot itself does not import, so nothing in it is a sheet.
			if not entry.begins_with(".") and entry != "addons" and not FileAccess.file_exists(full_path.path_join(".gdignore")):
				_scan_for_sheets(full_path, into)
		elif entry.ends_with(".tres"):
			var header: String = FileAccess.get_file_as_string(full_path).left(400)
			if header.contains("EventSheetResource") or header.contains("event_sheet.gd"):
				into.append(full_path)
		elif entry.ends_with(".gd") and not _is_plugin_pack_script(full_path):
			into.append(full_path)
		entry = directory.get_next()
	directory.list_dir_end()


## Structured JSON view of a sheet (.tres, or any .gd opened as a sheet). Every row carries its
## `address`, which the editing tools take back; a `.gd` sheet's rows also carry the file `lines`
## each one is written on. In the editor, a sheet open in a tab is read as the tab holds it.
func _tool_read_sheet(arguments: Dictionary) -> Dictionary:
	var path: String = str(arguments.get("path", ""))
	var sheet: EventSheetResource = _sheet_for_reading(path)
	if sheet == null:
		return {"error": "Not an event sheet: %s" % path}
	var lines: Dictionary = _row_lines(sheet)
	var payload: Dictionary = {
		"path": path,
		"host_class": sheet.host_class,
		"behavior_mode": sheet.behavior_mode,
		"custom_class_name": sheet.custom_class_name,
		"includes": Array(sheet.includes),
		"variables": sheet.variables,
		"functions": _serialize_functions(sheet.functions),
		"rows": _serialize_rows(sheet.events, "", lines)
	}
	if live_host != null:
		payload["read_from"] = "editor" if _live_sheet(path) != null else "disk"
	return payload


## {row instance id: [start, end]} for a sheet written to a `.gd`, from the source map of what it
## saves to - written nowhere. Empty for a stored sheet, whose generated file is not its source.
func _row_lines(sheet: EventSheetResource) -> Dictionary:
	var lines: Dictionary = {}
	if sheet.external_source_path.is_empty():
		return lines
	for entry: Variant in SheetCompiler.echo(sheet).get("source_map", []):
		if entry is Dictionary:
			var key: String = str((entry as Dictionary).get("uid", ""))
			if not lines.has(key):
				lines[key] = [int((entry as Dictionary).get("start", 0)), int((entry as Dictionary).get("end", 0))]
	return lines


func _serialize_functions(functions: Array) -> Array:
	var serialized: Array = []
	for entry: Variant in functions:
		if entry is EventFunction:
			var event_function: EventFunction = entry as EventFunction
			var params: Array = []
			for param: Variant in event_function.params:
				if param is ACEParam:
					params.append({"id": (param as ACEParam).id, "type": (param as ACEParam).type_name})
			serialized.append({
				"name": event_function.function_name,
				"params": params,
				"exposed": event_function.expose_as_ace
			})
	return serialized


func _serialize_rows(rows: Array, prefix: String = "", lines: Dictionary = {}) -> Array:
	var serialized: Array = []
	for index: int in range(rows.size()):
		var row: Variant = rows[index]
		var address: String = str(index) if prefix.is_empty() else "%s/%d" % [prefix, index]
		var entry: Dictionary = _serialize_row(row, address, lines)
		if entry.is_empty():
			continue
		entry["address"] = address
		if row is Object and lines.has(str((row as Object).get_instance_id())):
			entry["lines"] = lines[str((row as Object).get_instance_id())]
		serialized.append(entry)
	return serialized


func _serialize_row(row: Variant, address: String, lines: Dictionary) -> Dictionary:
	if row is EventRow:
		var event_row: EventRow = row as EventRow
		var conditions: Array = []
		for condition: Variant in event_row.conditions:
			if condition is ACECondition:
				conditions.append(_serialize_ace(condition))
		var actions: Array = []
		for action: Variant in event_row.actions:
			if action is ACEAction:
				actions.append(_serialize_ace(action))
			elif action is RawCodeRow:
				actions.append({"kind": "gdscript", "code": (action as RawCodeRow).code})
		return {
			"kind": "event",
			"trigger": {"provider": event_row.trigger_provider_id, "id": event_row.trigger_id},
			"conditions": conditions,
			"actions": actions,
			"pick_filters": event_row.pick_filters.size(),
			"sub_events": _serialize_rows(event_row.sub_events, address, lines),
			"enabled": event_row.enabled
		}
	if row is EventGroup:
		var group: EventGroup = row as EventGroup
		return {
			"kind": "group",
			"name": group.group_name,
			"description": group.description,
			"enabled": group.enabled,
			"children": _serialize_rows(ROW_EDITS.children_of(group) as Array, address, lines)
		}
	if row is CommentRow:
		return {"kind": "comment", "text": (row as CommentRow).text}
	if row is LocalVariable:
		return {"kind": "variable", "name": (row as LocalVariable).name, "type": (row as LocalVariable).type_name, "default": (row as LocalVariable).default_value}
	if row is EnumRow:
		return {"kind": "enum", "name": (row as EnumRow).enum_name, "members": Array((row as EnumRow).members)}
	if row is RawCodeRow:
		return {"kind": "gdscript", "code": (row as RawCodeRow).code}
	# Every other row kind (signals, anchors, custom blocks, ...) is still a row with an address, so
	# a client counting rows counts the same rows the editing tools do.
	if row is Object:
		return {"kind": ROW_EDITS.kinds_of([row])[0]}
	return {}


func _serialize_ace(ace: Resource) -> Dictionary:
	return {
		"kind": "ace",
		"provider": str(ace.get("provider_id")),
		"id": str(ace.get("ace_id")),
		"params": ace.get("params"),
		"codegen_template": str(ace.get("codegen_template"))
	}


## The full ACE vocabulary (builtins + zero-config addons), optionally filtered.
## Composition-policy enforcement over MCP: when the
## project restricts include sources to a tag, addon ACEs without that tag disappear
## from list_aces - an AI assistant told "only approved addons" is policy-BOUND, not
## policy-advised. Core builtins always list.
func _policy_allows_definition(definition: ACEDefinition) -> bool:
	var include_sources: String = str(SheetCompiler._addon_policy("include_sources", "anywhere"))
	if not include_sources.begins_with("tagged:"):
		return true
	if definition.provider_id == "Core":
		return true
	var required_tag: String = include_sources.trim_prefix("tagged:").strip_edges()
	var definition_tags: Array = definition.metadata.get("tags", []) if definition.metadata.get("tags") is Array else []
	return definition_tags.has(required_tag)


func _tool_list_aces(arguments: Dictionary) -> Dictionary:
	_ensure_registry()
	var query: String = str(arguments.get("query", "")).to_lower()
	var type_names: Dictionary = {
		ACEDefinition.ACEType.TRIGGER: "trigger",
		ACEDefinition.ACEType.CONDITION: "condition",
		ACEDefinition.ACEType.ACTION: "action",
		ACEDefinition.ACEType.EXPRESSION: "expression"
	}
	var aces: Array = []
	for definition: ACEDefinition in _registry.get_all_definitions():
		if not _policy_allows_definition(definition):
			continue
		var haystack: String = definition.get_search_text().to_lower() + " " + ("%s %s" % [definition.id, definition.provider_id]).to_lower()
		if not query.is_empty() and not haystack.contains(query):
			continue
		var params: Array = []
		for parameter: Variant in definition.parameters:
			if parameter is Dictionary:
				params.append({
					"id": str((parameter as Dictionary).get("id", "")),
					"hint": str((parameter as Dictionary).get("hint", ""))
				})
		aces.append({
			"provider": definition.provider_id,
			"id": definition.id,
			"type": str(type_names.get(definition.ace_type, "action")),
			"display_name": definition.display_name,
			"category": definition.category,
			"codegen_template": str((definition.metadata as Dictionary).get("codegen_template", "")) if definition.metadata is Dictionary else "",
			"tags": (definition.metadata as Dictionary).get("tags", []) if definition.metadata is Dictionary else [],
			"params": params
		})
	return {"aces": aces, "count": aces.size()}


## Compiles a sheet. Dry-run by default (output returned, nothing overwritten), and in the editor the
## dry run compiles the tab as it is, unsaved edits included. write_output=true compiles the FILE to
## its real output path.
func _tool_compile_sheet(arguments: Dictionary) -> Dictionary:
	var path: String = str(arguments.get("path", ""))
	var write_output: bool = bool(arguments.get("write_output", false))
	var sheet: EventSheetResource = _load_sheet(path) if write_output else _sheet_for_reading(path)
	if sheet == null:
		return {"error": "Not an event sheet: %s" % path}
	var result: Dictionary = SheetCompiler.compile(sheet, "") if write_output else SheetCompiler.echo(sheet)
	return {
		"success": bool(result.get("success", false)),
		"errors": result.get("errors", []),
		"warnings": result.get("warnings", []),
		"wrote_file": write_output,
		"output": str(result.get("output", ""))
	}


## Compile-checks a GDScript block/expression against an optional sheet's context.
func _tool_lint_block(arguments: Dictionary) -> Dictionary:
	var sheet: EventSheetResource = null
	if not str(arguments.get("sheet_path", "")).is_empty():
		sheet = _sheet_for_reading(str(arguments.get("sheet_path", "")))
	var verdict: Dictionary = EventSheetGDScriptLint.lint(
		str(arguments.get("code", "")),
		bool(arguments.get("in_flow", true)),
		sheet
	)
	return {"ok": bool(verdict.get("ok", false)), "problem": str(verdict.get("error", ""))}


## Which row one line of a `.gd` became: the file is opened the way the editor opens it, saved back
## the way the editor saves it (written nowhere), and the line looked up in what that save maps each
## row to. A file that does not save back byte for byte is told so, because there its line numbers
## no longer mean the same lines. Reads the file on disk - the line is a line of the file.
func _tool_explain(arguments: Dictionary) -> Dictionary:
	var path: String = str(arguments.get("path", ""))
	var number: int = int(arguments.get("line", 0))
	if not path.ends_with(".gd") or not FileAccess.file_exists(path):
		return {"error": "explain reads a .gd file: %s" % path}
	var source: String = FileAccess.get_file_as_string(path)
	var file_lines: PackedStringArray = source.split("\n")
	if number < 1 or number > file_lines.size():
		return {"error": "%s has no line %d (it has %d)." % [path, number, file_lines.size()]}
	var answer: Dictionary = {"path": path, "line": number, "text": file_lines[number - 1]}
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source, true, path)
	if sheet == null:
		answer["row"] = null
		answer["reason"] = "this file does not open as a sheet"
		return answer
	sheet.external_source_path = path
	var emitted: Dictionary = SheetCompiler.echo(sheet)
	if str(emitted.get("output", "")) != source:
		answer["row"] = null
		answer["reason"] = "this file does not save back byte for byte, so no line number maps"
		return answer
	var source_map: Array = emitted.get("source_map", []) as Array
	var row: Resource = EventSheetLineRowMapper.resource_for_line(source_map, number)
	if row == null:
		answer["row"] = null
		answer["reason"] = "no row is written on this line"
		return answer
	var address: String = ROW_EDITS.address_of(sheet, row)
	var range_lines: Vector2i = EventSheetLineRowMapper.range_for_resource(source_map, row)
	answer["row"] = address if not address.is_empty() else null
	answer["kind"] = ROW_EDITS.kinds_of([row])[0]
	answer["lines"] = [range_lines.x, range_lines.y]
	var detail: Dictionary = _serialize_row(row, address, {})
	if not detail.is_empty():
		answer["detail"] = detail
	if address.is_empty():
		answer["reason"] = "the row is inside a function body, not in the event tree"
	return answer


## The standing contracts over files, the way tools/verify_sheets.gd checks them: each file parses,
## opens as a sheet and saves back byte for byte, holds no doubled baked local, and has no migration
## row waiting on a person. No paths = the whole project, which reads every script and is slow; name
## the files changed. Read-only.
func _tool_verify(arguments: Dictionary) -> Dictionary:
	var requested: PackedStringArray = PackedStringArray()
	var given: Variant = arguments.get("paths", [])
	if given is Array:
		for entry: Variant in given as Array:
			requested.append(str(entry))
	elif given is String and not str(given).is_empty():
		requested.append(str(given))
	var gate: Script = load(VERIFY_PATH)
	var result: Dictionary = gate.call("run", requested, PackedStringArray(), "res://addons/eventsheet/mcp/run_mcp_server.gd")
	var failures: Array = []
	for failure: Variant in result.get("failures", []):
		if failure is Dictionary:
			failures.append({
				"check": str((failure as Dictionary).get("check", "")),
				"path": str((failure as Dictionary).get("path", "")),
				"line": int((failure as Dictionary).get("line", 0)),
				"message": str((failure as Dictionary).get("message", "")),
				"text": str(gate.call("failure_line", failure as Dictionary))
			})
	return {
		"files": int(result.get("files", 0)),
		"passed": failures.is_empty(),
		"failures": failures,
		"verdict": str(gate.call("verdict", result))
	}

# ── Tools: editing ────────────────────────────────────────────────────────────


## Inserts rows from snippet text OR plain GDScript (converted through the same lossless lift the
## editor's paste uses). With no `parent` they go at the top level; `parent` names an event or a group
## by address and they go inside it. `position` is the index among that level's rows (default: the
## end). dry_run previews the row kinds and writes nothing.
func _tool_apply_snippet(arguments: Dictionary) -> Dictionary:
	var path: String = str(arguments.get("path", ""))
	var rows: Array = ROW_EDITS.rows_from_text(str(arguments.get("text", "")))
	if rows.is_empty():
		return {"error": "Nothing to apply: not a snippet and no convertible GDScript rows."}
	var kinds: Array = ROW_EDITS.kinds_of(rows)
	if bool(arguments.get("dry_run", false)):
		if _sheet_for_reading(path) == null:
			return {"error": "Not an event sheet: %s" % path}
		return {"dry_run": true, "rows": kinds.size(), "kinds": kinds}
	var parent: String = str(arguments.get("parent", ""))
	var position: int = int(arguments.get("position", -1))
	var outcome: Dictionary = _mutate(path, "Add Rows", func(sheet: EventSheetResource) -> Dictionary:
		var refused: String = ROW_EDITS.insert(sheet, parent, position, rows)
		if not refused.is_empty():
			return {"error": refused}
		return {"applied": kinds.size(), "kinds": kinds})
	if not outcome.has("error") and not outcome.has("undo"):
		outcome["hint"] = "Run compile_sheet to regenerate the script."
	return outcome


## Replaces the row at `row` with the rows `text` converts to (snippet text or GDScript), in place.
func _tool_edit_row(arguments: Dictionary) -> Dictionary:
	var path: String = str(arguments.get("path", ""))
	var address: String = str(arguments.get("row", ""))
	var rows: Array = ROW_EDITS.rows_from_text(str(arguments.get("text", "")))
	if rows.is_empty():
		return {"error": "Nothing to put in its place: not a snippet and no convertible GDScript rows."}
	var kinds: Array = ROW_EDITS.kinds_of(rows)
	return _mutate(path, "Edit Row", func(sheet: EventSheetResource) -> Dictionary:
		var refused: String = ROW_EDITS.replace(sheet, address, rows)
		if not refused.is_empty():
			return {"error": refused}
		return {"edited": address, "kinds": kinds})


## Deletes the row at `row`, with every row under it.
func _tool_delete_row(arguments: Dictionary) -> Dictionary:
	var path: String = str(arguments.get("path", ""))
	var address: String = str(arguments.get("row", ""))
	return _mutate(path, "Delete Row", func(sheet: EventSheetResource) -> Dictionary:
		var target: Dictionary = ROW_EDITS.resolve(sheet, address)
		var kind: String = "" if target.has("error") else str(ROW_EDITS.kinds_of([target.get("row")])[0])
		var refused: String = ROW_EDITS.delete(sheet, address)
		if not refused.is_empty():
			return {"error": refused}
		return {"deleted": address, "kind": kind})


## A comment row. With `row`, that comment's text is rewritten; without it, a new comment goes in at
## `parent` / `position`, read as apply_snippet reads them.
func _tool_comment(arguments: Dictionary) -> Dictionary:
	var path: String = str(arguments.get("path", ""))
	var text: String = str(arguments.get("text", ""))
	if text.strip_edges().is_empty():
		return {"error": "A comment needs text."}
	if arguments.has("row"):
		var address: String = str(arguments.get("row", ""))
		return _mutate(path, "Edit Comment", func(sheet: EventSheetResource) -> Dictionary:
			var target: Dictionary = ROW_EDITS.resolve(sheet, address)
			if target.has("error"):
				return {"error": str(target.get("error"))}
			if not (target.get("row") is CommentRow):
				return {"error": "Row %s is not a comment." % address}
			(target.get("row") as CommentRow).text = text
			return {"edited": address})
	var parent: String = str(arguments.get("parent", ""))
	var position: int = int(arguments.get("position", -1))
	return _mutate(path, "Add Comment", func(sheet: EventSheetResource) -> Dictionary:
		var comment_row: CommentRow = CommentRow.new()
		comment_row.text = text
		var refused: String = ROW_EDITS.insert(sheet, parent, position, [comment_row])
		if not refused.is_empty():
			return {"error": refused}
		return {"added": ROW_EDITS.address_of(sheet, comment_row)})


## A variable's export options, read - and with `set`, written. A `.gd` sheet's variables are rows;
## a stored sheet keeps most of its own in the sheet's variable table, and both are answered here.
func _tool_variable_properties(arguments: Dictionary) -> Dictionary:
	var path: String = str(arguments.get("path", ""))
	var variable_name: String = str(arguments.get("name", ""))
	var changes: Dictionary = arguments.get("set", {}) if arguments.get("set") is Dictionary else {}
	if changes.is_empty():
		var sheet: EventSheetResource = _sheet_for_reading(path)
		if sheet == null:
			return {"error": "Not an event sheet: %s" % path}
		return _variable_properties_of(sheet, variable_name)
	return _mutate(path, "Variable Properties", func(sheet: EventSheetResource) -> Dictionary:
		var variable: LocalVariable = _variable_row(sheet, variable_name)
		var allowed: PackedStringArray = VARIABLE_ROW_FIELDS if variable != null else VARIABLE_ENTRY_FIELDS
		for key: Variant in changes:
			if not allowed.has(str(key)):
				return {"error": "%s is not an export option here (%s can be set)." % [str(key), ", ".join(allowed)]}
		if variable != null:
			for key: Variant in changes:
				match str(key):
					"options":
						variable.options = PackedStringArray(changes[key] as Array) if changes[key] is Array else PackedStringArray()
					"attributes":
						if not (changes[key] is Dictionary):
							return {"error": "attributes takes an object."}
						variable.attributes = (changes[key] as Dictionary).duplicate(true)
					"exported":
						variable.exported = bool(changes[key])
					_:
						variable.set(str(key), str(changes[key]))
			return _variable_properties_of(sheet, variable_name)
		if not sheet.variables.has(variable_name):
			return {"error": "No variable named %s on this sheet." % variable_name}
		var descriptor: Dictionary = (sheet.variables[variable_name] as Dictionary).duplicate(true) if sheet.variables[variable_name] is Dictionary else {}
		for key: Variant in changes:
			descriptor[str(key)] = changes[key]
		sheet.variables[variable_name] = descriptor
		return _variable_properties_of(sheet, variable_name))


func _variable_row(sheet: EventSheetResource, variable_name: String) -> LocalVariable:
	for variable: LocalVariable in ROW_EDITS.variable_rows(sheet):
		if variable.name == variable_name:
			return variable
	return null


func _variable_properties_of(sheet: EventSheetResource, variable_name: String) -> Dictionary:
	var variable: LocalVariable = _variable_row(sheet, variable_name)
	if variable != null:
		return {
			"name": variable.name,
			"row": ROW_EDITS.address_of(sheet, variable),
			"type": variable.type_name,
			"default": variable.default_value,
			"exported": variable.exported,
			"export_hint": variable.export_hint,
			"options": Array(variable.options),
			"attributes": variable.attributes,
			"description": variable.description,
			"onready": variable.onready,
			"constant": variable.is_constant,
			"static": variable.is_static
		}
	if sheet.variables.has(variable_name) and sheet.variables[variable_name] is Dictionary:
		var descriptor: Dictionary = sheet.variables[variable_name] as Dictionary
		return {
			"name": variable_name,
			"row": null,
			"type": str(descriptor.get("type", "")),
			"default": descriptor.get("default"),
			"exported": bool(descriptor.get("exported", false)),
			"options": Array(descriptor.get("options", [])) if descriptor.get("options") is Array or descriptor.get("options") is PackedStringArray else [],
			"attributes": descriptor.get("attributes", {}),
			"description": str(descriptor.get("description", ""))
		}
	return {"error": "No variable named %s on this sheet." % variable_name}


## Renames a variable or a function across the sheet - its declaration and every place the sheet
## names it, the way the editor's Rename Everywhere does within one sheet.
func _tool_rename(arguments: Dictionary) -> Dictionary:
	var path: String = str(arguments.get("path", ""))
	var old_name: String = str(arguments.get("from", ""))
	var new_name: String = str(arguments.get("to", ""))
	return _mutate(path, "Rename %s" % old_name, func(sheet: EventSheetResource) -> Dictionary:
		var refused: String = EventSheetRefactor.validate_new_name(sheet, old_name, new_name)
		if refused.is_empty() and _variable_row(sheet, new_name) != null:
			refused = "A variable named \"%s\" already exists." % new_name
		if not refused.is_empty():
			return {"error": refused}
		var count: int = EventSheetRefactor.rename_symbol(sheet, old_name, new_name)
		if count == 0:
			return {"error": "%s is not named anywhere on this sheet." % old_name}
		return {"renamed": old_name, "to": new_name, "places": count})


## The Project Doctor through the public API, so extension-registered checks
## (EventSheets.register_doctor_check) report over MCP exactly like built-ins.
func _tool_run_doctor() -> Dictionary:
	return load(API_PATH).doctor()

# ── Where sheets come from, and where edits go ────────────────────────────────


## The sheet a tab of the running editor holds for `path`, or null (no editor, or not open there).
func _live_sheet(path: String) -> EventSheetResource:
	if live_host == null or path.is_empty():
		return null
	return live_host.call("sheet_open_at", path) as EventSheetResource


## The sheet to READ for `path`: the editor's tab when one holds it, the file otherwise.
func _sheet_for_reading(path: String) -> EventSheetResource:
	var live: EventSheetResource = _live_sheet(path)
	return live if live != null else _load_sheet(path)


## Runs `change` (sheet -> {"error"} or the answer) on the sheet at `path` and keeps what it did.
##
## In the editor: through the dock's undo funnel, as one step named `label` - the open tab redraws,
## Ctrl+Z takes it back, and the file is written when the person saves it.
##
## Headless: on the file. A `.tres` is saved through ResourceSaver. A `.gd` is written only when it is
## safe to: the file must open as a sheet and save back byte for byte BEFORE the edit (otherwise
## rows the edit never touched could come out different), the edited sheet must compile, and the
## bytes about to be written must themselves open and save back unchanged. Any of those failing
## refuses the edit and leaves the file exactly as it was.
func _mutate(path: String, label: String, change: Callable) -> Dictionary:
	if live_host != null:
		# The tab is edited and the person's next save writes it, so a `.gd` must pass the same gates
		# the file path does first: not mid-merge, not marked to stay code, and saving back byte for
		# byte, or that save would change lines the edit never touched.
		var refused: String = script_edit_refusal(path)
		if refused.is_empty():
			refused = round_trip_refusal(path)
		if not refused.is_empty():
			return {"error": refused}
		var answer: Dictionary = {}
		var done: Dictionary = live_host.call("edit_sheet", path, label, func(sheet: EventSheetResource) -> bool:
			answer.merge(change.call(sheet) as Dictionary, true)
			return not answer.has("error"))
		if answer.has("error"):
			return answer
		if done.has("error"):
			return done
		answer["where"] = "editor"
		answer["undo"] = label
		answer["saved"] = false
		return answer
	if path.ends_with(".gd"):
		return _mutate_script(path, change)
	if not path.ends_with(".tres"):
		return {"error": "Not an event sheet: %s (a .tres sheet or a .gd script)." % path}
	var sheet: EventSheetResource = _load_sheet(path)
	if sheet == null:
		return {"error": "Not an event sheet: %s" % path}
	var outcome: Dictionary = change.call(sheet)
	if outcome.has("error"):
		return outcome
	EventSheetBackups.backup_sheet(path)
	var save_error: Error = ResourceSaver.save(sheet, path)
	if save_error != OK:
		return {"error": "Failed to save %s (error %d)." % [path, save_error]}
	outcome["saved"] = true
	return outcome


## Why a `.gd` is never edited as a sheet, or "": a file a merge has not finished with is not
## GDScript yet, and a file its owner marked to stay code is shown and left alone. The live link asks
## this too, before it opens a tab for an edit.
static func script_edit_refusal(path: String) -> String:
	if path.get_extension() != "gd":
		return ""
	if EventSheetConflictGuard.blocks_file(path):
		return "%s still holds merge conflict markers - finish the merge before editing it." % path
	if EventSheetInteropDoctor.stays_code(path):
		return "%s is marked to stay code, so it is not edited as a sheet." % path
	return ""


## Why the `.gd` at `path` on disk may not be edited as a sheet because it does not open as one, or
## does not save back byte for byte; "" when it does (and for anything not a `.gd`).
static func round_trip_refusal(path: String) -> String:
	if path.get_extension() != "gd" or not FileAccess.file_exists(path):
		return ""
	var source: String = FileAccess.get_file_as_string(path)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source, true, path)
	if sheet == null:
		return "%s does not open as a sheet." % path
	sheet.external_source_path = path
	if str(SheetCompiler.echo(sheet).get("output", "")) != source:
		return "%s does not save back byte for byte as a sheet, so editing it here could change lines the edit never touched. Nothing was written." % path
	return ""


func _mutate_script(path: String, change: Callable) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "Not an event sheet: %s" % path}
	var refused: String = script_edit_refusal(path)
	if refused.is_empty():
		refused = round_trip_refusal(path)
	if not refused.is_empty():
		return {"error": refused}
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(FileAccess.get_file_as_string(path), true, path)
	if sheet == null:
		return {"error": "%s does not open as a sheet." % path}
	sheet.external_source_path = path
	var outcome: Dictionary = change.call(sheet)
	if outcome.has("error"):
		return outcome
	var emitted: Dictionary = SheetCompiler.echo(sheet)
	if not bool(emitted.get("success", false)):
		return {"error": "The edited sheet does not compile, so nothing was written: %s" % "; ".join(PackedStringArray(emitted.get("errors", [])))}
	var written: String = str(emitted.get("output", ""))
	var reopened: EventSheetResource = GDScriptImporter.new().import_external_source(written, true, path)
	if reopened == null:
		return {"error": "The edited file would not open as a sheet again, so nothing was written."}
	reopened.external_source_path = path
	if str(SheetCompiler.echo(reopened).get("output", "")) != written:
		return {"error": "The edited file would not save back byte for byte, so nothing was written."}
	EventSheetBackups.backup_sheet(path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"error": "Could not write %s (error %d)." % [path, FileAccess.get_open_error()]}
	file.store_string(written)
	file.close()
	outcome["saved"] = true
	return outcome


## Loads a sheet from a .tres resource or any .gd file, off disk.
func _load_sheet(path: String) -> EventSheetResource:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	if path.ends_with(".gd"):
		return GDScriptImporter.new().import_external(path)
	# CACHE_MODE_IGNORE: the server is long-lived - a cached resource would silently
	# serve stale sheets after the user edits them in the editor.
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource


## The ACE registry, bootstrapped exactly like the editor (builtins + zero-config addons).
func _ensure_registry() -> void:
	if _registry != null:
		return
	_registry_editor = load(EVENT_SHEET_EDITOR_PATH).new()
	_registry_editor.call("setup", EventSheetResource.new())
	_registry = _registry_editor.get("_ace_registry") as EventSheetACERegistry


func _tool_descriptors() -> Array:
	var path_property: Dictionary = {"type": "string", "description": "res:// path to the sheet (.tres or .gd)"}
	var row_property: Dictionary = {"type": "string", "description": "a row address from read_sheet, e.g. \"3\" or \"3/0\""}
	var parent_property: Dictionary = {"type": "string", "description": "address of the event or group to insert into; omit for the top level"}
	var position_property: Dictionary = {"type": "integer", "description": "index among that level's rows; omit to append"}
	return [
		{
			"name": "list_sheets",
			"description": "List every event sheet in the Godot project: stored .tres sheets and .gd scripts (any script opens as a sheet). In the editor, also names the sheets open in its tabs and whether each has unsaved edits.",
			"inputSchema": {"type": "object", "properties": {}}
		},
		{
			"name": "read_sheet",
			"description": "Read an event sheet as structured JSON (rows, variables, enums, functions). Every row carries its address for the editing tools; a .gd sheet's rows also carry the file lines they are written on. In the editor, a sheet open in a tab is read as the tab holds it, unsaved edits included.",
			"inputSchema": {"type": "object", "properties": {"path": path_property}, "required": ["path"]}
		},
		{
			"name": "list_aces",
			"description": "List the available ACE vocabulary (triggers/conditions/actions/expressions), including zero-config addons. Optional substring query.",
			"inputSchema": {"type": "object", "properties": {"query": {"type": "string"}}}
		},
		{
			"name": "compile_sheet",
			"description": "Compile a sheet to GDScript. Dry-run by default (returns the output text; in the editor it compiles the open tab as it is); set write_output=true to compile the file to its real output.",
			"inputSchema": {"type": "object", "properties": {"path": path_property, "write_output": {"type": "boolean"}}, "required": ["path"]}
		},
		{
			"name": "lint_block",
			"description": "Compile-check a script block or statement list against a sheet's context (variables, enums, host class).",
			"inputSchema": {"type": "object", "properties": {"code": {"type": "string"}, "in_flow": {"type": "boolean", "description": "true = statements inside an event; false = class-level code"}, "sheet_path": {"type": "string"}}, "required": ["code"]}
		},
		{
			"name": "apply_snippet",
			"description": "Insert rows into a sheet (.tres or .gd) from EventSheet snippet text OR plain GDScript (auto-converted to events/variables/comments). Top level by default; parent + position insert inside an event or group. Set dry_run=true to preview. A .gd file is written only if it saves back byte for byte; in the editor the edit is one undo step in the open tab.",
			"inputSchema": {"type": "object", "properties": {"path": path_property, "text": {"type": "string"}, "parent": parent_property, "position": position_property, "dry_run": {"type": "boolean"}}, "required": ["path", "text"]}
		},
		{
			"name": "edit_row",
			"description": "Replace one row with the rows that snippet text or GDScript converts to, in the same place.",
			"inputSchema": {"type": "object", "properties": {"path": path_property, "row": row_property, "text": {"type": "string"}}, "required": ["path", "row", "text"]}
		},
		{
			"name": "delete_row",
			"description": "Delete one row and every row under it.",
			"inputSchema": {"type": "object", "properties": {"path": path_property, "row": row_property}, "required": ["path", "row"]}
		},
		{
			"name": "comment",
			"description": "Add a comment row (at parent/position, top-level end by default), or with row, rewrite that comment's text.",
			"inputSchema": {"type": "object", "properties": {"path": path_property, "text": {"type": "string"}, "row": row_property, "parent": parent_property, "position": position_property}, "required": ["path", "text"]}
		},
		{
			"name": "variable_properties",
			"description": "Read a variable's export options (exported, export_hint, options, attributes such as group/range/tooltip, description); pass set to change them.",
			"inputSchema": {"type": "object", "properties": {"path": path_property, "name": {"type": "string"}, "set": {"type": "object", "description": "fields to change: exported, export_hint, options, attributes, description"}}, "required": ["path", "name"]}
		},
		{
			"name": "rename",
			"description": "Rename a variable or function across the sheet: its declaration and every place the sheet names it.",
			"inputSchema": {"type": "object", "properties": {"path": path_property, "from": {"type": "string"}, "to": {"type": "string"}}, "required": ["path", "from", "to"]}
		},
		{
			"name": "explain",
			"description": "Which row one line of a .gd file becomes when the file opens as a sheet: its address, kind and the lines it is written on.",
			"inputSchema": {"type": "object", "properties": {"path": {"type": "string"}, "line": {"type": "integer", "description": "1-based line number"}}, "required": ["path", "line"]}
		},
		{
			"name": "verify",
			"description": "Check files against the standing contracts: each parses, opens as a sheet and saves back byte for byte, holds no doubled baked local, and has no migration row waiting on a person. Pass the paths you changed; none = the whole project (slow). Read-only.",
			"inputSchema": {"type": "object", "properties": {"paths": {"type": "array", "items": {"type": "string"}}}}
		},
		{
			"name": "run_doctor",
			"description": "Run the Project Doctor health audit over every sheet: stale generated outputs, compile failures, debug residue, wiring gaps, vocabulary hygiene. Returns findings plus error/warning/info counts.",
			"inputSchema": {"type": "object", "properties": {}}
		}
	]


func _result(message: Dictionary, result: Variant) -> Dictionary:
	return {"jsonrpc": "2.0", "id": request_id(message), "result": result}


func _error(message: Dictionary, code: int, error_text: String) -> Dictionary:
	return {"jsonrpc": "2.0", "id": request_id(message), "error": {"code": code, "message": error_text}}


## The request's id as the client wrote it. JSON hands every number back as a float, which would be
## written back as `1.0` for a request sent as `1`; a whole number goes back whole.
static func request_id(message: Dictionary) -> Variant:
	var id: Variant = message.get("id")
	if id is float and is_equal_approx(float(id), floorf(float(id))) and absf(float(id)) < 9.0e15:
		return int(id)
	return id
