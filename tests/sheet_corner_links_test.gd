# EventSheets test - ADDING LIVES IN THE SHEET.
#
# The four Add buttons left the resting strip and the Add menu folded into the one cascading Menu.
# Nothing about adding was removed - it moved to where the adding happens. The canvas carries the
# two doors itself, in its own corners: a muted "Add event" at the top left and a "+ Add…" at the
# top right, on EVERY sheet, pinned to the corners a reader can see rather than to content that
# scrolls away.
#
# Pinned by VALUE: the exact rects both links land in, at rest and after a resize; which point hits
# which link; what each link does; and the Add cascade's item list with its keys read back off the
# menu itself. A count of items would pass for a menu that had swapped one command for another, and
# a "the links exist" check would pass for two links stacked in the same corner.
@tool
class_name SheetCornerLinksTest
extends RefCounted


## Label widths this test lays the links out with. Made up on purpose: the geometry is a pure
## function of the measured width, so pinning it against numbers this file owns keeps the answer the
## same on a machine whose editor font is not this one's.
const ADD_EVENT_WIDTH: float = 60.0
const ADD_MENU_WIDTH: float = 44.0
const LINK_SIZE: int = 12


## An undo manager the editor can be stood up with, exactly as the other toolbar tests use.
class NoopUndoManager:
	extends RefCounted

	func create_action(_name: String) -> void:
		pass

	func add_do_method(_target: Variant, _method: Variant, _arg: Variant = null) -> void:
		pass

	func add_undo_method(_target: Variant, _method: Variant, _arg: Variant = null) -> void:
		pass

	func commit_action() -> void:
		pass

	func clear_history() -> void:
		pass

	func has_undo() -> bool:
		return false

	func has_redo() -> bool:
		return false


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_two_corners() and ok
	ok = _test_the_links_move_with_the_window() and ok
	ok = _test_what_each_link_opens() and ok
	ok = _test_the_links_own_their_band() and ok
	ok = _test_a_sheet_being_read_offers_nothing() and ok
	ok = _test_the_add_cascade() and ok
	ok = _test_the_four_buttons_are_still_there() and ok
	return ok


## BOTH CORNERS, at exact coordinates. "Add event" hangs off the visible LEFT edge and "+ Add…" off
## the visible RIGHT one, which is the whole claim: two links, two corners, never one corner twice.
static func _test_the_two_corners() -> bool:
	var widths: Dictionary = {"add_event": ADD_EVENT_WIDTH, "add_menu": ADD_MENU_WIDTH}
	var rects: Dictionary = ViewportCornerLinks.layout(widths, 0.0, 800.0, 0.0, LINK_SIZE)
	var ok: bool = _check("the sheet carries exactly two corner links", rects.keys(),
		["add_event", "add_menu"])
	ok = _check("Add event sits in the top-left corner", rects["add_event"],
		Rect2(12.0, 6.0, ADD_EVENT_WIDTH, 20.0)) and ok
	ok = _check("+ Add… sits in the top-right corner", rects["add_menu"],
		Rect2(800.0 - 12.0 - ADD_MENU_WIDTH, 6.0, ADD_MENU_WIDTH, 20.0)) and ok
	# Hit-tested like the getting-started buttons: a point inside a link's own rect names that link,
	# and a point between them names neither, so a click on the sheet is still a click on the sheet.
	ok = _check("a click on the left link names it",
		ViewportCornerLinks.link_at_in(rects, Vector2(20.0, 12.0)), "add_event") and ok
	ok = _check("a click on the right link names it",
		ViewportCornerLinks.link_at_in(rects, Vector2(770.0, 12.0)), "add_menu") and ok
	ok = _check("a click between them names neither",
		ViewportCornerLinks.link_at_in(rects, Vector2(400.0, 12.0)), "") and ok
	ok = _check("and a click below them names neither",
		ViewportCornerLinks.link_at_in(rects, Vector2(20.0, 90.0)), "") and ok
	return ok


## THEY ARE PINNED TO THE WINDOW, not to the content. A narrower window brings the right-hand link
## in; a scrolled sheet carries both links down with the window's own top edge, so neither can ever
## scroll off the sheet the way a row does.
static func _test_the_links_move_with_the_window() -> bool:
	var widths: Dictionary = {"add_event": ADD_EVENT_WIDTH, "add_menu": ADD_MENU_WIDTH}
	var narrow: Dictionary = ViewportCornerLinks.layout(widths, 0.0, 520.0, 0.0, LINK_SIZE)
	var ok: bool = _check("a resize leaves the left link exactly where it was",
		narrow["add_event"], Rect2(12.0, 6.0, ADD_EVENT_WIDTH, 20.0))
	ok = _check("and brings the right link in with the edge", narrow["add_menu"],
		Rect2(520.0 - 12.0 - ADD_MENU_WIDTH, 6.0, ADD_MENU_WIDTH, 20.0)) and ok
	# Scrolled 300 px down and 40 px across: both links ride the visible corners.
	var scrolled: Dictionary = ViewportCornerLinks.layout(widths, 40.0, 40.0 + 520.0, 300.0, LINK_SIZE)
	ok = _check("scrolled, the left link rides the window's left edge",
		scrolled["add_event"], Rect2(52.0, 306.0, ADD_EVENT_WIDTH, 20.0)) and ok
	ok = _check("and the right link rides its right edge", scrolled["add_menu"],
		Rect2(40.0 + 520.0 - 12.0 - ADD_MENU_WIDTH, 306.0, ADD_MENU_WIDTH, 20.0)) and ok
	return ok


