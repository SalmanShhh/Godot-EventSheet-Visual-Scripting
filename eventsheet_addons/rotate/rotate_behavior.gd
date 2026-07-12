## @ace_tags(movement, visual)
## @ace_category("Rotate")
@icon("res://eventsheet_addons/behavior.svg")
class_name RotateBehavior
extends Node

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("RotateBehavior behavior requires a Node parent.")

# --- Designer knobs (tune in the Inspector) ---
## Spin on/off - Set Rotation Enabled flips it at runtime.
@export var rotate_enabled: bool = true
## Rotation speed in degrees per second (negative = the other way).
@export var speed: float = 90.0
## Speed change in degrees per second, per second (0 = constant speed).
@export var acceleration: float = 0.0
## What to spin: a Node2D's rotation, or a Node3D's X / Y / Z axis.
@export_enum("2d", "x", "y", "z") var rotation_type: String = "2d"

# --- Internal state ---
# The live speed (deg/s) - starts at the Speed knob, then Acceleration ramps it.
var _current_speed: float = 0.0
var _speed_primed: bool = false
# Editor-preview contract (Tools > Preview Behaviors on Selected Node): pure angle math
# over the Inspector values - angle(t) = speed*t + accel*t^2/2 - so the editor animates
# the spin without running the behavior. Handles a Node2D's float rotation AND a
# Node3D's Vector3 rotation from the same sample.
static func editor_preview_sample(params: Dictionary, base: Dictionary, time: float) -> Dictionary:
	if not bool(params.get("rotate_enabled", true)):
		return {}
	var angle: float = deg_to_rad(float(params.get("speed", 90.0)) * time + 0.5 * float(params.get("acceleration", 0.0)) * time * time)
	var base_rotation: Variant = base.get("rotation", 0.0)
	var type: String = str(params.get("rotation_type", "2d"))
	if type == "2d" and (base_rotation is float or base_rotation is int):
		return {"rotation": float(base_rotation) + angle}
	if base_rotation is Vector3:
		var euler: Vector3 = base_rotation
		match type:
			"x":
				return {"rotation": euler + Vector3(angle, 0.0, 0.0)}
			"y":
				return {"rotation": euler + Vector3(0.0, angle, 0.0)}
			"z":
				return {"rotation": euler + Vector3(0.0, 0.0, angle)}
	return {}

func _physics_process(delta: float) -> void:
	if not rotate_enabled or host == null:
		return
	if not _speed_primed:
		_current_speed = speed
		_speed_primed = true
	_current_speed += acceleration * delta
	var step: float = deg_to_rad(_current_speed * delta)
	# Type-safe spin: a mismatched host (rotation_type "2d" on a Node3D) is a no-op,
	# never an error - swap the knob or the parent freely.
	if rotation_type == "2d" and host is Node2D:
		(host as Node2D).rotation += step
	elif host is Node3D:
		match rotation_type:
			"x":
				(host as Node3D).rotation.x += step
			"y":
				(host as Node3D).rotation.y += step
			"z":
				(host as Node3D).rotation.z += step

## @ace_condition
## @ace_name("Is Rotating")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$RotateBehavior.is_rotating()")
func is_rotating() -> bool:
	return rotate_enabled and absf(_current_speed if _speed_primed else speed) > 0.001

## @ace_expression
## @ace_name("Rotation Speed")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$RotateBehavior.rotation_speed()")
func rotation_speed() -> float:
	return _current_speed if _speed_primed else speed

func set_rotation_enabled(enabled: bool) -> void:
	rotate_enabled = enabled

func set_rotation_speed(degrees_per_second: float) -> void:
	speed = degrees_per_second
	_current_speed = degrees_per_second
	_speed_primed = true

func set_rotation_acceleration(degrees_per_second_squared: float) -> void:
	acceleration = degrees_per_second_squared

func set_rotation_type(type: String) -> void:
	if type in ["2d", "x", "y", "z"]:
		rotation_type = type

func reverse_rotation() -> void:
	if not _speed_primed:
		_current_speed = speed
		_speed_primed = true
	_current_speed = -_current_speed
	speed = _current_speed

# Rotate behavior (event-sheet parity): spins the host at Speed degrees/second, ramping by Acceleration. Rotation Type covers a 2D node's rotation and a 3D node's X, Y, or Z axis - one pack for pickups, fans, planets, and drills. Set Rotation Enabled toggles it; Reverse flips direction. Previewable in the editor (Tools > Preview Behaviors on Selected Node). This pack is an event sheet - extend it by editing it.
