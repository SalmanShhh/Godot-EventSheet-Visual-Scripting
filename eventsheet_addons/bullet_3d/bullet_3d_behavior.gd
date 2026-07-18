## @ace_category("Bullet 3D")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/bullet_3d/icon.svg")
class_name Bullet3DBehavior
extends Node
## Flies a Node3D forward every frame like a projectile: it launches along the host forward direction, then gravity bends the path into an arc. Tune speed and gravity in the Inspector or live from the sheet, and relaunch, retarget, or freeze a shot while the game runs.

## The node this behavior acts on (its parent). Required host: Node3D.
var host: Node3D = null

func _enter_tree() -> void:
	host = get_parent() as Node3D
	if host == null:
		push_warning("Bullet3DBehavior behavior requires a Node3D parent.")

var distance_travelled: float = 0.0
## Downward acceleration pulling the bullet's vertical velocity down each second.
@export var gravity: float = 0.0
var launched: bool = false
## Units per second the bullet travels along the host's forward (-Z).
@export var speed: float = 10.0
var vel_x: float = 0.0
var vel_y: float = 0.0
var vel_z: float = 0.0

# Which way gravity pulls (a Vector3 cannot emit from the variables dict, so it
# lives here). Any direction works - the arc bends toward it; normalized before use.
## The direction gravity pulls the arc toward (default straight down).
@export var gravity_direction: Vector3 = Vector3.DOWN

func _process(delta: float) -> void:
	if host == null:
		return
	if not launched:
		launch_forward()
	# Gravity pulls along gravity_direction; the default Vector3.DOWN normalizes to
	# itself exactly, so this is the plain vel_y drop it generalizes, bit for bit.
	var gravity_pull := gravity_direction.normalized() * gravity * delta
	vel_x += gravity_pull.x
	vel_y += gravity_pull.y
	vel_z += gravity_pull.z
	var motion := Vector3(vel_x, vel_y, vel_z) * delta
	host.position += motion
	distance_travelled += motion.length()

## @ace_action
## @ace_name("Launch Forward")
## @ace_category("Bullet 3D")
## @ace_description("(Re)launches along the host's current forward direction.")
## @ace_icon("res://eventsheet_addons/bullet_3d/icon.svg")
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
## @ace_icon("res://eventsheet_addons/bullet_3d/icon.svg")
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

## @ace_action
## @ace_name("Set Gravity Direction")
## @ace_category("Bullet 3D")
## @ace_description("Points gravity along a new 3D direction (it is normalized for you) - the arc bends that way from now on. (0, -1, 0) is normal down, (0, 1, 0) pulls up, (1, 0, 0) pulls along +X.")
## @ace_icon("res://eventsheet_addons/bullet_3d/icon.svg")
## @ace_codegen_template("$Bullet3DBehavior.set_gravity_direction({x}, {y}, {z})")
func set_gravity_direction(x: float, y: float, z: float) -> void:
	gravity_direction = Vector3(x, y, z)

# Bullet 3D behavior (event-sheet-style): launches along the host's forward (-Z) with speed and gravity; tracks distance travelled.
