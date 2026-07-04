## @ace_category("Car")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/behavior.svg")
class_name CarBehavior
extends Node

## The node this behavior acts on (its parent). Required host: CharacterBody2D.
var host: CharacterBody2D = null

func _enter_tree() -> void:
	host = get_parent() as CharacterBody2D
	if host == null:
		push_warning("CarBehavior behavior requires a CharacterBody2D parent.")

## @ace_trigger
## @ace_name("On Drift Started")
signal drift_started
## @ace_trigger
## @ace_name("On Drift Recovered")
signal drift_recovered

var _drifting: bool = false
@export var acceleration: float = 300.0
@export var deceleration: float = 400.0
@export var drift_angle_threshold: float = 15.0
@export var drift_recover: float = 0.15
@export var max_speed: float = 400.0
var speed: float = 0.0
@export var steer_degrees: float = 180.0
@export var turn_while_stopped: bool = false

func _physics_process(delta: float) -> void:
	if host == null:
		return
	var throttle := Input.get_axis(&"ui_down", &"ui_up")
	if throttle > 0.0:
		speed = minf(speed + acceleration * delta, max_speed)
	elif throttle < 0.0:
		speed = maxf(speed - acceleration * delta, -max_speed * 0.5)
	else:
		speed = move_toward(speed, 0.0, deceleration * delta)
	var steer := Input.get_axis(&"ui_left", &"ui_right")
	var steer_scale := 1.0 if (turn_while_stopped and absf(speed) < 1.0) else clampf(absf(speed) / max_speed, 0.0, 1.0) * signf(speed)
	host.rotation += deg_to_rad(steer_degrees) * steer * delta * steer_scale
	var heading := Vector2.from_angle(host.rotation) * speed
	host.velocity = host.velocity.lerp(heading, clampf(drift_recover, 0.01, 1.0))
	# Drift = the velocity has slid away from the heading; edge-triggered so each slide fires once.
	var drifting := absf(speed) > 20.0 and host.velocity.length() > 20.0 and absf(host.velocity.angle_to(heading)) > deg_to_rad(drift_angle_threshold)
	if drifting and not _drifting:
		_drifting = true
		drift_started.emit()
	elif not drifting and _drifting:
		_drifting = false
		drift_recovered.emit()
	host.move_and_slide()

## @ace_action
## @ace_name("Stop Car")
## @ace_category("Car")
## @ace_description("Kills all momentum.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$CarBehavior.stop_car()")
func stop_car() -> void:
	speed = 0.0
	if host != null:
		host.velocity = Vector2.ZERO

# Car behavior (event-sheet parity): accelerate/brake with up/down, steer with left/right. drift_recover blends sliding back toward the heading (1 = grippy, low = drifty); turn_while_stopped allows steering at rest.
