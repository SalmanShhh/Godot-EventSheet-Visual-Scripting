# Godot EventSheets — pack ACE node-target parameterization (the "On node" idiom).
#
# Behavior-pack ACEs authored as "$Pack.method(...)" gain a configurable node target so a sheet can
# point them at the behavior wherever it actually lives ($Player/WeaponKit, not only a direct child
# named after the pack). This pins _parameterize_node_target: a bare $Identifier prefix becomes a
# {target} param; a method whose own arg is literally "target" (e.g. spring_host_scale(target)) falls
# back to "on_node" so the node path and the method arg never collide; non-bare prefixes ($"Quoted",
# %Unique, multi-segment $A/B) stay verbatim; triggers are never targeted.
@tool
class_name NodeTargetTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# Plain bare prefix: $Foo.bar() -> {target}.bar(), with a "target" node param prepended.
	var d1: ACEDefinition = _def("$Foo.bar()", [])
	EventSheetACEGenerator._parameterize_node_target(d1)
	ok = _check("plain prefix -> {target}", str(d1.metadata.get("codegen_template", "")), "{target}.bar()") and ok
	ok = _check("plain prefix injects target param (default $Foo)",
		d1.parameters.size() == 1 and str(d1.parameters[0].get("id", "")) == "target" and str(d1.parameters[0].get("default_value", "")) == "$Foo", true) and ok

	# Collision: the method's own arg is named "target" -> fall back to "on_node", keep both distinct.
	var d2: ACEDefinition = _def("$SpringBehavior.spring_host_scale({target})", [{"id": "target", "type": TYPE_FLOAT, "default_value": "1.0"}])
	EventSheetACEGenerator._parameterize_node_target(d2)
	ok = _check("collision -> {on_node} prefix", str(d2.metadata.get("codegen_template", "")), "{on_node}.spring_host_scale({target})") and ok
	ok = _check("collision keeps node + method arg distinct",
		d2.parameters.size() == 2 and str(d2.parameters[0].get("id", "")) == "on_node" and str(d2.parameters[1].get("id", "")) == "target", true) and ok

	# Multi-segment path is already explicit -> untouched.
	var d3: ACEDefinition = _def("$Player/WeaponKit.fire()", [])
	EventSheetACEGenerator._parameterize_node_target(d3)
	ok = _check("multi-segment path untouched", str(d3.metadata.get("codegen_template", "")), "$Player/WeaponKit.fire()") and ok
	ok = _check("multi-segment path injects no param", d3.parameters.size(), 0) and ok

	# %Unique-name prefix -> untouched (does not begin with $).
	var d4: ACEDefinition = _def("%Weapon.reload()", [])
	EventSheetACEGenerator._parameterize_node_target(d4)
	ok = _check("unique-name prefix untouched", str(d4.metadata.get("codegen_template", "")), "%Weapon.reload()") and ok

	# Triggers are never node-targeted.
	var d5: ACEDefinition = _def("$Foo.bar()", [])
	d5.ace_type = ACEDefinition.ACEType.TRIGGER
	EventSheetACEGenerator._parameterize_node_target(d5)
	ok = _check("triggers untouched", str(d5.metadata.get("codegen_template", "")), "$Foo.bar()") and ok

	return ok


static func _def(template: String, params: Array) -> ACEDefinition:
	var d: ACEDefinition = ACEDefinition.new()
	d.ace_type = ACEDefinition.ACEType.ACTION
	d.metadata = {"codegen_template": template}
	d.parameters = params
	return d


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] node_target_test: %s" % label)
		return true
	print("[FAIL] node_target_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
