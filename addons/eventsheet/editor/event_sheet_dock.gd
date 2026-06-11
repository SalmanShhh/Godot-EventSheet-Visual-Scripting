@tool
class_name EventSheetDock
extends Control

const EVENT_SHEET_FILTERS: Array[String] = ["*.tres ; EventSheetResource", "*.res ; EventSheetResource", "*.gd ; GDScript (open as EventSheet)"]
const VARIABLE_USAGE_MAX_DEPTH := 8
const CONDITION_MENU_EDIT := 1
const CONDITION_MENU_ADD := 2
const CONDITION_MENU_REPLACE := 3
const CONDITION_MENU_INVERT := 4
const CONDITION_MENU_DELETE := 5
const CONDITION_MENU_TOGGLE_ENABLED := 6
const CONDITION_MENU_EDIT_ACE_COMMENT := 21
const ACTION_MENU_EDIT := 1
const ACTION_MENU_ADD := 2
const ACTION_MENU_REPLACE := 3
const ACTION_MENU_DELETE := 4
const ACTION_MENU_TOGGLE_ENABLED := 5
const ACTION_MENU_EDIT_ACE_COMMENT := 21
const ROW_MENU_ADD_SUB_EVENT := 1
const ROW_MENU_ADD_EVENT_BELOW := 2
const ROW_MENU_ADD_GROUP_BELOW := 3
const ROW_MENU_ADD_COMMENT_BELOW := 4
const ROW_MENU_COPY := 5
const ROW_MENU_PASTE := 6
const ROW_MENU_DELETE := 7
const ROW_MENU_TOGGLE_CONDITION_BLOCK := 8
const ROW_MENU_TOGGLE_GROUP_FOLD := 9
const ROW_MENU_ADD_SUB_CONDITION := 10
const ROW_MENU_TOGGLE_ENABLED := 11
const ROW_MENU_ADD_VARIABLE_BELOW := 12
const ROW_MENU_ADD_COMMENT_SUB_EVENT := 13
const ROW_MENU_ADD_GDSCRIPT_BELOW := 14
const ROW_MENU_ADD_GDSCRIPT_ACTION := 15
const ROW_MENU_EDIT_COMMENT := 16
const ROW_MENU_ATTACH_COMMENT := 17
const ACTION_MENU_DETACH_COMMENT := 6
const ROW_MENU_ADD_PICK_FILTER := 18
const ROW_MENU_ADD_ENUM := 19
const ROW_MENU_EDIT_GROUP_DESC := 20
const ROW_MENU_GROUP_COLOR := 27
const ROW_MENU_GROUP_RUNTIME := 28
const ROW_MENU_FIND_USAGES := 29
const ROW_MENU_ADD_SIGNAL := 21
const ROW_MENU_ADD_MATCH := 22
const ROW_MENU_OPEN_IN_SPLIT := 23
const VARIABLE_MENU_EDIT := 1
const VARIABLE_MENU_CONVERT_SCOPE := 2
const VARIABLE_MENU_TOGGLE_CONST := 3
const THEME_FILTERS: Array[String] = ["*.tres ; EventSheetEditorStyle", "*.res ; EventSheetEditorStyle"]
const EMPTY_MENU_NEW_EVENT := 1
const EMPTY_MENU_NEW_CONDITION := 2
const EMPTY_MENU_ADD_VARIABLE := 3
const ACE_DRAG_KINDS := ["condition", "action"]
const SIDE_PANEL_MIN_WIDTH := 160.0
const SIDE_PANEL_MAX_WIDTH := 220.0
const SIDE_PANEL_WIDTH_RATIO := 0.18

var _toolbar: HBoxContainer = null
var _title_strip: HBoxContainer = null
var _title_tab_label: Label = null
var _title_path_label: Label = null
var _title_dirty_dot: Label = null
var _status_label: Label = null
var _theme_picker: OptionButton = null
var _provider_dialog: Window = null
var _provider_list: ItemList = null
var _provider_file_dialog: FileDialog = null
var _split: HSplitContainer = null
var _scroll: ScrollContainer = null
var _column_header: SheetColumnHeader = null
var _identity_banner: SheetIdentityBanner = null
var _viewport: EventSheetViewport = null
var _side_panel: VBoxContainer = null
var _preview_window: Window = null
var _preview_title: Label = null
var _preview_list: ItemList = null
var _global_var_list: ItemList = null
var _local_var_list: ItemList = null

var _current_sheet: EventSheetResource = null  # the ACTIVE tab's sheet
var _current_sheet_path: String = ""           # the ACTIVE tab's path
var _dirty: bool = false                        # the ACTIVE tab's dirty flag
# Open sheet tabs. Each entry: {sheet: EventSheetResource, path: String, dirty: bool}.
# The active tab's live state mirrors _current_sheet/_current_sheet_path/_dirty.
var _open_tabs: Array[Dictionary] = []
var _active_tab_index: int = -1
var _tab_bar: TabBar = null
var _suppress_tab_signal: bool = false
# Provider class -> autoload name (rebuilt with the registry): lets picked bus triggers
# bake "autoload:<Name>" sources so consumers connect by singleton name.
var _autoload_provider_names: Dictionary = {}
var _autoload_annotation_regex: RegEx = null
var _ace_registry: EventSheetACERegistry = EventSheetACERegistry.new()
var _editor_param_store: EditorParamStore = EditorParamStore.new()
var _param_resolver: ParamDefaultResolver = ParamDefaultResolver.new()
var _exposed_node: EventSheetExposedNode = EventSheetExposedNode.new()
var _ace_sources: Array[Object] = []  # instances we created (sheet providers / demo); freed on refresh
var _manual_ace_sources: Array[Object] = []  # externally supplied (caller-owned, not freed)
var _clipboard: Dictionary = {}
var _undo_redo_adapter: EventSheetUndoRedoAdapter = EventSheetUndoRedoAdapter.new()

# ── Extracted sub-components ─────────────────────────────────────────────────
var _ace_picker: ACEPickerDialog = ACEPickerDialog.new()
var _ace_params: ACEParamsDialog = ACEParamsDialog.new()
var _variable_dlg: VariableDialog = VariableDialog.new()
var _condition_context_menu: PopupMenu = null
var _action_context_menu: PopupMenu = null
var _row_context_menu: PopupMenu = null
var _variable_context_menu: PopupMenu = null
var _empty_space_context_menu: PopupMenu = null
var _theme_file_dialog: FileDialog = null
var _context_row: EventRowData = null
var _context_hit: Dictionary = {}
var _context_variable: Dictionary = {}
var _global_variable_entries: Array[Dictionary] = []
var _local_variable_entries: Array[Dictionary] = []
var _active_theme_style: EventSheetEditorStyle = null

func _init() -> void:
    if not _undo_redo_adapter.has_manager():
        _undo_redo_adapter.set_manager(UndoRedo.new())
    _build_ui()

func _ready() -> void:
    _build_ui()
    _param_resolver.set_param_store(_editor_param_store)
    _ace_picker.init_dialog(self, _ace_registry)
    _ace_picker.ace_selected.connect(_on_ace_picker_selected)
    _ace_params.init_dialog(self, _ace_registry, _collect_sheet_variable_names)
    _ace_params.set_lint_context_provider(func() -> EventSheetResource: return _current_sheet)
    _ace_params.params_confirmed.connect(_on_ace_params_confirmed)
    _ace_params.back_requested.connect(_on_ace_params_back_requested)
    _variable_dlg.init_dialog(self)
    _variable_dlg.variable_confirmed.connect(_on_variable_dialog_confirmed)
    _refresh_ace_registry()
    if _current_sheet == null:
        _current_sheet = _build_demo_sheet()
        _viewport.set_debug_overlay_states({})
    setup(_current_sheet)

func setup(sheet: EventSheetResource = null) -> void:
    _build_ui()
    var target_sheet: EventSheetResource = sheet if sheet != null else _build_demo_sheet()
    var target_path: String = sheet.resource_path if sheet != null else ""
    _open_sheet_in_tab(target_sheet, target_path)

## Opens a sheet in a tab — activating its existing tab if already open, else adding one.
func _open_sheet_in_tab(sheet: EventSheetResource, path: String) -> void:
    for i in range(_open_tabs.size()):
        if _open_tabs[i].get("sheet") == sheet:
            _activate_tab(i)
            return
    _sync_active_tab_state()
    _open_tabs.append({"sheet": sheet, "path": path, "dirty": false})
    _activate_tab(_open_tabs.size() - 1)

## Makes the tab at index active, loading its sheet into the shared viewport.
func _activate_tab(index: int) -> void:
    if index < 0 or index >= _open_tabs.size():
        return
    if index != _active_tab_index:
        _sync_active_tab_state()
    _active_tab_index = index
    var tab: Dictionary = _open_tabs[index]
    _current_sheet = tab.get("sheet")
    _current_sheet_path = str(tab.get("path", ""))
    _dirty = bool(tab.get("dirty", false))
    _viewport.set_debug_overlay_states({})
    _clear_undo_history()
    _refresh_ace_registry()
    _viewport.set_sheet(_current_sheet)
    _sync_split_sheet()
    _sync_active_theme_binding()
    _refresh_title_strip()
    _refresh_theme_picker_selection()
    _refresh_exposed_node()
    _refresh_variable_panel()
    _refresh_tab_bar()
    var label: String = _current_sheet_path.get_file() if not _current_sheet_path.is_empty() else "(unsaved EventSheet)"
    _set_status("Loaded: %s" % label)

## Persists the live active-tab state (_current_sheet/path/dirty) back into _open_tabs.
func _sync_active_tab_state() -> void:
    if _active_tab_index < 0 or _active_tab_index >= _open_tabs.size():
        return
    _open_tabs[_active_tab_index] = {"sheet": _current_sheet, "path": _current_sheet_path, "dirty": _dirty}

## Closes the tab at index, activating a neighbour (or a fresh demo sheet when none remain).
func _close_tab(index: int) -> void:
    if index < 0 or index >= _open_tabs.size():
        return
    _open_tabs.remove_at(index)
    _active_tab_index = -1
    if _open_tabs.is_empty():
        setup(null)
        return
    _activate_tab(mini(index, _open_tabs.size() - 1))

func _refresh_tab_bar() -> void:
    if _tab_bar == null:
        return
    _suppress_tab_signal = true
    _tab_bar.clear_tabs()
    for tab: Dictionary in _open_tabs:
        _tab_bar.add_tab(_format_tab_title(tab.get("sheet"), str(tab.get("path", "")), bool(tab.get("dirty", false))))
    if _active_tab_index >= 0 and _active_tab_index < _tab_bar.get_tab_count():
        _tab_bar.current_tab = _active_tab_index
    _tab_bar.visible = _open_tabs.size() >= 1
    _suppress_tab_signal = false

func _update_active_tab_title() -> void:
    if _tab_bar == null or _active_tab_index < 0 or _active_tab_index >= _tab_bar.get_tab_count():
        return
    _suppress_tab_signal = true
    _tab_bar.set_tab_title(_active_tab_index, _format_tab_title(_current_sheet, _current_sheet_path, _dirty))
    _suppress_tab_signal = false

func _format_tab_title(sheet: EventSheetResource, path: String, dirty: bool) -> String:
    var title: String = _format_sheet_title(sheet, path)
    # Sheet-type badges: ⚙ behavior, ◆ custom node (C3 users expect typed tabs).
    if sheet != null and sheet.behavior_mode:
        title = "⚙ " + title
    elif sheet != null and not sheet.custom_class_name.strip_edges().is_empty():
        title = "◆ " + title
    return ("● " + title) if dirty else title

func _on_tab_selected(index: int) -> void:
    if not _suppress_tab_signal:
        _activate_tab(index)

func _on_tab_close_pressed(index: int) -> void:
    if not _suppress_tab_signal:
        _close_tab(index)

## Number of open sheet tabs.
func get_open_tab_count() -> int:
    return _open_tabs.size()

## Index of the active tab (-1 when none).
func get_active_tab_index() -> int:
    return _active_tab_index

## Activates a tab by index (public entry point for tab navigation).
func activate_tab(index: int) -> void:
    _activate_tab(index)

## Whether the tab at index has unsaved changes.
func is_tab_dirty(index: int) -> bool:
    if index < 0 or index >= _open_tabs.size():
        return false
    return bool(_open_tabs[index].get("dirty", false))

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

func use_default_theme() -> bool:
    if _current_sheet == null or _current_sheet.editor_style == null:
        return false
    var changed: bool = _perform_undoable_sheet_edit("Set Default Theme", func() -> bool:
        _current_sheet.editor_style = null
        return true
    )
    if changed:
        _refresh_after_edit()
    return changed

func load_theme_style_from_path(path: String) -> bool:
    if _current_sheet == null:
        return false
    var resolved_path: String = path.strip_edges()
    if resolved_path.is_empty():
        _set_status("Theme load failed: no file selected.", true)
        return false
    var loaded: Resource = ResourceLoader.load(resolved_path)
    if not (loaded is EventSheetEditorStyle):
        _set_status("Theme load failed: %s is not an EventSheetEditorStyle." % resolved_path.get_file(), true)
        return false
    var changed: bool = _perform_undoable_sheet_edit("Set Theme", func() -> bool:
        _current_sheet.editor_style = loaded as EventSheetEditorStyle
        return true
    )
    if changed:
        _refresh_after_edit()
        _mark_dirty("Applied theme: %s." % resolved_path.get_file())
    return changed

func reload_active_theme() -> bool:
    if _current_sheet == null:
        _set_status("Reload theme failed: no sheet loaded.", true)
        return false
    var active_style: EventSheetEditorStyle = _current_sheet.editor_style
    if active_style == null:
        _set_status("Reload theme failed: no active style.", true)
        return false
    var style_path: String = active_style.resource_path
    if style_path.is_empty():
        _set_status("Reload theme failed: active style is unsaved.", true)
        return false
    var reloaded: Resource = ResourceLoader.load(style_path, "", ResourceLoader.CACHE_MODE_REPLACE)
    if not (reloaded is EventSheetEditorStyle):
        _set_status("Reload theme failed: could not load resource.", true)
        return false
    _current_sheet.editor_style = reloaded as EventSheetEditorStyle
    _refresh_after_edit()
    return true

func set_undo_redo_manager(undo_redo: Variant) -> void:
    if undo_redo == null:
        return
    _undo_redo_adapter.set_manager(undo_redo)
    if _exposed_node != null:
        _exposed_node.set_undo_redo_manager(_undo_redo_adapter.get_manager())
    if not _exposed_node.row_param_changed.is_connected(_on_exposed_row_param_changed):
        _exposed_node.row_param_changed.connect(_on_exposed_row_param_changed)

func set_auto_ace_sources(sources: Array[Object]) -> void:
    _manual_ace_sources = sources.duplicate()
    _refresh_ace_registry()

## Registers a GDScript file as a custom-ACE provider on the current sheet. Its annotated
## methods/signals/exported properties then appear in the ACE picker.
func add_ace_provider_script(path: String) -> bool:
    if not _ensure_sheet_for_editing():
        return false
    var clean_path: String = path.strip_edges()
    if clean_path.is_empty() or _current_sheet.ace_provider_scripts.has(clean_path):
        return false
    var probe: Object = _instantiate_provider_script(clean_path)
    if probe == null:
        _set_status("Not a usable ACE provider script: %s" % clean_path.get_file(), true)
        return false
    if probe is Node:
        (probe as Node).free()
    var changed: bool = _perform_undoable_sheet_edit("Add ACE Provider", func() -> bool:
        _current_sheet.ace_provider_scripts.append(clean_path)
        return true
    )
    if changed:
        _refresh_ace_registry()
        _refresh_provider_list()
        _mark_dirty("Added ACE provider: %s" % clean_path.get_file())
    return changed

## Removes a registered custom-ACE provider script from the current sheet.
func remove_ace_provider_script(path: String) -> bool:
    if not _ensure_sheet_for_editing():
        return false
    if not _current_sheet.ace_provider_scripts.has(path):
        return false
    var changed: bool = _perform_undoable_sheet_edit("Remove ACE Provider", func() -> bool:
        _current_sheet.ace_provider_scripts.erase(path)
        return true
    )
    if changed:
        _refresh_ace_registry()
        _refresh_provider_list()
        _mark_dirty("Removed ACE provider: %s" % path.get_file())
    return changed

func get_ace_provider_scripts() -> PackedStringArray:
    var output: PackedStringArray = PackedStringArray()
    if _current_sheet == null:
        return output
    for path: Variant in _current_sheet.ace_provider_scripts:
        output.append(str(path))
    return output

func _on_manage_ace_providers_requested() -> void:
    if not _ensure_sheet_for_editing():
        return
    _build_provider_dialog()
    _refresh_provider_list()
    _provider_dialog.popup_centered(Vector2i(560, 420))

func _build_provider_dialog() -> void:
    if _provider_dialog != null:
        return
    _provider_dialog = Window.new()
    _provider_dialog.title = "Custom ACE Providers"
    _provider_dialog.visible = false
    _provider_dialog.min_size = Vector2i(460, 320)
    _provider_dialog.close_requested.connect(func() -> void: _provider_dialog.hide())
    add_child(_provider_dialog)

    var margin: MarginContainer = MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 10)
    margin.add_theme_constant_override("margin_right", 10)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 10)
    _provider_dialog.add_child(margin)

    var content: VBoxContainer = VBoxContainer.new()
    content.add_theme_constant_override("separation", 8)
    margin.add_child(content)

    var hint: Label = Label.new()
    hint.text = "Register GDScript files whose methods, signals and exported variables become custom ACEs.\nZero-config alternative: drop scripts into res://eventsheet_addons/ and they register project-wide automatically."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(hint)

    _provider_list = ItemList.new()
    _provider_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _provider_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(_provider_list)

    var buttons: HBoxContainer = HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 6)
    content.add_child(buttons)
    var add_button: Button = Button.new()
    add_button.text = "Add…"
    add_button.pressed.connect(_on_provider_add_pressed)
    buttons.add_child(add_button)
    var remove_button: Button = Button.new()
    remove_button.text = "Remove Selected"
    remove_button.pressed.connect(_on_provider_remove_pressed)
    buttons.add_child(remove_button)

    _provider_file_dialog = FileDialog.new()
    _provider_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    _provider_file_dialog.access = FileDialog.ACCESS_RESOURCES
    _provider_file_dialog.filters = PackedStringArray(["*.gd ; GDScript"])
    _provider_file_dialog.file_selected.connect(_on_provider_file_selected)
    _provider_dialog.add_child(_provider_file_dialog)

func _refresh_provider_list() -> void:
    if _provider_list == null:
        return
    _provider_list.clear()
    for path in get_ace_provider_scripts():
        _provider_list.add_item(path)

func _on_provider_add_pressed() -> void:
    if _provider_file_dialog != null:
        _provider_file_dialog.popup_centered(Vector2i(720, 520))

func _on_provider_file_selected(path: String) -> void:
    add_ace_provider_script(path)

func _on_provider_remove_pressed() -> void:
    if _provider_list == null:
        return
    var selected: PackedInt32Array = _provider_list.get_selected_items()
    if selected.is_empty():
        return
    remove_ace_provider_script(_provider_list.get_item_text(selected[0]))

func _build_ui() -> void:
    if _toolbar != null:
        return
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL

    var root: VBoxContainer = VBoxContainer.new()
    root.name = "EventSheetWorkspaceRoot"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    root.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(root)

    _toolbar = HBoxContainer.new()
    _toolbar.name = "EventSheetToolbar"
    _toolbar.add_theme_constant_override("separation", 4)
    root.add_child(_toolbar)

    _add_toolbar_button("New…", _open_template_menu)
    _add_toolbar_button("Open", _on_open_requested)
    _add_toolbar_button("Save", _on_save_requested)
    _add_toolbar_button("Save As", _on_save_as_requested)
    _add_toolbar_button("Export Addon…", _export_addon_pack)
    # Debug + addon-author tools live in one menu — the toolbar had grown past 25
    # buttons (UX audit finding); these six are workflow tools, not per-row editing.
    var tools_menu: MenuButton = MenuButton.new()
    tools_menu.text = "Tools"
    tools_menu.flat = false
    var tools_popup: PopupMenu = tools_menu.get_popup()
    tools_popup.add_item("Debug Breakpoints (toggle)", 0)
    tools_popup.add_item("Live Values (toggle)", 1)
    tools_popup.add_item("Bookmarks…", 2)
    tools_popup.add_separator()
    tools_popup.add_item("Register Autoload", 3)
    tools_popup.add_item("Publish Preview…", 4)
    tools_popup.add_item("Test Bench", 5)
    tools_popup.add_separator()
    tools_popup.add_item("Find in Project…", 6)
    tools_popup.add_item("Project Doctor…", 7)
    tools_popup.add_item("Vocabulary Doc", 8)
    tools_popup.add_separator()
    tools_popup.add_item("Sheet Backups…", 9)
    tools_popup.add_item("Save as Template", 10)
    tools_popup.id_pressed.connect(func(id: int) -> void:
        match id:
            0: _toggle_breakpoint_emission()
            1: _toggle_live_values()
            2: _open_bookmarks_panel()
            3: _register_autoload()
            4: _open_publish_preview()
            5: _open_test_bench()
            6: _open_project_find()
            7: _open_project_doctor()
            8: _generate_vocabulary_doc()
            9: _open_sheet_backups()
            10: _save_as_project_template()
    )
    _toolbar.add_child(tools_menu)
    _add_toolbar_button("Split", _toggle_split_view)
    _add_toolbar_button("Detach", _toggle_detached_view)
    _add_toolbar_button("Link", _toggle_linked_views)
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
    _add_toolbar_separator()
    var theme_label: Label = Label.new()
    theme_label.text = "Theme:"
    _toolbar.add_child(theme_label)
    _theme_picker = OptionButton.new()
    _theme_picker.name = "EventSheetThemePicker"
    _theme_picker.tooltip_text = "Switch the editor theme for this sheet"
    _theme_picker.item_selected.connect(_on_theme_preset_selected)
    _toolbar.add_child(_theme_picker)
    _populate_theme_picker()
    _add_toolbar_button("Load Theme…", _on_load_theme_requested)
    _add_toolbar_button("Reload Theme", _on_reload_theme_requested)
    _add_toolbar_separator()
    _add_toolbar_button("ACE Providers…", _on_manage_ace_providers_requested)
    _add_toolbar_button("GDScript", _toggle_code_panel)
    _add_toolbar_button("Sheet Type…", _open_sheet_type_dialog)
    _add_toolbar_button("Theme Editor…", _open_theme_editor)
    _quick_add_edit = LineEdit.new()
    _quick_add_edit.placeholder_text = "Quick add…  (e.g. every tick, heal 5)"
    _quick_add_edit.tooltip_text = "C3-style quick add: type an event/condition/action (C3 phrasing works) plus optional parameter values, press Enter."
    _quick_add_edit.custom_minimum_size = Vector2(190.0, 0.0)
    _quick_add_edit.text_submitted.connect(func(text: String) -> void:
        if _quick_add(text):
            _quick_add_edit.clear()
    )
    _toolbar.add_child(_quick_add_edit)

    _tab_bar = TabBar.new()
    _tab_bar.name = "EventSheetTabBar"
    _tab_bar.clip_tabs = true
    _tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ALWAYS
    _tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _tab_bar.tab_selected.connect(_on_tab_selected)
    _tab_bar.tab_close_pressed.connect(_on_tab_close_pressed)
    root.add_child(_tab_bar)

    _title_strip = HBoxContainer.new()
    _title_strip.name = "EventSheetTitleStrip"
    _title_strip.add_theme_constant_override("separation", 8)
    root.add_child(_title_strip)

    var title_tab_shell: PanelContainer = PanelContainer.new()
    title_tab_shell.name = "EventSheetTitleTab"
    _title_strip.add_child(title_tab_shell)

    var title_tab_content: HBoxContainer = HBoxContainer.new()
    title_tab_content.add_theme_constant_override("separation", 4)
    title_tab_shell.add_child(title_tab_content)

    _title_tab_label = Label.new()
    _title_tab_label.name = "EventSheetTitleTabLabel"
    _title_tab_label.text = "No Sheet Loaded"
    title_tab_content.add_child(_title_tab_label)

    _title_dirty_dot = Label.new()
    _title_dirty_dot.name = "EventSheetTitleDirtyDot"
    _title_dirty_dot.text = "●"
    _title_dirty_dot.modulate = Color(0.99, 0.78, 0.30, 1.0)
    _title_dirty_dot.visible = false
    title_tab_content.add_child(_title_dirty_dot)

    _title_path_label = Label.new()
    _title_path_label.name = "EventSheetTitlePath"
    _title_path_label.modulate = Color(0.72, 0.76, 0.84, 1.0)
    _title_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _title_path_label.clip_text = true
    _title_path_label.text = "Open or create a sheet to begin"
    _title_strip.add_child(_title_path_label)

    # Pinned Conditions/Actions column header, above the scrolling sheet (bound to the
    # viewport once it exists). Kept outside the scroll so the scroll still has a single child.
    _identity_banner = SheetIdentityBanner.new()
    root.add_child(_identity_banner)
    _identity_banner.edit_requested.connect(_open_sheet_type_dialog)

    _column_header = SheetColumnHeader.new()
    root.add_child(_column_header)

    _scroll = ScrollContainer.new()
    _scroll.name = "EventSheetScroll"
    _scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    root.add_child(_scroll)

    _viewport = EventSheetViewport.new()
    _viewport.name = "EventSheetViewport"
    _viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _viewport.set_ace_registry(_ace_registry)
    _scroll.add_child(_viewport)
    _column_header.setup(_viewport)
    _identity_banner.setup(_viewport)

    _viewport.selection_changed.connect(_on_viewport_selection_changed)
    _viewport.selection_changed.connect(func(row_data: EventRowData) -> void:
        if _mirroring_selection:
            return  # a mirrored selection must not steal the active view
        _active_viewport_ref = _viewport
        _mirror_selection(_viewport, row_data)
    )
    _viewport.row_drop_requested.connect(_on_row_drop_requested)
    _viewport.rows_drop_requested.connect(_on_rows_drop_requested)
    _viewport.ace_preview_requested.connect(_on_ace_preview_requested)
    _viewport.ace_picker_requested.connect(_on_viewport_ace_picker_requested)
    _viewport.span_edit_requested.connect(_on_viewport_span_edit_requested)
    _viewport.ace_edit_requested.connect(_on_viewport_ace_edit_requested)
    _viewport.param_value_edit_requested.connect(_on_param_value_edit_requested)
    _viewport.variable_edit_requested.connect(_on_viewport_variable_edit_requested)
    _viewport.comment_edit_requested.connect(_open_comment_dialog)
    _viewport.pick_filter_edit_requested.connect(_open_pick_filter_dialog)
    _viewport.enum_edit_requested.connect(_open_enum_dialog)
    _viewport.signal_edit_requested.connect(_open_signal_dialog)
    _viewport.match_edit_requested.connect(_open_match_dialog)
    _viewport.row_disable_toggle_requested.connect(_toggle_selected_rows_enabled)
    _viewport.row_move_requested.connect(_move_selected_row)
    _viewport.find_requested.connect(_show_find_bar)
    _viewport.find_step_requested.connect(_find_step)
    _apply_editor_native_defaults()
    _viewport.ace_drop_requested.connect(_on_viewport_ace_drop_requested)
    _viewport.drag_status_requested.connect(_on_viewport_drag_status_requested)
    _viewport.lane_ratio_changed.connect(_on_viewport_lane_ratio_changed)
    _viewport.add_event_requested.connect(_on_viewport_add_event_requested)
    _viewport.raw_code_edit_requested.connect(_on_viewport_raw_code_edit_requested)
    _viewport.context_menu_requested.connect(_on_viewport_context_menu_requested)
    _viewport.empty_space_double_clicked.connect(_on_viewport_empty_space_double_clicked)
    _viewport.empty_space_context_menu_requested.connect(_on_viewport_empty_space_context_menu_requested)
    _viewport.set_external_span_edit_handler_enabled(true)

    _status_label = Label.new()
    _status_label.name = "EventSheetStatus"
    _status_label.text = "Ready"
    root.add_child(_status_label)

    _exposed_node.name = "EventSheetExposedParams"
    add_child(_exposed_node)
    _exposed_node.setup(_ace_registry, _editor_param_store, _current_sheet, _param_resolver)
    _exposed_node.set_undo_redo_manager(_undo_redo_adapter.get_manager())
    _build_context_menus()
    _build_preview_window()
    _build_theme_file_dialog()

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        if _active_theme_style != null and _active_theme_style.changed.is_connected(_on_active_theme_style_changed):
            _active_theme_style.changed.disconnect(_on_active_theme_style_changed)
        _active_theme_style = null
        _release_ace_sources()
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
        # GDScript-backed sheets: refocusing the editor is the moment external edits (the
        # script editor, another tool, git) usually land — offer to reload from disk.
        _prompt_external_reload_if_changed()

