@tool
class_name EventSheetDock
extends Control

const EVENT_SHEET_FILTERS: Array[String] = ["*.tres ; EventSheetResource", "*.res ; EventSheetResource"]
const VARIABLE_USAGE_MAX_DEPTH := 8
const CONDITION_MENU_EDIT := 1
const CONDITION_MENU_ADD := 2
const CONDITION_MENU_REPLACE := 3
const CONDITION_MENU_INVERT := 4
const CONDITION_MENU_DELETE := 5
const ACTION_MENU_EDIT := 1
const ACTION_MENU_ADD := 2
const ACTION_MENU_REPLACE := 3
const ACTION_MENU_DELETE := 4
const ROW_MENU_ADD_SUB_EVENT := 1
const ROW_MENU_ADD_EVENT_BELOW := 2
const ROW_MENU_ADD_GROUP_BELOW := 3
const ROW_MENU_ADD_COMMENT_BELOW := 4
const ROW_MENU_COPY := 5
const ROW_MENU_PASTE := 6
const ROW_MENU_DELETE := 7
const ROW_MENU_TOGGLE_CONDITION_BLOCK := 8
const ROW_MENU_TOGGLE_GROUP_FOLD := 9
const ACE_DRAG_KINDS := ["condition", "action"]
const SIDE_PANEL_MIN_WIDTH := 160.0
const SIDE_PANEL_MAX_WIDTH := 220.0
const SIDE_PANEL_WIDTH_RATIO := 0.18

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
var _condition_context_menu: PopupMenu = null
var _action_context_menu: PopupMenu = null
var _row_context_menu: PopupMenu = null
var _context_row: EventRowData = null
var _context_hit: Dictionary = {}
var _global_variable_entries: Array[Dictionary] = []
var _local_variable_entries: Array[Dictionary] = []

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
    _add_toolbar_button("Zoom -", _on_zoom_out_requested)
    _add_toolbar_button("Zoom +", _on_zoom_in_requested)
    _add_toolbar_separator()
    _add_toolbar_button("Add Global Var", _on_add_global_variable_requested)
    _add_toolbar_button("Add Local Var", _on_add_local_variable_requested)

    _split = HSplitContainer.new()
    _split.name = "EventSheetWorkspaceSplit"
    _split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(_split)

    _scroll = ScrollContainer.new()
    _scroll.name = "EventSheetScroll"
    _scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
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
    _viewport.rows_drop_requested.connect(_on_rows_drop_requested)
    _viewport.ace_preview_requested.connect(_on_ace_preview_requested)
    _viewport.ace_picker_requested.connect(_on_viewport_ace_picker_requested)
    _viewport.span_edit_requested.connect(_on_viewport_span_edit_requested)
    _viewport.ace_edit_requested.connect(_on_viewport_ace_edit_requested)
    _viewport.ace_drop_requested.connect(_on_viewport_ace_drop_requested)
    _viewport.context_menu_requested.connect(_on_viewport_context_menu_requested)
    _viewport.set_external_span_edit_handler_enabled(true)

    _side_panel = VBoxContainer.new()
    _side_panel.name = "EventSheetSidePanel"
    _side_panel.custom_minimum_size = Vector2(SIDE_PANEL_MIN_WIDTH, 0.0)
    _side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _split.add_child(_side_panel)

    _preview_title = Label.new()
    _preview_title.name = "ACEPreviewTitle"
    _preview_title.text = "Dropped ACE Preview"
    _side_panel.add_child(_preview_title)

    _preview_list = ItemList.new()
    _preview_list.name = "ACEPreviewList"
    _preview_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _preview_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _preview_list.size_flags_stretch_ratio = 1.15
    _preview_list.custom_minimum_size = Vector2(140.0, 120.0)
    _side_panel.add_child(_preview_list)

    var globals_label: Label = Label.new()
    globals_label.text = "Global Variables"
    _side_panel.add_child(globals_label)

    _global_var_list = ItemList.new()
    _global_var_list.name = "GlobalVariableList"
    _global_var_list.custom_minimum_size = Vector2(140.0, 96.0)
    _global_var_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _global_var_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _global_var_list.size_flags_stretch_ratio = 0.55
    _global_var_list.item_activated.connect(_on_global_variable_activated)
    _side_panel.add_child(_global_var_list)

    var locals_label: Label = Label.new()
    locals_label.text = "Local Variables (selected event)"
    _side_panel.add_child(locals_label)

    _local_var_list = ItemList.new()
    _local_var_list.name = "LocalVariableList"
    _local_var_list.custom_minimum_size = Vector2(140.0, 96.0)
    _local_var_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _local_var_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _local_var_list.size_flags_stretch_ratio = 0.55
    _local_var_list.item_activated.connect(_on_local_variable_activated)
    _side_panel.add_child(_local_var_list)

    _status_label = Label.new()
    _status_label.name = "EventSheetStatus"
    _status_label.text = "Ready"
    root.add_child(_status_label)

    _exposed_node.name = "EventSheetExposedParams"
    add_child(_exposed_node)
    _exposed_node.setup(_ace_registry, _editor_param_store, _current_sheet, _param_resolver)
    _exposed_node.set_undo_redo_manager(_undo_redo_adapter.get_manager())
    _build_context_menus()
    call_deferred("_sync_workspace_layout")

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        call_deferred("_sync_workspace_layout")
    elif what == NOTIFICATION_PREDELETE:
        _release_ace_sources()

