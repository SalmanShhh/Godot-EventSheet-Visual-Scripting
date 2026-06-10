# EventForge — dev tool: builds the sample behavior packs.
# Constructs the Platformer / Eight-Direction behavior sheets programmatically (also a
# reference for authoring sheets from code), saves the editable .tres sources, and compiles
# the .gd scripts into res://eventsheet_addons/ where the zero-config scanner publishes
# their ACEs project-wide. Re-run after compiler changes so sheet + script never drift
# (sample_behavior_pack_test guards that):
#   godot --headless --script tools/build_sample_behaviors.gd
@tool
extends SceneTree

func _init() -> void:
	var ok: bool = true
	ok = _build_platformer() and ok
	ok = _build_eight_direction() and ok
	ok = _build_timer() and ok
	ok = _build_flash() and ok
	ok = _build_state_machine() and ok
	ok = _build_sine() and ok
	ok = _build_orbit() and ok
	ok = _build_bullet() and ok
	ok = _build_move_to() and ok
	ok = _build_follow() and ok
	ok = _build_drag_drop() and ok
	ok = _build_car() and ok
	ok = _build_tile_movement() and ok
	ok = _build_line_of_sight() and ok
	print("[build_sample_behaviors] %s" % ("done" if ok else "FAILED"))
	quit(0 if ok else 1)