# ── External sheet file watching (GDScript-backed sheets) ────────────────────
# mtime of the active external .gd at open/save time; divergence = changed on disk.
var _external_mtime: int = 0
var _external_reload_dialog: ConfirmationDialog = null

## True when the active GDScript-backed sheet's file changed on disk since open/save.
func _external_sheet_changed_on_disk() -> bool:
    if _current_sheet == null or _current_sheet.external_source_path.is_empty():
        return false
    var disk_mtime: int = FileAccess.get_modified_time(_current_sheet.external_source_path)
    return disk_mtime != 0 and _external_mtime != 0 and disk_mtime != _external_mtime

## Re-imports the active external sheet from disk (fresh lossless import + ACE lift).
func _reload_external_sheet() -> void:
    if _current_sheet == null or _current_sheet.external_source_path.is_empty():
        return
    _load_sheet_from_path(_current_sheet.external_source_path)
    _set_status("Reloaded from disk: %s" % _current_sheet_path.get_file())

func _prompt_external_reload_if_changed() -> void:
    if not _external_sheet_changed_on_disk():
        return
    if _external_reload_dialog == null:
        _external_reload_dialog = ConfirmationDialog.new()
        _external_reload_dialog.title = "File Changed On Disk"
        _external_reload_dialog.ok_button_text = "Reload"
        _external_reload_dialog.cancel_button_text = "Keep Editor Version"
        _external_reload_dialog.confirmed.connect(_reload_external_sheet)
        # Keeping the editor version: remember the new mtime so we only ask once per change.
        _external_reload_dialog.canceled.connect(func() -> void:
            if _current_sheet != null:
                _external_mtime = FileAccess.get_modified_time(_current_sheet.external_source_path)
        )
        add_child(_external_reload_dialog)
    _external_reload_dialog.dialog_text = "%s was modified outside the sheet editor.
Reload it (re-import + event lifting)? Unsaved sheet edits will be lost." % _current_sheet.external_source_path.get_file()
    _external_reload_dialog.popup_centered(Vector2i(460, 160))

func _build_preview_window() -> void:
    if _preview_window != null:
        return
    _preview_window = Window.new()
    _preview_window.name = "ACEPreviewWindow"
    _preview_window.title = "Dropped ACE Preview"
    _preview_window.visible = false
    _preview_window.min_size = Vector2i(480, 280)
    _preview_window.close_requested.connect(func() -> void:
        if _preview_window != null:
            _preview_window.hide()
    )
    add_child(_preview_window)

    var content: VBoxContainer = VBoxContainer.new()
    content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _preview_window.add_child(content)

    _preview_title = Label.new()
    _preview_title.name = "ACEPreviewTitle"
    _preview_title.text = "Dropped ACE Preview"
    content.add_child(_preview_title)

    _preview_list = ItemList.new()
    _preview_list.name = "ACEPreviewList"
    _preview_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _preview_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(_preview_list)

func _build_theme_file_dialog() -> void:
    if _theme_file_dialog != null:
        return
    _theme_file_dialog = FileDialog.new()
    _theme_file_dialog.name = "EventSheetThemeFileDialog"
    _theme_file_dialog.title = "Load EventSheet Theme"
    _theme_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    _theme_file_dialog.access = FileDialog.ACCESS_RESOURCES
    _theme_file_dialog.filters = PackedStringArray(THEME_FILTERS)
    _theme_file_dialog.file_selected.connect(_on_theme_file_selected)
    add_child(_theme_file_dialog)

func _build_context_menus() -> void:
    if _condition_context_menu != null:
        return
    _condition_context_menu = PopupMenu.new()
    _condition_context_menu.add_item("Edit Condition", CONDITION_MENU_EDIT)
    _condition_context_menu.add_item("Add Condition", CONDITION_MENU_ADD)
    _condition_context_menu.add_item("Replace Condition", CONDITION_MENU_REPLACE)
    _condition_context_menu.add_separator()
    _condition_context_menu.add_item("Invert Condition", CONDITION_MENU_INVERT)
    _condition_context_menu.add_item("Disable Condition", CONDITION_MENU_TOGGLE_ENABLED)
    _condition_context_menu.add_item("Edit ACE Comment…", CONDITION_MENU_EDIT_ACE_COMMENT)
    _condition_context_menu.add_separator()
    _condition_context_menu.add_item("Delete Condition", CONDITION_MENU_DELETE)
    _condition_context_menu.id_pressed.connect(_on_condition_context_menu_id_pressed)
    add_child(_condition_context_menu)

    _action_context_menu = PopupMenu.new()
    _action_context_menu.add_item("Edit Action", ACTION_MENU_EDIT)
    _action_context_menu.add_item("Add Action", ACTION_MENU_ADD)
    _action_context_menu.add_item("Replace Action", ACTION_MENU_REPLACE)
    _action_context_menu.add_separator()
    _action_context_menu.add_item("Disable Action", ACTION_MENU_TOGGLE_ENABLED)
    _action_context_menu.add_item("Edit ACE Comment…", ACTION_MENU_EDIT_ACE_COMMENT)
    _action_context_menu.add_item("Detach Comment To Row", ACTION_MENU_DETACH_COMMENT)
    _action_context_menu.add_item("Delete Action", ACTION_MENU_DELETE)
    _action_context_menu.id_pressed.connect(_on_action_context_menu_id_pressed)
    add_child(_action_context_menu)

    _row_context_menu = PopupMenu.new()
    _row_context_menu.add_item("Add Sub-Event", ROW_MENU_ADD_SUB_EVENT)
    _row_context_menu.add_item("Add Comment Sub-Event", ROW_MENU_ADD_COMMENT_SUB_EVENT)
    _row_context_menu.add_item("Convert to OR Block", ROW_MENU_TOGGLE_CONDITION_BLOCK)
    _row_context_menu.add_item("Add Sub-Condition", ROW_MENU_ADD_SUB_CONDITION)
    _row_context_menu.add_item("Close Group", ROW_MENU_TOGGLE_GROUP_FOLD)
    _row_context_menu.add_item("Add Event Below", ROW_MENU_ADD_EVENT_BELOW)
    _row_context_menu.add_item("Add Group Below", ROW_MENU_ADD_GROUP_BELOW)
    _row_context_menu.add_item("Add Comment Below", ROW_MENU_ADD_COMMENT_BELOW)
    _row_context_menu.add_item("Add Variable Below", ROW_MENU_ADD_VARIABLE_BELOW)
    _row_context_menu.add_item("Add GDScript Block Below", ROW_MENU_ADD_GDSCRIPT_BELOW)
    _row_context_menu.add_item("Add GDScript Action", ROW_MENU_ADD_GDSCRIPT_ACTION)
    _row_context_menu.add_item("Add Pick Filter (For Each)…", ROW_MENU_ADD_PICK_FILTER)
    _row_context_menu.add_item("Add Enum Below", ROW_MENU_ADD_ENUM)
    _row_context_menu.add_item("Edit Group Description…", ROW_MENU_EDIT_GROUP_DESC)
    _row_context_menu.add_item("Group Color…", ROW_MENU_GROUP_COLOR)
    _row_context_menu.add_item("Runtime Toggleable (Set Group Active)", ROW_MENU_GROUP_RUNTIME)
    _row_context_menu.add_item("Find Usages (project)", ROW_MENU_FIND_USAGES)
    _row_context_menu.add_item("Add Signal Below", ROW_MENU_ADD_SIGNAL)
    _row_context_menu.add_item("Add Match To Actions…", ROW_MENU_ADD_MATCH)
    _row_context_menu.add_item("Open in Split", ROW_MENU_OPEN_IN_SPLIT)
    _row_context_menu.add_separator()
    _row_context_menu.add_item("Edit Comment…", ROW_MENU_EDIT_COMMENT)
    _row_context_menu.add_item("Attach Comment To Event Above", ROW_MENU_ATTACH_COMMENT)
    _row_context_menu.add_separator()
    _row_context_menu.add_item("Disable Row", ROW_MENU_TOGGLE_ENABLED)
    _row_context_menu.add_separator()
    _row_context_menu.add_item("Copy", ROW_MENU_COPY)
    _row_context_menu.add_item("Paste", ROW_MENU_PASTE)
    _row_context_menu.add_separator()
    _row_context_menu.add_item("Delete Row", ROW_MENU_DELETE)
    _row_context_menu.add_theme_font_size_override("font_size", 14)
    _row_context_menu.id_pressed.connect(_on_row_context_menu_id_pressed)
    add_child(_row_context_menu)

    _variable_context_menu = PopupMenu.new()
    _variable_context_menu.add_item("Edit Variable", VARIABLE_MENU_EDIT)
    _variable_context_menu.add_item("Convert Scope", VARIABLE_MENU_CONVERT_SCOPE)
    _variable_context_menu.add_item("Toggle Constant", VARIABLE_MENU_TOGGLE_CONST)
    _variable_context_menu.id_pressed.connect(_on_variable_context_menu_id_pressed)
    add_child(_variable_context_menu)

    _empty_space_context_menu = PopupMenu.new()
    _empty_space_context_menu.name = "EventSheetEmptySpaceContextMenu"
    _empty_space_context_menu.add_item("New Event", EMPTY_MENU_NEW_EVENT)
    _empty_space_context_menu.add_item("New Condition", EMPTY_MENU_NEW_CONDITION)
    _empty_space_context_menu.add_item("Add New Variable", EMPTY_MENU_ADD_VARIABLE)
    _empty_space_context_menu.id_pressed.connect(_on_empty_space_context_menu_id_pressed)
    add_child(_empty_space_context_menu)

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
    # Structural/letter shortcuts are suppressed while typing in a text field so authoring
    # keys never fire mid-edit (text fields already consume their own text shortcuts).
    var typing: bool = _text_field_has_focus()
    var shift: bool = key_event.shift_pressed
    if key_event.ctrl_pressed or key_event.meta_pressed:
        if key_event.keycode == KEY_C and shift:
            if not typing:
                _on_add_condition_requested()
                accept_event()
        elif key_event.keycode == KEY_C:
            _on_copy_requested()
            accept_event()
        elif key_event.keycode == KEY_V and shift:
            if not typing:
                _on_add_global_variable_requested()
                accept_event()
        elif key_event.keycode == KEY_V:
            _on_paste_requested()
            accept_event()
        elif key_event.keycode == KEY_A and shift:
            if not typing:
                _on_add_action_requested()
                accept_event()
        elif key_event.keycode == KEY_S and shift:
            _on_save_as_requested()
            accept_event()
        elif key_event.keycode == KEY_S:
            _on_save_requested()
            accept_event()
        elif key_event.keycode == KEY_E:
            if not typing:
                _on_add_event_requested()
                accept_event()
        elif key_event.keycode == KEY_D:
            if not typing:
                _on_duplicate_requested()
                accept_event()
        elif key_event.keycode == KEY_Z and shift:
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
        return
    if typing:
        return
    if key_event.keycode == KEY_Q:
        _on_add_comment_requested()
        accept_event()
    # C3 reflexes: E adds an event, C a condition, A an action (on the selection).
    elif key_event.keycode == KEY_E:
        _on_add_event_requested()
        accept_event()
    elif key_event.keycode == KEY_C:
        _on_add_condition_requested()
        accept_event()
    elif key_event.keycode == KEY_A:
        _on_add_action_requested()
        accept_event()
    elif key_event.keycode == KEY_G:
        _on_add_group_requested()
        accept_event()
    elif key_event.keycode == KEY_X:
        # Toggle enabled/disabled for the whole current selection (conditions, actions,
        # events, groups, comments) — single or multi-select.
        _toggle_selected_enabled()
        accept_event()
    elif key_event.keycode == KEY_TAB and shift:
        # Outdent (un-nest); only consume Tab when the move actually applies so normal
        # focus traversal still works when there is nothing to outdent.
        if _outdent_selected_event():
            accept_event()
    elif key_event.keycode == KEY_TAB:
        if _indent_selected_event():
            accept_event()
    elif key_event.keycode == KEY_BACKTAB:
        if _outdent_selected_event():
            accept_event()
    elif key_event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
        _delete_selected_content()
        accept_event()
    elif key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_F2]:
        if _viewport != null and _viewport.begin_edit_selected():
            accept_event()

## True when a text-input control owns keyboard focus (so authoring shortcuts are paused).
func _text_field_has_focus() -> bool:
    var view: Viewport = get_viewport()
    if view == null:
        return false
    var focus_owner: Control = view.gui_get_focus_owner()
    return focus_owner is LineEdit or focus_owner is TextEdit or focus_owner is SpinBox

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

func _on_load_theme_requested() -> void:
    if _theme_file_dialog == null:
        _build_theme_file_dialog()
    if _theme_file_dialog == null:
        _set_status("Theme picker unavailable.", true)
        return
    _theme_file_dialog.current_dir = _suggest_sheet_directory()
    _theme_file_dialog.popup_centered(Vector2i(760, 520))

func _on_theme_file_selected(path: String) -> void:
    load_theme_style_from_path(path)

func _on_set_default_theme_requested() -> void:
    if use_default_theme():
        _mark_dirty("Applied default theme.")
    else:
        _set_status("Default theme already active.", true)

func _on_reload_theme_requested() -> void:
    if reload_active_theme():
        _set_status("Reloaded active theme.")
    else:
        _set_status("Reload theme failed: no active style resource path.", true)

## Populates the toolbar theme switcher with "Default" plus the discovered bundled themes.
func _populate_theme_picker() -> void:
    if _theme_picker == null:
        return
    _theme_picker.clear()
    _theme_picker.add_item("Default")
    _theme_picker.set_item_metadata(0, "")
    for preset: Dictionary in EventSheetThemePresets.list_presets():
        _theme_picker.add_item(str(preset.get("name", "Theme")))
        _theme_picker.set_item_metadata(_theme_picker.item_count - 1, str(preset.get("path", "")))
    _refresh_theme_picker_selection()

## Selects the switcher entry matching the current sheet's active theme (Default if none).
func _refresh_theme_picker_selection() -> void:
    if _theme_picker == null:
        return
    var active_path: String = ""
    if _current_sheet != null and _current_sheet.editor_style != null:
        active_path = _current_sheet.editor_style.resource_path
    var target_index: int = 0
    for i in range(_theme_picker.item_count):
        if str(_theme_picker.get_item_metadata(i)) == active_path:
            target_index = i
            break
    _theme_picker.selected = target_index

## Applies the chosen theme preset (or the built-in default) to the current sheet.
func _on_theme_preset_selected(index: int) -> void:
    if _theme_picker == null:
        return
    var path: String = str(_theme_picker.get_item_metadata(index))
    if path.is_empty():
        _on_set_default_theme_requested()
    else:
        load_theme_style_from_path(path)
    _refresh_theme_picker_selection()

func _load_sheet_from_path(path: String) -> void:
    var resolved_path: String = path.strip_edges()
    if resolved_path.is_empty():
        _set_status("Open failed: no file selected.", true)
        return
    # GDScript-backed sheets: any .gd opens losslessly (lifted rows + verbatim blocks); the
    # file stays the single source of truth and Save compiles back to it.
    if resolved_path.get_extension() == "gd":
        var imported: EventSheetResource = GDScriptImporter.new().import_external(resolved_path)
        if imported == null:
            _set_status("Open failed: could not read %s." % resolved_path.get_file(), true)
            return
        setup(imported)
        _current_sheet_path = resolved_path
        _dirty = false
        _refresh_title_strip()
        _clear_undo_history()
        var lifted_count: int = 0
        for entry in imported.events:
            if entry is LocalVariable:
                lifted_count += 1
        _external_mtime = FileAccess.get_modified_time(resolved_path)
        _set_status("Opened GDScript as sheet: %d variable(s) lifted, file remains the source of truth." % lifted_count)
        return
    var loaded: Resource = ResourceLoader.load(resolved_path)
    if loaded is EventSheetResource:
        setup(loaded as EventSheetResource)
        _current_sheet_path = resolved_path
        _dirty = false
        _refresh_title_strip()
        _clear_undo_history()
        return
    _set_status("Open failed: %s is not an EventSheetResource." % resolved_path.get_file(), true)

func _on_save_requested() -> void:
    if _current_sheet == null:
        _set_status("Nothing to save.", true)
        return
    # GDScript-backed sheets save by compiling back to their .gd source (order-preserving;
    # an untouched sheet reproduces the file byte-identically).
    if not _current_sheet.external_source_path.is_empty():
        var compile_result: Dictionary = SheetCompiler.compile(_current_sheet, _current_sheet.external_source_path)
        if bool(compile_result.get("success", false)):
            _dirty = false
            _external_mtime = FileAccess.get_modified_time(_current_sheet.external_source_path)
            _refresh_title_strip()
            _set_status("Saved GDScript: %s" % _current_sheet.external_source_path.get_file())
        else:
            _set_status("Save failed: %s" % ", ".join(PackedStringArray(compile_result.get("errors", []))), true)
        return
    if _current_sheet_path.is_empty() and _current_sheet.resource_path.is_empty():
        _on_save_as_requested()
        return
    var save_path: String = _current_sheet_path if not _current_sheet_path.is_empty() else _current_sheet.resource_path
    # Backup ring: the file's pre-save bytes go to user://eventsheet_backups first
    # (eventsheets/editor/backup_count, 0 disables) — a bad save costs one save, not
    # the sheet. Restore lives in Tools → Sheet Backups….
    EventSheetBackups.backup_sheet(save_path)
    var err: Error = ResourceSaver.save(_current_sheet, save_path)
    if err == OK:
        _current_sheet.take_over_path(save_path)
        _current_sheet_path = save_path
        _dirty = false
        # Compile-on-save (default ON; eventsheets/editor/compile_on_save to disable):
        # play-testing can never hit a stale generated script. Export integrity still
        # covers exports; this covers F5.
        var compile_on_save: bool = bool(ProjectSettings.get_setting("eventsheets/editor/compile_on_save", true))
        if compile_on_save:
            var auto_result: Dictionary = SheetCompiler.compile(_current_sheet, "")
            if not bool(auto_result.get("success", false)):
                _set_status("Saved, but the sheet doesn't compile: %s" % str(auto_result.get("errors")), true)
                _refresh_title_strip()
                return
        _refresh_title_strip()
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
    # Save As .tres converts a GDScript-backed sheet into a normal sheet: the .gd stops
    # being the source of truth (it is left untouched on disk).
    if not _current_sheet.external_source_path.is_empty():
        _current_sheet.external_source_path = ""
    var err: Error = ResourceSaver.save(_current_sheet, resolved_path)
    if err == OK:
        _current_sheet.take_over_path(resolved_path)
        _current_sheet_path = resolved_path
        _dirty = false
        _refresh_title_strip()
        _set_status("Saved as: %s" % resolved_path.get_file())
    else:
        _set_status("Save failed (error %d)." % err, true)

func _on_add_event_requested() -> void:
    if not _ensure_sheet_for_editing():
        return
    _ace_picker.open("new_event", false, _active_view().get_selected_context().get("source_resource", null))

func _on_add_signal_event_requested() -> void:
    if not _ensure_sheet_for_editing():
        return
    _ace_picker.open("new_event", true, _active_view().get_selected_context().get("source_resource", null))

func _on_add_condition_requested() -> void:
    if not _ensure_sheet_for_editing():
        return
    var selected_resource: Resource = _active_view().get_selected_context().get("source_resource", null)
    if selected_resource is EventRow:
        _ace_picker.open("append_condition", false, selected_resource)
        return
    _ace_picker.open("new_condition_event", false, selected_resource)

func _on_add_action_requested() -> void:
    if not _ensure_selected_event():
        return
    _ace_picker.open("append_action", false, _active_view().get_selected_context().get("source_resource", null))

func _on_add_comment_requested() -> void:
    if not _ensure_sheet_for_editing():
        return
    var comment: CommentRow = CommentRow.new()
    comment.text = "Comment"
    var changed: bool = _perform_undoable_sheet_edit("Add Comment", func() -> bool:
        _insert_row_below_selection(comment)
        return true
    )
    if changed:
        _mark_dirty("Added comment.")

func _on_add_group_requested() -> void:
    if not _ensure_sheet_for_editing():
        return
    var group: EventGroup = EventGroup.new()
    group.name = "Group"
    group.group_name = group.name
    var changed: bool = _perform_undoable_sheet_edit("Add Group", func() -> bool:
        _insert_row_below_selection(group)
        return true
    )
    if changed:
        _mark_dirty("Added group.")

func _on_duplicate_requested() -> void:
    if not _ensure_sheet_for_editing():
        return
    var selected_resource: Resource = _active_view().get_selected_context().get("source_resource", null)
    if not (selected_resource is EventRow):
        _set_status("Select an event row to duplicate.", true)
        return
    var clone: EventRow = (selected_resource as EventRow).duplicate(true)
    _assign_fresh_event_uids(clone)
    var changed: bool = _perform_undoable_sheet_edit("Duplicate Event", func() -> bool:
        _insert_row_below_selection(clone, selected_resource)
        return true
    )
    if changed:
        _mark_dirty("Duplicated event.")

## Recursively assigns fresh event UIDs to a cloned event row and its sub-events so the
## duplicate does not share selection/fold identity with the source.
func _assign_fresh_event_uids(row: EventRow) -> void:
    row.event_uid = EventRow._generate_short_uid()
    # Stateful conditions (Every X Seconds…): the COPY must own its own accumulator —
    # re-bake the member uid across all four baked fields, or both timers silently
    # share one member (C3 copies are independent timers).
    for condition: Variant in row.conditions:
        if condition is ACECondition and not (condition as ACECondition).member_declaration.is_empty():
            var stateful: ACECondition = condition as ACECondition
            var uid_regex: RegEx = RegEx.new()
            uid_regex.compile("__[a-z_]+_([0-9a-f]{8})\\b")
            var uid_match: RegExMatch = uid_regex.search(stateful.member_declaration)
            if uid_match == null:
                continue
            var old_uid: String = uid_match.get_string(1)
            var new_uid: String = "%08x" % (randi() & 0x7fffffff)
            stateful.member_declaration = stateful.member_declaration.replace(old_uid, new_uid)
            stateful.codegen_template = stateful.codegen_template.replace(old_uid, new_uid)
            stateful.codegen_prelude = stateful.codegen_prelude.replace(old_uid, new_uid)
            stateful.codegen_on_true = stateful.codegen_on_true.replace(old_uid, new_uid)
    # Multi-line action templates bake `__spawn_<uid>`/`__sfx_<uid>` locals — pasting the
    # same event twice into one trigger would declare the same local twice in one
    # function body. Re-bake every baked uid the template carries.
    for action: Variant in row.actions:
        if action is ACEAction and (action as ACEAction).codegen_template.contains("__"):
            var baked: ACEAction = action as ACEAction
            var action_uid_regex: RegEx = RegEx.new()
            action_uid_regex.compile("__[a-z_]+_([0-9a-f]{8})\\b")
            var seen_uids: Dictionary = {}
            for action_match: RegExMatch in action_uid_regex.search_all(baked.codegen_template):
                seen_uids[action_match.get_string(1)] = true
            for stale_uid: Variant in seen_uids.keys():
                baked.codegen_template = baked.codegen_template.replace(str(stale_uid), "%08x" % (randi() & 0x7fffffff))
    for sub_event in row.sub_events:
        if sub_event is EventRow:
            _assign_fresh_event_uids(sub_event as EventRow)

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
    var context: Dictionary = _active_view().get_selected_context()
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
    # Row copies are written in two forms: the internal clipboard (rich, same-session
    # pastes) and a portable text snippet on the SYSTEM clipboard, so rows can be shared
    # across projects, editor instances, and forum/Discord posts (see EventSheetSnippet).
    var top_level: Array = _top_level_selected_resources()
    if top_level.is_empty():
        top_level = [selected_resource]
    DisplayServer.clipboard_set(EventSheetSnippet.serialize_rows(top_level, _current_sheet))
    _clipboard = {"type": "row", "payload": selected_resource.duplicate(true)}
    _set_status("Copied %d row(s) — shareable snippet placed on the clipboard." % top_level.size())

## Top-most selected row resources: children of a selected ancestor are skipped because
## they already travel inside their parent's serialized form.
func _top_level_selected_resources() -> Array:
    var resources: Array = []
    for row_data in _get_selected_rows_from_context():
        if row_data == null or row_data.source_resource == null:
            continue
        if not resources.has(row_data.source_resource):
            resources.append(row_data.source_resource)
    var top_level: Array = []
    for resource in resources:
        var has_selected_ancestor: bool = false
        for other in resources:
            if other != resource and _resource_contains_descendant(other, resource):
                has_selected_ancestor = true
                break
        if not has_selected_ancestor:
            top_level.append(resource)
    return top_level

func _on_paste_requested() -> void:
    # Paste priority: portable snippets (in-app copies refresh them too) → raw GDScript
    # copied from anywhere (auto-converted to events/rows) → the internal clipboard for
    # same-session rich pastes.
    if _paste_snippet_text(DisplayServer.clipboard_get()):
        return
    if _paste_gdscript_text(DisplayServer.clipboard_get()):
        return
    if _clipboard.is_empty():
        _set_status("Clipboard is empty.", true)
        return
    if not _ensure_sheet_for_editing():
        return
    var clip_type: String = str(_clipboard.get("type", ""))
    var payload: Variant = _clipboard.get("payload", null)
    var context: Dictionary = _active_view().get_selected_context()
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

## Pastes a shareable snippet from text (see EventSheetSnippet). Returns false when the
## text is not a snippet so the caller falls back to the internal clipboard. Pasted events
## get fresh UIDs; sheet variables the snippet references are created when missing (never
## overwritten), so the pasted rows compile immediately.
func _paste_snippet_text(text: String) -> bool:
    if not EventSheetSnippet.is_snippet_text(text):
        return false
    if not _ensure_sheet_for_editing():
        return true
    var snippet: Dictionary = EventSheetSnippet.deserialize(text)
    var rows: Array = snippet.get("rows", [])
    if rows.is_empty():
        _set_status("Clipboard snippet is empty or invalid.", true)
        return true
    # Dictionary so the undoable lambda can mutate it (GDScript lambdas capture by value).
    var counters: Dictionary = {"variables_created": 0}
    var required_variables: Dictionary = snippet.get("required_variables", {})
    var changed: bool = _perform_undoable_sheet_edit("Paste Snippet", func() -> bool:
        for variable_name in required_variables.keys():
            if not _current_sheet.variables.has(variable_name):
                _current_sheet.variables[variable_name] = required_variables[variable_name]
                counters["variables_created"] = int(counters["variables_created"]) + 1
        var anchor: Resource = _active_view().get_selected_context().get("source_resource", null)
        for row in rows:
            if row is EventRow:
                _assign_fresh_event_uids(row as EventRow)
            _insert_row_below_selection(row, anchor)
            anchor = row  # keeps pasted rows in their original order, each after the last
        return true
    )
    if changed:
        var provider_names: PackedStringArray = PackedStringArray()
        for provider in snippet.get("providers", []):
            provider_names.append(str(provider))
        var provider_note: String = "" if provider_names.is_empty() else " Uses providers: %s." % ", ".join(provider_names)
        _mark_dirty("Pasted snippet: %d row(s), %d variable(s) created.%s" % [rows.size(), int(counters["variables_created"]), provider_note])
    return true

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

## Appends an in-flow GDScript block to the right-clicked event's actions (C3-style inline
## scripting: statements emitted inside the event body).
func _add_gdscript_action_to_context_row() -> void:
    if _context_row == null or not (_context_row.source_resource is EventRow):
        _set_status("Add a GDScript action from an event row.", true)
        return
    var target_event: EventRow = _context_row.source_resource as EventRow
    var changed: bool = _perform_undoable_sheet_edit("Add GDScript Action", func() -> bool:
        var inline_raw: RawCodeRow = RawCodeRow.new()
        inline_raw.code = "pass"
        target_event.actions.append(inline_raw)
        return true
    )
    if changed:
        _mark_dirty("Added GDScript action.")

