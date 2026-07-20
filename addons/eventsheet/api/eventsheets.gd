@tool
class_name EventSheets
extends RefCounted
# ═══════════════════════════════════════════════════════════════════════════════════════
# The PUBLIC API for building on top of Godot EventSheets.
#
# Everything here is a compatibility promise (like ace_ids and codegen templates):
# method names and shapes are stable once shipped - new capabilities are added, existing
# ones are never renamed. Tool scripts, other plugins, and the plugin's OWN features call
# through this one class instead of reaching into editor internals, so extensions keep
# working across refactors of the dock/viewport.
#
# Three groups of services:
#
#   VOCABULARY - add words to the language. Register a provider script (its methods,
#   signals, and exported vars become ACEs), register a Custom Block kind (a new row
#   type with byte-gated round-trip), look definitions up, or reflect any engine /
#   class_name class into vocabulary on demand.
#
#   EDITOR - drive the live editor. Read the current sheet, open one, mutate it through
#   edit() (THE undo funnel: your change is one undo step, and you must re-fetch rows
#   from the live sheet afterwards - commits replace resources with snapshot duplicates),
#   set the status line, and add your own Command Palette entries.
#
#   CODEGEN - the compiler and importer as plain services, dock-free: compile a sheet to
#   GDScript, open GDScript back as a sheet, or byte-verify a round-trip - the same gate
#   the plugin's own lifts must pass.
#
#   PROJECT HEALTH - the Doctor as a service: run the whole audit, or register your own
#   check so it runs everywhere the Doctor runs (dock panel, headless CLI, CI, MCP).
#
# Editor services require the EventSheet dock to be open (they no-op safely headless and
# return null/false); vocabulary, codegen and health services work anywhere, including tests.
# ═══════════════════════════════════════════════════════════════════════════════════════

## The live dock, registered by the dock itself at setup. Weak by contract: every use
## checks validity, so a closed workspace never leaves the API pointing at a freed node.
static var _dock: Control = null

## Palette entries registered from code: Array of {"title": String, "run": Callable}.
## The Command Palette appends these after the built-in commands on every open.
static var _palette_commands: Array[Dictionary] = []


# ── Vocabulary ─────────────────────────────────────────────────────────────────────────


## Registers a @tool class_name script as an ACE provider: its public methods, signals,
## and @export vars become actions/conditions/expressions/triggers (see the Custom ACEs
## guide for the annotation and registrar dialects). Project-wide; idempotent.
static func register_provider_script(script_path: String) -> bool:
	if script_path.strip_edges().is_empty():
		return false
	if _dock_alive():
		return _dock.add_ace_provider_script(script_path)
	EventForgeBridgeRuntime.register_provider_script(script_path)
	return true


## Registers a Custom Block kind (a new NON-ACE row type: markers, notes, data blocks).
## The kind gets the Add menu, Command Palette, edit dialog, compile and lift wiring
## automatically; its round-trip is byte-verify gated like every built-in.
static func register_block_kind(kind: EventSheetBlockKind) -> void:
	EventSheetBlockRegistry.register_kind(kind)


## Builds a Custom Block kind from a plain Dictionary, so a beginner never has to subclass:
##   {"kind_id": "my_pack.note", "title": "Note", "category": "Blocks",
##    "fields": [{"id": "text", "label": "Text", "type": TYPE_STRING, "default": "hi"}],
##    "emit": "## NOTE: {text}", "summary": "note: {text}"}
## `emit` is a template (one output line per line of the string) with {field} placeholders; `summary`
## is the one-line viewport display. Forward emission and the summary work immediately; pass an
## optional `lift` Callable (func(lines, i) -> Dictionary) for reverse recovery, else the block still
## emits perfectly and re-imports as a verbatim GDScript block. Register the result with
## register_block_kind(). See the Custom Blocks guide for the field types and the byte-gate.
static func simple_block_kind(config: Dictionary) -> EventSheetBlockKind:
	var kind: EventSheetSimpleBlockKind = EventSheetSimpleBlockKind.new()
	kind.kind_id = str(config.get("kind_id", ""))
	kind.title = str(config.get("title", kind.kind_id))
	kind.category = str(config.get("category", "Blocks"))
	var schema: Array[Dictionary] = []
	for field: Variant in config.get("fields", []):
		if field is Dictionary:
			schema.append(field)
	kind.field_schema = schema
	kind.emit_template = str(config.get("emit", ""))
	kind.summary_template = str(config.get("summary", ""))
	var lift_value: Variant = config.get("lift", null)
	if lift_value is Callable:
		kind.lift_callable = lift_value
	return kind


## Looks a definition up in the live editor's registry ("Core", "Print"). Editor-only:
## returns null when no dock is open.
static func find_ace(provider_id: String, ace_id: String) -> ACEDefinition:
	if not _dock_alive():
		return null
	return _dock._ace_registry.find_definition(provider_id, ace_id)


## Reflects ANY class - engine or class_name script - into browsable vocabulary: methods
## classify by return type, signals become triggers, editor properties become Set/Get
## pairs. Session-cached shared instances; treat the definitions as IMMUTABLE.
static func class_vocabulary(target_class: String) -> Array[ACEDefinition]:
	return EventSheetClassDBSource.definitions_for_class(target_class)


# ── Editor ─────────────────────────────────────────────────────────────────────────────


## The sheet open in the active editor tab, or null (no dock / no sheet).
static func current_sheet() -> EventSheetResource:
	if not _dock_alive():
		return null
	return _dock.get_current_sheet()


## Opens a sheet (.gd or .tres) in the editor. Returns false when no dock is open.
static func open_sheet(path: String) -> bool:
	if not _dock_alive():
		return false
	_dock._load_sheet_from_path(path)
	return true


## THE way to mutate the current sheet from an extension: `mutation` receives the live
## EventSheetResource, and the whole change lands as ONE undo step with the given label,
## followed by a rebuild and a dirty mark. Return false from `mutation` to signal
## "nothing changed" (no undo step, no dirty). RULES: never cache rows across calls -
## the funnel's commit replaces resources with snapshot duplicates, so re-fetch from
## current_sheet() every time.
static func edit(label: String, mutation: Callable) -> bool:
	if not _dock_alive() or not mutation.is_valid():
		return false
	var changed: bool = _dock._perform_undoable_sheet_edit(label, func() -> bool:
		var result: Variant = mutation.call(_dock._current_sheet)
		return bool(result) if result is bool else true)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty(label)
	return changed


