# Pack builder - follow (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Follow behavior (event-sheet parity)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "FollowBehavior"
	sheet.class_description = "Makes the host Node2D trail another node every frame, either easing smoothly toward it or replaying its path with a delay. Built for pets, homing shots, camera dummies, and snake tails without hand-writing lerp code on every object."
	sheet.addon_category = "Follow"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"target_path": {"type": "String", "default": "", "exported": true, "description": "Node path (relative to the host) of the node to follow; empty means idle."},
		"target_group": {"type": "String", "default": "", "exported": true, "description": "Follow the first node in this GROUP instead of a path - no tree path, so it survives the target being moved or renamed. Takes priority over Target Path; leave blank to use the path."},
		"mode": {"type": "String", "default": "smooth", "exported": true, "options": ["smooth", "delayed"], "description": "smooth lerps toward the target each frame; delayed replays the target's past positions."},
		"follow_speed": {"type": "float", "default": 5.0, "exported": true, "description": "In smooth mode, how quickly the host chases the target each second (higher is snappier)."},
		"delay": {"type": "float", "default": 0.4, "exported": true, "description": "In delayed mode, how many seconds behind the target's recorded path the host trails."},
		"min_distance": {"type": "float", "default": 0.0, "exported": true, "description": "In smooth mode, stops and fires On Reached Target once within this many pixels of the target."},
		"stepping": {"type": "bool", "default": false, "exported": true, "description": "In SMOOTH mode, sweep the path each frame instead of lerping straight there, so a fast chase cannot pass through a thin wall between two frames. Delayed mode ignores it, since retracing the target's recorded path is the point of that mode."},
		"step_mask": {"type": "int", "default": 1, "exported": true, "description": "Collision layers the swept path tests against. Each layer is a bit, so layers 1 and 3 are 1 + 4 = 5."},
		"step_hits_areas": {"type": "bool", "default": false, "exported": true, "description": "Also stop the sweep on Area2D nodes, which it ignores by default."},
		"following": {"type": "bool", "default": true, "exported": false},
		"history": {"type": "Array", "default": [], "exported": false},
		"clock": {"type": "float", "default": 0.0, "exported": false},
		"_reached": {"type": "bool", "default": false, "exported": false},
		"_blocked": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Follow behavior (event-sheet parity): trails another node. mode smooth = lerp chase; mode delayed = replay the target's position history after a delay (the Follow behavior)."
	sheet.events.append(about)
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Reached Target\")",
		"signal reached_target",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Path Blocked\")",
		"## @ace_description(\"Fires when Stepping finds something between the host and where the chase was about to put it.\")",
		"signal path_blocked",
		"",
		"## The furthest point on the way to `to` that is actually reachable this frame.",
		"##",
		"## The smooth chase sets position outright, so a fast follow_speed can cross a thin wall entirely",
		"## between two frames and never touch it. With Stepping on, a swept ray finds what the chase",
		"## skipped and returns the contact point instead. Positions are in the parent's space, so the",
		"## sweep converts by offsetting the host's global position by the same delta.",
		"##",
		"## Delayed mode never calls this: replaying the target's recorded path exactly IS that mode.",
		"func step_toward(from: Vector2, to: Vector2) -> Vector2:",
		"\tif not stepping or from == to or host == null or not host.is_inside_tree():",
		"\t\treturn to",
		"\tvar world_from: Vector2 = host.global_position",
		"\tvar step_query := PhysicsRayQueryParameters2D.create(world_from, world_from + (to - from), step_mask, [])",
		"\tstep_query.collide_with_areas = step_hits_areas",
		"\tvar step_hit := host.get_world_2d().direct_space_state.intersect_ray(step_query)",
		"\tif step_hit.is_empty():",
		"\t\t_blocked = false",
		"\t\treturn to",
		"\t# EDGE-triggered, mirroring _reached above. A chase has no stop flag by design - it keeps",
		"\t# pressing at the wall - so emitting on every blocked frame would make the trigger useless.",
		"\tif not _blocked:",
		"\t\t_blocked = true",
		"\t\tpath_blocked.emit()",
		"\tvar contact: Vector2 = step_hit.get(\"position\", world_from)",
		"\t# Park just SHORT of the surface, never exactly on it: a ray that STARTS on a shape does not",
		"\t# report that shape (hit-from-inside is off), so a chaser left touching the wall sails straight",
		"\t# through on the next frame's sweep. Half a pixel of clearance keeps the next ray honest.",
		"\treturn from + (contact - (to - from).normalized() * 0.5 - world_from)"
	]))
	sheet.events.append(signal_block)
	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"# A chase has to watch its target every frame while it is on, so processing tracks the one",
		"# state that turns it off: Stop Following. A follow authored as stopped costs nothing until",
		"# Start Following or Follow Group.",
		"set_process(following)"
	]))
	ready_row.actions.append(ready_body)
	sheet.events.append(ready_row)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"	return",
		"# Resolve by GROUP first (no tree path, so it survives the target being moved or renamed),",
		"# otherwise fall back to the explicit path.",
		"var target: Node = null",
		"if target_group != \"\":",
		"	target = get_tree().get_first_node_in_group(target_group)",
		"elif target_path != \"\":",
		"	target = host.get_node_or_null(NodePath(target_path))",
		"if not (target is Node2D):",
		"	return",
		"var target_2d := target as Node2D",
		"clock += delta",
		"history.append([clock, target_2d.position])",
		"while history.size() > 2 and float(history[0][0]) < clock - delay - 1.0:",
		"	history.pop_front()",
		"if not following:",
		"	return",
		"if mode == \"delayed\":",
		"	var sample_time := clock - delay",
		"	for entry: Array in history:",
		"		if float(entry[0]) >= sample_time:",
		"			host.position = entry[1]",
		"			break",
		"	return",
		"if host.position.distance_to(target_2d.position) <= min_distance:",
		"	if not _reached:",
		"		_reached = true",
		"		reached_target.emit()",
		"	return",
		"_reached = false",
		"host.position = step_toward(host.position, host.position.lerp(target_2d.position, clampf(follow_speed * delta, 0.0, 1.0)))"
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
			"target_group = \"\"",
		"following = true",
		"history = []",
		"# The chase is on again, and a chase reads its target every frame - the recorded path",
		"# delayed mode replays is gathered by that same tick.",
		"set_process(true)"
	]))
	start_following_fn.events.append(start_following_fn_body)
	sheet.functions.append(start_following_fn)

	var follow_group_fn: EventFunction = EventFunction.new()
	follow_group_fn.function_name = "follow_group"
	follow_group_fn.expose_as_ace = true
	follow_group_fn.ace_display_name = "Follow Group"
	follow_group_fn.ace_category = "Follow"
	follow_group_fn.description = "Follows the first node in a group - no tree path, so it survives the target being moved or renamed."
	var follow_group_fn_group: ACEParam = ACEParam.new()
	follow_group_fn_group.id = "group"
	follow_group_fn_group.type_name = "String"
	follow_group_fn.params.append(follow_group_fn_group)
	var follow_group_fn_body: RawCodeRow = RawCodeRow.new()
	follow_group_fn_body.code = "
".join(PackedStringArray([
		"target_group = group",
		"target_path = \"\"",
		"following = true",
		"history = []",
		"# The chase is on again, and a chase reads its target every frame - the recorded path",
		"# delayed mode replays is gathered by that same tick.",
		"set_process(true)"
	]))
	follow_group_fn.events.append(follow_group_fn_body)
	sheet.functions.append(follow_group_fn)

	var stop_following_fn: EventFunction = EventFunction.new()
	stop_following_fn.function_name = "stop_following"
	stop_following_fn.expose_as_ace = true
	stop_following_fn.ace_display_name = "Stop Following"
	stop_following_fn.ace_category = "Follow"
	stop_following_fn.description = "Stops trailing the target."
	var stop_following_fn_body: RawCodeRow = RawCodeRow.new()
	stop_following_fn_body.code = "\n".join(PackedStringArray([
		"following = false",
		"# Nothing is being trailed any more, so the frame that watched the target is wasted work -",
		"# Start Following and Follow Group turn it back on, and both start a fresh history anyway.",
		"set_process(false)"
	]))
	stop_following_fn.events.append(stop_following_fn_body)
	sheet.functions.append(stop_following_fn)

	return Lib.save_pack(sheet, "res://eventsheet_addons/follow/follow_behavior")
