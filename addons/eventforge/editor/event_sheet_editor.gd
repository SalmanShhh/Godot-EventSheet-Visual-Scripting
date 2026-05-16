# EventForge — Event sheet editor
@tool
extends Control
class_name EventSheetEditor

enum ViewMode {
    EVENT_SHEET,
    GDSCRIPT,
    SPLIT
}

const FALLBACK_OPEN_PATH: String = "res://demo/sheets/player.tres"
const FALLBACK_SAVE_PATH: String = "res://demo/sheets/editor_saved_sheet.tres"

var current_sheet: EventSheetResource = null
var current_view_mode: ViewMode = ViewMode.SPLIT
var generated_code_preview: String = ""
var _preview_dirty: bool = false
var _sheet_dirty: bool = false
var _refreshing_preview: bool = false

var _selected_row: EventRow = null
var _pending_row_for_condition: EventRow = null
var _pending_row_for_action: EventRow = null

## Tracks which sub-element is focused for inspector editing.
## Values: "event", "condition", "action", "variable", "group"
var _selected_entry_kind: String = "event"
var _selected_entry_index: int = -1
var _selected_variable_name: String = ""
var _selected_group: EventGroup = null

var _row_clipboard: Resource = null
var _row_clipboard_kind: String = ""
var _identifier_regex: RegEx = null

var _toolbar: SheetToolbar
var _active_sheet_label: Label
var _main_split: HSplitContainer
var _sheet_area: HSplitContainer
var _ace_palette: ACEPalette
var _vars_list: VBoxContainer
var _row_scroll: ScrollContainer
var _row_list: VBoxContainer
var _inspector_scroll: ScrollContainer
var _inspector_container: VBoxContainer
var _gdscript_panel: GDScriptPanel
var _status_label: Label
var _condition_picker: ConditionPicker
var _action_picker: ActionPicker
var _open_dialog: EditorFileDialog
var _save_dialog: EditorFileDialog
var _preview_refresh_timer: Timer

func _ready() -> void:
    _build_ui()
    set_view_mode(ViewMode.SPLIT)
    set_sheet(null)

## Assigns an active sheet resource and refreshes editor content.
func set_sheet(sheet: EventSheetResource) -> void:
    current_sheet = sheet
    _selected_row = null
    _selected_entry_kind = "event"
    _selected_entry_index = -1
    _selected_variable_name = ""
    _selected_group = null
    _preview_dirty = false
    _sheet_dirty = false
    refresh_rows()
    _rebuild_vars_panel()
    _rebuild_inspector()
    _update_active_sheet_header()
    _refresh_preview_for_sheet_change()

func _refresh_preview_for_sheet_change() -> void:
    if current_sheet == null:
        # Ensure preview/status panels immediately reflect "no sheet loaded".
        refresh_preview()
        return
    _mark_preview_dirty(false)

## Creates a new in-memory sheet and resets editor state.
func create_new_sheet() -> void:
    var sheet: EventSheetResource = EventSheetResource.new()
    sheet.host_class = "Node"
    sheet.events = []
    set_sheet(sheet)
    _sheet_dirty = true
    _update_active_sheet_header()
    _set_status("New in-memory sheet created.")

## Rebuilds visible event rows.
## Global variable rows are rendered at the top, followed by group/event rows,
## mirroring a Construct/GDevelop-style vertical document flow.
func refresh_rows() -> void:
    if _row_list == null:
        return

    _clear_children(_row_list)
    if current_sheet == null:
        var no_sheet_label: Label = Label.new()
        no_sheet_label.text = "No Event Sheet Open"
        no_sheet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        no_sheet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _row_list.add_child(no_sheet_label)
        return

    # --- Global variable rows (top of document) ---
    var var_keys: Array = current_sheet.variables.keys()
    var_keys.sort()
    for var_key: Variant in var_keys:
        var v_name: String = str(var_key)
        var v_desc: Variant = current_sheet.variables[var_key]
        if not (v_desc is Dictionary):
            v_desc = {"type": "Variant", "default": null}
        var var_row: VariableRowUI = VariableRowUI.new()
        var_row.setup(v_name, v_desc as Dictionary)
        var_row.set_selected(v_name == _selected_variable_name and _selected_entry_kind == "variable")
        var_row.selected.connect(_on_variable_row_selected)
        _row_list.add_child(var_row)

    if current_sheet.events.is_empty():
        var empty_button: Button = Button.new()
        empty_button.text = "No events yet. Click here or press Add Event to create one."
        empty_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        empty_button.custom_minimum_size = Vector2(0, 84)
        empty_button.flat = true
        empty_button.pressed.connect(_on_add_event_requested)
        _row_list.add_child(empty_button)
        return

    for entry: Resource in current_sheet.events:
        if entry is EventGroup:
            var group_ui: GroupRowUI = GroupRowUI.new()
            group_ui.setup(entry as EventGroup)
            group_ui.set_selected(entry == _selected_group and _selected_entry_kind == "group")
            group_ui.selected.connect(_on_group_row_selected)
            _row_list.add_child(group_ui)
        elif entry is EventRow:
            var row: EventRow = entry
            var row_ui: EventRowUI = EventRowUI.new()
            row_ui.set_row(row)
            row_ui.set_selected(row == _selected_row and _selected_entry_kind in ["event", "condition", "action"])
            row_ui.selected.connect(_on_row_selected)
            row_ui.delete_requested.connect(_on_row_delete_requested)
            row_ui.add_condition_requested.connect(_on_add_condition_requested)
            row_ui.add_action_requested.connect(_on_add_action_requested)
            row_ui.duplicate_requested.connect(_on_row_duplicate_requested)
            row_ui.condition_selected.connect(_on_condition_entry_selected)
            row_ui.action_selected.connect(_on_action_entry_selected)
            _row_list.add_child(row_ui)

    var add_more_button: Button = Button.new()
    add_more_button.text = "Click empty space to add another event."
    add_more_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_more_button.flat = true
    add_more_button.custom_minimum_size = Vector2(0, 56)
    add_more_button.pressed.connect(_on_add_event_requested)
    _row_list.add_child(add_more_button)

## Recompiles the sheet to update the generated code preview panel.
func refresh_preview() -> void:
    if _gdscript_panel == null or _refreshing_preview:
        return
    _refreshing_preview = true

    if current_sheet == null:
        generated_code_preview = "# No sheet loaded\n"
        _gdscript_panel.set_source(generated_code_preview)
        _set_status("No sheet loaded.")
        _update_active_sheet_header()
        _refreshing_preview = false
        return

    var output_path: String = ""
    if current_sheet.resource_path.is_empty():
        output_path = "user://eventforge_preview_generated.gd"

    var result: Dictionary = SheetCompiler.compile(current_sheet, output_path)
    generated_code_preview = str(result.get("output", ""))
    _gdscript_panel.set_source(generated_code_preview)

    if bool(result.get("success", false)):
        _preview_dirty = false
        _update_active_sheet_header()
        var warnings: Array = result.get("warnings", [])
        if warnings.is_empty():
            _set_status("Preview updated.")
        else:
            _set_status("Compile succeeded with warnings: %s" % "; ".join(warnings))
    else:
        var errors: Array = result.get("errors", [])
        _set_status("Compile failed: %s" % "; ".join(errors))
        _update_active_sheet_header()
    _refreshing_preview = false