func _sync_workspace_layout() -> void:
    if _split == null:
        return
    var total_width: float = size.x
    if total_width <= 0.0:
        return
    var side_panel_width: float = clampf(total_width * SIDE_PANEL_WIDTH_RATIO, SIDE_PANEL_MIN_WIDTH, SIDE_PANEL_MAX_WIDTH)
    _split.split_offset = int(max(total_width - side_panel_width, 0.0))

func _build_context_menus() -> void:
    if _condition_context_menu != null:
        return
    _condition_context_menu = PopupMenu.new()
    _condition_context_menu.add_item("Edit Condition", CONDITION_MENU_EDIT)
    _condition_context_menu.add_item("Add Condition", CONDITION_MENU_ADD)
    _condition_context_menu.add_item("Replace Condition", CONDITION_MENU_REPLACE)
    _condition_context_menu.add_separator()
    _condition_context_menu.add_item("Invert Condition", CONDITION_MENU_INVERT)
    _condition_context_menu.add_separator()
    _condition_context_menu.add_item("Delete Condition", CONDITION_MENU_DELETE)
    _condition_context_menu.id_pressed.connect(_on_condition_context_menu_id_pressed)
    add_child(_condition_context_menu)

    _action_context_menu = PopupMenu.new()
    _action_context_menu.add_item("Edit Action", ACTION_MENU_EDIT)
    _action_context_menu.add_item("Add Action", ACTION_MENU_ADD)
    _action_context_menu.add_item("Replace Action", ACTION_MENU_REPLACE)
    _action_context_menu.add_separator()
    _action_context_menu.add_item("Delete Action", ACTION_MENU_DELETE)
    _action_context_menu.id_pressed.connect(_on_action_context_menu_id_pressed)
    add_child(_action_context_menu)

    _row_context_menu = PopupMenu.new()
    _row_context_menu.add_item("Add Sub-Event", ROW_MENU_ADD_SUB_EVENT)
    _row_context_menu.add_item("Convert to OR Block", ROW_MENU_TOGGLE_CONDITION_BLOCK)
    _row_context_menu.add_item("Close Group", ROW_MENU_TOGGLE_GROUP_FOLD)
    _row_context_menu.add_item("Add Event Below", ROW_MENU_ADD_EVENT_BELOW)
    _row_context_menu.add_item("Add Group Below", ROW_MENU_ADD_GROUP_BELOW)
    _row_context_menu.add_item("Add Comment Below", ROW_MENU_ADD_COMMENT_BELOW)
    _row_context_menu.add_separator()
    _row_context_menu.add_item("Copy", ROW_MENU_COPY)
    _row_context_menu.add_item("Paste", ROW_MENU_PASTE)
    _row_context_menu.add_separator()
    _row_context_menu.add_item("Delete Row", ROW_MENU_DELETE)
    _row_context_menu.add_theme_font_size_override("font_size", 14)
    _row_context_menu.id_pressed.connect(_on_row_context_menu_id_pressed)
    add_child(_row_context_menu)

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
        elif key_event.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
            _on_zoom_in_requested()
            accept_event()
        elif key_event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
            _on_zoom_out_requested()
            accept_event()
    elif key_event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
        _delete_selected_rows()
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
    if _ace_picker.get_popup_rect().has_point(get_global_mouse_position()):
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
        dialog.call_deferred("queue_free")
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
        dialog.call_deferred("queue_free")
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

func _on_zoom_in_requested() -> void:
    if _viewport == null:
        return
    _viewport.zoom_in()
    _set_status("Zoom: %d%%" % int(round(_viewport.get_zoom_factor() * 100.0)))

func _on_zoom_out_requested() -> void:
    if _viewport == null:
        return
    _viewport.zoom_out()
    _set_status("Zoom: %d%%" % int(round(_viewport.get_zoom_factor() * 100.0)))

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
    if not _ensure_sheet_for_editing():
        return
    var target_event: EventRow = _find_first_event_row_resource()
    var context: Dictionary = {"create_event_if_missing": true}
    if target_event != null:
        _select_first_event_row()
        context["selected_resource"] = target_event
    _variable_dlg.open_for_edit("local", context, "", "int", "", false, "Create Variable")

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
    var initial_values: Dictionary = context.get("existing_params", {})
    _ace_params.open_with_values(definition, context, initial_values)

func _on_viewport_ace_picker_requested(row_data: EventRowData, lane: String) -> void:
    if row_data == null or not (row_data.source_resource is EventRow):
        return
    match lane:
        "action":
            _ace_picker.open("append_action", false, row_data.source_resource)
        _:
            _ace_picker.open("append_condition", false, row_data.source_resource)

