@tool
extends SceneTree


func _init() -> void:
	var wanted: PackedStringArray = PackedStringArray([
		"CastRayInto2D", "RayResultHit2D", "RayResultCollider2D", "RayResultPoint2D",
		"RayResultNormal2D", "RayResultInGroup2D", "RayResultShape2D",
		"RayCast2DSetTarget", "RayCast2DForceUpdate", "RayCast2DIsColliding",
		"RayCast2DGetPoint", "RayCast2DGetNormal", "RayCast2DHitsGroup",
		"RayCast2DSetMask", "RayCast2DAddException", "RayCast2DSetEnabled",
		"ShapeCast2DIsColliding", "ShapeCast2DForceUpdate", "ShapeCast2DSetTarget",
		"ShapeCast2DCount", "ShapeCast2DColliderAt", "ShapeCast2DSafeFraction",
		"QueryBodiesUnderMouse2D", "QueryBodiesInCircle2D", "CastCircleMotion2D"
	])
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if not wanted.has(descriptor.ace_id):
			continue
		var param_ids: PackedStringArray = PackedStringArray()
		for p: ACEParam in descriptor.params:
			param_ids.append("%s=%s" % [p.id, str(p.default_value)])
		print("### ", descriptor.ace_id, " | type=", descriptor.ace_type, " | node_type=", descriptor.node_type)
		print("    TEMPLATE<<", descriptor.codegen_template.replace("\n", "\n").replace("\t", "\t"), ">>")
		print("    PARAMS<<", ", ".join(param_ids), ">>")
	quit(0)