## C3 "Timer" behavior: attach under any node; Start/Stop ACEs; "On Timer" trigger.
func _build_timer() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "TimerBehavior"
	sheet.variables = {
		"duration": {"type": "float", "default": 1.0, "exported": true},
		"repeating": {"type": "bool", "default": false, "exported": true},
		"remaining": {"type": "float", "default": 0.0, "exported": false},
		"running": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Timer behavior (C3-style): Start Timer / Stop Timer from any sheet; the On Timer trigger fires when it elapses (repeats when 'repeating')."
	sheet.events.append(about)
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "## @ace_trigger\n## @ace_name(\"On Timer\")\n## @ace_category(\"Timer\")\nsignal timer_finished"
	sheet.events.append(signal_block)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var countdown: RawCodeRow = RawCodeRow.new()
	countdown.code = "\n".join(PackedStringArray([
		"if not running:",
		"\treturn",
		"remaining -= delta",
		"if remaining > 0.0:",
		"\treturn",
		"timer_finished.emit()",
		"if repeating:",
		"\tremaining = duration",
		"else:",
		"\trunning = false"
	]))
	tick.actions.append(countdown)
	sheet.events.append(tick)

	var start_timer: EventFunction = EventFunction.new()
	start_timer.function_name = "start_timer"
	start_timer.expose_as_ace = true
	start_timer.ace_display_name = "Start Timer"
	start_timer.ace_category = "Timer"
	start_timer.description = "Starts (or restarts) the countdown with the given duration."
	var seconds_param: ACEParam = ACEParam.new()
	seconds_param.id = "seconds"
	seconds_param.type_name = "float"
	start_timer.params.append(seconds_param)
	var start_body: RawCodeRow = RawCodeRow.new()
	start_body.code = "duration = seconds\nremaining = seconds\nrunning = true"
	start_timer.events.append(start_body)
	sheet.functions.append(start_timer)

	var stop_timer: EventFunction = EventFunction.new()
	stop_timer.function_name = "stop_timer"
	stop_timer.expose_as_ace = true
	stop_timer.ace_display_name = "Stop Timer"
	stop_timer.ace_category = "Timer"
	stop_timer.description = "Stops the countdown without firing On Timer."
	var stop_body: RawCodeRow = RawCodeRow.new()
	stop_body.code = "running = false"
	stop_timer.events.append(stop_body)
	sheet.functions.append(stop_timer)
	return _save_pack(sheet, "res://eventsheet_addons/timer/timer_behavior")

## C3 "Flash" behavior: toggles host visibility at an interval for a duration.
func _build_flash() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CanvasItem"
	sheet.custom_class_name = "FlashBehavior"
	sheet.variables = {
		"interval": {"type": "float", "default": 0.1, "exported": true},
		"remaining": {"type": "float", "default": 0.0, "exported": false},
		"accumulator": {"type": "float", "default": 0.0, "exported": false},
		"flashing": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Flash behavior (C3-style): blinks the host's visibility for a duration, then restores it and fires On Flash Finished."
	sheet.events.append(about)
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "## @ace_trigger\n## @ace_name(\"On Flash Finished\")\n## @ace_category(\"Flash\")\nsignal flash_finished"
	sheet.events.append(signal_block)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var blink: RawCodeRow = RawCodeRow.new()
	blink.code = "\n".join(PackedStringArray([
		"if not flashing or host == null:",
		"\treturn",
		"remaining -= delta",
		"accumulator += delta",
		"if accumulator >= interval:",
		"\taccumulator = 0.0",
		"\thost.visible = not host.visible",
		"if remaining <= 0.0:",
		"\tflashing = false",
		"\thost.visible = true",
		"\tflash_finished.emit()"
	]))
	tick.actions.append(blink)
	sheet.events.append(tick)

	var flash: EventFunction = EventFunction.new()
	flash.function_name = "flash"
	flash.expose_as_ace = true
	flash.ace_display_name = "Flash"
	flash.ace_category = "Flash"
	flash.description = "Blinks the host for the given number of seconds."
	var flash_seconds: ACEParam = ACEParam.new()
	flash_seconds.id = "seconds"
	flash_seconds.type_name = "float"
	flash.params.append(flash_seconds)
	var flash_body: RawCodeRow = RawCodeRow.new()
	flash_body.code = "remaining = seconds\naccumulator = 0.0\nflashing = true"
	flash.events.append(flash_body)
	sheet.functions.append(flash)

	var stop_flash: EventFunction = EventFunction.new()
	stop_flash.function_name = "stop_flash"
	stop_flash.expose_as_ace = true
	stop_flash.ace_display_name = "Stop Flash"
	stop_flash.ace_category = "Flash"
	stop_flash.description = "Stops flashing and restores visibility."
	var stop_flash_body: RawCodeRow = RawCodeRow.new()
	stop_flash_body.code = "flashing = false\nif host != null:\n\thost.visible = true"
	stop_flash.events.append(stop_flash_body)
	sheet.functions.append(stop_flash)
	return _save_pack(sheet, "res://eventsheet_addons/flash/flash_behavior")

## Minimal state machine: Set State action, On State Changed trigger, and an Is In State
## CONDITION authored as an annotated class-level GDScript block — the example of mixing
## expose-as-ACE functions with hand-annotated block ACEs in one behavior.
func _build_state_machine() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "StateMachineBehavior"
	sheet.variables = {"state": {"type": "String", "default": "idle", "exported": true}}
	var about: CommentRow = CommentRow.new()
	about.text = "State machine behavior: Set State / Is In State from any sheet; On State Changed fires with (previous, next)."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On State Changed\")",
		"## @ace_category(\"State Machine\")",
		"signal state_changed(previous: String, next: String)",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is In State\")",
		"## @ace_category(\"State Machine\")",
		"## @ace_codegen_template(\"$StateMachineBehavior.state == {state_name}\")",
		"func is_in_state(state_name: String) -> bool:",
		"\treturn state == state_name"
	]))
	sheet.events.append(block)

	var set_state: EventFunction = EventFunction.new()
	set_state.function_name = "set_state"
	set_state.expose_as_ace = true
	set_state.ace_display_name = "Set State"
	set_state.ace_category = "State Machine"
	set_state.description = "Switches to the given state and fires On State Changed."
	var next_param: ACEParam = ACEParam.new()
	next_param.id = "next"
	next_param.type_name = "String"
	set_state.params.append(next_param)
	var set_body: RawCodeRow = RawCodeRow.new()
	set_body.code = "\n".join(PackedStringArray([
		"if state == next:",
		"\treturn",
		"var previous: String = state",
		"state = next",
		"state_changed.emit(previous, next)"
	]))
	set_state.events.append(set_body)
	sheet.functions.append(set_state)
	return _save_pack(sheet, "res://eventsheet_addons/state_machine/state_machine_behavior")

