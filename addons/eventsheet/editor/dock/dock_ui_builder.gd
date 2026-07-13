@tool
class_name EventSheetDockUIBuilder
extends RefCounted
# The dock's UI CONSTRUCTION pass, extracted from event_sheet_dock.gd to keep that file
# maintainable. Everything here BUILDS controls and wires their signals back into the dock:
# the main workspace layout (_build_ui: toolbar strip, viewport scroll host, status bar,
# panels), the provider-registration dialog, the GDScript code panel, the lazily-created
# editor dialogs, and the raw-GDScript block dialog. All state (every widget reference,
# every preference flag) STAYS ON THE DOCK - construction writes through the `_dock.`
# back-reference, so lifecycle, signal targets, and teardown behave exactly as before the
# extraction. Bodies were moved VERBATIM with member access rewritten through `_dock.`;
# the dock keeps one-line delegates so no call site changed.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


func build_ui() -> void:
	if _dock._toolbar != null:
		return
	_dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var root: VBoxContainer = VBoxContainer.new()
	root.name = "EventSheetWorkspaceRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock.add_child(root)

	# Toolbar redesign: grouped by purpose (Sheet / Add / Edit / View / Tools menus)
	# with only the high-frequency reflexes as one-click buttons - and it FLOWS to
	# a second row instead of clipping when the panel is narrow (the old single HBox
	# of ~28 controls overflowed past the panel edge).
	# The toolbar + grouped Sheet/Add/Edit/View/Tools menus + theme picker + quick-add
	# are built by the extracted EventSheetMenuBar; it adds _dock._toolbar as root's FIRST child
	# and assigns _dock._toolbar/_dock._view_popup/_dock._theme_picker/_dock._quick_add_edit back onto the dock.
	_dock._menu_bar.init(_dock)
	_dock._menu_bar.build(root)

	_dock._tab_bar = TabBar.new()
	_dock._tab_bar.name = "EventSheetTabBar"
	_dock._tab_bar.clip_tabs = true
	_dock._tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ALWAYS
	_dock._tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock._tab_bar.tab_selected.connect(_dock._on_tab_selected)
	_dock._tab_bar.tab_close_pressed.connect(_dock._on_tab_close_pressed)
	root.add_child(_dock._tab_bar)

	_dock._title_strip = HBoxContainer.new()
	_dock._title_strip.name = "EventSheetTitleStrip"
	_dock._title_strip.add_theme_constant_override("separation", 8)
	root.add_child(_dock._title_strip)

	var title_tab_shell: PanelContainer = PanelContainer.new()
	title_tab_shell.name = "EventSheetTitleTab"
	_dock._title_strip.add_child(title_tab_shell)

	var title_tab_content: HBoxContainer = HBoxContainer.new()
	title_tab_content.add_theme_constant_override("separation", 4)
	title_tab_shell.add_child(title_tab_content)

	_dock._title_tab_label = Label.new()
	_dock._title_tab_label.name = "EventSheetTitleTabLabel"
	_dock._title_tab_label.text = "No Sheet Loaded"
	title_tab_content.add_child(_dock._title_tab_label)

	_dock._title_dirty_dot = Label.new()
	_dock._title_dirty_dot.name = "EventSheetTitleDirtyDot"
	_dock._title_dirty_dot.text = "●"
	_dock._title_dirty_dot.modulate = Color(0.99, 0.78, 0.30, 1.0)
	_dock._title_dirty_dot.visible = false
	title_tab_content.add_child(_dock._title_dirty_dot)

	_dock._title_path_label = Label.new()
	_dock._title_path_label.name = "EventSheetTitlePath"
	_dock._title_path_label.modulate = Color(0.72, 0.76, 0.84, 1.0)
	_dock._title_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock._title_path_label.clip_text = true
	_dock._title_path_label.text = "Open or create a sheet to begin"
	_dock._title_strip.add_child(_dock._title_path_label)

	# Pinned Conditions/Actions column header, above the scrolling sheet (bound to the
	# viewport once it exists). Kept outside the scroll so the scroll still has a single child.
	_dock._identity_banner = SheetIdentityBanner.new()
	root.add_child(_dock._identity_banner)
	_dock._identity_banner.edit_requested.connect(_dock._open_sheet_type_dialog)

	# Read-only preview banner (a .gd opened just to look at it) - hidden for normal sheets.
	_dock._preview_banner = _dock._preview_glue.build_preview_banner()
	root.add_child(_dock._preview_banner)

	_dock._column_header = SheetColumnHeader.new()
	root.add_child(_dock._column_header)

	_dock._scroll = ScrollContainer.new()
	_dock._scroll.name = "EventSheetScroll"
	_dock._scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock._scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock._scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_dock._scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Wrap the viewport in _dock._content_host, then sit it beside the Open Sheets panel in _dock._workspace_body.
	_dock._content_host = VBoxContainer.new()
	_dock._content_host.name = "EventSheetContentHost"
	_dock._content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock._content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock._content_host.add_child(_dock._scroll)
	_dock._open_sheets_panel = EventSheetOpenSheetsDock.new()
	_dock._open_sheets_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock._open_sheets_panel.activate_requested.connect(_dock.activate_open_tab)
	_dock._open_sheets_panel.reopen_requested.connect(_dock.reopen_sheet_path)
	_dock._open_sheets_panel.collapse_toggled.connect(_dock._on_open_sheets_panel_collapsed)
	_dock.open_tabs_changed.connect(_dock._refresh_open_sheets_panel)
	# The Functions overview is its own dockable rail panel (fold-expandable on demand) - it used
	# to live inside the Generated-GDScript side panel, so seeing your functions meant opening the
	# code view. The list's click/right-click handlers stay on the dock.
	_dock._functions_panel = EventSheetFunctionsPanel.new()
	_dock._functions_panel.add_requested.connect(_dock._open_function_dialog)
	_dock._functions_list = _dock._functions_panel.list
	_dock._functions_list.item_clicked.connect(_dock._on_functions_list_item_clicked)
	_dock._functions_menu = PopupMenu.new()
	_dock._functions_menu.add_item("Delete Function", 0)
	_dock._functions_menu.id_pressed.connect(_dock._on_functions_menu_id_pressed)
	_dock._functions_list.add_child(_dock._functions_menu)
	# The Anatomy panel shares the left rail below Open Sheets: the active behaviour's organs
	# (knobs/state/triggers/actions/conditions/expressions/uses) at a glance, click to jump.
	_dock._anatomy_panel = BehaviourAnatomyPanel.new()
	_dock._anatomy_panel.reveal_requested.connect(func(resource: Resource) -> void:
		var view: EventSheetViewport = _dock._active_view()
		if view != null:
			view.reveal_resource(resource))
	# Uses entries jump to the provider's own sheet - the same go-to-definition as
	# Ctrl+Click on one of its verbs, so Alt+Left walks straight back.
	_dock._anatomy_panel.open_provider_requested.connect(func(provider_id: String) -> void:
		var provider_path: String = _dock._navigate._script_path_for_class(provider_id)
		if provider_path.is_empty():
			_dock._set_status("No script found for provider %s." % provider_id, true)
			return
		_dock._navigate.record_current()
		_dock._navigate.open_or_focus(provider_path)
		_dock._set_status("Opened %s - a behaviour this sheet uses (Alt+Left jumps back)." % provider_path.get_file()))
	var left_rail: VBoxContainer = VBoxContainer.new()
	left_rail.name = "EventSheetLeftRail"
	left_rail.add_theme_constant_override("separation", 8)
	left_rail.add_child(_dock._open_sheets_panel)
	left_rail.add_child(_dock._functions_panel)
	left_rail.add_child(_dock._anatomy_panel)
	_dock._workspace_body = HSplitContainer.new()
	_dock._workspace_body.name = "EventSheetWorkspaceBody"
	_dock._workspace_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock._workspace_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock._workspace_body.add_child(left_rail)
	_dock._workspace_body.add_child(_dock._content_host)
	root.add_child(_dock._workspace_body)
	_dock._apply_open_sheets_panel_prefs()

	_dock._viewport = EventSheetViewport.new()
	_dock._viewport.name = "EventSheetViewport"
	_dock._viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock._viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock._viewport.set_ace_registry(_dock._ace_registry)
	_dock._scroll.add_child(_dock._viewport)
	_dock._column_header.setup(_dock._viewport)
	_dock._identity_banner.setup(_dock._viewport)

	_dock._viewport.selection_changed.connect(_dock._on_viewport_selection_changed)
	_dock._viewport.selection_changed.connect(func(row_data: EventRowData) -> void:
		if _dock._mirroring_selection:
			return  # a mirrored selection must not steal the active view
		_dock._active_viewport_ref = _dock._viewport
		_dock._mirror_selection(_dock._viewport, row_data)
	)
	_dock._viewport.row_drop_requested.connect(_dock._on_row_drop_requested)
	_dock._viewport.rows_drop_requested.connect(_dock._on_rows_drop_requested)
	_dock._viewport.ace_preview_requested.connect(_dock._on_ace_preview_requested)
	_dock._viewport.asset_dropped.connect(_dock._apply_asset_drop)
	_dock._viewport.ace_picker_requested.connect(_dock._on_viewport_ace_picker_requested)
	_dock._viewport.span_edit_requested.connect(_dock._on_viewport_span_edit_requested)
	_dock._viewport.navigate_requested.connect(_dock._navigate.navigate)
	_dock._viewport.navigation_probe = _dock._navigate.can_navigate
	_dock._viewport.ace_edit_requested.connect(_dock._on_viewport_ace_edit_requested)
	_dock._viewport.param_value_edit_requested.connect(_dock._on_param_value_edit_requested)
	_dock._viewport.param_value_edit_at_rect_requested.connect(func(ace: Resource, param_id: String, current_text: String, anchor_screen: Rect2) -> void:
		_dock._inline_params.on_param_value_edit_requested(ace, param_id, current_text, anchor_screen))
	_dock._viewport.color_swatch_edit_requested.connect(_dock._on_color_swatch_edit_requested)
	_dock._viewport.param_node_drop_requested.connect(_dock._on_param_node_drop_requested)
	_dock._viewport.variable_edit_requested.connect(_dock._on_viewport_variable_edit_requested)
	_dock._viewport.comment_edit_requested.connect(_dock._open_comment_dialog)
	_dock._viewport.group_edit_requested.connect(_dock._on_group_edit_requested)
	_dock._viewport.pick_filter_edit_requested.connect(_dock._open_pick_filter_dialog)
	_dock._viewport.with_node_edit_requested.connect(_dock._open_with_node_dialog)
	_dock._viewport.enum_edit_requested.connect(_dock._open_enum_dialog)
	_dock._viewport.signal_edit_requested.connect(_dock._open_signal_dialog)
	_dock._viewport.custom_block_edit_requested.connect(_dock._open_custom_block_dialog)
	_dock._viewport.function_edit_requested.connect(_dock._function_dialog_glue._open_function_dialog_for)
	_dock._viewport.variable_group_requested.connect(_dock._variable_grouping.on_group_requested)
	_dock._viewport.variable_group_rename_requested.connect(_dock._variable_grouping.on_rename_requested)
	_dock._viewport.match_edit_requested.connect(_dock._open_match_dialog)
	_dock._viewport.row_disable_toggle_requested.connect(_dock._toggle_selected_rows_enabled)
	_dock._viewport.row_move_requested.connect(_dock._move_selected_row)
	_dock._viewport.delete_requested.connect(_dock._delete_selected_content)
	_dock._viewport.find_requested.connect(_dock._show_find_bar)
	_dock._viewport.find_step_requested.connect(_dock._find_step)
	_dock._apply_editor_native_defaults()
	_dock._viewport.ace_drop_requested.connect(_dock._on_viewport_ace_drop_requested)
	_dock._viewport.drag_status_requested.connect(_dock._on_viewport_drag_status_requested)
	_dock._viewport.lane_ratio_changed.connect(_dock._on_viewport_lane_ratio_changed)
	_dock._viewport.add_event_requested.connect(_dock._on_viewport_add_event_requested)
	_dock._viewport.raw_code_edit_requested.connect(_dock._on_viewport_raw_code_edit_requested)
	_dock._viewport.context_menu_requested.connect(_dock._on_viewport_context_menu_requested)
	_dock._viewport.empty_space_double_clicked.connect(_dock._on_viewport_empty_space_double_clicked)
	_dock._viewport.template_menu_requested.connect(_dock._open_template_menu)
	_dock._viewport.empty_space_context_menu_requested.connect(_dock._on_viewport_empty_space_context_menu_requested)
	_dock._viewport.set_external_span_edit_handler_enabled(true)

	_dock._status_label = Label.new()
	_dock._status_label.name = "EventSheetStatus"
	_dock._status_label.text = "Ready"
	root.add_child(_dock._status_label)

	_dock._exposed_node.name = "EventSheetExposedParams"
	_dock.add_child(_dock._exposed_node)
	_dock._exposed_node.setup(_dock._ace_registry, _dock._editor_param_store, _dock._current_sheet, _dock._param_resolver)
	_dock._exposed_node.set_undo_redo_manager(_dock._undo_redo_adapter.get_manager())
	# The right-click context menus (condition/action/row/variable/empty-space) are built by the
	# extracted EventSheetContextMenus; build_all() constructs each and assigns it back onto the dock
	# (the _*_context_menu / _row_*_submenu members the dock + tests read by name). init() only stores
	# the _dock back-reference, so wiring it here - before any context-menu site runs - is enough.
	_dock._context_menus.init(_dock)
	_dock._context_menus.build_all()
	_dock._build_preview_window()
	_dock._build_theme_file_dialog()


