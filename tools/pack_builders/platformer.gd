# Pack builder — platformer (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

static func build() -> bool:
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

	return Lib.save_pack(sheet, "res://eventsheet_addons/platformer_movement/platformer_movement_behavior")
