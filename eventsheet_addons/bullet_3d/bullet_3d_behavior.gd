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

## @ace_trigger
## @ace_name("On Bullet Hit")
signal on_bullet_hit(collider: Object, point: Vector3, normal: Vector3)

## Units per second the bullet travels along the host's forward (-Z).
@export var speed: float = 10.0
## Downward acceleration pulling the bullet's vertical velocity down each second.
@export var gravity: float = 0.0
## Sweep the path each frame instead of jumping along it, so a fast bullet cannot pass through thin geometry between two frames.
@export var stepping: bool = false
## Collision layers the swept path tests against. Each layer is a bit, so layers 1 and 3 are 1 + 4 = 5.
@export var step_mask: int = 1
## Also stop the sweep on Area3D nodes, which it ignores by default.
@export var step_hits_areas: bool = false
## Park the bullet at the point it struck and stop it. Turn off to keep flying and just report the hit.
@export var stop_on_step_hit: bool = true
var distance_travelled: float = 0.0
var vel_x: float = 0.0
var vel_y: float = 0.0
var vel_z: float = 0.0
var launched: bool = false
## When off, the bullet stops moving. Parity with the 2D pack, and what Stepping switches off when it parks the bullet on a hit.
@export var enabled_movement: bool = true

# Which way gravity pulls (a Vector3 cannot emit from the variables dict, so it
# lives here). Any direction works - the arc bends toward it; normalized before use.
## The direction gravity pulls the arc toward (default straight down).
@export var gravity_direction: Vector3 = Vector3.DOWN

func _process(delta: float) -> void:
	if host == null or not enabled_movement:
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
	# STEPPING: a fast bullet covers more ground per frame than a thin wall is deep, so a plain
	# teleport can land on the far side having touched nothing. Sweeping the frame's motion finds
	# what the jump skipped. Off by default - the two lines below are the original path.
	if stepping and motion != Vector3.ZERO and host.is_inside_tree():
		var step_from := host.global_position
		var step_query := PhysicsRayQueryParameters3D.create(step_from, step_from + motion, step_mask, [])
		step_query.collide_with_areas = step_hits_areas
		var step_hit := host.get_world_3d().direct_space_state.intersect_ray(step_query)
		if not step_hit.is_empty():
			# Park just SHORT of the surface: a ray that STARTS on a shape does not report it, so a
			# bullet left exactly touching the wall would sail through if it were ever restarted.
			host.global_position = step_hit.get("position", step_from) - motion.normalized() * 0.01
			distance_travelled += step_from.distance_to(host.global_position)
			if stop_on_step_hit:
				enabled_movement = false
			on_bullet_hit.emit(step_hit.get("collider"), step_hit.get("position", step_from), step_hit.get("normal", Vector3.ZERO))
			return
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

## @ace_hidden
static func editor_preview_sample(params: Dictionary, base: Dictionary, time: float) -> Dictionary:
	# Editor-preview contract (Tools > Preview Behaviors on Selected Node): the arc solved for a
	# time instead of integrated frame by frame - p(t) = rest + forward*speed*t + pull*t*t/2 -
	# so the editor can show which way the shot goes, and how far gravity bends it, without
	# running the behavior. Stepping is deliberately NOT previewed: a sweep needs a physics space
	# and the editor has none, so the preview shows the unobstructed flight and says so by
	# ignoring the knob rather than pretending to collide.
	if not bool(params.get("enabled_movement", true)):
		return {}
	var rest: Variant = base.get("position", null)
	if not rest is Vector3:
		return {}
	var euler: Variant = base.get("rotation", Vector3.ZERO)
	var facing: Basis = Basis.from_euler(euler if euler is Vector3 else Vector3.ZERO)
	var forward: Vector3 = -facing.z
	var pull_direction: Variant = params.get("gravity_direction", Vector3.DOWN)
	var pull: Vector3 = (pull_direction if pull_direction is Vector3 else Vector3.DOWN).normalized() * float(params.get("gravity", 0.0))
	var flown: Vector3 = forward * float(params.get("speed", 10.0)) * time + pull * time * time * 0.5
	return {"position": (rest as Vector3) + flown}

# Bullet 3D behavior (event-sheet-style): launches along the host's forward (-Z) with speed and gravity; tracks distance travelled.
