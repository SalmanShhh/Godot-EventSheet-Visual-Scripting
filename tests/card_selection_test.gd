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