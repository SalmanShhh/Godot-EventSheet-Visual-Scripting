# EventForge — behavior-mode host targeting for node-scoped ACEs.
#
# Inside a behavior sheet the compiled script is `extends Node` with a `host` member (its parent), so a
# node-scoped ACE must call on `host`, not on the behavior Node (self). The {host.} optional-prefix
# idiom does this: it resolves to `host.` when the compiler passes host_default="host" (behavior mode)
# and to nothing otherwise — so the SAME descriptor stays byte-identical on a normal sheet and becomes
# host-targeted in a behavior. Pins both shapes, incl. a negated condition wrapping the host call.
@tool
extends RefCounted
class_name HostTargetCodegenTest

static func run() -> bool:
	var ok: bool = true

	# Action, no params: Move And Slide.
	var slide: ACEAction = ACEAction.new()
	slide.provider_id = "Core"
	slide.ace_id = "MoveAndSlide"
	slide.enabled = true
	ok = _check("MoveAndSlide stays bare on a normal sheet", ActionCodegen.generate_action(slide, "", ""), "move_and_slide()") and ok
	ok = _check("MoveAndSlide targets the host in a behavior", ActionCodegen.generate_action(slide, "", "host"), "host.move_and_slide()") and ok

	# Action with a param: Set Velocity — the {host.} prefix must precede the assignment target.
	var set_vel: ACEAction = ACEAction.new()
	set_vel.provider_id = "Core"
	set_vel.ace_id = "SetVelocity2D"
	set_vel.enabled = true
	set_vel.params = {"vel": "Vector2(120, 0)"}
	ok = _check("SetVelocity2D stays bare on a normal sheet", ActionCodegen.generate_action(set_vel, "", ""), "velocity = Vector2(120, 0)") and ok
	ok = _check("SetVelocity2D targets the host in a behavior", ActionCodegen.generate_action(set_vel, "", "host"), "host.velocity = Vector2(120, 0)") and ok

	# Condition: Is On Floor — bare, host-targeted, and host-targeted-then-negated.
	var on_floor: ACECondition = ACECondition.new()
	on_floor.provider_id = "Core"
	on_floor.ace_id = "IsOnFloor"
	on_floor.enabled = true
	ok = _check("IsOnFloor stays bare on a normal sheet", ConditionCodegen.generate_condition(on_floor, ""), "is_on_floor()") and ok
	ok = _check("IsOnFloor targets the host in a behavior", ConditionCodegen.generate_condition(on_floor, "host"), "host.is_on_floor()") and ok
	on_floor.negated = true
	ok = _check("a negated host condition wraps the host call", ConditionCodegen.generate_condition(on_floor, "host"), "not (host.is_on_floor())") and ok

	# A collision slide query (Is On Wall) retrofitted in the same pass.
	var on_wall: ACECondition = ACECondition.new()
	on_wall.provider_id = "Core"
	on_wall.ace_id = "IsOnWall"
	on_wall.enabled = true
	ok = _check("IsOnWall stays bare on a normal sheet", ConditionCodegen.generate_condition(on_wall, ""), "is_on_wall()") and ok
	ok = _check("IsOnWall targets the host in a behavior", ConditionCodegen.generate_condition(on_wall, "host"), "host.is_on_wall()") and ok

	return ok

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] host_target_codegen_test: %s" % label)
		return true
	print("[FAIL] host_target_codegen_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
