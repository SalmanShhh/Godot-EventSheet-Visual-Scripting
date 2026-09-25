# EventForge - demo resource reference regression tests
@tool
class_name DemoResourceReferenceTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const DEMO_SHEET_PATH := "res://tests/fixtures/compiler_golden_sheet.tres"
const INVALID_PARENT_DIR_PATH := "res://../addons/"


static func run() -> bool:
	var source: String = FileAccess.get_file_as_string(DEMO_SHEET_PATH)
	return _check("demo sheet no longer serializes parent-directory addon paths", source.contains(INVALID_PARENT_DIR_PATH), false)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("demo_resource_reference_test", label, actual, expected)