func _build_platformer() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "PlatformerMovement"
	sheet.variables = {
		"move_speed": {"type": "float", "default": 200.0, "exported": true},
		"jump_velocity": {"type": "float", "default": -400.0, "exported": true},
		"gravity": {"type": "float", "default": 980.0, "exported": true}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "Platformer movement behavior: attach under a CharacterBody2D. Move with ui_left/ui_right; call Jump from any sheet."
	sheet.events.append(about)

	# The behavior's own signal, published as a trigger via block annotations.
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "## @ace_trigger\n## @ace_name(\"On Jumped\")\n## @ace_category(\"Platformer\")\nsignal jumped"
	sheet.events.append(signal_block)

	# Movement core: every physics tick, drive the host.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var movement: RawCodeRow = RawCodeRow.new()
	movement.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"var direction := Input.get_axis(\"ui_left\", \"ui_right\")",
		"host.velocity.x = direction * move_speed",
		"if not host.is_on_floor():",
		"\thost.velocity.y += gravity * delta",
		"host.move_and_slide()"
	]))
	tick.actions.append(movement)
	sheet.events.append(tick)

	# Exposed ACEs: published project-wide once the compiled script is in eventsheet_addons.
	var jump: EventFunction = EventFunction.new()
	jump.function_name = "jump"
	jump.expose_as_ace = true
	jump.ace_display_name = "Jump"
	jump.ace_category = "Platformer"
	jump.description = "Makes the host jump when it is on the floor."
	var jump_body: RawCodeRow = RawCodeRow.new()
	jump_body.code = "if host != null and host.is_on_floor():\n\thost.velocity.y = jump_velocity\n\tjumped.emit()"
	jump.events.append(jump_body)
	sheet.functions.append(jump)

	var set_speed: EventFunction = EventFunction.new()
	set_speed.function_name = "set_move_speed"
	set_speed.expose_as_ace = true
	set_speed.ace_display_name = "Set Move Speed"
	set_speed.ace_category = "Platformer"
	set_speed.description = "Changes the horizontal move speed."
	var speed_param: ACEParam = ACEParam.new()
	speed_param.id = "speed"
	speed_param.type_name = "float"
	set_speed.params.append(speed_param)
	var set_speed_body: RawCodeRow = RawCodeRow.new()
	set_speed_body.code = "move_speed = {speed}".replace("{speed}", "speed")
	set_speed.events.append(set_speed_body)
	sheet.functions.append(set_speed)

	return _save_pack(sheet, "res://eventsheet_addons/platformer_movement/platformer_movement_behavior")

func _build_eight_direction() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "EightDirectionMovement"
	sheet.variables = {"move_speed": {"type": "float", "default": 200.0, "exported": true}}

	var about: CommentRow = CommentRow.new()
	about.text = "Top-down 8-direction movement: attach under a CharacterBody2D; moves with the ui_* input actions."
	sheet.events.append(about)

	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var movement: RawCodeRow = RawCodeRow.new()
	movement.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"var input_vector := Input.get_vector(\"ui_left\", \"ui_right\", \"ui_up\", \"ui_down\")",
		"host.velocity = input_vector * move_speed",
		"host.move_and_slide()"
	]))
	tick.actions.append(movement)
	sheet.events.append(tick)

	var set_speed: EventFunction = EventFunction.new()
	set_speed.function_name = "set_move_speed"
	set_speed.expose_as_ace = true
	set_speed.ace_display_name = "Set Move Speed"
	set_speed.ace_category = "Eight Direction"
	set_speed.description = "Changes the movement speed."
	var speed_param: ACEParam = ACEParam.new()
	speed_param.id = "speed"
	speed_param.type_name = "float"
	set_speed.params.append(speed_param)
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "move_speed = speed"
	set_speed.events.append(body)
	sheet.functions.append(set_speed)

	return _save_pack(sheet, "res://eventsheet_addons/eight_direction/eight_direction_movement_behavior")