## Applies Event Sheet / GDScript / Split layout visibility.
func set_view_mode(mode: ViewMode) -> void:
    current_view_mode = mode
    if _toolbar != null:
        _toolbar.set_view_mode(mode)

    if _sheet_area == null or _gdscript_panel == null:
        return

    match mode:
        ViewMode.EVENT_SHEET:
            _sheet_area.visible = true
            _gdscript_panel.visible = false
        ViewMode.GDSCRIPT:
            _sheet_area.visible = false
            _gdscript_panel.visible = true
        ViewMode.SPLIT:
            _sheet_area.visible = true
            _gdscript_panel.visible = true

func _build_ui() -> void:
    if _toolbar != null:
        return

    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL

    var root: VBoxContainer = VBoxContainer.new()
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(root)

    _toolbar = SheetToolbar.new()
    _toolbar.setup()
    _toolbar.new_sheet_requested.connect(create_new_sheet)
    _toolbar.open_sheet_requested.connect(_on_open_sheet_requested)
    _toolbar.save_sheet_requested.connect(_on_save_sheet_requested)
    _toolbar.save_sheet_as_requested.connect(_on_save_sheet_as_requested)
    _toolbar.add_event_requested.connect(_on_add_event_requested)
    _toolbar.compile_requested.connect(refresh_preview)
    _toolbar.refresh_preview_requested.connect(refresh_preview)
    _toolbar.view_mode_changed.connect(_on_toolbar_view_mode_changed)
    _toolbar.copy_requested.connect(_on_copy_requested)
    _toolbar.paste_requested.connect(_on_paste_requested)
    _toolbar.duplicate_requested.connect(_on_duplicate_requested)
    _toolbar.delete_requested.connect(_on_delete_requested)
    root.add_child(_toolbar)

    _active_sheet_label = Label.new()
    _active_sheet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _active_sheet_label.text = "No Event Sheet Open"
    root.add_child(_active_sheet_label)

    _main_split = HSplitContainer.new()
    _main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(_main_split)

    _sheet_area = HSplitContainer.new()
    _sheet_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _sheet_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _main_split.add_child(_sheet_area)

    var left_panel: VBoxContainer = VBoxContainer.new()
    left_panel.custom_minimum_size = Vector2(300, 0)
    left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _sheet_area.add_child(left_panel)

    _ace_palette = ACEPalette.new()
    _ace_palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _ace_palette.refresh()
    _ace_palette.ace_selected.connect(_on_ace_selected)
    left_panel.add_child(_ace_palette)

    var left_spacer: Control = Control.new()
    left_spacer.custom_minimum_size = Vector2(0, 8)
    left_panel.add_child(left_spacer)

    # Sheet Variables sub-panel
    var vars_outer: VBoxContainer = VBoxContainer.new()
    vars_outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left_panel.add_child(vars_outer)

    var vars_controls: VBoxContainer = VBoxContainer.new()
    vars_outer.add_child(vars_controls)

    var vars_title: Label = Label.new()
    vars_title.text = "Sheet Variables"
    vars_controls.add_child(vars_title)

    var add_var_btn: Button = Button.new()
    add_var_btn.text = "+ Add Var"
    add_var_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
    add_var_btn.pressed.connect(_on_add_variable_pressed)
    vars_controls.add_child(add_var_btn)

    var vars_scroll: ScrollContainer = ScrollContainer.new()
    vars_scroll.custom_minimum_size = Vector2(0, 120)
    vars_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vars_outer.add_child(vars_scroll)

    _vars_list = VBoxContainer.new()
    _vars_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vars_scroll.add_child(_vars_list)

    _row_scroll = ScrollContainer.new()
    _row_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _row_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _sheet_area.add_child(_row_scroll)

    _row_list = VBoxContainer.new()
    _row_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _row_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _row_list.add_theme_constant_override("separation", 8)
    _row_scroll.add_child(_row_list)

    _inspector_scroll = ScrollContainer.new()
    _inspector_scroll.custom_minimum_size = Vector2(320, 260)
    _inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _sheet_area.add_child(_inspector_scroll)

    _inspector_container = VBoxContainer.new()
    _inspector_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _inspector_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _inspector_scroll.add_child(_inspector_container)

    _gdscript_panel = GDScriptPanel.new()
    _gdscript_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _gdscript_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _main_split.add_child(_gdscript_panel)

    _status_label = Label.new()
    _status_label.text = "Ready"
    root.add_child(_status_label)

    _preview_refresh_timer = Timer.new()
    _preview_refresh_timer.one_shot = true
    _preview_refresh_timer.wait_time = 0.4
    _preview_refresh_timer.timeout.connect(_on_preview_refresh_timeout)
    add_child(_preview_refresh_timer)

    _condition_picker = ConditionPicker.new()
    _condition_picker.descriptor_selected.connect(_on_condition_descriptor_selected)
    add_child(_condition_picker)

    _action_picker = ActionPicker.new()
    _action_picker.action_selected.connect(_on_action_selected)
    add_child(_action_picker)

    _build_file_dialogs()
    _rebuild_inspector()

func _on_add_event_requested() -> void:
    if current_sheet == null:
        create_new_sheet()

    var row: EventRow = EventRow.new()
    current_sheet.events.append(row)
    _selected_row = row
    _selected_group = null
    _selected_entry_kind = "event"
    _selected_entry_index = -1
    _selected_variable_name = ""
    refresh_rows()
    _rebuild_inspector()
    _mark_preview_dirty()
    _set_status("New Event created. Choose when this event runs, then add conditions and actions.")

func _on_row_selected(row: EventRow) -> void:
    _selected_row = row
    _selected_group = null
    _selected_entry_kind = "event"
    _selected_entry_index = -1
    _selected_variable_name = ""
    refresh_rows()
    _rebuild_inspector()

func _on_row_delete_requested(row: EventRow) -> void:
    if current_sheet == null:
        return

    var events: Array = current_sheet.events
    for index: int in range(events.size()):
        if events[index] == row:
            events.remove_at(index)
            break
    if _selected_row == row:
        _selected_row = null
        _selected_entry_kind = "event"
        _selected_entry_index = -1
    refresh_rows()
    _rebuild_inspector()
    _mark_preview_dirty()

func _on_add_condition_requested(row: EventRow) -> void:
    _selected_row = row
    _selected_group = null
    _selected_entry_kind = "event"
    _selected_entry_index = -1
    refresh_rows()
    _rebuild_inspector()
    _pending_row_for_condition = row
    if _condition_picker != null:
        _condition_picker.open_picker()

func _on_add_action_requested(row: EventRow) -> void:
    _selected_row = row
    _selected_group = null
    _selected_entry_kind = "event"
    _selected_entry_index = -1
    refresh_rows()
    _rebuild_inspector()
    _pending_row_for_action = row
    if _action_picker != null:
        _action_picker.open_picker()