## Signal-to-sheet connect (the "wire a signal into events" flow the Node dock uses):
## appends an On <Signal> trigger event to the CURRENT sheet. Core signals map to their
## named triggers (body_entered becomes On Body Entered); anything else becomes a
## signal:<name> trigger with the argument signature baked so the handler emits with the
## right parameters. Returns false when the workspace is closed.
static func add_trigger_for_signal(signal_name: String, args_signature: String = "") -> bool:
	return edit("Connect Signal: %s" % signal_name, func(sheet: EventSheetResource) -> bool:
		sheet.events.append(build_signal_trigger_event(signal_name, args_signature))
		return true)


## The trigger event for one signal - pure and static so tests pin the mapping. Core
## signals get their named trigger id (no args needed - the compiler knows their
## signatures); everything else rides the generic signal:<name> trigger with args baked.
static func build_signal_trigger_event(signal_name: String, args_signature: String = "") -> EventRow:
	var row: EventRow = EventRow.new()
	if EventSheetACELifter.CORE_SIGNAL_TRIGGERS.has(signal_name):
		row.trigger_provider_id = "Core"
		row.trigger_id = str(EventSheetACELifter.CORE_SIGNAL_TRIGGERS[signal_name])
	else:
		row.trigger_provider_id = ""
		row.trigger_id = "signal:%s" % signal_name
		row.trigger_args = args_signature
	return row


## Every signal a node offers (script signals AND its native class's), each as
## {"name": String, "args": String} where args is the baked handler signature
## ("body: Node" style - the exact format trigger_args expects). The connect-signal
## dialog lists these; also handy for tooling that reflects over a scene.
static func signals_of(node: Object) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if node == null:
		return out
	for signal_info: Dictionary in node.get_signal_list():
		var parts: PackedStringArray = PackedStringArray()
		for arg: Dictionary in signal_info.get("args", []):
			var arg_name: String = str(arg.get("name", ""))
			var arg_type: int = int(arg.get("type", TYPE_NIL))
			var arg_class: String = str(arg.get("class_name", ""))
			if not arg_class.is_empty():
				parts.append("%s: %s" % [arg_name, arg_class])
			elif arg_type != TYPE_NIL:
				parts.append("%s: %s" % [arg_name, type_string(arg_type)])
			else:
				parts.append(arg_name)
		out.append({"name": str(signal_info.get("name", "")), "args": ", ".join(parts)})
	return out


## Writes to the editor's status line (is_error tints it as a problem).
static func set_status(text: String, is_error: bool = false) -> void:
	if _dock_alive():
		_dock._set_status(text, is_error)


## Rebuilds the editor's rows from the current sheet (after out-of-funnel changes;
## prefer edit(), which refreshes for you).
static func refresh() -> void:
	if _dock_alive():
		_dock._refresh_after_edit()


## Builds a sheet-native CONDITION/ACTION row so a construct reads as an EVENT, not a text blob - the model
## the whole tool is built on. The discriminating text (a pattern, a guard, a case) goes in the CONDITION
## cell; each `action_lines` entry is an ACTION cell. Returns an EventRowData laid out with the condition |
## action lane divider (or null with no dock). This is the primitive for mapping ANY feature onto the event
## model: the built-in switch/case dogfoods it for its case rows, and a Custom Block's renderer can return
## these so its rows read as events. `source` is the resource a double-click on the row should route to.
static func build_condition_action_row(condition_text: String, action_lines: PackedStringArray, indent: int = 0, source: Resource = null) -> EventRowData:
	if not _dock_alive():
		return null
	var view: EventSheetViewport = _dock._active_view()
	if view == null:
		return null
	return view._row_builder._build_condition_action_row(condition_text, action_lines, indent, source)


## Marks a row as a LANGUAGE block - a row that renders a GDScript construct (a class, a switch case, a
## host binding...) rather than a regular ACE event. The viewport draws such rows with a quiet accent
## stripe + faint wash (the theme's `language_block_accent_color`), so the distinction reads at a glance
## without dimming the row. Returns the same row, so it chains:
## `EventSheets.mark_language_block(EventSheets.build_condition_action_row("case X", lines))`.
## Use it whenever a Custom Block or a feature renders language structure as event rows - every built-in
## language block (data class, methods class, switch case, host binding) carries the same mark.
static func mark_language_block(row: EventRowData) -> EventRowData:
	if row != null:
		row.language_block = true
	return row


## Adds an entry to the Command Palette (Ctrl+P). `action` runs when picked. Re-register
## under the same title to replace; unregister_palette_command removes it. Works before
## the dock opens - entries appear once a palette exists.
static func register_palette_command(title: String, action: Callable, category: String = "") -> void:
	# An optional category prefixes the display title ("My Pack: Reroll Loot") so extension
	# commands group together in the palette's fuzzy filter.
	if not category.is_empty():
		title = "%s: %s" % [category, title]
	unregister_palette_command(title)
	_palette_commands.append({"title": title, "run": action})


static func unregister_palette_command(title: String) -> void:
	for index in range(_palette_commands.size() - 1, -1, -1):
		if str(_palette_commands[index].get("title", "")) == title:
			_palette_commands.remove_at(index)


## The registered extension commands, in registration order (read by the palette).
static func palette_commands() -> Array[Dictionary]:
	return _palette_commands.duplicate()


## Builds the same live Inspector mock the Variable dialog shows - decor, group heading, widget
## miniature, and the plain-language sentence - as a plain Control for YOUR dialogs and panels.
## Dock-free. `attributes` uses the compiler's keys (range/drawer/group/header/info/options/...).
static func build_inspector_preview(variable_name: String, type_name: String, default_text: String, attributes: Dictionary, exported: bool = true, constant: bool = false) -> Control:
	var card: EventSheetInspectorPreviewCard = EventSheetInspectorPreviewCard.new()
	card.update_preview(variable_name, type_name, default_text, attributes, exported, constant)
	return card


## One plain sentence describing an exported variable's Inspector look ("A whole number, from 0
## to 100, shown as a progress bar, grouped under Combat."). Dock-free; the same source of truth
## as the preview card, so your tooling never drifts from the editor's own wording.
static func describe_inspector(type_name: String, attributes: Dictionary, exported: bool = true, constant: bool = false) -> String:
	return EventSheetInspectorPreviewCard.describe(type_name, attributes, exported, constant)


# ── Codegen ────────────────────────────────────────────────────────────────────────────


