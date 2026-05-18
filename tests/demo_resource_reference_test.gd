# EventForge — demo resource reference regression tests
@tool
extends RefCounted
class_name DemoResourceReferenceTest

const DEMO_SHEET_PATH := "res://demo/sheets/player.tres"
const FORBIDDEN_PATH_FRAGMENT := "res://../addons/"

static func run() -> bool:
	var passed: bool = true
	var source: String = FileAccess.get_file_as_string(DEMO_SHEET_PATH)
	passed = _check("demo sheet no longer serializes parent-directory addon paths", source.contains(FORBIDDEN_PATH_FRAGMENT), false) and passed

	var sheet: EventSheetResource = load(DEMO_SHEET_PATH) as EventSheetResource
	passed = _check("demo sheet loads as EventSheetResource", sheet is EventSheetResource, true) and passed
	passed = _check("demo sheet script resolves", sheet != null and sheet.get_script() != null, true) and passed
	if sheet != null:
		for index in range(sheet.events.size()):
			passed = _check_row_scripts(sheet.events[index], "demo row %d" % index) and passed
	return passed

static func _check_row_scripts(entry: Resource, label: String) -> bool:
	if entry == null:
		return _check("%s resource exists" % label, false, true)
	if entry is EventRow:
		var row: EventRow = entry as EventRow
		var passed: bool = _check("%s script resolves" % label, row.get_script() != null, true)
		for action_index in range(row.actions.size()):
			var action: ACEAction = row.actions[action_index] as ACEAction
			passed = _check("%s action %d script resolves" % [label, action_index], action != null and action.get_script() != null, true) and passed
		for condition_index in range(row.conditions.size()):
			var condition: ACECondition = row.conditions[condition_index] as ACECondition
			passed = _check("%s condition %d script resolves" % [label, condition_index], condition != null and condition.get_script() != null, true) and passed
		for child_index in range(row.sub_events.size()):
			passed = _check_row_scripts(row.sub_events[child_index], "%s sub-event %d" % [label, child_index]) and passed
		return passed
	if entry is EventGroup:
		var group: EventGroup = entry as EventGroup
		var group_passed: bool = _check("%s group script resolves" % label, group.get_script() != null, true)
		var children: Array[Resource] = group.events if not group.events.is_empty() else group.rows
		for child_index in range(children.size()):
			group_passed = _check_row_scripts(children[child_index], "%s child %d" % [label, child_index]) and group_passed
		return group_passed
	return _check("%s resource script resolves" % label, entry.get_script() != null, true)

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] demo_resource_reference_test: %s" % label)
		return true
	print("[FAIL] demo_resource_reference_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
