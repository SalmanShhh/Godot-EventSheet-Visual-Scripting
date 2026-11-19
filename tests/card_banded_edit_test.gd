# Godot EventSheets - a Juice list with bands is edited without drawing it again.
#
# A Juice list groups the cards between two Pauses or Holds on a band, so every real list has bands. Adding a card at its
# end, taking a Pause out (two bands become one), moving a card, opening or shutting one and switching one off used to draw
# every card of the list again (200 cards: 350 ms each). A card that stays now keeps its controls and is carried to the band
# and the place it has, and only the cards that are new, or that were asked for, are drawn. What the list shows afterwards
# is exactly what drawing it afresh shows, which is what each row below holds it to, and a run of random edits is held to
# the same.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const BOUNDED := preload("res://tests/card_edit_bounded_test.gd")
const P := "card_banded_edit_test"


static func _fresh_signature(drawer: EventSheetCardListDrawer) -> Array:
	return BOUNDED._fresh_signature(drawer, BOUNDED._juice)


static func _built(drawer: EventSheetCardListDrawer) -> int:
	return int(drawer.get("cards_built"))


static func run() -> bool:
	var ok: bool = true
	ok = _add_pins() and ok
	ok = _remove_pins() and ok
	ok = _move_pins() and ok
	ok = _fold_pins() and ok
	ok = _random_edits() and ok
	return ok