## WHAT EACH LINK OPENS. Neither is a new power: the left one runs the dock's add-event path (the E
## key's, the Ghost Row's, the trailing row's) and the right one opens the very menu a right-click on
## empty space opens. Pinned through the dock's own router, so a link that stopped reaching its door
## is named here rather than in a screenshot.
static func _test_what_each_link_opens() -> bool:
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var ok: bool = _check("the viewport announces a corner link and the dock listens",
		editor._viewport.corner_link_activated.is_connected(
			editor._on_viewport_corner_link_activated), true)
	# The right link's door IS the empty-space context menu, which is the same PopupMenu the
	# right-click builds - one menu, two ways in. Popping a menu up from a dock that is in no tree
	# prints two engine errors ("data.tree is null" / "!is_inside_tree()") and does nothing else;
	# that is the price of exercising the real router here rather than a stand-in, and the row
	# context menu's own test pays it the same way.
	editor._on_viewport_corner_link_activated("add_menu", Vector2.ZERO)
	ok = _check("+ Add… opens the empty-space menu, and clears the row context first",
		editor._context_row == null, true) and ok
	ok = _check("that menu is the one the right-click opens",
		editor._empty_space_context_menu.name, "EventSheetEmptySpaceContextMenu") and ok
	# The words each link says on hover, with the key printed from the ONE shortcut table rather
	# than typed here - a rebind shows through without an edit.
	var binding: String = EventSheetShortcuts.binding_for("add_event")
	ok = _check("Add event says what it does and prints its key",
		ViewportCornerLinks.tooltip_for("add_event").ends_with("(%s)" % binding), true) and ok
	ok = _check("+ Add… names the menu it opens, with no key of its own",
		ViewportCornerLinks.tooltip_for("add_menu"),
		"Everything you can add here - the same menu right-clicking empty space opens.") and ok
	editor.free()
	return ok


## THE LINKS OWN A BAND, and the sheet starts below it. They used to be drawn straight into the
## first row's lanes - "Add event" over row 1's condition lane and "+ Add…" over the row's own
## "+ Add action…" cell - and they claim the click before the row hit-test, so the top of row 1
## could not be clicked as a row at all, and on a sheet with a head band the left link sat over the
## band's words. Pinned by VALUE: the band's height, that row 1 starts under it, and that a click in
## the band is a click on no row.
static func _test_the_links_own_their_band() -> bool:
	var ok: bool = _check("the band is the words plus the air around them",
		ViewportCornerLinks.band_height(LINK_SIZE), 6.0 * 2.0 + float(LINK_SIZE) + 8.0)
	# The laid-out link sits INSIDE its own band rather than through the row beneath it.
	var widths: Dictionary = {"add_event": ADD_EVENT_WIDTH, "add_menu": ADD_MENU_WIDTH}
	var rects: Dictionary = ViewportCornerLinks.layout(widths, 0.0, 800.0, 0.0, LINK_SIZE)
	var link: Rect2 = rects["add_event"]
	ok = _check("and the words sit inside it",
		link.position.y >= 0.0 and link.position.y + link.size.y <= ViewportCornerLinks.band_height(LINK_SIZE),
		true) and ok
	var editor: EventSheetEditor = _editor_with_one_event()
	var offset: float = editor._viewport.content_top_offset()
	ok = _check("an editing surface owes the links a band", offset > 0.0, true) and ok
	ok = _check("and row 1 starts under it, not through it",
		editor._viewport._get_row_top(0), offset) and ok
	ok = _check("a click in the band is a click on no row",
		editor._viewport._find_row_index_at_y(offset * 0.5), -1) and ok
	ok = _check("and a click just under it is row 1",
		editor._viewport._find_row_index_at_y(offset + 2.0), 0) and ok
	editor.free()
	return ok


