# Godot EventSheets — 3D vocabulary (lane 1: wrap native 3D nodes)
# Node3D/CharacterBody3D/RigidBody3D/Camera3D groups + the Input Vector expression;
# Tween/visibility/math/scene-flow ACEs are already dimension-agnostic.
@tool
extends RefCounted
class_name Native3DAcesTest

static func run() -> bool:
	var all_passed: bool = true

	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("Node3D vocabulary registered",
		by_id.has("SetPosition3D") and by_id.has("LookAt3D") and by_id.has("SetScale3D") and by_id.has("GetPosition3D"), true) and all_passed
	all_passed = _check("CharacterBody3D vocabulary registered",
		by_id.has("IsOnFloor3D") and by_id.has("MoveAndSlide3D") and by_id.has("SetVelocity3D"), true) and all_passed
	all_passed = _check("RigidBody3D + Camera3D registered",
		by_id.has("ApplyCentralImpulse3D") and by_id.has("SetCameraFov"), true) and all_passed
	all_passed = _check("input vector registered with StringName idiom",
		str(by_id["GetInputVector"].codegen_template).contains("Input.get_vector(&{left}"), true) and all_passed
	all_passed = _check("3D groups by node type", str(by_id["MoveAndSlide3D"].node_type), "CharacterBody3D") and all_passed

	# Compile a 3D movement event end to end.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody3D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnPhysicsProcess"
	var grounded: ACECondition = ACECondition.new()
	grounded.provider_id = "Core"
	grounded.ace_id = "IsOnFloor3D"
	grounded.codegen_template = "is_on_floor()"
	event.conditions.append(grounded)
	var set_velocity: ACEAction = ACEAction.new()
	set_velocity.provider_id = "Core"
	set_velocity.ace_id = "SetVelocity3D"
	set_velocity.codegen_template = "velocity = {vel}"
	set_velocity.params = {"vel": "Vector3(Input.get_axis(\"ui_left\", \"ui_right\") * 5.0, velocity.y, 0.0)"}
	event.actions.append(set_velocity)
	var slide: ACEAction = ACEAction.new()
	slide.provider_id = "Core"
	slide.ace_id = "MoveAndSlide3D"
	slide.codegen_template = "move_and_slide()"
	event.actions.append(slide)
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_3d.gd").get("output", ""))
	all_passed = _check("3D event compiles",
		output.contains("if is_on_floor():") and output.contains("move_and_slide()"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("3D output parses", generated.reload(true) == OK, true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] native_3d_aces_test: %s" % label)
		return true
	print("[FAIL] native_3d_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
