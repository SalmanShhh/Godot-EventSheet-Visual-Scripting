# Pack source - flock. The behaviour code this pack ships, as real GDScript: highlighted,
# checked and breakpointable here, and assembled into the pack by Lib.pack_from_source.
# Every #region, and the body of every top-level func, is one piece of the sheet; everything
# else is scaffolding the pack declares for itself at build time and never reads from here.
extends Node2D

var host: Node2D = null

#region block_1
# --- Designer knobs (tune in the Inspector) ---
## The group whose members fly together. The host joins it when it enters the scene, so every
## node carrying this behaviour with the same group name is one flock - and anything else you put
## in that group by hand counts as a neighbour too.
@export var flock_group: StringName = &"flock"
## How far a member looks for neighbours, in pixels. Only members inside this circle are steered
## by: a bird reacts to the birds around it, never to the whole sky.
@export var neighbour_radius: float = 120.0
## Closer than this a neighbour is too close, and separation pushes away from it - harder the
## closer it is. Make it a little more than the width of the sprite and members never overlap.
@export var separation_radius: float = 40.0
## How strongly a member keeps its distance from neighbours that are too close.
@export var separation_weight: float = 1.5
## How strongly a member turns to fly the way its neighbours are flying.
@export var alignment_weight: float = 1.0
## How strongly a member is drawn toward the middle of its neighbours.
@export var cohesion_weight: float = 1.0
## The slowest a member flies, in pixels per second. Above zero, a flock never stalls in mid-air.
@export var min_speed: float = 60.0
## The fastest a member flies, in pixels per second.
@export var max_speed: float = 180.0
## How quickly a member may change its velocity, in pixels per second per second, for each of the
## three rules. Low turns in wide, lazy arcs; high snaps round on the spot.
@export var max_force: float = 360.0
## A group the flock keeps away from - a predator, the player, a wall of hazards. Empty avoids
## nothing.
@export var avoid_group: StringName = &""
## How close a member of the avoid group has to be before the flock reacts, in pixels.
@export var avoid_radius: float = 160.0
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
## The velocity this member is flying at, in pixels per second. Neighbours read it to align with
## this one, and a row can read it to aim a trail or pitch a wing-beat sound.
var flock_velocity: Vector2 = Vector2.ZERO

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
func _velocity_of(member: Node2D) -> Vector2:
	for child: Node in member.get_children():
		if child.get_script() == get_script():
			var flying: Vector2 = child.get("flock_velocity")
			return flying
	if member is CharacterBody2D:
		return (member as CharacterBody2D).velocity
	if member is RigidBody2D:
		return (member as RigidBody2D).linear_velocity
	return Vector2.ZERO

## The change of velocity that turns this member toward a direction at full speed, no larger than
## max force - the one shape all three rules and the avoid group are steered through.
## @ace_hidden
func _steer_toward(direction: Vector2) -> Vector2:
	if direction.is_zero_approx():
		return Vector2.ZERO
	return (direction.normalized() * max_speed - flock_velocity).limit_length(max_force)

## The direction away from a neighbour that sits exactly on top of this member. Two members on one
## spot would otherwise push each other along the same line and never part, so each one leaves
## along an angle of its own, fixed for its lifetime: a hash of its instance id spread over the
## whole turn, where a remainder by 360 gave two members a one-in-360 chance of the same angle.
## @ace_hidden
func _away_from_the_same_spot() -> Vector2:
	return Vector2.RIGHT.rotated(float(hash(get_instance_id())) / 4294967296.0 * TAU)