func _on_condition_descriptor_selected(descriptor: ACEDescriptor) -> void:
    if _pending_row_for_condition == null or descriptor == null:
        return
    _selected_row = _pending_row_for_condition
    _pending_row_for_condition = null
    _apply_descriptor_to_selected_row(descriptor)

func _on_action_selected(action: ACEAction) -> void:
    if _pending_row_for_action == null or action == null:
        return
    _materialize_action_params(action)
    _ensure_default_my_var_for_action_ace_id(action.ace_id)
    _pending_row_for_action.actions.append(action)
    _selected_row = _pending_row_for_action
    _pending_row_for_action = null
    _rebuild_vars_panel()
    refresh_rows()
    _rebuild_inspector()
    _mark_preview_dirty()

func _on_row_duplicate_requested(row: EventRow) -> void:
    _selected_row = row
    _selected_group = null
    _selected_entry_kind = "event"
    _selected_entry_index = -1
    refresh_rows()
    _rebuild_inspector()
    _on_duplicate_requested()

## Handles a click on a global variable row in the canvas.
func _on_variable_row_selected(v_name: String) -> void:
    _selected_row = null
    _selected_group = null
    _selected_entry_kind = "variable"
    _selected_entry_index = -1
    _selected_variable_name = v_name
    refresh_rows()
    _rebuild_inspector()

## Handles a click on a group row header in the canvas.
func _on_group_row_selected(group: EventGroup) -> void:
    _selected_row = null
    _selected_group = group
    _selected_entry_kind = "group"
    _selected_entry_index = -1
    _selected_variable_name = ""
    refresh_rows()
    _rebuild_inspector()

## Handles a click on a specific condition entry inside an event row.
func _on_condition_entry_selected(row: EventRow, index: int) -> void:
    _selected_row = row
    _selected_group = null
    _selected_entry_kind = "condition"
    _selected_entry_index = index
    _selected_variable_name = ""
    refresh_rows()
    _rebuild_inspector()

## Handles a click on a specific action entry inside an event row.
func _on_action_entry_selected(row: EventRow, index: int) -> void:
    _selected_row = row
    _selected_group = null
    _selected_entry_kind = "action"
    _selected_entry_index = index
    _selected_variable_name = ""
    refresh_rows()
    _rebuild_inspector()

func _on_toolbar_view_mode_changed(mode: int) -> void:
    match mode:
        ViewMode.EVENT_SHEET:
            set_view_mode(ViewMode.EVENT_SHEET)
        ViewMode.GDSCRIPT:
            set_view_mode(ViewMode.GDSCRIPT)
        ViewMode.SPLIT:
            set_view_mode(ViewMode.SPLIT)

func _mark_preview_dirty(mark_sheet_dirty: bool = true) -> void:
    if mark_sheet_dirty:
        _sheet_dirty = true
    _preview_dirty = true
    _update_active_sheet_header()
    _set_status("Preview update scheduled...")
    if _preview_refresh_timer != null:
        _preview_refresh_timer.start()

func _on_preview_refresh_timeout() -> void:
    if not _preview_dirty:
        return
    refresh_preview()

func _active_sheet_title() -> String:
    if current_sheet == null:
        return "No Event Sheet Open"
    if current_sheet.resource_path.is_empty():
        return "Unsaved Event Sheet"
    return "Event Sheet: %s" % current_sheet.resource_path.get_file()

func _update_active_sheet_header() -> void:
    if _active_sheet_label == null:
        return
    var dirty_marker: String = " *" if _sheet_dirty or _preview_dirty else ""
    _active_sheet_label.text = "%s%s" % [_active_sheet_title(), dirty_marker]

func _set_status(message: String) -> void:
    if _status_label != null:
        _status_label.text = message

func _on_ace_selected(descriptor: ACEDescriptor) -> void:
    if descriptor == null:
        return
    _apply_descriptor_to_selected_row(descriptor)

func _apply_descriptor_to_selected_row(descriptor: ACEDescriptor) -> void:
    if descriptor == null:
        return
    match descriptor.ace_type:
        ACEDescriptor.ACEType.TRIGGER:
            var row: EventRow = _selected_row
            if row == null:
                row = _add_row_for_trigger()
            if TriggerResolver.has_trigger_condition(row):
                _selected_row = row
                refresh_rows()
                _rebuild_inspector()
                _set_status("Only one run context is supported per event.")
                return
            _assign_trigger(row, descriptor)
            _selected_row = row
            refresh_rows()
            _rebuild_inspector()
            _mark_preview_dirty()
            _set_status("Run context set to %s." % _entry_name(descriptor.provider_id, descriptor.ace_id))
        ACEDescriptor.ACEType.CONDITION:
            if _selected_row == null:
                _set_status("Select an event row first.")
                return
            _selected_row.conditions.append(_make_condition(descriptor))
            refresh_rows()
            _rebuild_inspector()
            _mark_preview_dirty()
            _set_status("Condition added: %s." % descriptor.ace_id)
        ACEDescriptor.ACEType.ACTION:
            if _selected_row == null:
                _set_status("Select an event row first.")
                return
            _ensure_default_my_var_for_action_ace_id(descriptor.ace_id)
            _selected_row.actions.append(_make_action(descriptor))
            _rebuild_vars_panel()
            refresh_rows()
            _rebuild_inspector()
            _mark_preview_dirty()
            _set_status("Action added: %s." % descriptor.ace_id)
        ACEDescriptor.ACEType.EXPRESSION:
            _set_status("Expressions are not inserted directly yet.")

func _add_row_for_trigger() -> EventRow:
    if current_sheet == null:
        create_new_sheet()
    var row: EventRow = EventRow.new()
    current_sheet.events.append(row)
    return row

func _clear_trigger_condition(row: EventRow) -> void:
    if row == null:
        return
    row.trigger_provider_id = ""
    row.trigger_id = ""
    row.trigger_params = {}
    row.trigger = null

func _sync_trigger_resource(row: EventRow) -> void:
    if row == null:
        return
    if row.trigger_id.is_empty():
        row.trigger = null
        return
    if row.trigger == null:
        row.trigger = ACECondition.new()
    row.trigger.provider_id = row.trigger_provider_id
    row.trigger.ace_id = row.trigger_id
    row.trigger.params = row.trigger_params.duplicate(true)
    row.trigger.parameters = row.trigger_params.duplicate(true)

func _assign_trigger(row: EventRow, descriptor: ACEDescriptor) -> void:
    if row == null or descriptor == null:
        return
    row.trigger_provider_id = descriptor.provider_id
    row.trigger_id = descriptor.ace_id
    row.trigger_params = _params_from_descriptor(descriptor)
    row.trigger = _make_condition(descriptor)
    row.trigger.params = row.trigger_params.duplicate(true)
    row.trigger.parameters = row.trigger_params.duplicate(true)

func _params_from_descriptor(descriptor: ACEDescriptor) -> Dictionary:
    var params: Dictionary = {}
    if descriptor == null:
        return params

    for param: ACEParam in descriptor.params:
        if param == null:
            continue
        var param_id: String = param.id if not param.id.is_empty() else param.name
        if param_id.is_empty():
            continue
        params[param_id] = _default_param_value(descriptor, param_id, param)
    return params

