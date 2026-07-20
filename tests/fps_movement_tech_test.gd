# Godot EventSheets - FPS Controller movement tech (crouch / crouch slide / wall ride / wall jump).
#
# Loads the COMPILED pack and drives the crouch shape math + state machine on a real
# CharacterBody3D rig (capsule + Head). The rig lives OUTSIDE the scene tree (the runner has no
# main loop), which pins the headroom sweep's no-space guard: standing must be allowed, never
# crash, without a physics space. Floor/wall contact and the actual ceiling block need a stepped
# physics world - verified in the FPS Arena showcase, not here.
@tool
class_name FPSMovementTechTest
extends RefCounted

const PACK := "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("fps controller pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	# The reference rig: body + capsule collider + Head, live in the tree for physics queries.
	var host: CharacterBody3D = CharacterBody3D.new()
	host.name = "TechRig"
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.height = 1.8
	shape_node.shape = capsule
	shape_node.position.y = 0.9
	host.add_child(shape_node)
	var head: Node3D = Node3D.new()
	head.name = "Head"
	head.position.y = 1.5
	host.add_child(head)
	var behavior: Node = script.new()
	host.add_child(behavior)
	behavior.set("host", host)

	# The new surface exists (methods flip to conditions/expressions via return type).
	for method_name: String in ["do_crouch", "stand_up", "set_crouching", "stop_sliding", "do_wall_jump", "stop_wall_ride", "is_crouching", "is_sliding", "is_wall_riding", "can_stand_up", "wall_normal_x", "wall_normal_z"]:
		all_passed = _check("method %s exists" % method_name, behavior.has_method(method_name), true) and all_passed
	for signal_name: String in ["crouched", "stood_up", "slide_started", "slide_ended", "wall_ride_started", "wall_ride_ended", "wall_jumped"]:
		all_passed = _check("signal %s exists" % signal_name, behavior.has_signal(signal_name), true) and all_passed

	# ── Crouch: capsule shrinks toward the floor, Head drops, resource is duplicated ──
	var events: Array = []
	behavior.connect("crouched", func() -> void: events.append("crouched"))
	behavior.connect("stood_up", func() -> void: events.append("stood_up"))
	behavior.connect("slide_ended", func() -> void: events.append("slide_ended"))
	behavior.do_crouch()
	all_passed = _check("crouch flips Is Crouching", behavior.is_crouching(), true) and all_passed
	all_passed = _check("crouch fires On Crouched", events, ["crouched"]) and all_passed
	var live_capsule: CapsuleShape3D = shape_node.shape as CapsuleShape3D
	all_passed = _check("capsule shrinks to Crouch Height", is_equal_approx(live_capsule.height, 0.9), true) and all_passed
	all_passed = _check("the shared capsule RESOURCE is untouched (duplicated on first crouch)", is_equal_approx(capsule.height, 1.8), true) and all_passed
	all_passed = _check("the shape sinks by half the lost height (feet stay planted)", is_equal_approx(shape_node.position.y, 0.9 - 0.45), true) and all_passed
	all_passed = _check("the Head drops by the lost height", is_equal_approx(head.position.y, 1.5 - 0.9), true) and all_passed
	all_passed = _check("crouching at rest starts no slide", behavior.is_sliding(), false) and all_passed
	all_passed = _check("no physics space: Can Stand Up allows standing (never crashes)", behavior.can_stand_up(), true) and all_passed

	# ── Stand: everything restores exactly ──
	behavior.stand_up()
	all_passed = _check("stand restores Is Crouching", behavior.is_crouching(), false) and all_passed
	all_passed = _check("stand fires On Stood Up", events, ["crouched", "stood_up"]) and all_passed
	all_passed = _check("capsule height restores", is_equal_approx((shape_node.shape as CapsuleShape3D).height, 1.8), true) and all_passed
	all_passed = _check("capsule radius restores (a deep crouch auto-thins it)", is_equal_approx((shape_node.shape as CapsuleShape3D).radius, 0.5), true) and all_passed
	all_passed = _check("shape position restores", is_equal_approx(shape_node.position.y, 0.9), true) and all_passed
	all_passed = _check("Head height restores", is_equal_approx(head.position.y, 1.5), true) and all_passed

	# ── Set Crouching is the scripted toggle ──
	behavior.set_crouching(true)
	all_passed = _check("Set Crouching on crouches", behavior.is_crouching(), true) and all_passed
	behavior.set_crouching(false)
	all_passed = _check("Set Crouching off stands", behavior.is_crouching(), false) and all_passed

	# ── Slide state: ending a slide keeps the crouch and fires the signal ──
	behavior.set("sliding", true)
	behavior.set("slide_time", 0.2)
	all_passed = _check("Is Sliding reflects an active slide", behavior.is_sliding(), true) and all_passed
	behavior.stop_sliding()
	all_passed = _check("Stop Sliding ends the slide", behavior.is_sliding(), false) and all_passed
	all_passed = _check("Stop Sliding fires On Slide Ended", events.back(), "slide_ended") and all_passed
	behavior.stop_sliding()
	all_passed = _check("Stop Sliding is idempotent (no double signal)", events.count("slide_ended"), 1) and all_passed

	# ── Multiple jumps (double / triple), the platformer's pattern on the FPS controller ──
	for jump_member: String in ["do_jump", "do_air_jump", "reset_jumps", "_launch_jump"]:
		all_passed = _check("member %s exists" % jump_member, behavior.has_method(jump_member), true) and all_passed
	all_passed = _check("On Air Jumped signal exists", behavior.has_signal("air_jumped"), true) and all_passed
	var air_events: Array = []
	behavior.connect("jumped", func() -> void: air_events.append("ground"))
	behavior.connect("air_jumped", func() -> void: air_events.append("air"))
	behavior.set("max_jumps", 2)         # double jump
	behavior.set("jump_velocity", 4.5)
	behavior.set("_jumps_left", 1)       # one air jump banked (as the on-floor reset would leave it)
	host.velocity = Vector3.ZERO
	behavior.do_jump()
	all_passed = _check("the ground jump launches up + fires On Jumped", host.velocity.y > 0.0 and air_events == ["ground"], true) and all_passed
	behavior.do_air_jump()
	all_passed = _check("the air jump launches up + fires On Air Jumped", air_events == ["ground", "air"], true) and all_passed
	behavior.set("_jumps_left", 0)
	behavior.reset_jumps()
	all_passed = _check("Reset Jumps refills the air budget from Max Jumps", int(behavior.get("_jumps_left")), 1) and all_passed
	behavior.set("max_jumps", 1)
	behavior.reset_jumps()
	all_passed = _check("Max Jumps 1 leaves no air jumps", int(behavior.get("_jumps_left")), 0) and all_passed

	# ── Wall verbs without a wall: honest no-ops ──
	host.velocity = Vector3.ZERO
	behavior.do_wall_jump()
	all_passed = _check("Wall Jump without a wall is a no-op", is_equal_approx(host.velocity.y, 0.0), true) and all_passed
	all_passed = _check("Wall Normal X is zero off-wall", behavior.wall_normal_x(), 0.0) and all_passed
	all_passed = _check("Is Wall Riding starts false", behavior.is_wall_riding(), false) and all_passed
	behavior.stop_wall_ride()
	all_passed = _check("Stop Wall Ride off-wall is safe", behavior.is_wall_riding(), false) and all_passed

	host.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] fps_movement_tech_test: %s" % label)
		return true
	print("[FAIL] fps_movement_tech_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
