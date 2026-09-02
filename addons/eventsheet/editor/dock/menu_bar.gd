@tool
class_name EventSheetMenuBar
extends RefCounted
# The dock's top toolbar + menu bar: the HFlowContainer that flow-wraps the grouped
# Sheet/Add/Edit/View/Tools menus, the high-frequency one-click buttons, and the quick-add
# LineEdit. Assembly only - every menu/button action targets
# a dock method that STAYS on the dock, reached through the `_dock` back-reference (the same
# pattern as the other dock/ helpers). The widgets the dock reads later (_toolbar, _view_popup,
# _quick_add_edit) stay DECLARED on the dock; build() constructs them and assigns
# them back so nothing else changes. Extracted from event_sheet_dock.gd to keep that file
# maintainable; the menus keep their .name + item order so the dock's tests find them unchanged.

var _dock: Control = null


## This file's own path, so a control it builds can say where it was built. Written out rather
## than derived, because a RefCounted helper has no script path to ask for at the point it matters.
const THIS_FILE_PATH: String = "res://addons/eventsheet/editor/dock/menu_bar.gd"

## Where the "show every button" choice is remembered, in the same editor-settings project
## metadata section every other per-project editor choice uses. The default is REST, for every
## project including one that already exists - nothing is migrated, because there was no
## resting/expanded choice to migrate.
const FULL_TOOLBAR_META_KEY: String = "eventsheets_full_toolbar"

## The View menu's mirror of the chevron. A number the View menu has never used.
const FULL_TOOLBAR_VIEW_ID: int = 9814

## View ▸ Sheet theme, the home of the per-sheet theme picker that used to be an OptionButton on
## the strip. The next number the View menu has never used.
const SHEET_THEME_VIEW_ID: int = 9815

## Where "this project has already been told the strip rests" is remembered, in the same editor
## settings project metadata section every other per-project editor choice uses. Read with a NON-null
## sentinel default, because a missing key with a null default prints an editor ERROR.
const RESTING_NOTE_META_KEY: String = "eventsheets_resting_note_seen"

## The one-time note itself, said in the status bar the first time a project with sheets already in
## it opens on the resting strip. Held as a constant so the suite pins the words rather than a
## paraphrase of them.
const RESTING_NOTE: String = "The toolbar is resting: every button is under Menu or the chevron, keys unchanged. View > Full toolbar brings it all back."

## The controls the strip shows AT REST, in reading order: the one cascading Menu, the save/undo/redo
## icons, the play button's slot, the Quick add field, and the chevron that expands the rest. Held as
## node references rather than indices, because the strip's order is edited by every pass that
## touches it and an index list goes stale silently.
var _resting_controls: Array = []

## Whether this session has already said the one-time resting note. The durable answer is the
## project metadata beside it; this is what keeps a session that has no EditorSettings to write to
## (a headless run, a test) from repeating the note on every sheet it opens.
var _resting_note_said: bool = false

## The chevron itself, and the strip it expands.
var _expander: Button = null
var _toolbar_ref: HFlowContainer = null
var _full_toolbar: bool = false

## The reader's OWN choice, which is not always what the strip is showing. Something can expand the
## strip for a moment without that being a decision - a Manual link pointing at a button that rests
## hidden, say - and a moment must never overwrite a preference. Only set_full_toolbar moves this,
## and only this is written to the project's metadata.
var _remembered_full_toolbar: bool = false

## The two history icons, kept so their disabled state can follow the undo history the way Godot's
## own toolbars do.
var _undo_button: Button = null
var _redo_button: Button = null

## The View menu, kept so the chevron and the menu item stay one choice shown twice.
var _view_popup_ref: PopupMenu = null

## The split play button that fills the strip's play slot: one face for the run this project chose,
## one narrow dropdown for all six. Kept so the dock and the suite can reach the face and its menu.
var _play_button: EventSheetPlayButton = EventSheetPlayButton.new()


func init(dock: Control) -> void:
	_dock = dock


