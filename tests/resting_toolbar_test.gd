# EventSheets test - THE STRIP AT REST, AND EXPANDED.
#
# The editor's top strip used to front twenty-one interactive controls at once, which is a menu bar
# wearing a toolbar's clothes: everything one click away, and nothing findable. It rests now. Seven
# controls in one row that never wraps - one cascading Menu, the save/undo/redo icons, the play
# button's slot, Quick add, and a chevron - with every other button one chevron away and every
# retired menu one hop inside the Menu.
#
# NOTHING WAS REMOVED, and that is the half of this a test has to hold. The four MenuButtons that
# left the strip are the very same PopupMenus, re-parented as cascading submenus, so every item id,
# every handler and every dynamic submenu still answers. Settings' one item moved into Tools beside
# Keyboard Shortcuts. Simple Mode kept all of its powers and gave up the one it had over the strip.
#
# Pinned by VALUE - the resting names in order, the counts inside the cascade, the measured resting
# width - because a count of children says nothing about which children.
@tool
class_name RestingToolbarTest
extends RefCounted


## The budget for the RESTING row, in px, measured off the built strip by this very test.
##
## It was 520 while the play slot stood empty - the narrowest canvas any layout test here draws a
## sheet into (event_cell_wrap_test builds its viewport at 520 wide) - and the row measured 494.
## The slot is full now: the play button is a face Button wearing the chosen run's own words beside
## a narrow dropdown, and that pair is 115 px of the row. Headless is the widest the face ever gets,
## because no editor icon arrives here and the words carry it alone.
##
## 609 measured, 640 budgeted: room for one more icon-sized control, so the next pass that puts
## something on the resting strip comes here, re-measures, and says why - rather than finding out
## by watching the row wrap.
const RESTING_WIDTH_BUDGET: float = 640.0


## An undo manager whose history this test can move by hand, so the two icons can be held against a
## history that has something in it and one that does not, without building real edits.
class HistoryStub:
	extends RefCounted

	var undo_available: bool = false
	var redo_available: bool = false

	func create_action(_name: String) -> void:
		pass

	func add_do_method(_target: Variant, _method: Variant, _arg: Variant = null) -> void:
		pass

	func add_undo_method(_target: Variant, _method: Variant, _arg: Variant = null) -> void:
		pass

	func commit_action() -> void:
		pass

	func clear_history() -> void:
		undo_available = false
		redo_available = false

	func has_undo() -> bool:
		return undo_available

	func has_redo() -> bool:
		return redo_available


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_resting_row() and ok
	ok = _test_the_cascade() and ok
	ok = _test_the_two_states() and ok
	ok = _test_the_history_icons() and ok
	ok = _test_keys_come_from_the_table() and ok
	ok = _test_simple_mode_lets_the_strip_alone() and ok
	ok = _test_the_sheet_theme_menu() and ok
	ok = _test_the_one_time_note() and ok
	return ok


## THE SEVEN, in reading order. Named rather than counted: a strip that swapped Undo for something
## else would keep any count you cared to write.
static func _test_the_resting_row() -> bool:
	var editor: EventSheetEditor = _editor()
	var resting: PackedStringArray = PackedStringArray()
	for child: Node in editor._toolbar.get_children():
		if (child as Control).visible:
			resting.append(str(child.name))
	var ok: bool = _check("the strip rests as seven controls, in this order", resting,
		PackedStringArray(["EventSheetMenu", "EventSheetSaveButton", "EventSheetUndoButton",
			"EventSheetRedoButton", "EventSheetPlaySlot", "EventSheetQuickAdd",
			"EventSheetToolbarExpander"]))
	# The play button lives in that slot: one face and one narrow dropdown, two adjacent controls in
	# a single frame, because Godot has no split button to reach for.
	ok = _check("the play button has its slot",
		editor._toolbar.find_child("EventSheetPlaySlot", true, false) is HBoxContainer, true) and ok
	ok = _check("and the split button is in it",
		editor._toolbar.find_child("EventSheetPlayFace", true, false) is Button
			and editor._toolbar.find_child("EventSheetPlayMenu", true, false) is MenuButton, true) and ok
	# The row has to FIT. Measured off the built strip rather than guessed, and held under the
	# narrowest canvas this suite already draws a sheet into.
	var width: float = editor._menu_bar.resting_minimum_width()
	print("[resting_toolbar_test] resting strip minimum width: %.1f px" % width)
	ok = _check("the resting row stays inside its width budget",
		width > 0.0 and width < RESTING_WIDTH_BUDGET, true) and ok
	editor.free()
	return ok


