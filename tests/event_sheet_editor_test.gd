# EventForge — EventSheetEditor helper behavior tests
@tool
extends RefCounted
class_name EventSheetEditorTest

## Runs EventSheetEditor helper tests.
static func run() -> bool:
	var all_passed: bool = true
	var editor: EventSheetEditor = EventSheetEditor.new()
	var lane_row: EventRowUI = EventRowUI.new()
	lane_row.event_row = EventRow.new()
	lane_row.refresh()
	all_passed = _check("event row no IF label", _contains_label_text(lane_row, "IF"), false) and all_passed
	all_passed = _check("event row no THEN label", _contains_label_text(lane_row, "THEN"), false) and all_passed
	all_passed = _check("event row no lane marker dots", _contains_label_text(lane_row, "●"), false) and all_passed
	all_passed = _check("event row no Conditions label", _contains_label_text(lane_row, "Conditions"), false) and all_passed
	all_passed = _check("event row no Actions label", _contains_label_text(lane_row, "Actions"), false) and all_passed
	all_passed = _check("toolbar meta no sheet", SheetToolbar.format_document_meta(null), "No sheet loaded") and all_passed
	all_passed = _check("toolbar selection none", SheetToolbar.format_selection_meta("none"), "No selection") and all_passed
	all_passed = _check("toolbar selection event", SheetToolbar.format_selection_meta("event"), "Selection: Event") and all_passed
	var toolbar_ui: SheetToolbar = SheetToolbar.new()
	all_passed = _check("toolbar contains shortcuts hint label", _contains_label_text(toolbar_ui, SheetToolbar.shortcut_hint_text()), true) and all_passed
	all_passed = _check("toolbar shortcuts hint hidden without sheet", toolbar_ui._shortcuts_hint_label.visible, false) and all_passed
	toolbar_ui.set_sheet_loaded(true)
	all_passed = _check("toolbar shortcuts hint visible with loaded sheet", toolbar_ui._shortcuts_hint_label.visible, true) and all_passed
	all_passed = _check("toolbar add event tooltip includes shortcut", toolbar_ui._add_event_btn.tooltip_text.find("Ctrl+E") != -1, true) and all_passed
	all_passed = _check("toolbar add variable tooltip includes shortcut", toolbar_ui._add_var_btn.tooltip_text.find("Ctrl+Shift+V") != -1, true) and all_passed
	var toolbar_sheet: EventSheetResource = EventSheetResource.new()
	toolbar_sheet.variables["health"] = {"type": "int", "default": 100}
	toolbar_sheet.events.append(EventRow.new())
	all_passed = _check("toolbar meta loaded sheet", SheetToolbar.format_document_meta(toolbar_sheet), "1 globals · 1 root rows") and all_passed
	toolbar_sheet = null
	toolbar_ui.free()

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

	var expr_param: ACEParam = ACEParam.new()
	expr_param.type_name = "String"
	expr_param.hint = "expression"
	var expr_input: Control = editor._create_ace_param_input(expr_param, "value")
	all_passed = _check("expression param uses line edit input", expr_input is LineEdit, true) and all_passed
	all_passed = _check("expression hint enables picker button", editor._param_supports_expression_picker(expr_param, expr_input), true) and all_passed
	var get_var_expression_desc: ACEDescriptor = ACERegistry.find_descriptor("Core", "GetVar")
	all_passed = _check("get var expression descriptor exists", get_var_expression_desc != null, true) and all_passed
	if get_var_expression_desc != null:
		all_passed = _check("expression snippet applies defaults", editor._build_expression_snippet(get_var_expression_desc, {"var_name": "health"}), "health") and all_passed
		all_passed = _check("expression snippet keeps unresolved token when value missing", editor._build_expression_snippet(get_var_expression_desc, {}), "{var_name}") and all_passed
	all_passed = _check("expression separator omitted after open paren", editor._should_insert_expression_separator("(", "delta"), false) and all_passed
	all_passed = _check("expression separator used for bare identifiers", editor._should_insert_expression_separator("health", "delta"), true) and all_passed

	var compare_var: ACEDescriptor = ACERegistry.find_descriptor("Core", "CompareVar")
	all_passed = _check("compare var descriptor exists", compare_var != null, true) and all_passed
	# CompareVar params: [0]=var_name, [1]=op, [2]=value.
	if compare_var != null and compare_var.params.size() > 2:
		all_passed = _check("compare var op options count", compare_var.params[1].options.size(), 6) and all_passed
		all_passed = _check("compare var value marked expression", compare_var.params[2].hint, "expression") and all_passed

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
	all_passed = _check("document header rendered", _count_nodes_named(editor, "SheetDocumentHeader") >= 1, true) and all_passed
	all_passed = _check("globals section shell rendered", _count_nodes_named(editor, "SheetSectionGlobals") >= 1, true) and all_passed
	all_passed = _check("events section shell rendered", _count_nodes_named(editor, "SheetSectionEvents") >= 1, true) and all_passed
	all_passed = _check("sub events render nested rows", _count_event_row_nodes(editor), 2) and all_passed
	all_passed = _check("sheet gutter wrappers rendered", _count_nodes_named(editor, "SheetGutter") >= 2, true) and all_passed

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
		all_passed = _check("ace picker popup starts hidden", editor._ace_picker_popup.visible, false) and all_passed

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

	# Row-level insertion affordances insert relative to nested and group rows.
	var nested_insert_sheet: EventSheetResource = EventSheetResource.new()
	var parent_insert_event: EventRow = EventRow.new()
	var child_insert_event: EventRow = EventRow.new()
	parent_insert_event.sub_events.append(child_insert_event)
	nested_insert_sheet.events.append(parent_insert_event)
	editor.current_sheet = nested_insert_sheet
	editor.refresh_canvas()
	var child_insert_row_ui: EventRowUI = editor._find_event_row_ui_by_uid(editor._canvas_vbox, child_insert_event.event_uid)
	if child_insert_row_ui != null:
		editor._on_event_insert_above_requested(child_insert_row_ui)
		all_passed = _check("insert above nested row adds sibling in parent sub-events", parent_insert_event.sub_events.size(), 2) and all_passed
		var inserted_nested: Variant = parent_insert_event.sub_events[0]
		all_passed = _check("insert above nested row places new row before target", inserted_nested is EventRow and (inserted_nested as EventRow).event_uid != child_insert_event.event_uid, true) and all_passed

	var group_insert_sheet: EventSheetResource = EventSheetResource.new()
	var group_insert: EventGroup = EventGroup.new()
	group_insert.events.append(EventRow.new())
	group_insert_sheet.events.append(group_insert)
	editor.current_sheet = group_insert_sheet
	editor.refresh_canvas()
	var group_insert_row_ui: GroupRowUI = editor._find_group_row_ui_by_uid(editor._canvas_vbox, group_insert.group_uid)
	if group_insert_row_ui != null:
		editor._on_group_insert_below_requested(group_insert_row_ui)
		all_passed = _check("insert below group row adds sibling event in root list", group_insert_sheet.events.size(), 2) and all_passed
		all_passed = _check("insert below group row inserts event resource", group_insert_sheet.events[1] is EventRow, true) and all_passed

	# Workflow: shortcut action dispatch opens add-condition picker for selected event.
	var shortcut_sheet: EventSheetResource = EventSheetResource.new()
	var shortcut_event: EventRow = EventRow.new()
	shortcut_sheet.events.append(shortcut_event)
	editor.current_sheet = shortcut_sheet
	editor.refresh_canvas()
	var shortcut_row_ui: EventRowUI = editor._find_event_row_ui_by_uid(editor._canvas_vbox, shortcut_event.event_uid)
	if shortcut_row_ui != null:
		editor._on_event_selected(shortcut_row_ui)
		all_passed = _check("shortcut add condition handled", editor._handle_workflow_shortcut("add_condition"), true) and all_passed
		all_passed = _check("shortcut add condition opens picker mode", editor._ace_picker_mode, "append_condition") and all_passed
		all_passed = _check("shortcut add condition targets selected row", editor._ace_picker_target_row == shortcut_row_ui, true) and all_passed
		if editor._ace_picker_popup != null:
			editor._ace_picker_popup.hide()
		var add_event_key: InputEventKey = InputEventKey.new()
		add_event_key.pressed = true
		add_event_key.ctrl_pressed = true
		add_event_key.keycode = KEY_E
		editor._unhandled_key_input(add_event_key)
		all_passed = _check("keyboard Ctrl+E opens add event picker", editor._ace_picker_mode, "new_event") and all_passed
		if editor._ace_picker_popup != null:
			editor._ace_picker_popup.hide()

	# Workflow: shortcut delete dispatch removes selected action.
	var shortcut_del_sheet: EventSheetResource = EventSheetResource.new()
	var shortcut_del_event: EventRow = EventRow.new()
	var shortcut_del_action: ACEAction = ACEAction.new()
	shortcut_del_action.ace_id = "QueueFree"
	shortcut_del_event.actions.append(shortcut_del_action)
	shortcut_del_sheet.events.append(shortcut_del_event)
	editor.current_sheet = shortcut_del_sheet
	editor.refresh_canvas()
	var shortcut_del_row_ui: EventRowUI = editor._find_event_row_ui_by_uid(editor._canvas_vbox, shortcut_del_event.event_uid)
	if shortcut_del_row_ui != null:
		editor._selected_row = shortcut_del_row_ui
		editor._selected_entry_kind = "action"
		editor._selected_index = 0
		all_passed = _check("shortcut delete selected action handled", editor._handle_workflow_shortcut("delete_selection"), true) and all_passed
		all_passed = _check("shortcut delete selected action removes action", shortcut_del_event.actions.size(), 0) and all_passed
		shortcut_del_event.actions.append(shortcut_del_action)
		editor._selected_row = shortcut_del_row_ui
		editor._selected_entry_kind = "action"
		editor._selected_index = 0
		var delete_key: InputEventKey = InputEventKey.new()
		delete_key.pressed = true
		delete_key.keycode = KEY_DELETE
		editor._unhandled_key_input(delete_key)
		all_passed = _check("keyboard Delete removes selected action", shortcut_del_event.actions.size(), 0) and all_passed

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

	# Deleting an earlier condition keeps selected condition index in sync.
	var shift_cond_event: EventRow = EventRow.new()
	var shift_cond_a: ACECondition = ACECondition.new()
	shift_cond_a.ace_id = "Always"
	var shift_cond_b: ACECondition = ACECondition.new()
	shift_cond_b.ace_id = "Always"
	shift_cond_event.conditions.append(shift_cond_a)
	shift_cond_event.conditions.append(shift_cond_b)
	var shift_cond_sheet: EventSheetResource = EventSheetResource.new()
	shift_cond_sheet.events.append(shift_cond_event)
	editor.current_sheet = shift_cond_sheet
	editor.refresh_canvas()
	var shift_cond_row_ui: EventRowUI = editor._find_event_row_ui_by_uid(editor._canvas_vbox, shift_cond_event.event_uid)
	if shift_cond_row_ui != null:
		editor._selected_row = shift_cond_row_ui
		editor._selected_entry_kind = "condition"
		editor._selected_index = 1
		editor._on_condition_delete_requested(shift_cond_row_ui, 0)
		all_passed = _check("delete earlier condition keeps condition selection kind", editor._selected_entry_kind, "condition") and all_passed
		all_passed = _check("delete earlier condition shifts selected index", editor._selected_index, 0) and all_passed

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

	# Deleting an earlier action keeps selected action index in sync.
	var shift_act_event: EventRow = EventRow.new()
	var shift_act_a: ACEAction = ACEAction.new()
	shift_act_a.ace_id = "QueueFree"
	var shift_act_b: ACEAction = ACEAction.new()
	shift_act_b.ace_id = "QueueFree"
	shift_act_event.actions.append(shift_act_a)
	shift_act_event.actions.append(shift_act_b)
	var shift_act_sheet: EventSheetResource = EventSheetResource.new()
	shift_act_sheet.events.append(shift_act_event)
	editor.current_sheet = shift_act_sheet
	editor.refresh_canvas()
	var shift_act_row_ui: EventRowUI = editor._find_event_row_ui_by_uid(editor._canvas_vbox, shift_act_event.event_uid)
	if shift_act_row_ui != null:
		editor._selected_row = shift_act_row_ui
		editor._selected_entry_kind = "action"
		editor._selected_index = 1
		editor._on_action_delete_requested(shift_act_row_ui, 0)
		all_passed = _check("delete earlier action keeps action selection kind", editor._selected_entry_kind, "action") and all_passed
		all_passed = _check("delete earlier action shifts selected index", editor._selected_index, 0) and all_passed

	# Deleting an action in another row keeps selected variable inspector/context intact.
	var cross_row_sheet: EventSheetResource = EventSheetResource.new()
	cross_row_sheet.variables["score"] = {"type": "int", "default": 0}
	var cross_row_event: EventRow = EventRow.new()
	var cross_row_action: ACEAction = ACEAction.new()
	cross_row_action.ace_id = "QueueFree"
	cross_row_event.actions.append(cross_row_action)
	cross_row_sheet.events.append(cross_row_event)
	editor.current_sheet = cross_row_sheet
	editor.refresh_canvas()
	var cross_row_var_ui: VariableRowUI = editor._find_variable_row_ui_by_name(editor._canvas_vbox, "score")
	var cross_row_event_ui: EventRowUI = editor._find_event_row_ui_by_uid(editor._canvas_vbox, cross_row_event.event_uid)
	if cross_row_var_ui != null and cross_row_event_ui != null:
		editor._suppress_variable_popup_on_select = true
		editor._on_variable_selected(cross_row_var_ui)
		editor._suppress_variable_popup_on_select = false
		editor._on_action_delete_requested(cross_row_event_ui, 0)
		all_passed = _check("cross-row delete keeps variable selection kind", editor._selected_entry_kind, "variable") and all_passed
		all_passed = _check("cross-row delete keeps variable inspector heading", _contains_label_text(editor._inspector_vbox, "Variable"), true) and all_passed
		all_passed = _check("cross-row delete does not switch inspector to event", _contains_label_text(editor._inspector_vbox, "Event"), false) and all_passed

	# Phase 4: inspector content wrapped in card shells.
	var inspector_sheet: EventSheetResource = EventSheetResource.new()
	var inspector_event: EventRow = EventRow.new()
	inspector_sheet.events.append(inspector_event)
	editor.current_sheet = inspector_sheet
	editor.refresh_canvas()
	var inspector_row_ui: EventRowUI = editor._find_event_row_ui_by_uid(editor._canvas_vbox, inspector_event.event_uid)
	if inspector_row_ui != null:
		editor._rebuild_inspector_event(inspector_row_ui)
		all_passed = _check("inspector event uses card shell", _count_panel_containers(editor._inspector_vbox) >= 1, true) and all_passed

	var inspector_var_sheet: EventSheetResource = EventSheetResource.new()
	inspector_var_sheet.variables["score"] = {"type": "int", "default": 0}
	editor.current_sheet = inspector_var_sheet
	editor.refresh_canvas()
	var inspector_var_ui: VariableRowUI = editor._find_variable_row_ui_by_name(editor._canvas_vbox, "score")
	if inspector_var_ui != null:
		editor._rebuild_inspector_variable(inspector_var_ui)
		all_passed = _check("inspector variable uses card shell", _count_panel_containers(editor._inspector_vbox) >= 1, true) and all_passed

	# Phase 4: group row shows event count.
	var count_group: EventGroup = EventGroup.new()
	count_group.events.append(EventRow.new())
	count_group.events.append(EventRow.new())
	var count_group_row: GroupRowUI = GroupRowUI.new()
	count_group_row.event_group = count_group
	count_group_row.refresh()
	all_passed = _check("group row shows event count", _contains_label_text(count_group_row, "(2)"), true) and all_passed
	all_passed = _check("group row lane divider present", _has_color_rect_min_width(count_group_row, 2), true) and all_passed
	all_passed = _check("group row insertion button above visible", _find_button_with_tooltip(count_group_row, "Insert event above this group") != null, true) and all_passed
	all_passed = _check("group row insertion button below visible", _find_button_with_tooltip(count_group_row, "Insert event below this group") != null, true) and all_passed

	var empty_group: EventGroup = EventGroup.new()
	var empty_group_row: GroupRowUI = GroupRowUI.new()
	empty_group_row.event_group = empty_group
	empty_group_row.refresh()
	all_passed = _check("group row count hidden when empty", not _contains_label_text(empty_group_row, "(0)"), true) and all_passed
	all_passed = _check("group row count label empty string when no events", empty_group_row._count_label.text, "") and all_passed

	# Phase 4: toolbar sheet name formatting.
	var untitled_sheet: EventSheetResource = EventSheetResource.new()
	all_passed = _check("toolbar sheet name untitled", SheetToolbar._format_sheet_name(untitled_sheet), "Untitled Sheet") and all_passed
	all_passed = _check("toolbar sheet name null", SheetToolbar._format_sheet_name(null), "") and all_passed
	all_passed = _check("editor doc title null", EventSheetEditor._format_document_title(null), "No Sheet Loaded") and all_passed
	all_passed = _check("editor doc title unsaved", EventSheetEditor._format_document_title(untitled_sheet), "Untitled Sheet") and all_passed
	all_passed = _check("editor doc path null", EventSheetEditor._format_document_path_hint(null), "Open or create a sheet to begin") and all_passed
	all_passed = _check("editor doc path unsaved", EventSheetEditor._format_document_path_hint(untitled_sheet), "Unsaved (in-memory)") and all_passed
	untitled_sheet.take_over_path("res://demo/event_sheet_editor_test_sheet.tres")
	all_passed = _check("editor doc title saved", EventSheetEditor._format_document_title(untitled_sheet), "event_sheet_editor_test_sheet") and all_passed
	all_passed = _check("editor doc path saved", EventSheetEditor._format_document_path_hint(untitled_sheet), "res://demo/event_sheet_editor_test_sheet.tres") and all_passed

	# Phase 4: section empty states use PanelContainer cards.
	var empty_section_sheet: EventSheetResource = EventSheetResource.new()
	editor.current_sheet = empty_section_sheet
	editor.refresh_canvas()
	var globals_section: Node = _find_node_named(editor, "SheetSectionGlobals")
	all_passed = _check("globals empty state is card", globals_section != null and _count_panel_containers(globals_section) >= 1, true) and all_passed
	var events_section: Node = _find_node_named(editor, "SheetSectionEvents")
	all_passed = _check("events empty state is card", events_section != null and _count_panel_containers(events_section) >= 1, true) and all_passed
	all_passed = _check("events section is unframed host", events_section is PanelContainer, false) and all_passed
	all_passed = _check("events section has anchored add event button", _find_button_with_text(events_section, "Add Event") != null, true) and all_passed
	all_passed = _check("events section no old + Event header action", _find_button_with_text(events_section, "+ Event") == null, true) and all_passed

	# Phase 5: section headers use ColorRect accent rail, not a "●" bullet label.
	all_passed = _check("globals section no bullet label", not _contains_label_text(globals_section, "●"), true) and all_passed
	all_passed = _check("events section no bullet label", not _contains_label_text(events_section, "●"), true) and all_passed
	all_passed = _check("globals section has color rect rail", globals_section != null and _count_color_rects(globals_section) >= 1, true) and all_passed
	all_passed = _check("events section has color rect rail", events_section != null and _count_color_rects(events_section) >= 1, true) and all_passed
	all_passed = _check("canvas has document strip", _find_node_named(editor, "SheetCanvasDocumentStrip") != null, true) and all_passed
	all_passed = _check("canvas has resource tab shell", _find_node_named(editor, "SheetCanvasResourceTab") != null, true) and all_passed

	# Phase 5: inspector card has a HSeparator after the heading.
	var sep_sheet: EventSheetResource = EventSheetResource.new()
	var sep_event: EventRow = EventRow.new()
	sep_sheet.events.append(sep_event)
	editor.current_sheet = sep_sheet
	editor.refresh_canvas()
	var sep_row_ui: EventRowUI = editor._find_event_row_ui_by_uid(editor._canvas_vbox, sep_event.event_uid)
	if sep_row_ui != null:
		editor._rebuild_inspector_event(sep_row_ui)
		all_passed = _check("inspector event card has separator after heading", _count_separators(editor._inspector_vbox) >= 1, true) and all_passed

	# Phase 6: empty inspector state also has a HSeparator after the heading.
	editor._show_empty_inspector()
	all_passed = _check("empty inspector has separator after heading", _count_separators(editor._inspector_vbox) >= 1, true) and all_passed

	# Phase 6: inspector card has a left border accent (border_width_left = 3).
	var card_sheet: EventSheetResource = EventSheetResource.new()
	var card_event: EventRow = EventRow.new()
	card_sheet.events.append(card_event)
	editor.current_sheet = card_sheet
	editor.refresh_canvas()
	var card_row_ui: EventRowUI = editor._find_event_row_ui_by_uid(editor._canvas_vbox, card_event.event_uid)
	if card_row_ui != null:
		editor._rebuild_inspector_event(card_row_ui)
		var card_node: PanelContainer = _find_first_panel_container(editor._inspector_vbox)
		var has_left_accent: bool = false
		if card_node != null:
			var sb: StyleBox = card_node.get_theme_stylebox("panel")
			if sb is StyleBoxFlat:
				has_left_accent = (sb as StyleBoxFlat).border_width_left == 3
		all_passed = _check("inspector card has left border accent", has_left_accent, true) and all_passed

	# Stabilization: variable_delete_requested signal exists on VariableRowUI.
	var signal_var_row: VariableRowUI = VariableRowUI.new()
	all_passed = _check("variable row has delete signal", signal_var_row.has_signal("variable_delete_requested"), true) and all_passed

	# Stabilization: group_delete_requested signal exists on GroupRowUI.
	var signal_group_row: GroupRowUI = GroupRowUI.new()
	all_passed = _check("group row has delete signal", signal_group_row.has_signal("group_delete_requested"), true) and all_passed

	# Stabilization: deleting the selected variable resets selection kind and shows empty inspector.
	var del_var_sheet: EventSheetResource = EventSheetResource.new()
	del_var_sheet.variables["lives"] = {"type": "int", "default": 3}
	editor.current_sheet = del_var_sheet
	editor.refresh_canvas()
	var del_var_row_ui: VariableRowUI = editor._find_variable_row_ui_by_name(editor._canvas_vbox, "lives")
	if del_var_row_ui != null:
		editor._suppress_variable_popup_on_select = true
		editor._on_variable_selected(del_var_row_ui)
		editor._suppress_variable_popup_on_select = false
		editor._on_variable_delete_requested(del_var_row_ui)
		all_passed = _check("delete selected variable resets selection kind", editor._selected_entry_kind, "none") and all_passed
		all_passed = _check("delete selected variable removes from sheet", del_var_sheet.variables.has("lives"), false) and all_passed
		all_passed = _check("delete selected variable shows empty inspector", not _contains_label_text(editor._inspector_vbox, "Variable"), true) and all_passed

	# Stabilization: deleting a non-selected variable keeps selection kind intact.
	var del_var2_sheet: EventSheetResource = EventSheetResource.new()
	del_var2_sheet.variables["hp"] = {"type": "int", "default": 100}
	del_var2_sheet.variables["mp"] = {"type": "int", "default": 50}
	var del_var2_event: EventRow = EventRow.new()
	del_var2_sheet.events.append(del_var2_event)
	editor.current_sheet = del_var2_sheet
	editor.refresh_canvas()
	var del_var2_event_ui: EventRowUI = editor._find_event_row_ui_by_uid(editor._canvas_vbox, del_var2_event.event_uid)
	var del_var2_mp_ui: VariableRowUI = editor._find_variable_row_ui_by_name(editor._canvas_vbox, "mp")
	if del_var2_event_ui != null and del_var2_mp_ui != null:
		editor._on_event_selected(del_var2_event_ui)
		editor._on_variable_delete_requested(del_var2_mp_ui)
		all_passed = _check("delete non-selected variable keeps event selection kind", editor._selected_entry_kind, "event") and all_passed
		all_passed = _check("delete non-selected variable removes from sheet", del_var2_sheet.variables.has("mp"), false) and all_passed

	# Stabilization: deleting the selected group resets selection kind and shows empty inspector.
	var del_grp_sheet: EventSheetResource = EventSheetResource.new()
	var del_grp_group: EventGroup = EventGroup.new()
	del_grp_sheet.events.append(del_grp_group)
	editor.current_sheet = del_grp_sheet
	editor.refresh_canvas()
	var del_grp_uid: String = del_grp_group.group_uid
	var del_grp_row_ui: GroupRowUI = editor._find_group_row_ui_by_uid(editor._canvas_vbox, del_grp_uid)
	if del_grp_row_ui != null:
		editor._on_group_selected(del_grp_row_ui)
		editor._on_group_delete_requested(del_grp_row_ui)
		all_passed = _check("delete selected group resets selection kind", editor._selected_entry_kind, "none") and all_passed
		all_passed = _check("delete selected group removes from sheet", del_grp_sheet.events.size(), 0) and all_passed

	# Stabilization: cross-row condition deletion keeps selected variable inspector intact.
	var cross_cond_sheet: EventSheetResource = EventSheetResource.new()
	cross_cond_sheet.variables["coins"] = {"type": "int", "default": 0}
	var cross_cond_event: EventRow = EventRow.new()
	var cross_cond: ACECondition = ACECondition.new()
	cross_cond.ace_id = "Always"
	cross_cond_event.conditions.append(cross_cond)
	cross_cond_sheet.events.append(cross_cond_event)
	editor.current_sheet = cross_cond_sheet
	editor.refresh_canvas()
	var cross_cond_var_ui: VariableRowUI = editor._find_variable_row_ui_by_name(editor._canvas_vbox, "coins")
	var cross_cond_event_ui: EventRowUI = editor._find_event_row_ui_by_uid(editor._canvas_vbox, cross_cond_event.event_uid)
	if cross_cond_var_ui != null and cross_cond_event_ui != null:
		editor._suppress_variable_popup_on_select = true
		editor._on_variable_selected(cross_cond_var_ui)
		editor._suppress_variable_popup_on_select = false
		editor._on_condition_delete_requested(cross_cond_event_ui, 0)
		all_passed = _check("cross-row cond delete keeps variable selection kind", editor._selected_entry_kind, "variable") and all_passed
		all_passed = _check("cross-row cond delete keeps variable inspector heading", _contains_label_text(editor._inspector_vbox, "Variable"), true) and all_passed
		all_passed = _check("cross-row cond delete does not switch inspector to event", _contains_label_text(editor._inspector_vbox, "Event"), false) and all_passed

	# Stabilization: condition inversion on non-selected row does not corrupt selection/inspector.
	var invert_sheet: EventSheetResource = EventSheetResource.new()
	invert_sheet.variables["power"] = {"type": "int", "default": 5}
	var invert_event: EventRow = EventRow.new()
	var invert_cond: ACECondition = ACECondition.new()
	invert_cond.ace_id = "Always"
	invert_event.conditions.append(invert_cond)
	invert_sheet.events.append(invert_event)
	editor.current_sheet = invert_sheet
	editor.refresh_canvas()
	var invert_var_ui: VariableRowUI = editor._find_variable_row_ui_by_name(editor._canvas_vbox, "power")
	var invert_event_ui: EventRowUI = editor._find_event_row_ui_by_uid(editor._canvas_vbox, invert_event.event_uid)
	if invert_var_ui != null and invert_event_ui != null:
		editor._suppress_variable_popup_on_select = true
		editor._on_variable_selected(invert_var_ui)
		editor._suppress_variable_popup_on_select = false
		editor._on_condition_invert_requested(invert_event_ui, 0)
		all_passed = _check("invert condition keeps variable selection kind", editor._selected_entry_kind, "variable") and all_passed
		all_passed = _check("invert condition keeps variable inspector heading", _contains_label_text(editor._inspector_vbox, "Variable"), true) and all_passed
		all_passed = _check("invert condition does not switch inspector to event", _contains_label_text(editor._inspector_vbox, "Event"), false) and all_passed

	# ACE picker grouping: _get_picker_group prioritises node_type over category.
	var node_type_ace: ACEDescriptor = ACEDescriptor.new()
	node_type_ace.provider_id = "Core"
	node_type_ace.ace_type = ACEDescriptor.ACEType.CONDITION
	node_type_ace.category = "General Conditions"
	node_type_ace.node_type = "CharacterBody2D"
	all_passed = _check("picker group uses node_type when set", editor._get_picker_group(node_type_ace), "CharacterBody2D") and all_passed

	var category_ace: ACEDescriptor = ACEDescriptor.new()
	category_ace.provider_id = "Core"
	category_ace.ace_type = ACEDescriptor.ACEType.CONDITION
	category_ace.category = "Variables"
	category_ace.node_type = ""
	all_passed = _check("picker group falls back to category", editor._get_picker_group(category_ace), "Variables") and all_passed

	var trigger_ace: ACEDescriptor = ACEDescriptor.new()
	trigger_ace.provider_id = "Core"
	trigger_ace.ace_type = ACEDescriptor.ACEType.TRIGGER
	trigger_ace.node_type = ""
	all_passed = _check("picker group triggers group when no node_type", editor._get_picker_group(trigger_ace), "Run Context / Triggers") and all_passed

	var trigger_with_node_type: ACEDescriptor = ACEDescriptor.new()
	trigger_with_node_type.provider_id = "Core"
	trigger_with_node_type.ace_type = ACEDescriptor.ACEType.TRIGGER
	trigger_with_node_type.node_type = "Area2D"
	all_passed = _check("picker group trigger with node_type uses node_type", editor._get_picker_group(trigger_with_node_type), "Area2D") and all_passed

	var runtime_ace: ACEDescriptor = ACEDescriptor.new()
	runtime_ace.provider_id = "MyPlugin"
	runtime_ace.ace_type = ACEDescriptor.ACEType.ACTION
	runtime_ace.node_type = ""
	all_passed = _check("picker group runtime provider uses provider_id", editor._get_picker_group(runtime_ace), "MyPlugin") and all_passed

	var expression_ace: ACEDescriptor = ACEDescriptor.new()
	expression_ace.provider_id = "Core"
	expression_ace.ace_type = ACEDescriptor.ACEType.EXPRESSION
	expression_ace.category = ""
	expression_ace.node_type = ""
	all_passed = _check("picker group expression default category", editor._get_picker_group(expression_ace), "General Expressions") and all_passed

	# _get_picker_group_color: node-type groups get amber; known categories get distinct colours.
	var amber: Color = EventSheetEditor.ACE_PICKER_NODE_TYPE_GROUP_COLOR
	all_passed = _check("picker color CharacterBody2D is amber", EventSheetEditor._get_picker_group_color("CharacterBody2D"), amber) and all_passed
	all_passed = _check("picker color Area2D is amber", EventSheetEditor._get_picker_group_color("Area2D"), amber) and all_passed
	all_passed = _check("picker color custom class is amber", EventSheetEditor._get_picker_group_color("RigidBody2D"), amber) and all_passed
	all_passed = _check("picker color Variables is not amber", EventSheetEditor._get_picker_group_color("Variables") != amber, true) and all_passed
	all_passed = _check("picker color Custom ACEs is not amber", EventSheetEditor._get_picker_group_color("Custom ACEs") != amber, true) and all_passed

	# IsOnFloor built-in maps to CharacterBody2D group; OnBodyEntered to Area2D.
	var is_on_floor_desc: ACEDescriptor = ACERegistry.find_descriptor("Core", "IsOnFloor")
	if is_on_floor_desc != null:
		all_passed = _check("IsOnFloor picker group", editor._get_picker_group(is_on_floor_desc), "CharacterBody2D") and all_passed

	var on_body_entered_desc: ACEDescriptor = ACERegistry.find_descriptor("Core", "OnBodyEntered")
	if on_body_entered_desc != null:
		all_passed = _check("OnBodyEntered picker group", editor._get_picker_group(on_body_entered_desc), "Area2D") and all_passed

	# Expanded built-in ACEs: new node-type tagged descriptors.
	var on_area_entered_desc: ACEDescriptor = ACERegistry.find_descriptor("Core", "OnAreaEntered")
	if on_area_entered_desc != null:
		all_passed = _check("OnAreaEntered picker group", editor._get_picker_group(on_area_entered_desc), "Area2D") and all_passed

	var move_and_slide_desc: ACEDescriptor = ACERegistry.find_descriptor("Core", "MoveAndSlide")
	if move_and_slide_desc != null:
		all_passed = _check("MoveAndSlide picker group", editor._get_picker_group(move_and_slide_desc), "CharacterBody2D") and all_passed
		all_passed = _check("MoveAndSlide is action", move_and_slide_desc.ace_type, ACEDescriptor.ACEType.ACTION) and all_passed

	var start_timer_desc: ACEDescriptor = ACERegistry.find_descriptor("Core", "StartTimer")
	if start_timer_desc != null:
		all_passed = _check("StartTimer picker group", editor._get_picker_group(start_timer_desc), "Timer") and all_passed
		all_passed = _check("StartTimer is action", start_timer_desc.ace_type, ACEDescriptor.ACEType.ACTION) and all_passed

	var is_timer_stopped_desc: ACEDescriptor = ACERegistry.find_descriptor("Core", "IsTimerStopped")
	if is_timer_stopped_desc != null:
		all_passed = _check("IsTimerStopped picker group", editor._get_picker_group(is_timer_stopped_desc), "Timer") and all_passed
		all_passed = _check("IsTimerStopped is condition", is_timer_stopped_desc.ace_type, ACEDescriptor.ACEType.CONDITION) and all_passed

	var on_timeout_desc: ACEDescriptor = ACERegistry.find_descriptor("Core", "OnTimeout")
	if on_timeout_desc != null:
		all_passed = _check("OnTimeout picker group", editor._get_picker_group(on_timeout_desc), "Timer") and all_passed

	var play_animation_desc: ACEDescriptor = ACERegistry.find_descriptor("Core", "PlayAnimation")
	if play_animation_desc != null:
		all_passed = _check("PlayAnimation picker group", editor._get_picker_group(play_animation_desc), "AnimationPlayer") and all_passed

	var set_position_desc: ACEDescriptor = ACERegistry.find_descriptor("Core", "SetPosition2D")
	if set_position_desc != null:
		all_passed = _check("SetPosition2D picker group", editor._get_picker_group(set_position_desc), "Node2D") and all_passed

	var apply_impulse_desc: ACEDescriptor = ACERegistry.find_descriptor("Core", "ApplyCentralImpulse")
	if apply_impulse_desc != null:
		all_passed = _check("ApplyCentralImpulse picker group", editor._get_picker_group(apply_impulse_desc), "RigidBody2D") and all_passed

	# _get_picker_item_color: verify type-based item colouring.
	var trigger_sample: ACEDescriptor = ACEDescriptor.new()
	trigger_sample.ace_type = ACEDescriptor.ACEType.TRIGGER
	var condition_sample: ACEDescriptor = ACEDescriptor.new()
	condition_sample.ace_type = ACEDescriptor.ACEType.CONDITION
	var action_sample: ACEDescriptor = ACEDescriptor.new()
	action_sample.ace_type = ACEDescriptor.ACEType.ACTION
	all_passed = _check("picker item color: trigger != condition", EventSheetEditor._get_picker_item_color(trigger_sample) != EventSheetEditor._get_picker_item_color(condition_sample), true) and all_passed
	all_passed = _check("picker item color: action != condition", EventSheetEditor._get_picker_item_color(action_sample) != EventSheetEditor._get_picker_item_color(condition_sample), true) and all_passed
	all_passed = _check("picker item color: trigger != action", EventSheetEditor._get_picker_item_color(trigger_sample) != EventSheetEditor._get_picker_item_color(action_sample), true) and all_passed

	# _get_ace_type_label: verify human-readable labels.
	all_passed = _check("ace type label trigger", EventSheetEditor._get_ace_type_label(ACEDescriptor.ACEType.TRIGGER), "Trigger") and all_passed
	all_passed = _check("ace type label condition", EventSheetEditor._get_ace_type_label(ACEDescriptor.ACEType.CONDITION), "Condition") and all_passed
	all_passed = _check("ace type label action", EventSheetEditor._get_ace_type_label(ACEDescriptor.ACEType.ACTION), "Action") and all_passed
	all_passed = _check("ace type label expression", EventSheetEditor._get_ace_type_label(ACEDescriptor.ACEType.EXPRESSION), "Expression") and all_passed

	# ACE picker search: _populate_ace_picker with filter_text omits non-matching items.
	# Provide a minimal Tree so _populate_ace_picker can run without the full editor layout.
	var search_tree: Tree = Tree.new()
	search_tree.hide_root = true
	editor._ace_picker_tree = search_tree
	editor._ace_picker_mode = "new_event"
	editor._populate_ace_picker(true, true, false, "floor")
	var floor_root: TreeItem = search_tree.get_root()
	var found_floor_item: bool = false
	if floor_root != null:
		var grp: TreeItem = floor_root.get_first_child()
		while grp != null:
			var child: TreeItem = grp.get_first_child()
			while child != null:
				if "floor" in child.get_text(0).to_lower():
					found_floor_item = true
				child = child.get_next()
			grp = grp.get_next()
	all_passed = _check("search filter 'floor' finds Is On Floor", found_floor_item, true) and all_passed

	# Empty search should repopulate all (more than just one group).
	editor._populate_ace_picker(true, true, true, "")
	var empty_root: TreeItem = search_tree.get_root()
	var empty_group_count: int = 0
	if empty_root != null:
		var g: TreeItem = empty_root.get_first_child()
		while g != null:
			empty_group_count += 1
			g = g.get_next()
	all_passed = _check("empty filter shows multiple groups", empty_group_count > 3, true) and all_passed

	# Expression picker: list only expressions and preserve grouped discovery.
	var expression_tree: Tree = Tree.new()
	expression_tree.hide_root = true
	editor._expression_picker_tree = expression_tree
	editor._expression_picker_description = Label.new()
	editor._populate_expression_picker("velocity")
	var expression_root: TreeItem = expression_tree.get_root()
	var found_velocity_expression: bool = false
	if expression_root != null:
		var group: TreeItem = expression_root.get_first_child()
		while group != null:
			var expression_item: TreeItem = group.get_first_child()
			while expression_item != null:
				var value: Variant = expression_item.get_metadata(0)
				if value is ACEDescriptor:
					var descriptor: ACEDescriptor = value as ACEDescriptor
					if descriptor.ace_type == ACEDescriptor.ACEType.EXPRESSION and "velocity" in descriptor.get_list_name().to_lower():
						found_velocity_expression = true
				expression_item = expression_item.get_next()
			group = group.get_next()
	all_passed = _check("expression picker search finds velocity expression", found_velocity_expression, true) and all_passed

	# Phase 7: horizontal lane composition — event row has a 2px lane divider ColorRect.
	var lane_row_2: EventRowUI = EventRowUI.new()
	lane_row_2.event_row = EventRow.new()
	lane_row_2.refresh()
	all_passed = _check("event row lane divider present", _has_color_rect_min_width(lane_row_2, 2), true) and all_passed

	# Phase 7: event row has at least 2 inner PanelContainers (condition lane + action lane).
	all_passed = _check("event row has lane panels", _count_panel_containers(lane_row_2) >= 2, true) and all_passed

	# Phase 7: outer EventRowUI panel style has zero content margins (lanes flush to border).
	var lane_row_outer_style: StyleBox = lane_row_2.get_theme_stylebox("panel")
	var outer_margins_flush: bool = false
	if lane_row_outer_style is StyleBoxFlat:
		var sflat: StyleBoxFlat = lane_row_outer_style as StyleBoxFlat
		outer_margins_flush = (
			sflat.content_margin_left == 0 and
			sflat.content_margin_right == 0 and
			sflat.content_margin_top == 0 and
			sflat.content_margin_bottom == 0
		)
	all_passed = _check("event row outer panel has flush margins for lane layout", outer_margins_flush, true) and all_passed

	# Phase 8: lane rows use denser, cell-like controls while preserving lane composition.
	var cell_like_event: EventRow = EventRow.new()
	var cell_like_condition: ACECondition = ACECondition.new()
	cell_like_condition.ace_id = "Always"
	cell_like_event.conditions.append(cell_like_condition)
	var cell_like_action: ACEAction = ACEAction.new()
	cell_like_action.ace_id = "QueueFree"
	cell_like_event.actions.append(cell_like_action)
	var lane_row_3: EventRowUI = EventRowUI.new()
	lane_row_3.event_row = cell_like_event
	lane_row_3.refresh()

	var run_btn: Button = _find_button_with_prefix(lane_row_3, EventRowUI.RUN_CONTEXT_SYMBOL + " ")
	all_passed = _check("run-context button found in condition lane", run_btn != null, true) and all_passed
	if run_btn != null:
		var run_style_flat: StyleBoxFlat = _get_flat_stylebox(run_btn, "normal")
		all_passed = _check("run-context style exists", run_style_flat != null, true) and all_passed
		if run_style_flat != null:
			all_passed = _check("run-context uses square cell corners", run_style_flat.corner_radius_top_left, 0) and all_passed
			all_passed = _check("run-context has visible cell border", run_style_flat.border_width_left, 1) and all_passed
			all_passed = _check("run-context vertical padding tightened", run_style_flat.content_margin_top, 0) and all_passed

	var condition_btn: Button = _find_button_with_text(lane_row_3, "Always")
	all_passed = _check("condition token button found", condition_btn != null, true) and all_passed
	if condition_btn != null:
		var condition_style: StyleBoxFlat = _get_flat_stylebox(condition_btn, "normal")
		all_passed = _check("condition token style exists", condition_style != null, true) and all_passed
		if condition_style != null:
			all_passed = _check("condition token has lane-accent left border", condition_style.border_width_left, 2) and all_passed
			all_passed = _check("condition token top padding tightened", condition_style.content_margin_top, 2) and all_passed

	var lane_entry_buttons: Array = _find_buttons_with_tooltip(lane_row_3, EventRowUI.ENTRY_TOOLTIP_TEXT)
	all_passed = _check("lane entry tokens rendered", lane_entry_buttons.size() >= 2, true) and all_passed
	var action_btn: Button = lane_entry_buttons[1] as Button if lane_entry_buttons.size() >= 2 else null
	all_passed = _check("action token button found", action_btn != null, true) and all_passed
	if action_btn != null:
		var action_style: StyleBoxFlat = _get_flat_stylebox(action_btn, "normal")
		all_passed = _check("action token style exists", action_style != null, true) and all_passed
		if action_style != null:
			all_passed = _check("action token has lane-accent left border", action_style.border_width_left, 2) and all_passed
			all_passed = _check("action token top padding tightened", action_style.content_margin_top, 2) and all_passed

	all_passed = _check("action lane add button uses +Add label", _find_button_with_text(lane_row_3, "+Add") != null, true) and all_passed
	all_passed = _check("action context menu label: edit", _popup_menu_has_item_text(lane_row_3, "Edit Action"), true) and all_passed
	all_passed = _check("action context menu label: add", _popup_menu_has_item_text(lane_row_3, "Add Action"), true) and all_passed
	all_passed = _check("action context menu label: replace", _popup_menu_has_item_text(lane_row_3, "Replace Action"), true) and all_passed
	all_passed = _check("action context menu label: delete", _popup_menu_has_item_text(lane_row_3, "Delete Action"), true) and all_passed
	all_passed = _check("condition context menu label: edit", _popup_menu_has_item_text(lane_row_3, "Edit Condition"), true) and all_passed
	all_passed = _check("condition context menu label: add", _popup_menu_has_item_text(lane_row_3, "Add Condition"), true) and all_passed
	all_passed = _check("condition context menu label: replace", _popup_menu_has_item_text(lane_row_3, "Replace Condition"), true) and all_passed
	all_passed = _check("condition context menu label: invert", _popup_menu_has_item_text(lane_row_3, "Invert"), true) and all_passed
	all_passed = _check("condition context menu label: delete", _popup_menu_has_item_text(lane_row_3, "Delete Condition"), true) and all_passed
	all_passed = _check("event row insertion button above visible", _find_button_with_tooltip(lane_row_3, "Insert event above this row") != null, true) and all_passed
	all_passed = _check("event row insertion button below visible", _find_button_with_tooltip(lane_row_3, "Insert event below this row") != null, true) and all_passed

	var depth_row_0: EventRowUI = EventRowUI.new()
	depth_row_0.event_row = EventRow.new()
	depth_row_0.set_depth(0)
	depth_row_0.refresh()
	var depth_row_3: EventRowUI = EventRowUI.new()
	depth_row_3.event_row = EventRow.new()
	depth_row_3.set_depth(3)
	depth_row_3.refresh()
	var depth_style_0: StyleBoxFlat = _get_flat_stylebox(depth_row_0, "panel")
	var depth_style_3: StyleBoxFlat = _get_flat_stylebox(depth_row_3, "panel")
	all_passed = _check("depth row style depth0 exists", depth_style_0 != null, true) and all_passed
	all_passed = _check("depth row style depth3 exists", depth_style_3 != null, true) and all_passed
	if depth_style_0 != null and depth_style_3 != null:
		all_passed = _check("nested depth tint lightens row red channel", depth_style_3.bg_color.r > depth_style_0.bg_color.r, true) and all_passed
		all_passed = _check("nested depth tint lightens row green channel", depth_style_3.bg_color.g > depth_style_0.bg_color.g, true) and all_passed
		all_passed = _check("nested depth tint lightens row blue channel", depth_style_3.bg_color.b > depth_style_0.bg_color.b, true) and all_passed

	lane_row_2.free()
	lane_row_3.free()
	depth_row_0.free()
	depth_row_3.free()

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

