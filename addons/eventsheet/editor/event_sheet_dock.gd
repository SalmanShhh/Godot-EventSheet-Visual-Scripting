@tool
class_name EventSheetDock
extends Control

const EVENT_SHEET_FILTERS := PackedStringArray(["*.tres ; EventSheetResource", "*.res ; EventSheetResource"])

var _toolbar: HBoxContainer = null
var _status_label: Label = null
var _split: HSplitContainer = null
var _scroll: ScrollContainer = null
var _viewport: EventSheetViewport = null
var _side_panel: VBoxContainer = null
var _preview_title: Label = null
var _preview_list: ItemList = null
var _global_var_list: ItemList = null
var _local_var_list: ItemList = null

var _current_sheet: EventSheetResource = null
var _current_sheet_path: String = ""
var _dirty: bool = false
var _ace_registry: EventSheetACERegistry = EventSheetACERegistry.new()
var _ace_sources: Array[Object] = []
var _clipboard: Dictionary = {}

var _ace_picker_window: Window = null
var _ace_picker_search: LineEdit = null
var _ace_picker_tree: Tree = null
var _ace_picker_hint: Label = null
var _ace_picker_context: Dictionary = {}

var _ace_params_dialog: ConfirmationDialog = null
var _ace_params_form: VBoxContainer = null
var _ace_params_fields: Dictionary = {}
var _ace_params_definition: ACEDefinition = null
var _ace_params_context: Dictionary = {}

var _variable_dialog: ConfirmationDialog = null
var _variable_scope_label: Label = null
var _variable_name_edit: LineEdit = null
var _variable_type_option: OptionButton = null
var _variable_default_edit: LineEdit = null
var _variable_scope: String = "global"

func _init() -> void:
    _build_ui()

func _ready() -> void:
    _build_ui()
    _build_ace_picker_window()
    _build_ace_params_dialog()
    _build_variable_dialog()
    _refresh_ace_registry()
    if _current_sheet == null:
        _current_sheet = _build_demo_sheet()
        _viewport.set_debug_overlay_states({
            "demo_overlap": "hit",
            "demo_attack": "step"
        })
    setup(_current_sheet)

func setup(sheet: EventSheetResource = null) -> void:
    _build_ui()
    if sheet == null:
        _current_sheet = _build_demo_sheet()
        _current_sheet_path = ""
        _viewport.set_debug_overlay_states({
            "demo_overlap": "hit",
            "demo_attack": "step"
        })
        _set_status("Loaded demo EventSheet.")
    else:
        _current_sheet = sheet
        _current_sheet_path = sheet.resource_path
        _viewport.set_debug_overlay_states({})
        _set_status("Loaded: %s" % (_current_sheet_path.get_file() if not _current_sheet_path.is_empty() else "(unsaved EventSheet)"))
    _dirty = false
    _refresh_ace_registry()
    _viewport.set_sheet(_current_sheet)
    _refresh_variable_panel()

func get_viewport_control() -> EventSheetViewport:
    return _viewport

func get_ace_registry() -> EventSheetACERegistry:
    return _ace_registry

func get_current_sheet() -> EventSheetResource:
    return _current_sheet

func set_auto_ace_sources(sources: Array[Object]) -> void:
    _release_ace_sources()
    _ace_sources = sources.duplicate()
    _refresh_ace_registry()