## Builds the toolbar + menu bar and adds it as the FIRST child of `root` (the workspace
## VBox), exactly where the dock used to inline this. Assigns _toolbar/_view_popup/
## _quick_add_edit back onto the dock during the build, before any reader runs.
func build(root: Node) -> void:
	var _toolbar: HFlowContainer = HFlowContainer.new()
	_toolbar.name = "EventSheetToolbar"
	_toolbar.add_theme_constant_override("h_separation", 4)
	_dock._toolbar = _toolbar
	_toolbar_ref = _toolbar
	root.add_child(_toolbar)

	# ── THE STRIP AT REST ──────────────────────────────────────────────────────────────────────
	# One cascading Menu, three icons, the play button, Quick add, and a chevron. Every command the
	# strip used to front is still here - it moved into the Menu, and the chevron brings the whole
	# strip back. Nothing was removed: every retired control keeps its key and its in-sheet door.
	#
	# ☰ Menu ▾ - Sheet, Add, Edit, View and Tools as cascading submenus of ONE button. Each carries
	# the name, the items in their order, the ids and the handlers the MenuButton it replaces
	# carried, so every item id, handler, dynamic submenu and printed key answers untouched - held
	# item by item by the suite rather than claimed here.
	var menu_button: MenuButton = MenuButton.new()
	menu_button.name = "EventSheetMenu"
	menu_button.text = "☰ Menu"
	# The hover names the groups the button actually opens. It said "four groups" and left Add out,
	# because Add joined the cascade after this line was written - so a reader hovering the one
	# button on the strip was told about a menu that is not the one underneath it. The suite derives
	# the list from this popup's own submenus, so the next group to join fails that check by name.
	menu_button.tooltip_text = "Every command in the editor, in five groups: Sheet, Add, Edit, View and Tools."
	menu_button.flat = false
	# TAB REACHES IT. A MenuButton defaults to FOCUS_ACCESSIBILITY, which means the focus ring skips
	# it entirely - so the one button holding the whole command tree could only be reached with a
	# mouse or through the Ctrl+P palette. Enter opens the cascade from the keyboard once it can be
	# focused, because that is what a focused MenuButton already does with ui_accept.
	menu_button.focus_mode = Control.FOCUS_ALL
	var menu_popup: PopupMenu = menu_button.get_popup()
	_toolbar.add_child(menu_button)

	# Sheet ▸ - file lifecycle + identity (low frequency, one menu).
	var sheet_popup: PopupMenu = PopupMenu.new()
	sheet_popup.name = "EventSheetSheetMenu"
	menu_popup.add_child(sheet_popup)
	menu_popup.add_submenu_node_item("Sheet", sheet_popup, 0)
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
	# THE MENU TEACHES ITS KEYS. Every entry in this group that has a binding in the ONE shortcut
	# table prints it, through the same hint_key seam the right-click menus and the Add menu use - a
	# hint only, never a second listener, because the keys are already routed in the viewport. An
	# entry with no binding (New…, Export GDScript…, the wizards) simply says what it does.
	for keyed: Variant in [[1, "open"], [2, "save"], [3, "save_as"]]:
		var sheet_keyed: Array = keyed
		EventSheetContextMenus.hint_key(sheet_popup, int(sheet_keyed[0]),
			EventSheetShortcuts.binding_for(str(sheet_keyed[1])))
	# ── THE ICON STRIP ─────────────────────────────────────────────────────────────────────────
	# Save, Undo, Redo, as icon-only buttons wearing the editor's own icons. Every tooltip prints its
	# key from the ONE shortcut table, so a rebound key shows its new binding here without an edit.
	# Undo and Redo are new controls, not new powers: both gestures already existed on their keys and
	# on the Edit menu, and both call the dock's undo funnel, exactly as those do.
	#
	# Godot 4.7 ships Save and Redo but NO Undo, so the strip read "[save icon] Undo [redo icon]"
	# until the icon seam started deriving the missing arrow from its twin. Undo and Redo also name
	# the glyph they wear where there is no editor theme to ask at all; Save does not, because its
	# icon is one the editor has always carried and its word is the one every reader knows.
	var save_button: Button = _add_toolbar_button(_toolbar, "Save", _dock._on_save_requested,
		_with_key("Save the sheet - compile-on-save keeps its generated script fresh.", "save"),
		"Save", true)
	save_button.name = "EventSheetSaveButton"
	_undo_button = _add_toolbar_button(_toolbar, "Undo", _dock._on_undo_requested,
		_with_key("Undo the last edit to this sheet.", "undo"), "Undo", true, "↶")
	_undo_button.name = "EventSheetUndoButton"
	_redo_button = _add_toolbar_button(_toolbar, "Redo", _dock._on_redo_requested,
		_with_key("Redo the edit you just undid.", "redo"), "Redo", true, "↷")
	_redo_button.name = "EventSheetRedoButton"
	# ── THE PLAY BUTTON ────────────────────────────────────────────────────────────────────────
	# Godot has no split button, so the resting play control is a face Button beside a narrow
	# MenuButton inside one PanelContainer - two adjacent controls reading as one. The slot is a
	# plain box in the strip's resting order, filled by the play button itself, so the strip's order
	# never has to be rearranged to make room for it.
	var play_slot: HBoxContainer = HBoxContainer.new()
	play_slot.name = "EventSheetPlaySlot"
	play_slot.add_theme_constant_override("separation", 0)
	_toolbar.add_child(play_slot)
	_play_button.build(play_slot, _dock)
	# And the same six ways to play, as the plain buttons they have always been, for the expanded
	# strip. They are one table with the play button's dropdown - the same words, the same order and
	# the same handlers - and every one of them is adopted by the run controls, so a running game
	# relabels each of them wherever it is shown. The keys stay Godot's for the two that are
	# Godot's own (F6 / F5).
	for run_entry: Variant in EventSheetRunControls.BUTTONS:
		var run: Array = run_entry
		var run_id: String = str(run[0])
		_dock._run_controls.adopt(run_id, _add_toolbar_button(_toolbar,
			str(run[1]), func() -> void: _dock._run_controls.activate(run_id),
			EventSheetRunControls.tooltip_for(run_id), str(run[3])))
	_dock._run_controls.refresh()
	# And the watch that keeps those labels honest. A game can start and stop without this dock
	# hearing about it - closed from its own window, or played and stopped from Godot's own play bar
	# - and the face is the strip's one primary control, so it must never be the last to know. The
	# timer lives on the DOCK, never on the toolbar: the strip's children are a pinned list, and a
	# Timer among them is not a control anybody meant to put there.
	_dock._run_controls.watch(_dock)
	_add_toolbar_separator(_toolbar)
	# The core reflexes stay one click (E / C / A on the keyboard).
	_add_toolbar_button(_toolbar, "Add Event", _dock._on_add_event_requested, "Add an event (E).", "Add")
	_add_toolbar_button(_toolbar, "Add Condition", _dock._on_add_condition_requested, "Add a condition to the selected event (C).", "MemberConstant")
	_add_toolbar_button(_toolbar, "Add Action", _dock._on_add_action_requested, "Add an action to the selected event (A).", "MemberMethod")
	# Kept as a reference: Simple Mode hides this deliberate drop-to-code surface entirely.
	_dock._add_code_button = _add_toolbar_button(_toolbar, "Add Code", _dock._on_add_gdscript_action_requested, "Add a script block to the selected event - the deliberate 'drop to code' escape hatch. Opens the code editor immediately.", "Script")
	# Add ▸ - the whole authoring vocabulary, as a cascading submenu of the one Menu rather than as a
	# MenuButton of its own. The four Add buttons above are still here, one chevron away, and the
	# canvas carries its own "Add event" / "+ Add…" corner links; the strip stopped competing with
	# them. Every item id is exactly the one it always had - ADD a number, never renumber - because
	# the command palette, the shortcut dispatch and the suite all address these items by id.
	#
	# THE MENU TEACHES THE KEYS. The five reflexes lead it, each with its key printed from the ONE
	# shortcut table (never typed out here, so a rebind shows through), and so do the three items
	# further down that have one.
	var add_popup: PopupMenu = PopupMenu.new()
	add_popup.name = "EventSheetAddMenu"
	menu_popup.add_child(add_popup)
	menu_popup.add_submenu_node_item("Add", add_popup, 6)
	add_popup.add_item("Event", 12)
	add_popup.add_item("Condition", 13)
	add_popup.add_item("Action", 14)
	add_popup.add_item("Group", 15)
	add_popup.add_item("Comment", 16)
	add_popup.add_separator()
	add_popup.add_item("Signal Event…", 0)
	# The sheet's own members are INSTANCE variables of the object the file is; a GLOBAL is
	# one value the whole project shares, and lives on an autoload. Two different things, so two
	# items, each named the thing it makes.
	add_popup.add_item("Instance Variable…", 1)
	add_popup.add_item("Local Variable…", 2)
	add_popup.add_item("Global Variable…", 8)
	# Declare ▸ - every way to give something a NAME, gathered in one place: what the sheet
	# remembers (Variable, Constant, Collection), reaches (Node reference), uses (Resource),
	# announces (Signal), and the named values a thing can take (Enum). Each entry opens the
	# same dialog its scattered sibling opens - one place to find them, not a second flow.
	# Wired the explicit way (a named child PopupMenu plus add_submenu_item with its own id) -
	# never an id-less add_submenu_item.
	var declare_menu: PopupMenu = PopupMenu.new()
	declare_menu.name = "EventSheetDeclareMenu"
	declare_menu.add_item("Variable…", 0)
	declare_menu.set_item_tooltip(declare_menu.get_item_index(0), "A value the object remembers - the Add variable dialog, scope pickable inside.")
	declare_menu.add_item("Constant…", 1)
	declare_menu.set_item_tooltip(declare_menu.get_item_index(1), "A named value that never changes - reads \"Always NAME = value\" and compiles to a const.")
	declare_menu.add_item("Node reference…", 2)
	declare_menu.set_item_tooltip(declare_menu.get_item_index(2), "A handle on a node of the scene - compiles to an @onready var holding the node.")
	declare_menu.add_item("Resource…", 3)
	declare_menu.set_item_tooltip(declare_menu.get_item_index(3), "A file this sheet uses - a scene, sound, texture - preloaded under a constant name.")
	declare_menu.add_item("Enum…", 4)
	declare_menu.set_item_tooltip(declare_menu.get_item_index(4), "The named values a thing can take - compiles before variables, usable as a type.")
	declare_menu.add_item("Signal…", 5)
	declare_menu.set_item_tooltip(declare_menu.get_item_index(5), "An announcement other objects can hear - appears in the On/Emit Signal pickers.")
	declare_menu.add_item("Collection…", 6)
	declare_menu.set_item_tooltip(declare_menu.get_item_index(6), "A list or table of values - the Add variable dialog opened on the List type, items editable as a grid.")
	declare_menu.id_pressed.connect(func(id: int) -> void:
		match id:
			0: _dock._on_add_global_variable_requested()
			1: _dock._add_rows.on_declare_constant_requested()
			2: _dock._add_rows.on_declare_node_reference_requested()
			3: _dock._open_custom_block_add("preload")
			4: _dock._add_rows.on_declare_enum_requested()
			5: _dock._add_rows.on_declare_signal_requested()
			6: _dock._add_rows.on_declare_collection_requested()
	)
	add_popup.add_child(declare_menu)
	add_popup.add_submenu_item("Declare", "EventSheetDeclareMenu", 11)
	add_popup.add_item("Function…", 3)
	# The other half of the shared-sheet gesture. How it is wired was decided by the shared
	# sheet itself, so this asks nothing: pick the sheet, and the rows that wire it are written.
	add_popup.add_item("Include sheet…", 10)
	add_popup.add_separator()
	# The three event-shape commands, on the Add menu as well as the right-click menu: the sheet
	# reads Or blocks, blank sub-events and Else, so all three must be typeable in the same words.
	add_popup.add_item("Add blank sub-event", 5)
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
			12: _dock._on_add_event_requested()
			13: _dock._on_add_condition_requested()
			14: _dock._on_add_action_requested()
			15: _dock._on_add_group_requested()
			16: _dock._on_add_comment_requested()
	)
	# Every key on this menu, printed from EventSheetShortcuts through the ONE seam that puts a key
	# on a menu item. A hint only: the keys are already routed in the viewport's own key handling,
	# and a second listener on a hidden popup would run the gesture twice.
	for keyed: Variant in [[12, "add_event"], [13, "add_condition"], [14, "add_action"],
			[15, "add_group"], [16, "add_comment"], [8, "add_variable"], [3, "add_function"],
			[5, "add_blank_subevent"]]:
		var keyed_entry: Array = keyed
		EventSheetContextMenus.hint_key(add_popup, int(keyed_entry[0]),
			EventSheetShortcuts.binding_for(str(keyed_entry[1])))
	# Kept as a reference so Simple Mode can gate the code item (id 4) live.
	_dock._add_menu_popup = add_popup
	# Edit ▸ - clipboard + history (all on shortcuts too).
	var edit_popup: PopupMenu = PopupMenu.new()
	edit_popup.name = "EventSheetEditMenu"
	menu_popup.add_child(edit_popup)
	menu_popup.add_submenu_node_item("Edit", edit_popup, 1)
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
	# The four gestures on this menu that have keys print them from the same table.
	for keyed: Variant in [[0, "copy"], [1, "paste"], [2, "undo"], [3, "redo"]]:
		var edit_keyed: Array = keyed
		EventSheetContextMenus.hint_key(edit_popup, int(edit_keyed[0]),
			EventSheetShortcuts.binding_for(str(edit_keyed[1])))
	# View ▸ - panels, multi-view, zoom and theming.
	var view_popup: PopupMenu = PopupMenu.new()
	view_popup.name = "EventSheetViewMenu"
	menu_popup.add_child(view_popup)
	menu_popup.add_submenu_node_item("View", view_popup, 2)
	_dock._view_popup = view_popup
	_view_popup_ref = view_popup
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
	# Sheet theme ▸ - the per-sheet theme picker, which used to be an OptionButton on the strip. Same
	# preset list, same per-sheet semantics, ticked on the one this sheet wears. The submenu is
	# refilled every time View opens (the Language idiom), so a theme dropped into the themes folder
	# mid-session is pickable without a restart and the tick follows a theme changed elsewhere.
	# Explicit child-popup wiring with its own id, never an id-less add_submenu_item.
	var sheet_theme_menu: PopupMenu = PopupMenu.new()
	sheet_theme_menu.name = "EventSheetSheetThemeMenu"
	view_popup.add_child(sheet_theme_menu)
	view_popup.add_submenu_item(EventSheetL10n.translate("Sheet theme"), "EventSheetSheetThemeMenu",
		SHEET_THEME_VIEW_ID)
	view_popup.set_item_tooltip(view_popup.get_item_index(SHEET_THEME_VIEW_ID),
		EventSheetL10n.translate("The theme this sheet is drawn with - the bundled presets, plus Match Editor, which derives the sheet's colours from your own editor theme. Remembered on the sheet, so it travels with the file."))
	_dock._bind_sheet_theme_menu(sheet_theme_menu)
	view_popup.about_to_popup.connect(func() -> void: _dock._populate_sheet_theme_menu())
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
	# Tools ▸ - debug + project workflow tools (the UX-audit consolidation).
	var tools_popup: PopupMenu = PopupMenu.new()
	tools_popup.name = "EventSheetToolsMenu"
	menu_popup.add_child(tools_popup)
	menu_popup.add_submenu_node_item("Tools", tools_popup, 3)
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
	tools_popup.add_item("Docs Housekeeping…", 25)
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
	tools_popup.add_item("Lift Workbench…", 26)
	tools_popup.set_item_tooltip(tools_popup.get_item_index(26), "Paste hand-written GDScript and see, line by line, what claims it, the rows it opens as, and whether it saves back byte-identically.")
	tools_popup.add_item("Addon manager…", 23)
	tools_popup.add_separator()
	tools_popup.add_item("Welcome…", 13)
	tools_popup.add_item("Start the Tour…", 17)
	tools_popup.add_item("Keyboard Shortcuts", 16)
	# Words is the reader's own vocabulary choice, and it sits beside Keyboard Shortcuts because both
	# are "how the editor answers to me". It is the whole of what the retired Settings menu carried;
	# id 63 is the next number the Tools menu has never used, because an id belongs to its menu and a
	# moved item cannot bring its old number into a menu that already spent it.
	tools_popup.add_item("Words…", 63)
	tools_popup.set_item_tooltip(tools_popup.get_item_index(63), "Every word the sheet lets you choose, on one page, with a live preview of an event in them.")
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
			25: _dock.open_docs_housekeeping()
			9: _dock._open_sheet_backups()
			10: _dock._save_as_project_template()
			11: _dock._attach_behavior_to_selection()
			18: _dock.toggle_behavior_preview()
			19: _dock._open_save_studio()
			12: _dock._open_lift_report()
			26: _dock.open_lift_workbench()
			13: _dock.show_welcome()
			17: _dock.start_tour()
			16: _dock._open_shortcuts_help()
			22: _dock.open_documentation()
			20: _dock._report_issue()
			21: _dock._open_translation_studio()
			14: _dock._run_diagnostics_action()
			23: _dock.open_addon_manager()
			63: _dock.open_words_settings()
	)
	tools_popup.set_item_tooltip(tools_popup.get_item_index(24), "Every open sheet on one page - how big each is, how much of it is described, what the Doctor said about it - plus a search that reaches all of them and the page each sheet writes about itself.")
	tools_popup.set_item_tooltip(tools_popup.get_item_index(25), "The documentation chores in one window: rewrite the page each sheet writes about itself, check what the guides do not answer, export the Manual as a browsable site, write out a translator's missing keys. Nothing is published - drafts stay drafts.")
	tools_popup.set_item_tooltip(tools_popup.get_item_index(23), "Every installed pack with its version: enable or disable one, read its guide, check for updates, import a pack from a .zip or a URL, or publish yours.")
	tools_popup.set_item_tooltip(tools_popup.get_item_index(22), "The Manual: the tutorials, the guides, and a reference page for every object and behavior. F1 opens help for whatever is selected; Ctrl+F1 reopens the page you were reading.")
	# The dot: a reader who has not opened What's new since the plugin's version changed gets a mark
	# on the Manual entry, and it comes off the moment they read it. Re-asked every time the menu
	# opens, so reading the page while the menu is closed still clears it.
	tools_popup.about_to_popup.connect(func() -> void: mark_unread(tools_popup, 22, "Manual…"))
	tools_popup.set_item_tooltip(tools_popup.get_item_index(21), "The whole handoff to a translator in one window: sweep the project for the text your game shows, read the note each key travels with, merge a returned file and register the catalogs.")
	tools_popup.set_item_tooltip(tools_popup.get_item_index(14), "Lint every ƒx expression + script block; flag the offending rows and jump to the first.")
	tools_popup.set_item_tooltip(tools_popup.get_item_index(0), "Toggle breakpoint emission: debug-compiled sheets pause at rows with breakpoints.")
	tools_popup.set_item_tooltip(tools_popup.get_item_index(1), "Toggle Live Values: running sheets stream their variables here (editable).")
	# The one gesture on this menu with a key of its own, printed from the table like every other.
	EventSheetContextMenus.hint_key(tools_popup, 6, EventSheetShortcuts.binding_for("project_search"))
	# The Menu's foot: the two doors a reader looks for by name rather than by group. Both open the
	# same Manual the Tools entry does - this is a second door onto one page, never a second page.
	menu_popup.add_separator()
	menu_popup.add_item("Manual…", 4)
	menu_popup.add_item("What's new…", 5)
	# THE SAME DOT ON THE SAME DOOR. Tools ▸ Manual… wears a mark when the reader has not opened
	# What's new since the plugin's version changed, and this is the door a reader looks for by name
	# rather than by group - so it was the one Manual entry that never said there was something
	# unread. Re-asked every time the Menu opens, so reading the page clears it either way.
	menu_popup.about_to_popup.connect(func() -> void: mark_unread(menu_popup, 4, "Manual…"))
	menu_popup.id_pressed.connect(func(id: int) -> void:
		match id:
			4: _dock.open_documentation()
			5: _dock.open_documentation("reference:whats-new")
	)
	_add_toolbar_separator(_toolbar)
	# Simple Mode is no longer a pill on the strip: the strip is already calm, so the audience flag
	# reads and flips from View ▸ Simple Mode (id 11) and from the Welcome window, where a reader
	# meets it first. Every one of its other powers is untouched.
	# GDScript stays a one-click toggle on the EXPANDED strip (the pairing thesis: honest output,
	# always one click away), beside its twin in View ▸ GDScript Panel - the same toggle, the same
	# handler, shown where the other panel toggles are named.
	var code_panel_button: Button = _add_toolbar_button(_toolbar, "GDScript", _dock._toggle_code_panel, "Toggle the generated-GDScript panel - the sheet's honest compiled output, side by side.", "Script")
	code_panel_button.name = "EventSheetCodePanelButton"
	# The per-sheet theme picker is no longer an OptionButton on the strip: it is View ▸ Sheet theme,
	# a submenu built from the very same preset list with the sheet's own theme ticked. The
	# semantics are untouched - one theme per sheet, chosen out of the undo history, persisted on
	# the sheet resource - only the surface moved.
	var _quick_add_edit: LineEdit = LineEdit.new()
	_quick_add_edit.name = "EventSheetQuickAdd"
	_quick_add_edit.placeholder_text = "Quick add or find…  (e.g. heal 5, or Chase)"
	_quick_add_edit.tooltip_text = "Type a row and press Enter to add it, exactly as before - or read the answers underneath: the states, rows, variables, functions, signals, modes and Doctor findings that match what you typed. Down arrow to reach them, Enter to go there."
	# Wider now that it answers as well as adds: the answers say what kind they are and where they
	# live, and a label cut in half is a label nobody reads.
	_quick_add_edit.custom_minimum_size = Vector2(240.0, 0.0)
	_dock._quick_add_edit = _quick_add_edit
	_quick_add_edit.text_submitted.connect(func(text: String) -> void:
		if _dock._quick_add(text):
			_quick_add_edit.clear()
	)
	# And the answers, riding the same field on the shipped completion popup. The add line is the
	# first entry in that list and runs this very same call, so Enter on an untouched list still
	# adds the row - the popup swallows the key, and the add happens on the other side of it.
	_dock._ask_field.attach(_quick_add_edit)
	_toolbar.add_child(_quick_add_edit)
	# ── THE CHEVRON ────────────────────────────────────────────────────────────────────────────
	# The whole strip, one click away, and back again. It is a plain Button carrying a glyph rather
	# than an editor icon, so it reads the same on a build whose editor theme has no arrow to lend.
	_expander = _add_toolbar_button(_toolbar, "»", _toggle_full_toolbar_from_chevron, "", "")
	_expander.name = "EventSheetToolbarExpander"
	# The resting seven, in reading order. The play slot is empty until the run-controls pass fills
	# it, and an empty container simply draws nothing.
	_resting_controls = [menu_button, save_button, _undo_button, _redo_button, play_slot,
		_quick_add_edit, _expander]
	_full_toolbar = _stored_full_toolbar()
	_remembered_full_toolbar = _full_toolbar
	_apply_toolbar_expansion()
	refresh_history_buttons()
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
	view_popup.add_submenu_item(EventSheetL10n.translate("Variable rows"), "EventSheetVariableViewMenu", 9813)
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
	# ── View ▸ Full toolbar (appended block - keep together) ───────────────────────────────────
	# The chevron's twin. The strip's resting/expanded state is ONE choice, so it is shown in two
	# places and written in one - a reader who never notices the chevron still finds it by name, and
	# a reader who uses the chevron sees this tick follow. Id 9814 is the next number the View menu
	# has never used.
	view_popup.add_check_item("Full toolbar", FULL_TOOLBAR_VIEW_ID)
	view_popup.set_item_checked(view_popup.get_item_index(FULL_TOOLBAR_VIEW_ID), _full_toolbar)
	view_popup.set_item_tooltip(view_popup.get_item_index(FULL_TOOLBAR_VIEW_ID),
		"Show every button the strip has. Off - the default - the strip rests as the Menu, Save, Undo, Redo, the play button, Quick add and the chevron, and everything else is one click away inside the Menu. Remembered for this project.")
	view_popup.id_pressed.connect(func(id: int) -> void:
		if id == FULL_TOOLBAR_VIEW_ID:
			set_full_toolbar(not _full_toolbar))


