## @ace_category("Move To 3D")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/move_to_3d/icon.svg")
class_name MoveTo3DBehavior
extends Node
## Point-to-point movement for any Node3D: hand it Vector3 targets and it glides the host straight toward each one at a steady speed, popping waypoints off a queue and firing On Arrived at the last stop. Attach under a drone, elevator, pickup, or camera rig and tune the pace with the single max_speed knob.

## The node this behavior acts on (its parent). Required host: Node3D.
var host: Node3D = null

func _enter_tree() -> void:
	host = get_parent() as Node3D
	if host == null:
		push_warning("MoveTo3DBehavior behavior requires a Node3D parent.")

## @ace_trigger
## @ace_name("On Arrived (3D)")
signal arrived
## @ace_trigger
## @ace_name("On Path Blocked (3D)")
signal path_blocked

## Units per second the host glides toward each waypoint.
@export var max_speed: float = 5.0
## Sweep the path each frame instead of gliding straight to the next point, so a fast mover cannot pass through thin geometry between two frames.
@export var stepping: bool = false
## Collision layers the swept path tests against. Each layer is a bit, so layers 1 and 3 are 1 + 4 = 5.
@export var step_mask: int = 1
## Also stop the sweep on Area3D nodes, which it ignores by default.
@export var step_hits_areas: bool = false
## Drop the waypoint queue and stop when the path is blocked. Turn off to keep pushing at the obstacle and just report it.
@export var stop_on_step_hit: bool = true
var waypoints: Array = []
var moving: bool = false

func _process(delta: float) -> void:
	if not moving or host == null or waypoints.is_empty():
		return
	var target: Vector3 = waypoints[0]
	host.position = step_toward(host.position, host.position.move_toward(target, max_speed * delta))
	if host.position.distance_to(target) < 0.05:
		waypoints.pop_front()
		if waypoints.is_empty():
			moving = false
			arrived.emit()

## @ace_action
## @ace_name("Move To Position (3D)")
## @ace_category("Move To 3D")
## @ace_description("Replaces the queue and glides toward the point.")
## @ace_icon("res://eventsheet_addons/move_to_3d/icon.svg")
## @ace_codegen_template("$MoveTo3DBehavior.move_to_position_3d({x}, {y}, {z})")
func move_to_position_3d(x: float, y: float, z: float) -> void:
	waypoints = [Vector3(x, y, z)]
	moving = true

## @ace_action
## @ace_name("Add Waypoint (3D)")
## @ace_category("Move To 3D")
## @ace_description("Appends a stop to the queue.")
## @ace_icon("res://eventsheet_addons/move_to_3d/icon.svg")
## @ace_codegen_template("$MoveTo3DBehavior.add_waypoint_3d({x}, {y}, {z})")
func add_waypoint_3d(x: float, y: float, z: float) -> void:
	waypoints.append(Vector3(x, y, z))
	moving = true

## @ace_action
## @ace_name("Stop Moving (3D)")
## @ace_category("Move To 3D")
## @ace_description("Clears the queue without firing On Arrived.")
## @ace_icon("res://eventsheet_addons/move_to_3d/icon.svg")
## @ace_codegen_template("$MoveTo3DBehavior.stop_moving_3d()")
func stop_moving_3d() -> void:
	moving = false
	waypoints = []

## The furthest point on the way to `to` that is actually reachable this frame.
##
## Gliding sets position outright, so at speed the host can cross thin geometry entirely between
## two frames and never touch it. With Stepping on, a swept ray finds what the glide skipped and
## returns the contact point instead. Positions are in the parent's space, so the sweep converts
## by offsetting the host's global position by the same delta.
func step_toward(from: Vector3, to: Vector3) -> Vector3:
	if not stepping or from == to or host == null or not host.is_inside_tree():
		return to
	var world_from: Vector3 = host.global_position
	var step_query := PhysicsRayQueryParameters3D.create(world_from, world_from + (to - from), step_mask, [])
	step_query.collide_with_areas = step_hits_areas
	var step_hit := host.get_world_3d().direct_space_state.intersect_ray(step_query)
	if step_hit.is_empty():
		return to
	if stop_on_step_hit:
		waypoints.clear()
		moving = false
	path_blocked.emit()
	var contact: Vector3 = step_hit.get("position", world_from)
	# Park just SHORT of the surface, never exactly on it: a ray that STARTS on a shape does not
	# report that shape (hit-from-inside is off), so a host left touching the wall sails straight
	# through on the next frame's sweep. A centimetre of clearance keeps the next ray honest.
	return from + (contact - (to - from).normalized() * 0.01 - world_from)

# Move To 3D behavior (event-sheet-style): glides through a queue of Vector3 waypoints and fires On Arrived at the final stop.
