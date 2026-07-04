# EventForge module - Collision vocabulary (the "Helper ACEs for collisions").
#
# The collision queries you'd otherwise drop to a raw block for: CharacterBody slide/wall/
# floor results (valid AFTER Move And Slide), Area overlap tests + lists, collision layer/
# mask bits, and enabling/disabling a CollisionShape. Lane-1 wraps of native nodes - every
# template is one direct GDScript line (parity covenant), and each is node-type-scoped so
# the picker files it under its node's section (CharacterBody2D, Area2D, …).
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant).
@tool
class_name EventForgeCollisionACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── CharacterBody2D: slide results (valid after Move And Slide) ──
	descriptors.append(F.make_descriptor("Core", "IsOnWall", "Is On Wall", ACEDescriptor.ACEType.CONDITION, "{host.}is_on_wall()", "", [], "Collisions", "Is on wall", "CharacterBody2D")
		.described("True when this 2D character is pressing against a wall."))
	descriptors.append(F.make_descriptor("Core", "IsOnCeiling", "Is On Ceiling", ACEDescriptor.ACEType.CONDITION, "{host.}is_on_ceiling()", "", [], "Collisions", "Is on ceiling", "CharacterBody2D")
		.described("True when this 2D character is touching a ceiling above."))
	descriptors.append(F.make_descriptor("Core", "GetWallNormal", "Wall Normal", ACEDescriptor.ACEType.EXPRESSION, "{host.}get_wall_normal()", "", [], "Collisions", "wall normal", "CharacterBody2D")
		.described("Returns the direction the touched wall is facing, for wall-jumps or sliding."))
	descriptors.append(F.make_descriptor("Core", "GetFloorNormal", "Floor Normal", ACEDescriptor.ACEType.EXPRESSION, "{host.}get_floor_normal()", "", [], "Collisions", "floor normal", "CharacterBody2D")
		.described("Returns the direction the floor is facing, useful on slopes."))
	descriptors.append(F.make_descriptor("Core", "GetSlideCount", "Slide Collision Count", ACEDescriptor.ACEType.EXPRESSION, "get_slide_collision_count()", "", [], "Collisions", "slide collision count", "CharacterBody2D")
		.described("Returns how many things the character hit during its last move."))
	descriptors.append(F.make_descriptor("Core", "GetLastSlideCollider", "Last Slide Collider", ACEDescriptor.ACEType.EXPRESSION, "(get_last_slide_collision().get_collider() if get_slide_collision_count() > 0 else null)", "", [], "Collisions", "last slide collider", "CharacterBody2D")
		.described("Returns the node the character bumped into last, or nothing if none."))
	descriptors.append(F.make_descriptor("Core", "GetLastSlideNormal", "Last Slide Normal", ACEDescriptor.ACEType.EXPRESSION, "(get_last_slide_collision().get_normal() if get_slide_collision_count() > 0 else Vector2.ZERO)", "", [], "Collisions", "last slide normal", "CharacterBody2D")
		.described("Returns the surface direction from the character's last collision."))

	# ── Area2D: overlap tests + lists (the common "am I touching X" queries) ──
	descriptors.append(F.make_descriptor("Core", "OverlapsBody", "Overlaps Body", ACEDescriptor.ACEType.CONDITION, "overlaps_body({body})", "", [F.make_param("body", "String", "get_node(\"../Player\")", "Body", "The body node to test against (replace with your target - `self` never overlaps itself).", "expression")], "Collisions", "overlaps body {body}", "Area2D")
		.described("True when this Area2D is overlapping the given physics body."))
	descriptors.append(F.make_descriptor("Core", "OverlapsArea", "Overlaps Area", ACEDescriptor.ACEType.CONDITION, "overlaps_area({area})", "", [F.make_param("area", "String", "get_node(\"../Trigger\")", "Area", "The area node to test against (replace with your target - `self` never overlaps itself).", "expression")], "Collisions", "overlaps area {area}", "Area2D")
		.described("True when this Area2D is overlapping the given other area."))
	descriptors.append(F.make_descriptor("Core", "HasOverlappingBodies", "Has Overlapping Bodies", ACEDescriptor.ACEType.CONDITION, "has_overlapping_bodies()", "", [], "Collisions", "has overlapping bodies", "Area2D")
		.described("True when this Area2D currently overlaps any physics body."))
	descriptors.append(F.make_descriptor("Core", "HasOverlappingAreas", "Has Overlapping Areas", ACEDescriptor.ACEType.CONDITION, "has_overlapping_areas()", "", [], "Collisions", "has overlapping areas", "Area2D")
		.described("True when this Area2D currently overlaps any other area."))
	descriptors.append(F.make_descriptor("Core", "GetOverlappingBodies", "Overlapping Bodies", ACEDescriptor.ACEType.EXPRESSION, "get_overlapping_bodies()", "", [], "Collisions", "overlapping bodies", "Area2D")
		.described("Returns the list of physics bodies currently inside this Area2D."))
	descriptors.append(F.make_descriptor("Core", "GetOverlappingAreas", "Overlapping Areas", ACEDescriptor.ACEType.EXPRESSION, "get_overlapping_areas()", "", [], "Collisions", "overlapping areas", "Area2D")
		.described("Returns the list of areas currently overlapping this Area2D."))

	# ── CollisionObject2D: layers & masks (CharacterBody / Area / Rigid / Static all inherit) ──
	descriptors.append(F.make_descriptor("Core", "SetCollisionLayerBit", "Set Collision Layer Bit", ACEDescriptor.ACEType.ACTION, "set_collision_layer_value({layer}, {enabled})", "", [F.make_param("layer", "String", "1", "Layer", "Layer number (1-32).", "expression"), F.make_param("enabled", "String", "true", "Enabled", "Sit on this layer?", "", ["true", "false"])], "Collisions", "Set layer {layer} = {enabled}", "CollisionObject2D")
		.described("Turns a collision layer on or off, controlling what this object sits on."))
	descriptors.append(F.make_descriptor("Core", "SetCollisionMaskBit", "Set Collision Mask Bit", ACEDescriptor.ACEType.ACTION, "set_collision_mask_value({mask}, {enabled})", "", [F.make_param("mask", "String", "1", "Mask", "Mask number (1-32).", "expression"), F.make_param("enabled", "String", "true", "Enabled", "Scan this layer?", "", ["true", "false"])], "Collisions", "Set mask {mask} = {enabled}", "CollisionObject2D")
		.described("Turns a collision mask bit on or off, controlling what this object detects."))
	descriptors.append(F.make_descriptor("Core", "IsOnCollisionLayer", "Is On Collision Layer", ACEDescriptor.ACEType.CONDITION, "get_collision_layer_value({layer})", "", [F.make_param("layer", "String", "1", "Layer", "Layer number (1-32).", "expression")], "Collisions", "is on layer {layer}", "CollisionObject2D")
		.described("True when this object occupies the given collision layer."))

	# ── CollisionShape2D: toggle (deferred so it is safe to call mid-physics) ──
	descriptors.append(F.make_descriptor("Core", "EnableCollisionShape", "Enable Collision Shape", ACEDescriptor.ACEType.ACTION, "set_deferred(&\"disabled\", false)", "", [], "Collisions", "Enable collision shape", "CollisionShape2D")
		.described("Switches this collision shape back on so it can collide again."))
	descriptors.append(F.make_descriptor("Core", "DisableCollisionShape", "Disable Collision Shape", ACEDescriptor.ACEType.ACTION, "set_deferred(&\"disabled\", true)", "", [], "Collisions", "Disable collision shape", "CollisionShape2D")
		.described("Switches this collision shape off, safely, so it stops colliding."))

	# ── 3D parity (CharacterBody3D slide + Area3D overlap) ──
	descriptors.append(F.make_descriptor("Core", "IsOnWall3D", "Is On Wall (3D)", ACEDescriptor.ACEType.CONDITION, "{host.}is_on_wall()", "", [], "Collisions", "Is on wall", "CharacterBody3D")
		.described("True when this 3D character is pressing against a wall."))
	descriptors.append(F.make_descriptor("Core", "IsOnCeiling3D", "Is On Ceiling (3D)", ACEDescriptor.ACEType.CONDITION, "{host.}is_on_ceiling()", "", [], "Collisions", "Is on ceiling", "CharacterBody3D")
		.described("True when this 3D character is touching a ceiling above."))
	descriptors.append(F.make_descriptor("Core", "GetWallNormal3D", "Wall Normal (3D)", ACEDescriptor.ACEType.EXPRESSION, "{host.}get_wall_normal()", "", [], "Collisions", "wall normal", "CharacterBody3D")
		.described("Fires with the direction a 3D body just bumped into a wall, useful for wall-jumps or ricochets."))
	descriptors.append(F.make_descriptor("Core", "GetFloorNormal3D", "Floor Normal (3D)", ACEDescriptor.ACEType.EXPRESSION, "{host.}get_floor_normal()", "", [], "Collisions", "floor normal", "CharacterBody3D")
		.described("Fires with the slope direction of the floor a 3D body is standing on, handy for slope-aware movement."))
	descriptors.append(F.make_descriptor("Core", "HasOverlappingBodies3D", "Has Overlapping Bodies (3D)", ACEDescriptor.ACEType.CONDITION, "has_overlapping_bodies()", "", [], "Collisions", "has overlapping bodies", "Area3D")
		.described("True when this 3D Area is currently overlapping at least one physics body."))
	descriptors.append(F.make_descriptor("Core", "GetOverlappingBodies3D", "Overlapping Bodies (3D)", ACEDescriptor.ACEType.EXPRESSION, "get_overlapping_bodies()", "", [], "Collisions", "overlapping bodies", "Area3D")
		.described("Fires with the list of physics bodies currently inside this 3D Area."))

	return descriptors