func _build_ui() -> void:
    if _toolbar != null:
        return
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL

    var root: VBoxContainer = VBoxContainer.new()
    root.name = "EventSheetWorkspaceRoot"
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(root)

    _toolbar = HBoxContainer.new()
    _toolbar.name = "EventSheetToolbar"
    _toolbar.add_theme_constant_override("separation", 4)
    root.add_child(_toolbar)

    _add_toolbar_button("Open", _on_open_requested)
    _add_toolbar_button("Save", _on_save_requested)
    _add_toolbar_button("Save As", _on_save_as_requested)
    _add_toolbar_separator()
    _add_toolbar_button("Add Event", _on_add_event_requested)
    _add_toolbar_button("Add Signal Event", _on_add_signal_event_requested)
    _add_toolbar_button("Add Condition", _on_add_condition_requested)
    _add_toolbar_button("Add Action", _on_add_action_requested)
    _add_toolbar_separator()
    _add_toolbar_button("Copy", _on_copy_requested)
    _add_toolbar_button("Paste", _on_paste_requested)
    _add_toolbar_separator()
    _add_toolbar_button("Add Global Var", _on_add_global_variable_requested)
    _add_toolbar_button("Add Local Var", _on_add_local_variable_requested)

    _split = HSplitContainer.new()
    _split.name = "EventSheetWorkspaceSplit"
    _split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _split.split_offset = 860
    root.add_child(_split)

    _scroll = ScrollContainer.new()
    _scroll.name = "EventSheetScroll"
    _scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _split.add_child(_scroll)

    _viewport = EventSheetViewport.new()
    _viewport.name = "EventSheetViewport"
    _viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _viewport.set_ace_registry(_ace_registry)
    _scroll.add_child(_viewport)

    _viewport.selection_changed.connect(_on_viewport_selection_changed)
    _viewport.row_drop_requested.connect(_on_row_drop_requested)
    _viewport.ace_preview_requested.connect(_on_ace_preview_requested)

    _side_panel = VBoxContainer.new()
    _side_panel.name = "EventSheetSidePanel"
    _side_panel.custom_minimum_size = Vector2(250.0, 220.0)
    _split.add_child(_side_panel)

    _preview_title = Label.new()
    _preview_title.name = "ACEPreviewTitle"
    _preview_title.text = "Dropped ACE Preview"
    _side_panel.add_child(_preview_title)

    _preview_list = ItemList.new()
    _preview_list.name = "ACEPreviewList"
    _preview_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _preview_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _preview_list.custom_minimum_size = Vector2(180.0, 160.0)
    _side_panel.add_child(_preview_list)

    var globals_label: Label = Label.new()
    globals_label.text = "Global Variables"
    _side_panel.add_child(globals_label)

    _global_var_list = ItemList.new()
    _global_var_list.name = "GlobalVariableList"
    _global_var_list.custom_minimum_size = Vector2(180.0, 100.0)
    _global_var_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _side_panel.add_child(_global_var_list)

    var locals_label: Label = Label.new()
    locals_label.text = "Local Variables (selected event)"
    _side_panel.add_child(locals_label)

    _local_var_list = ItemList.new()
    _local_var_list.name = "LocalVariableList"
    _local_var_list.custom_minimum_size = Vector2(180.0, 100.0)
    _local_var_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _side_panel.add_child(_local_var_list)

    _status_label = Label.new()
    _status_label.name = "EventSheetStatus"
    _status_label.text = "Ready"
    root.add_child(_status_label)

func _add_toolbar_button(text: String, callable: Callable) -> void:
    var button: Button = Button.new()
    button.text = text
    button.pressed.connect(callable)
    _toolbar.add_child(button)

func _add_toolbar_separator() -> void:
    var sep: VSeparator = VSeparator.new()
    _toolbar.add_child(sep)

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event: InputEventKey = event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    if key_event.ctrl_pressed or key_event.meta_pressed:
        if key_event.keycode == KEY_C:
            _on_copy_requested()
            accept_event()
        elif key_event.keycode == KEY_V:
            _on_paste_requested()
            accept_event()
        elif key_event.keycode == KEY_S:
            _on_save_requested()
            accept_event()
        elif key_event.keycode == KEY_O:
            _on_open_requested()
            accept_event()

func _on_open_requested() -> void:
    var dialog: FileDialog = FileDialog.new()
    dialog.title = "Open EventSheet"
    dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    dialog.access = FileDialog.ACCESS_RESOURCES
    dialog.filters = EVENT_SHEET_FILTERS
    dialog.file_selected.connect(_load_sheet_from_path)
    dialog.canceled.connect(func() -> void: dialog.queue_free())
    add_child(dialog)
    dialog.popup_centered(Vector2i(860, 580))

func _load_sheet_from_path(path: String) -> void:
    var loaded: Resource = ResourceLoader.load(path)
    if loaded is EventSheetResource:
        setup(loaded as EventSheetResource)
        _current_sheet_path = path
        _dirty = false
        return
    _set_status("Open failed: %s is not an EventSheetResource." % path.get_file(), true)

func _on_save_requested() -> void:
    if _current_sheet == null:
        _set_status("Nothing to save.", true)
        return
    if _current_sheet_path.is_empty() and _current_sheet.resource_path.is_empty():
        _on_save_as_requested()
        return
    var save_path: String = _current_sheet_path if not _current_sheet_path.is_empty() else _current_sheet.resource_path
    var err: Error = ResourceSaver.save(_current_sheet, save_path)
    if err == OK:
        _current_sheet.take_over_path(save_path)
        _current_sheet_path = save_path
        _dirty = false
        _set_status("Saved: %s" % save_path.get_file())
    else:
        _set_status("Save failed (error %d)." % err, true)

