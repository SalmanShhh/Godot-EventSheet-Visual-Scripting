# Godot EventSheets - selecting cards, and copying and pasting them between objects.
#
# THE ONE THING THIS FILE IS ABOUT: a selection is a VIEW, never data. Clicking, Shift-clicking and
# Ctrl-clicking cards change what is selected and nothing in the saved list; a paste ADDS the cards
# under the last selected one, as one change (one Ctrl+Z step); a card that travels between two
# objects as clipboard text arrives with every key and every type it left with.
#
# The selection lives in the shared card-list drawer, so a Drawing Prefab's list has it too. The
# headless run has no clipboard (the display server keeps none), so the text-taking doors are pinned
# here and the keys that read the real clipboard are proven in the running editor.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "card_selection"

const SCHEMA: Dictionary = {"kinds": [
	{"kind": "shake", "label": "Shake", "fields": [], "defaults": {"amount": 0.4}},
	{"kind": "flash", "label": "Flash", "fields": [], "defaults": {"amount": 1.0}}
], "label_key": "label"}


static func run() -> bool:
	var ok: bool = true
	ok = _selection_pins() and ok
	ok = _paste_pins() and ok
	ok = _gesture_pins() and ok
	ok = _key_pins() and ok
	ok = _header_pins() and ok
	return ok


static func _drawer(cards: Array) -> EventSheetCardListDrawer:
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": SCHEMA})
	drawer.set_value(cards)
	return drawer


static func _three() -> Array:
	return [{"verb": "shake", "label": "A"}, {"verb": "flash", "label": "B"}, {"verb": "shake", "label": "C"}]


static func _labels(drawer: EventSheetCardListDrawer) -> Array:
	var labels: Array = []
	for card: Variant in drawer.get_value():
		labels.append(str((card as Dictionary).get("label", "")))
	return labels


