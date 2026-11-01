@tool
class_name SilentHolesParamsTest
extends RefCounted

# The commit gate of the Edit Parameter dialog and of the two places that edit one parameter without
# it (the sheet's inline value editor and the Properties bar). Each check already existed and was
# skipped, discarded or never shown: a blank required field did not block OK, an unhealthy lint probe
# skipped the compile check without a word, a vector's axis boxes were never checked, and the inline
# editors committed anything. The completion popup also dropped the type line of every suggestion.

const SUPPORT := preload("res://tests/support.gd")
const NAME := "silent_holes_params_test"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _blank_required_blocks_ok() and all_passed
	all_passed = _lint_probe_unhealthy_is_said() and all_passed
	all_passed = _vector_axes_are_checked() and all_passed
	all_passed = _shared_gate_for_inline_editors() and all_passed
	all_passed = _completion_keeps_its_detail() and all_passed
	return all_passed


static func _definition_with(parameters: Array) -> ACEDefinition:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = "test"
	definition.id = "SilentHolesVerb"
	definition.display_name = "Silent holes verb"
	definition.parameters = parameters
	return definition


## Wires a dialog with no window to a definition and a set of fields, the way open() leaves it.
static func _dialog_with(definition: ACEDefinition, fields: Dictionary, sheet: EventSheetResource) -> ACEParamsDialog:
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	dialog._definition = definition
	for parameter: Variant in definition.parameters:
		dialog._param_dicts[str((parameter as Dictionary)["id"])] = parameter
	dialog._fields = fields
	dialog._read_variable_context()
	return dialog


static func _blank_required_blocks_ok() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var definition: ACEDefinition = _definition_with([
		{"id": "label", "display_name": "Label", "type_name": "String", "required": true},
		{"id": "note", "display_name": "Note", "type_name": "String"},
	])
	var label_edit: LineEdit = LineEdit.new()
	var note_edit: LineEdit = LineEdit.new()
	var dialog: ACEParamsDialog = _dialog_with(definition, {"label": label_edit, "note": note_edit}, sheet)
	var confirmed: Array = []
	dialog.params_confirmed.connect(func(_d: Variant, values: Dictionary, _c: Dictionary) -> void:
		confirmed.append(values))
	dialog._on_confirmed()
	var blocker: Dictionary = dialog._blocking_expression_field()
	var passed: bool = SUPPORT.pins(NAME, [
		["a blank required field blocks OK: nothing was committed", confirmed.size(), 0],
		["the blocker names the blank field", blocker.get("field") == label_edit, true],
		["the reason is the one beside OK", str(blocker.get("reason", "")), "Label is empty"],
		["the sentence says why", str(blocker.get("message", "")).contains("cannot be left blank"), true],
	])
	label_edit.text = "hello"
	dialog._on_confirmed()
	passed = SUPPORT.pins(NAME, [
		["once filled, OK commits", confirmed.size(), 1],
		["the optional blank never blocked", str((confirmed[0] as Dictionary).get("note", "x")), ""],
	]) and passed
	# A literal of the wrong kind is only a warning: it compiles, so it never blocks.
	var numeric: ACEDefinition = _definition_with([
		{"id": "amount", "display_name": "Amount", "type_name": "float", "hint": "expression"}])
	var amount_edit: CodeEdit = CodeEdit.new()
	amount_edit.text = "\"hello\""
	var warn_dialog: ACEParamsDialog = _dialog_with(numeric, {"amount": amount_edit}, sheet)
	passed = SUPPORT.check(NAME, "a warning-level note does not block",
		warn_dialog._blocking_expression_field().is_empty(), true) and passed
	for node: Node in [label_edit, note_edit, amount_edit]:
		node.free()
	return passed


static func _lint_probe_unhealthy_is_said() -> bool:
	# A sheet variable named like a member of the host class makes the probe itself unparseable.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables["position"] = {"type": "Vector2", "default": "Vector2(0, 0)"}
	var definition: ACEDefinition = _definition_with([
		{"id": "amount", "display_name": "Amount", "type_name": "float", "hint": "expression"}])
	var amount_edit: CodeEdit = CodeEdit.new()
	amount_edit.text = "1 + 1"
	var dialog: ACEParamsDialog = _dialog_with(definition, {"amount": amount_edit}, sheet)
	var healthy: bool = dialog._lint_context_healthy()
	var reason: String = dialog._lint_unhealthy_reason()
	var passed: bool = SUPPORT.pins(NAME, [
		["the probe is unhealthy for a variable shadowing a host member", healthy, false],
		["the reason names the variable", reason.contains("position"), true],
		["the reason names the host class", reason.contains("Node2D"), true],
	])
	var fine: EventSheetResource = EventSheetResource.new()
	var fine_dialog: ACEParamsDialog = _dialog_with(definition, {"amount": amount_edit}, fine)
	passed = SUPPORT.check(NAME, "a healthy sheet says nothing", fine_dialog._lint_unhealthy_reason(), "") and passed
	# Opened for real, the note is carried to the quiet slot beside OK.
	dialog._lint_paused_reason = reason
	dialog._ok_reason = Label.new()
	dialog._refresh_notes()
	passed = SUPPORT.pins(NAME, [
		["the slot beside OK says the check is paused", dialog._ok_reason.text, "compile check paused"],
		["the tooltip carries the full reason", dialog._ok_reason.tooltip_text, reason],
	]) and passed
	dialog._ok_reason.free()
	amount_edit.free()
	return passed


