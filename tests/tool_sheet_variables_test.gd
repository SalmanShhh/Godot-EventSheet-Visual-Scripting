# Godot EventSheets - a @tool sheet's variables, written both ways.
#
# A tool sheet's variables are rows (a `.gd` sheet keeps its variables in the tree), and each of their
# options must come out as the plain GDScript a tool author would write by hand:
#   * Show if / Lock unless: one generated _validate_property after the last variable, and a setter on
#     every variable a condition reads that calls notify_property_list_changed(), so the field appears
#     the moment the box is ticked instead of after the node is selected again;
#   * On changed, with Wait for ready: the setter calls the function behind `if is_node_ready():`, since
#     a tool script's setters also run while the scene loads;
#   * Saved but hidden: `@export_storage`.
# Opened again, a sheet-written file reads back as the options that wrote it (the generated function
# and the refresh-only setters go back onto the variables), byte for byte; anything hand-edited stays
# the code it is.
@tool
class_name ToolSheetVariablesTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P: String = "tool_sheet_variables_test"


static func run() -> bool:
	var ok: bool = true
	ok = _row_variables_compile() and ok
	ok = _reopened_file_reads_as_options() and ok
	ok = _hand_edited_function_stays_code() and ok
	ok = _own_function_wins() and ok
	ok = _dictionary_wait_for_ready() and ok
	ok = _dialog_payload_keeps_the_options() and ok
	return ok


static func _row(var_name: String, type_name: String, value: Variant, attributes: Dictionary) -> LocalVariable:
	var row: LocalVariable = LocalVariable.new()
	row.name = var_name
	row.type_name = type_name
	row.default_value = value
	row.exported = true
	row.attributes = attributes
	return row


static func _painter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.tool_mode = true
	sheet.host_class = "Node2D"
	sheet.events.append(_row("use_noise", "bool", true, {}))
	sheet.events.append(_row("noise_seed", "int", 1234, {"show_if": "use_noise"}))
	sheet.events.append(_row("mode_custom", "bool", false, {}))
	sheet.events.append(_row("custom_scale", "float", 1.0, {"lock_unless": "mode_custom"}))
	sheet.events.append(_row("brush_size", "int", 3, {"on_changed": "rebuild_preview", "wait_for_ready": true}))
	sheet.events.append(_row("hardness", "float", 0.5, {"on_changed": "rebuild_preview"}))
	var hidden: LocalVariable = _row("_baked_cells", "Array[Vector2i]", [], {"storage": true})
	hidden.default_value = "[]"
	hidden.expression_default = true
	sheet.events.append(hidden)
	var rebuild: EventFunction = EventFunction.new()
	rebuild.function_name = "rebuild_preview"
	sheet.functions.append(rebuild)
	return sheet


static func _row_variables_compile() -> bool:
	var result: Dictionary = SheetCompiler.compile(_painter(), "user://eventsheets_tool_vars.gd")
	var output: String = str(result.get("output", ""))
	return SUPPORT.pins(P, [
		["a variable a Show if reads refreshes the Inspector from its setter",
			output.contains("@export var use_noise: bool = true:\n\tset(value):\n\t\tuse_noise = value\n\t\tnotify_property_list_changed()\n@export var noise_seed: int = 1234\n"), true],
		["a variable a Lock unless reads does too",
			output.contains("@export var mode_custom: bool = false:\n\tset(value):\n\t\tmode_custom = value\n\t\tnotify_property_list_changed()\n"), true],
		["On changed with Wait for ready calls the function once the node is ready",
			output.contains("@export var brush_size: int = 3:\n\tset(value):\n\t\tbrush_size = value\n\t\tif is_node_ready():\n\t\t\trebuild_preview()\n"), true],
		["On changed without it calls the function straight away",
			output.contains("@export var hardness: float = 0.5:\n\tset(value):\n\t\thardness = value\n\t\trebuild_preview()\n"), true],
		["Saved but hidden is @export_storage",
			output.contains("@export_storage var _baked_cells: Array[Vector2i] = []\n"), true],
		["one _validate_property, straight after the last variable",
			output.contains("@export_storage var _baked_cells: Array[Vector2i] = []\n\n%s\nfunc _validate_property(property: Dictionary) -> void:\n\tif str(property.name) == \"noise_seed\" and not bool(use_noise):\n\t\tproperty.usage &= ~PROPERTY_USAGE_EDITOR\n\tif str(property.name) == \"custom_scale\" and not bool(mode_custom):\n\t\tproperty.usage |= PROPERTY_USAGE_READ_ONLY\n" % SheetCompiler.INSPECTOR_CONDITIONS_DOC), true],
		["nothing to warn about", result.get("warnings"), []],
	])