func _on_save_as_requested() -> void:
    if _current_sheet == null:
        _set_status("Nothing to save.", true)
        return
    var dialog: FileDialog = FileDialog.new()
    dialog.title = "Save EventSheet As"
    dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    dialog.access = FileDialog.ACCESS_RESOURCES
    dialog.filters = EVENT_SHEET_FILTERS
    if not _current_sheet_path.is_empty():
        dialog.current_path = _current_sheet_path
    elif not _current_sheet.resource_path.is_empty():
        dialog.current_path = _current_sheet.resource_path
    dialog.file_selected.connect(_save_sheet_to_path)
    dialog.canceled.connect(func() -> void: dialog.queue_free())
    add_child(dialog)
    dialog.popup_centered(Vector2i(860, 580))

func _save_sheet_to_path(path: String) -> void:
    var err: Error = ResourceSaver.save(_current_sheet, path)
    if err == OK:
        _current_sheet.take_over_path(path)
        _current_sheet_path = path
        _dirty = false
        _set_status("Saved as: %s" % path.get_file())
    else:
        _set_status("Save failed (error %d)." % err, true)

func _on_add_event_requested() -> void:
    if not _ensure_sheet_for_editing():
        return
    _open_ace_picker("new_event", false)

func _on_add_signal_event_requested() -> void:
    if not _ensure_sheet_for_editing():
        return
    _open_ace_picker("new_event", true)

func _on_add_condition_requested() -> void:
    if not _ensure_selected_event():
        return
    _open_ace_picker("append_condition", false)

func _on_add_action_requested() -> void:
    if not _ensure_selected_event():
        return
    _open_ace_picker("append_action", false)

func _on_copy_requested() -> void:
    var context: Dictionary = _viewport.get_selected_context()
    var selected_resource: Resource = context.get("source_resource", null)
    if selected_resource == null:
        _set_status("Nothing selected to copy.", true)
        return
    var metadata: Dictionary = context.get("span_metadata", {})
    if selected_resource is EventRow and not metadata.is_empty():
        var event_row: EventRow = selected_resource as EventRow
        var kind: String = str(metadata.get("kind", ""))
        var ace_index: int = int(metadata.get("ace_index", -1))
        if kind == "condition" and ace_index >= 0 and ace_index < event_row.conditions.size():
            _clipboard = {"type": "condition", "payload": event_row.conditions[ace_index].duplicate(true)}
            _set_status("Copied condition.")
            return
        if kind == "action" and ace_index >= 0 and ace_index < event_row.actions.size() and event_row.actions[ace_index] is ACEAction:
            _clipboard = {"type": "action", "payload": (event_row.actions[ace_index] as ACEAction).duplicate(true)}
            _set_status("Copied action.")
            return
        if kind == "trigger" and event_row.trigger != null:
            _clipboard = {"type": "trigger", "payload": event_row.trigger.duplicate(true)}
            _set_status("Copied trigger.")
            return
    _clipboard = {"type": "row", "payload": selected_resource.duplicate(true)}
    _set_status("Copied row.")

func _on_paste_requested() -> void:
    if _clipboard.is_empty():
        _set_status("Clipboard is empty.", true)
        return
    if not _ensure_sheet_for_editing():
        return
    var clip_type: String = str(_clipboard.get("type", ""))
    var payload: Variant = _clipboard.get("payload", null)
    var context: Dictionary = _viewport.get_selected_context()
    var selected_resource: Resource = context.get("source_resource", null)
    match clip_type:
        "row":
            if payload is Resource:
                _insert_row_below_selection((payload as Resource).duplicate(true))
                _mark_dirty("Pasted row.")
        "condition":
            if selected_resource is EventRow and payload is ACECondition:
                (selected_resource as EventRow).conditions.append((payload as ACECondition).duplicate(true))
                _mark_dirty("Pasted condition.")
        "action":
            if selected_resource is EventRow and payload is ACEAction:
                (selected_resource as EventRow).actions.append((payload as ACEAction).duplicate(true))
                _mark_dirty("Pasted action.")
        "trigger":
            if selected_resource is EventRow and payload is ACECondition:
                (selected_resource as EventRow).trigger = (payload as ACECondition).duplicate(true)
                _mark_dirty("Pasted trigger.")
    _refresh_after_edit()

func _on_add_global_variable_requested() -> void:
    if not _ensure_sheet_for_editing():
        return
    _open_variable_dialog("global")

