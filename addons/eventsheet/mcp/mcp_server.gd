# Godot EventSheets — MCP server (protocol core)
# A Model Context Protocol server exposing event sheets to AI assistants: list/read
# sheets, browse the ACE registry, compile (dry-run by default), lint GDScript blocks,
# and apply snippets/GDScript as rows. JSON-RPC 2.0; the stdio transport lives in
# run_mcp_server.gd — this class is transport-free so tests drive handle_message
# directly. See docs/MCP-SERVER.md for client setup.
@tool
extends RefCounted
class_name EventSheetMCPServer

const PROTOCOL_VERSION := "2024-11-05"

var _registry_editor: EventSheetEditor = null
var _registry: EventSheetACERegistry = null

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
			return _result(message, {"tools": _tool_descriptors()})
		"tools/call":
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

# ── Tools ─────────────────────────────────────────────────────────────────────

## Every .tres event sheet in the project (header pre-filter, skips addons/.godot).
func _tool_list_sheets() -> Dictionary:
	var sheets: Array = []
	_scan_for_sheets("res://", sheets)
	return {"sheets": sheets}

func _scan_for_sheets(directory_path: String, into: Array) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		var full_path: String = directory_path.path_join(entry)
		if directory.current_is_dir():
			if not entry.begins_with(".") and entry != "addons":
				_scan_for_sheets(full_path, into)
		elif entry.ends_with(".tres"):
			var header: String = FileAccess.get_file_as_string(full_path).left(400)
			if header.contains("EventSheetResource") or header.contains("event_sheet.gd"):
				into.append(full_path)
		entry = directory.get_next()
	directory.list_dir_end()

## Structured JSON view of a sheet (.tres, or a GDScript-backed sheet via any .gd path).
func _tool_read_sheet(arguments: Dictionary) -> Dictionary:
	var sheet: EventSheetResource = _load_sheet(str(arguments.get("path", "")))
	if sheet == null:
		return {"error": "Not an event sheet: %s" % str(arguments.get("path", ""))}
	return {
		"path": str(arguments.get("path", "")),
		"host_class": sheet.host_class,
		"behavior_mode": sheet.behavior_mode,
		"custom_class_name": sheet.custom_class_name,
		"includes": Array(sheet.includes),
		"variables": sheet.variables,
		"functions": _serialize_functions(sheet.functions),
		"rows": _serialize_rows(sheet.events)
	}

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

func _serialize_rows(rows: Array) -> Array:
	var serialized: Array = []
	for row: Variant in rows:
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
			serialized.append({
				"kind": "event",
				"trigger": {"provider": event_row.trigger_provider_id, "id": event_row.trigger_id},
				"conditions": conditions,
				"actions": actions,
				"pick_filters": event_row.pick_filters.size(),
				"sub_events": _serialize_rows(event_row.sub_events),
				"enabled": event_row.enabled
			})
		elif row is EventGroup:
			var group: EventGroup = row as EventGroup
			serialized.append({
				"kind": "group",
				"name": group.group_name,
				"description": group.description,
				"enabled": group.enabled,
				"children": _serialize_rows(group.events if not group.events.is_empty() else group.rows)
			})
		elif row is CommentRow:
			serialized.append({"kind": "comment", "text": (row as CommentRow).text})
		elif row is LocalVariable:
			serialized.append({"kind": "variable", "name": (row as LocalVariable).name, "type": (row as LocalVariable).type_name, "default": (row as LocalVariable).default_value})
		elif row is EnumRow:
			serialized.append({"kind": "enum", "name": (row as EnumRow).enum_name, "members": Array((row as EnumRow).members)})
		elif row is RawCodeRow:
			serialized.append({"kind": "gdscript", "code": (row as RawCodeRow).code})
	return serialized

func _serialize_ace(ace: Resource) -> Dictionary:
	return {
		"kind": "ace",
		"provider": str(ace.get("provider_id")),
		"id": str(ace.get("ace_id")),
		"params": ace.get("params"),
		"codegen_template": str(ace.get("codegen_template"))
	}

## The full ACE vocabulary (builtins + zero-config addons), optionally filtered.
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

## Compiles a sheet. Dry-run by default (output returned, nothing overwritten);
## write_output=true writes to the sheet's real output path.
func _tool_compile_sheet(arguments: Dictionary) -> Dictionary:
	var path: String = str(arguments.get("path", ""))
	var sheet: EventSheetResource = _load_sheet(path)
	if sheet == null:
		return {"error": "Not an event sheet: %s" % path}
	var write_output: bool = bool(arguments.get("write_output", false))
	var output_path: String = "" if write_output else "user://eventsheets_mcp_dry_run.gd"
	var result: Dictionary = SheetCompiler.compile(sheet, output_path)
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
		sheet = _load_sheet(str(arguments.get("sheet_path", "")))
	var verdict: Dictionary = EventSheetGDScriptLint.lint(
		str(arguments.get("code", "")),
		bool(arguments.get("in_flow", true)),
		sheet
	)
	return {"ok": bool(verdict.get("ok", false)), "problem": str(verdict.get("error", ""))}

