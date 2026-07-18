## @ace_category("Bullet")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/bullet/icon.svg")
class_name BulletBehavior
extends Node
## Fire-and-forget projectile movement for a Node2D: the host launches in the direction it is facing and keeps flying every frame. Tune speed, acceleration, and gravity, redirect or pause it live, and read how far it has flown from plain event rows.

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("BulletBehavior behavior requires a Node2D parent.")

## Change in speed per second along the direction of motion.
@export var acceleration: float = 0.0
## Rotates the host to face its direction of motion.
@export var align_rotation: bool = true
var distance_travelled: float = 0.0
## When off, the bullet stops moving.
@export var enabled_movement: bool = true
## Downward pull added to vertical speed each second.
@export var gravity: float = 0.0
## Direction gravity pulls, in degrees (90 = down, 270 = up, 0 = right) - arcs bend that way instead of downward.
@export_range(0, 360, 1) var gravity_angle: float = 90.0
var launched: bool = false
## Travel speed in pixels per second.
@export var speed: float = 300.0
var vel_x: float = 0.0
var vel_y: float = 0.0

func _process(delta: float) -> void:
	if host == null or not enabled_movement:
		return
	if not launched:
		vel_x = cos(host.rotation) * speed
		vel_y = sin(host.rotation) * speed
		launched = true
	var direction := Vector2(vel_x, vel_y).normalized()
	vel_x += direction.x * acceleration * delta
	vel_y += direction.y * acceleration * delta
	# Gravity pulls along gravity_angle; built from Vector2.DOWN.rotated so the default
	# 90 degrees is EXACTLY (0, 1) - the plain vel_y pull this generalizes, bit for bit.
	var gravity_pull := Vector2.DOWN.rotated(deg_to_rad(gravity_angle - 90.0)) * gravity * delta
	vel_x += gravity_pull.x
	vel_y += gravity_pull.y
	var motion := Vector2(vel_x, vel_y) * delta
	host.position += motion
	distance_travelled += motion.length()
	if align_rotation and motion != Vector2.ZERO:
		host.rotation = motion.angle()

## @ace_action
## @ace_name("Set Bullet Speed")
## @ace_category("Bullet")
## @ace_description("Changes speed, keeping the current direction.")
## @ace_icon("res://eventsheet_addons/bullet/icon.svg")
## @ace_codegen_template("$BulletBehavior.set_bullet_speed({value})")
func set_bullet_speed(value: float) -> void:
	speed = value
	var direction := Vector2(vel_x, vel_y).normalized()
	if direction == Vector2.ZERO and host != null:
		direction = Vector2.from_angle(host.rotation)
	vel_x = direction.x * value
	vel_y = direction.y * value
	launched = true

## @ace_action
## @ace_name("Set Angle Of Motion")
## @ace_category("Bullet")
## @ace_description("Redirects the bullet (degrees).")
## @ace_icon("res://eventsheet_addons/bullet/icon.svg")
## @ace_codegen_template("$BulletBehavior.set_angle_of_motion({degrees})")
func set_angle_of_motion(degrees: float) -> void:
	vel_x = cos(deg_to_rad(degrees)) * speed
	vel_y = sin(deg_to_rad(degrees)) * speed
	launched = true

## @ace_action
## @ace_name("Set Gravity Angle")
## @ace_category("Bullet")
## @ace_description("Points gravity in a new direction, in degrees (90 = down, 270 = up, 0 = right) - the arc bends that way from now on. Magnet fields, wind wells, and upside-down zones in one action.")
## @ace_icon("res://eventsheet_addons/bullet/icon.svg")
## @ace_codegen_template("$BulletBehavior.set_gravity_angle({angle})")
func set_gravity_angle(angle: float) -> void:
	gravity_angle = wrapf(angle, 0.0, 360.0)

## @ace_action
## @ace_name("Set Bullet Enabled")
## @ace_category("Bullet")
## @ace_description("Pauses or resumes the movement.")
## @ace_icon("res://eventsheet_addons/bullet/icon.svg")
## @ace_codegen_template("$BulletBehavior.set_bullet_enabled({is_enabled})")
func set_bullet_enabled(is_enabled: bool) -> void:
	enabled_movement = is_enabled

# Bullet behavior (event-sheet parity): angle-of-motion movement with acceleration and gravity; tracks distance travelled (read $BulletBehavior.distance_travelled).
