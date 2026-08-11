# Godot EventSheets - the 2D spatial pattern verbs (proximity, aiming, screen wrap, hover).
#
# Four Node2D ACEs that cover what a 2D game asks for constantly and that otherwise force a drop to
# GDScript: "is that thing close enough?", "aim at it over time", "come back on the other side of
# the screen", "float gently in place". This test pins the SHIPPED descriptors (the registry form,
# after the cross-node "On node" pass rewrites eligible templates) and compiles a real sheet so the
# exact emitted GDScript is nailed down, defaults and all.
#
# Two things worth knowing while reading:
#   - Wrap / Bob carry a {uid} token the DOCK bakes at apply time, so the test bakes it the same way
#     via ACEAction.codegen_template - an unbaked {uid} would not even parse.
#   - A bare EventRow with conditions and no trigger_id compiles to NOTHING, so the probe row rides
#     an OnProcess trigger (which is also where these per-frame verbs belong).
@tool
class_name SpatialPatternAcesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# --- Authored form: identity, category and host gate straight off the module ---
	var authored: Dictionary = {}
	for descriptor in EventForgeNodeACEs.get_descriptors():
		authored[descriptor.ace_id] = descriptor
	all_passed = _check("IsNodeWithinDistance registered", authored.has("IsNodeWithinDistance"), true) and all_passed
	all_passed = _check("TurnToward registered", authored.has("TurnToward"), true) and all_passed
	all_passed = _check("WrapInsideScreen registered", authored.has("WrapInsideScreen"), true) and all_passed
	all_passed = _check("BobUpAndDown registered", authored.has("BobUpAndDown"), true) and all_passed
	for ace_id: String in ["IsNodeWithinDistance", "TurnToward", "WrapInsideScreen", "BobUpAndDown"]:
		if not authored.has(ace_id):
			continue
		var spatial: ACEDescriptor = authored[ace_id]
		all_passed = _check("%s sits under Movement" % ace_id, str(spatial.category), "Movement") and all_passed
		all_passed = _check("%s is gated to Node2D hosts" % ace_id, str(spatial.node_type), "Node2D") and all_passed
	if authored.has("IsNodeWithinDistance"):
		var near: ACEDescriptor = authored["IsNodeWithinDistance"]
		all_passed = _check("proximity is a CONDITION", near.ace_type == ACEDescriptor.ACEType.CONDITION, true) and all_passed
		all_passed = _check("proximity asks for the other node + a distance", _param_ids(near), "other,distance") and all_passed
		all_passed = _check("proximity defaults to a node that always exists", str((near.params[0] as ACEParam).default_value), "get_parent()") and all_passed
		all_passed = _check("proximity reads in plain words", str(near.display_text), "is within {distance} px of {other}") and all_passed
	if authored.has("TurnToward"):
		var turn: ACEDescriptor = authored["TurnToward"]
		all_passed = _check("turning is an ACTION", turn.ace_type == ACEDescriptor.ACEType.ACTION, true) and all_passed
		all_passed = _check("turning asks for a target + a turn speed", _param_ids(turn), "target,degrees_per_second") and all_passed
		all_passed = _check("turning is frame-rate independent", str(turn.codegen_template).contains("get_process_delta_time()"), true) and all_passed
	if authored.has("WrapInsideScreen"):
		var wrap: ACEDescriptor = authored["WrapInsideScreen"]
		all_passed = _check("screen wrap needs no parameters", _param_ids(wrap), "") and all_passed
		all_passed = _check("screen wrap measures the viewport once into a per-row local", str(wrap.codegen_template).contains("var __wrap_size_{uid}: Vector2 = get_viewport_rect().size"), true) and all_passed
	if authored.has("BobUpAndDown"):
		var bob: ACEDescriptor = authored["BobUpAndDown"]
		all_passed = _check("bobbing asks for a height + a period", _param_ids(bob), "height,period") and all_passed
		all_passed = _check("bobbing remembers its resting height in node metadata", str(bob.codegen_template).contains("set_meta(&\"__bob_base_{uid}\", position.y)"), true) and all_passed

	# --- Shipped form: the cross-node pass rewrites ONLY the plain member-operation template ---
	# The proximity condition is a single member operation, so it earns an optional "On node" prefix
	# (measure from another node instead of this one). The other three lead with `rotation =` owning
	# its own target param, a `var`, or an `if`, so they ship exactly as authored - self-verbs.
	var shipped: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		shipped[descriptor.ace_id] = descriptor
	if shipped.has("IsNodeWithinDistance"):
		var shipped_near: ACEDescriptor = shipped["IsNodeWithinDistance"]
		all_passed = _check("proximity ships with the optional cross-node prefix",
			str(shipped_near.codegen_template), "{target.}global_position.distance_to({other}.global_position) <= maxf({distance}, 0.0)") and all_passed
		all_passed = _check("proximity gains the On node param last", _param_ids(shipped_near), "other,distance,target") and all_passed
	if shipped.has("WrapInsideScreen"):
		all_passed = _check("screen wrap ships untouched (a leading var is not prefixable)",
			str((shipped["WrapInsideScreen"] as ACEDescriptor).codegen_template).contains("{target.}"), false) and all_passed
	if shipped.has("BobUpAndDown"):
		all_passed = _check("bobbing ships untouched (a leading if is not prefixable)",
			str((shipped["BobUpAndDown"] as ACEDescriptor).codegen_template).contains("{target.}"), false) and all_passed
	if shipped.has("TurnToward"):
		all_passed = _check("turning keeps its own target param", _param_ids(shipped["TurnToward"] as ACEDescriptor), "target,degrees_per_second") and all_passed

	# --- The four verbs inside a real per-frame sheet: pin the exact emitted lines ---
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "SpatialPatternProbe"
	var row: EventRow = EventRow.new()
	row.trigger_id = "OnProcess"  # a row without a trigger compiles to nothing at all
	row.conditions.append(_condition("IsNodeWithinDistance", {"other": "get_parent()", "distance": "64.0"}))
	row.actions.append(_action(shipped, "TurnToward", {"target": "get_parent()", "degrees_per_second": "180.0"}, ""))
	row.actions.append(_action(shipped, "WrapInsideScreen", {}, "w1"))
	row.actions.append(_action(shipped, "BobUpAndDown", {"height": "6.0", "period": "2.0"}, "b1"))
	sheet.events.append(row)
	var output: String = str(SheetCompiler.compile(sheet, "user://spatial_pattern_probe.gd").get("output", ""))
	all_passed = _check("the proximity check emits the distance_to comparison, blank target dropped",
		output.contains("if global_position.distance_to(get_parent().global_position) <= maxf(64.0, 0.0):"), true) and all_passed
	all_passed = _check("turning emits rotate_toward with the angle to the target",
		output.contains("rotation = rotate_toward(rotation, (get_parent().global_position - global_position).angle(), deg_to_rad(maxf(180.0, 0.0)) * get_process_delta_time())"), true) and all_passed
	all_passed = _check("screen wrap emits its baked viewport local",
		output.contains("var __wrap_size_w1: Vector2 = get_viewport_rect().size"), true) and all_passed
	all_passed = _check("screen wrap emits the wrapf on both axes",
		output.contains("position = Vector2(wrapf(position.x, 0.0, __wrap_size_w1.x), wrapf(position.y, 0.0, __wrap_size_w1.y))"), true) and all_passed
	all_passed = _check("bobbing emits its first-run metadata guard",
		output.contains("if not has_meta(&\"__bob_base_b1\"):"), true) and all_passed
	all_passed = _check("bobbing emits the sine ride around the remembered base",
		output.contains("position.y = float(get_meta(&\"__bob_base_b1\")) + sin(Time.get_ticks_msec() / 1000.0 * TAU / maxf(2.0, 0.01)) * 6.0"), true) and all_passed
	all_passed = _check("no {uid} token survives into the emitted script", output.contains("{uid}"), false) and all_passed
	all_passed = _check("the compiled probe is valid GDScript", _parses(output), true) and all_passed

	return all_passed


static func _param_ids(descriptor: ACEDescriptor) -> String:
	var ids: PackedStringArray = PackedStringArray()
	for parameter: ACEParam in descriptor.params:
		ids.append(str(parameter.id))
	return ",".join(ids)


static func _parses(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload(true) == OK


static func _condition(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	return condition


## ACEAction on the SHIPPED template, baking {uid} into a per-row token exactly as the dock does at
## apply time. An empty uid leaves the registry template in charge (no {uid} to bake).
static func _action(shipped: Dictionary, ace_id: String, params: Dictionary, uid: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	if not uid.is_empty():
		action.codegen_template = str((shipped[ace_id] as ACEDescriptor).codegen_template).replace("{uid}", uid)
	return action


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] spatial_pattern_aces_test: %s" % label)
		return true
	print("[FAIL] spatial_pattern_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
