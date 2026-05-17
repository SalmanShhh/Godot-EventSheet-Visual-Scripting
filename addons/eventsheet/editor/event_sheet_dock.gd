@tool
class_name EventSheetDock
extends Control

const EVENT_SHEET_FILTERS: Array[String] = ["*.tres ; EventSheetResource", "*.res ; EventSheetResource"]

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
var _editor_param_store: EditorParamStore = EditorParamStore.new()
var _param_resolver: ParamDefaultResolver = ParamDefaultResolver.new()
var _exposed_node: EventSheetExposedNode = EventSheetExposedNode.new()
var _ace_sources: Array[Object] = []
var _clipboard: Dictionary = {}
var _undo_redo_adapter: EventSheetUndoRedoAdapter = EventSheetUndoRedoAdapter.new()

# ── Extracted sub-components ─────────────────────────────────────────────────
var _ace_picker: ACEPickerDialog = ACEPickerDialog.new()
var _ace_params: ACEParamsDialog = ACEParamsDialog.new()
var _variable_dlg: VariableDialog = VariableDialog.new()

func _init() -> void:
    if not _undo_redo_adapter.has_manager():
        _undo_redo_adapter.set_manager(UndoRedo.new())
    _build_ui()

func _ready() -> void:
    _build_ui()
    _param_resolver.set_param_store(_editor_param_store)
    _ace_picker.init_dialog(self, _ace_registry)
    _ace_picker.ace_selected.connect(_on_ace_picker_selected)
    _ace_params.init_dialog(self)
    _ace_params.params_confirmed.connect(_on_ace_params_confirmed)
    _variable_dlg.init_dialog(self)
    _variable_dlg.variable_confirmed.connect(_on_variable_dialog_confirmed)
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
    _clear_undo_history()
    _refresh_ace_registry()
    _viewport.set_sheet(_current_sheet)
    _refresh_exposed_node()
    _refresh_variable_panel()

func get_viewport_control() -> EventSheetViewport:
    return _viewport

func get_ace_registry() -> EventSheetACERegistry:
    return _ace_registry

func get_current_sheet() -> EventSheetResource:
    return _current_sheet

func get_editor_param_store() -> EditorParamStore:
    return _editor_param_store

func get_exposed_node() -> EventSheetExposedNode:
    return _exposed_node

func set_undo_redo_manager(undo_redo: Variant) -> void:
    if undo_redo == null:
        return
    _undo_redo_adapter.set_manager(undo_redo)
    if _exposed_node != null:
        _exposed_node.set_undo_redo_manager(_undo_redo_adapter.get_manager())

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
    _add_toolbar_button("Undo", _on_undo_requested)
    _add_toolbar_button("Redo", _on_redo_requested)
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
    _viewport.ace_picker_requested.connect(_on_viewport_ace_picker_requested)
    _viewport.span_edit_requested.connect(_on_viewport_span_edit_requested)
    _viewport.set_external_span_edit_handler_enabled(true)

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

    _exposed_node.name = "EventSheetExposedParams"
    add_child(_exposed_node)
    _exposed_node.setup(_ace_registry, _editor_param_store, _current_sheet, _param_resolver)
    _exposed_node.set_undo_redo_manager(_undo_redo_adapter.get_manager())

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
    if key_event.keycode == KEY_ESCAPE and _ace_picker.is_open():
        _ace_picker.close()
        accept_event()
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
        elif key_event.keycode == KEY_Z and key_event.shift_pressed:
            _on_redo_requested()
            accept_event()
        elif key_event.keycode == KEY_Z:
            _on_undo_requested()
            accept_event()
        elif key_event.keycode == KEY_Y:
            _on_redo_requested()
            accept_event()
        elif key_event.keycode == KEY_O:
            _on_open_requested()
            accept_event()

