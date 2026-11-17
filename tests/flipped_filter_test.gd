# Godot EventSheets - a For Each filter placed now that is one comparison writes the comparison it means.
#
# `if not (star.position.y > 560.0): continue` says the opposite of what a reader wants to know. A filter
# placed now (`filter_flipped`) that is one plain comparison writes `if star.position.y <= 560.0:`, and a
# single filter condition is no longer bracketed twice (`not ((a > b))`). A filter saved before keeps its
# `not (...)`, anything that is not one plain comparison keeps it too, and every spelling opens and saves
# back byte for byte. The flip is the rule the condition rows already follow for an inverted comparison.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "flipped_filter_test"


static func run() -> bool:
	var ok: bool = true
	ok = SUPPORT.check(P, "the pick filter can say: write the comparison it means", "filter_flipped" in PickFilter.new(), true) and ok
	if not ("filter_flipped" in PickFilter.new()):
		return false
	ok = SUPPORT.check(P, "a pick filter for a new row asks for it", PickFilter.for_new_row().filter_flipped, true) and ok
	ok = SUPPORT.check(P, "a pick filter made any other way does not", PickFilter.new().filter_flipped, false) and ok
	var sheet: EventSheetResource = EventSheets.new_sheet()
	var event_row: EventRow = EventRow.new()
	event_row.trigger_provider_id = "Core"
	event_row.trigger_id = "OnProcess"
	var pick: PickFilter = PickFilter.new()
	pick.iterator_name = "enemy"
	pick.collection_kind = PickFilter.CollectionKind.GROUP
	pick.collection_value = "enemies"
	pick.predicate_expression = "enemy.health <= 0"
	event_row.pick_filters.append(pick)
	sheet.events.append(event_row)
	ok = SUPPORT.check(P, "a filter saved before keeps its not", _text(sheet).contains("\t\tif not (enemy.health <= 0):\n\t\t\tcontinue\n"), true) and ok
	pick.filter_flipped = true
	ok = SUPPORT.check(P, "a new filter writes the comparison it means", _text(sheet).contains("\t\tif enemy.health > 0:\n\t\t\tcontinue\n"), true) and ok
	for pair: Array in [["a >= b", "a < b"], ["a < b", "a >= b"], ["a == 3", "a != 3"], ["a != null", "a == null"], ["x.y > -1.5", "x.y <= -1.5"]]:
		pick.predicate_expression = str(pair[0])
		ok = SUPPORT.check(P, "%s is written as %s" % [pair[0], pair[1]], _text(sheet).contains("\t\tif %s:\n\t\t\tcontinue\n" % pair[1]), true) and ok
	for text: String in ["enemy.health <= 0 and enemy.visible", "enemy.is_dead()", "a < b < c", "not enemy.alive", "enemy.has(\"x y\") == true"]:
		pick.predicate_expression = text
		ok = SUPPORT.check(P, "%s keeps its not (...)" % text, _text(sheet).contains("\t\tif not (%s):\n\t\t\tcontinue\n" % text), true) and ok
	# Filter conditions: one comparison condition is no longer bracketed twice.
	pick.predicate_expression = ""
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "CompareVar"
	condition.codegen_template = "{var_name} {op} {value}"
	condition.params = {"var_name": "enemy.shield", "op": ">", "value": "3"}
	pick.filter_conditions.append(condition)
	var guard_text: String = _text(sheet)
	ok = SUPPORT.check(P, "one filter condition is not bracketed twice", guard_text.contains("\t\tif enemy.shield <= 3:\n\t\t\tcontinue\n") or guard_text.contains("\t\tif not (enemy.shield > 3):\n\t\t\tcontinue\n"), true) and ok
	ok = SUPPORT.check(P, "no doubled brackets in a new filter", guard_text.contains("not (("), false) and ok
	pick.filter_flipped = false
	ok = SUPPORT.check(P, "a filter saved before keeps the doubled brackets it wrote", _text(sheet).contains("if not ((enemy.shield > 3)):"), true) and ok
	# The files that ship each old shape still open and save byte for byte, and so does the new one.
	for path: String in ["res://demo/showcase/starfall/starfall.gd", "res://demo/showcase/top_down_shooter/top_down_shooter.gd"]:
		ok = SUPPORT.check(P, "%s opens and saves back byte for byte" % path.get_file(), EventSheets.round_trips(FileAccess.get_file_as_string(path)), true) and ok
	var new_form: String = "extends Node2D\n\nfunc _process(_delta: float) -> void:\n\tfor star in get_tree().get_nodes_in_group(\"stars\"):\n\t\tif star.position.y <= 560.0:\n\t\t\tcontinue\n\t\tstar.queue_free()\n"
	ok = SUPPORT.check(P, "a file in the new spelling saves back byte for byte", EventSheets.round_trips(new_form), true) and ok
	return ok


static func _text(sheet: EventSheetResource) -> String:
	return str(EventSheets.echo(sheet).get("output", ""))
