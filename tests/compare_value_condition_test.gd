# EventForge — CompareValue condition compile test
@tool
extends RefCounted
class_name CompareValueConditionTest

## Verifies CompareValue condition metadata and compiler output.
static func run() -> bool:
	var all_passed: bool = true

	var compare_value: ACEDescriptor = ACERegistry.find_descriptor("Core", "CompareValue")
	all_passed = _check("compare value descriptor exists", compare_value != null, true) and all_passed

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"

	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "CompareValue"
	condition.params = {
		"left": "health + 1",
		"op": ">=",
		"right": "max_health"
	}
	condition.parameters = condition.params.duplicate(true)
	row.conditions.append(condition)

	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "PrintLog"
	action.params = {
		"message": "\"CompareValue ok\""
	}
	action.parameters = action.params.duplicate(true)
	row.actions.append(action)
	sheet.events.append(row)

	var result: Dictionary = SheetCompiler.compile(sheet, "user://compare_value_generated_test_output.gd")
	all_passed = _check("compare value compile success", bool(result.get("success", false)), true) and all_passed
	var output: String = str(result.get("output", ""))
	all_passed = _check("compare value condition emitted", output.contains("\tif health + 1 >= max_health:"), true) and all_passed
	all_passed = _check("compare value action emitted", output.contains("\t\tprint(\"CompareValue ok\")"), true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] compare_value_condition_test: %s" % label)
		return true
	print("[FAIL] compare_value_condition_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