static func _contains_label_text(node: Node, expected: String) -> bool:
	if node == null:
		return false
	if node is Label:
		var lbl: Label = node as Label
		if lbl.text == expected:
			return true
	for child: Node in node.get_children():
		if _contains_label_text(child, expected):
			return true
	return false

static func _count_nodes_named(node: Node, expected_name: String) -> int:
	if node == null:
		return 0
	var total: int = 1 if node.name == expected_name else 0
	for child: Node in node.get_children():
		total += _count_nodes_named(child, expected_name)
	return total

static func _count_panel_containers(node: Node) -> int:
	if node == null:
		return 0
	var total: int = 1 if node is PanelContainer else 0
	for child: Node in node.get_children():
		total += _count_panel_containers(child)
	return total

static func _count_color_rects(node: Node) -> int:
	if node == null:
		return 0
	var total: int = 1 if node is ColorRect else 0
	for child: Node in node.get_children():
		total += _count_color_rects(child)
	return total

static func _count_separators(node: Node) -> int:
	if node == null:
		return 0
	var total: int = 1 if node is HSeparator else 0
	for child: Node in node.get_children():
		total += _count_separators(child)
	return total

static func _find_first_panel_container(node: Node) -> PanelContainer:
	if node == null:
		return null
	if node is PanelContainer:
		return node as PanelContainer
	for child: Node in node.get_children():
		var found: PanelContainer = _find_first_panel_container(child)
		if found != null:
			return found
	return null

