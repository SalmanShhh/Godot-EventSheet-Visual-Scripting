## @ace_tags(vehicle, physics)
## @ace_category("Physics Car")
@icon("res://eventsheet_addons/physics_car/icon.svg")
class_name PhysicsCar
extends Node
## Turns a RigidBody2D into a drivable arcade car: throttle, brake, and steering forces plus lateral grip and drift detection on top of the real physics body, so collisions and pushes stay fully physical. Drive it with Simulate Control, feed it analog Set Throttle / Set Steer values, or let it steer itself with Drive Toward Position.

## The node this behavior acts on (its parent). Required host: RigidBody2D.
var host: RigidBody2D = null

func _enter_tree() -> void:
	host = get_parent() as RigidBody2D
	if host == null:
		push_warning("PhysicsCar behavior requires a RigidBody2D parent.")

## @ace_trigger
## @ace_name("On Collided")
signal on_collided
## @ace_trigger
## @ace_name("On Drift Started")
signal on_drift_started
## @ace_trigger
## @ace_name("On Drift Ended")
signal on_drift_ended
## @ace_trigger
## @ace_name("On Drive Target Reached")
signal on_drive_target_reached

# --- Designer knobs (tune the FEEL in the Inspector) ---
## Top forward speed, in pixels per second.
@export var max_speed: float = 400.0
## Forward push strength (how hard the engine accelerates).
@export var acceleration: float = 1800.0
## Top reverse speed, in pixels per second.
@export var reverse_max_speed: float = 180.0
## Reverse push strength.
@export var reverse_acceleration: float = 900.0
## Braking strength.
@export var brake_force: float = 2800.0
## Coasting drag when you are off the throttle (higher = slows sooner).
@export_range(0.0, 4.0, 0.05) var coast_drag: float = 0.4
## Turn rate at full steer and full speed, in radians per second.
@export_range(0.5, 12.0, 0.1) var steer_rate: float = 3.2
## Ease steering in with speed, so a near-stopped car barely turns.
@export var speed_based_steering: bool = true
## Speed at which steering reaches full strength (with speed-based steering on).
@export var min_steer_speed: float = 40.0
## Sideways grip: how much side-slip is cancelled each step (1 = glued, 0 = ice).
@export_range(0.0, 1.0, 0.01) var grip: float = 0.78
## Slip angle (degrees between where the car points and where it moves) that counts as a drift.
@export_range(1.0, 60.0, 1.0) var drift_threshold: float = 12.0
## Grip while the handbrake is held (low = easy to slide the back out).
@export_range(0.0, 1.0, 0.01) var handbrake_grip: float = 0.06
## How close (pixels) a Drive Toward target must be to count as reached.
@export var reach_distance: float = 16.0

# --- Input state (set by the actions; persists until you change it or call Stop) ---
var throttle: float = 0.0
var brake: float = 0.0
var steer: float = 0.0
# Handbrake is momentary: it resets every physics step, so hold it by calling Enable Handbrake each frame.
var _handbrake: bool = false
# "" | "angle" | "position": which auto-steer mode Drive Toward set (cleared by manual input / Stop).
var _drive_mode: String = ""
var _drive_target: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _reached: bool = false
# --- Cached readings (for the conditions + expressions) ---
var _drifting: bool = false
var _drift_time: float = 0.0
var _surface_grip: float = 1.0
var _surface_resist: float = 1.0
var _speed: float = 0.0
var _fwd_speed: float = 0.0
var _lat_speed: float = 0.0
var _slip: float = 0.0
var _motion_angle: float = 0.0
var _heading_error: float = 0.0
var _eff_grip: float = 0.0
var _target_dist: float = 0.0
var _collision_force: float = 0.0
var _collision_angle: float = 0.0

func _ready() -> void:
	if host is RigidBody2D:
		var body: RigidBody2D = host as RigidBody2D
		body.contact_monitor = true
		if body.max_contacts_reported < 4:
			body.max_contacts_reported = 4
		if not body.body_entered.is_connected(_on_body_entered):
			body.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_drive(delta)

