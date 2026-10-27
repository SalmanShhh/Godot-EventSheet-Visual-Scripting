## @ace_category("FPS Controller")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/fps_controller/icon.svg")
class_name FPSController
extends Node
## A complete first / third person character controller you attach under a CharacterBody3D: mouse look, WASD movement, sprint, jump, crouch, crouch slide, wall ride, and wall jump. Each move fires its own triggers, so a camera lean or a sound is one event row away.

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
## @ace_name("On Air Jumped")
## @ace_category("FPS Controller")
signal air_jumped
## @ace_trigger
## @ace_name("On Landed")
## @ace_category("FPS Controller")
signal landed
## @ace_trigger
## @ace_name("On Camera Mode Changed")
## @ace_category("FPS Controller")
signal camera_mode_changed
## @ace_trigger
## @ace_name("On Crouched")
## @ace_category("FPS Controller")
signal crouched
## @ace_trigger
## @ace_name("On Stood Up")
## @ace_category("FPS Controller")
signal stood_up
## @ace_trigger
## @ace_name("On Slide Started")
## @ace_category("FPS Controller")
signal slide_started
## @ace_trigger
## @ace_name("On Slide Ended")
## @ace_category("FPS Controller")
signal slide_ended
## @ace_trigger
## @ace_name("On Wall Ride Started")
## @ace_category("FPS Controller")
signal wall_ride_started
## @ace_trigger
## @ace_name("On Wall Ride Ended")
## @ace_category("FPS Controller")
signal wall_ride_ended
## @ace_trigger
## @ace_name("On Wall Jumped")
## @ace_category("FPS Controller")
signal wall_jumped

