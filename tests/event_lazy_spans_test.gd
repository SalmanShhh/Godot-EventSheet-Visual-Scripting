# EventForge - Lazy event-span invariants
#
# Event-row spans are built lazily (only when a row is laid out/hit/selected) so large
# sheets load fast. Row heights/metrics are derived up front from a cheap line count.
# This test guards the two invariants that make that safe:
#   1. _count_event_lines(e) == (max span line_index in _build_event_spans(e)) + 1
#      for a range of event shapes (else/elif, triggers, conditions, actions, comments).
#   2. After loading a sheet, event-row spans are empty until _ensure_event_spans()
#      builds them, and the built span count is non-trivial.
# Headless-safe (no popups / display-server calls).
@tool
class_name EventLazySpansTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()

	for case in _build_cases():
		var label: String = case["name"]
		var event_row: EventRow = case["row"]
		var spans: Array = viewport._build_event_spans(event_row)
		var max_line_index: int = -1
		for span in spans:
			if span != null and span.metadata is Dictionary:
				max_line_index = maxi(max_line_index, int((span.metadata as Dictionary).get("line_index", 0)))
		var spans_lines: int = max_line_index + 1
		var counted: int = viewport._count_event_lines(event_row)
		all_passed = _check(
			"line count matches spans for '%s' (counted=%d, spans=%d)" % [label, counted, spans_lines],
			counted == spans_lines, true) and all_passed

	# Lazy-load behavior: a sheet larger than EAGER_SPAN_LIMIT keeps spans lazy.
	var big_sheet: EventSheetResource = EventSheetResource.new()
	for i in range(EventSheetViewport.EAGER_SPAN_LIMIT + 50):
		big_sheet.events.append(_make_row("on_tick", 2, 2, ""))
	viewport.set_sheet(big_sheet)
	var first: EventRowData = viewport.get_flat_rows()[0].get("row")
	all_passed = _check("first row is an event row", first != null and first.row_type == EventRowData.RowType.EVENT, true) and all_passed
	all_passed = _check("event spans are lazy (empty) right after load (large sheet)", first != null and first.spans.is_empty(), true) and all_passed
	all_passed = _check("line_count precomputed for lazy row", first != null and first.line_count >= 1, true) and all_passed
	if first != null:
		viewport._ensure_event_spans(first)
		all_passed = _check("ensure builds the event spans", not first.spans.is_empty(), true) and all_passed

	# Integration: interacting with a lazy (off-screen) row must build its spans via
	# the layout/selection choke points (not just a direct _ensure_event_spans call).
	viewport.set_sheet(big_sheet)
	var hit_index: int = 4
	var hit_row: EventRowData = viewport.get_flat_rows()[hit_index].get("row")
	all_passed = _check("lazy row has no spans before interaction", hit_row != null and hit_row.spans.is_empty(), true) and all_passed
	var hit_y: float = viewport._get_row_top(hit_index) + 2.0
	viewport._hit_test(Vector2(40.0, hit_y))
	all_passed = _check("hit-test builds spans for the touched row", hit_row != null and not hit_row.spans.is_empty(), true) and all_passed

	viewport.set_sheet(big_sheet)
	var sel_index: int = 7
	var sel_row: EventRowData = viewport.get_flat_rows()[sel_index].get("row")
	all_passed = _check("lazy row has no spans before selection", sel_row != null and sel_row.spans.is_empty(), true) and all_passed
	viewport._select_row(sel_index)
	all_passed = _check("selection builds spans for the selected row", sel_row != null and not sel_row.spans.is_empty(), true) and all_passed

	# Small sheets (<= EAGER_SPAN_LIMIT) build spans eagerly, matching the original behavior.
	var small_sheet: EventSheetResource = EventSheetResource.new()
	small_sheet.events.append(_make_row("on_tick", 1, 1, ""))
	viewport.set_sheet(small_sheet)
	var small_first: EventRowData = viewport.get_flat_rows()[0].get("row")
	all_passed = _check("small sheet builds event spans eagerly", small_first != null and not small_first.spans.is_empty(), true) and all_passed

	viewport.free()
	return all_passed


static func _build_cases() -> Array:
	var cases: Array = []
	cases.append({"name": "empty (every tick)", "row": _make_row("", 0, 0, "")})
	cases.append({"name": "trigger only", "row": _make_row("on_tick", 0, 0, "")})
	cases.append({"name": "trigger + 1 condition", "row": _make_row("on_tick", 1, 0, "")})
	cases.append({"name": "trigger + 3 conditions", "row": _make_row("on_tick", 3, 0, "")})
	cases.append({"name": "2 actions, no trigger", "row": _make_row("", 0, 2, "")})
	cases.append({"name": "trigger + 2 cond + 3 act", "row": _make_row("on_tick", 2, 3, "")})
	cases.append({"name": "comment, no actions", "row": _make_row("on_tick", 1, 0, "note")})
	cases.append({"name": "comment + 2 actions", "row": _make_row("on_tick", 1, 2, "note")})
	cases.append({"name": "explicit trigger resource", "row": _make_trigger_resource_row(2, 2)})
	cases.append({"name": "else mode", "row": _make_else_row(EventRow.ElseMode.ELSE, 1, 1)})
	cases.append({"name": "elif mode", "row": _make_else_row(EventRow.ElseMode.ELIF, 1, 1)})
	cases.append({"name": "OR conditions negated", "row": _make_or_row()})
	return cases


static func _make_row(trigger_id: String, condition_count: int, action_count: int, comment: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_id = trigger_id
	row.comment = comment
	for i in range(condition_count):
		var condition: ACECondition = ACECondition.new()
		condition.ace_id = "cond_%d" % i
		row.conditions.append(condition)
	for i in range(action_count):
		var action: ACEAction = ACEAction.new()
		action.ace_id = "act_%d" % i
		row.actions.append(action)
	return row


static func _make_trigger_resource_row(condition_count: int, action_count: int) -> EventRow:
	var row: EventRow = _make_row("", condition_count, action_count, "")
	row.trigger = ACECondition.new()
	row.trigger.ace_id = "explicit_trigger"
	return row


static func _make_else_row(else_mode: int, condition_count: int, action_count: int) -> EventRow:
	var row: EventRow = _make_row("", condition_count, action_count, "")
	row.else_mode = else_mode
	return row


static func _make_or_row() -> EventRow:
	var row: EventRow = _make_row("", 3, 1, "")
	row.condition_mode = EventRow.ConditionMode.OR
	(row.conditions[1] as ACECondition).negated = true
	return row


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] event_lazy_spans_test: %s" % label)
		return true
	print("[FAIL] event_lazy_spans_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