## Puts (or takes off) the unread mark on a Manual entry: a reader who has not opened What's new
## since the plugin's version changed gets a ● beside the words, and it comes off the moment they
## read it. Asked on every open rather than kept, so reading the page while the menu is closed
## clears it too. One function because two menus carry this same door.
static func mark_unread(popup: PopupMenu, item_id: int, label: String) -> void:
	var index: int = popup.get_item_index(item_id)
	if index < 0:
		return
	var unread: bool = EventSheetDocWhatsNew.has_unread(EventSheets.docs_version(),
		EventSheetDocWhatsNew.seen_version())
	popup.set_item_text(index, "%s ●" % label if unread else label)


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


## A tooltip with its key printed after it, read from the ONE shortcut table. An action with no key
## simply says what it does. Same shape the beginner toolbar's tooltips use, for the same reason: a
## hand-typed key name is a key name that goes stale the first time somebody rebinds it.
static func _with_key(text: String, action: String) -> String:
	var what: String = EventSheetL10n.translate(text)
	var binding: String = EventSheetShortcuts.binding_for(action)
	return what if binding.is_empty() else "%s  (%s)" % [what, binding]


## The strip's play button, so a caller that wants the face (a preview harness, a tutorial step, a
## test) reaches it without knowing how the slot is put together.
func play_button() -> EventSheetPlayButton:
	return _play_button


