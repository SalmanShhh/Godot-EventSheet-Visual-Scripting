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
## a narrow dropdown, and that pair is 115 px of the row.
##
## THIS IS A HEADLESS NUMBER, and it is not the widest the row ever gets. It was written down as if
## it were: "headless is the widest the face ever gets, because no editor icon arrives here". That
## is false - in the editor the play face wears an icon AND its words, so the real strip is WIDER
## than what this measures, while the three history icons are NARROWER (they wear a one-character
## glyph here and an editor icon there). Nothing measures the strip inside a running editor; the
## preview harness prints its width when it renders, and that is the number to compare against.
##
## 555 measured headless, 640 budgeted: room for one more icon-sized control, so the next pass that
## puts something on the resting strip comes here, re-measures, and says why - rather than finding
## out by watching the row wrap.
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
	ok = _test_the_strip_is_keyboard_reachable() and ok
	ok = _test_the_history_icons() and ok
	ok = _test_the_icon_faces() and ok
	ok = _test_keys_come_from_the_table() and ok
	ok = _test_the_printed_keys_are_hints_only() and ok
	ok = _test_simple_mode_lets_the_strip_alone() and ok
	ok = _test_the_sheet_theme_menu() and ok
	ok = _test_the_one_time_note() and ok
	ok = _test_pointing_at_a_button_is_not_a_choice() and ok
	ok = _test_the_guide_names_every_control() and ok
	return ok


## THE GUIDE IS PART OF THE STRIP. A resting toolbar only works if the reader can find out where a
## button went, so docs/GUIDE-THE-TOOLBAR.md carries a where-did-it-go row per control. The list is
## DERIVED from the built strip rather than typed here, so a pass that adds a button to the toolbar
## and forgets the guide fails this check by name instead of shipping a guide that is quietly short
## one row. The names are compared with their leading glyph stripped, because the guide writes
## "Debug layout" where the button wears an emoji in front of it.
##
## Each button is asked for the words it was BUILT with rather than for what is on its face: an
## icon-only face carries an icon in the editor and a glyph here, and reading the face meant the
## three icon buttons quietly dropped out of this sweep the moment they stopped saying their names.
static func _test_the_guide_names_every_control() -> bool:
	var guide: String = FileAccess.get_file_as_string("res://docs/GUIDE-THE-TOOLBAR.md")
	var ok: bool = _check("the toolbar guide reads", guide.is_empty(), false)
	if guide.is_empty():
		return false
	var editor: EventSheetEditor = _editor()
	var unnamed: PackedStringArray = PackedStringArray()
	var checked: int = 0
	for child: Node in editor._toolbar.get_children():
		if not (child is Button):
			continue
		var label: String = _plain_label(editor._toolbar_control_label(child as Button))
		if label.is_empty():
			continue
		checked += 1
		if not guide.contains(label):
			unnamed.append(label)
	editor.free()
	# Without this the check passes vacuously the day the strip stops building buttons.
	ok = _check("the strip's buttons were actually swept", checked > 10, true) and ok
	ok = _check("the guide names every button on the strip", unnamed, PackedStringArray()) and ok
	# And the four surfaces that are not buttons but are what the guide is FOR.
	for phrase: String in ["Quick add", "Full toolbar", "Sheet theme", "Words"]:
		ok = _check("the guide names %s" % phrase, guide.contains(phrase), true) and ok
	return ok


## Whether the item at `index` is one of the Menu's cascading groups rather than a plain command or
## a separator. The cascade is built with add_submenu_node_item, which names the popup NODE, so the
## submenu is asked for by node first and by name second.
static func _submenu_label_at(popup: PopupMenu, index: int) -> bool:
	if popup.is_item_separator(index):
		return false
	if not popup.get_item_submenu(index).is_empty():
		return true
	return popup.get_item_submenu_node(index) != null


## A button's words with any leading icon glyph and spacing removed, so "🐞 Debug layout" compares as
## "Debug layout". Returns "" for a control whose whole label is a glyph (the chevron), which the
## guide names in prose rather than by its character.
static func _plain_label(text: String) -> String:
	var start: int = 0
	while start < text.length() and not _is_word_start(text[start]):
		start += 1
	return text.substr(start).strip_edges()


static func _is_word_start(character: String) -> bool:
	return (character >= "A" and character <= "Z") or (character >= "a" and character <= "z")


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
	# THE HOVER NAMES THE MENU IT OPENS. It said "four groups: Sheet, Edit, View and Tools" while the
	# button cascaded five - Add joined after those words were written - so the one control on the
	# strip described a menu that is not the one underneath it. Derived from the popup's own submenu
	# labels rather than typed here, so the next group to join fails this by name.
	var groups: PackedStringArray = PackedStringArray()
	for index: int in popup.item_count:
		if _submenu_label_at(popup, index):
			groups.append(popup.get_item_text(index))
	var unnamed: PackedStringArray = PackedStringArray()
	for group: String in groups:
		if not menu.tooltip_text.contains(group):
			unnamed.append(group)
	ok = _check("the Menu's hover was asked about every group it opens", groups.size(), 5) and ok
	ok = _check("and it names each one", unnamed, PackedStringArray()) and ok
	ok = _check("and counts them", menu.tooltip_text.contains("five groups"), true) and ok
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


