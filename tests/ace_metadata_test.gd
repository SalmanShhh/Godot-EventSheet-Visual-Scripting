# EventForge — ACE metadata normalization tests
@tool
extends RefCounted
class_name ACEMetadataTest

## Runs ACE metadata normalization checks.
static func run() -> bool:
	var all_passed: bool = true

	var normalized: ACEDescriptor = ACERegistry.normalize_descriptor({
		"providerId": "CustomPlatformer",
		"aceId": "SetVariableJumpHeight",
		"type": "action",
		"listName": "Set variable jump height",
		"displayText": "Set variable jump height to {0}",
		"description": "Tap for a short hop, hold for a full jump. Disable for a fixed jump height every time.",
		"category": "Custom ACEs",
		"params": [
			{
				"id": "enabled",
				"name": "Enabled",
				"desc": "Whether variable jump height is active.",
				"type": "boolean",
				"initialValue": "true",
				"hint": "variable_reference",
				"options": ["A", "B"]
			}
		]
	})

	all_passed = _check("normalize descriptor exists", normalized != null, true) and all_passed
	all_passed = _check("listName alias", normalized.get_list_name(), "Set variable jump height") and all_passed
	all_passed = _check("displayText alias", normalized.get_display_text(), "Set variable jump height to {0}") and all_passed
	all_passed = _check("description alias", normalized.description, "Tap for a short hop, hold for a full jump. Disable for a fixed jump height every time.") and all_passed
	all_passed = _check("param count", normalized.params.size(), 1) and all_passed
	all_passed = _check("param desc alias", normalized.params[0].description, "Whether variable jump height is active.") and all_passed
	all_passed = _check("param initialValue alias", str(normalized.params[0].get_initial_value()), "true") and all_passed
	all_passed = _check("param hint preserved", normalized.params[0].hint, "variable_reference") and all_passed
	all_passed = _check("param options preserved", normalized.params[0].options.size(), 2) and all_passed
	all_passed = _check("default params generated", str(normalized.build_default_params().get("enabled", "")), "true") and all_passed
	all_passed = _check("display template render", normalized.format_display(normalized.build_default_params()), "Set variable jump height to true") and all_passed

	var always_descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "Always")
	all_passed = _check("core Always condition registered", always_descriptor != null, true) and all_passed
	if always_descriptor != null:
		all_passed = _check("core Always codegen", always_descriptor.codegen_template, "true") and all_passed

	var compare_value_descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "CompareValue")
	all_passed = _check("core CompareValue condition registered", compare_value_descriptor != null, true) and all_passed
	if compare_value_descriptor != null:
		all_passed = _check("compare value list name", compare_value_descriptor.get_list_name(), "Compare Value") and all_passed
		all_passed = _check("compare value display text", compare_value_descriptor.get_display_text(), "{left} {op} {right}") and all_passed
		all_passed = _check("compare value operator options", compare_value_descriptor.params[1].options.size(), 6) and all_passed

	var practical_ids: Array[String] = [
		"CompareVar",
		"HasGroupMember",
		"IsOnFloor",
		"SetVar",
		"PrintLog",
		"QueueFree",
		"EmitSignal"
	]
	for ace_id: String in practical_ids:
		all_passed = _check("core practical ACE exists: %s" % ace_id, ACERegistry.find_descriptor("Core", ace_id) != null, true) and all_passed

	var invalid_custom: ACEDescriptor = ACERegistry.normalize_descriptor({
		"providerId": "CustomPlatformer",
		"aceId": "MissingInitial",
		"type": "action",
		"listName": "Missing Initial",
		"displayText": "Missing Initial",
		"params": [
			{"id": "amount", "name": "amount", "type": "int"}
		]
	})
	all_passed = _check("custom ACE without initial/default is rejected", invalid_custom == null, true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ace_metadata_test: %s" % label)
		return true
	print("[FAIL] ace_metadata_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