## Closes the ACE picker when the user clicks anywhere outside the popup rect.
func _gui_input(event: InputEvent) -> void:
    if not (event is InputEventMouseButton):
        return
    var mouse_event: InputEventMouseButton = event as InputEventMouseButton
    if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
        return
    if not _ace_picker.is_open():
        return
    if _ace_picker.get_popup_rect().has_point(mouse_event.position):
        return
    _ace_picker.close()

func _on_open_requested() -> void:
    var dialog: FileDialog = FileDialog.new()
    dialog.title = "Open EventSheet"
    dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    dialog.access = FileDialog.ACCESS_RESOURCES
    dialog.filters = PackedStringArray(EVENT_SHEET_FILTERS)
    dialog.current_dir = _suggest_sheet_directory()
    dialog.file_selected.connect(func(path: String) -> void:
        _load_sheet_from_path(path)
        dialog.queue_free()
    )
    dialog.canceled.connect(func() -> void: dialog.queue_free())
    add_child(dialog)
    dialog.popup_centered(Vector2i(860, 580))

func _load_sheet_from_path(path: String) -> void:
    var resolved_path: String = path.strip_edges()
    if resolved_path.is_empty():
        _set_status("Open failed: no file selected.", true)
        return
    var loaded: Resource = ResourceLoader.load(resolved_path)
    if loaded is EventSheetResource:
        setup(loaded as EventSheetResource)
        _current_sheet_path = resolved_path
        _dirty = false
        _clear_undo_history()
        return
    _set_status("Open failed: %s is not an EventSheetResource." % resolved_path.get_file(), true)

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
    dialog.filters = PackedStringArray(EVENT_SHEET_FILTERS)
    dialog.current_path = _build_initial_save_path()
    dialog.file_selected.connect(func(path: String) -> void:
        _save_sheet_to_path(path)
        dialog.queue_free()
    )
    dialog.canceled.connect(func() -> void: dialog.queue_free())
    add_child(dialog)
    dialog.popup_centered(Vector2i(860, 580))

func _save_sheet_to_path(path: String) -> void:
    if _current_sheet == null:
        _set_status("Nothing to save.", true)
        return
    var resolved_path: String = _normalize_sheet_save_path(path)
    var err: Error = ResourceSaver.save(_current_sheet, resolved_path)
    if err == OK:
        _current_sheet.take_over_path(resolved_path)
        _current_sheet_path = resolved_path
        _dirty = false
        _set_status("Saved as: %s" % resolved_path.get_file())
    else:
        _set_status("Save failed (error %d)." % err, true)

func _on_add_event_requested() -> void:
    if not _ensure_sheet_for_editing():
        return
    _ace_picker.open("new_event", false, _viewport.get_selected_context().get("source_resource", null))

func _on_add_signal_event_requested() -> void:
    if not _ensure_sheet_for_editing():
        return
    _ace_picker.open("new_event", true, _viewport.get_selected_context().get("source_resource", null))

func _on_add_condition_requested() -> void:
    if not _ensure_sheet_for_editing():
        return
    var selected_resource: Resource = _viewport.get_selected_context().get("source_resource", null)
    if selected_resource is EventRow:
        _ace_picker.open("append_condition", false, selected_resource)
        return
    _ace_picker.open("new_condition_event", false, selected_resource)

func _on_add_action_requested() -> void:
    if not _ensure_selected_event():
        return
    _ace_picker.open("append_action", false, _viewport.get_selected_context().get("source_resource", null))

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
    var result := {"label": ""}
    var changed: bool = _perform_undoable_sheet_edit("Paste", func() -> bool:
        match clip_type:
            "row":
                if payload is Resource:
                    _insert_row_below_selection((payload as Resource).duplicate(true))
                    result["label"] = "Pasted row."
                    return true
            "condition":
                if selected_resource is EventRow and payload is ACECondition:
                    (selected_resource as EventRow).conditions.append((payload as ACECondition).duplicate(true))
                    result["label"] = "Pasted condition."
                    return true
            "action":
                if selected_resource is EventRow and payload is ACEAction:
                    (selected_resource as EventRow).actions.append((payload as ACEAction).duplicate(true))
                    result["label"] = "Pasted action."
                    return true
            "trigger":
                if selected_resource is EventRow and payload is ACECondition:
                    (selected_resource as EventRow).trigger = (payload as ACECondition).duplicate(true)
                    result["label"] = "Pasted trigger."
                    return true
        return false
    )
    if not changed:
        _set_status("Paste target is not valid for clipboard payload.", true)
    else:
        _mark_dirty(str(result.get("label", "Pasted.")))

