# Godot EventSheets - the Doctor's obvious-param-type lint
# A param declared float/int/bool holding a plain literal of the wrong kind (a quoted
# string in a number slot, a number in a bool slot) gets an advisory finding. The
# conservatism IS the contract: expressions, identifiers, and String-typed params are
# never judged - expressions are opaque by design, so this check must never cry wolf.
# Pins: every literal_type_mismatch verdict (fire AND must-NOT-fire), the end-to-end scan
# against a real typed builtin descriptor, and sub-event recursion.
@tool
class_name ParamTypeLintTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ---- the verdicts, value by value ----
	var doctor := EventSheetProjectDoctor
	all_passed = _check("a quoted string in a float slot fires", doctor.literal_type_mismatch("float", "\"3.5\"").is_empty(), false) and all_passed
	all_passed = _check("a bool in an int slot fires", doctor.literal_type_mismatch("int", "true").is_empty(), false) and all_passed
	all_passed = _check("a number in a bool slot fires", doctor.literal_type_mismatch("bool", "1").is_empty(), false) and all_passed
	all_passed = _check("a quoted string in a bool slot fires", doctor.literal_type_mismatch("bool", "\"yes\"").is_empty(), false) and all_passed
	all_passed = _check("a plain number in a float slot is fine", doctor.literal_type_mismatch("float", "3.5"), "") and all_passed
	all_passed = _check("an int literal in a float slot is fine", doctor.literal_type_mismatch("float", "3"), "") and all_passed
	all_passed = _check("true in a bool slot is fine", doctor.literal_type_mismatch("bool", "true"), "") and all_passed
	all_passed = _check("an EXPRESSION is never judged", doctor.literal_type_mismatch("float", "speed * 2"), "") and all_passed
	all_passed = _check("an identifier is never judged", doctor.literal_type_mismatch("bool", "is_ready"), "") and all_passed
	all_passed = _check("a String slot is never judged", doctor.literal_type_mismatch("String", "\"anything\""), "") and all_passed
	all_passed = _check("string concatenation is not a whole-value literal", doctor.literal_type_mismatch("float", "\"a\" + \"b\""), "") and all_passed
	all_passed = _check("an empty value is fine", doctor.literal_type_mismatch("int", ""), "") and all_passed

	# ---- end to end: a real typed builtin param, firing and clean ----
	var bad_row: EventRow = EventRow.new()
	bad_row.trigger_provider_id = "Core"
	bad_row.trigger_id = "OnReady"
	var bad_action: ACEAction = ACEAction.new()
	bad_action.provider_id = "Core"
	bad_action.ace_id = "VibrationHandheld"
	bad_action.params = {"duration_ms": "\"200\""}
	bad_row.actions.append(bad_action)
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor._scan_param_types(bad_row, "res://probe.tres", findings)
	all_passed = _check("a quoted number in the int slot yields exactly one finding", findings.size(), 1) and all_passed
	if findings.size() == 1:
		all_passed = _check("the finding is advisory", str(findings[0].get("severity", "")), "info") and all_passed
		all_passed = _check("the finding names the check", str(findings[0].get("check", "")), "param-type") and all_passed
		all_passed = _check("the message names the ACE, param, and value",
			str(findings[0].get("message", "")),
			"Vibrate Phone's \"duration_ms\" expects int but holds a quoted string (\"200\") - double-check the value.") and all_passed

	var clean_row: EventRow = EventRow.new()
	clean_row.trigger_provider_id = "Core"
	clean_row.trigger_id = "OnReady"
	var clean_action: ACEAction = ACEAction.new()
	clean_action.provider_id = "Core"
	clean_action.ace_id = "VibrationHandheld"
	clean_action.params = {"duration_ms": "duration * 1000"}
	clean_row.actions.append(clean_action)
	var clean_findings: Array[Dictionary] = []
	EventSheetProjectDoctor._scan_param_types(clean_row, "res://probe.tres", clean_findings)
	all_passed = _check("an expression in the same slot stays silent", clean_findings.size(), 0) and all_passed

	# ---- sub-events are scanned too ----
	var parent_row: EventRow = EventRow.new()
	parent_row.trigger_provider_id = "Core"
	parent_row.trigger_id = "OnReady"
	parent_row.sub_events.append(bad_row)
	var nested_findings: Array[Dictionary] = []
	EventSheetProjectDoctor._scan_param_types(parent_row, "res://probe.tres", nested_findings)
	all_passed = _check("sub-events are scanned", nested_findings.size(), 1) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] param_type_lint_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
