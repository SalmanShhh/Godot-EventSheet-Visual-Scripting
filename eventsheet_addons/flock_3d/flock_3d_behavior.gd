## @ace_tags(movement, steering, group)
## @ace_category("Flock 3D")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/flock_3d/icon.svg")
class_name Flock3DBehavior
extends Node
## Flocking for a Node3D: every member of a group steers by the members around it - keep apart from the ones too close, fly the way the rest are flying, drift toward their middle - and flees anything in an avoid group. Weights, speeds, the steering force and both radii are Inspector values with a Set row each.

## The node this behavior acts on (its parent). Required host: Node3D.
var host: Node3D = null

func _enter_tree() -> void:
	host = get_parent() as Node3D
	if host == null:
		push_warning("Flock3DBehavior behavior requires a Node3D parent.")

# --- Designer knobs (tune in the Inspector) ---
## The group whose members fly together. The host joins it when it enters the scene, so every
## node carrying this behaviour with the same group name is one flock - and anything else you put
## in that group by hand counts as a neighbour too.
@export var flock_group: StringName = &"flock"
## How far a member looks for neighbours, in metres. Only members inside this sphere are steered
## by: a bird reacts to the birds around it, never to the whole sky.
@export var neighbour_radius: float = 4.0
## Closer than this a neighbour is too close, and separation pushes away from it - harder the
## closer it is. Make it a little more than the width of the model and members never overlap.
@export var separation_radius: float = 1.2
## How strongly a member keeps its distance from neighbours that are too close.
@export var separation_weight: float = 1.5
## How strongly a member turns to fly the way its neighbours are flying.
@export var alignment_weight: float = 1.0
## How strongly a member is drawn toward the middle of its neighbours.
@export var cohesion_weight: float = 1.0
## The slowest a member flies, in metres per second. Above zero, a flock never stalls in mid-air.
@export var min_speed: float = 2.0
## The fastest a member flies, in metres per second.
@export var max_speed: float = 6.0
## How quickly a member may change its velocity, in metres per second per second, for each of the
## three rules. Low turns in wide, lazy arcs; high snaps round on the spot.
@export var max_force: float = 12.0
## A group the flock keeps away from - a predator, the player, a wall of hazards. Empty avoids
## nothing.
@export var avoid_group: StringName = &""
## How close a member of the avoid group has to be before the flock reacts, in metres.
@export var avoid_radius: float = 5.0
## How strongly the flock flees the avoid group. Higher than the other weights, so fear wins.
@export var avoid_weight: float = 3.0
## Turns the host to face the way it is flying.
@export var face_heading: bool = true
## Master on/off - Set Flocking Enabled flips it at runtime.
@export var flocking_enabled: bool = true:
	set(value):
		flocking_enabled = value
		# Every write lands here - a sheet's Set Flocking Enabled action, the Inspector, another
		# script - so the steering stops and restarts with the knob whoever switched it.
		set_physics_process(value)

# --- Internal state ---
## The velocity this member is flying at, in metres per second. Neighbours read it to align with
## this one, and a row can read it to aim a trail or pitch a wing-beat sound.
var flock_velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	if host != null:
		if not String(flock_group).is_empty():
			host.add_to_group(flock_group)
		# A member placed without a velocity sets off the way it faces, so a flock laid out by hand
		# in the editor flies the way it was drawn - along its forward, -Z.
		if flock_velocity.is_zero_approx():
			flock_velocity = -host.basis.z.normalized() * min_speed
	# The steering only runs while flocking is on - a member authored with it off costs nothing per
	# physics frame until Set Flocking Enabled turns it on.
	set_physics_process(flocking_enabled)

func _physics_process(delta: float) -> void:
	if not flocking_enabled or host == null:
		return
	flock_velocity = _next_velocity(delta)
	if face_heading and not flock_velocity.is_zero_approx():
		_face_along(flock_velocity)
	# A CharacterBody3D flies with move_and_slide, so walls stop it the way they stop anything
	# else; any other node is simply moved along.
	var body: CharacterBody3D = host as CharacterBody3D
	if body != null:
		body.velocity = flock_velocity
		body.move_and_slide()
		flock_velocity = body.velocity
	elif host.is_inside_tree():
		host.global_position += flock_velocity * delta
	else:
		host.position += flock_velocity * delta

## @ace_action
## @ace_featured
## @ace_name("Set Flock Weights")
## @ace_category("Flock 3D")
## @ace_description("Sets how strongly the three rules pull: separation keeps members apart, alignment turns them the way their neighbours fly, cohesion draws them toward their neighbours' middle. Zero switches a rule off; a weight is relative to the other two.")
## @ace_display_template("flock with separation [b]{separation}[/b], alignment [b]{alignment}[/b], cohesion [b]{cohesion}[/b]")
## @ace_icon("res://eventsheet_addons/flock_3d/icon.svg")
## @ace_codegen_template("$Flock3DBehavior.set_flock_weights({separation}, {alignment}, {cohesion})")
func set_flock_weights(separation: float, alignment: float, cohesion: float) -> void:
	separation_weight = separation
	alignment_weight = alignment
	cohesion_weight = cohesion