func _on_add_global_variable_requested() -> void:
    if not _ensure_sheet_for_editing():
        return
    _variable_dlg.open("global")

func _on_add_local_variable_requested() -> void:
    if not _ensure_selected_event():
        return
    _variable_dlg.open("local")

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

# ── ACE picker signal handler ────────────────────────────────────────────────

func _on_ace_picker_selected(definition: ACEDefinition, context: Dictionary) -> void:
    if definition.parameters.is_empty():
        _apply_ace_definition(definition, {}, context)
        return
    _ace_params.open(definition, context)

func _on_viewport_ace_picker_requested(row_data: EventRowData, lane: String) -> void:
    if row_data == null or not (row_data.source_resource is EventRow):
        return
    match lane:
        "action":
            _ace_picker.open("append_action", false, row_data.source_resource)
        _:
            _ace_picker.open("append_condition", false, row_data.source_resource)

# ── ACE params dialog signal handler ────────────────────────────────────────

func _on_ace_params_confirmed(definition: ACEDefinition, values: Dictionary, context: Dictionary) -> void:
    _apply_ace_definition(definition, values, context)

func _apply_ace_definition(definition: ACEDefinition, params: Dictionary, context: Dictionary) -> void:
    if definition == null:
        return
    var mode: String = str(context.get("mode", "new_event"))
    var selected_resource: Resource = context.get("selected_resource", null)
    var message := {"text": ""}
    var changed: bool = _perform_undoable_sheet_edit("Apply ACE", func() -> bool:
        match mode:
            "new_condition_event":
                var condition_event: EventRow = EventRow.new()
                if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
                    condition_event.trigger = _create_condition_from_definition(definition, params)
                else:
                    condition_event.conditions.append(_create_condition_from_definition(definition, params))
                _insert_row_below_selection(condition_event)
                message["text"] = "Added event."
                return true
            "append_condition":
                if selected_resource is EventRow:
                    var target_event: EventRow = selected_resource as EventRow
                    var condition_entry: ACECondition = _create_condition_from_definition(definition, params)
                    if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
                        target_event.trigger = condition_entry
                    else:
                        target_event.conditions.append(condition_entry)
                    message["text"] = "Added condition."
                    return true
            "append_action":
                if selected_resource is EventRow:
                    var action_entry: ACEAction = _create_action_from_definition(definition, params)
                    (selected_resource as EventRow).actions.append(action_entry)
                    message["text"] = "Added action."
                    return true
            _:
                var event_row: EventRow = EventRow.new()
                if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
                    event_row.trigger = _create_condition_from_definition(definition, params)
                elif definition.ace_type == ACEDefinition.ACEType.CONDITION:
                    event_row.conditions.append(_create_condition_from_definition(definition, params))
                elif definition.ace_type == ACEDefinition.ACEType.ACTION:
                    event_row.actions.append(_create_action_from_definition(definition, params))
                _insert_row_below_selection(event_row)
                message["text"] = "Added event."
                return true
        return false
    )
    if changed:
        _mark_dirty(str(message.get("text", "Applied ACE.")))

func _create_condition_from_definition(definition: ACEDefinition, params: Dictionary) -> ACECondition:
    var condition: ACECondition = ACECondition.new()
    condition.provider_id = definition.provider_id
    condition.ace_id = definition.id
    condition.params = _resolve_definition_params(definition, params)
    return condition

