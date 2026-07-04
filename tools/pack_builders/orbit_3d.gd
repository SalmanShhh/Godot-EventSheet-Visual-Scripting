# Pack builder - orbit_3d (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Orbit 3D behavior (event-sheet-style)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "Orbit3DBehavior"
	sheet.addon_category = "Orbit 3D"
	sheet.variables = {
		"radius": {"type": "float", "default": 3.0, "exported": true},
		"speed_degrees": {"type": "float", "default": 90.0, "exported": true},
		"angle": {"type": "float", "default": 0.0, "exported": false},
		"center_x": {"type": "float", "default": 0.0, "exported": false},
		"center_y": {"type": "float", "default": 0.0, "exported": false},
		"center_z": {"type": "float", "default": 0.0, "exported": false},
		"center_captured": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Orbit 3D behavior (event-sheet-style): circles the host around its starting point in the XZ plane (Y stays)."
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
		"\tcenter_z = host.position.z",
		"\tcenter_captured = true",
		"angle += deg_to_rad(speed_degrees) * delta",
		"host.position = Vector3(center_x + cos(angle) * radius, center_y, center_z + sin(angle) * radius)"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var set_orbit3d_center_fn: EventFunction = EventFunction.new()
	set_orbit3d_center_fn.function_name = "set_orbit3d_center"
	set_orbit3d_center_fn.expose_as_ace = true
	set_orbit3d_center_fn.ace_display_name = "Set Orbit 3D Center"
	set_orbit3d_center_fn.ace_category = "Orbit 3D"
	set_orbit3d_center_fn.description = "Orbits around the given point from now on."
	var set_orbit3d_center_fn_x: ACEParam = ACEParam.new()
	set_orbit3d_center_fn_x.id = "x"
	set_orbit3d_center_fn_x.type_name = "float"
	set_orbit3d_center_fn.params.append(set_orbit3d_center_fn_x)
	var set_orbit3d_center_fn_y: ACEParam = ACEParam.new()
	set_orbit3d_center_fn_y.id = "y"
	set_orbit3d_center_fn_y.type_name = "float"
	set_orbit3d_center_fn.params.append(set_orbit3d_center_fn_y)
	var set_orbit3d_center_fn_z: ACEParam = ACEParam.new()
	set_orbit3d_center_fn_z.id = "z"
	set_orbit3d_center_fn_z.type_name = "float"
	set_orbit3d_center_fn.params.append(set_orbit3d_center_fn_z)
	var set_orbit3d_center_fn_body: RawCodeRow = RawCodeRow.new()
	set_orbit3d_center_fn_body.code = "\n".join(PackedStringArray([
		"center_x = x",
		"center_y = y",
		"center_z = z",
		"center_captured = true"
	]))
	set_orbit3d_center_fn.events.append(set_orbit3d_center_fn_body)
	sheet.functions.append(set_orbit3d_center_fn)

	return Lib.save_pack(sheet, "res://eventsheet_addons/orbit_3d/orbit_3d_behavior")