## @ace_action
## @ace_name("Set Throttle")
## @ace_category("Physics Car")
## @ace_description("Sets the throttle from -1 (full reverse) to 1 (full forward). Persists until you change it or call Stop.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.set_throttle({amount})")
func set_throttle(amount: float) -> void:
	throttle = clampf(amount, -1.0, 1.0)
	_drive_mode = ""

## @ace_action
## @ace_name("Set Brake")
## @ace_category("Physics Car")
## @ace_description("Sets the brake from 0 (off) to 1 (full). Braking slows the car without reversing it.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.set_brake({amount})")
func set_brake(amount: float) -> void:
	brake = clampf(amount, 0.0, 1.0)

## @ace_action
## @ace_name("Set Steer")
## @ace_category("Physics Car")
## @ace_description("Sets the steering from -1 (full left) to 1 (full right). Persists until you change it or call Stop.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.set_steer({amount})")
func set_steer(amount: float) -> void:
	steer = clampf(amount, -1.0, 1.0)
	_drive_mode = ""

## @ace_action
## @ace_name("Simulate Control")
## @ace_category("Physics Car")
## @ace_description("The keyboard-style control: pass "up" / "down" / "left" / "right" while the key is held, or "stop" to release. Call it every frame the key is down (pair with Stop when no key is down).")
## @ace_param_options(direction up, down, left, right, stop)
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.simulate_control({direction})")
func simulate_control(direction: String) -> void:
	_drive_mode = ""
	match direction:
		"up": throttle = 1.0
		"down": throttle = -1.0
		"left": steer = -1.0
		"right": steer = 1.0
		"stop": throttle = 0.0
	if direction == "stop":
		steer = 0.0
		brake = 0.0

## @ace_action
## @ace_name("Stop")
## @ace_category("Physics Car")
## @ace_description("Clears throttle, brake, and steer, and exits any Drive Toward mode. The car coasts to rest.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.stop()")
func stop() -> void:
	throttle = 0.0
	brake = 0.0
	steer = 0.0
	_drive_mode = ""

## @ace_action
## @ace_name("Enable Handbrake")
## @ace_category("Physics Car")
## @ace_description("Cuts the grip for this one physics frame, so the back end slides. Call it every frame you want the handbrake held.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.enable_handbrake()")
func enable_handbrake() -> void:
	_handbrake = true

## @ace_action
## @ace_name("Drive Toward Angle")
## @ace_category("Physics Car")
## @ace_description("Auto-steers toward a heading (degrees) and applies throttle. Call it each frame; the car turns until it faces within the tolerance. Sets the Is Driving Toward Angle mode.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.drive_toward_angle({target_angle}, {throttle_amount}, {max_steer}, {tolerance})")
func drive_toward_angle(target_angle: float, throttle_amount: float, max_steer: float, tolerance: float) -> void:
	_drive_mode = "angle"
	var body: RigidBody2D = host as RigidBody2D
	if body == null:
		return
	_heading_error = wrapf(target_angle - rad_to_deg(body.rotation), -180.0, 180.0)
	throttle = clampf(throttle_amount, -1.0, 1.0)
	steer = _steer_for(_heading_error, tolerance, max_steer)

## @ace_action
## @ace_name("Drive Toward Position")
## @ace_category("Physics Car")
## @ace_description("Auto-steers toward a world position and applies throttle. Call it each frame (for example toward a waypoint). Fires On Drive Target Reached inside the reach distance. Sets the Is Driving Toward Position mode.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.drive_toward_position({x}, {y}, {throttle_amount}, {max_steer}, {tolerance})")
func drive_toward_position(x: float, y: float, throttle_amount: float, max_steer: float, tolerance: float) -> void:
	_drive_mode = "position"
	var target: Vector2 = Vector2(x, y)
	if _drive_target.distance_to(target) > 1.0:
		_reached = false
	_drive_target = target
	_has_target = true
	var body: RigidBody2D = host as RigidBody2D
	if body == null:
		return
	_heading_error = wrapf(rad_to_deg((target - body.global_position).angle()) - rad_to_deg(body.rotation), -180.0, 180.0)
	throttle = clampf(throttle_amount, -1.0, 1.0)
	steer = _steer_for(_heading_error, tolerance, max_steer)

