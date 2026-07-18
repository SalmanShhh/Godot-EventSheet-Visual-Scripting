## @ace_category("Move To")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/move_to/icon.svg")
class_name MoveToBehavior
extends Node
## Glides the host Node2D to a point at a steady speed, walks queued waypoints in order, and fires On Arrived at the last stop. Smooth point-to-point movement for enemies, pickups, and cursor tokens without writing tween code.

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("MoveToBehavior behavior requires a Node2D parent.")

## @ace_trigger
## @ace_name("On Arrived")
## @ace_category("Move To")
signal arrived

## Pixels per second the host glides toward its target.
@export var max_speed: float = 200.0
var moving: bool = false
## When on, the host faces its direction of travel.
@export var rotate_toward_motion: bool = false
var waypoints: Array = []

func _process(delta: float) -> void:
	if moving and is_instance_valid(host) and not waypoints.is_empty():
		var target: Vector2 = waypoints[0]
		var previous: Vector2 = host.position
		host.position = host.position.move_toward(target, max_speed * delta)
		if rotate_toward_motion and host.position != previous:
			host.rotation = (host.position - previous).angle()
		if host.position.distance_to(target) < 0.5:
			waypoints.pop_front()
			if waypoints.is_empty():
				moving = false
				arrived.emit()

## @ace_action
## @ace_name("Move To Position")
## @ace_category("Move To")
## @ace_description("Replaces the queue and glides toward the point.")
## @ace_icon("res://eventsheet_addons/move_to/icon.svg")
## @ace_codegen_template("$MoveToBehavior.move_to_position({x}, {y})")
func move_to_position(x: float, y: float) -> void:
	waypoints = [Vector2(x, y)]
	moving = true

## @ace_action
## @ace_name("Add Waypoint")
## @ace_category("Move To")
## @ace_description("Appends a stop to the queue (waypoints).")
## @ace_icon("res://eventsheet_addons/move_to/icon.svg")
## @ace_codegen_template("$MoveToBehavior.add_waypoint({x}, {y})")
func add_waypoint(x: float, y: float) -> void:
	waypoints.append(Vector2(x, y))
	moving = true

## @ace_action
## @ace_name("Stop Moving")
## @ace_category("Move To")
## @ace_description("Clears the queue without firing On Arrived.")
## @ace_icon("res://eventsheet_addons/move_to/icon.svg")
## @ace_codegen_template("$MoveToBehavior.stop_moving()")
func stop_moving() -> void:
	moving = false
	waypoints = []

# Move To behavior (event-sheet parity): glides through a waypoint queue (Move To Position replaces it, Add Waypoint appends) and fires On Arrived at the final stop. rotate_toward_motion faces the travel direction.