func _create_action_from_definition(definition: ACEDefinition, params: Dictionary) -> ACEAction:
    var action: ACEAction = ACEAction.new()
    action.provider_id = definition.provider_id
    action.ace_id = definition.id
    action.params = _resolve_definition_params(definition, params)
    return action

func _resolve_definition_params(definition: ACEDefinition, row_params: Dictionary) -> Dictionary:
    return _param_resolver.resolve_all(definition, row_params if row_params != null else {})

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

## Returns the best available EventSheet file name suggestion for save dialogs.
func _suggest_sheet_filename() -> String:
    var candidate_path: String = _current_sheet_path
    if candidate_path.is_empty() and _current_sheet != null:
        candidate_path = _current_sheet.resource_path
    var file_name: String = candidate_path.get_file()
    if file_name.is_empty():
        file_name = "event_sheet.tres"
    elif file_name.get_extension().is_empty():
        file_name += ".tres"
    return file_name

## Returns the preferred directory for open/save dialogs, defaulting to res://.
func _suggest_sheet_directory() -> String:
    var candidate_path: String = _current_sheet_path
    if candidate_path.is_empty() and _current_sheet != null:
        candidate_path = _current_sheet.resource_path
    var directory: String = candidate_path.get_base_dir()
    if directory.is_empty():
        return "res://"
    return directory

## Builds the initial save path shown in the Save As dialog.
func _build_initial_save_path() -> String:
    var candidate_path: String = _current_sheet_path
    if candidate_path.is_empty() and _current_sheet != null:
        candidate_path = _current_sheet.resource_path
    if candidate_path.is_empty():
        return "res://%s" % _suggest_sheet_filename()
    return _normalize_sheet_save_path(candidate_path)

## Ensures save paths always include a valid filename and EventSheet resource extension.
func _normalize_sheet_save_path(path: String) -> String:
    var resolved_path: String = path.strip_edges()
    if resolved_path.is_empty():
        resolved_path = "res://%s" % _suggest_sheet_filename()
    var file_name: String = resolved_path.get_file()
    if file_name.is_empty():
        resolved_path = resolved_path.path_join(_suggest_sheet_filename())
        file_name = resolved_path.get_file()
    var extension: String = file_name.get_extension().to_lower()
    if extension.is_empty():
        resolved_path += ".tres"
    elif extension not in ["tres", "res"]:
        resolved_path = "%s.tres" % resolved_path.get_basename()
    return resolved_path

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
    if _resource_contains_descendant(source_resource, target_resource):
        _set_status("Cannot move a row into one of its descendants.", true)
        return
    var insertion_index: int = target_index
    if source_container == target_container and source_index < target_index:
        insertion_index -= 1
    var moved: bool = _perform_undoable_sheet_edit("Drag Row", func() -> bool:
        source_container.remove_at(source_index)
        target_container.insert(insertion_index, source_resource)
        return true
    )
    if moved:
        _mark_dirty("Moved row via drag and drop.")

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

func _on_viewport_span_edit_requested(row_data: EventRowData, edit_kind: String, old_value: String, new_value: String) -> void:
    if row_data == null or row_data.source_resource == null:
        return
    if old_value == new_value:
        return
    var updated: bool = _perform_undoable_sheet_edit("Edit Row Text", func() -> bool:
        match edit_kind:
            "group_name":
                if row_data.source_resource is EventGroup:
                    var group: EventGroup = row_data.source_resource as EventGroup
                    group.name = new_value
                    group.group_name = new_value
                    return true
            "comment_text":
                if row_data.source_resource is CommentRow:
                    (row_data.source_resource as CommentRow).text = new_value
                    return true
            "event_comment":
                if row_data.source_resource is EventRow:
                    (row_data.source_resource as EventRow).comment = new_value
                    return true
        return false
    )
    if updated:
        _mark_dirty("Updated row text.")