func _on_add_local_variable_requested() -> void:
    if not _ensure_selected_event():
        return
    _open_variable_dialog("local")

func _ensure_sheet_for_editing() -> bool:
    if _current_sheet != null:
        return true
    _set_status("Create or open an EventSheet first.", true)
    return false

func _ensure_selected_event() -> bool:
    if not _ensure_sheet_for_editing():
        return false
    var selected: Resource = _viewport.get_selected_context().get("source_resource", null)
    if selected is EventRow:
        return true
    _set_status("Select an event row first.", true)
    return false

func _build_ace_picker_window() -> void:
    if _ace_picker_window != null:
        return
    _ace_picker_window = Window.new()
    _ace_picker_window.title = "Select ACE"
    _ace_picker_window.visible = false
    _ace_picker_window.min_size = Vector2i(640, 420)
    add_child(_ace_picker_window)

    var content: VBoxContainer = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _ace_picker_window.add_child(content)

    _ace_picker_search = LineEdit.new()
    _ace_picker_search.placeholder_text = "Search actions, conditions, triggers..."
    _ace_picker_search.text_changed.connect(func(_text: String) -> void: _refresh_ace_picker_tree())
    content.add_child(_ace_picker_search)

    _ace_picker_hint = Label.new()
    _ace_picker_hint.text = ""
    content.add_child(_ace_picker_hint)

    _ace_picker_tree = Tree.new()
    _ace_picker_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _ace_picker_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _ace_picker_tree.columns = 2
    _ace_picker_tree.set_column_title(0, "ACE")
    _ace_picker_tree.set_column_title(1, "Category")
    _ace_picker_tree.set_column_titles_visible(true)
    _ace_picker_tree.item_activated.connect(_on_ace_picker_item_activated)
    content.add_child(_ace_picker_tree)

func _open_ace_picker(mode: String, signals_only: bool) -> void:
    if _ace_picker_window == null:
        _build_ace_picker_window()
    _ace_picker_context = {
        "mode": mode,
        "signals_only": signals_only,
        "selected_resource": _viewport.get_selected_context().get("source_resource", null)
    }
    _ace_picker_search.text = ""
    _ace_picker_hint.text = _build_picker_hint(mode, signals_only)
    _refresh_ace_picker_tree()
    _ace_picker_window.popup_centered(Vector2i(720, 520))

func _build_picker_hint(mode: String, signals_only: bool) -> String:
    if signals_only:
        return "Select a signal trigger ACE to create a signal event."
    match mode:
        "append_condition":
            return "Select a condition or trigger ACE to append to the selected event."
        "append_action":
            return "Select an action ACE to append to the selected event."
        _:
            return "Select an ACE to create a new event."

func _refresh_ace_picker_tree() -> void:
    if _ace_picker_tree == null:
        return
    _ace_picker_tree.clear()
    var root: TreeItem = _ace_picker_tree.create_item()
    var query: String = _ace_picker_search.text
    var mode: String = str(_ace_picker_context.get("mode", "new_event"))
    var signals_only: bool = bool(_ace_picker_context.get("signals_only", false))
    var definitions: Array[ACEDefinition] = _ace_registry.search(query)
    var category_nodes: Dictionary = {}
    for definition in definitions:
        if not _is_definition_allowed_for_mode(definition, mode, signals_only):
            continue
        var category: String = definition.category
        if category.is_empty():
            category = "General"
        if not category_nodes.has(category):
            var category_item: TreeItem = _ace_picker_tree.create_item(root)
            category_item.set_text(0, category)
            category_nodes[category] = category_item
        var item: TreeItem = _ace_picker_tree.create_item(category_nodes[category])
        item.set_text(0, "%s — %s" % [definition.provider_id, definition.display_name])
        item.set_text(1, category)
        item.set_metadata(0, definition)

func _is_definition_allowed_for_mode(definition: ACEDefinition, mode: String, signals_only: bool) -> bool:
    if definition == null:
        return false
    if signals_only:
        return definition.ace_type == ACEDefinition.ACEType.TRIGGER and definition.category.to_lower().find("signal") != -1
    match mode:
        "append_condition":
            return definition.ace_type in [ACEDefinition.ACEType.CONDITION, ACEDefinition.ACEType.TRIGGER]
        "append_action":
            return definition.ace_type == ACEDefinition.ACEType.ACTION
        _:
            return definition.ace_type in [ACEDefinition.ACEType.TRIGGER, ACEDefinition.ACEType.CONDITION, ACEDefinition.ACEType.ACTION]

