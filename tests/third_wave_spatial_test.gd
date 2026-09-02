# Godot EventSheets - the second set of 2D spatial verbs (knockback, vacuum pickup, orbit).
#
# Four more Node2D ACEs for things a 2D game asks for constantly and that otherwise force a drop to
# GDScript: "shove that thing away from the blast", "spend the shove over time", "suck every coin in
# range toward me", "circle around that node". This test pins the SHIPPED descriptors (the registry
# form, after the cross-node "On node" pass rewrites eligible templates) and compiles a real sheet so
# the exact emitted GDScript is nailed down, defaults and all.
#
# Two things worth knowing while reading:
#   - Apply Pushes / Pull Group Toward / Orbit Around carry a {uid} token the DOCK bakes at apply
#     time, so the test bakes it the same way via ACEAction.codegen_template - an unbaked {uid} would
#     not even parse.
#   - A bare EventRow with no trigger_id compiles to NOTHING, so the probe row rides an OnProcess
#     trigger (which is also where these per-frame verbs belong).
@tool
class_name ThirdWaveSpatialTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var all_passed: bool = true

	# --- Authored form: identity, category and host gate straight off the module ---
	var authored: Dictionary = {}
	for descriptor in EventForgeNodeACEs.get_descriptors():
		authored[descriptor.ace_id] = descriptor
	all_passed = _check("PushAwayFrom registered", authored.has("PushAwayFrom"), true) and all_passed
	all_passed = _check("ApplyPushes registered", authored.has("ApplyPushes"), true) and all_passed
	all_passed = _check("PullGroupToward registered", authored.has("PullGroupToward"), true) and all_passed
	all_passed = _check("OrbitAround registered", authored.has("OrbitAround"), true) and all_passed
	for ace_id: String in ["PushAwayFrom", "ApplyPushes", "PullGroupToward", "OrbitAround"]:
		if not authored.has(ace_id):
			continue
		var spatial: ACEDescriptor = authored[ace_id]
		all_passed = _check("%s is an ACTION" % ace_id, spatial.ace_type == ACEDescriptor.ACEType.ACTION, true) and all_passed
		all_passed = _check("%s sits under Movement" % ace_id, str(spatial.category), "Movement") and all_passed
		all_passed = _check("%s is gated to Node2D hosts" % ace_id, str(spatial.node_type), "Node2D") and all_passed
	if authored.has("PushAwayFrom"):
		var push: ACEDescriptor = authored["PushAwayFrom"]
		all_passed = _check("the push asks what to flee and how hard", _param_ids(push), "source,strength") and all_passed
		all_passed = _check("the push defaults to a node that always exists", str((push.params[0] as ACEParam).default_value), "get_parent()") and all_passed
		all_passed = _check("the push stores an impulse rather than moving", str(push.codegen_template).contains("set_meta(&\"__ef_push\""), true) and all_passed
		all_passed = _check("the push reads in plain words", str(push.display_text), "push away from {source} with strength {strength}") and all_passed
	if authored.has("ApplyPushes"):
		var apply: ACEDescriptor = authored["ApplyPushes"]
		all_passed = _check("applying pushes asks only for friction", _param_ids(apply), "friction") and all_passed
		all_passed = _check("applying pushes decays frame-rate independently", str(apply.codegen_template).contains("exp(-maxf({friction}, 0.0) * get_process_delta_time())"), true) and all_passed
		all_passed = _check("applying pushes reads the impulse the push half left", str(apply.codegen_template).contains("get_meta(&\"__ef_push\", Vector2.ZERO)"), true) and all_passed
	if authored.has("PullGroupToward"):
		var pull: ACEDescriptor = authored["PullGroupToward"]
		all_passed = _check("the pull asks for a group, a range and a speed", _param_ids(pull), "group,radius,speed") and all_passed
		all_passed = _check("the pull offers the live group picker", str((pull.params[0] as ACEParam).hint), "group_reference") and all_passed
		all_passed = _check("the pull skips non-2D members instead of crashing", str(pull.codegen_template).contains("if __pull_{uid} is Node2D and"), true) and all_passed
	if authored.has("OrbitAround"):
		var orbit: ACEDescriptor = authored["OrbitAround"]
		all_passed = _check("orbiting asks for a center, a radius and a speed", _param_ids(orbit), "center,radius,degrees_per_second") and all_passed
		all_passed = _check("orbiting remembers its angle in node metadata", str(orbit.codegen_template).contains("set_meta(&\"__orbit_{uid}\", __orbit_{uid})"), true) and all_passed
		all_passed = _check("orbiting reads in plain words", str(orbit.display_text), "orbit around {center} at radius {radius}, {degrees_per_second} deg/s") and all_passed

	# --- Shipped form: the cross-node pass rewrites ONLY the plain member-operation template ---
	# The push is a single member call (set_meta), so it earns an optional "On node" prefix - shove a
	# different node away from the blast. The other three lead with a `var` or a `for`, so they ship
	# exactly as authored - self-verbs.
	var shipped: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		shipped[descriptor.ace_id] = descriptor
	if shipped.has("PushAwayFrom"):
		var shipped_push: ACEDescriptor = shipped["PushAwayFrom"]
		all_passed = _check("the push ships with the optional cross-node prefix",
			str(shipped_push.codegen_template), "{target.}set_meta(&\"__ef_push\", (global_position - {source}.global_position).normalized() * maxf({strength}, 0.0))") and all_passed
		all_passed = _check("the push gains the On node param last", _param_ids(shipped_push), "source,strength,target") and all_passed
	if shipped.has("ApplyPushes"):
		all_passed = _check("applying pushes ships untouched (a leading var is not prefixable)",
			str((shipped["ApplyPushes"] as ACEDescriptor).codegen_template).contains("{target.}"), false) and all_passed
		all_passed = _check("applying pushes keeps its single param", _param_ids(shipped["ApplyPushes"] as ACEDescriptor), "friction") and all_passed
	if shipped.has("PullGroupToward"):
		all_passed = _check("the pull ships untouched (a leading for is not prefixable)",
			str((shipped["PullGroupToward"] as ACEDescriptor).codegen_template).contains("{target.}"), false) and all_passed
		all_passed = _check("the pull keeps its three params", _param_ids(shipped["PullGroupToward"] as ACEDescriptor), "group,radius,speed") and all_passed
	if shipped.has("OrbitAround"):
		all_passed = _check("orbiting ships untouched (a leading var is not prefixable)",
			str((shipped["OrbitAround"] as ACEDescriptor).codegen_template).contains("{target.}"), false) and all_passed
		all_passed = _check("orbiting keeps its three params", _param_ids(shipped["OrbitAround"] as ACEDescriptor), "center,radius,degrees_per_second") and all_passed

	# --- The four verbs inside a real per-frame sheet: pin the exact emitted lines ---
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "ThirdWaveSpatialProbe"
	var row: EventRow = EventRow.new()
	row.trigger_id = "OnProcess"  # a row without a trigger compiles to nothing at all
	row.actions.append(_action(shipped, "PushAwayFrom", {"source": "get_parent()", "strength": "300.0"}, ""))
	row.actions.append(_action(shipped, "ApplyPushes", {"friction": "8.0"}, "p1"))
	row.actions.append(_action(shipped, "PullGroupToward", {"group": "\"coins\"", "radius": "96.0", "speed": "400.0"}, "g1"))
	row.actions.append(_action(shipped, "OrbitAround", {"center": "get_parent()", "radius": "40.0", "degrees_per_second": "90.0"}, "o1"))
	sheet.events.append(row)
	var output: String = str(SheetCompiler.compile(sheet, "user://third_wave_spatial_probe.gd").get("output", ""))
	all_passed = _check("the push emits the normalized impulse, blank target dropped",
		output.contains("set_meta(&\"__ef_push\", (global_position - get_parent().global_position).normalized() * maxf(300.0, 0.0))"), true) and all_passed
	all_passed = _check("applying pushes emits its baked impulse local",
		output.contains("var __push_p1: Vector2 = get_meta(&\"__ef_push\", Vector2.ZERO)"), true) and all_passed
	all_passed = _check("applying pushes emits the move and the exponential decay",
		output.contains("\t\tset_meta(&\"__ef_push\", __push_p1 * exp(-maxf(8.0, 0.0) * get_process_delta_time()))"), true) and all_passed
	all_passed = _check("the pull emits its baked loop over the group",
		output.contains("for __pull_g1: Node in get_tree().get_nodes_in_group(\"coins\"):"), true) and all_passed
	all_passed = _check("the pull emits the move_toward inside the range test",
		output.contains("\t\t\t(__pull_g1 as Node2D).global_position = (__pull_g1 as Node2D).global_position.move_toward(global_position, maxf(400.0, 0.0) * get_process_delta_time())"), true) and all_passed
	all_passed = _check("orbiting emits its baked angle local and metadata write",
		output.contains("var __orbit_o1: float = float(get_meta(&\"__orbit_o1\", 0.0)) + deg_to_rad(90.0) * get_process_delta_time()"), true) and all_passed
	all_passed = _check("orbiting emits the ring position around the center node",
		output.contains("global_position = get_parent().global_position + Vector2(cos(__orbit_o1), sin(__orbit_o1)) * maxf(40.0, 0.0)"), true) and all_passed
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
	return SUPPORT.check("third_wave_spatial_test", label, actual, expected)