func _make_condition(descriptor: ACEDescriptor) -> ACECondition:
    var condition: ACECondition = ACECondition.new()
    condition.provider_id = descriptor.provider_id
    condition.ace_id = descriptor.ace_id
    condition.params = _params_from_descriptor(descriptor)
    condition.parameters = condition.params.duplicate(true)
    return condition

func _make_action(descriptor: ACEDescriptor) -> ACEAction:
    var action: ACEAction = ACEAction.new()
    action.provider_id = descriptor.provider_id
    action.ace_id = descriptor.ace_id
    action.params = _params_from_descriptor(descriptor)
    action.parameters = action.params.duplicate(true)
    return action

func _default_param_value(descriptor: ACEDescriptor, param_id: String, param: ACEParam) -> Variant:
    var ace_id: String = descriptor.ace_id
    match ace_id:
        "PrintLog":
            if param_id == "message":
                return "\"Hello from EventForge\""
        "SetVar":
            if param_id == "var_name":
                return "my_var"
            if param_id == "value":
                return "0"
        "AddVar":
            if param_id == "var_name":
                return "my_var"
            if param_id == "amount":
                return "1"
        "EmitSignal":
            if param_id == "signal_name":
                return "\"eventforge_signal\""
            if param_id == "args":
                return ""
        "CompareVar":
            if param_id == "var_name":
                return "my_var"
            if param_id == "op":
                return "=="
            if param_id == "value":
                return "0"
        "HasGroupMember":
            if param_id == "group":
                return "\"enemy\""
        "OnSignal":
            if param_id == "target_node":
                return "self"
            if param_id == "signal_name":
                return "eventforge_signal"

    var default_value: Variant = param.default_value
    if _is_string_like_param(param):
        if default_value == null:
            return "\"\""
        var text: String = str(default_value)
        if text.is_empty():
            return "\"\""
        return text
    return default_value

func _is_string_like_param(param: ACEParam) -> bool:
    if param == null:
        return false
    if param.type == TYPE_STRING:
        return true
    var name: String = param.type_name.strip_edges().to_lower()
    return name == "string" or name == "stringname" or name == "nodepath"

func _materialize_condition_params(condition: ACECondition) -> void:
    if condition == null:
        return
    if condition.params.is_empty():
        var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
        if descriptor != null:
            condition.params = _params_from_descriptor(descriptor)
    condition.parameters = condition.params.duplicate(true)

func _materialize_action_params(action: ACEAction) -> void:
    if action == null:
        return
    if action.params.is_empty():
        var descriptor: ACEDescriptor = ACERegistry.find_descriptor(action.provider_id, action.ace_id)
        if descriptor != null:
            action.params = _params_from_descriptor(descriptor)
    action.parameters = action.params.duplicate(true)

func _ensure_default_my_var_for_action_ace_id(ace_id: String) -> void:
    if current_sheet == null:
        return
    if ace_id != "SetVar" and ace_id != "AddVar":
        return
    if current_sheet.variables.has("my_var"):
        return
    current_sheet.variables["my_var"] = {
        "type": "int",
        "default": 0
    }

func _rebuild_inspector() -> void:
    if _inspector_container == null:
        return

    _clear_children(_inspector_container)

    # --- Focused: variable selected ---
    if _selected_entry_kind == "variable" and not _selected_variable_name.is_empty():
        _rebuild_inspector_variable(_selected_variable_name)
        return

    # --- Focused: group selected ---
    if _selected_entry_kind == "group" and _selected_group != null:
        _rebuild_inspector_group(_selected_group)
        return

    if _selected_row == null:
        var empty_label: Label = Label.new()
        empty_label.text = "Select an event row, group, or variable to edit."
        _inspector_container.add_child(empty_label)
        return

    # --- Focused: condition selected ---
    if _selected_entry_kind == "condition" and _selected_entry_index >= 0:
        _rebuild_inspector_condition(_selected_row, _selected_entry_index)
        return

    # --- Focused: action selected ---
    if _selected_entry_kind == "action" and _selected_entry_index >= 0:
        _rebuild_inspector_action(_selected_row, _selected_entry_index)
        return

    # --- Full event inspector (default) ---
    _rebuild_inspector_event(_selected_row)

## Builds the full event inspector for the selected row.
func _rebuild_inspector_event(row: EventRow) -> void:
    _inspector_container.add_child(_title_label("Inspector — Event"))
    _inspector_container.add_child(_read_only_line("UID", row.event_uid))
    _inspector_container.add_child(_read_only_line("Runs", _run_summary_for_row(row)))

    var enabled_toggle: CheckBox = CheckBox.new()
    enabled_toggle.text = "Enabled"
    enabled_toggle.button_pressed = row.enabled
    enabled_toggle.toggled.connect(_on_inspector_enabled_toggled)
    _inspector_container.add_child(enabled_toggle)

    var run_context_provider: String = _run_context_provider_for_row(row)
    var run_context_id: String = TriggerResolver.get_trigger_id(row)
    _add_text_editor("Run Context Provider", run_context_provider, func(value: String) -> void:
        if _selected_row == null:
            return
        _selected_row.trigger_provider_id = value.strip_edges()
        _sync_trigger_resource(_selected_row)
        refresh_rows()
        _mark_preview_dirty()
    )
    _add_text_editor("Run Context ID", run_context_id, func(value: String) -> void:
        if _selected_row == null:
            return
        _selected_row.trigger_id = value.strip_edges()
        _sync_trigger_resource(_selected_row)
        refresh_rows()
        _mark_preview_dirty()
    )

    var clear_run_context_button: Button = Button.new()
    clear_run_context_button.text = "Clear Run Context"
    clear_run_context_button.disabled = not TriggerResolver.has_trigger_condition(row)
    clear_run_context_button.pressed.connect(func() -> void:
        if _selected_row == null:
            return
        _clear_trigger_condition(_selected_row)
        refresh_rows()
        _rebuild_inspector()
        _mark_preview_dirty()
    )
    _inspector_container.add_child(clear_run_context_button)

    _inspector_container.add_child(_title_label("Run Context Params"))
    _add_params_editor(
        TriggerResolver.get_trigger_params(row),
        _on_trigger_param_changed,
        TriggerResolver.get_trigger_id(row)
    )

    _inspector_container.add_child(_title_label("Conditions"))
    if row.conditions.is_empty():
        _inspector_container.add_child(_read_only_line("-", "Always"))
    else:
        for index: int in range(row.conditions.size()):
            var condition: ACECondition = row.conditions[index]
            _materialize_condition_params(condition)
            _add_entry_header(
                "Condition %d: %s" % [index + 1, _entry_name(condition.provider_id, condition.ace_id)],
                "Remove",
                Callable(self, "_remove_condition").bind(index)
            )
            _add_params_editor(
                condition.params,
                Callable(self, "_on_condition_param_changed").bind(index),
                condition.ace_id
            )

    _inspector_container.add_child(_title_label("Actions"))
    if row.actions.is_empty():
        _inspector_container.add_child(_read_only_line("-", "No actions"))
    else:
        for index: int in range(row.actions.size()):
            var action_variant: Variant = row.actions[index]
            if not (action_variant is ACEAction):
                continue
            var action: ACEAction = action_variant
            _materialize_action_params(action)
            _add_entry_header(
                "Action %d: %s" % [index + 1, _entry_name(action.provider_id, action.ace_id)],
                "Remove",
                Callable(self, "_remove_action").bind(index)
            )
            _add_params_editor(
                action.params,
                Callable(self, "_on_action_param_changed").bind(index),
                action.ace_id
            )

