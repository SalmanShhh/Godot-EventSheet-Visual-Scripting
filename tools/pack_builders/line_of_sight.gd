# Pack builder - line_of_sight (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Line of Sight behavior (event-sheet parity)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "LOSBehavior"
	sheet.addon_category = "Line Of Sight"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"sight_range": {"type": "float", "default": 400.0, "exported": true, "description": "Maximum distance the node can see - targets farther away are never visible."},
		"cone_of_view_degrees": {"type": "float", "default": 360.0, "exported": true, "description": "Field of view angle in degrees centered on the node's facing - 360 sees all around."},
		"collision_mask": {"type": "int", "default": 1, "exported": true, "description": "Physics layers the sight raycast tests against - matching bodies block the view."}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Line of Sight behavior (event-sheet parity): raycast LOS with range and an optional cone of view (degrees; 360 = all around). Conditions: Has Line Of Sight To, Has LOS Between positions."
	sheet.events.append(about)
	var extra_block_0: RawCodeRow = RawCodeRow.new()
	extra_block_0.code = "\n".join(PackedStringArray([
		"## @ace_condition",
		"## @ace_name(\"Has Line Of Sight To\")",
		"func has_los_to(point: Vector2) -> bool:",
		"\tif host == null or host.global_position.distance_to(point) > sight_range:",
		"\t\treturn false",
		"\tif cone_of_view_degrees < 360.0:",
		"\t\tvar to_target := (point - host.global_position).angle()",
		"\t\tif absf(angle_difference(host.rotation, to_target)) > deg_to_rad(cone_of_view_degrees) * 0.5:",
		"\t\t\treturn false",
		"\treturn has_los_between(host.global_position, point)",
		"",
		"## @ace_condition",
		"## @ace_name(\"Has LOS Between\")",
		"func has_los_between(from_point: Vector2, to_point: Vector2) -> bool:",
		"\tif host == null:",
		"\t\treturn false",
		"\tvar query := PhysicsRayQueryParameters2D.create(from_point, to_point)",
		"\tquery.collision_mask = collision_mask",
		"\treturn host.get_world_2d().direct_space_state.intersect_ray(query).is_empty()",
		"",
		"## @ace_expression",
		"## @ace_name(\"Nearest Visible In Group\")",
		"## The closest group member this node can actually SEE (range + cone + raycast) - scans every",
		"## candidate and skips occluded ones, so a nearer-but-blocked enemy can't shadow a visible farther",
		"## one. Returns null if none are visible. The targeting primitive for auto-attack AI.",
		"func nearest_visible_in_group(group: String) -> Node2D:",
		"\tvar best: Node2D = null",
		"\tfor n: Node in get_tree().get_nodes_in_group(group):",
		"\t\tvar candidate: Node2D = n as Node2D",
		"\t\tif candidate == null or candidate == host:",
		"\t\t\tcontinue",
		"\t\tif not has_los_to(candidate.global_position):",
		"\t\t\tcontinue",
		"\t\tif best == null or host.global_position.distance_to(candidate.global_position) < host.global_position.distance_to(best.global_position):",
		"\t\t\tbest = candidate",
		"\treturn best"
	]))
	sheet.events.append(extra_block_0)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"pass"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	return Lib.save_pack(sheet, "res://eventsheet_addons/line_of_sight/line_of_sight_behavior")
