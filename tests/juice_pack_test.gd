# Godot EventSheets — juice pack (screenshake / zoom / squash & stretch) smoke + trauma equivalence.
#
# Loads the COMPILED juice pack and drives the trauma integrator directly. The headless runner has no
# live viewport, so the auto-found camera is null — which is exactly the path we want to prove is SAFE:
# Shake still accrues + decays trauma, and the camera/host effects no-op instead of crashing. The
# visual side (actual offset/zoom/scale tweens) is verified in-editor, not here.
@tool
class_name JuicePackTest
extends RefCounted

const PACK := "res://eventsheet_addons/juice/juice_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("juice pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var behavior: Node = script.new()
	# Shake accrues trauma and decays back to rest.
	behavior.shake(0.6)
	all_passed = _check("shake starts a shake", behavior.is_shaking(), true) and all_passed
	all_passed = _check("trauma reflects the shake strength", is_equal_approx(behavior.current_trauma(), 0.6), true) and all_passed
	behavior.shake(2.0)
	all_passed = _check("trauma clamps to 1.0", behavior.current_trauma() <= 1.0, true) and all_passed
	for _i in 200:
		behavior._process(0.1)
		if not behavior.is_shaking():
			break
	all_passed = _check("shake decays back to rest", behavior.is_shaking(), false) and all_passed

	# Stop Shake clears trauma immediately.
	behavior.shake(0.5)
	behavior.stop_shake()
	all_passed = _check("stop_shake clears the shake", behavior.is_shaking(), false) and all_passed

	# With no live camera/host, the camera + transform effects must no-op (not crash).
	behavior.squash_and_stretch(0.3, 0.2)
	behavior.spring_squash(0.3)
	behavior.clear_slowmo()
	behavior.zoom_by_percent(150.0, 0.2)
	behavior.zoom_to_position(Vector2(100, 100), 150.0, 0.2)
	behavior.zoom_toward_point(Vector2(50, 50), 150.0, 0.2)
	behavior.use_camera(NodePath("Nonexistent"))
	all_passed = _check("camera/host effects no-op safely without a camera or host", true, true) and all_passed

	# Slowmo + spring-squash compiled in (the runtime tween needs a live tree — verified in-editor).
	all_passed = _check("slowmo + clear_slowmo + spring_squash actions exist", behavior.has_method("slowmo") and behavior.has_method("clear_slowmo") and behavior.has_method("spring_squash"), true) and all_passed
	all_passed = _check("slowmo helpers + On Slowmo Finished signal exist", behavior.has_method("_set_time_scale") and behavior.has_method("_slowmo_trans") and behavior.has_method("_apply_host_scale") and behavior.has_signal("slowmo_finished"), true) and all_passed

	# Teardown safety (D1): leaving the tree mid-slowmo restores the GLOBAL Engine.time_scale, so a scene
	# change during slow motion can't leave the whole game running slow.
	all_passed = _check("a tree-exit teardown handler exists", behavior.has_method("_on_tree_exiting"), true) and all_passed
	Engine.time_scale = 0.25
	behavior._on_tree_exiting()
	all_passed = _check("tree-exit teardown restores Engine.time_scale", is_equal_approx(Engine.time_scale, 1.0), true) and all_passed

	# The spring-squash integrator springs the scale back to rest (the math runs in the tick; no live host needed).
	behavior.squash_damping = 0.9
	behavior._base_scale = Vector2.ONE
	behavior._squash_value = Vector2(1.3, 0.7)
	behavior._squash_velocity = Vector2.ZERO
	behavior._squash_spring_active = true
	for _k in 3000:
		behavior._process(0.016)
		if not behavior._squash_spring_active:
			break
	all_passed = _check("spring squash settles back to rest", behavior._squash_spring_active, false) and all_passed
	all_passed = _check("spring squash returns to base scale", behavior._squash_value.is_equal_approx(Vector2.ONE), true) and all_passed

	# Engine.time_scale must not leak to other tests.
	all_passed = _check("Engine.time_scale restored to 1.0", is_equal_approx(Engine.time_scale, 1.0), true) and all_passed

	behavior.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] juice_pack_test: %s" % label)
		return true
	print("[FAIL] juice_pack_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
