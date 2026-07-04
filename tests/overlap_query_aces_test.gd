# Godot EventSheets - 2D overlap queries (roadmap: "what is HERE right now", no Area2D).
#
# Three one-shot query actions collect overlapping physics objects into a variable:
# at a point, inside a circle, inside a rectangle. Results compose with the existing
# language - For Each picks over the array, Expression Is True gates on not-empty.
# The parse teeth compile a sheet using all three and GDScript.reload() the output.
@tool
class_name OverlapQueryACEsTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	var descriptors: Array[ACEDescriptor] = EventForgeBuiltinACEs.get_descriptors()
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in descriptors:
		by_id[descriptor.ace_id] = descriptor
	for ace_id: String in ["QueryBodiesAtPoint2D", "QueryBodiesInCircle2D", "QueryBodiesInRect2D"]:
		var descriptor: ACEDescriptor = by_id.get(ace_id)
		ok = _check("%s exists in the Overlap 2D category" % ace_id,
			descriptor != null and descriptor.category == "Overlap 2D", true) and ok
		if descriptor != null:
			ok = _check("%s stores into a variable_reference param" % ace_id,
				str((descriptor.params[0] as ACEParam).hint), "variable_reference") and ok

	# Parse teeth: a sheet using all three queries compiles to loadable GDScript.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables = {"hits": {"type": "Array", "default": [], "exported": false}}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var uid_counter: int = 0
	for ace_id: String in ["QueryBodiesAtPoint2D", "QueryBodiesInCircle2D", "QueryBodiesInRect2D"]:
		var descriptor: ACEDescriptor = by_id.get(ace_id)
		if descriptor == null:
			continue
		uid_counter += 1
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = ace_id
		action.codegen_template = descriptor.codegen_template.replace("{uid}", "t%d" % uid_counter)
		var params: Dictionary = {"into": "hits", "point": "Vector2(10, 20)", "center": "Vector2(0, 0)", "radius": "48.0", "size": "Vector2(96, 32)", "max_results": "16"}
		action.params = params
		event.actions.append(action)
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://overlap_query_test.gd").get("output", ""))
	ok = _check("the compiled sheet queries all three shapes",
		output.contains("intersect_point") and output.count("intersect_shape") == 2, true) and ok
	var parse: GDScript = GDScript.new()
	parse.source_code = output
	ok = _check("the compiled output is loadable GDScript", parse.reload() == OK, true) and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] overlap_query_aces_test: %s" % label)
		return true
	print("[FAIL] overlap_query_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
