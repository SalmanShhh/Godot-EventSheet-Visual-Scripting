## @ace_category("Bullet 3D")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/behavior.svg")
class_name Bullet3DBehavior
extends Node

## The node this behavior acts on (its parent). Required host: Node3D.
var host: Node3D = null

func _enter_tree() -> void:
	host = get_parent() as Node3D
	if host == null:
		push_warning("Bullet3DBehavior behavior requires a Node3D parent.")

var distance_travelled: float = 0.0
@export var gravity: float = 0.0
var launched: bool = false
@export var speed: float = 10.0
var vel_x: float = 0.0
var vel_y: float = 0.0
var vel_z: float = 0.0

func _process(delta: float) -> void:
	if host == null:
		return
	if not launched:
		launch_forward()
	vel_y -= gravity * delta
	var motion := Vector3(vel_x, vel_y, vel_z) * delta
	host.position += motion
	distance_travelled += motion.length()

## @ace_action
## @ace_name("Launch Forward")
## @ace_category("Bullet 3D")
## @ace_description("(Re)launches along the host's current forward direction.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$Bullet3DBehavior.launch_forward()")
func launch_forward() -> void:
	if host == null:
		return
	var forward := -host.global_transform.basis.z * speed
	vel_x = forward.x
	vel_y = forward.y
	vel_z = forward.z
	launched = true

## @ace_action
## @ace_name("Set Bullet 3D Speed")
## @ace_category("Bullet 3D")
## @ace_description("Changes speed, keeping the current direction.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$Bullet3DBehavior.set_bullet3d_speed({value})")
func set_bullet3d_speed(value: float) -> void:
	speed = value
	var direction := Vector3(vel_x, vel_y, vel_z).normalized()
	if direction == Vector3.ZERO and host != null:
		direction = -host.global_transform.basis.z
	vel_x = direction.x * value
	vel_y = direction.y * value
	vel_z = direction.z * value
	launched = true

# Bullet 3D behavior (event-sheet-style): launches along the host's forward (-Z) with speed and gravity; tracks distance travelled.
