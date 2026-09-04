# Pack builder - bullet (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Bullet behavior (event-sheet parity)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "BulletBehavior"
	sheet.class_description = "Fire-and-forget projectile movement for a Node2D: the host launches in the direction it is facing and keeps flying every frame. Tune speed, acceleration, and gravity, redirect or pause it live, and read how far it has flown from plain event rows."
	sheet.addon_category = "Bullet"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"speed": {"type": "float", "default": 300.0, "exported": true, "description": "Travel speed in pixels per second."},
		"acceleration": {"type": "float", "default": 0.0, "exported": true, "description": "Change in speed per second along the direction of motion."},
		"gravity": {"type": "float", "default": 0.0, "exported": true, "description": "Downward pull added to vertical speed each second."},
		"gravity_angle": {"type": "float", "default": 90.0, "exported": true, "description": "Direction gravity pulls, in degrees (90 = down, 270 = up, 0 = right) - arcs bend that way instead of downward.", "attributes": {"range": {"min": "0", "max": "360", "step": "1"}}},
		"align_rotation": {"type": "bool", "default": true, "exported": true, "description": "Rotates the host to face its direction of motion."},
		"stepping": {"type": "bool", "default": false, "exported": true, "description": "Sweep the path each frame instead of jumping along it, so a fast bullet cannot pass through a thin wall between two frames."},
		"step_mask": {"type": "int", "default": 1, "exported": true, "description": "Collision layers the swept path tests against. Each layer is a bit, so layers 1 and 3 are 1 + 4 = 5."},
		"step_hits_areas": {"type": "bool", "default": false, "exported": true, "description": "Also stop the sweep on Area2D nodes, which it ignores by default."},
		"stop_on_step_hit": {"type": "bool", "default": true, "exported": true, "description": "Park the bullet at the point it struck and stop it. Turn off to keep flying and just report the hit."},
		"distance_travelled": {"type": "float", "default": 0.0, "exported": false},
		"vel_x": {"type": "float", "default": 0.0, "exported": false},
		"vel_y": {"type": "float", "default": 0.0, "exported": false},
		"launched": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Bullet behavior (event-sheet parity): angle-of-motion movement with acceleration and gravity; tracks distance travelled (read $BulletBehavior.distance_travelled)."
	sheet.events.append(about)

	# The freeze switch, written here rather than through the variables dict so it can carry a
	# setter (the variables dict has no spelling for one).
	var enabled_block: RawCodeRow = RawCodeRow.new()
	enabled_block.code = "\n".join(PackedStringArray([
		"## When off, the bullet stops moving.",
		"@export var enabled_movement: bool = true:",
		"\tset(value):",
		"\t\tenabled_movement = value",
		"\t\t# Every write lands here - Set Bullet Enabled, the reflected Set Enabled Movement action,",
		"\t\t# the Inspector, another script - so the tick follows the switch whoever flipped it. A",
		"\t\t# frozen bullet costs nothing per frame.",
		"\t\tset_process(value)"
	]))
	sheet.events.append(enabled_block)

	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\t# Nothing to move means no frame will ever have work; stop paying for the tick at all.",
		"\tset_process(false)",
		"\treturn",
		"# The tick runs only while the bullet is actually flying - a shot authored frozen, or one",
		"# parked by a stepping hit, costs nothing per frame until Set Bullet Enabled starts it again.",
		"set_process(enabled_movement)"
	]))
	ready_row.actions.append(ready_body)
	sheet.events.append(ready_row)

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
		"# Gravity pulls along gravity_angle; built from Vector2.DOWN.rotated so the default",
		"# 90 degrees is EXACTLY (0, 1) - the plain vel_y pull this generalizes, bit for bit.",
		"var gravity_pull := Vector2.DOWN.rotated(deg_to_rad(gravity_angle - 90.0)) * gravity * delta",
		"vel_x += gravity_pull.x",
		"vel_y += gravity_pull.y",
		"var motion := Vector2(vel_x, vel_y) * delta",
		"# STEPPING: at 3000 px/s a bullet covers 50px in a frame, so a 20px wall can sit entirely",
		"# between where it was and where it lands and never be touched. Sweeping the frame's motion",
		"# finds what a teleport skipped. Off by default - the two lines below are the original path.",
		"if stepping and motion != Vector2.ZERO and host.is_inside_tree():",
		"	var step_from := host.global_position",
		"	var step_query := PhysicsRayQueryParameters2D.create(step_from, step_from + motion, step_mask, [])",
		"	step_query.collide_with_areas = step_hits_areas",
		"	var step_hit := host.get_world_2d().direct_space_state.intersect_ray(step_query)",
		"	if not step_hit.is_empty():",
		"		# Park just SHORT of the surface: a ray that STARTS on a shape does not report it, so a",
		"		# bullet left exactly touching the wall would sail through if it were ever restarted.",
		"		host.global_position = step_hit.get(\"position\", step_from) - motion.normalized() * 0.5",
		"		distance_travelled += step_from.distance_to(host.global_position)",
		"		if align_rotation:",
		"			host.rotation = motion.angle()",
		"		if stop_on_step_hit:",
		"			enabled_movement = false",
		"			# A parked bullet is finished flying - stop paying for a tick that would only",
		"			# early-return, until Set Bullet Enabled sends it on its way again.",
		"			set_process(false)",
		"		on_bullet_hit.emit(step_hit.get(\"collider\"), step_hit.get(\"position\", step_from), step_hit.get(\"normal\", Vector2.ZERO))",
		"		return",
		"host.position += motion",
		"distance_travelled += motion.length()",
		"if align_rotation and motion != Vector2.ZERO:",
		"\thost.rotation = motion.angle()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# The trigger Stepping fires. Declared with its arguments so a sheet row receives what was hit,
	# where, and which way that surface faces - everything an impact effect needs.
	var signals_block: RawCodeRow = RawCodeRow.new()
	signals_block.code = "