## @ace_action
## @ace_name("Set Flock Speeds")
## @ace_category("Flock 3D")
## @ace_description("Sets the slowest and the fastest a member flies, in metres per second. A maximum below the minimum is raised to it, so the two can never cross.")
## @ace_display_template("fly between [b]{minimum}[/b] and [b]{maximum}[/b] m/s")
## @ace_icon("res://eventsheet_addons/flock_3d/icon.svg")
## @ace_codegen_template("$Flock3DBehavior.set_flock_speeds({minimum}, {maximum})")
func set_flock_speeds(minimum: float, maximum: float) -> void:
	min_speed = maxf(minimum, 0.0)
	max_speed = maxf(maximum, min_speed)

## @ace_action
## @ace_name("Set Max Force")
## @ace_category("Flock 3D")
## @ace_description("Sets how quickly a member may change its velocity, in metres per second per second, for each rule. Low turns in wide arcs; high turns on the spot.")
## @ace_display_template("steer with at most [b]{force}[/b] force")
## @ace_icon("res://eventsheet_addons/flock_3d/icon.svg")
## @ace_codegen_template("$Flock3DBehavior.set_max_force({force})")
func set_max_force(force: float) -> void:
	max_force = maxf(force, 0.0)

## @ace_action
## @ace_name("Set Flock Radii")
## @ace_category("Flock 3D")
## @ace_description("Sets how far a member looks for neighbours, and how close a neighbour may come before separation pushes it away. Make the second a little wider than the model and members never overlap.")
## @ace_display_template("see neighbours within [b]{neighbours}[/b], keep [b]{too_close}[/b] apart")
## @ace_icon("res://eventsheet_addons/flock_3d/icon.svg")
## @ace_codegen_template("$Flock3DBehavior.set_flock_radii({neighbours}, {too_close})")
func set_flock_radii(neighbours: float, too_close: float) -> void:
	neighbour_radius = maxf(neighbours, 0.0)
	separation_radius = maxf(too_close, 0.0)

## @ace_action
## @ace_featured
## @ace_name("Set Avoid Group")
## @ace_category("Flock 3D")
## @ace_description("Sets the group the flock flees - a predator, the player, a hazard - how close it must come before the flock reacts, and how strongly it flees. An empty group avoids nothing.")
## @ace_display_template("flee [b]{group}[/b] within [b]{radius}[/b], weight [b]{weight}[/b]")
## @ace_icon("res://eventsheet_addons/flock_3d/icon.svg")
## @ace_codegen_template("$Flock3DBehavior.set_avoid_group({group}, {radius}, {weight})")
func set_avoid_group(group: StringName, radius: float, weight: float) -> void:
	avoid_group = group
	avoid_radius = maxf(radius, 0.0)
	avoid_weight = weight

## @ace_action
## @ace_name("Set Flock Group")
## @ace_category("Flock 3D")
## @ace_description("Moves the host from its flock to another one in a single row: it leaves the old group and joins the new, so it is never counted by both.")
## @ace_display_template("fly with the [b]{group}[/b] flock")
## @ace_icon("res://eventsheet_addons/flock_3d/icon.svg")
## @ace_codegen_template("$Flock3DBehavior.set_flock_group({group})")
func set_flock_group(group: StringName) -> void:
	# Leaving the old flock and joining the new one in a single row, so a bird that is told to
	# follow another flock is never counted by both.
	if host != null:
		if host.is_in_group(flock_group):
			host.remove_from_group(flock_group)
		if not String(group).is_empty():
			host.add_to_group(group)
	flock_group = group

## @ace_action
## @ace_name("Set Flocking Enabled")
## @ace_category("Flock 3D")
## @ace_description("Turns the steering on or off at runtime. Off, the host keeps still and costs nothing per frame; on again, it flies off at the velocity it had.")
## @ace_display_template("Set flocking to [b]{enabled}[/b]")
## @ace_icon("res://eventsheet_addons/flock_3d/icon.svg")
## @ace_codegen_template("$Flock3DBehavior.set_flocking_enabled({enabled})")
func set_flocking_enabled(enabled: bool) -> void:
	flocking_enabled = enabled
	# Flocking off means no steering to run, so stop paying for the physics frame.
	set_physics_process(enabled)

## Everything in a group, as the tree holds it. One seam, because a headless test has no tree and
## both group searches in this pack go through here.
## @ace_hidden
func _group_members(group: StringName) -> Array:
	if host == null or not host.is_inside_tree() or String(group).is_empty():
		return []
	return host.get_tree().get_nodes_in_group(group)

