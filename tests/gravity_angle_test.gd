# Godot EventSheets - Platformer Movement's Gravity Angle
# One exported angle (degrees; 90 = down, the default) rotates the whole movement frame:
# gravity pull, running, jumping, wall kicks, and is_on_floor() via up_direction. Pins:
# the default frame is EXACTLY the old fixed-down math (Vector2.DOWN.rotated(0) carries
# zero float noise), the frame axes at the cardinal angles, the jump kernel and jump-cut
# acting along the frame, Set Gravity Angle wrapping, and the emitted up_direction line.
@tool
class_name GravityAngleTest
extends RefCounted

const PACK_PATH := "res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var behavior: Node = (load(PACK_PATH) as Script).new() as Node
	var host: CharacterBody2D = CharacterBody2D.new()
	behavior.set("host", host)

	# ---- the default frame is exactly the fixed-down frame (behavior-neutral proof) ----
	all_passed = _check("the default angle is 90 (straight down)", float(behavior.get("gravity_angle")), 90.0) and all_passed
	all_passed = _check("down at 90 degrees is EXACTLY (0, 1)", behavior.call("_gravity_down") == Vector2.DOWN, true) and all_passed
	all_passed = _check("right at 90 degrees is EXACTLY (1, 0)", behavior.call("_gravity_right") == Vector2.RIGHT, true) and all_passed

	# ---- cardinal angles point the frame where the tooltip promises ----
	behavior.set("gravity_angle", 0.0)
	all_passed = _check("0 degrees pulls right", (behavior.call("_gravity_down") as Vector2).is_equal_approx(Vector2.RIGHT), true) and all_passed
	behavior.set("gravity_angle", 270.0)
	all_passed = _check("270 degrees pulls up", (behavior.call("_gravity_down") as Vector2).is_equal_approx(Vector2.UP), true) and all_passed
	all_passed = _check("right stays perpendicular at 270", (behavior.call("_gravity_right") as Vector2).is_equal_approx(Vector2.LEFT), true) and all_passed

	# ---- the jump kernel rises AGAINST gravity, whatever direction that is ----
	host.velocity = Vector2.ZERO
	behavior.call("_perform_jump", -400.0)
	# Distance compare, not is_equal_approx: Vector2 is float32, so the rotated frame
	# carries ~1e-5-scale noise that a per-component approx check would reject.
	all_passed = _check("a jump under ceiling-gravity pushes screen-down", host.velocity.distance_to(Vector2(0.0, 400.0)) < 0.001, true) and all_passed

	# ---- the jump cut scales only the along-gravity component ----
	behavior.set("gravity_angle", 90.0)
	behavior.set("variable_jump_height", true)
	behavior.set("jump_cut_factor", 0.5)
	host.velocity = Vector2(50.0, -200.0)
	behavior.call("jump_released")
	all_passed = _check("the jump cut halves the rise and keeps the run", host.velocity.is_equal_approx(Vector2(50.0, -100.0)), true) and all_passed
	host.velocity = Vector2(50.0, 120.0)
	behavior.call("jump_released")
	all_passed = _check("falling is never cut", host.velocity.is_equal_approx(Vector2(50.0, 120.0)), true) and all_passed

	# ---- the action wraps into 0-360 ----
	behavior.call("set_gravity_angle", 450.0)
	all_passed = _check("Set Gravity Angle wraps 450 to 90", float(behavior.get("gravity_angle")), 90.0) and all_passed

	# ---- the emitted tick keeps floor detection honest ----
	var emitted: String = FileAccess.get_file_as_string(PACK_PATH)
	all_passed = _check("the tick re-aims up_direction from the frame", emitted.contains("host.up_direction = -down"), true) and all_passed
	all_passed = _check("gravity applies along the frame, not velocity.y", emitted.contains("v_down = minf(v_down + gravity * delta, max_fall_speed)"), true) and all_passed

	behavior.free()
	host.free()

	# ---- the Bullet pack's 2D twin: arcs bend along gravity_angle ----
	var bullet: Node = (load("res://eventsheet_addons/bullet/bullet_behavior.gd") as Script).new() as Node
	var bullet_host: Node2D = Node2D.new()
	bullet.set("host", bullet_host)
	all_passed = _check("Bullet's default angle is 90 (straight down)", float(bullet.get("gravity_angle")), 90.0) and all_passed
	# At the default angle the pull is EXACTLY (0, gravity * delta): a horizontal shot
	# gains no sideways drift, bit for bit, so existing games play identically.
	bullet.set("launched", true)
	bullet.set("speed", 0.0)
	bullet.set("gravity", 100.0)
	bullet.set("align_rotation", false)
	bullet.call("_process", 1.0)
	all_passed = _check("default-angle pull is exactly vertical", float(bullet.get("vel_x")), 0.0) and all_passed
	all_passed = _check("default-angle pull strength is unchanged", float(bullet.get("vel_y")), 100.0) and all_passed
	# Under ceiling-gravity the same shot drifts UP instead.
	bullet.set("vel_x", 0.0)
	bullet.set("vel_y", 0.0)
	bullet.set("gravity_angle", 270.0)
	bullet.call("_process", 1.0)
	all_passed = _check("ceiling-gravity pulls the arc up", float(bullet.get("vel_y")) < -99.0, true) and all_passed
	bullet.call("set_gravity_angle", -90.0)
	all_passed = _check("Bullet's Set Gravity Angle wraps -90 to 270", float(bullet.get("gravity_angle")), 270.0) and all_passed
	bullet.free()
	bullet_host.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] gravity_angle_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