var _bob_base_y: float = 0.0
var _bob_captured: bool = false
var _bob_time: float = 0.0
var _coyote_timer: float = 0.0
var _firing_timer: float = 0.0
var _jumps_left: int = 0
var _sway_x: float = 0.0
var _sway_y: float = 0.0
var ai_move_x: float = 0.0
var ai_move_z: float = 0.0
var crouching: bool = false
var head_base_y: float = 0.0
var pitch: float = 0.0
var push_x: float = 0.0
var push_z: float = 0.0
var shape_base_y: float = 0.0
var slide_dir_x: float = 0.0
var slide_dir_z: float = 0.0
var slide_time: float = 0.0
var sliding: bool = false
var sprint_held: bool = false
var standing_height: float = 0.0
var standing_radius: float = 0.0
var wall_ride_time: float = 0.0
var wall_riding: bool = false
var was_on_floor: bool = true
var yaw: float = 0.0
## Reads the ai_move_x/z intents instead of the keyboard when on (for AI or cutscene drivers).
@export_group("AI Driver")
@export var ai_controlled: bool = false
## How far the camera pulls back in third person (the SpringArm3D length).
@export_group("Camera")
@export var camera_distance: float = 3.5
## Locks the mouse to the window for looking as soon as the scene starts.
@export var capture_mouse_on_ready: bool = true
## Starts in third-person camera when on, first-person when off.
@export var third_person: bool = false
## Capsule height while crouched (the feet stay planted).
@export_group("Crouch & Slide")
@export var crouch_height: float = 0.9
## Multiplies move speed while crouched.
@export var crouch_speed_multiplier: float = 0.5
## Starting speed of a crouch slide, decaying to crouch-walk pace.
@export var slide_boost_speed: float = 9.0
## How long a crouch slide lasts, in seconds.
@export var slide_duration: float = 0.9
## Allows a crouch slide when crouching at speed.
@export var slide_enabled: bool = true
## Minimum horizontal speed needed to start a crouch slide.
@export var slide_min_speed: float = 6.5
## Grace window in seconds to still take the ground jump just after walking off a ledge (0 turns it off). A coyote jump is the floor jump, not a mid-air one, so it never spends the air-jump budget.
@export_group("Jump")
@export var coyote_time: float = 0.1
## Upward velocity applied on a jump (and on a wall jump).
@export var jump_velocity: float = 4.5
## Total jumps before touching the floor again (1 = a single jump, 2 = double jump, 3 = triple). Extra jumps happen in mid-air.
@export var max_jumps: int = 1
## Aim with the device's gyroscope as well as the mouse - the phone itself turns the view. Off on desktop, where the sensor reads 0 anyway.
@export_group("Look")
@export var gyro_aim: bool = false
## How far a turn of the device moves the view, in mouse pixels per radian per second. Higher is twitchier.
@export var gyro_sensitivity: float = 220.0
## Look sensitivity in degrees turned per mouse pixel moved.
@export var mouse_sensitivity: float = 0.12
## Highest look angle in degrees (how far you can look up).
@export var pitch_max: float = 80.0
## Lowest look angle in degrees (how far you can look down).
@export var pitch_min: float = -80.0
## How much of the run you keep in mid-air, as a share: 1 turns on a coin the way you do on the ground, 0.35 lets you steer a jump without redirecting it, 0 is pure momentum. It is the difference between a floaty platformer and a shooter that rewards a good launch.
@export_group("Movement")
@export var air_control: float = 0.35
## Walking speed in metres per second while the firing window is open - the shooter's foot-planted slowdown. It replaces Move Speed as the base, so sprint and crouch still multiply it.
@export var firing_move_speed: float = 2.5
## Downward acceleration pulling the host to the floor, in metres per second squared.
@export var gravity: float = 9.8
## Landing with jump still held hops straight back off without ever planting a foot, and the landing frame keeps the speed it came in with - the bunny hop. Off, every landing settles to walking pace first.
@export var keep_momentum: bool = true
## Base walking speed in metres per second.
@export var move_speed: float = 5.0
## Multiplies move speed while the sprint key (Shift) is held.
@export var sprint_multiplier: float = 1.6
## Allows jumping off a wall while airborne.
@export_group("Wall Tech")
@export var wall_jump_enabled: bool = true
## How hard a wall jump pushes away from the wall (the kick fades over about half a second).
@export var wall_jump_push: float = 6.0
## Allows riding a wall when airborne and pushing into it.
@export var wall_ride_enabled: bool = true
## Scales gravity while wall riding (lower means a slower slide down).
@export var wall_ride_gravity_scale: float = 0.25
## Longest a single wall ride can last, in seconds.
@export var wall_ride_max_time: float = 1.5
## Minimum horizontal speed needed to start or keep a wall ride.
@export var wall_ride_min_speed: float = 3.0
## How far a bobbing weapon rises and falls, in metres, at full running speed. Walk slower and the bob shrinks with you.
@export_group("Weapon Feel")
@export var bob_amount: float = 0.045
## Seconds for one full bob cycle - a footstep down and back up. Shorter is a jog, longer is a trudge.
@export var bob_period: float = 0.6
## How far a swaying weapon lags behind the view, in radians per mouse pixel. The weight of the thing in your hands.
@export var sway_amount: float = 0.002
## How quickly a swaying weapon catches back up, per second. Higher is a pistol, lower is a rocket launcher.
@export var sway_speed: float = 10.0

# Which way gravity pulls (a Vector3 cannot emit from the variables dict, so it lives
# here). Designed for vertical flips - DOWN and UP are exact (walk on ceilings); a
# tilted direction still pulls and floors correctly but the run plane stays world-
# horizontal (full wall-walking with camera roll is future work).
## The direction gravity pulls (default straight down; (0, 1, 0) walks on ceilings).
@export var gravity_direction: Vector3 = Vector3.DOWN
func _head() -> Node3D:
	return (host.get_node_or_null("Head") as Node3D) if host != null else null
## The host's capsule collider (first CollisionShape3D child holding a CapsuleShape3D).
## @ace_hidden
func _capsule() -> CollisionShape3D:
	if host == null:
		return null
	for child in host.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is CapsuleShape3D:
			return child as CollisionShape3D
	return null

func _ready() -> void:
	if capture_mouse_on_ready:
		capture_mouse()
	apply_camera_mode()

