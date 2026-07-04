## @ace_category("Orbit")
@icon("res://eventsheet_addons/behavior.svg")
class_name OrbitBehavior
extends Node

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("OrbitBehavior behavior requires a Node2D parent.")

var angle: float = 0.0
var center_captured: bool = false
var center_x: float = 0.0
var center_y: float = 0.0
@export var match_rotation: bool = false
@export var offset_angle_degrees: float = 0.0
@export var primary_radius: float = 100.0
@export var secondary_radius: float = 0.0
@export var speed_degrees: float = 90.0
var total_rotation: float = 0.0

func _process(delta: float) -> void:
	if host == null:
		return
	if not center_captured:
		center_x = host.position.x
		center_y = host.position.y
		center_captured = true
	var step := deg_to_rad(speed_degrees) * delta
	angle += step
	total_rotation += absf(step)
	var radius_b := secondary_radius if secondary_radius > 0.0 else primary_radius
	var local := Vector2(cos(angle) * primary_radius, sin(angle) * radius_b).rotated(deg_to_rad(offset_angle_degrees))
	var previous := host.position
	host.position = Vector2(center_x, center_y) + local
	if match_rotation and host.position != previous:
		host.rotation = (host.position - previous).angle()

## @ace_action
## @ace_name("Set Orbit Center")
## @ace_category("Orbit")
## @ace_description("Orbits around the given point from now on.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$OrbitBehavior.set_orbit_center({x}, {y})")
func set_orbit_center(x: float, y: float) -> void:
	center_x = x
	center_y = y
	center_captured = true

## @ace_action
## @ace_name("Set Orbit Speed")
## @ace_category("Orbit")
## @ace_description("Degrees per second (negative reverses).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$OrbitBehavior.set_orbit_speed({degrees_per_second})")
func set_orbit_speed(degrees_per_second: float) -> void:
	speed_degrees = degrees_per_second

## @ace_action
## @ace_name("Set Orbit Radii")
## @ace_category("Orbit")
## @ace_description("Primary/secondary radii (secondary 0 = circle).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$OrbitBehavior.set_orbit_radii({primary}, {secondary})")
func set_orbit_radii(primary: float, secondary: float) -> void:
	primary_radius = primary
	secondary_radius = secondary

# Orbit behavior (event-sheet parity): circles or ellipses around a point. secondary_radius 0 = circle; offset_angle tilts the ellipse; match_rotation faces the travel direction.
