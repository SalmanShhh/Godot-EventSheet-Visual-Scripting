# Godot EventSheets - the loops a stack or queue makes: For each popped from the front / back, and
# Push back keeping the last N.
#
# For each popped is a loop CONDITION: its event runs once per item, and each item comes off the list as
# it is used - `while not L.is_empty():` with `var name = L.pop_front()` as the body's first line - so
# the loop and the take can never get out of step. The While-that-cannot-end mistake stays quiet for it
# because the take changes the list. Push back keeping the last N is one action: an append, then a trim
# from the front.
@tool
class_name StackQueueLoopsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const ROWS := preload("res://tests/stack_queue_rows_test.gd")
const NAME := "stack_queue_loops"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_drain_loop_compiles() and ok
	ok = _test_the_drain_loop_lifts() and ok
	ok = _test_the_endless_while_check_stays_quiet() and ok
	ok = _test_the_drain_rows() and ok
	return ok


## A sheet with one On Ready event that drains `jobs` into `job`, compiled.
static func drain_output(kind: int, type_text: String = "", index_name: String = "") -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {"jobs": {"type": "Array", "default": [], "exported": false}}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var pick: PickFilter = PickFilter.new()
	pick.collection_kind = kind
	pick.collection_value = "jobs"
	pick.iterator_name = "job"
	pick.iterator_type = type_text
	pick.index_name = index_name
	event.pick_filters.append(pick)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "CallFunction"
	action.codegen_template = "print({message})"
	action.params = {"message": "job"}
	event.actions.append(action)
	sheet.events.append(event)
	return SUPPORT.compile_output(sheet, "user://%s_drain.gd" % NAME)


static func _test_the_drain_loop_compiles() -> bool:
	var ok: bool = true
	var front: String = drain_output(PickFilter.CollectionKind.DRAIN_FRONT)
	ok = SUPPORT.check(NAME, "a front drain writes the while and the take",
		front.contains("\twhile not jobs.is_empty():\n\t\tvar job = jobs.pop_front()\n"), true) and ok
	var back: String = drain_output(PickFilter.CollectionKind.DRAIN_BACK)
	ok = SUPPORT.check(NAME, "a back drain takes from the back",
		back.contains("\twhile not jobs.is_empty():\n\t\tvar job = jobs.pop_back()\n"), true) and ok
	var typed: String = drain_output(PickFilter.CollectionKind.DRAIN_FRONT, "Callable")
	ok = SUPPORT.check(NAME, "a typed list gives the local its type",
		typed.contains("\t\tvar job: Callable = jobs.pop_front()\n"), true) and ok
	var indexed: String = drain_output(PickFilter.CollectionKind.DRAIN_FRONT, "", "n")
	ok = SUPPORT.check(NAME, "a loop index counts before the take",
		indexed.contains("\tvar n: int = -1\n\twhile not jobs.is_empty():\n\t\tn += 1\n\t\tvar job = jobs.pop_front()\n"), true) and ok
	var generated: GDScript = GDScript.new()
	generated.source_code = typed
	ok = SUPPORT.check(NAME, "the loop parses", generated.reload(true), OK) and ok
	return ok


static func _first_pick(sheet: EventSheetResource) -> PickFilter:
	for entry: Variant in sheet.events:
		if entry is EventRow and not (entry as EventRow).pick_filters.is_empty():
			return (entry as EventRow).pick_filters[0] as PickFilter
	return null