## Whether the strip is showing every button it has.
func full_toolbar() -> bool:
	return _full_toolbar


## Show (or rest) the whole strip, remember the choice for this project, and put the chevron and the
## View menu's tick on the same answer.
func set_full_toolbar(shown: bool) -> void:
	_full_toolbar = shown
	_remembered_full_toolbar = shown
	var settings: Object = EventSheetEditorSettings.current()
	if settings != null:
		settings.call("set_project_metadata", "eventsheets", FULL_TOOLBAR_META_KEY, shown)
	_apply_toolbar_expansion()
	if _dock != null:
		_dock._set_status(EventSheetL10n.translate("Full toolbar on - every button is on the strip.") if shown
			else EventSheetL10n.translate("Toolbar rested. The chevron, or View ▸ Full toolbar, brings the rest back."))


## THE ONE-TIME NOTE. A project that already has sheets in it had a strip with twenty-one controls
## on it yesterday; the first sheet it opens on the resting strip says once, in the status bar,
## where everything went and that no key changed. Said ONCE per project, remembered in the same
## per-project metadata the rest of the strip's state uses.
##
## `opened_existing_sheet` is what makes a brand-new project never see it: a project whose first
## sheet is the blank one the workspace seeds has nothing to be told, because it never saw the old
## strip. Answers whether the note was said, so the caller (and the suite) can tell.
func announce_resting_strip(opened_existing_sheet: bool) -> bool:
	if _dock == null or _full_toolbar or not opened_existing_sheet or _resting_note_said:
		return false
	var settings: Object = EventSheetEditorSettings.current()
	var stored: Variant = ("" if settings == null
		else settings.call("get_project_metadata", "eventsheets", RESTING_NOTE_META_KEY, ""))
	# Said once per SESSION as well as once per project: every tab activation passes through here,
	# and the metadata write is the editor's to keep - a headless run (no EditorSettings at all)
	# still has to say it exactly once rather than on every sheet it opens.
	_resting_note_said = true
	if stored is bool and bool(stored):
		return false
	if settings != null:
		settings.call("set_project_metadata", "eventsheets", RESTING_NOTE_META_KEY, true)
	_dock._set_status(EventSheetL10n.translate(RESTING_NOTE))
	return true


