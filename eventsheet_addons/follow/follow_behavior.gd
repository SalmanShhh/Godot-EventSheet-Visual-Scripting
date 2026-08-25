## @ace_category("Follow")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/follow/icon.svg")
class_name FollowBehavior
extends Node
## Makes the host Node2D trail another node every frame, either easing smoothly toward it or replaying its path with a delay. Built for pets, homing shots, camera dummies, and snake tails without hand-writing lerp code on every object.

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("FollowBehavior behavior requires a Node2D parent.")

## @ace_trigger
## @ace_name("On Reached Target")
signal reached_target
## @ace_trigger
## @ace_name("On Path Blocked")
signal path_blocked

var _blocked: bool = false
var _reached: bool = false
var clock: float = 0.0
## In delayed mode, how many seconds behind the target's recorded path the host trails.
@export var delay: float = 0.4
## In smooth mode, how quickly the host chases the target each second (higher is snappier).
@export var follow_speed: float = 5.0
var following: bool = true
var history: Array = []
## In smooth mode, stops and fires On Reached Target once within this many pixels of the target.
@export var min_distance: float = 0.0
## smooth lerps toward the target each frame; delayed replays the target's past positions.
@export_enum("smooth", "delayed") var mode: String = "smooth"
## Also stop the sweep on Area2D nodes, which it ignores by default.
@export var step_hits_areas: bool = false
## Collision layers the swept path tests against. Each layer is a bit, so layers 1 and 3 are 1 + 4 = 5.
@export var step_mask: int = 1
## In SMOOTH mode, sweep the path each frame instead of lerping straight there, so a fast chase cannot pass through a thin wall between two frames. Delayed mode ignores it, since retracing the target's recorded path is the point of that mode.
@export var stepping: bool = false
## Follow the first node in this GROUP instead of a path - no tree path, so it survives the target being moved or renamed. Takes priority over Target Path; leave blank to use the path.
@export var target_group: String = ""
## Node path (relative to the host) of the node to follow; empty means idle.
@export var target_path: String = ""

func _process(delta: float) -> void:
	if host == null:
		return
	# Resolve by GROUP first (no tree path, so it survives the target being moved or renamed),
	# otherwise fall back to the explicit path.
	var target: Node = null
	if target_group != "":
		target = get_tree().get_first_node_in_group(target_group)
	elif target_path != "":
		target = host.get_node_or_null(NodePath(target_path))
	if not (target is Node2D):
		return
	var target_2d := target as Node2D
	clock += delta
	history.append([clock, target_2d.position])
	while history.size() > 2 and float(history[0][0]) < clock - delay - 1.0:
		history.pop_front()
	if not following:
		return
	if mode == "delayed":
		var sample_time := clock - delay
		for entry: Array in history:
			if float(entry[0]) >= sample_time:
				host.position = entry[1]
				break
		return
	if host.position.distance_to(target_2d.position) <= min_distance:
		if not _reached:
			_reached = true
			reached_target.emit()
		return
	_reached = false
	host.position = step_toward(host.position, host.position.lerp(target_2d.position, clampf(follow_speed * delta, 0.0, 1.0)))

## @ace_action
## @ace_name("Start Following")
## @ace_category("Follow")
## @ace_description("Follows the node at the given path.")
## @ace_icon("res://eventsheet_addons/follow/icon.svg")
## @ace_codegen_template("$FollowBehavior.start_following({path})")
func start_following(path: String) -> void:
	target_path = path
	target_group = ""
	following = true
	history = []

## @ace_action
## @ace_name("Follow Group")
## @ace_category("Follow")
## @ace_description("Follows the first node in a group - no tree path, so it survives the target being moved or renamed.")
## @ace_icon("res://eventsheet_addons/follow/icon.svg")
## @ace_codegen_template("$FollowBehavior.follow_group({group})")
func follow_group(group: String) -> void:
	target_group = group
	target_path = ""
	following = true
	history = []

## @ace_action
## @ace_name("Stop Following")
## @ace_category("Follow")
## @ace_description("Stops trailing the target.")
## @ace_icon("res://eventsheet_addons/follow/icon.svg")
## @ace_codegen_template("$FollowBehavior.stop_following()")
func stop_following() -> void:
	following = false

## The furthest point on the way to `to` that is actually reachable this frame.
##
## The smooth chase sets position outright, so a fast follow_speed can cross a thin wall entirely
## between two frames and never touch it. With Stepping on, a swept ray finds what the chase
## skipped and returns the contact point instead. Positions are in the parent's space, so the
## sweep converts by offsetting the host's global position by the same delta.
##
## Delayed mode never calls this: replaying the target's recorded path exactly IS that mode.
func step_toward(from: Vector2, to: Vector2) -> Vector2:
	if not stepping or from == to or host == null or not host.is_inside_tree():
		return to
	var world_from: Vector2 = host.global_position
	var step_query := PhysicsRayQueryParameters2D.create(world_from, world_from + (to - from), step_mask, [])
	step_query.collide_with_areas = step_hits_areas
	var step_hit := host.get_world_2d().direct_space_state.intersect_ray(step_query)
	if step_hit.is_empty():
		_blocked = false
		return to
	# EDGE-triggered, mirroring _reached above. A chase has no stop flag by design - it keeps
	# pressing at the wall - so emitting on every blocked frame would make the trigger useless.
	if not _blocked:
		_blocked = true
		path_blocked.emit()
	var contact: Vector2 = step_hit.get("position", world_from)
	# Park just SHORT of the surface, never exactly on it: a ray that STARTS on a shape does not
	# report that shape (hit-from-inside is off), so a chaser left touching the wall sails straight
	# through on the next frame's sweep. Half a pixel of clearance keeps the next ray honest.
	return from + (contact - (to - from).normalized() * 0.5 - world_from)

# Follow behavior (event-sheet parity): trails another node. mode smooth = lerp chase; mode delayed = replay the target's position history after a delay (the Follow behavior).
