# Godot EventSheets - changing the order of cards from the keyboard and the card menu.
#
# Alt+Up and Alt+Down move the selected cards one place, the way Alt+Up and Alt+Down move lines in
# Godot's script editor: the cards stay selected so the next press moves them again, a held key
# (an echo) keeps walking them, and each press is ONE change announced. The card menu says the keys
# beside Move up and Move down, gains Move to bottom, and its four moves act on every selected card
# when the clicked card is one of them, as Remove already does.
#
# The drawer is shared, so the Juice Player's list and the Drawing Prefab's shapes both have this.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "card_reorder_keys_test"

const DRAWER_PATH := "res://addons/eventsheet/editor/inspector/card_list_drawer.gd"
## Read by name, so a drawer without the entry fails a pin instead of failing to compile.
static var _to_bottom: int = -1

const SCHEMA: Dictionary = {"kinds": [
	{"kind": "shake", "label": "Shake", "fields": [], "defaults": {}},
], "label_key": "label"}


static func run() -> bool:
	_to_bottom = int((load(DRAWER_PATH) as GDScript).get_script_constant_map().get("MENU_MOVE_TO_BOTTOM", -1))
	var ok: bool = true
	ok = _key_pins() and ok
	ok = _menu_pins() and ok
	ok = _order_pins() and ok
	ok = fold_pins() and ok
	return ok


static func _drawer() -> EventSheetCardListDrawer:
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": SCHEMA})
	drawer.set_value([{"verb": "shake", "label": "A"}, {"verb": "shake", "label": "B"},
		{"verb": "shake", "label": "C"}, {"verb": "shake", "label": "D"}])
	return drawer


static func _labels(drawer: EventSheetCardListDrawer) -> Array:
	var labels: Array = []
	for card: Variant in drawer.get_value():
		labels.append(str((card as Dictionary).get("label", "")))
	return labels


