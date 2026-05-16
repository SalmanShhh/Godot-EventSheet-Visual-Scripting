# EventForge — EventSheetEditor helper behavior tests
@tool
extends RefCounted
class_name EventSheetEditorTest

## Runs EventSheetEditor helper tests.
static func run() -> bool:
	var all_passed: bool = true
	var editor: EventSheetEditor = EventSheetEditor.new()

	all_passed = _check("parse int", editor._parse_variable_initial_value("42", "int"), 42) and all_passed
	all_passed = _check("parse float", editor._parse_variable_initial_value("3.5", "float"), 3.5) and all_passed
	all_passed = _check("parse bool true", editor._parse_variable_initial_value("true", "bool"), true) and all_passed
	all_passed = _check("parse bool false", editor._parse_variable_initial_value("no", "bool"), false) and all_passed
	all_passed = _check("parse string", editor._parse_variable_initial_value("Player", "String"), "Player") and all_passed
	all_passed = _check("parse variant empty -> null", editor._parse_variable_initial_value(" ", "Variant"), null) and all_passed

	# LineEdit fallback still works for int params (backwards compatibility).
	var int_param: ACEParam = ACEParam.new()
	int_param.type_name = "int"
	var int_input: LineEdit = LineEdit.new()
	int_input.text = "13"
	all_passed = _check("ace param int input", editor._extract_ace_param_input_value(int_param, int_input), 13) and all_passed
	int_input.text = "abc"
	all_passed = _check("ace param int invalid input", editor._extract_ace_param_input_value(int_param, int_input), 0) and all_passed
	int_input.text = ""
	all_passed = _check("ace param int empty input", editor._extract_ace_param_input_value(int_param, int_input), 0) and all_passed

	# SpinBox controls for int and float params.
	var spin_int_param: ACEParam = ACEParam.new()
	spin_int_param.type_name = "int"
	var spin_int: SpinBox = SpinBox.new()
	spin_int.value = 7.0
	all_passed = _check("ace param int spinbox", editor._extract_ace_param_input_value(spin_int_param, spin_int), 7) and all_passed

	var spin_float_param: ACEParam = ACEParam.new()
	spin_float_param.type_name = "float"
	var spin_float: SpinBox = SpinBox.new()
	spin_float.value = 3.14
	all_passed = _check("ace param float spinbox", editor._extract_ace_param_input_value(spin_float_param, spin_float), 3.14) and all_passed

	var bool_param: ACEParam = ACEParam.new()
	bool_param.type_name = "boolean"
	var bool_input: OptionButton = OptionButton.new()
	bool_input.add_item("False")
	bool_input.add_item("True")
	bool_input.select(1)
	all_passed = _check("ace param bool input", editor._extract_ace_param_input_value(bool_param, bool_input), true) and all_passed
	bool_input.select(0)
	all_passed = _check("ace param bool false input", editor._extract_ace_param_input_value(bool_param, bool_input), false) and all_passed

	# Variable name list from sheet.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables["health"] = {"type": "int", "default": 100}
	sheet.variables["speed"] = {"type": "float", "default": 5.0}
	editor.current_sheet = sheet
	var var_names: Array[String] = editor._get_available_variable_names()
	all_passed = _check("variable names sorted count", var_names.size(), 2) and all_passed
	all_passed = _check("variable names first sorted", var_names[0], "health") and all_passed
	all_passed = _check("variable names second sorted", var_names[1], "speed") and all_passed

	# Variable dropdown reflects current sheet variables.
	var var_dropdown: OptionButton = editor._create_variable_dropdown("speed")
	all_passed = _check("variable dropdown item count", var_dropdown.item_count, 2) and all_passed
	all_passed = _check("variable dropdown selects existing", var_dropdown.get_item_text(var_dropdown.selected), "speed") and all_passed

	var group_default: EventGroup = EventGroup.new()
	all_passed = _check("group default expanded", editor._is_group_collapsed(group_default), false) and all_passed

	var group_collapsed: EventGroup = EventGroup.new()
	group_collapsed.collapsed = true
	all_passed = _check("group collapsed flag", editor._is_group_collapsed(group_collapsed), true) and all_passed

	var group_legacy: EventGroup = EventGroup.new()
	group_legacy.collapsed = false
	group_legacy.expanded = false
	all_passed = _check("group legacy expanded=false", editor._is_group_collapsed(group_legacy), true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] event_sheet_editor_test: %s" % label)
		return true
	print("[FAIL] event_sheet_editor_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
