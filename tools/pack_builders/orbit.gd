# Pack builder — orbit (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## Orbit behavior (C3 parity)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "OrbitBehavior"
	sheet.variables = {
		"primary_radius": {"type": "float", "default": 100.0, "exported": true},
		"secondary_radius": {"type": "float", "default": 0.0, "exported": true},
		"speed_degrees": {"type": "float", "default": 90.0, "exported": true},
		"offset_angle_degrees": {"type": "float", "default": 0.0, "exported": true},
		"match_rotation": {"type": "bool", "default": false, "exported": true},
		"angle": {"type": "float", "default": 0.0, "exported": false},
		"total_rotation": {"type": "float", "default": 0.0, "exported": false},
		"center_x": {"type": "float", "default": 0.0, "exported": false},
		"center_y": {"type": "float", "default": 0.0, "exported": false},
		"center_captured": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Orbit behavior (C3 parity): circles or ellipses around a point. secondary_radius 0 = circle; offset_angle tilts the ellipse; match_rotation faces the travel direction."
	sheet.events.append(about)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"if not center_captured:",
		"\tcenter_x = host.position.x",
		"\tcenter_y = host.position.y",
		"\tcenter_captured = true",
		"var step := deg_to_rad(speed_degrees) * delta",
		"angle += step",
		"total_rotation += absf(step)",
		"var radius_b := secondary_radius if secondary_radius > 0.0 else primary_radius",
		"var local := Vector2(cos(angle) * primary_radius, sin(angle) * radius_b).rotated(deg_to_rad(offset_angle_degrees))",
		"var previous := host.position",
		"host.position = Vector2(center_x, center_y) + local",
		"if match_rotation and host.position != previous:",
		"\thost.rotation = (host.position - previous).angle()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var set_orbit_center_fn: EventFunction = EventFunction.new()
	set_orbit_center_fn.function_name = "set_orbit_center"
	set_orbit_center_fn.expose_as_ace = true
	set_orbit_center_fn.ace_display_name = "Set Orbit Center"
	set_orbit_center_fn.ace_category = "Orbit"
	set_orbit_center_fn.description = "Orbits around the given point from now on."
	var set_orbit_center_fn_x: ACEParam = ACEParam.new()
	set_orbit_center_fn_x.id = "x"
	set_orbit_center_fn_x.type_name = "float"
	set_orbit_center_fn.params.append(set_orbit_center_fn_x)
	var set_orbit_center_fn_y: ACEParam = ACEParam.new()
	set_orbit_center_fn_y.id = "y"
	set_orbit_center_fn_y.type_name = "float"
	set_orbit_center_fn.params.append(set_orbit_center_fn_y)
	var set_orbit_center_fn_body: RawCodeRow = RawCodeRow.new()
	set_orbit_center_fn_body.code = "\n".join(PackedStringArray([
		"center_x = x",
		"center_y = y",
		"center_captured = true"
	]))
	set_orbit_center_fn.events.append(set_orbit_center_fn_body)
	sheet.functions.append(set_orbit_center_fn)

	var set_orbit_speed_fn: EventFunction = EventFunction.new()
	set_orbit_speed_fn.function_name = "set_orbit_speed"
	set_orbit_speed_fn.expose_as_ace = true
	set_orbit_speed_fn.ace_display_name = "Set Orbit Speed"
	set_orbit_speed_fn.ace_category = "Orbit"
	set_orbit_speed_fn.description = "Degrees per second (negative reverses)."
	var set_orbit_speed_fn_degrees_per_second: ACEParam = ACEParam.new()
	set_orbit_speed_fn_degrees_per_second.id = "degrees_per_second"
	set_orbit_speed_fn_degrees_per_second.type_name = "float"
	set_orbit_speed_fn.params.append(set_orbit_speed_fn_degrees_per_second)
	var set_orbit_speed_fn_body: RawCodeRow = RawCodeRow.new()
	set_orbit_speed_fn_body.code = "\n".join(PackedStringArray([
		"speed_degrees = degrees_per_second"
	]))
	set_orbit_speed_fn.events.append(set_orbit_speed_fn_body)
	sheet.functions.append(set_orbit_speed_fn)

	var set_orbit_radii_fn: EventFunction = EventFunction.new()
	set_orbit_radii_fn.function_name = "set_orbit_radii"
	set_orbit_radii_fn.expose_as_ace = true
	set_orbit_radii_fn.ace_display_name = "Set Orbit Radii"
	set_orbit_radii_fn.ace_category = "Orbit"
	set_orbit_radii_fn.description = "Primary/secondary radii (secondary 0 = circle)."
	var set_orbit_radii_fn_primary: ACEParam = ACEParam.new()
	set_orbit_radii_fn_primary.id = "primary"
	set_orbit_radii_fn_primary.type_name = "float"
	set_orbit_radii_fn.params.append(set_orbit_radii_fn_primary)
	var set_orbit_radii_fn_secondary: ACEParam = ACEParam.new()
	set_orbit_radii_fn_secondary.id = "secondary"
	set_orbit_radii_fn_secondary.type_name = "float"
	set_orbit_radii_fn.params.append(set_orbit_radii_fn_secondary)
	var set_orbit_radii_fn_body: RawCodeRow = RawCodeRow.new()
	set_orbit_radii_fn_body.code = "\n".join(PackedStringArray([
		"primary_radius = primary",
		"secondary_radius = secondary"
	]))
	set_orbit_radii_fn.events.append(set_orbit_radii_fn_body)
	sheet.functions.append(set_orbit_radii_fn)

	return Lib.save_pack(sheet, "res://eventsheet_addons/orbit/orbit_behavior")