## Builds a focused inspector for a single condition entry.
func _rebuild_inspector_condition(row: EventRow, index: int) -> void:
    if index < 0 or index >= row.conditions.size():
        _rebuild_inspector_event(row)
        return
    var condition: ACECondition = row.conditions[index]
    _materialize_condition_params(condition)
    _inspector_container.add_child(_title_label(
        "Condition %d: %s" % [index + 1, _entry_name(condition.provider_id, condition.ace_id)]
    ))
    var back_btn: Button = Button.new()
    back_btn.text = "← Back to Event"
    back_btn.pressed.connect(func() -> void:
        _selected_entry_kind = "event"
        _selected_entry_index = -1
        _rebuild_inspector()
    )
    _inspector_container.add_child(back_btn)
    _add_params_editor(
        condition.params,
        Callable(self, "_on_condition_param_changed").bind(index),
        condition.ace_id
    )
    var remove_btn: Button = Button.new()
    remove_btn.text = "Remove Condition"
    remove_btn.pressed.connect(Callable(self, "_remove_condition").bind(index))
    _inspector_container.add_child(remove_btn)

## Builds a focused inspector for a single action entry.
func _rebuild_inspector_action(row: EventRow, index: int) -> void:
    if index < 0 or index >= row.actions.size():
        _rebuild_inspector_event(row)
        return
    var action_variant: Variant = row.actions[index]
    if not (action_variant is ACEAction):
        _rebuild_inspector_event(row)
        return
    var action: ACEAction = action_variant
    _materialize_action_params(action)
    _inspector_container.add_child(_title_label(
        "Action %d: %s" % [index + 1, _entry_name(action.provider_id, action.ace_id)]
    ))
    var back_btn: Button = Button.new()
    back_btn.text = "← Back to Event"
    back_btn.pressed.connect(func() -> void:
        _selected_entry_kind = "event"
        _selected_entry_index = -1
        _rebuild_inspector()
    )
    _inspector_container.add_child(back_btn)
    _add_params_editor(
        action.params,
        Callable(self, "_on_action_param_changed").bind(index),
        action.ace_id
    )
    var remove_btn: Button = Button.new()
    remove_btn.text = "Remove Action"
    remove_btn.pressed.connect(Callable(self, "_remove_action").bind(index))
    _inspector_container.add_child(remove_btn)

## Builds a focused inspector for a global sheet variable.
func _rebuild_inspector_variable(v_name: String) -> void:
    if current_sheet == null or not current_sheet.variables.has(v_name):
        var lbl: Label = Label.new()
        lbl.text = "Variable not found."
        _inspector_container.add_child(lbl)
        return
    var descriptor: Dictionary = current_sheet.variables[v_name]
    _inspector_container.add_child(_title_label("Global Variable: %s" % v_name))
    _inspector_container.add_child(_read_only_line("Scope", "Global"))

    var var_types: Array[String] = ["int", "float", "String", "bool", "NodePath", "Variant"]
    var type_row: HBoxContainer = HBoxContainer.new()
    var type_label: Label = Label.new()
    type_label.text = "Type"
    type_label.custom_minimum_size = Vector2(120, 0)
    type_row.add_child(type_label)
    var type_opt: OptionButton = OptionButton.new()
    type_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for type_str: String in var_types:
        type_opt.add_item(type_str)
    var current_type: String = str(descriptor.get("type", "int"))
    var type_index: int = var_types.find(current_type)
    if type_index < 0:
        type_index = 0
    type_opt.selected = type_index
    type_opt.item_selected.connect(func(index: int) -> void:
        _set_variable_type(v_name, var_types[index])
        _rebuild_inspector()
    )
    type_row.add_child(type_opt)
    _inspector_container.add_child(type_row)

    var default_val: Variant = descriptor.get("default", null)
    _add_text_editor("Default", "" if default_val == null else str(default_val), func(value: String) -> void:
        _set_variable_default(v_name, value)
    )

    var export_check: CheckBox = CheckBox.new()
    export_check.text = "Exported"
    export_check.button_pressed = bool(descriptor.get("exported", true))
    export_check.toggled.connect(func(is_on: bool) -> void:
        _set_variable_exported(v_name, is_on)
    )
    _inspector_container.add_child(export_check)

    var delete_btn: Button = Button.new()
    delete_btn.text = "Delete Variable"
    delete_btn.pressed.connect(func() -> void:
        _selected_entry_kind = "event"
        _selected_entry_index = -1
        _selected_variable_name = ""
        _selected_group = null
        _selected_row = null
        _delete_variable(v_name)
    )
    _inspector_container.add_child(delete_btn)

## Builds a focused inspector for a selected group header.
func _rebuild_inspector_group(group: EventGroup) -> void:
    _inspector_container.add_child(_title_label("Group: %s" % _group_display_name(group)))
    _add_text_editor("name", group.name, func(value: String) -> void:
        if _selected_group == null:
            return
        _selected_group.name = value
        refresh_rows()
        _mark_preview_dirty()
    )
    _add_text_editor("group_name", group.group_name, func(value: String) -> void:
        if _selected_group == null:
            return
        _selected_group.group_name = value
        refresh_rows()
        _mark_preview_dirty()
    )
    _add_text_editor("description", group.description, func(value: String) -> void:
        if _selected_group == null:
            return
        _selected_group.description = value
        _mark_preview_dirty()
    )

    var enabled_toggle: CheckBox = CheckBox.new()
    enabled_toggle.text = "Enabled"
    enabled_toggle.button_pressed = group.enabled
    enabled_toggle.toggled.connect(func(is_enabled: bool) -> void:
        if _selected_group == null:
            return
        _selected_group.enabled = is_enabled
        refresh_rows()
        _mark_preview_dirty()
    )
    _inspector_container.add_child(enabled_toggle)

    var collapsed_toggle: CheckBox = CheckBox.new()
    collapsed_toggle.text = "Collapsed"
    collapsed_toggle.button_pressed = group.collapsed
    collapsed_toggle.toggled.connect(func(is_collapsed: bool) -> void:
        if _selected_group == null:
            return
        _selected_group.collapsed = is_collapsed
        _selected_group.expanded = not is_collapsed
        _mark_preview_dirty()
    )
    _inspector_container.add_child(collapsed_toggle)

    var note: Label = Label.new()
    note.text = "Nested local variables and group event bodies are planned."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _inspector_container.add_child(note)