func _on_ace_picker_item_activated() -> void:
    var item: TreeItem = _ace_picker_tree.get_selected()
    if item == null:
        return
    var definition: ACEDefinition = item.get_metadata(0)
    if definition == null:
        return
    if definition.parameters.is_empty():
        _apply_ace_definition(definition, {}, _ace_picker_context)
        _ace_picker_window.hide()
        return
    _ace_picker_window.hide()
    _open_ace_params_dialog(definition, _ace_picker_context)

func _build_ace_params_dialog() -> void:
    if _ace_params_dialog != null:
        return
    _ace_params_dialog = ConfirmationDialog.new()
    _ace_params_dialog.title = "ACE Parameters"
    _ace_params_dialog.visible = false
    _ace_params_dialog.confirmed.connect(_on_ace_params_confirmed)
    add_child(_ace_params_dialog)

    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(520.0, 260.0)
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _ace_params_dialog.add_child(scroll)

    _ace_params_form = VBoxContainer.new()
    _ace_params_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_ace_params_form)

func _open_ace_params_dialog(definition: ACEDefinition, context: Dictionary) -> void:
    _ace_params_definition = definition
    _ace_params_context = context.duplicate(true)
    _ace_params_fields.clear()
    for child in _ace_params_form.get_children():
        _ace_params_form.remove_child(child)
        child.queue_free()
    for parameter in definition.parameters:
        if not (parameter is Dictionary):
            continue
        var param_dict: Dictionary = parameter
        var row: HBoxContainer = HBoxContainer.new()
        var label: Label = Label.new()
        var key: String = str(param_dict.get("id", ""))
        label.text = str(param_dict.get("display_name", key))
        label.custom_minimum_size = Vector2(160.0, 0.0)
        row.add_child(label)
        var field: Control = _create_param_field(param_dict)
        field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(field)
        _ace_params_form.add_child(row)
        _ace_params_fields[key] = field
    _ace_params_dialog.title = "%s Parameters" % definition.display_name
    _ace_params_dialog.popup_centered(Vector2i(560, 360))

func _create_param_field(param_dict: Dictionary) -> Control:
    var field_type: int = int(param_dict.get("type", TYPE_NIL))
    var default_value: Variant = param_dict.get("default_value", "")
    if field_type == TYPE_BOOL:
        var check: CheckBox = CheckBox.new()
        check.button_pressed = str(default_value).to_lower() in ["true", "1"]
        return check
    if field_type in [TYPE_INT, TYPE_FLOAT]:
        var spin: SpinBox = SpinBox.new()
        spin.step = 1.0 if field_type == TYPE_INT else 0.1
        spin.allow_greater = true
        spin.allow_lesser = true
        spin.value = float(default_value)
        return spin
    var edit: LineEdit = LineEdit.new()
    edit.text = str(default_value)
    return edit

func _on_ace_params_confirmed() -> void:
    if _ace_params_definition == null:
        return
    var values: Dictionary = {}
    for key in _ace_params_fields.keys():
        values[str(key)] = _extract_field_value(_ace_params_fields[key])
    _apply_ace_definition(_ace_params_definition, values, _ace_params_context)
    _ace_params_definition = null
    _ace_params_context.clear()

func _extract_field_value(field: Control) -> Variant:
    if field is CheckBox:
        return (field as CheckBox).button_pressed
    if field is SpinBox:
        var spin: SpinBox = field as SpinBox
        if is_equal_approx(spin.step, 1.0):
            return int(spin.value)
        return spin.value
    if field is LineEdit:
        return (field as LineEdit).text
    return ""

func _apply_ace_definition(definition: ACEDefinition, params: Dictionary, context: Dictionary) -> void:
    if definition == null:
        return
    var mode: String = str(context.get("mode", "new_event"))
    var selected_resource: Resource = context.get("selected_resource", null)
    match mode:
        "append_condition":
            if selected_resource is EventRow:
                var target_event: EventRow = selected_resource as EventRow
                var condition_entry: ACECondition = _create_condition_from_definition(definition, params)
                if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
                    target_event.trigger = condition_entry
                else:
                    target_event.conditions.append(condition_entry)
                _mark_dirty("Added condition.")
        "append_action":
            if selected_resource is EventRow:
                var action_entry: ACEAction = _create_action_from_definition(definition, params)
                (selected_resource as EventRow).actions.append(action_entry)
                _mark_dirty("Added action.")
        _:
            var event_row: EventRow = EventRow.new()
            if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
                event_row.trigger = _create_condition_from_definition(definition, params)
            elif definition.ace_type == ACEDefinition.ACEType.CONDITION:
                event_row.conditions.append(_create_condition_from_definition(definition, params))
            elif definition.ace_type == ACEDefinition.ACEType.ACTION:
                event_row.actions.append(_create_action_from_definition(definition, params))
            _insert_row_below_selection(event_row)
            _mark_dirty("Added event.")
    _refresh_after_edit()

