# Godot EventSheets - the project index finishing its count does not build the rows again.
#
# A function head's hover card says who else calls the function, and that answer comes off a project
# index the editor counts a slice per frame. The rows of a freshly opened sheet are built while it is
# still counting, so their cards are built without it - and when the count landed, the dock rebuilt
# every row of the sheet to put it in. Measured 2026-10-27 on platformer_pathfinding (1,443 rows):
# the editor froze for 11-13 s a few seconds after the file had finished opening, with nobody
# touching it. The cards are now written again in place, and the rows are built again only when a
# band about a SCENE was laid out while that half was still counting.
@tool
class_name SharedCountRefreshTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PIN := "shared_count_refresh_test"
## `grant_xp` is called from progress.gd of the interop corpus and from nothing else in the project.
const CALLED_NAME := "grant_xp"
## How many function heads the timed refresh writes.
const BUDGET_FUNCTIONS: int = 200
## Measured 2026-10-27: 3.5-3.6 ms over three runs, where building those rows again took 94-96 ms
## (and twelve seconds on a real 1,443-row sheet). Three times the former.
const REFRESH_BUDGET_MS: int = 12


static func run() -> bool:
	var ok: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	var function: EventFunction = EventFunction.new()
	function.function_name = CALLED_NAME
	sheet.functions.append(function)
	# Built while the index has not counted anything: the card cannot name the caller yet.
	EventSheetProjectShareIndex.clear_cache()
	EventSheetProjectShareIndex.take_scene_waits()
	viewport.set_sheet(sheet)
	ok = SUPPORT.check(PIN, "a card built while counting does not name the caller",
		_card(viewport).contains("progress.gd"), false) and ok

	# The count lands. Only the card is written again: no row is built.
	EventSheetProjectShareIndex.build_now()
	var builds_before: int = viewport._row_builds
	viewport.refresh_after_shared_count()
	ok = SUPPORT.check(PIN, "the count landing builds no row", viewport._row_builds - builds_before, 0) and ok
	ok = SUPPORT.check(PIN, "and the card names the caller it was waiting for",
		_card(viewport).contains("called by progress.gd"), true) and ok

	# A band about a scene was laid out while the scene half was still counting: that one is part of
	# the row's layout, so the rows ARE built again, once.
	EventSheetProjectShareIndex.clear_cache()
	ok = SUPPORT.check(PIN, "a scene question asked while counting is told not yet",
		EventSheetProjectShareIndex.scenes_ready(), false) and ok
	EventSheetProjectShareIndex.build_now()
	builds_before = viewport._row_builds
	viewport.refresh_after_shared_count()
	ok = SUPPORT.check(PIN, "a scene band that waited builds the rows again once",
		viewport._row_builds - builds_before, 1) and ok
	ok = SUPPORT.check(PIN, "and the wait is forgotten once it was paid for",
		EventSheetProjectShareIndex.take_scene_waits(), false) and ok
	EventSheetProjectShareIndex.clear_cache()
	viewport.free()
	ok = _pin_refresh_budget() and ok
	return ok


## Writing the cards of a sheet of 200 functions again, against the budget. The full rebuild it
## replaces grows with every row of the sheet; this grows with the function heads alone.
static func _pin_refresh_budget() -> bool:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	for index: int in range(BUDGET_FUNCTIONS):
		var function: EventFunction = EventFunction.new()
		function.function_name = "%s_%d" % [CALLED_NAME, index] if index > 0 else CALLED_NAME
		sheet.functions.append(function)
	EventSheetProjectShareIndex.clear_cache()
	EventSheetProjectShareIndex.take_scene_waits()
	viewport.set_sheet(sheet)
	EventSheetProjectShareIndex.build_now()
	var started: int = Time.get_ticks_usec()
	viewport.refresh_after_shared_count()
	var elapsed_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	viewport.rebuild_rows()
	var rebuild_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	print("[budget] shared_count_refresh %d functions: cards %.1f ms, full rebuild %.1f ms (budget %d)" % [
		BUDGET_FUNCTIONS, elapsed_ms, rebuild_ms, REFRESH_BUDGET_MS])
	var ok: bool = SUPPORT.check(PIN, "the cards of %d functions are written within %d ms" % [
		BUDGET_FUNCTIONS, REFRESH_BUDGET_MS], elapsed_ms <= float(REFRESH_BUDGET_MS), true)
	EventSheetProjectShareIndex.clear_cache()
	viewport.free()
	return ok


## The hover card of the sheet's one function head.
static func _card(viewport: EventSheetViewport) -> String:
	var index: int = 0
	while viewport.get_row_data(index) != null:
		var row: EventRowData = viewport.get_row_data(index)
		if row.source_resource is EventFunction:
			for span: SemanticSpan in row.spans:
				var metadata: Dictionary = span.metadata as Dictionary
				if bool(metadata.get("function_name", false)):
					return str(metadata.get("hover_note", ""))
		index += 1
	return "<no function head>"