func build_provider_dialog() -> void:
	if _dock._provider_dialog != null:
		return
	_dock._provider_dialog = Window.new()
	_dock._provider_dialog.title = "Custom ACE Providers"
	_dock._provider_dialog.visible = false
	_dock._provider_dialog.min_size = Vector2i(460, 320)
	_dock._provider_dialog.close_requested.connect(func() -> void: _dock._provider_dialog.hide())
	_dock.add_child(_dock._provider_dialog)

	var content: VBoxContainer = EventSheetPopupUI.form_box()
	var margin: MarginContainer = EventSheetPopupUI.margined(content)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dock._provider_dialog.add_child(margin)

	content.add_child(EventSheetPopupUI.hint_label("Register GDScript files whose methods, signals and exported variables become custom ACEs.\nZero-config alternative: drop scripts into res://eventsheet_addons/ and they register project-wide automatically."))

	var providers_box: VBoxContainer = EventSheetPopupUI.form_box()

	_dock._provider_list = ItemList.new()
	_dock._provider_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock._provider_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	providers_box.add_child(_dock._provider_list)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	providers_box.add_child(buttons)
	var add_button: Button = Button.new()
	add_button.text = "Add…"
	add_button.pressed.connect(_dock._on_provider_add_pressed)
	buttons.add_child(add_button)
	var remove_button: Button = Button.new()
	remove_button.text = "Remove Selected"
	remove_button.pressed.connect(_dock._on_provider_remove_pressed)
	buttons.add_child(remove_button)
	var open_in_godot_button: Button = Button.new()
	open_in_godot_button.text = "Open in Godot Script Editor"
	open_in_godot_button.tooltip_text = "Open the selected provider script in Godot's script editor."
	open_in_godot_button.pressed.connect(_dock._on_provider_open_in_godot_pressed)
	buttons.add_child(open_in_godot_button)

	var providers_card: PanelContainer = EventSheetPopupUI.titled_card("Providers", providers_box)
	providers_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(providers_card)

	_dock._provider_file_dialog = FileDialog.new()
	_dock._provider_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dock._provider_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_dock._provider_file_dialog.filters = PackedStringArray(["*.gd ; GDScript"])
	_dock._provider_file_dialog.file_selected.connect(_dock._on_provider_file_selected)
	_dock._provider_dialog.add_child(_dock._provider_file_dialog)


