## @ace_category("Car")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/car/icon.svg")
class_name CarBehavior
extends Node
## Turns a plain CharacterBody2D into a drivable top-down arcade car: arrow keys accelerate, reverse, and steer the moment you press play. Every handling knob (top speed, acceleration, coast, turn rate, grip, drift) is readable and settable live for boost pads, ice, and damage models.

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
## How fast speed builds while on the throttle, in pixels per second squared.
@export var acceleration: float = 300.0
## AI drive: read ai_throttle_axis/ai_steer_axis instead of the keyboard (a sheet or AI driver flips this on to steer).
@export var ai_controlled: bool = false
var ai_steer_axis: float = 0.0
var ai_throttle_axis: float = 0.0
## How fast the car coasts back to a stop when off the throttle, in pixels per second squared.
@export var deceleration: float = 400.0
## Angle in degrees between velocity and heading before a drift is counted.
@export var drift_angle_threshold: float = 15.0
## How strongly velocity snaps back toward the heading each frame (1 = grippy, low = drifty).
@export var drift_recover: float = 0.15
## Top forward speed in pixels per second (reverse tops out at half this).
@export var max_speed: float = 400.0
var speed: float = 0.0
## Turn rate in degrees per second at full steering.
@export var steer_degrees: float = 180.0
## Allows steering while the car is stopped.
@export var turn_while_stopped: bool = false

func _physics_process(delta: float) -> void:
	if host == null:
		return
	# The AI seam: a driver writes ai_throttle_axis/ai_steer_axis and flips ai_controlled
	# on; off (the default) these are exactly the keyboard reads they always were.
	var throttle := ai_throttle_axis if ai_controlled else Input.get_axis(&"ui_down", &"ui_up")
	if throttle > 0.0:
		speed = minf(speed + acceleration * delta, max_speed)
	elif throttle < 0.0:
		speed = maxf(speed - acceleration * delta, -max_speed * 0.5)
	else:
		speed = move_toward(speed, 0.0, deceleration * delta)
	var steer := ai_steer_axis if ai_controlled else Input.get_axis(&"ui_left", &"ui_right")
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
## @ace_icon("res://eventsheet_addons/car/icon.svg")
## @ace_codegen_template("$CarBehavior.stop_car()")
func stop_car() -> void:
	speed = 0.0
	if host != null:
		host.velocity = Vector2.ZERO

# Car behavior (event-sheet parity): accelerate/brake with up/down, steer with left/right. drift_recover blends sliding back toward the heading (1 = grippy, low = drifty); turn_while_stopped allows steering at rest.
