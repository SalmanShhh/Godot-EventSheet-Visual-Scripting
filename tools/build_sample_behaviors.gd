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
	print("[build_sample_behaviors] %s" % ("done" if ok else "FAILED"))
	quit(0 if ok else 1)

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