func _toggle_full_toolbar_from_chevron() -> void:
	set_full_toolbar(not _full_toolbar)


## The strip in whichever state it is in: at rest only the seven resting controls are visible, and
## expanded everything is. Nothing is ever removed from the strip - a hidden button keeps its place,
## its handler and its key, which is why the resting state costs no lookup anywhere else.
func _apply_toolbar_expansion() -> void:
	if _toolbar_ref == null:
		return
	for child: Node in _toolbar_ref.get_children():
		var control: Control = child as Control
		if control == null:
			continue
		control.visible = _full_toolbar or _resting_controls.has(control)
	if _expander != null:
		_expander.text = "«" if _full_toolbar else "»"
		_expander.tooltip_text = ("Rest the toolbar - Menu, Save, Undo, Redo, play and Quick add."
			if _full_toolbar else "Show every button on the toolbar.")
	if _view_popup_ref != null:
		var index: int = _view_popup_ref.get_item_index(FULL_TOOLBAR_VIEW_ID)
		if index >= 0:
			_view_popup_ref.set_item_checked(index, _full_toolbar)


## Undo and Redo grey out when there is nothing to undo or redo, the way Godot's own toolbars do.
## Called from the dock's undo funnel - the one place every edit, undo, redo and history clear
## passes through - so the two icons never claim a history the sheet does not have.
func refresh_history_buttons() -> void:
	if _dock == null:
		return
	if _undo_button != null:
		_undo_button.disabled = not _dock._undo_redo_adapter.has_undo()
	if _redo_button != null:
		_redo_button.disabled = not _dock._undo_redo_adapter.has_redo()


