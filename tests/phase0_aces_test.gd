# Phase 0 quick-wins: 2D physics (raycast) vocabulary, loop-control ACEs, and compiled
# Pick-Filter conditions (iterator-scoped, AND/OR). Else/Else-If chaining is already
# covered by language_gaps_test; this adds the new authoring surfaces.
@tool
class_name Phase0ACEsTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ── Registry presence: loop control + 2D raycast vocabulary ──
	var ids: Dictionary = {}
	var node_types: Dictionary = {}
	var templates: Dictionary = {}
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		ids[d.ace_id] = true
		node_types[d.ace_id] = d.node_type
		templates[d.ace_id] = d.codegen_template
	all_passed = _check("loop Break ACE present", ids.has("LoopBreak"), true) and all_passed
	all_passed = _check("loop Continue ACE present", ids.has("LoopContinue"), true) and all_passed
	all_passed = _check("CurrentItem expression present", ids.has("CurrentItem"), true) and all_passed
	all_passed = _check("Break compiles to a bare keyword", str(templates.get("LoopBreak", "")), "break") and all_passed
	all_passed = _check("RayCast2D condition present", ids.has("RayCast2DIsColliding"), true) and all_passed
	all_passed = _check("RayCast2D scoped to RayCast2D node", str(node_types.get("RayCast2DIsColliding", "")), "RayCast2D") and all_passed
	all_passed = _check("World raycast hit present", ids.has("WorldRaycastHit2D"), true) and all_passed
	all_passed = _check("World raycast uses the 2D space-state query",
		str(templates.get("WorldRaycastHit2D", "")).contains("get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D"), true) and all_passed
	all_passed = _check("World raycast scoped to Node2D", str(node_types.get("WorldRaycastHit2D", "")), "Node2D") and all_passed

	# ── Pick-Filter structured conditions compile (iterator-scoped, AND-joined) ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables = {"score": {"type": "int", "default": 0, "exported": false}}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var pick: PickFilter = PickFilter.new()
	pick.collection_kind = PickFilter.CollectionKind.GROUP
	pick.collection_value = "enemies"
	pick.iterator_name = "enemy"
	# A node-typed condition (scoped to the picked instance) + a global one (left as-is).
	var on_floor: ACECondition = ACECondition.new()
	on_floor.provider_id = "Core"
	on_floor.ace_id = "IsOnFloor"  # node_type CharacterBody2D, template is_on_floor()
	var score_pos: ACECondition = ACECondition.new()
	score_pos.provider_id = "Core"
	score_pos.ace_id = "CompareVar"  # no node_type → stays unscoped
	score_pos.codegen_template = "{var_name} {op} {value}"
	score_pos.params = {"var_name": "score", "op": ">", "value": "0"}
	pick.filter_conditions.append(on_floor)
	pick.filter_conditions.append(score_pos)
	pick.filter_mode = 0  # AND
	event.pick_filters.append(pick)
	var act: ACEAction = ACEAction.new()
	act.provider_id = "Core"
	act.ace_id = "PrintLog"
	act.codegen_template = "print({m})"
	act.params = {"m": "enemy.name"}
	event.actions.append(act)
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_phase0_pf.gd").get("output", ""))
	all_passed = _check("filter condition scoped to the iterator", output.contains("enemy.is_on_floor()"), true) and all_passed
	all_passed = _check("global filter condition stays unscoped", output.contains("score > 0"), true) and all_passed
	all_passed = _check("filter conditions emit a guard + continue",
		output.contains("if not (") and output.contains("\tcontinue"), true) and all_passed
	all_passed = _check("AND joins the filter conditions", output.contains(") and ("), true) and all_passed
	pick.filter_mode = 1  # OR
	output = str(SheetCompiler.compile(sheet, "user://eventsheets_phase0_pf.gd").get("output", ""))
	all_passed = _check("OR joins the filter conditions", output.contains(") or ("), true) and all_passed

	# The compiled output must parse (parity / reload gate).
	var script: GDScript = GDScript.new()
	script.source_code = output
	all_passed = _check("compiled pick-filter sheet parses", script.reload() == OK, true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] phase0_aces_test: %s" % label)
		return true
	print("[FAIL] phase0_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
