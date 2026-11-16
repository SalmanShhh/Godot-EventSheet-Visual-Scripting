# Godot EventSheets - dragging a card in the shared card list: where a drop lands, and what a drag carries.
#
# A card dropped on the upper half of another goes in front of it, on the lower half behind it. A drag of a
# selected card carries the whole selection, in order. A drop that leaves the list as it was writes nothing.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "card_drag_drop_test"

const SCHEMA: Dictionary = {"kinds": [
	{"kind": "shake", "label": "Shake", "fields": [], "defaults": {}},
], "label_key": "label"}


static func run() -> bool:
	var ok: bool = true
	ok = _slot_pins() and ok
	ok = _drawer_pins() and ok
	ok = _record_pins() and ok
	return ok


static func _labels(drawer: EventSheetCardListDrawer) -> Array:
	var labels: Array = []
	for card: Variant in drawer.get_value():
		labels.append(str((card as Dictionary).get("label", "")))
	return labels


static func _slot_pins() -> bool:
	return SUPPORT.pins(TEST_NAME, [
		["the upper half of a card is the gap in front of it", EventSheetCardListDrawer.drop_slot(3, 4.0, 30.0), 3],
		["the lower half is the gap behind it", EventSheetCardListDrawer.drop_slot(3, 20.0, 30.0), 4],
		["the very middle counts as the lower half", EventSheetCardListDrawer.drop_slot(3, 15.0, 30.0), 4],
		["one card dropped two gaps further down", EventSheetCardListDrawer.slot_order(5, [0], 3), [1, 2, 0, 3, 4]],
		["one card dropped at the end", EventSheetCardListDrawer.slot_order(5, [1], 5), [0, 2, 3, 4, 1]],
		["one card dropped at the start", EventSheetCardListDrawer.slot_order(5, [3], 0), [3, 0, 1, 2, 4]],
		["two cards (2 and 5) dropped in front of the first travel together, in order", EventSheetCardListDrawer.slot_order(6, [1, 4], 0), [1, 4, 0, 2, 3, 5]],
		["and dropped behind the last", EventSheetCardListDrawer.slot_order(6, [1, 4], 6), [0, 2, 3, 5, 1, 4]],
		["dropped in the gap they already sit in, nothing changes", EventSheetCardListDrawer.slot_order(4, [1], 1), [0, 1, 2, 3]],
		["and the gap just behind them", EventSheetCardListDrawer.slot_order(4, [1], 2), [0, 1, 2, 3]],
	])


static func _drawer() -> EventSheetCardListDrawer:
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": SCHEMA})
	drawer.set_value([{"verb": "shake", "label": "A"}, {"verb": "shake", "label": "B"}, {"verb": "shake", "label": "C"},
		{"verb": "shake", "label": "D"}, {"verb": "shake", "label": "E"}, {"verb": "shake", "label": "F"}])
	return drawer


static func _drawer_pins() -> bool:
	var drawer: EventSheetCardListDrawer = _drawer()
	var announced: Array = [0]
	drawer.value_changed.connect(func(_value: Array) -> void: announced[0] += 1)
	var same_place: bool = drawer.move_cards_to_slot([2], 2)
	var nothing: int = announced[0]
	drawer.move_cards_to_slot([0], 3)
	var one_card: Array = _labels(drawer)
	drawer.set_value(_drawer().get_value())
	drawer.select_card(1, "click")
	drawer.select_card(4, "ctrl")
	drawer.move_cards_to_slot(drawer.selected_cards(), 0)
	var selection: Array = _labels(drawer)
	var still: Array = drawer.selected_cards()
	var picture: Control = drawer.drag_picture(0, 200.0, 2)
	var picture_text: String = ""
	for label: Node in picture.find_children("*", "Label", true, false):
		picture_text += (label as Label).text + "|"
	var picture_ignores_mouse: bool = (picture.get_child(0) as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE
	var row_still_there: String = drawer.card_labels()[0]
	picture.free()
	drawer.free()
	return SUPPORT.pins(TEST_NAME, [
		["a drop in the gap a card already sits in reports nothing moved", same_place, false],
		["and writes no change", nothing, 0],
		["one card dropped in front of the fourth", one_card, ["B", "C", "A", "D", "E", "F"]],
		["a dragged selection (2 and 5) lands together in order", selection, ["B", "E", "A", "C", "D", "F"]],
		["and stays selected", still, [0, 1]],
		["the picture that rides is the card's own line, with its title and how many travel", picture_text.contains("+1"), true],
		["and takes no mouse", picture_ignores_mouse, true],
		["making the picture leaves the list's own records alone", row_still_there is String, true],
	])


## A card that wears a picture (the Juice Player's) keeps the records that repaint it in place: making the picture that
## rides under the pointer must not swap them for its own copies.
static func _drawn(_entry: Dictionary, _scale: float) -> Dictionary:
	return {"texture": ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8)), "tint": true}


static func _record_pins() -> bool:
	var schema: Dictionary = {"tiles": true, "kinds": [{"kind": "a", "label": "A", "fields": [], "defaults": {}}], "icons": Callable(load("res://tests/card_drag_drop_test.gd"), "_drawn")}
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": schema})
	drawer.set_value([{"verb": "a"}, {"verb": "a"}])
	var before: Variant = drawer._pictures.get(0)
	var had_picture: bool = before != null
	var titles_before: Variant = drawer._titles.get(0)
	var picture: Control = drawer.drag_picture(0, 220.0, 1)
	var same_picture: bool = drawer._pictures.get(0) == before
	var same_title: bool = drawer._titles.get(0) == titles_before
	picture.free()
	drawer.free()
	return SUPPORT.pins(TEST_NAME, [
		["a card of a list that draws pictures has a picture record to keep", had_picture, true],
		["the real card keeps its own picture record while a copy is made", same_picture, true],
		["and its own title record", same_title, true],
	])