func _create_condition_from_definition(definition: ACEDefinition, params: Dictionary) -> ACECondition:
    var condition: ACECondition = ACECondition.new()
    condition.provider_id = definition.provider_id
    condition.ace_id = definition.id
    condition.params = params.duplicate(true)
    return condition

func _create_action_from_definition(definition: ACEDefinition, params: Dictionary) -> ACEAction:
    var action: ACEAction = ACEAction.new()
    action.provider_id = definition.provider_id
    action.ace_id = definition.id
    action.params = params.duplicate(true)
    return action

func _insert_row_below_selection(row_resource: Resource) -> void:
    if _current_sheet == null or row_resource == null:
        return
    var selected_resource: Resource = _viewport.get_selected_context().get("source_resource", null)
    if selected_resource == null:
        _current_sheet.events.append(row_resource)
        return
    var location: Dictionary = _find_resource_location(selected_resource)
    var container: Array = location.get("container", _current_sheet.events)
    var index: int = int(location.get("index", container.size() - 1))
    container.insert(index + 1, row_resource)

func _find_resource_location(target: Resource) -> Dictionary:
    return _find_resource_location_in_array(target, _current_sheet.events)

func _find_resource_location_in_array(target: Resource, container: Array) -> Dictionary:
    for index in range(container.size()):
        var entry: Resource = container[index]
        if entry == target:
            return {"container": container, "index": index}
        if entry is EventGroup:
            var group_children: Array = _group_children_array(entry as EventGroup)
            var nested_group: Dictionary = _find_resource_location_in_array(target, group_children)
            if not nested_group.is_empty():
                return nested_group
        elif entry is EventRow:
            var nested_event: Dictionary = _find_resource_location_in_array(target, (entry as EventRow).sub_events)
            if not nested_event.is_empty():
                return nested_event
    return {}

func _group_children_array(group: EventGroup) -> Array:
    if not group.events.is_empty():
        return group.events
    return group.rows

func _on_row_drop_requested(source_row: EventRowData, target_row: EventRowData) -> void:
    if source_row == null or target_row == null or _current_sheet == null:
        return
    var source_resource: Resource = source_row.source_resource
    var target_resource: Resource = target_row.source_resource
    if source_resource == null or target_resource == null or source_resource == target_resource:
        return
    var source_location: Dictionary = _find_resource_location(source_resource)
    var target_location: Dictionary = _find_resource_location(target_resource)
    if source_location.is_empty() or target_location.is_empty():
        return
    var source_container: Array = source_location.get("container", [])
    var target_container: Array = target_location.get("container", [])
    var source_index: int = int(source_location.get("index", -1))
    var target_index: int = int(target_location.get("index", -1))
    if source_index < 0 or target_index < 0:
        return
    source_container.remove_at(source_index)
    if source_container == target_container and source_index < target_index:
        target_index -= 1
    target_container.insert(target_index, source_resource)
    _mark_dirty("Moved row via drag and drop.")
    _refresh_after_edit()

func _on_ace_preview_requested(source_label: String, definitions: Array[ACEDefinition]) -> void:
    _preview_title.text = "Dropped ACE Preview — %s (%d)" % [source_label, definitions.size()]
    _preview_list.clear()
    for definition in definitions:
        _preview_list.add_item("[%s] %s" % [_ace_type_label(definition.ace_type), definition.format_display()])
    if definitions.is_empty():
        _preview_list.add_item("No ACE definitions were generated from this drop payload.")

func _ace_type_label(ace_type: int) -> String:
    match ace_type:
        ACEDefinition.ACEType.CONDITION:
            return "Condition"
        ACEDefinition.ACEType.TRIGGER:
            return "Trigger"
        ACEDefinition.ACEType.EXPRESSION:
            return "Expression"
        _:
            return "Action"

func _on_viewport_selection_changed(_row_data: EventRowData) -> void:
    _refresh_variable_panel()