## Makes sure a control on the strip can actually be seen before something points at it: a tutorial
## step that pulses "Add Action" while the strip rests would pulse a hidden button. Answers whether
## the control belongs to this strip at all.
##
## THIS IS NOT A CHOICE, so it does not overwrite one. It used to call set_full_toolbar(true), which
## wrote eventsheets_full_toolbar into the project's metadata and never put it back - so following a
## Manual link that points at a hidden button permanently expanded a strip the reader had chosen to
## rest, with nothing to undo it. The strip is expanded for as long as it takes to look at the thing
## being pointed at; the remembered choice is untouched, the chevron rests it again, and reopening
## the project rests it on its own.
func reveal_control(control: Control) -> bool:
	if _toolbar_ref == null or control == null or control.get_parent() != _toolbar_ref:
		return false
	if control.visible:
		return true
	_full_toolbar = true
	_apply_toolbar_expansion()
	if _dock != null:
		_dock._set_status(EventSheetL10n.translate("Showing every button so this one can be pointed at - your resting toolbar is still remembered. The chevron rests it again."))
	return true


## The reader's own resting/expanded choice, which is what gets remembered for the project. Not
## always what the strip is SHOWING: something that points at a hidden button expands the strip
## without deciding anything.
func remembered_full_toolbar() -> bool:
	return _remembered_full_toolbar


