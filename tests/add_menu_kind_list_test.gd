# Godot EventSheets - the Add menu's block items open the kind they say, whenever the list grew.
#
# The items were numbered by their place in the registry's list at the moment the menu was built, and
# the click read the CURRENT list by that number. A kind registered after the menu was built moved
# every kind after it one place along, so a click opened its neighbour. Each item now remembers the
# kind it was made for, and the menu offers a newly registered kind the next time it opens.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "add_menu_kind_list_test"


class EarlyKind:
	extends EventSheetBlockKind

	func _init() -> void:
		kind_id = "aaa_menu_probe.early"
		title = "Early Probe"


static func run() -> bool:
	var ok: bool = true
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	var menu_button: MenuButton = editor._toolbar.find_child("EventSheetMenu", true, false) as MenuButton
	var add_menu: PopupMenu = menu_button.get_popup().find_child("EventSheetAddMenu", true, false) as PopupMenu
	var note_id: int = _id_of(add_menu, "Note…")
	ok = SUPPORT.check(P, "the menu offers the note block", note_id >= 100, true) and ok

	# A kind that sorts before every other one is registered after the menu was built.
	var early: EarlyKind = EarlyKind.new()
	EventSheetBlockRegistry.register_kind(early)
	add_menu.id_pressed.emit(note_id)
	ok = SUPPORT.check(P, "a click still opens the kind its item names",
		_opened_kind(editor), "demo.note") and ok
	ok = SUPPORT.check(P, "the new kind is not offered until the menu opens", _id_of(add_menu, "Early Probe…"), -1) and ok

	# Opening the menu brings the list up to date.
	add_menu.about_to_popup.emit()
	var early_id: int = _id_of(add_menu, "Early Probe…")
	ok = SUPPORT.check(P, "opening the menu offers the new kind", early_id >= 100, true) and ok
	add_menu.id_pressed.emit(early_id)
	ok = SUPPORT.check(P, "and its item opens it", _opened_kind(editor), "aaa_menu_probe.early") and ok
	add_menu.id_pressed.emit(_id_of(add_menu, "Note…"))
	ok = SUPPORT.check(P, "the note item still opens the note after the refresh", _opened_kind(editor), "demo.note") and ok
	var count_with: int = add_menu.item_count

	# Taking the kind back takes its item away the next time the menu opens.
	EventSheetBlockRegistry.unregister_kind(early.kind_id)
	add_menu.about_to_popup.emit()
	ok = SUPPORT.check(P, "an unregistered kind leaves the menu", _id_of(add_menu, "Early Probe…"), -1) and ok
	ok = SUPPORT.check(P, "and the menu is one item shorter", add_menu.item_count, count_with - 1) and ok
	editor.free()
	return ok


static func _id_of(menu: PopupMenu, text: String) -> int:
	for index: int in range(menu.item_count):
		if menu.get_item_text(index) == text:
			return menu.get_item_id(index)
	return -1


static func _opened_kind(editor: EventSheetEditor) -> String:
	var dialog: RefCounted = editor._custom_block_dialog
	var kind: EventSheetBlockKind = dialog._target_kind
	return "" if kind == null else kind.kind_id
