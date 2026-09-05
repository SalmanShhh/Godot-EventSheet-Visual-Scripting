# Godot EventSheets - Project Doctor coroutine-in-per-frame advisory.
#
# A coroutine action (Wait / Wait For Signal / Await Next Frame / Await If Over Budget / raw `await`) under
# a re-firing On Process overlaps itself - the next tick fires while the previous run is still suspended, so
# the loop double-processes. The Doctor flags it. This drives the detection logic on hand-built events.
@tool
class_name CoroutineDoctorTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var all_passed: bool = true

	# Each await-causing ACE flags once.
	for ace_id: String in ["AwaitNextFrame", "Wait", "AwaitSignal", "AwaitIfOverBudget"]:
		var findings: Array[Dictionary] = []
		EventSheetProjectDoctor._scan_coroutine_misuse(_event_with_ace(ace_id), "res://x.tres", findings)
		all_passed = _check("%s flags coroutine-in-per-frame" % ace_id, findings.size() == 1 and str(findings[0].get("check")) == "coroutine-in-per-frame", true) and all_passed

	# Begin Frame Budget alone does NOT await - it just arms the fence - so it must not flag.
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

	# A pack row that awaits is caught by its own template, whether or not anybody remembered to
	# name it in the list - which is what the three lists were drifting apart over.
	var f3: Array[Dictionary] = []
	EventSheetProjectDoctor._scan_coroutine_misuse(
		_event_with_template("play_and_wait", "await $FeedbackPlayer.play_and_wait({at_strength})"), "res://x.tres", f3)
	all_passed = _check("a pack row that awaits flags", f3.size(), 1) and all_passed
	var f4: Array[Dictionary] = []
	EventSheetProjectDoctor._scan_coroutine_misuse(
		_event_with_template("play", "$FeedbackPlayer.play({at_strength})"), "res://x.tres", f4)
	all_passed = _check("and one that does not await stays quiet", f4.size(), 0) and all_passed

	# The three lists that have to agree, asked the same question about the same id.
	all_passed = _check("the Doctor knows the awaiting Feedback Player row",
		EventSheetProjectDoctor.COROUTINE_ACE_IDS.has("play_and_wait"), true) and all_passed
	all_passed = _check("and so does the compiler",
		SheetCompiler._COROUTINE_ACE_IDS.has("play_and_wait"), true) and all_passed
	all_passed = _check("and the canvas draws the hourglass on it",
		ViewportRowBuilder.action_awaits(_awaiting_action()), true) and all_passed

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


## An action whose template is the whole of what it is: a pack row, carrying no builtin id the
## lists above could have known in advance.
static func _event_with_template(ace_id: String, template: String) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnProcess"
	event.actions.append(_action(ace_id, template))
	return event


static func _awaiting_action() -> ACEAction:
	return _action("play_and_wait", "await $FeedbackPlayer.play_and_wait({at_strength})")


static func _action(ace_id: String, template: String) -> ACEAction:
	var act: ACEAction = ACEAction.new()
	act.provider_id = "FeedbackPlayer"
	act.ace_id = ace_id
	act.codegen_template = template
	return act


static func _event_with_raw(code: String) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = code
	event.actions.append(raw)
	return event


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("coroutine_doctor_test", label, actual, expected)
