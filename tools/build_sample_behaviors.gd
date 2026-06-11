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
	ok = _build_spring() and ok
	ok = _build_tween() and ok
	ok = _build_save_system() and ok
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
	ok = _build_sine_3d() and ok
	ok = _build_orbit_3d() and ok
	ok = _build_bullet_3d() and ok
	ok = _build_move_to_3d() and ok
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
## Sine behavior (C3 parity)
func _build_sine() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "SineBehavior"
	sheet.variables = {
		"movement": {"type": "String", "default": "horizontal", "exported": true, "options": ["horizontal", "vertical", "forwards-backwards", "size", "angle", "opacity", "value-only"]},
		"wave": {"type": "String", "default": "sine", "exported": true, "options": ["sine", "triangle", "sawtooth", "reverse-sawtooth", "square"]},
		"period": {"type": "float", "default": 4.0, "exported": true},
		"magnitude": {"type": "float", "default": 50.0, "exported": true},
		"phase_degrees": {"type": "float", "default": 0.0, "exported": true},
		"active": {"type": "bool", "default": true, "exported": true},
		"wave_value": {"type": "float", "default": 0.0, "exported": false},
		"time": {"type": "float", "default": 0.0, "exported": false},
		"base_x": {"type": "float", "default": 0.0, "exported": false},
		"base_y": {"type": "float", "default": 0.0, "exported": false},
		"base_rotation": {"type": "float", "default": 0.0, "exported": false},
		"base_scale_x": {"type": "float", "default": 1.0, "exported": false},
		"base_scale_y": {"type": "float", "default": 1.0, "exported": false},
		"base_alpha": {"type": "float", "default": 1.0, "exported": false},
		"base_captured": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Sine behavior (C3 parity): wave-driven oscillation. movement: horizontal, vertical, forwards-backwards, size, angle, opacity, value-only. wave: sine, triangle, sawtooth, reverse-sawtooth, square. Read the current wave via $SineBehavior.wave_value."
	sheet.events.append(about)
	var extra_block_0: RawCodeRow = RawCodeRow.new()
	extra_block_0.code = "\n".join(PackedStringArray([
		"## @ace_hidden",
		"func _wave(t: float) -> float:",
		"\tvar cycle := fposmod(t, 1.0)",
		"\tmatch wave:",
		"\t\t\"triangle\":",
		"\t\t\treturn 1.0 - 4.0 * absf(cycle - 0.5)",
		"\t\t\"sawtooth\":",
		"\t\t\treturn 2.0 * cycle - 1.0",
		"\t\t\"reverse-sawtooth\":",
		"\t\t\treturn 1.0 - 2.0 * cycle",
		"\t\t\"square\":",
		"\t\t\treturn 1.0 if cycle < 0.5 else -1.0",
		"\treturn sin(cycle * TAU)"
	]))
	sheet.events.append(extra_block_0)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not active or host == null:",
		"\treturn",
		"if not base_captured:",
		"\tupdate_initial_state()",
		"time += delta",
		"var t := time / maxf(period, 0.001) + phase_degrees / 360.0",
		"wave_value = _wave(t)",
		"var offset := wave_value * magnitude",
		"if movement == \"horizontal\":",
		"\thost.position.x = base_x + offset",
		"elif movement == \"vertical\":",
		"\thost.position.y = base_y + offset",
		"elif movement == \"forwards-backwards\":",
		"\thost.position = Vector2(base_x, base_y) + Vector2.from_angle(base_rotation) * offset",
		"elif movement == \"size\":",
		"\thost.scale = Vector2(base_scale_x, base_scale_y) * (1.0 + wave_value * magnitude * 0.01)",
		"elif movement == \"angle\":",
		"\thost.rotation = base_rotation + offset * 0.0174533",
		"elif movement == \"opacity\":",
		"\thost.modulate.a = clampf(base_alpha + wave_value * magnitude * 0.01, 0.0, 1.0)"
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

	var update_initial_state_fn: EventFunction = EventFunction.new()
	update_initial_state_fn.function_name = "update_initial_state"
	update_initial_state_fn.expose_as_ace = true
	update_initial_state_fn.ace_display_name = "Update Initial State"
	update_initial_state_fn.ace_category = "Sine"
	update_initial_state_fn.description = "Re-captures the host's current position/scale/angle/opacity as the wave's base (C3 updateInitialState)."
	var update_initial_state_fn_body: RawCodeRow = RawCodeRow.new()
	update_initial_state_fn_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"base_x = host.position.x",
		"base_y = host.position.y",
		"base_rotation = host.rotation",
		"base_scale_x = host.scale.x",
		"base_scale_y = host.scale.y",
		"base_alpha = host.modulate.a",
		"base_captured = true"
	]))
	update_initial_state_fn.events.append(update_initial_state_fn_body)
	sheet.functions.append(update_initial_state_fn)

	var set_sine_phase_fn: EventFunction = EventFunction.new()
	set_sine_phase_fn.function_name = "set_sine_phase"
	set_sine_phase_fn.expose_as_ace = true
	set_sine_phase_fn.ace_display_name = "Set Phase"
	set_sine_phase_fn.ace_category = "Sine"
	set_sine_phase_fn.description = "Phase offset in degrees."
	var set_sine_phase_fn_degrees: ACEParam = ACEParam.new()
	set_sine_phase_fn_degrees.id = "degrees"
	set_sine_phase_fn_degrees.type_name = "float"
	set_sine_phase_fn.params.append(set_sine_phase_fn_degrees)
	var set_sine_phase_fn_body: RawCodeRow = RawCodeRow.new()
	set_sine_phase_fn_body.code = "\n".join(PackedStringArray([
		"phase_degrees = degrees"
	]))
	set_sine_phase_fn.events.append(set_sine_phase_fn_body)
	sheet.functions.append(set_sine_phase_fn)

	var reset_sine_fn: EventFunction = EventFunction.new()
	reset_sine_fn.function_name = "reset_sine"
	reset_sine_fn.expose_as_ace = true
	reset_sine_fn.ace_display_name = "Reset Sine"
	reset_sine_fn.ace_category = "Sine"
	reset_sine_fn.description = "Restarts the wave from the current state."
	var reset_sine_fn_body: RawCodeRow = RawCodeRow.new()
	reset_sine_fn_body.code = "\n".join(PackedStringArray([
		"time = 0.0",
		"base_captured = false"
	]))
	reset_sine_fn.events.append(reset_sine_fn_body)
	sheet.functions.append(reset_sine_fn)

	return _save_pack(sheet, "res://eventsheet_addons/sine/sine_behavior")

