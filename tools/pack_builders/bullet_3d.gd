# Pack builder — bullet_3d (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## Bullet 3D behavior (C3-style)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "Bullet3DBehavior"
	sheet.variables = {
		"speed": {"type": "float", "default": 10.0, "exported": true},
		"gravity": {"type": "float", "default": 0.0, "exported": true},
		"distance_travelled": {"type": "float", "default": 0.0, "exported": false},
		"vel_x": {"type": "float", "default": 0.0, "exported": false},
		"vel_y": {"type": "float", "default": 0.0, "exported": false},
		"vel_z": {"type": "float", "default": 0.0, "exported": false},
		"launched": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Bullet 3D behavior (C3-style): launches along the host's forward (-Z) with speed and gravity; tracks distance travelled."
	sheet.events.append(about)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"if not launched:",
		"\tlaunch_forward()",
		"vel_y -= gravity * delta",
		"var motion := Vector3(vel_x, vel_y, vel_z) * delta",
		"host.position += motion",
		"distance_travelled += motion.length()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var launch_forward_fn: EventFunction = EventFunction.new()
	launch_forward_fn.function_name = "launch_forward"
	launch_forward_fn.expose_as_ace = true
	launch_forward_fn.ace_display_name = "Launch Forward"
	launch_forward_fn.ace_category = "Bullet 3D"
	launch_forward_fn.description = "(Re)launches along the host's current forward direction."
	var launch_forward_fn_body: RawCodeRow = RawCodeRow.new()
	launch_forward_fn_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"var forward := -host.global_transform.basis.z * speed",
		"vel_x = forward.x",
		"vel_y = forward.y",
		"vel_z = forward.z",
		"launched = true"
	]))
	launch_forward_fn.events.append(launch_forward_fn_body)
	sheet.functions.append(launch_forward_fn)

	var set_bullet3d_speed_fn: EventFunction = EventFunction.new()
	set_bullet3d_speed_fn.function_name = "set_bullet3d_speed"
	set_bullet3d_speed_fn.expose_as_ace = true
	set_bullet3d_speed_fn.ace_display_name = "Set Bullet 3D Speed"
	set_bullet3d_speed_fn.ace_category = "Bullet 3D"
	set_bullet3d_speed_fn.description = "Changes speed, keeping the current direction."
	var set_bullet3d_speed_fn_value: ACEParam = ACEParam.new()
	set_bullet3d_speed_fn_value.id = "value"
	set_bullet3d_speed_fn_value.type_name = "float"
	set_bullet3d_speed_fn.params.append(set_bullet3d_speed_fn_value)
	var set_bullet3d_speed_fn_body: RawCodeRow = RawCodeRow.new()
	set_bullet3d_speed_fn_body.code = "\n".join(PackedStringArray([
		"speed = value",
		"var direction := Vector3(vel_x, vel_y, vel_z).normalized()",
		"if direction == Vector3.ZERO and host != null:",
		"\tdirection = -host.global_transform.basis.z",
		"vel_x = direction.x * value",
		"vel_y = direction.y * value",
		"vel_z = direction.z * value",
		"launched = true"
	]))
	set_bullet3d_speed_fn.events.append(set_bullet3d_speed_fn_body)
	sheet.functions.append(set_bullet3d_speed_fn)

	return Lib.save_pack(sheet, "res://eventsheet_addons/bullet_3d/bullet_3d_behavior")
