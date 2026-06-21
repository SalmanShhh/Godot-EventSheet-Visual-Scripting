# Godot EventSheets — Nearest/Furthest picking expressions + the Line-of-Sight "Nearest Visible".
#
# Feature: auto-attack / targeting primitives. Two project-level expressions (NearestInGroup /
# FurthestInGroup) pick the closest/farthest node in a group by distance to the calling node, via the
# reduce() idiom (Godot 4 Array has NO min_by/max_by). The LoS packs gain a "Nearest Visible In Group"
# that additionally requires an unobstructed raycast — the occlusion-correct single pick.
@tool
extends RefCounted
class_name NearestPickingTest

const LOS_PACK := "res://eventsheet_addons/line_of_sight/line_of_sight_behavior.gd"
const LOS3D_PACK := "res://eventsheet_addons/line_of_sight_3d/line_of_sight_3d_behavior.gd"

static func run() -> bool:
	var all_passed: bool = true

	# --- Registration: the two project-level picking expressions in the Nodes: Picking row ---
	var by_id: Dictionary = {}
	for descriptor in EventForgeNodeACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("Nearest + Furthest In Group registered", by_id.has("NearestInGroup") and by_id.has("FurthestInGroup"), true) and all_passed
	if by_id.has("NearestInGroup"):
		var d: ACEDescriptor = by_id["NearestInGroup"]
		all_passed = _check("Nearest is an EXPRESSION under Nodes: Picking", d.ace_type == ACEDescriptor.ACEType.EXPRESSION and str(d.category) == "Nodes: Picking", true) and all_passed
		all_passed = _check("Nearest takes one 'group' param", d.params.size() == 1 and str((d.params[0] as ACEParam).id) == "group", true) and all_passed
		all_passed = _check("Nearest uses reduce + distance_to (never the nonexistent min_by)", str(d.codegen_template).contains("reduce(") and str(d.codegen_template).contains("global_position.distance_to") and not str(d.codegen_template).contains("min_by"), true) and all_passed
		all_passed = _check("Nearest compares with <", str(d.codegen_template).contains("< global_position.distance_to"), true) and all_passed
	if by_id.has("FurthestInGroup"):
		all_passed = _check("Furthest compares with >", str((by_id["FurthestInGroup"] as ACEDescriptor).codegen_template).contains("> global_position.distance_to"), true) and all_passed

	# --- Logic: the exact reduce algorithm picks the right node, and an empty group yields null ---
	var ref: Node2D = Node2D.new()
	ref.position = Vector2.ZERO
	var near_node: Node2D = Node2D.new(); near_node.position = Vector2(-5, 0)
	var mid_node: Node2D = Node2D.new(); mid_node.position = Vector2(10, 0)
	var far_node: Node2D = Node2D.new(); far_node.position = Vector2(50, 0)
	var nodes: Array = [mid_node, far_node, near_node]
	var nearest: Variant = nodes.reduce(func(__acc, __n): return __n if __acc == null or ref.global_position.distance_to(__n.global_position) < ref.global_position.distance_to(__acc.global_position) else __acc, null)
	all_passed = _check("nearest picks the closest node", nearest == near_node, true) and all_passed
	var furthest: Variant = nodes.reduce(func(__acc, __n): return __n if __acc == null or ref.global_position.distance_to(__n.global_position) > ref.global_position.distance_to(__acc.global_position) else __acc, null)
	all_passed = _check("furthest picks the farthest node", furthest == far_node, true) and all_passed
	var empty_nodes: Array = []
	var none: Variant = empty_nodes.reduce(func(__acc, __n): return __n if __acc == null or ref.global_position.distance_to(__n.global_position) < ref.global_position.distance_to(__acc.global_position) else __acc, null)
	all_passed = _check("empty group reduces to null", none == null, true) and all_passed
	ref.free(); near_node.free(); mid_node.free(); far_node.free()

	# --- LoS packs: the occlusion-correct "Nearest Visible In Group" compiles + exists (2D + 3D) ---
	var los2d: GDScript = load(LOS_PACK)
	all_passed = _check("LoS 2D pack loads", los2d != null, true) and all_passed
	if los2d != null:
		var b2d: Node = los2d.new()
		all_passed = _check("LoS 2D exposes Nearest Visible In Group", b2d.has_method("nearest_visible_in_group"), true) and all_passed
		b2d.free()
	var los3d: GDScript = load(LOS3D_PACK)
	all_passed = _check("LoS 3D pack loads", los3d != null, true) and all_passed
	if los3d != null:
		var b3d: Node = los3d.new()
		all_passed = _check("LoS 3D exposes Nearest Visible In Group", b3d.has_method("nearest_visible_in_group"), true) and all_passed
		b3d.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] nearest_picking_test: %s" % label)
		return true
	print("[FAIL] nearest_picking_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
