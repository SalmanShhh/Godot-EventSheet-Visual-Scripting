## @ace_tags(movement, platformer)
## @ace_category("Platformer")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/platformer_movement/icon.svg")
class_name PlatformerMovement
extends Node
## Full jump-and-run movement for a CharacterBody2D in one drop: acceleration and friction, gravity with a terminal velocity, coyote time, jump buffering, variable jump height, multi-jump, wall slide, and wall jump. You only fire Jump on the button press, tune the feel in the Inspector, and react to triggers like On Jumped and On Landed.

## The node this behavior acts on (its parent). Required host: CharacterBody2D.
var host: CharacterBody2D = null

func _enter_tree() -> void:
	host = get_parent() as CharacterBody2D
	if host == null:
		push_warning("PlatformerMovement behavior requires a CharacterBody2D parent.")

## @ace_trigger
## @ace_name("On Jumped")
signal jumped
## @ace_trigger
## @ace_name("On Landed")
signal landed
## @ace_trigger
## @ace_name("On Double Jumped")
signal double_jumped
## @ace_trigger
## @ace_name("On Wall Jumped")
signal wall_jumped

var _air_time: float = 0.0
var _buffer_timer: float = 0.0
var _coyote_timer: float = 0.0
var _facing: int = 1
var _jumps_left: int = 0
var _wall_sliding: bool = false
var _was_on_floor: bool = false
## How fast you reach top speed when pressing a direction.
@export var acceleration: float = 1500.0
## AI drive: read ai_move_axis instead of the keyboard (the Platformer Pathfinding behavior flips this on to steer).
@export var ai_controlled: bool = false
var ai_move_axis: float = 0.0
## Grace window (s) to still jump just after walking off a ledge.
@export var coyote_time: float = 0.1
## How fast you stop when no direction is pressed.
@export var deceleration: float = 1800.0
## Jump off walls (kicks away from the wall).
@export var enable_wall_jump: bool = false
## Cling and slow your fall when pressing into a wall.
@export var enable_wall_slide: bool = false
## Downward acceleration (px/s²).
@export var gravity: float = 980.0
## Press jump this many seconds early and it still fires on landing.
@export var jump_buffer_time: float = 0.1
## Fraction of upward speed kept when jump is released early.
@export_range(0, 1, 0.05) var jump_cut_factor: float = 0.45
## Upward velocity of a jump (negative = up).
@export var jump_velocity: float = -400.0
## Terminal velocity - gravity never pulls you faster than this.
@export var max_fall_speed: float = 1000.0
## Total jumps before touching ground (2 = double jump).
@export var max_jumps: int = 1
## Top horizontal run speed (px/s).
@export var move_speed: float = 200.0
## Releasing jump early cuts the rise (hold = higher).
@export var variable_jump_height: bool = true
## Horizontal kick away from the wall on a wall jump.
@export var wall_jump_push: float = 260.0
## Upward velocity of a wall jump (negative = up).
@export var wall_jump_velocity: float = -380.0
## Max fall speed while wall sliding (px/s).
@export var wall_slide_speed: float = 80.0

func _physics_process(delta: float) -> void:
	if host == null:
		return
	var was_on_floor := _was_on_floor
	var on_floor := host.is_on_floor()
	if not on_floor:
		host.velocity.y = minf(host.velocity.y + gravity * delta, max_fall_speed)
		_air_time += delta
	else:
		_air_time = 0.0
	# The AI seam: a sibling driver (Platformer Pathfinding) writes ai_move_axis and flips
	# ai_controlled on; off (the default) this is exactly the keyboard read it always was.
	var direction := ai_move_axis if ai_controlled else Input.get_axis("ui_left", "ui_right")
	var target_speed := direction * move_speed
	var rate := acceleration if not is_zero_approx(direction) else deceleration
	host.velocity.x = move_toward(host.velocity.x, target_speed, rate * delta)
	if not is_zero_approx(direction):
		_facing = 1 if direction > 0.0 else -1
	_wall_sliding = false
	if enable_wall_slide and not on_floor and host.is_on_wall() and host.velocity.y > 0.0 and not is_zero_approx(direction):
		host.velocity.y = minf(host.velocity.y, wall_slide_speed)
		_wall_sliding = true
	if on_floor:
		_coyote_timer = coyote_time
		_jumps_left = maxi(max_jumps - 1, 0)
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_buffer_timer = maxf(_buffer_timer - delta, 0.0)
	if on_floor and not was_on_floor:
		landed.emit()
	_was_on_floor = on_floor
	if _buffer_timer > 0.0 and (on_floor or _coyote_timer > 0.0 or _jumps_left > 0 or (enable_wall_jump and host.is_on_wall())):
		_buffer_timer = 0.0
		jump()
	host.move_and_slide()

