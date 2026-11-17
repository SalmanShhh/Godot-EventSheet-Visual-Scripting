# Godot EventSheets - moving a card touches only the cards that moved.
#
# A held Alt+Down walks a card down the list one place at a time. Redrawing every card of a list of 200 for each step
# made the walk crawl, so a move now builds again only the cards whose place changed (the two that swapped, or the
# moved ones and their neighbours), adding a card builds one, and a change to a field builds none. What the list
# shows afterwards, what is saved and the undo step are exactly what a full redraw gave.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const STEPS_PROPERTY_PATH := "res://addons/eventsheet/editor/inspector/drawing_prefab_steps_property.gd"
const P := "card_reorder_bounded_test"


static func _editor() -> EventSheetCardListDrawer:
	var editor_class: GDScript = (load(STEPS_PROPERTY_PATH) as GDScript).get_script_constant_map().get("ShapeStepsEditor") as GDScript
	return editor_class.new() as EventSheetCardListDrawer


static func _steps(count: int) -> Array:
	var kinds: Array = ["circle", "ring", "rect", "line", "cone", "arc", "pie"]
	var steps: Array = []
	for index: int in count:
		steps.append({"kind": kinds[index % kinds.size()], "x": float(index), "y": 0.0, "p1": 5.0 + float(index), "p2": 3.0, "p3": 2.0, "color": "#ff8800"})
	return steps


## The summary line each card shows, in list order, read off the controls the list holds right now.
static func _shown(drawer: EventSheetCardListDrawer) -> Array:
	var titles: Dictionary = drawer.get("_titles")
	var shown: Array = []
	for index: int in (drawer.get_value() as Array).size():
		var label: Label = titles.get(index) as Label
		shown.append(label.text if label != null and is_instance_valid(label) else "<none>")
	return shown


## The order of the card controls in the list, as the card index each one was built for.
static func _row_indices(drawer: EventSheetCardListDrawer) -> Array:
	var found: Array = []
	var list: Control = drawer.get("_list")
	for child: Node in list.get_children():
		if child.is_queued_for_deletion():
			continue
		if child.has_method("card_index"):
			found.append(child.call("card_index"))
	return found


static func run() -> bool:
	var ok: bool = true
	var big: EventSheetCardListDrawer = _editor()
	big.set_value(_steps(120))
	var table: Array = []
	var built_at_start: int = int(big.get("cards_built"))
	table.append(["a list of 120 builds each card once to start", built_at_start >= 120, true])

	big.select_card(50)
	var before: int = int(big.get("cards_built"))
	big.move_selected(1)
	var one_step: int = int(big.get("cards_built")) - before
	table.append(["moving one card one place builds at most two cards", one_step <= 2, true])
	table.append(["and the card is where it was moved to", (big.get_value() as Array)[51]["x"], 50.0])
	table.append(["its neighbour took its old place", (big.get_value() as Array)[50]["x"], 51.0])
	table.append(["the selection followed the card", big.selected_cards(), [51]])

	before = int(big.get("cards_built"))
	big.move_selected(1)
	big.move_selected(1)
	big.move_selected(-1)
	var three_steps: int = int(big.get("cards_built")) - before
	table.append(["three more steps build at most six", three_steps <= 6, true])

	big.select_card(10, "click")
	big.select_card(20, "ctrl")
	before = int(big.get("cards_built"))
	big.move_selected(1)
	table.append(["two selected cards moving one place build at most four", int(big.get("cards_built")) - before <= 4, true])

	before = int(big.get("cards_built"))
	big.write_card_key(5, "p1", 33.0)
	table.append(["a field edit builds no card", int(big.get("cards_built")) - before, 0])

	before = int(big.get("cards_built"))
	big.add_card("circle")
	table.append(["adding a card builds one", int(big.get("cards_built")) - before, 1])
	table.append(["and the list holds it", (big.get_value() as Array).size(), 121])

	# Whatever the partial redraw did, the list must read as a list drawn afresh from the same cards.
	var fresh: EventSheetCardListDrawer = _editor()
	fresh.set_value(big.get_value())
	table.append(["after the moves the list shows what a fresh drawing of the same cards shows", _shown(big), _shown(fresh)])
	table.append(["and its card controls sit in list order", _row_indices(big), _row_indices(fresh)])

	# A move that crosses nothing the list keeps in a group, at the edges, with a selection at both ends.
	var small: EventSheetCardListDrawer = _editor()
	small.set_value(_steps(4))
	small.select_card(0)
	var edge_before: int = int(small.get("cards_built"))
	var moved_past_top: bool = small.move_selected(-1)
	table.append(["a move that goes nowhere builds nothing", [moved_past_top, int(small.get("cards_built")) - edge_before], [false, 0]])
	small.select_card(3)
	table.append(["the last card does not move down", small.move_selected(1), false])
	small.select_card(0)
	table.append(["a move to the bottom is a different shape of move and still ends in order", [small.move_selected_to(true), (small.get_value() as Array)[3]["x"]], [true, 0.0]])
	var small_fresh: EventSheetCardListDrawer = _editor()
	small_fresh.set_value(small.get_value())
	table.append(["and the list after it reads as drawn afresh", _shown(small), _shown(small_fresh)])
	ok = SUPPORT.pins(P, table)
	for drawer: EventSheetCardListDrawer in [big, fresh, small, small_fresh]:
		drawer.free()
	return ok
