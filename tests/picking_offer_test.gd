@tool
class_name PickingOfferTest
extends RefCounted

# EventForge - picking, offered in Godot's shape.
#
# Typed on another object's sheet, "Enemy health <= 0" means "every Enemy that passes" in another
# event-sheet editor. When Enemy is a family, the Ghost Row offers that as a For each over the
# family with the test as its filter. These pins hold:
#   1. the offer a sentence makes, by value, and the sentences that make none;
#   2. the line the Ghost Row shows for it;
#   3. the loop it compiles to - the one a person writes by hand;
#   4. the project's own families are found from their `@ace_family` marker;
#   5. a family loop in a real file reads "For each Enemy" with Enemy as its object.

const SUPPORT := preload("res://tests/support.gd")
const KNOWN: Dictionary = {"Enemy": "family_enemy", "BigBat": "family_big_bat"}


static func run() -> bool:
	var ok: bool = _offers()
	ok = _the_loop_it_writes() and ok
	ok = _the_project_and_the_reading() and ok
	return ok


static func _offers() -> bool:
	var offer: Dictionary = EventSheetPickingOffer.offer_for("Enemy health <= 0", KNOWN, "Player")
	return SUPPORT.pins("picking_offer_test", [
		["a test on a family is offered as its loop", [offer.get("group"), offer.get("iterator"), offer.get("test")],
			["family_enemy", "enemy", "enemy.health <= 0"]],
		["the other editor's glyphs and lower case read the same",
			EventSheetPickingOffer.offer_for("enemy hp ≤ 0", KNOWN, "Player").get("test", ""), "enemy.hp <= 0"],
		["a single = is a comparison", EventSheetPickingOffer.offer_for("Enemy state = 2", KNOWN, "").get("test", ""),
			"enemy.state == 2"],
		["a family's name alone offers the loop with no test",
			[EventSheetPickingOffer.offer_for("BigBat", KNOWN, "").get("iterator"),
				EventSheetPickingOffer.offer_for("BigBat", KNOWN, "").get("test")], ["big_bat", ""]],
		["the sheet's own class is never offered", EventSheetPickingOffer.offer_for("Enemy hp < 1", KNOWN, "Enemy"), {}],
		["an object that is not a family is never offered", EventSheetPickingOffer.offer_for("Player hp < 1", KNOWN, ""), {}],
		["words that are not a comparison are not guessed at",
			EventSheetPickingOffer.offer_for("Enemy takes damage now", KNOWN, ""), {}],
		["the Ghost Row line", EventSheetPickingOffer.label_for(offer), "⟳  For each Enemy where health ≤ 0"],
	])


static func _the_loop_it_writes() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event_row: EventRow = EventSheetPickingOffer.event_for(
		EventSheetPickingOffer.offer_for("Enemy health <= 0", KNOWN, ""), "pick_test")
	var destroy: RawCodeRow = RawCodeRow.new()
	destroy.code = "enemy.queue_free()"
	event_row.actions.append(destroy)
	sheet.events.append(event_row)
	var output: String = SUPPORT.compile_output(sheet)
	return SUPPORT.pins("picking_offer_test", [
		["it walks the family's group", output.contains("for enemy in get_tree().get_nodes_in_group(\"family_enemy\"):"), true],
		["the test filters each one", output.contains("\t\tif not (enemy.health <= 0):\n\t\t\tcontinue"), true],
		["and the actions act on the one picked", output.contains("\t\tenemy.queue_free()"), true],
	])


static func _the_project_and_the_reading() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external("res://demo/showcase/family_arena/family_arena.gd")
	sheet.read_only = true
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var loop_text: String = ""
	var loop_object: String = ""
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		view._row_builder._ensure_event_spans(row_data)
		for span: SemanticSpan in row_data.spans:
			if span.metadata is Dictionary and str((span.metadata as Dictionary).get("kind", "")) == "pick_filter" \
					and span.text.contains("Enemy") and loop_text.is_empty():
				loop_text = span.text
				loop_object = str((span.metadata as Dictionary).get("object_label", ""))
	view.free()
	return SUPPORT.pins("picking_offer_test", [
		["the showcase's family is found from its marker", EventSheetPickingOffer.families().get("Enemy", ""), "family_enemy"],
		["a hand-written family loop reads as the family's For each", loop_text, "For each Enemy"],
		["with the family as its object", loop_object, "Enemy"],
	])