static func _reopened_file_reads_as_options() -> bool:
	var output: String = SUPPORT.compile_output(_painter(), "user://eventsheets_tool_vars.gd")
	var reopened: EventSheetResource = SUPPORT.reopen(output)
	var rows: Dictionary = {}
	for entry: Variant in reopened.events:
		if entry is LocalVariable:
			rows[(entry as LocalVariable).name] = entry
	var function_names: Array = []
	for entry: Variant in reopened.functions:
		function_names.append((entry as EventFunction).function_name)
	return SUPPORT.pins(P, [
		["the Show if comes back onto its variable", (rows["noise_seed"] as LocalVariable).attributes.get("show_if"), "use_noise"],
		["so does the Lock unless", (rows["custom_scale"] as LocalVariable).attributes.get("lock_unless"), "mode_custom"],
		["the refresh-only setter is the option's, not a setter of its own", (rows["use_noise"] as LocalVariable).setter_body, ""],
		["the generated function is not read as a function the author wrote", function_names.has("_validate_property"), false],
		["a setter that does more stays the setter it is",
			(rows["brush_size"] as LocalVariable).setter_body, "brush_size = value\nif is_node_ready():\n\trebuild_preview()"],
		["the file saves back byte for byte", SUPPORT.reemit(output, "user://eventsheets_tool_vars_again.gd"), output],
	])


static func _hand_edited_function_stays_code() -> bool:
	var output: String = SUPPORT.compile_output(_painter(), "user://eventsheets_tool_vars.gd")
	# A line the compiler never writes, added by hand: the whole function stays the author's.
	var edited: String = output.replace("\t\tproperty.usage |= PROPERTY_USAGE_READ_ONLY\n",
		"\t\tproperty.usage |= PROPERTY_USAGE_READ_ONLY\n\tif str(property.name) == \"hardness\":\n\t\tproperty.hint_string = \"\"\n")
	var reopened: EventSheetResource = SUPPORT.reopen(edited)
	var lifted_condition: bool = false
	for entry: Variant in reopened.events:
		if entry is LocalVariable and (entry as LocalVariable).attributes.has("show_if"):
			lifted_condition = true
	# A group show-if comment with no function behind it is a plain comment: reading it as the option
	# would make the save write a function the file does not have.
	var comment_only: String = "extends Node\n\n@export var dashed: bool = false\n# @inspector_show_if dashed\n@export_group(\"Dashes\")\n@export var dash_count: int = 16\n"
	return SUPPORT.pins(P, [
		["a hand-edited function is not read back as options", lifted_condition, false],
		["and saves back byte for byte", SUPPORT.reemit(edited, "user://eventsheets_tool_vars_edited.gd"), edited],
		["a lone group show-if comment saves back byte for byte", SUPPORT.reemit(comment_only, "user://eventsheets_tool_vars_comment.gd"), comment_only],
	])


static func _own_function_wins() -> bool:
	var sheet: EventSheetResource = _painter()
	var own: RawCodeRow = RawCodeRow.new()
	own.code = "func _validate_property(property: Dictionary) -> void:\n\tpass"
	sheet.events.append(own)
	var result: Dictionary = SheetCompiler.compile(sheet, "user://eventsheets_tool_vars_own.gd")
	var output: String = str(result.get("output", ""))
	return SUPPORT.pins(P, [
		["the sheet's own _validate_property is the only one", output.count("func _validate_property("), 1],
		["no refresh setter serves a function that is not written", output.contains("notify_property_list_changed()"), false],
		["the warning names what is left to it", result.get("warnings"),
			["The sheet writes its own _validate_property, so the Show if / Lock unless on noise_seed, custom_scale are left to it."]],
	])


static func _dictionary_wait_for_ready() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.tool_mode = true
	sheet.variables = {"brush_size": {"type": "int", "default": 3, "exported": true,
		"attributes": {"on_changed": "rebuild_preview", "wait_for_ready": true}}}
	var rebuild: EventFunction = EventFunction.new()
	rebuild.function_name = "rebuild_preview"
	sheet.functions.append(rebuild)
	var output: String = SUPPORT.compile_output(sheet, "user://eventsheets_tool_vars_dict.gd")
	return SUPPORT.check(P, "a dictionary variable's On changed waits for ready too",
		output.contains("@export var brush_size: int = 3:\n\tset(value):\n\t\tbrush_size = value\n\t\tif is_node_ready():\n\t\t\trebuild_preview()\n"), true)


static func _dialog_payload_keeps_the_options() -> bool:
	var kept: Dictionary = EventSheetVariablesManager._tree_group_attributes({
		"show_if": "use_noise", "lock_unless": "mode_custom", "group_show_if": "dashed", "group": "Noise",
		"on_changed": "rebuild_preview", "wait_for_ready": true, "storage": true,
		"tool_button": {"args": "\"Bake\", \"Bake\"", "label": "Bake"}})
	return SUPPORT.check(P, "a sheet variable keeps what the dialog sends for a tool", kept, {
		"group": "Noise", "show_if": "use_noise", "group_show_if": "dashed", "lock_unless": "mode_custom",
		"on_changed": "rebuild_preview", "wait_for_ready": true, "storage": true,
		"tool_button": {"args": "\"Bake\", \"Bake\"", "label": "Bake"}})