## Saves the editable sheet (.tres) and the compiled addon script (.gd) side by side.
## Sine behavior (C3-style)
func _build_sine() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "SineBehavior"
	sheet.variables = {
		"movement": {"type": "String", "default": "horizontal", "exported": true},
		"period": {"type": "float", "default": 4.0, "exported": true},
		"magnitude": {"type": "float", "default": 50.0, "exported": true},
		"active": {"type": "bool", "default": true, "exported": true},
		"time": {"type": "float", "default": 0.0, "exported": false},
		"base_x": {"type": "float", "default": 0.0, "exported": false},
		"base_y": {"type": "float", "default": 0.0, "exported": false},
		"base_captured": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Sine behavior (C3-style): oscillates the host around its starting position/angle. movement: horizontal, vertical or angle."
	sheet.events.append(about)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not active or host == null:",
		"\treturn",
		"if not base_captured:",
		"\tbase_x = host.position.x",
		"\tbase_y = host.position.y",
		"\tbase_captured = true",
		"time += delta",
		"var offset := sin(time * TAU / period) * magnitude",
		"if movement == \"horizontal\":",
		"\thost.position.x = base_x + offset",
		"elif movement == \"vertical\":",
		"\thost.position.y = base_y + offset",
		"elif movement == \"angle\":",
		"\thost.rotation = offset * 0.0174533"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var set_sine_active_fn: EventFunction = EventFunction.new()
	set_sine_active_fn.function_name = "set_sine_active"
	set_sine_active_fn.expose_as_ace = true
	set_sine_active_fn.ace_display_name = "Set Sine Active"
	set_sine_active_fn.ace_category = "Sine"
	set_sine_active_fn.description = "Pauses or resumes the oscillation."
	var set_sine_active_fn_is_active: ACEParam = ACEParam.new()
	set_sine_active_fn_is_active.id = "is_active"
	set_sine_active_fn_is_active.type_name = "bool"
	set_sine_active_fn.params.append(set_sine_active_fn_is_active)
	var set_sine_active_fn_body: RawCodeRow = RawCodeRow.new()
	set_sine_active_fn_body.code = "\n".join(PackedStringArray([
		"active = is_active"
	]))
	set_sine_active_fn.events.append(set_sine_active_fn_body)
	sheet.functions.append(set_sine_active_fn)

	var reset_sine_fn: EventFunction = EventFunction.new()
	reset_sine_fn.function_name = "reset_sine"
	reset_sine_fn.expose_as_ace = true
	reset_sine_fn.ace_display_name = "Reset Sine"
	reset_sine_fn.ace_category = "Sine"
	reset_sine_fn.description = "Restarts the wave from the current position."
	var reset_sine_fn_body: RawCodeRow = RawCodeRow.new()
	reset_sine_fn_body.code = "\n".join(PackedStringArray([
		"time = 0.0",
		"base_captured = false"
	]))
	reset_sine_fn.events.append(reset_sine_fn_body)
	sheet.functions.append(reset_sine_fn)

	return _save_pack(sheet, "res://eventsheet_addons/sine/sine_behavior")

## Orbit behavior (C3-style)
func _build_orbit() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "OrbitBehavior"
	sheet.variables = {
		"radius": {"type": "float", "default": 100.0, "exported": true},
		"speed_degrees": {"type": "float", "default": 90.0, "exported": true},
		"angle": {"type": "float", "default": 0.0, "exported": false},
		"center_x": {"type": "float", "default": 0.0, "exported": false},
		"center_y": {"type": "float", "default": 0.0, "exported": false},
		"center_captured": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Orbit behavior (C3-style): circles the host around its starting point (or a set center)."
	sheet.events.append(about)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"if not center_captured:",
		"\tcenter_x = host.position.x",
		"\tcenter_y = host.position.y",
		"\tcenter_captured = true",
		"angle += deg_to_rad(speed_degrees) * delta",
		"host.position = Vector2(center_x, center_y) + Vector2.from_angle(angle) * radius"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var set_orbit_center_fn: EventFunction = EventFunction.new()
	set_orbit_center_fn.function_name = "set_orbit_center"
	set_orbit_center_fn.expose_as_ace = true
	set_orbit_center_fn.ace_display_name = "Set Orbit Center"
	set_orbit_center_fn.ace_category = "Orbit"
	set_orbit_center_fn.description = "Orbits around the given point from now on."
	var set_orbit_center_fn_x: ACEParam = ACEParam.new()
	set_orbit_center_fn_x.id = "x"
	set_orbit_center_fn_x.type_name = "float"
	set_orbit_center_fn.params.append(set_orbit_center_fn_x)
	var set_orbit_center_fn_y: ACEParam = ACEParam.new()
	set_orbit_center_fn_y.id = "y"
	set_orbit_center_fn_y.type_name = "float"
	set_orbit_center_fn.params.append(set_orbit_center_fn_y)
	var set_orbit_center_fn_body: RawCodeRow = RawCodeRow.new()
	set_orbit_center_fn_body.code = "\n".join(PackedStringArray([
		"center_x = x",
		"center_y = y",
		"center_captured = true"
	]))
	set_orbit_center_fn.events.append(set_orbit_center_fn_body)
	sheet.functions.append(set_orbit_center_fn)

	var set_orbit_speed_fn: EventFunction = EventFunction.new()
	set_orbit_speed_fn.function_name = "set_orbit_speed"
	set_orbit_speed_fn.expose_as_ace = true
	set_orbit_speed_fn.ace_display_name = "Set Orbit Speed"
	set_orbit_speed_fn.ace_category = "Orbit"
	set_orbit_speed_fn.description = "Degrees per second (negative reverses)."
	var set_orbit_speed_fn_degrees_per_second: ACEParam = ACEParam.new()
	set_orbit_speed_fn_degrees_per_second.id = "degrees_per_second"
	set_orbit_speed_fn_degrees_per_second.type_name = "float"
	set_orbit_speed_fn.params.append(set_orbit_speed_fn_degrees_per_second)
	var set_orbit_speed_fn_body: RawCodeRow = RawCodeRow.new()
	set_orbit_speed_fn_body.code = "\n".join(PackedStringArray([
		"speed_degrees = degrees_per_second"
	]))
	set_orbit_speed_fn.events.append(set_orbit_speed_fn_body)
	sheet.functions.append(set_orbit_speed_fn)

	return _save_pack(sheet, "res://eventsheet_addons/orbit/orbit_behavior")

## Bullet behavior (C3-style)
func _build_bullet() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "BulletBehavior"
	sheet.variables = {
		"speed": {"type": "float", "default": 300.0, "exported": true},
		"acceleration": {"type": "float", "default": 0.0, "exported": true},
		"gravity": {"type": "float", "default": 0.0, "exported": true},
		"align_rotation": {"type": "bool", "default": true, "exported": true},
		"vel_x": {"type": "float", "default": 0.0, "exported": false},
		"vel_y": {"type": "float", "default": 0.0, "exported": false},
		"launched": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Bullet behavior (C3-style): moves at the host's angle of motion with acceleration and gravity."
	sheet.events.append(about)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"if not launched:",
		"\tvel_x = cos(host.rotation) * speed",
		"\tvel_y = sin(host.rotation) * speed",
		"\tlaunched = true",
		"var direction := Vector2(vel_x, vel_y).normalized()",
		"vel_x += direction.x * acceleration * delta",
		"vel_y += direction.y * acceleration * delta + 0.0",
		"vel_y += gravity * delta",
		"host.position += Vector2(vel_x, vel_y) * delta",
		"if align_rotation and (vel_x != 0.0 or vel_y != 0.0):",
		"\thost.rotation = Vector2(vel_x, vel_y).angle()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var set_bullet_speed_fn: EventFunction = EventFunction.new()
	set_bullet_speed_fn.function_name = "set_bullet_speed"
	set_bullet_speed_fn.expose_as_ace = true
	set_bullet_speed_fn.ace_display_name = "Set Bullet Speed"
	set_bullet_speed_fn.ace_category = "Bullet"
	set_bullet_speed_fn.description = "Changes speed, keeping the current direction."
	var set_bullet_speed_fn_value: ACEParam = ACEParam.new()
	set_bullet_speed_fn_value.id = "value"
	set_bullet_speed_fn_value.type_name = "float"
	set_bullet_speed_fn.params.append(set_bullet_speed_fn_value)
	var set_bullet_speed_fn_body: RawCodeRow = RawCodeRow.new()
	set_bullet_speed_fn_body.code = "\n".join(PackedStringArray([
		"speed = value",
		"var direction := Vector2(vel_x, vel_y).normalized()",
		"if direction == Vector2.ZERO and host != null:",
		"\tdirection = Vector2.from_angle(host.rotation)",
		"vel_x = direction.x * value",
		"vel_y = direction.y * value",
		"launched = true"
	]))
	set_bullet_speed_fn.events.append(set_bullet_speed_fn_body)
	sheet.functions.append(set_bullet_speed_fn)

	var set_angle_of_motion_fn: EventFunction = EventFunction.new()
	set_angle_of_motion_fn.function_name = "set_angle_of_motion"
	set_angle_of_motion_fn.expose_as_ace = true
	set_angle_of_motion_fn.ace_display_name = "Set Angle Of Motion"
	set_angle_of_motion_fn.ace_category = "Bullet"
	set_angle_of_motion_fn.description = "Redirects the bullet (degrees)."
	var set_angle_of_motion_fn_degrees: ACEParam = ACEParam.new()
	set_angle_of_motion_fn_degrees.id = "degrees"
	set_angle_of_motion_fn_degrees.type_name = "float"
	set_angle_of_motion_fn.params.append(set_angle_of_motion_fn_degrees)
	var set_angle_of_motion_fn_body: RawCodeRow = RawCodeRow.new()
	set_angle_of_motion_fn_body.code = "\n".join(PackedStringArray([
		"vel_x = cos(deg_to_rad(degrees)) * speed",
		"vel_y = sin(deg_to_rad(degrees)) * speed",
		"launched = true"
	]))
	set_angle_of_motion_fn.events.append(set_angle_of_motion_fn_body)
	sheet.functions.append(set_angle_of_motion_fn)

	return _save_pack(sheet, "res://eventsheet_addons/bullet/bullet_behavior")

## Move To behavior (C3-style)
func _build_move_to() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "MoveToBehavior"
	sheet.variables = {
		"max_speed": {"type": "float", "default": 200.0, "exported": true},
		"target_x": {"type": "float", "default": 0.0, "exported": false},
		"target_y": {"type": "float", "default": 0.0, "exported": false},
		"moving": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Move To behavior (C3-style): glides the host to a target position and fires On Arrived."
	sheet.events.append(about)
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Arrived\")",
		"## @ace_category(\"Move To\")",
		"signal arrived"
	]))
	sheet.events.append(signal_block)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not moving or host == null:",
		"\treturn",
		"var target := Vector2(target_x, target_y)",
		"host.position = host.position.move_toward(target, max_speed * delta)",
		"if host.position.distance_to(target) < 0.5:",
		"\tmoving = false",
		"\tarrived.emit()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var move_to_position_fn: EventFunction = EventFunction.new()
	move_to_position_fn.function_name = "move_to_position"
	move_to_position_fn.expose_as_ace = true
	move_to_position_fn.ace_display_name = "Move To Position"
	move_to_position_fn.ace_category = "Move To"
	move_to_position_fn.description = "Starts gliding toward the point."
	var move_to_position_fn_x: ACEParam = ACEParam.new()
	move_to_position_fn_x.id = "x"
	move_to_position_fn_x.type_name = "float"
	move_to_position_fn.params.append(move_to_position_fn_x)
	var move_to_position_fn_y: ACEParam = ACEParam.new()
	move_to_position_fn_y.id = "y"
	move_to_position_fn_y.type_name = "float"
	move_to_position_fn.params.append(move_to_position_fn_y)
	var move_to_position_fn_body: RawCodeRow = RawCodeRow.new()
	move_to_position_fn_body.code = "\n".join(PackedStringArray([
		"target_x = x",
		"target_y = y",
		"moving = true"
	]))
	move_to_position_fn.events.append(move_to_position_fn_body)
	sheet.functions.append(move_to_position_fn)

	var stop_moving_fn: EventFunction = EventFunction.new()
	stop_moving_fn.function_name = "stop_moving"
	stop_moving_fn.expose_as_ace = true
	stop_moving_fn.ace_display_name = "Stop Moving"
	stop_moving_fn.ace_category = "Move To"
	stop_moving_fn.description = "Stops without firing On Arrived."
	var stop_moving_fn_body: RawCodeRow = RawCodeRow.new()
	stop_moving_fn_body.code = "\n".join(PackedStringArray([
		"moving = false"
	]))
	stop_moving_fn.events.append(stop_moving_fn_body)
	sheet.functions.append(stop_moving_fn)

	return _save_pack(sheet, "res://eventsheet_addons/move_to/move_to_behavior")

## Follow behavior (C3-style)
func _build_follow() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "FollowBehavior"
	sheet.variables = {
		"target_path": {"type": "String", "default": "", "exported": true},
		"follow_speed": {"type": "float", "default": 5.0, "exported": true},
		"min_distance": {"type": "float", "default": 0.0, "exported": true},
		"following": {"type": "bool", "default": true, "exported": true}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Follow behavior (C3-style): smoothly trails another node (set the target path)."
	sheet.events.append(about)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not following or host == null or target_path == \"\":",
		"\treturn",
		"var target := host.get_node_or_null(NodePath(target_path))",
		"if not (target is Node2D):",
		"\treturn",
		"if host.position.distance_to(target.position) <= min_distance:",
		"\treturn",
		"host.position = host.position.lerp(target.position, clampf(follow_speed * delta, 0.0, 1.0))"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var start_following_fn: EventFunction = EventFunction.new()
	start_following_fn.function_name = "start_following"
	start_following_fn.expose_as_ace = true
	start_following_fn.ace_display_name = "Start Following"
	start_following_fn.ace_category = "Follow"
	start_following_fn.description = "Follows the node at the given path."
	var start_following_fn_path: ACEParam = ACEParam.new()
	start_following_fn_path.id = "path"
	start_following_fn_path.type_name = "String"
	start_following_fn.params.append(start_following_fn_path)
	var start_following_fn_body: RawCodeRow = RawCodeRow.new()
	start_following_fn_body.code = "\n".join(PackedStringArray([
		"target_path = path",
		"following = true"
	]))
	start_following_fn.events.append(start_following_fn_body)
	sheet.functions.append(start_following_fn)

	var stop_following_fn: EventFunction = EventFunction.new()
	stop_following_fn.function_name = "stop_following"
	stop_following_fn.expose_as_ace = true
	stop_following_fn.ace_display_name = "Stop Following"
	stop_following_fn.ace_category = "Follow"
	stop_following_fn.description = "Stops trailing the target."
	var stop_following_fn_body: RawCodeRow = RawCodeRow.new()
	stop_following_fn_body.code = "\n".join(PackedStringArray([
		"following = false"
	]))
	stop_following_fn.events.append(stop_following_fn_body)
	sheet.functions.append(stop_following_fn)

	return _save_pack(sheet, "res://eventsheet_addons/follow/follow_behavior")

## Drag & Drop behavior (C3-style)
func _build_drag_drop() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "DragDropBehavior"
	sheet.variables = {
		"grab_radius": {"type": "float", "default": 48.0, "exported": true},
		"dragging": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Drag & Drop behavior (C3-style): grab the host with the mouse within the grab radius; fires On Drag Start and On Dropped."
	sheet.events.append(about)
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Drag Start\")",
		"## @ace_category(\"Drag & Drop\")",
		"signal drag_started",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Dropped\")",
		"## @ace_category(\"Drag & Drop\")",
		"signal dropped"
	]))
	sheet.events.append(signal_block)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):",
		"\tvar mouse := host.get_global_mouse_position()",
		"\tif not dragging and mouse.distance_to(host.global_position) <= grab_radius:",
		"\t\tdragging = true",
		"\t\tdrag_started.emit()",
		"\tif dragging:",
		"\t\thost.global_position = mouse",
		"elif dragging:",
		"\tdragging = false",
		"\tdropped.emit()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var drop_now_fn: EventFunction = EventFunction.new()
	drop_now_fn.function_name = "drop_now"
	drop_now_fn.expose_as_ace = true
	drop_now_fn.ace_display_name = "Drop Now"
	drop_now_fn.ace_category = "Drag & Drop"
	drop_now_fn.description = "Releases the drag immediately."
	var drop_now_fn_body: RawCodeRow = RawCodeRow.new()
	drop_now_fn_body.code = "\n".join(PackedStringArray([
		"if dragging:",
		"\tdragging = false",
		"\tdropped.emit()"
	]))
	drop_now_fn.events.append(drop_now_fn_body)
	sheet.functions.append(drop_now_fn)

	return _save_pack(sheet, "res://eventsheet_addons/drag_drop/drag_drop_behavior")