func _on_viewport_ace_edit_requested(row_data: EventRowData, span_index: int, metadata: Dictionary) -> void:
    if row_data == null or not (row_data.source_resource is EventRow):
        return
    var event_row: EventRow = row_data.source_resource as EventRow
    var edit_context: Dictionary = _build_ace_edit_context(event_row, span_index, metadata)
    if edit_context.is_empty():
        return
    var definition: ACEDefinition = edit_context.get("definition", null)
    if definition == null:
        _set_status("ACE metadata could not be resolved for editing.", true)
        return
    if definition.parameters.is_empty():
        _ace_picker.open(str(edit_context.get("mode", "")), false, event_row, edit_context)
        return
    _ace_params.open_with_values(definition, edit_context, edit_context.get("existing_params", {}))

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
            "replace_trigger":
                if selected_resource is EventRow:
                    (selected_resource as EventRow).trigger = _create_condition_from_definition(definition, params)
                    message["text"] = "Updated trigger."
                    return true
            "replace_condition":
                if selected_resource is EventRow:
                    var condition_index: int = int(context.get("ace_index", -1))
                    if condition_index >= 0 and condition_index < (selected_resource as EventRow).conditions.size():
                        (selected_resource as EventRow).conditions[condition_index] = _create_condition_from_definition(definition, params)
                        message["text"] = "Updated condition."
                        return true
            "replace_action":
                if selected_resource is EventRow:
                    var action_index: int = int(context.get("ace_index", -1))
                    if action_index >= 0 and action_index < (selected_resource as EventRow).actions.size():
                        (selected_resource as EventRow).actions[action_index] = _create_action_from_definition(definition, params)
                        message["text"] = "Updated action."
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

func _insert_row_below_selection(row_resource: Resource, explicit_selected_resource: Resource = null) -> void:
    if _current_sheet == null or row_resource == null:
        return
    var selected_resource: Resource = explicit_selected_resource if explicit_selected_resource != null else _viewport.get_selected_context().get("source_resource", null)
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

func _on_row_drop_requested(source_row: EventRowData, target_row: EventRowData, drop_mode: String = "before") -> void:
    if source_row == null:
        return
    _move_rows([source_row], target_row, drop_mode)

func _on_rows_drop_requested(
    source_rows: Array,
    target_row: EventRowData,
    drop_mode: String = "before"
) -> void:
    _move_rows(source_rows, target_row, drop_mode)

func _move_rows(source_rows: Array, target_row: EventRowData, drop_mode: String) -> void:
    if target_row == null or _current_sheet == null or source_rows.is_empty():
        return
    var target_resource: Resource = target_row.source_resource
    if target_resource == null:
        return
    var source_resources: Array[Resource] = []
    for source_row in source_rows:
        if not (source_row is EventRowData):
            continue
        var source_resource: Resource = (source_row as EventRowData).source_resource
        if source_resource == null or source_resource == target_resource or source_resources.has(source_resource):
            continue
        if _resource_contains_descendant(source_resource, target_resource):
            _set_status("Cannot move a row into one of its descendants.", true)
            return
        source_resources.append(source_resource)
    if source_resources.is_empty():
        return
    var moved: bool = _perform_undoable_sheet_edit("Drag Row", func() -> bool:
        for source_resource in source_resources:
            var source_location: Dictionary = _find_resource_location(source_resource)
            if source_location.is_empty():
                continue
            var source_container: Array = source_location.get("container", [])
            var source_index: int = int(source_location.get("index", -1))
            if source_index >= 0 and source_index < source_container.size():
                source_container.remove_at(source_index)
        var target_container: Array = []
        var insertion_index: int = 0
        if drop_mode == "inside":
            if target_resource is EventGroup:
                target_container = _group_children_array(target_resource as EventGroup)
                insertion_index = target_container.size()
            elif target_resource is EventRow:
                target_container = (target_resource as EventRow).sub_events
                insertion_index = target_container.size()
        else:
            var target_location: Dictionary = _find_resource_location(target_resource)
            if target_location.is_empty():
                return false
            target_container = target_location.get("container", [])
            insertion_index = int(target_location.get("index", 0))
            if drop_mode == "after":
                insertion_index += 1
        for offset in range(source_resources.size()):
            target_container.insert(insertion_index + offset, source_resources[offset])
        return true
    )
    if moved:
        _mark_dirty("Moved row via drag and drop.")