static func _key(code: Key, ctrl: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.ctrl_pressed = ctrl
	return event


## Click, Shift+click and Ctrl+click, and a selection that follows its cards through a move.
static func _selection_pins() -> bool:
	var drawer: EventSheetCardListDrawer = _drawer(_three())
	var emitted: Array = [0]
	drawer.value_changed.connect(func(_value: Array) -> void: emitted[0] += 1)
	drawer.select_card(0, "click")
	var after_click: Array = drawer.selected_cards()
	drawer.select_card(2, "shift")
	var after_shift: Array = drawer.selected_cards()
	drawer.select_card(1, "ctrl")
	var after_ctrl: Array = drawer.selected_cards()
	drawer.move_card(0, 2)
	var after_move: Array = drawer.selected_cards()
	var emitted_by_selecting: int = emitted[0]
	drawer.set_card_enabled(0, false)
	var after_edit: Array = drawer.selected_cards()
	var saved_after_selecting: Array = drawer.get_value()
	drawer.set_value(_three())
	var after_outside_change: Array = drawer.selected_cards()
	drawer.free()
	return SUPPORT.pins(TEST_NAME, [
		["a click selects one card", after_click, [0]],
		["Shift+click selects the run between", after_shift, [0, 1, 2]],
		["Ctrl+click takes one out", after_ctrl, [0, 2]],
		["a moved card stays selected where it lands", after_move, [1, 2]],
		["selecting changes nothing that is saved", saved_after_selecting.size(), 3],
		["and announces no change to the Inspector until the move", emitted_by_selecting, 1],
		["an edit to a card leaves the selection where it was", after_edit, [1, 2]],
		["a list handed in from outside (an undo) clears it, because the positions may mean other cards", after_outside_change, []]
	])


## A paste adds under the last selected card, as ONE change.
static func _paste_pins() -> bool:
	var drawer: EventSheetCardListDrawer = _drawer(_three())
	var clipboard: String = EventSheetCardSchemas.cards_to_text([{"verb": "flash", "label": "X"}, {"verb": "flash", "label": "Y"}])
	var emitted: Array = [0]
	drawer.value_changed.connect(func(_value: Array) -> void: emitted[0] += 1)
	drawer.select_card(0, "click")
	drawer.paste_after_selection(clipboard)
	var labels: Array = _labels(drawer)
	var after_paste: Array = drawer.selected_cards()
	var emitted_by_paste: int = emitted[0]
	drawer.clear_selection()
	drawer.paste_after_selection(clipboard)
	var at_the_end: Array = _labels(drawer)
	drawer.paste_after_selection("not a card list")
	var after_junk: Array = _labels(drawer)
	drawer.free()
	return SUPPORT.pins(TEST_NAME, [
		["a paste adds under the selected card instead of replacing the list", labels, ["A", "X", "Y", "B", "C"]],
		["and is one change, so one Ctrl+Z takes it back", emitted_by_paste, 1],
		["and the pasted cards are the ones selected afterwards", after_paste, [1, 2]],
		["with nothing selected a paste goes at the end", at_the_end, ["A", "X", "Y", "B", "C", "X", "Y"]],
		["text that is not a card list pastes nothing", after_junk, at_the_end]
	])


## Delete, Cut, Copy and Duplicate act on every selected card at once, each as one change.
static func _gesture_pins() -> bool:
	var drawer: EventSheetCardListDrawer = _drawer(_three())
	var emitted: Array = [0]
	drawer.value_changed.connect(func(_value: Array) -> void: emitted[0] += 1)
	drawer.select_card(1, "click")
	drawer.select_card(2, "shift")
	drawer.remove_selected()
	var deleted: Array = _labels(drawer)
	var emitted_by_delete: int = emitted[0]
	var after_delete: Array = drawer.selected_cards()

	drawer.set_value(_three())
	emitted[0] = 0
	drawer.select_card(0, "click")
	drawer.select_card(2, "ctrl")
	drawer.duplicate_selected()
	var duplicated: Array = _labels(drawer)
	var after_duplicate: Array = drawer.selected_cards()
	var emitted_by_duplicate: int = emitted[0]

	drawer.set_value(_three())
	emitted[0] = 0
	drawer.select_card(1, "click")
	drawer.select_card(2, "shift")
	var copied: String = drawer.copy_selected()
	var copy_left_list_alone: Array = _labels(drawer)
	var cut: String = drawer.cut_selected()
	var after_cut: Array = _labels(drawer)
	var emitted_by_cut: int = emitted[0]
	var copied_labels: Array = []
	for card: Variant in EventSheetCardSchemas.cards_from_text(copied):
		copied_labels.append(str((card as Dictionary).get("label", "")))

	drawer.set_value(_three())
	var nothing_to_remove: bool = drawer.remove_selected()
	drawer.free()
	return SUPPORT.pins(TEST_NAME, [
		["Delete removes every selected card at once", deleted, ["A"]],
		["as one change", emitted_by_delete, 1],
		["and nothing is selected after it", after_delete, []],
		["Duplicate copies each selected card in place", duplicated, ["A", "A", "B", "C", "C"]],
		["and selects the copies", after_duplicate, [1, 4]],
		["as one change", emitted_by_duplicate, 1],
		["Copy puts the selected cards, and only those, in the text", copied_labels, ["B", "C"]],
		["and leaves the list alone", copy_left_list_alone, ["A", "B", "C"]],
		["Cut takes the same text", cut, copied],
		["and removes them as one change", [after_cut, emitted_by_cut], [["A"], 1]],
		["Delete with nothing selected does nothing and says so", nothing_to_remove, false]
	])


## The keys, as far as a headless run can reach them: which ones the drawer takes, and that one with
## nothing to act on is left for Godot.
static func _key_pins() -> bool:
	var drawer: EventSheetCardListDrawer = _drawer(_three())
	var none_selected: bool = drawer.handle_key(_key(KEY_DELETE))
	var copy_with_none: bool = drawer.handle_key(_key(KEY_C, true))
	drawer.select_card(0, "click")
	var duplicate_taken: bool = drawer.handle_key(_key(KEY_D, true))
	var after_duplicate: Array = _labels(drawer)
	var delete_taken: bool = drawer.handle_key(_key(KEY_DELETE))
	var after_delete: Array = _labels(drawer)
	var other_key: bool = drawer.handle_key(_key(KEY_A))
	var released: InputEventKey = _key(KEY_DELETE)
	released.pressed = false
	drawer.select_card(0, "click")
	var release_ignored: bool = drawer.handle_key(released)
	drawer.free()
	return SUPPORT.pins(TEST_NAME, [
		["Delete with nothing selected is left for the editor", none_selected, false],
		["Ctrl+C with nothing selected is left for the editor's own copy of a value", copy_with_none, false],
		["Ctrl+D with a card selected is taken", duplicate_taken, true],
		["and duplicates it", after_duplicate, ["A", "A", "B", "C"]],
		["Delete with cards selected is taken", delete_taken, true],
		["and removes the selection (the copy)", after_delete, ["A", "B", "C"]],
		["a key the list has no use for is left alone", other_key, false],
		["a key release is never taken", release_ignored, false]
	])


## A card's whole line answers the mouse, so a right click on it reaches the card and the card can
## open its menu: no part of the header may swallow the click except the controls that are buttons.
static func _header_pins() -> bool:
	var drawer: EventSheetCardListDrawer = _drawer(_three())
	var row: Control = drawer._list.get_child(0)
	var swallowing: Array = []
	for node: Node in row.find_children("*", "PanelContainer", true, false):
		if (node as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			swallowing.append(node.get_class())
	var focusable: int = drawer.focus_mode
	var selected_box: StyleBox = null
	var plain_box: StyleBox = null
	drawer.select_card(0, "click")
	var line: PanelContainer = drawer._lines.get(0) as PanelContainer
	var other: PanelContainer = drawer._lines.get(1) as PanelContainer
	if line != null:
		selected_box = line.get_theme_stylebox("panel")
	if other != null:
		plain_box = other.get_theme_stylebox("panel")
	var filled: bool = selected_box is StyleBoxFlat and plain_box is StyleBoxFlat \
		and (selected_box as StyleBoxFlat).bg_color != (plain_box as StyleBoxFlat).bg_color
	var outlined: bool = false
	if selected_box is StyleBoxFlat:
		var flat: StyleBoxFlat = selected_box as StyleBoxFlat
		outlined = flat.border_width_left + flat.border_width_top + flat.border_width_right + flat.border_width_bottom > 0
	drawer.free()
	return SUPPORT.pins(TEST_NAME, [
		["no panel in a card's line swallows a right click", swallowing, []],
		["the list can hold the keyboard focus the keys need", focusable, Control.FOCUS_CLICK],
		["a selected card is drawn with a fill of its own", filled, true],
		["and with no outline", outlined, false]
	])