".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Bullet Hit\")",
		"## @ace_description(\"Fires when Stepping catches something in the bullet's path this frame. Hands back what was hit, the exact point, and the surface normal.\")",
		"signal on_bullet_hit(collider: Object, point: Vector2, normal: Vector2)"
	]))
	sheet.events.append(signals_block)

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
		"launched = true",
		"# Re-aiming a bullet re-syncs the tick to whether it is moving, so a shot re-enabled",
		"# through its Inspector flag rather than through Set Bullet Enabled still flies.",
		"set_process(enabled_movement)"
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
		"launched = true",
		"# Re-aiming a bullet re-syncs the tick to whether it is moving, so a shot re-enabled",
		"# through its Inspector flag rather than through Set Bullet Enabled still flies.",
		"set_process(enabled_movement)"
	]))
	set_angle_of_motion_fn.events.append(set_angle_of_motion_fn_body)
	sheet.functions.append(set_angle_of_motion_fn)

	var set_gravity_angle_fn: EventFunction = EventFunction.new()
	set_gravity_angle_fn.function_name = "set_gravity_angle"
	set_gravity_angle_fn.expose_as_ace = true
	set_gravity_angle_fn.ace_display_name = "Set Gravity Angle"
	set_gravity_angle_fn.ace_category = "Bullet"
	set_gravity_angle_fn.description = "Points gravity in a new direction, in degrees (90 = down, 270 = up, 0 = right) - the arc bends that way from now on. Magnet fields, wind wells, and upside-down zones in one action."
	var set_gravity_angle_fn_angle: ACEParam = ACEParam.new()
	set_gravity_angle_fn_angle.id = "angle"
	set_gravity_angle_fn_angle.type_name = "float"
	set_gravity_angle_fn.params.append(set_gravity_angle_fn_angle)
	var set_gravity_angle_fn_body: RawCodeRow = RawCodeRow.new()
	set_gravity_angle_fn_body.code = "\n".join(PackedStringArray([
		"gravity_angle = wrapf(angle, 0.0, 360.0)"
	]))
	set_gravity_angle_fn.events.append(set_gravity_angle_fn_body)
	sheet.functions.append(set_gravity_angle_fn)

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
		"enabled_movement = is_enabled",
		"# A frozen bullet costs nothing per frame; enabling it turns the tick back on.",
		"set_process(is_enabled)"
	]))
	set_bullet_enabled_fn.events.append(set_bullet_enabled_fn_body)
	sheet.functions.append(set_bullet_enabled_fn)

	# WHO FIRED IT. A shot that cannot say who fired it cannot score a kill, cannot be told apart
	# from an enemy's, and cannot avoid its own shooter. One line writes the node metadata key
	# `owner` that the Ownership rows and the Health pack's credit both read, so the answer is the
	# same one everywhere in the project.
	Lib.append_function(sheet, "set_fired_by", "Fired By", "Bullet",
		"Marks who fired this shot. Drop it on the row that spawns the bullet and every ownership row afterwards can answer: Hit Is Not My Owner stops it hurting its own shooter, Take Damage From credits the kill to the person rather than the projectile, and a turret's shot still traces back to whoever built the turret.",
		[["shooter", "Node"]], "
".join(PackedStringArray([
		"if host != null:",
		"	host.set_meta(&\"owner\", shooter)"
	])), "Fired by [i]{shooter}[/i]")

	return Lib.save_pack(sheet, "res://eventsheet_addons/bullet/bullet_behavior")