## Opens the variable dialog to add a tree-placed variable directly below the right-clicked
## row (so variables can sit between/above/under events like comments do).
func _add_tree_variable_below_context_row() -> void:
    if not _ensure_sheet_for_editing():
        return
    if _context_row == null or _context_row.source_resource == null:
        _set_status("Select a row to add a variable below.", true)
        return
    _variable_dlg.open_for_edit(
        "tree", {"insert_below": _context_row.source_resource}, "", "int", "0", false, "Add Variable", false, false
    )

func _ensure_sheet_for_editing() -> bool:
    if _current_sheet != null:
        return true
    _set_status("Create or open an EventSheet first.", true)
    return false

func _ensure_selected_event() -> bool:
    if not _ensure_sheet_for_editing():
        return false
    var selected: Resource = _active_view().get_selected_context().get("source_resource", null)
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
    context["from_picker"] = true
    _ace_params.open_with_values(definition, context, initial_values)

## Re-opens the ACE picker when the params dialog requests Back.
func _on_ace_params_back_requested(_definition: ACEDefinition, context: Dictionary) -> void:
    var mode: String = str(context.get("mode", "new_event"))
    var signals_only: bool = bool(context.get("signals_only", false))
    var selected_resource: Resource = context.get("selected_resource", null)
    _ace_picker.open(mode, signals_only, selected_resource, context)

## Returns the sheet's variable names for variable-reference parameter dropdowns.
func _collect_sheet_variable_names() -> PackedStringArray:
    var names: PackedStringArray = PackedStringArray()
    if _current_sheet == null:
        return names
    for key: Variant in _current_sheet.variables.keys():
        names.append(str(key))
    names.sort()
    return names

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
    # Action-cell comments edit in the comment dialog, not the ACE editor.
    if bool(metadata.get("action_comment", false)):
        var comment_index: int = int(metadata.get("ace_index", -1))
        if comment_index >= 0 and comment_index < event_row.actions.size() and event_row.actions[comment_index] is CommentRow:
            _open_comment_dialog(event_row.actions[comment_index])
            return
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

func _on_viewport_variable_edit_requested(row_data: EventRowData, metadata: Dictionary) -> void:
    _context_variable = _context_variable_entry_from_metadata(row_data, metadata)
    if _context_variable.is_empty():
        _set_status("Select a valid variable before editing.", true)
        return
    _edit_context_variable()

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
                    _bake_trigger_signature(condition_event, definition)
                else:
                    condition_event.conditions.append(_create_condition_from_definition(definition, params))
                var insert_into: Variant = context.get("insert_into", null)
                if insert_into is EventGroup:
                    _group_children_array(insert_into as EventGroup).append(condition_event)
                elif insert_into is EventSheetResource:
                    (insert_into as EventSheetResource).events.append(condition_event)
                else:
                    _insert_row_below_selection(condition_event)
                message["text"] = "Added event."
                return true
            "new_sub_condition_event":
                if selected_resource is EventRow:
                    var child_condition_event: EventRow = EventRow.new()
                    if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
                        child_condition_event.trigger = _create_condition_from_definition(definition, params)
                        _bake_trigger_signature(child_condition_event, definition)
                    else:
                        child_condition_event.conditions.append(_create_condition_from_definition(definition, params))
                    (selected_resource as EventRow).sub_events.append(child_condition_event)
                    message["text"] = "Added sub-condition."
                    return true
            "append_condition":
                if selected_resource is EventRow:
                    var target_event: EventRow = selected_resource as EventRow
                    var condition_entry: ACECondition = _create_condition_from_definition(definition, params)
                    # Only use the trigger slot when the event has no trigger yet; otherwise
                    # append as a normal condition so an existing trigger (e.g. "Every tick")
                    # is never overwritten by adding a condition.
                    if definition.ace_type == ACEDefinition.ACEType.TRIGGER and target_event.trigger == null and target_event.trigger_id.is_empty():
                        target_event.trigger = condition_entry
                        _bake_trigger_signature(target_event, definition)
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
                    _bake_trigger_signature(selected_resource as EventRow, definition)
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
                    _bake_trigger_signature(event_row, definition)
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

## Bakes a trigger definition's identity + argument signature onto the event row, so the
## compiler can group it, generate a connectable handler (`func _on_<signal>(args)`), and
## emit the `_ready` connection — all without registry access at compile time. Fixes the
## gap where picker-created trigger events never set trigger_id and silently skipped
## compilation. Mirrors codegen_template baking on conditions/actions.
func _bake_trigger_signature(event_row: EventRow, definition: ACEDefinition) -> void:
    if event_row == null or definition == null or definition.ace_type != ACEDefinition.ACEType.TRIGGER:
        return
    event_row.trigger_provider_id = definition.provider_id
    event_row.trigger_id = definition.id
    # Bus triggers: autoload providers connect by singleton name (project-wide signals).
    if _autoload_provider_names.has(definition.provider_id):
        event_row.trigger_source_path = "autoload:%s" % str(_autoload_provider_names[definition.provider_id])
    var parts: PackedStringArray = PackedStringArray()
    for parameter in definition.parameters:
        if not (parameter is Dictionary):
            continue
        var param_id: String = str((parameter as Dictionary).get("id", ""))
        if param_id.is_empty():
            continue
        var param_type: int = int((parameter as Dictionary).get("type", TYPE_NIL))
        parts.append(param_id if param_type == TYPE_NIL else "%s: %s" % [param_id, type_string(param_type)])
    event_row.trigger_args = ", ".join(parts)

func _create_condition_from_definition(definition: ACEDefinition, params: Dictionary) -> ACECondition:
    var condition: ACECondition = ACECondition.new()
    condition.provider_id = definition.provider_id
    condition.ace_id = definition.id
    condition.params = _resolve_definition_params(definition, params)
    # Bake the custom/addon codegen template so the ACE compiles standalone.
    condition.codegen_template = _baked_template_for(definition)
    # Stateful conditions (Every X Seconds…): bake a fresh uid into the member/prelude/
    # on-true/template so every applied instance owns its own state.
    var member_template: String = str(definition.metadata.get("member_template", ""))
    if not member_template.is_empty():
        var stateful_uid: String = "%08x" % (randi() & 0x7fffffff)
        condition.member_declaration = member_template.replace("{uid}", stateful_uid)
        condition.codegen_prelude = str(definition.metadata.get("codegen_prelude", "")).replace("{uid}", stateful_uid)
        condition.codegen_on_true = str(definition.metadata.get("codegen_on_true", "")).replace("{uid}", stateful_uid)
        condition.codegen_template = condition.codegen_template.replace("{uid}", stateful_uid)
    return condition

func _create_action_from_definition(definition: ACEDefinition, params: Dictionary) -> ACEAction:
    var action: ACEAction = ACEAction.new()
    action.provider_id = definition.provider_id
    action.ace_id = definition.id
    action.params = _resolve_definition_params(definition, params)
    # Bake the custom/addon codegen template so the ACE compiles standalone.
    action.codegen_template = _baked_template_for(definition)
    # Multi-statement action templates declare locals — bake a fresh uid per instance.
    if action.codegen_template.contains("{uid}"):
        action.codegen_template = action.codegen_template.replace("{uid}", "%08x" % (randi() & 0x7fffffff))
    return action

## The codegen template baked onto applied ACEs. Explicit @ace_codegen_template wins; addon
## METHODS without one become **instance-backed**: the call targets a per-provider member
## (`__eventsheet_provider_<Class>.method({args})`) that the compiler declares as a plain
## owned instance of the addon class — so template-less addon ACEs compile and run in
## exported games with zero EventForge dependency (the addon script ships like any class).
func _baked_template_for(definition: ACEDefinition) -> String:
    var explicit: String = str(definition.metadata.get("codegen_template", ""))
    if not explicit.strip_edges().is_empty():
        return explicit
    if str(definition.metadata.get("semantic_source", "")) != "reflection":
        return ""
    if str(definition.metadata.get("source_kind", "")) != "method":
        return ""
    var method_name: String = str(definition.metadata.get("source_name", ""))
    if method_name.is_empty() or definition.provider_id.is_empty():
        return ""
    var argument_tokens: PackedStringArray = PackedStringArray()
    for parameter in definition.parameters:
        if parameter is Dictionary and not str((parameter as Dictionary).get("id", "")).is_empty():
            argument_tokens.append("{%s}" % str((parameter as Dictionary).get("id", "")))
    return "__eventsheet_provider_%s.%s(%s)" % [definition.provider_id, method_name, ", ".join(argument_tokens)]

func _resolve_definition_params(definition: ACEDefinition, row_params: Dictionary) -> Dictionary:
    return _param_resolver.resolve_all(definition, row_params if row_params != null else {})

func _insert_row_below_selection(row_resource: Resource, explicit_selected_resource: Resource = null) -> void:
    if _current_sheet == null or row_resource == null:
        return
    var selected_resource: Resource = explicit_selected_resource if explicit_selected_resource != null else _active_view().get_selected_context().get("source_resource", null)
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

func _on_row_drop_requested(source_row: EventRowData, target_row: EventRowData, drop_mode: String = "before", copy_mode: bool = false) -> void:
    if source_row == null:
        return
    _move_rows([source_row], target_row, drop_mode, copy_mode)

func _on_rows_drop_requested(
    source_rows: Array,
    target_row: EventRowData,
    drop_mode: String = "before",
    copy_mode: bool = false
) -> void:
    _move_rows(source_rows, target_row, drop_mode, copy_mode)

func _move_rows(source_rows: Array, target_row: EventRowData, drop_mode: String, copy_mode: bool = false) -> void:
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
        if not copy_mode and _resource_contains_descendant(source_resource, target_resource):
            _set_status("Cannot move a row into one of its descendants.", true)
            return
        source_resources.append(source_resource)
    if source_resources.is_empty():
        return
    var moved: bool = _perform_undoable_sheet_edit("Drag Row", func() -> bool:
        var inserted_resources: Array[Resource] = []
        if copy_mode:
            for source_resource in source_resources:
                inserted_resources.append(source_resource.duplicate(true))
        else:
            inserted_resources = source_resources
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
        for offset in range(inserted_resources.size()):
            target_container.insert(insertion_index + offset, inserted_resources[offset])
        return true
    )
    if moved:
        _mark_dirty("Copied row via drag and drop." if copy_mode else "Moved row via drag and drop.")

func _on_viewport_ace_drop_requested(
    source_entries: Array,
    target_row: EventRowData,
    target_lane: String,
    target_ace_index: int,
    insert_mode: String,
    copy_mode: bool = false
) -> void:
    if target_row == null or not ["condition", "action"].has(target_lane):
        return
    var target_event: EventRow = target_row.source_resource as EventRow
    if target_event == null:
        return
    var normalized_entries: Array = _normalize_ace_drag_entries(source_entries, target_lane)
    if normalized_entries.is_empty():
        return
    var trigger_entries: Array = []
    var excluded_trigger_resources: Array = []
    for entry in normalized_entries:
        if _drag_entry_is_trigger_like(entry):
            trigger_entries.append(entry)
            if not copy_mode:
                var trigger_resource: Resource = entry.get("resource", null) as Resource
                if trigger_resource != null:
                    excluded_trigger_resources.append(trigger_resource)
    if target_lane == "condition":
        if trigger_entries.size() > 1:
            _set_status("Events can only have one trigger.", true)
            return
        if not trigger_entries.is_empty() and _event_has_trigger_like(target_event, excluded_trigger_resources):
            _set_status("This event already has a trigger.", true)
            return
    var target_anchor: Resource = _resolve_event_ace_resource(target_event, target_lane, target_ace_index)
    if not copy_mode and target_anchor != null:
        for entry in normalized_entries:
            if entry.get("resource", null) == target_anchor:
                target_anchor = null
                break
    var moved: bool = _perform_undoable_sheet_edit("Drag ACE", func() -> bool:
        var moving_resources: Array = []
        var moved_trigger: ACECondition = null
        for entry in normalized_entries:
            var source_resource: Resource = entry.get("resource", null) as Resource
            if source_resource == null:
                continue
            var inserted_resource: Resource = source_resource.duplicate(true) if copy_mode else source_resource
            if _drag_entry_is_trigger_like(entry):
                moved_trigger = inserted_resource as ACECondition
            else:
                moving_resources.append(inserted_resource)
        if not copy_mode:
            var removal_groups: Dictionary = {}
            for entry in normalized_entries:
                var source_event: EventRow = entry.get("event_row")
                var removal_entries: Array = removal_groups.get(source_event, []).duplicate()
                removal_entries.append(entry)
                removal_groups[source_event] = removal_entries
            for source_event in removal_groups.keys():
                var entries_to_remove: Array = removal_groups.get(source_event, []).duplicate()
                entries_to_remove.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
                    return int(a.get("ace_index", -1)) > int(b.get("ace_index", -1))
                )
                for removal_entry in entries_to_remove:
                    _remove_drag_entry_from_source(removal_entry)
        if moved_trigger != null:
            target_event.trigger = moved_trigger
        var target_array: Array = _event_ace_array(target_event, target_lane)
        var insertion_index: int = target_array.size()
        if target_anchor != null:
            var anchor_index: int = target_array.find(target_anchor)
            if anchor_index >= 0:
                insertion_index = anchor_index + (1 if insert_mode == "after" else 0)
        for offset in range(moving_resources.size()):
            target_array.insert(insertion_index + offset, moving_resources[offset])
        return moved_trigger != null or not moving_resources.is_empty()
    )
    if moved:
        _mark_dirty("Copied ACE via drag and drop." if copy_mode else "Moved ACE via drag and drop.")

func _normalize_ace_drag_entries(source_entries: Array, lane: String) -> Array:
    var normalized: Array = []
    for entry in source_entries:
        if not (entry is Dictionary):
            continue
        var entry_dict: Dictionary = entry
        var source_event: EventRow = entry_dict.get("source_resource", null) as EventRow
        var kind: String = str(entry_dict.get("kind", ""))
        var ace_index: int = int(entry_dict.get("ace_index", -1))
        var lane_matches: bool = (
            kind == "action" if lane == "action" else kind in ["condition", "trigger"]
        )
        if source_event == null or not lane_matches or ace_index < 0:
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

func _remove_drag_entry_from_source(entry: Dictionary) -> void:
    var source_event: EventRow = entry.get("event_row", null) as EventRow
    if source_event == null:
        return
    var kind: String = str(entry.get("kind", ""))
    var ace_index: int = int(entry.get("ace_index", -1))
    match kind:
        "trigger":
            if source_event.trigger == entry.get("resource", null):
                source_event.trigger = null
        "condition":
            if ace_index >= 0 and ace_index < source_event.conditions.size():
                source_event.conditions.remove_at(ace_index)
        "action":
            if ace_index >= 0 and ace_index < source_event.actions.size():
                source_event.actions.remove_at(ace_index)

func _drag_entry_is_trigger_like(entry: Dictionary) -> bool:
    if str(entry.get("kind", "")) == "trigger":
        return true
    var resource: Resource = entry.get("resource", null) as Resource
    return resource is ACECondition and _is_trigger_condition(resource as ACECondition)

func _event_has_trigger_like(event_row: EventRow, excluded_resources: Array = []) -> bool:
    if event_row == null:
        return false
    if event_row.trigger != null and not excluded_resources.has(event_row.trigger):
        return true
    if not event_row.trigger_id.is_empty():
        return true
    for condition in event_row.conditions:
        if not (condition is ACECondition):
            continue
        if excluded_resources.has(condition):
            continue
        if _is_trigger_condition(condition as ACECondition):
            return true
    return false

func _is_trigger_condition(condition: ACECondition) -> bool:
    if condition == null:
        return false
    var definition: ACEDefinition = _find_definition(condition.provider_id, condition.ace_id)
    if definition != null:
        return definition.ace_type == ACEDefinition.ACEType.TRIGGER
    var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
    return descriptor != null and descriptor.ace_type == ACEDescriptor.ACEType.TRIGGER

func _event_ace_array(event_row: EventRow, lane: String) -> Array:
    if lane == "condition":
        return event_row.conditions
    return event_row.actions

func _resolve_event_ace_resource(event_row: EventRow, lane: String, ace_index: int) -> Resource:
    if event_row == null or ace_index < 0:
        return null
    if lane == "trigger":
        return event_row.trigger
    var ace_array: Array = _event_ace_array(event_row, lane)
    if ace_index < ace_array.size() and ace_array[ace_index] is Resource:
        return ace_array[ace_index]
    return null

func _on_ace_preview_requested(source_label: String, definitions: Array[ACEDefinition]) -> void:
    if _preview_window == null or _preview_list == null:
        return
    _preview_window.title = "Dropped ACE Preview — %s (%d)" % [source_label, definitions.size()]
    _preview_title.text = "Dropped ACE Preview — %s (%d)" % [source_label, definitions.size()]
    _preview_list.clear()
    for definition in definitions:
        _preview_list.add_item("[%s] %s" % [_ace_type_label(definition.ace_type), definition.format_display()])
    if definitions.is_empty():
        _preview_list.add_item("No ACE definitions were generated from this drop payload.")
    _preview_window.popup_centered(Vector2i(560, 320))

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

func _on_viewport_drag_status_requested(message: String, is_error: bool) -> void:
    _set_status(message, is_error)

var _raw_code_dialog: ConfirmationDialog = null
var _raw_code_edit: CodeEdit = null
var _raw_code_target: RawCodeRow = null
var _raw_code_in_flow: bool = false
var _raw_code_hint: Label = null
var _raw_code_lint_label: Label = null

# ── GDScript provenance panel ────────────────────────────────────────────────
# Read-only side panel showing the generated GDScript; selecting a sheet row highlights the
# exact lines it compiles to (sheet → code provenance, via the compiler's source_map).
var _code_edit: CodeEdit = null
var _code_source_map: Array = []
var _code_panel_highlight: Vector2i = Vector2i(-1, -1)
const CODE_PANEL_HIGHLIGHT_COLOR := Color(0.35, 0.55, 0.95, 0.18)

func _toggle_code_panel() -> void:
    _ensure_code_panel()
    _side_panel.visible = not _side_panel.visible
    _split.dragger_visibility = (
        SplitContainer.DRAGGER_VISIBLE if _side_panel.visible else SplitContainer.DRAGGER_HIDDEN_COLLAPSED
    )
    if _side_panel.visible:
        _refresh_code_panel()

func is_code_panel_visible() -> bool:
    return _side_panel != null and _side_panel.visible

## Builds the panel lazily on first toggle: wraps the sheet scroll in an HSplitContainer
## (so the default tree stays untouched until the user asks for the panel) and adds the
## code view on the right.
func _ensure_code_panel() -> void:
    if _split != null:
        return
    var scroll_parent: Node = _scroll.get_parent()
    var scroll_index: int = _scroll.get_index()
    _split = HSplitContainer.new()
    _split.name = "EventSheetCodeSplit"
    _split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll_parent.remove_child(_scroll)
    scroll_parent.add_child(_split)
    scroll_parent.move_child(_split, scroll_index)
    _split.add_child(_scroll)
    _side_panel = VBoxContainer.new()
    _side_panel.name = "GeneratedGDScriptPanel"
    _side_panel.custom_minimum_size = Vector2(360.0, 0.0)
    _side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _side_panel.visible = false
    var header: HBoxContainer = HBoxContainer.new()
    var title: Label = Label.new()
    title.text = "Generated GDScript"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    var copy_button: Button = Button.new()
    copy_button.text = "Copy"
    copy_button.tooltip_text = "Copy the generated script to the clipboard"
    copy_button.pressed.connect(func() -> void:
        if _code_edit != null:
            DisplayServer.clipboard_set(_code_edit.text)
    )
    header.add_child(copy_button)
    var close_button: Button = Button.new()
    close_button.text = "✕"
    close_button.tooltip_text = "Close the GDScript panel"
    close_button.pressed.connect(_toggle_code_panel)
    header.add_child(close_button)
    _side_panel.add_child(header)
    _code_edit = CodeEdit.new()
    _code_edit.editable = false
    _code_edit.gutters_draw_line_numbers = true
    _code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
    # GDScriptSyntaxHighlighter is editor-only; headless test runs skip it.
    if Engine.is_editor_hint() and ClassDB.class_exists("GDScriptSyntaxHighlighter"):
        _code_edit.syntax_highlighter = ClassDB.instantiate("GDScriptSyntaxHighlighter")
    _code_edit.gui_input.connect(_on_code_panel_gui_input)
    _side_panel.add_child(_code_edit)
    _split.add_child(_side_panel)
    _split.split_offset = int(size.x * 0.6) if size.x > 0.0 else 600

## Recompiles the current sheet into the panel (text + source map) and re-highlights.
func _refresh_code_panel() -> void:
    if _code_edit == null or _side_panel == null or not _side_panel.visible:
        return
    if _current_sheet == null:
        _code_edit.text = ""
        _code_source_map = []
        _code_panel_highlight = Vector2i(-1, -1)
        return
    var compile_result: Dictionary = SheetCompiler.compile(_current_sheet, "user://eventforge_code_panel_preview.gd")
    _code_edit.text = str(compile_result.get("output", ""))
    _code_source_map = compile_result.get("source_map", [])
    _code_panel_highlight = Vector2i(-1, -1)
    _update_code_panel_highlight()

## Highlights the generated lines for the currently selected sheet row and scrolls to them.
func _update_code_panel_highlight() -> void:
    if _code_edit == null or _side_panel == null or not _side_panel.visible:
        return
    if _code_panel_highlight.x >= 0:
        for line in range(_code_panel_highlight.x, _code_panel_highlight.y + 1):
            if line < _code_edit.get_line_count():
                _code_edit.set_line_background_color(line, Color(0, 0, 0, 0))
    _code_panel_highlight = Vector2i(-1, -1)
    var selected: Resource = _active_view().get_selected_context().get("source_resource", null) if _viewport != null else null
    if selected == null:
        return
    var uid: String = str(selected.get_instance_id())
    for entry: Variant in _code_source_map:
        if not (entry is Dictionary) or str((entry as Dictionary).get("uid", "")) != uid:
            continue
        var start_line: int = int((entry as Dictionary).get("start", 0)) - 1
        var end_line: int = mini(int((entry as Dictionary).get("end", 0)) - 1, _code_edit.get_line_count() - 1)
        if start_line < 0 or end_line < start_line:
            continue
        for line in range(start_line, end_line + 1):
            _code_edit.set_line_background_color(line, CODE_PANEL_HIGHLIGHT_COLOR)
        _code_edit.set_caret_line(start_line)
        _code_panel_highlight = Vector2i(start_line, end_line)
        return

## Reverse provenance: clicking a line of generated code selects the sheet row that
## produced it. Reacts only to mouse releases (never caret moves), so the forward
## direction — selection setting the caret in _update_code_panel_highlight — cannot loop.
func _on_code_panel_gui_input(event: InputEvent) -> void:
    if not (event is InputEventMouseButton):
        return
    var mouse: InputEventMouseButton = event as InputEventMouseButton
    if mouse.button_index != MOUSE_BUTTON_LEFT or mouse.pressed:
        return
    # The click already moved the caret; source maps are 1-based.
    _select_sheet_row_for_code_line(_code_edit.get_caret_line() + 1)

## Picks the most specific source-map entry containing the line (smallest range wins, so
## in-flow blocks beat their event and events beat their trigger function), then walks
## outward until something selects — inner entries may reference resources without rows of
## their own (e.g. an in-flow block inside an event's actions).
func _select_sheet_row_for_code_line(line: int) -> void:
    if _viewport == null:
        return
    var containing: Array = []
    for entry: Variant in _code_source_map:
        if not (entry is Dictionary):
            continue
        var start: int = int((entry as Dictionary).get("start", 0))
        var end: int = int((entry as Dictionary).get("end", 0))
        if line >= start and line <= end:
            containing.append(entry)
    containing.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return (int(a.get("end", 0)) - int(a.get("start", 0))) < (int(b.get("end", 0)) - int(b.get("start", 0)))
    )
    for entry: Variant in containing:
        var resource: Resource = instance_from_id(int(str((entry as Dictionary).get("uid", "0")))) as Resource
        if resource != null and _viewport.select_resource(resource):
            _update_code_panel_highlight()
            return

## Double-clicking a GDScript block opens a CodeEdit dialog with compile-check linting and
## sheet-symbol completion. in_flow blocks live inside an event's actions (statements);
## class-level blocks are tree rows (helper functions, @onready vars, signals…).
func _on_viewport_raw_code_edit_requested(raw_resource: Resource, in_flow: bool) -> void:
    var raw_row: RawCodeRow = raw_resource as RawCodeRow
    if raw_row == null:
        return
    _ensure_raw_code_dialog()
    _raw_code_target = raw_row
    _raw_code_in_flow = in_flow
    _raw_code_hint.text = (
        "Statements emitted inside this event's body (after its conditions)."
        if in_flow
        else "Plain GDScript, emitted verbatim at class level (helper functions, @onready vars, signals…)."
    )
    _raw_code_edit.text = raw_row.code
    _validate_raw_code()
    _raw_code_dialog.popup_centered(Vector2i(680, 460))
    _raw_code_edit.grab_focus()

func _ensure_raw_code_dialog() -> void:
    if _raw_code_dialog != null:
        return
    _raw_code_dialog = ConfirmationDialog.new()
    _raw_code_dialog.title = "Edit GDScript Block"
    var layout_box: VBoxContainer = VBoxContainer.new()
    layout_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _raw_code_hint = Label.new()
    _raw_code_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout_box.add_child(_raw_code_hint)
    _raw_code_edit = CodeEdit.new()
    _raw_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _raw_code_edit.custom_minimum_size = Vector2(620.0, 330.0)
    _raw_code_edit.gutters_draw_line_numbers = true
    _raw_code_edit.indent_use_spaces = false
    # GDScriptSyntaxHighlighter is editor-only; headless test runs skip it.
    if Engine.is_editor_hint() and ClassDB.class_exists("GDScriptSyntaxHighlighter"):
        _raw_code_edit.syntax_highlighter = ClassDB.instantiate("GDScriptSyntaxHighlighter")
    _raw_code_edit.code_completion_enabled = true
    _raw_code_edit.text_changed.connect(_validate_raw_code)
    _raw_code_edit.code_completion_requested.connect(_populate_raw_code_completion)
    layout_box.add_child(_raw_code_edit)
    _raw_code_lint_label = Label.new()
    _raw_code_lint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout_box.add_child(_raw_code_lint_label)
    _raw_code_dialog.add_child(layout_box)
    _raw_code_dialog.confirmed.connect(_on_raw_code_dialog_confirmed)
    add_child(_raw_code_dialog)

## Compile-checks the dialog's code against the sheet context (host class + sheet symbols).
func _validate_raw_code() -> void:
    if _raw_code_edit == null or _raw_code_lint_label == null:
        return
    var lint_result: Dictionary = EventSheetGDScriptLint.lint(_raw_code_edit.text, _raw_code_in_flow, _current_sheet)
    if bool(lint_result.get("ok", true)):
        _raw_code_lint_label.text = "✓ Compiles"
        _raw_code_lint_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.6))
    else:
        _raw_code_lint_label.text = "✗ %s" % str(lint_result.get("error", "Does not compile."))
        _raw_code_lint_label.add_theme_color_override("font_color", Color(0.95, 0.5, 0.5))

## Supplies sheet variables/functions and host-class members as completion candidates.
func _populate_raw_code_completion() -> void:
    if _raw_code_edit == null:
        return
    # Context-aware: `host.` / typed-variable. / $Behavior. offer that type's members.
    for candidate: Dictionary in EventSheetGDScriptLint.completion_for_context(_text_before_caret(_raw_code_edit), _current_sheet):
        var label: String = str(candidate.get("label", ""))
        _raw_code_edit.add_code_completion_option(int(candidate.get("kind", CodeEdit.KIND_PLAIN_TEXT)), label, label)
    _raw_code_edit.update_code_completion_options(true)
    _raw_code_edit.set_code_hint(EventSheetGDScriptLint.signature_hint(_text_before_caret(_raw_code_edit), _current_sheet))

## The current line's text up to the caret (what context completion/hints parse).
static func _text_before_caret(edit: CodeEdit) -> String:
    return edit.get_line(edit.get_caret_line()).substr(0, edit.get_caret_column())