func _group_display_name(group: EventGroup) -> String:
    if group == null:
        return "Group"
    var display_name: String = group.name
    if display_name.is_empty():
        display_name = group.group_name
    if display_name.is_empty():
        display_name = "Group"
    return display_name

func _on_inspector_enabled_toggled(is_enabled: bool) -> void:
    if _selected_row == null:
        return
    _selected_row.enabled = is_enabled
    refresh_rows()
    _mark_preview_dirty()

func _entry_name(provider_id: String, ace_id: String) -> String:
    if ace_id.is_empty():
        return "<unset>"
    var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
    if descriptor != null and not descriptor.display_name.is_empty():
        return "%s (%s)" % [descriptor.display_name, ace_id]
    return ace_id

func _run_summary_for_row(row: EventRow) -> String:
    if row == null:
        return "Every Frame"
    var trigger_id: String = TriggerResolver.get_trigger_id(row)
    match trigger_id:
        "":
            return "Every Frame"
        "OnReady":
            return "On Ready"
        "OnProcess":
            return "On Process"
        "OnPhysicsProcess":
            return "On Physics Process"
        "OnBodyEntered":
            return "On Body Entered"
        "OnSignal":
            var params: Dictionary = TriggerResolver.get_trigger_params(row)
            var signal_name: String = str(params.get("signal_name", "eventforge_signal")).strip_edges()
            var target_node: String = str(params.get("target_node", "self")).strip_edges()
            if target_node.is_empty() or target_node == ".":
                target_node = "self"
            return "On Signal \"%s\" from %s" % [signal_name, target_node]
        _:
            return _entry_name(TriggerResolver.get_trigger_provider_id(row), trigger_id)

func _run_context_provider_for_row(row: EventRow) -> String:
    if row == null:
        return ""
    if not row.trigger_provider_id.is_empty():
        return row.trigger_provider_id
    if TriggerResolver.has_trigger_condition(row):
        return TriggerResolver.get_trigger_provider_id(row)
    return ""

func _add_entry_header(text: String, button_text: String, callback: Callable) -> void:
    var header: HBoxContainer = HBoxContainer.new()
    var label: Label = Label.new()
    label.text = text
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(label)

    var button: Button = Button.new()
    button.text = button_text
    button.pressed.connect(callback)
    header.add_child(button)
    _inspector_container.add_child(header)

func _add_params_editor(params: Dictionary, callback: Callable, ace_id: String = "") -> void:
    var keys: Array = params.keys()
    keys.sort()
    if keys.is_empty():
        _inspector_container.add_child(_read_only_line("-", "No params"))
        return

    var var_name_aces: Array[String] = ["SetVar", "AddVar", "CompareVar", "GetVar"]
    for key: Variant in keys:
        var key_name: String = str(key)
        if key_name == "var_name" and ace_id in var_name_aces:
            _add_var_name_picker(key_name, str(params[key]), func(value: String) -> void:
                callback.call(key_name, value)
            )
        else:
            _add_text_editor(key_name, str(params[key]), func(value: String) -> void:
                callback.call(key_name, value)
            )

func _title_label(text: String) -> Label:
    var label: Label = Label.new()
    label.text = text
    return label

func _read_only_line(name: String, value: String) -> HBoxContainer:
    var row: HBoxContainer = HBoxContainer.new()

    var key_label: Label = Label.new()
    key_label.text = name
    key_label.custom_minimum_size = Vector2(120, 0)
    row.add_child(key_label)

    var value_label: Label = Label.new()
    value_label.text = value
    row.add_child(value_label)
    return row

func _add_text_editor(name: String, value: String, callback: Callable) -> void:
    var row: HBoxContainer = HBoxContainer.new()

    var key_label: Label = Label.new()
    key_label.text = name
    key_label.custom_minimum_size = Vector2(120, 0)
    row.add_child(key_label)

    var editor: LineEdit = LineEdit.new()
    editor.text = value
    editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    editor.text_changed.connect(func(new_text: String) -> void:
        callback.call(new_text)
    )
    row.add_child(editor)
    _inspector_container.add_child(row)

func _remove_condition(index: int) -> void:
    if _selected_row == null:
        return
    if index < 0 or index >= _selected_row.conditions.size():
        return
    if _selected_entry_kind == "condition":
        _selected_entry_kind = "event"
        _selected_entry_index = -1
    _selected_row.conditions.remove_at(index)
    refresh_rows()
    _rebuild_inspector()
    _mark_preview_dirty()

func _remove_action(index: int) -> void:
    if _selected_row == null:
        return
    if index < 0 or index >= _selected_row.actions.size():
        return
    if _selected_entry_kind == "action":
        _selected_entry_kind = "event"
        _selected_entry_index = -1
    _selected_row.actions.remove_at(index)
    refresh_rows()
    _rebuild_inspector()
    _mark_preview_dirty()

func _on_trigger_param_changed(key: String, value: String) -> void:
    if _selected_row == null:
        return
    _selected_row.trigger_params[key] = value
    _sync_trigger_resource(_selected_row)
    _mark_preview_dirty()

func _on_condition_param_changed(key: String, value: String, index: int) -> void:
    if _selected_row == null:
        return
    if index < 0 or index >= _selected_row.conditions.size():
        return
    var edited: ACECondition = _selected_row.conditions[index]
    edited.params[key] = value
    edited.parameters = edited.params.duplicate(true)
    _mark_preview_dirty()

func _on_action_param_changed(key: String, value: String, index: int) -> void:
    if _selected_row == null:
        return
    if index < 0 or index >= _selected_row.actions.size():
        return
    var edited_variant: Variant = _selected_row.actions[index]
    if edited_variant is ACEAction:
        var edited_action: ACEAction = edited_variant
        edited_action.params[key] = value
        edited_action.parameters = edited_action.params.duplicate(true)
        _mark_preview_dirty()

func _build_file_dialogs() -> void:
    _open_dialog = EditorFileDialog.new()
    _open_dialog.access = EditorFileDialog.ACCESS_RESOURCES
    _open_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
    _open_dialog.title = "Open Event Sheet"
    _open_dialog.add_filter("*.tres ; Event Sheet Resource")
    _open_dialog.add_filter("*.res ; Resource")
    _open_dialog.file_selected.connect(_on_open_path_selected)
    add_child(_open_dialog)

    _save_dialog = EditorFileDialog.new()
    _save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
    _save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
    _save_dialog.title = "Save Event Sheet As"
    _save_dialog.add_filter("*.tres ; Event Sheet Resource")
    _save_dialog.add_filter("*.res ; Resource")
    _save_dialog.file_selected.connect(_on_save_path_selected)
    add_child(_save_dialog)

func _on_open_sheet_requested() -> void:
    if _open_dialog != null:
        _open_dialog.popup_centered_ratio(0.7)
        return
    _open_sheet_from_path(FALLBACK_OPEN_PATH)

func _on_save_sheet_requested() -> void:
    if current_sheet == null:
        _set_status("No sheet loaded.")
        return
    if not current_sheet.resource_path.is_empty():
        _save_sheet_to_path(current_sheet.resource_path)
        return
    _on_save_sheet_as_requested()

