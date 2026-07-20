# EventForge - the Camera FOV + Animation control modules: node-scoped ACEs that compile to plain
# Camera3D / AnimationPlayer member operations, parse standalone against the real host classes, and
# gain the optional "On node" target from the builtin targetable pass.
@tool
class_name CameraAnimationAcesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("camera FOV ACEs registered",
		by_id.has("TweenCameraFov") and by_id.has("AdjustCameraFov") and by_id.has("GetCameraFov"), true) and all_passed
	all_passed = _check("animation ACEs registered",
		by_id.has("SetAnimationSpeed") and by_id.has("SeekAnimation") and by_id.has("QueueAnimation")
		and by_id.has("PauseAnimation") and by_id.has("HasAnimation")
		and by_id.has("AnimationPosition") and by_id.has("AnimationLength"), true) and all_passed
	all_passed = _check("Adjust/Get FOV are Camera3D-scoped", str((by_id["AdjustCameraFov"] as ACEDescriptor).node_type), "Camera3D") and all_passed
	all_passed = _check("animation ACEs are AnimationPlayer-scoped", str((by_id["SeekAnimation"] as ACEDescriptor).node_type), "AnimationPlayer") and all_passed
	# A clean member read (Camera FOV) gains the "On node" target; a self-referential assignment
	# (Adjust adds to fov it reads back) is correctly left OFF the targetable path.
	all_passed = _check("Camera FOV expression gains the On node target", _has_target_param(by_id["GetCameraFov"]), true) and all_passed
	all_passed = _check("Adjust Camera FOV is NOT retargetable (self-referential)", _has_target_param(by_id["AdjustCameraFov"]), false) and all_passed
	# The active-camera tween is NOT node-scoped (so it never mis-targets self's fov onto another camera).
	all_passed = _check("Tween Camera FOV is active-camera, not node-scoped", str((by_id["TweenCameraFov"] as ACEDescriptor).node_type), "") and all_passed

	# Each host-only template must be valid GDScript inside its real host class - substitute defaults
	# and compile a subclass so the member operations (fov, speed_scale, seek(), queue()...) resolve.
	all_passed = _check("Camera3D FOV templates parse in a Camera3D", _templates_parse_in("Camera3D",
		["AdjustCameraFov", "GetCameraFov"], by_id), true) and all_passed
	all_passed = _check("the active-camera FOV tween parses in a Node", _templates_parse_in("Node", ["TweenCameraFov"], by_id), true) and all_passed
	all_passed = _check("AnimationPlayer templates parse in an AnimationPlayer", _templates_parse_in("AnimationPlayer",
		["SetAnimationSpeed", "SeekAnimation", "QueueAnimation", "PauseAnimation", "SetAnimationTime", "HasAnimation", "AnimationPosition", "AnimationLength", "AnimationSpeed"], by_id), true) and all_passed

	return all_passed


## Compiles a subclass of `host_class` whose method body runs each ACE's template (defaults filled),
## so every member/method the templates name is resolved against the real engine class.
static func _templates_parse_in(host_class: String, ace_ids: Array, by_id: Dictionary) -> bool:
	var lines: PackedStringArray = PackedStringArray(["extends %s" % host_class, "func _probe() -> void:"])
	for ace_id: String in ace_ids:
		var descriptor: ACEDescriptor = by_id[ace_id]
		# The builtin targetable pass rewrites clean member ops to `{target.}member`; the blank-target
		# form (host-relative) is what compiles, so resolve the idiom to empty for the probe.
		var template: String = str(descriptor.codegen_template).replace("{target.}", "").replace("{uid}", "probe")
		for parameter: ACEParam in descriptor.params:
			template = template.replace("{%s}" % parameter.id, str(parameter.default_value) if str(parameter.default_value) != "" else "0")
		# Expressions are values (bind them); actions are statements (run them bare). Multi-line action
		# templates keep their own indentation - re-indent every line one tab into the probe method.
		if descriptor.ace_type == ACEDescriptor.ACEType.EXPRESSION or descriptor.ace_type == ACEDescriptor.ACEType.CONDITION:
			lines.append("\tvar __r_%s = %s" % [ace_id.to_snake_case(), template])
		else:
			for template_line: String in template.split("\n"):
				lines.append("\t%s" % template_line)
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(lines)
	return script.reload(true) == OK


static func _has_target_param(descriptor: ACEDescriptor) -> bool:
	for parameter: ACEParam in descriptor.params:
		if parameter.id == "target":
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] camera_animation_aces_test: %s" % label)
		return true
	print("[FAIL] camera_animation_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