func _physics_process(delta: float) -> void:
	if host == null:
		return
	# The gyro half of looking around: the device's own rotation rate fed through the same
	# Add Look the mouse uses, so one clamp and one yaw serve both hands. Reads 0 on desktop.
	if gyro_aim:
		var rate := Input.get_gyroscope()
		if rate != Vector3.ZERO:
			add_look(rate.y * gyro_sensitivity * delta, rate.x * gyro_sensitivity * delta)
	# up_direction tracks the gravity direction, so is_on_floor() means "resting against
	# whatever gravity presses you into" - the ceiling under inverted gravity.
	host.up_direction = -_gravity_dir()
	var on_floor := host.is_on_floor()
	# Gravity, softened while riding a wall so the slide down reads as a glide.
	if not on_floor:
		host.velocity += _gravity_dir() * gravity * (wall_ride_gravity_scale if wall_riding else 1.0) * delta
	sprint_held = Input.is_key_pressed(KEY_SHIFT) and not crouching
	# Crouch is hold-to-crouch (Ctrl); standing back up is ceiling-checked and retries
	# every frame the key is up, so releasing under a low tunnel pops you up at the exit.
	if Input.is_key_pressed(KEY_CTRL):
		if not crouching:
			do_crouch()
	elif crouching:
		stand_up()
	# The standard AI drive seam: a driver (a 3D navigator, a cutscene) writes ai_move_x/z
	# and flips ai_controlled on; off (the default) this is exactly the keyboard read.
	# Bunny hop: the frame the feet touch down with jump STILL HELD is not a landing, it is the
	# bottom of the next hop. Held here as one fact so the speed write below and the jump read
	# further down cannot disagree about which frame it was.
	var hopping := keep_momentum and on_floor and not was_on_floor and Input.is_action_pressed("ui_accept")
	var input_vec := Vector2(ai_move_x, ai_move_z).limit_length(1.0) if ai_controlled else Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := host.transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)
	if direction.length() > 1.0:
		direction = direction.normalized()
	if sliding:
		# Crouch slide: locked direction, speed decaying from the boost down to crouch-walk pace.
		slide_time += delta
		var slide_fraction := clampf(slide_time / maxf(slide_duration, 0.001), 0.0, 1.0)
		var slide_now := lerpf(slide_boost_speed, move_speed * crouch_speed_multiplier, slide_fraction)
		host.velocity.x = slide_dir_x * slide_now
		host.velocity.z = slide_dir_z * slide_now
		if slide_fraction >= 1.0 or not on_floor:
			stop_sliding()
	else:
		# While the firing window is open the base speed becomes firing_move_speed - sprint and
		# crouch still multiply it, so a firing sprint is a fast walk rather than a full sprint.
		var base_speed := firing_move_speed if _firing_timer > 0.0 else move_speed
		var speed := base_speed * (sprint_multiplier if sprint_held else 1.0) * (crouch_speed_multiplier if crouching else 1.0)
		# push_x/z is the decaying wall-jump kick - without it the every-frame velocity
		# assignment would erase the push after a single physics tick.
		if (not on_floor or hopping) and air_control < 1.0:
			# Air control: off the ground the wish direction STEERS the speed you already have
			# instead of replacing it, so a jump keeps its launch and a bunny hop keeps its run.
			# The share is a per-second rate, hence the delta - at 1.0 it is the ground write.
			var steer := clampf(air_control, 0.0, 1.0) * 12.0 * delta
			host.velocity.x = lerpf(host.velocity.x, direction.x * speed + push_x, steer)
			host.velocity.z = lerpf(host.velocity.z, direction.z * speed + push_z, steer)
		else:
			host.velocity.x = direction.x * speed + push_x
			host.velocity.z = direction.z * speed + push_z
	# The firing window closes on its own, so a weapon only has to say it fired once.
	_firing_timer = maxf(_firing_timer - delta, 0.0)
	# The sway is the LAST mouse movement, bleeding away - so a weapon that lags the view
	# catches up when the view stops. Decayed here rather than in Sway With Mouse so it
	# settles at the same rate whether or not anything is asking to sway this frame.
	var sway_decay := minf(sway_speed * delta, 1.0)
	_sway_x = lerpf(_sway_x, 0.0, sway_decay)
	_sway_y = lerpf(_sway_y, 0.0, sway_decay)
	var push_fade := wall_jump_push * 2.0 * delta
	push_x = move_toward(push_x, 0.0, push_fade)
	push_z = move_toward(push_z, 0.0, push_fade)
	if wall_riding:
		wall_ride_time += delta
		if on_floor or not host.is_on_wall() or wall_ride_time >= wall_ride_max_time or Vector2(host.velocity.x, host.velocity.z).length() < wall_ride_min_speed:
			stop_wall_ride()
		else:
			# Glue: a slight into-wall push keeps contact; move_and_slide discards it against the wall.
			var wall_normal := host.get_wall_normal()
			host.velocity.x -= wall_normal.x * 1.5
			host.velocity.z -= wall_normal.z * 1.5
	elif wall_ride_enabled and not on_floor and host.is_on_wall() and input_vec.y < -0.2 and Vector2(host.velocity.x, host.velocity.z).length() >= wall_ride_min_speed:
		_start_wall_ride()
	# Refill the air-jump budget while grounded: max_jumps counts the floor jump too, so
	# _jumps_left holds the EXTRA (mid-air) jumps still available (2 = one air jump left).
	# Coyote time: the ground jump stays available for coyote_time seconds after leaving the
	# floor WITHOUT jumping. The jump itself zeroes the timer, so a coyote jump can never be
	# followed by a second ground jump, and falling past the window grants nothing.
	if on_floor:
		_jumps_left = maxi(max_jumps - 1, 0)
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	if Input.is_action_just_pressed("ui_accept") or hopping:
		if on_floor or _coyote_timer > 0.0:
			if sliding:
				stop_sliding()
			do_jump()
		elif wall_jump_enabled and host.is_on_wall():
			do_wall_jump()
		elif _jumps_left > 0:
			_jumps_left -= 1
			do_air_jump()
	host.move_and_slide()
	if host.is_on_floor() and not was_on_floor:
		landed.emit()
	was_on_floor = host.is_on_floor()