## Orbit behavior (C3 parity)
func _build_orbit() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "OrbitBehavior"
	sheet.variables = {
		"primary_radius": {"type": "float", "default": 100.0, "exported": true},
		"secondary_radius": {"type": "float", "default": 0.0, "exported": true},
		"speed_degrees": {"type": "float", "default": 90.0, "exported": true},
		"offset_angle_degrees": {"type": "float", "default": 0.0, "exported": true},
		"match_rotation": {"type": "bool", "default": false, "exported": true},
		"angle": {"type": "float", "default": 0.0, "exported": false},
		"total_rotation": {"type": "float", "default": 0.0, "exported": false},
		"center_x": {"type": "float", "default": 0.0, "exported": false},
		"center_y": {"type": "float", "default": 0.0, "exported": false},
		"center_captured": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Orbit behavior (C3 parity): circles or ellipses around a point. secondary_radius 0 = circle; offset_angle tilts the ellipse; match_rotation faces the travel direction."
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
		"var step := deg_to_rad(speed_degrees) * delta",
		"angle += step",
		"total_rotation += absf(step)",
		"var radius_b := secondary_radius if secondary_radius > 0.0 else primary_radius",
		"var local := Vector2(cos(angle) * primary_radius, sin(angle) * radius_b).rotated(deg_to_rad(offset_angle_degrees))",
		"var previous := host.position",
		"host.position = Vector2(center_x, center_y) + local",
		"if match_rotation and host.position != previous:",
		"\thost.rotation = (host.position - previous).angle()"
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

	var set_orbit_radii_fn: EventFunction = EventFunction.new()
	set_orbit_radii_fn.function_name = "set_orbit_radii"
	set_orbit_radii_fn.expose_as_ace = true
	set_orbit_radii_fn.ace_display_name = "Set Orbit Radii"
	set_orbit_radii_fn.ace_category = "Orbit"
	set_orbit_radii_fn.description = "Primary/secondary radii (secondary 0 = circle)."
	var set_orbit_radii_fn_primary: ACEParam = ACEParam.new()
	set_orbit_radii_fn_primary.id = "primary"
	set_orbit_radii_fn_primary.type_name = "float"
	set_orbit_radii_fn.params.append(set_orbit_radii_fn_primary)
	var set_orbit_radii_fn_secondary: ACEParam = ACEParam.new()
	set_orbit_radii_fn_secondary.id = "secondary"
	set_orbit_radii_fn_secondary.type_name = "float"
	set_orbit_radii_fn.params.append(set_orbit_radii_fn_secondary)
	var set_orbit_radii_fn_body: RawCodeRow = RawCodeRow.new()
	set_orbit_radii_fn_body.code = "\n".join(PackedStringArray([
		"primary_radius = primary",
		"secondary_radius = secondary"
	]))
	set_orbit_radii_fn.events.append(set_orbit_radii_fn_body)
	sheet.functions.append(set_orbit_radii_fn)

	return _save_pack(sheet, "res://eventsheet_addons/orbit/orbit_behavior")

## Bullet behavior (C3 parity)
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
		"enabled_movement": {"type": "bool", "default": true, "exported": true},
		"distance_travelled": {"type": "float", "default": 0.0, "exported": false},
		"vel_x": {"type": "float", "default": 0.0, "exported": false},
		"vel_y": {"type": "float", "default": 0.0, "exported": false},
		"launched": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Bullet behavior (C3 parity): angle-of-motion movement with acceleration and gravity; tracks distance travelled (read $BulletBehavior.distance_travelled)."
	sheet.events.append(about)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null or not enabled_movement:",
		"\treturn",
		"if not launched:",
		"\tvel_x = cos(host.rotation) * speed",
		"\tvel_y = sin(host.rotation) * speed",
		"\tlaunched = true",
		"var direction := Vector2(vel_x, vel_y).normalized()",
		"vel_x += direction.x * acceleration * delta",
		"vel_y += direction.y * acceleration * delta",
		"vel_y += gravity * delta",
		"var motion := Vector2(vel_x, vel_y) * delta",
		"host.position += motion",
		"distance_travelled += motion.length()",
		"if align_rotation and motion != Vector2.ZERO:",
		"\thost.rotation = motion.angle()"
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

	var set_bullet_enabled_fn: EventFunction = EventFunction.new()
	set_bullet_enabled_fn.function_name = "set_bullet_enabled"
	set_bullet_enabled_fn.expose_as_ace = true
	set_bullet_enabled_fn.ace_display_name = "Set Bullet Enabled"
	set_bullet_enabled_fn.ace_category = "Bullet"
	set_bullet_enabled_fn.description = "Pauses or resumes the movement."
	var set_bullet_enabled_fn_is_enabled: ACEParam = ACEParam.new()
	set_bullet_enabled_fn_is_enabled.id = "is_enabled"
	set_bullet_enabled_fn_is_enabled.type_name = "bool"
	set_bullet_enabled_fn.params.append(set_bullet_enabled_fn_is_enabled)
	var set_bullet_enabled_fn_body: RawCodeRow = RawCodeRow.new()
	set_bullet_enabled_fn_body.code = "\n".join(PackedStringArray([
		"enabled_movement = is_enabled"
	]))
	set_bullet_enabled_fn.events.append(set_bullet_enabled_fn_body)
	sheet.functions.append(set_bullet_enabled_fn)

	return _save_pack(sheet, "res://eventsheet_addons/bullet/bullet_behavior")

## Move To behavior (C3 parity)
func _build_move_to() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "MoveToBehavior"
	sheet.variables = {
		"max_speed": {"type": "float", "default": 200.0, "exported": true},
		"rotate_toward_motion": {"type": "bool", "default": false, "exported": true},
		"waypoints": {"type": "Array", "default": [], "exported": false},
		"moving": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Move To behavior (C3 parity): glides through a waypoint queue (Move To Position replaces it, Add Waypoint appends) and fires On Arrived at the final stop. rotate_toward_motion faces the travel direction."
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
		"if not moving or host == null or waypoints.is_empty():",
		"\treturn",
		"var target: Vector2 = waypoints[0]",
		"var previous := host.position",
		"host.position = host.position.move_toward(target, max_speed * delta)",
		"if rotate_toward_motion and host.position != previous:",
		"\thost.rotation = (host.position - previous).angle()",
		"if host.position.distance_to(target) < 0.5:",
		"\twaypoints.pop_front()",
		"\tif waypoints.is_empty():",
		"\t\tmoving = false",
		"\t\tarrived.emit()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var move_to_position_fn: EventFunction = EventFunction.new()
	move_to_position_fn.function_name = "move_to_position"
	move_to_position_fn.expose_as_ace = true
	move_to_position_fn.ace_display_name = "Move To Position"
	move_to_position_fn.ace_category = "Move To"
	move_to_position_fn.description = "Replaces the queue and glides toward the point."
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
		"waypoints = [Vector2(x, y)]",
		"moving = true"
	]))
	move_to_position_fn.events.append(move_to_position_fn_body)
	sheet.functions.append(move_to_position_fn)

	var add_waypoint_fn: EventFunction = EventFunction.new()
	add_waypoint_fn.function_name = "add_waypoint"
	add_waypoint_fn.expose_as_ace = true
	add_waypoint_fn.ace_display_name = "Add Waypoint"
	add_waypoint_fn.ace_category = "Move To"
	add_waypoint_fn.description = "Appends a stop to the queue (C3 waypoints)."
	var add_waypoint_fn_x: ACEParam = ACEParam.new()
	add_waypoint_fn_x.id = "x"
	add_waypoint_fn_x.type_name = "float"
	add_waypoint_fn.params.append(add_waypoint_fn_x)
	var add_waypoint_fn_y: ACEParam = ACEParam.new()
	add_waypoint_fn_y.id = "y"
	add_waypoint_fn_y.type_name = "float"
	add_waypoint_fn.params.append(add_waypoint_fn_y)
	var add_waypoint_fn_body: RawCodeRow = RawCodeRow.new()
	add_waypoint_fn_body.code = "\n".join(PackedStringArray([
		"waypoints.append(Vector2(x, y))",
		"moving = true"
	]))
	add_waypoint_fn.events.append(add_waypoint_fn_body)
	sheet.functions.append(add_waypoint_fn)

	var stop_moving_fn: EventFunction = EventFunction.new()
	stop_moving_fn.function_name = "stop_moving"
	stop_moving_fn.expose_as_ace = true
	stop_moving_fn.ace_display_name = "Stop Moving"
	stop_moving_fn.ace_category = "Move To"
	stop_moving_fn.description = "Clears the queue without firing On Arrived."
	var stop_moving_fn_body: RawCodeRow = RawCodeRow.new()
	stop_moving_fn_body.code = "\n".join(PackedStringArray([
		"moving = false",
		"waypoints = []"
	]))
	stop_moving_fn.events.append(stop_moving_fn_body)
	sheet.functions.append(stop_moving_fn)

	return _save_pack(sheet, "res://eventsheet_addons/move_to/move_to_behavior")