func _on_viewport_ace_drop_requested(
    source_entries: Array,
    target_row: EventRowData,
    target_lane: String,
    target_ace_index: int,
    insert_mode: String
) -> void:
    if target_row == null or not ACE_DRAG_KINDS.has(target_lane):
        return
    var target_event: EventRow = target_row.source_resource as EventRow
    if target_event == null:
        return
    var normalized_entries: Array = _normalize_ace_drag_entries(source_entries, target_lane)
    if normalized_entries.is_empty():
        return
    var moving_resources: Array = []
    for entry in normalized_entries:
        moving_resources.append(entry.get("resource"))
    var target_anchor: Resource = _resolve_event_ace_resource(target_event, target_lane, target_ace_index)
    if target_anchor != null and moving_resources.has(target_anchor):
        target_anchor = null
    var moved: bool = _perform_undoable_sheet_edit("Drag ACE", func() -> bool:
        var removal_groups: Dictionary = {}
        for entry in normalized_entries:
            var source_event: EventRow = entry.get("event_row")
            var source_indices: Array = removal_groups.get(source_event, []).duplicate()
            source_indices.append(int(entry.get("ace_index", -1)))
            removal_groups[source_event] = source_indices
        for source_event in removal_groups.keys():
            var indices: Array = removal_groups.get(source_event, []).duplicate()
            indices.sort()
            indices.reverse()
            var source_array: Array = _event_ace_array(source_event, target_lane)
            for source_index in indices:
                if source_index >= 0 and source_index < source_array.size():
                    source_array.remove_at(source_index)
        var target_array: Array = _event_ace_array(target_event, target_lane)
        var insertion_index: int = target_array.size()
        if target_anchor != null:
            var anchor_index: int = target_array.find(target_anchor)
            if anchor_index >= 0:
                insertion_index = anchor_index + (1 if insert_mode == "after" else 0)
        for offset in range(moving_resources.size()):
            target_array.insert(insertion_index + offset, moving_resources[offset])
        return true
    )
    if moved:
        _mark_dirty("Moved ACE via drag and drop.")

func _normalize_ace_drag_entries(source_entries: Array, lane: String) -> Array:
    var normalized: Array = []
    for entry in source_entries:
        if not (entry is Dictionary):
            continue
        var entry_dict: Dictionary = entry
        var source_event: EventRow = entry_dict.get("source_resource", null) as EventRow
        var kind: String = str(entry_dict.get("kind", ""))
        var ace_index: int = int(entry_dict.get("ace_index", -1))
        if source_event == null or kind != lane or ace_index < 0:
            continue
        var ace_resource: Resource = _resolve_event_ace_resource(source_event, kind, ace_index)
        if ace_resource == null:
            continue
        normalized.append({
            "event_row": source_event,
            "kind": kind,
            "ace_index": ace_index,
            "resource": ace_resource
        })
    return normalized

func _event_ace_array(event_row: EventRow, lane: String) -> Array:
    if lane == "condition":
        return event_row.conditions
    return event_row.actions

func _resolve_event_ace_resource(event_row: EventRow, lane: String, ace_index: int) -> Resource:
    if event_row == null or ace_index < 0:
        return null
    var ace_array: Array = _event_ace_array(event_row, lane)
    if ace_index < ace_array.size() and ace_array[ace_index] is Resource:
        return ace_array[ace_index]
    return null

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

func _on_viewport_context_menu_requested(row_data: EventRowData, hit: Dictionary, global_position: Vector2) -> void:
    _context_row = row_data
    _context_hit = hit.duplicate(true)
    if row_data == null:
        return
    var metadata: Dictionary = hit.get("span_metadata", {})
    var kind: String = str(metadata.get("kind", ""))
    if kind in ["condition", "trigger"]:
        _show_popup_menu(_condition_context_menu, global_position)
        return
    if kind == "action":
        _show_popup_menu(_action_context_menu, global_position)
        return
    _show_popup_menu(_row_context_menu, global_position)

func _show_popup_menu(menu: PopupMenu, global_position: Vector2) -> void:
    if menu == null:
        return
    _configure_context_menu(menu)
    menu.reset_size()
    menu.popup(Rect2i(Vector2i(global_position), Vector2i.ONE))

func _configure_context_menu(menu: PopupMenu) -> void:
    if menu == _condition_context_menu:
        var invert_index: int = menu.get_item_index(CONDITION_MENU_INVERT)
        if invert_index >= 0:
            menu.set_item_text(invert_index, "Remove Inversion" if _context_condition_is_negated() else "Invert Condition")
    elif menu == _row_context_menu:
        var toggle_index: int = menu.get_item_index(ROW_MENU_TOGGLE_CONDITION_BLOCK)
        if toggle_index >= 0:
            var selected_events: Array[EventRow] = _get_selected_event_rows_from_context()
            var has_events: bool = not selected_events.is_empty()
            menu.set_item_disabled(toggle_index, not has_events)
            if has_events:
                menu.set_item_text(
                    toggle_index,
                    (
                        "Convert to AND Block"
                        if _event_rows_use_or_mode(selected_events)
                        else "Convert to OR Block"
                    )
                )
        var group_toggle_index: int = menu.get_item_index(ROW_MENU_TOGGLE_GROUP_FOLD)
        if group_toggle_index >= 0:
            var context_group: EventGroup = null
            if _context_row != null and _context_row.source_resource is EventGroup:
                context_group = _context_row.source_resource as EventGroup
            menu.set_item_disabled(group_toggle_index, context_group == null)
            if context_group != null:
                menu.set_item_text(
                    group_toggle_index,
                    "Open Group" if context_group.is_collapsed() else "Close Group"
                )