## Builds the panel lazily on first toggle: wraps the sheet scroll in an HSplitContainer
## (so the default tree stays untouched until the user asks for the panel) and adds the
## code view on the right.
func ensure_code_panel() -> void:
	if _dock._split != null:
		return
	var scroll_parent: Node = _dock._scroll.get_parent()
	var scroll_index: int = _dock._scroll.get_index()
	_dock._split = HSplitContainer.new()
	_dock._split.name = "EventSheetCodeSplit"
	_dock._split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock._split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_parent.remove_child(_dock._scroll)
	scroll_parent.add_child(_dock._split)
	scroll_parent.move_child(_dock._split, scroll_index)
	_dock._split.add_child(_dock._scroll)
	_dock._side_panel = VBoxContainer.new()
	_dock._side_panel.name = "GeneratedGDScriptPanel"
	_dock._side_panel.custom_minimum_size = Vector2(360.0, 0.0)
	_dock._side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock._side_panel.visible = false
	# (The Functions overview used to live here; it is now its own dockable left-rail panel -
	# see functions_panel.gd - so it no longer requires the code view to be open.)
	var header: HBoxContainer = HBoxContainer.new()
	var title: Label = Label.new()
	title.text = "Generated GDScript"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var open_in_godot_button: Button = Button.new()
	open_in_godot_button.text = "Open in Godot Script Editor"
	open_in_godot_button.tooltip_text = "Open the .gd source in Godot's own script editor (code-backed sheets). For a .tres sheet, Save As… a .gd first."
	open_in_godot_button.pressed.connect(_dock._open_generated_in_godot)
	header.add_child(open_in_godot_button)
	var copy_button: Button = Button.new()
	copy_button.text = "Copy"
	copy_button.tooltip_text = "Copy the generated script to the clipboard"
	copy_button.pressed.connect(func() -> void:
		if _dock._code_edit != null:
			DisplayServer.clipboard_set(_dock._code_edit.text)
	)
	header.add_child(copy_button)
	var close_button: Button = Button.new()
	close_button.text = "✕"
	close_button.tooltip_text = "Close the GDScript panel"
	close_button.pressed.connect(_dock._toggle_code_panel)
	header.add_child(close_button)
	_dock._side_panel.add_child(header)
	# Orientation for non-programmers: say what this panel even is before the code scares them off.
	var code_hint: Label = Label.new()
	code_hint.text = "The plain GDScript your sheet compiles to - read-only, refreshed live as you edit. Your game ships this, with no runtime dependency."
	code_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	code_hint.modulate = Color(1.0, 1.0, 1.0, 0.6)
	_dock._side_panel.add_child(code_hint)
	_dock._code_edit = CodeEdit.new()
	_dock._code_edit.editable = false
	_dock._code_edit.gutters_draw_line_numbers = true
	_dock._code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock._code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# GDScriptSyntaxHighlighter is editor-only; headless test runs skip it.
	if Engine.is_editor_hint() and ClassDB.class_exists("GDScriptSyntaxHighlighter"):
		_dock._code_edit.syntax_highlighter = ClassDB.instantiate("GDScriptSyntaxHighlighter")
	# Make the panel read like the actual script editor: its code font + the minimap.
	_dock._apply_editor_code_settings(_dock._code_edit)
	_dock._code_edit.gui_input.connect(_dock._on_code_panel_gui_input)
	_dock._side_panel.add_child(_dock._code_edit)
	_dock._split.add_child(_dock._side_panel)
	_dock._split.split_offset = int(_dock.size.x * 0.6) if _dock.size.x > 0.0 else 600


