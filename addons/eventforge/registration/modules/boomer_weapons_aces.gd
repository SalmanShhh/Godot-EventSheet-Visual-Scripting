# EventForge module - Weapons in 3D (X25): hitscan, explosions, an arsenal and the secrets counter.
#
# The FPS Controller pack moves the player and the Bullet 3D pack throws things; what a fast 3D
# shooter still writes out by hand is the ray from the middle of the screen with the damage on the
# end of it, the blast that pushes everything away from a point, and the wrapping index over a list
# of weapons. Each of those is ten lines of ray, loop and index plumbing, and each is one row here.
#
# The push in Explode At is a real impulse on a real body, so rocket jumping falls out of it: stand
# in your own blast and it throws you. That is not a special case in the row - it is what pushing
# every body away from a point means, and the row is honest about it rather than filtering the
# player out.
#
# Everything compiles to plain Godot physics queries with zero plugin references, which is what lets
# an opened shooter read back as these rows.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeBoomerWeaponsACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const WEAPONS := "Weapons 3D"

## The middle of the screen, which is where a shooter's crosshair is and therefore where the shot
## comes from. One constant so the ray origin and the ray direction can never aim at two points.
const SCREEN_CENTRE := "get_viewport().get_visible_rect().size * 0.5"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_shooting(descriptors)
	_arsenal(descriptors)
	_secrets(descriptors)
	return descriptors


## The two shots a 3D shooter has: the instant one down the crosshair, and the one that goes off at
## a point and pushes everything away from it.
static func _shooting(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "FireHitscan", "Fire Hitscan", ACEDescriptor.ACEType.ACTION, "\n".join(PackedStringArray([
		"var __cam_{uid} = get_viewport().get_camera_3d()",
		"var __from_{uid} = __cam_{uid}.project_ray_origin(%s)" % SCREEN_CENTRE,
		"var __aim_{uid} = __cam_{uid}.project_ray_normal(%s)" % SCREEN_CENTRE,
		"var __dir_{uid} = __aim_{uid}.rotated(Vector3.UP, deg_to_rad(randf_range(-{spread}, {spread}))).rotated(__aim_{uid}.cross(Vector3.UP).normalized(), deg_to_rad(randf_range(-{spread}, {spread})))",
		"var __query_{uid} = PhysicsRayQueryParameters3D.create(__from_{uid}, __from_{uid} + __dir_{uid} * {reach})",
		"__query_{uid}.collision_mask = {mask}",
		"var __hit_{uid} = get_world_3d().direct_space_state.intersect_ray(__query_{uid})",
		"if not __hit_{uid}.is_empty() and __hit_{uid}.collider.has_method(\"take_damage\"):",
		"\t__hit_{uid}.collider.take_damage({damage})"
	])), "", [
		F.make_param("spread", "String", "1.5", "Spread", "How many degrees the shot can wander from dead centre.", "angle"),
		F.make_param("damage", "String", "25", "Damage", "How much the thing hit loses.", "expression"),
		F.make_param("reach", "String", "200.0", "Reach", "How far the shot carries.", "expression"),
		F.make_param("mask", "String", "1", "Hits layers", "Which collision layers the shot can hit.", "physics_layer_3d")
	], WEAPONS, "Fire hitscan (spread {spread}°, damage {damage})", "Node3D")
		.described("Shoots a ray from the middle of the screen and damages the first thing it hits. Instant, no projectile - the shotgun, the rifle and the zap all start here.").featured())
	descriptors.append(F.make_descriptor("Core", "ExplodeAt", "Explode At", ACEDescriptor.ACEType.ACTION, "\n".join(PackedStringArray([
		"var __blast_{uid} = PhysicsShapeQueryParameters3D.new()",
		"var __ball_{uid} = SphereShape3D.new()",
		"__ball_{uid}.radius = {radius}",
		"__blast_{uid}.shape = __ball_{uid}",
		"__blast_{uid}.transform = Transform3D(Basis(), {point})",
		"__blast_{uid}.collision_mask = {mask}",
		"for __caught_{uid} in get_world_3d().direct_space_state.intersect_shape(__blast_{uid}, 32):",
		"\tvar __body_{uid} = __caught_{uid}.collider",
		"\tvar __away_{uid} = __body_{uid}.global_position - {point}",
		"\tvar __falloff_{uid} = clampf(1.0 - __away_{uid}.length() / {radius}, 0.0, 1.0)",
		"\tif __body_{uid}.has_method(\"take_damage\"):",
		"\t\t__body_{uid}.take_damage({damage} * __falloff_{uid})",
		"\tif __body_{uid} is CharacterBody3D:",
		"\t\t__body_{uid}.velocity += __away_{uid}.normalized() * {push} * __falloff_{uid}",
		"\telif __body_{uid} is RigidBody3D:",
		"\t\t__body_{uid}.apply_impulse(__away_{uid}.normalized() * {push} * __falloff_{uid})"
	])), "", [
		F.make_param("point", "String", "global_position", "Point", "Where the blast goes off.", "expression"),
		F.make_param("radius", "String", "6.0", "Radius", "How far the blast reaches.", "expression"),
		F.make_param("damage", "String", "80", "Damage", "Damage at the centre, fading to nothing at the edge.", "expression"),
		F.make_param("push", "String", "12.0", "Push", "How hard bodies are thrown away from the point.", "expression"),
		F.make_param("mask", "String", "1", "Hits layers", "Which collision layers the blast can catch.", "physics_layer_3d")
	], WEAPONS, "Explode at {point} (radius {radius}, damage {damage})", "Node3D")
		.described("Damages and throws everything near a point, fading with distance. The push is real physics, so standing in your own blast throws you - which is how rocket jumping works.").featured())