static func _vector_axes_are_checked() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var definition: ACEDefinition = _definition_with([
		{"id": "where", "display_name": "Where", "type_name": "Vector2", "hint": "expression"}])
	var dialog: ACEParamsDialog = _dialog_with(definition, {}, sheet)
	var container: Control = dialog._create_vector_field("where", PackedStringArray(["1", "2"]))
	var axes: Array = container.get_meta("vector_axis_edits")
	var passed: bool = SUPPORT.check(NAME, "two clean axes do not block",
		dialog._blocking_expression_field().is_empty(), true)
	(axes[1] as LineEdit).text = "(3 + "
	(axes[1] as LineEdit).text_changed.emit("(3 + ")
	var structural: Dictionary = dialog._blocking_expression_field()
	passed = SUPPORT.pins(NAME, [
		["an unbalanced axis blocks", structural.get("field") == axes[1], true],
		["the axis box turns red as it is typed", _tinted(axes[1]), true],
	]) and passed
	(axes[1] as LineEdit).text = "no_such_name_here + 1"
	passed = SUPPORT.check(NAME, "an axis that does not compile blocks",
		dialog._blocking_expression_field().get("field") == axes[1], true) and passed
	(axes[1] as LineEdit).text = ""
	var blank: Dictionary = dialog._blocking_expression_field()
	passed = SUPPORT.pins(NAME, [
		["a blank axis blocks", blank.get("field") == axes[1], true],
		["and says so", str(blank.get("message", "")).contains("axis"), true],
	]) and passed
	(axes[1] as LineEdit).text = "2"
	passed = SUPPORT.check(NAME, "a fixed axis lets OK through",
		dialog._blocking_expression_field().is_empty(), true) and passed
	container.free()
	return passed


static func _tinted(control: Control) -> bool:
	return control.has_theme_color_override("font_color")


static func _shared_gate_for_inline_editors() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	var required: Dictionary = {"id": "label", "display_name": "Label", "type_name": "String", "required": true}
	var expression: Dictionary = {"id": "amount", "display_name": "Amount", "type_name": "float", "hint": "expression"}
	var blank: Dictionary = dialog.blocking_problem_for(required, "  ", false)
	var good: Dictionary = dialog.blocking_problem_for(required, "x", false)
	var broken: Dictionary = dialog.blocking_problem_for(expression, "(1 +", true)
	var unknown: Dictionary = dialog.blocking_problem_for(expression, "no_such_name_here + 1", true)
	var fine: Dictionary = dialog.blocking_problem_for(expression, "1 + 2", true)
	var warned: Dictionary = dialog.blocking_problem_for(
		{"id": "amount", "display_name": "Amount", "type_name": "float"}, "\"text\"", false)
	var passed: bool = SUPPORT.pins(NAME, [
		["a blank required value is refused", str(blank.get("reason", "")), "Label is empty"],
		["a filled one is not", good.is_empty(), true],
		["a malformed expression is refused", broken.is_empty(), false],
		["a non-compiling expression is refused", unknown.is_empty(), false],
		["a good expression passes", fine.is_empty(), true],
		["a warning-level literal passes", warned.is_empty(), true],
	])
	# The vector's axis boxes count as GDScript for the bar's commit.
	var holder: Control = Control.new()
	holder.set_meta("vector_axis_edits", [])
	var code: CodeEdit = CodeEdit.new()
	var plain: LineEdit = LineEdit.new()
	passed = SUPPORT.pins(NAME, [
		["a vector field holds GDScript", EventSheetParamFieldFactory.holds_expression(holder), true],
		["a code box holds GDScript", EventSheetParamFieldFactory.holds_expression(code), true],
		["a plain box does not", EventSheetParamFieldFactory.holds_expression(plain), false],
	]) and passed
	holder.free()
	code.free()
	plain.free()
	return passed


static func _completion_keeps_its_detail() -> bool:
	return SUPPORT.pins(NAME, [
		["a detail follows the name after a gap", ACEParamsDialog.completion_label("hp", "int"), "hp    int"],
		["no detail leaves the bare name", ACEParamsDialog.completion_label("hp", "  "), "hp"],
		["the first sentence of a description", ACEParamsDialog.first_sentence("Rounds down. Then more."), "Rounds down"],
		["a long description is cut", ACEParamsDialog.first_sentence("x".repeat(80)).length() <= 60, true],
	])