## TAB REACHES EVERY RESTING CONTROL. A MenuButton defaults to FOCUS_ACCESSIBILITY, which the focus
## ring skips, and neither the one Menu button nor the play dropdown set anything else - so the whole
## command tree and all six ways to play were mouse-only, and the only keyboard route to them was the
## Ctrl+P palette. Pinned over the resting row as a whole rather than over the two that were wrong,
## so a control added to the strip is held to it too.
static func _test_the_strip_is_keyboard_reachable() -> bool:
	var editor: EventSheetEditor = _editor()
	var unreachable: PackedStringArray = PackedStringArray()
	var checked: int = 0
	for child: Node in editor._toolbar.get_children():
		var control: Control = child as Control
		if control == null or not control.visible or control is HBoxContainer:
			continue
		checked += 1
		if control.focus_mode != Control.FOCUS_ALL:
			unreachable.append(str(control.name))
	# The play slot is a plain box; what has to be reachable is the pair inside it.
	for inner: String in ["EventSheetPlayFace", "EventSheetPlayMenu"]:
		var control: Control = editor._toolbar.find_child(inner, true, false) as Control
		checked += 1
		if control == null or control.focus_mode != Control.FOCUS_ALL:
			unreachable.append(inner)
	var ok: bool = _check("the resting row was actually swept", checked, 8)
	ok = _check("and Tab reaches every control on it", unreachable, PackedStringArray()) and ok
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


## THE THREE ICON FACES. Save, Undo and Redo are icon-only buttons, and the strip shipped reading
## "[save icon] Undo [redo icon]" - two pictures and a word - because the factory asked the editor
## theme for an icon called "Undo" and Godot 4.7 does not ship one. Probed against the RUNNING
## editor theme (1045 icons): Save true, Redo true, Undo FALSE, UndoRedo true (that is the history
## pair, not an undo arrow), MainScene FALSE, MainPlay true.
##
## Two halves are pinned here. Headlessly - where there is no editor theme at all - each icon-only
## face falls back to a GLYPH rather than to the words, so the row still reads as a row of icons.
## And the names the strip asks for are pinned against the answers above: the one Godot does not
## ship is derived from its twin, and the run that asked for a name that does not exist asks for the
## one that does. The live has_icon sweep is the preview harness's job, because it needs an editor.
static func _test_the_icon_faces() -> bool:
	var editor: EventSheetEditor = _editor()
	var undo_button: Button = editor._toolbar.find_child("EventSheetUndoButton", true, false) as Button
	var redo_button: Button = editor._toolbar.find_child("EventSheetRedoButton", true, false) as Button
	var save_button: Button = editor._toolbar.find_child("EventSheetSaveButton", true, false) as Button
	var ok: bool = _check("with no editor theme, Undo wears a glyph", undo_button.text, "↶")
	ok = _check("and Redo wears its own", redo_button.text, "↷") and ok
	ok = _check("neither invents an icon out of nothing", undo_button.icon == null and redo_button.icon == null, true) and ok
	# Save keeps its word here: its icon is one the editor has always carried, so there is no glyph
	# to fall back to and nothing to fall back from.
	ok = _check("Save keeps the word every reader knows", save_button.text, "Save") and ok
	# The words are still what the strip is addressed BY, whatever the face wears - a tutorial step
	# that says "pulse Undo" names the gesture, not the glyph.
	ok = _check("the face still answers to its words",
		str(undo_button.get_meta(EventSheetMenuBar.LABEL_META_KEY, "")), "Undo") and ok
	ok = _check("and the dock resolves it by them",
		editor._toolbar_control_label(undo_button), "Undo") and ok
	editor.free()
	# The one arrow Godot ships without a twin is DERIVED from the twin rather than hand-drawn, so
	# both arrows keep the editor's own stroke weight and its own recoloured palette.
	ok = _check("Undo is mirrored from Redo", str(EventSheetEditorIcons.MIRRORED.get("Undo", "")), "Redo") and ok
	# Preview project asked for "MainScene", which is not an icon name in this editor, so it arrived
	# iconless on the face, in the dropdown and on the expanded strip.
	ok = _check("Preview project asks for the icon Godot's own run bar wears",
		EventSheetRunControls.icon_for("preview_project"), "MainPlay") and ok
	var strip_sources: String = ""
	for path: String in ["res://addons/eventsheet/editor/dock/menu_bar.gd",
			"res://addons/eventsheet/editor/dock/run_controls.gd",
			"res://addons/eventsheet/editor/dock/play_button.gd"]:
		strip_sources += FileAccess.get_file_as_string(path)
	ok = _check("the sources were actually read", strip_sources.length() > 1000, true) and ok
	ok = _check("and no control asks for MainScene again",
		strip_sources.contains("\"MainScene\""), false) and ok
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


