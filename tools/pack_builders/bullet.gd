# Pack builder - bullet (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Bullet behavior (event-sheet parity)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "BulletBehavior"
	sheet.addon_category = "Bullet"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"speed": {"type": "float", "default": 300.0, "exported": true},
		"acceleration": {"type": "float", "default": 0.0, "exported": true},
		"gravity": {"type": "float", "default": 0.0, "exported": true},
		"align_rotation": {"type": "bool", "default": true, "exported": true},
		"enabled_movement": {"type": "bool", "default": true, "exported": true},
		"distance_travelled": {"type": "float", "default": 0.0, "exported": false},
		"vel_x": {"type": "float", "default": 0.0, "exported": false},
		"vel_y": {"type": "float", "default": 0.0, "exported": false},
		"launched": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Bullet behavior (event-sheet parity): angle-of-motion movement with acceleration and gravity; tracks distance travelled (read $BulletBehavior.distance_travelled)."
	sheet.events.append(about)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null or not enabled_movement:",
		"\treturn",
		"if not launched:",
		"\tvel_x = cos(host.rotation) * speed",
		"\tvel_y = sin(host.rotation) * speed",
		"\tlaunched = true",
		"var direction := Vector2(vel_x, vel_y).normalized()",
		"vel_x += direction.x * acceleration * delta",
		"vel_y += direction.y * acceleration * delta",
		"vel_y += gravity * delta",
		"var motion := Vector2(vel_x, vel_y) * delta",
		"host.position += motion",
		"distance_travelled += motion.length()",
		"if align_rotation and motion != Vector2.ZERO:",
		"\thost.rotation = motion.angle()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var set_bullet_speed_fn: EventFunction = EventFunction.new()
	set_bullet_speed_fn.function_name = "set_bullet_speed"
	set_bullet_speed_fn.expose_as_ace = true
	set_bullet_speed_fn.ace_display_name = "Set Bullet Speed"
	set_bullet_speed_fn.ace_category = "Bullet"
	set_bullet_speed_fn.description = "Changes speed, keeping the current direction."
	var set_bullet_speed_fn_value: ACEParam = ACEParam.new()
	set_bullet_speed_fn_value.id = "value"
	set_bullet_speed_fn_value.type_name = "float"
	set_bullet_speed_fn.params.append(set_bullet_speed_fn_value)
	var set_bullet_speed_fn_body: RawCodeRow = RawCodeRow.new()
	set_bullet_speed_fn_body.code = "\n".join(PackedStringArray([
		"speed = value",
		"var direction := Vector2(vel_x, vel_y).normalized()",
		"if direction == Vector2.ZERO and host != null:",
		"\tdirection = Vector2.from_angle(host.rotation)",
		"vel_x = direction.x * value",
		"vel_y = direction.y * value",
		"launched = true"
	]))
	set_bullet_speed_fn.events.append(set_bullet_speed_fn_body)
	sheet.functions.append(set_bullet_speed_fn)

	var set_angle_of_motion_fn: EventFunction = EventFunction.new()
	set_angle_of_motion_fn.function_name = "set_angle_of_motion"
	set_angle_of_motion_fn.expose_as_ace = true
	set_angle_of_motion_fn.ace_display_name = "Set Angle Of Motion"
	set_angle_of_motion_fn.ace_category = "Bullet"
	set_angle_of_motion_fn.description = "Redirects the bullet (degrees)."
	var set_angle_of_motion_fn_degrees: ACEParam = ACEParam.new()
	set_angle_of_motion_fn_degrees.id = "degrees"
	set_angle_of_motion_fn_degrees.type_name = "float"
	set_angle_of_motion_fn.params.append(set_angle_of_motion_fn_degrees)
	var set_angle_of_motion_fn_body: RawCodeRow = RawCodeRow.new()
	set_angle_of_motion_fn_body.code = "\n".join(PackedStringArray([
		"vel_x = cos(deg_to_rad(degrees)) * speed",
		"vel_y = sin(deg_to_rad(degrees)) * speed",
		"launched = true"
	]))
	set_angle_of_motion_fn.events.append(set_angle_of_motion_fn_body)
	sheet.functions.append(set_angle_of_motion_fn)

	var set_bullet_enabled_fn: EventFunction = EventFunction.new()
	set_bullet_enabled_fn.function_name = "set_bullet_enabled"
	set_bullet_enabled_fn.expose_as_ace = true
	set_bullet_enabled_fn.ace_display_name = "Set Bullet Enabled"
	set_bullet_enabled_fn.ace_category = "Bullet"
	set_bullet_enabled_fn.description = "Pauses or resumes the movement."
	var set_bullet_enabled_fn_is_enabled: ACEParam = ACEParam.new()
	set_bullet_enabled_fn_is_enabled.id = "is_enabled"
	set_bullet_enabled_fn_is_enabled.type_name = "bool"
	set_bullet_enabled_fn.params.append(set_bullet_enabled_fn_is_enabled)
	var set_bullet_enabled_fn_body: RawCodeRow = RawCodeRow.new()
	set_bullet_enabled_fn_body.code = "\n".join(PackedStringArray([
		"enabled_movement = is_enabled"
	]))
	set_bullet_enabled_fn.events.append(set_bullet_enabled_fn_body)
	sheet.functions.append(set_bullet_enabled_fn)

	return Lib.save_pack(sheet, "res://eventsheet_addons/bullet/bullet_behavior")