static func _test_the_drain_loop_lifts() -> bool:
	var ok: bool = true
	for case: Array in [
		["the front", "\twhile not jobs.is_empty():\n\t\tvar job = jobs.pop_front()\n\t\tprint(job)\n", PickFilter.CollectionKind.DRAIN_FRONT, ""],
		["the back", "\twhile not jobs.is_empty():\n\t\tvar job = jobs.pop_back()\n\t\tprint(job)\n", PickFilter.CollectionKind.DRAIN_BACK, ""],
		["a typed take", "\twhile not jobs.is_empty():\n\t\tvar job: Callable = jobs.pop_front()\n\t\tprint(job)\n", PickFilter.CollectionKind.DRAIN_FRONT, "Callable"],
	]:
		var opened: Dictionary = ROWS.reopened(str(case[1]))
		var pick: PickFilter = _first_pick(opened["sheet"])
		ok = SUPPORT.check(NAME, "a hand-written drain of %s opens as the loop condition" % case[0],
			[pick.collection_kind, pick.collection_value, pick.iterator_name, pick.iterator_type] if pick != null else [],
			[case[2], "jobs", "job", case[3]]) and ok
		ok = SUPPORT.check(NAME, "...and saves back byte for byte (%s)" % case[0], opened["again"], opened["source"]) and ok
	# The shapes that differ stay as the loops they are.
	for case: Array in [
		["a while that does not take", "\twhile not jobs.is_empty():\n\t\tvar job = jobs.back()\n\t\tprint(job)\n"],
		["a take from another list", "\twhile not jobs.is_empty():\n\t\tvar job = others.pop_front()\n\t\tprint(job)\n"],
		["a take that is not the first line", "\twhile not jobs.is_empty():\n\t\tprint(1)\n\t\tvar job = jobs.pop_front()\n"],
		["remove_at(0) for pop_front", "\twhile not jobs.is_empty():\n\t\tvar job = jobs[0]\n\t\tjobs.remove_at(0)\n"],
	]:
		var kept: Dictionary = ROWS.reopened(str(case[1]))
		var kept_pick: PickFilter = _first_pick(kept["sheet"])
		ok = SUPPORT.check(NAME, "%s stays a While" % case[0],
			kept_pick != null and kept_pick.collection_kind == PickFilter.CollectionKind.WHILE, true) and ok
		ok = SUPPORT.check(NAME, "...and saves back byte for byte (%s)" % case[0], kept["again"], kept["source"]) and ok
	return ok


static func _kinds(sheet: EventSheetResource) -> PackedStringArray:
	var kinds: PackedStringArray = PackedStringArray()
	for finding: Dictionary in EventSheetMistakeFindings.findings(sheet):
		kinds.append(str(finding.get("kind", "")))
	return kinds


static func _test_the_endless_while_check_stays_quiet() -> bool:
	var ok: bool = true
	var endless: Dictionary = ROWS.reopened("\twhile lives > 0:\n\t\tprint(lives)\n")
	ok = SUPPORT.check(NAME, "a While nothing inside can end is still caught",
		_kinds(endless["sheet"]).has(EventSheetMistakeFindings.KIND_ENDLESS_WHILE), true) and ok
	var drained: Dictionary = ROWS.reopened("\twhile not jobs.is_empty():\n\t\tvar job = jobs.pop_front()\n\t\tprint(job)\n")
	ok = SUPPORT.check(NAME, "the drain loop is quiet, because the take changes the list",
		_kinds(drained["sheet"]).has(EventSheetMistakeFindings.KIND_ENDLESS_WHILE), false) and ok
	return ok


static func _test_the_drain_rows() -> bool:
	var ok: bool = true
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([] as Array[Object], true)
	for pair: Array in [["ForEachPoppedFromFront", "front"], ["ForEachPoppedFromBack", "back"]]:
		var definition: ACEDefinition = registry.find_definition("Core", str(pair[0]))
		ok = SUPPORT.check(NAME, "%s is a looping condition" % pair[0],
			definition != null and definition.ace_type == ACEDefinition.ACEType.CONDITION and bool(definition.metadata.get("looping", false)), true) and ok
		ok = SUPPORT.check(NAME, "...that drains from the %s" % pair[1], str(definition.metadata.get("looping_drain", "")), pair[1]) and ok
		ok = SUPPORT.check(NAME, "...in the Array page", definition.category, "Variables: Array") and ok
	return ok
