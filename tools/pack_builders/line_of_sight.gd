# Pack builder — line_of_sight (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## Line of Sight behavior (C3 parity)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "LOSBehavior"
	sheet.variables = {
		"sight_range": {"type": "float", "default": 400.0, "exported": true},
		"cone_of_view_degrees": {"type": "float", "default": 360.0, "exported": true},
		"collision_mask": {"type": "int", "default": 1, "exported": true}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Line of Sight behavior (C3 parity): raycast LOS with range and an optional cone of view (degrees; 360 = all around). Conditions: Has Line Of Sight To, Has LOS Between positions."
	sheet.events.append(about)
	var extra_block_0: RawCodeRow = RawCodeRow.new()
	extra_block_0.code = "\n".join(PackedStringArray([
		"## @ace_condition",
		"## @ace_name(\"Has Line Of Sight To\")",
		"## @ace_category(\"Line Of Sight\")",
		"## @ace_codegen_template(\"$LOSBehavior.has_los_to({point})\")",
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
		"## @ace_category(\"Line Of Sight\")",
		"## @ace_codegen_template(\"$LOSBehavior.has_los_between({from_point}, {to_point})\")",
		"func has_los_between(from_point: Vector2, to_point: Vector2) -> bool:",
		"\tif host == null:",
		"\t\treturn false",
		"\tvar query := PhysicsRayQueryParameters2D.create(from_point, to_point)",
		"\tquery.collision_mask = collision_mask",
		"\treturn host.get_world_2d().direct_space_state.intersect_ray(query).is_empty()"
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