func _on_condition_context_menu_id_pressed(id: int) -> void:
    if _context_row == null or not (_context_row.source_resource is EventRow):
        return
    match id:
        CONDITION_MENU_EDIT:
            _on_viewport_ace_edit_requested(_context_row, int(_context_hit.get("span_index", -1)), _context_hit.get("span_metadata", {}))
        CONDITION_MENU_ADD:
            _ace_picker.open("append_condition", false, _context_row.source_resource)
        CONDITION_MENU_REPLACE:
            var replace_context: Dictionary = _build_ace_edit_context(_context_row.source_resource as EventRow, int(_context_hit.get("span_index", -1)), _context_hit.get("span_metadata", {}))
            if not replace_context.is_empty():
                _ace_picker.open(str(replace_context.get("mode", "replace_condition")), false, _context_row.source_resource, replace_context)
        CONDITION_MENU_INVERT:
            _toggle_context_condition_inversion()
        CONDITION_MENU_DELETE:
            _delete_context_ace()

func _on_action_context_menu_id_pressed(id: int) -> void:
    if _context_row == null or not (_context_row.source_resource is EventRow):
        return
    match id:
        ACTION_MENU_EDIT:
            _on_viewport_ace_edit_requested(_context_row, int(_context_hit.get("span_index", -1)), _context_hit.get("span_metadata", {}))
        ACTION_MENU_ADD:
            _ace_picker.open("append_action", false, _context_row.source_resource)
        ACTION_MENU_REPLACE:
            var replace_context: Dictionary = _build_ace_edit_context(_context_row.source_resource as EventRow, int(_context_hit.get("span_index", -1)), _context_hit.get("span_metadata", {}))
            if not replace_context.is_empty():
                _ace_picker.open("replace_action", false, _context_row.source_resource, replace_context)
        ACTION_MENU_DELETE:
            _delete_context_ace()

func _on_row_context_menu_id_pressed(id: int) -> void:
    if _context_row == null:
        return
    match id:
        ROW_MENU_ADD_SUB_EVENT:
            _insert_child_event_for_context_row()
        ROW_MENU_ADD_EVENT_BELOW:
            _insert_context_row_below(EventRow.new(), "Added event.")
        ROW_MENU_ADD_GROUP_BELOW:
            var group: EventGroup = EventGroup.new()
            group.name = "Group"
            group.group_name = group.name
            _insert_context_row_below(group, "Added group.")
        ROW_MENU_ADD_COMMENT_BELOW:
            var comment: CommentRow = CommentRow.new()
            comment.text = "Comment"
            _insert_context_row_below(comment, "Added comment.")
        ROW_MENU_COPY:
            _on_copy_requested()
        ROW_MENU_PASTE:
            _on_paste_requested()
        ROW_MENU_DELETE:
            _delete_selected_rows()
        ROW_MENU_TOGGLE_CONDITION_BLOCK:
            _toggle_context_condition_block()
        ROW_MENU_TOGGLE_GROUP_FOLD:
            _toggle_context_group_fold()

func _delete_context_ace() -> void:
    if _context_row == null or not (_context_row.source_resource is EventRow):
        return
    var event_row: EventRow = _context_row.source_resource as EventRow
    var metadata: Dictionary = _context_hit.get("span_metadata", {})
    var ace_index: int = int(metadata.get("ace_index", -1))
    var kind: String = str(metadata.get("kind", ""))
    var deleted: bool = _perform_undoable_sheet_edit("Delete ACE", func() -> bool:
        match kind:
            "trigger":
                if event_row.trigger != null:
                    event_row.trigger = null
                    return true
            "condition":
                if ace_index >= 0 and ace_index < event_row.conditions.size():
                    event_row.conditions.remove_at(ace_index)
                    return true
            "action":
                if ace_index >= 0 and ace_index < event_row.actions.size():
                    event_row.actions.remove_at(ace_index)
                    return true
        return false
    )
    if deleted:
        _mark_dirty("Deleted ACE.")

func _toggle_context_condition_inversion() -> void:
    if _context_row == null or not (_context_row.source_resource is EventRow):
        return
    var event_row: EventRow = _context_row.source_resource as EventRow
    var metadata: Dictionary = _context_hit.get("span_metadata", {})
    var kind: String = str(metadata.get("kind", ""))
    var ace_index: int = int(metadata.get("ace_index", -1))
    var toggled: bool = _perform_undoable_sheet_edit("Invert Condition", func() -> bool:
        if kind == "trigger" and event_row.trigger != null:
            event_row.trigger.negated = not event_row.trigger.negated
            return true
        if kind == "condition" and ace_index >= 0 and ace_index < event_row.conditions.size():
            event_row.conditions[ace_index].negated = not event_row.conditions[ace_index].negated
            return true
        return false
    )
    if toggled:
        _mark_dirty("Updated condition inversion.")

func _toggle_context_condition_block() -> void:
    var selected_events: Array[EventRow] = _get_selected_event_rows_from_context()
    if selected_events.is_empty():
        return
    var target_mode: int = (
        EventRow.ConditionMode.AND
        if _event_rows_use_or_mode(selected_events)
        else EventRow.ConditionMode.OR
    )
    var toggled: bool = _perform_undoable_sheet_edit("Toggle Condition Block", func() -> bool:
        for event_row in selected_events:
            event_row.condition_mode = target_mode
        return true
    )
    if toggled:
        _mark_dirty("Updated condition block.")

