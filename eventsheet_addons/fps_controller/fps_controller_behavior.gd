## @ace_category("FPS Controller")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/behavior.svg")
class_name FPSController
extends Node

## The node this behavior acts on (its parent). Required host: CharacterBody3D.
var host: CharacterBody3D = null

func _enter_tree() -> void:
	host = get_parent() as CharacterBody3D
	if host == null:
		push_warning("FPSController behavior requires a CharacterBody3D parent.")

## @ace_trigger
## @ace_name("On Jumped")
## @ace_category("FPS Controller")
signal jumped
## @ace_trigger
## @ace_name("On Landed")
## @ace_category("FPS Controller")
signal landed
## @ace_trigger
## @ace_name("On Camera Mode Changed")
## @ace_category("FPS Controller")
signal camera_mode_changed

@export var camera_distance: float = 3.5
@export var capture_mouse_on_ready: bool = true
@export var gravity: float = 9.8
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.12
@export var move_speed: float = 5.0
var pitch: float = 0.0
@export var pitch_max: float = 80.0
@export var pitch_min: float = -80.0
var sprint_held: bool = false
@export var sprint_multiplier: float = 1.6
@export var third_person: bool = false
var was_on_floor: bool = true
var yaw: float = 0.0

func _head() -> Node3D:
	return (host.get_node_or_null("Head") as Node3D) if host != null else null

func _ready() -> void:
	if capture_mouse_on_ready:
		capture_mouse()
	apply_camera_mode()

func _physics_process(delta: float) -> void:
	if host == null:
		return
	if not host.is_on_floor():
		host.velocity.y -= gravity * delta
	sprint_held = Input.is_key_pressed(KEY_SHIFT)
	var input_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := host.transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)
	if direction.length() > 1.0:
		direction = direction.normalized()
	var speed := move_speed * (sprint_multiplier if sprint_held else 1.0)
	host.velocity.x = direction.x * speed
	host.velocity.z = direction.z * speed
	if Input.is_action_just_pressed("ui_accept") and host.is_on_floor():
		do_jump()
	host.move_and_slide()
	if host.is_on_floor() and not was_on_floor:
		landed.emit()
	was_on_floor = host.is_on_floor()

## @ace_action
## @ace_name("Jump")
## @ace_category("FPS Controller")
## @ace_description("Launches the host upward with Jump Velocity and fires On Jumped.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$FPSController.do_jump()")
func do_jump() -> void:
	if host == null:
		return
	host.velocity.y = jump_velocity
	jumped.emit()

## @ace_action
## @ace_name("Add Look")
## @ace_category("FPS Controller")
## @ace_description("Turns the view by a mouse delta (pixels): yaw rotates the host, pitch tilts the Head child, clamped to Pitch Min/Max.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$FPSController.add_look({x}, {y})")
func add_look(x: float, y: float) -> void:
	yaw = wrapf(yaw - x * mouse_sensitivity, -180.0, 180.0)
	pitch = clampf(pitch - y * mouse_sensitivity, pitch_min, pitch_max)
	if host != null:
		host.rotation_degrees.y = yaw
	var head := _head()
	if head != null:
		head.rotation_degrees.x = pitch

## @ace_action
## @ace_name("Set Third Person")
## @ace_category("FPS Controller")
## @ace_description("Switches between first person (off) and third person (on) and fires On Camera Mode Changed.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$FPSController.set_third_person({enabled})")
func set_third_person(enabled: bool) -> void:
	third_person = enabled
	apply_camera_mode()
	camera_mode_changed.emit()

## @ace_action
## @ace_name("Toggle Camera Mode")
## @ace_category("FPS Controller")
## @ace_description("Flips between first and third person.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$FPSController.toggle_camera_mode()")
func toggle_camera_mode() -> void:
	set_third_person(not third_person)

## @ace_action
## @ace_name("Apply Camera Mode")
## @ace_category("FPS Controller")
## @ace_description("Re-applies the current camera mode to the Head's SpringArm3D (named Arm): ~0 length in first person, Camera Distance in third.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$FPSController.apply_camera_mode()")
func apply_camera_mode() -> void:
	var head := _head()
	if head == null:
		return
	var arm := head.get_node_or_null("Arm") as SpringArm3D
	if arm != null:
		arm.spring_length = camera_distance if third_person else 0.05

## @ace_action
## @ace_name("Capture Mouse")
## @ace_category("FPS Controller")
## @ace_description("Locks the mouse to the window for looking around (Esc releases it).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$FPSController.capture_mouse()")
func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## @ace_action
## @ace_name("Release Mouse")
## @ace_category("FPS Controller")
## @ace_description("Frees the mouse cursor.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$FPSController.release_mouse()")
func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## @ace_action
## @ace_name("Set Move Speed")
## @ace_category("FPS Controller")
## @ace_description("Changes the base walking speed.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$FPSController.set_move_speed({value})")
func set_move_speed(value: float) -> void:
	move_speed = value

## @ace_action
## @ace_name("Set Mouse Sensitivity")
## @ace_category("FPS Controller")
## @ace_description("Changes look sensitivity (degrees per mouse pixel).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$FPSController.set_mouse_sensitivity({value})")
func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = value

## @ace_condition
## @ace_name("Is Sprinting")
## @ace_category("FPS Controller")
## @ace_description("True while the sprint key (Shift) is held.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$FPSController.is_sprinting()")
func is_sprinting() -> bool:
	return sprint_held

## @ace_condition
## @ace_name("Is First Person")
## @ace_category("FPS Controller")
## @ace_description("True in first-person camera mode.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$FPSController.is_first_person()")
func is_first_person() -> bool:
	return not third_person

## @ace_expression
## @ace_name("Current Speed")
## @ace_category("FPS Controller")
## @ace_description("The host's horizontal speed right now (metres per second).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$FPSController.current_speed()")
func current_speed() -> float:
	return Vector2(host.velocity.x, host.velocity.z).length() if host != null else 0.0

## @ace_expression
## @ace_name("Look Yaw")
## @ace_category("FPS Controller")
## @ace_description("The current horizontal look angle in degrees (-180..180).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$FPSController.look_yaw()")
func look_yaw() -> float:
	return yaw

## @ace_expression
## @ace_name("Look Pitch")
## @ace_category("FPS Controller")
## @ace_description("The current vertical look angle in degrees (clamped to Pitch Min/Max).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$FPSController.look_pitch()")
func look_pitch() -> float:
	return pitch

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look((event as InputEventMouseMotion).relative.x, (event as InputEventMouseMotion).relative.y)
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		release_mouse()

# FPS/TPS controller behavior: mouse look + WASD move + sprint + jump on the host CharacterBody3D; a SpringArm3D named Arm under a Head child switches first/third person.