# ── Variable dialog signal handler ────────────────────────────────────────────

func _on_variable_dialog_confirmed(var_name: String, type_name: String, default_value: Variant, scope: String) -> void:
    if var_name.is_empty():
        _set_status("Variable name is required.", true)
        return
    var selected: Resource = _viewport.get_selected_context().get("source_resource", null)
    var message := {"text": ""}
    var added: bool = _perform_undoable_sheet_edit("Create Variable", func() -> bool:
        if scope == "global":
            _current_sheet.variables[var_name] = {
                "type": type_name,
                "default": default_value
            }
            message["text"] = "Added global variable %s." % var_name
            return true
        if not (selected is EventRow):
            return false
        var local_var: LocalVariable = LocalVariable.new()
        local_var.name = var_name
        local_var.type_name = type_name
        local_var.type = _type_from_name(type_name)
        local_var.default_value = default_value
        (selected as EventRow).local_variables.append(local_var)
        message["text"] = "Added local variable %s." % var_name
        return true
    )
    if not added and scope != "global":
        _set_status("Select an event row for local variable creation.", true)
        return
    if added:
        _mark_dirty(str(message.get("text", "Added variable.")))

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
    _refresh_exposed_node()
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
    _ace_picker.set_registry(_ace_registry)
    _refresh_exposed_node()

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

func _refresh_exposed_node() -> void:
    if _exposed_node == null:
        return
    _exposed_node.setup(_ace_registry, _editor_param_store, _current_sheet, _param_resolver)
    _exposed_node.set_undo_redo_manager(_undo_redo_adapter.get_manager())
    _exposed_node.on_registry_refreshed()

func _on_undo_requested() -> void:
    if not _undo_redo_adapter.has_undo():
        _set_status("Nothing to undo.", true)
        return
    _undo_redo_adapter.undo()

func _on_redo_requested() -> void:
    if not _undo_redo_adapter.has_redo():
        _set_status("Nothing to redo.", true)
        return
    _undo_redo_adapter.redo()

func _capture_sheet_snapshot() -> EventSheetResource:
    if _current_sheet == null:
        return null
    return _current_sheet.duplicate(true)

func _restore_sheet_snapshot(snapshot: EventSheetResource) -> void:
    if snapshot == null:
        return
    _current_sheet = snapshot.duplicate(true)
    if not _current_sheet_path.is_empty():
        _current_sheet.take_over_path(_current_sheet_path)
    _refresh_after_edit()
    _mark_dirty("Applied undo/redo.")

func _perform_undoable_sheet_edit(action_name: String, operation: Callable) -> bool:
    if _current_sheet == null or not operation.is_valid():
        return false
    var before: EventSheetResource = _capture_sheet_snapshot()
    var changed: bool = bool(operation.call())
    if not changed:
        return false
    var after: EventSheetResource = _capture_sheet_snapshot()
    if before == null or after == null:
        return false
    if not _undo_redo_adapter.has_manager():
        _refresh_after_edit()
        return true
    _undo_redo_adapter.create_action(action_name)
    _undo_redo_adapter.add_do_method(self, "_restore_sheet_snapshot", [after])
    _undo_redo_adapter.add_undo_method(self, "_restore_sheet_snapshot", [before])
    _undo_redo_adapter.commit_action()
    return true

func _clear_undo_history() -> void:
    _undo_redo_adapter.clear_history()

func _resource_contains_descendant(source: Resource, candidate: Resource) -> bool:
    if source == null or candidate == null:
        return false
    if source == candidate:
        return true
    if source is EventRow:
        for child in (source as EventRow).sub_events:
            if _resource_contains_descendant(child, candidate):
                return true
    elif source is EventGroup:
        var group: EventGroup = source as EventGroup
        var children: Array = group.events if not group.events.is_empty() else group.rows
        for child in children:
            if _resource_contains_descendant(child, candidate):
                return true
    return false
