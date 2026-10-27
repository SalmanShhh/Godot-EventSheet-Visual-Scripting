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

## @ace_trigger
## @ace_name("On Bullet Hit")
signal on_bullet_hit(collider: Object, point: Vector2, normal: Vector2)

## Travel speed in pixels per second.
@export var speed: float = 300.0
## Change in speed per second along the direction of motion.
@export var acceleration: float = 0.0
## Downward pull added to vertical speed each second.
@export var gravity: float = 0.0
## Direction gravity pulls, in degrees (90 = down, 270 = up, 0 = right) - arcs bend that way instead of downward.
@export_range(0, 360, 1) var gravity_angle: float = 90.0
## Rotates the host to face its direction of motion.
@export var align_rotation: bool = true
## Sweep the path each frame instead of jumping along it, so a fast bullet cannot pass through a thin wall between two frames.
@export var stepping: bool = false
## Collision layers the swept path tests against. Each layer is a bit, so layers 1 and 3 are 1 + 4 = 5.
@export var step_mask: int = 1
## Also stop the sweep on Area2D nodes, which it ignores by default.
@export var step_hits_areas: bool = false
## Park the bullet at the point it struck and stop it. Turn off to keep flying and just report the hit.
@export var stop_on_step_hit: bool = true
var distance_travelled: float = 0.0
var vel_x: float = 0.0
var vel_y: float = 0.0
var launched: bool = false

## When off, the bullet stops moving.
@export var enabled_movement: bool = true:
	set(value):
		enabled_movement = value
		# Every write lands here - Set Bullet Enabled, the reflected Set Enabled Movement action,
		# the Inspector, another script - so the tick follows the switch whoever flipped it. A
		# frozen bullet costs nothing per frame.
		set_process(value)

func _ready() -> void:
	if host == null:
		# Nothing to move means no frame will ever have work; stop paying for the tick at all.
		set_process(false)
		return
	# The tick runs only while the bullet is actually flying - a shot authored frozen, or one
	# parked by a stepping hit, costs nothing per frame until Set Bullet Enabled starts it again.
	set_process(enabled_movement)

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
	# STEPPING: at 3000 px/s a bullet covers 50px in a frame, so a 20px wall can sit entirely
	# between where it was and where it lands and never be touched. Sweeping the frame's motion
	# finds what a teleport skipped. Off by default - the two lines below are the original path.
	if stepping and motion != Vector2.ZERO and host.is_inside_tree():
		var step_from := host.global_position
		var step_query := PhysicsRayQueryParameters2D.create(step_from, step_from + motion, step_mask, [])
		step_query.collide_with_areas = step_hits_areas
		var step_hit := host.get_world_2d().direct_space_state.intersect_ray(step_query)
		if not step_hit.is_empty():
			# Park just SHORT of the surface: a ray that STARTS on a shape does not report it, so a
			# bullet left exactly touching the wall would sail through if it were ever restarted.
			host.global_position = step_hit.get("position", step_from) - motion.normalized() * 0.5
			distance_travelled += step_from.distance_to(host.global_position)
			if align_rotation:
				host.rotation = motion.angle()
			if stop_on_step_hit:
				enabled_movement = false
				# A parked bullet is finished flying - stop paying for a tick that would only
				# early-return, until Set Bullet Enabled sends it on its way again.
				set_process(false)
			on_bullet_hit.emit(step_hit.get("collider"), step_hit.get("position", step_from), step_hit.get("normal", Vector2.ZERO))
			return
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
	# Re-aiming a bullet re-syncs the tick to whether it is moving, so a shot re-enabled
	# through its Inspector flag rather than through Set Bullet Enabled still flies.
	set_process(enabled_movement)

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
	# Re-aiming a bullet re-syncs the tick to whether it is moving, so a shot re-enabled
	# through its Inspector flag rather than through Set Bullet Enabled still flies.
	set_process(enabled_movement)

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
	# A frozen bullet costs nothing per frame; enabling it turns the tick back on.
	set_process(is_enabled)

## @ace_action
## @ace_name("Fired By")
## @ace_category("Bullet")
## @ace_description("Marks who fired this shot. Drop it on the row that spawns the bullet and every ownership row afterwards can answer: Hit Is Not My Owner stops it hurting its own shooter, Take Damage From credits the kill to the person rather than the projectile, and a turret's shot still traces back to whoever built the turret.")
## @ace_display_template("Fired by [i]{shooter}[/i]")
## @ace_icon("res://eventsheet_addons/bullet/icon.svg")
## @ace_codegen_template("$BulletBehavior.set_fired_by({shooter})")
func set_fired_by(shooter: Node) -> void:
	if host != null:
		host.set_meta(&"owner", shooter)

# Bullet behavior (event-sheet parity): angle-of-motion movement with acceleration and gravity; tracks distance travelled (read $BulletBehavior.distance_travelled).
