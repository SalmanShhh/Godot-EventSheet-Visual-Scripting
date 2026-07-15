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

	ok = _check("the match header renders", texts.has("match phase:"), true) and ok
	ok = _check("the first case pattern renders", texts.has("\t0:"), true) and ok
	ok = _check("the case body is summarised (not a raw blob)", texts.has("\t\tvelocity = Vector2.ZERO"), true) and ok
	ok = _check("the default case pattern renders", texts.has("\t_:"), true) and ok
	ok = _check("an empty case reads as pass", texts.has("\t\tpass"), true) and ok
	ok = _check("branches_text is not shown when cases exist", _any_contains(texts, "SHOULD_NOT_SHOW"), false) and ok
	ok = _check("structured match spans are read-only (no match_action dialog)", match_action_texts.is_empty(), true) and ok

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