## Builds a ready-to-fill EventSheetResource from a plain Dictionary, so you can author a sheet,
## behavior, autoload, or tool script from code (there is no other public "create sheet" entry).
## All keys optional:
##   {"class_name": "Enemy", "host_class": "CharacterBody2D", "behavior_mode": false,
##    "autoload_mode": false, "autoload_name": "", "tool_mode": false,
##    "category": "My Pack", "tags": ["ai"], "description": "..."}
## For a tool script pass {"tool_mode": true, "host_class": "EditorScript"}. Append events and
## functions to the returned sheet, then compile() it or open_sheet() its saved path.
static func new_sheet(config: Dictionary = {}) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = str(config.get("host_class", "Node"))
	sheet.custom_class_name = str(config.get("class_name", ""))
	sheet.behavior_mode = bool(config.get("behavior_mode", false))
	sheet.autoload_mode = bool(config.get("autoload_mode", false))
	sheet.autoload_name = str(config.get("autoload_name", ""))
	sheet.tool_mode = bool(config.get("tool_mode", false))
	sheet.addon_category = str(config.get("category", ""))
	sheet.class_description = str(config.get("description", ""))
	if config.has("tags"):
		var tags: PackedStringArray = PackedStringArray()
		for tag: Variant in config.get("tags", []):
			tags.append(str(tag))
		sheet.addon_tags = tags
	return sheet


## Compiles a sheet to plain GDScript. Returns the compiler's result Dictionary:
## "output" (the source text), "success", "errors", "warnings", "source_map".
static func compile(sheet: EventSheetResource, output_path: String = "") -> Dictionary:
	return SheetCompiler.compile(sheet, output_path)


## The exact GDScript a variable compiles to - its "Ships as:" truth, decor comments, tooltip,
## grouping, and the @export annotation included. Deterministic: same variable, same bytes.
static func variable_code(variable: LocalVariable) -> String:
	return SheetCompiler._emit_tree_variable_line(variable)


## Builds one Inspector-GRID variable descriptor (the `"drawer": "table"` payload) from plain
## column phrases, so nobody hand-assembles the column-hint syntax: this is the ONE owner of
## it - the Custom Resource wizard, pack builders, and extensions all converge here.
##
## Each column is a String phrase or a pass-through Dictionary:
##   "name"                      -> {"name": "name", "type": "String"}
##   "weight: float"             -> {"name": "weight", "type": "float"}   (float/int/bool/String)
##   "kind: coin|gem|key"        -> {"name": "kind", "type": "enum(coin|gem|key)"} (a dropdown)
## Options (all optional): tooltip, group, required (bool). Returns the full variable
## descriptor - drop it into EventSheetResource.variables under the grid's name:
##   sheet.variables["drops"] = EventSheets.resource_grid(["name", "kind: coin|gem|key",
##       "weight: float"], {"tooltip": "One drop per row.", "group": "Loot"})
static func resource_grid(columns: Array, options: Dictionary = {}) -> Dictionary:
	var table_columns: Array = []
	for column: Variant in columns:
		if column is Dictionary:
			table_columns.append((column as Dictionary).duplicate(true))
			continue
		var phrase: String = str(column).strip_edges()
		if phrase.is_empty():
			continue
		var column_name: String = phrase
		var column_type: String = "String"
		var colon: int = phrase.find(":")
		if colon >= 0:
			column_name = phrase.substr(0, colon).strip_edges()
			var kind: String = phrase.substr(colon + 1).strip_edges()
			if kind.contains("|"):
				# Plain choices become a dropdown column; spaces around the | are forgiven.
				var choices: PackedStringArray = PackedStringArray()
				for choice: String in kind.split("|"):
					if not choice.strip_edges().is_empty():
						choices.append(choice.strip_edges())
				column_type = "enum(%s)" % "|".join(choices)
			elif kind in ["float", "int", "bool", "String"]:
				column_type = kind
			elif not kind.is_empty():
				column_type = kind  # already-formed hints (enum(...)) pass through untouched
		table_columns.append({"name": column_name, "type": column_type})
	var attributes: Dictionary = {"drawer": "table", "table_columns": table_columns}
	if not str(options.get("tooltip", "")).is_empty():
		attributes["tooltip"] = str(options.get("tooltip"))
	if not str(options.get("group", "")).is_empty():
		attributes["group"] = str(options.get("group"))
	if bool(options.get("required", false)):
		attributes["required"] = true
	return {"type": "Array", "default": [], "exported": true, "attributes": attributes}


## Gives a variable a LIVE validation check without the author learning the machinery: creates
## a `validate_<variable>` sheet function (returns a warning String, "" = valid - the body is a
## ready-to-edit condition/action skeleton) and wires the variable's `validate` attribute to it,
## so the Inspector shows the returned message above the field while it is edited (@tool sheets).
## Reuses an existing function of that name instead of duplicating. Returns the function name,
## or "" when the sheet/variable doesn't exist. The Custom Resource wizard's "Add a validation
## check" box calls this; packs and extensions can too.
static func attach_validator(sheet: EventSheetResource, variable_name: String) -> String:
	if sheet == null or not sheet.variables.has(variable_name):
		return ""
	var function_name: String = "validate_%s" % variable_name
	var exists: bool = false
	for candidate: Resource in sheet.functions:
		if candidate is EventFunction and (candidate as EventFunction).function_name == function_name:
			exists = true
			break
	if not exists:
		var validator: EventFunction = EventFunction.new()
		validator.function_name = function_name
		validator.return_type = TYPE_STRING
		validator.doc_comment = "Checked live while %s is edited in the Inspector: return a warning to show, or \"\" when the data is fine." % variable_name
		var body: RawCodeRow = RawCodeRow.new()
		var descriptor: Dictionary = sheet.variables.get(variable_name, {})
		if str(descriptor.get("type", "")) == "Array":
			body.code = "if %s.is_empty():\n\treturn \"Add at least one row.\"\nreturn \"\"" % variable_name
		else:
			body.code = "# Return a warning message when %s looks wrong, e.g.:\n# if %s == null:\n#\treturn \"Set %s first.\"\nreturn \"\"" % [variable_name, variable_name, variable_name]
		validator.events.append(body)
		sheet.functions.append(validator)
	var variable_descriptor: Dictionary = sheet.variables.get(variable_name, {})
	var variable_attributes: Dictionary = variable_descriptor.get("attributes", {})
	variable_attributes["validate"] = function_name
	variable_descriptor["attributes"] = variable_attributes
	sheet.variables[variable_name] = variable_descriptor
	return function_name


## Opens GDScript source as an editable sheet (the lossless external path: everything
## liftable lifts, everything else stays verbatim - never corrupted).
static func open_gd_as_sheet(source: String) -> EventSheetResource:
	return GDScriptImporter.new().import_external_source(source)


