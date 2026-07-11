# EventForge - On-ramp affordances (empty-state CTAs + "+ Add condition" link)
#
# Guards the beginner on-ramp shipped by the visuals pass:
#   1. empty_sheet_advice(null) is its own honest state (no sheet loaded is not "empty sheet").
#   2. The empty-state CTA button specs: one create button with no sheet, add-event +
#      template shortcut with an empty sheet, and stable action ids (the input path
#      dispatches on them).
#   3. Every built event row carries a "+ Add condition" span in the condition lane
#      (kind add_condition), on its own line below the conditions - including the
#      empty-event case where the Every Tick placeholder holds line 0.
# Headless-safe (no popups / display-server calls).
@tool
class_name OnrampAffordancesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# 1. Null-sheet advice is a distinct, honest state.
	var advice: Dictionary = EventSheetScriptIntent.empty_sheet_advice(null)
	all_passed = _check("null-sheet advice heading", str(advice.get("heading", "")), "No event sheet is open") and all_passed
	all_passed = _check("null-sheet advice has a primary line", str(advice.get("primary", "")).is_empty(), false) and all_passed
	var default_advice: Dictionary = EventSheetScriptIntent.empty_sheet_advice(EventSheetResource.new())
	all_passed = _check("empty-sheet advice stays the add-first-event push", str(default_advice.get("heading", "")), "This event sheet is empty") and all_passed

	# 2. CTA button specs: stable action ids in draw order.
	var no_sheet_specs: Array[Dictionary] = ViewportEmptyStateHelper.cta_specs(null)
	all_passed = _check("no-sheet CTA count", no_sheet_specs.size(), 1) and all_passed
	all_passed = _check("no-sheet CTA opens the starter menu", str(no_sheet_specs[0].get("action", "")), "template_menu") and all_passed
	var empty_specs: Array[Dictionary] = ViewportEmptyStateHelper.cta_specs(EventSheetResource.new())
	all_passed = _check("empty-sheet CTA count", empty_specs.size(), 2) and all_passed
	all_passed = _check("empty-sheet primary CTA adds an event", str(empty_specs[0].get("action", "")), "add_event") and all_passed
	all_passed = _check("empty-sheet secondary CTA opens templates", str(empty_specs[1].get("action", "")), "template_menu") and all_passed
	for spec: Dictionary in no_sheet_specs + empty_specs:
		all_passed = _check("CTA '%s' has a label" % str(spec.get("action", "")), str(spec.get("label", "")).is_empty(), false) and all_passed

	# 3. "+ Add condition" span on built event rows.
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var populated: EventRow = _make_row("on_tick", 1, 1)
	var populated_span: Dictionary = _find_span_metadata(viewport._build_event_spans(populated), "add_condition")
	all_passed = _check("populated row has an add_condition span", populated_span.is_empty(), false) and all_passed
	all_passed = _check("add_condition lives in the condition lane", str(populated_span.get("lane", "")), "condition") and all_passed
	all_passed = _check("add_condition sits below trigger + condition", int(populated_span.get("line_index", -1)), 2) and all_passed
	var empty_event: EventRow = _make_row("", 0, 0)
	var empty_span: Dictionary = _find_span_metadata(viewport._build_event_spans(empty_event), "add_condition")
	all_passed = _check("empty event keeps the add_condition span", empty_span.is_empty(), false) and all_passed
	all_passed = _check("add_condition sits below the Every Tick placeholder", int(empty_span.get("line_index", -1)), 1) and all_passed
	var action_span: Dictionary = _find_span_metadata(viewport._build_event_spans(populated), "add_action")
	all_passed = _check("add_action affordance still present", action_span.is_empty(), false) and all_passed
	viewport.free()

	return all_passed


static func _make_row(trigger_id: String, condition_count: int, action_count: int) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_id = trigger_id
	for i in range(condition_count):
		var condition: ACECondition = ACECondition.new()
		condition.ace_id = "cond_%d" % i
		row.conditions.append(condition)
	for i in range(action_count):
		var action: ACEAction = ACEAction.new()
		action.ace_id = "act_%d" % i
		row.actions.append(action)
	return row


static func _find_span_metadata(spans: Array, kind: String) -> Dictionary:
	for span in spans:
		if span != null and span.metadata is Dictionary and str((span.metadata as Dictionary).get("kind", "")) == kind:
			return span.metadata as Dictionary
	return {}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] onramp_affordances_test: %s" % label)
		return true
	print("[FAIL] onramp_affordances_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
