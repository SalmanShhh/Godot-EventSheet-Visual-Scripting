# Pack builder - orbit (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Orbit behavior (event-sheet parity)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "OrbitBehavior"
	sheet.class_description = "Sweeps a Node2D around a center point every frame: attach to a moon, shield orb, or spinning hazard and it circles on a radius (or tilted ellipse) at a speed you can change live. The center is captured from wherever the node starts, and the node can face the direction it is travelling."
	sheet.addon_category = "Orbit"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"primary_radius": {"type": "float", "default": 100.0, "exported": true, "description": "Orbit radius on the primary axis, in pixels."},
		"secondary_radius": {"type": "float", "default": 0.0, "exported": true, "description": "Orbit radius on the second axis, in pixels; 0 makes a circle from primary_radius."},
		"speed_degrees": {"type": "float", "default": 90.0, "exported": true, "description": "Degrees per second traveled around the orbit; negative reverses direction."},
		"offset_angle_degrees": {"type": "float", "default": 0.0, "exported": true, "description": "Tilts the whole ellipse by this many degrees."},
		"match_rotation": {"type": "bool", "default": false, "exported": true, "description": "When on, the node rotates to face its direction of travel."},
		"angle": {"type": "float", "default": 0.0, "exported": false},
		"total_rotation": {"type": "float", "default": 0.0, "exported": false},
		"center_x": {"type": "float", "default": 0.0, "exported": false},
		"center_y": {"type": "float", "default": 0.0, "exported": false},
		"center_captured": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Orbit behavior (event-sheet parity): circles or ellipses around a point. secondary_radius 0 = circle; offset_angle tilts the ellipse; match_rotation faces the travel direction."
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
	var preview_block: RawCodeRow = RawCodeRow.new()
	preview_block.code = "\n".join(PackedStringArray([
		"# Editor-preview contract (Tools > Preview Behaviors on Selected Node): the tick's ellipse",
		"# solved for a time rather than accumulated - angle(t) = speed*t - so the editor can show the",
		"# ring without running the behavior or writing the saved position. Facing is sampled the same",
		"# way, from the tangent at t, so match_rotation looks right in the preview too.",
		"## @ace_hidden",
		"static func editor_preview_sample(params: Dictionary, base: Dictionary, time: float) -> Dictionary:",
		"\tvar rest: Variant = base.get(\"position\", null)",
		"\tif not rest is Vector2:",
		"\t\treturn {}",
		"\tvar centre: Vector2 = rest",
		"\tvar primary: float = float(params.get(\"primary_radius\", 100.0))",
		"\tvar secondary: float = float(params.get(\"secondary_radius\", 0.0))",
		"\tvar radius_b: float = secondary if secondary > 0.0 else primary",
		"\tvar tilt: float = deg_to_rad(float(params.get(\"offset_angle_degrees\", 0.0)))",
		"\tvar speed: float = deg_to_rad(float(params.get(\"speed_degrees\", 90.0)))",
		"\tvar angle: float = speed * time",
		"\tvar local: Vector2 = Vector2(cos(angle) * primary, sin(angle) * radius_b).rotated(tilt)",
		"\tvar out: Dictionary = {\"position\": centre + local}",
		"\tif bool(params.get(\"match_rotation\", false)):",
		"\t\tvar tangent: Vector2 = Vector2(-sin(angle) * primary, cos(angle) * radius_b).rotated(tilt)",
		"\t\tif tangent != Vector2.ZERO:",
		"\t\t\tout[\"rotation\"] = tangent.angle()",
		"\treturn out"
	]))
	sheet.events.append(preview_block)

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
