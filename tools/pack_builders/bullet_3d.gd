# Pack builder - bullet_3d (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Bullet 3D behavior (event-sheet-style)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "Bullet3DBehavior"
	sheet.class_description = "Flies a Node3D forward every frame like a projectile: it launches along the host forward direction, then gravity bends the path into an arc. Tune speed and gravity in the Inspector or live from the sheet, and relaunch, retarget, or freeze a shot while the game runs."
	sheet.addon_category = "Bullet 3D"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"speed": {"type": "float", "default": 10.0, "exported": true, "description": "Units per second the bullet travels along the host's forward (-Z)."},
		"gravity": {"type": "float", "default": 0.0, "exported": true, "description": "Downward acceleration pulling the bullet's vertical velocity down each second."},
		"stepping": {"type": "bool", "default": false, "exported": true, "description": "Sweep the path each frame instead of jumping along it, so a fast bullet cannot pass through thin geometry between two frames."},
		"step_mask": {"type": "int", "default": 1, "exported": true, "description": "Collision layers the swept path tests against. Each layer is a bit, so layers 1 and 3 are 1 + 4 = 5."},
		"step_hits_areas": {"type": "bool", "default": false, "exported": true, "description": "Also stop the sweep on Area3D nodes, which it ignores by default."},
		"stop_on_step_hit": {"type": "bool", "default": true, "exported": true, "description": "Park the bullet at the point it struck and stop it. Turn off to keep flying and just report the hit."},
		"distance_travelled": {"type": "float", "default": 0.0, "exported": false},
		"vel_x": {"type": "float", "default": 0.0, "exported": false},
		"vel_y": {"type": "float", "default": 0.0, "exported": false},
		"vel_z": {"type": "float", "default": 0.0, "exported": false},
		"launched": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Bullet 3D behavior (event-sheet-style): launches along the host's forward (-Z) with speed and gravity; tracks distance travelled."
	sheet.events.append(about)
	# The two exports the variables dict cannot spell: a Vector3 literal, and a property with a
	# setter.
	var gravity_block: RawCodeRow = RawCodeRow.new()
	gravity_block.code = "\n".join(PackedStringArray([
		"# Which way gravity pulls (a Vector3 cannot emit from the variables dict, so it",
		"# lives here). Any direction works - the arc bends toward it; normalized before use.",
		"## The direction gravity pulls the arc toward (default straight down).",
		"@export var gravity_direction: Vector3 = Vector3.DOWN",
		"## When off, the bullet stops moving. Parity with the 2D pack, and what Stepping switches off when it parks the bullet on a hit.",
		"@export var enabled_movement: bool = true:",
		"\tset(value):",
		"\t\tenabled_movement = value",
		"\t\t# There is no enable verb here, so a bullet parked by a stepping hit is sent on its way",
		"\t\t# by a plain write to this flag - the reflected Set Enabled Movement action, the",
		"\t\t# Inspector, another script. Every one of them lands here, which is what turns the tick",
		"\t\t# back on; a frozen bullet costs nothing per frame until then.",
		"\t\tset_process(value)"
	]))
	sheet.events.append(gravity_block)

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
		"# parked by a stepping hit, costs nothing per frame until it is launched again.",
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
		"\tlaunch_forward()",
		"# Gravity pulls along gravity_direction; the default Vector3.DOWN normalizes to",
		"# itself exactly, so this is the plain vel_y drop it generalizes, bit for bit.",
		"var gravity_pull := gravity_direction.normalized() * gravity * delta",
		"vel_x += gravity_pull.x",
		"vel_y += gravity_pull.y",
		"vel_z += gravity_pull.z",
		"var motion := Vector3(vel_x, vel_y, vel_z) * delta",
		"# STEPPING: a fast bullet covers more ground per frame than a thin wall is deep, so a plain",
		"# teleport can land on the far side having touched nothing. Sweeping the frame's motion finds",
		"# what the jump skipped. Off by default - the two lines below are the original path.",
		"if stepping and motion != Vector3.ZERO and host.is_inside_tree():",
		"\tvar step_from := host.global_position",
		"\tvar step_query := PhysicsRayQueryParameters3D.create(step_from, step_from + motion, step_mask, [])",
		"\tstep_query.collide_with_areas = step_hits_areas",
		"\tvar step_hit := host.get_world_3d().direct_space_state.intersect_ray(step_query)",
		"\tif not step_hit.is_empty():",
		"\t\t# Park just SHORT of the surface: a ray that STARTS on a shape does not report it, so a",
		"\t\t# bullet left exactly touching the wall would sail through if it were ever restarted.",
		"\t\thost.global_position = step_hit.get(\"position\", step_from) - motion.normalized() * 0.01",
		"\t\tdistance_travelled += step_from.distance_to(host.global_position)",
		"\t\tif stop_on_step_hit:",
		"\t\t\tenabled_movement = false",
		"\t\t\t# A parked bullet is finished flying - stop paying for a tick that would only",
		"\t\t\t# early-return, until something launches it again.",
		"\t\t\tset_process(false)",
		"\t\ton_bullet_hit.emit(step_hit.get(\"collider\"), step_hit.get(\"position\", step_from), step_hit.get(\"normal\", Vector3.ZERO))",
		"\t\treturn",
		"host.position += motion",
		"distance_travelled += motion.length()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)
	var preview_block: RawCodeRow = RawCodeRow.new()
	preview_block.code = "\n".join(PackedStringArray([
		"# Editor-preview contract (Tools > Preview Behaviors on Selected Node): the arc solved for a",
		"# time instead of integrated frame by frame - p(t) = rest + forward*speed*t + pull*t*t/2 -",
		"# so the editor can show which way the shot goes, and how far gravity bends it, without",
		"# running the behavior. Stepping is deliberately NOT previewed: a sweep needs a physics space",
		"# and the editor has none, so the preview shows the unobstructed flight and says so by",
		"# ignoring the knob rather than pretending to collide.",
		"## @ace_hidden",
		"static func editor_preview_sample(params: Dictionary, base: Dictionary, time: float) -> Dictionary:",
		"\tif not bool(params.get(\"enabled_movement\", true)):",
		"\t\treturn {}",
		"\tvar rest: Variant = base.get(\"position\", null)",
		"\tif not rest is Vector3:",
		"\t\treturn {}",
		"\tvar euler: Variant = base.get(\"rotation\", Vector3.ZERO)",
		"\tvar facing: Basis = Basis.from_euler(euler if euler is Vector3 else Vector3.ZERO)",
		"\tvar forward: Vector3 = -facing.z",
		"\tvar pull_direction: Variant = params.get(\"gravity_direction\", Vector3.DOWN)",
		"\tvar pull: Vector3 = (pull_direction if pull_direction is Vector3 else Vector3.DOWN).normalized() * float(params.get(\"gravity\", 0.0))",
		"\tvar flown: Vector3 = forward * float(params.get(\"speed\", 10.0)) * time + pull * time * time * 0.5",
		"\treturn {\"position\": (rest as Vector3) + flown}"
	]))
	sheet.events.append(preview_block)

	# The trigger Stepping fires, declared with its arguments so a sheet row receives what was hit,
	# where, and which way that surface faces - everything an impact effect needs.
	var signals_block: RawCodeRow = RawCodeRow.new()
	signals_block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Bullet Hit\")",
		"## @ace_description(\"Fires when Stepping catches something in the bullet's path this frame. Hands back what was hit, the exact point, and the surface normal.\")",
		"signal on_bullet_hit(collider: Object, point: Vector3, normal: Vector3)"
	]))
	sheet.events.append(signals_block)

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
		"launched = true",
		"# Launching re-syncs the tick to whether the bullet is moving, so a shot re-enabled",
		"# through its Inspector flag and then relaunched still flies.",
		"set_process(enabled_movement)"
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
		"launched = true",
		"# Re-aiming a bullet re-syncs the tick to whether it is moving, so a shot re-enabled",
		"# through its Inspector flag still flies.",
		"set_process(enabled_movement)"
	]))
	set_bullet3d_speed_fn.events.append(set_bullet3d_speed_fn_body)
	sheet.functions.append(set_bullet3d_speed_fn)

	var set_gravity_direction_fn: EventFunction = EventFunction.new()
	set_gravity_direction_fn.function_name = "set_gravity_direction"
	set_gravity_direction_fn.expose_as_ace = true
	set_gravity_direction_fn.ace_display_name = "Set Gravity Direction"
	set_gravity_direction_fn.ace_category = "Bullet 3D"
	set_gravity_direction_fn.description = "Points gravity along a new 3D direction (it is normalized for you) - the arc bends that way from now on. (0, -1, 0) is normal down, (0, 1, 0) pulls up, (1, 0, 0) pulls along +X."
	for axis_name in ["x", "y", "z"]:
		var axis_param: ACEParam = ACEParam.new()
		axis_param.id = axis_name
		axis_param.type_name = "float"
		set_gravity_direction_fn.params.append(axis_param)
	var set_gravity_direction_fn_body: RawCodeRow = RawCodeRow.new()
	set_gravity_direction_fn_body.code = "\n".join(PackedStringArray([
		"gravity_direction = Vector3(x, y, z)"
	]))
	set_gravity_direction_fn.events.append(set_gravity_direction_fn_body)
	sheet.functions.append(set_gravity_direction_fn)

	return Lib.save_pack(sheet, "res://eventsheet_addons/bullet_3d/bullet_3d_behavior")
