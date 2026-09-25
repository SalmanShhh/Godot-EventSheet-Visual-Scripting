# EventForge - the Camera FOV + Animation control modules: node-scoped ACEs that compile to plain
# Camera3D / AnimationPlayer member operations and gain the optional "On node" target from the
# builtin targetable pass. That each template parses inside its real host class is
# builtin_ace_compile_test's job, which compiles every builtin with its defaults in its node_type.
@tool
class_name CameraAnimationAcesTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


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

	return all_passed


static func _has_target_param(descriptor: ACEDescriptor) -> bool:
	for parameter: ACEParam in descriptor.params:
		if parameter.id == "target":
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("camera_animation_aces_test", label, actual, expected)