## Follow behavior (C3 parity)
func _build_follow() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "FollowBehavior"
	sheet.variables = {
		"target_path": {"type": "String", "default": "", "exported": true},
		"mode": {"type": "String", "default": "smooth", "exported": true, "options": ["smooth", "delayed"]},
		"follow_speed": {"type": "float", "default": 5.0, "exported": true},
		"delay": {"type": "float", "default": 0.4, "exported": true},
		"min_distance": {"type": "float", "default": 0.0, "exported": true},
		"following": {"type": "bool", "default": true, "exported": true},
		"history": {"type": "Array", "default": [], "exported": false},
		"clock": {"type": "float", "default": 0.0, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Follow behavior (C3 parity): trails another node. mode smooth = lerp chase; mode delayed = replay the target's position history after a delay (C3's Follow)."
	sheet.events.append(about)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null or target_path == \"\":",
		"\treturn",
		"var target := host.get_node_or_null(NodePath(target_path))",
		"if not (target is Node2D):",
		"\treturn",
		"clock += delta",
		"history.append([clock, target.position])",
		"while history.size() > 2 and float(history[0][0]) < clock - delay - 1.0:",
		"\thistory.pop_front()",
		"if not following:",
		"\treturn",
		"if mode == \"delayed\":",
		"\tvar sample_time := clock - delay",
		"\tfor entry: Array in history:",
		"\t\tif float(entry[0]) >= sample_time:",
		"\t\t\thost.position = entry[1]",
		"\t\t\tbreak",
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
		"following = true",
		"history = []"
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

## Drag & Drop behavior (C3 parity)
func _build_drag_drop() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "DragDropBehavior"
	sheet.variables = {
		"grab_radius": {"type": "float", "default": 48.0, "exported": true},
		"axes": {"type": "String", "default": "both", "exported": true, "options": ["both", "horizontal", "vertical"]},
		"dragging": {"type": "bool", "default": false, "exported": false},
		"grab_x": {"type": "float", "default": 0.0, "exported": false},
		"grab_y": {"type": "float", "default": 0.0, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Drag & Drop behavior (C3 parity): grab within the radius; axes locks dragging to one axis (both, horizontal, vertical). Fires On Drag Start / On Dropped."
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
		"\t\tgrab_x = host.global_position.x",
		"\t\tgrab_y = host.global_position.y",
		"\t\tdrag_started.emit()",
		"\tif dragging:",
		"\t\tvar destination := mouse",
		"\t\tif axes == \"horizontal\":",
		"\t\t\tdestination.y = grab_y",
		"\t\telif axes == \"vertical\":",
		"\t\t\tdestination.x = grab_x",
		"\t\thost.global_position = destination",
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

## Car behavior (C3 parity)
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
		"drift_recover": {"type": "float", "default": 0.15, "exported": true},
		"turn_while_stopped": {"type": "bool", "default": false, "exported": true},
		"speed": {"type": "float", "default": 0.0, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Car behavior (C3 parity): accelerate/brake with up/down, steer with left/right. drift_recover blends sliding back toward the heading (1 = grippy, low = drifty); turn_while_stopped allows steering at rest."
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
		"var steer_scale := 1.0 if (turn_while_stopped and absf(speed) < 1.0) else clampf(absf(speed) / max_speed, 0.0, 1.0) * signf(speed)",
		"host.rotation += deg_to_rad(steer_degrees) * steer * delta * steer_scale",
		"var heading := Vector2.from_angle(host.rotation) * speed",
		"host.velocity = host.velocity.lerp(heading, clampf(drift_recover, 0.01, 1.0))",
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

## Tile Movement behavior (C3 parity)
func _build_tile_movement() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "TileMovementBehavior"
	sheet.variables = {
		"tile_size": {"type": "float", "default": 64.0, "exported": true},
		"move_time": {"type": "float", "default": 0.15, "exported": true},
		"default_controls": {"type": "bool", "default": true, "exported": true},
		"moving": {"type": "bool", "default": false, "exported": false},
		"from_x": {"type": "float", "default": 0.0, "exported": false},
		"from_y": {"type": "float", "default": 0.0, "exported": false},
		"to_x": {"type": "float", "default": 0.0, "exported": false},
		"to_y": {"type": "float", "default": 0.0, "exported": false},
		"progress": {"type": "float", "default": 0.0, "exported": false},
		"pending_x": {"type": "float", "default": 0.0, "exported": false},
		"pending_y": {"type": "float", "default": 0.0, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Tile Movement behavior (C3 parity): grid-locked stepping (arrow keys or Simulate Step); grid-space helpers convert between tiles and pixels. Fires On Step Finished per tile."
	sheet.events.append(about)
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Step Finished\")",
		"## @ace_category(\"Tile Movement\")",
		"signal step_finished"
	]))
	sheet.events.append(signal_block)
	var extra_block_0: RawCodeRow = RawCodeRow.new()
	extra_block_0.code = "\n".join(PackedStringArray([
		"## @ace_hidden",
		"func to_grid(pixel: Vector2) -> Vector2i:",
		"\treturn Vector2i(roundi(pixel.x / tile_size), roundi(pixel.y / tile_size))",
		"",
		"## @ace_hidden",
		"func from_grid(tile: Vector2i) -> Vector2:",
		"\treturn Vector2(tile) * tile_size"
	]))
	sheet.events.append(extra_block_0)
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
		"var step := Vector2(pending_x, pending_y)",
		"pending_x = 0.0",
		"pending_y = 0.0",
		"if step == Vector2.ZERO and default_controls:",
		"\tstep = Vector2(Input.get_axis(&\"ui_left\", &\"ui_right\"), Input.get_axis(&\"ui_up\", &\"ui_down\"))",
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

	var simulate_step_fn: EventFunction = EventFunction.new()
	simulate_step_fn.function_name = "simulate_step"
	simulate_step_fn.expose_as_ace = true
	simulate_step_fn.ace_display_name = "Simulate Step"
	simulate_step_fn.ace_category = "Tile Movement"
	simulate_step_fn.description = "Steps one tile in a direction: left, right, up or down (C3 simulate control)."
	var simulate_step_fn_direction: ACEParam = ACEParam.new()
	simulate_step_fn_direction.id = "direction"
	simulate_step_fn_direction.type_name = "String"
	simulate_step_fn.params.append(simulate_step_fn_direction)
	var simulate_step_fn_body: RawCodeRow = RawCodeRow.new()
	simulate_step_fn_body.code = "\n".join(PackedStringArray([
		"if direction == \"left\":",
		"\tpending_x = -1.0",
		"elif direction == \"right\":",
		"\tpending_x = 1.0",
		"elif direction == \"up\":",
		"\tpending_y = -1.0",
		"elif direction == \"down\":",
		"\tpending_y = 1.0"
	]))
	simulate_step_fn.events.append(simulate_step_fn_body)
	sheet.functions.append(simulate_step_fn)

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

## Line of Sight behavior (C3 parity)
func _build_line_of_sight() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "LOSBehavior"
	sheet.variables = {
		"sight_range": {"type": "float", "default": 400.0, "exported": true},
		"cone_of_view_degrees": {"type": "float", "default": 360.0, "exported": true},
		"collision_mask": {"type": "int", "default": 1, "exported": true}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Line of Sight behavior (C3 parity): raycast LOS with range and an optional cone of view (degrees; 360 = all around). Conditions: Has Line Of Sight To, Has LOS Between positions."
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
		"\tif cone_of_view_degrees < 360.0:",
		"\t\tvar to_target := (point - host.global_position).angle()",
		"\t\tif absf(angle_difference(host.rotation, to_target)) > deg_to_rad(cone_of_view_degrees) * 0.5:",
		"\t\t\treturn false",
		"\treturn has_los_between(host.global_position, point)",
		"",
		"## @ace_condition",
		"## @ace_name(\"Has LOS Between\")",
		"## @ace_category(\"Line Of Sight\")",
		"## @ace_codegen_template(\"$LOSBehavior.has_los_between({from_point}, {to_point})\")",
		"func has_los_between(from_point: Vector2, to_point: Vector2) -> bool:",
		"\tif host == null:",
		"\t\treturn false",
		"\tvar query := PhysicsRayQueryParameters2D.create(from_point, to_point)",
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

## Sine 3D behavior (C3-style)
func _build_sine_3d() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "Sine3DBehavior"
	sheet.variables = {
		"movement": {"type": "String", "default": "y", "exported": true, "options": ["x", "y", "z", "rotation-y"]},
		"wave": {"type": "String", "default": "sine", "exported": true, "options": ["sine", "triangle", "sawtooth", "reverse-sawtooth", "square"]},
		"period": {"type": "float", "default": 4.0, "exported": true},
		"magnitude": {"type": "float", "default": 2.0, "exported": true},
		"active": {"type": "bool", "default": true, "exported": true},
		"time": {"type": "float", "default": 0.0, "exported": false},
		"base_x": {"type": "float", "default": 0.0, "exported": false},
		"base_y": {"type": "float", "default": 0.0, "exported": false},
		"base_z": {"type": "float", "default": 0.0, "exported": false},
		"base_rot_y": {"type": "float", "default": 0.0, "exported": false},
		"base_captured": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Sine 3D behavior (C3-style): oscillates the host along an axis (x, y, z) or around the Y axis (rotation-y), with the full wave set."
	sheet.events.append(about)
	var extra_block_0: RawCodeRow = RawCodeRow.new()
	extra_block_0.code = "\n".join(PackedStringArray([
		"## @ace_hidden",
		"func _wave(t: float) -> float:",
		"\tvar cycle := fposmod(t, 1.0)",
		"\tmatch wave:",
		"\t\t\"triangle\":",
		"\t\t\treturn 1.0 - 4.0 * absf(cycle - 0.5)",
		"\t\t\"sawtooth\":",
		"\t\t\treturn 2.0 * cycle - 1.0",
		"\t\t\"reverse-sawtooth\":",
		"\t\t\treturn 1.0 - 2.0 * cycle",
		"\t\t\"square\":",
		"\t\t\treturn 1.0 if cycle < 0.5 else -1.0",
		"\treturn sin(cycle * TAU)"
	]))
	sheet.events.append(extra_block_0)
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
		"\tbase_z = host.position.z",
		"\tbase_rot_y = host.rotation.y",
		"\tbase_captured = true",
		"time += delta",
		"var offset := _wave(time / maxf(period, 0.001)) * magnitude",
		"if movement == \"x\":",
		"\thost.position.x = base_x + offset",
		"elif movement == \"y\":",
		"\thost.position.y = base_y + offset",
		"elif movement == \"z\":",
		"\thost.position.z = base_z + offset",
		"elif movement == \"rotation-y\":",
		"\thost.rotation.y = base_rot_y + offset * 0.0174533"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var set_sine3d_active_fn: EventFunction = EventFunction.new()
	set_sine3d_active_fn.function_name = "set_sine3d_active"
	set_sine3d_active_fn.expose_as_ace = true
	set_sine3d_active_fn.ace_display_name = "Set Sine 3D Active"
	set_sine3d_active_fn.ace_category = "Sine 3D"
	set_sine3d_active_fn.description = "Pauses or resumes the oscillation."
	var set_sine3d_active_fn_is_active: ACEParam = ACEParam.new()
	set_sine3d_active_fn_is_active.id = "is_active"
	set_sine3d_active_fn_is_active.type_name = "bool"
	set_sine3d_active_fn.params.append(set_sine3d_active_fn_is_active)
	var set_sine3d_active_fn_body: RawCodeRow = RawCodeRow.new()
	set_sine3d_active_fn_body.code = "\n".join(PackedStringArray([
		"active = is_active"
	]))
	set_sine3d_active_fn.events.append(set_sine3d_active_fn_body)
	sheet.functions.append(set_sine3d_active_fn)

	var reset_sine3d_fn: EventFunction = EventFunction.new()
	reset_sine3d_fn.function_name = "reset_sine3d"
	reset_sine3d_fn.expose_as_ace = true
	reset_sine3d_fn.ace_display_name = "Reset Sine 3D"
	reset_sine3d_fn.ace_category = "Sine 3D"
	reset_sine3d_fn.description = "Restarts the wave from the current state."
	var reset_sine3d_fn_body: RawCodeRow = RawCodeRow.new()
	reset_sine3d_fn_body.code = "\n".join(PackedStringArray([
		"time = 0.0",
		"base_captured = false"
	]))
	reset_sine3d_fn.events.append(reset_sine3d_fn_body)
	sheet.functions.append(reset_sine3d_fn)

	return _save_pack(sheet, "res://eventsheet_addons/sine_3d/sine_3d_behavior")

## Orbit 3D behavior (C3-style)
func _build_orbit_3d() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "Orbit3DBehavior"
	sheet.variables = {
		"radius": {"type": "float", "default": 3.0, "exported": true},
		"speed_degrees": {"type": "float", "default": 90.0, "exported": true},
		"angle": {"type": "float", "default": 0.0, "exported": false},
		"center_x": {"type": "float", "default": 0.0, "exported": false},
		"center_y": {"type": "float", "default": 0.0, "exported": false},
		"center_z": {"type": "float", "default": 0.0, "exported": false},
		"center_captured": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Orbit 3D behavior (C3-style): circles the host around its starting point in the XZ plane (Y stays)."
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
		"\tcenter_z = host.position.z",
		"\tcenter_captured = true",
		"angle += deg_to_rad(speed_degrees) * delta",
		"host.position = Vector3(center_x + cos(angle) * radius, center_y, center_z + sin(angle) * radius)"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var set_orbit3d_center_fn: EventFunction = EventFunction.new()
	set_orbit3d_center_fn.function_name = "set_orbit3d_center"
	set_orbit3d_center_fn.expose_as_ace = true
	set_orbit3d_center_fn.ace_display_name = "Set Orbit 3D Center"
	set_orbit3d_center_fn.ace_category = "Orbit 3D"
	set_orbit3d_center_fn.description = "Orbits around the given point from now on."
	var set_orbit3d_center_fn_x: ACEParam = ACEParam.new()
	set_orbit3d_center_fn_x.id = "x"
	set_orbit3d_center_fn_x.type_name = "float"
	set_orbit3d_center_fn.params.append(set_orbit3d_center_fn_x)
	var set_orbit3d_center_fn_y: ACEParam = ACEParam.new()
	set_orbit3d_center_fn_y.id = "y"
	set_orbit3d_center_fn_y.type_name = "float"
	set_orbit3d_center_fn.params.append(set_orbit3d_center_fn_y)
	var set_orbit3d_center_fn_z: ACEParam = ACEParam.new()
	set_orbit3d_center_fn_z.id = "z"
	set_orbit3d_center_fn_z.type_name = "float"
	set_orbit3d_center_fn.params.append(set_orbit3d_center_fn_z)
	var set_orbit3d_center_fn_body: RawCodeRow = RawCodeRow.new()
	set_orbit3d_center_fn_body.code = "\n".join(PackedStringArray([
		"center_x = x",
		"center_y = y",
		"center_z = z",
		"center_captured = true"
	]))
	set_orbit3d_center_fn.events.append(set_orbit3d_center_fn_body)
	sheet.functions.append(set_orbit3d_center_fn)

	return _save_pack(sheet, "res://eventsheet_addons/orbit_3d/orbit_3d_behavior")

## Bullet 3D behavior (C3-style)
func _build_bullet_3d() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "Bullet3DBehavior"
	sheet.variables = {
		"speed": {"type": "float", "default": 10.0, "exported": true},
		"gravity": {"type": "float", "default": 0.0, "exported": true},
		"distance_travelled": {"type": "float", "default": 0.0, "exported": false},
		"vel_x": {"type": "float", "default": 0.0, "exported": false},
		"vel_y": {"type": "float", "default": 0.0, "exported": false},
		"vel_z": {"type": "float", "default": 0.0, "exported": false},
		"launched": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Bullet 3D behavior (C3-style): launches along the host's forward (-Z) with speed and gravity; tracks distance travelled."
	sheet.events.append(about)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"if not launched:",
		"\tlaunch_forward()",
		"vel_y -= gravity * delta",
		"var motion := Vector3(vel_x, vel_y, vel_z) * delta",
		"host.position += motion",
		"distance_travelled += motion.length()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var launch_forward_fn: EventFunction = EventFunction.new()
	launch_forward_fn.function_name = "launch_forward"
	launch_forward_fn.expose_as_ace = true
	launch_forward_fn.ace_display_name = "Launch Forward"
	launch_forward_fn.ace_category = "Bullet 3D"
	launch_forward_fn.description = "(Re)launches along the host's current forward direction."
	var launch_forward_fn_body: RawCodeRow = RawCodeRow.new()
	launch_forward_fn_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"var forward := -host.global_transform.basis.z * speed",
		"vel_x = forward.x",
		"vel_y = forward.y",
		"vel_z = forward.z",
		"launched = true"
	]))
	launch_forward_fn.events.append(launch_forward_fn_body)
	sheet.functions.append(launch_forward_fn)

	var set_bullet3d_speed_fn: EventFunction = EventFunction.new()
	set_bullet3d_speed_fn.function_name = "set_bullet3d_speed"
	set_bullet3d_speed_fn.expose_as_ace = true
	set_bullet3d_speed_fn.ace_display_name = "Set Bullet 3D Speed"
	set_bullet3d_speed_fn.ace_category = "Bullet 3D"
	set_bullet3d_speed_fn.description = "Changes speed, keeping the current direction."
	var set_bullet3d_speed_fn_value: ACEParam = ACEParam.new()
	set_bullet3d_speed_fn_value.id = "value"
	set_bullet3d_speed_fn_value.type_name = "float"
	set_bullet3d_speed_fn.params.append(set_bullet3d_speed_fn_value)
	var set_bullet3d_speed_fn_body: RawCodeRow = RawCodeRow.new()
	set_bullet3d_speed_fn_body.code = "\n".join(PackedStringArray([
		"speed = value",
		"var direction := Vector3(vel_x, vel_y, vel_z).normalized()",
		"if direction == Vector3.ZERO and host != null:",
		"\tdirection = -host.global_transform.basis.z",
		"vel_x = direction.x * value",
		"vel_y = direction.y * value",
		"vel_z = direction.z * value",
		"launched = true"
	]))
	set_bullet3d_speed_fn.events.append(set_bullet3d_speed_fn_body)
	sheet.functions.append(set_bullet3d_speed_fn)

	return _save_pack(sheet, "res://eventsheet_addons/bullet_3d/bullet_3d_behavior")

## Move To 3D behavior (C3-style)
func _build_move_to_3d() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "MoveTo3DBehavior"
	sheet.variables = {
		"max_speed": {"type": "float", "default": 5.0, "exported": true},
		"waypoints": {"type": "Array", "default": [], "exported": false},
		"moving": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Move To 3D behavior (C3-style): glides through a queue of Vector3 waypoints and fires On Arrived at the final stop."
	sheet.events.append(about)
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Arrived (3D)\")",
		"## @ace_category(\"Move To 3D\")",
		"signal arrived"
	]))
	sheet.events.append(signal_block)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not moving or host == null or waypoints.is_empty():",
		"\treturn",
		"var target: Vector3 = waypoints[0]",
		"host.position = host.position.move_toward(target, max_speed * delta)",
		"if host.position.distance_to(target) < 0.05:",
		"\twaypoints.pop_front()",
		"\tif waypoints.is_empty():",
		"\t\tmoving = false",
		"\t\tarrived.emit()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var move_to_position_3d_fn: EventFunction = EventFunction.new()
	move_to_position_3d_fn.function_name = "move_to_position_3d"
	move_to_position_3d_fn.expose_as_ace = true
	move_to_position_3d_fn.ace_display_name = "Move To Position (3D)"
	move_to_position_3d_fn.ace_category = "Move To 3D"
	move_to_position_3d_fn.description = "Replaces the queue and glides toward the point."
	var move_to_position_3d_fn_x: ACEParam = ACEParam.new()
	move_to_position_3d_fn_x.id = "x"
	move_to_position_3d_fn_x.type_name = "float"
	move_to_position_3d_fn.params.append(move_to_position_3d_fn_x)
	var move_to_position_3d_fn_y: ACEParam = ACEParam.new()
	move_to_position_3d_fn_y.id = "y"
	move_to_position_3d_fn_y.type_name = "float"
	move_to_position_3d_fn.params.append(move_to_position_3d_fn_y)
	var move_to_position_3d_fn_z: ACEParam = ACEParam.new()
	move_to_position_3d_fn_z.id = "z"
	move_to_position_3d_fn_z.type_name = "float"
	move_to_position_3d_fn.params.append(move_to_position_3d_fn_z)
	var move_to_position_3d_fn_body: RawCodeRow = RawCodeRow.new()
	move_to_position_3d_fn_body.code = "\n".join(PackedStringArray([
		"waypoints = [Vector3(x, y, z)]",
		"moving = true"
	]))
	move_to_position_3d_fn.events.append(move_to_position_3d_fn_body)
	sheet.functions.append(move_to_position_3d_fn)

	var add_waypoint_3d_fn: EventFunction = EventFunction.new()
	add_waypoint_3d_fn.function_name = "add_waypoint_3d"
	add_waypoint_3d_fn.expose_as_ace = true
	add_waypoint_3d_fn.ace_display_name = "Add Waypoint (3D)"
	add_waypoint_3d_fn.ace_category = "Move To 3D"
	add_waypoint_3d_fn.description = "Appends a stop to the queue."
	var add_waypoint_3d_fn_x: ACEParam = ACEParam.new()
	add_waypoint_3d_fn_x.id = "x"
	add_waypoint_3d_fn_x.type_name = "float"
	add_waypoint_3d_fn.params.append(add_waypoint_3d_fn_x)
	var add_waypoint_3d_fn_y: ACEParam = ACEParam.new()
	add_waypoint_3d_fn_y.id = "y"
	add_waypoint_3d_fn_y.type_name = "float"
	add_waypoint_3d_fn.params.append(add_waypoint_3d_fn_y)
	var add_waypoint_3d_fn_z: ACEParam = ACEParam.new()
	add_waypoint_3d_fn_z.id = "z"
	add_waypoint_3d_fn_z.type_name = "float"
	add_waypoint_3d_fn.params.append(add_waypoint_3d_fn_z)
	var add_waypoint_3d_fn_body: RawCodeRow = RawCodeRow.new()
	add_waypoint_3d_fn_body.code = "\n".join(PackedStringArray([
		"waypoints.append(Vector3(x, y, z))",
		"moving = true"
	]))
	add_waypoint_3d_fn.events.append(add_waypoint_3d_fn_body)
	sheet.functions.append(add_waypoint_3d_fn)

	var stop_moving_3d_fn: EventFunction = EventFunction.new()
	stop_moving_3d_fn.function_name = "stop_moving_3d"
	stop_moving_3d_fn.expose_as_ace = true
	stop_moving_3d_fn.ace_display_name = "Stop Moving (3D)"
	stop_moving_3d_fn.ace_category = "Move To 3D"
	stop_moving_3d_fn.description = "Clears the queue without firing On Arrived."
	var stop_moving_3d_fn_body: RawCodeRow = RawCodeRow.new()
	stop_moving_3d_fn_body.code = "\n".join(PackedStringArray([
		"moving = false",
		"waypoints = []"
	]))
	stop_moving_3d_fn.events.append(stop_moving_3d_fn_body)
	sheet.functions.append(stop_moving_3d_fn)

	return _save_pack(sheet, "res://eventsheet_addons/move_to_3d/move_to_3d_behavior")

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


## Numeric springing (cleaned-up port of the author's C3 simple_spring addon): NAMED
## springs (value/target/velocity each) driven by stiffness + damping + precision, with
## impulses, reached-triggers and host-transform conveniences. Mesh deformation from the
## C3 original is an honest skip (that's shader/skeleton territory in Godot). Exported
## properties showcase Inspector attributes (ranges + tooltips) in a shipped pack.
func _build_spring() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "SpringBehavior"
	sheet.addon_tags = PackedStringArray(["motion", "juice"])
	sheet.variables = {
		"default_stiffness": {"type": "float", "default": 170.0, "exported": true,
			"attributes": {"tooltip": "Spring force toward the target (higher = snappier).", "range": {"min": "1", "max": "1000", "step": "1"}}},
		"default_damping": {"type": "float", "default": 0.85, "exported": true,
			"attributes": {"tooltip": "0 = oscillate forever, 1 = no overshoot.", "range": {"min": "0", "max": "1", "step": "0.01"}}},
		"default_precision": {"type": "float", "default": 0.01, "exported": true,
			"attributes": {"tooltip": "Distance + speed below which a spring counts as settled."}},
		"springs": {"type": "Dictionary", "default": {}, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Numeric springing: snappy, physical motion for ANY number. Name a spring, set its target, read its value — or use the host helpers (x/y/angle/scale) for instant juice."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Spring Reached\")",
		"## @ace_category(\"Spring\")",
		"signal spring_reached(spring_name: String)",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Springing\")",
		"## @ace_category(\"Spring\")",
		"## @ace_codegen_template(\"$SpringBehavior.is_springing({spring_name})\")",
		"func is_springing(spring_name: String) -> bool:",
		"\treturn springs.has(spring_name) and bool(springs[spring_name].get(\"active\", false))",
		"",
		"## @ace_expression",
		"## @ace_name(\"Spring Value\")",
		"## @ace_category(\"Spring\")",
		"func spring_value(spring_name: String) -> float:",
		"\treturn float(springs.get(spring_name, {}).get(\"value\", 0.0))",
		"",
		"## @ace_expression",
		"## @ace_name(\"Spring Velocity\")",
		"## @ace_category(\"Spring\")",
		"func spring_velocity(spring_name: String) -> float:",
		"\treturn float(springs.get(spring_name, {}).get(\"velocity\", 0.0))",
		"",
		"## @ace_expression",
		"## @ace_name(\"Spring Progress\")",
		"## @ace_category(\"Spring\")",
		"func spring_progress(spring_name: String) -> float:",
		"\tvar entry: Dictionary = springs.get(spring_name, {})",
		"\tvar span: float = absf(float(entry.get(\"target\", 0.0)) - float(entry.get(\"from\", 0.0)))",
		"\tif span <= 0.0:",
		"\t\treturn 1.0",
		"\treturn clampf(1.0 - absf(float(entry.get(\"target\", 0.0)) - float(entry.get(\"value\", 0.0))) / span, 0.0, 1.0)",
		"",
		"func _spring_entry(spring_name: String) -> Dictionary:",
		"\tif not springs.has(spring_name):",
		"\t\tsprings[spring_name] = {\"value\": 0.0, \"from\": 0.0, \"target\": 0.0, \"velocity\": 0.0,",
		"\t\t\t\"stiffness\": default_stiffness, \"damping\": default_damping, \"precision\": default_precision, \"active\": false}",
		"\treturn springs[spring_name]",
		"",
		"# Host conveniences: springs with these names write straight onto the parent.",
		"func _apply_to_host(spring_name: String, value: float) -> void:",
		"\tif host == null:",
		"\t\treturn",
		"\tmatch spring_name:",
		"\t\t\"__x\": host.position.x = value",
		"\t\t\"__y\": host.position.y = value",
		"\t\t\"__angle\": host.rotation_degrees = value",
		"\t\t\"__scale\": host.scale = Vector2(value, value)"
	]))
	sheet.events.append(block)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var simulate: RawCodeRow = RawCodeRow.new()
	simulate.code = "\n".join(PackedStringArray([
		"# Semi-implicit integration; damping uses pow() so motion is framerate-independent.",
		"for spring_name: Variant in springs.keys():",
		"\tvar entry: Dictionary = springs[spring_name]",
		"\tif not bool(entry.get(\"active\", false)):",
		"\t\tcontinue",
		"\tentry[\"velocity\"] = float(entry[\"velocity\"]) + (float(entry[\"target\"]) - float(entry[\"value\"])) * float(entry[\"stiffness\"]) * delta",
		"\t# Damping is the fraction of velocity LOST PER SECOND (framerate-independent).",
		"\tentry[\"velocity\"] = float(entry[\"velocity\"]) * pow(1.0 - float(entry[\"damping\"]), delta)",
		"\tentry[\"value\"] = float(entry[\"value\"]) + float(entry[\"velocity\"]) * delta",
		"\tif absf(float(entry[\"target\"]) - float(entry[\"value\"])) < float(entry[\"precision\"]) and absf(float(entry[\"velocity\"])) < float(entry[\"precision\"]):",
		"\t\tentry[\"value\"] = float(entry[\"target\"])",
		"\t\tentry[\"velocity\"] = 0.0",
		"\t\tentry[\"active\"] = false",
		"\t\tspring_reached.emit(str(spring_name))",
		"\t_apply_to_host(str(spring_name), float(entry[\"value\"]))"
	]))
	tick.actions.append(simulate)
	sheet.events.append(tick)
	_append_function(sheet, "spring_to", "Spring To", "Spring", "Springs the named value toward a target.",
		[["spring_name", "String"], ["target", "float"]],
		"var entry: Dictionary = _spring_entry(spring_name)\nentry[\"from\"] = float(entry[\"value\"])\nentry[\"target\"] = target\nentry[\"active\"] = true")
	_append_function(sheet, "spring_between", "Spring Between", "Spring", "Snaps to a start value, then springs to the end value.",
		[["spring_name", "String"], ["from_value", "float"], ["to_value", "float"]],
		"var entry: Dictionary = _spring_entry(spring_name)\nentry[\"value\"] = from_value\nentry[\"from\"] = from_value\nentry[\"velocity\"] = 0.0\nentry[\"target\"] = to_value\nentry[\"active\"] = true")
	_append_function(sheet, "set_spring", "Set Spring Value", "Spring", "Snaps the named spring (no motion).",
		[["spring_name", "String"], ["value", "float"]],
		"var entry: Dictionary = _spring_entry(spring_name)\nentry[\"value\"] = value\nentry[\"from\"] = value\nentry[\"target\"] = value\nentry[\"velocity\"] = 0.0\nentry[\"active\"] = false")
	_append_function(sheet, "add_impulse", "Add Impulse", "Spring", "Kicks the named spring's velocity (instant juice).",
		[["spring_name", "String"], ["amount", "float"]],
		"var entry: Dictionary = _spring_entry(spring_name)\nentry[\"velocity\"] = float(entry[\"velocity\"]) + amount\nentry[\"active\"] = true")
	_append_function(sheet, "stop_spring", "Stop Spring", "Spring", "Freezes the named spring where it is.",
		[["spring_name", "String"]],
		"if springs.has(spring_name):\n\tsprings[spring_name][\"active\"] = false")
	_append_function(sheet, "configure_spring", "Configure Spring", "Spring", "Per-spring stiffness/damping/precision overrides.",
		[["spring_name", "String"], ["stiffness", "float"], ["damping", "float"], ["precision", "float"]],
		"var entry: Dictionary = _spring_entry(spring_name)\nentry[\"stiffness\"] = stiffness\nentry[\"damping\"] = clampf(damping, 0.0, 1.0)\nentry[\"precision\"] = precision")
	_append_function(sheet, "spring_host_x", "Spring Host X", "Spring", "Springs the host's X position.",
		[["target", "float"]],
		"var entry: Dictionary = _spring_entry(\"__x\")\nif not bool(entry[\"active\"]) and host != null:\n\tentry[\"value\"] = host.position.x\nentry[\"from\"] = float(entry[\"value\"])\nentry[\"target\"] = target\nentry[\"active\"] = true")
	_append_function(sheet, "spring_host_y", "Spring Host Y", "Spring", "Springs the host's Y position.",
		[["target", "float"]],
		"var entry: Dictionary = _spring_entry(\"__y\")\nif not bool(entry[\"active\"]) and host != null:\n\tentry[\"value\"] = host.position.y\nentry[\"from\"] = float(entry[\"value\"])\nentry[\"target\"] = target\nentry[\"active\"] = true")
	_append_function(sheet, "spring_host_angle", "Spring Host Angle", "Spring", "Springs the host's rotation (degrees).",
		[["degrees", "float"]],
		"var entry: Dictionary = _spring_entry(\"__angle\")\nif not bool(entry[\"active\"]) and host != null:\n\tentry[\"value\"] = host.rotation_degrees\nentry[\"from\"] = float(entry[\"value\"])\nentry[\"target\"] = degrees\nentry[\"active\"] = true")
	_append_function(sheet, "spring_host_scale", "Spring Host Scale", "Spring", "Springs the host's uniform scale (squash & stretch!).",
		[["target", "float"]],
		"var entry: Dictionary = _spring_entry(\"__scale\")\nif not bool(entry[\"active\"]) and host != null:\n\tentry[\"value\"] = host.scale.x\nentry[\"from\"] = float(entry[\"value\"])\nentry[\"target\"] = target\nentry[\"active\"] = true")
	return _save_pack(sheet, "res://eventsheet_addons/spring/spring_behavior")

## Tween behavior: Godot's Tween, the C3-behavior way — duration/transition/easing as
## Inspector combos, one-call property/position/scale/rotation/alpha tweens on the host,
## and an On Tween Finished trigger. Plain create_tween underneath (parity contract).
func _build_tween() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "TweenBehavior"
	sheet.addon_tags = PackedStringArray(["motion", "juice"])
	sheet.variables = {
		"default_duration": {"type": "float", "default": 0.3, "exported": true,
			"attributes": {"tooltip": "Seconds used when a tween call passes 0.", "range": {"min": "0.01", "max": "10", "step": "0.01"}}},
		"transition": {"type": "String", "default": "sine", "exported": true,
			"options": ["linear", "sine", "quad", "cubic", "quart", "quint", "expo", "circ", "elastic", "back", "bounce", "spring"]},
		"easing": {"type": "String", "default": "out", "exported": true,
			"options": ["in", "out", "in_out", "out_in"]}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Tweens, the behavior way: pick transition + easing in the Inspector, then call one action — Tween Position / Scale / Rotation / Alpha / any property."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Tween Finished\")",
		"## @ace_category(\"Tween\")",
		"signal tween_finished",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Tweening\")",
		"## @ace_category(\"Tween\")",
		"## @ace_codegen_template(\"$TweenBehavior.is_tweening()\")",
		"func is_tweening() -> bool:",
		"\treturn _active_tween != null and _active_tween.is_running()",
		"",
		"var _active_tween: Tween = null",
		"",
		"func _trans_id() -> int:",
		"\tmatch transition:",
		"\t\t\"linear\": return Tween.TRANS_LINEAR",
		"\t\t\"quad\": return Tween.TRANS_QUAD",
		"\t\t\"cubic\": return Tween.TRANS_CUBIC",
		"\t\t\"quart\": return Tween.TRANS_QUART",
		"\t\t\"quint\": return Tween.TRANS_QUINT",
		"\t\t\"expo\": return Tween.TRANS_EXPO",
		"\t\t\"circ\": return Tween.TRANS_CIRC",
		"\t\t\"elastic\": return Tween.TRANS_ELASTIC",
		"\t\t\"back\": return Tween.TRANS_BACK",
		"\t\t\"bounce\": return Tween.TRANS_BOUNCE",
		"\t\t\"spring\": return Tween.TRANS_SPRING",
		"\treturn Tween.TRANS_SINE",
		"",
		"func _ease_id() -> int:",
		"\tmatch easing:",
		"\t\t\"in\": return Tween.EASE_IN",
		"\t\t\"in_out\": return Tween.EASE_IN_OUT",
		"\t\t\"out_in\": return Tween.EASE_OUT_IN",
		"\treturn Tween.EASE_OUT",
		"",
		"func _start_tween(property_path: String, final_value: Variant, duration: float) -> void:",
		"\tif host == null:",
		"\t\treturn",
		"\tvar seconds: float = duration if duration > 0.0 else default_duration",
		"\t_active_tween = host.create_tween()",
		"\t_active_tween.tween_property(host, NodePath(property_path), final_value, seconds).set_trans(_trans_id()).set_ease(_ease_id())",
		"\t_active_tween.finished.connect(func() -> void: tween_finished.emit())"
	]))
	sheet.events.append(block)
	_append_function(sheet, "tween_property_to", "Tween Property", "Tween", "Tweens any host property (e.g. position:x) to a value.",
		[["property_path", "String"], ["final_value", "float"], ["duration", "float"]],
		"_start_tween(property_path, final_value, duration)")
	_append_function(sheet, "tween_position", "Tween Position", "Tween", "Moves the host to (x, y).",
		[["x", "float"], ["y", "float"], ["duration", "float"]],
		"_start_tween(\"position\", Vector2(x, y), duration)")
	_append_function(sheet, "tween_scale", "Tween Scale", "Tween", "Scales the host uniformly.",
		[["amount", "float"], ["duration", "float"]],
		"_start_tween(\"scale\", Vector2(amount, amount), duration)")
	_append_function(sheet, "tween_rotation", "Tween Rotation", "Tween", "Rotates the host to the given degrees.",
		[["degrees", "float"], ["duration", "float"]],
		"_start_tween(\"rotation_degrees\", degrees, duration)")
	_append_function(sheet, "tween_alpha", "Tween Alpha", "Tween", "Fades the host's modulate alpha.",
		[["alpha", "float"], ["duration", "float"]],
		"_start_tween(\"modulate:a\", clampf(alpha, 0.0, 1.0), duration)")
	_append_function(sheet, "stop_tweens", "Stop Tweens", "Tween", "Kills the running tween (host stays where it is).",
		[],
		"if _active_tween != null:\n\t_active_tween.kill()\n\t_active_tween = null")
	return _save_pack(sheet, "res://eventsheet_addons/tween/tween_behavior")

