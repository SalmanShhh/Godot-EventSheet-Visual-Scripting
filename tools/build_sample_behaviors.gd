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