## @ace_hidden
func _launch_jump() -> void:
	# Replace the along-gravity component with the jump - frame-aware, so "up" is
	# whatever direction gravity opposes. At default gravity this is velocity.y = jump.
	host.velocity -= _gravity_dir() * host.velocity.dot(_gravity_dir())
	host.velocity += -_gravity_dir() * jump_velocity

## @ace_action
## @ace_name("Jump")
## @ace_category("FPS Controller")
## @ace_description("Launches the host upward with Jump Velocity and fires On Jumped. The tick calls this from the floor or within Coyote Time; call it yourself for a scripted jump. Spends the coyote window, so it never grants a second ground jump.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.do_jump()")
func do_jump() -> void:
	if host == null:
		return
	_coyote_timer = 0.0
	_launch_jump()
	jumped.emit()

## @ace_action
## @ace_name("Air Jump")
## @ace_category("FPS Controller")
## @ace_description("Performs a mid-air (double) jump with Jump Velocity and fires On Air Jumped, regardless of the remaining jump budget. The tick calls this automatically when Max Jumps allows; call it yourself for a power-up jump.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.do_air_jump()")
func do_air_jump() -> void:
	if host == null:
		return
	_launch_jump()
	air_jumped.emit()

## @ace_action
## @ace_name("Add Look")
## @ace_category("FPS Controller")
## @ace_description("Turns the view by a mouse delta (pixels): yaw rotates the host, pitch tilts the Head child, clamped to Pitch Min/Max.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.add_look({x}, {y})")
func add_look(x: float, y: float) -> void:
	yaw = wrapf(yaw - x * mouse_sensitivity, -180.0, 180.0)
	pitch = clampf(pitch - y * mouse_sensitivity, pitch_min, pitch_max)
	# Sway reads the RAW look delta: a weapon lags behind how far the hands moved.
	_sway_x = x
	_sway_y = y
	if host != null:
		host.rotation_degrees.y = yaw
	var head := _head()
	if head != null:
		head.rotation_degrees.x = pitch

## @ace_action
## @ace_name("Set Third Person")
## @ace_category("FPS Controller")
## @ace_description("Switches between first person (off) and third person (on) and fires On Camera Mode Changed.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.set_third_person({enabled})")
func set_third_person(enabled: bool) -> void:
	third_person = enabled
	apply_camera_mode()
	camera_mode_changed.emit()

## @ace_action
## @ace_name("Toggle Camera Mode")
## @ace_category("FPS Controller")
## @ace_description("Flips between first and third person.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.toggle_camera_mode()")
func toggle_camera_mode() -> void:
	set_third_person(not third_person)