func _build_variable_dialog() -> void:
    if _variable_dialog != null:
        return
    _variable_dialog = ConfirmationDialog.new()
    _variable_dialog.title = "Create Variable"
    _variable_dialog.visible = false
    _variable_dialog.confirmed.connect(_on_variable_dialog_confirmed)
    add_child(_variable_dialog)

    var form: VBoxContainer = VBoxContainer.new()
    form.custom_minimum_size = Vector2(420.0, 180.0)
    _variable_dialog.add_child(form)

    _variable_scope_label = Label.new()
    form.add_child(_variable_scope_label)

    var name_row: HBoxContainer = HBoxContainer.new()
    var name_label: Label = Label.new()
    name_label.text = "Name"
    name_label.custom_minimum_size = Vector2(120.0, 0.0)
    name_row.add_child(name_label)
    _variable_name_edit = LineEdit.new()
    _variable_name_edit.placeholder_text = "health"
    _variable_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_row.add_child(_variable_name_edit)
    form.add_child(name_row)

    var type_row: HBoxContainer = HBoxContainer.new()
    var type_label: Label = Label.new()
    type_label.text = "Type"
    type_label.custom_minimum_size = Vector2(120.0, 0.0)
    type_row.add_child(type_label)
    _variable_type_option = OptionButton.new()
    for option in ["int", "float", "bool", "String", "Variant"]:
        _variable_type_option.add_item(option)
    _variable_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    type_row.add_child(_variable_type_option)
    form.add_child(type_row)

    var default_row: HBoxContainer = HBoxContainer.new()
    var default_label: Label = Label.new()
    default_label.text = "Default"
    default_label.custom_minimum_size = Vector2(120.0, 0.0)
    default_row.add_child(default_label)
    _variable_default_edit = LineEdit.new()
    _variable_default_edit.placeholder_text = "0"
    _variable_default_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    default_row.add_child(_variable_default_edit)
    form.add_child(default_row)

func _open_variable_dialog(scope: String) -> void:
    if _variable_dialog == null:
        _build_variable_dialog()
    _variable_scope = scope
    _variable_scope_label.text = "Scope: %s" % scope.capitalize()
    _variable_name_edit.text = ""
    _variable_default_edit.text = ""
    _variable_type_option.selected = 0
    _variable_dialog.popup_centered(Vector2i(440, 220))

func _on_variable_dialog_confirmed() -> void:
    var name: String = _variable_name_edit.text.strip_edges()
    if name.is_empty():
        _set_status("Variable name is required.", true)
        return
    var type_name: String = _variable_type_option.get_item_text(_variable_type_option.selected)
    var default_value: Variant = _parse_variable_default(type_name, _variable_default_edit.text)
    if _variable_scope == "global":
        _current_sheet.variables[name] = {
            "type": type_name,
            "default": default_value
        }
        _mark_dirty("Added global variable %s." % name)
    else:
        var selected: Resource = _viewport.get_selected_context().get("source_resource", null)
        if not (selected is EventRow):
            _set_status("Select an event row for local variable creation.", true)
            return
        var local_var: LocalVariable = LocalVariable.new()
        local_var.name = name
        local_var.type_name = type_name
        local_var.type = _type_from_name(type_name)
        local_var.default_value = default_value
        (selected as EventRow).local_variables.append(local_var)
        _mark_dirty("Added local variable %s." % name)
    _refresh_after_edit()

func _parse_variable_default(type_name: String, raw: String) -> Variant:
    var value: String = raw.strip_edges()
    match type_name:
        "int":
            return int(value) if not value.is_empty() else 0
        "float":
            return float(value) if not value.is_empty() else 0.0
        "bool":
            return value.to_lower() in ["true", "1", "yes"]
        "String":
            return value
        _:
            return value

func _type_from_name(type_name: String) -> int:
    match type_name:
        "int":
            return TYPE_INT
        "float":
            return TYPE_FLOAT
        "bool":
            return TYPE_BOOL
        "String":
            return TYPE_STRING
        _:
            return TYPE_NIL

func _refresh_variable_panel() -> void:
    if _global_var_list == null or _local_var_list == null:
        return
    _global_var_list.clear()
    _local_var_list.clear()
    if _current_sheet != null:
        var names: Array = _current_sheet.variables.keys()
        names.sort()
        for var_name in names:
            var descriptor: Dictionary = _current_sheet.variables.get(var_name, {})
            _global_var_list.add_item("%s : %s = %s" % [var_name, str(descriptor.get("type", "Variant")), str(descriptor.get("default", ""))])
    var selected_resource: Resource = _viewport.get_selected_context().get("source_resource", null)
    if selected_resource is EventRow:
        for local_var in (selected_resource as EventRow).local_variables:
            if local_var == null:
                continue
            _local_var_list.add_item("%s : %s = %s" % [local_var.name, local_var.type_name, str(local_var.default_value)])

