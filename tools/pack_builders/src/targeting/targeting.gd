# Pack source - targeting. The behaviour code this pack ships, as real GDScript: highlighted,
# checked and breakpointable here, and assembled into the pack by Lib.pack_from_source.
# Every #region, and the body of every top-level func, is one piece of the sheet; everything
# else is scaffolding the pack declares for itself at build time and never reads from here.
extends Node2D

var host: Node2D = null

#region block_1
# --- Designer knobs (tune in the Inspector) ---
## The group the assist rows search when a row names none - the hostiles this node aims at.
@export var target_group: StringName = &"enemies"
## The default cone width in degrees, centred on the host's facing, that Lock On To Nearest
## searches when a row leaves its own cone at 0.
@export var lock_cone_degrees: float = 60.0
## The default reach in pixels a lock searches within, and the distance a held lock is lost past.
@export var lock_range: float = 400.0
## Whether a wall breaks a lock and hides a target from the assist rows. Off by default, because
## a raycast per frame is a cost a top-down shooter with no walls should not pay.
@export var require_line_of_sight: bool = false
## The physics layers a wall lives on, for the sight ray this pack casts when no Line Of Sight
## behaviour is attached to the host.
@export_flags_2d_physics var blocker_mask: int = 1
## How much Magnetism slows a turn while the aim is crossing a target: 1 is no slowing at all,
## 0 stops the turn dead. Half is the usual gentle drag.
@export var magnetism_slowdown: float = 0.5

# --- Internal state ---
# The node this behaviour is holding, or null. Written only through _take and _drop, so every
# lock and every loss announces itself exactly once.
var _target: Node2D = null
# The candidates the last Lock On To Nearest found, ordered left to right by their angle from
# the facing. Cycle Target walks this ring; nothing else writes it.
var _ring: Array[Node2D] = []
# Whether a target is being held right now. A separate flag rather than a test on _target,
# because a node that has been freed reads as null in GDScript: asking _target for its nullness
# would answer "nothing was ever held" for the one case this behaviour most has to announce,
# and the death would park the loss check silently instead of saying so.
var _holding: bool = false
# The reach the current lock was taken at, so a lock made with a row's own range is lost at that
# range rather than at the Inspector's. A lock made by NAMING a node is held at INF, because that
# row's whole promise is that it keeps what it was pointed at whatever the range says.
var _held_reach: float = 400.0

## @ace_trigger
## @ace_name("On Target Locked")
signal target_locked(target: Node2D)

## @ace_trigger
## @ace_name("On Target Lost")
signal target_lost(why: StringName)

## The aim-assist dial, read from the one place the accessibility rows write it. Zero is the
## honest off switch: no target is ever inside a radius of zero, so every assist row hands back
## exactly what it was given and the options screen turns the whole feature off with one slider.
## @ace_hidden
func _aim_assist_radius() -> float:
	return maxf(float(Engine.get_meta("aim_assist_radius", 0.0)), 0.0)

## Which way the cone points. In 2D that is the host's own rotation, the same facing the Line Of
## Sight behaviour measures its view fan around, so a guard and its lock agree about "in front".
## @ace_hidden
func _facing() -> Vector2:
	return Vector2.RIGHT.rotated(host.rotation) if host != null else Vector2.RIGHT

## Everything in a group, as the tree holds it. One seam, because a headless test has no tree and
## every row in this pack that searches goes through here.
## @ace_hidden
func _group_members(group: StringName) -> Array:
	if host == null or not host.is_inside_tree():
		return []
	var searched: StringName = group if not String(group).is_empty() else target_group
	return host.get_tree().get_nodes_in_group(searched)

## Whether nothing solid stands between two world points. A Line Of Sight behaviour attached to
## the same host answers it if there is one, so the two packs share one idea of a wall; otherwise
## this casts its own ray on blocker_mask. With sight checking off the answer is always yes.
## @ace_hidden
func _view_is_clear(from_point: Vector2, to_point: Vector2) -> bool:
	if not require_line_of_sight:
		return true
	if host == null:
		return false
	for child: Node in host.get_children():
		if child.has_method("has_los_between"):
			return bool(child.call("has_los_between", from_point, to_point))
	if not host.is_inside_tree():
		return true
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_point, to_point)
	query.collision_mask = blocker_mask
	return host.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

## Where a world point sits on screen right now - the canvas transform, which is the same
## arithmetic the built-in World Point To Screen expression writes.
## @ace_hidden
func _screen_point(world_point: Vector2) -> Vector2:
	if host == null or not host.is_inside_tree():
		return Vector2.ZERO
	return host.get_viewport().get_canvas_transform() * world_point

## The group members inside the cone and the reach, ordered left to right by their angle from the
## facing. That order is what makes Cycle Target predictable: the next target is the next one
## along, not whichever the tree happened to list second.
## @ace_hidden
func _ring_of(group: StringName, cone_degrees: float, reach: float) -> Array[Node2D]:
	var found: Array[Node2D] = []
	if host == null:
		return found
	var half: float = deg_to_rad(cone_degrees) * 0.5
	var facing: float = _facing().angle()
	for member: Node in _group_members(group):
		var candidate: Node2D = member as Node2D
		if candidate == null or candidate == host or not is_instance_valid(candidate):
			continue
		var offset: Vector2 = candidate.global_position - host.global_position
		if offset.length() > reach:
			continue
		if cone_degrees < 360.0 and absf(angle_difference(facing, offset.angle())) > half:
			continue
		if not _view_is_clear(host.global_position, candidate.global_position):
			continue
		found.append(candidate)
	var origin: Vector2 = host.global_position
	found.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var angle_a: float = angle_difference(facing, (a.global_position - origin).angle())
		var angle_b: float = angle_difference(facing, (b.global_position - origin).angle())
		if is_equal_approx(angle_a, angle_b):
			return origin.distance_to(a.global_position) < origin.distance_to(b.global_position)
		return angle_a < angle_b)
	return found