func _on_raw_code_dialog_confirmed() -> void:
    if _raw_code_target == null:
        return
    var target: RawCodeRow = _raw_code_target
    # Guardrail: broken GDScript never commits — the dialog reopens with the text intact.
    var commit_lint: Dictionary = EventSheetGDScriptLint.lint(_raw_code_edit.text, _raw_code_in_flow, _current_sheet)
    if not bool(commit_lint.get("ok", true)):
        _set_status("GDScript block not saved: fix the error first (or Cancel to discard).", true)
        if is_inside_tree():
            _raw_code_dialog.call_deferred("popup_centered", Vector2i(680, 420))
        return
    _raw_code_target = null
    var new_code: String = _raw_code_edit.text
    var changed: bool = _perform_undoable_sheet_edit("Edit GDScript Block", func() -> bool:
        if target.code == new_code:
            return false
        target.code = new_code
        return true
    )
    if changed:
        _refresh_after_edit()
        _mark_dirty("Updated GDScript block.")

# ── Paste GDScript as events ─────────────────────────────────────────────────

## Returns true when the clipboard text reads like GDScript (conservative: a paste that is
## not code must fall through to the internal clipboard untouched).
static func _looks_like_gdscript(text: String) -> bool:
    var code_line: RegEx = RegEx.new()
    if code_line.compile("(?m)^(func |var |@export|@onready|signal |extends |class_name |if .*:|for .*:|while .*:|match .*:)") != OK:
        return false
    return code_line.search(text) != null

## Pastes raw GDScript copied from anywhere, converted through the same pipeline that
## opens .gd files as sheets: the lossless rule keeps every line (unrecognized code stays
## verbatim GDScript block rows), declarations verify-lift to variable rows, and trigger
## functions ACE-lift into real events when the round-trip verifies. Returns false for
## non-code clipboards so the regular paste paths continue.
func _paste_gdscript_text(text: String) -> bool:
    if text.strip_edges().is_empty() or EventSheetSnippet.is_snippet_text(text):
        return false
    if not _looks_like_gdscript(text):
        return false
    if not _ensure_sheet_for_editing():
        return false
    var imported: EventSheetResource = GDScriptImporter.new().import_external_source(text)
    if imported.events.is_empty():
        return false
    var rows: Array = imported.events.duplicate()
    var lifted_events: int = 0
    var context: Dictionary = _active_view().get_selected_context()
    var anchor: Resource = context.get("source_resource", null)
    var changed: bool = _perform_undoable_sheet_edit("Paste GDScript", func() -> bool:
        var insert_after: Resource = anchor
        for row: Variant in rows:
            if row is EventRow:
                _assign_fresh_event_uids(row)
            _insert_row_below_selection(row, insert_after)
            insert_after = row
        return true
    )
    if not changed:
        return false
    for row: Variant in rows:
        if row is EventRow:
            lifted_events += 1
    _refresh_after_edit()
    if lifted_events > 0:
        _mark_dirty("Pasted GDScript: %d row(s), %d event(s) auto-converted." % [rows.size(), lifted_events])
    else:
        _mark_dirty("Pasted GDScript as %d block row(s) — no trigger functions to convert." % rows.size())
    return true

# ── Visual theme editor ───────────────────────────────────────────────────────
var _theme_editor: EventSheetThemeEditor = null

func _open_theme_editor() -> void:
    if _theme_editor == null:
        _theme_editor = EventSheetThemeEditor.new()
    _theme_editor.open(self, _active_theme_style)

## Called by the theme editor's "Apply To Current Sheet": assigns the working style to the
## active sheet undoably and repaints.
func apply_theme_style(style: EventSheetEditorStyle) -> void:
    if _current_sheet == null or style == null:
        return
    var changed: bool = _perform_undoable_sheet_edit("Apply Theme", func() -> bool:
        _current_sheet.editor_style = style
        return true
    )
    if changed:
        _active_theme_style = style
        _refresh_after_edit()
        _refresh_theme_picker_selection()
        _mark_dirty("Theme applied from the theme editor.")

# ── Inspector per-row param edits ───────────────────────────────────

## The Inspector's "Selected ACE" section delegates writes here: the dock owns the
## undoable sheet edit and the viewport refresh.
func _on_exposed_row_param_changed(target: Resource, param_id: String, value: Variant) -> void:
    if target == null or param_id.is_empty():
        return
    var changed: bool = _perform_undoable_sheet_edit("Edit Param (Inspector)", func() -> bool:
        var params: Dictionary = target.get("params")
        params[param_id] = value
        target.set("params", params)
        return true
    )
    if changed:
        _refresh_after_edit()
        _mark_dirty("Parameter updated from the Inspector.")

# ── Enum dialog (name + members, one per line) ───────────────────────────────────────
var _enum_dialog: ConfirmationDialog = null
var _enum_name_edit: LineEdit = null
var _enum_members_edit: TextEdit = null
var _enum_target: EnumRow = null

## Opens the enum editor for an EnumRow (double-click or "Add Enum Below").
func _open_enum_dialog(enum_resource: Resource) -> void:
    var enum_row: EnumRow = enum_resource as EnumRow
    if enum_row == null:
        return
    _ensure_enum_dialog()
    _enum_target = enum_row
    _enum_name_edit.text = enum_row.enum_name
    _enum_members_edit.text = "
".join(enum_row.members)
    _enum_dialog.popup_centered(Vector2i(420, 300))

func _ensure_enum_dialog() -> void:
    if _enum_dialog != null:
        return
    _enum_dialog = ConfirmationDialog.new()
    _enum_dialog.title = "Edit Enum"
    var form: VBoxContainer = VBoxContainer.new()
    form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _enum_name_edit = _add_sheet_type_field(form, "Enum name", "State")
    var members_label: Label = Label.new()
    members_label.text = "Members (one per line; optional \"NAME = 4\" values)"
    members_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    members_label.custom_minimum_size = Vector2(380.0, 0.0)
    form.add_child(members_label)
    _enum_members_edit = TextEdit.new()
    _enum_members_edit.custom_minimum_size = Vector2(380.0, 150.0)
    _enum_members_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
    form.add_child(_enum_members_edit)
    _enum_dialog.add_child(form)
    _enum_dialog.confirmed.connect(_on_enum_dialog_confirmed)
    add_child(_enum_dialog)

