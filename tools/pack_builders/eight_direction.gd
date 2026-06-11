# Pack builder — eight_direction (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

static func build() -> bool:
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

	return Lib.save_pack(sheet, "res://eventsheet_addons/eight_direction/eight_direction_movement_behavior")