## Shared shape for the spring/tween builders: one exposed-as-ACE function.
func _append_function(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = function_name
	event_function.expose_as_ace = true
	event_function.ace_display_name = display_name
	event_function.ace_category = category
	event_function.description = description
	for param_pair: Array in params:
		var parameter: ACEParam = ACEParam.new()
		parameter.id = str(param_pair[0])
		parameter.type_name = str(param_pair[1])
		event_function.params.append(parameter)
	var body_row: RawCodeRow = RawCodeRow.new()
	body_row.code = body
	event_function.events.append(body_row)
	sheet.functions.append(event_function)


## Save System addon v2: slot-based persistence as an AUTOLOAD sheet — deliberately
## UN-opinionated: storage strategy (directory/pattern/section/format/encryption) is
## exported Inspector properties; the core is Variant-typed (typed Save Number/Text
## remain as conveniences — their ace_ids are API); before_save/after_load lifecycle
## signals let ANY sheet contribute state without this pack knowing it exists; slot
## metadata powers save/load menus; optional autosave. Full-state snapshots stay an
## honest non-goal (Godot serializes scenes, not "the whole game").
## THE DEEPEST EXTENSION POINT: this pack IS an event sheet — open the .tres, add
## functions, recompile, re-register.
func _build_save_system() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "SaveSystem"
	sheet.host_class = "Node"
	sheet.custom_class_name = "SaveSystemAddon"
	sheet.addon_tags = PackedStringArray(["persistence"])
	sheet.variables = {
		"slot": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "Active save slot (each slot is its own file).", "range": {"min": "0", "max": "9", "step": "1"}, "group": "Save System"}},
		"save_directory": {"type": "String", "default": "user://", "exported": true,
			"attributes": {"tooltip": "Where save files live."}},
		"file_pattern": {"type": "String", "default": "save_{slot}.cfg", "exported": true,
			"attributes": {"tooltip": "{slot} becomes the slot number."}},
		"section": {"type": "String", "default": "save", "exported": true,
			"attributes": {"tooltip": "ConfigFile section / JSON namespace for values."}},
		"format": {"type": "String", "default": "config", "exported": true, "options": ["config", "json"]},
		"encryption_key": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "Non-empty = encrypted saves (keep the key out of screenshots!)."}},
		"autosave_interval": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Seconds between autosaves (0 = off). Fires On Before Save first.", "range": {"min": "0", "max": "600", "step": "1"}}},
		"autosave_accumulator": {"type": "float", "default": 0.0, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Save System: register as the SaveSystem autoload, then save from any sheet. Strategy (paths/format/encryption) lives in the Inspector; On Before Save / On After Load let every sheet contribute its own state. This pack is an event sheet — extend it by editing it."
	sheet.events.append(about)
	var helpers: RawCodeRow = RawCodeRow.new()
	helpers.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Save Written\")",
		"## @ace_category(\"Save System\")",
		"signal save_written(slot_index: int)",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Before Save\")",
		"## @ace_category(\"Save System\")",
		"signal before_save(slot_index: int)",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On After Load\")",
		"## @ace_category(\"Save System\")",
		"signal after_load(slot_index: int)",
		"",
		"func _slot_path(target_slot: int = -1) -> String:",
		"\tvar chosen: int = slot if target_slot < 0 else target_slot",
		"\treturn save_directory.path_join(file_pattern.replace(\"{slot}\", str(chosen)))",
		"",
		"# Format-agnostic backends: everything above reads/writes one Dictionary.",
		"func _read_all() -> Dictionary:",
		"\tvar path: String = _slot_path()",
		"\tif format == \"json\":",
		"\t\tvar file: FileAccess = FileAccess.open_encrypted_with_pass(path, FileAccess.READ, encryption_key) if not encryption_key.is_empty() else FileAccess.open(path, FileAccess.READ)",
		"\t\tif file == null:",
		"\t\t\treturn {}",
		"\t\tvar parsed: Variant = JSON.parse_string(file.get_as_text())",
		"\t\treturn (parsed as Dictionary).get(section, {}) if parsed is Dictionary else {}",
		"\tvar config: ConfigFile = ConfigFile.new()",
		"\tif encryption_key.is_empty():",
		"\t\tconfig.load(path)",
		"\telse:",
		"\t\tconfig.load_encrypted_pass(path, encryption_key)",
		"\tvar data: Dictionary = {}",
		"\tfor key: String in config.get_section_keys(section) if config.has_section(section) else PackedStringArray():",
		"\t\tdata[key] = config.get_value(section, key)",
		"\treturn data",
		"",
		"func _write_all(data: Dictionary) -> void:",
		"\tvar path: String = _slot_path()",
		"\tif format == \"json\":",
		"\t\tvar file: FileAccess = FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, encryption_key) if not encryption_key.is_empty() else FileAccess.open(path, FileAccess.WRITE)",
		"\t\tif file != null:",
		"\t\t\tfile.store_string(JSON.stringify({section: data}, \"\\t\"))",
		"\t\t\tfile.close()",
		"\telse:",
		"\t\tvar config: ConfigFile = ConfigFile.new()",
		"\t\tfor key: Variant in data.keys():",
		"\t\t\tconfig.set_value(section, str(key), data[key])",
		"\t\tif encryption_key.is_empty():",
		"\t\t\tconfig.save(path)",
		"\t\telse:",
		"\t\t\tconfig.save_encrypted_pass(path, encryption_key)",
		"\tsave_written.emit(slot)"
	]))
	sheet.events.append(helpers)
	var autosave_tick: EventRow = EventRow.new()
	autosave_tick.trigger_provider_id = "Core"
	autosave_tick.trigger_id = "OnProcess"
	var autosave_body: RawCodeRow = RawCodeRow.new()
	autosave_body.code = "\n".join(PackedStringArray([
		"if autosave_interval <= 0.0:",
		"\treturn",
		"autosave_accumulator += delta",
		"if autosave_accumulator >= autosave_interval:",
		"\tautosave_accumulator = 0.0",
		"\tsave_game()"
	]))
	autosave_tick.actions.append(autosave_body)
	sheet.events.append(autosave_tick)
	# Variant-typed core.
	_append_function(sheet, "save_value", "Save Value", "Save System", "Writes ANY value (number, text, Vector2, Color, Dictionary…) under the key.",
		[["key", "String"], ["value", "Variant"]],
		"var data: Dictionary = _read_all()\ndata[key] = value\n_write_all(data)")
	var load_value: EventFunction = _exposed_function("load_value", "Load Value", "Save System", "Reads any value (your default when missing).", [["key", "String"], ["default_value", "Variant"]],
		"return _read_all().get(key, default_value)")
	# TYPE_MAX = the compiler's "returns Variant" sentinel.
	load_value.return_type = TYPE_MAX
	sheet.functions.append(load_value)
	# Typed conveniences (ace_ids are API — kept, now thin delegations).
	_append_function(sheet, "save_number", "Save Number", "Save System", "Writes a number under the key (active slot).",
		[["key", "String"], ["value", "float"]],
		"save_value(key, value)")
	var load_number: EventFunction = _exposed_function("load_number", "Load Number", "Save System", "Reads a number (0 when missing).", [["key", "String"]],
		"return float(load_value(key, 0.0))")
	load_number.return_type = TYPE_FLOAT
	sheet.functions.append(load_number)
	_append_function(sheet, "save_text", "Save Text", "Save System", "Writes a string under the key (active slot).",
		[["key", "String"], ["value", "String"]],
		"save_value(key, value)")
	var load_text: EventFunction = _exposed_function("load_text", "Load Text", "Save System", "Reads a string (\"\" when missing).", [["key", "String"]],
		"return str(load_value(key, \"\"))")
	load_text.return_type = TYPE_STRING
	sheet.functions.append(load_text)
	var has_key: EventFunction = _exposed_function("has_save_key", "Has Save Key", "Save System", "Whether the key exists in the active slot.", [["key", "String"]],
		"return _read_all().has(key)")
	has_key.return_type = TYPE_BOOL
	sheet.functions.append(has_key)
	_append_function(sheet, "delete_slot", "Delete Slot", "Save System", "Removes the active slot's save file.",
		[],
		"if FileAccess.file_exists(_slot_path()):\n\tDirAccess.remove_absolute(_slot_path())")
	# Lifecycle orchestration: other sheets contribute state via On Before Save.
	_append_function(sheet, "save_game", "Save Game", "Save System", "Broadcasts On Before Save (every sheet writes its state), then On Save Written.",
		[],
		"before_save.emit(slot)\nsave_written.emit(slot)")
	_append_function(sheet, "load_game", "Load Game", "Save System", "Broadcasts On After Load — every sheet reads its state back.",
		[],
		"after_load.emit(slot)")
	# Slot metadata (save/load menus).
	var slot_exists: EventFunction = _exposed_function("slot_exists", "Slot Exists", "Save System", "Whether the slot has a save file.", [["slot_index", "int"]],
		"return FileAccess.file_exists(_slot_path(slot_index))")
	slot_exists.return_type = TYPE_BOOL
	sheet.functions.append(slot_exists)
	var list_slots: EventFunction = _exposed_function("list_slots", "List Slots", "Save System", "Slot numbers that have save files (for menus).", [],
		"\n".join(PackedStringArray([
			"var found: Array = []",
			"for candidate: int in range(100):",
			"\tif FileAccess.file_exists(_slot_path(candidate)):",
			"\t\tfound.append(candidate)",
			"return found"
		])))
	list_slots.return_type = TYPE_ARRAY
	sheet.functions.append(list_slots)
	var slot_time: EventFunction = _exposed_function("slot_modified_time", "Slot Modified Time", "Save System", "Unix mtime of the slot's file (0 when missing).", [["slot_index", "int"]],
		"return FileAccess.get_modified_time(_slot_path(slot_index)) if FileAccess.file_exists(_slot_path(slot_index)) else 0")
	slot_time.return_type = TYPE_INT
	sheet.functions.append(slot_time)
	return _save_pack(sheet, "res://eventsheet_addons/save_system/save_system_addon")

## _append_function, but returning the function for return-type tweaks.
func _exposed_function(function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> EventFunction:
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = function_name
	event_function.expose_as_ace = true
	event_function.ace_display_name = display_name
	event_function.ace_category = category
	event_function.description = description
	for param_pair: Array in params:
		var parameter: ACEParam = ACEParam.new()
		parameter.id = str(param_pair[0])
		parameter.type_name = str(param_pair[1])
		event_function.params.append(parameter)
	var body_row: RawCodeRow = RawCodeRow.new()
	body_row.code = body
	event_function.events.append(body_row)
	return event_function
