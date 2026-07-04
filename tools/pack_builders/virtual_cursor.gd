# Pack builder - virtual_cursor (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Virtual Cursor behavior (event-sheet parity - ported from the virtual_cursor addon).
## Input-agnostic controllable cursor on a CharacterBody2D; drives the Drag N Drop pack.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "VirtualCursor"
	sheet.addon_category = "Virtual Cursor"
	sheet.ace_expose_all_mode = "node"
	# Scalar / Array / Dictionary state via sheet.variables. The exported int enums
	# (direction_mode/hover_mode/bounce_mode) and the Vector2/Rect2 runtime state live in
	# the raw header block below (the variable emitter only does @export_enum for String
	# and can't emit Vector2/Rect2 literals faithfully).
	sheet.variables = {
		"max_speed": {"type": "float", "default": 600.0, "exported": true, "attributes": {"tooltip": "Max cursor speed (px/s)."}},
		"acceleration": {"type": "float", "default": 1800.0, "exported": true, "attributes": {"tooltip": "Speed-up rate while axis held (px/s^2)."}},
		"deceleration": {"type": "float", "default": 2400.0, "exported": true, "attributes": {"tooltip": "Slow-down rate when axis released (px/s^2)."}},
		"allow_sliding": {"type": "bool", "default": true, "exported": true, "attributes": {"tooltip": "Slide along solids instead of hard-stop."}},
		"default_controls": {"type": "bool", "default": true, "exported": true, "attributes": {"tooltip": "Read ui_left/right/up/down each tick (keyboard+gamepad)."}},
		"enabled": {"type": "bool", "default": true, "exported": true, "attributes": {"tooltip": "Master on/off."}},
		"constrain_to_layout": {"type": "bool", "default": false, "exported": true, "attributes": {"tooltip": "Clamp inside the viewport/constraint bounds."}},
		"mouse_smoothing": {"type": "float", "default": 0.15, "exported": false},
		"has_mouse_target": {"type": "bool", "default": false, "exported": false},
		"has_simulated_axis": {"type": "bool", "default": false, "exported": false},
		"ignoring_input": {"type": "bool", "default": false, "exported": false},
		"homing_enabled": {"type": "bool", "default": false, "exported": false},
		"homing_mode": {"type": "int", "default": 0, "exported": false},
		"homing_radius": {"type": "float", "default": 120.0, "exported": false},
		"homing_strength": {"type": "float", "default": 0.5, "exported": false},
		"homing_targets": {"type": "Array", "default": [], "exported": false},
		"in_homing_range": {"type": "bool", "default": false, "exported": false},
		"nearest_homing_uid": {"type": "int", "default": -1, "exported": false},
		"nearest_homing_dist": {"type": "float", "default": -1.0, "exported": false},
		"homing_snapped_uid": {"type": "int", "default": -1, "exported": false},
		"solids": {"type": "Array", "default": [], "exported": false},
		"solid_collision": {"type": "bool", "default": true, "exported": false},
		"blocked_this_tick": {"type": "bool", "default": false, "exported": false},
		"solid_uid": {"type": "int", "default": -1, "exported": false},
		"has_constraint_bounds": {"type": "bool", "default": false, "exported": false},
		"interact_states": {"type": "Dictionary", "default": {}, "exported": false},
		"last_pressed_id": {"type": "String", "default": "", "exported": false},
		"last_released_id": {"type": "String", "default": "", "exported": false},
		"hovered_uid": {"type": "int", "default": -1, "exported": false},
		"edge_hit_prev": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Virtual Cursor behavior (event-sheet parity): input-agnostic controllable cursor on a CharacterBody2D - event-driven/axis/mouse-follow movement with accel/decel and direction modes, homing magnet, solid push-out via move_and_slide with sliding, lossless bounce, layout/viewport constraints, hover detection, and named interact buttons. Drives the Drag N Drop pack."
	sheet.events.append(about)

	# Exported int enums + Vector2 / Rect2 runtime state - declared verbatim at class level.
	var decls: RawCodeRow = RawCodeRow.new()
	decls.code = "\n".join(PackedStringArray([
		"## Movement axis constraint.",
		"@export_enum(\"up_down\", \"left_right\", \"four\", \"eight\") var direction_mode: int = 3",
		"## Point = origin inside shape; Overlap = shapes overlap.",
		"@export_enum(\"point\", \"overlap\") var hover_mode: int = 0",
		"## Which surfaces reflect the cursor losslessly.",
		"@export_enum(\"none\", \"solids\", \"constraints\", \"both\") var bounce_mode: int = 0",
		"var vel: Vector2 = Vector2.ZERO",
		"var report_vel: Vector2 = Vector2.ZERO",
		"var axis: Vector2 = Vector2.ZERO",
		"var simulated_axis: Vector2 = Vector2.ZERO",
		"var mouse_target: Vector2 = Vector2.ZERO",
		"var constraint_bounds: Rect2 = Rect2()"
	]))
	sheet.events.append(decls)

	# Triggers + conditions + expressions + non-exposed helpers.
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Interact Pressed\")",
		"signal interact_pressed(id: String)",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Interact Released\")",
		"signal interact_released(id: String)",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Layout Edge Hit\")",
		"signal layout_edge_hit",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Homing Target Entered\")",
		"signal homing_target_entered",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Homing Target Exited\")",
		"signal homing_target_exited",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Homing Snapped\")",
		"signal homing_snapped",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Solid Hit\")",
		"signal solid_hit",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Bounce\")",
		"signal bounce_triggered",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Interact Held\")",
		"func is_interact_held(id: String) -> bool:",
		"\tif id == \"\":",
		"\t\tfor key in interact_states:",
		"\t\t\tif bool(interact_states[key]):",
		"\t\t\t\treturn true",
		"\t\treturn false",
		"\treturn bool(interact_states.get(id, false))",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Moving\")",
		"func is_moving() -> bool:",
		"\treturn report_vel.length() > 0.0",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is In Homing Range\")",
		"func is_in_homing_range() -> bool:",
		"\treturn in_homing_range",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Blocked\")",
		"func is_blocked() -> bool:",
		"\treturn blocked_this_tick",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Enabled\")",
		"func is_cursor_enabled() -> bool:",
		"\treturn enabled",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Ignoring Input\")",
		"func is_ignoring_input() -> bool:",
		"\treturn ignoring_input",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Hovering\")",
		"func is_hovering(target: Node2D) -> bool:",
		"\thovered_uid = -1",
		"\tif host == null or target == null or target == host or not target.visible:",
		"\t\treturn false",
		"\tvar hit := false",
		"\tif hover_mode == 0:",
		"\t\tvar shape := target.get_node_or_null(\"CollisionShape2D\") as CollisionShape2D",
		"\t\tif shape != null and shape.shape != null:",
		"\t\t\thit = shape.shape.collide(shape.global_transform, _point_shape(), Transform2D(0.0, host.global_position))",
		"\t\telif target.has_method(\"get_global_rect\"):",
		"\t\t\thit = target.call(\"get_global_rect\").has_point(host.global_position)",
		"\t\telse:",
		"\t\t\t# Robust fallback for plain Sprite2D/CanvasItem (no CollisionShape2D, no",
		"\t\t\t# get_global_rect): derive a world rect from get_rect(), else distance check.",
		"\t\t\tvar info := _target_world_rect(target)",
		"\t\t\tif bool(info[\"has_area\"]):",
		"\t\t\t\thit = (info[\"rect\"] as Rect2).has_point(host.global_position)",
		"\t\t\telse:",
		"\t\t\t\thit = host.global_position.distance_to(target.global_position) <= _target_extent(target)",
		"\telse:",
		"\t\tvar host_node: Node = host",
		"\t\tif host_node is Area2D:",
		"\t\t\tvar area := host_node as Area2D",
		"\t\t\thit = area.get_overlapping_bodies().has(target) or area.get_overlapping_areas().has(target)",
		"\t\telse:",
		"\t\t\t# CharacterBody2D host never overlaps as an Area2D - gate on the target's",
		"\t\t\t# derived extent instead of a fixed 32px so size is respected.",
		"\t\t\thit = host.global_position.distance_to(target.global_position) <= _target_extent(target)",
		"\tif hit:",
		"\t\thovered_uid = target.get_instance_id()",
		"\treturn hit",
		"",
		"## @ace_expression",
		"## @ace_name(\"Cursor X\")",
		"func cursor_x() -> float:",
		"\treturn host.global_position.x if host != null else 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Cursor Y\")",
		"func cursor_y() -> float:",
		"\treturn host.global_position.y if host != null else 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Speed\")",
		"func speed() -> float:",
		"\treturn report_vel.length()",
		"",
		"## @ace_expression",
		"## @ace_name(\"Velocity X\")",
		"func velocity_x() -> float:",
		"\treturn report_vel.x",
		"",
		"## @ace_expression",
		"## @ace_name(\"Velocity Y\")",
		"func velocity_y() -> float:",
		"\treturn report_vel.y",
		"",
		"## @ace_expression",
		"## @ace_name(\"Moving Angle\")",
		"func moving_angle() -> float:",
		"\treturn fposmod(rad_to_deg(report_vel.angle()), 360.0)",
		"",
		"## @ace_expression",
		"## @ace_name(\"Axis X\")",
		"func axis_x() -> float:",
		"\treturn axis.x",
		"",
		"## @ace_expression",
		"## @ace_name(\"Axis Y\")",
		"func axis_y() -> float:",
		"\treturn axis.y",
		"",
		"## @ace_expression",
		"## @ace_name(\"Max Speed\")",
		"func max_speed_value() -> float:",
		"\treturn max_speed",
		"",
		"## @ace_expression",
		"## @ace_name(\"Hovered UID\")",
		"func hovered_uid_value() -> int:",
		"\treturn hovered_uid",
		"",
		"## @ace_expression",
		"## @ace_name(\"Homing Target UID\")",
		"func homing_target_uid_value() -> int:",
		"\treturn nearest_homing_uid",
		"",
		"## @ace_expression",
		"## @ace_name(\"Homing Target Dist\")",
		"func homing_target_dist_value() -> float:",
		"\treturn nearest_homing_dist",
		"",
		"## @ace_expression",
		"## @ace_name(\"Count Homing Targets\")",
		"func count_homing_targets() -> int:",
		"\treturn homing_targets.size()",
		"",
		"## @ace_expression",
		"## @ace_name(\"Bounce Mode\")",
		"func bounce_mode_token() -> String:",
		"\treturn [\"none\", \"solids\", \"constraints\", \"both\"][bounce_mode]",
		"",
		"func _point_shape() -> Shape2D:",
		"\tvar s := CircleShape2D.new()",
		"\ts.radius = 0.5",
		"\treturn s",
		"",
		"## Best-effort world-space AABB for a target that has no usable CollisionShape2D.",
		"## Sprite2D/CanvasItem expose a LOCAL get_rect(); we transform its centre + half-size",
		"## through global_transform so hover works on plain sprites. Returns has_area=false when",
		"## nothing usable is found (caller then falls back to a distance/extent check).",
		"func _target_world_rect(target: Node2D) -> Dictionary:",
		"\tvar shape := target.get_node_or_null(\"CollisionShape2D\") as CollisionShape2D",
		"\tif shape != null and shape.shape != null:",
		"\t\tvar lr: Rect2 = shape.shape.get_rect()",
		"\t\treturn {\"has_area\": true, \"rect\": _xform_rect(shape.global_transform, lr)}",
		"\tif target.has_method(\"get_rect\"):",
		"\t\tvar r: Rect2 = target.call(\"get_rect\")",
		"\t\treturn {\"has_area\": true, \"rect\": _xform_rect(target.global_transform, r)}",
		"\treturn {\"has_area\": false, \"rect\": Rect2()}",
		"",
		"## Transform a local-space Rect2 into a world-space AABB by mapping its four corners.",
		"func _xform_rect(xform: Transform2D, r: Rect2) -> Rect2:",
		"\tvar p0 := xform * r.position",
		"\tvar out := Rect2(p0, Vector2.ZERO)",
		"\tout = out.expand(xform * Vector2(r.position.x + r.size.x, r.position.y))",
		"\tout = out.expand(xform * Vector2(r.position.x, r.position.y + r.size.y))",
		"\tout = out.expand(xform * (r.position + r.size))",
		"\treturn out",
		"",
		"## A representative world-space proximity radius for a target: half the larger side of",
		"## its derived world rect, else 32px. Used by overlap-mode hover so the gate tracks the",
		"## actual target size instead of a fixed constant.",
		"func _target_extent(target: Node2D) -> float:",
		"\tvar info := _target_world_rect(target)",
		"\tif bool(info[\"has_area\"]):",
		"\t\tvar r: Rect2 = info[\"rect\"]",
		"\t\tvar e := maxf(r.size.x, r.size.y) * 0.5",
		"\t\tif e > 0.0:",
		"\t\t\treturn e",
		"\treturn 32.0",
		"",
		"func _resolve_bounds() -> Rect2:",
		"\tif has_constraint_bounds:",
		"\t\treturn constraint_bounds",
		"\tif host != null and host.get_viewport() != null:",
		"\t\treturn host.get_viewport().get_visible_rect()",
		"\treturn Rect2(0, 0, 1920, 1080)"
	]))
	sheet.events.append(block)

	# Physics-tick integrator (5-stage order).
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not enabled or host == null:",
		"\treport_vel = Vector2.ZERO",
		"\treturn",
		"# 1) VELOCITY: resolve axis.",
		"if ignoring_input:",
		"\taxis = Vector2.ZERO",
		"elif has_simulated_axis:",
		"\taxis = simulated_axis.limit_length(1.0)",
		"\tsimulated_axis = Vector2.ZERO",
		"\thas_simulated_axis = false",
		"elif default_controls:",
		"\taxis = Input.get_vector(\"ui_left\", \"ui_right\", \"ui_up\", \"ui_down\")",
		"else:",
		"\taxis = Vector2.ZERO",
		"if direction_mode == 0:",
		"\taxis.x = 0.0",
		"elif direction_mode == 1:",
		"\taxis.y = 0.0",
		"elif direction_mode == 2:",
		"\tif absf(axis.x) >= absf(axis.y):",
		"\t\taxis.y = 0.0",
		"\telse:",
		"\t\taxis.x = 0.0",
		"if has_mouse_target:",
		"\tvar lerp_t := 1.0 - pow(1.0 - mouse_smoothing, delta * 60.0)",
		"\tvar to := mouse_target - host.global_position",
		"\tvar target_speed := minf(to.length() * mouse_smoothing * 60.0, max_speed)",
		"\tvel = vel.lerp(to.normalized() * target_speed, lerp_t)",
		"\tif to.length() < 0.5:",
		"\t\tvel *= 0.5",
		"\t\thas_mouse_target = false",
		"elif axis != Vector2.ZERO:",
		"\tvar dir := axis.normalized()",
		"\tvar spd := minf(vel.length() + acceleration * delta, max_speed)",
		"\tvel = dir * spd",
		"else:",
		"\tvar spd := maxf(vel.length() - deceleration * delta, 0.0)",
		"\tvel = vel.normalized() * spd if vel.length() > 0.0 else Vector2.ZERO",
		"# 2) HOMING (steer/snap, pre-move).",
		"if homing_enabled and not homing_targets.is_empty():",
		"\tvar pruned: Array = []",
		"\tfor id in homing_targets:",
		"\t\tif is_instance_valid(instance_from_id(id)):",
		"\t\t\tpruned.append(id)",
		"\thoming_targets = pruned",
		"\tvar best_uid := -1",
		"\tvar best_dist := -1.0",
		"\tvar best_pos := host.global_position",
		"\tfor id in homing_targets:",
		"\t\tvar n := instance_from_id(id) as Node2D",
		"\t\tif n == null:",
		"\t\t\tcontinue",
		"\t\tvar d: float = host.global_position.distance_to(n.global_position)",
		"\t\tif best_dist < 0.0 or d < best_dist:",
		"\t\t\tbest_dist = d",
		"\t\t\tbest_uid = id",
		"\t\t\tbest_pos = n.global_position",
		"\tvar within := best_uid != -1 and best_dist <= homing_radius",
		"\tif within and not in_homing_range:",
		"\t\thoming_target_entered.emit()",
		"\telif not within and in_homing_range:",
		"\t\thoming_target_exited.emit()",
		"\tin_homing_range = within",
		"\tnearest_homing_uid = best_uid if within else -1",
		"\tnearest_homing_dist = best_dist if within else -1.0",
		"\tif within:",
		"\t\tvar dir_to := (best_pos - host.global_position).normalized()",
		"\t\tif homing_mode == 0:",
		"\t\t\thoming_snapped_uid = -1",
		"\t\t\tvel = vel.lerp(dir_to * max_speed * homing_strength, minf(1.0, homing_strength * 6.0 * delta))",
		"\t\telse:",
		"\t\t\tif axis != Vector2.ZERO:",
		"\t\t\t\thoming_snapped_uid = -1",
		"\t\t\t\tvel += dir_to * max_speed * homing_strength * 4.0 * delta",
		"\t\t\t\tvel = vel.limit_length(max_speed)",
		"\t\t\telse:",
		"\t\t\t\thost.global_position = best_pos",
		"\t\t\t\tvel = Vector2.ZERO",
		"\t\t\t\treport_vel = Vector2.ZERO",
		"\t\t\t\t# Latch: emit once on a fresh snap, not every frame the cursor rests here.",
		"\t\t\t\tif homing_snapped_uid != best_uid:",
		"\t\t\t\t\thoming_snapped_uid = best_uid",
		"\t\t\t\t\thoming_snapped.emit()",
		"\telse:",
		"\t\thoming_snapped_uid = -1",
		"else:",
		"\tif in_homing_range:",
		"\t\thoming_target_exited.emit()",
		"\tin_homing_range = false",
		"\tnearest_homing_uid = -1",
		"\tnearest_homing_dist = -1.0",
		"\thoming_snapped_uid = -1",
		"# 3) MOVE + SOLIDS.",
		"host.velocity = vel",
		"host.move_and_slide()",
		"blocked_this_tick = host.get_slide_collision_count() > 0",
		"if blocked_this_tick:",
		"\tvar col := host.get_last_slide_collision()",
		"\tsolid_uid = col.get_collider().get_instance_id() if col != null and col.get_collider() != null else -1",
		"\tsolid_hit.emit()",
		"\tif bounce_mode == 1 or bounce_mode == 3:",
		"\t\tfor i in host.get_slide_collision_count():",
		"\t\t\tvel = vel.bounce(host.get_slide_collision(i).get_normal())",
		"\t\tbounce_triggered.emit()",
		"\tif not allow_sliding:",
		"\t\tvel = Vector2.ZERO",
		"\telse:",
		"\t\tvel = host.velocity",
		"# 4) CONSTRAIN.",
		"if constrain_to_layout:",
		"\tvar b := _resolve_bounds()",
		"\tvar p := host.global_position",
		"\tvar cp := Vector2(clampf(p.x, b.position.x, b.end.x), clampf(p.y, b.position.y, b.end.y))",
		"\tvar edge := cp != p",
		"\tif edge:",
		"\t\thost.global_position = cp",
		"\t\tif bounce_mode == 2 or bounce_mode == 3:",
		"\t\t\tif cp.x != p.x:",
		"\t\t\t\tvel.x = -vel.x",
		"\t\t\tif cp.y != p.y:",
		"\t\t\t\tvel.y = -vel.y",
		"\t\t\tbounce_triggered.emit()",
		"\t\telse:",
		"\t\t\tif cp.x != p.x:",
		"\t\t\t\tvel.x = 0.0",
		"\t\t\tif cp.y != p.y:",
		"\t\t\t\tvel.y = 0.0",
		"\tif edge and not edge_hit_prev:",
		"\t\tlayout_edge_hit.emit()",
		"\tedge_hit_prev = edge",
		"# 5) report.",
		"report_vel = vel"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# Actions.
	Lib.append_function(sheet, "press_interact", "Press Interact", "Virtual Cursor",
		"Marks a named interact button held and fires On Interact Pressed.",
		[["id", "String"]], "\n".join(PackedStringArray([
		"interact_states[id] = true",
		"last_pressed_id = id",
		"interact_pressed.emit(id)"
	])))

	Lib.append_function(sheet, "release_interact", "Release Interact", "Virtual Cursor",
		"Marks a named interact button released and fires On Interact Released.",
		[["id", "String"]], "\n".join(PackedStringArray([
		"interact_states[id] = false",
		"last_released_id = id",
		"interact_released.emit(id)"
	])))

	Lib.append_function(sheet, "simulate_interact", "Simulate Interact", "Virtual Cursor",
		"Fires a press+release of a named button in one tick.",
		[["id", "String"]], "\n".join(PackedStringArray([
		"if ignoring_input:",
		"\treturn",
		"last_pressed_id = id",
		"last_released_id = id",
		"interact_pressed.emit(id)",
		"interact_released.emit(id)"
	])))

	Lib.append_function(sheet, "set_max_speed", "Set Max Speed", "Virtual Cursor",
		"Sets the max cursor speed (px/s).",
		[["speed", "float"]], "\n".join(PackedStringArray([
		"max_speed = speed"
	])))

	Lib.append_function(sheet, "set_acceleration", "Set Acceleration", "Virtual Cursor",
		"Sets the speed-up rate while an axis is held.",
		[["rate", "float"]], "\n".join(PackedStringArray([
		"acceleration = rate"
	])))

	Lib.append_function(sheet, "set_deceleration", "Set Deceleration", "Virtual Cursor",
		"Sets the slow-down rate when the axis is released.",
		[["rate", "float"]], "\n".join(PackedStringArray([
		"deceleration = rate"
	])))

	Lib.append_function(sheet, "set_cursor_velocity", "Set Velocity", "Virtual Cursor",
		"Sets the cursor velocity directly.",
		[["vel_x", "float"], ["vel_y", "float"]], "\n".join(PackedStringArray([
		"vel = Vector2(vel_x, vel_y)",
		"report_vel = vel"
	])))

	Lib.append_function(sheet, "simulate_direct_mouse_position", "Simulate Direct Mouse Position", "Virtual Cursor",
		"Teleports the cursor to a position, reporting the implied velocity.",
		[["target_x", "float"], ["target_y", "float"]], "\n".join(PackedStringArray([
		"if ignoring_input or host == null:",
		"\treturn",
		"var dt: float = get_physics_process_delta_time()",
		"var new_pos := Vector2(target_x, target_y)",
		"if dt > 0.0:",
		"\treport_vel = (new_pos - host.global_position) / dt",
		"host.global_position = new_pos",
		"vel = Vector2.ZERO"
	])))

	Lib.append_function(sheet, "simulate_mouse", "Simulate Mouse", "Virtual Cursor",
		"Drives the cursor toward a target with smoothing (mouse-follow).",
		[["target_x", "float"], ["target_y", "float"], ["smoothing", "float"]], "\n".join(PackedStringArray([
		"if ignoring_input:",
		"\treturn",
		"mouse_target = Vector2(target_x, target_y)",
		"mouse_smoothing = clampf(smoothing, 0.0, 1.0)",
		"has_mouse_target = true"
	])))

	Lib.append_function(sheet, "simulate_axis", "Simulate Axis", "Virtual Cursor",
		"Feeds an analog axis for this tick (accel/decel applies).",
		[["x", "float"], ["y", "float"]], "\n".join(PackedStringArray([
		"if ignoring_input:",
		"\treturn",
		"simulated_axis += Vector2(x, y)",
		"has_simulated_axis = true"
	])))

	Lib.append_function(sheet, "simulate_control", "Simulate Control", "Virtual Cursor",
		"Feeds a cardinal direction (0 up, 1 down, 2 left, 3 right) for this tick.",
		[["direction", "int"]], "\n".join(PackedStringArray([
		"if ignoring_input:",
		"\treturn",
		"var dirs := [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]",
		"if direction >= 0 and direction < 4:",
		"\tsimulated_axis += dirs[direction]",
		"\thas_simulated_axis = true"
	])))

	Lib.append_function(sheet, "set_homing_enabled", "Set Homing Enabled", "Virtual Cursor",
		"Turns the homing magnet on/off.",
		[["is_enabled", "bool"]], "\n".join(PackedStringArray([
		"homing_enabled = is_enabled"
	])))

	Lib.append_function(sheet, "set_homing_mode", "Set Homing Mode", "Virtual Cursor",
		"0 steer, 1 snap-radius, 2 snap-overlap.",
		[["mode", "int"]], "\n".join(PackedStringArray([
		"homing_mode = clampi(mode, 0, 2)"
	])))

	Lib.append_function(sheet, "set_homing_radius", "Set Homing Radius", "Virtual Cursor",
		"Sets the homing engagement radius.",
		[["radius", "float"]], "\n".join(PackedStringArray([
		"homing_radius = maxf(0.0, radius)"
	])))

	Lib.append_function(sheet, "set_homing_strength", "Set Homing Strength", "Virtual Cursor",
		"How strongly the cursor is pulled toward a homing target (0..1).",
		[["strength", "float"]], "\n".join(PackedStringArray([
		"homing_strength = clampf(strength, 0.0, 1.0)"
	])))

	Lib.append_function(sheet, "add_homing_target", "Add Homing Target", "Virtual Cursor",
		"Registers a node as a homing target.",
		[["target", "Node2D"]], "\n".join(PackedStringArray([
		"if target != null:",
		"\tvar id := target.get_instance_id()",
		"\tif not homing_targets.has(id):",
		"\t\thoming_targets.append(id)"
	])))

	Lib.append_function(sheet, "remove_homing_target", "Remove Homing Target", "Virtual Cursor",
		"Unregisters a homing target.",
		[["target", "Node2D"]], "\n".join(PackedStringArray([
		"if target != null:",
		"\thoming_targets.erase(target.get_instance_id())"
	])))

	Lib.append_function(sheet, "clear_homing_targets", "Clear Homing Targets", "Virtual Cursor",
		"Removes every homing target.",
		[], "\n".join(PackedStringArray([
		"homing_targets.clear()",
		"in_homing_range = false",
		"nearest_homing_uid = -1",
		"nearest_homing_dist = -1.0",
		"homing_snapped_uid = -1"
	])))

	Lib.append_function(sheet, "add_solid", "Add Solid", "Virtual Cursor",
		"Registers a node as a tracked solid (for SolidUID reporting).",
		[["target", "Node2D"]], "\n".join(PackedStringArray([
		"if target != null:",
		"\tvar id := target.get_instance_id()",
		"\tif not solids.has(id):",
		"\t\tsolids.append(id)"
	])))

	Lib.append_function(sheet, "remove_solid", "Remove Solid", "Virtual Cursor",
		"Unregisters a tracked solid.",
		[["target", "Node2D"]], "\n".join(PackedStringArray([
		"if target != null:",
		"\tsolids.erase(target.get_instance_id())"
	])))

	Lib.append_function(sheet, "clear_solids", "Clear Solids", "Virtual Cursor",
		"Clears the tracked-solids list.",
		[], "\n".join(PackedStringArray([
		"solids.clear()"
	])))

	Lib.append_function(sheet, "set_solid_collision", "Set Solid Collision", "Virtual Cursor",
		"Toggles solid push-out via move_and_slide.",
		[["is_enabled", "bool"]], "\n".join(PackedStringArray([
		"solid_collision = is_enabled"
	])))

	Lib.append_function(sheet, "set_allow_sliding", "Set Allow Sliding", "Virtual Cursor",
		"Slide along solids (true) or hard-stop (false).",
		[["state", "bool"]], "\n".join(PackedStringArray([
		"allow_sliding = state"
	])))

	Lib.append_function(sheet, "set_bounce", "Set Bounce", "Virtual Cursor",
		"0 none, 1 solids, 2 constraints, 3 both.",
		[["mode", "int"]], "\n".join(PackedStringArray([
		"bounce_mode = clampi(mode, 0, 3)"
	])))

	Lib.append_function(sheet, "set_direction_mode", "Set Direction Mode", "Virtual Cursor",
		"0 up/down, 1 left/right, 2 four-way, 3 eight-way.",
		[["mode", "int"]], "\n".join(PackedStringArray([
		"direction_mode = clampi(mode, 0, 3)"
	])))

	Lib.append_function(sheet, "set_default_controls", "Set Default Controls", "Virtual Cursor",
		"Read ui_left/right/up/down each tick.",
		[["state", "bool"]], "\n".join(PackedStringArray([
		"default_controls = state"
	])))

	Lib.append_function(sheet, "set_cursor_enabled", "Set Enabled", "Virtual Cursor",
		"Master on/off.",
		[["is_enabled", "bool"]], "\n".join(PackedStringArray([
		"enabled = is_enabled"
	])))

	Lib.append_function(sheet, "set_ignoring_input", "Set Ignoring Input", "Virtual Cursor",
		"Ignore all input while true (movement decays to zero).",
		[["state", "bool"]], "\n".join(PackedStringArray([
		"ignoring_input = state"
	])))

	Lib.append_function(sheet, "set_constrain_to_layout", "Set Constrain To Layout", "Virtual Cursor",
		"Clamp the cursor inside the bounds.",
		[["is_enabled", "bool"]], "\n".join(PackedStringArray([
		"constrain_to_layout = is_enabled"
	])))

	Lib.append_function(sheet, "set_constraint_bounds", "Set Constraint Bounds", "Virtual Cursor",
		"Sets explicit clamp bounds (all-zero clears them, falling back to the viewport).",
		[["left", "float"], ["top", "float"], ["right", "float"], ["bottom", "float"]], "\n".join(PackedStringArray([
		"if left == 0.0 and top == 0.0 and right == 0.0 and bottom == 0.0:",
		"\thas_constraint_bounds = false",
		"else:",
		"\tconstraint_bounds = Rect2(left, top, right - left, bottom - top)",
		"\thas_constraint_bounds = true"
	])))

	Lib.append_function(sheet, "set_hover_mode", "Set Hover Mode", "Virtual Cursor",
		"0 point (origin inside shape), 1 overlap (shapes overlap).",
		[["mode", "int"]], "\n".join(PackedStringArray([
		"hover_mode = clampi(mode, 0, 1)"
	])))

	return Lib.save_pack(sheet, "res://eventsheet_addons/virtual_cursor/virtual_cursor_behavior")