## @ace_action
## @ace_name("Apply Camera Mode")
## @ace_category("FPS Controller")
## @ace_description("Re-applies the current camera mode to the Head's SpringArm3D (named Arm): ~0 length in first person, Camera Distance in third.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
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
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.capture_mouse()")
func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## @ace_action
## @ace_name("Release Mouse")
## @ace_category("FPS Controller")
## @ace_description("Frees the mouse cursor.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.release_mouse()")
func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## @ace_action
## @ace_name("Set Move Speed")
## @ace_category("FPS Controller")
## @ace_description("Changes the base walking speed.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.set_move_speed({value})")
func set_move_speed(value: float) -> void:
	move_speed = value

## @ace_action
## @ace_name("Set Mouse Sensitivity")
## @ace_category("FPS Controller")
## @ace_description("Changes look sensitivity (degrees per mouse pixel).")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.set_mouse_sensitivity({value})")
func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = value

## @ace_condition
## @ace_name("Is Sprinting")
## @ace_category("FPS Controller")
## @ace_description("True while the sprint key (Shift) is held.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.is_sprinting()")
func is_sprinting() -> bool:
	return sprint_held

## @ace_condition
## @ace_name("Is First Person")
## @ace_category("FPS Controller")
## @ace_description("True in first-person camera mode.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.is_first_person()")
func is_first_person() -> bool:
	return not third_person

## @ace_expression
## @ace_name("Current Speed")
## @ace_category("FPS Controller")
## @ace_description("The host's horizontal speed right now (metres per second).")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.current_speed()")
func current_speed() -> float:
	return Vector2(host.velocity.x, host.velocity.z).length() if host != null else 0.0

## @ace_expression
## @ace_name("Look Yaw")
## @ace_category("FPS Controller")
## @ace_description("The current horizontal look angle in degrees (-180..180).")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.look_yaw()")
func look_yaw() -> float:
	return yaw

## @ace_expression
## @ace_name("Look Pitch")
## @ace_category("FPS Controller")
## @ace_description("The current vertical look angle in degrees (clamped to Pitch Min/Max).")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.look_pitch()")
func look_pitch() -> float:
	return pitch

## @ace_action
## @ace_featured
## @ace_name("Crouch")
## @ace_category("FPS Controller")
## @ace_description("Crouches: the capsule shrinks to Crouch Height (feet stay planted), the Head drops, and movement slows to the crouch multiplier. Crouching at sprint speed starts a crouch slide (see Slide knobs). Fires On Crouched. Held Ctrl does this automatically.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.do_crouch()")
func do_crouch() -> void:
	if crouching or host == null:
		return
	crouching = true
	_apply_crouch_shape(true)
	if slide_enabled and host.is_on_floor():
		var horizontal := Vector3(host.velocity.x, 0.0, host.velocity.z)
		if horizontal.length() >= slide_min_speed:
			sliding = true
			slide_time = 0.0
			var slide_direction := horizontal.normalized()
			slide_dir_x = slide_direction.x
			slide_dir_z = slide_direction.z
			slide_started.emit()
	crouched.emit()

## @ace_action
## @ace_name("Stand Up")
## @ace_category("FPS Controller")
## @ace_description("Stands back up from a crouch - unless a ceiling is in the way, in which case the crouch holds (re-check by calling again, or use the Can Stand Up condition). Ends any slide. Fires On Stood Up.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.stand_up()")
func stand_up() -> void:
	if not crouching:
		return
	if not _can_stand_up():
		return
	if sliding:
		stop_sliding()
	crouching = false
	_apply_crouch_shape(false)
	stood_up.emit()

## @ace_action
## @ace_name("Set Crouching")
## @ace_category("FPS Controller")
## @ace_description("Crouches (on) or stands (off) - the scripted version of holding/releasing Ctrl.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.set_crouching({enabled})")
func set_crouching(enabled: bool) -> void:
	if enabled:
		do_crouch()
	else:
		stand_up()