# Initializes the picker/params/variable dialogs and wires their signals + providers.
# Idempotent (guarded by _dock._editor_dialogs_initialized) and safe to run detached: it only
# touches dialog init + signal connections + provider wiring - nothing tree-bound. Called
# from _dock._ready() in the real editor AND from _dock.setup() so headless tests (which never enter
# the tree, so _dock._ready never fires) still get initialized dialogs.
func ensure_editor_dialogs_initialized() -> void:
	if _dock._editor_dialogs_initialized:
		return
	_dock._editor_dialogs_initialized = true
	_dock._load_simple_mode_preference()
	_dock._param_resolver.set_param_store(_dock._editor_param_store)
	_dock._ace_picker.init_dialog(_dock, _dock._ace_registry)
	_dock._ace_picker.set_simple_mode_provider(func() -> bool: return _dock._simple_mode)
	_dock._ace_picker.set_reflect_class_provider(func() -> String: return _dock._current_sheet.host_class if _dock._current_sheet != null else "")
	_dock._variable_dlg.simple_mode_provider = func() -> bool: return _dock._simple_mode
	_dock._ace_picker.ace_selected.connect(_dock._on_ace_picker_selected)
	_dock._ace_params.init_dialog(_dock, _dock._ace_registry, _dock._collect_sheet_variable_names)
	_dock._ace_params.set_lint_context_provider(func() -> EventSheetResource: return _dock._current_sheet)
	_dock._ace_params.set_variable_creator(_dock._create_variable_quickfix)
	_dock._ace_params.params_confirmed.connect(_dock._on_ace_params_confirmed)
	_dock._ace_params.back_requested.connect(_dock._on_ace_params_back_requested)
	_dock._variable_dlg.init_dialog(_dock)
	_dock._new_addon_panel.init(_dock)
	_dock._welcome.init(_dock)
	_dock._tour.init(_dock)
	_dock._behavior_preview.init(_dock)
	_dock._starter.init(_dock)
	_dock._comments.init(_dock)
	_dock._struct_rows.init(_dock)
	_dock._inline_params.init(_dock)
	_dock._doctor.init(_dock)
	_dock._includes.init(_dock)
	_dock._find_refs.init(_dock)
	_dock._pick.init(_dock)
	_dock._ai.init(_dock)
	_dock._sheet_type.init(_dock)
	_dock._session.init(_dock)
	_dock._shortcuts.init(_dock)
	_dock._rename.init(_dock)
	_dock._variables.init(_dock)
	_dock._multi_view.init(_dock)
	_dock._command_palette.init(_dock)
	_dock._sheet_diff.init(_dock)
	_dock._variable_grouping.init(_dock)
	_dock._context_menus.init(_dock)
	_dock._external_watcher.init(_dock)
	_dock._sheet_io.init(_dock)
	_dock._ace_apply.init(_dock)
	_dock._row_edit_ops.init(_dock)
	_dock._preview_glue.init(_dock)
	_dock._author_actions.init(_dock)
	_dock._ghost_row.init(_dock)
	_dock._navigate.init(_dock)
	_dock._export_pack.init(_dock)
	_dock._save_studio.init(_dock)
	_dock._function_dialog_glue.init(_dock)
	_dock._theme_manager.init(_dock)
	_dock._find_bar_glue.init(_dock)
	_dock._clipboard_glue.init(_dock)
	_dock._quick_prompts.init(_dock)
	_dock._custom_block_dialog.init(_dock)
	# Feed the active sheet so the name field can flag host-member shadowing (live + blocking).
	_dock._variable_dlg.set_sheet_provider(func() -> EventSheetResource: return _dock._current_sheet)
	_dock._variable_dlg.variable_confirmed.connect(_dock._on_variable_dialog_confirmed)
	# Sheet enums feed the variable dialog's one-click combo fill.
	_dock._variable_dlg.set_enum_provider(func() -> Array:
		var sheet_enums: Array = []
		if _dock._current_sheet != null:
			for row: Variant in _dock._current_sheet.events:
				if row is EnumRow and (row as EnumRow).enabled:
					sheet_enums.append({"name": (row as EnumRow).enum_name, "members": (row as EnumRow).members})
		return sheet_enums)