## The narrowest the RESTING strip can be drawn without wrapping: every resting control's own
## minimum width plus the separations between them. HFlowContainer answers its combined minimum size
## as the widest single child (it is allowed to wrap), so the resting row's width has to be added up
## rather than asked for.
func resting_minimum_width() -> float:
	if _toolbar_ref == null:
		return 0.0
	var separation: int = _toolbar_ref.get_theme_constant("h_separation")
	var total: float = 0.0
	var counted: int = 0
	for child: Node in _toolbar_ref.get_children():
		var control: Control = child as Control
		if control == null or not _resting_controls.has(control):
			continue
		total += control.get_combined_minimum_size().x
		counted += 1
	return total + float(separation) * float(maxi(counted - 1, 0))


## The stored choice, read the way every other per-project editor choice here is read: a NON-null
## sentinel default, because a missing key with a null default prints an editor ERROR on a fresh
## project. Anything that is not a stored bool means "nobody chose", and nobody choosing means rest.
func _stored_full_toolbar() -> bool:
	var settings: Object = EventSheetEditorSettings.current()
	if settings == null:
		return false
	var stored: Variant = settings.call("get_project_metadata", "eventsheets", FULL_TOOLBAR_META_KEY, "")
	return stored if stored is bool else false


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


## The words an icon-only button stands for, kept in its own meta so anything that addresses a
## toolbar control by its label (a tutorial's pulse) still finds it once the words come off the face.
const LABEL_META_KEY: String = "eventsheets_toolbar_label"