## THE CASCADE. One Menu, four submenus that are the same PopupMenus as before - which is what keeps
## every id, handler and dynamic submenu inside them working untouched - and the two doors at its
## foot. The four MenuButtons and the Settings MenuButton are gone from the strip.
static func _test_the_cascade() -> bool:
	var editor: EventSheetEditor = _editor()
	var menu: MenuButton = editor._toolbar.find_child("EventSheetMenu", true, false) as MenuButton
	var ok: bool = _check("the strip carries one Menu button", menu != null, true)
	if menu == null:
		editor.free()
		return false
	var popup: PopupMenu = menu.get_popup()
	var labels: PackedStringArray = PackedStringArray()
	for index: int in popup.item_count:
		labels.append(popup.get_item_text(index))
	# FIVE groups now: Add joined them when the strip stopped fronting the adding. It sits second,
	# where it sat on the strip, and it is the same PopupMenu with the same ids - only its hanger
	# changed.
	ok = _check("the Menu cascades the five groups, then the two doors", labels,
		PackedStringArray(["Sheet", "Add", "Edit", "View", "Tools", "", "Manual…", "What's new…"])) and ok
	# The submenus are the SAME menus, so their contents are pinned here as well as in the workflow
	# test: a cascade that quietly rebuilt a menu would pass a "there are four submenus" check.
	var counts: Dictionary = {}
	for name: String in ["EventSheetSheetMenu", "EventSheetEditMenu", "EventSheetViewMenu",
			"EventSheetToolsMenu"]:
		var submenu: PopupMenu = popup.find_child(name, true, false) as PopupMenu
		counts[name] = -1 if submenu == null else submenu.item_count
	ok = _check("Sheet keeps its items", counts["EventSheetSheetMenu"], 27) and ok
	ok = _check("Edit keeps its items", counts["EventSheetEditMenu"], 10) and ok
	# 57, not 56: View ▸ Sheet theme joined it when the theme OptionButton left the strip. The item
	# is a submenu, so this counts the hanger - its entries are pinned in _test_the_sheet_theme_menu.
	ok = _check("View keeps its items, plus Full toolbar and Sheet theme",
		counts["EventSheetViewMenu"], 57) and ok
	ok = _check("Tools keeps its items, plus Words…", counts["EventSheetToolsMenu"], 42) and ok
	# Words… moved menus rather than leaving: it is on Tools now, beside Keyboard Shortcuts.
	var tools: PopupMenu = popup.find_child("EventSheetToolsMenu", true, false) as PopupMenu
	ok = _check("Words… is on Tools, at its own id",
		tools.get_item_text(tools.get_item_index(63)), "Words…") and ok
	ok = _check("and it sits beside Keyboard Shortcuts",
		tools.get_item_index(63) - tools.get_item_index(16), 1) and ok
	# Nothing named Settings is left on the strip, and the Menu is the ONLY MenuButton on it - Add
	# was the last one beside it, and it cascades from inside the Menu now.
	var menu_buttons: PackedStringArray = PackedStringArray()
	for child: Node in editor._toolbar.get_children():
		if child is MenuButton:
			menu_buttons.append(str((child as MenuButton).text))
	ok = _check("the Menu is the only MenuButton on the strip", menu_buttons,
		PackedStringArray(["☰ Menu"])) and ok
	editor.free()
	return ok