## @ace_action
## @ace_name("Teleport")
## @ace_category("Physics Car")
## @ace_description("Moves the car to a position and clears its velocity and spin (for respawns and resets).")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.teleport({x}, {y})")
func teleport(x: float, y: float) -> void:
	var body: RigidBody2D = host as RigidBody2D
	if body == null:
		return
	body.global_position = Vector2(x, y)
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0

## @ace_action
## @ace_name("Set Max Speed")
## @ace_category("Physics Car")
## @ace_description("Changes the top forward speed at runtime (for boosts or speed caps).")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.set_max_speed({value})")
func set_max_speed(value: float) -> void:
	max_speed = maxf(value, 0.0)

## @ace_action
## @ace_name("Set Grip")
## @ace_category("Physics Car")
## @ace_description("Changes the base sideways grip at runtime (1 = glued, 0 = ice).")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.set_grip({value})")
func set_grip(value: float) -> void:
	grip = clampf(value, 0.0, 1.0)

## @ace_action
## @ace_name("Set Surface Grip")
## @ace_category("Physics Car")
## @ace_description("Sets a terrain grip multiplier on top of the base grip (for example 0.2 on ice, 0.45 in mud). 1 = no change.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.set_surface_grip({multiplier})")
func set_surface_grip(multiplier: float) -> void:
	_surface_grip = maxf(multiplier, 0.0)

## @ace_action
## @ace_name("Set Surface Resistance")
## @ace_category("Physics Car")
## @ace_description("Sets a terrain drag multiplier (above 1 = sticky mud that slows you, below 1 = slick). 1 = no change.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.set_surface_resistance({multiplier})")
func set_surface_resistance(multiplier: float) -> void:
	_surface_resist = maxf(multiplier, 0.0)

## @ace_action
## @ace_name("Reset Surface")
## @ace_category("Physics Car")
## @ace_description("Restores both terrain multipliers to 1 (call it when the car leaves a terrain zone).")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.reset_surface()")
func reset_surface() -> void:
	_surface_grip = 1.0
	_surface_resist = 1.0

## @ace_action
## @ace_name("Set Reach Distance")
## @ace_category("Physics Car")
## @ace_description("Sets how close (pixels) a Drive Toward target must be to fire On Drive Target Reached.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.set_reach_distance({distance})")
func set_reach_distance(distance: float) -> void:
	reach_distance = maxf(distance, 0.0)

## @ace_condition
## @ace_name("Is Moving")
## @ace_category("Physics Car")
## @ace_description("Whether the car is above a small movement speed.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.is_moving()")
func is_moving() -> bool:
	return _speed > 5.0

## @ace_condition
## @ace_name("Is Reversing")
## @ace_category("Physics Car")
## @ace_description("Whether the car is moving backwards.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.is_reversing()")
func is_reversing() -> bool:
	return _fwd_speed < -1.0

## @ace_condition
## @ace_name("Is Drifting")
## @ace_category("Physics Car")
## @ace_description("Whether the slip angle is past the drift threshold.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.is_drifting()")
func is_drifting() -> bool:
	return _drifting

## @ace_condition
## @ace_name("Is Handbrake Active")
## @ace_category("Physics Car")
## @ace_description("Whether the handbrake was requested this physics frame.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.is_handbrake_active()")
func is_handbrake_active() -> bool:
	return _handbrake

## @ace_condition
## @ace_name("Is At Max Speed")
## @ace_category("Physics Car")
## @ace_description("Whether the car has hit its forward speed cap.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.is_at_max_speed()")
func is_at_max_speed() -> bool:
	return _fwd_speed >= max_speed - 1.0

## @ace_condition
## @ace_name("Has Reached Drive Target")
## @ace_category("Physics Car")
## @ace_description("Whether the last Drive Toward Position target has been reached.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.has_reached_target()")
func has_reached_target() -> bool:
	return _reached

