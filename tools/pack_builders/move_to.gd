# Pack builder — move_to (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## Move To behavior (C3 parity)
static func build() -> bool:
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

	return Lib.save_pack(sheet, "res://eventsheet_addons/move_to/move_to_behavior")
