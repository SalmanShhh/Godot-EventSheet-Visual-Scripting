# Pack builder - eight_direction (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Top-down 8-direction movement, authored entirely as ACE rows (ZERO RawCode) - the new behaviour
## physics vocabulary in action: a typed input-vector local, Set Velocity, and Move And Slide, all
## host-targeted via {host.}. The movement behaviour the user asked to be code-free.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "EightDirectionMovement"
	sheet.class_description = "Top-down eight-way movement with nothing to wire: attach under a CharacterBody2D and it reads the built-in ui_left/right/up/down actions every physics frame and moves the host. Arrow keys work the moment you press play; set, nudge, or read the move speed from the sheet."
	sheet.addon_category = "Eight Direction"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"move_speed": {"type": "float", "default": 200.0, "exported": true, "description": "Movement speed in pixels per second the host travels at full input."},
		"ai_controlled": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "AI drive: read ai_move_x/ai_move_y instead of the keyboard (the standard seam an AI driver flips on to steer)."}},
		"ai_move_x": {"type": "float", "default": 0.0, "exported": false},
		"ai_move_y": {"type": "float", "default": 0.0, "exported": false}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "Top-down 8-direction movement: attach under a CharacterBody2D; moves with the ui_* input actions. An AI can steer it through the standard drive seam: flip ai_controlled on and write ai_move_x/ai_move_y."
	sheet.events.append(about)

	# On Physics Process: read the input vector, drive velocity, and move - all as ACE rows.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	tick.conditions.append(_cond("IsValid", {"target": "host"}))
	tick.actions.append(_action("SetLocalVarTyped", {"name": "input_vector", "var_type": "Vector2", "value": "Vector2(ai_move_x, ai_move_y).limit_length(1.0) if ai_controlled else Input.get_vector(\"ui_left\", \"ui_right\", \"ui_up\", \"ui_down\")"}))
	tick.actions.append(_action("SetVelocity2D", {"vel": "input_vector * move_speed"}))
	tick.actions.append(_action("MoveAndSlide", {}))
	sheet.events.append(tick)

	# set_move_speed(speed): retune at runtime.
	var set_speed: EventFunction = EventFunction.new()
	set_speed.function_name = "set_move_speed"
	set_speed.expose_as_ace = true
	set_speed.ace_display_name = "Set Move Speed"
	set_speed.ace_category = "Eight Direction"
	set_speed.description = "Changes the movement speed."
	set_speed.params.append(_param("speed", "float"))
	var body: EventRow = EventRow.new()
	body.actions.append(_action("SetVar", {"var_name": "move_speed", "value": "speed"}))
	set_speed.events.append(body)
	sheet.functions.append(set_speed)

	return Lib.save_pack(sheet, "res://eventsheet_addons/eight_direction/eight_direction_movement_behavior")


## Built-in Core ACE rows; templates resolve from the registry at compile time (no baked template).
static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


static func _cond(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	return condition


static func _param(id: String, type_name: String) -> ACEParam:
	var param: ACEParam = ACEParam.new()
	param.id = id
	param.type_name = type_name
	return param
