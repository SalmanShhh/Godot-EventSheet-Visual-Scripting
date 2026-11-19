# Godot EventSheets - a long list of cards is drawn the first screenful at once and the rest a few at a time.
#
# Choosing a node that holds 200 juice cards drew all 200 inside the one frame the click lands in (about 400 ms). The
# Inspector's list now asks for the cards in turn: the first fourteen at once, then each frame as many as fit in a few
# milliseconds, with empty room at the foot of the list in place of the cards that have not come yet so the scroll bar
# holds still. Anything that works on the cards one by one finishes the drawing first, so it never meets a part drawn list,
# and what the list shows when the last card is drawn is exactly what drawing it all at once shows.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const BOUNDED := preload("res://tests/card_edit_bounded_test.gd")
const P := "card_progressive_draw_test"


static func _gradual() -> EventSheetCardListDrawer:
	var drawer: EventSheetCardListDrawer = BOUNDED._juice()
	drawer.progressive = true
	return drawer


## Hands the drawing its frames until it is done (a bounded number, so a drawing that never finishes fails and does not hang).
static func _finish(drawer: EventSheetCardListDrawer) -> int:
	var frames: int = 0
	while int(drawer.get("_undrawn_from")) >= 0 and frames < 2000:
		drawer._process(0.016)
		frames += 1
	return frames


static func _tail_of(drawer: EventSheetCardListDrawer) -> Control:
	var list: Control = drawer.get("_list")
	var last: Node = list.get_child(list.get_child_count() - 1)
	return last as Control


static func run() -> bool:
	var table: Array = []
	var whole: EventSheetCardListDrawer = BOUNDED._juice()
	whole.set_value(BOUNDED._moments(200))
	var drawer: EventSheetCardListDrawer = _gradual()
	drawer.set_value(BOUNDED._moments(200))
	table.append(["a list of 200 draws only its first screenful at once", int(drawer.get("cards_built")) <= EventSheetCardListDrawer.FIRST_DRAWN + 10, true])
	table.append(["and says where the drawing stands", int(drawer.get("_undrawn_from")) >= EventSheetCardListDrawer.FIRST_DRAWN, true])
	var tail: Control = _tail_of(drawer)
	table.append(["the room for the cards to come stands at the foot of the list", tail.custom_minimum_size.y > 0.0, true])
	var held: float = tail.custom_minimum_size.y
	var frames: int = _finish(drawer)
	table.append(["the cards arrive over several frames, not in one", frames > 1, true])
	table.append(["all 200 are drawn in the end", int(drawer.get("cards_built")), 200])
	table.append(["the drawing is over", int(drawer.get("_undrawn_from")), -1])
	table.append(["the room is given back", (drawer.get("_list") as Control).get_children().any(func(node: Node) -> bool: return node == tail), false])
	table.append(["the finished list reads as drawn all at once", BOUNDED._signature(drawer), BOUNDED._signature(whole)])
	table.append(["a short list is drawn whole at once", _short_is_whole(), true])
	table.append(["a list of 200 held room for the cards still to come", held > 0.0, true])

	# Whatever works on the cards one by one finishes the drawing first.
	drawer.set_value(BOUNDED._moments(200))
	drawer.select_card(10)
	drawer.remove_selected()
	table.append(["a card taken out while the list is part drawn finds every card drawn", int(drawer.get("_undrawn_from")), -1])
	table.append(["and the list reads as drawn all at once", BOUNDED._signature(drawer), BOUNDED._fresh_signature(drawer, BOUNDED._juice)])
	drawer.set_value(BOUNDED._moments(200))
	drawer.add_card("shake")
	table.append(["a card added while it is part drawn reads as drawn all at once", BOUNDED._signature(drawer), BOUNDED._fresh_signature(drawer, BOUNDED._juice)])
	drawer.set_value(BOUNDED._moments(200))
	drawer.move_cards_to_slot([5], 150)
	table.append(["a card moved while it is part drawn reads as drawn all at once", BOUNDED._signature(drawer), BOUNDED._fresh_signature(drawer, BOUNDED._juice)])
	drawer.set_value(BOUNDED._moments(200))
	drawer.reveal_card(150)
	table.append(["scrolling to a card that is not drawn yet draws the rest", int(drawer.get("_undrawn_from")), -1])
	table.append(["and the card is there", (drawer.get("_lines") as Dictionary).has(150), true])

	# A new list while one is part drawn starts over, and leaves nothing behind.
	drawer.set_value(BOUNDED._moments(200))
	drawer.set_value(BOUNDED._moments(90))
	_finish(drawer)
	table.append(["a list set while another is part drawn draws only the new one", (drawer.get("_lines") as Dictionary).size(), 90])
	table.append(["and reads as drawn all at once", BOUNDED._signature(drawer), BOUNDED._fresh_signature(drawer, BOUNDED._juice)])
	# The cards still to come are known by the data, so a value written before they are drawn is there when they are.
	var written: EventSheetCardListDrawer = _gradual()
	written.set_value(BOUNDED._moments(200))
	written.write_card_key(150, "seconds", 0.77)
	_finish(written)
	table.append(["a value written into a card not drawn yet shows when it is", written.head_summary_of(150).contains("0.77"), true])
	written.free()
	# A list drawn whole by a test or a dialog (the default) never waits.
	var plain: EventSheetCardListDrawer = BOUNDED._juice()
	plain.set_value(BOUNDED._moments(200))
	table.append(["a list that was not asked to draw gradually draws every card at once", int(plain.get("_undrawn_from")), -1])
	var ok: bool = SUPPORT.pins(P, table)
	whole.free()
	drawer.free()
	plain.free()
	return ok


static func _short_is_whole() -> bool:
	var short: EventSheetCardListDrawer = _gradual()
	short.set_value(BOUNDED._moments(30))
	var drawn: bool = int(short.get("_undrawn_from")) == -1 and (short.get("_lines") as Dictionary).size() == 30
	short.free()
	return drawn