func _on_enum_dialog_confirmed() -> void:
    if _enum_target == null:
        return
    var target: EnumRow = _enum_target
    var new_name: String = EventSheetIdentifierRules.sanitize(_enum_name_edit.text)
    if not EventSheetIdentifierRules.is_valid(new_name):
        _set_status("\"%s\" can't be an enum name (letters/digits/underscores, not a GDScript keyword)." % _enum_name_edit.text, true)
        return
    var new_members: PackedStringArray = PackedStringArray()
    for line: String in _enum_members_edit.text.split("
"):
        if line.strip_edges().is_empty():
            continue
        var member_name: String = EventSheetIdentifierRules.sanitize(line.get_slice("=", 0))
        if not EventSheetIdentifierRules.is_valid(member_name):
            _set_status("\"%s\" can't be an enum member name." % line.strip_edges(), true)
            return
        var member_text: String = member_name
        if line.contains("="):
            member_text += " = " + line.get_slice("=", 1).strip_edges()
        new_members.append(member_text)
    if new_members.is_empty():
        _set_status("Enums need a name and at least one member.", true)
        return
    var changed: bool = _perform_undoable_sheet_edit("Edit Enum", func() -> bool:
        target.enum_name = new_name
        target.members = new_members
        return true
    )
    if changed:
        _refresh_after_edit()
        _mark_dirty("Enum updated (compiles before variables; use it as a variable type).")

# ── Variable rename refactor ──────────────────────────────────────────────────────────

## Whole-word renames a variable across everything that embeds GDScript text — ACE params,
## GDScript blocks (class-level, in-flow, function bodies), and pick-filter expressions —
## so a rename never silently breaks compiled code (C3-style refactor safety).
## Returns the number of replacements. Call inside the same undoable edit as the rename.
func _rename_variable_references(old_name: String, new_name: String) -> int:
    if old_name.is_empty() or old_name == new_name or _current_sheet == null:
        return 0
    var regex: RegEx = RegEx.new()
    if regex.compile("\\b%s\\b" % old_name) != OK:  # names are sanitized identifiers — regex-safe
        return 0
    var counter: Dictionary = {"count": 0}
    _rename_in_rows(_current_sheet.events, regex, new_name, counter)
    for function_resource: Variant in _current_sheet.functions:
        if function_resource is EventFunction:
            var function_rows: Array = (function_resource as EventFunction).events if not (function_resource as EventFunction).events.is_empty() else (function_resource as EventFunction).rows
            _rename_in_rows(function_rows, regex, new_name, counter)
    return int(counter.get("count", 0))

func _rename_in_rows(rows: Array, regex: RegEx, new_name: String, counter: Dictionary) -> void:
    for row: Variant in rows:
        if row is RawCodeRow:
            (row as RawCodeRow).code = _regex_rename(regex, (row as RawCodeRow).code, new_name, counter)
        elif row is EventGroup:
            var group: EventGroup = row as EventGroup
            _rename_in_rows(group.events if not group.events.is_empty() else group.rows, regex, new_name, counter)
        elif row is EventRow:
            var event_row: EventRow = row as EventRow
            if event_row.trigger != null:
                _rename_in_params(event_row.trigger, regex, new_name, counter)
            for condition: Variant in event_row.conditions:
                if condition is ACECondition:
                    _rename_in_params(condition, regex, new_name, counter)
            for action: Variant in event_row.actions:
                if action is ACEAction:
                    _rename_in_params(action, regex, new_name, counter)
                elif action is RawCodeRow:
                    (action as RawCodeRow).code = _regex_rename(regex, (action as RawCodeRow).code, new_name, counter)
            for pick: Variant in event_row.pick_filters:
                if pick is PickFilter:
                    (pick as PickFilter).collection_value = _regex_rename(regex, (pick as PickFilter).collection_value, new_name, counter)
                    (pick as PickFilter).predicate_expression = _regex_rename(regex, (pick as PickFilter).predicate_expression, new_name, counter)
            _rename_in_rows(event_row.sub_events, regex, new_name, counter)

## String params hold GDScript expressions / variable references — rename inside them.
## Baked codegen templates can embed the variable too, but their {placeholder} tokens must
## never be touched (they're param names, not variables).
func _rename_in_params(ace: Resource, regex: RegEx, new_name: String, counter: Dictionary) -> void:
    var params: Dictionary = ace.get("params")
    for key: Variant in params.keys():
        if params[key] is String:
            params[key] = _regex_rename(regex, params[key], new_name, counter)
    var template: String = str(ace.get("codegen_template"))
    if not template.is_empty():
        ace.set("codegen_template", _rename_in_template(template, regex, new_name, counter))

## Renames only OUTSIDE {placeholder} segments of a codegen template.
func _rename_in_template(template: String, regex: RegEx, new_name: String, counter: Dictionary) -> String:
    var output: String = ""
    var cursor: int = 0
    while cursor < template.length():
        var open: int = template.find("{", cursor)
        if open == -1:
            output += _regex_rename(regex, template.substr(cursor), new_name, counter)
            break
        var close: int = template.find("}", open)
        if close == -1:
            output += _regex_rename(regex, template.substr(cursor), new_name, counter)
            break
        output += _regex_rename(regex, template.substr(cursor, open - cursor), new_name, counter)
        output += template.substr(open, close - open + 1)
        cursor = close + 1
    return output

func _regex_rename(regex: RegEx, text: String, new_name: String, counter: Dictionary) -> String:
    if text.is_empty():
        return text
    var hits: int = regex.search_all(text).size()
    if hits == 0:
        return text
    counter["count"] = int(counter.get("count", 0)) + hits
    return regex.sub(text, new_name, true)

# ── Signal + match dialogs ─────────────────────────────────────────────────────────────
var _signal_dialog: ConfirmationDialog = null
var _signal_name_edit: LineEdit = null
var _signal_params_edit: TextEdit = null
var _signal_target: SignalRow = null
var _match_dialog: ConfirmationDialog = null
var _match_expression_edit: LineEdit = null
var _match_branches_edit: TextEdit = null
var _match_hint: Label = null
var _match_target: MatchRow = null

## Opens the signal editor (double-click or "Add Signal Below").
func _open_signal_dialog(signal_resource: Resource) -> void:
    var signal_row: SignalRow = signal_resource as SignalRow
    if signal_row == null:
        return
    _ensure_signal_dialog()
    _signal_target = signal_row
    _signal_name_edit.text = signal_row.signal_name
    _signal_params_edit.text = "\n".join(signal_row.params)
    _signal_dialog.popup_centered(Vector2i(420, 280))

func _ensure_signal_dialog() -> void:
    if _signal_dialog != null:
        return
    _signal_dialog = ConfirmationDialog.new()
    _signal_dialog.title = "Edit Signal"
    var form: VBoxContainer = VBoxContainer.new()
    form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _signal_name_edit = _add_sheet_type_field(form, "Signal name", "hit")
    var params_label: Label = Label.new()
    params_label.text = "Parameters (one per line; optional \"damage: int\" types)"
    params_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    params_label.custom_minimum_size = Vector2(380.0, 0.0)
    form.add_child(params_label)
    _signal_params_edit = TextEdit.new()
    _signal_params_edit.custom_minimum_size = Vector2(380.0, 120.0)
    _signal_params_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
    form.add_child(_signal_params_edit)
    _signal_dialog.add_child(form)
    _signal_dialog.confirmed.connect(_on_signal_dialog_confirmed)
    add_child(_signal_dialog)

func _on_signal_dialog_confirmed() -> void:
    if _signal_target == null:
        return
    var target: SignalRow = _signal_target
    var new_name: String = EventSheetIdentifierRules.sanitize(_signal_name_edit.text)
    if not EventSheetIdentifierRules.is_valid(new_name):
        _set_status("\"%s\" can't be a signal name (letters/digits/underscores, not a GDScript keyword)." % _signal_name_edit.text, true)
        return
    var new_params: PackedStringArray = PackedStringArray()
    for line: String in _signal_params_edit.text.split("\n"):
        if line.strip_edges().is_empty():
            continue
        var param_name: String = EventSheetIdentifierRules.sanitize(line.get_slice(":", 0))
        if not EventSheetIdentifierRules.is_valid(param_name):
            _set_status("\"%s\" can't be a signal parameter name." % line.strip_edges(), true)
            return
        var param_text: String = param_name
        if line.contains(":"):
            param_text += ": " + line.get_slice(":", 1).strip_edges()
        new_params.append(param_text)
    var changed: bool = _perform_undoable_sheet_edit("Edit Signal", func() -> bool:
        target.signal_name = new_name
        target.params = new_params
        return true
    )
    if changed:
        _refresh_after_edit()
        _mark_dirty("Signal updated (it now appears in the On/Emit Signal pickers).")

## Opens the match editor (double-click a match cell or "Add Match To Actions…").
func _open_match_dialog(match_resource: Resource) -> void:
    var match_row: MatchRow = match_resource as MatchRow
    if match_row == null:
        return
    _ensure_match_dialog()
    _match_target = match_row
    _match_expression_edit.text = match_row.match_expression
    _match_branches_edit.text = match_row.branches_text
    _match_hint.text = ""
    _match_dialog.popup_centered(Vector2i(520, 380))

func _ensure_match_dialog() -> void:
    if _match_dialog != null:
        return
    _match_dialog = ConfirmationDialog.new()
    _match_dialog.title = "Edit Match (switch)"
    var form: VBoxContainer = VBoxContainer.new()
    form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _match_expression_edit = _add_sheet_type_field(form, "Match expression", "state")
    var branches_label: Label = Label.new()
    branches_label.text = "Branches (GDScript match-body syntax — patterns + indented bodies)"
    branches_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    branches_label.custom_minimum_size = Vector2(380.0, 0.0)
    form.add_child(branches_label)
    _match_branches_edit = TextEdit.new()
    _match_branches_edit.custom_minimum_size = Vector2(480.0, 200.0)
    _match_branches_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
    form.add_child(_match_branches_edit)
    _match_hint = Label.new()
    form.add_child(_match_hint)
    _match_dialog.add_child(form)
    _match_dialog.confirmed.connect(_on_match_dialog_confirmed)
    add_child(_match_dialog)

func _on_match_dialog_confirmed() -> void:
    if _match_target == null:
        return
    var target: MatchRow = _match_target
    var expression: String = _match_expression_edit.text.strip_edges()
    var branches: String = _match_branches_edit.text
    # Guardrail: the WHOLE construct must compile before it commits.
    var construct: String = "match %s:\n" % expression
    for branch_line: String in branches.split("\n"):
        construct += "\t" + branch_line + "\n"
    var verdict: Dictionary = EventSheetGDScriptLint.lint(construct.trim_suffix("\n"), true, _current_sheet)
    if expression.is_empty() or not bool(verdict.get("ok", true)):
        _match_hint.text = "✗ The match doesn't compile — fix it before applying."
        if is_inside_tree():
            _match_dialog.call_deferred("popup_centered", Vector2i(520, 380))
        return
    var changed: bool = _perform_undoable_sheet_edit("Edit Match", func() -> bool:
        target.match_expression = expression
        target.branches_text = branches
        return true
    )
    if changed:
        _refresh_after_edit()
        _mark_dirty("Match updated.")

# ── Multi-view: split view (same sheet, two panes — VSCode-style) ─────────────────────
var _split_container: HSplitContainer = null
var _split_scroll: ScrollContainer = null
var _split_viewport: EventSheetViewport = null
# The pane whose selection drives selection-based ops (toolbar copy/paste, Ctrl+/,
# Alt+arrows, dialogs opened from the toolbar). Updated whenever a pane's selection
# changes; falls back to the primary.
var _active_viewport_ref: EventSheetViewport = null

func _active_view() -> EventSheetViewport:
    if _active_viewport_ref != null and is_instance_valid(_active_viewport_ref):
        return _active_viewport_ref
    return _viewport

## Toggles a second, read/navigate-only pane over the SAME sheet (debugging, reading,
## comparing distant regions). Breakpoints/bookmarks/disabled state are shared by
## reference; scroll/zoom/selection/folds are per-pane. See EDITOR-UI-SPEC "Multi-view".
func _toggle_split_view() -> void:
    if _split_viewport != null:
        _close_split_view()
        _set_status("Split view closed.")
        return
    if _scroll == null or _scroll.get_parent() == null:
        return
    var slot: Node = _scroll.get_parent()
    var slot_index: int = _scroll.get_index()
    slot.remove_child(_scroll)
    _split_container = HSplitContainer.new()
    _split_container.name = "EventSheetSplit"
    _split_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _split_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    slot.add_child(_split_container)
    slot.move_child(_split_container, slot_index)
    _split_container.add_child(_scroll)
    _split_scroll = ScrollContainer.new()
    _split_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _split_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _split_container.add_child(_split_scroll)
    _split_viewport = EventSheetViewport.new()
    _split_viewport.name = "EventSheetSplitViewport"
    _split_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _split_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _split_viewport.set_ace_registry(_ace_registry)
    _split_viewport.adopt_shared_state(_viewport.get_shared_state())
    _split_scroll.add_child(_split_viewport)
    _connect_view_signals(_split_viewport)
    _split_viewport.set_sheet(_current_sheet)
    _set_status("Split view: the right pane navigates independently (editing happens in the left pane).")

## Wires a secondary pane for FULL editing: the dock's handlers are payload-driven
## (signals carry the row/resource), so the same set serves any number of panes;
## selection-driven toolbar ops route through _active_view().
func _connect_view_signals(view: EventSheetViewport) -> void:
    view.selection_changed.connect(func(row_data: EventRowData) -> void:
        if _mirroring_selection:
            return  # a mirrored selection must not steal the active view
        _active_viewport_ref = view
        _mirror_selection(view, row_data)
        _on_viewport_selection_changed(row_data)
    )
    view.row_drop_requested.connect(_on_row_drop_requested)
    view.rows_drop_requested.connect(_on_rows_drop_requested)
    view.ace_picker_requested.connect(_on_viewport_ace_picker_requested)
    view.span_edit_requested.connect(_on_viewport_span_edit_requested)
    view.ace_edit_requested.connect(_on_viewport_ace_edit_requested)
    view.param_value_edit_requested.connect(_on_param_value_edit_requested)
    view.variable_edit_requested.connect(_on_viewport_variable_edit_requested)
    view.comment_edit_requested.connect(_open_comment_dialog)
    view.pick_filter_edit_requested.connect(_open_pick_filter_dialog)
    view.enum_edit_requested.connect(_open_enum_dialog)
    view.signal_edit_requested.connect(_open_signal_dialog)
    view.match_edit_requested.connect(_open_match_dialog)
    view.row_disable_toggle_requested.connect(_toggle_selected_rows_enabled)
    view.row_move_requested.connect(_move_selected_row)
    view.find_requested.connect(_show_find_bar)
    view.find_step_requested.connect(_find_step)
    view.context_menu_requested.connect(_on_viewport_context_menu_requested)
    view.raw_code_edit_requested.connect(_on_viewport_raw_code_edit_requested)

## "Open in Split": pins the given row in the other pane (opens the split if needed).
func _open_row_in_split(row_data: EventRowData) -> void:
    if row_data == null:
        return
    if _split_viewport == null:
        _toggle_split_view()
    if _split_viewport == null:
        return
    for attempt in range(2):
        for index in range(_split_viewport.get_flat_rows().size()):
            var split_row: EventRowData = _split_viewport.get_flat_rows()[index].get("row")
            if split_row != null and split_row.source_resource == row_data.source_resource:
                _split_viewport._select_row(index, -1)
                _split_viewport.ensure_selection_visible()
                _split_viewport.queue_redraw()
                return
        # Not in the flat list — it's inside a folded group: unfold the split and retry.
        _split_viewport._fold_state.clear()
        _split_viewport.set_sheet(_current_sheet)

# ── Multi-view P2: detached window (a pane on another monitor) ────────────────────────
var _detached_window: Window = null
var _detached_viewport: EventSheetViewport = null

## Toggles a floating OS window hosting another full-editing pane over the same sheet —
## drag it to a second monitor while debugging. Same shared state + refresh bus as the
## split pane.
func _toggle_detached_view() -> void:
    if _detached_window != null:
        _close_detached_view()
        _set_status("Detached view closed.")
        return
    if _viewport == null:
        return
    _detached_window = Window.new()
    _detached_window.title = "Event Sheet — detached view"
    _detached_window.size = Vector2i(960, 640)
    _detached_window.close_requested.connect(_close_detached_view)
    var detached_scroll: ScrollContainer = ScrollContainer.new()
    detached_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _detached_window.add_child(detached_scroll)
    _detached_viewport = EventSheetViewport.new()
    _detached_viewport.name = "EventSheetDetachedViewport"
    _detached_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _detached_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _detached_viewport.set_ace_registry(_ace_registry)
    _detached_viewport.adopt_shared_state(_viewport.get_shared_state())
    detached_scroll.add_child(_detached_viewport)
    _connect_view_signals(_detached_viewport)
    add_child(_detached_window)
    _detached_viewport.set_sheet(_current_sheet)
    if is_inside_tree():
        _detached_window.popup_centered(Vector2i(960, 640))
    _set_status("Detached view opened — drag it anywhere; both panes edit the same sheet.")

func _close_detached_view() -> void:
    if _detached_window == null:
        return
    if _active_viewport_ref == _detached_viewport:
        _active_viewport_ref = null
    _detached_window.queue_free()
    _detached_window = null
    _detached_viewport = null

# ── Multi-view P3: linked panes (follow selection) ─────────────────────────────────────
var _linked_views: bool = false
var _mirroring_selection: bool = false

## Toggles follow-selection: selecting a row in one pane scrolls/selects it in the
## others — e.g. keep the split zoomed out as an overview and click rows to focus them
## in the detail pane.
func _toggle_linked_views() -> void:
    _linked_views = not _linked_views
    _set_status("Linked panes: selection now follows across views." if _linked_views else "Panes unlinked.")

## Mirrors a selection into every OTHER pane (guarded against recursion).
func _mirror_selection(from_view: EventSheetViewport, row_data: EventRowData) -> void:
    if not _linked_views or _mirroring_selection or row_data == null or row_data.source_resource == null:
        return
    _mirroring_selection = true
    for view: EventSheetViewport in [_viewport, _split_viewport, _detached_viewport]:
        if view == null or view == from_view or not is_instance_valid(view):
            continue
        for index in range(view.get_flat_rows().size()):
            var candidate: EventRowData = view.get_flat_rows()[index].get("row")
            if candidate != null and candidate.source_resource == row_data.source_resource:
                view._select_row(index, -1)
                view.ensure_selection_visible()
                view.queue_redraw()
                break
    _mirroring_selection = false

func _close_split_view() -> void:
    if _split_container == null:
        return
    if _active_viewport_ref == _split_viewport:
        _active_viewport_ref = null
    var slot: Node = _split_container.get_parent()
    var slot_index: int = _split_container.get_index()
    _split_container.remove_child(_scroll)
    if slot != null:
        slot.add_child(_scroll)
        slot.move_child(_scroll, slot_index)
    _split_container.queue_free()
    _split_container = null
    _split_scroll = null
    _split_viewport = null

## Keeps every secondary pane on the current sheet after edits/opens (the refresh bus).
func _sync_split_sheet() -> void:
    if _split_viewport != null:
        _split_viewport.set_sheet(_current_sheet)
    if _detached_viewport != null:
        _detached_viewport.set_sheet(_current_sheet)

# ── Export as Addon Pack (C3 coverage Phase C) ─# ── Export as Addon Pack (C3 coverage Phase C) ────────────────────────────────────────

## One-click addon publishing: writes the current behavior sheet (+ compiled script) into
## eventsheet_addons/<class_snake>/ where the zero-config scanner publishes its ACEs
## project-wide — the same layout the bundled packs use. base_dir_override is for tests.
func _export_addon_pack(base_dir_override: String = "") -> void:
    if _current_sheet == null:
        return
    if not _current_sheet.behavior_mode or _current_sheet.custom_class_name.strip_edges().is_empty():
        _set_status("Addon packs are behavior sheets — enable behavior mode and set a class name first (Sheet Type).", true)
        return
    var class_name_text: String = _current_sheet.custom_class_name.strip_edges()
    if not EventSheetIdentifierRules.is_valid(class_name_text):
        _set_status("\"%s\" can't be a class name (letters/digits/underscores, not a keyword)." % class_name_text, true)
        return
    var folder_name: String = class_name_text.to_snake_case()
    var base_dir: String = base_dir_override if not base_dir_override.is_empty() else "res://eventsheet_addons/%s" % folder_name
    var base_path: String = "%s/%s" % [base_dir, folder_name]
    DirAccess.make_dir_recursive_absolute(base_dir)
    var pack_sheet: EventSheetResource = _current_sheet.duplicate(true)
    var save_error: Error = ResourceSaver.save(pack_sheet, base_path + ".tres")
    if save_error != OK:
        _set_status("Export failed: couldn't save %s.tres (error %d)." % [base_path, save_error], true)
        return
    # Adopt the saved path BEFORE compiling so the generated "# Source:" header matches a
    # recompile of the exported .tres (the same no-drift rule the bundled packs follow).
    pack_sheet.take_over_path(base_path + ".tres")
    var compile_result: Dictionary = SheetCompiler.compile(pack_sheet, base_path + ".gd")
    if not bool(compile_result.get("success", false)):
        _set_status("Export failed: the sheet doesn't compile (%s)." % str(compile_result.get("errors")), true)
        return
    # Auto-docs: shared packs are documented by default.
    var readme_file: FileAccess = FileAccess.open("%s/README.md" % base_dir, FileAccess.WRITE)
    if readme_file != null:
        readme_file.store_string(_generate_pack_readme(pack_sheet))
        readme_file.close()
    # Lane A composition: packs travel complete — bundle included sheets unless the
    # project policy says reference-only (docs/ADDON-COMPOSITION-SPEC.md).
    var bundled_count: int = 0
    if str(SheetCompiler._addon_policy("export_bundling", "bundle")) == "bundle":
        for include_path: String in pack_sheet.includes:
            if ResourceLoader.exists(include_path):
                var bundle_target: String = "%s/%s" % [base_dir, include_path.get_file()]
                if bundle_target != include_path and DirAccess.copy_absolute(include_path, bundle_target) == OK:
                    bundled_count += 1
    if Engine.is_editor_hint() and is_inside_tree():
        EditorInterface.get_resource_filesystem().scan()
    var bundle_note: String = " (+%d bundled include(s))" % bundled_count if bundled_count > 0 else ""
    _set_status("Exported addon pack to %s (.tres + .gd)%s — its ACEs are now published project-wide." % [base_dir, bundle_note])

# ── Godot-feel: find bar, keyboard row ops, editor-native defaults ─# ── Godot-feel: find bar, keyboard row ops, editor-native defaults ─# ── Godot-feel: find bar, keyboard row ops, editor-native defaults ────────────────────
var _find_bar: HBoxContainer = null
var _find_edit: LineEdit = null
var _find_count_label: Label = null
var _replace_edit: LineEdit = null
var _find_resource_matches: Array[Resource] = []
var _find_cursor: int = -1

# ── Live Values panel — extracted to dock/live_values_panel.gd ───────────────────────
var _live_values_panel: EventSheetLiveValuesPanel = null

func _ensure_live_values_panel() -> EventSheetLiveValuesPanel:
    if _live_values_panel == null:
        _live_values_panel = EventSheetLiveValuesPanel.new(self)
    return _live_values_panel

# Forwarding properties: tests (and the plugin) reach these through the dock.
var _live_values_tree: Tree:
    get: return _ensure_live_values_panel().tree
var _live_values_label: RichTextLabel:
    get: return _ensure_live_values_panel().label
var _live_values_window: Window:
    get: return _ensure_live_values_panel().window

func set_live_values_debugger(debugger: EventSheetLiveValuesDebugger) -> void:
    _ensure_live_values_panel().debugger = debugger

func _toggle_live_values() -> void:
    _ensure_live_values_panel().toggle()

func _ensure_live_values_window() -> void:
    _ensure_live_values_panel().ensure_window()

func update_live_values(values: Dictionary) -> void:
    _ensure_live_values_panel().update_values(values)

# ── Single-param inline editing (C3's fastest gesture) ───────────────────────────────
var _param_edit_popup: PopupPanel = null
var _param_edit_field: LineEdit = null
var _param_edit_target: Resource = null
var _param_edit_key: String = ""

## Double-clicking a highlighted value opens this one-field editor at the mouse.
func _on_param_value_edit_requested(ace: Resource, param_id: String, current_text: String) -> void:
    if _param_edit_popup == null:
        _param_edit_popup = PopupPanel.new()
        _param_edit_field = LineEdit.new()
        _param_edit_field.custom_minimum_size = Vector2(180.0, 0.0)
        _param_edit_field.text_submitted.connect(func(_t: String) -> void: _commit_inline_param_edit())
        _param_edit_popup.add_child(_param_edit_field)
        add_child(_param_edit_popup)
    _param_edit_target = ace
    _param_edit_key = param_id
    _param_edit_field.text = current_text
    _param_edit_popup.popup(Rect2i(Vector2i(DisplayServer.mouse_get_position()), Vector2i(200, 36)))
    _param_edit_field.grab_focus()
    _param_edit_field.select_all()

func _commit_inline_param_edit() -> void:
    if _param_edit_target == null or _param_edit_key.is_empty():
        return
    var target: Resource = _param_edit_target
    var key: String = _param_edit_key
    var new_text: String = _param_edit_field.text
    var changed: bool = _perform_undoable_sheet_edit("Edit Parameter", func() -> bool:
        var params: Dictionary = target.get("params")
        if str(params.get(key, "")) == new_text:
            return false
        params[key] = new_text
        return true
    )
    _param_edit_popup.hide()
    if changed:
        _refresh_after_edit()
        _mark_dirty("Parameter updated.")

## Toggles debug compiles: gutter breakpoints (F9) emit real `breakpoint` statements.
func _toggle_breakpoint_emission() -> void:
    if _current_sheet == null:
        return
    _current_sheet.emit_breakpoints = not _current_sheet.emit_breakpoints
    _set_status("Debug compile ON: breakpointed events emit `breakpoint` (recompile to apply)." if _current_sheet.emit_breakpoints else "Debug compile OFF: breakpoints render only.")

## Ctrl+F: a script-editor-style find bar (Enter/F3 next, Shift+F3 previous, Esc hides).
func _show_find_bar() -> void:
    _ensure_find_bar()
    _find_bar.visible = true
    _find_edit.grab_focus()
    _find_edit.select_all()

func _ensure_find_bar() -> void:
    if _find_bar != null:
        return
    _find_bar = HBoxContainer.new()
    _find_bar.name = "EventSheetFindBar"
    _find_edit = LineEdit.new()
    _find_edit.placeholder_text = "Find in sheet…  (Enter: next, Esc: close)"
    _find_edit.custom_minimum_size = Vector2(220.0, 0.0)
    _find_edit.text_changed.connect(_on_find_text_changed)
    _find_edit.text_submitted.connect(func(_text: String) -> void: _find_step(1))
    _find_edit.gui_input.connect(func(input_event: InputEvent) -> void:
        if input_event is InputEventKey and (input_event as InputEventKey).pressed and (input_event as InputEventKey).keycode == KEY_ESCAPE:
            _find_bar.visible = false
            if _viewport != null:
                _viewport.grab_focus()
    )
    _find_bar.add_child(_find_edit)
    _find_count_label = Label.new()
    _find_count_label.text = ""
    _find_bar.add_child(_find_count_label)
    _replace_edit = LineEdit.new()
    _replace_edit.placeholder_text = "Replace with…"
    _replace_edit.custom_minimum_size = Vector2(160.0, 0.0)
    _find_bar.add_child(_replace_edit)
    var replace_button: Button = Button.new()
    replace_button.text = "Replace All"
    replace_button.pressed.connect(_replace_all_in_sheet)
    _find_bar.add_child(replace_button)
    var split_match_button: Button = Button.new()
    split_match_button.text = "Open in Split"
    split_match_button.tooltip_text = "Open the current match in the split pane."
    split_match_button.pressed.connect(_open_match_in_split)
    _find_bar.add_child(split_match_button)
    var close_button: Button = Button.new()
    close_button.text = "✕"
    close_button.flat = true
    close_button.pressed.connect(func() -> void: _find_bar.visible = false)
    _find_bar.add_child(close_button)
    _toolbar.add_child(_find_bar)

func _on_find_text_changed(text: String) -> void:
    _find_resource_matches = _viewport.search_all(text) if _viewport != null else []
    _find_cursor = -1
    if _find_resource_matches.is_empty():
        _find_count_label.text = "no matches" if not text.strip_edges().is_empty() else ""
        return
    _find_step(1)

func _find_step(direction: int) -> void:
    # Matches recompute on every step (results go stale after any edit) and search the
    # FULL tree — find lands inside folded groups by unfolding the path to the match.
    if _find_edit == null or _viewport == null or _find_edit.text.strip_edges().is_empty():
        return
    _find_resource_matches = _viewport.search_all(_find_edit.text)
    if _find_resource_matches.is_empty():
        if _find_count_label != null:
            _find_count_label.text = "no matches"
        return
    _find_cursor = wrapi(_find_cursor + direction, 0, _find_resource_matches.size())
    _find_count_label.text = "%d of %d" % [_find_cursor + 1, _find_resource_matches.size()]
    _viewport.reveal_resource(_find_resource_matches[_find_cursor])

## Replace All: substitutes the find text across comments, GDScript blocks, string
## params, pick-filter expressions, group names/descriptions and match branches —
## one undoable edit, count reported.
func _replace_all_in_sheet() -> void:
    if _viewport == null or _current_sheet == null or _find_edit == null or _replace_edit == null:
        return
    var find_text: String = _find_edit.text
    if find_text.is_empty():
        _set_status("Type something in Find first.", true)
        return
    var replace_text: String = _replace_edit.text
    var counter: Dictionary = {"count": 0}
    var changed: bool = _perform_undoable_sheet_edit("Replace All", func() -> bool:
        _replace_in_rows(_current_sheet.events, find_text, replace_text, counter)
        for function_resource: Variant in _current_sheet.functions:
            if function_resource is EventFunction:
                _replace_in_rows((function_resource as EventFunction).events if not (function_resource as EventFunction).events.is_empty() else (function_resource as EventFunction).rows, find_text, replace_text, counter)
        return int(counter.get("count", 0)) > 0
    )
    if changed:
        _refresh_after_edit()
        _mark_dirty("Replaced %d occurrence(s)." % int(counter.get("count", 0)))
    else:
        _set_status("No matches for \"%s\"." % find_text)

func _replace_in_rows(rows: Array, find_text: String, replace_text: String, counter: Dictionary) -> void:
    for row: Variant in rows:
        if row is CommentRow:
            counter["count"] = int(counter.get("count", 0)) + (row as CommentRow).text.count(find_text)
            (row as CommentRow).text = (row as CommentRow).text.replace(find_text, replace_text)
        elif row is RawCodeRow:
            counter["count"] = int(counter.get("count", 0)) + (row as RawCodeRow).code.count(find_text)
            (row as RawCodeRow).code = (row as RawCodeRow).code.replace(find_text, replace_text)
        elif row is EventGroup:
            var group: EventGroup = row as EventGroup
            counter["count"] = int(counter.get("count", 0)) + group.group_name.count(find_text) + group.description.count(find_text)
            group.group_name = group.group_name.replace(find_text, replace_text)
            group.name = group.group_name
            group.description = group.description.replace(find_text, replace_text)
            _replace_in_rows(group.events if not group.events.is_empty() else group.rows, find_text, replace_text, counter)
        elif row is EventRow:
            var event_row: EventRow = row as EventRow
            for ace: Variant in event_row.conditions + event_row.actions:
                if ace is RawCodeRow:
                    counter["count"] = int(counter.get("count", 0)) + (ace as RawCodeRow).code.count(find_text)
                    (ace as RawCodeRow).code = (ace as RawCodeRow).code.replace(find_text, replace_text)
                elif ace is MatchRow:
                    counter["count"] = int(counter.get("count", 0)) + (ace as MatchRow).branches_text.count(find_text)
                    (ace as MatchRow).branches_text = (ace as MatchRow).branches_text.replace(find_text, replace_text)
                elif ace is Resource and ace.get("params") is Dictionary:
                    if ace.get("comment") is String and not str(ace.get("comment")).is_empty():
                        counter["count"] = int(counter.get("count", 0)) + str(ace.get("comment")).count(find_text)
                        ace.set("comment", str(ace.get("comment")).replace(find_text, replace_text))
                    var params: Dictionary = ace.get("params")
                    for key: Variant in params.keys():
                        if params[key] is String:
                            counter["count"] = int(counter.get("count", 0)) + (params[key] as String).count(find_text)
                            params[key] = (params[key] as String).replace(find_text, replace_text)
            for pick: Variant in event_row.pick_filters:
                if pick is PickFilter:
                    counter["count"] = int(counter.get("count", 0)) + (pick as PickFilter).collection_value.count(find_text) + (pick as PickFilter).predicate_expression.count(find_text) + (pick as PickFilter).order_by_expression.count(find_text)
                    (pick as PickFilter).collection_value = (pick as PickFilter).collection_value.replace(find_text, replace_text)
                    (pick as PickFilter).predicate_expression = (pick as PickFilter).predicate_expression.replace(find_text, replace_text)
                    (pick as PickFilter).order_by_expression = (pick as PickFilter).order_by_expression.replace(find_text, replace_text)
            _replace_in_rows(event_row.sub_events, find_text, replace_text, counter)

# ── Group color tags ──────────────────────────────────────────────────────────────────
var _group_color_popup: PopupPanel = null
var _group_color_picker: ColorPickerButton = null
var _group_color_target: EventGroup = null

## Opt-in runtime toggling: the group compiles a guard member that Set Group Active
## flips at runtime (feature flags, debug switches). Off = zero-cost organization.
func _toggle_group_runtime() -> void:
    var target: Resource = _context_row.source_resource if _context_row != null else null
    if not (target is EventGroup):
        _set_status("Right-click a group to make it runtime-toggleable.", true)
        return
    var group: EventGroup = target
    var changed: bool = _perform_undoable_sheet_edit("Runtime Toggleable", func() -> bool:
        group.runtime_toggleable = not group.runtime_toggleable
        return true
    )
    if changed:
        _refresh_after_edit()
        _mark_dirty("Group \"%s\" is %s — Set Group Active targets \"%s\"." % [group.group_name, "runtime-toggleable" if group.runtime_toggleable else "compile-time only again", group.group_name.to_snake_case()])

## C3-style group colors: tint the selected group's accent/background (clear = theme).
func _open_group_color_picker() -> void:
    var target: Resource = _context_row.source_resource if _context_row != null else null
    if not (target is EventGroup):
        _set_status("Right-click a group to color it.", true)
        return
    if _group_color_popup == null:
        _group_color_popup = PopupPanel.new()
        var color_box: HBoxContainer = HBoxContainer.new()
        _group_color_picker = ColorPickerButton.new()
        _group_color_picker.custom_minimum_size = Vector2(120.0, 0.0)
        _group_color_picker.color_changed.connect(func(value: Color) -> void: _apply_group_color(value))
        color_box.add_child(_group_color_picker)
        var clear_button: Button = Button.new()
        clear_button.text = "Theme default"
        clear_button.pressed.connect(func() -> void:
            _apply_group_color(Color(0.0, 0.0, 0.0, 0.0))
            _group_color_popup.hide()
        )
        color_box.add_child(clear_button)
        _group_color_popup.add_child(color_box)
        add_child(_group_color_popup)
    _group_color_target = target
    _group_color_picker.color = target.custom_color if target.custom_color.a > 0.0 else Color(0.55, 0.45, 0.85, 1.0)
    _group_color_popup.popup(Rect2i(Vector2i(DisplayServer.mouse_get_position()), Vector2i(220, 42)))

func _apply_group_color(value: Color) -> void:
    if _group_color_target == null:
        return
    var target: EventGroup = _group_color_target
    var changed: bool = _perform_undoable_sheet_edit("Group Color", func() -> bool:
        if target.custom_color == value:
            return false
        target.custom_color = value
        return true
    )
    if changed:
        _refresh_after_edit()
        _mark_dirty("Group color updated.")

# ── Autoload (Singleton) sheets ───────────────────────────────────────────────────────

## One click: compile the autoload sheet and register the generated script in
## ProjectSettings. Guarded: needs the type, a name, a saved sheet, and a free slot.
func _register_autoload() -> void:
    if _current_sheet == null or not _current_sheet.autoload_mode:
        _set_status("Set the sheet type to Autoload (Singleton) first (Sheet Type…).", true)
        return
    var problem: String = _register_autoload_entry(_current_sheet, _current_sheet_path)
    if problem.is_empty():
        _set_status("Registered autoload \"%s\" — every sheet (and script) can call it now." % _current_sheet.autoload_name)
    else:
        _set_status(problem, true)

## The testable core: compiles next to the sheet and writes the autoload entry.
## Returns "" on success or the user-facing problem.
func _register_autoload_entry(sheet: EventSheetResource, sheet_path: String) -> String:
    var autoload_name: String = sheet.autoload_name.strip_edges()
    if autoload_name.is_empty() or not EventSheetIdentifierRules.is_valid(autoload_name):
        return "Autoload needs a valid name (Sheet Type… → Autoload name)."
    if sheet_path.is_empty():
        return "Save the sheet first — the autoload entry must point at a real file."
    var output_path: String = sheet_path.get_basename() + ".gd"
    var compile_result: Dictionary = SheetCompiler.compile(sheet, output_path)
    if not bool(compile_result.get("success", false)):
        return "Autoload not registered: the sheet doesn't compile (%s)." % str(compile_result.get("errors"))
    var setting_name: String = "autoload/%s" % autoload_name
    var target_value: String = "*%s" % output_path
    if ProjectSettings.has_setting(setting_name) and str(ProjectSettings.get_setting(setting_name)) != target_value:
        return "An autoload named \"%s\" already exists and points elsewhere — pick another name." % autoload_name
    ProjectSettings.set_setting(setting_name, target_value)
    if Engine.is_editor_hint():
        ProjectSettings.save()
    return ""

# ── Addon-author loop — extracted to dock/author_loop.gd ─────────────────────────────
var _author_loop: EventSheetAuthorLoop = null

func _ensure_author_loop() -> EventSheetAuthorLoop:
    if _author_loop == null:
        _author_loop = EventSheetAuthorLoop.new(self)
    return _author_loop

func _collect_publish_surface(sheet: EventSheetResource) -> Dictionary:
    return EventSheetAuthorLoop.collect_publish_surface(sheet)

static func publish_surface_text(surface: Dictionary) -> String:
    return EventSheetAuthorLoop.publish_surface_text(surface)

func _generate_pack_readme(sheet: EventSheetResource) -> String:
    return EventSheetAuthorLoop.generate_pack_readme(sheet)

func _open_publish_preview() -> void:
    _ensure_author_loop().open_publish_preview()

func _open_test_bench() -> void:
    _ensure_author_loop().open_test_bench()

func _build_test_bench(sheet: EventSheetResource, scene_path: String) -> String:
    return _ensure_author_loop().build_test_bench(sheet, scene_path)

# ── Project-wide find / replace / usages — extracted to dock/project_find.gd ─────────
# (Dock decomposition arc: state + logic live in the helper; these delegates keep the
# public/test surface stable.)
var _project_find: EventSheetProjectFind = null

func _open_project_find(initial_query: String = "") -> void:
    if _project_find == null:
        _project_find = EventSheetProjectFind.new(self)
    _project_find.open(initial_query)

# ── Project Doctor — the one-stop health audit (Tools menu; core lives in
# EventSheetProjectDoctor so the headless CLI and CI run the same checks) ─────────────
var _doctor_window: Window = null
var _doctor_tree: Tree = null

func _open_project_doctor() -> void:
    if _doctor_window == null:
        _doctor_window = Window.new()
        _doctor_window.title = "Project Doctor"
        _doctor_window.size = Vector2i(680, 440)
        _doctor_window.close_requested.connect(func() -> void: _doctor_window.hide())
        var box: VBoxContainer = VBoxContainer.new()
        box.set_anchors_preset(Control.PRESET_FULL_RECT)
        _doctor_tree = Tree.new()
        _doctor_tree.hide_root = true
        _doctor_tree.columns = 3
        _doctor_tree.set_column_title(0, "Severity")
        _doctor_tree.set_column_title(1, "Where")
        _doctor_tree.set_column_title(2, "Finding")
        _doctor_tree.set_column_expand(0, false)
        _doctor_tree.set_column_custom_minimum_width(0, 80)
        _doctor_tree.set_column_expand(1, false)
        _doctor_tree.set_column_custom_minimum_width(1, 180)
        _doctor_tree.column_titles_visible = true
        _doctor_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
        box.add_child(_doctor_tree)
        var rerun_button: Button = Button.new()
        rerun_button.text = "Re-run checks"
        rerun_button.pressed.connect(_run_project_doctor)
        box.add_child(rerun_button)
        _doctor_window.add_child(box)
        add_child(_doctor_window)
    _doctor_window.popup_centered()
    _run_project_doctor()

func _run_project_doctor() -> void:
    _doctor_tree.clear()
    var root_item: TreeItem = _doctor_tree.create_item()
    var report: Dictionary = EventSheetProjectDoctor.run()
    for finding: Dictionary in (report.get("findings", []) as Array):
        var item: TreeItem = _doctor_tree.create_item(root_item)
        var severity: String = str(finding.get("severity"))
        item.set_text(0, severity.to_upper())
        item.set_custom_color(0, Color(0.92, 0.42, 0.42) if severity == "error"
            else (Color(0.93, 0.78, 0.4) if severity == "warning" else Color(0.6, 0.72, 0.86)))
        item.set_text(1, str(finding.get("path")).get_file())
        item.set_tooltip_text(1, str(finding.get("path")))
        item.set_text(2, str(finding.get("message")))
    var errors: int = int(report.get("errors", 0))
    _set_status("Project Doctor: %d error(s), %d warning(s), %d note(s)." % [errors, int(report.get("warnings", 0)), int(report.get("infos", 0))], errors > 0)

## Writes the always-current project vocabulary reference (EventSheetVocabularyDoc) —
## the answer to "what can I say in this project?" as one committed markdown file.
func _generate_vocabulary_doc() -> void:
    var doc_path: String = EventSheetVocabularyDoc.write()
    if doc_path.is_empty():
        _set_status("Couldn't write the vocabulary doc to %s." % EventSheetVocabularyDoc.doc_path(), true)
        return
    if Engine.is_editor_hint() and is_inside_tree():
        EditorInterface.get_resource_filesystem().scan()
    _set_status("Vocabulary doc written to %s." % doc_path)

# ── Sheet backups — the save-time ring (core in EventSheetBackups) ────────────────────
var _backups_window: Window = null
var _backups_list: ItemList = null

func _open_sheet_backups() -> void:
    if _current_sheet == null or _current_sheet_path.is_empty():
        _set_status("Backups track saved sheets — save this sheet first.", true)
        return
    if _backups_window == null:
        _backups_window = Window.new()
        _backups_window.title = "Sheet Backups"
        _backups_window.size = Vector2i(460, 360)
        _backups_window.close_requested.connect(func() -> void: _backups_window.hide())
        var box: VBoxContainer = VBoxContainer.new()
        box.set_anchors_preset(Control.PRESET_FULL_RECT)
        _backups_list = ItemList.new()
        _backups_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _backups_list.item_activated.connect(func(_index: int) -> void: _on_restore_backup_pressed())
        box.add_child(_backups_list)
        var restore_button: Button = Button.new()
        restore_button.text = "Restore into editor (unsaved — Save to keep)"
        restore_button.pressed.connect(_on_restore_backup_pressed)
        box.add_child(restore_button)
        _backups_window.add_child(box)
        add_child(_backups_window)
    _backups_list.clear()
    for backup_path: String in EventSheetBackups.list_backups(_current_sheet_path):
        var stamp: String = Time.get_datetime_string_from_unix_time(int(FileAccess.get_modified_time(backup_path))).replace("T", " ")
        _backups_list.add_item("%s — %s" % [stamp, backup_path.get_file()])
        _backups_list.set_item_metadata(_backups_list.item_count - 1, backup_path)
    if _backups_list.item_count == 0:
        _backups_list.add_item("(no backups yet — they appear from the second save on)")
        _backups_list.set_item_disabled(0, true)
    _backups_window.popup_centered()

func _on_restore_backup_pressed() -> void:
    var selected: PackedInt32Array = _backups_list.get_selected_items()
    if selected.is_empty() or _backups_list.get_item_metadata(selected[0]) == null:
        return
    _restore_backup_path(str(_backups_list.get_item_metadata(selected[0])))
    _backups_window.hide()

## Restores a backup INTO the editor as an unsaved change: every storage property of
## the backup is copied onto the open sheet (same object — tabs, viewport and code
## panel stay coherent), the user reviews and saves to keep it. Nothing on disk
## changes until that save, and the save itself backs up the pre-restore state.
func _restore_backup_path(backup_path: String) -> void:
    var backup: EventSheetResource = ResourceLoader.load(backup_path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource
    if backup == null:
        _set_status("Couldn't load that backup.", true)
        return
    for property: Dictionary in backup.get_property_list():
        var property_name: String = str(property.get("name"))
        if (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE) != 0 \
                and not property_name.begins_with("resource_") and property_name != "script":
            _current_sheet.set(property_name, backup.get(property_name))
    _dirty = true
    _clear_undo_history()
    _refresh_after_edit()
    _refresh_title_strip()
    _set_status("Backup restored into the editor (unsaved) — Save to keep it, reopen the sheet to discard.")

## Writes a deep copy of the current sheet into the project templates dir (never
## overwrites — an existing name gets a -2/-3 suffix). It joins the New… menu
## immediately (the menu rescans on every open).
func _save_as_project_template() -> void:
    if _current_sheet == null:
        return
    var dir_path: String = EventSheetTemplates.templates_dir()
    DirAccess.make_dir_recursive_absolute(dir_path)
    var base_name: String = _current_sheet.custom_class_name.to_snake_case()
    if base_name.is_empty():
        base_name = _current_sheet_path.get_file().get_basename() if not _current_sheet_path.is_empty() else "template"
    var target: String = dir_path.path_join(base_name + ".tres")
    var suffix: int = 2
    while FileAccess.file_exists(target):
        target = dir_path.path_join("%s-%d.tres" % [base_name, suffix])
        suffix += 1
    if ResourceSaver.save(_current_sheet.duplicate(true), target) != OK:
        _set_status("Couldn't write the template to %s." % target, true)
        return
    if Engine.is_editor_hint() and is_inside_tree():
        EditorInterface.get_resource_filesystem().scan()
    _set_status("Template saved: %s — it's in the New… menu now." % target)

static func list_project_sheets() -> PackedStringArray:
    return EventSheetProjectFind.list_project_sheets()

static func find_in_sheet(sheet: EventSheetResource, needle: String) -> Array:
    return EventSheetProjectFind.find_in_sheet(sheet, needle)

## Find-bar "Open in Split": jumps the split pane to the current match (opening the
## split if needed) — marrying search and multi-view.
func _open_match_in_split() -> void:
    if _find_resource_matches.is_empty():
        _set_status("Find something first.", true)
        return
    var match_resource: Resource = _find_resource_matches[clampi(_find_cursor, 0, _find_resource_matches.size() - 1)]
    if _split_viewport == null:
        _toggle_split_view()
    if _split_viewport != null:
        _split_viewport.reveal_resource(match_resource)
        _set_status("Match opened in the split pane.")

# ── Bookmarks panel — extracted to dock/bookmarks_panel.gd ───────────────────────────
var _bookmarks_panel: EventSheetBookmarksPanel = null

func _ensure_bookmarks_panel() -> EventSheetBookmarksPanel:
    if _bookmarks_panel == null:
        _bookmarks_panel = EventSheetBookmarksPanel.new(self)
    return _bookmarks_panel

# Forwarding properties (tests assign these directly — keep them settable).
var _bookmarks_window: Window:
    get: return _ensure_bookmarks_panel().window
    set(value): _ensure_bookmarks_panel().window = value
var _bookmarks_list: ItemList:
    get: return _ensure_bookmarks_panel().list
    set(value): _ensure_bookmarks_panel().list = value

func _open_bookmarks_panel() -> void:
    _ensure_bookmarks_panel().open()

func _refresh_bookmarks_list() -> void:
    _ensure_bookmarks_panel().refresh()

## Ctrl+/: toggles the selected rows' enabled state (the sheet's "comment out").
func _toggle_selected_rows_enabled() -> void:
    if _viewport == null or _current_sheet == null:
        return
    var targets: Array[Resource] = []
    for row_data: EventRowData in _active_view().get_selected_rows():
        if row_data != null and row_data.source_resource != null:
            targets.append(row_data.source_resource)
    if targets.is_empty():
        return
    var changed: bool = _perform_undoable_sheet_edit("Toggle Row Enabled", func() -> bool:
        for target: Resource in targets:
            target.set("enabled", not bool(target.get("enabled")))
        return true
    )
    if changed:
        _refresh_after_edit()
        _mark_dirty("Toggled %d row(s)." % targets.size())

## Alt+Up/Down: moves the selected row past its flat neighbor (reuses the drag machinery).
func _move_selected_row(direction: int) -> void:
    if _viewport == null:
        return
    var selected_index: int = _active_view().get_selected_context().get("row_index", -1)
    var row_data: EventRowData = _active_view().get_selected_row_data()
    if row_data == null or selected_index < 0:
        return
    var target_index: int = selected_index + direction
    if target_index < 0 or target_index >= _viewport.get_flat_rows().size():
        return
    var target_row: EventRowData = _viewport.get_flat_rows()[target_index].get("row")
    if target_row == null or target_row.source_resource == null:
        return
    _move_rows([row_data], target_row, "before" if direction < 0 else "after")

## Editor-native defaults: inherit the user's editor theme + display scale when no
## explicit sheet theme was chosen (presets/per-sheet themes still override).
func _apply_editor_native_defaults() -> void:
    if not Engine.is_editor_hint() or _viewport == null:
        return
    if _active_theme_style == null:
        var derived: EventSheetEditorStyle = EventSheetEditorThemeDeriver.derive_from_editor()
        if derived != null:
            apply_theme_style(derived)
    var editor_scale: float = EditorInterface.get_editor_scale()
    if editor_scale > 1.01:
        _viewport.set_zoom_factor(editor_scale)

# ── Quick-add bar (C3 "type to insert") ──────────────────────────────────────
var _quick_add_edit: LineEdit = null

## Best ACE for a quick-add query. Leading words match a definition (display name / id,
## with the picker's C3 synonym phrasing honored); trailing words fill its parameters
## positionally as raw values. Returns {definition, params} or {}.
func _quick_match(query: String) -> Dictionary:
    var text: String = query.strip_edges().to_lower()
    if text.is_empty() or _ace_registry == null:
        return {}
    var queries: Array[String] = [text]
    for synonym_query: String in ACEPickerDialog._c3_synonym_queries(text):
        queries.append(synonym_query.to_lower())
    var best: ACEDefinition = null
    var best_score: int = 0
    var best_rest: String = ""
    var best_name_length: int = 1 << 30
    for definition: ACEDefinition in _ace_registry.get_all_definitions():
        if bool(definition.metadata.get("hidden", false)):
            continue
        for candidate_name: String in [definition.display_name.to_lower(), definition.id.to_lower()]:
            if candidate_name.is_empty():
                continue
            for candidate_query: String in queries:
                var score: int = 0
                var rest: String = ""
                if candidate_query == candidate_name:
                    score = 100
                elif candidate_query.begins_with(candidate_name + " "):
                    score = 90
                    rest = candidate_query.substr(candidate_name.length() + 1)
                elif candidate_name.begins_with(candidate_query):
                    score = 60
                elif candidate_name.contains(candidate_query):
                    score = 40
                # Shorter matched names win ties (the query "process" should pick
                # OnProcess, not OnPhysicsProcess).
                if score > best_score or (score == best_score and candidate_name.length() < best_name_length):
                    best = definition
                    best_score = score
                    best_rest = rest
                    best_name_length = candidate_name.length()
    if best == null or best_score == 0:
        return {}
    var params: Dictionary = {}
    var values: PackedStringArray = best_rest.split(" ", false)
    for index in range(mini(values.size(), best.parameters.size())):
        var parameter: Variant = best.parameters[index]
        if parameter is Dictionary:
            params[str((parameter as Dictionary).get("id", ""))] = values[index]
    return {"definition": best, "params": params}

## Applies the best match: triggers/conditions become a new event; actions append via the
## standard apply flow (below the current selection). Returns true when something landed.
func _quick_add(query: String) -> bool:
    if not _ensure_sheet_for_editing():
        return false
    var matched: Dictionary = _quick_match(query)
    if matched.is_empty():
        _set_status("Quick add: nothing matches \"%s\"." % query.strip_edges(), true)
        return false
    var definition: ACEDefinition = matched.get("definition")
    var mode: String = "" if definition.ace_type == ACEDefinition.ACEType.ACTION else "new_condition_event"
    var context: Dictionary = {
        "mode": mode,
        "selected_resource": _active_view().get_selected_context().get("source_resource", null)
    }
    _apply_ace_definition(definition, matched.get("params", {}), context)
    return true

# ── Pick-filter dialog (C3 "for each" picking) ───────────────────────────────
var _pick_dialog: ConfirmationDialog = null
var _pick_iterator_edit: LineEdit = null
var _pick_kind_option: OptionButton = null
var _pick_collection_edit: LineEdit = null
var _pick_predicate_edit: LineEdit = null
var _pick_order_edit: LineEdit = null
var _pick_desc_check: CheckBox = null
var _pick_preset_option: OptionButton = null
var _pick_first_n_spin: SpinBox = null
var _pick_delete_button: Button = null
var _pick_target_event: EventRow = null
var _pick_target_index: int = -1

## Opens the pick-filter dialog: pick_index = -1 adds a new filter, >= 0 edits/deletes.
func _open_pick_filter_dialog(event_resource: Resource, pick_index: int = -1) -> void:
    var event_row: EventRow = event_resource as EventRow
    if event_row == null:
        _set_status("Select an event to add a pick filter.", true)
        return
    _ensure_pick_dialog()
    _pick_target_event = event_row
    _pick_target_index = pick_index
    var editing: bool = pick_index >= 0 and pick_index < event_row.pick_filters.size()
    var pick: PickFilter = event_row.pick_filters[pick_index] if editing else PickFilter.new()
    _pick_iterator_edit.text = pick.iterator_name
    _pick_kind_option.select(_pick_kind_to_option(pick.collection_kind))
    _pick_collection_edit.text = pick.collection_value if not pick.collection_value.is_empty() else pick.source_expression
    _pick_predicate_edit.text = pick.predicate_expression
    _pick_order_edit.text = pick.order_by_expression
    _pick_desc_check.button_pressed = pick.order_descending
    _pick_preset_option.select(0)
    _pick_first_n_spin.value = pick.pick_first_n
    _pick_delete_button.visible = editing
    _pick_dialog.title = "Edit Pick Filter (For Each)" if editing else "Add Pick Filter (For Each)"
    _pick_dialog.popup_centered(Vector2i(520, 300))

func _ensure_pick_dialog() -> void:
    if _pick_dialog != null:
        return
    _pick_dialog = ConfirmationDialog.new()
    var form: VBoxContainer = VBoxContainer.new()
    form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _pick_iterator_edit = _add_sheet_type_field(form, "Iterator name", "item")
    var kind_row: HBoxContainer = HBoxContainer.new()
    var kind_label: Label = Label.new()
    kind_label.text = "Collection"
    kind_label.custom_minimum_size = Vector2(130.0, 0.0)
    kind_row.add_child(kind_label)
    _pick_kind_option = OptionButton.new()
    _pick_kind_option.add_item("Node group")        # → get_tree().get_nodes_in_group(value)
    _pick_kind_option.add_item("Children")          # → get_children()
    _pick_kind_option.add_item("GDScript iterable") # → value verbatim (array, range(), …)
    _pick_kind_option.add_item("Repeat N times")    # → for i in range(value)
    _pick_kind_option.add_item("While (condition)") # → while value
    _pick_kind_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    kind_row.add_child(_pick_kind_option)
    form.add_child(kind_row)
    _pick_collection_edit = _add_sheet_type_field(form, "Group / expression", "enemies   or   range(3)")
    _pick_predicate_edit = _add_sheet_type_field(form, "Where (GDScript)", "item.health < 50   (optional)")
    _pick_order_edit = _add_sheet_type_field(form, "Order by (GDScript)", "item.global_position.distance_to(position)   (optional)")
    _pick_desc_check = CheckBox.new()
    _pick_desc_check.text = "Descending (highest first)"
    form.add_child(_pick_desc_check)
    var preset_label: Label = Label.new()
    preset_label.text = "C3 presets (loops & picking)"
    preset_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    preset_label.custom_minimum_size = Vector2(380.0, 0.0)
    form.add_child(preset_label)
    _pick_preset_option = OptionButton.new()
    for preset_name: String in ["Custom…", "For (indexed)", "For Each", "For Each (ordered)", "Repeat", "While", "Pick all (group)", "Pick by comparison / evaluate", "Pick by highest value", "Pick by lowest value", "Pick nth instance", "Pick random instance", "Pick last created", "Pick overlapping point"]:
        _pick_preset_option.add_item(preset_name)
    _pick_preset_option.item_selected.connect(_apply_pick_preset)
    form.add_child(_pick_preset_option)
    var n_row: HBoxContainer = HBoxContainer.new()
    var n_label: Label = Label.new()
    n_label.text = "Pick first N (0 = all)"
    n_label.custom_minimum_size = Vector2(130.0, 0.0)
    n_row.add_child(n_label)
    _pick_first_n_spin = SpinBox.new()
    _pick_first_n_spin.min_value = 0
    _pick_first_n_spin.max_value = 9999
    n_row.add_child(_pick_first_n_spin)
    form.add_child(n_row)
    _pick_delete_button = Button.new()
    _pick_delete_button.text = "Delete This Pick Filter"
    _pick_delete_button.pressed.connect(_on_pick_filter_deleted)
    form.add_child(_pick_delete_button)
    _pick_dialog.add_child(form)
    _pick_dialog.confirmed.connect(_on_pick_filter_confirmed)
    add_child(_pick_dialog)

func _pick_kind_to_option(kind: int) -> int:
    match kind:
        PickFilter.CollectionKind.GROUP:
            return 0
        PickFilter.CollectionKind.CHILDREN:
            return 1
        PickFilter.CollectionKind.REPEAT:
            return 3
        PickFilter.CollectionKind.WHILE:
            return 4
        _:
            return 2
func _pick_option_to_kind(option: int) -> int:
    match option:
        0:
            return PickFilter.CollectionKind.GROUP
        1:
            return PickFilter.CollectionKind.CHILDREN
        3:
            return PickFilter.CollectionKind.REPEAT
        4:
            return PickFilter.CollectionKind.WHILE
        _:
            return PickFilter.CollectionKind.EXPRESSION

## C3 presets: each fills the pick-filter fields with the matching loop/picking shape
## (everything still compiles to plain for/while loops — see _emit_pick_filters).
func _apply_pick_preset(index: int) -> void:
    match index:
        1:  # For (indexed)
            _pick_kind_option.select(3)
            _pick_iterator_edit.text = "i"
            _pick_collection_edit.text = "10"
            _pick_order_edit.text = ""
            _pick_predicate_edit.text = ""
        2:  # For Each
            _pick_kind_option.select(0)
            _pick_iterator_edit.text = "item"
            _pick_order_edit.text = ""
        3:  # For Each (ordered)
            _pick_kind_option.select(0)
            _pick_iterator_edit.text = "item"
            _pick_order_edit.text = "item.name"
        4:  # Repeat
            _pick_kind_option.select(3)
            _pick_iterator_edit.text = "_i"
            _pick_collection_edit.text = "10"
        5:  # While
            _pick_kind_option.select(4)
            _pick_collection_edit.text = "health > 0"
        6:  # Pick all (group)
            _pick_kind_option.select(0)
            _pick_predicate_edit.text = ""
            _pick_order_edit.text = ""
            _pick_first_n_spin.value = 0
        7:  # Pick by comparison / evaluate
            _pick_kind_option.select(0)
            _pick_predicate_edit.text = "item.health < 50"
        8:  # Pick by highest value
            _pick_kind_option.select(0)
            _pick_order_edit.text = "item.health"
            _pick_desc_check.button_pressed = true
            _pick_first_n_spin.value = 1
        9:  # Pick by lowest value
            _pick_kind_option.select(0)
            _pick_order_edit.text = "item.health"
            _pick_desc_check.button_pressed = false
            _pick_first_n_spin.value = 1
        10: # Pick nth instance
            _pick_kind_option.select(2)
            _pick_collection_edit.text = "[get_tree().get_nodes_in_group(\"enemies\")[0]]"
        11: # Pick random instance
            _pick_kind_option.select(2)
            _pick_collection_edit.text = "[get_tree().get_nodes_in_group(\"enemies\").pick_random()]"
        12: # Pick last created
            _pick_kind_option.select(2)
            _pick_collection_edit.text = "[get_tree().get_nodes_in_group(\"enemies\").back()]"
        13: # Pick overlapping point
            _pick_kind_option.select(0)
            _pick_predicate_edit.text = "item.global_position.distance_to(get_global_mouse_position()) < 32.0"

func _on_pick_filter_confirmed() -> void:
    if _pick_target_event == null:
        return
    var event_row: EventRow = _pick_target_event
    var target_index: int = _pick_target_index
    var iterator: String = _pick_iterator_edit.text.strip_edges()
    var kind: int = _pick_option_to_kind(_pick_kind_option.selected)
    var collection: String = _pick_collection_edit.text.strip_edges()
    var predicate: String = _pick_predicate_edit.text.strip_edges()
    var first_n: int = int(_pick_first_n_spin.value)
    var changed: bool = _perform_undoable_sheet_edit("Edit Pick Filter", func() -> bool:
        var pick: PickFilter = event_row.pick_filters[target_index] if target_index >= 0 and target_index < event_row.pick_filters.size() else PickFilter.new()
        pick.iterator_name = iterator if not iterator.is_empty() else "item"
        pick.collection_kind = kind
        pick.collection_value = collection
        pick.predicate_expression = predicate
        pick.order_by_expression = _pick_order_edit.text.strip_edges()
        pick.order_descending = _pick_desc_check.button_pressed
        pick.pick_first_n = first_n
        if target_index < 0:
            event_row.pick_filters.append(pick)
        return true
    )
    if changed:
        _refresh_after_edit()
        _mark_dirty("Pick filter saved (compiles as a for-each loop).")

func _on_pick_filter_deleted() -> void:
    if _pick_target_event == null or _pick_target_index < 0:
        _pick_dialog.hide()
        return
    var event_row: EventRow = _pick_target_event
    var target_index: int = _pick_target_index
    var changed: bool = _perform_undoable_sheet_edit("Delete Pick Filter", func() -> bool:
        if target_index < event_row.pick_filters.size():
            event_row.pick_filters.remove_at(target_index)
            return true
        return false
    )
    _pick_dialog.hide()
    if changed:
        _refresh_after_edit()
        _mark_dirty("Pick filter removed.")

# ── Comment dialog (multiline text + per-comment color) ─────────────────────
var _comment_dialog: ConfirmationDialog = null
var _comment_text_edit: TextEdit = null
var _comment_color_button: ColorPickerButton = null
var _comment_dialog_target: CommentRow = null

## Dialog editor for comments: multiline comment rows, action-cell comments, and the row
## context menu's "Edit Comment…". Single-line comment rows keep inline editing.
func _open_comment_dialog(comment_resource: Resource) -> void:
    var comment_row: CommentRow = comment_resource as CommentRow
    if comment_row == null:
        return
    _ensure_comment_dialog()
    _comment_dialog_target = comment_row
    _comment_text_edit.text = comment_row.text
    _comment_color_button.color = comment_row.custom_color
    _comment_dialog.popup_centered(Vector2i(560, 320))
    _comment_text_edit.grab_focus()

func _ensure_comment_dialog() -> void:
    if _comment_dialog != null:
        return
    _comment_dialog = ConfirmationDialog.new()
    _comment_dialog.title = "Edit Comment"
    var form: VBoxContainer = VBoxContainer.new()
    form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _comment_text_edit = TextEdit.new()
    _comment_text_edit.custom_minimum_size = Vector2(520.0, 200.0)
    _comment_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _comment_text_edit.placeholder_text = "Comment text (multiline supported)"
    form.add_child(_comment_text_edit)
    var color_row: HBoxContainer = HBoxContainer.new()
    var color_label: Label = Label.new()
    color_label.text = "Background color (alpha 0 = theme default)"
    color_row.add_child(color_label)
    _comment_color_button = ColorPickerButton.new()
    _comment_color_button.custom_minimum_size = Vector2(64.0, 0.0)
    _comment_color_button.color = Color(0, 0, 0, 0)
    color_row.add_child(_comment_color_button)
    form.add_child(color_row)
    _comment_dialog.add_child(form)
    _comment_dialog.confirmed.connect(_on_comment_dialog_confirmed)
    add_child(_comment_dialog)

func _on_comment_dialog_confirmed() -> void:
    if _comment_dialog_target == null:
        return
    var target: CommentRow = _comment_dialog_target
    var new_text: String = _comment_text_edit.text
    var new_color: Color = _comment_color_button.color
    var changed: bool = _perform_undoable_sheet_edit("Edit Comment", func() -> bool:
        target.text = new_text
        target.custom_color = new_color
        return true
    )
    if changed:
        _refresh_after_edit()
        _mark_dirty("Comment updated.")

# ── Comment ↔ action-cell conversion ─────────────────────────────────────────

## Finds the array + index holding `target` among sheet rows (recursing into groups and
## sub-events). Returns {} when not found.
func _locate_row_container(rows: Array, target: Resource) -> Dictionary:
    for index in range(rows.size()):
        var row: Variant = rows[index]
        if row == target:
            return {"container": rows, "index": index}
        if row is EventRow:
            var found: Dictionary = _locate_row_container((row as EventRow).sub_events, target)
            if not found.is_empty():
                return found
        elif row is EventGroup:
            var group_children: Array = _group_children_array(row as EventGroup)
            var found_in_group: Dictionary = _locate_row_container(group_children, target)
            if not found_in_group.is_empty():
                return found_in_group
    return {}

## Finds the EventRow whose actions contain `target` (action-cell comments/blocks).
func _locate_owning_event(rows: Array, target: Resource) -> EventRow:
    for row: Variant in rows:
        if row is EventRow:
            if (row as EventRow).actions.has(target):
                return row as EventRow
            var nested: EventRow = _locate_owning_event((row as EventRow).sub_events, target)
            if nested != null:
                return nested
        elif row is EventGroup:
            var found: EventRow = _locate_owning_event(_group_children_array(row as EventGroup), target)
            if found != null:
                return found
    return null

## Comment row → action-cell comment of the nearest EventRow ABOVE it (C3's "comment in
## the actions"). The reverse of _detach_comment_to_row.
func _attach_comment_to_event_above(comment_row: CommentRow) -> void:
    if _current_sheet == null or comment_row == null:
        return
    var location: Dictionary = _locate_row_container(_current_sheet.events, comment_row)
    if location.is_empty():
        _set_status("Comment not found in the sheet.", true)
        return
    var container: Array = location.get("container")
    var target_event: EventRow = null
    for index in range(int(location.get("index")) - 1, -1, -1):
        if container[index] is EventRow:
            target_event = container[index] as EventRow
            break
    if target_event == null:
        _set_status("No event above this comment to attach to.", true)
        return
    var changed: bool = _perform_undoable_sheet_edit("Attach Comment To Event", func() -> bool:
        container.erase(comment_row)
        target_event.actions.append(comment_row)
        return true
    )
    if changed:
        _refresh_after_edit()
        _mark_dirty("Comment attached to the event above (action note).")

## Action-cell comment → standalone comment row directly below its event.
func _detach_comment_to_row(comment_row: CommentRow) -> void:
    if _current_sheet == null or comment_row == null:
        return
    var owner_event: EventRow = _locate_owning_event(_current_sheet.events, comment_row)
    if owner_event == null:
        _set_status("This comment is not inside an event.", true)
        return
    var owner_location: Dictionary = _locate_row_container(_current_sheet.events, owner_event)
    if owner_location.is_empty():
        _set_status("Owning event not found in the sheet.", true)
        return
    var changed: bool = _perform_undoable_sheet_edit("Detach Comment", func() -> bool:
        owner_event.actions.erase(comment_row)
        var container: Array = owner_location.get("container")
        container.insert(int(owner_location.get("index")) + 1, comment_row)
        return true
    )
    if changed:
        _refresh_after_edit()
        _mark_dirty("Comment detached to its own row.")

# ── Sheet Type dialog (Event Sheet / Custom Node / Behavior) ────────────────
# Discoverable alternative to the Inspector fields: matches C3's "Add behavior" mental
# model while writing the same sheet properties Godot users see in the Inspector.
var _sheet_type_dialog: ConfirmationDialog = null
var _sheet_type_option: OptionButton = null
var _sheet_type_name_edit: LineEdit = null
var _sheet_type_icon_edit: LineEdit = null
var _sheet_type_host_edit: LineEdit = null
var _sheet_type_tool_check: CheckBox = null
var _sheet_type_tags_edit: LineEdit = null
var _sheet_type_includes_edit: LineEdit = null
var _sheet_type_uses_edit: LineEdit = null
var _sheet_type_requires_edit: LineEdit = null
var _sheet_type_autoload_edit: LineEdit = null

func _open_sheet_type_dialog() -> void:
    if not _ensure_sheet_for_editing():
        return
    _ensure_sheet_type_dialog()
    if _current_sheet.tool_mode and _current_sheet.host_class == "EditorScript":
        _sheet_type_option.select(3)
    elif _current_sheet.behavior_mode:
        _sheet_type_option.select(2)
    elif not _current_sheet.custom_class_name.strip_edges().is_empty():
        _sheet_type_option.select(1)
    else:
        _sheet_type_option.select(0)
    _sheet_type_name_edit.text = _current_sheet.custom_class_name
    _sheet_type_icon_edit.text = _current_sheet.custom_class_icon
    _sheet_type_host_edit.text = _current_sheet.host_class
    _sheet_type_tool_check.button_pressed = _current_sheet.tool_mode
    _sheet_type_tags_edit.text = ", ".join(_current_sheet.addon_tags)
    _sheet_type_includes_edit.text = ", ".join(PackedStringArray(_current_sheet.includes))
    _sheet_type_uses_edit.text = ", ".join(PackedStringArray(_current_sheet.uses_addons))
    _sheet_type_requires_edit.text = ", ".join(PackedStringArray(_current_sheet.requires_behaviors))
    _sheet_type_autoload_edit.text = _current_sheet.autoload_name
    _sheet_type_dialog.popup_centered(Vector2i(460, 300))

func _ensure_sheet_type_dialog() -> void:
    if _sheet_type_dialog != null:
        return
    _sheet_type_dialog = ConfirmationDialog.new()
    _sheet_type_dialog.title = "Sheet Type"
    var form: VBoxContainer = VBoxContainer.new()
    form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _sheet_type_option = OptionButton.new()
    _sheet_type_option.add_item("Event Sheet")           # plain: compiles onto the host node
    _sheet_type_option.add_item("Custom Node")           # class_name + @icon → Create Node dialog
    _sheet_type_option.add_item("Behavior (acts on parent)")  # Node component with `host`
    _sheet_type_option.add_item("Editor Tool (EditorScript)")  # EXPERIMENTAL: events -> editor tooling
    _sheet_type_option.add_item("Autoload (Singleton)")  # extends Node; registered project-wide
    form.add_child(_sheet_type_option)
    _sheet_type_name_edit = _add_sheet_type_field(form, "Class name", "PatrolBehavior")
    _sheet_type_icon_edit = _add_sheet_type_field(form, "Icon (res://…)", "res://icons/patrol.svg")
    _sheet_type_host_edit = _add_sheet_type_field(form, "Host / base class", "CharacterBody2D")
    _sheet_type_tool_check = CheckBox.new()
    _sheet_type_tool_check.text = "@tool — runs inside the editor (EXPERIMENTAL, editor-version-coupled)"
    form.add_child(_sheet_type_tool_check)
    _sheet_type_tags_edit = _add_sheet_type_field(form, "Tags (comma-separated)", "movement, retro, jam")
    _sheet_type_includes_edit = _add_sheet_type_field(form, "Includes (addon sheets)", "res://eventsheet_addons/screen_shake/screen_shake.tres, …")
    _sheet_type_uses_edit = _add_sheet_type_field(form, "Uses (addon classes)", "ScreenShake, MathHelpers — owned helper instances")
    _sheet_type_requires_edit = _add_sheet_type_field(form, "Requires (sibling behaviors)", "ScreenShake — shows the warning badge when the sibling is missing")
    _sheet_type_autoload_edit = _add_sheet_type_field(form, "Autoload name (singleton)", "GameState — global identifier every sheet can call")
    var hint: Label = Label.new()
    hint.text = "Custom nodes appear in Godot's Create Node dialog with their icon.\nBehaviors attach as child nodes and act on their parent via the typed `host` accessor."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    form.add_child(hint)
    _sheet_type_dialog.add_child(form)
    _sheet_type_dialog.confirmed.connect(_on_sheet_type_confirmed)
    add_child(_sheet_type_dialog)

func _add_sheet_type_field(form: VBoxContainer, label_text: String, placeholder: String) -> LineEdit:
    var row: HBoxContainer = HBoxContainer.new()
    var label: Label = Label.new()
    label.text = label_text
    label.custom_minimum_size = Vector2(130.0, 0.0)
    row.add_child(label)
    var edit: LineEdit = LineEdit.new()
    edit.placeholder_text = placeholder
    edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(edit)
    form.add_child(row)
    return edit

func _on_sheet_type_confirmed() -> void:
    _apply_sheet_type_settings(
        _sheet_type_option.selected,
        _sheet_type_name_edit.text,
        _sheet_type_icon_edit.text,
        _sheet_type_host_edit.text,
        _sheet_type_tool_check.button_pressed,
        VariableDialog.parse_options(_sheet_type_tags_edit.text)
    ,
        VariableDialog.parse_options(_sheet_type_includes_edit.text),
        VariableDialog.parse_options(_sheet_type_uses_edit.text),
        VariableDialog.parse_options(_sheet_type_requires_edit.text),
        _sheet_type_autoload_edit.text
    )

## Applies the chosen sheet type (0 = plain, 1 = custom node, 2 = behavior) undoably and
## refreshes every identity surface (banner, tab badge, header, lint context).
func _apply_sheet_type_settings(type_index: int, class_name_text: String, icon_path: String, host_class_text: String, tool_enabled: bool = false, addon_tags: PackedStringArray = PackedStringArray(), include_paths: PackedStringArray = PackedStringArray(), uses_classes: PackedStringArray = PackedStringArray(), requires_classes: PackedStringArray = PackedStringArray(), autoload_name_text: String = "") -> void:
    if _current_sheet == null:
        return
    var changed: bool = _perform_undoable_sheet_edit("Set Sheet Type", func() -> bool:
        _current_sheet.behavior_mode = type_index == 2
        # Autoload (Singleton) sheets: extends Node, addressed project-wide by name.
        _current_sheet.autoload_mode = type_index == 4
        _current_sheet.autoload_name = autoload_name_text.strip_edges() if type_index == 4 else ""
        if type_index == 4:
            _current_sheet.host_class = "Node"
        # Editor Tool preset: an EditorScript with @tool — pair with On Editor Run.
        _current_sheet.tool_mode = tool_enabled or type_index == 3
        _current_sheet.custom_class_name = class_name_text.strip_edges() if type_index != 0 else ""
        _current_sheet.custom_class_icon = icon_path.strip_edges() if type_index != 0 else ""
        # Plain sheets aren't addons: clear tags like the class name/icon (otherwise a
        # type switch would leave stale tags that never emit — silent confusion).
        _current_sheet.addon_tags = addon_tags if type_index != 0 else PackedStringArray()
        # Lane A composition (meta-packs): includes apply like tags; plain sheets keep
        # their includes too (library sheets predate addon composition).
        var applied_includes: Array[String] = []
        for include_path: String in include_paths:
            if not include_path.strip_edges().is_empty():
                applied_includes.append(include_path.strip_edges())
        _current_sheet.includes = applied_includes
        var applied_uses: Array[String] = []
        for uses_class: String in uses_classes:
            if not uses_class.strip_edges().is_empty():
                applied_uses.append(uses_class.strip_edges())
        _current_sheet.uses_addons = applied_uses
        var applied_requires: Array[String] = []
        for requires_class: String in requires_classes:
            if not requires_class.strip_edges().is_empty():
                applied_requires.append(requires_class.strip_edges())
        _current_sheet.requires_behaviors = applied_requires
        if type_index == 3:
            _current_sheet.host_class = "EditorScript"
        elif not host_class_text.strip_edges().is_empty():
            _current_sheet.host_class = host_class_text.strip_edges()
        return true
    )
    if changed:
        _refresh_after_edit()
        _refresh_title_strip()
        _refresh_tab_bar()
        _mark_dirty("Sheet type updated.")

## Footer "Add event…" rows: opens the event picker; the new event is appended into the
## clicked footer's owner (a group, or the sheet end).
func _on_viewport_add_event_requested(owner_resource: Resource) -> void:
    if not _ensure_sheet_for_editing():
        return
    _ace_picker.open(
        "new_condition_event",
        false,
        null,
        {"mode": "new_condition_event", "insert_into": owner_resource}
    )

## Persists a lane-divider resize. A default-themed sheet is promoted to a concrete editor
## style so the ratio saves with the sheet; an already-styled sheet is edited in place.
func _on_viewport_lane_ratio_changed(ratio: float) -> void:
    if _current_sheet == null:
        return
    if _current_sheet.editor_style == null:
        var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
        style.ensure_defaults()
        style.get_event_style().condition_lane_ratio = ratio
        _current_sheet.editor_style = style
        _viewport.apply_editor_style(style)
    else:
        _current_sheet.editor_style.get_event_style().condition_lane_ratio = ratio
    _mark_dirty("Resized conditions/actions lane to %d%%." % int(round(ratio * 100.0)))

func _on_viewport_context_menu_requested(row_data: EventRowData, hit: Dictionary, global_position: Vector2) -> void:
    _context_row = row_data
    _context_hit = hit.duplicate(true)
    _context_variable = {}
    if row_data == null:
        return
    var metadata: Dictionary = hit.get("span_metadata", {})
    if str(metadata.get("kind", "")) == "variable":
        _context_variable = _context_variable_entry_from_metadata(row_data, metadata)
        if not _context_variable.is_empty():
            _show_popup_menu(_variable_context_menu, global_position)
            return
    var kind: String = str(metadata.get("kind", ""))
    if kind in ["condition", "trigger"]:
        _show_popup_menu(_condition_context_menu, global_position)
        return
    if kind == "action":
        _show_popup_menu(_action_context_menu, global_position)
        return
    _show_popup_menu(_row_context_menu, global_position)

func _on_viewport_empty_space_double_clicked() -> void:
    if not _ensure_sheet_for_editing():
        return
    var created: bool = _perform_undoable_sheet_edit("Add Event", func() -> bool:
        _current_sheet.events.append(EventRow.new())
        return true
    )
    if created:
        _mark_dirty("Added event.")

func _on_viewport_empty_space_context_menu_requested(global_position: Vector2) -> void:
    _context_row = null
    _context_hit = {}
    _context_variable = {}
    _show_popup_menu(_empty_space_context_menu, global_position)

func _on_empty_space_context_menu_id_pressed(id: int) -> void:
    match id:
        EMPTY_MENU_NEW_EVENT:
            _on_viewport_empty_space_double_clicked()
        EMPTY_MENU_NEW_CONDITION:
            if _viewport != null:
                _viewport.clear_selection()
            _on_add_condition_requested()
        EMPTY_MENU_ADD_VARIABLE:
            _on_add_global_variable_requested()

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
        var condition_toggle_index: int = menu.get_item_index(CONDITION_MENU_TOGGLE_ENABLED)
        if condition_toggle_index >= 0:
            menu.set_item_text(
                condition_toggle_index,
                "Enable Condition" if _context_ace_is_disabled() else "Disable Condition"
            )
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
        var sub_condition_index: int = menu.get_item_index(ROW_MENU_ADD_SUB_CONDITION)
        if sub_condition_index >= 0:
            var context_event: EventRow = _context_row.source_resource as EventRow if _context_row != null else null
            menu.set_item_disabled(sub_condition_index, context_event == null)
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
        var row_toggle_index: int = menu.get_item_index(ROW_MENU_TOGGLE_ENABLED)
        if row_toggle_index >= 0:
            menu.set_item_text(
                row_toggle_index,
                "Enable Row" if _context_row_is_disabled() else "Disable Row"
            )
    elif menu == _variable_context_menu:
        var has_variable: bool = not _context_variable.is_empty()
        var convert_index: int = menu.get_item_index(VARIABLE_MENU_CONVERT_SCOPE)
        if convert_index >= 0:
            menu.set_item_disabled(convert_index, not has_variable)
            if has_variable:
                var scope_label: String = str(_context_variable.get("scope", "global"))
                menu.set_item_text(
                    convert_index,
                    "Convert to Global" if scope_label == "local" else "Convert to Local"
                )
        var const_index: int = menu.get_item_index(VARIABLE_MENU_TOGGLE_CONST)
        if const_index >= 0:
            var supports_const: bool = has_variable and bool(_context_variable.get("supports_const", false))
            menu.set_item_disabled(const_index, not supports_const)
            if has_variable:
                var is_constant: bool = bool(_context_variable.get("is_constant", false))
                menu.set_item_text(
                    const_index,
                    "Unset Constant" if is_constant else "Set Constant"
                )
    elif menu == _action_context_menu:
        var action_toggle_index: int = menu.get_item_index(ACTION_MENU_TOGGLE_ENABLED)
        if action_toggle_index >= 0:
            menu.set_item_text(
                action_toggle_index,
                "Enable Action" if _context_ace_is_disabled() else "Disable Action"
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
        CONDITION_MENU_EDIT_ACE_COMMENT:
            _open_ace_comment_dialog(_context_ace_resource("condition"))
        CONDITION_MENU_TOGGLE_ENABLED:
            _toggle_context_ace_enabled()
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
        ACTION_MENU_EDIT_ACE_COMMENT:
            _open_ace_comment_dialog(_context_ace_resource("action"))
        ACTION_MENU_TOGGLE_ENABLED:
            _toggle_context_ace_enabled()
        ACTION_MENU_DETACH_COMMENT:
            var detach_index: int = int(_context_hit.get("ace_index", -1))
            var context_event: EventRow = _context_row.source_resource as EventRow
            if context_event != null and detach_index >= 0 and detach_index < context_event.actions.size() and context_event.actions[detach_index] is CommentRow:
                _detach_comment_to_row(context_event.actions[detach_index] as CommentRow)
            else:
                _set_status("Right-click an action-cell comment to detach it.", true)
        ACTION_MENU_DELETE:
            _delete_context_ace()

func _on_row_context_menu_id_pressed(id: int) -> void:
    if _context_row == null:
        return
    match id:
        ROW_MENU_ADD_SUB_EVENT:
            _insert_child_event_for_context_row()
        ROW_MENU_ADD_COMMENT_SUB_EVENT:
            _insert_child_comment_for_context_row()
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
        ROW_MENU_ADD_VARIABLE_BELOW:
            _add_tree_variable_below_context_row()
        ROW_MENU_ADD_GDSCRIPT_BELOW:
            var raw_block: RawCodeRow = RawCodeRow.new()
            raw_block.code = "# GDScript — emitted verbatim at class level"
            _insert_context_row_below(raw_block, "Added GDScript block.")
        ROW_MENU_ADD_GDSCRIPT_ACTION:
            _add_gdscript_action_to_context_row()
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
        ROW_MENU_ADD_SUB_CONDITION:
            _open_sub_condition_picker_for_context_row()
        ROW_MENU_TOGGLE_ENABLED:
            _toggle_context_row_enabled()
        ROW_MENU_EDIT_COMMENT:
            if _context_row.source_resource is CommentRow:
                _open_comment_dialog(_context_row.source_resource)
            else:
                _set_status("Select a comment row to edit it.", true)
        ROW_MENU_ATTACH_COMMENT:
            if _context_row.source_resource is CommentRow:
                _attach_comment_to_event_above(_context_row.source_resource as CommentRow)
            else:
                _set_status("Only comment rows can attach to an event.", true)
        ROW_MENU_ADD_PICK_FILTER:
            _open_pick_filter_dialog(_context_row.source_resource, -1)
        ROW_MENU_ADD_ENUM:
            var new_enum: EnumRow = EnumRow.new()
            _insert_context_row_below(new_enum, "Added enum.")
            _open_enum_dialog(new_enum)
        ROW_MENU_OPEN_IN_SPLIT:
            _open_row_in_split(_context_row)
        ROW_MENU_ADD_SIGNAL:
            var new_signal: SignalRow = SignalRow.new()
            _insert_context_row_below(new_signal, "Added signal.")
            _open_signal_dialog(new_signal)
        ROW_MENU_ADD_MATCH:
            if _context_row.source_resource is EventRow:
                var new_match: MatchRow = MatchRow.new()
                var match_host: EventRow = _context_row.source_resource as EventRow
                var added_match: bool = _perform_undoable_sheet_edit("Add Match", func() -> bool:
                    match_host.actions.append(new_match)
                    return true
                )
                if added_match:
                    _refresh_after_edit()
                    _open_match_dialog(new_match)
            else:
                _set_status("Select an event to add a match to its actions.", true)
        ROW_MENU_FIND_USAGES:
            var usage_target: Resource = _context_row.source_resource if _context_row != null else null
            var usage_query: String = ""
            if usage_target is LocalVariable:
                usage_query = (usage_target as LocalVariable).name
            elif usage_target is EventGroup:
                usage_query = (usage_target as EventGroup).group_name
            elif _context_row != null and not _context_row.spans.is_empty():
                usage_query = str(_context_row.spans[0].text).get_slice(":", 0).strip_edges()
            if usage_query.is_empty():
                _set_status("Nothing identifiable to search for on this row.", true)
            else:
                _open_project_find(usage_query)
        ROW_MENU_GROUP_RUNTIME:
            _toggle_group_runtime()
        ROW_MENU_GROUP_COLOR:
            _open_group_color_picker()
        ROW_MENU_EDIT_GROUP_DESC:
            if _context_row.source_resource is EventGroup:
                var described_group: EventGroup = _context_row.source_resource as EventGroup
                if described_group.description.strip_edges().is_empty():
                    var seeded: bool = _perform_undoable_sheet_edit("Add Group Description", func() -> bool:
                        described_group.description = "Description"
                        return true
                    )
                    if seeded:
                        _refresh_after_edit()
                _set_status("Double-click the description line (or slow-double-click) to edit it.")
            else:
                _set_status("Select a group to edit its description.", true)

func _on_variable_context_menu_id_pressed(id: int) -> void:
    if _context_variable.is_empty():
        return
    match id:
        VARIABLE_MENU_EDIT:
            _edit_context_variable()
        VARIABLE_MENU_CONVERT_SCOPE:
            _convert_context_variable_scope()
        VARIABLE_MENU_TOGGLE_CONST:
            _toggle_context_variable_constant()

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

## The ACE resource the context menu was opened on (condition/trigger/action lanes).
func _context_ace_resource(lane: String) -> Resource:
    if _context_row == null or not (_context_row.source_resource is EventRow):
        return null
    var event_row: EventRow = _context_row.source_resource as EventRow
    var metadata: Dictionary = _context_hit.get("span_metadata", {})
    var ace_index: int = int(metadata.get("ace_index", -1))
    if lane == "condition":
        if str(metadata.get("kind", "")) == "trigger":
            return event_row.trigger
        return event_row.conditions[ace_index] if ace_index >= 0 and ace_index < event_row.conditions.size() else null
    return event_row.actions[ace_index] if ace_index >= 0 and ace_index < event_row.actions.size() else null

# ── Per-ACE comments (C3 condition/action notes) ──────────────────────────────────────
var _ace_comment_dialog: ConfirmationDialog = null
var _ace_comment_edit: LineEdit = null
var _ace_comment_target: Resource = null

## C3-style per-condition/action note: shown dimmed after the ACE text in the sheet.
func _open_ace_comment_dialog(target: Resource) -> void:
    if target == null:
        _set_status("Right-click a condition or action to comment it.", true)
        return
    if _ace_comment_dialog == null:
        _ace_comment_dialog = ConfirmationDialog.new()
        _ace_comment_dialog.title = "ACE Comment"
        _ace_comment_edit = LineEdit.new()
        _ace_comment_edit.placeholder_text = "Why this condition/action exists…"
        _ace_comment_edit.custom_minimum_size = Vector2(360.0, 0.0)
        _ace_comment_dialog.add_child(_ace_comment_edit)
        _ace_comment_dialog.confirmed.connect(_on_ace_comment_confirmed)
        add_child(_ace_comment_dialog)
    _ace_comment_target = target
    _ace_comment_edit.text = str(target.get("comment"))
    _ace_comment_dialog.popup_centered(Vector2i(420, 110))

func _on_ace_comment_confirmed() -> void:
    if _ace_comment_target == null:
        return
    var target: Resource = _ace_comment_target
    var new_comment: String = _ace_comment_edit.text.strip_edges()
    var changed: bool = _perform_undoable_sheet_edit("Edit ACE Comment", func() -> bool:
        target.set("comment", new_comment)
        return true
    )
    if changed:
        _refresh_after_edit()
        _mark_dirty("ACE comment saved.")

# ── Starter templates (C3 "new from template") ─────────────────────────────────────────
var _template_menu: PopupMenu = null

func _open_template_menu() -> void:
    _build_template_menu_items()
    _template_menu.popup(Rect2i(Vector2i(get_global_mouse_position()), Vector2i(0, 0)))

## Rebuilt on every open so project templates (res://eventsheet_templates/, ids 100+)
## appear the moment a .tres lands in the folder — same zero-config convention as
## eventsheet_addons/.
var _project_template_paths: PackedStringArray = PackedStringArray()

func _build_template_menu_items() -> void:
    if _template_menu == null:
        _template_menu = PopupMenu.new()
        _template_menu.id_pressed.connect(_new_sheet_from_template)
        add_child(_template_menu)
    _template_menu.clear()
    _template_menu.add_item("Blank Sheet", 0)
    _template_menu.add_item("Platformer Starter", 1)
    _template_menu.add_item("Top-down Starter", 2)
    _template_menu.add_item("Game State (Autoload)", 3)
    _template_menu.add_item("Event Bus (Autoload)", 4)
    _template_menu.add_item("Save System (Autoload)", 5)
    _project_template_paths = EventSheetTemplates.list_templates()
    if not _project_template_paths.is_empty():
        _template_menu.add_separator("Project templates")
        for index in _project_template_paths.size():
            _template_menu.add_item(_project_template_paths[index].get_file().get_basename().capitalize(), 100 + index)

## Builds a fresh sheet from a starter template and adopts it (unsaved; Save As to keep).
func _new_sheet_from_template(template_id: int) -> void:
    if template_id >= 100:
        var template_index: int = template_id - 100
        if template_index >= _project_template_paths.size():
            return
        var template_copy: EventSheetResource = EventSheetTemplates.load_copy(_project_template_paths[template_index])
        if template_copy == null:
            _set_status("Couldn't load that template.", true)
            return
        setup(template_copy)
        _current_sheet_path = ""
        _dirty = true
        _refresh_title_strip()
        _clear_undo_history()
        _set_status("New sheet from project template — Save As… to keep it.")
        return
    var sheet: EventSheetResource = EventSheetResource.new()
    match template_id:
        1:
            sheet.host_class = "CharacterBody2D"
            var note: CommentRow = CommentRow.new()
            note.text = "[b]Platformer Starter[/b] — move with ui_left/ui_right, jump with ui_accept.\nTune the numbers, then Compile and attach the script."
            sheet.events.append(note)
            var tick: EventRow = EventRow.new()
            tick.trigger_provider_id = "Core"
            tick.trigger_id = "OnPhysicsProcess"
            var move: RawCodeRow = RawCodeRow.new()
            move.code = "velocity.x = Input.get_axis(&\"ui_left\", &\"ui_right\") * 220.0\nif not is_on_floor():\n\tvelocity.y += 980.0 * delta\nmove_and_slide()"
            tick.actions.append(move)
            sheet.events.append(tick)
            var jump: EventRow = EventRow.new()
            jump.trigger_provider_id = "Core"
            jump.trigger_id = "OnPhysicsProcess"
            var grounded: ACECondition = ACECondition.new()
            grounded.provider_id = "Core"
            grounded.ace_id = "IsOnFloor"
            grounded.codegen_template = "is_on_floor()"
            jump.conditions.append(grounded)
            var pressed: ACECondition = ACECondition.new()
            pressed.provider_id = "Core"
            pressed.ace_id = "IsActionJustPressed"
            pressed.codegen_template = "Input.is_action_just_pressed(&{action})"
            pressed.params = {"action": "\"ui_accept\""}
            jump.conditions.append(pressed)
            var leap: ACEAction = ACEAction.new()
            leap.provider_id = "Core"
            leap.ace_id = "SetVelocity2D"
            leap.codegen_template = "velocity.y = {vel}"
            leap.params = {"vel": "-420.0"}
            jump.actions.append(leap)
            sheet.events.append(jump)
        2:
            sheet.host_class = "CharacterBody2D"
            var note2: CommentRow = CommentRow.new()
            note2.text = "[b]Top-down Starter[/b] — 8-way movement with the arrow keys."
            sheet.events.append(note2)
            var tick2: EventRow = EventRow.new()
            tick2.trigger_provider_id = "Core"
            tick2.trigger_id = "OnPhysicsProcess"
            var move2: RawCodeRow = RawCodeRow.new()
            move2.code = "velocity = Input.get_vector(&\"ui_left\", &\"ui_right\", &\"ui_up\", &\"ui_down\") * 200.0\nmove_and_slide()"
            tick2.actions.append(move2)
            sheet.events.append(tick2)
        3:
            sheet.autoload_mode = true
            sheet.autoload_name = "GameState"
            sheet.host_class = "Node"
            sheet.variables = {
                "score": {"type": "int", "default": 0, "exported": true, "attributes": {"tooltip": "Current score."}},
                "lives": {"type": "int", "default": 3, "exported": true, "attributes": {"range": {"min": "0", "max": "99", "step": "1"}}}
            }
            var score_signal: RawCodeRow = RawCodeRow.new()
            score_signal.code = "## @ace_trigger\n## @ace_name(\"On Score Changed\")\n## @ace_category(\"Game State\")\nsignal score_changed(new_score: int)"
            sheet.events.append(score_signal)
            var add_score: EventFunction = EventFunction.new()
            add_score.function_name = "add_score"
            add_score.expose_as_ace = true
            add_score.ace_display_name = "Add Score"
            add_score.ace_category = "Game State"
            var amount_param: ACEParam = ACEParam.new()
            amount_param.id = "amount"
            amount_param.type_name = "int"
            add_score.params.append(amount_param)
            var add_body: RawCodeRow = RawCodeRow.new()
            add_body.code = "score += amount\nscore_changed.emit(score)"
            add_score.events.append(add_body)
            sheet.functions.append(add_score)
        4:
            sheet.autoload_mode = true
            sheet.autoload_name = "EventBus"
            sheet.host_class = "Node"
            var bus_note: CommentRow = CommentRow.new()
            bus_note.text = "[b]Event Bus[/b] — declare project-wide signals here; emit them from any sheet via EventBus.<signal>.emit(...)."
            sheet.events.append(bus_note)
            var bus_signals: RawCodeRow = RawCodeRow.new()
            bus_signals.code = "## @ace_trigger\n## @ace_name(\"On Game Paused\")\n## @ace_category(\"Event Bus\")\nsignal game_paused\n\n## @ace_trigger\n## @ace_name(\"On Level Completed\")\n## @ace_category(\"Event Bus\")\nsignal level_completed(level: int)"
            sheet.events.append(bus_signals)
        5:
            sheet.autoload_mode = true
            sheet.autoload_name = "SaveSystem"
            sheet.host_class = "Node"
            sheet.variables = {"save_path": {"type": "String", "default": "user://save.cfg", "exported": true, "attributes": {"tooltip": "Where the save file lives."}}}
            var save_fn: EventFunction = EventFunction.new()
            save_fn.function_name = "save_number"
            save_fn.expose_as_ace = true
            save_fn.ace_display_name = "Save Number"
            save_fn.ace_category = "Save System"
            for save_param_pair in [["key", "String"], ["value", "float"]]:
                var save_param: ACEParam = ACEParam.new()
                save_param.id = str(save_param_pair[0])
                save_param.type_name = str(save_param_pair[1])
                save_fn.params.append(save_param)
            var save_body: RawCodeRow = RawCodeRow.new()
            save_body.code = "var config: ConfigFile = ConfigFile.new()\nconfig.load(save_path)\nconfig.set_value(\"save\", key, value)\nconfig.save(save_path)"
            save_fn.events.append(save_body)
            sheet.functions.append(save_fn)
            var load_fn: EventFunction = EventFunction.new()
            load_fn.function_name = "load_number"
            load_fn.expose_as_ace = true
            load_fn.ace_display_name = "Load Number"
            load_fn.ace_category = "Save System"
            load_fn.return_type = TYPE_FLOAT
            var load_param: ACEParam = ACEParam.new()
            load_param.id = "key"
            load_param.type_name = "String"
            load_fn.params.append(load_param)
            var load_body: RawCodeRow = RawCodeRow.new()
            load_body.code = "var config: ConfigFile = ConfigFile.new()\nconfig.load(save_path)\nreturn float(config.get_value(\"save\", key, 0.0))"
            load_fn.events.append(load_body)
            sheet.functions.append(load_fn)
    setup(sheet)
    _current_sheet_path = ""
    _dirty = true
    _refresh_title_strip()
    _clear_undo_history()
    _set_status("New sheet from template — Save As… to keep it.")

func _context_ace_is_disabled() -> bool:
    if _context_row == null or not (_context_row.source_resource is EventRow):
        return false
    var event_row: EventRow = _context_row.source_resource as EventRow
    var metadata: Dictionary = _context_hit.get("span_metadata", {})
    var kind: String = str(metadata.get("kind", ""))
    var ace_index: int = int(metadata.get("ace_index", -1))
    match kind:
        "trigger":
            return event_row.trigger != null and not event_row.trigger.enabled
        "condition":
            return ace_index >= 0 and ace_index < event_row.conditions.size() and not event_row.conditions[ace_index].enabled
        "action":
            return ace_index >= 0 and ace_index < event_row.actions.size() and event_row.actions[ace_index] is ACEAction and not ((event_row.actions[ace_index] as ACEAction).enabled)
    return false

func _toggle_context_ace_enabled() -> void:
    if _context_row == null or not (_context_row.source_resource is EventRow):
        return
    var event_row: EventRow = _context_row.source_resource as EventRow
    var metadata: Dictionary = _context_hit.get("span_metadata", {})
    var kind: String = str(metadata.get("kind", ""))
    var ace_index: int = int(metadata.get("ace_index", -1))
    var changed: bool = _perform_undoable_sheet_edit("Toggle ACE Enabled", func() -> bool:
        match kind:
            "trigger":
                if event_row.trigger != null:
                    event_row.trigger.enabled = not event_row.trigger.enabled
                    return true
            "condition":
                if ace_index >= 0 and ace_index < event_row.conditions.size():
                    event_row.conditions[ace_index].enabled = not event_row.conditions[ace_index].enabled
                    return true
            "action":
                if ace_index >= 0 and ace_index < event_row.actions.size() and event_row.actions[ace_index] is ACEAction:
                    var target_action: ACEAction = event_row.actions[ace_index] as ACEAction
                    target_action.enabled = not target_action.enabled
                    return true
        return false
    )
    if changed:
        _mark_dirty("Updated ACE enabled state.")

## Disables (or re-enables) everything currently selected at once: individual conditions /
## actions when ACE spans are selected, otherwise the selected rows (events/groups/comments).
## If anything in the selection is enabled it disables the whole lot; otherwise it enables it.
func _toggle_selected_enabled() -> void:
    if _viewport == null:
        return
    var span_targets: Array = _active_view().get_selected_span_targets()
    var row_targets: Array[EventRowData] = []
    if span_targets.is_empty():
        row_targets = _get_selected_rows_from_context()
    if span_targets.is_empty() and row_targets.is_empty():
        return
    var any_enabled: bool = false
    for target in span_targets:
        if _ace_target_enabled(target):
            any_enabled = true
            break
    if not any_enabled:
        for row_data in row_targets:
            if _row_data_resource_enabled(row_data):
                any_enabled = true
                break
    var new_enabled: bool = not any_enabled
    var changed: bool = _perform_undoable_sheet_edit("Toggle Enabled", func() -> bool:
        var did_change: bool = false
        for target in span_targets:
            if _set_ace_target_enabled(target, new_enabled):
                did_change = true
        for row_data in row_targets:
            if _set_row_data_resource_enabled(row_data, new_enabled):
                did_change = true
        return did_change
    )
    if changed:
        _mark_dirty("%s selection." % ("Enabled" if new_enabled else "Disabled"))

func _ace_target_enabled(target: Dictionary) -> bool:
    var event_row: EventRow = target.get("source_resource", null) as EventRow
    if event_row == null:
        return true
    var ace_index: int = int(target.get("ace_index", -1))
    match str(target.get("kind", "")):
        "trigger":
            return event_row.trigger == null or event_row.trigger.enabled
        "condition":
            return ace_index < 0 or ace_index >= event_row.conditions.size() or event_row.conditions[ace_index].enabled
        "action":
            return ace_index < 0 or ace_index >= event_row.actions.size() or not (event_row.actions[ace_index] is ACEAction) or (event_row.actions[ace_index] as ACEAction).enabled
    return true

func _set_ace_target_enabled(target: Dictionary, enabled: bool) -> bool:
    var event_row: EventRow = target.get("source_resource", null) as EventRow
    if event_row == null:
        return false
    var ace_index: int = int(target.get("ace_index", -1))
    match str(target.get("kind", "")):
        "trigger":
            if event_row.trigger != null:
                event_row.trigger.enabled = enabled
                return true
        "condition":
            if ace_index >= 0 and ace_index < event_row.conditions.size():
                event_row.conditions[ace_index].enabled = enabled
                return true
        "action":
            if ace_index >= 0 and ace_index < event_row.actions.size() and event_row.actions[ace_index] is ACEAction:
                (event_row.actions[ace_index] as ACEAction).enabled = enabled
                return true
    return false

func _row_data_resource_enabled(row_data: EventRowData) -> bool:
    if row_data == null or row_data.source_resource == null:
        return true
    var resource: Resource = row_data.source_resource
    if resource is EventRow:
        return (resource as EventRow).enabled
    if resource is EventGroup:
        return (resource as EventGroup).enabled
    if resource is CommentRow:
        return (resource as CommentRow).enabled
    return true

func _set_row_data_resource_enabled(row_data: EventRowData, enabled: bool) -> bool:
    if row_data == null or row_data.source_resource == null:
        return false
    var resource: Resource = row_data.source_resource
    if resource is EventRow:
        (resource as EventRow).enabled = enabled
        return true
    if resource is EventGroup:
        (resource as EventGroup).enabled = enabled
        return true
    if resource is CommentRow:
        (resource as CommentRow).enabled = enabled
        return true
    return false

func _context_row_is_disabled() -> bool:
    if _context_row == null or _context_row.source_resource == null:
        return false
    if _context_row.source_resource is EventRow:
        return not (_context_row.source_resource as EventRow).enabled
    if _context_row.source_resource is EventGroup:
        return not (_context_row.source_resource as EventGroup).enabled
    if _context_row.source_resource is CommentRow:
        return not (_context_row.source_resource as CommentRow).enabled
    return false

func _toggle_context_row_enabled() -> void:
    if _context_row == null or _context_row.source_resource == null:
        return
    var changed: bool = _perform_undoable_sheet_edit("Toggle Row Enabled", func() -> bool:
        if _context_row.source_resource is EventRow:
            var event_row: EventRow = _context_row.source_resource as EventRow
            event_row.enabled = not event_row.enabled
            return true
        if _context_row.source_resource is EventGroup:
            var group: EventGroup = _context_row.source_resource as EventGroup
            group.enabled = not group.enabled
            return true
        if _context_row.source_resource is CommentRow:
            var comment_row: CommentRow = _context_row.source_resource as CommentRow
            comment_row.enabled = not comment_row.enabled
            return true
        return false
    )
    if changed:
        _mark_dirty("Updated row enabled state.")

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

func _delete_selected_content() -> void:
    if _delete_selected_spans():
        return
    _delete_selected_rows()

func _delete_selected_spans() -> bool:
    if _viewport == null:
        return false
    var selected_targets: Array = _active_view().get_selected_span_targets()
    if selected_targets.is_empty():
        return false
    var deleted: bool = _perform_undoable_sheet_edit("Delete ACE", func() -> bool:
        var targets_by_row: Dictionary = {}
        for target in selected_targets:
            if not (target is Dictionary):
                continue
            var target_dict: Dictionary = target as Dictionary
            var row_uid: String = str(target_dict.get("row_uid", ""))
            if row_uid.is_empty():
                continue
            if not targets_by_row.has(row_uid):
                targets_by_row[row_uid] = []
            (targets_by_row[row_uid] as Array).append(target_dict)
        for row_targets in targets_by_row.values():
            var targets_for_row: Array = row_targets as Array
            targets_for_row.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
                return int(a.get("ace_index", -1)) > int(b.get("ace_index", -1))
            )
            for target_dict in targets_for_row:
                var event_row: EventRow = target_dict.get("source_resource", null) as EventRow
                if event_row == null:
                    continue
                var kind: String = str(target_dict.get("kind", ""))
                var ace_index: int = int(target_dict.get("ace_index", -1))
                match kind:
                    "trigger":
                        if event_row.trigger != null:
                            event_row.trigger = null
                    "condition":
                        if ace_index >= 0 and ace_index < event_row.conditions.size():
                            event_row.conditions.remove_at(ace_index)
                    "action":
                        if ace_index >= 0 and ace_index < event_row.actions.size():
                            event_row.actions.remove_at(ace_index)
        return true
    )
    if not deleted:
        return false
    _viewport.clear_selection()
    _mark_dirty("Deleted ACE.")
    return true

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

## Nests a comment inside the right-clicked event (as a sub-event), so it can describe the
## events beneath it. Comments are the one non-event row allowed as a sub-event.
func _insert_child_comment_for_context_row() -> void:
    if _context_row == null or not (_context_row.source_resource is EventRow):
        _set_status("Add a comment sub-event from an event row.", true)
        return
    var changed: bool = _perform_undoable_sheet_edit("Add Comment Sub-Event", func() -> bool:
        var comment: CommentRow = CommentRow.new()
        comment.text = "Comment"
        (_context_row.source_resource as EventRow).sub_events.append(comment)
        return true
    )
    if changed:
        _refresh_after_edit()
        _mark_dirty("Added comment sub-event.")

func _open_sub_condition_picker_for_context_row() -> void:
    if _context_row == null or not (_context_row.source_resource is EventRow):
        return
    _ace_picker.open("new_sub_condition_event", false, _context_row.source_resource)

## The currently selected EventRow resource, or null when the selection is not an event.
func _selected_event_resource() -> EventRow:
    if _viewport == null:
        return null
    var resource: Variant = _active_view().get_selected_context().get("source_resource", null)
    return resource as EventRow if resource is EventRow else null

## Nests the selected event under the event directly above it (its preceding sibling),
## moving it into that event's sub_events. Returns true when the move happened.
func _indent_selected_event() -> bool:
    if not _ensure_sheet_for_editing():
        return false
    var target: EventRow = _selected_event_resource()
    if target == null:
        return false
    var location: Dictionary = _find_resource_location(target)
    var container: Array = location.get("container", [])
    var index: int = int(location.get("index", -1))
    if index <= 0:
        _set_status("Nothing above to nest this event under.", true)
        return false
    var previous: Variant = container[index - 1]
    if not (previous is EventRow):
        _set_status("Events can only be nested under another event.", true)
        return false
    var changed: bool = _perform_undoable_sheet_edit("Indent Event", func() -> bool:
        container.remove_at(index)
        (previous as EventRow).sub_events.append(target)
        return true
    )
    if changed:
        _mark_dirty("Nested event under the one above.")
    return changed

## Un-nests the selected sub-event, moving it out to its parent's container just after the
## parent. Returns true when the move happened.
func _outdent_selected_event() -> bool:
    if not _ensure_sheet_for_editing():
        return false
    var target: EventRow = _selected_event_resource()
    if target == null:
        return false
    var parent_info: Dictionary = _find_parent_event(target)
    var parent: Variant = parent_info.get("parent", null)
    if not bool(parent_info.get("found", false)) or not (parent is EventRow):
        _set_status("Event is already at the top level.", true)
        return false
    var parent_event: EventRow = parent as EventRow
    var parent_location: Dictionary = _find_resource_location(parent_event)
    var parent_container: Array = parent_location.get("container", [])
    var parent_index: int = int(parent_location.get("index", -1))
    if parent_index < 0:
        return false
    var changed: bool = _perform_undoable_sheet_edit("Outdent Event", func() -> bool:
        parent_event.sub_events.erase(target)
        parent_container.insert(parent_index + 1, target)
        return true
    )
    if changed:
        _mark_dirty("Un-nested event to the parent level.")
    return changed

## Finds the EventRow whose sub_events directly contains target.
## Returns {found: bool, parent: EventRow|null} (parent is null at root/group level).
func _find_parent_event(target: Resource) -> Dictionary:
    if _current_sheet == null:
        return {"found": false, "parent": null}
    return _find_parent_event_recursive(target, _current_sheet.events, null)

func _find_parent_event_recursive(target: Resource, container: Array, parent: EventRow) -> Dictionary:
    for entry in container:
        if entry == target:
            return {"found": true, "parent": parent}
        if entry is EventGroup:
            var grouped: Dictionary = _find_parent_event_recursive(target, _group_children_array(entry as EventGroup), null)
            if bool(grouped.get("found", false)):
                return grouped
        elif entry is EventRow:
            var nested: Dictionary = _find_parent_event_recursive(target, (entry as EventRow).sub_events, entry as EventRow)
            if bool(nested.get("found", false)):
                return nested
    return {"found": false, "parent": null}

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
    _update_code_panel_highlight()
    if _exposed_node != null and _viewport != null:
        _exposed_node.set_row_context(_active_view().get_selected_ace_resource())

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
            "group_description":
                if row_data.source_resource is EventGroup:
                    (row_data.source_resource as EventGroup).description = new_value
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

func _on_variable_dialog_confirmed(
    var_name: String,
    type_name: String,
    default_value: Variant,
    scope: String,
    context: Dictionary = {},
    is_constant: bool = false,
    exported: bool = true,
    combo_options: PackedStringArray = PackedStringArray(),
    attributes: Dictionary = {}
) -> void:
    # Guardrail (C3-style): auto-correct what's fixable, block what isn't — BEFORE commit.
    var sanitized_name: String = EventSheetIdentifierRules.sanitize(var_name)
    if sanitized_name.is_empty() or not EventSheetIdentifierRules.is_valid(sanitized_name):
        _set_status("\"%s\" can't be a variable name (letters/digits/underscores, not a GDScript keyword)." % var_name, true)
        return
    if sanitized_name != var_name:
        _set_status("Variable name auto-corrected to \"%s\"." % sanitized_name)
    var_name = sanitized_name
    var selected: Resource = context.get("selected_resource", _active_view().get_selected_context().get("source_resource", null))
    var original_name: String = str(context.get("original_name", ""))
    var editing: bool = bool(context.get("editing", false))
    var action_verb: String = "Updated" if editing else "Added"
    var message := {"text": ""}
    var supports_const: bool = _variable_type_supports_const(type_name)
    var resolved_constant: bool = is_constant and supports_const
    var added: bool = _perform_undoable_sheet_edit("Create Variable", func() -> bool:
        if scope == "tree":
            var editing_resource: Variant = context.get("variable_resource", null)
            if editing and editing_resource is LocalVariable:
                var existing: LocalVariable = editing_resource as LocalVariable
                existing.options = combo_options
                var previous_tree_name: String = existing.name
                existing.name = var_name
                if previous_tree_name != var_name:
                    message["renamed"] = _rename_variable_references(previous_tree_name, var_name)
                existing.type_name = type_name
                existing.default_value = default_value
                existing.is_constant = resolved_constant
                existing.exported = exported
                message["text"] = "Updated variable %s." % var_name
                return true
            var tree_var: LocalVariable = LocalVariable.new()
            tree_var.options = combo_options
            tree_var.name = var_name
            tree_var.type_name = type_name
            tree_var.default_value = default_value
            tree_var.is_constant = resolved_constant
            tree_var.exported = exported
            var anchor: Variant = context.get("insert_below", null)
            if anchor is Resource:
                var location: Dictionary = _find_resource_location(anchor as Resource)
                var container: Array = location.get("container", _current_sheet.events)
                var anchor_index: int = int(location.get("index", container.size() - 1))
                container.insert(anchor_index + 1, tree_var)
            else:
                _current_sheet.events.append(tree_var)
            message["text"] = "Added variable %s." % var_name
            return true
        if scope == "global":
            if editing and not original_name.is_empty() and original_name != var_name:
                _current_sheet.variables.erase(original_name)
                message["renamed"] = _rename_variable_references(original_name, var_name)
            _current_sheet.variables[var_name] = {
                "type": type_name,
                "default": default_value,
                "const": resolved_constant,
                "exported": exported,
                "exposed": exported,
                "options": Array(combo_options),
                "attributes": attributes
            }
            message["text"] = "%s %s variable %s." % [action_verb, "global" if exported else "private", var_name]
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
        local_var.is_constant = resolved_constant
        message["text"] = "%s local variable %s." % [action_verb, var_name]
        return true
    )
    if not added and scope != "global":
        _set_status("Add or select an event row before editing local variables.", true)
        return
    if added:
        var status_text: String = str(message.get("text", "Saved variable."))
        var renamed_references: int = int(message.get("renamed", 0))
        if renamed_references > 0:
            status_text += " %d reference(s) updated across the sheet." % renamed_references
        _mark_dirty(status_text)
        if scope == "local" and not (selected is EventRow):
            _select_first_event_row()

func _context_variable_entry_from_metadata(row_data: EventRowData, metadata: Dictionary) -> Dictionary:
    if row_data == null or metadata.is_empty() or _current_sheet == null:
        return {}
    var var_name: String = str(metadata.get("variable_name", ""))
    var scope: String = str(metadata.get("variable_scope", "global"))
    if var_name.is_empty():
        return {}
    if scope == "tree":
        var tree_var: LocalVariable = row_data.source_resource as LocalVariable
        if tree_var == null:
            return {}
        return {
            "name": tree_var.name,
            "scope": "tree",
            "type": tree_var.type_name,
            "default": tree_var.default_value,
            "is_constant": tree_var.is_constant,
            "exported": tree_var.exported,
            "resource": tree_var
        }
    var type_name: String = "Variant"
    var default_value: Variant = null
    var is_constant: bool = false
    var index: int = int(metadata.get("variable_index", -1))
    var owner_event: EventRow = null
    if scope == "local":
        if row_data.source_resource is EventRow:
            owner_event = row_data.source_resource as EventRow
        if owner_event == null and _viewport != null:
            var selected_resource: Resource = _active_view().get_selected_context().get("source_resource", null)
            if selected_resource is EventRow:
                owner_event = selected_resource as EventRow
        if owner_event == null:
            return {}
        var local_var: LocalVariable = _resolve_local_variable(owner_event, var_name, index)
        if local_var == null:
            return {}
        type_name = local_var.type_name
        default_value = local_var.default_value
        is_constant = local_var.is_constant
        index = owner_event.local_variables.find(local_var)
    else:
        var descriptor: Dictionary = _current_sheet.variables.get(var_name, {})
        if descriptor.is_empty():
            return {}
        type_name = str(descriptor.get("type", "Variant"))
        default_value = descriptor.get("default", null)
        is_constant = bool(descriptor.get("const", descriptor.get("is_constant", false)))
    return {
        "scope": scope,
        "name": var_name,
        "type": type_name,
        "default": default_value,
        "is_constant": is_constant,
        "supports_const": _variable_type_supports_const(type_name),
        "event_row": owner_event,
        "index": index
    }

func _resolve_local_variable(event_row: EventRow, var_name: String, index: int = -1) -> LocalVariable:
    if event_row == null:
        return null
    if index >= 0 and index < event_row.local_variables.size():
        var indexed: LocalVariable = event_row.local_variables[index]
        if indexed != null and indexed.name == var_name:
            return indexed
    for local_var in event_row.local_variables:
        if local_var is LocalVariable and (local_var as LocalVariable).name == var_name:
            return local_var as LocalVariable
    return null

func _edit_context_variable() -> void:
    if _context_variable.is_empty():
        return
    var scope: String = str(_context_variable.get("scope", "global"))
    if scope == "tree":
        var tree_var: LocalVariable = _context_variable.get("resource", null)
        if tree_var == null:
            _set_status("Could not resolve the variable to edit.", true)
            return
        _variable_dlg.open_for_edit(
            "tree",
            {"editing": true, "variable_resource": tree_var},
            tree_var.name,
            tree_var.type_name,
            tree_var.default_value,
            false,
            "Edit Variable",
            tree_var.is_constant,
            tree_var.exported
        )
        return
    if scope == "local":
        var owner_event: EventRow = _context_variable.get("event_row", null)
        if owner_event == null:
            _set_status("Select the owning event before editing this local variable.", true)
            return
        _variable_dlg.open_for_edit(
            "local",
            {
                "editing": true,
                "original_name": str(_context_variable.get("name", "")),
                "variable_index": int(_context_variable.get("index", -1)),
                "selected_resource": owner_event
            },
            str(_context_variable.get("name", "")),
            str(_context_variable.get("type", "Variant")),
            _context_variable.get("default", null),
            _is_local_variable_in_use(str(_context_variable.get("name", "")), owner_event),
            "Edit Variable",
            bool(_context_variable.get("is_constant", false))
        )
        return
    var global_name: String = str(_context_variable.get("name", ""))
    _variable_dlg.open_for_edit(
        "global",
        {"editing": true, "original_name": global_name},
        global_name,
        str(_context_variable.get("type", "Variant")),
        _context_variable.get("default", null),
        _is_global_variable_in_use(global_name),
        "Edit Variable",
        bool(_context_variable.get("is_constant", false)),
        bool(_context_variable.get("exported", _context_variable.get("exposed", true)))
    )

func _convert_context_variable_scope() -> void:
    if _context_variable.is_empty():
        return
    var scope: String = str(_context_variable.get("scope", "global"))
    if scope == "global":
        _prompt_convert_global_variable_to_local(_context_variable)
        return
    var converted: bool = _convert_variable_scope(_context_variable, "global")
    if not converted:
        _set_status("Could not convert variable to global scope.", true)

func _toggle_context_variable_constant() -> void:
    if _context_variable.is_empty():
        return
    if not bool(_context_variable.get("supports_const", false)):
        _set_status("Const is unavailable for this variable type.", true)
        return
    var scope: String = str(_context_variable.get("scope", "global"))
    var var_name: String = str(_context_variable.get("name", ""))
    var new_constant: bool = not bool(_context_variable.get("is_constant", false))
    var changed: bool = _perform_undoable_sheet_edit("Toggle Variable Constant", func() -> bool:
        if scope == "global":
            var descriptor: Dictionary = _current_sheet.variables.get(var_name, {})
            if descriptor.is_empty():
                return false
            descriptor["const"] = new_constant
            _current_sheet.variables[var_name] = descriptor
            return true
        var owner_event: EventRow = _context_variable.get("event_row", null)
        var local_var: LocalVariable = _resolve_local_variable(owner_event, var_name, int(_context_variable.get("index", -1)))
        if local_var == null:
            return false
        local_var.is_constant = new_constant
        return true
    )
    if changed:
        _mark_dirty("%s variable %s as constant." % ["Marked" if new_constant else "Unmarked", var_name])
        _context_variable["is_constant"] = new_constant

func _prompt_convert_global_variable_to_local(entry: Dictionary) -> void:
    if _current_sheet == null:
        return
    var options: Array[Dictionary] = _collect_event_row_options()
    if options.is_empty():
        _set_status("Add an event row first, then convert this variable to local.", true)
        return
    var dialog: ConfirmationDialog = ConfirmationDialog.new()
    dialog.title = "Convert Global Variable to Local"
    var content: VBoxContainer = VBoxContainer.new()
    content.custom_minimum_size = Vector2(420.0, 120.0)
    dialog.add_child(content)
    var summary: Label = Label.new()
    summary.text = "Select the target event for local variable %s." % str(entry.get("name", ""))
    summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(summary)
    var picker: OptionButton = OptionButton.new()
    picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for option in options:
        picker.add_item(str(option.get("label", "")))
        picker.set_item_metadata(picker.item_count - 1, str(option.get("uid", "")))
    content.add_child(picker)
    dialog.confirmed.connect(func() -> void:
        var selected_uid: String = str(picker.get_item_metadata(picker.selected))
        var converted: bool = _convert_variable_scope(entry, "local", selected_uid)
        if not converted:
            _set_status("Could not convert variable to local scope.", true)
        dialog.queue_free()
    )
    dialog.canceled.connect(func() -> void: dialog.queue_free())
    dialog.close_requested.connect(func() -> void: dialog.queue_free())
    add_child(dialog)
    dialog.popup_centered(Vector2i(460, 180))

func _collect_event_row_options() -> Array[Dictionary]:
    var options: Array[Dictionary] = []
    if _current_sheet == null:
        return options
    var event_rows: Array[EventRow] = []
    _collect_event_rows_recursive(_current_sheet.events, event_rows)
    for event_row in event_rows:
        options.append(
            {
                "uid": event_row.event_uid,
                "label": _format_event_target_label(event_row)
            }
        )
    return options

func _collect_event_rows_recursive(resources: Array, output: Array[EventRow]) -> void:
    for resource_entry in resources:
        if resource_entry is EventRow:
            output.append(resource_entry as EventRow)
            _collect_event_rows_recursive((resource_entry as EventRow).sub_events, output)
        elif resource_entry is EventGroup:
            _collect_event_rows_recursive(_group_children_array(resource_entry as EventGroup), output)

func _format_event_target_label(event_row: EventRow) -> String:
    if event_row == null:
        return "(invalid event)"
    var label: String = "Event %s" % event_row.event_uid
    if not event_row.comment.is_empty():
        label += " — %s" % event_row.comment
    elif not event_row.trigger_id.is_empty():
        label += " — %s" % event_row.trigger_id
    elif event_row.trigger != null and not event_row.trigger.ace_id.is_empty():
        label += " — %s" % event_row.trigger.ace_id
    return label

func _find_event_row_by_uid(event_uid: String) -> EventRow:
    if _current_sheet == null or event_uid.is_empty():
        return null
    var event_rows: Array[EventRow] = []
    _collect_event_rows_recursive(_current_sheet.events, event_rows)
    for event_row in event_rows:
        if event_row.event_uid == event_uid:
            return event_row
    return null

func _convert_variable_scope(entry: Dictionary, target_scope: String, target_event_uid: String = "") -> bool:
    if _current_sheet == null or entry.is_empty():
        return false
    var source_scope: String = str(entry.get("scope", "global"))
    var var_name: String = str(entry.get("name", ""))
    var type_name: String = str(entry.get("type", "Variant"))
    var default_value: Variant = entry.get("default", null)
    var is_constant: bool = bool(entry.get("is_constant", false))
    if source_scope == target_scope:
        return false
    var converted: bool = _perform_undoable_sheet_edit("Convert Variable Scope", func() -> bool:
        if source_scope == "global" and target_scope == "local":
            var descriptor: Dictionary = _current_sheet.variables.get(var_name, {})
            if descriptor.is_empty():
                _set_status("Global variable %s no longer exists." % var_name, true)
                return false
            var target_event: EventRow = _find_event_row_by_uid(target_event_uid)
            if target_event == null:
                _set_status("Select a target event for local conversion.", true)
                return false
            if _resolve_local_variable(target_event, var_name) != null:
                _set_status("Target event already has a local variable named %s." % var_name, true)
                return false
            var local_var: LocalVariable = LocalVariable.new()
            local_var.name = var_name
            local_var.type_name = type_name
            local_var.type = _type_from_name(type_name)
            local_var.default_value = default_value
            local_var.is_constant = is_constant
            target_event.local_variables.append(local_var)
            _current_sheet.variables.erase(var_name)
            return true
        if source_scope == "local" and target_scope == "global":
            var owner_event: EventRow = entry.get("event_row", null)
            var local_var: LocalVariable = _resolve_local_variable(owner_event, var_name, int(entry.get("index", -1)))
            if local_var == null:
                _set_status("Local variable %s no longer exists." % var_name, true)
                return false
            if _current_sheet.variables.has(var_name):
                _set_status("A global variable named %s already exists." % var_name, true)
                return false
            _current_sheet.variables[var_name] = {
                "type": local_var.type_name,
                "default": local_var.default_value,
                "const": local_var.is_constant,
                "exposed": true
            }
            owner_event.local_variables.remove_at(owner_event.local_variables.find(local_var))
            return true
        return false
    )
    if converted:
        _mark_dirty("Converted variable %s to %s scope." % [var_name, target_scope])
    return converted

func _variable_type_supports_const(type_name: String) -> bool:
    return type_name != "Variant"

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
        entry.get("default", null),
        _is_global_variable_in_use(var_name),
        "Edit Variable",
        bool(entry.get("const", false)),
        bool(entry.get("exported", entry.get("exposed", true)))
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
        entry.get("default", null),
        _is_local_variable_in_use(var_name, selected_resource),
        "Edit Variable",
        bool(entry.get("const", false))
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
    var selected_rows: Array[EventRowData] = _active_view().get_selected_rows()
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
    if depth >= VARIABLE_USAGE_MAX_DEPTH or var_name.is_empty() or values.is_empty():
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
    _global_variable_entries.clear()
    _local_variable_entries.clear()
    if _global_var_list != null:
        _global_var_list.clear()
    if _local_var_list != null:
        _local_var_list.clear()
    if _current_sheet != null:
        var names: Array = _current_sheet.variables.keys()
        names.sort()
        for var_name in names:
            var descriptor: Dictionary = _current_sheet.variables.get(var_name, {})
            var is_constant: bool = bool(descriptor.get("const", descriptor.get("is_constant", false)))
            if _global_var_list != null:
                _global_var_list.add_item(
                    "%s%s : %s = %s"
                    % [
                        "const " if is_constant else "",
                        var_name,
                        str(descriptor.get("type", "Variant")),
                        str(descriptor.get("default", ""))
                    ]
                )
            _global_variable_entries.append({
                "name": var_name,
                "type": str(descriptor.get("type", "Variant")),
                "default": descriptor.get("default", ""),
                "const": is_constant
            })
    var selected_resource: Resource = _active_view().get_selected_context().get("source_resource", null)
    if selected_resource is EventRow:
        for index in range((selected_resource as EventRow).local_variables.size()):
            var local_var: LocalVariable = (selected_resource as EventRow).local_variables[index]
            if local_var == null:
                continue
            if _local_var_list != null:
                _local_var_list.add_item(
                    "%s%s : %s = %s"
                    % [
                        "const " if local_var.is_constant else "",
                        local_var.name,
                        local_var.type_name,
                        str(local_var.default_value)
                    ]
                )
            _local_variable_entries.append({
                "index": index,
                "name": local_var.name,
                "type": local_var.type_name,
                "default": local_var.default_value,
                "const": local_var.is_constant,
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
    _sync_split_sheet()
    _sync_active_theme_binding()
    _refresh_exposed_node()
    _refresh_variable_panel()
    _refresh_code_panel()

func _sync_active_theme_binding() -> void:
    var next_style: EventSheetEditorStyle = (
        _current_sheet.editor_style
        if _current_sheet != null and _current_sheet.editor_style != null
        else null
    )
    if _active_theme_style == next_style:
        return
    if _active_theme_style != null and _active_theme_style.changed.is_connected(_on_active_theme_style_changed):
        _active_theme_style.changed.disconnect(_on_active_theme_style_changed)
    _active_theme_style = next_style
    if _active_theme_style != null and not _active_theme_style.changed.is_connected(_on_active_theme_style_changed):
        _active_theme_style.changed.connect(_on_active_theme_style_changed)

func _on_active_theme_style_changed() -> void:
    if _viewport == null or _current_sheet == null:
        return
    _viewport.set_sheet(_current_sheet)
    _set_status("Theme change detected and reloaded.")

func _mark_dirty(message: String) -> void:
    _dirty = true
    _refresh_title_strip()
    _set_status("%s%s" % [message, " *" if _dirty else ""])

func _set_status(text: String, is_error: bool = false) -> void:
    if _status_label == null:
        return
    _status_label.text = text
    _status_label.modulate = Color(1.0, 0.48, 0.48) if is_error else Color(1.0, 1.0, 1.0)

func _refresh_title_strip() -> void:
    # Keep the active tab's persisted state and tab title in sync with the live state.
    _sync_active_tab_state()
    _update_active_tab_title()
    if _title_tab_label == null or _title_path_label == null or _title_dirty_dot == null:
        return
    _title_tab_label.text = _format_sheet_title(_current_sheet, _current_sheet_path)
    _title_path_label.text = _format_sheet_path_hint(_current_sheet, _current_sheet_path)
    _title_dirty_dot.visible = _dirty and _current_sheet != null
    if _identity_banner != null:
        _identity_banner.update_from_sheet(_current_sheet)

static func _format_sheet_title(sheet: EventSheetResource, explicit_path: String) -> String:
    if sheet == null:
        return "No Sheet Loaded"
    var resolved_path: String = _resolve_sheet_path(sheet, explicit_path)
    if resolved_path.is_empty():
        return "Untitled EventSheet"
    return resolved_path.get_file().get_basename()

static func _format_sheet_path_hint(sheet: EventSheetResource, explicit_path: String) -> String:
    if sheet == null:
        return "Open or create a sheet to begin"
    var resolved_path: String = _resolve_sheet_path(sheet, explicit_path)
    if resolved_path.is_empty():
        return "Unsaved (in-memory)"
    return resolved_path

static func _resolve_sheet_path(sheet: EventSheetResource, explicit_path: String) -> String:
    if sheet == null:
        return explicit_path
    if not explicit_path.is_empty():
        return explicit_path
    return sheet.resource_path

func _refresh_ace_registry() -> void:
    if _ace_registry == null:
        _ace_registry = EventSheetACERegistry.new()
    _release_ace_sources()
    var owned_sources: Array[Object] = _build_sheet_ace_sources()
    var combined_sources: Array[Object] = owned_sources.duplicate()
    combined_sources.append_array(_manual_ace_sources)
    if combined_sources.is_empty():
        owned_sources = _build_default_ace_sources()
        combined_sources = owned_sources.duplicate()
    # Zero-config addons: scripts under res://eventsheet_addons/ register project-wide
    # automatically — purely additive (they never displace the default vocabulary or the
    # sheet's own providers; deduped against the sheet's provider list).
    var addon_sources: Array[Object] = _build_addon_ace_sources()
    owned_sources.append_array(addon_sources)
    combined_sources.append_array(addon_sources)
    _ace_sources = owned_sources
    _ace_registry.refresh_from_sources(combined_sources, true)
    if _viewport != null:
        _viewport.set_ace_registry(_ace_registry)
    _ace_picker.set_registry(_ace_registry)
    _refresh_exposed_node()

## Instantiates the current sheet's registered provider scripts into reflectable sources.
func _build_sheet_ace_sources() -> Array[Object]:
    var sources: Array[Object] = []
    if _current_sheet == null:
        return sources
    for path: Variant in _current_sheet.ace_provider_scripts:
        var instance: Object = _instantiate_provider_script(str(path))
        if instance != null:
            sources.append(instance)
    return sources

## Instantiates every scanned zero-config addon script (res://eventsheet_addons/), skipping
## paths the sheet already registers explicitly.
func _build_addon_ace_sources() -> Array[Object]:
    var sources: Array[Object] = []
    var sheet_paths: Array = _current_sheet.ace_provider_scripts if _current_sheet != null else []
    # Folder scan + code-registered providers (EventForgeBridge.register_script_as_provider
    # lets other plugins/tools extend the vocabulary without touching eventsheet_addons/).
    var provider_paths: Array[String] = EventSheetAddonScanner.list_addon_scripts()
    for registered_path: String in EventForgeBridgeRuntime.get_registered_provider_scripts():
        if not provider_paths.has(registered_path):
            provider_paths.append(registered_path)
    # Registered autoloads with annotated scripts publish project-wide (event buses,
    # game state) — zero-config, like eventsheet_addons/.
    _autoload_provider_names.clear()
    for property_info: Dictionary in ProjectSettings.get_property_list():
        var setting_name: String = str(property_info.get("name", ""))
        if not setting_name.begins_with("autoload/"):
            continue
        var autoload_path: String = str(ProjectSettings.get_setting(setting_name, "")).trim_prefix("*")
        if not autoload_path.ends_with(".gd"):
            continue
        # Only ANNOTATED autoloads publish (reflection would otherwise dump every
        # public method of e.g. the plugin's own bridge into every picker — silent
        # vocabulary pollution). The regex anchors on the annotation form so a passing
        # doc-comment mention of "@ace_*" doesn't count.
        var autoload_source: String = FileAccess.get_file_as_string(autoload_path)
        if _autoload_annotation_regex == null:
            _autoload_annotation_regex = RegEx.new()
            _autoload_annotation_regex.compile("(?m)^\\s*## @ace_")
        if _autoload_annotation_regex.search(autoload_source) == null:
            continue
        var autoload_script: Script = load(autoload_path) if ResourceLoader.exists(autoload_path) else null
        if autoload_script == null:
            continue
        # Map class -> singleton name even when the script is ALREADY scanned (an addon
        # registered as an autoload still needs bus-style trigger baking).
        var provider_class: String = str(autoload_script.get_global_name())
        if provider_class.is_empty():
            provider_class = autoload_path.get_file().get_basename().to_pascal_case()
        _autoload_provider_names[provider_class] = setting_name.trim_prefix("autoload/")
        if not provider_paths.has(autoload_path):
            provider_paths.append(autoload_path)
    for path: String in provider_paths:
        if sheet_paths.has(path):
            continue
        var instance: Object = _instantiate_provider_script(path)
        if instance != null:
            sources.append(instance)
    return sources

## Loads and instantiates a provider script (Node/Resource/RefCounted) for reflection.
## Returns null when the path is not an instantiable script.
func _instantiate_provider_script(path: String) -> Object:
    if path.strip_edges().is_empty() or not ResourceLoader.exists(path):
        return null
    var resource: Resource = load(path)
    if not (resource is Script):
        return null
    var script: Script = resource as Script
    if not script.can_instantiate():
        return null
    var instance: Variant = script.new()
    return instance if instance is Object else null

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
    # The built-in demo sheet pairs with the bundled demo gameplay actor. Resolve it BY
    # NAME: "first reflected provider" broke once addons became additive (order varies),
    # and the registry may not be refreshed yet when the demo builds — the literal
    # fallback is the actor's class_name, which is what reflection registers it under.
    if _ace_registry != null:
        for provider_id: String in _ace_registry.get_reflected_provider_ids():
            if provider_id.contains("DemoGameplayActor"):
                return provider_id
    return "EventSheetDemoGameplayActor"

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