func _on_save_sheet_as_requested() -> void:
    if current_sheet == null:
        _set_status("No sheet loaded.")
        return
    if _save_dialog != null:
        _save_dialog.current_path = current_sheet.resource_path if not current_sheet.resource_path.is_empty() else FALLBACK_SAVE_PATH
        _save_dialog.popup_centered_ratio(0.7)
        return
    _save_sheet_to_path(FALLBACK_SAVE_PATH)

func _on_open_path_selected(path: String) -> void:
    _open_sheet_from_path(path)

func _on_save_path_selected(path: String) -> void:
    _save_sheet_to_path(path)

func _open_sheet_from_path(path: String) -> void:
    var loaded: EventSheetResource = load(path) as EventSheetResource
    if loaded == null:
        _set_status("Failed to open sheet: %s" % path)
        return
    set_sheet(loaded)
    _set_status("Opened sheet: %s" % path)

func _save_sheet_to_path(path: String) -> void:
    if current_sheet == null:
        _set_status("No sheet loaded.")
        return
    var final_path: String = path
    if not final_path.ends_with(".tres"):
        final_path += ".tres"
    var err: Error = ResourceSaver.save(current_sheet, final_path)
    if err != OK:
        _set_status("Failed to save sheet: %s" % final_path)
        return
    current_sheet.take_over_path(final_path)
    _sheet_dirty = false
    _update_active_sheet_header()
    _set_status("Saved sheet: %s" % final_path)

func _clear_children(container: Node) -> void:
    for child: Node in container.get_children():
        container.remove_child(child)
        child.queue_free()

# ---------------------------------------------------------------------------
# Sheet Variables panel
# ---------------------------------------------------------------------------

## Rebuilds the Sheet Variables panel from current_sheet.variables.
## Uses the current dictionary-backed variable model until a dedicated SheetVariable resource exists.
func _rebuild_vars_panel() -> void:
    if _vars_list == null:
        return
    _clear_children(_vars_list)
    if current_sheet == null:
        return
    for var_key: Variant in current_sheet.variables.keys():
        var var_name: String = str(var_key)
        var descriptor: Variant = current_sheet.variables[var_key]
        if not (descriptor is Dictionary):
            descriptor = {"type": "int", "default": 0, "exported": true}
        _add_var_row_ui(var_name, descriptor)

## Builds the UI row for a single sheet variable entry (name, type, export, default, delete).
## Closures capture var_name by value so each row correctly targets its own variable.
func _add_var_row_ui(var_name: String, descriptor: Dictionary) -> void:
    var var_types: Array[String] = ["int", "float", "String", "bool", "NodePath", "Variant"]
    var container: VBoxContainer = VBoxContainer.new()

    var header: HBoxContainer = HBoxContainer.new()

    var name_edit: LineEdit = LineEdit.new()
    name_edit.text = var_name
    name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_edit.text_submitted.connect(func(new_name: String) -> void:
        _rename_variable(var_name, new_name)
    )
    header.add_child(name_edit)

    var type_opt: OptionButton = OptionButton.new()
    for type_str: String in var_types:
        type_opt.add_item(type_str)
    var current_type: String = str(descriptor.get("type", "int"))
    var type_index: int = var_types.find(current_type)
    if type_index < 0:
        type_index = 0
    type_opt.selected = type_index
    type_opt.item_selected.connect(func(index: int) -> void:
        _set_variable_type(var_name, var_types[index])
    )
    header.add_child(type_opt)

    var export_check: CheckBox = CheckBox.new()
    export_check.text = "Exp"
    export_check.button_pressed = bool(descriptor.get("exported", true))
    export_check.toggled.connect(func(is_on: bool) -> void:
        _set_variable_exported(var_name, is_on)
    )
    header.add_child(export_check)

    var delete_btn: Button = Button.new()
    delete_btn.text = "X"
    delete_btn.pressed.connect(func() -> void:
        _delete_variable(var_name)
    )
    header.add_child(delete_btn)

    container.add_child(header)

    var default_row: HBoxContainer = HBoxContainer.new()
    var default_label: Label = Label.new()
    default_label.text = "Default:"
    default_label.custom_minimum_size = Vector2(55, 0)
    default_row.add_child(default_label)

    var default_val: Variant = descriptor.get("default", null)
    var default_edit: LineEdit = LineEdit.new()
    default_edit.text = "" if default_val == null else str(default_val)
    default_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    default_edit.text_changed.connect(func(new_default: String) -> void:
        _set_variable_default(var_name, new_default)
    )
    default_row.add_child(default_edit)
    container.add_child(default_row)

    _vars_list.add_child(container)

func _on_add_variable_pressed() -> void:
    if current_sheet == null:
        return
    var base_name: String = "new_var"
    var candidate: String = base_name
    var counter: int = 1
    while current_sheet.variables.has(candidate):
        candidate = "%s_%d" % [base_name, counter]
        counter += 1
    current_sheet.variables[candidate] = {
        "type": "int",
        "default": 0,
        "exported": true
    }
    _rebuild_vars_panel()
    _rebuild_inspector()
    _mark_preview_dirty()

## Renames a sheet variable key without updating ACE param references.
## Validates the new name as a GDScript identifier and rejects duplicates.
func _rename_variable(old_name: String, new_name: String) -> void:
    if current_sheet == null:
        return
    var trimmed: String = new_name.strip_edges()
    if trimmed == old_name:
        return
    if not _is_valid_identifier_name(trimmed):
        _set_status("Invalid variable name: '%s'. Use letters, digits, and underscores, not starting with a digit." % trimmed)
        return
    if current_sheet.variables.has(trimmed):
        _set_status("Variable '%s' already exists." % trimmed)
        return
    var value: Variant = current_sheet.variables[old_name]
    current_sheet.variables.erase(old_name)
    current_sheet.variables[trimmed] = value
    _rebuild_vars_panel()
    _rebuild_inspector()
    _mark_preview_dirty()
    _set_status("Variable renamed to '%s'. Existing references are not updated automatically yet." % trimmed)

func _delete_variable(var_name: String) -> void:
    if current_sheet == null:
        return
    if _selected_entry_kind == "variable" and _selected_variable_name == var_name:
        _selected_entry_kind = "event"
        _selected_entry_index = -1
        _selected_variable_name = ""
        _selected_row = null
        _selected_group = null
    current_sheet.variables.erase(var_name)
    refresh_rows()
    _rebuild_vars_panel()
    _rebuild_inspector()
    _mark_preview_dirty()
    _set_status("Variable '%s' deleted." % var_name)

func _set_variable_type(var_name: String, type_name: String) -> void:
    if current_sheet == null or not current_sheet.variables.has(var_name):
        return
    var descriptor: Dictionary = current_sheet.variables[var_name]
    descriptor["type"] = type_name
    descriptor["default"] = _default_for_type(type_name)
    current_sheet.variables[var_name] = descriptor
    _rebuild_vars_panel()
    _mark_preview_dirty()