func _refresh_after_edit() -> void:
    if _viewport == null:
        return
    _viewport.set_sheet(_current_sheet)
    _refresh_variable_panel()

func _mark_dirty(message: String) -> void:
    _dirty = true
    _set_status("%s%s" % [message, " *" if _dirty else ""])

func _set_status(text: String, is_error: bool = false) -> void:
    if _status_label == null:
        return
    _status_label.text = text
    _status_label.modulate = Color(1.0, 0.48, 0.48) if is_error else Color(1.0, 1.0, 1.0)

func _refresh_ace_registry() -> void:
    if _ace_registry == null:
        _ace_registry = EventSheetACERegistry.new()
    var sources: Array[Object] = _ace_sources.duplicate()
    if sources.is_empty():
        _release_ace_sources()
        sources = _build_default_ace_sources()
        _ace_sources = sources.duplicate()
    _ace_registry.refresh_from_sources(sources, true)
    if _viewport != null:
        _viewport.set_ace_registry(_ace_registry)

func _build_default_ace_sources() -> Array[Object]:
    var demo_script: Script = load("res://addons/eventsheet/runtime/demo_gameplay_actor.gd")
    if demo_script == null or not demo_script.can_instantiate():
        return []
    var demo_source: Variant = demo_script.new()
    if demo_source is Object:
        return [demo_source]
    return []

func _build_demo_sheet() -> EventSheetResource:
    var sheet := EventSheetResource.new()
    sheet.host_class = "CharacterBody2D"
    sheet.variables["health"] = {"type": "int", "default": 100}
    sheet.variables["score"] = {"type": "int", "default": 0}

    var intro_comment := CommentRow.new()
    intro_comment.text = "Drag a node into the viewport to preview reflected ACEs."
    sheet.events.append(intro_comment)

    var encounter_group := EventGroup.new()
    encounter_group.name = _get_demo_provider_id()
    encounter_group.group_name = encounter_group.name

    var overlap_event := EventRow.new()
    overlap_event.event_uid = "demo_overlap"
    overlap_event.trigger = _make_condition(_get_demo_provider_id(), "signal:died", {})
    overlap_event.conditions = [_make_condition(_get_demo_provider_id(), "method:is_dead", {})]
    overlap_event.actions = [
        _make_action(_get_demo_provider_id(), "set:health", {"value": "100"}),
        _make_action(_get_demo_provider_id(), "method:heal", {"amount": "25"})
    ]
    overlap_event.comment = "Auto-generated gameplay vocabulary"

    var child_event := EventRow.new()
    child_event.event_uid = "demo_attack"
    child_event.conditions = [_make_condition("Core", "Always", {})]
    child_event.actions = [_make_action(_get_demo_provider_id(), "method:take_damage", {"amount": "10"})]
    overlap_event.sub_events.append(child_event)

    encounter_group.events.append(overlap_event)
    sheet.events.append(encounter_group)

    var movement_event := EventRow.new()
    movement_event.event_uid = "demo_movement"
    movement_event.trigger = _make_condition("Core", "OnProcess", {})
    movement_event.actions = [
        _make_action(_get_demo_provider_id(), "add:health", {"amount": "5"}),
        _make_action(_get_demo_provider_id(), "method:jump", {})
    ]
    sheet.events.append(movement_event)

    return sheet

func _make_condition(provider_id: String, ace_id: String, params: Dictionary) -> ACECondition:
    var condition := ACECondition.new()
    condition.provider_id = provider_id
    condition.ace_id = ace_id
    condition.params = params.duplicate(true)
    return condition

func _make_action(provider_id: String, ace_id: String, params: Dictionary) -> ACEAction:
    var action := ACEAction.new()
    action.provider_id = provider_id
    action.ace_id = ace_id
    action.params = params.duplicate(true)
    return action

func _get_demo_provider_id() -> String:
    if _ace_registry != null:
        var reflected_providers: PackedStringArray = _ace_registry.get_reflected_provider_ids()
        if not reflected_providers.is_empty():
            return reflected_providers[0]
    return "Core"

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        _release_ace_sources()

func _release_ace_sources() -> void:
    for source_object in _ace_sources:
        if source_object is Node:
            (source_object as Node).free()
    _ace_sources.clear()
