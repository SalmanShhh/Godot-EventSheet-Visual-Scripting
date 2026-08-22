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

## Y18. The other half of a level of this shape: what the things IN it do. Filed apart from the
## weapons because a reader looking for "why did the second guard come running" is not looking on
## the same page as one looking for the shotgun.
const ENEMIES := "Enemies 3D"
const PICKUPS := "Pickups"

## The middle of the screen, which is where a shooter's crosshair is and therefore where the shot
## comes from. One constant so the ray origin and the ray direction can never aim at two points.
const SCREEN_CENTRE := "get_viewport().get_visible_rect().size * 0.5"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_shooting(descriptors)
	_arsenal(descriptors)
	_secrets(descriptors)
	_enemies(descriptors)
	_pickups(descriptors)
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


## Y18. What a room full of enemies does. Alerting is the noise words aimed at somebody: a noise says
## "something happened over there", an alert says "it was HIM, go". Infighting is the one line in a
## hurt handler that turns a rocket splashed across a corridor into a brawl, and it is the reason a
## blast that catches two enemies is more interesting than one that catches one.
static func _enemies(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "AlertEnemiesWithin", "Alert Enemies Within",
		ACEDescriptor.ACEType.ACTION, "\n".join(PackedStringArray([
		# Dispatched BY NAME on each member rather than through a signal, exactly as Make Noise
		# dispatches `hear`: the enemies of a level come and go with the level and nothing is
		# connected to them, so a name is the only spelling that keeps working.
		"for __alerted_{uid} in get_tree().get_nodes_in_group({group}):",
		# Nobody is alerted about themselves: a hurt enemy shouting to the room would otherwise hear
		# its own shout and go looking for itself, which is a bug that reads as a very stupid enemy.
		"\tif __alerted_{uid} != {target} and __alerted_{uid}.global_position.distance_to({at}) < {radius}:",
		"\t\t__alerted_{uid}.alerted({target})"
	])), "", [
		F.make_param("at", "String", "global_position", "Around", "Where the alert goes out from (a position expression).", "expression"),
		F.make_param("radius", "String", "400.0", "Within", "How far the alert carries.", "expression"),
		F.make_param("target", "String", "self", "About", "Who they should be looking for.", "expression"),
		F.make_param("group", "String", "\"enemies\"", "Alerts", "The group whose members can be alerted - each one needs an On Alerted event.", "group_reference")
	], ENEMIES, "Alert enemies within [b]{radius}[/b] of [b]{at}[/b] to [i]{target}[/i]", "Node3D")
		.described("Tells every enemy close enough who to come for. The one that saw you shouts, and the room answers - the difference between fighting one guard and fighting a room.").featured())
	descriptors.append(F.make_descriptor("Core", "OnAlerted", "On Alerted", ACEDescriptor.ACEType.TRIGGER,
		"", "alerted", [], ENEMIES, "On alerted to")
		.described("Runs when an Alert Enemies Within action reaches this one, with who to go for. Put this object in the alerted group first (Add To Group, on created)."))
	descriptors.append(F.make_descriptor("Core", "RetaliateAgainstAttacker", "Retaliate Against Attacker",
		ACEDescriptor.ACEType.ACTION, "\n".join(PackedStringArray([
		"if {attacker}.is_in_group({group}):",
		"\t{target} = {attacker}"
	])), "", [
		F.make_param("attacker", "String", "attacker", "Attacker", "Whoever did the damage - the argument the hurt event was given.", "variable_reference"),
		F.make_param("group", "String", "\"enemies\"", "Who counts as one of them", "The group that turns on its own.", "group_reference"),
		F.make_param("target", "String", "target", "Target variable", "The variable holding who this one is going for.", "variable_reference")
	], ENEMIES, "Retaliate against [i]{attacker}[/i] (infighting)")
		.described("Makes this one turn on whoever hurt it, but only when the attacker is one of its own kind - so a rocket that splashes two of them starts a fight, and a rocket from you does not make them attack you twice.").featured())


## Y18. A pickup that comes back. Hiding it, waiting and showing it again is three lines and a state
## nobody enjoys getting right twice; here it is the row it always meant to be.
static func _pickups(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "RespawnAfter", "Respawn After",
		ACEDescriptor.ACEType.ACTION, "\n".join(PackedStringArray([
		"hide()",
		# Deferred on purpose: this row runs from inside the pickup's own walked-into callback, and
		# the physics server refuses a monitoring change while it is flushing its queries.
		"set_deferred(\"monitoring\", false)",
		"await get_tree().create_timer({seconds}).timeout",
		"show()",
		"set_deferred(\"monitoring\", true)"
	])), "", [
		F.make_param("seconds", "String", "30.0", "After seconds", "How long before it comes back.", "expression")
	], PICKUPS, "Respawn after [b]{seconds}[/b] seconds", "Area3D")
		.described("Takes the pickup away, waits, and puts it back - the health and ammo that keep a level playable on the way out. It stops being collectable while it is gone, so nothing picks up an invisible one.").featured())


static func section_descriptions() -> Dictionary:
	return {
		WEAPONS: "The shots, blasts and weapon switching a fast 3D shooter is made of. Movement is the FPS Controller behaviour's job.",
		ENEMIES: "What a room of enemies does about you: who they hear about, and who they turn on.",
		PICKUPS: "The health, ammo and armour lying around a level, and the clock that brings them back.",
	}