## How fast a neighbour is flying. A neighbour carrying this same behaviour answers with its own
## flock velocity; a physics body answers with its velocity; anything else is standing still.
## @ace_hidden
func _velocity_of(member: Node3D) -> Vector3:
	for child: Node in member.get_children():
		if child.get_script() == get_script():
			var flying: Vector3 = child.get("flock_velocity")
			return flying
	if member is CharacterBody3D:
		return (member as CharacterBody3D).velocity
	if member is RigidBody3D:
		return (member as RigidBody3D).linear_velocity
	return Vector3.ZERO

## The change of velocity that turns this member toward a direction at full speed, no larger than
## max force - the one shape all three rules and the avoid group are steered through.
## @ace_hidden
func _steer_toward(direction: Vector3) -> Vector3:
	if direction.is_zero_approx():
		return Vector3.ZERO
	return (direction.normalized() * max_speed - flock_velocity).limit_length(max_force)

## The direction away from a neighbour that sits exactly on top of this member. Two members on one
## spot would otherwise push each other along the same line and never part, so each one leaves
## along an angle of its own, fixed for its lifetime: a hash of its instance id spread over the
## whole turn, where a remainder by 360 gave two members a one-in-360 chance of the same angle.
## @ace_hidden
func _away_from_the_same_spot() -> Vector3:
	return Vector3.RIGHT.rotated(Vector3.UP, float(hash(get_instance_id())) / 4294967296.0 * TAU)

## Where a node is in the world. A node outside the scene tree has no global transform to ask, so
## its own position stands in - which is what a headless test, and a member not yet added, has.
## @ace_hidden
func _place_of(node: Node3D) -> Vector3:
	return node.global_position if node.is_inside_tree() else node.position

## Turns the host to look along its flight, keeping its scale. Flying straight up or down has no
## single "level" way to face, so the host keeps the facing it had until it turns again.
## @ace_hidden
func _face_along(direction: Vector3) -> void:
	var forward: Vector3 = direction.normalized()
	if absf(forward.dot(Vector3.UP)) > 0.999:
		return
	host.basis = Basis.looking_at(forward, Vector3.UP) * Basis.from_scale(host.scale)

## The velocity after one step of the three rules and the avoid group: separation from the
## neighbours that are too close, alignment with the way the neighbours fly, cohesion toward their
## middle, and a flight from anything in the avoid group nearby. Clamped between the two speeds.
## @ace_hidden
func _next_velocity(delta: float) -> Vector3:
	var here: Vector3 = _place_of(host)
	var apart: Vector3 = Vector3.ZERO
	var heading_sum: Vector3 = Vector3.ZERO
	var middle_sum: Vector3 = Vector3.ZERO
	var count: int = 0
	for member: Node in _group_members(flock_group):
		var other: Node3D = member as Node3D
		if other == null or other == host or not is_instance_valid(other):
			continue
		var offset: Vector3 = here - _place_of(other)
		var distance: float = offset.length()
		if distance > neighbour_radius:
			continue
		count += 1
		heading_sum += _velocity_of(other)
		middle_sum += _place_of(other)
		if distance < separation_radius:
			var away: Vector3 = offset / distance if distance > 0.0 else _away_from_the_same_spot()
			apart += away * (1.0 - distance / separation_radius)
	var steering: Vector3 = Vector3.ZERO
	if count > 0:
		steering += _steer_toward(heading_sum / count) * alignment_weight
		steering += _steer_toward(middle_sum / count - here) * cohesion_weight
	steering += _steer_toward(apart) * separation_weight
	var flee: Vector3 = Vector3.ZERO
	for member: Node in _group_members(avoid_group):
		var threat: Node3D = member as Node3D
		if threat == null or threat == host or not is_instance_valid(threat):
			continue
		var from_threat: Vector3 = here - _place_of(threat)
		var gap: float = from_threat.length()
		if gap < avoid_radius:
			var escape: Vector3 = from_threat / gap if gap > 0.0 else _away_from_the_same_spot()
			flee += escape * (1.0 - gap / avoid_radius)
	steering += _steer_toward(flee) * avoid_weight
	var next: Vector3 = flock_velocity + steering * delta
	var speed: float = next.length()
	if speed > max_speed:
		next *= max_speed / speed
	elif speed < min_speed and speed > 0.0:
		next *= min_speed / speed
	return next

# Flock 3D behavior: attach it under every bird, fish or bat that should fly together. Each member looks at the members of its flock group inside the neighbour radius and blends three pushes: separation from the ones too close, alignment with the way they fly, cohesion toward their middle. An avoid group is fled on top. A CharacterBody3D host flies with move_and_slide; any other Node3D is moved along. The host turns to look the way it flies. This pack is an event sheet - extend it by editing it.