## Publishes a behaviour sheet as an ADDON PACK .gd at base_path + ".gd" - the ONE pack
## pipeline, shared by the bundled builders and the dock's Export Addon (they can never
## drift apart). In order: a pack-local icon.svg beside base_path is adopted when the sheet
## has no icon (then icon_path, when given); raw code de-codes into rows wherever it
## recompiles byte-identically (function bodies, event bodies, trigger signals, helper
## declarations - per-item byte-gated, unliftable code stays verbatim); row uids become
## deterministic (same sheet, same bytes - version-control friendly); and the sheet compiles
## banner-less, so the .gd IS the pack: the editable event sheet AND the runtime script.
## MUTATES `sheet` (lifts + uids + icon) - pass a duplicate to keep an original untouched.
## Returns the compile result Dictionary ({"success", "output", "warnings", ...}).
static func publish_pack(sheet: EventSheetResource, base_path: String, icon_path: String = "") -> Dictionary:
	if sheet == null:
		return {"success": false, "errors": ["No sheet."]}
	if sheet.custom_class_icon.strip_edges().is_empty():
		var local_icon: String = base_path.get_base_dir() + "/icon.svg"
		if FileAccess.file_exists(local_icon):
			sheet.custom_class_icon = local_icon
		elif not icon_path.strip_edges().is_empty():
			sheet.custom_class_icon = icon_path
	EventSheetACELifter.lift_function_bodies(sheet)
	EventSheetACELifter.lift_event_bodies(sheet)
	EventSheetACELifter.lift_signal_declarations(sheet, false)
	EventSheetACELifter.lift_function_declarations(sheet, false)
	stabilize_row_uids(sheet)
	DirAccess.make_dir_recursive_absolute(base_path.get_base_dir())
	return SheetCompiler.compile(sheet, base_path + ".gd", true)


## Stamps deterministic row uids derived from each row's structural path, so an unchanged
## sheet regenerates byte-for-byte (EventRow/EventGroup otherwise mint a random uid per
## _init(), churning every regeneration). publish_pack calls this; generators that compile
## sheets themselves (showcase builders) call it directly before compiling.
static func stabilize_row_uids(sheet: EventSheetResource) -> void:
	var class_seed: String = sheet.custom_class_name if not sheet.custom_class_name.is_empty() else "sheet"
	_publish_assign_uids_in_list(sheet.events, class_seed + "/events")
	for function_resource: Variant in sheet.functions:
		if function_resource is EventFunction:
			_publish_assign_uids_in_list((function_resource as EventFunction).events, class_seed + "/fn/" + (function_resource as EventFunction).function_name)


static func _publish_assign_uids_in_list(rows: Array, path_prefix: String) -> void:
	var index: int = 0
	for row: Variant in rows:
		var row_path: String = "%s/%d" % [path_prefix, index]
		if row is EventRow:
			(row as EventRow).event_uid = row_path.sha256_text().substr(0, 6)
			_publish_assign_uids_in_list((row as EventRow).sub_events, row_path)
		elif row is EventGroup:
			(row as EventGroup).group_uid = row_path.sha256_text().substr(0, 6)
			_publish_assign_uids_in_list((row as EventGroup).events, row_path)
		index += 1


## The byte gate as a service: true when importing `source` and recompiling reproduces
## it byte-identically - the same covenant every built-in lift must satisfy. Use it to
## verify a custom block kind or an emission tweak can never corrupt user files.
static func round_trips(source: String) -> bool:
	var sheet: EventSheetResource = open_gd_as_sheet(source)
	if sheet == null:
		return false
	sheet.external_source_path = "user://__eventsheets_api_roundtrip.gd"
	return str(compile(sheet, sheet.external_source_path).get("output", "")) == source


# ── Save support (build the save_state seam into any script or tool) ───────────────────
#
# A node persists across a save by exposing two plain methods - `save_state() ->
# Dictionary` and `load_state(state: Dictionary)`. The Save System duck-types the pair
# (no base class, no registration), so these services let an extension GENERATE that
# seam, detect it, and preview how a snapshot lands on disk - the same primitives the
# built-in Save Studio is built on. Dock-free; they work in tests and headless tools.

## Object-typed declared types that are references, not data, and never belong in a
## snapshot. Used to pre-tick the safe fields in persistable_fields().
const _NON_DATA_TYPES: PackedStringArray = ["Node", "Node2D", "Node3D", "Control", "Tween", "Timer", "Resource", "Texture2D", "PackedScene", "RandomNumberGenerator", "FastNoiseLite", "Mutex", "Thread", "Camera2D", "Camera3D", "SubViewport", "Sprite2D", "Line2D", "AudioStreamPlayer", "Callable", "Signal"]
const _SAVE_SYSTEM_SCRIPT: String = "res://eventsheet_addons/save_system/save_system_addon.gd"


