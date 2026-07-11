# EventForge module - 3D vocabulary
#
# Lane-1 wraps of Node3D/CharacterBody3D/RigidBody3D/Camera3D surfaces.
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForge3DACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── 3D vocabulary (same lane-1 rule: wrap native nodes; Tween/visibility/math/
	# input/scene-flow ACEs above are already dimension-agnostic) ──
	descriptors.append(F.make_descriptor("Core", "SetPosition3D", "Set Position (3D)", ACEDescriptor.ACEType.ACTION, "position = {pos}", "", [F.make_param("pos", "String", "Vector3(0, 0, 0)", "Position", "Target position as a Vector3 expression.", "expression")], "General Actions", "Set position to {pos}", "Node3D")
		.described("Teleports a 3D node to an exact world position."))
	descriptors.append(F.make_descriptor("Core", "TranslateNode3D", "Move By (3D)", ACEDescriptor.ACEType.ACTION, "translate({offset})", "", [F.make_param("offset", "String", "Vector3(0, 0, 0)", "Offset", "Local-space offset.", "expression")], "General Actions", "Move by {offset}", "Node3D")
		.described("Nudges a 3D node by an offset relative to its own facing (local space)."))
	descriptors.append(F.make_descriptor("Core", "RotateNode3D", "Rotate (3D)", ACEDescriptor.ACEType.ACTION, "rotate({axis}, {radians})", "", [F.make_param("axis", "String", "Vector3.UP", "Axis", "Rotation axis (must be normalized), e.g. Vector3.UP for yaw.", "expression"), F.make_param("radians", "String", "0.0", "Radians", "Angle to rotate by, in radians (often speed * delta).", "expression")], "General Actions", "Rotate {radians} rad around {axis}", "Node3D")
		.described("Spins a 3D node around an axis by an angle, often using speed times delta."))
	descriptors.append(F.make_descriptor("Core", "SetRotationDeg3D", "Set Rotation (3D, Degrees)", ACEDescriptor.ACEType.ACTION, "rotation_degrees = {degrees}", "", [F.make_param("degrees", "String", "Vector3(0, 0, 0)", "Degrees", "Euler angles in degrees.", "expression")], "General Actions", "Set rotation to {degrees}", "Node3D")
		.described("Sets a 3D node's rotation directly using degree angles."))
	descriptors.append(F.make_descriptor("Core", "LookAt3D", "Look At", ACEDescriptor.ACEType.ACTION, "look_at({target})", "", [F.make_param("target", "String", "Vector3(0, 0, -1)", "Target", "World position to face. Must differ from this node's own position (and not be vertically aligned with it).", "expression")], "General Actions", "Look at {target}", "Node3D")
		.described("Turns a 3D node to face a world position (e.g. an enemy facing the player)."))
	descriptors.append(F.make_descriptor("Core", "SetScale3D", "Set Scale (3D)", ACEDescriptor.ACEType.ACTION, "scale = {scale}", "", [F.make_param("scale", "String", "Vector3(1, 1, 1)", "Scale", "Scale factor.", "expression")], "General Actions", "Set scale to {scale}", "Node3D")
		.described("Sets how big a 3D node is by changing its scale."))
	descriptors.append(F.make_descriptor("Core", "GetPosition3D", "Get Position (3D)", ACEDescriptor.ACEType.EXPRESSION, "position", "", [], "General Expressions", "position", "Node3D")
		.described("Returns a 3D node's current world position as a Vector3."))
	descriptors.append(F.make_descriptor("Core", "IsOnFloor3D", "Is On Floor (3D)", ACEDescriptor.ACEType.CONDITION, "is_on_floor()", "", [], "General Conditions", "Is on floor", "CharacterBody3D")
		.described("True when a 3D character body is standing on the ground (check before jumping)."))
	descriptors.append(F.make_descriptor("Core", "MoveAndSlide3D", "Move And Slide (3D)", ACEDescriptor.ACEType.ACTION, "move_and_slide()", "", [], "General Actions", "Move and slide", "CharacterBody3D")
		.described("Moves a 3D character body by its velocity, sliding smoothly along walls and slopes."))
	descriptors.append(F.make_descriptor("Core", "SetVelocity3D", "Set Velocity (3D)", ACEDescriptor.ACEType.ACTION, "velocity = {vel}", "", [F.make_param("vel", "String", "Vector3(0, 0, 0)", "Velocity", "Velocity vector as a Vector3 expression.", "expression")], "General Actions", "Set velocity to {vel}", "CharacterBody3D")
		.described("Sets a 3D character body's velocity, which Move And Slide then uses to move it."))
	descriptors.append(F.make_descriptor("Core", "GetVelocity3D", "Get Velocity (3D)", ACEDescriptor.ACEType.EXPRESSION, "velocity", "", [], "General Expressions", "velocity", "CharacterBody3D")
		.described("Returns a 3D character body's current velocity vector."))
	descriptors.append(F.make_descriptor("Core", "ApplyCentralImpulse3D", "Apply Central Impulse (3D)", ACEDescriptor.ACEType.ACTION, "apply_central_impulse({impulse})", "", [F.make_param("impulse", "String", "Vector3(0, 0, 0)", "Impulse", "Impulse vector.", "expression")], "General Actions", "Apply impulse {impulse}", "RigidBody3D")
		.described("Gives a 3D physics body a sudden push (e.g. a knockback or launch)."))
	descriptors.append(F.make_descriptor("Core", "MakeCamera3DCurrent", "Make Camera Current (3D)", ACEDescriptor.ACEType.ACTION, "make_current()", "", [], "General Actions", "Make this camera current", "Camera3D")
		.described("Switches the view to this 3D camera, making it the active one."))
	descriptors.append(F.make_descriptor("Core", "SetCameraFov", "Set Camera FOV", ACEDescriptor.ACEType.ACTION, "fov = {degrees}", "", [F.make_param("degrees", "String", "75.0", "Degrees", "Field of view.", "expression")], "General Actions", "Set FOV to {degrees}", "Camera3D")
		.described("Sets a 3D camera's field of view in degrees (lower zooms in, higher widens)."))
	descriptors.append(F.make_descriptor("Core", "GetInputVector", "Input Vector", ACEDescriptor.ACEType.EXPRESSION, "Input.get_vector(&{left}, &{right}, &{up}, &{down})", "", [F.make_param("left", "String", F.default_input_action(), "Left", "Negative X action.", "input_action", F.input_action_options()), F.make_param("right", "String", F.default_input_action(), "Right", "Positive X action.", "input_action", F.input_action_options()), F.make_param("up", "String", F.default_input_action(), "Up", "Negative Y action.", "input_action", F.input_action_options()), F.make_param("down", "String", F.default_input_action(), "Down", "Positive Y action.", "input_action", F.input_action_options())], "Input", "input vector {left}/{right}/{up}/{down}")
		.described("Returns a movement direction from four input actions, ideal for player movement."))

	# ── 3D spatial queries (the biggest functional 3D gap: shooting, interaction, AI
	# vision, ground-snap are all raycast-centric). Two flavors, both single-line per
	# the parity contract: a RayCast3D node set, and a host-agnostic Node3D world query. ──
	descriptors.append(F.make_descriptor("Core", "RayCast3DIsColliding", "RayCast Is Colliding (3D)", ACEDescriptor.ACEType.CONDITION, "is_colliding()", "", [], "Raycast 3D", "RayCast is colliding", "RayCast3D")
		.described("True when a RayCast3D is currently hitting something in front of it."))
	descriptors.append(F.make_descriptor("Core", "RayCast3DForceUpdate", "Force RayCast Update (3D)", ACEDescriptor.ACEType.ACTION, "force_raycast_update()", "", [], "Raycast 3D", "Force raycast update", "RayCast3D")
		.described("Forces a RayCast3D to recheck immediately instead of waiting for the next frame."))
	descriptors.append(F.make_descriptor("Core", "RayCast3DGetCollider", "RayCast Collider (3D)", ACEDescriptor.ACEType.EXPRESSION, "get_collider()", "", [], "Raycast 3D", "raycast collider", "RayCast3D")
		.described("Returns the object a RayCast3D is currently hitting."))
	descriptors.append(F.make_descriptor("Core", "RayCast3DGetPoint", "RayCast Hit Point (3D)", ACEDescriptor.ACEType.EXPRESSION, "get_collision_point()", "", [], "Raycast 3D", "raycast hit point", "RayCast3D")
		.described("Returns the exact world point where a RayCast3D hits something."))
	descriptors.append(F.make_descriptor("Core", "RayCast3DGetNormal", "RayCast Hit Normal (3D)", ACEDescriptor.ACEType.EXPRESSION, "get_collision_normal()", "", [], "Raycast 3D", "raycast hit normal", "RayCast3D")
		.described("Returns the surface direction at the point a RayCast3D hits."))
	descriptors.append(F.make_descriptor("Core", "WorldRaycastHit3D", "World Raycast Hits? (3D)", ACEDescriptor.ACEType.CONDITION, "not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create({from}, {to})).is_empty()", "", [F.make_param("from", "String", "Vector3(0, 0, 0)", "From", "Ray start (Vector3 expression).", "expression"), F.make_param("to", "String", "Vector3(0, 0, 0)", "To", "Ray end (Vector3 expression).", "expression")], "Raycast 3D", "world raycast {from} -> {to} hits", "Node3D")
		.described("True when a ray cast between two points hits anything in the 3D world."))
	descriptors.append(F.make_descriptor("Core", "WorldRaycastPoint3D", "World Raycast Point (3D)", ACEDescriptor.ACEType.EXPRESSION, "get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create({from}, {to})).get(\"position\", Vector3.ZERO)", "", [F.make_param("from", "String", "Vector3(0, 0, 0)", "From", "Ray start (Vector3 expression).", "expression"), F.make_param("to", "String", "Vector3(0, 0, 0)", "To", "Ray end (Vector3 expression).", "expression")], "Raycast 3D", "world raycast point {from} -> {to}", "Node3D")
		.described("Returns the world point where a ray between two points first hits something."))

	return descriptors
