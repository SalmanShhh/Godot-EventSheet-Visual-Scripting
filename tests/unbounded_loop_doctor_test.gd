# Godot EventSheets - Project Doctor unbounded-loop advisory (frame-spreading Solution 5).
#
# A heavy For Each that runs every frame and is neither capped (pick_first_n) nor budgeted (frame_spread)
# can hitch the game. The Doctor flags the PATTERN. This drives the detection logic directly on hand-built
# events (the public check loads sheets from disk; the core logic is what matters here).
@tool
class_name UnboundedLoopDoctorTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var all_passed: bool = true

	# Trigger classification.
	all_passed = _check("OnProcess is a per-frame trigger", EventSheetProjectDoctor._is_per_frame_trigger("OnProcess"), true) and all_passed
	all_passed = _check("OnPhysicsProcess is per-frame", EventSheetProjectDoctor._is_per_frame_trigger("OnPhysicsProcess"), true) and all_passed
	all_passed = _check("OnReady is NOT per-frame", EventSheetProjectDoctor._is_per_frame_trigger("OnReady"), false) and all_passed

	# An unbounded For Each with >= threshold actions flags once.
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor._scan_unbounded_loops(_loop_event(0, 0.0, 0, 3), "res://x.tres", 3, findings)
	all_passed = _check("unbounded per-frame loop with enough actions flags", findings.size() == 1 and str(findings[0].get("check")) == "unbounded-loop", true) and all_passed

	# Budgeted loops (count or ms) are exempt - this is what the new PickFilter fields buy us.
	findings = []
	EventSheetProjectDoctor._scan_unbounded_loops(_loop_event(10, 0.0, 0, 3), "res://x.tres", 3, findings)
	all_passed = _check("a count-budgeted loop is exempt", findings.size(), 0) and all_passed
	findings = []
	EventSheetProjectDoctor._scan_unbounded_loops(_loop_event(0, 4.0, 0, 3), "res://x.tres", 3, findings)
	all_passed = _check("a ms-budgeted loop is exempt", findings.size(), 0) and all_passed

	# A capped loop (pick first N) is exempt.
	findings = []
	EventSheetProjectDoctor._scan_unbounded_loops(_loop_event(0, 0.0, 5, 3), "res://x.tres", 3, findings)
	all_passed = _check("a pick-first-N loop is exempt", findings.size(), 0) and all_passed

	# Below the action threshold is exempt (flags the cost pattern, not every loop).
	findings = []
	EventSheetProjectDoctor._scan_unbounded_loops(_loop_event(0, 0.0, 0, 2), "res://x.tres", 3, findings)
	all_passed = _check("a light loop (under threshold) is exempt", findings.size(), 0) and all_passed

	# A loop in an event that has a condition of its own is not accused, nor one under a sub-event that
	# does: the guard may be a key press or a once flag, and the audit cannot tell which. An unguarded
	# sub-event is still walked.
	var guarded_parent: EventRow = EventRow.new()
	guarded_parent.trigger_id = "OnProcess"
	var guarded_child: EventRow = _loop_event(0, 0.0, 0, 3)
	guarded_child.trigger_id = ""
	guarded_child.conditions.append(ACECondition.new())
	guarded_parent.sub_events.append(guarded_child)
	findings = []
	EventSheetProjectDoctor._scan_unbounded_loops(guarded_parent, "res://x.tres", 3, findings)
	all_passed = _check("a loop under a guarded sub-event is not accused", findings.size(), 0) and all_passed
	var guarded_top: EventRow = _loop_event(0, 0.0, 0, 3)
	guarded_top.conditions.append(ACECondition.new())
	findings = []
	EventSheetProjectDoctor._scan_unbounded_loops(guarded_top, "res://x.tres", 3, findings)
	all_passed = _check("a loop in an event with its own condition is not accused either", findings.size(), 0) and all_passed
	var open_parent: EventRow = EventRow.new()
	open_parent.trigger_id = "OnProcess"
	var open_child: EventRow = _loop_event(0, 0.0, 0, 3)
	open_child.trigger_id = ""
	open_parent.sub_events.append(open_child)
	findings = []
	EventSheetProjectDoctor._scan_unbounded_loops(open_parent, "res://x.tres", 3, findings)
	all_passed = _check("a loop under an unguarded sub-event still is", findings.size(), 1) and all_passed

	return all_passed


static func _loop_event(spread_count: int, spread_ms: float, first_n: int, action_count: int) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnProcess"
	var pick: PickFilter = PickFilter.new()
	pick.enabled = true
	pick.collection_kind = PickFilter.CollectionKind.GROUP
	pick.collection_value = "\"enemies\""
	pick.iterator_name = "enemy"
	pick.pick_first_n = first_n
	pick.frame_spread_count = spread_count
	pick.frame_spread_budget_ms = spread_ms
	event.pick_filters.append(pick)
	for _i in action_count:
		event.actions.append(RawCodeRow.new())
	return event


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("unbounded_loop_doctor_test", label, actual, expected)