## Adds a one-click toolbar button wired to `callable`, with an optional editor icon.
## Returns the button so callers that need to gate/restyle it can keep a reference.
## (Moved verbatim from the dock; targets the toolbar passed in rather than a member.)
##
## `icon_only` drops the words from the face and leaves the icon to carry it - and only when the icon
## actually arrived. `glyph` is what an icon-only face falls back to when no icon did: a headless run
## has no editor theme at all, and a one-character glyph keeps a row of icons reading as a row of
## icons instead of as two pictures and a word. A face with neither an icon nor a glyph keeps its
## words, so a button never becomes a blank rectangle nobody can name.
func _add_toolbar_button(toolbar: HFlowContainer, text: String, callable: Callable, tooltip: String = "", editor_icon: String = "", icon_only: bool = false, glyph: String = "") -> Button:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	# The words stay on the button's own meta whatever the face ends up wearing, so anything that
	# addresses a toolbar control by its label (a tutorial's pulse) still finds it.
	button.set_meta(LABEL_META_KEY, text)
	# Editor icons make the toolbar read as part of Godot. The seam answers null headlessly and for
	# a name the running theme does not carry, and derives the one arrow Godot ships without a twin.
	var icon: Texture2D = EventSheetEditorIcons.icon(editor_icon)
	if icon != null:
		button.icon = icon
		if icon_only:
			button.text = ""
	elif icon_only and not glyph.is_empty():
		button.text = glyph
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