static func _has_color_rect_min_width(node: Node, min_width: int) -> bool:
	if node == null:
		return false
	if node is ColorRect:
		var cr: ColorRect = node as ColorRect
		if cr.custom_minimum_size.x >= min_width:
			return true
	for child: Node in node.get_children():
		if _has_color_rect_min_width(child, min_width):
			return true
	return false

static func _find_button_with_text(node: Node, expected_text: String) -> Button:
	if node == null:
		return null
	if node is Button:
		var btn: Button = node as Button
		if btn.text == expected_text:
			return btn
	for child: Node in node.get_children():
		var found: Button = _find_button_with_text(child, expected_text)
		if found != null:
			return found
	return null

static func _find_button_with_prefix(node: Node, prefix: String) -> Button:
	if node == null:
		return null
	if node is Button:
		var btn: Button = node as Button
		if btn.text.begins_with(prefix):
			return btn
	for child: Node in node.get_children():
		var found: Button = _find_button_with_prefix(child, prefix)
		if found != null:
			return found
	return null

static func _get_flat_stylebox(control: Control, style_name: String) -> StyleBoxFlat:
	if control == null:
		return null
	var style: StyleBox = control.get_theme_stylebox(style_name)
	if style is StyleBoxFlat:
		return style as StyleBoxFlat
	return null