## A PRINTED KEY IS A HINT, NEVER A LISTENER. Hanging a live Shortcut on a menu item under the one
## Menu button does not add a label to the item - it adds a LISTENER, and one that wins: a MenuButton
## forwards every key press it sees to its popup (and recursively into its submenus) whenever the
## MenuButton is visible in the tree, popup closed and focus anywhere, and Godot runs _shortcut_input
## before _unhandled_key_input. So E stopped opening the Ghost Row and started opening the full
## picker, and every other printed key fired the sheet's handler from any non-text focus in the
## editor, ahead of Godot's own.
##
## Swept over the WHOLE cascade rather than over a typed list of items, so an item hinted by a later
## pass is held to this too. Two values per item: it carries the key (that is the hint), and the key
## is disabled (that is the not-a-listener).
static func _test_the_printed_keys_are_hints_only() -> bool:
	var editor: EventSheetEditor = _editor()
	var popup: PopupMenu = (editor._toolbar.find_child("EventSheetMenu", true, false) as MenuButton).get_popup()
	var live: PackedStringArray = PackedStringArray()
	var hinted: int = 0
	for menu: Node in _every_popup_under(popup):
		var submenu: PopupMenu = menu as PopupMenu
		for index: int in submenu.item_count:
			var shortcut: Shortcut = submenu.get_item_shortcut(index)
			if shortcut == null or shortcut.events.is_empty():
				continue
			hinted += 1
			if not submenu.is_item_shortcut_disabled(index):
				live.append("%s ▸ %s" % [str(submenu.name), submenu.get_item_text(index)])
	# Without this the sweep passes vacuously the day hint_key stops hanging keys on items at all.
	var ok: bool = _check("the cascade prints keys at all", hinted > 8, true)
	ok = _check("and not one of them is a live editor shortcut", live, PackedStringArray()) and ok
	editor.free()
	return ok


## Every PopupMenu in the cascade, the root included - the Menu's five groups and every submenu they
## hang, however deep. Walked rather than listed, because the cascade grows.
static func _every_popup_under(popup: PopupMenu) -> Array[PopupMenu]:
	var found: Array[PopupMenu] = [popup]
	for child: Node in popup.get_children():
		if child is PopupMenu:
			found.append_array(_every_popup_under(child as PopupMenu))
	return found


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


## POINTING AT A BUTTON IS NOT A CHOICE. The Manual's "show me this control" links, and the public
## EventSheets.pulse_control behind them, have to make a hidden button visible before they can pulse
## it - and that used to be done by calling set_full_toolbar(true), which WRITES the project's
## remembered choice. Reading a doc page that points at, say, Add Action permanently expanded a strip
## the reader had chosen to rest, with nothing to put it back.
##
## Two answers are separate now and both are pinned: what the strip is SHOWING, and what the reader
## CHOSE. Only the chevron and View ▸ Full toolbar move the second one.
static func _test_pointing_at_a_button_is_not_a_choice() -> bool:
	var editor: EventSheetEditor = _editor()
	var ok: bool = _check("the strip rests, and that is the reader's choice",
		[editor._menu_bar.full_toolbar(), editor._menu_bar.remembered_full_toolbar()], [false, false])
	var hidden: Button = editor._toolbar.find_child("EventSheetCodePanelButton", true, false) as Button
	ok = _check("the button being pointed at rests hidden", hidden.visible, false) and ok
	ok = _check("pointing at it says it belongs to this strip",
		editor.pulse_control(editor._toolbar_control_label(hidden)), true) and ok
	ok = _check("and now it can be seen", hidden.visible, true) and ok
	ok = _check("but nothing was decided on the reader's behalf",
		editor._menu_bar.remembered_full_toolbar(), false) and ok
	# The chevron still is a choice, in both directions.
	editor._menu_bar.set_full_toolbar(false)
	ok = _check("the chevron rests it again", hidden.visible, false) and ok
	editor._menu_bar.set_full_toolbar(true)
	ok = _check("and choosing the full strip IS remembered",
		editor._menu_bar.remembered_full_toolbar(), true) and ok
	# A control that is already on show needs no expanding, so pointing at Save decides nothing
	# either - and does not expand a strip that was resting.
	editor._menu_bar.set_full_toolbar(false)
	ok = _check("pointing at a resting control expands nothing",
		[editor.pulse_control("Save"), editor._menu_bar.full_toolbar()], [true, false]) and ok
	editor.free()
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
