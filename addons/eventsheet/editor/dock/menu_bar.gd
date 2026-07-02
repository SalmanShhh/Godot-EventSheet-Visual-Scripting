@tool
extends RefCounted
class_name EventSheetMenuBar
# The dock's top toolbar + menu bar: the HFlowContainer that flow-wraps the grouped
# Sheet/Add/Edit/View/Tools MenuButtons, the high-frequency one-click buttons, the per-sheet
# theme picker, and the quick-add LineEdit. Construction-only — every menu/button action targets
# a dock method that STAYS on the dock, reached through the `_dock` back-reference (the same
# pattern as the other dock/ helpers). The widgets the dock reads later (_toolbar, _view_popup,
# _theme_picker, _quick_add_edit) stay DECLARED on the dock; build() constructs them and assigns
# them back so nothing else changes. Extracted from event_sheet_dock.gd to keep that file
# maintainable; the menus keep their .name + item order so the dock's tests find them unchanged.

var _dock: Control = null

func init(dock: Control) -> void:
	_dock = dock

## Builds the toolbar + menu bar and adds it as the FIRST child of `root` (the workspace
## VBox), exactly where the dock used to inline this. Assigns _toolbar/_view_popup/
## _theme_picker/_quick_add_edit back onto the dock during the build, before any reader runs.
func build(root: Node) -> void:
	var _toolbar: HFlowContainer = HFlowContainer.new()
	_toolbar.name = "EventSheetToolbar"
	_toolbar.add_theme_constant_override("h_separation", 4)
	_dock._toolbar = _toolbar
	root.add_child(_toolbar)

	# Sheet ▾ — file lifecycle + identity (low frequency, one menu).
	var sheet_menu: MenuButton = MenuButton.new()
	sheet_menu.name = "EventSheetSheetMenu"
	sheet_menu.text = "Sheet"
	sheet_menu.tooltip_text = "Create, open, save, and configure this event sheet."
	sheet_menu.flat = false
	var sheet_popup: PopupMenu = sheet_menu.get_popup()
	sheet_popup.add_item("New…", 0)
	sheet_popup.add_item("Open…", 1)
	sheet_popup.add_item("Save", 2)
	sheet_popup.add_item("Save As…", 3)
	sheet_popup.add_separator()
	sheet_popup.add_item("Export GDScript…", 7)
	sheet_popup.set_item_tooltip(
		sheet_popup.get_item_index(7),
		"Write this sheet's plain, standalone GDScript to a file you own. No plugin dependency — proof you can leave the addon anytime."
	)
	sheet_popup.add_separator()
	sheet_popup.add_item("Sheet Type…", 4)
	sheet_popup.add_item("Manage Includes…", 8)
	sheet_popup.add_item("Custom Actions…", 5)
	sheet_popup.add_item("New Behaviour Addon…", 9)
	sheet_popup.set_item_tooltip(
		sheet_popup.get_item_index(9),
		"Scaffold a ready-to-edit behaviour script in res://eventsheet_addons/ — its signals become triggers, methods become actions/conditions, and @export vars become properties, all auto-discovered as custom ACEs."
	)
	sheet_popup.add_item("Export Addon…", 6)
	sheet_popup.id_pressed.connect(func(id: int) -> void:
		match id:
			0: _dock._open_template_menu()
			1: _dock._on_open_requested()
			2: _dock._on_save_requested()
			3: _dock._on_save_as_requested()
			4: _dock._open_sheet_type_dialog()
			5: _dock._on_manage_ace_providers_requested()
			6: _dock._export_addon_pack()
			7: _dock._export_gdscript_requested()
			8: _dock._open_include_manager()
			9: _dock._new_addon_panel.open()
	)
	_toolbar.add_child(sheet_menu)
	_add_toolbar_button(_toolbar, "Save", _dock._on_save_requested, "Save the sheet — compile-on-save keeps its generated script fresh (Ctrl+S).", "Save")
	_add_toolbar_button(_toolbar, "Run Scene", _dock._run_from_sheet, "Save, then play the scene that uses this sheet's script.", "Play")
	_add_toolbar_separator(_toolbar)
	# The core reflexes stay one click (E / C / A on the keyboard).
	_add_toolbar_button(_toolbar, "Add Event", _dock._on_add_event_requested, "Add an event (E).", "Add")
	_add_toolbar_button(_toolbar, "Add Condition", _dock._on_add_condition_requested, "Add a condition to the selected event (C).", "MemberConstant")
	_add_toolbar_button(_toolbar, "Add Action", _dock._on_add_action_requested, "Add an action to the selected event (A).", "MemberMethod")
	_add_toolbar_button(_toolbar, "Add Code", _dock._on_add_gdscript_action_requested, "Add a GDScript block to the selected event — the deliberate 'drop to code' escape hatch (like Construct 3's script actions). Opens the code editor immediately.", "Script")
	# Add ▾ — the rest of the authoring vocabulary.
	var add_menu: MenuButton = MenuButton.new()
	add_menu.name = "EventSheetAddMenu"
	add_menu.text = "Add"
	add_menu.flat = false
	var add_popup: PopupMenu = add_menu.get_popup()
	add_popup.add_item("Signal Event…", 0)
	add_popup.add_item("Global Variable…", 1)
	add_popup.add_item("Local Variable…", 2)
	add_popup.add_item("Function…", 3)
	add_popup.add_separator()
	add_popup.add_item("Code (GDScript) on Selected Event", 4)
	add_popup.id_pressed.connect(func(id: int) -> void:
		match id:
			0: _dock._on_add_signal_event_requested()
			1: _dock._on_add_global_variable_requested()
			2: _dock._on_add_local_variable_requested()
			3: _dock._open_function_dialog()
			4: _dock._on_add_gdscript_action_requested()
	)
	_toolbar.add_child(add_menu)
	# Edit ▾ — clipboard + history (all on shortcuts too).
	var edit_menu: MenuButton = MenuButton.new()
	edit_menu.name = "EventSheetEditMenu"
	edit_menu.text = "Edit"
	edit_menu.flat = false
	var edit_popup: PopupMenu = edit_menu.get_popup()
	edit_popup.add_item("Copy", 0)
	edit_popup.add_item("Paste", 1)
	edit_popup.add_separator()
	edit_popup.add_item("Undo", 2)
	edit_popup.add_item("Redo", 3)
	edit_popup.add_separator()
	edit_popup.add_item("Extract Selection to Include…", 4)
	edit_popup.add_item("Find References…", 5)
	edit_popup.add_separator()
	edit_popup.add_item("Generate from Description (AI)…", 6)
	edit_popup.id_pressed.connect(func(id: int) -> void:
		match id:
			0: _dock._on_copy_requested()
			1: _dock._on_paste_requested()
			2: _dock._on_undo_requested()
			3: _dock._on_redo_requested()
			4: _dock._extract_to_include_requested()
			5: _dock._find_references_requested()
			6: _dock._open_ai_generate()
	)
	_toolbar.add_child(edit_menu)
	# View ▾ — panels, multi-view, zoom and theming.
	var view_menu: MenuButton = MenuButton.new()
	view_menu.name = "EventSheetViewMenu"
	view_menu.text = "View"
	view_menu.tooltip_text = "Panels, multi-view panes, theme, live values, and zoom."
	view_menu.flat = false
	var view_popup: PopupMenu = view_menu.get_popup()
	_dock._view_popup = view_popup
	view_popup.add_check_item("Simple Mode (beginner-friendly)", 11)
	view_popup.set_item_checked(view_popup.get_item_index(11), _dock._simple_mode)
	view_popup.add_separator()
	view_popup.add_item("GDScript Panel (toggle)", 0)
	view_popup.add_check_item("Open Sheets Panel", 13)
	view_popup.set_item_checked(view_popup.get_item_index(13), bool(_dock._read_open_sheets_panel_prefs().get("shown", true)))
	view_popup.add_check_item("Add-Event Rows", 9)
	view_popup.set_item_checked(view_popup.get_item_index(9), true)
	view_popup.add_separator()
	view_popup.add_item("Split View (toggle)", 1)
	view_popup.add_item("Detached View (toggle)", 2)
	view_popup.add_item("Link Views (toggle)", 3)
	view_popup.add_separator()
	view_popup.add_item("Zoom In", 4)
	view_popup.add_item("Zoom Out", 5)
	view_popup.add_separator()
	view_popup.add_item("Load Theme…", 6)
	view_popup.add_item("Reload Theme", 7)
	view_popup.add_item("Theme Editor…", 8)
	view_popup.add_separator()
	view_popup.add_check_item("MCP Server (AI tools)", 12)
	view_popup.set_item_checked(view_popup.get_item_index(12), EventSheetMCPServer.is_enabled())
	view_popup.id_pressed.connect(func(id: int) -> void:
		match id:
			0: _dock._toggle_code_panel()
			1: _dock._toggle_split_view()
			2: _dock._toggle_detached_view()
			3: _dock._toggle_linked_views()
			4: _dock._on_zoom_in_requested()
			5: _dock._on_zoom_out_requested()
			6: _dock._on_load_theme_requested()
			7: _dock._on_reload_theme_requested()
			8: _dock._open_theme_editor()
			9: _dock._toggle_add_event_rows(view_popup)
			11: _dock.set_simple_mode(not _dock._simple_mode)
			12: _dock._toggle_mcp_server(view_popup)
			13: _dock._toggle_open_sheets_panel(view_popup)
	)
	# Toggles say what they toggle on hover (user call: hovering a toggle should
	# explain it).
	view_popup.set_item_tooltip(view_popup.get_item_index(0), "Show/hide the generated-GDScript panel beside the sheet.")
	view_popup.set_item_tooltip(view_popup.get_item_index(9), "Show/hide the trailing \"+ Add event…\" rows. Turn off for a cleaner, calmer sheet.")
	view_popup.set_item_tooltip(view_popup.get_item_index(11), "Hide the advanced/code entries (GDScript blocks, sub-conditions, pick filters, match, signals/enums) from the right-click menus. Everything still works in Expert mode.")
	view_popup.set_item_tooltip(view_popup.get_item_index(12), "Turn the MCP server (AI-assistant tools) on/off. When off, connected AI clients see no tools and can't read or change your sheets. Takes effect live — no reconnect needed.")
	view_popup.set_item_tooltip(view_popup.get_item_index(1), "Show/hide a second synchronized view of this sheet, side by side.")
	view_popup.set_item_tooltip(view_popup.get_item_index(2), "Pop the sheet view out into its own window / bring it back.")
	view_popup.set_item_tooltip(view_popup.get_item_index(3), "Link/unlink scrolling between the split views.")
	_toolbar.add_child(view_menu)
	# Tools ▾ — debug + project workflow tools (the UX-audit consolidation).
	var tools_menu: MenuButton = MenuButton.new()
	tools_menu.text = "Tools"
	tools_menu.tooltip_text = "Debug tools, validation, import, and project workflow."
	tools_menu.flat = false
	var tools_popup: PopupMenu = tools_menu.get_popup()
	tools_popup.add_item("Debug Breakpoints (toggle)", 0)
	tools_popup.add_item("Live Values (toggle)", 1)
	tools_popup.add_item("Event Trace (live highlight)", 15)
	tools_popup.add_item("Bookmarks…", 2)
	tools_popup.add_separator()
	tools_popup.add_item("Register Autoload", 3)
	tools_popup.add_item("Publish Preview…", 4)
	tools_popup.add_item("Test Bench", 5)
	tools_popup.add_separator()
	tools_popup.add_item("Find in Project…", 6)
	tools_popup.add_item("Project Doctor…", 7)
	tools_popup.add_item("Check Sheet for Errors", 14)
	tools_popup.add_item("Vocabulary Doc", 8)
	tools_popup.add_separator()
	tools_popup.add_item("Sheet Backups…", 9)
	tools_popup.add_item("Save as Template", 10)
	tools_popup.add_item("Attach to Selected Node", 11)
	tools_popup.add_item("Lift Report…", 12)
	tools_popup.add_separator()
	tools_popup.add_item("Welcome…", 13)
	tools_popup.add_item("Keyboard Shortcuts", 16)
	tools_popup.id_pressed.connect(func(id: int) -> void:
		match id:
			0: _dock._toggle_breakpoint_emission()
			1: _dock._toggle_live_values()
			15: _dock._toggle_event_trace()
			2: _dock._open_bookmarks_panel()
			3: _dock._register_autoload()
			4: _dock._open_publish_preview()
			5: _dock._open_test_bench()
			6: _dock._open_project_find()
			7: _dock._open_project_doctor()
			8: _dock._generate_vocabulary_doc()
			9: _dock._open_sheet_backups()
			10: _dock._save_as_project_template()
			11: _dock._attach_behavior_to_selection()
			12: _dock._open_lift_report()
			13: _dock.show_welcome()
			16: _dock._open_shortcuts_help()
			14: _dock._run_diagnostics_action()
	)
	tools_popup.set_item_tooltip(tools_popup.get_item_index(14), "Lint every ƒx expression + GDScript block; flag the offending rows and jump to the first.")
	tools_popup.set_item_tooltip(tools_popup.get_item_index(0), "Toggle breakpoint emission: debug-compiled sheets pause at rows with breakpoints.")
	tools_popup.set_item_tooltip(tools_popup.get_item_index(1), "Toggle Live Values: running sheets stream their variables here (editable).")
	_toolbar.add_child(tools_menu)
	_add_toolbar_separator(_toolbar)
	# GDScript stays a one-click toggle (the pairing thesis: honest output, always
	# one click away) next to the per-sheet theme picker.
	_add_toolbar_button(_toolbar, "GDScript", _dock._toggle_code_panel, "Toggle the generated-GDScript panel — the sheet's honest compiled output, side by side.", "Script")
	var _theme_picker: OptionButton = OptionButton.new()
	_theme_picker.name = "EventSheetThemePicker"
	_theme_picker.tooltip_text = "Theme for this sheet (Load/Reload and the Theme Editor live in View)"
	_theme_picker.item_selected.connect(_dock._on_theme_preset_selected)
	_dock._theme_picker = _theme_picker
	_toolbar.add_child(_theme_picker)
	_dock._populate_theme_picker()
	var _quick_add_edit: LineEdit = LineEdit.new()
	_quick_add_edit.placeholder_text = "Quick add…  (e.g. every tick, heal 5)"
	_quick_add_edit.tooltip_text = "Event-sheet-style quick add: type an event/condition/action (event-sheet phrasing works) plus optional parameter values, press Enter."
	_quick_add_edit.custom_minimum_size = Vector2(190.0, 0.0)
	_dock._quick_add_edit = _quick_add_edit
	_quick_add_edit.text_submitted.connect(func(text: String) -> void:
		if _dock._quick_add(text):
			_quick_add_edit.clear()
	)
	_toolbar.add_child(_quick_add_edit)

## Adds a one-click toolbar button wired to `callable`, with an optional editor icon.
## (Moved verbatim from the dock; targets the toolbar passed in rather than a member.)
func _add_toolbar_button(toolbar: HFlowContainer, text: String, callable: Callable, tooltip: String = "", editor_icon: String = "") -> void:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	# Editor icons make the toolbar read as part of Godot (no-op headless / pre-1.0
	# editor theme without the icon).
	if not editor_icon.is_empty() and Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor_theme: Theme = EditorInterface.get_editor_theme()
		if editor_theme != null and editor_theme.has_icon(editor_icon, "EditorIcons"):
			button.icon = editor_theme.get_icon(editor_icon, "EditorIcons")
	button.pressed.connect(callable)
	toolbar.add_child(button)

func _add_toolbar_separator(toolbar: HFlowContainer) -> void:
	var sep: VSeparator = VSeparator.new()
	toolbar.add_child(sep)
