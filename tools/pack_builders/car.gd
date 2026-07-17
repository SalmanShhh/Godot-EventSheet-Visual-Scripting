# Pack builder - car (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Car behavior (event-sheet parity)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "CarBehavior"
	sheet.class_description = "Turns a plain CharacterBody2D into a drivable top-down arcade car: arrow keys accelerate, reverse, and steer the moment you press play. Every handling knob (top speed, acceleration, coast, turn rate, grip, drift) is readable and settable live for boost pads, ice, and damage models."
	sheet.addon_category = "Car"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"max_speed": {"type": "float", "default": 400.0, "exported": true, "description": "Top forward speed in pixels per second (reverse tops out at half this)."},
		"acceleration": {"type": "float", "default": 300.0, "exported": true, "description": "How fast speed builds while on the throttle, in pixels per second squared."},
		"deceleration": {"type": "float", "default": 400.0, "exported": true, "description": "How fast the car coasts back to a stop when off the throttle, in pixels per second squared."},
		"steer_degrees": {"type": "float", "default": 180.0, "exported": true, "description": "Turn rate in degrees per second at full steering."},
		"drift_recover": {"type": "float", "default": 0.15, "exported": true, "description": "How strongly velocity snaps back toward the heading each frame (1 = grippy, low = drifty)."},
		"turn_while_stopped": {"type": "bool", "default": false, "exported": true, "description": "Allows steering while the car is stopped."},
		"drift_angle_threshold": {"type": "float", "default": 15.0, "exported": true, "description": "Angle in degrees between velocity and heading before a drift is counted."},
		"ai_controlled": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "AI drive: read ai_throttle_axis/ai_steer_axis instead of the keyboard (a sheet or AI driver flips this on to steer)."}},
		"ai_throttle_axis": {"type": "float", "default": 0.0, "exported": false},
		"ai_steer_axis": {"type": "float", "default": 0.0, "exported": false},
		"speed": {"type": "float", "default": 0.0, "exported": false},
		"_drifting": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Car behavior (event-sheet parity): accelerate/brake with up/down, steer with left/right. drift_recover blends sliding back toward the heading (1 = grippy, low = drifty); turn_while_stopped allows steering at rest."
	sheet.events.append(about)
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Drift Started\")",
		"signal drift_started",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Drift Recovered\")",
		"signal drift_recovered"
	]))
	sheet.events.append(signal_block)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"# The AI seam: a driver writes ai_throttle_axis/ai_steer_axis and flips ai_controlled",
		"# on; off (the default) these are exactly the keyboard reads they always were.",
		"var throttle := ai_throttle_axis if ai_controlled else Input.get_axis(&\"ui_down\", &\"ui_up\")",
		"if throttle > 0.0:",
		"\tspeed = minf(speed + acceleration * delta, max_speed)",
		"elif throttle < 0.0:",
		"\tspeed = maxf(speed - acceleration * delta, -max_speed * 0.5)",
		"else:",
		"\tspeed = move_toward(speed, 0.0, deceleration * delta)",
		"var steer := ai_steer_axis if ai_controlled else Input.get_axis(&\"ui_left\", &\"ui_right\")",
		"var steer_scale := 1.0 if (turn_while_stopped and absf(speed) < 1.0) else clampf(absf(speed) / max_speed, 0.0, 1.0) * signf(speed)",
		"host.rotation += deg_to_rad(steer_degrees) * steer * delta * steer_scale",
		"var heading := Vector2.from_angle(host.rotation) * speed",
		"host.velocity = host.velocity.lerp(heading, clampf(drift_recover, 0.01, 1.0))",
		"# Drift = the velocity has slid away from the heading; edge-triggered so each slide fires once.",
		"var drifting := absf(speed) > 20.0 and host.velocity.length() > 20.0 and absf(host.velocity.angle_to(heading)) > deg_to_rad(drift_angle_threshold)",
		"if drifting and not _drifting:",
		"\t_drifting = true",
		"\tdrift_started.emit()",
		"elif not drifting and _drifting:",
		"\t_drifting = false",
		"\tdrift_recovered.emit()",
		"host.move_and_slide()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var stop_car_fn: EventFunction = EventFunction.new()
	stop_car_fn.function_name = "stop_car"
	stop_car_fn.expose_as_ace = true
	stop_car_fn.ace_display_name = "Stop Car"
	stop_car_fn.ace_category = "Car"
	stop_car_fn.description = "Kills all momentum."
	var stop_car_fn_body: RawCodeRow = RawCodeRow.new()
	stop_car_fn_body.code = "\n".join(PackedStringArray([
		"speed = 0.0",
		"if host != null:",
		"\thost.velocity = Vector2.ZERO"
	]))
	stop_car_fn.events.append(stop_car_fn_body)
	sheet.functions.append(stop_car_fn)

	return Lib.save_pack(sheet, "res://eventsheet_addons/car/car_behavior")
