# EventForge - ACE metadata normalization tests
@tool
class_name ACEMetadataTest
extends RefCounted


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

	# node_type field is propagated from dict using snake_case and camelCase keys.
	var node_type_descriptor: ACEDescriptor = ACERegistry.normalize_descriptor({
		"providerId": "MyPlugin",
		"aceId": "MoveAndSlide",
		"type": "action",
		"listName": "Move and slide",
		"node_type": "CharacterBody2D",
		"category": "Physics",
		"params": []
	})
	all_passed = _check("node_type from snake_case key", node_type_descriptor.node_type, "CharacterBody2D") and all_passed
	all_passed = _check("nodeType alias synced from node_type", node_type_descriptor.nodeType, "CharacterBody2D") and all_passed

	var node_type_camel_descriptor: ACEDescriptor = ACERegistry.normalize_descriptor({
		"aceId": "OverlapBody",
		"type": "condition",
		"listName": "Overlaps body",
		"nodeType": "Area2D",
		"params": []
	})
	all_passed = _check("node_type from camelCase nodeType key", node_type_camel_descriptor.node_type, "Area2D") and all_passed

	# Built-in ACEs: IsOnFloor is tagged as CharacterBody2D.
	var is_on_floor: ACEDescriptor = ACERegistry.find_descriptor("Core", "IsOnFloor")
	all_passed = _check("IsOnFloor registered", is_on_floor != null, true) and all_passed
	if is_on_floor != null:
		all_passed = _check("IsOnFloor node_type", is_on_floor.node_type, "CharacterBody2D") and all_passed

	# Built-in ACEs: OnBodyEntered is tagged as Area2D.
	var on_body_entered: ACEDescriptor = ACERegistry.find_descriptor("Core", "OnBodyEntered")
	all_passed = _check("OnBodyEntered registered", on_body_entered != null, true) and all_passed
	if on_body_entered != null:
		all_passed = _check("OnBodyEntered node_type", on_body_entered.node_type, "Area2D") and all_passed

	# Core ACEs without a specific node type have empty node_type.
	var set_var: ACEDescriptor = ACERegistry.find_descriptor("Core", "SetVar")
	all_passed = _check("SetVar registered", set_var != null, true) and all_passed
	if set_var != null:
		all_passed = _check("SetVar node_type is empty", set_var.node_type, "") and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ace_metadata_test: %s" % label)
		return true
	print("[FAIL] ace_metadata_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
