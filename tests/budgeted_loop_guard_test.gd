# Godot EventSheets - a budgeted For Each placed now writes only the limit it has.
#
# The old spelling declared a deadline local even for a loop that has only a count, and wrote a guard that
# tests both limits whichever were set. A loop placed now (`tidy_budget`) writes the one test it needs.
# A loop saved before, or read from a file, keeps the long guard: the flag is off for it, and an opened
# budgeted loop is plain rows that save back the bytes they were read from.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "budgeted_loop_guard_test"
const OLD_COUNT_ONLY: String = "(90 > 0 and __done_abcdef12_0 >= 90) or (0.0 > 0.0 and"


static func run() -> bool:
	var ok: bool = true
	ok = SUPPORT.check(P, "the pick filter can say: write only the limit it has", "tidy_budget" in PickFilter.new(), true) and ok
	if not ("tidy_budget" in PickFilter.new()):
		return false
	var sheet: EventSheetResource = EventSheets.new_sheet()
	var loop_event: EventRow = EventRow.new()
	loop_event.trigger_provider_id = "Core"
	loop_event.trigger_id = "OnProcess"
	loop_event.event_uid = "abcdef12"
	var pick: PickFilter = PickFilter.new()
	pick.iterator_name = "enemy"
	pick.collection_value = "get_tree().get_nodes_in_group(\"enemies\")"
	pick.frame_spread_count = 90
	loop_event.pick_filters.append(pick)
	sheet.events.append(loop_event)
	var old_text: String = str(EventSheets.echo(sheet).get("output", ""))
	ok = SUPPORT.check(P, "a loop saved before keeps its long guard", old_text.contains(OLD_COUNT_ONLY), true) and ok
	ok = SUPPORT.check(P, "a loop saved before keeps its deadline local", old_text.contains("__loop_end_abcdef12_0"), true) and ok
	pick.tidy_budget = true
	var count_only: String = str(EventSheets.echo(sheet).get("output", ""))
	ok = SUPPORT.check(P, "a count alone writes only the count", count_only.contains("\t\tif __done_abcdef12_0 >= 90:\n\t\t\tbreak\n"), true) and ok
	ok = SUPPORT.check(P, "a count alone has no deadline local", count_only.contains("__loop_end_abcdef12_0"), false) and ok
	pick.frame_spread_count = 0
	pick.frame_spread_budget_ms = 2.0
	var time_only: String = str(EventSheets.echo(sheet).get("output", ""))
	ok = SUPPORT.check(P, "a time alone writes only the time test", time_only.contains("\t\tif __done_abcdef12_0 > 0 and Time.get_ticks_usec() >= __loop_end_abcdef12_0:\n"), true) and ok
	ok = SUPPORT.check(P, "a time alone keeps its deadline local", time_only.contains("var __loop_end_abcdef12_0: int = Time.get_ticks_usec() + int(2.0 * 1000.0)"), true) and ok
	pick.frame_spread_count = 90
	var both: String = str(EventSheets.echo(sheet).get("output", ""))
	ok = SUPPORT.check(P, "both limits write both tests", both.contains("\t\tif __done_abcdef12_0 > 0 and (__done_abcdef12_0 >= 90 or Time.get_ticks_usec() >= __loop_end_abcdef12_0):\n"), true) and ok
	# Every spelling opens and saves back byte for byte, the file that ships the old one and the new ones.
	var old_source: String = FileAccess.get_file_as_string("res://demo/showcase/swarm/swarm.gd")
	ok = SUPPORT.check(P, "the shipped budgeted loop opens and saves back byte for byte", EventSheets.round_trips(old_source), true) and ok
	for text: String in [count_only, time_only, both]:
		ok = SUPPORT.check(P, "a loop written in the plain spelling opens and saves back byte for byte", EventSheets.round_trips(text), true) and ok
	return ok