## The nearest thing the aim ray is pointing near enough to, inside the accessibility radius.
## "Near enough" is the perpendicular distance from the ray, which is what the shipped setting's
## own words mean by how far from dead centre a target still counts.
## @ace_hidden
func _nearest_under(aim: Vector2) -> Node2D:
	var radius: float = _aim_assist_radius()
	if radius <= 0.0 or host == null or aim.is_zero_approx():
		return null
	var ray: Vector2 = aim.normalized()
	var origin: Vector2 = host.global_position
	var best: Node2D = null
	var best_along: float = INF
	for member: Node in _group_members(&""):
		var candidate: Node2D = member as Node2D
		if candidate == null or candidate == host or not is_instance_valid(candidate):
			continue
		var offset: Vector2 = candidate.global_position - origin
		var along: float = offset.dot(ray)
		if along <= 0.0 or along > lock_range or along >= best_along:
			continue
		if absf(offset.cross(ray)) > radius:
			continue
		if not _view_is_clear(origin, candidate.global_position):
			continue
		best = candidate
		best_along = along
	return best

## Takes a node as the held target and says so once. Locking on to what is already held is not a
## new lock, so a row polled every frame does not fire On Target Locked every frame.
## @ace_hidden
func _take(candidate: Node2D) -> void:
	if candidate == null or candidate == _target:
		return
	_target = candidate
	_holding = true
	set_process(true)
	target_locked.emit(candidate)

## Lets the held target go and says why. Every ending goes through here - a death, a target that
## walked out of reach, a wall, and a deliberate Release Lock - so one On Target Lost row cleans
## up after all four and the reason word tells them apart.
## @ace_hidden
func _drop(why: StringName) -> void:
	if not _holding:
		return
	_target = null
	_holding = false
	set_process(false)
	target_lost.emit(why)
#endregion

func _ready() -> void:
	# Nothing to watch until something is held: the per-frame loss check starts with the first
	# lock and stops with the last, so an unlocked node costs nothing per frame.
	set_process(false)

func _process(_delta: float) -> void:
	if not _holding:
		set_process(false)
		return
	# A freed target is lost the frame it dies, which is why this check comes before every other
	# one: reading a position off a freed node is the crash this row exists to prevent.
	if not is_instance_valid(_target) or _target.is_queued_for_deletion():
		_drop(&"died")
		return
	if host == null:
		return
	if host.global_position.distance_to(_target.global_position) > _held_reach:
		_drop(&"out_of_range")
		return
	if not _view_is_clear(host.global_position, _target.global_position):
		_drop(&"blocked")

func lock_nearest(group: StringName, cone_degrees: float, max_range: float) -> void:
	var cone: float = cone_degrees if cone_degrees > 0.0 else lock_cone_degrees
	var reach: float = max_range if max_range > 0.0 else lock_range
	_ring = _ring_of(group, cone, reach)
	if _ring.is_empty():
		return
	var origin: Vector2 = host.global_position if host != null else Vector2.ZERO
	var best: Node2D = _ring[0]
	for candidate: Node2D in _ring:
		if origin.distance_to(candidate.global_position) < origin.distance_to(best.global_position):
			best = candidate
	_held_reach = reach
	_take(best)

func lock_on_to(node: Node2D) -> void:
	if node == null:
		return
	var only: Array[Node2D] = [node]
	_ring = only
	# NO REACH AT ALL. The row says it holds the node you name whatever the cone and the range say,
	# and a boss the cutscene points at is routinely farther off than the lock range - so a reach of
	# lock_range dropped it as out_of_range on the very next frame, one frame after On Target Locked.
	# The target dying and a wall coming between still end it; the distance does not.
	_held_reach = INF
	_take(node)

func cycle_target() -> void:
	var living: Array[Node2D] = []
	for candidate: Node2D in _ring:
		if is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			living.append(candidate)
	_ring = living
	if _ring.is_empty():
		return
	# find() answers -1 when nothing is held, and -1 + 1 is the first entry - so cycling with no
	# lock takes the leftmost candidate, and cycling off the last one wraps round to it too.
	var next: int = (_ring.find(_target) + 1) % _ring.size()
	_take(_ring[next])

func release_lock() -> void:
	_drop(&"released")

func is_locked_on() -> bool:
	return _holding and is_instance_valid(_target)

func locked_target() -> Node2D:
	return _target if is_locked_on() else null

func locked_target_on_screen() -> Vector2:
	return _screen_point(_target.global_position) if is_locked_on() else Vector2.ZERO

func distance_to_target() -> float:
	if not is_locked_on() or host == null:
		return INF
	return host.global_position.distance_to(_target.global_position)

func assisted_aim(direction: Vector2, strength: float) -> Vector2:
	if direction.is_zero_approx():
		return direction
	var best: Node2D = _nearest_under(direction)
	if best == null or host == null:
		return direction
	var toward: Vector2 = (best.global_position - host.global_position).normalized()
	return direction.normalized().slerp(toward, clampf(strength, 0.0, 1.0)) * direction.length()

func magnetism(turn_rate: float) -> float:
	if host == null or _nearest_under(_facing()) == null:
		return turn_rate
	return turn_rate * clampf(magnetism_slowdown, 0.0, 1.0)