## @ace_action
## @ace_name("Stop Sliding")
## @ace_category("FPS Controller")
## @ace_description("Ends a crouch slide early (you stay crouched). Fires On Slide Ended.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.stop_sliding()")
func stop_sliding() -> void:
	if not sliding:
		return
	sliding = false
	slide_ended.emit()

## @ace_action
## @ace_featured
## @ace_name("Wall Jump")
## @ace_category("FPS Controller")
## @ace_description("Kicks off the wall the host is touching: Jump Velocity upward plus Wall Jump Push away from the wall (the push fades over about half a second). Ends any wall ride. Fires On Wall Jumped. Pressing jump mid-air against a wall does this automatically.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.do_wall_jump()")
func do_wall_jump() -> void:
	if host == null or not host.is_on_wall():
		return
	var wall_normal := host.get_wall_normal()
	if wall_riding:
		stop_wall_ride()
	push_x = wall_normal.x * wall_jump_push
	push_z = wall_normal.z * wall_jump_push
	host.velocity -= _gravity_dir() * host.velocity.dot(_gravity_dir())
	host.velocity += -_gravity_dir() * jump_velocity
	wall_jumped.emit()

## @ace_condition
## @ace_name("Can Jump")
## @ace_category("FPS Controller")
## @ace_description("True while some jump is available right now: standing on the floor, within Coyote Time after leaving it, touching a wall with Wall Jump enabled, or holding a mid-air jump. Use it to show a jump prompt or gate a jump sound.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.can_jump()")
func can_jump() -> bool:
	if host == null:
		return false
	return host.is_on_floor() or _coyote_timer > 0.0 or (wall_jump_enabled and host.is_on_wall()) or _jumps_left > 0

## @ace_action
## @ace_name("Set Coyote Time")
## @ace_category("FPS Controller")
## @ace_description("Changes the coyote grace window at runtime (0 turns it off) - a floaty-feel power-up, a hard-mode toggle, or a per-level tweak.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.set_coyote_time({seconds})")
func set_coyote_time(seconds: float) -> void:
	coyote_time = maxf(seconds, 0.0)

## @ace_action
## @ace_name("Set Move Speed While Firing")
## @ace_category("FPS Controller")
## @ace_description("Holds the host to a shooter's walking speed for a moment after a shot: sets Firing Move Speed and opens the firing window for the given seconds. Drop it on your weapon's fired trigger and the player plants their feet while shooting, then eases straight back to normal walking speed when the window closes. Sprint and crouch still multiply the firing speed, and Move Speed itself is untouched.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.set_move_speed_while_firing({speed}, {seconds})")
func set_move_speed_while_firing(speed: float, seconds: float) -> void:
	firing_move_speed = maxf(speed, 0.0)
	_firing_timer = maxf(seconds, 0.0)

## @ace_condition
## @ace_name("Is Firing")
## @ace_category("FPS Controller")
## @ace_description("True while the firing window opened by Set Move Speed While Firing is still open - the cue for a weapon-ready pose, a tighter camera, or a lowered aim sway.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.is_firing()")
func is_firing() -> bool:
	return _firing_timer > 0.0

## @ace_action
## @ace_name("Bob With Movement")
## @ace_category("FPS Controller")
## @ace_description("Bobs a weapon (or a hand, or a torch) up and down as the host runs, on a sine wave the size of Bob Amount and Bob Period long. The bob scales with how fast the host is actually moving, so it fades to nothing when you stop and never has to be turned off. Run it every tick on the node you want bobbing - the weapon's own start height is captured the first time, so wherever you placed it is where it bobs around.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.bob_with_movement({weapon})")
func bob_with_movement(weapon: Node3D) -> void:
	if weapon == null:
		return
	if not _bob_captured:
		_bob_captured = true
		_bob_base_y = weapon.position.y
	var pace := clampf(current_speed() / maxf(move_speed, 0.001), 0.0, 1.0)
	_bob_time += get_process_delta_time()
	weapon.position.y = _bob_base_y + sin(_bob_time * TAU / maxf(bob_period, 0.001)) * bob_amount * pace