func _toggle_context_group_fold() -> void:
    if _context_row == null or not (_context_row.source_resource is EventGroup):
        return
    var context_group: EventGroup = _context_row.source_resource as EventGroup
    context_group.set_collapsed_state(not context_group.is_collapsed())
    _viewport.toggle_row_fold_by_uid(_context_row.row_uid)
    _mark_dirty("Updated group fold state.")

func _delete_context_row() -> void:
    if _context_row == null or _context_row.source_resource == null:
        return
    var target_resource: Resource = _context_row.source_resource
    var location: Dictionary = _find_resource_location(target_resource)
    if location.is_empty():
        return
    var container: Array = location.get("container", [])
    var index: int = int(location.get("index", -1))
    if index < 0 or index >= container.size():
        return
    var deleted: bool = _perform_undoable_sheet_edit("Delete Row", func() -> bool:
        container.remove_at(index)
        return true
    )
    if deleted:
        _mark_dirty("Deleted row.")

func _delete_selected_rows() -> void:
    var selected_rows: Array[EventRowData] = _get_selected_rows_from_context()
    if selected_rows.is_empty():
        _delete_context_row()
        return
    var resources_to_delete: Array[Resource] = []
    for row_data in selected_rows:
        var source_resource: Resource = row_data.source_resource if row_data != null else null
        if source_resource == null:
            continue
        var covered_by_parent: bool = false
        for existing_resource in resources_to_delete:
            if _resource_contains_descendant(existing_resource, source_resource):
                covered_by_parent = true
                break
        if covered_by_parent:
            continue
        var filtered_resources: Array[Resource] = []
        for existing_resource in resources_to_delete:
            if not _resource_contains_descendant(source_resource, existing_resource):
                filtered_resources.append(existing_resource)
        resources_to_delete = filtered_resources
        resources_to_delete.append(source_resource)
    if resources_to_delete.is_empty():
        return
    var deleted: bool = _perform_undoable_sheet_edit("Delete Row", func() -> bool:
        resources_to_delete.sort_custom(func(a: Resource, b: Resource) -> bool:
            return _resource_sort_key(a) > _resource_sort_key(b)
        )
        for resource_entry in resources_to_delete:
            var location: Dictionary = _find_resource_location(resource_entry)
            if location.is_empty():
                continue
            var container: Array = location.get("container", [])
            var index: int = int(location.get("index", -1))
            if index >= 0 and index < container.size():
                container.remove_at(index)
        return true
    )
    if deleted:
        _viewport.clear_selection()
        _mark_dirty("Deleted row.")

func _insert_child_event_for_context_row() -> void:
    if _context_row == null or not (_context_row.source_resource is EventRow):
        return
    var changed: bool = _perform_undoable_sheet_edit("Add Sub Event", func() -> bool:
        (_context_row.source_resource as EventRow).sub_events.append(EventRow.new())
        return true
    )
    if changed:
        _mark_dirty("Added sub-event.")

func _insert_context_row_below(resource_entry: Resource, message: String) -> void:
    if resource_entry == null or _context_row == null:
        return
    var changed: bool = _perform_undoable_sheet_edit("Insert Row", func() -> bool:
        _insert_row_below_selection(resource_entry, _context_row.source_resource)
        return true
    )
    if changed:
        _mark_dirty(message)

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

func _on_variable_dialog_confirmed(var_name: String, type_name: String, default_value: Variant, scope: String, context: Dictionary = {}) -> void:
    if var_name.is_empty():
        _set_status("Variable name is required.", true)
        return
    var selected: Resource = context.get("selected_resource", _viewport.get_selected_context().get("source_resource", null))
    var original_name: String = str(context.get("original_name", ""))
    var editing: bool = bool(context.get("editing", false))
    var action_verb: String = "Updated" if editing else "Added"
    var message := {"text": ""}
    var added: bool = _perform_undoable_sheet_edit("Create Variable", func() -> bool:
        if scope == "global":
            if editing and not original_name.is_empty() and original_name != var_name:
                _current_sheet.variables.erase(original_name)
            _current_sheet.variables[var_name] = {
                "type": type_name,
                "default": default_value
            }
            message["text"] = "%s global variable %s." % [action_verb, var_name]
            return true
        var target_event: EventRow = null
        if selected is EventRow:
            target_event = selected as EventRow
        else:
            target_event = _find_first_event_row_resource()
        if target_event == null and not editing and bool(context.get("create_event_if_missing", true)):
            target_event = EventRow.new()
            _current_sheet.events.append(target_event)
        if target_event == null:
            return false
        var variable_index: int = int(context.get("variable_index", -1))
        var local_var: LocalVariable = null
        if editing and variable_index >= 0 and variable_index < target_event.local_variables.size():
            local_var = target_event.local_variables[variable_index]
        else:
            local_var = LocalVariable.new()
            target_event.local_variables.append(local_var)
        local_var.name = var_name
        local_var.type_name = type_name
        local_var.type = _type_from_name(type_name)
        local_var.default_value = default_value
        message["text"] = "%s local variable %s." % [action_verb, var_name]
        return true
    )
    if not added and scope != "global":
        _set_status("Add or select an event row before editing local variables.", true)
        return
    if added:
        _mark_dirty(str(message.get("text", "Saved variable.")))
        if scope == "local" and not (selected is EventRow):
            _select_first_event_row()

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

