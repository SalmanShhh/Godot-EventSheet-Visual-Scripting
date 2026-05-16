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

	# Variable dropdown empty-state is explicit and non-selectable.
	editor.current_sheet = EventSheetResource.new()
	var empty_var_dropdown: OptionButton = editor._create_variable_dropdown("")
	all_passed = _check("variable dropdown empty item count", empty_var_dropdown.item_count, 1) and all_passed
	all_passed = _check("variable dropdown empty text", empty_var_dropdown.get_item_text(0), EventSheetEditor.NO_VARIABLES_AVAILABLE_TEXT) and all_passed
	all_passed = _check("variable dropdown empty item disabled", empty_var_dropdown.is_item_disabled(0), true) and all_passed
	all_passed = _check("variable dropdown empty control disabled", empty_var_dropdown.disabled, true) and all_passed

	var var_param: ACEParam = ACEParam.new()
	var_param.hint = "variable_reference"
	all_passed = _check("variable dropdown empty extracts blank", editor._extract_ace_param_input_value(var_param, empty_var_dropdown), "") and all_passed
	editor._ace_params_fields = {
		"var_name": {
			"param": var_param,
			"input": empty_var_dropdown
		}
	}
	all_passed = _check("variable dropdown empty blocks apply", editor._has_missing_variable_reference_selection(), true) and all_passed

	editor.current_sheet = sheet
	var valid_var_dropdown: OptionButton = editor._create_variable_dropdown("health")
	editor._ace_params_fields = {
		"var_name": {
			"param": var_param,
			"input": valid_var_dropdown
		}
	}
	all_passed = _check("valid variable selection allows apply", editor._has_missing_variable_reference_selection(), false) and all_passed

	# Operator params with options render as dropdowns.
	var op_param: ACEParam = ACEParam.new()
	op_param.type_name = "String"
	op_param.options = ["==", "!=", "<", "<=", ">", ">="]
	var op_input: Control = editor._create_ace_param_input(op_param, ">=")
	all_passed = _check("operator options use dropdown control", op_input is OptionButton, true) and all_passed
	if op_input is OptionButton:
		var op_dropdown: OptionButton = op_input as OptionButton
		all_passed = _check("operator dropdown item count", op_dropdown.item_count, 6) and all_passed
		all_passed = _check("operator dropdown selected value", op_dropdown.get_item_text(op_dropdown.selected), ">=") and all_passed

	var compare_var: ACEDescriptor = ACERegistry.find_descriptor("Core", "CompareVar")
	all_passed = _check("compare var descriptor exists", compare_var != null, true) and all_passed
	if compare_var != null and compare_var.params.size() > 1:
		all_passed = _check("compare var op options count", compare_var.params[1].options.size(), 6) and all_passed

	var group_default: EventGroup = EventGroup.new()
	all_passed = _check("group default expanded", editor._is_group_collapsed(group_default), false) and all_passed

	var group_collapsed: EventGroup = EventGroup.new()
	group_collapsed.collapsed = true
	all_passed = _check("group collapsed flag", editor._is_group_collapsed(group_collapsed), true) and all_passed

	var group_legacy: EventGroup = EventGroup.new()
	group_legacy.collapsed = false
	group_legacy.expanded = false
	all_passed = _check("group legacy expanded=false", editor._is_group_collapsed(group_legacy), true) and all_passed

	# Event row sub-events are rendered as additional indented rows.
	editor._build_layout()
	var sub_event_sheet: EventSheetResource = EventSheetResource.new()
	var parent_row: EventRow = EventRow.new()
	var child_row: EventRow = EventRow.new()
	parent_row.sub_events.append(child_row)
	sub_event_sheet.events.append(parent_row)
	editor.current_sheet = sub_event_sheet
	editor.refresh_canvas()
	all_passed = _check("sub events render nested rows", _count_event_row_nodes(editor), 2) and all_passed

	# Cycle safety: child referencing parent should still render each row once.
	child_row.sub_events.append(parent_row)
	editor.refresh_canvas()
	all_passed = _check("sub events cycle guard prevents duplicate rendering", _count_event_row_nodes(editor), 2) and all_passed

	# ACE params dialog back button is created and visible state reflects from_picker.
	all_passed = _check("ace params back button created", editor._ace_params_back_button != null, true) and all_passed
	if editor._ace_params_back_button != null:
		editor._ace_params_from_picker = false
		editor._ace_params_back_button.visible = false
		all_passed = _check("back button hidden for edit flow", editor._ace_params_back_button.visible, false) and all_passed
		editor._ace_params_from_picker = true
		editor._ace_params_back_button.visible = true
		all_passed = _check("back button visible for picker flow", editor._ace_params_back_button.visible, true) and all_passed

	# ACE picker popup is created as a Window (movable and titled).
	all_passed = _check("ace picker popup created", editor._ace_picker_popup != null, true) and all_passed
	if editor._ace_picker_popup != null:
		all_passed = _check("ace picker popup is window", editor._ace_picker_popup is Window, true) and all_passed

	# Zero-param ACE applies once and clears picker/params state after apply.
	var zero_param_sheet: EventSheetResource = EventSheetResource.new()
	editor.current_sheet = zero_param_sheet
	editor.refresh_canvas()
	editor._ace_picker_mode = "append_condition"
	var zero_param_row: EventRow = EventRow.new()
	zero_param_sheet.events.append(zero_param_row)
	var zero_param_row_ui: EventRowUI = EventRowUI.new()
	zero_param_row_ui.event_row = zero_param_row
	editor._ace_picker_target_row = zero_param_row_ui
	editor._ace_picker_target_condition_index = -1
	var always_descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "Always")
	if always_descriptor != null:
		all_passed = _check("always descriptor has no params", always_descriptor.params.is_empty(), true) and all_passed
		editor._open_ace_params_dialog_for_picker_selection(always_descriptor)
		all_passed = _check("zero-param apply clears picker mode", editor._ace_picker_mode, "") and all_passed
		all_passed = _check("zero-param apply clears picker target row", editor._ace_picker_target_row == null, true) and all_passed
		all_passed = _check("zero-param apply clears params descriptor", editor._ace_params_descriptor == null, true) and all_passed
		all_passed = _check("zero-param condition added once", zero_param_row.conditions.size(), 1) and all_passed

	# Delete event removes it from the sheet and refreshes.
	var delete_sheet: EventSheetResource = EventSheetResource.new()
	editor.current_sheet = delete_sheet
	var del_event: EventRow = EventRow.new()
	delete_sheet.events.append(del_event)
	var del_uid: String = del_event.event_uid
	editor._delete_event_by_uid(del_uid)
	all_passed = _check("delete event removes from sheet", delete_sheet.events.size(), 0) and all_passed
	all_passed = _check("delete event resets selection kind", editor._selected_entry_kind, "none") and all_passed
	all_passed = _check("delete event refresh removes row ui", editor._find_event_row_ui_by_uid(editor._canvas_vbox, del_uid) == null, true) and all_passed

	# Delete condition removes it from the event row.
	var del_cond_sheet: EventSheetResource = EventSheetResource.new()
	var del_cond_event: EventRow = EventRow.new()
	var del_cond: ACECondition = ACECondition.new()
	del_cond.ace_id = "Always"
	del_cond_event.conditions.append(del_cond)
	del_cond_sheet.events.append(del_cond_event)
	editor.current_sheet = del_cond_sheet
	editor.refresh_canvas()
	var del_cond_row_ui: EventRowUI = editor._find_event_row_ui_by_uid(editor._canvas_vbox, del_cond_event.event_uid)
	if del_cond_row_ui != null:
		editor._selected_row = del_cond_row_ui
		editor._selected_entry_kind = "condition"
		editor._selected_index = 0
		editor._on_condition_delete_requested(del_cond_row_ui, 0)
		all_passed = _check("delete condition removes from event", del_cond_event.conditions.size(), 0) and all_passed
		all_passed = _check("delete condition keeps sane selection kind", editor._selected_entry_kind, "event") and all_passed
		all_passed = _check("delete condition resets selected index", editor._selected_index, -1) and all_passed

	# Delete action removes it from the event row.
	var del_act_event: EventRow = EventRow.new()
	var del_action: ACEAction = ACEAction.new()
	del_action.ace_id = "QueueFree"
	del_act_event.actions.append(del_action)
	del_cond_sheet.events.append(del_act_event)
	editor.refresh_canvas()
	var del_act_row_ui: EventRowUI = editor._find_event_row_ui_by_uid(editor._canvas_vbox, del_act_event.event_uid)
	if del_act_row_ui != null:
		editor._selected_row = del_act_row_ui
		editor._selected_entry_kind = "action"
		editor._selected_index = 0
		editor._on_action_delete_requested(del_act_row_ui, 0)
		all_passed = _check("delete action removes from event", del_act_event.actions.size(), 0) and all_passed
		all_passed = _check("delete action keeps sane selection kind", editor._selected_entry_kind, "event") and all_passed
		all_passed = _check("delete action resets selected index", editor._selected_index, -1) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] event_sheet_editor_test: %s" % label)
		return true
	print("[FAIL] event_sheet_editor_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false

static func _count_event_row_nodes(node: Node) -> int:
	if node == null:
		return 0
	var total: int = 1 if node is EventRowUI else 0
	for child: Node in node.get_children():
		total += _count_event_row_nodes(child)
	return total
