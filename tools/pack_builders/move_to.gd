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
		"stepping": {"type": "bool", "default": false, "exported": true, "description": "Sweep the path each frame instead of gliding straight to the next point, so a fast mover cannot pass through a thin wall between two frames."},
		"step_mask": {"type": "int", "default": 1, "exported": true, "description": "Collision layers the swept path tests against. Each layer is a bit, so layers 1 and 3 are 1 + 4 = 5."},
		"step_hits_areas": {"type": "bool", "default": false, "exported": true, "description": "Also stop the sweep on Area2D nodes, which it ignores by default."},
		"stop_on_step_hit": {"type": "bool", "default": true, "exported": true, "description": "Drop the waypoint queue and stop when the path is blocked. Turn off to keep pushing at the obstacle and just report it."},
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

	var blocked_signal: SignalRow = SignalRow.new()
	blocked_signal.signal_name = "path_blocked"
	blocked_signal.trigger = true
	blocked_signal.ace_name = "On Path Blocked"
	blocked_signal.ace_category = "Move To"
	sheet.events.append(blocked_signal)

	# The sweep, as ACE ROWS like the rest of this pack - it carries a ZERO RawCode budget
	# (tests/pack_rawcode_budget_test.gd), which is the point of it: the whole behaviour, sweep
	# included, is expressible in the visual model. Off by default, in which case the first row
	# returns the destination untouched and nothing about the glide changes.
	var step_fn: EventFunction = EventFunction.new()
	step_fn.function_name = "step_toward"
	step_fn.description = "The furthest point on the way to `to` that is actually reachable this frame. Gliding sets position outright, so at speed the host can cross a thin wall entirely between two frames and never touch it; with Stepping on, a swept ray finds what the glide skipped."
	step_fn.return_type = TYPE_VECTOR2
	step_fn.params.append(_param("from", "Vector2"))
	step_fn.params.append(_param("to", "Vector2"))

	var step_off: EventRow = EventRow.new()
	step_off.conditions.append(_cond("ExpressionIsTrue", {"expr": "not stepping or from == to or host == null or not host.is_inside_tree()"}))
	step_off.actions.append(_action("ReturnValue", {"value": "to"}))
	step_fn.events.append(step_off)

	var step_cast: EventRow = EventRow.new()
	# Positions arrive in the PARENT's space; the sweep works in world space, so it offsets the host's
	# global position by the same delta rather than converting each point.
	step_cast.actions.append(_action("SetLocalVarTyped", {"name": "world_from", "var_type": "Vector2", "value": "host.global_position"}))
	step_cast.actions.append(_action("SetLocalVarInferred", {"name": "step_query", "value": "PhysicsRayQueryParameters2D.create(world_from, world_from + (to - from), step_mask, [])"}))
	step_cast.actions.append(_action("SetProperty", {"target": "step_query", "property": "collide_with_areas", "value": "step_hits_areas"}))
	step_cast.actions.append(_action("SetLocalVarInferred", {"name": "step_hit", "value": "host.get_world_2d().direct_space_state.intersect_ray(step_query)"}))
	step_fn.events.append(step_cast)

	var step_clear: EventRow = EventRow.new()
	step_clear.conditions.append(_cond("ExpressionIsTrue", {"expr": "step_hit.is_empty()"}))
	step_clear.actions.append(_action("ReturnValue", {"value": "to"}))
	step_fn.events.append(step_clear)

	var step_stop: EventRow = EventRow.new()
	step_stop.conditions.append(_cond("ExpressionIsTrue", {"expr": "stop_on_step_hit"}))
	step_stop.actions.append(_action("CallMethod", {"target": "waypoints", "method": "clear", "args": ""}))
	step_stop.actions.append(_action("SetVar", {"var_name": "moving", "value": "false"}))
	# A blocked path that drops its queue is stopped, so the tick has nothing left to do - stop
	# paying for it until a Move To Position or an Add Waypoint gives it somewhere to go.
	step_stop.actions.append(_action("CallMethod", {"target": "self", "method": "set_process", "args": "false"}))
	step_fn.events.append(step_stop)

	var step_report: EventRow = EventRow.new()
	step_report.actions.append(_action("EmitSignal", {"signal_name": "path_blocked", "args": ""}))
	# Park just SHORT of the surface, never exactly on it: a ray that STARTS on a shape does not report
	# that shape (hit-from-inside is off), so a host left touching the wall sails straight through on
	# the next frame's sweep. Half a pixel of clearance keeps the next ray honest.
	step_report.actions.append(_action("ReturnValue", {"value": "from + (step_hit.get(\"position\", world_from) - (to - from).normalized() * 0.5 - world_from)"}))
	step_fn.events.append(step_report)
	sheet.functions.append(step_fn)

	# On Ready: a host that has not been sent anywhere yet has nothing to glide toward, so the tick
	# starts off and every verb that gives it a destination turns it back on. `moving` is the state
	# the whole tick is gated on, so reading it here keeps the two in step with no second flag.
	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	ready_row.actions.append(_action("CallMethod", {"target": "self", "method": "set_process", "args": "moving"}))
	sheet.events.append(ready_row)

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
	tick.actions.append(_action("SetProperty", {"target": "host", "property": "position", "value": "step_toward(host.position, host.position.move_toward(target, max_speed * delta))"}))

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
	# The last stop is reached, so nothing is left to glide toward. Processing goes off BEFORE the
	# trigger fires, so a row that answers On Arrived with another Move To turns it straight back on.
	finished.actions.append(_action("CallMethod", {"target": "self", "method": "set_process", "args": "false"}))
	finished.actions.append(_action("EmitSignal", {"signal_name": "arrived", "args": ""}))
	reached.sub_events.append(finished)
	tick.sub_events.append(reached)
	sheet.events.append(tick)

	# Move To Position(x, y): replace the queue and glide toward the point.
	var move_to_position: EventFunction = _exposed("move_to_position", "Move To Position", "Replaces the queue and glides toward the point.", [["x", "float"], ["y", "float"]])
	var move_to_position_body: EventRow = EventRow.new()
	move_to_position_body.actions.append(_action("SetVar", {"var_name": "waypoints", "value": "[Vector2(x, y)]"}))
	move_to_position_body.actions.append(_action("SetVar", {"var_name": "moving", "value": "true"}))
	# There is somewhere to be again, so the per-frame glide is worth paying for.
	move_to_position_body.actions.append(_action("CallMethod", {"target": "self", "method": "set_process", "args": "true"}))
	move_to_position.events.append(move_to_position_body)
	sheet.functions.append(move_to_position)

	# Add Waypoint(x, y): append a stop to the queue (waypoints).
	var add_waypoint: EventFunction = _exposed("add_waypoint", "Add Waypoint", "Appends a stop to the queue (waypoints).", [["x", "float"], ["y", "float"]])
	var add_waypoint_body: EventRow = EventRow.new()
	add_waypoint_body.actions.append(_action("CallMethod", {"target": "waypoints", "method": "append", "args": "Vector2(x, y)"}))
	add_waypoint_body.actions.append(_action("SetVar", {"var_name": "moving", "value": "true"}))
	# A stop appended to an empty queue restarts the glide, so the tick has to come back on.
	add_waypoint_body.actions.append(_action("CallMethod", {"target": "self", "method": "set_process", "args": "true"}))
	add_waypoint.events.append(add_waypoint_body)
	sheet.functions.append(add_waypoint)

	# Stop Moving(): clear the queue without firing On Arrived.
	var stop_moving: EventFunction = _exposed("stop_moving", "Stop Moving", "Clears the queue without firing On Arrived.", [])
	var stop_moving_body: EventRow = EventRow.new()
	stop_moving_body.actions.append(_action("SetVar", {"var_name": "moving", "value": "false"}))
	stop_moving_body.actions.append(_action("SetVar", {"var_name": "waypoints", "value": "[]"}))
	# A stopped mover costs nothing per frame; Move To Position turns processing back on.
	stop_moving_body.actions.append(_action("CallMethod", {"target": "self", "method": "set_process", "args": "false"}))
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