## The arsenal: a list of weapons, an index into it, and the two ways a player changes it.
static func _arsenal(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "SwitchToNextWeapon", "Switch To Next Weapon", ACEDescriptor.ACEType.ACTION, "{index} = ({index} + 1) % {weapons}.size()", "", [F.make_param("index", "String", "weapon_index", "Current weapon", "The number variable holding which weapon is out.", "variable_reference"), F.make_param("weapons", "String", "weapons", "Weapons", "The list of weapons.", "variable_reference")], WEAPONS, "Switch to next weapon")
		.described("Moves to the next weapon in the list, wrapping round to the first after the last - the mouse wheel up.").featured())
	descriptors.append(F.make_descriptor("Core", "SwitchToPreviousWeapon", "Switch To Previous Weapon", ACEDescriptor.ACEType.ACTION, "{index} = ({index} - 1 + {weapons}.size()) % {weapons}.size()", "", [F.make_param("index", "String", "weapon_index", "Current weapon", "The number variable holding which weapon is out.", "variable_reference"), F.make_param("weapons", "String", "weapons", "Weapons", "The list of weapons.", "variable_reference")], WEAPONS, "Switch to previous weapon")
		.described("Moves to the weapon before this one, wrapping round to the last after the first - the mouse wheel down.").featured())
	descriptors.append(F.make_descriptor("Core", "CurrentWeapon", "Current Weapon", ACEDescriptor.ACEType.EXPRESSION, "{weapons}[{index}]", "", [F.make_param("weapons", "String", "weapons", "Weapons", "The list of weapons.", "variable_reference"), F.make_param("index", "String", "weapon_index", "Current weapon", "The number variable holding which weapon is out.", "variable_reference")], WEAPONS, "current weapon")
		.described("The weapon that is out right now - the name to look ammo up by and to show on the HUD.").featured())


## Secrets: the counter every shooter of this shape keeps, and the first-time-only test that feeds it.
static func _secrets(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "MarkSecretFound", "Mark Secret Found", ACEDescriptor.ACEType.ACTION, "if not {name} in {found}:\n\t{found}.append({name})", "", [F.make_param("name", "String", "\"secret\"", "Secret", "What this secret is called.", "expression"), F.make_param("found", "String", "secrets_found", "Found", "The list of secrets found so far.", "variable_reference")], WEAPONS, "Mark secret {name} found")
		.described("Records a secret the first time it is found and never again, so walking back through the room does not count twice.").featured())
	descriptors.append(F.make_descriptor("Core", "SecretsFoundCount", "Secrets Found", ACEDescriptor.ACEType.EXPRESSION, "{found}.size()", "", [F.make_param("found", "String", "secrets_found", "Found", "The list of secrets found so far.", "variable_reference")], WEAPONS, "secrets found")
		.described("How many secrets the player has found - the left-hand number of the end-of-level screen."))
	descriptors.append(F.make_descriptor("Core", "SecretAlreadyFound", "Secret Already Found", ACEDescriptor.ACEType.CONDITION, "({name} in {found})", "", [F.make_param("name", "String", "\"secret\"", "Secret", "What this secret is called.", "expression"), F.make_param("found", "String", "secrets_found", "Found", "The list of secrets found so far.", "variable_reference")], WEAPONS, "Secret {name} already found")
		.described("True when this secret has already been counted - the guard on the chime and the pop-up."))


static func section_descriptions() -> Dictionary:
	return {
		WEAPONS: "The shots, blasts and weapon switching a fast 3D shooter is made of. Movement is the FPS Controller behaviour's job.",
	}
