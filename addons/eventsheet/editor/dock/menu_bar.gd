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


## This file's own path, so a control it builds can say where it was built. Written out rather
## than derived, because a RefCounted helper has no script path to ask for at the point it matters.
const THIS_FILE_PATH: String = "res://addons/eventsheet/editor/dock/menu_bar.gd"


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
	sheet_popup.add_item("Import event sheet…", 18)
	sheet_popup.set_item_tooltip(
		sheet_popup.get_item_index(18),
		"Bring a sheet over from another event-sheet editor. Pick the project it saved or one exported sheet, say which node each object became, and see exactly what came across - every row the vocabulary knows becomes the row that says the same thing, and every row it does not arrives switched off with its own words beside it. Nothing is written until you choose Save as…"
	)
	sheet_popup.add_item("Save as Text…", 16)
	sheet_popup.set_item_tooltip(
		sheet_popup.get_item_index(16),
		"Write the whole sheet as a plain listing in its own words - \"+ \" for a condition, \"-> \" for an action, indented by sub-event, event numbers on - ready to paste into an issue, a design doc or a chat."
	)
	sheet_popup.add_separator()
	sheet_popup.add_item("Sheet Type…", 4)
	# A shared sheet is a script whose whole job is to be included. The wiring question
	# ("as a base class" / "as a helper") is asked ONCE, when the shared sheet is made, and never
	# again per includer.
	sheet_popup.add_item("New shared sheet…", 19)
	sheet_popup.set_item_tooltip(
		sheet_popup.get_item_index(19),
		"Write events once and include them in many scripts. You choose here how it is wired: as a base class (the including script extends it) or as a helper (the including script keeps one of it and forwards its triggers to it)."
	)
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
	sheet_popup.add_separator()
	# The Start page. It opens by itself when the workspace has nothing in it; this is how a
	# reader gets back to it afterwards.
	sheet_popup.add_item("Start page", 17)
	sheet_popup.set_item_tooltip(sheet_popup.get_item_index(17),
		"Templates by genre, what you had open last, and the tutorials - on one page.")
	sheet_popup.id_pressed.connect(func(id: int) -> void:
		match id:
			17: _dock._open_start_page()
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
			18: _dock._import_sheet_wizard.open()
			16: _dock._save_sheet_as_text_requested()
			19: _dock._shared_sheets.open_new_shared_sheet()
	)
	_toolbar.add_child(sheet_menu)
	_add_toolbar_button(_toolbar, "Save", _dock._on_save_requested, "Save the sheet - compile-on-save keeps its generated script fresh (Ctrl+S).", "Save")
	_add_toolbar_button(_toolbar, "Run Scene", _dock._run_from_sheet, "Save, then play the scene that uses this sheet's script.", "Play")
	# Testing a networked game needs two copies of it running. Godot can already do that; this
	# button is the one that finds the setting for you and says in its tooltip how to take it back.
	_add_toolbar_button(_toolbar, "Play as host + client", _dock._play_as_host_and_client,
		EventSheetRunInstances.tooltip(), "Play")
	# Preview on the SHEET. The keys stay Godot's (F6 / F5) and the names are the ones an
	# author coming from another event-sheet editor reaches for; while a game runs the first two
	# relabel themselves Stop / Restart, so the strip never claims it will do something it will not.
	for preview_entry: Variant in EventSheetRunControls.BUTTONS:
		var preview: Array = preview_entry
		var preview_id: String = str(preview[0])
		_dock._run_controls.adopt(preview_id, _add_toolbar_button(_toolbar,
			str(preview[1]), func() -> void: _dock._run_controls.activate(preview_id), str(preview[2])))
	_dock._run_controls.refresh()
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
	# The sheet's own members are INSTANCE variables of the object the file is; a GLOBAL is
	# one value the whole project shares, and lives on an autoload. Two different things, so two
	# items, each named the thing it makes.
	add_popup.add_item("Instance Variable…", 1)
	add_popup.add_item("Local Variable…", 2)
	add_popup.add_item("Global Variable… (V)", 8)
	add_popup.add_item("Function…", 3)
	# The other half of the shared-sheet gesture. How it is wired was decided by the shared
	# sheet itself, so this asks nothing: pick the sheet, and the rows that wire it are written.
	add_popup.add_item("Include sheet…", 10)
	add_popup.add_separator()
	# The three event-shape commands, on the Add menu as well as the right-click menu: the sheet
	# reads Or blocks, blank sub-events and Else, so all three must be typeable in the same words.
	add_popup.add_item("Add blank sub-event (B)", 5)
	add_popup.add_item("Make 'Or' block", 6)
	add_popup.add_item("Add 'Else'", 7)
	add_popup.add_separator()
	# The shapes a game is made of, as events. The patterns the sheet can READ it can also
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
			10: _dock._shared_sheets.open_include_sheet()
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
	# The two project-level surfaces a beginner (or a migrating author) gets by default
	# and everyone else turns on by hand. Both are off unless Simple mode or a template start asked
	# for them, and both remember the choice per project.
	view_popup.add_check_item("Project bar", _dock.PROJECT_BAR_VIEW_ID)
	view_popup.set_item_tooltip(view_popup.get_item_index(_dock.PROJECT_BAR_VIEW_ID),
		"The project by KIND - scenes, scripts, classes, base classes, behaviors, sounds, files - as a tab of the Object bar. Read only: every entry opens something you already have.")
	view_popup.add_check_item("Add toolbar", _dock.ADD_TOOLBAR_VIEW_ID)
	view_popup.set_item_tooltip(view_popup.get_item_index(_dock.ADD_TOOLBAR_VIEW_ID),
		"The eight ways to add something, as buttons above the canvas, each naming its key on hover. On in Simple mode.")
	view_popup.id_pressed.connect(func(id: int) -> void:
		if id == _dock.PROJECT_BAR_VIEW_ID:
			_dock._toggle_project_bar()
		elif id == _dock.ADD_TOOLBAR_VIEW_ID:
			_dock._toggle_add_toolbar())
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
	# Id 46, NOT 27: 27 is the Patterns lens four lines up. Sharing it left this item dead (a match
	# takes its first arm) and wrote this tick and this tooltip onto Patterns instead.
	view_popup.add_check_item("Minimap", 46)
	view_popup.set_item_checked(view_popup.get_item_index(46), _dock._minimap_enabled())
	view_popup.set_item_tooltip(view_popup.get_item_index(46), "A picture of the whole sheet down the right edge: one bar per event tinted by what it is, the part you are looking at as a box you can drag, and your bookmarks in the margin. On by default once a sheet passes 200 events.")
	view_popup.add_item("Sheet Map…", 28)
	view_popup.set_item_tooltip(view_popup.get_item_index(28), "Which sheets, scenes and globals call, signal and include which - the shape of the project's logic on one page.")
	view_popup.add_item("History…", 29)
	view_popup.set_item_tooltip(view_popup.get_item_index(29), "Every edit you have made to this sheet, in the sheet's own words. Click one to undo or redo back to it.")
	view_popup.add_item("Ask…", 42)
	view_popup.set_item_tooltip(view_popup.get_item_index(42), "Say what you want to happen and read back proposed events. Off until you turn it on in Project Settings; nothing is sent until you press Ask, and nothing is added until you say so.")
	view_popup.add_separator()
	view_popup.add_check_item("Reduced Motion", 43)
	view_popup.set_item_checked(view_popup.get_item_index(43), EventSheetAccessibility.reduced_motion())
	view_popup.set_item_tooltip(view_popup.get_item_index(43), "No pulses and no fades anywhere in the editor. Everything still says what it said - it just says it at once.")
	view_popup.add_item("Speak This Row", 44)
	view_popup.set_item_tooltip(view_popup.get_item_index(44), "Read the selected row's sentence aloud - the same words the row is drawn with.")
	view_popup.add_item("Object Properties", 45)
	view_popup.set_item_tooltip(view_popup.get_item_index(45), "Open the Object properties for the object the selected row names - the keyboard twin of clicking its name.")
	view_popup.add_separator()
	# Collapsing IS how a long sheet is browsed, so the sweeps live in the menu beside the
	# Outline, not only on their shortcuts.
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
	# Id 30, NOT 20: 20 is Humanized Names, and sharing it put this tooltip on that item.
	view_popup.add_submenu_item("Preview In Language", "EventSheetPreviewLanguageMenu", 30)
	view_popup.set_item_tooltip(view_popup.get_item_index(30), "Read the sheet in one of your GAME's languages while you author it - the rows show the translation instead of tr(\"…\"). Your sheet is not touched, but Godot's Locale > Test setting is set (that is what makes the next Play run in it); pick \"As authored\" to clear it again.")
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
			46: _dock._toggle_minimap(view_popup)
			28: _dock._open_sheet_map_panel()
			29: _dock._open_history_panel()
			42: _dock._open_ask()
			43: _dock._toggle_reduced_motion(view_popup)
			44: _dock._speak_selected_row()
			45: _dock._open_properties_for_selected_row()
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
	tools_popup.add_item("Project View…", 24)
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
	tools_popup.add_item("Addon manager…", 23)
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
			24: _dock._open_project_view()
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
			23: _dock.open_addon_manager()
	)
	tools_popup.set_item_tooltip(tools_popup.get_item_index(24), "Every open sheet on one page - how big each is, how much of it is described, what the Doctor said about it - plus a search that reaches all of them and the page each sheet writes about itself.")
	tools_popup.set_item_tooltip(tools_popup.get_item_index(23), "Every installed pack with its version: enable or disable one, read its guide, check for updates, import a pack from a .zip or a URL, or publish yours.")
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
	# Settings ▾ - the choices that are the reader's, not the project's. Words is the first: the
	# whole vocabulary the sheet lets you choose, on one page.
	var settings_menu: MenuButton = MenuButton.new()
	settings_menu.text = "Settings"
	settings_menu.tooltip_text = "Your own choices, stored with the editor settings rather than the project."
	settings_menu.flat = false
	var settings_popup: PopupMenu = settings_menu.get_popup()
	settings_popup.add_item("Words…", 0)
	settings_popup.set_item_tooltip(settings_popup.get_item_index(0), "Every word the sheet lets you choose, on one page, with a live preview of an event in them.")
	settings_popup.id_pressed.connect(func(id: int) -> void:
		match id:
			0: _dock.open_words_settings()
	)
	_toolbar.add_child(settings_menu)
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
	# Every menu on the strip remembers this file too, so "where is this menu made" is the same
	# gesture as "where is this button made". One sweep rather than a mark beside each `MenuButton`,
	# because a mark that has to be remembered at eleven call sites is a mark that goes stale.
	for child: Node in _toolbar.get_children():
		if child is MenuButton:
			EventSheetBuiltHere.mark(child as Control, THIS_FILE_PATH, (child as MenuButton).text)
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
	# ── The costs half of the same gutter (appended block - keep together) ─────────────────────
	# Counts say how OFTEN a row ran; costs say what one run of it took. One chip shows one of them,
	# the tooltip both, and the toggle sits beside its sibling because it is the same margin and the
	# same question asked the other way. Ids 9605/9606/9607 are clear of every block above.
	view_popup.add_check_item("Costs In The Sheet", _dock.COSTS_VIEW_ID)
	view_popup.set_item_checked(view_popup.get_item_index(_dock.COSTS_VIEW_ID), false)
	view_popup.set_item_tooltip(view_popup.get_item_index(_dock.COSTS_VIEW_ID),
		"Show what one fire of each event costs, in milliseconds, in the left margin - amber over 1 ms, red over 4. The numbers come from the last profiled run (this session's or the one before it); nothing is ever measured in the editor.")
	view_popup.id_pressed.connect(func(id: int) -> void:
		if id == _dock.COSTS_VIEW_ID:
			_dock._toggle_row_costs(view_popup))
	tools_popup.add_item("Run With Profiler", 9606)
	tools_popup.set_item_tooltip(tools_popup.get_item_index(9606),
		"Arm the Event Trace and play this layout. Play for a while, stop, and every row wears what it cost - kept until you clear it, and still there next time you open the editor.")
	tools_popup.add_item("Optimise This Sheet…", 9608)
	tools_popup.set_item_tooltip(tools_popup.get_item_index(9608),
		"Every classic way this sheet spends a frame it did not have to, with the fix beside it. The safe ones apply together as one undo step; the rest open one at a time, showing what would change before anything does.")
	tools_popup.add_item("Clear Measured Costs", 9607)
	tools_popup.set_item_tooltip(tools_popup.get_item_index(9607),
		"Forget every measured number - this session's and the stored run's - and put the gutter back to event numbers.")
	tools_popup.id_pressed.connect(func(id: int) -> void:
		if id == 9606:
			_dock._run_with_profiler()
		elif id == 9607:
			_dock._clear_measured_costs()
		elif id == 9608:
			_dock.open_optimiser())
	# ── Run Tests… (appended block - keep together) ────────────────────────────────────────────
	# Test sheets, run and reported. It belongs beside Test Bench: that item plays a behavior and
	# tells you nothing, this one runs every Test sheet in the project and says what each claim
	# said. The window is the whole output - no row is marked, ever. Id 9701 is clear of every
	# block above; a separate id_pressed handler keeps this block trivially mergeable.
	# ── Live edit + the replay recorder (appended block - keep together) ───────────────────────
	# The toggle sits with the other view choices because it is one: whether an edit made while the
	# game runs lands on its own or waits for the ⟳ on the status strip. The window sits beside Run
	# Tests… because what it writes IS a Test sheet. Ids 9801/9802 are clear of every block above.
	view_popup.add_check_item("Auto-apply while debugging", 9801)
	view_popup.set_item_checked(view_popup.get_item_index(9801), EventSheetLiveEdit.auto_apply_enabled())
	view_popup.set_item_tooltip(view_popup.get_item_index(9801),
		"While a game is running, every edit is applied to it the moment you make it, instead of waiting for ⟳ Apply to running game (Ctrl+Alt+S). A change a live reload cannot carry still stops and says so.")
	view_popup.id_pressed.connect(func(id: int) -> void:
		if id != 9801:
			return
		EventSheetLiveEdit.set_auto_apply_enabled(not EventSheetLiveEdit.auto_apply_enabled())
		view_popup.set_item_checked(view_popup.get_item_index(9801), EventSheetLiveEdit.auto_apply_enabled()))
	tools_popup.add_item("Replay Recorder…", 9802)
	tools_popup.set_item_tooltip(tools_popup.get_item_index(9802),
		"Record a play and keep it as a test: every control the running game sees is captured with its frame, and Stop writes it as an ordinary Test sheet you can read, edit and replay - here or headlessly.")
	tools_popup.id_pressed.connect(func(id: int) -> void:
		if id == 9802:
			_open_replay_recorder())
	tools_popup.add_item("Run Tests…", 9701)
	tools_popup.set_item_tooltip(tools_popup.get_item_index(9701),
		"Run every Test sheet in the project and show what each claim said - pass, fail, and why. The same run happens headlessly with: godot --headless --script tools/run_test_sheets.gd. Nothing is drawn on your sheets.")
	tools_popup.id_pressed.connect(func(id: int) -> void:
		if id == 9701:
			_open_run_tests())
	# ── Arrange by… + Saved Views (appended block - keep together) ─────────────────────────────
	# Two submenus on View, wired the explicit way (a named child PopupMenu plus add_submenu_item
	# with its OWN id) - never an id-less add_submenu_item. Both rebuild on open, so the
	# arrangement radio always shows the live one and a view saved a second ago is already listed.
	# Ids 9807/9802: "clear of every block above" was true of 9801/9802 when this block was written
	# and false by the time three blocks had each claimed them, which is what menu_id_collision_test
	# now catches. Every appended block picks the next number the View menu has never used.
	var arrange_menu: PopupMenu = PopupMenu.new()
	arrange_menu.name = "EventSheetArrangeMenu"
	view_popup.add_child(arrange_menu)
	view_popup.add_submenu_item("Arrange by", "EventSheetArrangeMenu", 9807)
	view_popup.set_item_tooltip(view_popup.get_item_index(9807),
		"Read the same events re-grouped under headers - by the object they talk about, by the trigger they hang off, or by the group they sit in. Display only: the file is never reordered and every event keeps its number.")
	arrange_menu.about_to_popup.connect(func() -> void:
		arrange_menu.clear()
		var active_mode: int = _dock.arrangement_mode()
		for mode: int in EventSheetArrangement.MODE_IDS.size():
			arrange_menu.add_radio_check_item(EventSheetL10n.translate(EventSheetArrangement.mode_label(mode)), mode)
			arrange_menu.set_item_checked(mode, mode == active_mode))
	arrange_menu.id_pressed.connect(func(mode: int) -> void: _dock.set_arrangement_mode(mode))
	# ── View ▸ Variable rows (appended block - keep together) ──────────────────────────────────
	# How much of a variable row is drawn: the sentence a beginner reads, the sentence with the
	# declaration echoed beside it (the shipped default), or the declaration as the whole row. A
	# toolbar setting, never a row on the sheet. Id 9813 is the next number the View menu has never
	# used; the submenu's radio ids are its own private range, rebuilt on every open.
	var variable_view_menu: PopupMenu = PopupMenu.new()
	variable_view_menu.name = "EventSheetVariableViewMenu"
	view_popup.add_child(variable_view_menu)
	view_popup.add_submenu_item("Variable rows", "EventSheetVariableViewMenu", 9813)
	view_popup.set_item_tooltip(view_popup.get_item_index(9813),
		"How much of a variable row to draw: the sentence on its own, the sentence with the GDScript declaration echoed at the right edge, or that declaration as the whole row. Display only - the file is never touched. Simple Mode keeps it on sentence.")
	variable_view_menu.about_to_popup.connect(func() -> void:
		variable_view_menu.clear()
		var active_view_mode: int = _dock.variable_row_view()
		for mode: int in EventSheetCodeEcho.VIEW_LABELS.size():
			variable_view_menu.add_radio_check_item(
				EventSheetL10n.translate(EventSheetCodeEcho.VIEW_LABELS[mode]), mode)
			variable_view_menu.set_item_checked(mode, mode == active_view_mode))
	variable_view_menu.id_pressed.connect(func(mode: int) -> void: _dock.set_variable_row_view(mode))
	var views_menu: PopupMenu = PopupMenu.new()
	views_menu.name = "EventSheetSavedViewsMenu"
	view_popup.add_child(views_menu)
	view_popup.add_submenu_item("Saved Views", "EventSheetSavedViewsMenu", 9802)
	view_popup.set_item_tooltip(view_popup.get_item_index(9802),
		"A named way of reading this sheet - its arrangement, its filter and its reading lenses saved together, and put back in one click.")
	views_menu.about_to_popup.connect(func() -> void:
		views_menu.clear()
		views_menu.add_item(EventSheetL10n.translate("Save Current View…"), 0)
		var names: PackedStringArray = EventSheetSavedViews.view_names()
		if names.is_empty():
			return
		views_menu.add_separator()
		for name_index: int in names.size():
			views_menu.add_item(names[name_index], 100 + name_index)
		views_menu.add_separator()
		for name_index: int in names.size():
			views_menu.add_item(EventSheetL10n.translate("Forget %s") % names[name_index], 500 + name_index))
	views_menu.id_pressed.connect(func(id: int) -> void:
		var names: PackedStringArray = EventSheetSavedViews.view_names()
		if id == 0:
			_dock.save_current_view_requested()
		elif id >= 500 and id - 500 < names.size():
			_dock.delete_saved_view(names[id - 500])
		elif id >= 100 and id - 100 < names.size():
			_dock.apply_saved_view(names[id - 100]))
	# ── Sheet ▸ Health… (appended block - keep together) ───────────────────────────────────────
	# How this sheet is doing, at a glance, with every line clicking through to the panel behind it.
	# Id 9812 is clear of the Sheet menu's own run.
	sheet_popup.add_item("Health…", 9812)
	sheet_popup.set_item_tooltip(sheet_popup.get_item_index(9812),
		"How this sheet is doing in one card: how much of it reads as events, its patterns and which of them a shipped behavior could take over, what the Doctor says, its Test Sheets and how they last went, and how much of it nothing uses. Click a line to open the panel it comes from.")
	sheet_popup.id_pressed.connect(func(id: int) -> void:
		if id == 9812:
			_dock.open_sheet_health())
	# ── Sheet ▸ Export (appended block - keep together) ────────────────────────────────────────
	# The sheet as a picture, for a forum post, a design doc or a lesson: the canvas exactly as it is
	# being read. Id 9811 is clear of the Sheet menu's own run; the submenu's ids are its own.
	var export_menu: PopupMenu = PopupMenu.new()
	export_menu.name = "EventSheetExportMenu"
	sheet_popup.add_child(export_menu)
	sheet_popup.add_submenu_item("Export", "EventSheetExportMenu", 9811)
	sheet_popup.set_item_tooltip(sheet_popup.get_item_index(9811),
		"The whole sheet as a picture - the current theme, density, arrangement and lenses, with the event numbers on. PDF is that picture split into pages; Markdown is the plain listing with a figure per group.")
	export_menu.add_item(EventSheetL10n.translate("Image (PNG)…"), 0)
	export_menu.add_item(EventSheetL10n.translate("PDF…"), 1)
	export_menu.add_item(EventSheetL10n.translate("Markdown with figures…"), 2)
	export_menu.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			_dock.export_sheet_picture_requested("png")
		elif id == 1:
			_dock.export_sheet_picture_requested("pdf")
		elif id == 2:
			_dock.export_sheet_picture_requested("md"))
	# ── Sheet ▸ Workspaces (appended block - keep together) ────────────────────────────────────
	# A scene's sheets, opened together and remembered under the scene's name. Rebuilt on open so a
	# workspace made a second ago is already listed. Id 9810 is clear of the Sheet menu's own run.
	var workspaces_menu: PopupMenu = PopupMenu.new()
	workspaces_menu.name = "EventSheetWorkspacesMenu"
	sheet_popup.add_child(workspaces_menu)
	sheet_popup.add_submenu_item("Workspaces", "EventSheetWorkspacesMenu", 9810)
	sheet_popup.set_item_tooltip(sheet_popup.get_item_index(9810),
		"A scene's sheets, open together: the whole layout plus every script in it, in tree order, as one named tab group. Right-click a scene in the FileSystem ▸ Open its sheets makes one; picking it here opens it again.")
	workspaces_menu.about_to_popup.connect(func() -> void:
		workspaces_menu.clear()
		var names: PackedStringArray = EventSheetWorkspaces.workspace_names()
		if names.is_empty():
			workspaces_menu.add_item(EventSheetL10n.translate("No workspaces yet"), -1)
			workspaces_menu.set_item_disabled(0, true)
			return
		for name_index: int in names.size():
			workspaces_menu.add_item(names[name_index], 100 + name_index)
		workspaces_menu.add_separator()
		for name_index: int in names.size():
			workspaces_menu.add_item(EventSheetL10n.translate("Forget %s") % names[name_index], 500 + name_index))
	workspaces_menu.id_pressed.connect(func(id: int) -> void:
		var names: PackedStringArray = EventSheetWorkspaces.workspace_names()
		if id >= 500 and id - 500 < names.size():
			_dock.forget_workspace(names[id - 500])
		elif id >= 100 and id - 100 < names.size():
			_dock.open_workspace(names[id - 100]))
	# ── Show Events in the Scene (appended block - keep together) ──────────────────────────────
	# The events overlay's switch. It marks the SCENE, not the sheet, which is why it is one item
	# rather than a lens - and it starts off. Id 9803 is clear of every block above.
	view_popup.add_check_item("Show Events in the Scene", 9803)
	view_popup.set_item_checked(view_popup.get_item_index(9803), EventSheetSceneEvents.is_enabled())
	view_popup.set_item_tooltip(view_popup.get_item_index(9803),
		"Mark every node whose script is a sheet with a small ⌗ and its event count - in the Scene dock, and beside the node in the 2D editor. Hover names its triggers. Nodes with no events are unmarked, and this is off by default.")
	view_popup.id_pressed.connect(func(id: int) -> void:
		if id != 9803:
			return
		var wanted: bool = not EventSheetSceneEvents.is_enabled()
		EventSheetSceneEvents.set_enabled(wanted)
		view_popup.set_item_checked(view_popup.get_item_index(9803), wanted)
		_dock._set_status(EventSheetL10n.translate("Events in the scene: on") if wanted
			else EventSheetL10n.translate("Events in the scene: off")))
	# ── Follow Scene Selection (appended block - keep together) ────────────────────────────────
	# The Scene dock and the sheet on one selection. Ticked by default, because that is what the
	# reader who came from an editor where the layout and the sheet were one surface expects; the
	# item exists because somebody working on one row while clicking around a scene reasonably
	# wants it off. Backed by the project setting, so the choice survives the session. Id 9805 is
	# the next number the View menu has never used - 9801 is Auto-apply while debugging, and while
	# this item shared it a click on either toggled BOTH settings.
	view_popup.add_check_item("Follow Scene Selection", 9805)
	view_popup.set_item_checked(view_popup.get_item_index(9805),
		EventSheetSceneSelectionLink.follow_enabled())
	view_popup.set_item_tooltip(view_popup.get_item_index(9805),
		"Keep the Scene dock and the sheet on one selection: picking a node highlights it on the Object bar and offers to filter the sheet's events to it, and picking a row selects the node that row is about. Right-click a node in the Scene dock for Show events.")
	view_popup.id_pressed.connect(func(id: int) -> void:
		if id == 9805:
			_dock._toggle_follow_scene_selection(view_popup))
	# ── Debugger (appended block - keep together) ──────────────────────────────────────────────
	# One window over four seams that already shipped: Inspect (the Live Values stream, per object),
	# Watch (the same watch list this dock already keeps), Profile (the Event Trace timings) and
	# Breakpoints (the F9 rows). It sits on View rather than on Tools because it SHOWS rather than
	# switches - the three Tools toggles that arm the streams stay exactly where they were. Id 9806
	# is the next number the View menu has never used; 9802 is the Saved Views submenu, and sharing
	# it wrote this tooltip onto Saved Views.
	view_popup.add_item("Debugger…", 9806)
	view_popup.set_item_tooltip(view_popup.get_item_index(9806),
		"One window with four tabs: Inspect (every object's live values, editable), Watch, Profile (time per event) and Breakpoints. Needs a debug run - Tools ▸ Live Values and Tools ▸ Event Trace arm the streams it reads.")
	view_popup.id_pressed.connect(func(id: int) -> void:
		if id == 9806:
			_dock.open_debugger())


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


## The Replay Recorder window, built the first time it is asked for and kept afterwards. Loaded by
## path so the editor's boot path never carries it.
var _replay_recorder_panel: RefCounted = null


func _open_replay_recorder() -> void:
	if _replay_recorder_panel == null:
		_replay_recorder_panel = load("res://addons/eventsheet/editor/dock/replay_recorder_panel.gd").new()
		_replay_recorder_panel.init(_dock)
	_replay_recorder_panel.open()


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
	# The button remembers which of the editor's files made it, so Ctrl+Shift+Alt on it opens
	# that file as a sheet at the row that names these words. Nothing is written outside the editor's
	# own repo, so a game project's toolbar carries no extra bytes.
	EventSheetBuiltHere.mark(button, THIS_FILE_PATH, text)
	toolbar.add_child(button)
	return button


func _add_toolbar_separator(toolbar: HFlowContainer) -> void:
	var sep: VSeparator = VSeparator.new()
	toolbar.add_child(sep)
