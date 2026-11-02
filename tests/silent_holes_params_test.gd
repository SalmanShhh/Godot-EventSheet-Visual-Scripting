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
	all_passed = _locals_and_parameters_are_variables() and all_passed
	all_passed = _values_are_judged_where_they_are_written() and all_passed
	all_passed = _completion_keeps_its_detail() and all_passed
	all_passed = _completion_label_keeps_the_name() and all_passed
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


## A variable picker holds a name the row can write to, and a local or a parameter is one: an opened
## `left -= 1` inside a function must not lock its dialog behind "left is not a variable".
static func _locals_and_parameters_are_variables() -> bool:
	var source: String = "extends Node2D\n\nvar kills: int = 0\n\n\nfunc hurt(amount: int) -> void:\n\tvar left: int = amount - 1\n\tfor i in range(3):\n\t\tkills += i + left\n\n\nfunc _on_entered(body: Node2D) -> void:\n\tprint(body)\n"
	var sheet: EventSheetResource = SUPPORT.reopen(source, true, "res://tests/silent_holes_scope_source.gd")
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	var picker: Dictionary = {"id": "variable", "display_name": "Variable", "hint": "variable_reference"}
	var rows: Array = []
	for name_text: String in ["kills", "position", "amount", "left", "i", "body"]:
		rows.append(["%s may be written to" % name_text, dialog.blocking_problem_for(picker, name_text, false), {}])
	rows.append(["a name nothing declares is still refused", dialog.blocking_problem_for(picker, "kils", false).is_empty(), false])
	# The form's own gate asks the same question.
	var definition: ACEDefinition = _definition_with([picker])
	var picker_edit: LineEdit = LineEdit.new()
	picker_edit.text = "left"
	var form: ACEParamsDialog = _dialog_with(definition, {"variable": picker_edit}, sheet)
	rows.append(["the form lets OK through for a local", form._blocking_expression_field(), {}])
	picker_edit.text = "kils"
	rows.append(["and refuses a typo", form._blocking_expression_field().is_empty(), false])
	picker_edit.free()
	return SUPPORT.pins(NAME, rows)


## Some values are not expressions on their own and are perfectly good where their verb writes them: a
## test on the element a sibling field names, the statement a body runs, a list of values between brackets,
## the name a lambda binds. Asked of the verb's own template, a good one passes and a typo still does not.
static func _values_are_judged_where_they_are_written() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	var filter: String = "{var_name}.filter(func({element}): return {predicate})"
	var predicate: Dictionary = {"id": "predicate", "display_name": "Where", "hint": "expression"}
	var element: Dictionary = {"id": "element", "display_name": "Element", "hint": "expression"}
	var values: Dictionary = {"var_name": "items", "element": "x", "predicate": "x > 0"}
	var pick: String = "[{values}].pick_random()"
	var code: String = "{code}"
	var body: Dictionary = {"id": "code", "display_name": "Code", "hint": "expression"}
	var rows: Array = [
		["a test on the element a sibling names passes", dialog.blocking_problem_for(predicate, "x > 5", true, "", filter, values), {}],
		["a typo in that test does not", dialog.blocking_problem_for(predicate, "y > 5", true, "", filter, values).is_empty(), false],
		["the name the lambda binds passes", dialog.blocking_problem_for(element, "item", true, "", filter, {"predicate": "item > 0"}), {}],
		["a list between brackets passes", dialog.blocking_problem_for({"id": "values", "hint": "expression"}, "1, 2, 3", true, "", pick, {}), {}],
		["a statement a body runs passes", dialog.blocking_problem_for(body, "var total := 1", true, "", code, {}), {}],
		["a statement that cannot compile does not", dialog.blocking_problem_for(body, "var total := no_such_name", true, "", code, {}).is_empty(), false],
		["without a template the value stands alone, as before", dialog.blocking_problem_for(predicate, "x > 5", true).is_empty(), false],
	]
	# The form's own gate, with the shipped verb.
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	var no_sources: Array[Object] = []
	registry.refresh_from_sources(no_sources, true)
	for definition: ACEDefinition in registry.get_all_definitions():
		if definition.id != "ArrayFilter":
			continue
		var form: ACEParamsDialog = ACEParamsDialog.new()
		form.set_lint_context_provider(func() -> EventSheetResource: return sheet)
		form._definition = definition
		var made: Array[Control] = []
		for parameter: Variant in definition.parameters:
			var described: Dictionary = parameter
			var key: String = str(described["id"])
			form._param_dicts[key] = described
			var seeded: String = "items" if key == "var_name" else str(described.get("default_value", ""))
			made.append(form._create_field(described, {key: seeded}, key, str(described.get("hint", ""))))
		form._read_variable_context()
		rows.append(["Filter's own defaults close the form", form._blocking_expression_field().get("message", ""), ""])
		rows.append(["and its test wears no error as it is built, before the element's field exists",
			str((form._field_notes.get("predicate", {}) as Dictionary).get("level", "")), ""])
		var box: CodeEdit = form._fields["predicate"]
		box.draw.emit()
		rows.append(["a box with no suggestions open keeps its one line", box.custom_minimum_size.y, 31.0])
		for control: Control in made:
			control.free()
	return SUPPORT.pins(NAME, rows)


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


## CodeEdit right-aligns a line too long for its popup, so a long detail would hide the name it describes.
static func _completion_label_keeps_the_name() -> bool:
	var long_detail: String = "a sentence far longer than any one line of the popup has any room for at all"
	var fitted: String = ACEParamsDialog.completion_label("kills", long_detail, 30)
	return SUPPORT.pins(NAME, [
		["the line fits the room", fitted.length() <= 30, true],
		["and starts with the whole name", fitted.begins_with("kills    a sentence"), true],
		["a name with no room beside it stands alone", ACEParamsDialog.completion_label("a_very_long_variable_name_here", long_detail, 30), "a_very_long_variable_name_here"],
		["a short detail is left whole", ACEParamsDialog.completion_label("kills", "int", 30), "kills    int"],
	])


static func _completion_keeps_its_detail() -> bool:
	return SUPPORT.pins(NAME, [
		["a detail follows the name after a gap", ACEParamsDialog.completion_label("hp", "int"), "hp    int"],
		["no detail leaves the bare name", ACEParamsDialog.completion_label("hp", "  "), "hp"],
		["the first sentence of a description", ACEParamsDialog.first_sentence("Rounds down. Then more."), "Rounds down"],
		["a long description is cut", ACEParamsDialog.first_sentence("x".repeat(80)).length() <= 60, true],
	])
