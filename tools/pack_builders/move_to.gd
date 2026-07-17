# Pack builder - move_to (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Move To behavior (event-sheet parity), authored entirely as ACE rows (ZERO RawCode): glides through a
## waypoint queue and fires On Arrived at the final stop. The per-step position math
## (move_toward / angle / distance_to) lives in ACE expression params - the visual event-sheet model - so there is
## no GDScript block.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "MoveToBehavior"
	sheet.class_description = "Glides the host Node2D to a point at a steady speed, walks queued waypoints in order, and fires On Arrived at the last stop. Smooth point-to-point movement for enemies, pickups, and cursor tokens without writing tween code."
	sheet.addon_category = "Move To"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"max_speed": {"type": "float", "default": 200.0, "exported": true, "description": "Pixels per second the host glides toward its target."},
		"rotate_toward_motion": {"type": "bool", "default": false, "exported": true, "description": "When on, the host faces its direction of travel."},
		"waypoints": {"type": "Array", "default": [], "exported": false},
		"moving": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Move To behavior (event-sheet parity): glides through a waypoint queue (Move To Position replaces it, Add Waypoint appends) and fires On Arrived at the final stop. rotate_toward_motion faces the travel direction."
	sheet.events.append(about)

	var arrived_signal: SignalRow = SignalRow.new()
	arrived_signal.signal_name = "arrived"
	arrived_signal.trigger = true
	arrived_signal.ace_name = "On Arrived"
	arrived_signal.ace_category = "Move To"
	sheet.events.append(arrived_signal)

	# On Process: while moving with a live host and queued waypoints, glide toward the head waypoint;
	# pop it on arrival and fire On Arrived when the queue empties.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	tick.conditions.append(_cond("ExpressionIsTrue", {"expr": "moving"}))
	tick.conditions.append(_cond("IsValid", {"target": "host"}))
	tick.conditions.append(_cond("ExpressionIsTrue", {"expr": "not waypoints.is_empty()"}))
	tick.actions.append(_action("SetLocalVarTyped", {"name": "target", "var_type": "Vector2", "value": "waypoints[0]"}))
	tick.actions.append(_action("SetLocalVarTyped", {"name": "previous", "var_type": "Vector2", "value": "host.position"}))
	tick.actions.append(_action("SetProperty", {"target": "host", "property": "position", "value": "host.position.move_toward(target, max_speed * delta)"}))

	var rotate: EventRow = EventRow.new()
	rotate.conditions.append(_cond("ExpressionIsTrue", {"expr": "rotate_toward_motion and host.position != previous"}))
	rotate.actions.append(_action("SetProperty", {"target": "host", "property": "rotation", "value": "(host.position - previous).angle()"}))
	tick.sub_events.append(rotate)

	var reached: EventRow = EventRow.new()
	reached.conditions.append(_cond("ExpressionIsTrue", {"expr": "host.position.distance_to(target) < 0.5"}))
	reached.actions.append(_action("CallMethod", {"target": "waypoints", "method": "pop_front", "args": ""}))
	var finished: EventRow = EventRow.new()
	finished.conditions.append(_cond("ExpressionIsTrue", {"expr": "waypoints.is_empty()"}))
	finished.actions.append(_action("SetVar", {"var_name": "moving", "value": "false"}))
	finished.actions.append(_action("EmitSignal", {"signal_name": "arrived", "args": ""}))
	reached.sub_events.append(finished)
	tick.sub_events.append(reached)
	sheet.events.append(tick)

	# Move To Position(x, y): replace the queue and glide toward the point.
	var move_to_position: EventFunction = _exposed("move_to_position", "Move To Position", "Replaces the queue and glides toward the point.", [["x", "float"], ["y", "float"]])
	var move_to_position_body: EventRow = EventRow.new()
	move_to_position_body.actions.append(_action("SetVar", {"var_name": "waypoints", "value": "[Vector2(x, y)]"}))
	move_to_position_body.actions.append(_action("SetVar", {"var_name": "moving", "value": "true"}))
	move_to_position.events.append(move_to_position_body)
	sheet.functions.append(move_to_position)

	# Add Waypoint(x, y): append a stop to the queue (waypoints).
	var add_waypoint: EventFunction = _exposed("add_waypoint", "Add Waypoint", "Appends a stop to the queue (waypoints).", [["x", "float"], ["y", "float"]])
	var add_waypoint_body: EventRow = EventRow.new()
	add_waypoint_body.actions.append(_action("CallMethod", {"target": "waypoints", "method": "append", "args": "Vector2(x, y)"}))
	add_waypoint_body.actions.append(_action("SetVar", {"var_name": "moving", "value": "true"}))
	add_waypoint.events.append(add_waypoint_body)
	sheet.functions.append(add_waypoint)

	# Stop Moving(): clear the queue without firing On Arrived.
	var stop_moving: EventFunction = _exposed("stop_moving", "Stop Moving", "Clears the queue without firing On Arrived.", [])
	var stop_moving_body: EventRow = EventRow.new()
	stop_moving_body.actions.append(_action("SetVar", {"var_name": "moving", "value": "false"}))
	stop_moving_body.actions.append(_action("SetVar", {"var_name": "waypoints", "value": "[]"}))
	stop_moving.events.append(stop_moving_body)
	sheet.functions.append(stop_moving)

	return Lib.save_pack(sheet, "res://eventsheet_addons/move_to/move_to_behavior")


static func _exposed(fn_name: String, display: String, desc: String, params: Array) -> EventFunction:
	var fn: EventFunction = EventFunction.new()
	fn.function_name = fn_name
	fn.expose_as_ace = true
	fn.ace_display_name = display
	fn.ace_category = "Move To"
	fn.description = desc
	for pair: Array in params:
		fn.params.append(_param(str(pair[0]), str(pair[1])))
	return fn


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