## A SHEET BEING READ OFFERS NOTHING TO ADD. An opened pack, a read-only resource and reading mode
## already suppress the trailing "+ Add event…" footers, because they are an offer the view cannot
## honour - and these two corner doors are the same offer in the corners, so they were the one
## "Add" left standing on a sheet nothing can be added to. With no links there is no band either:
## a read-only preview starts exactly where it always did.
static func _test_a_sheet_being_read_offers_nothing() -> bool:
	var editor: EventSheetEditor = _editor_with_one_event()
	var ok: bool = _check("an editable sheet carries them",
		ViewportCornerLinks.shown_on(editor._viewport), true)
	editor._current_sheet.read_only = true
	editor._viewport._rebuild_row_metrics()
	ok = _check("a read-only sheet does not", ViewportCornerLinks.shown_on(editor._viewport), false) and ok
	ok = _check("and owes them no band", editor._viewport.content_top_offset(), 0.0) and ok
	ok = _check("so its first row starts at the top",
		editor._viewport._get_row_top(0), 0.0) and ok
	editor._current_sheet.read_only = false
	editor._viewport.reading_mode = true
	ok = _check("reading mode does not either",
		ViewportCornerLinks.shown_on(editor._viewport), false) and ok
	editor._viewport.reading_mode = false
	editor._viewport.set_figure_mode(true)
	ok = _check("and neither does an illustration",
		ViewportCornerLinks.shown_on(editor._viewport), false) and ok
	editor.free()
	return ok


## An editor over a sheet with one event in it, so the row metrics have a row 1 to place.
static func _editor_with_one_event() -> EventSheetEditor:
	var sheet: EventSheetResource = EventSheetResource.new()
	var event_row: EventRow = EventRow.new()
	event_row.trigger_provider_id = "Core"
	event_row.trigger_id = "OnProcess"
	sheet.events.append(event_row)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	return editor


## THE ADD CASCADE. Add is a submenu of the one Menu button now, and it TEACHES THE KEYS: the five
## reflexes lead it, each printing its binding from EventSheetShortcuts, and so do Global Variable
## and Function. Pinned as the item list plus the key beside each item, read back off the menu.
static func _test_the_add_cascade() -> bool:
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var menu: MenuButton = editor._toolbar.find_child("EventSheetMenu", true, false) as MenuButton
	var add_popup: PopupMenu = menu.get_popup().find_child("EventSheetAddMenu", true, false) as PopupMenu
	var ok: bool = _check("Add hangs off the one Menu button", add_popup != null, true)
	if add_popup == null:
		editor.free()
		return false
	var head: PackedStringArray = PackedStringArray()
	for index: int in mini(add_popup.item_count, 6):
		head.append(add_popup.get_item_text(index))
	ok = _check("the five reflexes lead the Add menu", head,
		PackedStringArray(["Event", "Condition", "Action", "Group", "Comment", ""])) and ok
	# The key beside each item, read off the item's own Shortcut - which is what the reader sees.
	for entry: Array in [[12, "add_event"], [13, "add_condition"], [14, "add_action"],
			[15, "add_group"], [16, "add_comment"], [8, "add_variable"], [3, "add_function"]]:
		var index: int = add_popup.get_item_index(int(entry[0]))
		var shortcut: Shortcut = add_popup.get_item_shortcut(index)
		var printed: String = "" if shortcut == null else shortcut.get_as_text()
		var binding: String = EventSheetShortcuts.binding_for(str(entry[1]))
		ok = _check("item %d prints the %s key from the table" % [int(entry[0]), str(entry[1])],
			printed.to_lower().replace(" ", "").ends_with(binding.to_lower().replace("+", "")),
			true) and ok
	# The ids are the compatibility promise: the palette, the shortcut dispatch and the suite all
	# address these items by number, so a moved item keeps its own and a new one takes a fresh one.
	ok = _check("Global Variable… kept its id", add_popup.get_item_text(add_popup.get_item_index(8)),
		"Global Variable…") and ok
	ok = _check("and the code item kept the id Simple Mode gates it by",
		add_popup.get_item_text(add_popup.get_item_index(4)),
		"Code (GDScript) on Selected Event") and ok
	editor.free()
	return ok


## NOTHING WAS REMOVED. The four Add buttons are off the RESTING strip and whole on the expanded
## one, keys, handlers and all - which is why the corner links are a second door rather than a
## replacement.
static func _test_the_four_buttons_are_still_there() -> bool:
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var resting: PackedStringArray = PackedStringArray()
	var expanded: PackedStringArray = PackedStringArray()
	for child: Node in editor._toolbar.get_children():
		if child is Button and not str((child as Button).text).is_empty():
			expanded.append(str((child as Button).text))
			if (child as Control).visible:
				resting.append(str((child as Button).text))
	var ok: bool = true
	for label: String in ["Add Event", "Add Condition", "Add Action", "Add Code"]:
		ok = _check("%s is off the resting strip" % label, resting.has(label), false) and ok
		ok = _check("%s is still on the strip" % label, expanded.has(label), true) and ok
	editor.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sheet_corner_links_test: %s" % label)
		return true
	print("[FAIL] sheet_corner_links_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