static func _add_pins() -> bool:
	var table: Array = []
	var drawer: EventSheetCardListDrawer = BOUNDED._juice()
	drawer.set_value(BOUNDED._moments(120))
	var rows: Dictionary = BOUNDED._rows_of(drawer)
	var before: int = _built(drawer)
	# The list ends on a Pause (card 119), so the new card stands on its own.
	drawer.add_card("shake")
	table.append(["a card added after a Pause draws one card", _built(drawer) - before, 1])
	table.append(["the cards before it kept their controls", BOUNDED._rows_of(drawer)[60], rows[60]])
	table.append(["a card added after a Pause reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	# A list that ends inside a band: the new card joins it.
	drawer.set_value(BOUNDED._moments(118))
	before = _built(drawer)
	drawer.add_card("pulse")
	table.append(["a card added inside the last band draws one card", _built(drawer) - before, 1])
	table.append(["and reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	# The undo and the redo of it.
	var with_card: Array = drawer.get_value()
	var without_card: Array = with_card.slice(0, with_card.size() - 1)
	before = _built(drawer)
	drawer.set_value(without_card)
	table.append(["its undo draws no card", _built(drawer) - before, 0])
	table.append(["and reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	before = _built(drawer)
	drawer.set_value(with_card)
	table.append(["its redo draws one card", _built(drawer) - before, 1])
	table.append(["and reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	# A Pause added at the end of a band splits nothing but ends the band.
	drawer.add_card("pause")
	table.append(["a Pause added after a band reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	var ok: bool = SUPPORT.pins(P, table)
	drawer.free()
	return ok


static func _remove_pins() -> bool:
	var table: Array = []
	var drawer: EventSheetCardListDrawer = BOUNDED._juice()
	drawer.set_value(BOUNDED._moments(120))
	var rows: Dictionary = BOUNDED._rows_of(drawer)
	var cards: Array = drawer.get_value()
	# A Pause (card 9) taken out joins the band before it and the band after it, and draws no card at all.
	drawer.select_card(9)
	var before: int = _built(drawer)
	drawer.remove_selected()
	table.append(["a Pause taken out draws no card", _built(drawer) - before, 0])
	table.append(["the cards after it kept their controls", BOUNDED._rows_of(drawer)[60], rows[61]])
	table.append(["a Pause taken out reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	before = _built(drawer)
	drawer.set_value(cards)
	table.append(["its undo draws one card", _built(drawer) - before, 1])
	table.append(["and reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	# Two Pauses and the cards between them taken out at once.
	drawer.select_card(9)
	drawer.select_card(19, "shift")
	drawer.remove_selected()
	table.append(["ten cards taken out across a band reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	# A Hold taken out: the Holds after it write their wait again.
	drawer.set_value(cards)
	drawer.select_card(4)
	drawer.remove_selected()
	table.append(["a Hold taken out reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	# One card of a band of three left standing alone.
	drawer.set_value(BOUNDED._moments(30))
	drawer.select_card(10, "click")
	drawer.select_card(11, "shift")
	drawer.remove_selected()
	table.append(["a band cut down to one card reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	# An open card in the same band, in front of the card taken out, is drawn once, not twice.
	drawer.set_value(BOUNDED._moments(60))
	drawer.set_unfolded(36, true)
	drawer.set_unfolded(39, true)
	drawer.select_card(38)
	drawer.remove_selected()
	table.append(["a card taken out beside open cards of its band reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	table.append(["and one row stands for each card", (drawer.get("_lines") as Dictionary).size(), drawer.get_value().size()])
	var ok: bool = SUPPORT.pins(P, table)
	drawer.free()
	return ok


static func _move_pins() -> bool:
	var table: Array = []
	var drawer: EventSheetCardListDrawer = BOUNDED._juice()
	drawer.set_value(BOUNDED._moments(120))
	var rows: Dictionary = BOUNDED._rows_of(drawer)
	var original: Array = drawer.get_value()
	# One card dragged three places down inside a band.
	var before: int = _built(drawer)
	drawer.move_cards_to_slot([32], 36)
	table.append(["a card moved inside a band draws no card", _built(drawer) - before, 0])
	table.append(["a card that did not move kept its controls", BOUNDED._rows_of(drawer)[50], rows[50]])
	table.append(["the card that moved kept its own controls", BOUNDED._rows_of(drawer)[35], rows[32]])
	table.append(["a card moved inside a band reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	# Undone, redone.
	before = _built(drawer)
	drawer.set_value(original)
	table.append(["its undo reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	table.append(["and draws at most the few cards that changed place", _built(drawer) - before <= 5, true])
	# A card dragged out of its band into another one, past a Pause.
	drawer.set_value(original)
	drawer.move_cards_to_slot([12], 25)
	table.append(["a card moved to another band reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	# A card dragged next to a Pause so that it stands on its own.
	drawer.set_value(original)
	drawer.move_cards_to_slot([5], 10)
	table.append(["a card moved to the far side of a Pause reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	# A Pause dragged to the middle of a band splits it.
	drawer.set_value(original)
	drawer.move_cards_to_slot([9], 15)
	table.append(["a Pause moved into a band reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	# Several cards to the top, to the bottom, and one place up by the keys.
	drawer.set_value(original)
	drawer.select_card(30)
	drawer.select_card(70, "ctrl")
	drawer.select_card(101, "ctrl")
	drawer.move_selected_to(false)
	table.append(["three cards moved to the top read as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	drawer.move_selected_to(true)
	table.append(["and to the bottom", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	drawer.move_selected(-1)
	table.append(["and one place up", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	table.append(["the cards are the same cards in another order", drawer.get_value().size(), original.size()])
	# A card that was open travels open, and is drawn again for its new number.
	drawer.set_value(original)
	drawer.set_unfolded(32, true)
	drawer.select_card(32)
	drawer.move_cards_to_slot([32], 40)
	table.append(["an open card moved reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	table.append(["and is still open where it landed", drawer.is_unfolded(39), true])
	var ok: bool = SUPPORT.pins(P, table)
	drawer.free()
	return ok


static func _fold_pins() -> bool:
	var table: Array = []
	var drawer: EventSheetCardListDrawer = BOUNDED._juice()
	drawer.set_value(BOUNDED._moments(120))
	var rows: Dictionary = BOUNDED._rows_of(drawer)
	var before: int = _built(drawer)
	var open_button: Button = BOUNDED._button_with_tooltip(drawer, 50, "Open this card.")
	open_button.pressed.emit()
	table.append(["opening one card draws that one card", _built(drawer) - before, 1])
	table.append(["the card is open", drawer.is_unfolded(50), true])
	table.append(["the cards beside it kept their controls", BOUNDED._rows_of(drawer)[51], rows[51]])
	table.append(["a list with one card opened reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	# A second one opened: only the one that is asked for and the one already open are drawn.
	before = _built(drawer)
	var second: Button = BOUNDED._button_with_tooltip(drawer, 80, "Open this card.")
	second.pressed.emit()
	table.append(["opening a second card draws that card and the open one", _built(drawer) - before <= 2, true])
	var shut: Button = BOUNDED._button_with_tooltip(drawer, 50, "Open this card.")
	before = _built(drawer)
	shut.pressed.emit()
	table.append(["shutting a card draws it again, shut", _built(drawer) - before <= 2, true])
	table.append(["the card is shut", drawer.is_unfolded(50), false])
	table.append(["and the list reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	# Switched off and on: the one card is drawn again, in the band it stands in.
	before = _built(drawer)
	drawer.set_card_enabled(33, false)
	table.append(["a card switched off draws one card", _built(drawer) - before <= 2, true])
	table.append(["and reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	drawer.set_card_enabled(33, true)
	table.append(["switched on again it reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	# A card replaced by pasting over it.
	var text: String = EventSheetCardSchemas.cards_to_text([{"verb": "shake", "amount": 0.9, "seconds": 0.2}])
	before = _built(drawer)
	drawer.paste_over(42, text)
	table.append(["a card pasted over draws one card", _built(drawer) - before <= 2, true])
	table.append(["and reads as drawn afresh", BOUNDED._signature(drawer), _fresh_signature(drawer)])
	# One card asked to be drawn again from outside (a node picked in it).
	before = _built(drawer)
	drawer._redraw_card(60)
	table.append(["one card drawn again draws one card", _built(drawer) - before, 1])
	var ok: bool = SUPPORT.pins(P, table)
	drawer.free()
	return ok


## A seeded run of edits of every kind on a list with bands and a few open cards: after each, the list reads as drawn
## afresh from the same cards, the same open cards and the same selection.
static func _random_edits() -> bool:
	var table: Array = []
	var drawer: EventSheetCardListDrawer = BOUNDED._juice()
	drawer.set_value(BOUNDED._moments(60))
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 20261119
	var history: Array = [drawer.get_value()]
	var mismatches: Array = []
	var names: Array = []
	for step: int in 160:
		var count: int = drawer.get_value().size()
		var pick: int = random.randi_range(0, maxi(count - 1, 0))
		var kind: int = random.randi_range(0, 8)
		var name: String = ""
		match kind:
			0:
				drawer.select_card(pick)
				drawer.remove_selected()
				name = "remove %d" % pick
			1:
				drawer.select_card(pick)
				drawer.duplicate_selected()
				name = "duplicate %d" % pick
			2:
				var slot: int = random.randi_range(0, count)
				drawer.move_cards_to_slot([pick], slot)
				name = "move %d to %d" % [pick, slot]
			3:
				drawer.set_unfolded(pick, not drawer.is_unfolded(pick))
				name = "fold %d" % pick
			4:
				drawer.add_card(["shake", "pause", "pulse", "hold_until"][random.randi_range(0, 3)])
				name = "add"
			5:
				drawer.select_card(pick)
				drawer.select_card(mini(pick + random.randi_range(0, 4), count - 1), "shift")
				drawer.remove_selected()
				name = "remove a run at %d" % pick
			6:
				drawer.select_card(pick)
				drawer.move_selected(random.randi_range(0, 1) * 2 - 1)
				name = "step %d" % pick
			7:
				drawer.set_card_enabled(pick, random.randi_range(0, 1) == 0)
				name = "enable %d" % pick
			8:
				var back: Array = history[random.randi_range(0, history.size() - 1)]
				drawer.set_value(back)
				name = "set an earlier list"
		names.append(name)
		if drawer.get_value().is_empty():
			drawer.set_value(BOUNDED._moments(60))
		history.append(drawer.get_value())
		if history.size() > 12:
			history.remove_at(0)
		if BOUNDED._signature(drawer) != _fresh_signature(drawer):
			mismatches.append("%d: %s" % [step, name])
	table.append(["160 random edits each leave the list as drawn afresh (first mismatch, if any)", mismatches.slice(0, 1), []])
	var ok: bool = SUPPORT.pins(P, table)
	drawer.free()
	return ok