## @ace_condition
## @ace_name("Has Surface Override")
## @ace_category("Physics Car")
## @ace_description("Whether a terrain grip or resistance multiplier is currently in effect.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.has_surface_override()")
func has_surface_override() -> bool:
	return not is_equal_approx(_surface_grip, 1.0) or not is_equal_approx(_surface_resist, 1.0)

## @ace_condition
## @ace_name("Is Driving Toward Angle")
## @ace_category("Physics Car")
## @ace_description("Whether the car is in Drive Toward Angle mode.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.is_driving_toward_angle()")
func is_driving_toward_angle() -> bool:
	return _drive_mode == "angle"

## @ace_condition
## @ace_name("Is Driving Toward Position")
## @ace_category("Physics Car")
## @ace_description("Whether the car is in Drive Toward Position mode.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.is_driving_toward_position()")
func is_driving_toward_position() -> bool:
	return _drive_mode == "position"

## @ace_expression
## @ace_name("Speed")
## @ace_category("Physics Car")
## @ace_description("Current speed, in pixels per second.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.speed()")
func speed() -> float:
	return _speed

## @ace_expression
## @ace_name("Forward Speed")
## @ace_category("Physics Car")
## @ace_description("Speed along the way the car faces (negative when reversing).")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.forward_speed()")
func forward_speed() -> float:
	return _fwd_speed

## @ace_expression
## @ace_name("Lateral Speed")
## @ace_category("Physics Car")
## @ace_description("Sideways slide speed (the part grip fights).")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.lateral_speed()")
func lateral_speed() -> float:
	return _lat_speed

## @ace_expression
## @ace_name("Angle Of Motion")
## @ace_category("Physics Car")
## @ace_description("The direction the car is actually moving, in degrees.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.angle_of_motion()")
func angle_of_motion() -> float:
	return _motion_angle

## @ace_expression
## @ace_name("Slip Angle")
## @ace_category("Physics Car")
## @ace_description("Degrees between where the car points and where it moves.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.slip_angle()")
func slip_angle() -> float:
	return _slip

## @ace_expression
## @ace_name("Drift Duration")
## @ace_category("Physics Car")
## @ace_description("Seconds the current drift has lasted (or the final length inside On Drift Ended).")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.drift_duration()")
func drift_duration() -> float:
	return _drift_time

## @ace_expression
## @ace_name("Throttle Input")
## @ace_category("Physics Car")
## @ace_description("The current throttle value (-1 to 1).")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.throttle_input()")
func throttle_input() -> float:
	return throttle

## @ace_expression
## @ace_name("Brake Input")
## @ace_category("Physics Car")
## @ace_description("The current brake value (0 to 1).")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.brake_input()")
func brake_input() -> float:
	return brake

## @ace_expression
## @ace_name("Steer Input")
## @ace_category("Physics Car")
## @ace_description("The current steer value (-1 to 1).")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.steer_input()")
func steer_input() -> float:
	return steer

## @ace_expression
## @ace_name("Heading Error")
## @ace_category("Physics Car")
## @ace_description("Signed degrees a Drive Toward action still needs to turn.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.heading_error()")
func heading_error() -> float:
	return _heading_error

## @ace_expression
## @ace_name("Drive Target Distance")
## @ace_category("Physics Car")
## @ace_description("Distance to the current Drive Toward Position target (0 if none).")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.drive_target_distance()")
func drive_target_distance() -> float:
	return _target_dist

## @ace_expression
## @ace_name("Effective Grip")
## @ace_category("Physics Car")
## @ace_description("The final grip after handbrake and terrain multipliers.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.effective_grip()")
func effective_grip() -> float:
	return _eff_grip

## @ace_expression
## @ace_name("Surface Grip Multiplier")
## @ace_category("Physics Car")
## @ace_description("The active terrain grip multiplier.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.surface_grip_multiplier()")
func surface_grip_multiplier() -> float:
	return _surface_grip

## @ace_expression
## @ace_name("Surface Resistance Multiplier")
## @ace_category("Physics Car")
## @ace_description("The active terrain drag multiplier.")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.surface_resistance_multiplier()")
func surface_resistance_multiplier() -> float:
	return _surface_resist

