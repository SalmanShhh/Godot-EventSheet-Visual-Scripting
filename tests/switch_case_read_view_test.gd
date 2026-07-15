# EventForge - a structured switch/case (a MatchRow with `cases`) renders each case as a readable `pattern:`
# line with its body summarised beneath, instead of a raw branches_text blob. Pins: the case lines appear in
# the event's action spans, an empty case reads as `pass`, branches_text is NOT shown when cases exist, and -
# so a structured match never opens the branches_text dialog it cannot represent - the structured match spans
# carry no `match_action` flag (read-only until the editing phase lands). Pure view (no compile/model touch).
@tool
class_name SwitchCaseReadViewTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	var idle_body: RawCodeRow = RawCodeRow.new()
	idle_body.code = "velocity = Vector2.ZERO"
	var idle_case: MatchCase = MatchCase.new()
	idle_case.pattern = "0"
	idle_case.events = [idle_body]
	var default_case: MatchCase = MatchCase.new()
	default_case.pattern = "_"
	default_case.events = []  # empty -> `pass`
	var match_row: MatchRow = MatchRow.new()
	match_row.match_expression = "phase"
	match_row.branches_text = "SHOULD_NOT_SHOW:\n\tbreakpoint"
	match_row.cases = [idle_case, default_case]

	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.actions.append(match_row)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.events.append(event)

	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)

	var event_row_data: EventRowData = null
	for entry: Dictionary in viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == event:
			event_row_data = row_data
	ok = _check("the event row renders", event_row_data != null, true) and ok
	if event_row_data == null:
		viewport.free()
		return false

	var texts: Array = []
	var match_action_texts: Array = []
	for span: SemanticSpan in event_row_data.spans:
		texts.append(str(span.text))
		if span.metadata is Dictionary and bool((span.metadata as Dictionary).get("match_action", false)):
			match_action_texts.append(str(span.text))

	ok = _check("the event shows just the match header in its action lane", texts.has("match phase:"), true) and ok
	ok = _check("branches_text is not shown when cases exist", _any_contains(texts, "SHOULD_NOT_SHOW"), false) and ok
	ok = _check("the match header opens the editor on double-click (match_action)", not match_action_texts.is_empty(), true) and ok

	# ── Each case maps onto the sheet's model: a condition/action CHILD row - PATTERN in the condition cell,
	# BODY in the action cell (not a flat text block in one action lane) ──
	var case_rows: Array = []
	for child: EventRowData in event_row_data.children:
		if child.row_type == EventRowData.RowType.EVENT and _lane_span(child, "condition") != null:
			case_rows.append(child)
	ok = _check("each case renders as its own condition/action row (2 cases)", case_rows.size(), 2) and ok
	if case_rows.size() == 2:
		ok = _check("a case row is an EVENT row (so it gets the condition | action lanes)",
			(case_rows[0] as EventRowData).row_type == EventRowData.RowType.EVENT, true) and ok
		ok = _check("the first case's PATTERN is in the condition cell", _lane_text(case_rows[0], "condition"), "0") and ok
		ok = _check("the first case's BODY is in the action cell", _lane_text(case_rows[0], "action"), "velocity = Vector2.ZERO") and ok
		ok = _check("the default case's pattern is in the condition cell", _lane_text(case_rows[1], "condition"), "_") and ok
		ok = _check("an empty case reads as a `pass` action", _lane_text(case_rows[1], "action"), "pass") and ok

	# ── A raw-text MatchRow (no cases) still shows its branches and keeps the double-click dialog ──
	var raw_match: MatchRow = MatchRow.new()
	raw_match.match_expression = "mode"
	raw_match.branches_text = "1:\n\tprint(\"one\")"
	var raw_event: EventRow = EventRow.new()
	raw_event.trigger_provider_id = "Core"
	raw_event.trigger_id = "OnProcess"
	raw_event.actions.append(raw_match)
	var raw_sheet: EventSheetResource = EventSheetResource.new()
	raw_sheet.host_class = "Node2D"
	raw_sheet.events.append(raw_event)
	viewport.set_sheet(raw_sheet)
	var raw_row_data: EventRowData = null
	for entry: Dictionary in viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == raw_event:
			raw_row_data = row_data
	var raw_has_match_action: bool = false
	var raw_shows_branch: bool = false
	if raw_row_data != null:
		for span: SemanticSpan in raw_row_data.spans:
			if str(span.text).contains("print(\"one\")"):
				raw_shows_branch = true
			if span.metadata is Dictionary and bool((span.metadata as Dictionary).get("match_action", false)):
				raw_has_match_action = true
	ok = _check("a raw-text match still shows its branches", raw_shows_branch, true) and ok
	ok = _check("a raw-text match keeps its double-click dialog (match_action)", raw_has_match_action, true) and ok

	viewport.free()
	return ok


static func _lane_span(row: EventRowData, lane: String) -> SemanticSpan:
	for span: SemanticSpan in row.spans:
		if span.metadata is Dictionary and str((span.metadata as Dictionary).get("lane")) == lane:
			return span
	return null


static func _lane_text(row: EventRowData, lane: String) -> String:
	var span: SemanticSpan = _lane_span(row, lane)
	return str(span.text) if span != null else "<none>"


static func _any_contains(texts: Array, needle: String) -> bool:
	for t: Variant in texts:
		if str(t).contains(needle):
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] switch_case_read_view_test: %s" % label)
		return true
	print("[FAIL] switch_case_read_view_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