static func _find_buttons_with_tooltip(node: Node, tooltip: String) -> Array:
	var found: Array = []
	_collect_buttons_with_tooltip(node, tooltip, found)
	return found

static func _find_button_with_tooltip(node: Node, tooltip: String) -> Button:
	var buttons: Array = _find_buttons_with_tooltip(node, tooltip)
	if buttons.is_empty():
		return null
	var first: Variant = buttons[0]
	if not (first is Button):
		return null
	return first as Button

static func _collect_buttons_with_tooltip(node: Node, tooltip: String, out: Array) -> void:
	if node == null:
		return
	if node is Button:
		var btn: Button = node as Button
		if btn.tooltip_text == tooltip:
			out.append(btn)
	for child: Node in node.get_children():
		_collect_buttons_with_tooltip(child, tooltip, out)

static func _popup_menu_has_item_text(node: Node, expected_text: String) -> bool:
	var popup: PopupMenu = _find_popup_with_item_text(node, expected_text)
	return popup != null

static func _find_popup_with_item_text(node: Node, expected_text: String) -> PopupMenu:
	if node == null:
		return null
	if node is PopupMenu:
		var popup: PopupMenu = node as PopupMenu
		for i: int in range(popup.item_count):
			if popup.get_item_text(i) == expected_text:
				return popup
	for child: Node in node.get_children():
		var found: PopupMenu = _find_popup_with_item_text(child, expected_text)
		if found != null:
			return found
	return null

static func _find_node_named(node: Node, expected_name: String) -> Node:
	if node == null:
		return null
	if node.name == expected_name:
		return node
	for child: Node in node.get_children():
		var found: Node = _find_node_named(child, expected_name)
		if found != null:
			return found
	return null