func _set_variable_default(var_name: String, default_str: String) -> void:
    if current_sheet == null or not current_sheet.variables.has(var_name):
        return
    var descriptor: Dictionary = current_sheet.variables[var_name]
    var type_name: String = str(descriptor.get("type", "Variant"))
    descriptor["default"] = _parse_default_value(default_str, type_name)
    current_sheet.variables[var_name] = descriptor
    _mark_preview_dirty()

func _set_variable_exported(var_name: String, is_exported: bool) -> void:
    if current_sheet == null or not current_sheet.variables.has(var_name):
        return
    var descriptor: Dictionary = current_sheet.variables[var_name]
    descriptor["exported"] = is_exported
    current_sheet.variables[var_name] = descriptor
    _mark_preview_dirty()

func _default_for_type(type_name: String) -> Variant:
    match type_name:
        "int": return 0
        "float": return 0.0
        "bool": return false
        "String": return ""
        "NodePath": return ""
        _: return null

## Parses a raw string entered by the user into a typed Variant for storage.
## Falls back to the string itself for unknown or freeform types like NodePath and Variant.
func _parse_default_value(text: String, type_name: String) -> Variant:
    match type_name:
        "int":
            if text.is_valid_int():
                return int(text)
            return 0
        "float":
            if text.is_valid_float():
                return float(text)
            return 0.0
        "bool":
            return text.to_lower() == "true" or text == "1"
        "String":
            return text
        _:
            return text

func _is_valid_identifier_name(value: String) -> bool:
    if value.is_empty():
        return false
    if _identifier_regex == null:
        _identifier_regex = RegEx.new()
        _identifier_regex.compile("^[A-Za-z_][A-Za-z0-9_]*$")
    return _identifier_regex.search(value) != null

# ---------------------------------------------------------------------------
# Variable-aware param picker
# ---------------------------------------------------------------------------

## Renders a variable picker for ACE params that reference sheet variables.
## Unknown existing values are preserved as extra options so older sheets do not lose data.
func _add_var_name_picker(name: String, current_value: String, callback: Callable) -> void:
    var row: HBoxContainer = HBoxContainer.new()

    var key_label: Label = Label.new()
    key_label.text = name
    key_label.custom_minimum_size = Vector2(120, 0)
    row.add_child(key_label)

    var var_keys: Array = current_sheet.variables.keys() if current_sheet != null else []
    if var_keys.is_empty():
        var editor: LineEdit = LineEdit.new()
        editor.text = current_value
        editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        editor.text_changed.connect(func(new_text: String) -> void:
            callback.call(new_text)
        )
        row.add_child(editor)
        _inspector_container.add_child(row)
        var hint: Label = Label.new()
        hint.text = "(no sheet variables — create one in Sheet Vars)"
        hint.add_theme_constant_override("margin_left", 24)
        _inspector_container.add_child(hint)
        return

    var picker: OptionButton = OptionButton.new()
    picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var current_index: int = -1
    var idx: int = 0
    for var_key: Variant in var_keys:
        var var_name_str: String = str(var_key)
        picker.add_item(var_name_str, idx)
        if var_name_str == current_value:
            current_index = idx
        idx += 1

    if current_index == -1 and not current_value.is_empty():
        picker.add_item(current_value, idx)
        current_index = idx
        idx += 1

    if current_index >= 0:
        picker.selected = current_index
    elif picker.item_count > 0:
        picker.selected = 0
        callback.call(picker.get_item_text(0))

    picker.item_selected.connect(func(index: int) -> void:
        callback.call(picker.get_item_text(index))
    )
    row.add_child(picker)
    _inspector_container.add_child(row)

# ---------------------------------------------------------------------------
# Copy / Paste / Duplicate / Delete
# ---------------------------------------------------------------------------

## Regenerates identities for a pasted row tree.
## This prevents copied rows/sub-events from sharing source-mapping IDs with originals.
func _regenerate_row_tree_identity(resource: Resource) -> void:
    if resource == null:
        return
    if resource.has_method("regenerate_uid"):
        resource.call("regenerate_uid")
    if resource is EventRow:
        var row: EventRow = resource
        for child: Resource in row.sub_events:
            _regenerate_row_tree_identity(child)

## Copies the selected event row into the editor-local clipboard.
## The clipboard stores a deep duplicate so later edits to the original don't corrupt the copy.
func _on_copy_requested() -> void:
    if current_sheet == null:
        _set_status("Open or create an Event Sheet before copying.")
        return
    if _selected_row == null:
        _set_status("Select an event row before copying.")
        return
    _row_clipboard = _selected_row.duplicate(true)
    _row_clipboard_kind = _selected_row.get_row_kind()
    _set_status("Copied event row.")

## Pastes the clipboard row after the selected row, or at the end if nothing is selected.
## Regenerates identities for the entire pasted row tree to avoid UID collisions with originals.
func _on_paste_requested() -> void:
    if current_sheet == null:
        _set_status("Open or create an Event Sheet before pasting.")
        return
    if _row_clipboard == null:
        _set_status("Nothing to paste.")
        return
    var pasted: EventRow = _row_clipboard.duplicate(true) as EventRow
    if pasted == null:
        _set_status("Clipboard does not contain a valid event row.")
        return
    _regenerate_row_tree_identity(pasted)
    var insert_index: int = current_sheet.events.size()
    if _selected_row != null:
        var sel_index: int = current_sheet.events.find(_selected_row)
        if sel_index >= 0:
            insert_index = sel_index + 1
    current_sheet.events.insert(insert_index, pasted)
    _selected_row = pasted
    refresh_rows()
    _rebuild_inspector()
    _mark_preview_dirty()
    _set_status("Pasted event row.")

## Duplicates the selected row by copying it to the clipboard and immediately pasting.
## Status is overwritten after paste to show "Duplicated" rather than "Pasted".
func _on_duplicate_requested() -> void:
    if _selected_row == null:
        _set_status("Select an event row to duplicate.")
        return
    _on_copy_requested()
    _on_paste_requested()
    _set_status("Duplicated event row.")

func _on_delete_requested() -> void:
    if _selected_row == null:
        _set_status("Select an event row to delete.")
        return
    _on_row_delete_requested(_selected_row)
    _set_status("Deleted event row.")

# ---------------------------------------------------------------------------
# Keyboard shortcuts
# ---------------------------------------------------------------------------

## Handles Ctrl+C/V/D and Delete/Backspace shortcuts for row operations.
## Skips handling when a text input widget has focus to avoid intercepting normal editing.
func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed:
        return
    var focus_owner: Control = get_viewport().gui_get_focus_owner() if get_viewport() != null else null
    if focus_owner is LineEdit or focus_owner is TextEdit or focus_owner is CodeEdit:
        return
    var ctrl: bool = event.ctrl_pressed or event.meta_pressed
    if ctrl:
        match event.keycode:
            KEY_C:
                _on_copy_requested()
                get_viewport().set_input_as_handled()
            KEY_V:
                _on_paste_requested()
                get_viewport().set_input_as_handled()
            KEY_D:
                _on_duplicate_requested()
                get_viewport().set_input_as_handled()
    elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
        _on_delete_requested()
        get_viewport().set_input_as_handled()
