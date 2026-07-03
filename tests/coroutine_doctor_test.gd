# Godot EventSheets — Project Doctor coroutine-in-per-frame advisory.
#
# A coroutine action (Wait / Wait For Signal / Await Next Frame / Await If Over Budget / raw `await`) under
# a re-firing On Process overlaps itself — the next tick fires while the previous run is still suspended, so
# the loop double-processes. The Doctor flags it. This drives the detection logic on hand-built events.
@tool
class_name CoroutineDoctorTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# Each await-causing ACE flags once.
	for ace_id: String in ["AwaitNextFrame", "Wait", "AwaitSignal", "AwaitIfOverBudget"]:
		var findings: Array[Dictionary] = []
		EventSheetProjectDoctor._scan_coroutine_misuse(_event_with_ace(ace_id), "res://x.tres", findings)
		all_passed = _check("%s flags coroutine-in-per-frame" % ace_id, findings.size() == 1 and str(findings[0].get("check")) == "coroutine-in-per-frame", true) and all_passed

	# Begin Frame Budget alone does NOT await — it just arms the fence — so it must not flag.
	var f0: Array[Dictionary] = []
	EventSheetProjectDoctor._scan_coroutine_misuse(_event_with_ace("BeginFrameBudget"), "res://x.tres", f0)
	all_passed = _check("Begin Frame Budget alone is not a coroutine", f0.size(), 0) and all_passed

	# A raw GDScript block that awaits flags; a plain block does not.
	var f1: Array[Dictionary] = []
	EventSheetProjectDoctor._scan_coroutine_misuse(_event_with_raw("await get_tree().process_frame"), "res://x.tres", f1)
	all_passed = _check("a raw await block flags", f1.size(), 1) and all_passed
	var f2: Array[Dictionary] = []
	EventSheetProjectDoctor._scan_coroutine_misuse(_event_with_raw("health -= 1"), "res://x.tres", f2)
	all_passed = _check("a non-coroutine action does not flag", f2.size(), 0) and all_passed

	# The caller gates on per-frame triggers, so a one-shot trigger is never scanned.
	all_passed = _check("OnReady is not per-frame (caller skips it)", EventSheetProjectDoctor._is_per_frame_trigger("OnReady"), false) and all_passed
	all_passed = _check("OnProcess is per-frame", EventSheetProjectDoctor._is_per_frame_trigger("OnProcess"), true) and all_passed

	return all_passed


static func _event_with_ace(ace_id: String) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnProcess"
	var act: ACEAction = ACEAction.new()
	act.provider_id = "Core"
	act.ace_id = ace_id
	event.actions.append(act)
	return event


static func _event_with_raw(code: String) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = code
	event.actions.append(raw)
	return event


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] coroutine_doctor_test: %s" % label)
		return true
	print("[FAIL] coroutine_doctor_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