## Car behavior (C3-style)
func _build_car() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "CarBehavior"
	sheet.variables = {
		"max_speed": {"type": "float", "default": 400.0, "exported": true},
		"acceleration": {"type": "float", "default": 300.0, "exported": true},
		"deceleration": {"type": "float", "default": 400.0, "exported": true},
		"steer_degrees": {"type": "float", "default": 180.0, "exported": true},
		"speed": {"type": "float", "default": 0.0, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Car behavior (C3-style): accelerate/brake with up/down, steer with left/right (steering scales with speed)."
	sheet.events.append(about)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"var throttle := Input.get_axis(&\"ui_down\", &\"ui_up\")",
		"if throttle > 0.0:",
		"\tspeed = minf(speed + acceleration * delta, max_speed)",
		"elif throttle < 0.0:",
		"\tspeed = maxf(speed - acceleration * delta, -max_speed * 0.5)",
		"else:",
		"\tspeed = move_toward(speed, 0.0, deceleration * delta)",
		"var steer := Input.get_axis(&\"ui_left\", &\"ui_right\")",
		"host.rotation += deg_to_rad(steer_degrees) * steer * delta * clampf(absf(speed) / max_speed, 0.0, 1.0) * signf(speed)",
		"host.velocity = Vector2.from_angle(host.rotation) * speed",
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

	return _save_pack(sheet, "res://eventsheet_addons/car/car_behavior")

## Tile Movement behavior (C3-style)
func _build_tile_movement() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "TileMovementBehavior"
	sheet.variables = {
		"tile_size": {"type": "float", "default": 64.0, "exported": true},
		"move_time": {"type": "float", "default": 0.15, "exported": true},
		"moving": {"type": "bool", "default": false, "exported": false},
		"from_x": {"type": "float", "default": 0.0, "exported": false},
		"from_y": {"type": "float", "default": 0.0, "exported": false},
		"to_x": {"type": "float", "default": 0.0, "exported": false},
		"to_y": {"type": "float", "default": 0.0, "exported": false},
		"progress": {"type": "float", "default": 0.0, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Tile Movement behavior (C3-style): grid-locked stepping with the arrow keys; fires On Step Finished per tile."
	sheet.events.append(about)
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Step Finished\")",
		"## @ace_category(\"Tile Movement\")",
		"signal step_finished"
	]))
	sheet.events.append(signal_block)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"if moving:",
		"\tprogress += delta / move_time",
		"\tif progress >= 1.0:",
		"\t\thost.position = Vector2(to_x, to_y)",
		"\t\tmoving = false",
		"\t\tstep_finished.emit()",
		"\telse:",
		"\t\thost.position = Vector2(from_x, from_y).lerp(Vector2(to_x, to_y), progress)",
		"\treturn",
		"var step := Vector2(Input.get_axis(&\"ui_left\", &\"ui_right\"), Input.get_axis(&\"ui_up\", &\"ui_down\"))",
		"if step.x != 0.0:",
		"\tstep.y = 0.0",
		"if step != Vector2.ZERO:",
		"\tfrom_x = host.position.x",
		"\tfrom_y = host.position.y",
		"\tto_x = from_x + signf(step.x) * tile_size",
		"\tto_y = from_y + signf(step.y) * tile_size",
		"\tprogress = 0.0",
		"\tmoving = true"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var teleport_to_tile_fn: EventFunction = EventFunction.new()
	teleport_to_tile_fn.function_name = "teleport_to_tile"
	teleport_to_tile_fn.expose_as_ace = true
	teleport_to_tile_fn.ace_display_name = "Teleport To Tile"
	teleport_to_tile_fn.ace_category = "Tile Movement"
	teleport_to_tile_fn.description = "Snaps to a tile coordinate instantly."
	var teleport_to_tile_fn_tile_x: ACEParam = ACEParam.new()
	teleport_to_tile_fn_tile_x.id = "tile_x"
	teleport_to_tile_fn_tile_x.type_name = "float"
	teleport_to_tile_fn.params.append(teleport_to_tile_fn_tile_x)
	var teleport_to_tile_fn_tile_y: ACEParam = ACEParam.new()
	teleport_to_tile_fn_tile_y.id = "tile_y"
	teleport_to_tile_fn_tile_y.type_name = "float"
	teleport_to_tile_fn.params.append(teleport_to_tile_fn_tile_y)
	var teleport_to_tile_fn_body: RawCodeRow = RawCodeRow.new()
	teleport_to_tile_fn_body.code = "\n".join(PackedStringArray([
		"if host != null:",
		"\thost.position = Vector2(tile_x, tile_y) * tile_size",
		"moving = false"
	]))
	teleport_to_tile_fn.events.append(teleport_to_tile_fn_body)
	sheet.functions.append(teleport_to_tile_fn)

	return _save_pack(sheet, "res://eventsheet_addons/tile_movement/tile_movement_behavior")

## Line of Sight behavior (C3-style)
func _build_line_of_sight() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "LOSBehavior"
	sheet.variables = {
		"sight_range": {"type": "float", "default": 400.0, "exported": true},
		"collision_mask": {"type": "int", "default": 1, "exported": true}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Line of Sight behavior (C3-style): the Has Line Of Sight To condition raycasts against solids within range."
	sheet.events.append(about)
	var extra_block_0: RawCodeRow = RawCodeRow.new()
	extra_block_0.code = "\n".join(PackedStringArray([
		"## @ace_condition",
		"## @ace_name(\"Has Line Of Sight To\")",
		"## @ace_category(\"Line Of Sight\")",
		"## @ace_codegen_template(\"$LOSBehavior.has_los_to({point})\")",
		"func has_los_to(point: Vector2) -> bool:",
		"\tif host == null or host.global_position.distance_to(point) > sight_range:",
		"\t\treturn false",
		"\tvar query := PhysicsRayQueryParameters2D.create(host.global_position, point)",
		"\tquery.collision_mask = collision_mask",
		"\treturn host.get_world_2d().direct_space_state.intersect_ray(query).is_empty()"
	]))
	sheet.events.append(extra_block_0)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"pass"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	return _save_pack(sheet, "res://eventsheet_addons/line_of_sight/line_of_sight_behavior")

func _save_pack(sheet: EventSheetResource, base_path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(base_path.get_base_dir())
	var save_error: Error = ResourceSaver.save(sheet, base_path + ".tres")
	if save_error != OK:
		push_error("Failed to save %s.tres (%d)" % [base_path, save_error])
		return false
	# Adopt the saved path BEFORE compiling so the generated "# Source:" header matches what
	# a recompile of the loaded .tres produces (the no-drift test depends on it).
	sheet.take_over_path(base_path + ".tres")
	var compile_result: Dictionary = SheetCompiler.compile(sheet, base_path + ".gd")
	if not bool(compile_result.get("success", false)):
		push_error("Failed to compile %s.gd: %s" % [base_path, compile_result.get("errors")])
		return false
	print("[build_sample_behaviors] built %s (.tres + .gd), warnings: %s" % [base_path.get_file(), compile_result.get("warnings")])
	return true
