# Godot EventSheets - the @ace_expose_all(node) one-line opt-in for custom addons.
#
# A Node with the class-level marker and ZERO per-method annotations publishes every own public method
# as a NODE-TARGETED ACE: type inferred from the return type, and codegen synthesized as
# {target}.method(args) - parameterized with an "On node" target defaulting to $Provider - so a behavior
# needs no per-method @ace_codegen_template / @ace_condition / @ace_name. Private + inherited members
# stay out.
@tool
class_name ExposeAllNodeTest
extends RefCounted

const SAMPLE := preload("res://tests/fixtures/expose_all_node_sample.gd")


static func run() -> bool:
	var ok: bool = true
	var sample: Node = SAMPLE.new()
	var registry := EventSheetACERegistry.new()
	registry.refresh_from_sources([sample], true)
	var pid: String = "ExposeAllNodeSample"

	# Methods auto-publish + classify from the return type with zero annotations.
	var can_fire: ACEDefinition = registry.find_definition(pid, "method:can_fire")
	ok = _check("bool method -> CONDITION", can_fire.ace_type if can_fire != null else -1, ACEDefinition.ACEType.CONDITION) and ok
	var fire: ACEDefinition = registry.find_definition(pid, "method:fire")
	ok = _check("void method -> ACTION", fire.ace_type if fire != null else -1, ACEDefinition.ACEType.ACTION) and ok
	var ammo: ACEDefinition = registry.find_definition(pid, "method:ammo_count")
	ok = _check("value method -> EXPRESSION", ammo.ace_type if ammo != null else -1, ACEDefinition.ACEType.EXPRESSION) and ok

	# (node) mode: codegen is the node-targeted, parameterized form - NOT the instance-backed default.
	ok = _check("can_fire codegen is node-targeted", str(can_fire.metadata.get("codegen_template", "")) if can_fire != null else "", "{target}.can_fire()") and ok
	ok = _check("fire codegen is node-targeted", str(fire.metadata.get("codegen_template", "")) if fire != null else "", "{target}.fire()") and ok
	var set_rate: ACEDefinition = registry.find_definition(pid, "method:set_rate")
	ok = _check("method args flow into the synthesized codegen", str(set_rate.metadata.get("codegen_template", "")) if set_rate != null else "", "{target}.set_rate({rate})") and ok

	# The "On node" target param is prepended, defaulting to the conventional $Provider path.
	var targeted: bool = can_fire != null and can_fire.parameters.size() >= 1 and str(can_fire.parameters[0].get("id", "")) == "target" and str(can_fire.parameters[0].get("default_value", "")) == "$ExposeAllNodeSample"
	ok = _check("On node target prepended, default $Provider", targeted, true) and ok

	# Private + inherited members are not exposed.
	ok = _check("_-prefixed method excluded", registry.find_definition(pid, "method:_private_helper") == null, true) and ok
	ok = _check("inherited Node method excluded", registry.find_definition(pid, "method:queue_free") == null, true) and ok

	# Signal still becomes a trigger.
	var fired: ACEDefinition = registry.find_definition(pid, "signal:fired")
	ok = _check("signal -> TRIGGER", fired.ace_type if fired != null else -1, ACEDefinition.ACEType.TRIGGER) and ok

	sample.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] expose_all_node_test: %s" % label)
		return true
	print("[FAIL] expose_all_node_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
