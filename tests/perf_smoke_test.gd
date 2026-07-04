# EventForge - Performance smoke test (virtualized viewport stress guard)
#
# Guards the core invariants that let the editor handle tens of thousands of
# events/ACEs without killing editor performance:
#   1. Building the model->view rows for a 10k-event sheet stays within a generous
#      time budget (regression guard against accidental O(n^2) work, NOT a micro-bench).
#   2. The viewport spawns NO per-row Control widgets regardless of row count
#      (everything is custom-drawn).
#   3. The visible draw window stays bounded by viewport height (visible-range
#      culling), so per-frame paint cost does not scale with total row count.
@tool
class_name PerfSmokeTest
extends RefCounted

const EVENT_COUNT := 10000
const NEST_EVERY := 25           # every Nth root event nests two sub-events
const SETUP_BUDGET_MS := 15000   # generous; catches O(n^2), not micro-regressions
const MAX_VISIBLE_WINDOW := 400  # culled draw window must be far below EVENT_COUNT


static func run() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = _build_large_sheet(EVENT_COUNT)

	var editor: EventSheetEditor = EventSheetEditor.new()
	var start_us: int = Time.get_ticks_usec()
	editor.setup(sheet)
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_us) / 1000.0

	var viewport: EventSheetViewport = editor.get_viewport_control()
	var total_rows: int = viewport.get_total_row_count()
	# Constrain the viewport via its scroll container so visible-range culling is
	# exercised the way it is in the real (clipped) editor, rather than the viewport
	# sizing itself to the full content height out of tree.
	var scroll: ScrollContainer = editor.find_child("EventSheetScroll", true, false) as ScrollContainer
	if scroll != null:
		scroll.size = Vector2(1280.0, 720.0)
		scroll.scroll_vertical = 0
	var visible: Vector2i = viewport.get_visible_row_range()
	var window: int = (visible.y - visible.x + 1) if visible.x >= 0 else 0

	all_passed = _check(
		"built >= %d flat rows from large sheet (got %d)" % [EVENT_COUNT, total_rows],
		total_rows >= EVENT_COUNT, true) and all_passed
	all_passed = _check(
		"viewport spawns no per-row widgets at %d rows (child_count=%d)" % [total_rows, viewport.get_child_count()],
		viewport.get_child_count() == 0, true) and all_passed
	all_passed = _check(
		"visible draw window bounded <= %d despite %d rows (window=%d)" % [MAX_VISIBLE_WINDOW, total_rows, window],
		window > 0 and window <= MAX_VISIBLE_WINDOW, true) and all_passed
	all_passed = _check(
		"setup(%d events) under %d ms (took %.1f ms)" % [EVENT_COUNT, SETUP_BUDGET_MS, elapsed_ms],
		elapsed_ms <= float(SETUP_BUDGET_MS), true) and all_passed

	editor.free()
	return all_passed


## Builds a large in-memory EventSheet for stress/perf testing.
## Each event carries a trigger, two conditions and two actions; every NEST_EVERY-th
## event nests two sub-events to exercise the flatten/indent path.
static func _build_large_sheet(count: int) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var events: Array[Resource] = []
	for i in range(count):
		var row: EventRow = _build_event_row(i)
		if i % NEST_EVERY == 0:
			row.sub_events.append(_build_event_row(i * 1000 + 1))
			row.sub_events.append(_build_event_row(i * 1000 + 2))
		events.append(row)
	sheet.events = events
	return sheet


static func _build_event_row(value_seed: int) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "on_tick"
	var cond_a: ACECondition = ACECondition.new()
	cond_a.ace_id = "is_value_greater"
	cond_a.params = {"value": value_seed, "threshold": 10}
	var cond_b: ACECondition = ACECondition.new()
	cond_b.ace_id = "is_enabled"
	row.conditions.append(cond_a)
	row.conditions.append(cond_b)
	var act_a: ACEAction = ACEAction.new()
	act_a.ace_id = "set_value"
	act_a.params = {"value": value_seed}
	var act_b: ACEAction = ACEAction.new()
	act_b.ace_id = "print_message"
	act_b.params = {"message": "row %d" % value_seed}
	row.actions.append(act_a)
	row.actions.append(act_b)
	return row


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] perf_smoke_test: %s" % label)
		return true
	print("[FAIL] perf_smoke_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
