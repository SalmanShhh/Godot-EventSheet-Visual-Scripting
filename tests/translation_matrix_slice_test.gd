# EventForge — First translation-matrix slice compiler tests
@tool
extends RefCounted
class_name TranslationMatrixSliceTest

const SHEET_PATH: String = "res://tests/fixtures/translation_matrix_slice.tres"
const GOLDEN_PATH: String = "res://tests/fixtures/translation_matrix_slice_expected.gd"
const TEST_OUTPUT_PATH: String = "res://tests/fixtures/translation_matrix_slice_generated_test_output.gd"
const UNSUPPORTED_OUTPUT_PATH: String = "res://tests/fixtures/translation_matrix_slice_unsupported_generated_test_output.gd"

## Runs first translation-matrix slice compiler checks.
static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_supported_slice_golden_output() and all_passed
	all_passed = _test_unsupported_construct_warnings() and all_passed
	if all_passed:
		print("[PASS] translation_matrix_slice_test")
	else:
		print("[FAIL] translation_matrix_slice_test")
	return all_passed

static func _test_supported_slice_golden_output() -> bool:
	var sheet: EventSheetResource = load(SHEET_PATH) as EventSheetResource
	if sheet == null:
		print("[FAIL] translation_matrix_slice_test: failed to load fixture sheet")
		return false

	var result: Dictionary = SheetCompiler.compile(sheet, TEST_OUTPUT_PATH)
	if not bool(result.get("success", false)):
		print("[FAIL] translation_matrix_slice_test: compile failed %s" % str(result.get("errors", [])))
		return false

	var warnings: Array[String] = result.get("warnings", []) as Array[String]
	if warnings.size() != 0:
		print("[FAIL] translation_matrix_slice_test: expected no warnings for supported slice")
		print("warnings: %s" % str(warnings))
		return false

	var expected: String = FileAccess.get_file_as_string(GOLDEN_PATH)
	var actual: String = str(result.get("output", ""))
	if expected != actual:
		print("[FAIL] translation_matrix_slice_test: golden mismatch")
		print("Expected:\n%s" % expected)
		print("Actual:\n%s" % actual)
		return false

	print("[PASS] translation_matrix_slice_test: golden output")
	return true

static func _test_unsupported_construct_warnings() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"

	var unsupported_trigger_event: EventRow = EventRow.new()
	unsupported_trigger_event.trigger_provider_id = "Core"
	unsupported_trigger_event.trigger_id = "OnBodyEntered"
	unsupported_trigger_event.conditions = [
		_make_condition("Always", {})
	]
	unsupported_trigger_event.actions = [
		_make_action("PrintLog", {"message": "\"trigger unsupported\""})
	]

	var unsupported_condition_event: EventRow = EventRow.new()
	unsupported_condition_event.trigger_provider_id = "Core"
	unsupported_condition_event.trigger_id = "OnProcess"
	unsupported_condition_event.conditions = [
		_make_condition("HasGroupMember", {"group": "\"enemy\""})
	]
	unsupported_condition_event.actions = [
		_make_action("PrintLog", {"message": "\"condition unsupported\""})
	]

	var unsupported_action_event: EventRow = EventRow.new()
	unsupported_action_event.trigger_provider_id = "Core"
	unsupported_action_event.trigger_id = "OnProcess"
	unsupported_action_event.conditions = [
		_make_condition("Always", {})
	]
	unsupported_action_event.actions = [
		_make_action("AddVar", {"var_name": "health", "amount": "1"})
	]

	sheet.events = [unsupported_trigger_event, unsupported_condition_event, unsupported_action_event]

	var result: Dictionary = SheetCompiler.compile(sheet, UNSUPPORTED_OUTPUT_PATH)
	if not bool(result.get("success", false)):
		print("[FAIL] translation_matrix_slice_test: unsupported compile failed %s" % str(result.get("errors", [])))
		return false

	var warnings: Array[String] = result.get("warnings", []) as Array[String]
	var expected_warning_fragments: PackedStringArray = [
		"Unsupported trigger in first translation-matrix slice: Core::OnBodyEntered",
		"Unsupported condition in first translation-matrix slice: Core::HasGroupMember",
		"Unsupported action in first translation-matrix slice: Core::AddVar"
	]
	for warning_fragment: String in expected_warning_fragments:
		if not _contains_warning(warnings, warning_fragment):
			print("[FAIL] translation_matrix_slice_test: missing warning fragment '%s'" % warning_fragment)
			print("warnings: %s" % str(warnings))
			return false

	print("[PASS] translation_matrix_slice_test: unsupported warnings")
	return true

static func _make_condition(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params.duplicate(true)
	return condition

static func _make_action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params.duplicate(true)
	return action

static func _contains_warning(warnings: Array[String], warning_fragment: String) -> bool:
	for warning_line: String in warnings:
		if warning_line.contains(warning_fragment):
			return true
	return false