## @ace_action
## @ace_featured
## @ace_name("Jump")
## @ace_category("Platformer")
## @ace_description("Jumps: from the floor or within coyote time, off a wall (if enabled), or a mid-air (double) jump if any remain. If none are available right now, the press is buffered.")
## @ace_icon("res://eventsheet_addons/platformer_movement/icon.svg")
## @ace_codegen_template("$PlatformerMovement.jump()")
func jump() -> void:
	if host == null:
		return
	if host.is_on_floor() or _coyote_timer > 0.0:
		_perform_jump(jump_velocity)
		jumped.emit()
	elif enable_wall_jump and host.is_on_wall():
		host.velocity.y = wall_jump_velocity
		host.velocity.x = host.get_wall_normal().x * wall_jump_push
		_coyote_timer = 0.0
		_facing = 1 if host.get_wall_normal().x > 0.0 else -1
		wall_jumped.emit()
	elif _jumps_left > 0:
		_perform_jump(jump_velocity)
		_jumps_left -= 1
		double_jumped.emit()
	else:
		_buffer_timer = jump_buffer_time

## @ace_action
## @ace_name("Jump Released")
## @ace_category("Platformer")
## @ace_description("Call when the jump button is released - cuts the rise short for variable jump height (hold = higher).")
## @ace_icon("res://eventsheet_addons/platformer_movement/icon.svg")
## @ace_codegen_template("$PlatformerMovement.jump_released()")
func jump_released() -> void:
	if host != null and variable_jump_height and host.velocity.y < 0.0:
		host.velocity.y *= jump_cut_factor

## @ace_action
## @ace_name("Set Move Speed")
## @ace_category("Platformer")
## @ace_description("Changes the horizontal move speed.")
## @ace_icon("res://eventsheet_addons/platformer_movement/icon.svg")
## @ace_codegen_template("$PlatformerMovement.set_move_speed({speed})")
func set_move_speed(speed: float) -> void:
	move_speed = speed

## @ace_action
## @ace_name("Reset Jumps")
## @ace_category("Platformer")
## @ace_description("Refills the air-jump count (e.g. after grabbing a power-up).")
## @ace_icon("res://eventsheet_addons/platformer_movement/icon.svg")
## @ace_codegen_template("$PlatformerMovement.reset_jumps()")
func reset_jumps() -> void:
	_jumps_left = maxi(max_jumps - 1, 0)

## @ace_condition
## @ace_name("Is Moving")
## @ace_icon("res://eventsheet_addons/platformer_movement/icon.svg")
## @ace_codegen_template("$PlatformerMovement.is_moving()")
func is_moving() -> bool:
	return host != null and absf(host.velocity.x) > 1.0

## @ace_condition
## @ace_name("Is Jumping")
## @ace_icon("res://eventsheet_addons/platformer_movement/icon.svg")
## @ace_codegen_template("$PlatformerMovement.is_jumping()")
func is_jumping() -> bool:
	return host != null and not host.is_on_floor() and host.velocity.y < 0.0

## @ace_condition
## @ace_name("Is Falling")
## @ace_icon("res://eventsheet_addons/platformer_movement/icon.svg")
## @ace_codegen_template("$PlatformerMovement.is_falling()")
func is_falling() -> bool:
	return host != null and not host.is_on_floor() and host.velocity.y > 0.0

## @ace_condition
## @ace_name("Is Wall Sliding")
## @ace_icon("res://eventsheet_addons/platformer_movement/icon.svg")
## @ace_codegen_template("$PlatformerMovement.is_wall_sliding()")
func is_wall_sliding() -> bool:
	return _wall_sliding

## @ace_condition
## @ace_name("Can Jump")
## @ace_icon("res://eventsheet_addons/platformer_movement/icon.svg")
## @ace_codegen_template("$PlatformerMovement.can_jump()")
func can_jump() -> bool:
	if host == null:
		return false
	return host.is_on_floor() or _coyote_timer > 0.0 or _jumps_left > 0 or (enable_wall_jump and host.is_on_wall())

## @ace_expression
## @ace_name("Jumps Remaining")
## @ace_icon("res://eventsheet_addons/platformer_movement/icon.svg")
## @ace_codegen_template("$PlatformerMovement.jumps_remaining()")
func jumps_remaining() -> int:
	return _jumps_left

## @ace_expression
## @ace_name("Air Time")
## @ace_icon("res://eventsheet_addons/platformer_movement/icon.svg")
## @ace_codegen_template("$PlatformerMovement.air_time()")
func air_time() -> float:
	return _air_time

## @ace_expression
## @ace_name("Facing Direction")
## @ace_icon("res://eventsheet_addons/platformer_movement/icon.svg")
## @ace_codegen_template("$PlatformerMovement.facing_direction()")
func facing_direction() -> int:
	return _facing

func _perform_jump(velocity_y: float) -> void:
	# Shared jump kernel: set the rise and spend the coyote window. _jumps_left counts
	# only AIR jumps (it is decremented by the air-jump branch, not here), so falling off
	# a ledge past the coyote window never grants a phantom jump.
	if host == null:
		return
	host.velocity.y = velocity_y
	_coyote_timer = 0.0

# Platformer movement: attach under a CharacterBody2D. Run with ui_left/ui_right, call Jump (with coyote time + buffering), and turn on wall slide / wall jump / double jump in the Inspector. Call Jump Released when the player lets go of the jump button for variable jump height.
