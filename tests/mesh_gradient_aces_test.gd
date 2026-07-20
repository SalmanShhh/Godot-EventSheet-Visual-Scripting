# EventForge - the Mesh + Gradient/Curve modules: primitive mesh builders compile to valid
# MeshInstance3D operations, the gradient builder + samplers compile to valid Gradient/Curve calls,
# and the Gradient variable type emits a native resource export (Godot's inspector editor).
@tool
class_name MeshGradientAcesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("mesh builders registered",
		by_id.has("SetBoxMesh") and by_id.has("SetSphereMesh") and by_id.has("SetCylinderMesh")
		and by_id.has("SetPlaneMesh") and by_id.has("SetCapsuleMesh") and by_id.has("SetPrismMesh")
		and by_id.has("SetTorusMesh") and by_id.has("SetMeshMaterial") and by_id.has("HasMesh")
		and by_id.has("MeshSurfaceCount") and by_id.has("MeshSize"), true) and all_passed
	all_passed = _check("gradient/curve ACEs registered",
		by_id.has("MakeGradient") and by_id.has("SampleGradient") and by_id.has("SampleCurve"), true) and all_passed
	all_passed = _check("mesh builders are MeshInstance3D-scoped", str((by_id["SetBoxMesh"] as ACEDescriptor).node_type), "MeshInstance3D") and all_passed

	# Every mesh template must be valid GDScript inside a MeshInstance3D (the primitive classes,
	# their properties, and get_aabb() all resolve).
	all_passed = _check("mesh templates parse in a MeshInstance3D", _templates_parse_in("MeshInstance3D",
		["SetBoxMesh", "SetSphereMesh", "SetCylinderMesh", "SetPlaneMesh", "SetCapsuleMesh", "SetPrismMesh", "SetTorusMesh", "SetMeshMaterial", "ClearMesh", "HasMesh", "MeshSurfaceCount", "MeshSize"], by_id), true) and all_passed
	# The gradient builder + samplers parse (Gradient.set_color, Gradient.sample, Curve.sample_baked).
	all_passed = _check("gradient/curve templates parse", _templates_parse_in("Node",
		["MakeGradient", "SampleGradient", "SampleCurve"], by_id), true) and all_passed

	# The gradient builder actually produces the sampled colour it promises (runtime, not just parse).
	var builder: GDScript = GDScript.new()
	builder.source_code = "@tool\nextends RefCounted\nstatic func build() -> Color:\n\tvar g := Gradient.new()\n\tg.set_color(0, Color.RED)\n\tg.set_color(1, Color.BLUE)\n\treturn g.sample(0.5)\n"
	all_passed = _check("gradient builder compiles + samples", builder.reload(true) == OK, true) and all_passed
	if builder.reload(true) == OK:
		var mid: Color = builder.build()
		all_passed = _check("a red->blue gradient samples purple at the middle", mid.is_equal_approx(Color.RED.lerp(Color.BLUE, 0.5)), true) and all_passed

	# The Gradient variable type emits a native resource export (so the Inspector shows its editor).
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.variables = {"ramp": {"type": "Gradient", "default": null, "exported": true}, "falloff": {"type": "Curve", "default": null, "exported": true}}
	var output: String = str(SheetCompiler.compile(sheet, "user://mesh_grad.gd").get("output", ""))
	all_passed = _check("Gradient variable exports as a native resource", output.contains("@export var ramp: Gradient = null"), true) and all_passed
	all_passed = _check("Curve variable exports as a native resource", output.contains("@export var falloff: Curve = null"), true) and all_passed
	all_passed = _check("Gradient is an authorable variable type", "Gradient" in VariableDialog.TYPE_OPTIONS, true) and all_passed

	return all_passed


static func _templates_parse_in(host_class: String, ace_ids: Array, by_id: Dictionary) -> bool:
	var lines: PackedStringArray = PackedStringArray(["extends %s" % host_class, "func _probe() -> void:"])
	var declared: Dictionary = {}
	for ace_id: String in ace_ids:
		var descriptor: ACEDescriptor = by_id[ace_id]
		# A unique per-ACE uid so multi-line builders that each declare a local (var __mesh_<uid>)
		# don't collide when several run in the one probe function.
		var template: String = str(descriptor.codegen_template).replace("{target.}", "").replace("{uid}", ace_id.to_snake_case())
		for parameter: ACEParam in descriptor.params:
			var fill: String = str(parameter.default_value) if str(parameter.default_value) != "" else "0"
			# variable_reference params name a local we declare once so the assignment resolves.
			if str(parameter.hint).begins_with("variable_reference") and not declared.has(str(parameter.default_value)):
				lines.append("\tvar %s = null" % str(parameter.default_value))
				declared[str(parameter.default_value)] = true
			template = template.replace("{%s}" % parameter.id, fill)
		if descriptor.ace_type == ACEDescriptor.ACEType.EXPRESSION or descriptor.ace_type == ACEDescriptor.ACEType.CONDITION:
			lines.append("\tvar __r_%s = %s" % [ace_id.to_snake_case(), template])
		else:
			for template_line: String in template.split("\n"):
				lines.append("\t%s" % template_line)
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(lines)
	return script.reload(true) == OK


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] mesh_gradient_aces_test: %s" % label)
		return true
	print("[FAIL] mesh_gradient_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
