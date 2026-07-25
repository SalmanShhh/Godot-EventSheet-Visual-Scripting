# Pack builder - move_to_3d (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Move To 3D behavior (event-sheet-style)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "MoveTo3DBehavior"
	sheet.class_description = "Point-to-point movement for any Node3D: hand it Vector3 targets and it glides the host straight toward each one at a steady speed, popping waypoints off a queue and firing On Arrived at the last stop. Attach under a drone, elevator, pickup, or camera rig and tune the pace with the single max_speed knob."
	sheet.addon_category = "Move To 3D"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"max_speed": {"type": "float", "default": 5.0, "exported": true, "description": "Units per second the host glides toward each waypoint."},
		"stepping": {"type": "bool", "default": false, "exported": true, "description": "Sweep the path each frame instead of gliding straight to the next point, so a fast mover cannot pass through thin geometry between two frames."},
		"step_mask": {"type": "int", "default": 1, "exported": true, "description": "Collision layers the swept path tests against. Each layer is a bit, so layers 1 and 3 are 1 + 4 = 5."},
		"step_hits_areas": {"type": "bool", "default": false, "exported": true, "description": "Also stop the sweep on Area3D nodes, which it ignores by default."},
		"stop_on_step_hit": {"type": "bool", "default": true, "exported": true, "description": "Drop the waypoint queue and stop when the path is blocked. Turn off to keep pushing at the obstacle and just report it."},
		"waypoints": {"type": "Array", "default": [], "exported": false},
		"moving": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Move To 3D behavior (event-sheet-style): glides through a queue of Vector3 waypoints and fires On Arrived at the final stop."
	sheet.events.append(about)
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Arrived (3D)\")",
		"signal arrived",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Path Blocked (3D)\")",
		"## @ace_description(\"Fires when Stepping finds something between the host and where it was about to glide to.\")",
		"signal path_blocked",
		"",
		"## The furthest point on the way to `to` that is actually reachable this frame.",
		"##",
		"## Gliding sets position outright, so at speed the host can cross thin geometry entirely between",
		"## two frames and never touch it. With Stepping on, a swept ray finds what the glide skipped and",
		"## returns the contact point instead. Positions are in the parent's space, so the sweep converts",
		"## by offsetting the host's global position by the same delta.",
		"func step_toward(from: Vector3, to: Vector3) -> Vector3:",
		"\tif not stepping or from == to or host == null or not host.is_inside_tree():",
		"\t\treturn to",
		"\tvar world_from: Vector3 = host.global_position",
		"\tvar step_query := PhysicsRayQueryParameters3D.create(world_from, world_from + (to - from), step_mask, [])",
		"\tstep_query.collide_with_areas = step_hits_areas",
		"\tvar step_hit := host.get_world_3d().direct_space_state.intersect_ray(step_query)",
		"\tif step_hit.is_empty():",
		"\t\treturn to",
		"\tif stop_on_step_hit:",
		"\t\twaypoints.clear()",
		"\t\tmoving = false",
		"\tpath_blocked.emit()",
		"\tvar contact: Vector3 = step_hit.get(\"position\", world_from)",
		"\t# Park just SHORT of the surface, never exactly on it: a ray that STARTS on a shape does not",
		"\t# report that shape (hit-from-inside is off), so a host left touching the wall sails straight",
		"\t# through on the next frame's sweep. A centimetre of clearance keeps the next ray honest.",
		"\treturn from + (contact - (to - from).normalized() * 0.01 - world_from)"
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
		"host.position = step_toward(host.position, host.position.move_toward(target, max_speed * delta))",
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

	return Lib.save_pack(sheet, "res://eventsheet_addons/move_to_3d/move_to_3d_behavior")