## Generates the save_state()/load_state() pair from a list of fields, in the repo-wide
## convention: snapshot keys drop a leading underscore, collections deep-copy, and loads
## coerce by type and tolerate a missing key (returning the field's current value). Each
## field is {"name": "_wallet", "type": "Dictionary"}; the type drives the coercion
## (int/float/bool/String/Dictionary/Array, anything else passes through). Returns the
## two methods as one pastable block, or "" when fields is empty.
static func save_state_code(fields: Array) -> String:
	var save_lines: PackedStringArray = PackedStringArray()
	var load_lines: PackedStringArray = PackedStringArray()
	for field: Variant in fields:
		if not field is Dictionary:
			continue
		var var_name: String = str((field as Dictionary).get("name", ""))
		var var_type: String = str((field as Dictionary).get("type", "Variant"))
		var key: String = var_name.trim_prefix("_")
		match var_type:
			"Dictionary":
				save_lines.append("\t\t\"%s\": %s.duplicate(true)," % [key, var_name])
				load_lines.append("\t%s = (state.get(\"%s\", {}) as Dictionary).duplicate(true)" % [var_name, key])
			"Array":
				save_lines.append("\t\t\"%s\": %s.duplicate(true)," % [key, var_name])
				load_lines.append("\t%s = (state.get(\"%s\", []) as Array).duplicate(true)" % [var_name, key])
			"int":
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = int(state.get(\"%s\", %s))" % [var_name, key, var_name])
			"float":
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = float(state.get(\"%s\", %s))" % [var_name, key, var_name])
			"bool":
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = bool(state.get(\"%s\", %s))" % [var_name, key, var_name])
			"String":
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = str(state.get(\"%s\", %s))" % [var_name, key, var_name])
			_:
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = state.get(\"%s\", %s)" % [var_name, key, var_name])
	if save_lines.is_empty():
		return ""
	save_lines[save_lines.size() - 1] = str(save_lines[save_lines.size() - 1]).trim_suffix(",")
	var lines: PackedStringArray = PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"func save_state() -> Dictionary:",
		"\treturn {"
	])
	lines.append_array(save_lines)
	lines.append("\t}")
	lines.append("")
	lines.append("")
	lines.append("func load_state(state: Dictionary) -> void:")
	lines.append("\tif state.is_empty():")
	lines.append("\t\treturn")
	lines.append_array(load_lines)
	return "\n".join(lines)


## Lists a script's top-level variables as [{"name", "type", "recommended"}], where
## `recommended` is true for plain-data fields (numbers, text, dictionaries, arrays,
## Vector2/Color...) and false for object references (a Node, a Resource, an RNG) that
## are pointers, not state. Feed the recommended ones to save_state_code(). Returns []
## when the file is missing or has no top-level vars.
static func persistable_fields(script_path: String) -> Array[Dictionary]:
	var fields: Array[Dictionary] = []
	if not FileAccess.file_exists(script_path):
		return fields
	var pattern: RegEx = RegEx.new()
	pattern.compile("^(?:@export[^\\n]*?\\s+)?var\\s+([a-zA-Z_]\\w*)\\s*(?::\\s*([\\w\\[\\], ]+?))?\\s*(?::?=.*)?$")
	for line: String in FileAccess.get_file_as_string(script_path).split("\n"):
		if line.begins_with("\t") or line.begins_with(" "):
			continue
		var hit: RegExMatch = pattern.search(line.strip_edges())
		if hit == null:
			continue
		var var_name: String = hit.get_string(1)
		var var_type: String = hit.get_string(2).strip_edges()
		fields.append({
			"name": var_name,
			"type": var_type if not var_type.is_empty() else "Variant",
			"recommended": _is_plain_data(var_name, var_type)
		})
	return fields


static func _is_plain_data(var_name: String, var_type: String) -> bool:
	if var_name == "host" or var_type.begins_with("Array[Node"):
		return false
	return not _NON_DATA_TYPES.has(var_type)


## True when `target` participates in the save convention - it exposes BOTH save_state
## and load_state. `target` may be a live Node, a Script/GDScript, or a script path.
static func has_save_support(target: Variant) -> bool:
	if target is Node:
		return (target as Node).has_method("save_state") and (target as Node).has_method("load_state")
	var script: Script = null
	if target is Script:
		script = target
	elif target is String and FileAccess.file_exists(target):
		var loaded: Variant = load(target)
		if loaded is Script:
			script = loaded
	if script == null:
		return false
	var names: Dictionary = {}
	for method: Dictionary in script.get_script_method_list():
		names[str(method.get("name", ""))] = true
	return names.has("save_state") and names.has("load_state")


## One call to add save support to a script: scans its recommended (plain-data) fields
## and returns the save_state/load_state pair to paste in. Skips object references. Use
## persistable_fields() + save_state_code() directly when you want to choose the fields.
static func add_save_support(script_path: String) -> String:
	var recommended: Array[Dictionary] = []
	for field: Dictionary in persistable_fields(script_path):
		if bool(field.get("recommended", false)):
			recommended.append(field)
	return save_state_code(recommended)


## The bundled pack scripts that already ship the seam (their .gd paths), so tooling can
## enumerate what persists out of the box. Empty when eventsheet_addons/ is not installed.
static func save_capable_scripts() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var root: String = "res://eventsheet_addons"
	if not DirAccess.dir_exists_absolute(root):
		return found
	for pack_dir: String in DirAccess.get_directories_at(root):
		for file: String in DirAccess.get_files_at("%s/%s" % [root, pack_dir]):
			if file.ends_with(".gd") and FileAccess.get_file_as_string("%s/%s/%s" % [root, pack_dir, file]).contains("func save_state() -> Dictionary:"):
				found.append("%s/%s/%s" % [root, pack_dir, file])
				break
	return found


## Renders a snapshot Dictionary to on-disk text through the REAL Save System backend in
## the given format ("config", "json", "binary", "csv"), so tooling can show exactly what
## a save will look like before committing to a format. Returns the file text (a hex head
## for binary), or an explanatory line when the Save System pack is not installed.
static func preview_save(data: Dictionary, format: String, key: String = "state") -> String:
	if not FileAccess.file_exists(_SAVE_SYSTEM_SCRIPT):
		return "The Save System pack is not installed (eventsheet_addons/save_system/)."
	var writer: Node = (load(_SAVE_SYSTEM_SCRIPT) as GDScript).new()
	writer.set("save_directory", "user://")
	writer.set("file_pattern", "__eventsheets_api_preview.tmp")
	writer.set("format", format)
	writer.call("save_value", key, data)
	var path: String = str(writer.call("_slot_path"))
	var text: String
	if format == "binary":
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		text = "binary (store_var): %d bytes - compact and fast, not hand-editable.\n\nFirst bytes:\n%s" % [bytes.size(), bytes.slice(0, mini(96, bytes.size())).hex_encode()]
	else:
		text = FileAccess.get_file_as_string(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	writer.free()
	return text


# ── Localisation (the editor UI's language - game l10n is the Translation module) ──────


## Translates an editor-UI string into the active plugin language. English is the default
## and the fallback: with no translation loaded (or English active) the text passes through
## unchanged. Route every user-facing string a FUTURE feature or extension shows through
## this (or through a Control, which auto-translates via the plugin's translation domain),
## and it localises the day someone drops in a CSV. Frozen ids (ace_id, kind_id, provider
## ids) are contracts, never translated - display strings only.
static func translate(text: String) -> String:
	return EventSheetL10n.translate(text)


## Registers an extension's own translation file (the drop-in CSV shape - see
## docs/GUIDE-TRANSLATING-THE-EDITOR.md - or a ready-made Translation resource), merging its
## messages into the language catalogs and refreshing the active language live. Use this when
## a pack ships translations for its OWN display names/descriptions somewhere outside the
## auto-scanned folders. Returns false when the file contributed nothing.
static func register_translation_file(path: String) -> bool:
	EventSheetL10n.ensure_loaded()
	if not EventSheetL10n.load_translation_file(path):
		return false
	EventSheetL10n.set_locale(EventSheetL10n.get_locale())
	return true


## Every language currently offered: "en" plus each locale a translation file provides.
static func available_languages() -> PackedStringArray:
	return EventSheetL10n.available_locales()


## Switches the editor UI language ("en" restores the default English). Persisted per-user.
static func set_editor_language(locale: String) -> void:
	EventSheetL10n.set_locale(locale)
	if _dock_alive():
		_dock.propagate_notification(MainLoop.NOTIFICATION_TRANSLATION_CHANGED)


# ── Project health ─────────────────────────────────────────────────────────────────────


## Runs the Project Doctor audit over every sheet in the project (dock-free). Returns
## {findings: Array[{severity, check, path, message}], errors, warnings, infos}.
static func doctor() -> Dictionary:
	return EventSheetProjectDoctor.run()


## Adds a project-health check that runs everywhere the Doctor runs (dock panel, CLI,
## CI, MCP), after the built-ins. `check` receives (sheet_paths: PackedStringArray,
## findings: Array[Dictionary]) and appends findings shaped
## {"severity": "error"|"warning"|"info", "check": <check_id>, "path": ..., "message": ...}.
## Doctor covenant applies: never write inside res://. Re-register an id to replace it.
static func register_doctor_check(check_id: String, check: Callable) -> void:
	EventSheetProjectDoctor.register_check(check_id, check)


static func unregister_doctor_check(check_id: String) -> void:
	EventSheetProjectDoctor.unregister_check(check_id)


# ── Extension seams (custom features plug in here) ─────────────────────────────────────

## Row context-menu items: [{label, filter: Callable(resource)->bool, action: Callable(resource)}].
static var _row_menu_items: Array[Dictionary] = []
## Lifecycle listeners: event name -> Array[Callable].
static var _lifecycle: Dictionary = {"opened": [], "saved": [], "compiled": []}
## Extension starters: [{label, build: Callable()->EventSheetResource}] - ids 1000+ in the dialog.
static var _starters: Array[Dictionary] = []
## Param editors: hint or type_name -> Callable(param_dict, initial_text) -> LineEdit.
static var _param_editors: Dictionary = {}
## Welcome Preferences rows: Array[Callable() -> Control].
static var _preference_builders: Array[Callable] = []
## Dictionary-defined ACEs live in the registry's extras (see register_simple_ace).
static var _simple_aces: Array[ACEDefinition] = []
## Editor-preview samplers: behavior script path -> Callable(params, base, time) -> Dictionary.
static var _editor_preview_samplers: Dictionary = {}
## Editor-gizmo drawers: behavior script path -> Callable(params, host, canvas) -> void.
static var _editor_gizmo_drawers: Dictionary = {}


## Adds an entry to the right-click menu of event rows. `filter` receives the row's source
## resource (an EventRow) and returns whether the item should appear; `action` receives the same
## resource when clicked. Mutate the sheet inside your action via EventSheets.edit() so the
## change is one undo step. Re-registering a label replaces it.
static func register_row_menu_item(label: String, filter: Callable, action: Callable) -> void:
	unregister_row_menu_item(label)
	_row_menu_items.append({"label": label, "filter": filter, "action": action})


static func unregister_row_menu_item(label: String) -> void:
	for index: int in range(_row_menu_items.size() - 1, -1, -1):
		if str(_row_menu_items[index].get("label", "")) == label:
			_row_menu_items.remove_at(index)


## The registered row items applicable to `resource` (consulted by the context-menu builder).
static func row_menu_items_for(resource: Resource) -> Array[Dictionary]:
	var applicable: Array[Dictionary] = []
	for entry: Dictionary in _row_menu_items:
		var filter: Callable = entry.get("filter", Callable())
		if not filter.is_valid() or bool(filter.call(resource)):
			applicable.append(entry)
	return applicable


## Lifecycle hooks: run `callback(payload)` whenever a sheet is opened ({sheet, path}), saved
## ({sheet, path}), or compiled ({sheet, path, success}). Fired by the editor's own open/save
## funnels - linters, sync tools, and exporters subscribe instead of polling.
static func on_sheet_opened(callback: Callable) -> void:
	(_lifecycle["opened"] as Array).append(callback)


static func on_sheet_saved(callback: Callable) -> void:
	(_lifecycle["saved"] as Array).append(callback)


static func on_sheet_compiled(callback: Callable) -> void:
	(_lifecycle["compiled"] as Array).append(callback)


## Internal: the dock's IO funnels announce lifecycle events here.
static func _notify_lifecycle(event_name: String, payload: Dictionary) -> void:
	for callback: Callable in (_lifecycle.get(event_name, []) as Array):
		if callback.is_valid():
			callback.call(payload)


## Registers a starter template for the FileSystem "Create New > Event Sheet" dialog:
## {"label": "FPS Player", "build": Callable() -> EventSheetResource}. Appears after the
## built-ins; the Callable runs fresh per create.
static func register_starter(config: Dictionary) -> void:
	if str(config.get("label", "")).is_empty() or not (config.get("build") is Callable):
		push_warning("[EventSheets] register_starter needs a label and a build Callable.")
		return
	_starters.append(config)


static func registered_starters() -> Array[Dictionary]:
	return _starters


## Teaches the quick-add bar, the Ghost Row, and the picker your pack's phrases:
## {"dash forward": "dash", ...} - the key is what users type, the value is the search term
## that finds your ACE.
static func register_quick_add_synonyms(synonyms: Dictionary) -> void:
	ACEPickerDialog.register_synonyms(synonyms)


## Registers the blurb shown when a picker section header is selected (the same channel the
## built-in sections use).
static func register_section_description(section_name: String, blurb: String) -> void:
	EventSheetSectionInfo.register_description(section_name, blurb)


## Registers a custom parameter editor. `tag` matches a param's hint (or its type_name when it
## has no hint); `factory(param_dict, initial_text)` must return a LineEdit (subclass and style
## it freely - add buttons, popups, validation - the dialog reads the final value from .text).
static func register_param_editor(tag: String, factory: Callable) -> void:
	_param_editors[tag] = factory


static func param_editor_for(tag: String) -> Callable:
	return _param_editors.get(tag, Callable())


## Commit-time validation for a param HINT (the generic seam the feature-tag nudge uses):
## `validator(value: String) -> Dictionary` runs when the params dialog commits a field
## with that hint. Return {} to let the commit pass, or a prompt spec to ask the user
## first: {"title", "message", "confirm_text", "cancel_text", "on_confirm": Callable}.
## The dialog owns the tricky part ONCE - the commit is deferred and then delivered
## exactly one time whichever way the prompt closes (confirm, cancel, Esc, titlebar X),
## with on_confirm invoked only on confirm. One validator per hint; last registration wins.
static var _param_commit_validators: Dictionary = {}
static var _builtin_validators_registered: bool = false


static func register_param_commit_validator(hint: String, validator: Callable) -> void:
	_param_commit_validators[hint] = validator


static func param_commit_validator_for(hint: String) -> Callable:
	_ensure_builtin_validators()
	return _param_commit_validators.get(hint, Callable())


static func _ensure_builtin_validators() -> void:
	if _builtin_validators_registered:
		return
	_builtin_validators_registered = true
	register_param_commit_validator("feature_tag", EventSheetFeatureTags.commit_validator)


## Adds a row to the Welcome window's Preferences card: `builder()` returns the Control (built
## fresh each time the Welcome first builds). Give your extension's setting a home without
## inventing a settings dialog.
static func register_preference(builder: Callable) -> void:
	_preference_builders.append(builder)


static func preference_builders() -> Array[Callable]:
	return _preference_builders


## Defines an ACE from a plain Dictionary - no provider script file:
##   {"id": "Dash", "kind": "action",              # action | condition | expression
##    "display_name": "Dash Forward", "category": "My Pack",
##    "template": "velocity.x = {speed} * 2.0",     # the GDScript it compiles to
##    "params": [{"id": "speed", "type_name": "float", "default": "300.0"}],
##    "description": "..."}
## register_simple_ace() puts it in every sheet's picker for the session (re-register on plugin
## load); simple_ace() just builds the definition. Ids are contracts once sheets use them.
static func simple_ace(config: Dictionary) -> ACEDefinition:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.id = str(config.get("id", ""))
	definition.provider_id = str(config.get("provider_id", "Extension"))
	definition.display_name = str(config.get("display_name", definition.id.capitalize()))
	definition.category = str(config.get("category", "Extensions"))
	definition.description = str(config.get("description", ""))
	match str(config.get("kind", "action")):
		"condition":
			definition.ace_type = ACEDefinition.ACEType.CONDITION
		"expression":
			definition.ace_type = ACEDefinition.ACEType.EXPRESSION
		_:
			definition.ace_type = ACEDefinition.ACEType.ACTION
	definition.metadata["codegen_template"] = str(config.get("template", ""))
	for param_config: Variant in (config.get("params", []) as Array):
		if param_config is Dictionary:
			definition.parameters.append((param_config as Dictionary).duplicate(true))
	return definition


static func register_simple_ace(config: Dictionary) -> ACEDefinition:
	var definition: ACEDefinition = simple_ace(config)
	if definition.id.is_empty():
		push_warning("[EventSheets] register_simple_ace needs an id.")
		return definition
	for index: int in range(_simple_aces.size() - 1, -1, -1):
		if _simple_aces[index].id == definition.id and _simple_aces[index].provider_id == definition.provider_id:
			_simple_aces.remove_at(index)
	_simple_aces.append(definition)
	if _dock_alive() and _dock.has_method("_refresh_ace_registry"):
		_dock.call("_refresh_ace_registry")
	return definition


static func simple_aces() -> Array[ACEDefinition]:
	return _simple_aces


## Runs a custom guided tour through the built-in tour engine. Steps use the same shape as the
## first-time tour: {"title", "body", "task", "check": Callable(sheet)->bool or Callable()}.
## Needs the workspace open; the check (optional) flips the step to Done live.
static func start_tour(steps: Array[Dictionary]) -> bool:
	if not _dock_alive() or not ("_tour" in _dock):
		return false
	_dock._tour.start(steps)
	return true


## Registers a named tour as a Command Palette entry ("Tour: <name>") - packs ship their own
## 2-minute walkthroughs on the engine the built-in tour uses.
static func register_tour(tour_name: String, steps: Array[Dictionary]) -> void:
	register_palette_command("Tour: %s" % tour_name, func() -> void: start_tour(steps))


## In-editor behavior preview (Tools > Preview Behaviors on Selected Node): a behavior opts in
## by shipping a pure static on its emitted script -
##   static func editor_preview_sample(params: Dictionary, base: Dictionary, time: float) -> Dictionary
## (params = the behavior node's exported values, base = the host's captured rest state, return =
## host properties to apply this frame). This call registers a sampler for scripts that CANNOT
## ship the static (third-party or generated code you don't control): `script_path` is the
## behavior script's resource path; `sampler` has the same signature and takes priority.
static func register_editor_preview(script_path: String, sampler: Callable) -> void:
	_editor_preview_samplers[script_path] = sampler


static func editor_preview_sampler_for(script_path: String) -> Callable:
	return _editor_preview_samplers.get(script_path, Callable())


## In-editor behavior gizmos (select a node, its behaviors draw their setup in the 2D viewport):
## a behavior opts in by shipping a pure static on its emitted script -
##   static func editor_gizmo_draw(params: Dictionary, host: Node2D, canvas: CanvasItem) -> void
## (params = the behavior node's live script variables, host = the parent Node2D, canvas = a
## transient child of the host to draw_* on in host-local space; for world-space shapes first
## canvas.draw_set_transform_matrix(host.get_global_transform().affine_inverse())). This call
## registers a drawer for scripts that CANNOT ship the static (third-party or generated code you
## don't control): `script_path` is the behavior script's resource path; `drawer` has the same
## signature and takes priority over the static.
static func register_editor_gizmo(script_path: String, drawer: Callable) -> void:
	_editor_gizmo_drawers[script_path] = drawer


static func editor_gizmo_drawer_for(script_path: String) -> Callable:
	return _editor_gizmo_drawers.get(script_path, Callable())


## Toggles the behavior preview on the current scene-editor selection - the same entry the
## Tools menu and Command Palette use. Returns false when the workspace is not open.
static func preview_behaviors() -> bool:
	if not _dock_alive() or not ("_behavior_preview" in _dock):
		return false
	_dock._behavior_preview.toggle()
	return true


## One-call pack verification for addon authors - the gates that actually bite, bundled:
## the emitted .gd must PARSE (the build + drift audit don't check this), and it must lift
## back and re-emit byte-identically (the lossless covenant). Returns
## {ok, parses, round_trips, errors: Array[String]}.
static func verify_pack(pack_gd_path: String) -> Dictionary:
	var report: Dictionary = {"ok": false, "parses": false, "round_trips": false, "errors": []}
	if not FileAccess.file_exists(pack_gd_path):
		(report["errors"] as Array).append("no such file: %s" % pack_gd_path)
		return report
	var script: Variant = load(pack_gd_path)
	report["parses"] = script is Script and (script as Script).can_instantiate()
	if not bool(report["parses"]):
		(report["errors"] as Array).append("the emitted GDScript does not parse/load: %s" % pack_gd_path)
	var source: String = FileAccess.get_file_as_string(pack_gd_path)
	report["round_trips"] = round_trips(source)
	if not bool(report["round_trips"]):
		(report["errors"] as Array).append("open-as-sheet does not re-emit byte-identically: %s" % pack_gd_path)
	report["ok"] = bool(report["parses"]) and bool(report["round_trips"])
	return report


# ── Asset drops (FileSystem files dragged onto the sheet canvas) ───────────────────────

## extension (lowercase, no dot) -> {"build": Callable, "description": String}
static var _asset_drop_handlers: Dictionary = {}
static var _builtin_asset_drop_handlers_registered: bool = false


## Registers a drop handler for FileSystem files dragged onto the sheet canvas.
## `build(asset_path: String, target_event: Resource) -> Resource` returns:
##   - an ACEAction: appended to the event row the file landed on, or to a fresh
##     On Ready event when it landed on empty space (the effect maps onto the ACTION
##     lane, like every effect in the event model);
##   - any other sheet row resource (a CustomBlockRow such as the preload kind, a
##     RawCodeRow, ...): inserted at the sheet's top level as a declaration;
##   - null to decline this file (the drop reports nothing was added).
## One handler per extension; last registration wins, so an extension can retarget a
## built-in type. The built-in handlers (scenes spawn, sounds play, images and
## resources/scripts preload, JSON loads into a variable) register through this same seam.
static func register_asset_drop_handler(extensions: PackedStringArray, build: Callable, description: String = "") -> void:
	# Register the built-ins FIRST so a caller retargeting a built-in extension lands AFTER
	# them (last-wins). Without this, the built-ins registered lazily on the first drop and
	# clobbered an extension's earlier registration - the exact opposite of the contract.
	# Safe from recursion: _ensure sets its guard flag before its own register calls, so the
	# nested calls short-circuit.
	_ensure_builtin_asset_drop_handlers()
	for extension: String in extensions:
		_asset_drop_handlers[extension.to_lower().trim_prefix(".")] = {"build": build, "description": description}


## The registered builder for one extension (an invalid Callable when unhandled).
static func asset_drop_builder_for(extension: String) -> Callable:
	_ensure_builtin_asset_drop_handlers()
	return ((_asset_drop_handlers.get(extension.to_lower(), {}) as Dictionary).get("build", Callable()) as Callable)


## Every extension the canvas accepts, sorted - the viewport's drop filter reads this,
## so registering a handler makes the drop cursor light up with no other wiring.
static func handled_asset_extensions() -> PackedStringArray:
	_ensure_builtin_asset_drop_handlers()
	var extensions: PackedStringArray = PackedStringArray()
	for extension: Variant in _asset_drop_handlers.keys():
		extensions.append(str(extension))
	extensions.sort()
	return extensions


## A ready-to-insert ACEAction built from a built-in Core descriptor: identity and
## template copied, {uid} baked fresh so stateful templates stay per-instance - exactly
## what a picker apply produces. The building block asset-drop handlers (and any other
## extension that inserts actions) use instead of re-implementing the apply path.
static func builtin_action(ace_id: String, params: Dictionary) -> ACEAction:
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		if descriptor.ace_id == ace_id:
			var action: ACEAction = ACEAction.new()
			action.provider_id = descriptor.provider_id
			action.ace_id = ace_id
			action.params = params.duplicate(true)
			action.codegen_template = str(descriptor.codegen_template)
			if action.codegen_template.contains("{uid}"):
				action.codegen_template = action.codegen_template.replace("{uid}", EventSheetDock._fresh_uid_token())
			return action
	return null


## A preload Custom Block row (`const Name := preload("res://...")`) for a resource
## path - runs on the Custom Block API's preload kind. The constant name derives from
## the filename (PascalCase, illegal characters stripped, letter-prefixed).
static func preload_block_for(asset_path: String) -> CustomBlockRow:
	var block: CustomBlockRow = CustomBlockRow.new()
	block.kind_id = "preload"
	block.fields = {"name": _preload_constant_name(asset_path), "path": asset_path}
	return block


static func _preload_constant_name(asset_path: String) -> String:
	var base: String = asset_path.get_file().get_basename().to_pascal_case()
	var sanitizer: RegEx = RegEx.new()
	sanitizer.compile("[^A-Za-z0-9_]")
	base = sanitizer.sub(base, "", true)
	if base.is_empty() or base[0].is_valid_int():
		base = "Res" + base
	return base


static func _ensure_builtin_asset_drop_handlers() -> void:
	if _builtin_asset_drop_handlers_registered:
		return
	_builtin_asset_drop_handlers_registered = true
	register_asset_drop_handler(PackedStringArray(["tscn", "scn"]), _drop_build_spawn_scene, "Spawn the scene at a position")
	register_asset_drop_handler(PackedStringArray(["ogg", "wav", "mp3"]), _drop_build_play_sound, "Play the sound")
	register_asset_drop_handler(PackedStringArray(["json"]), _drop_build_load_json, "Load the JSON file into a variable")
	# Images are Texture2D resources: a preload const compiles on ANY host and is referenceable,
	# unlike a `self.texture = …` action that fails on a host with no texture member (Node, Node2D,
	# CharacterBody2D, Control...) - which broke the whole sheet's compile.
	register_asset_drop_handler(PackedStringArray(["png", "jpg", "jpeg", "webp", "svg", "bmp", "tga", "ktx", "exr"]), _drop_build_preload, "Preload the image as a constant")
	register_asset_drop_handler(PackedStringArray(["tres", "res", "gd"]), _drop_build_preload, "Preload as a constant")


static func _drop_build_spawn_scene(asset_path: String, _target_event: Resource) -> Resource:
	return builtin_action("SpawnSceneAt", {"path": ACEParamsDialog.format_quoted_literal(asset_path), "position": "Vector2(0, 0)"})


static func _drop_build_play_sound(asset_path: String, _target_event: Resource) -> Resource:
	return builtin_action("PlaySound", {"path": ACEParamsDialog.format_quoted_literal(asset_path)})


static func _drop_build_load_json(asset_path: String, _target_event: Resource) -> Resource:
	return builtin_action("JsonLoadFile", {"var_name": "data", "path": ACEParamsDialog.format_quoted_literal(asset_path)})


static func _drop_build_preload(asset_path: String, _target_event: Resource) -> Resource:
	return preload_block_for(asset_path)


# ── Internal wiring (called by the plugin itself) ─────────────────────────────────────


## The dock announces itself here during setup; extensions never call this.
static func _register_dock(dock: Control) -> void:
	_dock = dock


static func _dock_alive() -> bool:
	return _dock != null and is_instance_valid(_dock)