func _on_global_variable_activated(index: int) -> void:
    if index < 0 or index >= _global_variable_entries.size():
        return
    var entry: Dictionary = _global_variable_entries[index]
    var var_name: String = str(entry.get("name", ""))
    _variable_dlg.open_for_edit(
        "global",
        {"editing": true, "original_name": var_name},
        var_name,
        str(entry.get("type", "Variant")),
        entry.get("default", ""),
        _is_global_variable_in_use(var_name),
        "Edit Variable"
    )

func _on_local_variable_activated(index: int) -> void:
    if index < 0 or index >= _local_variable_entries.size():
        return
    var entry: Dictionary = _local_variable_entries[index]
    var var_name: String = str(entry.get("name", ""))
    var selected_resource: Resource = entry.get("selected_resource", null)
    _variable_dlg.open_for_edit(
        "local",
        {
            "editing": true,
            "original_name": var_name,
            "variable_index": int(entry.get("index", -1)),
            "selected_resource": selected_resource
        },
        var_name,
        str(entry.get("type", "Variant")),
        entry.get("default", ""),
        _is_local_variable_in_use(var_name, selected_resource),
        "Edit Variable"
    )

func _is_global_variable_in_use(var_name: String) -> bool:
    if _current_sheet == null or var_name.is_empty():
        return false
    return _resource_array_uses_variable(_current_sheet.events, var_name)

func _is_local_variable_in_use(var_name: String, selected_resource: Resource) -> bool:
    if var_name.is_empty() or not (selected_resource is EventRow):
        return false
    return _event_row_uses_variable(selected_resource as EventRow, var_name)

func _resource_array_uses_variable(resources: Array, var_name: String) -> bool:
    for resource_entry in resources:
        if _resource_uses_variable(resource_entry, var_name):
            return true
    return false

func _resource_uses_variable(resource_entry: Resource, var_name: String) -> bool:
    if resource_entry == null:
        return false
    if resource_entry is EventRow:
        return _event_row_uses_variable(resource_entry as EventRow, var_name)
    if resource_entry is EventGroup:
        return _resource_array_uses_variable(_group_children_array(resource_entry as EventGroup), var_name)
    return false

func _event_row_uses_variable(event_row: EventRow, var_name: String) -> bool:
    if event_row == null:
        return false
    if _ace_entry_uses_variable(event_row.trigger, var_name):
        return true
    for condition in event_row.conditions:
        if _ace_entry_uses_variable(condition, var_name):
            return true
    for action_entry in event_row.actions:
        if _ace_entry_uses_variable(action_entry, var_name):
            return true
    return _resource_array_uses_variable(event_row.sub_events, var_name)

func _event_row_uses_or_mode(event_row: EventRow) -> bool:
    return event_row != null and event_row.condition_mode == EventRow.ConditionMode.OR

func _event_rows_use_or_mode(event_rows: Array[EventRow]) -> bool:
    if event_rows.is_empty():
        return false
    for event_row in event_rows:
        if not _event_row_uses_or_mode(event_row):
            return false
    return true

func _get_selected_rows_from_context() -> Array[EventRowData]:
    if _viewport == null:
        return []
    var selected_rows: Array[EventRowData] = _viewport.get_selected_rows()
    if selected_rows.is_empty():
        if _context_row != null:
            return [_context_row]
        return []
    if _context_row == null:
        return selected_rows
    for row_data in selected_rows:
        if row_data.row_uid == _context_row.row_uid:
            return selected_rows
    return [_context_row]

func _get_selected_event_rows_from_context() -> Array[EventRow]:
    var event_rows: Array[EventRow] = []
    for row_data in _get_selected_rows_from_context():
        if row_data != null and row_data.source_resource is EventRow:
            event_rows.append(row_data.source_resource as EventRow)
    return event_rows

func _resource_sort_key(resource_entry: Resource) -> int:
    return _find_row_index_for_resource(resource_entry)

func _find_row_index_for_resource(resource_entry: Resource) -> int:
    if _viewport == null or resource_entry == null:
        return -1
    var flat_rows: Array[Dictionary] = _viewport.get_flat_rows()
    for index in range(flat_rows.size()):
        var row_data: EventRowData = flat_rows[index].get("row")
        if row_data != null and row_data.source_resource == resource_entry:
            return index
    return -1

func _context_condition_is_negated() -> bool:
    if _context_row == null or not (_context_row.source_resource is EventRow):
        return false
    var event_row: EventRow = _context_row.source_resource as EventRow
    var metadata: Dictionary = _context_hit.get("span_metadata", {})
    var kind: String = str(metadata.get("kind", ""))
    var ace_index: int = int(metadata.get("ace_index", -1))
    if kind == "trigger" and event_row.trigger != null:
        return event_row.trigger.negated
    if kind == "condition" and ace_index >= 0 and ace_index < event_row.conditions.size():
        return event_row.conditions[ace_index].negated
    return false