## @ace_action
## @ace_name("Sway With Mouse")
## @ace_category("FPS Controller")
## @ace_description("Lets a weapon lag behind the view as you turn, by Sway Amount, catching back up at Sway Speed. It is the weight of the thing in your hands - a pistol at speed 14 flicks, a launcher at speed 5 wallows. Run it every tick on the node you want swaying.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.sway_with_mouse({weapon})")
func sway_with_mouse(weapon: Node3D) -> void:
	if weapon == null:
		return
	var catch_up := minf(sway_speed * get_process_delta_time(), 1.0)
	weapon.rotation.y = lerpf(weapon.rotation.y, -_sway_x * sway_amount, catch_up)
	weapon.rotation.x = lerpf(weapon.rotation.x, -_sway_y * sway_amount, catch_up)

## @ace_action
## @ace_name("Set Air Control")
## @ace_category("FPS Controller")
## @ace_description("Changes how much of the run the host keeps in mid-air, as a share (1 = full ground control, 0 = pure momentum). An ice level, a slow-fall power-up and a hard mode are all this one knob.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.set_air_control({share})")
func set_air_control(share: float) -> void:
	air_control = clampf(share, 0.0, 1.0)

## @ace_condition
## @ace_name("Is Bunny Hopping")
## @ace_category("FPS Controller")
## @ace_description("True on the frame a landing became the next hop instead - jump was still held as the feet touched down. The cue for a chained-hop sound, a speed streak, or the counter a speedrun HUD shows.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.is_bunny_hopping()")
func is_bunny_hopping() -> bool:
	return keep_momentum and host != null and host.is_on_floor() and Input.is_action_pressed("ui_accept")

## @ace_action
## @ace_name("Reset Jumps")
## @ace_category("FPS Controller")
## @ace_description("Refills the mid-air jump budget right now (e.g. after grabbing a double-jump power-up), so the player gets their extra jumps back without landing.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.reset_jumps()")
func reset_jumps() -> void:
	_jumps_left = maxi(max_jumps - 1, 0)

## @ace_action
## @ace_name("Stop Wall Ride")
## @ace_category("FPS Controller")
## @ace_description("Detaches from the wall immediately (full gravity resumes). Fires On Wall Ride Ended.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.stop_wall_ride()")
func stop_wall_ride() -> void:
	if not wall_riding:
		return
	wall_riding = false
	wall_ride_ended.emit()

## @ace_condition
## @ace_name("Is Crouching")
## @ace_category("FPS Controller")
## @ace_description("True while crouched (including during a crouch slide).")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.is_crouching()")
func is_crouching() -> bool:
	return crouching

## @ace_condition
## @ace_name("Is Sliding")
## @ace_category("FPS Controller")
## @ace_description("True during a crouch slide.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.is_sliding()")
func is_sliding() -> bool:
	return sliding

## @ace_condition
## @ace_name("Is Wall Riding")
## @ace_category("FPS Controller")
## @ace_description("True while riding a wall (airborne, glued to it, gravity softened).")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.is_wall_riding()")
func is_wall_riding() -> bool:
	return wall_riding

## @ace_condition
## @ace_name("Can Stand Up")
## @ace_category("FPS Controller")
## @ace_description("True when there is headroom to stand from the current crouch (no ceiling in the way).")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.can_stand_up()")
func can_stand_up() -> bool:
	return _can_stand_up()

## @ace_expression
## @ace_name("Wall Normal X")
## @ace_category("FPS Controller")
## @ace_description("The touched wall's outward normal, X component (zero when not on a wall) - with Z, the direction a wall jump pushes; feed it to camera lean.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.wall_normal_x()")
func wall_normal_x() -> float:
	return host.get_wall_normal().x if host != null and host.is_on_wall() else 0.0

## @ace_expression
## @ace_name("Wall Normal Z")
## @ace_category("FPS Controller")
## @ace_description("The touched wall's outward normal, Z component (zero when not on a wall).")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.wall_normal_z()")
func wall_normal_z() -> float:
	return host.get_wall_normal().z if host != null and host.is_on_wall() else 0.0

## @ace_action
## @ace_name("Set Gravity Direction")
## @ace_category("FPS Controller")
## @ace_description("Points gravity along a new 3D direction (normalized for you). (0, -1, 0) is normal down; (0, 1, 0) walks on ceilings - floor detection and jumps follow. A tilted direction still pulls correctly but the run plane stays world-horizontal.")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.set_gravity_direction({x}, {y}, {z})")
func set_gravity_direction(x: float, y: float, z: float) -> void:
	gravity_direction = Vector3(x, y, z)