## Appends rows to a .tres sheet from snippet text OR plain GDScript (auto-converted via
## the same lossless lift pipeline the editor's paste uses). dry_run previews row kinds.
func _tool_apply_snippet(arguments: Dictionary) -> Dictionary:
	var path: String = str(arguments.get("path", ""))
	if not path.ends_with(".tres"):
		return {"error": "apply_snippet mutates .tres sheets only (GDScript-backed sheets are edited as code)."}
	var sheet: EventSheetResource = _load_sheet(path)
	if sheet == null:
		return {"error": "Not an event sheet: %s" % path}
	var text: String = str(arguments.get("text", ""))
	var rows: Array = []
	if EventSheetSnippet.is_snippet_text(text):
		rows = EventSheetSnippet.deserialize(text).get("rows", [])
	else:
		var converted: EventSheetResource = GDScriptImporter.new().import_external_source(text)
		for row: Variant in converted.events:
			# Drop the synthetic prelude block the importer creates for bare pastes.
			if row is RawCodeRow and (row as RawCodeRow).code.strip_edges().begins_with("extends "):
				continue
			rows.append(row)
	if rows.is_empty():
		return {"error": "Nothing to apply: not a snippet and no convertible GDScript rows."}
	var kinds: Array = []
	for row: Variant in rows:
		kinds.append(str(row.get_class()) if not row.has_method("get_row_kind") else str(row.call("get_row_kind")))
	if bool(arguments.get("dry_run", false)):
		return {"dry_run": true, "rows": kinds.size(), "kinds": kinds}
	for row: Variant in rows:
		sheet.events.append(row)
	var save_error: Error = ResourceSaver.save(sheet, path)
	if save_error != OK:
		return {"error": "Failed to save %s (error %d)." % [path, save_error]}
	return {"applied": kinds.size(), "kinds": kinds, "hint": "Run compile_sheet to regenerate the script."}

# ── Helpers ───────────────────────────────────────────────────────────────────

## Loads a sheet from a .tres resource or any .gd file (GDScript-backed, read-only here).
func _load_sheet(path: String) -> EventSheetResource:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	if path.ends_with(".gd"):
		return GDScriptImporter.new().import_external(path)
	# CACHE_MODE_IGNORE: the server is long-lived — a cached resource would silently
	# serve stale sheets after the user edits them in the editor.
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource

## The ACE registry, bootstrapped exactly like the editor (builtins + zero-config addons).
func _ensure_registry() -> void:
	if _registry != null:
		return
	_registry_editor = EventSheetEditor.new()
	_registry_editor.setup(EventSheetResource.new())
	_registry = _registry_editor._ace_registry

func _tool_descriptors() -> Array:
	return [
		{
			"name": "list_sheets",
			"description": "List every event sheet (.tres) in the Godot project.",
			"inputSchema": {"type": "object", "properties": {}}
		},
		{
			"name": "read_sheet",
			"description": "Read an event sheet as structured JSON (rows, variables, enums, functions). Accepts .tres sheets or any .gd file (opened as a GDScript-backed sheet).",
			"inputSchema": {"type": "object", "properties": {"path": {"type": "string", "description": "res:// path to the sheet"}}, "required": ["path"]}
		},
		{
			"name": "list_aces",
			"description": "List the available ACE vocabulary (triggers/conditions/actions/expressions), including zero-config addons. Optional substring query.",
			"inputSchema": {"type": "object", "properties": {"query": {"type": "string"}}}
		},
		{
			"name": "compile_sheet",
			"description": "Compile a sheet to GDScript. Dry-run by default (returns the output text); set write_output=true to write the real file.",
			"inputSchema": {"type": "object", "properties": {"path": {"type": "string"}, "write_output": {"type": "boolean"}}, "required": ["path"]}
		},
		{
			"name": "lint_block",
			"description": "Compile-check a GDScript block or statement list against a sheet's context (variables, enums, host class).",
			"inputSchema": {"type": "object", "properties": {"code": {"type": "string"}, "in_flow": {"type": "boolean", "description": "true = statements inside an event; false = class-level code"}, "sheet_path": {"type": "string"}}, "required": ["code"]}
		},
		{
			"name": "apply_snippet",
			"description": "Append rows to a .tres sheet from EventSheet snippet text OR plain GDScript (auto-converted to events/variables/comments). Set dry_run=true to preview.",
			"inputSchema": {"type": "object", "properties": {"path": {"type": "string"}, "text": {"type": "string"}, "dry_run": {"type": "boolean"}}, "required": ["path", "text"]}
		}
	]

func _result(message: Dictionary, result: Variant) -> Dictionary:
	return {"jsonrpc": "2.0", "id": message.get("id"), "result": result}

func _error(message: Dictionary, code: int, error_text: String) -> Dictionary:
	return {"jsonrpc": "2.0", "id": message.get("id"), "error": {"code": code, "message": error_text}}
