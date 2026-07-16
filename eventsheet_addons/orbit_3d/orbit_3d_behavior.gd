## @ace_category("Orbit 3D")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/orbit_3d/icon.svg")
class_name Orbit3DBehavior
extends Node

## The node this behavior acts on (its parent). Required host: Node3D.
var host: Node3D = null

func _enter_tree() -> void:
	host = get_parent() as Node3D
	if host == null:
		push_warning("Orbit3DBehavior behavior requires a Node3D parent.")

var angle: float = 0.0
var center_captured: bool = false
var center_x: float = 0.0
var center_y: float = 0.0
var center_z: float = 0.0
## Distance in world units the host stays from the orbit center.
@export var radius: float = 3.0
## Degrees per second the host travels around the orbit.
@export var speed_degrees: float = 90.0

func _process(delta: float) -> void:
	if host == null:
		return
	if not center_captured:
		center_x = host.position.x
		center_y = host.position.y
		center_z = host.position.z
		center_captured = true
	angle += deg_to_rad(speed_degrees) * delta
	host.position = Vector3(center_x + cos(angle) * radius, center_y, center_z + sin(angle) * radius)

## @ace_action
## @ace_name("Set Orbit 3D Center")
## @ace_category("Orbit 3D")
## @ace_description("Orbits around the given point from now on.")
## @ace_icon("res://eventsheet_addons/orbit_3d/icon.svg")
## @ace_codegen_template("$Orbit3DBehavior.set_orbit3d_center({x}, {y}, {z})")
func set_orbit3d_center(x: float, y: float, z: float) -> void:
	center_x = x
	center_y = y
	center_z = z
	center_captured = true

# Orbit 3D behavior (event-sheet-style): circles the host around its starting point in the XZ plane (Y stays).
