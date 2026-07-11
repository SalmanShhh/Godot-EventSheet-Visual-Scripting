# Godot EventSheets - Juice 3D pack (camera shake / recoil / bob / jitter / lean / FOV).
#
# Loads the COMPILED pack and drives the effect integrators directly. Headless there is no
# viewport camera, which is exactly the path to prove SAFE: every effect's STATE still advances
# (trauma decays, recoil re-centres, the FOV kick recovers) while the camera apply no-ops. The
# additive apply/unapply itself is pinned against a real Camera3D node.
@tool
class_name Juice3DPackTest
extends RefCounted

const PACK := "res://eventsheet_addons/juice_3d/juice_3d_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("juice 3d pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var behavior: Node = script.new()
	# Shake accrues trauma and decays back to rest with no camera present.
	behavior.shake(0.6)
	all_passed = _check("shake starts a shake", behavior.is_shaking(), true) and all_passed
	all_passed = _check("trauma reflects the shake strength", is_equal_approx(behavior.current_trauma(), 0.6), true) and all_passed
	behavior.shake(2.0)
	all_passed = _check("trauma clamps to 1.0", behavior.current_trauma() <= 1.0, true) and all_passed
	for _i in 200:
		behavior._process(0.1)
		if not behavior.is_shaking():
			break
	all_passed = _check("shake decays back to rest without a camera", behavior.is_shaking(), false) and all_passed
	behavior.shake(0.5)
	behavior.stop_shake()
	all_passed = _check("stop_shake clears the shake", behavior.is_shaking(), false) and all_passed

	# Recoil kicks accumulate and re-centre at the recovery rate.
	behavior.set("recoil_recovery", 30.0)
	behavior.recoil(1.5, 0.0)
	behavior.recoil(1.5, 0.0)
	all_passed = _check("recoil kicks stack", is_equal_approx(float(behavior.get("_recoil_pitch")), 3.0), true) and all_passed
	behavior._process(0.05)
	all_passed = _check("recoil re-centres at the recovery rate", is_equal_approx(float(behavior.get("_recoil_pitch")), 3.0 - 30.0 * 0.05), true) and all_passed
	for _j in 200:
		behavior._process(0.1)
	all_passed = _check("recoil settles fully", is_equal_approx(float(behavior.get("_recoil_pitch")), 0.0), true) and all_passed

	# FOV punch recovers on its own; bob and jitter are simple toggles.
	behavior.fov_punch(8.0)
	all_passed = _check("fov punch kicks", is_equal_approx(float(behavior.get("_fov_kick")), 8.0), true) and all_passed
	for _k in 200:
		behavior._process(0.1)
	all_passed = _check("fov punch recovers to zero", is_equal_approx(float(behavior.get("_fov_kick")), 0.0), true) and all_passed
	behavior.start_head_bob(0.06, 2.0)
	all_passed = _check("head bob starts", bool(behavior.get("_bob_active")), true) and all_passed
	behavior.stop_head_bob()
	all_passed = _check("head bob stops", bool(behavior.get("_bob_active")), false) and all_passed
	behavior.start_jitter(0.02, 0.5)
	all_passed = _check("jitter starts", bool(behavior.get("_jitter_active")), true) and all_passed
	behavior.stop_jitter()
	all_passed = _check("jitter stops", bool(behavior.get("_jitter_active")), false) and all_passed

	# Tween-driven verbs + triggers are compiled in (tweens need a live tree - verified in-editor).
	all_passed = _check("lean + zoom + use_camera actions exist", behavior.has_method("lean") and behavior.has_method("zoom_fov_to") and behavior.has_method("use_camera"), true) and all_passed
	all_passed = _check("the finish triggers exist", behavior.has_signal("shake_stopped") and behavior.has_signal("lean_finished") and behavior.has_signal("zoom_finished"), true) and all_passed

	# The additive apply/unapply against a real camera: offsets go on, then come off exactly.
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(1.0, 2.0, 3.0)
	camera.rotation = Vector3(0.1, 0.2, 0.3)
	camera.fov = 75.0
	behavior.set("_last_camera", camera)
	behavior.set("_applied_position", Vector3(0.0, 0.05, 0.0))
	behavior.set("_applied_rotation", Vector3(0.02, 0.0, 0.0))
	behavior.set("_applied_fov", 8.0)
	camera.position += Vector3(0.0, 0.05, 0.0)
	camera.rotation += Vector3(0.02, 0.0, 0.0)
	camera.fov += 8.0
	behavior._unapply()
	all_passed = _check("unapply restores the camera position exactly", camera.position.is_equal_approx(Vector3(1.0, 2.0, 3.0)), true) and all_passed
	all_passed = _check("unapply restores the camera rotation exactly", camera.rotation.is_equal_approx(Vector3(0.1, 0.2, 0.3)), true) and all_passed
	all_passed = _check("unapply restores the camera fov exactly", is_equal_approx(camera.fov, 75.0), true) and all_passed
	all_passed = _check("unapply zeroes the applied ledger", Vector3(behavior.get("_applied_position")) == Vector3.ZERO and is_equal_approx(float(behavior.get("_applied_fov")), 0.0), true) and all_passed

	# Teardown hands the camera back clean (a scene change mid-shake must not strand offsets).
	all_passed = _check("a tree-exit teardown handler exists", behavior.has_method("_on_tree_exiting"), true) and all_passed

	camera.free()
	behavior.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] juice_3d_pack_test: %s" % label)
		return true
	print("[FAIL] juice_3d_pack_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