## @ace_expression
## @ace_name("Collision Force")
## @ace_category("Physics Car")
## @ace_description("Approximate impact speed of the latest collision (inside On Collided).")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.collision_force()")
func collision_force() -> float:
	return _collision_force

## @ace_expression
## @ace_name("Collision Angle")
## @ace_category("Physics Car")
## @ace_description("Approximate impact direction in degrees (inside On Collided).")
## @ace_icon("res://eventsheet_addons/physics_car/icon.svg")
## @ace_codegen_template("$PhysicsCar.collision_angle()")
func collision_angle() -> float:
	return _collision_angle

func _on_body_entered(_other: Node) -> void:
	# Records an impact from the body's own collision so On Collided can report it.
	_collision_force = _speed
	var body: RigidBody2D = host as RigidBody2D
	if body != null:
		_collision_angle = rad_to_deg(body.linear_velocity.angle())
	on_collided.emit()

func _drive(delta: float) -> void:
	# The whole car in one physics step: read the body's motion, detect drift, then apply drive,
	# brake, coast, steering, and lateral-grip forces. Collisions stay the body's job.
	var body: RigidBody2D = host as RigidBody2D
	if body == null:
		return
	var fwd: Vector2 = Vector2.RIGHT.rotated(body.rotation)
	var vel: Vector2 = body.linear_velocity
	_speed = vel.length()
	_fwd_speed = vel.dot(fwd)
	var lat_dir: Vector2 = fwd.orthogonal()
	_lat_speed = vel.dot(lat_dir)
	_slip = rad_to_deg(absf(vel.angle_to(fwd))) if _speed > 5.0 else 0.0
	if _speed > 0.1:
		_motion_angle = rad_to_deg(vel.angle())
	var now_drift: bool = _slip > drift_threshold and _speed > min_steer_speed
	if now_drift and not _drifting:
		_drifting = true
		_drift_time = 0.0
		on_drift_started.emit()
	elif not now_drift and _drifting:
		_drifting = false
		on_drift_ended.emit()
	if _drifting:
		_drift_time += delta
	if throttle > 0.0 and _fwd_speed < max_speed:
		body.apply_central_force(fwd * throttle * acceleration)
	elif throttle < 0.0 and _fwd_speed > -reverse_max_speed:
		body.apply_central_force(fwd * throttle * reverse_acceleration)
	if brake > 0.0 and _speed > 1.0:
		body.apply_central_force(-vel.normalized() * brake * brake_force)
	if is_zero_approx(throttle):
		body.apply_central_force(-vel * coast_drag * _surface_resist)
	var factor: float = 1.0
	if speed_based_steering:
		factor = clampf(_speed / maxf(min_steer_speed, 0.001), 0.0, 1.0)
	var dir_sign: float = 1.0 if _fwd_speed >= 0.0 else -1.0
	body.angular_velocity = steer * steer_rate * factor * dir_sign
	_eff_grip = clampf((handbrake_grip if _handbrake else grip) * _surface_grip, 0.0, 1.0)
	body.apply_central_impulse(-lat_dir * _lat_speed * _eff_grip * body.mass)
	_target_dist = body.global_position.distance_to(_drive_target) if _has_target else 0.0
	if _has_target and not _reached and _target_dist <= reach_distance:
		_reached = true
		on_drive_target_reached.emit()
	_handbrake = false

func _steer_for(error_deg: float, tolerance: float, max_steer: float) -> float:
	# Shared steering math for the Drive Toward actions: proportional to the heading error, zero
	# inside the tolerance, clamped by max_steer.
	if absf(error_deg) <= tolerance:
		return 0.0
	return clampf(error_deg / 45.0, -1.0, 1.0) * clampf(max_steer, 0.0, 1.0)

# PhysicsCar: attach to a RigidBody2D. Each physics frame it turns your throttle / brake / steer inputs into forces, fights sideways slide with grip, and detects drift. Drive it with Set Throttle + Set Steer, the keyboard-style Simulate Control, or point it at a target with Drive Toward Angle / Position. This pack is an event sheet - extend it by editing it.
