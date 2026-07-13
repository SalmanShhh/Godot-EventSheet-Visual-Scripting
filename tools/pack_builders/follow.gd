# Pack builder - follow (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Follow behavior (event-sheet parity)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "FollowBehavior"
	sheet.addon_category = "Follow"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"target_path": {"type": "String", "default": "", "exported": true, "description": "Node path (relative to the host) of the node to follow; empty means idle."},
		"mode": {"type": "String", "default": "smooth", "exported": true, "options": ["smooth", "delayed"], "description": "smooth lerps toward the target each frame; delayed replays the target's past positions."},
		"follow_speed": {"type": "float", "default": 5.0, "exported": true, "description": "In smooth mode, how quickly the host chases the target each second (higher is snappier)."},
		"delay": {"type": "float", "default": 0.4, "exported": true, "description": "In delayed mode, how many seconds behind the target's recorded path the host trails."},
		"min_distance": {"type": "float", "default": 0.0, "exported": true, "description": "In smooth mode, stops and fires On Reached Target once within this many pixels of the target."},
		"following": {"type": "bool", "default": true, "exported": false},
		"history": {"type": "Array", "default": [], "exported": false},
		"clock": {"type": "float", "default": 0.0, "exported": false},
		"_reached": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Follow behavior (event-sheet parity): trails another node. mode smooth = lerp chase; mode delayed = replay the target's position history after a delay (the Follow behavior)."
	sheet.events.append(about)
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Reached Target\")",
		"signal reached_target"
	]))
	sheet.events.append(signal_block)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null or target_path == \"\":",
		"\treturn",
		"var target := host.get_node_or_null(NodePath(target_path))",
		"if not (target is Node2D):",
		"\treturn",
		"clock += delta",
		"history.append([clock, target.position])",
		"while history.size() > 2 and float(history[0][0]) < clock - delay - 1.0:",
		"\thistory.pop_front()",
		"if not following:",
		"\treturn",
		"if mode == \"delayed\":",
		"\tvar sample_time := clock - delay",
		"\tfor entry: Array in history:",
		"\t\tif float(entry[0]) >= sample_time:",
		"\t\t\thost.position = entry[1]",
		"\t\t\tbreak",
		"\treturn",
		"if host.position.distance_to(target.position) <= min_distance:",
		"\tif not _reached:",
		"\t\t_reached = true",
		"\t\treached_target.emit()",
		"\treturn",
		"_reached = false",
		"host.position = host.position.lerp(target.position, clampf(follow_speed * delta, 0.0, 1.0))"
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
		"following = true",
		"history = []"
	]))
	start_following_fn.events.append(start_following_fn_body)
	sheet.functions.append(start_following_fn)

	var stop_following_fn: EventFunction = EventFunction.new()
	stop_following_fn.function_name = "stop_following"
	stop_following_fn.expose_as_ace = true
	stop_following_fn.ace_display_name = "Stop Following"
	stop_following_fn.ace_category = "Follow"
	stop_following_fn.description = "Stops trailing the target."
	var stop_following_fn_body: RawCodeRow = RawCodeRow.new()
	stop_following_fn_body.code = "\n".join(PackedStringArray([
		"following = false"
	]))
	stop_following_fn.events.append(stop_following_fn_body)
	sheet.functions.append(stop_following_fn)

	return Lib.save_pack(sheet, "res://eventsheet_addons/follow/follow_behavior")
