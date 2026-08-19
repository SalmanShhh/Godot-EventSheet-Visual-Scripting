@tool
class_name EventSheetMenuBar
extends RefCounted
# The dock's top toolbar + menu bar: the HFlowContainer that flow-wraps the grouped
# Sheet/Add/Edit/View/Tools MenuButtons, the high-frequency one-click buttons, the per-sheet
# theme picker, and the quick-add LineEdit. Assembly only - every menu/button action targets
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

	# Sheet ▾ - file lifecycle + identity (low frequency, one menu).
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
		"Write this sheet's plain, standalone GDScript to a file you own. No plugin dependency - proof you can leave the addon anytime."
	)
	sheet_popup.add_item("Save as Text…", 16)
	sheet_popup.set_item_tooltip(
		sheet_popup.get_item_index(16),
		"Write the whole sheet as a plain listing in its own words - \"+ \" for a condition, \"-> \" for an action, indented by sub-event, event numbers on - ready to paste into an issue, a design doc or a chat."
	)
	sheet_popup.add_separator()
	sheet_popup.add_item("Sheet Type…", 4)
	sheet_popup.add_item("Manage Includes…", 8)
	sheet_popup.add_item("Custom Actions…", 5)
	sheet_popup.add_item("New Behaviour Addon…", 9)
	sheet_popup.set_item_tooltip(
		sheet_popup.get_item_index(9),
		"Scaffold a ready-to-edit behaviour script in res://eventsheet_addons/ - its signals become triggers, methods become actions/conditions, and @export vars become properties, all auto-discovered as custom ACEs."
	)
	sheet_popup.add_item("New Editor Tool…", 12)
	sheet_popup.set_item_tooltip(
		sheet_popup.get_item_index(12),
		"Start an editor-side tool sheet: its events run INSIDE the editor (script editor > File > Run), never in the game - batch renames, scene checks, one-click chores."
	)
	sheet_popup.add_item("New Custom Resource…", 13)
	sheet_popup.set_item_tooltip(
		sheet_popup.get_item_index(13),
		"Make your own data asset in three questions: name one entry, list its columns, done - a Resource whose Inspector is a fill-in table, saved as .tres files designers edit."
	)
	sheet_popup.add_item("Teach a Verb - Share Published Verbs", 10)
	sheet_popup.set_item_tooltip(
		sheet_popup.get_item_index(10),
		"Make this sheet's published functions (its exposed ƒ functions) available in EVERY sheet's picker, node-targeted at $%s. Extract actions to a function first (right-click an event), then teach it here." % "<ClassName>"
	)
	sheet_popup.add_item("Inspector Designer…", 11)
	sheet_popup.set_item_tooltip(
		sheet_popup.get_item_index(11),
		"See the WHOLE sheet's Inspector as one live view - every exported variable with its decor, grouping, and widget, exactly as Godot will show it."
	)
	sheet_popup.add_item("Export Addon…", 6)
	sheet_popup.add_item("Publish New Version…", 14)
	sheet_popup.set_item_tooltip(sheet_popup.get_item_index(14), "Bump this pack's @ace_version (patch/minor/major) with a one-line change note recorded in its class docs - backed up first, republished on the spot.")
	sheet_popup.add_separator()
	sheet_popup.add_item("Name Raw Calls…", 15)
	sheet_popup.set_item_tooltip(sheet_popup.get_item_index(15), "Sweep this sheet for raw one-call code rows and name each one that matches an action you already have - engine classes, your own scripts, installed packs. Each conversion is kept only when it compiles to the exact same line; anything ambiguous is left alone.")
	sheet_popup.id_pressed.connect(func(id: int) -> void:
		match id:
			0: _dock._open_template_menu()
			1: _dock._on_open_requested()
			2: _dock._on_save_requested()
			3: _dock._on_save_as_requested()
			4: _dock._open_sheet_type_dialog()
			5: _dock._on_manage_ace_providers_requested()
			6: _dock._export_addon_pack()
			14: _dock._open_publish_version_dialog()
			15: _dock._name_raw_calls_requested()
			7: _dock._export_gdscript_requested()
			8: _dock._open_include_manager()
			9: _dock._new_addon_panel.open()
			10: _dock._share_verbs_with_project_requested()
			11: _dock._open_inspector_designer()
			12: _dock._starter._new_sheet_from_template(10)
			13: _dock._new_resource_wizard.open()
			16: _dock._save_sheet_as_text_requested()
	)
	_toolbar.add_child(sheet_menu)
	_add_toolbar_button(_toolbar, "Save", _dock._on_save_requested, "Save the sheet - compile-on-save keeps its generated script fresh (Ctrl+S).", "Save")
	_add_toolbar_button(_toolbar, "Run Scene", _dock._run_from_sheet, "Save, then play the scene that uses this sheet's script.", "Play")
	_add_toolbar_separator(_toolbar)
	# The core reflexes stay one click (E / C / A on the keyboard).
	_add_toolbar_button(_toolbar, "Add Event", _dock._on_add_event_requested, "Add an event (E).", "Add")
	_add_toolbar_button(_toolbar, "Add Condition", _dock._on_add_condition_requested, "Add a condition to the selected event (C).", "MemberConstant")
	_add_toolbar_button(_toolbar, "Add Action", _dock._on_add_action_requested, "Add an action to the selected event (A).", "MemberMethod")
	# Kept as a reference: Simple Mode hides this deliberate drop-to-code surface entirely.
	_dock._add_code_button = _add_toolbar_button(_toolbar, "Add Code", _dock._on_add_gdscript_action_requested, "Add a script block to the selected event - the deliberate 'drop to code' escape hatch. Opens the code editor immediately.", "Script")
	# Add ▾ - the rest of the authoring vocabulary.
	var add_menu: MenuButton = MenuButton.new()
	add_menu.name = "EventSheetAddMenu"
	add_menu.text = "Add"
	add_menu.flat = false
	var add_popup: PopupMenu = add_menu.get_popup()
	add_popup.add_item("Signal Event…", 0)
	# R37/R40 - the sheet's own members are INSTANCE variables of the object the file is; a GLOBAL is
	# one value the whole project shares, and lives on an autoload. Two different things, so two
	# items, each named the thing it makes.
	add_popup.add_item("Instance Variable…", 1)
	add_popup.add_item("Local Variable…", 2)
	add_popup.add_item("Global Variable… (V)", 8)
	add_popup.add_item("Function…", 3)
	add_popup.add_separator()
	# The three event-shape commands, on the Add menu as well as the right-click menu: the sheet
	# reads Or blocks, blank sub-events and Else, so all three must be typeable in the same words.
	add_popup.add_item("Add blank sub-event (B)", 5)
	add_popup.add_item("Make 'Or' block", 6)
	add_popup.add_item("Add 'Else'", 7)
	add_popup.add_separator()
	# S23 - the shapes a game is made of, as events. The patterns the sheet can READ it can also
	# WRITE, from the same fixtures: the list is the Manual's Common Game Patterns page, which draws
	# each one as a real picture of its rows with an Insert that lands them in this sheet - most
	# common first, so the ten a beginner wants are the ten they see.
	add_popup.add_item("Pattern…", 9)
	add_popup.set_item_tooltip(add_popup.get_item_index(9), "Insert a whole pattern - a cooldown, a wait sequence, a state machine - as events, picked from a page that draws each one.")
	add_popup.add_separator()
	add_popup.add_item("Code (GDScript) on Selected Event", 4)
	# Custom Block API kinds (preloads, region markers, registered pack kinds): one item per
	# registered kind, ids offset by 100 so the fixed ids above never collide.
	add_popup.add_separator()
	var registered_kinds: Array[EventSheetBlockKind] = EventSheetBlockRegistry.addable_kinds()
	for kind_index: int in range(registered_kinds.size()):
		# Kind TITLES localise (a pack can ship a CSV for its block names); kind_ids never do.
		add_popup.add_item("%s…" % EventSheetL10n.translate(registered_kinds[kind_index].title), 100 + kind_index)
	add_popup.id_pressed.connect(func(id: int) -> void:
		if id >= 100:
			var kinds_now: Array[EventSheetBlockKind] = EventSheetBlockRegistry.addable_kinds()
			if id - 100 < kinds_now.size():
				_dock._open_custom_block_add(kinds_now[id - 100].kind_id)
			return
		match id:
			0: _dock._on_add_signal_event_requested()
			1: _dock._on_add_global_variable_requested()
			2: _dock._on_add_local_variable_requested()
			3: _dock._open_function_dialog()
			4: _dock._on_add_gdscript_action_requested()
			5: _dock._on_add_blank_subevent_key()
			6: _dock._make_or_block_from_selection()
			7: _dock._make_else_from_selection()
			8: _dock._on_add_project_global_requested()
			9: EventSheetPatternManual.open_page("")
	)
	# Kept as a reference so Simple Mode can gate the code item (id 4) live.
	_dock._add_menu_popup = add_popup
	_toolbar.add_child(add_menu)
	# Edit ▾ - clipboard + history (all on shortcuts too).
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
	# View ▾ - panels, multi-view, zoom and theming.
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
	view_popup.add_check_item("Object Icons", 15)
	view_popup.set_item_checked(view_popup.get_item_index(15), true)
	view_popup.add_check_item("Event Numbers", 16)
	view_popup.set_item_checked(view_popup.get_item_index(16), true)
	view_popup.add_check_item("Aligned Object Columns", 18)
	view_popup.set_item_checked(view_popup.get_item_index(18), _dock._object_columns_aligned())
	view_popup.add_check_item("Compact Rows", 19)
	view_popup.set_item_checked(view_popup.get_item_index(19), _dock._compact_rows_enabled())
	view_popup.set_item_tooltip(view_popup.get_item_index(19), "Tighter rows - more events on screen with the same text size. Off = the comfortable default.")
	view_popup.add_check_item("Humanized Names", 20)
	view_popup.set_item_checked(view_popup.get_item_index(20), _dock._humanized_names_enabled())
	view_popup.set_item_tooltip(view_popup.get_item_index(20), "Read variable names as words: \"_coyote_timer\" becomes \"coyote timer\", and an exported knob reads with its Inspector name (\"Coyote Time\"). The raw name is always on hover. On by default while reading a sheet, off while authoring one.")
	view_popup.add_check_item("Familiar Words", 21)
	view_popup.set_item_checked(view_popup.get_item_index(21), _dock._familiar_words_enabled())
	view_popup.set_item_tooltip(view_popup.get_item_index(21), "Read the few Godot nouns other event-sheet editors name differently in the familiar word: a scene is a layout, pausing is time scale 0, a CanvasLayer is a layer. The Godot word stays on hover. Off by default.")
	view_popup.add_check_item("Patterns", 27)
	view_popup.set_item_checked(view_popup.get_item_index(27), _dock._patterns_lens_enabled())
	view_popup.set_item_tooltip(view_popup.get_item_index(27), "Name the shape an event is when a reading recognised one - a cooldown, an object pool, a wait sequence - with a marker chip whose hover shows the lines that were the evidence. On by default; off shows every event as its own plain sentences.")
	view_popup.add_item("Outline…", 17)
	view_popup.set_item_tooltip(view_popup.get_item_index(17), "Jump tree of the sheet's groups, regions, and published functions.")
	view_popup.add_check_item("Minimap", 27)
	view_popup.set_item_checked(view_popup.get_item_index(27), _dock._minimap_enabled())
	view_popup.set_item_tooltip(view_popup.get_item_index(27), "A picture of the whole sheet down the right edge: one bar per event tinted by what it is, the part you are looking at as a box you can drag, and your bookmarks in the margin. On by default once a sheet passes 200 events.")
	view_popup.add_item("Sheet Map…", 28)
	view_popup.set_item_tooltip(view_popup.get_item_index(28), "Which sheets, scenes and globals call, signal and include which - the shape of the project's logic on one page.")
	view_popup.add_item("History…", 29)
	view_popup.set_item_tooltip(view_popup.get_item_index(29), "Every edit you have made to this sheet, in the sheet's own words. Click one to undo or redo back to it.")
	view_popup.add_separator()
	# Collapsing IS how a long sheet is browsed, so the sweeps live in the menu beside the
	# Outline, not only on their shortcuts. Ids start at 22: 20 is already claimed twice above
	# (Humanized Names and the Preview In Language submenu), so the next free run starts there.
	view_popup.add_item("Collapse All", 22)
	view_popup.set_item_tooltip(view_popup.get_item_index(22), "Collapse every event and function block down to its own line (Ctrl+Shift+[). A collapsed block keeps a muted one-line summary of what it holds.")
	view_popup.add_item("Expand All", 23)
	view_popup.set_item_tooltip(view_popup.get_item_index(23), "Expand every block again (Ctrl+Shift+]).")
	view_popup.add_item("Expand To Level 1", 24)
	view_popup.add_item("Expand To Level 2", 25)
	view_popup.add_item("Expand To Level 3", 26)
	for level_id: int in [24, 25, 26]:
		view_popup.set_item_tooltip(view_popup.get_item_index(level_id),
			"Read the sheet down to this depth: everything shallower stays expanded, everything at this depth or deeper is collapsed. How deep you left a file is remembered for that file.")
	view_popup.add_separator()
	view_popup.add_item("Split View (toggle)", 1)
	view_popup.add_item("Detached View (toggle)", 2)
	view_popup.add_item("Link Views (toggle)", 3)
	view_popup.add_separator()
	view_popup.add_item("Zoom In", 4)
	view_popup.add_item("Zoom Out", 5)
	view_popup.add_item("Reset Zoom", 40)
	view_popup.set_item_tooltip(view_popup.get_item_index(40), "Back to 100% (Ctrl + 0). The zoom is remembered for every sheet you open, not for one file.")
	view_popup.add_check_item("Properties Bar", 41)
	view_popup.set_item_tooltip(view_popup.get_item_index(41), "Show the selected condition, action, object or group beside the sheet, with its parameters editable in place. Hidden by default in Simple Mode.")
	view_popup.set_item_checked(view_popup.get_item_index(41), not _dock._simple_mode)
	view_popup.add_separator()
	view_popup.add_item("Load Theme…", 6)
	view_popup.add_item("Reload Theme", 7)
	view_popup.add_item("Theme Editor…", 8)
	# Language lives beside the Theme entries (both are "how the editor looks/reads" choices).
	# The submenu rebuilds each open so a translation CSV dropped in mid-session is instantly
	# pickable (the drop-in reload keeps catalogs fresh; this keeps the MENU fresh). Explicit
	# child-popup wiring, never an id-less add_submenu_item (index-as-id collides with the
	# relabel logic - the 880/881 lesson).
	var language_menu: PopupMenu = PopupMenu.new()
	language_menu.name = "EventSheetLanguageMenu"
	view_popup.add_child(language_menu)
	view_popup.add_submenu_item("Language", "EventSheetLanguageMenu", 14)
	view_popup.set_item_tooltip(view_popup.get_item_index(14), "Switch the EventSheets editor language. Drop a translation CSV into addons/eventsheet/translations/ and it appears here automatically.")
	view_popup.about_to_popup.connect(func() -> void:
		language_menu.clear()
		var locales: PackedStringArray = EventSheetL10n.available_locales()
		for locale_index: int in locales.size():
			language_menu.add_radio_check_item(EventSheetL10n.locale_display_name(locales[locale_index]), locale_index)
			language_menu.set_item_checked(locale_index, locales[locale_index] == EventSheetL10n.get_locale())
	)
	language_menu.id_pressed.connect(func(locale_id: int) -> void:
		var locales: PackedStringArray = EventSheetL10n.available_locales()
		if locale_id < 0 or locale_id >= locales.size():
			return
		EventSheetL10n.set_locale(locales[locale_id])
		_dock.propagate_notification(MainLoop.NOTIFICATION_TRANSLATION_CHANGED)
		if _dock.get_viewport_control() != null:
			_dock.get_viewport_control().queue_redraw()
		_dock._set_status("Editor language: %s" % EventSheetL10n.locale_display_name(locales[locale_id]))
	)
	# Preview In Language is the GAME's languages, not the editor's - the sibling above switches the
	# plugin's own interface. Kept strictly apart: a French editor must never start rewriting the
	# user's rows. Picking one renders every globe-marked value in that locale AND points Godot's own
	# locale test setting at it, so the next Play speaks it with no debug key to bind.
	var preview_menu: PopupMenu = PopupMenu.new()
	preview_menu.name = "EventSheetPreviewLanguageMenu"
	_dock._preview_language_menu = preview_menu
	view_popup.add_child(preview_menu)
	view_popup.add_submenu_item("Preview In Language", "EventSheetPreviewLanguageMenu", 20)
	view_popup.set_item_tooltip(view_popup.get_item_index(20), "Read the sheet in one of your GAME's languages while you author it - the rows show the translation instead of tr(\"…\"). Your sheet is not touched, but Godot's Locale > Test setting is set (that is what makes the next Play run in it); pick \"As authored\" to clear it again.")
	view_popup.about_to_popup.connect(func() -> void: _dock._rebuild_preview_language_menu())
	preview_menu.id_pressed.connect(func(preview_id: int) -> void:
		var languages: PackedStringArray = _dock._preview_languages()
		_dock._preview_in_language("" if preview_id <= 0 or preview_id > languages.size() else languages[preview_id - 1]))
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
			40: _dock._on_zoom_reset_requested()
			41: _dock._toggle_properties_bar(view_popup)
			6: _dock._on_load_theme_requested()
			7: _dock._on_reload_theme_requested()
			8: _dock._open_theme_editor()
			9: _dock._toggle_add_event_rows(view_popup)
			15: _dock._toggle_object_icons(view_popup)
			16: _dock._toggle_event_numbers(view_popup)
			18: _dock._toggle_object_column_alignment(view_popup)
			19: _dock._toggle_compact_rows(view_popup)
			20: _dock._toggle_humanized_names(view_popup)
			21: _dock._toggle_familiar_words(view_popup)
			27: _dock._toggle_patterns_lens(view_popup)
			17: _dock._open_outline_panel()
			27: _dock._toggle_minimap(view_popup)
			28: _dock._open_sheet_map_panel()
			29: _dock._open_history_panel()
			11: _dock.set_simple_mode(not _dock._simple_mode)
			12: _dock._toggle_mcp_server(view_popup)
			13: _dock._toggle_open_sheets_panel(view_popup)
			22: _collapse_sweep(0)
			23: _collapse_sweep(-1)
			24: _collapse_sweep(1)
			25: _collapse_sweep(2)
			26: _collapse_sweep(3)
	)
	# Toggles say what they toggle on hover (user call: hovering a toggle should
	# explain it).
	view_popup.set_item_tooltip(view_popup.get_item_index(0), "Show/hide the generated-GDScript panel beside the sheet.")
	view_popup.set_item_tooltip(view_popup.get_item_index(9), "Show/hide the trailing \"+ Add event…\" rows. Turn off for a cleaner, calmer sheet.")
	view_popup.set_item_tooltip(view_popup.get_item_index(18), "On: every row's condition/action text starts at the same edge, so the sheet scans as a table. Off: the text follows each object's name, starting at a different point on every row. Drag the gap after an object name to set the width by hand.")
	view_popup.set_item_tooltip(view_popup.get_item_index(11), "Hide the advanced/code entries (script blocks, sub-conditions, pick filters, match, signals/enums) from the right-click menus. Everything still works in Expert mode.")
	view_popup.set_item_tooltip(view_popup.get_item_index(12), "Turn the MCP server (AI-assistant tools) on/off. When off, connected AI clients see no tools and can't read or change your sheets. Takes effect live - no reconnect needed.")
	view_popup.set_item_tooltip(view_popup.get_item_index(1), "Show/hide a second synchronized view of this sheet, side by side.")
	view_popup.set_item_tooltip(view_popup.get_item_index(2), "Pop the sheet view out into its own window / bring it back.")
	view_popup.set_item_tooltip(view_popup.get_item_index(3), "Link/unlink scrolling between the split views.")
	_toolbar.add_child(view_menu)
	# Tools ▾ - debug + project workflow tools (the UX-audit consolidation).
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
	tools_popup.add_item("Preview Behaviors on Selected Node", 18)
	tools_popup.add_item("Save Studio…", 19)
	# Translation Studio sits beside Save Studio because it is the same shape applied to text:
	# everything about one handoff in one window.
	tools_popup.add_item("Translation Studio…", 21)
	tools_popup.add_item("Lift Report…", 12)
	tools_popup.add_separator()
	tools_popup.add_item("Welcome…", 13)
	tools_popup.add_item("Start the Tour…", 17)
	tools_popup.add_item("Keyboard Shortcuts", 16)
	tools_popup.add_item("Manual…", 22)
	tools_popup.add_item("Report an Issue…", 20)
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
			18: _dock.toggle_behavior_preview()
			19: _dock._open_save_studio()
			12: _dock._open_lift_report()
			13: _dock.show_welcome()
			17: _dock.start_tour()
			16: _dock._open_shortcuts_help()
			22: _dock.open_documentation()
			20: _dock._report_issue()
			21: _dock._open_translation_studio()
			14: _dock._run_diagnostics_action()
	)
	tools_popup.set_item_tooltip(tools_popup.get_item_index(22), "The Manual: the tutorials, the guides, and a reference page for every object and behavior. F1 opens help for whatever is selected; Ctrl+F1 reopens the page you were reading.")
	# The dot: a reader who has not opened What's new since the plugin's version changed gets a mark
	# on the Manual entry, and it comes off the moment they read it. Re-asked every time the menu
	# opens, so reading the page while the menu is closed still clears it.
	tools_popup.about_to_popup.connect(func() -> void:
		var index: int = tools_popup.get_item_index(22)
		if index < 0:
			return
		var version: String = EventSheets.docs_version()
		tools_popup.set_item_text(index,
			"Manual… ●" if EventSheetDocWhatsNew.has_unread(version, EventSheetDocWhatsNew.seen_version()) else "Manual…"))
	tools_popup.set_item_tooltip(tools_popup.get_item_index(21), "The whole handoff to a translator in one window: sweep the project for the text your game shows, read the note each key travels with, merge a returned file and register the catalogs.")
	tools_popup.set_item_tooltip(tools_popup.get_item_index(14), "Lint every ƒx expression + script block; flag the offending rows and jump to the first.")
	tools_popup.set_item_tooltip(tools_popup.get_item_index(0), "Toggle breakpoint emission: debug-compiled sheets pause at rows with breakpoints.")
	tools_popup.set_item_tooltip(tools_popup.get_item_index(1), "Toggle Live Values: running sheets stream their variables here (editable).")
	_toolbar.add_child(tools_menu)
	_add_toolbar_separator(_toolbar)
	# Simple Mode as a persistent, visible pill (not only a buried View-menu check): the audience
	# flag should be one glance to read and one click to flip.
	var simple_button: Button = Button.new()
	simple_button.text = "Simple Mode"
	simple_button.toggle_mode = true
	simple_button.set_pressed_no_signal(_dock._simple_mode)
	simple_button.tooltip_text = "Beginner-friendly view: hides the advanced/code entries (script blocks, sub-conditions, pick filters, signals/enums). Everything still works when off."
	simple_button.toggled.connect(func(on: bool) -> void: _dock.set_simple_mode(on))
	_dock._simple_mode_button = simple_button
	_toolbar.add_child(simple_button)
	# GDScript stays a one-click toggle (the pairing thesis: honest output, always
	# one click away) next to the per-sheet theme picker.
	_add_toolbar_button(_toolbar, "GDScript", _dock._toggle_code_panel, "Toggle the generated-GDScript panel - the sheet's honest compiled output, side by side.", "Script")
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
	# ── Compare / Loose Ends / Find Repeated Rows (appended block - keep together) ──────────────
	# Three "scan, list, jump, fix" tools, which is why they sit beside Project Doctor and Check
	# Sheet for Errors. Each owns its own window, so they live in a lazily-filled dictionary here
	# rather than on the dock: nothing is constructed until the first time one is opened, and a
	# session that never opens them pays nothing. Ids start at 60 so the block above can grow
	# without colliding. A second id_pressed handler is deliberate - the match below simply
	# ignores every id it does not own, exactly as the first handler ignores these.
	var dev_tools: Dictionary = {}
	var open_dev_tool: Callable = func(key: String, factory: Callable) -> void:
		if not dev_tools.has(key):
			var made: Variant = factory.call()
			made.init(_dock)
			dev_tools[key] = made
		dev_tools[key].open()
	tools_popup.add_separator()
	tools_popup.add_item("Compare With…", 60)
	tools_popup.set_item_tooltip(tools_popup.get_item_index(60), "Compare this sheet against its last save, a backup, or another sheet - in rows, not in generated code. A row that only exists on the other side can be brought over in one undo step.")
	tools_popup.add_item("Loose Ends…", 61)
	tools_popup.set_item_tooltip(tools_popup.get_item_index(61), "Everything you left unfinished, indexed: TODO/FIXME notes, disabled rows, events with no actions, breakpoints left on, functions nothing calls. Nothing is drawn on the sheet - click an entry to jump to the row.")
	tools_popup.add_item("Find Repeated Rows…", 62)
	tools_popup.set_item_tooltip(tools_popup.get_item_index(62), "Find action sequences written more than once, then turn one into a reusable function: extracted where it first appears, called everywhere else, in one undo step.")
	tools_popup.id_pressed.connect(func(id: int) -> void:
		match id:
			60: open_dev_tool.call("compare", func() -> Variant: return EventSheetCompareDialog.new())
			61: open_dev_tool.call("loose_ends", func() -> Variant: return EventSheetLooseEndsPanel.new())
			62: open_dev_tool.call("repeated", func() -> Variant: return EventSheetRepeatedRows.new())
	)
	# The persisted Simple Mode preference loads before the toolbar builds - apply its gates now.
	_dock._apply_simple_mode_gates()
	# ── Row Hit Counts + Reset Hit Counts (appended block - keep together) ─────────────────────
	# The Event Trace lens, made switchable. Row Hit Counts sits beside Event Numbers because it is
	# the same question about the same margin ("what is this row's number" / "how often did it
	# run"), and it is added UNCHECKED on purpose: a count on every row is noise 95% of the time,
	# so the counts are kept always and drawn only when asked for. Reset Hit Counts joins the Event
	# Trace entry it belongs to. Ids 9601/9602 are clear of every block above; a third id_pressed
	# handler is deliberate - each ignores the ids it does not own.
	view_popup.add_check_item("Row Hit Counts", _dock.HIT_COUNTS_VIEW_ID)
	view_popup.set_item_checked(view_popup.get_item_index(_dock.HIT_COUNTS_VIEW_ID), false)
	view_popup.set_item_tooltip(view_popup.get_item_index(_dock.HIT_COUNTS_VIEW_ID),
		"Show how many times each event has fired since Run, as a small chip in the left margin - warm for the busiest rows, x0 and a dim rail for rows that never fired. Off by default; your rows are never touched. Needs Tools > Event Trace and a running game. You can also just hover an event number.")
	view_popup.id_pressed.connect(func(id: int) -> void:
		if id == _dock.HIT_COUNTS_VIEW_ID:
			_dock._toggle_row_hit_counts(view_popup))
	tools_popup.add_item("Reset Hit Counts", 9602)
	tools_popup.set_item_tooltip(tools_popup.get_item_index(9602),
		"Start the Event Trace's per-row tally over without restarting the game - reset, do the thing you are testing, and see exactly which rows moved.")
	tools_popup.id_pressed.connect(func(id: int) -> void:
		if id == 9602:
			_dock._reset_row_hit_counts())
	# ── Run Tests… (appended block - keep together) ────────────────────────────────────────────
	# Test sheets, run and reported. It belongs beside Test Bench: that item plays a behavior and
	# tells you nothing, this one runs every Test sheet in the project and says what each claim
	# said. The window is the whole output - no row is marked, ever. Id 9701 is clear of every
	# block above; a separate id_pressed handler keeps this block trivially mergeable.
	tools_popup.add_item("Run Tests…", 9701)
	tools_popup.set_item_tooltip(tools_popup.get_item_index(9701),
		"Run every Test sheet in the project and show what each claim said - pass, fail, and why. The same run happens headlessly with: godot --headless --script tools/run_test_sheets.gd. Nothing is drawn on your sheets.")
	tools_popup.id_pressed.connect(func(id: int) -> void:
		if id == 9701:
			_open_run_tests())