## REST IS THE DEFAULT, for every project including one that already exists - there was no
## resting/expanded choice before this, so there is nothing to migrate. The chevron and the View
## item are one choice shown twice.
static func _test_the_two_states() -> bool:
	var editor: EventSheetEditor = _editor()
	var ok: bool = _check("a project that never chose rests", editor._menu_bar.full_toolbar(), false)
	var expander: Button = editor._toolbar.find_child("EventSheetToolbarExpander", true, false) as Button
	ok = _check("the chevron points outward at rest", expander.text, "»") and ok
	var view_popup: PopupMenu = editor._view_popup
	var full_index: int = view_popup.get_item_index(EventSheetMenuBar.FULL_TOOLBAR_VIEW_ID)
	ok = _check("View names the same choice", view_popup.get_item_text(full_index), "Full toolbar") and ok
	ok = _check("and it is unticked at rest", view_popup.is_item_checked(full_index), false) and ok
	# Expanded: every child of the strip is on show, in the order it was always in.
	editor._menu_bar.set_full_toolbar(true)
	var hidden: PackedStringArray = PackedStringArray()
	for child: Node in editor._toolbar.get_children():
		if not (child as Control).visible:
			hidden.append(str(child.name))
	ok = _check("expanded, the strip hides nothing", hidden, PackedStringArray()) and ok
	ok = _check("the chevron turns around", expander.text, "«") and ok
	ok = _check("and the View tick follows it", view_popup.is_item_checked(full_index), true) and ok
	# The retired buttons are still buttons: hidden, never deleted, so their keys and handlers stand.
	var labels: PackedStringArray = PackedStringArray()
	for child: Node in editor._toolbar.get_children():
		if child is Button and not str((child as Button).text).is_empty():
			labels.append(str((child as Button).text))
	# THE FOUR ADD BUTTONS retired from the RESTING strip (they were never in the resting seven) and
	# stay, whole, on the expanded one. Nothing about adding was removed - it moved to where the
	# adding happens: the canvas's corner links, the keys, the Ghost Row, the trailing rows.
	for add_label: String in ["Add Event", "Add Condition", "Add Action", "Add Code"]:
		ok = _check("%s is still on the expanded strip" % add_label, labels.has(add_label), true) and ok
	ok = _check("so is Play as host + client, which a tutorial points at",
		labels.has("Play as host + client"), true) and ok
	editor._menu_bar.set_full_toolbar(false)
	ok = _check("and the strip rests again", expander.text, "»") and ok
	editor.free()
	return ok


## UNDO AND REDO ARE THE PASS'S ONE ADDITION - two icons over gestures that already existed on their
## keys and on the Edit menu. They call the dock's funnel, and they grey out with the history.
static func _test_the_history_icons() -> bool:
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	var history: HistoryStub = HistoryStub.new()
	editor.set_undo_redo_manager(history)
	editor._menu_bar.refresh_history_buttons()
	var undo_button: Button = editor._toolbar.find_child("EventSheetUndoButton", true, false) as Button
	var redo_button: Button = editor._toolbar.find_child("EventSheetRedoButton", true, false) as Button
	var ok: bool = _check("nothing to undo, so Undo is grey", undo_button.disabled, true)
	ok = _check("nothing to redo, so Redo is grey", redo_button.disabled, true) and ok
	history.undo_available = true
	editor._menu_bar.refresh_history_buttons()
	ok = _check("a history to undo lights Undo", undo_button.disabled, false) and ok
	history.redo_available = true
	editor._menu_bar.refresh_history_buttons()
	ok = _check("and a redo lights Redo", redo_button.disabled, false) and ok
	# The funnel: pressing the icon runs the same call the key and the Edit menu run, which is the
	# whole reason this is one addition rather than a second undo.
	editor._on_undo_requested()
	ok = _check("the icon calls the dock's undo funnel",
		undo_button.pressed.is_connected(editor._on_undo_requested), true) and ok
	ok = _check("and Redo calls its own",
		redo_button.pressed.is_connected(editor._on_redo_requested), true) and ok
	editor.free()
	return ok


