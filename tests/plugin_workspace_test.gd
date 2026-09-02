# EventForge - Plugin workspace behavior tests
@tool
class_name PluginWorkspaceTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


## Runs basic plugin helper checks for EventSheet workspace handling.
static func run() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var generic_resource: Resource = Resource.new()

	all_passed = _check(
		"handles EventSheetResource",
		EventForgePlugin.is_event_sheet_resource(sheet),
		true
	) and all_passed
	all_passed = _check(
		"rejects generic Resource",
		EventForgePlugin.is_event_sheet_resource(generic_resource),
		false
	) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("plugin_workspace_test", label, actual, expected)
