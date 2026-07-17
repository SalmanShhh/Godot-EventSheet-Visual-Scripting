# Pack builder - physics_car (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## PhysicsCar: a force-driven arcade car as a per-node BEHAVIOR you attach to a RigidBody2D. The body
## itself handles all the collisions, pushes, and impacts; this behavior adds drive input, steering,
## lateral grip (so the car does not slide sideways like ice), and drift detection - the repetitive
## steering / grip / drift math you would otherwise hand-write every project. It suits both the player
## (Set Throttle / Set Steer, or the keyboard-style Simulate Control) and AI (Drive Toward Angle /
## Drive Toward Position). Ported to be Godot-native and beginner-friendly:
##  - The host IS the RigidBody2D - Godot's own physics body - so there is no separate physics component
##    to add and keep in sync.
##  - Movement is real forces and impulses, so collisions stay physical.
##  - Steering, grip, and drift are tuned entirely from Inspector knobs; terrain is two runtime
##    multipliers (grip + resistance) for mud / ice / grass.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "RigidBody2D"
	sheet.custom_class_name = "PhysicsCar"
	sheet.class_description = "Turns a RigidBody2D into a drivable arcade car: throttle, brake, and steering forces plus lateral grip and drift detection on top of the real physics body, so collisions and pushes stay fully physical. Drive it with Simulate Control, feed it analog Set Throttle / Set Steer values, or let it steer itself with Drive Toward Position."
	sheet.addon_category = "Physics Car"
	sheet.addon_tags = PackedStringArray(["vehicle", "physics"])
	var about: CommentRow = CommentRow.new()
	about.text = "PhysicsCar: attach to a RigidBody2D. Each physics frame it turns your throttle / brake / steer inputs into forces, fights sideways slide with grip, and detects drift. Drive it with Set Throttle + Set Steer, the keyboard-style Simulate Control, or point it at a target with Drive Toward Angle / Position. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune the FEEL in the Inspector) ---",
		"## Top forward speed, in pixels per second.",
		"@export var max_speed: float = 400.0",
		"## Forward push strength (how hard the engine accelerates).",
		"@export var acceleration: float = 1800.0",
		"## Top reverse speed, in pixels per second.",
		"@export var reverse_max_speed: float = 180.0",
		"## Reverse push strength.",
		"@export var reverse_acceleration: float = 900.0",
		"## Braking strength.",
		"@export var brake_force: float = 2800.0",
		"## Coasting drag when you are off the throttle (higher = slows sooner).",
		"@export_range(0.0, 4.0, 0.05) var coast_drag: float = 0.4",
		"## Turn rate at full steer and full speed, in radians per second.",
		"@export_range(0.5, 12.0, 0.1) var steer_rate: float = 3.2",
		"## Ease steering in with speed, so a near-stopped car barely turns.",
		"@export var speed_based_steering: bool = true",
		"## Speed at which steering reaches full strength (with speed-based steering on).",
		"@export var min_steer_speed: float = 40.0",
		"## Sideways grip: how much side-slip is cancelled each step (1 = glued, 0 = ice).",
		"@export_range(0.0, 1.0, 0.01) var grip: float = 0.78",
		"## Slip angle (degrees between where the car points and where it moves) that counts as a drift.",
		"@export_range(1.0, 60.0, 1.0) var drift_threshold: float = 12.0",
		"## Grip while the handbrake is held (low = easy to slide the back out).",
		"@export_range(0.0, 1.0, 0.01) var handbrake_grip: float = 0.06",
		"## How close (pixels) a Drive Toward target must be to count as reached.",
		"@export var reach_distance: float = 16.0",
		"",
		"# --- Input state (set by the actions; persists until you change it or call Stop) ---",
		"var throttle: float = 0.0",
		"var brake: float = 0.0",
		"var steer: float = 0.0",
		"# Handbrake is momentary: it resets every physics step, so hold it by calling Enable Handbrake each frame.",
		"var _handbrake: bool = false",
		"# \"\" | \"angle\" | \"position\": which auto-steer mode Drive Toward set (cleared by manual input / Stop).",
		"var _drive_mode: String = \"\"",
		"var _drive_target: Vector2 = Vector2.ZERO",
		"var _has_target: bool = false",
		"var _reached: bool = false",
		"# --- Cached readings (for the conditions + expressions) ---",
		"var _drifting: bool = false",
		"var _drift_time: float = 0.0",
		"var _surface_grip: float = 1.0",
		"var _surface_resist: float = 1.0",
		"var _speed: float = 0.0",
		"var _fwd_speed: float = 0.0",
		"var _lat_speed: float = 0.0",
		"var _slip: float = 0.0",
		"var _motion_angle: float = 0.0",
		"var _heading_error: float = 0.0",
		"var _eff_grip: float = 0.0",
		"var _target_dist: float = 0.0",
		"var _collision_force: float = 0.0",
		"var _collision_angle: float = 0.0",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Collided\")",
		"signal on_collided()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Drift Started\")",
		"signal on_drift_started()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Drift Ended\")",
		"signal on_drift_ended()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Drive Target Reached\")",
		"signal on_drive_target_reached()",
		"",
		"# Records an impact from the body's own collision so On Collided can report it.",
		"func _on_body_entered(_other: Node) -> void:",
		"\t_collision_force = _speed",
		"\tvar body: RigidBody2D = host as RigidBody2D",
		"\tif body != null:",
		"\t\t_collision_angle = rad_to_deg(body.linear_velocity.angle())",
		"\ton_collided.emit()",
		"",
		"# The whole car in one physics step: read the body's motion, detect drift, then apply drive,",
		"# brake, coast, steering, and lateral-grip forces. Collisions stay the body's job.",
		"func _drive(delta: float) -> void:",
		"\tvar body: RigidBody2D = host as RigidBody2D",
		"\tif body == null:",
		"\t\treturn",
		"\tvar fwd: Vector2 = Vector2.RIGHT.rotated(body.rotation)",
		"\tvar vel: Vector2 = body.linear_velocity",
		"\t_speed = vel.length()",
		"\t_fwd_speed = vel.dot(fwd)",
		"\tvar lat_dir: Vector2 = fwd.orthogonal()",
		"\t_lat_speed = vel.dot(lat_dir)",
		"\t_slip = rad_to_deg(absf(vel.angle_to(fwd))) if _speed > 5.0 else 0.0",
		"\tif _speed > 0.1:",
		"\t\t_motion_angle = rad_to_deg(vel.angle())",
		"\tvar now_drift: bool = _slip > drift_threshold and _speed > min_steer_speed",
		"\tif now_drift and not _drifting:",
		"\t\t_drifting = true",
		"\t\t_drift_time = 0.0",
		"\t\ton_drift_started.emit()",
		"\telif not now_drift and _drifting:",
		"\t\t_drifting = false",
		"\t\ton_drift_ended.emit()",
		"\tif _drifting:",
		"\t\t_drift_time += delta",
		"\tif throttle > 0.0 and _fwd_speed < max_speed:",
		"\t\tbody.apply_central_force(fwd * throttle * acceleration)",
		"\telif throttle < 0.0 and _fwd_speed > -reverse_max_speed:",
		"\t\tbody.apply_central_force(fwd * throttle * reverse_acceleration)",
		"\tif brake > 0.0 and _speed > 1.0:",
		"\t\tbody.apply_central_force(-vel.normalized() * brake * brake_force)",
		"\tif is_zero_approx(throttle):",
		"\t\tbody.apply_central_force(-vel * coast_drag * _surface_resist)",
		"\tvar factor: float = 1.0",
		"\tif speed_based_steering:",
		"\t\tfactor = clampf(_speed / maxf(min_steer_speed, 0.001), 0.0, 1.0)",
		"\tvar dir_sign: float = 1.0 if _fwd_speed >= 0.0 else -1.0",
		"\tbody.angular_velocity = steer * steer_rate * factor * dir_sign",
		"\t_eff_grip = clampf((handbrake_grip if _handbrake else grip) * _surface_grip, 0.0, 1.0)",
		"\tbody.apply_central_impulse(-lat_dir * _lat_speed * _eff_grip * body.mass)",
		"\t_target_dist = body.global_position.distance_to(_drive_target) if _has_target else 0.0",
		"\tif _has_target and not _reached and _target_dist <= reach_distance:",
		"\t\t_reached = true",
		"\t\ton_drive_target_reached.emit()",
		"\t_handbrake = false",
		"",
		"# Shared steering math for the Drive Toward actions: proportional to the heading error, zero",
		"# inside the tolerance, clamped by max_steer.",
		"func _steer_for(error_deg: float, tolerance: float, max_steer: float) -> float:",
		"\tif absf(error_deg) <= tolerance:",
		"\t\treturn 0.0",
		"\treturn clampf(error_deg / 45.0, -1.0, 1.0) * clampf(max_steer, 0.0, 1.0)"
	]))
	sheet.events.append(block)
	# Enable the body's contact reporting once so On Collided can fire, and wire the impact handler.
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"if host is RigidBody2D:",
		"\tvar body: RigidBody2D = host as RigidBody2D",
		"\tbody.contact_monitor = true",
		"\tif body.max_contacts_reported < 4:",
		"\t\tbody.max_contacts_reported = 4",
		"\tif not body.body_entered.is_connected(_on_body_entered):",
		"\t\tbody.body_entered.connect(_on_body_entered)"
	]))
	on_ready.actions.append(ready_body)
	sheet.events.append(on_ready)
	# Drive the car every physics frame.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "_drive(delta)"
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# --- Driving input ---
	Lib.append_function(sheet, "set_throttle", "Set Throttle", "Physics Car", "Sets the throttle from -1 (full reverse) to 1 (full forward). Persists until you change it or call Stop.",
		[["amount", "float"]],
		"throttle = clampf(amount, -1.0, 1.0)\n_drive_mode = \"\"")
	_default(sheet, "amount", "1.0")
	Lib.append_function(sheet, "set_brake", "Set Brake", "Physics Car", "Sets the brake from 0 (off) to 1 (full). Braking slows the car without reversing it.",
		[["amount", "float"]],
		"brake = clampf(amount, 0.0, 1.0)")
	_default(sheet, "amount", "1.0")
	Lib.append_function(sheet, "set_steer", "Set Steer", "Physics Car", "Sets the steering from -1 (full left) to 1 (full right). Persists until you change it or call Stop.",
		[["amount", "float"]],
		"steer = clampf(amount, -1.0, 1.0)\n_drive_mode = \"\"")
	_default(sheet, "amount", "1.0")
	Lib.append_function(sheet, "simulate_control", "Simulate Control", "Physics Car", "The keyboard-style control: pass \"up\" / \"down\" / \"left\" / \"right\" while the key is held, or \"stop\" to release. Call it every frame the key is down (pair with Stop when no key is down).",
		[["direction", "String"]],
		"_drive_mode = \"\"\nmatch direction:\n\t\"up\": throttle = 1.0\n\t\"down\": throttle = -1.0\n\t\"left\": steer = -1.0\n\t\"right\": steer = 1.0\n\t\"stop\": throttle = 0.0\nif direction == \"stop\":\n\tsteer = 0.0\n\tbrake = 0.0")
	_param_options(sheet, "direction", ["up", "down", "left", "right", "stop"])
	_default(sheet, "direction", "up")
	Lib.append_function(sheet, "stop", "Stop", "Physics Car", "Clears throttle, brake, and steer, and exits any Drive Toward mode. The car coasts to rest.",
		[],
		"throttle = 0.0\nbrake = 0.0\nsteer = 0.0\n_drive_mode = \"\"")
	Lib.append_function(sheet, "enable_handbrake", "Enable Handbrake", "Physics Car", "Cuts the grip for this one physics frame, so the back end slides. Call it every frame you want the handbrake held.",
		[],
		"_handbrake = true")

	# --- AI steering ---
	Lib.append_function(sheet, "drive_toward_angle", "Drive Toward Angle", "Physics Car", "Auto-steers toward a heading (degrees) and applies throttle. Call it each frame; the car turns until it faces within the tolerance. Sets the Is Driving Toward Angle mode.",
		[["target_angle", "float"], ["throttle_amount", "float"], ["max_steer", "float"], ["tolerance", "float"]],
		"_drive_mode = \"angle\"\nvar body: RigidBody2D = host as RigidBody2D\nif body == null:\n\treturn\n_heading_error = wrapf(target_angle - rad_to_deg(body.rotation), -180.0, 180.0)\nthrottle = clampf(throttle_amount, -1.0, 1.0)\nsteer = _steer_for(_heading_error, tolerance, max_steer)")
	_default(sheet, "throttle_amount", "1.0")
	_default(sheet, "max_steer", "1.0")
	_default(sheet, "tolerance", "5.0")
	Lib.append_function(sheet, "drive_toward_position", "Drive Toward Position", "Physics Car", "Auto-steers toward a world position and applies throttle. Call it each frame (for example toward a waypoint). Fires On Drive Target Reached inside the reach distance. Sets the Is Driving Toward Position mode.",
		[["x", "float"], ["y", "float"], ["throttle_amount", "float"], ["max_steer", "float"], ["tolerance", "float"]],
		"_drive_mode = \"position\"\nvar target: Vector2 = Vector2(x, y)\nif _drive_target.distance_to(target) > 1.0:\n\t_reached = false\n_drive_target = target\n_has_target = true\nvar body: RigidBody2D = host as RigidBody2D\nif body == null:\n\treturn\n_heading_error = wrapf(rad_to_deg((target - body.global_position).angle()) - rad_to_deg(body.rotation), -180.0, 180.0)\nthrottle = clampf(throttle_amount, -1.0, 1.0)\nsteer = _steer_for(_heading_error, tolerance, max_steer)")
	_default(sheet, "throttle_amount", "1.0")
	_default(sheet, "max_steer", "1.0")
	_default(sheet, "tolerance", "5.0")

	# --- Setup + terrain ---
	Lib.append_function(sheet, "teleport", "Teleport", "Physics Car", "Moves the car to a position and clears its velocity and spin (for respawns and resets).",
		[["x", "float"], ["y", "float"]],
		"var body: RigidBody2D = host as RigidBody2D\nif body == null:\n\treturn\nbody.global_position = Vector2(x, y)\nbody.linear_velocity = Vector2.ZERO\nbody.angular_velocity = 0.0")
	Lib.append_function(sheet, "set_max_speed", "Set Max Speed", "Physics Car", "Changes the top forward speed at runtime (for boosts or speed caps).",
		[["value", "float"]],
		"max_speed = maxf(value, 0.0)")
	Lib.append_function(sheet, "set_grip", "Set Grip", "Physics Car", "Changes the base sideways grip at runtime (1 = glued, 0 = ice).",
		[["value", "float"]],
		"grip = clampf(value, 0.0, 1.0)")
	Lib.append_function(sheet, "set_surface_grip", "Set Surface Grip", "Physics Car", "Sets a terrain grip multiplier on top of the base grip (for example 0.2 on ice, 0.45 in mud). 1 = no change.",
		[["multiplier", "float"]],
		"_surface_grip = maxf(multiplier, 0.0)")
	Lib.append_function(sheet, "set_surface_resistance", "Set Surface Resistance", "Physics Car", "Sets a terrain drag multiplier (above 1 = sticky mud that slows you, below 1 = slick). 1 = no change.",
		[["multiplier", "float"]],
		"_surface_resist = maxf(multiplier, 0.0)")
	Lib.append_function(sheet, "reset_surface", "Reset Surface", "Physics Car", "Restores both terrain multipliers to 1 (call it when the car leaves a terrain zone).",
		[],
		"_surface_grip = 1.0\n_surface_resist = 1.0")
	Lib.append_function(sheet, "set_reach_distance", "Set Reach Distance", "Physics Car", "Sets how close (pixels) a Drive Toward target must be to fire On Drive Target Reached.",
		[["distance", "float"]],
		"reach_distance = maxf(distance, 0.0)")

	# --- Conditions ---
	_condition(sheet, "is_moving", "Is Moving", "Physics Car", "Whether the car is above a small movement speed.", [],
		"return _speed > 5.0")
	_condition(sheet, "is_reversing", "Is Reversing", "Physics Car", "Whether the car is moving backwards.", [],
		"return _fwd_speed < -1.0")
	_condition(sheet, "is_drifting", "Is Drifting", "Physics Car", "Whether the slip angle is past the drift threshold.", [],
		"return _drifting")
	_condition(sheet, "is_handbrake_active", "Is Handbrake Active", "Physics Car", "Whether the handbrake was requested this physics frame.", [],
		"return _handbrake")
	_condition(sheet, "is_at_max_speed", "Is At Max Speed", "Physics Car", "Whether the car has hit its forward speed cap.", [],
		"return _fwd_speed >= max_speed - 1.0")
	_condition(sheet, "has_reached_target", "Has Reached Drive Target", "Physics Car", "Whether the last Drive Toward Position target has been reached.", [],
		"return _reached")
	_condition(sheet, "has_surface_override", "Has Surface Override", "Physics Car", "Whether a terrain grip or resistance multiplier is currently in effect.", [],
		"return not is_equal_approx(_surface_grip, 1.0) or not is_equal_approx(_surface_resist, 1.0)")
	_condition(sheet, "is_driving_toward_angle", "Is Driving Toward Angle", "Physics Car", "Whether the car is in Drive Toward Angle mode.", [],
		"return _drive_mode == \"angle\"")
	_condition(sheet, "is_driving_toward_position", "Is Driving Toward Position", "Physics Car", "Whether the car is in Drive Toward Position mode.", [],
		"return _drive_mode == \"position\"")

	# --- Expressions: motion ---
	_expr(sheet, "speed", "Speed", "Physics Car", "Current speed, in pixels per second.", [],
		"return _speed", TYPE_FLOAT)
	_expr(sheet, "forward_speed", "Forward Speed", "Physics Car", "Speed along the way the car faces (negative when reversing).", [],
		"return _fwd_speed", TYPE_FLOAT)
	_expr(sheet, "lateral_speed", "Lateral Speed", "Physics Car", "Sideways slide speed (the part grip fights).", [],
		"return _lat_speed", TYPE_FLOAT)
	_expr(sheet, "angle_of_motion", "Angle Of Motion", "Physics Car", "The direction the car is actually moving, in degrees.", [],
		"return _motion_angle", TYPE_FLOAT)
	_expr(sheet, "slip_angle", "Slip Angle", "Physics Car", "Degrees between where the car points and where it moves.", [],
		"return _slip", TYPE_FLOAT)
	_expr(sheet, "drift_duration", "Drift Duration", "Physics Car", "Seconds the current drift has lasted (or the final length inside On Drift Ended).", [],
		"return _drift_time", TYPE_FLOAT)

	# --- Expressions: input + steering ---
	_expr(sheet, "throttle_input", "Throttle Input", "Physics Car", "The current throttle value (-1 to 1).", [],
		"return throttle", TYPE_FLOAT)
	_expr(sheet, "brake_input", "Brake Input", "Physics Car", "The current brake value (0 to 1).", [],
		"return brake", TYPE_FLOAT)
	_expr(sheet, "steer_input", "Steer Input", "Physics Car", "The current steer value (-1 to 1).", [],
		"return steer", TYPE_FLOAT)
	_expr(sheet, "heading_error", "Heading Error", "Physics Car", "Signed degrees a Drive Toward action still needs to turn.", [],
		"return _heading_error", TYPE_FLOAT)
	_expr(sheet, "drive_target_distance", "Drive Target Distance", "Physics Car", "Distance to the current Drive Toward Position target (0 if none).", [],
		"return _target_dist", TYPE_FLOAT)

	# --- Expressions: grip + collision ---
	_expr(sheet, "effective_grip", "Effective Grip", "Physics Car", "The final grip after handbrake and terrain multipliers.", [],
		"return _eff_grip", TYPE_FLOAT)
	_expr(sheet, "surface_grip_multiplier", "Surface Grip Multiplier", "Physics Car", "The active terrain grip multiplier.", [],
		"return _surface_grip", TYPE_FLOAT)
	_expr(sheet, "surface_resistance_multiplier", "Surface Resistance Multiplier", "Physics Car", "The active terrain drag multiplier.", [],
		"return _surface_resist", TYPE_FLOAT)
	_expr(sheet, "collision_force", "Collision Force", "Physics Car", "Approximate impact speed of the latest collision (inside On Collided).", [],
		"return _collision_force", TYPE_FLOAT)
	_expr(sheet, "collision_angle", "Collision Angle", "Physics Car", "Approximate impact direction in degrees (inside On Collided).", [],
		"return _collision_angle", TYPE_FLOAT)

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.feature_verbs(sheet, ["simulate_control", "drive_toward_position"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/physics_car/physics_car_behavior")


## Pre-fills the last-appended ACE's parameter default, so the dialog opens with a usable value
## (authoring-time metadata only - defaults never appear in the compiled .gd).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


## Sets the dropdown options[] on the last-appended ACE's parameter (a picker instead of free text).
static func _param_options(sheet: EventSheetResource, param_id: String, choices: Array) -> void:
	var typed: Array[String] = []
	for choice: Variant in choices:
		typed.append(str(choice))
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = typed


static func _condition(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = TYPE_BOOL
	sheet.functions.append(fn)


static func _expr(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String, ret: int) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = ret
	sheet.functions.append(fn)