func _ace_entry_uses_variable(entry: Resource, var_name: String) -> bool:
    if entry == null:
        return false
    if entry is ACECondition:
        var condition_entry: ACECondition = entry as ACECondition
        var condition_params: Dictionary = condition_entry.params
        if condition_params.is_empty():
            condition_params = condition_entry.parameters
        return _dictionary_uses_variable(condition_params, var_name, 0)
    if entry is ACEAction:
        var action_entry: ACEAction = entry as ACEAction
        var action_params: Dictionary = action_entry.params
        if action_params.is_empty():
            action_params = action_entry.parameters
        return _dictionary_uses_variable(action_params, var_name, 0)
    return false

func _dictionary_uses_variable(values: Dictionary, var_name: String, depth: int) -> bool:
    if depth >= VARIABLE_USAGE_MAX_DEPTH or values.is_empty() or var_name.is_empty():
        return false
    for value in values.values():
        if value is Dictionary and _dictionary_uses_variable(value as Dictionary, var_name, depth + 1):
            return true
        if value is Array:
            for nested_value in value:
                if nested_value is Dictionary and _dictionary_uses_variable(nested_value as Dictionary, var_name, depth + 1):
                    return true
                if nested_value == var_name:
                    return true
        elif str(value) == var_name:
            return true
    return false

func _build_ace_edit_context(event_row: EventRow, span_index: int, metadata: Dictionary) -> Dictionary:
    if event_row == null:
        return {}
    var ace_index: int = int(metadata.get("ace_index", -1))
    var kind: String = str(metadata.get("kind", ""))
    var definition: ACEDefinition = null
    var existing_params: Dictionary = {}
    var mode: String = ""
    match kind:
        "trigger":
            if event_row.trigger == null:
                return {}
            definition = _find_definition(event_row.trigger.provider_id, event_row.trigger.ace_id)
            existing_params = event_row.trigger.params if not event_row.trigger.params.is_empty() else event_row.trigger.parameters
            mode = "replace_trigger"
        "condition":
            if ace_index < 0 or ace_index >= event_row.conditions.size():
                return {}
            var condition_entry: ACECondition = event_row.conditions[ace_index]
            definition = _find_definition(condition_entry.provider_id, condition_entry.ace_id)
            existing_params = condition_entry.params if not condition_entry.params.is_empty() else condition_entry.parameters
            mode = "replace_condition"
        "action":
            if ace_index < 0 or ace_index >= event_row.actions.size() or not (event_row.actions[ace_index] is ACEAction):
                return {}
            var action_entry: ACEAction = event_row.actions[ace_index] as ACEAction
            definition = _find_definition(action_entry.provider_id, action_entry.ace_id)
            existing_params = action_entry.params if not action_entry.params.is_empty() else action_entry.parameters
            mode = "replace_action"
        _:
            return {}
    return {
        "mode": mode,
        "selected_resource": event_row,
        "row_data": _context_row,
        "definition": definition,
        "existing_params": existing_params.duplicate(true),
        "ace_index": ace_index,
        "span_index": span_index,
        "kind": kind
    }

func _find_definition(provider_id: String, ace_id: String) -> ACEDefinition:
    if _ace_registry == null:
        return null
    return _ace_registry.find_definition(provider_id, ace_id)


func _refresh_variable_panel() -> void:
    if _global_var_list == null or _local_var_list == null:
        return
    _global_var_list.clear()
    _local_var_list.clear()
    _global_variable_entries.clear()
    _local_variable_entries.clear()
    if _current_sheet != null:
        var names: Array = _current_sheet.variables.keys()
        names.sort()
        for var_name in names:
            var descriptor: Dictionary = _current_sheet.variables.get(var_name, {})
            _global_var_list.add_item("%s : %s = %s" % [var_name, str(descriptor.get("type", "Variant")), str(descriptor.get("default", ""))])
            _global_variable_entries.append({
                "name": var_name,
                "type": str(descriptor.get("type", "Variant")),
                "default": descriptor.get("default", "")
            })
    var selected_resource: Resource = _viewport.get_selected_context().get("source_resource", null)
    if selected_resource is EventRow:
        for index in range((selected_resource as EventRow).local_variables.size()):
            var local_var: LocalVariable = (selected_resource as EventRow).local_variables[index]
            if local_var == null:
                continue
            _local_var_list.add_item("%s : %s = %s" % [local_var.name, local_var.type_name, str(local_var.default_value)])
            _local_variable_entries.append({
                "index": index,
                "name": local_var.name,
                "type": local_var.type_name,
                "default": local_var.default_value,
                "selected_resource": selected_resource
            })

func _find_first_event_row_resource() -> EventRow:
    if _viewport == null:
        return null
    for row_entry: Dictionary in _viewport.get_flat_rows():
        var row_data: EventRowData = row_entry.get("row")
        if row_data != null and row_data.source_resource is EventRow:
            return row_data.source_resource as EventRow
    return null

func _select_first_event_row() -> void:
    if _viewport == null:
        return
    var rows: Array[Dictionary] = _viewport.get_flat_rows()
    for row_index: int in range(rows.size()):
        var row_data: EventRowData = rows[row_index].get("row")
        if row_data != null and row_data.source_resource is EventRow:
            _viewport._select_row(row_index)
            return

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
