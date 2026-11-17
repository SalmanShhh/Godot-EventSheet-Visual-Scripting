# Godot EventSheets - taking a card out of a long list, putting one in, and undoing either, cost a fraction of a full redraw.
#
# At 500 shapes a delete from the middle drew all the cards that were left and took most of a second on the main
# thread. A card that stays now keeps its controls, so the work follows the one card that changed. This holds the
# time of each edit, at 200 and 500 shapes and on a 200-card Juice list, to a fraction of what drawing the whole
# list costs in the same process (the ratio is what stays true on a slow or busy machine), and to the number of
# cards drawn, which does not depend on the machine at all.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const STEPS_PROPERTY_PATH := "res://addons/eventsheet/editor/inspector/drawing_prefab_steps_property.gd"
const SCHEMA_PATH := "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const P := "card_edit_perf_test"
## This test MEASURES, so it has to have the machine to itself: the sharded runner keeps it out of every parallel shard.
const PARALLEL_UNSAFE := true
## What one edit may cost, as a fraction of drawing the whole list.
const FRACTION: float = 0.25
const ROUNDS: int = 5


static func _shapes(count: int) -> Array:
	var kinds: Array = ["circle", "ring", "rect", "line", "cone", "arc", "pie"]
	var steps: Array = []
	for index: int in count:
		steps.append({"kind": kinds[index % kinds.size()], "x": float(index), "y": 0.0, "p1": 5.0 + float(index % 9), "p2": 3.0, "p3": 2.0, "color": "#ff8800"})
	return steps


static func _moments(count: int) -> Array:
	var verbs: Array = ["shake", "hitstop", "chromatic", "pulse"]
	var steps: Array = []
	for index: int in count:
		if index % 10 == 9:
			steps.append({"verb": "pause", "seconds": 0.1})
		else:
			steps.append({"verb": verbs[index % verbs.size()], "amount": 0.5, "seconds": 0.1 + float(index % 5) * 0.05})
	return steps


static func _median(values: Array) -> float:
	var sorted: Array = values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])


static func _prefab() -> EventSheetCardListDrawer:
	var editor_class: GDScript = (load(STEPS_PROPERTY_PATH) as GDScript).get_script_constant_map().get("ShapeStepsEditor") as GDScript
	return editor_class.new() as EventSheetCardListDrawer


static func _juice() -> EventSheetCardListDrawer:
	var schema: Dictionary = (load(SCHEMA_PATH) as GDScript).call("schema")
	return EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": schema})


## Times delete, undo (the list handed back as it was), redo, duplicate and paste in the middle of `drawer`, and returns
## each median in milliseconds with the whole-list redraw, and how many cards the edits drew in all.
static func _measure(drawer: EventSheetCardListDrawer, cards: Array, middle: int) -> Dictionary:
	drawer.set_value(cards)
	var whole: Array = []
	for round: int in ROUNDS:
		var started: int = Time.get_ticks_usec()
		drawer.call("_rebuild")
		whole.append(float(Time.get_ticks_usec() - started) / 1000.0)
	var after_delete: Array = cards.duplicate()
	after_delete.remove_at(middle)
	var text: String = EventSheetCardSchemas.cards_to_text([cards[3]])
	var times: Dictionary = {"delete": [], "undo": [], "redo": [], "duplicate": [], "paste": []}
	var built_before: int = int(drawer.get("cards_built"))
	for round: int in ROUNDS:
		drawer.select_card(middle)
		var begun: int = Time.get_ticks_usec()
		drawer.remove_selected()
		(times["delete"] as Array).append(float(Time.get_ticks_usec() - begun) / 1000.0)
		begun = Time.get_ticks_usec()
		drawer.set_value(cards)
		(times["undo"] as Array).append(float(Time.get_ticks_usec() - begun) / 1000.0)
		begun = Time.get_ticks_usec()
		drawer.set_value(after_delete)
		(times["redo"] as Array).append(float(Time.get_ticks_usec() - begun) / 1000.0)
		drawer.set_value(cards)
		drawer.select_card(middle)
		begun = Time.get_ticks_usec()
		drawer.duplicate_selected()
		(times["duplicate"] as Array).append(float(Time.get_ticks_usec() - begun) / 1000.0)
		drawer.set_value(cards)
		drawer.select_card(middle)
		begun = Time.get_ticks_usec()
		drawer.paste_after_selection(text)
		(times["paste"] as Array).append(float(Time.get_ticks_usec() - begun) / 1000.0)
		drawer.set_value(cards)
	return {"whole": _median(whole), "times": times, "built": int(drawer.get("cards_built")) - built_before}


static func run() -> bool:
	var table: Array = []
	var lists: Array = [
		["200 shapes", _prefab(), _shapes(200), 100],
		["500 shapes", _prefab(), _shapes(500), 250],
		["a Juice list of 200", _juice(), _moments(200), 101],
	]
	for entry: Variant in lists:
		var label: String = str((entry as Array)[0])
		var drawer: EventSheetCardListDrawer = (entry as Array)[1]
		var measured: Dictionary = _measure(drawer, (entry as Array)[2], int((entry as Array)[3]))
		var whole: float = float(measured["whole"])
		var summary: String = ""
		for edit: Variant in (measured["times"] as Dictionary):
			var median: float = _median((measured["times"] as Dictionary)[edit])
			summary += " %s %.1f ms," % [str(edit), median]
			table.append(["%s: a %s in the middle costs under a quarter of drawing the whole list (%.1f of %.1f ms)" % [label, str(edit), median, whole], median < whole * FRACTION, true])
		print("  [perf] %s: whole redraw %.1f ms,%s" % [label, whole, summary])
		# The cards drawn: a delete draws none, an undo of it one, a redo none, a duplicate one and a paste one, per round
		# (each round's set_value back to the full list draws the one card the undo needs).
		table.append(["%s: the edits drew a handful of cards (%d), not the list" % [label, int(measured["built"])], int(measured["built"]) <= ROUNDS * 12, true])
		drawer.free()
	return SUPPORT.pins(P, table)
