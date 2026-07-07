# Godot EventSheets - physics_car pack (RigidBody2D car behavior) input + steering logic.
#
# Loads the COMPILED behavior and drives it with a bare RigidBody2D assigned as its host (no physics
# space, so the force integration in _drive is not exercised here - that is felt by playing). This
# proves the pure logic: input clamping, the keyboard-style Simulate Control mapping, the Drive Toward
# steering math (heading error + proportional steer), the auto-steer modes, and the terrain overrides.
@tool
class_name PhysicsCarTest
extends RefCounted

const PACK := "res://eventsheet_addons/physics_car/physics_car_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("physics_car pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var car: Node = script.new()
	var body: RigidBody2D = RigidBody2D.new()
	# Assign the host directly (a bare .new() never enters the tree to run _enter_tree). The steering
	# math only reads the body's rotation / position, which work without a physics space.
	car.host = body

	# Input clamping.
	car.set_throttle(2.0)
	all_passed = _check("Set Throttle clamps to 1", is_equal_approx(car.throttle_input(), 1.0), true) and all_passed
	car.set_throttle(-9.0)
	all_passed = _check("Set Throttle clamps to -1", is_equal_approx(car.throttle_input(), -1.0), true) and all_passed
	car.set_brake(5.0)
	all_passed = _check("Set Brake clamps to 0..1", is_equal_approx(car.brake_input(), 1.0), true) and all_passed
	car.set_steer(-3.0)
	all_passed = _check("Set Steer clamps to -1", is_equal_approx(car.steer_input(), -1.0), true) and all_passed

	# Stop clears everything and exits any Drive Toward mode.
	car.stop()
	all_passed = _check("Stop clears the inputs and drive mode",
		is_zero_approx(car.throttle_input()) and is_zero_approx(car.brake_input()) and is_zero_approx(car.steer_input())
		and not car.is_driving_toward_angle() and not car.is_driving_toward_position(), true) and all_passed

	# Keyboard-style Simulate Control.
	car.simulate_control("up")
	all_passed = _check("Simulate Control up drives forward", is_equal_approx(car.throttle_input(), 1.0), true) and all_passed
	car.simulate_control("down")
	all_passed = _check("Simulate Control down reverses", is_equal_approx(car.throttle_input(), -1.0), true) and all_passed
	car.simulate_control("left")
	all_passed = _check("Simulate Control left steers left", is_equal_approx(car.steer_input(), -1.0), true) and all_passed
	car.simulate_control("right")
	all_passed = _check("Simulate Control right steers right", is_equal_approx(car.steer_input(), 1.0), true) and all_passed
	car.simulate_control("stop")
	all_passed = _check("Simulate Control stop clears throttle + steer",
		is_zero_approx(car.throttle_input()) and is_zero_approx(car.steer_input()), true) and all_passed

	# Drive Toward Angle: steer toward the target heading, zero inside the tolerance.
	body.rotation = 0.0
	car.drive_toward_angle(90.0, 1.0, 1.0, 5.0)
	all_passed = _check("Drive Toward Angle sets the mode, heading error, and a turning steer",
		car.is_driving_toward_angle() and is_equal_approx(car.heading_error(), 90.0) and car.steer_input() > 0.0 and is_equal_approx(car.throttle_input(), 1.0), true) and all_passed
	car.drive_toward_angle(0.0, 1.0, 1.0, 5.0)
	all_passed = _check("Drive Toward Angle stops steering once aligned within tolerance",
		is_zero_approx(car.heading_error()) and is_zero_approx(car.steer_input()), true) and all_passed

	# A manual input exits the auto-steer mode.
	car.set_throttle(0.5)
	all_passed = _check("a manual input exits Drive Toward mode", car.is_driving_toward_angle(), false) and all_passed

	# Drive Toward Position: aim at a world point.
	body.rotation = 0.0
	body.global_position = Vector2.ZERO
	car.drive_toward_position(100.0, 0.0, 1.0, 1.0, 5.0)
	all_passed = _check("Drive Toward Position straight ahead needs no steering",
		car.is_driving_toward_position() and is_zero_approx(car.steer_input()), true) and all_passed
	car.drive_toward_position(0.0, 100.0, 1.0, 1.0, 5.0)
	all_passed = _check("Drive Toward Position to the side steers toward it",
		is_equal_approx(car.heading_error(), 90.0) and car.steer_input() > 0.0, true) and all_passed

	# Terrain overrides.
	car.set_surface_grip(0.2)
	car.set_surface_resistance(1.6)
	all_passed = _check("Set Surface Grip / Resistance apply multipliers and report an override",
		is_equal_approx(car.surface_grip_multiplier(), 0.2) and is_equal_approx(car.surface_resistance_multiplier(), 1.6) and car.has_surface_override(), true) and all_passed
	car.reset_surface()
	all_passed = _check("Reset Surface restores the multipliers and clears the override",
		is_equal_approx(car.surface_grip_multiplier(), 1.0) and is_equal_approx(car.surface_resistance_multiplier(), 1.0) and not car.has_surface_override(), true) and all_passed

	# Handbrake is a momentary request.
	car.enable_handbrake()
	all_passed = _check("Enable Handbrake flags the handbrake", car.is_handbrake_active(), true) and all_passed

	car.free()
	body.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] physics_car_test: %s" % label)
		return true
	print("[FAIL] physics_car_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