## The velocity after one step of the three rules and the avoid group: separation from the
## neighbours that are too close, alignment with the way the neighbours fly, cohesion toward their
## middle, and a flight from anything in the avoid group nearby. Clamped between the two speeds.
## @ace_hidden
func _next_velocity(delta: float) -> Vector2:
	var here: Vector2 = host.global_position
	var apart: Vector2 = Vector2.ZERO
	var heading_sum: Vector2 = Vector2.ZERO
	var middle_sum: Vector2 = Vector2.ZERO
	var count: int = 0
	for member: Node in _group_members(flock_group):
		var other: Node2D = member as Node2D
		if other == null or other == host or not is_instance_valid(other):
			continue
		var offset: Vector2 = here - other.global_position
		var distance: float = offset.length()
		if distance > neighbour_radius:
			continue
		count += 1
		heading_sum += _velocity_of(other)
		middle_sum += other.global_position
		if distance < separation_radius:
			var away: Vector2 = offset / distance if distance > 0.0 else _away_from_the_same_spot()
			apart += away * (1.0 - distance / separation_radius)
	var steering: Vector2 = Vector2.ZERO
	if count > 0:
		steering += _steer_toward(heading_sum / count) * alignment_weight
		steering += _steer_toward(middle_sum / count - here) * cohesion_weight
	steering += _steer_toward(apart) * separation_weight
	var flee: Vector2 = Vector2.ZERO
	for member: Node in _group_members(avoid_group):
		var threat: Node2D = member as Node2D
		if threat == null or threat == host or not is_instance_valid(threat):
			continue
		var from_threat: Vector2 = here - threat.global_position
		var gap: float = from_threat.length()
		if gap < avoid_radius:
			var escape: Vector2 = from_threat / gap if gap > 0.0 else _away_from_the_same_spot()
			flee += escape * (1.0 - gap / avoid_radius)
	steering += _steer_toward(flee) * avoid_weight
	var next: Vector2 = flock_velocity + steering * delta
	var speed: float = next.length()
	if speed > max_speed:
		next *= max_speed / speed
	elif speed < min_speed and speed > 0.0:
		next *= min_speed / speed
	return next
#endregion

func _ready() -> void:
	if host != null:
		if not String(flock_group).is_empty():
			host.add_to_group(flock_group)
		# A member placed without a velocity sets off the way it faces, so a flock laid out by hand
		# in the editor flies the way it was drawn.
		if flock_velocity.is_zero_approx():
			flock_velocity = Vector2.RIGHT.rotated(host.rotation) * min_speed
	# The steering only runs while flocking is on - a member authored with it off costs nothing per
	# physics frame until Set Flocking Enabled turns it on.
	set_physics_process(flocking_enabled)

func _physics_process(delta: float) -> void:
	if not flocking_enabled or host == null:
		return
	flock_velocity = _next_velocity(delta)
	if face_heading and not flock_velocity.is_zero_approx():
		host.rotation = flock_velocity.angle()
	# A CharacterBody2D flies with move_and_slide, so walls stop it the way they stop anything
	# else; any other node is simply moved along.
	var body: CharacterBody2D = host as CharacterBody2D
	if body != null:
		body.velocity = flock_velocity
		body.move_and_slide()
		flock_velocity = body.velocity
	else:
		host.global_position += flock_velocity * delta

func set_flock_weights(separation: float, alignment: float, cohesion: float) -> void:
	separation_weight = separation
	alignment_weight = alignment
	cohesion_weight = cohesion

func set_flock_speeds(minimum: float, maximum: float) -> void:
	min_speed = maxf(minimum, 0.0)
	max_speed = maxf(maximum, min_speed)

func set_max_force(force: float) -> void:
	max_force = maxf(force, 0.0)

func set_flock_radii(neighbours: float, too_close: float) -> void:
	neighbour_radius = maxf(neighbours, 0.0)
	separation_radius = maxf(too_close, 0.0)

func set_avoid_group(group: StringName, radius: float, weight: float) -> void:
	avoid_group = group
	avoid_radius = maxf(radius, 0.0)
	avoid_weight = weight

func set_flock_group(group: StringName) -> void:
	# Leaving the old flock and joining the new one in a single row, so a bird that is told to
	# follow another flock is never counted by both.
	if host != null:
		if host.is_in_group(flock_group):
			host.remove_from_group(flock_group)
		if not String(group).is_empty():
			host.add_to_group(group)
	flock_group = group

func set_flocking_enabled(enabled: bool) -> void:
	flocking_enabled = enabled
	# Flocking off means no steering to run, so stop paying for the physics frame.
	set_physics_process(enabled)