func ensure_raw_code_dialog() -> void:
	if _dock._raw_code_dialog != null:
		return
	_dock._raw_code_dialog = ConfirmationDialog.new()
	_dock._raw_code_dialog.title = "Edit GDScript Block"
	# Standard popup margins, consistent with the other plugin dialogs.
	var layout_box: VBoxContainer = EventSheetPopupUI.form_box()
	layout_box.custom_minimum_size = Vector2(640.0, 0.0)
	layout_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The hint + lint labels are autowrap but WIDTH-BOUNDED (custom_minimum_size.x): a
	# ConfirmationDialog sizes to its content's minimum, and an UNBOUNDED autowrap label reports a
	# runaway min height during the initial zero-width pass (it wraps to one glyph per line), which
	# ballooned this popup to thousands of px tall on launch. Bounding the width makes the min-_dock.size
	# pass wrap at a sane width while still letting long lint errors wrap at runtime.
	_dock._raw_code_hint = Label.new()
	_dock._raw_code_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dock._raw_code_hint.custom_minimum_size = Vector2(620.0, 0.0)
	layout_box.add_child(_dock._raw_code_hint)
	# EventSheetRawCodeEdit adds Scene-node / asset drop (insert $Path / %Name at the caret) while keeping
	# the CodeEdit's native text drag-and-drop - a plain set_drag_forwarding would clobber the latter.
	_dock._raw_code_edit = EventSheetRawCodeEdit.new()
	_dock._raw_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dock._raw_code_edit.custom_minimum_size = Vector2(620.0, 330.0)
	_dock._raw_code_edit.gutters_draw_line_numbers = true
	_dock._raw_code_edit.indent_use_spaces = false
	# GDScriptSyntaxHighlighter is editor-only; headless test runs skip it.
	if Engine.is_editor_hint() and ClassDB.class_exists("GDScriptSyntaxHighlighter"):
		_dock._raw_code_edit.syntax_highlighter = ClassDB.instantiate("GDScriptSyntaxHighlighter")
	_dock._raw_code_edit.code_completion_enabled = true
	EventSheetPopupUI.configure_code_editor(_dock._raw_code_edit)  # auto-close brackets/quotes at the source
	_dock._raw_code_edit.text_changed.connect(_dock._validate_raw_code)
	_dock._raw_code_edit.code_completion_requested.connect(_dock._populate_raw_code_completion)
	layout_box.add_child(_dock._raw_code_edit)
	_dock._raw_code_lint_label = Label.new()
	_dock._raw_code_lint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dock._raw_code_lint_label.custom_minimum_size = Vector2(620.0, 0.0)
	layout_box.add_child(_dock._raw_code_lint_label)
	_dock._raw_code_dialog.add_child(EventSheetPopupUI.margined(layout_box))
	_dock._raw_code_dialog.confirmed.connect(_dock._on_raw_code_dialog_confirmed)
	# "Open in Godot" hands the block off to Godot's own script editor (more room, full tooling); the
	# in-popup editor stays for quick inline edits. custom_action fires for non-OK/Cancel buttons.
	var open_in_godot: Button = _dock._raw_code_dialog.add_button("Open in Godot Script Editor", false, "open_in_godot")
	open_in_godot.tooltip_text = "Edit this block in Godot's script editor - your changes return when you come back to the sheet."
	_dock._raw_code_dialog.custom_action.connect(func(action: StringName) -> void:
		if String(action) == "open_in_godot":
			_dock._open_raw_code_block_in_godot())
	_dock.add_child(_dock._raw_code_dialog)