## The View menu's collapse sweeps, aimed at whichever view is active (split/detached panes
## each keep their own collapse state). `level` 0 collapses everything, -1 expands
## everything, and anything above 0 reads the sheet down to that depth.
func _collapse_sweep(level: int) -> void:
	var view: EventSheetViewport = _dock._active_view()
	if view == null:
		return
	if level < 0:
		view.expand_all()
	elif level == 0:
		view.collapse_all()
	else:
		view.expand_to_level(level)


## The Run Tests… window, built the first time it is asked for and kept afterwards. Loaded by path
## so the editor's boot path never carries it (the boot-lazy gate) and nothing here names the class.
var _test_report_panel: RefCounted = null


func _open_run_tests() -> void:
	if _test_report_panel == null:
		_test_report_panel = load("res://addons/eventsheet/editor/dock/test_report_panel.gd").new()
		_test_report_panel.init(_dock)
	_test_report_panel.open()


## Adds a one-click toolbar button wired to `callable`, with an optional editor icon.
## Returns the button so callers that need to gate/restyle it can keep a reference.
## (Moved verbatim from the dock; targets the toolbar passed in rather than a member.)
func _add_toolbar_button(toolbar: HFlowContainer, text: String, callable: Callable, tooltip: String = "", editor_icon: String = "") -> Button:
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
	return button


func _add_toolbar_separator(toolbar: HFlowContainer) -> void:
	var sep: VSeparator = VSeparator.new()
	toolbar.add_child(sep)