## @ace_action
## @ace_name("Claim As Mine")
## @ace_category("FPS Controller")
## @ace_description("Marks something as belonging to this character - the round it just fired, the grenade it threw, the turret it dropped. Every ownership row afterwards traces back to this body, so friendly fire is refused, the kill is credited, and a turret this character placed still scores as its own.")
## @ace_display_template("Claim [i]{node}[/i] as mine")
## @ace_icon("res://eventsheet_addons/fps_controller/icon.svg")
## @ace_codegen_template("$FPSController.claim_as_mine({node})")
func claim_as_mine(node: Node) -> void:
	if node != null and host != null:
		node.set_meta(&"owner", host)

func _gravity_dir() -> Vector3:
	# The normalized pull axis; a zeroed export falls back to plain down.
	var pull := gravity_direction.normalized()
	return pull if pull != Vector3.ZERO else Vector3.DOWN

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look((event as InputEventMouseMotion).relative.x, (event as InputEventMouseMotion).relative.y)
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		release_mouse()

## Shrinks/restores the capsule + drops/raises the Head so crouching physically lowers the
## body. The capsule shortens toward the FLOOR (the shape node shifts down by half the lost
## height) so the feet stay planted. The shape resource is duplicated on first use - capsule
## resources are commonly shared across scenes, and crouching one character must not shrink
## every other user of that resource.
## @ace_hidden
func _apply_crouch_shape(low: bool) -> void:
	var shape_node := _capsule()
	if shape_node != null:
		var capsule := shape_node.shape as CapsuleShape3D
		if standing_height <= 0.0:
			standing_height = capsule.height
			standing_radius = capsule.radius
			shape_base_y = shape_node.position.y
			var head_node := _head()
			head_base_y = head_node.position.y if head_node != null else 0.0
			shape_node.shape = capsule.duplicate()
			capsule = shape_node.shape as CapsuleShape3D
		var low_height: float = minf(crouch_height, standing_height)
		capsule.height = low_height if low else standing_height
		# A crouch below capsule-diameter auto-shrinks the radius; put it back on stand.
		if not low:
			capsule.radius = standing_radius
		shape_node.position.y = shape_base_y - ((standing_height - low_height) * 0.5 if low else 0.0)
	var head := _head()
	if head != null and standing_height > 0.0:
		head.position.y = head_base_y - ((standing_height - minf(crouch_height, standing_height)) if low else 0.0)

## Headroom test for standing up: sweeps the (crouched) body upward by the height it would
## regain; any hit means a ceiling is in the way and the crouch holds. The sweep needs a
## live physics space - outside the tree (headless tools/tests) standing is always allowed.
## @ace_hidden
func _can_stand_up() -> bool:
	if host == null or standing_height <= 0.0 or not host.is_inside_tree():
		return true
	var params := PhysicsTestMotionParameters3D.new()
	params.from = host.global_transform
	params.motion = -_gravity_dir() * (standing_height - minf(crouch_height, standing_height))
	return not PhysicsServer3D.body_test_motion(host.get_rid(), params)

## @ace_hidden
func _start_wall_ride() -> void:
	wall_riding = true
	wall_ride_time = 0.0
	if host != null:
		# Soften the fall (keep 25% of the along-gravity speed) - frame-aware, so it
		# reads the same under flipped gravity.
		var fall := host.velocity.dot(_gravity_dir())
		if fall > 0.0:
			host.velocity -= _gravity_dir() * fall * 0.75
	wall_ride_started.emit()

# FPS/TPS controller behavior: mouse look + WASD move + sprint + jump on the host CharacterBody3D; a SpringArm3D named Arm under a Head child switches first/third person. Set Max Jumps to 2 for a double jump (3 for a triple) - extra jumps happen in mid-air and fire On Air Jumped. Coyote Time keeps the ground jump available for a moment after walking off a ledge. Movement tech included: crouch (hold Ctrl, capsule shrinks, ceiling-checked stand), crouch slide (crouch while sprinting), wall ride (hold forward against a wall mid-air), and wall jump (jump off any wall mid-air).
