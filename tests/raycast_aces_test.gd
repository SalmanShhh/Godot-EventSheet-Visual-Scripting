# EventForge - the raycasting module ("Raycast 2D" / "Raycast 3D" / "Overlap 3D").
#
# Godot casts rays four ways (RayCast nodes, ShapeCast nodes, direct space-state queries, camera
# picking) and this pins that a sheet can reach all four in BOTH dimensions - the gap that used to
# make 3D the poor relation, with no point query, no volume query, and a one-off ray that could not
# say what it hit.
#
# The Dictionary keys asserted below ("position", "normal", "collider", "shape", "face_index") are
# not guesses: they were read back off a live intersect_ray against a real StaticBody in both
# dimensions. A wrong key here fails SILENTLY at runtime - .get() would just hand back the default
# forever - so they are pinned as values, and the compile gate proves the templates parse.
@tool
class_name RaycastAcesTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	var by_id: Dictionary = {}
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[d.ace_id] = d

	# --- Every cast flavour reaches both dimensions ---
	for aid: String in [
		"RayCast2DSetTarget", "RayCast2DSetMask", "RayCast2DAddException", "RayCast2DHitsGroup",
		"RayCast3DSetTarget", "RayCast3DSetMask", "RayCast3DAddException", "RayCast3DHitsGroup",
		"ShapeCast2DIsColliding", "ShapeCast2DCount", "ShapeCast2DSafeFraction",
		"ShapeCast3DIsColliding", "ShapeCast3DCount", "ShapeCast3DSafeFraction",
		"CastRayInto2D", "CastRayInto3D", "CastCircleMotion2D", "CastSphereMotion3D",
		"QueryBodiesUnderMouse2D", "QueryBodiesAtPoint3D", "QueryBodiesInSphere3D", "QueryBodiesInBox3D",
		"CastMouseRayInto3D", "MouseRayHits3D", "MouseRayCollider3D", "MouseRayPoint3D",
	]:
		ok = _check("%s registered" % aid, by_id.has(aid), true) and ok

	# The 3D one-off ray could previously report only hit/point - not WHAT it hit or which way the
	# surface faced, so 3D could not do a bounce or a "shot an enemy?" test without writing GDScript.
	ok = _check("the 3D one-off ray can name what it hit", by_id.has("WorldRaycastCollider3D"), true) and ok
	ok = _check("and which way that surface faces", by_id.has("WorldRaycastNormal3D"), true) and ok
	ok = _check("2D gained the normal it was missing too", by_id.has("WorldRaycastNormal2D"), true) and ok

	# --- Kinds match the condition/action model: a question is a CONDITION, an effect an ACTION ---
	ok = _check("ShapeCast Is Colliding is a condition",
		by_id["ShapeCast2DIsColliding"].ace_type, ACEDescriptor.ACEType.CONDITION) and ok
	ok = _check("Cast Ray Into is an action (it writes a variable)",
		by_id["CastRayInto3D"].ace_type, ACEDescriptor.ACEType.ACTION) and ok
	ok = _check("Ray Result Point is an expression",
		by_id["RayResultPoint3D"].ace_type, ACEDescriptor.ACEType.EXPRESSION) and ok
	ok = _check("Ray Result Hit Something is a condition",
		by_id["RayResultHit3D"].ace_type, ACEDescriptor.ACEType.CONDITION) and ok

	# --- The result readers use the keys Godot ACTUALLY returns (verified against a live cast) ---
	ok = _check("hit point reads \"position\", the key intersect_ray really uses",
		str(by_id["RayResultPoint3D"].codegen_template), "{result}.get(\"position\", Vector3.ZERO)") and ok
	ok = _check("hit normal reads \"normal\"",
		str(by_id["RayResultNormal2D"].codegen_template), "{result}.get(\"normal\", Vector2.ZERO)") and ok
	ok = _check("hit object reads \"collider\"",
		str(by_id["RayResultCollider2D"].codegen_template), "{result}.get(\"collider\", null)") and ok
	ok = _check("hit shape index reads \"shape\"",
		str(by_id["RayResultShape3D"].codegen_template), "{result}.get(\"shape\", -1)") and ok
	# face_index is 3D-only - a 2D intersect_ray result has no such key, so offering it there would lie.
	ok = _check("face index reads \"face_index\"",
		str(by_id["RayResultFaceIndex3D"].codegen_template), "{result}.get(\"face_index\", -1)") and ok
	ok = _check("and is offered for 3D only, since a 2D cast has no such key",
		by_id.has("RayResultFaceIndex2D"), false) and ok
	# The zero defaults are dimension-correct: a Vector2.ZERO default in a 3D row would not compile.
	ok = _check("the 2D point default is a Vector2",
		str(by_id["RayResultPoint2D"].codegen_template).contains("Vector2.ZERO"), true) and ok

	# A group test on a clear ray must not crash: nothing-hit is checked BEFORE the member call.
	ok = _check("the group test guards against nothing-hit first",
		str(by_id["RayResultInGroup3D"].codegen_template),
		"({result}.get(\"collider\", null) != null and {result}[\"collider\"].is_in_group({group}))") and ok
	ok = _check("so does the RayCast node's group test",
		str(by_id["RayCast2DHitsGroup"].codegen_template),
		"(is_colliding() and get_collider() != null and get_collider().is_in_group({group}))") and ok

	# --- Cast-once-then-read: the whole point of the Into variants ---
	var cast_3d: String = str(by_id["CastRayInto3D"].codegen_template)
	ok = _check("Cast Ray Into fires exactly one intersect_ray",
		cast_3d.count("intersect_ray"), 1) and ok
	ok = _check("it uses per-row unique locals so two casts in one event cannot collide",
		cast_3d.contains("__rq_{uid}"), true) and ok
	ok = _check("it stores the whole result, not one field",
		cast_3d.contains("{into} = get_world_3d().direct_space_state.intersect_ray(__rq_{uid})"), true) and ok
	ok = _check("the mouse pick projects the ray through the cursor",
		str(by_id["CastMouseRayInto3D"].codegen_template).contains("project_ray_normal(__mouse_{uid})"), true) and ok
	ok = _check("and reads the mouse position once, not per line",
		str(by_id["CastMouseRayInto3D"].codegen_template).count("get_mouse_position()"), 1) and ok

	# --- Areas are opt-in, because Godot ignores them by default (the classic "my ray misses the
	# trigger zone" trap). Every world query therefore exposes the switch. ---
	for aid: String in ["CastRayInto2D", "CastRayInto3D", "CastMouseRayInto3D", "QueryBodiesAtPoint3D", "QueryBodiesUnderMouse2D"]:
		ok = _check("%s lets a sheet opt into detecting areas" % aid,
			_has_param(by_id[aid], "hit_areas"), true) and ok

	# --- The exception verbs must pass a CollisionObject, not any Node: `self` on a RayCast2D is a
	# compile error, so a default of `self` would have shipped rows that cannot compile. ---
	ok = _check("the 2D exception default casts to CollisionObject2D",
		str(_param(by_id["RayCast2DAddException"], "node").default_value), "get_parent() as CollisionObject2D") and ok
	ok = _check("and the 3D one to CollisionObject3D",
		str(_param(by_id["RayCast3DAddException"], "node").default_value), "get_parent() as CollisionObject3D") and ok

	# --- cast_motion returns a PackedFloat32Array; reading [0] blind crashes on an empty result ---
	for aid: String in ["CastCircleMotion2D", "CastSphereMotion3D"]:
		ok = _check("%s falls back to a clear path instead of indexing an empty result" % aid,
			str(by_id[aid].codegen_template).contains("if __cm_{uid}.size() > 0 else 1.0"), true) and ok

	# --- House rules: every verb explains itself, and its category has a picker icon ---
	var undescribed: Array[String] = []
	var categories: Dictionary = {}
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if not (str(d.category) in ["Raycast 2D", "Raycast 3D", "Overlap 3D"]):
			continue
		categories[str(d.category)] = true
		if str(d.description).strip_edges().is_empty():
			undescribed.append(str(d.ace_id))
	ok = _check("every raycast verb carries a plain-language description", undescribed, [] as Array[String]) and ok
	ok = _check("the 3D overlap queries got their own category", categories.has("Overlap 3D"), true) and ok

	return ok


static func _param(descriptor: ACEDescriptor, param_id: String) -> ACEParam:
	for p: ACEParam in descriptor.params:
		if str(p.id) == param_id:
			return p
	return ACEParam.new()


static func _has_param(descriptor: ACEDescriptor, param_id: String) -> bool:
	for p: ACEParam in descriptor.params:
		if str(p.id) == param_id:
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] raycast_aces_test: %s" % label)
		return true
	print("[FAIL] raycast_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