static func _alt(code: Key, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.alt_pressed = true
	event.echo = echo
	return event


static func _key_pins() -> bool:
	var drawer: EventSheetCardListDrawer = _drawer()
	var announced: Array = [0]
	drawer.value_changed.connect(func(_value: Array) -> void: announced[0] += 1)
	var nothing_selected: bool = drawer.handle_key(_alt(KEY_UP))
	drawer.select_card(1, "click")
	drawer.select_card(2, "ctrl")
	var taken: bool = drawer.handle_key(_alt(KEY_UP))
	var after_up: Array = _labels(drawer)
	var still_selected: Array = drawer.selected_cards()
	var at_top: bool = drawer.handle_key(_alt(KEY_UP))
	var unchanged_at_top: Array = _labels(drawer)
	var held: bool = drawer.handle_key(_alt(KEY_DOWN, true))
	var after_held: Array = _labels(drawer)
	var count: int = announced[0]
	drawer.free()
	return SUPPORT.pins(TEST_NAME, [
		["Alt+Up with nothing selected is left for the editor", nothing_selected, false],
		["Alt+Up with cards selected is taken", taken, true],
		["and moves them one place up together", after_up, ["B", "C", "A", "D"]],
		["they stay selected, so the next press moves them again", still_selected, [0, 1]],
		["at the top there is nowhere to go, and the key is left alone", [at_top, unchanged_at_top], [false, ["B", "C", "A", "D"]]],
		["a held key keeps walking them", [held, after_held], [true, ["A", "B", "C", "D"]]],
		["each press that moved something is one change", count, 2],
	])


static func _menu_pins() -> bool:
	var drawer: EventSheetCardListDrawer = _drawer()
	var popup: PopupMenu = PopupMenu.new()
	drawer._fill_card_menu(popup)
	var words: Array = []
	var down_keys: String = ""
	for index: int in range(popup.item_count):
		if popup.is_item_separator(index):
			continue
		words.append(popup.get_item_text(index))
		if popup.get_item_id(index) == EventSheetCardListDrawer.MENU_MOVE_DOWN:
			down_keys = OS.get_keycode_string(popup.get_item_accelerator(index))
	popup.free()
	drawer.select_card(0, "click")
	drawer.select_card(1, "ctrl")
	drawer._on_menu(1, _to_bottom)
	var to_bottom: Array = _labels(drawer)
	drawer._on_menu(2, EventSheetCardListDrawer.MENU_MOVE_TO_TOP)
	var back_to_top: Array = _labels(drawer)
	drawer.free()
	return SUPPORT.pins(TEST_NAME, [
		["the drawer has a Move to bottom entry", _to_bottom >= 0, true],
		["the menu offers Move to bottom after Move down", words, ["Duplicate", "Cut", "Copy", "Paste", "Paste over",
			"Move to top", "Move up", "Move down", "Move to bottom", "Remove"]],
		["Move down says its key", down_keys, "Alt+Down"],
		["Move to bottom on a selected card moves every selected card, in order", to_bottom, ["C", "D", "A", "B"]],
		["and Move to top brings them back", back_to_top, ["A", "B", "C", "D"]],
	])


## Every kind of move, for one card and for a split selection (cards 2 and 5 of six), and at both ends.
static func _order_pins() -> bool:
	var rows: Array = []
	var cases: Array = [
		["one card (the third) up", [2], -1, [0, 2, 1, 3, 4, 5]],
		["one card (the third) down", [2], 1, [0, 1, 3, 2, 4, 5]],
		["one card (the third) to the top", [2], -2, [2, 0, 1, 3, 4, 5]],
		["one card (the third) to the bottom", [2], 2, [0, 1, 3, 4, 5, 2]],
		["a split selection up", [1, 4], -1, [1, 0, 2, 4, 3, 5]],
		["a split selection down", [1, 4], 1, [0, 2, 1, 3, 5, 4]],
		["a split selection to the top", [1, 4], -2, [1, 4, 0, 2, 3, 5]],
		["a split selection to the bottom", [1, 4], 2, [0, 2, 3, 5, 1, 4]],
		["the first card up goes nowhere", [0], -1, [0, 1, 2, 3, 4, 5]],
		["the last card down goes nowhere", [5], 1, [0, 1, 2, 3, 4, 5]],
		["the first card to the top goes nowhere", [0], -2, [0, 1, 2, 3, 4, 5]],
		["the last card to the bottom goes nowhere", [5], 2, [0, 1, 2, 3, 4, 5]],
		["a selection at the top edge: the card at the edge waits, the other moves", [0, 3], -1, [0, 1, 3, 2, 4, 5]],
		["a run at the bottom edge stays", [4, 5], 1, [0, 1, 2, 3, 4, 5]],
	]
	for case: Array in cases:
		rows.append([str(case[0]), EventSheetCardListDrawer.moved_order(6, case[1], int(case[2])), case[3]])
	var drawer: EventSheetCardListDrawer = _drawer()
	var announced: Array = [0]
	drawer.value_changed.connect(func(_value: Array) -> void: announced[0] += 1)
	drawer.select_card(0, "click")
	var past_top: bool = drawer.move_selected(-1)
	drawer._on_menu(0, EventSheetCardListDrawer.MENU_MOVE_TO_TOP)
	var nothing_written: int = announced[0]
	drawer._on_menu(3, EventSheetCardListDrawer.MENU_MOVE_UP)
	var menu_alone: Array = _labels(drawer)
	var one_change: int = announced[0]
	drawer.free()
	rows.append(["a move past the end reports nothing moved", past_top, false])
	rows.append(["and a move that changes nothing writes nothing and makes no change", nothing_written, 0])
	rows.append(["the menu moves a card outside the selection on its own", menu_alone, ["A", "B", "D", "C"]])
	rows.append(["and that is one change", one_change, 1])
	return SUPPORT.pins(TEST_NAME, rows)


## An open Timing foldout belongs to its CARD: after the cards are moved or one is removed, the fold that
## was open is still open on the same card, and no other card opens by chance.
static func fold_pins() -> bool:
	var drawer: EventSheetCardListDrawer = _drawer()
	drawer.set("_open_folds", {"1:Timing": true})
	drawer.select_card(1, "click")
	drawer.handle_key(_alt(KEY_DOWN))
	var after_move: Dictionary = (drawer.get("_open_folds") as Dictionary).duplicate()
	drawer.handle_key(_alt(KEY_UP))
	drawer.handle_key(_alt(KEY_UP))
	var after_back: Dictionary = (drawer.get("_open_folds") as Dictionary).duplicate()
	drawer.free()
	drawer = _drawer()
	drawer.set("_open_folds", {"2:Timing": true})
	drawer.select_card(0, "click")
	drawer.remove_selected()
	var after_remove: Dictionary = (drawer.get("_open_folds") as Dictionary).duplicate()
	drawer.free()
	return SUPPORT.pins(TEST_NAME, [
		["moving card B down one place takes its open Timing fold with it", after_move, {"2:Timing": true}],
		["and moving it up twice takes it to the top", after_back, {"0:Timing": true}],
		["removing a card above it moves the fold to its new place", after_remove, {"1:Timing": true}],
	])