## Every key printed on the strip comes from the ONE shortcut table, so a rebind shows through
## without an edit here. Pinned against the table itself rather than against typed-out key names.
static func _test_keys_come_from_the_table() -> bool:
	var editor: EventSheetEditor = _editor()
	var ok: bool = true
	for entry: Array in [["EventSheetSaveButton", "save"], ["EventSheetUndoButton", "undo"],
			["EventSheetRedoButton", "redo"]]:
		var button: Button = editor._toolbar.find_child(str(entry[0]), true, false) as Button
		var binding: String = EventSheetShortcuts.binding_for(str(entry[1]))
		ok = _check("%s prints its key from the table" % str(entry[0]),
			button.tooltip_text.ends_with("(%s)" % binding), true) and ok
	# And so does every entry in the cascade that has one. A menu item carries its key as a Shortcut
	# (hint_key builds it from the same table), so the pin is "the item has one, and it is the one
	# the table says" - never a typed-out key name, which is the whole point of the seam.
	var popup: PopupMenu = (editor._toolbar.find_child("EventSheetMenu", true, false) as MenuButton).get_popup()
	for entry: Array in [["EventSheetSheetMenu", 1, "open"], ["EventSheetSheetMenu", 2, "save"],
			["EventSheetSheetMenu", 3, "save_as"], ["EventSheetEditMenu", 0, "copy"],
			["EventSheetEditMenu", 1, "paste"], ["EventSheetEditMenu", 2, "undo"],
			["EventSheetEditMenu", 3, "redo"], ["EventSheetToolsMenu", 6, "project_search"],
			["EventSheetAddMenu", 5, "add_blank_subevent"]]:
		var submenu: PopupMenu = popup.find_child(str(entry[0]), true, false) as PopupMenu
		var index: int = submenu.get_item_index(int(entry[1]))
		var shortcut: Shortcut = submenu.get_item_shortcut(index)
		ok = _check("%s id %d carries a key" % [str(entry[0]), int(entry[1])],
			shortcut != null and not shortcut.events.is_empty(), true) and ok
		if shortcut != null and not shortcut.events.is_empty():
			var expected: Dictionary = EventSheetShortcuts.parse(EventSheetShortcuts.binding_for(str(entry[2])))
			var pressed: InputEventKey = shortcut.events[0] as InputEventKey
			ok = _check("and it is the table’s key for %s" % str(entry[2]),
				int(pressed.keycode), int(expected.get("keycode", KEY_NONE))) and ok
	# The one hand-typed key on the Add menu is gone: the item says what it does, and its key is
	# printed beside it by the seam.
	var add_menu: PopupMenu = popup.find_child("EventSheetAddMenu", true, false) as PopupMenu
	ok = _check("no hand-typed key is left on the blank sub-event item",
		add_menu.get_item_text(add_menu.get_item_index(5)), "Add blank sub-event") and ok
	editor.free()
	return ok


## THE THEME PICKER MOVED, WHOLE. It was an OptionButton on the strip; it is View ▸ Sheet theme now,
## built from the very same preset list with the sheet’s own theme ticked. Pinned against
## EventSheetThemePresets rather than against typed-out theme names, so a bundled theme added or
## renamed cannot make this test lie.
static func _test_the_sheet_theme_menu() -> bool:
	var editor: EventSheetEditor = _editor()
	var ok: bool = _check("nothing named a theme picker is left on the strip",
		editor._toolbar.find_child("EventSheetThemePicker", true, false), null)
	var view_popup: PopupMenu = editor._view_popup
	var index: int = view_popup.get_item_index(EventSheetMenuBar.SHEET_THEME_VIEW_ID)
	ok = _check("View names it", view_popup.get_item_text(index), "Sheet theme") and ok
	var theme_menu: PopupMenu = view_popup.find_child("EventSheetSheetThemeMenu", true, false) as PopupMenu
	ok = _check("and it is a submenu of View", theme_menu != null, true) and ok
	if theme_menu == null:
		editor.free()
		return false
	var expected: PackedStringArray = PackedStringArray(["Match Editor (default)"])
	for preset: Dictionary in EventSheetThemePresets.list_presets():
		expected.append(str(preset.get("name", "Theme")))
	var listed: PackedStringArray = PackedStringArray()
	for item: int in theme_menu.item_count:
		listed.append(theme_menu.get_item_text(item))
	ok = _check("it lists Match Editor plus every discovered preset", listed, expected) and ok
	# The tick: a sheet with no style of its own wears the editor-derived default, which is entry 0.
	ok = _check("a sheet with no theme of its own ticks Match Editor",
		theme_menu.is_item_checked(0), true) and ok
	# Picking one is the same per-sheet apply the OptionButton did: the style lands on THIS sheet,
	# and the tick follows it.
	if theme_menu.item_count > 1:
		editor._theme_manager._on_theme_preset_selected(1)
		ok = _check("picking a preset puts it on this sheet",
			editor._current_sheet.editor_style != null
				and editor._current_sheet.editor_style.resource_path == str(theme_menu.get_item_metadata(1)),
			true) and ok
		ok = _check("and the tick moves with it", theme_menu.is_item_checked(1), true) and ok
		ok = _check("leaving Match Editor unticked", theme_menu.is_item_checked(0), false) and ok
		editor._theme_manager._on_theme_preset_selected(0)
		ok = _check("Match Editor clears the per-sheet override",
			editor._current_sheet.editor_style, null) and ok
	# The GDScript toggle is on the expanded strip and named in View, beside the other panel
	# toggles - one toggle, two doors, and neither of them on the resting strip.
	var code_button: Button = editor._toolbar.find_child("EventSheetCodePanelButton", true, false) as Button
	ok = _check("the GDScript toggle is a button on the strip", code_button != null, true) and ok
	ok = _check("and it rests hidden", code_button != null and code_button.visible, false) and ok
	ok = _check("View names the same panel",
		view_popup.get_item_text(view_popup.get_item_index(0)), "GDScript Panel (toggle)") and ok
	editor.free()
	return ok


