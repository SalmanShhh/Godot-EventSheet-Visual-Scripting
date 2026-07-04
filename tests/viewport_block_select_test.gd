# EventForge - clicking OUTSIDE the condition cell still selects the event block.
# Complements viewport_hit_select_test (which pins the Y→row resolution): this pins the per-row
# hit-test, so a click in a row's lane but off every cell - or in the left gutter - resolves to a
# WHOLE-ROW selection (span_index -1, row_index set), which _select_from_click turns into a block
# selection (and makes Delete act on the block instead of falling through to the scene tree).
@tool
class_name ViewportBlockSelectTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	var span: SemanticSpan = SemanticSpan.new()
	span.rect = Rect2(20, 0, 100, 20)  # the condition cell: x 20..120, y 0..20
	span.hoverable = true
	span.metadata = {"kind": "condition", "condition_index": 0}
	var row: EventRowData = EventRowData.new()
	row.spans = [span]
	# lane_divider_x=200 (left of it is the condition lane); gutter is the 0..20 left margin.
	var layout: Dictionary = {"lane_divider_x": 200.0, "gutter_rect": Rect2(0, 0, 20, 60)}
	var resolve_lane: Callable = func(_s): return "condition"
	var find_cond: Callable = func(_rd, _ci): return 0

	# Clicking the condition cell itself still targets that condition span.
	var on_cell: Dictionary = ViewportHitTestHelper.hit_test_row(Vector2(60, 10), 0, layout, row, resolve_lane, find_cond)
	ok = _check("click on the condition cell hits the condition span", int(on_cell.get("span_index", -99)), 0) and ok

	# Clicking the EMPTY area of the lane (below the cell) - the reported case - selects the WHOLE row.
	var empty_lane: Dictionary = ViewportHitTestHelper.hit_test_row(Vector2(60, 50), 0, layout, row, resolve_lane, find_cond)
	ok = _check("click outside the condition cell resolves the event row", int(empty_lane.get("row_index", -99)), 0) and ok
	ok = _check("click outside the condition cell selects the whole row (no span)", int(empty_lane.get("span_index", -99)), -1) and ok

	# Clicking the left gutter selects the whole row too.
	var gutter: Dictionary = ViewportHitTestHelper.hit_test_row(Vector2(8, 30), 0, layout, row, resolve_lane, find_cond)
	ok = _check("click in the gutter resolves the event row", int(gutter.get("row_index", -99)), 0) and ok
	ok = _check("click in the gutter selects the whole row", int(gutter.get("span_index", -99)), -1) and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] viewport_block_select_test: %s" % label)
		return true
	print("[FAIL] viewport_block_select_test: %s" % label)
	print("  expected: %s, actual: %s" % [str(expected), str(actual)])
	return false
