# EventForge module — 3D vocabulary
#
# Lane-1 wraps of Node3D/CharacterBody3D/RigidBody3D/Camera3D surfaces.
# Module contract: see ace_factory.gd — ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
extends RefCounted
class_name EventForge3DACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── 3D vocabulary (same lane-1 rule: wrap native nodes; Tween/visibility/math/
	# input/scene-flow ACEs above are already dimension-agnostic) ──
	descriptors.append(F.make_descriptor("Core", "SetPosition3D", "Set Position (3D)", ACEDescriptor.ACEType.ACTION, "position = {pos}", "", [F.make_param("pos", "String", "Vector3(0, 0, 0)", "Position", "Target position as a Vector3 expression.", "expression")], "General Actions", "Set position to {pos}", "Node3D"))
	descriptors.append(F.make_descriptor("Core", "TranslateNode3D", "Move By (3D)", ACEDescriptor.ACEType.ACTION, "translate({offset})", "", [F.make_param("offset", "String", "Vector3(0, 0, 0)", "Offset", "Local-space offset.", "expression")], "General Actions", "Move by {offset}", "Node3D"))
	descriptors.append(F.make_descriptor("Core", "SetRotationDeg3D", "Set Rotation (3D, Degrees)", ACEDescriptor.ACEType.ACTION, "rotation_degrees = {degrees}", "", [F.make_param("degrees", "String", "Vector3(0, 0, 0)", "Degrees", "Euler angles in degrees.", "expression")], "General Actions", "Set rotation to {degrees}", "Node3D"))
	descriptors.append(F.make_descriptor("Core", "LookAt3D", "Look At", ACEDescriptor.ACEType.ACTION, "look_at({target})", "", [F.make_param("target", "String", "Vector3(0, 0, 0)", "Target", "World position to face.", "expression")], "General Actions", "Look at {target}", "Node3D"))
	descriptors.append(F.make_descriptor("Core", "SetScale3D", "Set Scale (3D)", ACEDescriptor.ACEType.ACTION, "scale = {scale}", "", [F.make_param("scale", "String", "Vector3(1, 1, 1)", "Scale", "Scale factor.", "expression")], "General Actions", "Set scale to {scale}", "Node3D"))
	descriptors.append(F.make_descriptor("Core", "GetPosition3D", "Get Position (3D)", ACEDescriptor.ACEType.EXPRESSION, "position", "", [], "General Expressions", "position", "Node3D"))
	descriptors.append(F.make_descriptor("Core", "IsOnFloor3D", "Is On Floor (3D)", ACEDescriptor.ACEType.CONDITION, "is_on_floor()", "", [], "General Conditions", "Is on floor", "CharacterBody3D"))
	descriptors.append(F.make_descriptor("Core", "MoveAndSlide3D", "Move And Slide (3D)", ACEDescriptor.ACEType.ACTION, "move_and_slide()", "", [], "General Actions", "Move and slide", "CharacterBody3D"))
	descriptors.append(F.make_descriptor("Core", "SetVelocity3D", "Set Velocity (3D)", ACEDescriptor.ACEType.ACTION, "velocity = {vel}", "", [F.make_param("vel", "String", "Vector3(0, 0, 0)", "Velocity", "Velocity vector as a Vector3 expression.", "expression")], "General Actions", "Set velocity to {vel}", "CharacterBody3D"))
	descriptors.append(F.make_descriptor("Core", "GetVelocity3D", "Get Velocity (3D)", ACEDescriptor.ACEType.EXPRESSION, "velocity", "", [], "General Expressions", "velocity", "CharacterBody3D"))
	descriptors.append(F.make_descriptor("Core", "ApplyCentralImpulse3D", "Apply Central Impulse (3D)", ACEDescriptor.ACEType.ACTION, "apply_central_impulse({impulse})", "", [F.make_param("impulse", "String", "Vector3(0, 0, 0)", "Impulse", "Impulse vector.", "expression")], "General Actions", "Apply impulse {impulse}", "RigidBody3D"))
	descriptors.append(F.make_descriptor("Core", "MakeCamera3DCurrent", "Make Camera Current (3D)", ACEDescriptor.ACEType.ACTION, "make_current()", "", [], "General Actions", "Make this camera current", "Camera3D"))
	descriptors.append(F.make_descriptor("Core", "SetCameraFov", "Set Camera FOV", ACEDescriptor.ACEType.ACTION, "fov = {degrees}", "", [F.make_param("degrees", "String", "75.0", "Degrees", "Field of view.", "expression")], "General Actions", "Set FOV to {degrees}", "Camera3D"))
	descriptors.append(F.make_descriptor("Core", "GetInputVector", "Input Vector", ACEDescriptor.ACEType.EXPRESSION, "Input.get_vector(&{left}, &{right}, &{up}, &{down})", "", [F.make_param("left", "String", F.default_input_action(), "Left", "Negative X action.", "", F.input_action_options()), F.make_param("right", "String", F.default_input_action(), "Right", "Positive X action.", "", F.input_action_options()), F.make_param("up", "String", F.default_input_action(), "Up", "Negative Y action.", "", F.input_action_options()), F.make_param("down", "String", F.default_input_action(), "Down", "Positive Y action.", "", F.input_action_options())], "Input", "input vector {left}/{right}/{up}/{down}"))

	return descriptors