## THE ONE-TIME NOTE. A project that already has sheets in it is told once, in the status bar, that
## the strip rests and where everything went. Once - not once per sheet, not once per tab - and
## never at all for a project whose first sheet is the blank one the workspace seeds.
static func _test_the_one_time_note() -> bool:
	var editor: EventSheetEditor = _editor()
	var ok: bool = _check("a brand-new project is told nothing",
		editor._menu_bar.announce_resting_strip(false), false)
	ok = _check("a project with sheets in it is told once",
		editor._menu_bar.announce_resting_strip(true), true) and ok
	ok = _check("and the note is the one this file states",
		editor._status_label.text, EventSheetMenuBar.RESTING_NOTE) and ok
	ok = _check("never again, however many sheets it opens",
		editor._menu_bar.announce_resting_strip(true), false) and ok
	editor.free()
	# A reader who already expanded the strip is not told it is resting - because it is not.
	var expanded: EventSheetEditor = _editor()
	expanded._menu_bar.set_full_toolbar(true)
	ok = _check("an expanded strip says nothing about resting",
		expanded._menu_bar.announce_resting_strip(true), false) and ok
	expanded.free()
	return ok


## SIMPLE MODE KEPT EVERYTHING BUT THE STRIP. It no longer hides the Add Code button, because the
## strip is already calm; every other gate is exactly where it was.
static func _test_simple_mode_lets_the_strip_alone() -> bool:
	var editor: EventSheetEditor = _editor()
	editor._menu_bar.set_full_toolbar(true)
	var before: PackedStringArray = _visible_names(editor)
	editor.set_simple_mode(true)
	var ok: bool = _check("Simple Mode changes nothing on the strip", _visible_names(editor), before)
	# The gates that stay: the Add menu's code item disables, and the Properties bar closes.
	ok = _check("the Add menu's code item still disables in Simple Mode",
		editor._add_menu_popup.is_item_disabled(editor._add_menu_popup.get_item_index(4)), true) and ok
	editor.set_simple_mode(false)
	ok = _check("and enables again outside it",
		editor._add_menu_popup.is_item_disabled(editor._add_menu_popup.get_item_index(4)), false) and ok
	ok = _check("Simple Mode's own View item is still where it was",
		editor._view_popup.get_item_text(editor._view_popup.get_item_index(11)),
		"Simple Mode (beginner-friendly)") and ok
	editor.free()
	return ok


static func _visible_names(editor: EventSheetEditor) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for child: Node in editor._toolbar.get_children():
		if (child as Control).visible:
			names.append(str(child.name))
	return names


static func _editor() -> EventSheetEditor:
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	editor.set_undo_redo_manager(HistoryStub.new())
	return editor


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] resting_toolbar_test: %s" % label)
		return true
	print("[FAIL] resting_toolbar_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
