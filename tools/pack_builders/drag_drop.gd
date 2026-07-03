# Pack builder - drag_drop (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Drag & Drop behavior (event-sheet parity - event-driven rewrite of the dragndrop behavior).
## The author feeds the drag point each tick (virtual cursor, gamepad, touch, AI); this
## pack NEVER polls Input.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "DragDropBehavior"
	# Scalar / Array / Dictionary state goes through sheet.variables. Vector2 /
	# PackedVector2Array defaults and the @export_enum int live in the raw header block
	# below (the variable emitter can't produce those literals/enums faithfully).
	sheet.variables = {
		"follow_speed": {"type": "float", "default": 0.0, "exported": true, "attributes": {"tooltip": "Max catch-up speed (px/s); 0 = instant snap each tick."}},
		"break_distance": {"type": "float", "default": 0.0, "exported": true, "attributes": {"tooltip": "Gap that auto-ends the drag; 0 disables."}},
		"enabled": {"type": "bool", "default": true, "exported": true, "attributes": {"tooltip": "Active at start; disabling mid-drag cancels silently."}},
		"dragging": {"type": "bool", "default": false, "exported": false},
		"follow_uid": {"type": "int", "default": -1, "exported": false},
		"distance_from_point": {"type": "float", "default": 0.0, "exported": false},
		"throw_speed": {"type": "float", "default": 0.0, "exported": false},
		"has_throw_override": {"type": "bool", "default": false, "exported": false},
		"drop_reason": {"type": "String", "default": "manual", "exported": false},
		"break_action": {"type": "int", "default": 0, "exported": false},
		"snap_positions": {"type": "Array", "default": [], "exported": false},
		"snap_uids": {"type": "Array[int]", "default": [], "exported": false},
		"snap_radius": {"type": "float", "default": 0.0, "exported": false},
		"snap_mode": {"type": "int", "default": 0, "exported": false},
		"magnet_strength": {"type": "float", "default": 0.0, "exported": false},
		"is_snapping_flag": {"type": "bool", "default": false, "exported": false},
		"snapped_uid": {"type": "int", "default": -1, "exported": false},
		"throw_cursor": {"type": "int", "default": 0, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Drag & Drop behavior (event-sheet parity, event-driven): the author feeds the drag point each tick (virtual cursor, gamepad, touch, AI) - never polls Input. Follow-speed lag, direction lock, break-distance auto-drop, snapping/magnetism, auto-measured throw velocity (routed by you in On Dropped). NOTE: overlap snap mode is a v1 radius-distance simplification (true shape-overlap is a follow-up)."
	sheet.events.append(about)

	# Exported enum (int) + Vector2 / PackedVector2Array runtime state - declared verbatim
	# at class level (the variable emitter only does @export_enum for String + can't emit
	# Vector2/PackedVector2Array literals).
	var decls: RawCodeRow = RawCodeRow.new()
	decls.code = "\n".join(PackedStringArray([
		"## Per-tick movement lock (8Direction style).",
		"@export_enum(\"free\", \"up_down\", \"left_right\", \"four_dir\", \"eight_dir\") var directions: int = 0",
		"var drag_point: Vector2 = Vector2.ZERO",
		"var prev_drag_point: Vector2 = Vector2.ZERO",
		"var grab_offset: Vector2 = Vector2.ZERO",
		"var throw_vel: Vector2 = Vector2.ZERO",
		"var override_throw: Vector2 = Vector2.ZERO",
		"var snap_target: Vector2 = Vector2.ZERO",
		"var throw_history: PackedVector2Array = PackedVector2Array()"
	]))
	sheet.events.append(decls)

	# Triggers + conditions + expressions + non-exposed helpers.
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Drag Started\")",
		"## @ace_category(\"Drag & Drop\")",
		"signal drag_started",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Dropped\")",
		"## @ace_category(\"Drag & Drop\")",
		"signal dropped",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Drag Cancelled\")",
		"## @ace_category(\"Drag & Drop\")",
		"signal drag_cancelled",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Snapped\")",
		"## @ace_category(\"Drag & Drop\")",
		"signal snapped",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Dragging\")",
		"## @ace_category(\"Drag & Drop\")",
		"## @ace_codegen_template(\"$DragDropBehavior.is_dragging()\")",
		"func is_dragging() -> bool:",
		"\treturn dragging",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Enabled\")",
		"## @ace_category(\"Drag & Drop\")",
		"## @ace_codegen_template(\"$DragDropBehavior.is_dragdrop_enabled()\")",
		"func is_dragdrop_enabled() -> bool:",
		"\treturn enabled",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Snapping\")",
		"## @ace_category(\"Drag & Drop\")",
		"## @ace_codegen_template(\"$DragDropBehavior.is_snapping()\")",
		"func is_snapping() -> bool:",
		"\treturn is_snapping_flag",
		"",
		"## @ace_expression",
		"## @ace_name(\"Drag Point X\")",
		"## @ace_category(\"Drag & Drop\")",
		"func drag_point_x() -> float:",
		"\treturn drag_point.x",
		"",
		"## @ace_expression",
		"## @ace_name(\"Drag Point Y\")",
		"## @ace_category(\"Drag & Drop\")",
		"func drag_point_y() -> float:",
		"\treturn drag_point.y",
		"",
		"## @ace_expression",
		"## @ace_name(\"Drag Point Object UID\")",
		"## @ace_category(\"Drag & Drop\")",
		"func drag_point_object_uid() -> int:",
		"\treturn follow_uid",
		"",
		"## @ace_expression",
		"## @ace_name(\"Distance From Point\")",
		"## @ace_category(\"Drag & Drop\")",
		"func distance_from_point_value() -> float:",
		"\treturn distance_from_point",
		"",
		"## @ace_expression",
		"## @ace_name(\"Throw Velocity X\")",
		"## @ace_category(\"Drag & Drop\")",
		"func throw_velocity_x() -> float:",
		"\treturn throw_vel.x",
		"",
		"## @ace_expression",
		"## @ace_name(\"Throw Velocity Y\")",
		"## @ace_category(\"Drag & Drop\")",
		"func throw_velocity_y() -> float:",
		"\treturn throw_vel.y",
		"",
		"## @ace_expression",
		"## @ace_name(\"Throw Speed\")",
		"## @ace_category(\"Drag & Drop\")",
		"func throw_speed_value() -> float:",
		"\treturn throw_speed",
		"",
		"## @ace_expression",
		"## @ace_name(\"Drop Reason\")",
		"## @ace_category(\"Drag & Drop\")",
		"func drop_reason_value() -> String:",
		"\treturn drop_reason",
		"",
		"## @ace_expression",
		"## @ace_name(\"Snap Target X\")",
		"## @ace_category(\"Drag & Drop\")",
		"func snap_target_x() -> float:",
		"\treturn snap_target.x",
		"",
		"## @ace_expression",
		"## @ace_name(\"Snap Target Y\")",
		"## @ace_category(\"Drag & Drop\")",
		"func snap_target_y() -> float:",
		"\treturn snap_target.y",
		"",
		"## @ace_expression",
		"## @ace_name(\"Snapped Object UID\")",
		"## @ace_category(\"Drag & Drop\")",
		"func snapped_object_uid() -> int:",
		"\treturn snapped_uid",
		"",
		"func _constrain_step(step: Vector2) -> Vector2:",
		"\tmatch directions:",
		"\t\t1: return Vector2(0.0, step.y)",
		"\t\t2: return Vector2(step.x, 0.0)",
		"\t\t3: return Vector2(step.x, 0.0) if absf(step.x) >= absf(step.y) else Vector2(0.0, step.y)",
		"\t\t4:",
		"\t\t\tvar ang := snappedf(atan2(step.y, step.x), PI / 4.0)",
		"\t\t\tvar dir := Vector2(cos(ang), sin(ang))",
		"\t\t\treturn dir * (step.x * dir.x + step.y * dir.y)",
		"\t\t_: return step",
		"",
		"func _snap_points() -> Array:",
		"\tvar pts: Array = snap_positions.duplicate()",
		"\tfor id in snap_uids:",
		"\t\tvar n := instance_from_id(id)",
		"\t\tif is_instance_valid(n) and n != host:",
		"\t\t\tpts.append(n.global_position)",
		"\treturn pts",
		"",
		"func _nearest_snap(ref: Vector2) -> Vector2:",
		"\tvar best := ref",
		"\tvar best_d := INF",
		"\tfor p in _snap_points():",
		"\t\tvar d: float = ref.distance_to(p)",
		"\t\tif d < best_d:",
		"\t\t\tbest_d = d",
		"\t\t\tbest = p",
		"\treturn best",
		"",
		"## Overlap-mode proximity. With a positive snap_radius we honour it; otherwise (the v1",
		"## radius approximation of shape-overlap) we derive a sane extent from the host's first",
		"## CollisionShape2D so overlap snapping actually engages instead of degenerating to a",
		"## sub-pixel threshold. Falls back to 32px when no shape is present.",
		"func _overlap_proximity() -> float:",
		"\tif snap_radius > 0.0:",
		"\t\treturn snap_radius",
		"\tvar extent := 0.0",
		"\tif host != null:",
		"\t\tfor child in host.get_children():",
		"\t\t\tvar cs := child as CollisionShape2D",
		"\t\t\tif cs != null and cs.shape != null:",
		"\t\t\t\tvar r: Rect2 = cs.shape.get_rect()",
		"\t\t\t\textent = maxf(r.size.x, r.size.y) * 0.5",
		"\t\t\t\tbreak",
		"\treturn extent if extent > 0.0 else 32.0",
		"",
		"## Single source of truth for throw samples: push the per-frame drag-point velocity",
		"## into the 8-slot ring buffer whenever the drag point actually moves while dragging,",
		"## then advance it. Called from set_drag_point(_to_object) AND the glued-follow path so",
		"## the final pre-Drop flick (which can land on the same frame as Drop) is captured.",
		"func _sample_throw(new_point: Vector2) -> void:",
		"\tif not dragging:",
		"\t\tdrag_point = new_point",
		"\t\tprev_drag_point = new_point",
		"\t\treturn",
		"\tvar dt := get_process_delta_time()",
		"\tif dt > 0.0 and new_point != drag_point:",
		"\t\tvar v := (new_point - drag_point) / dt",
		"\t\tif throw_history.size() < 8:",
		"\t\t\tthrow_history.append(v)",
		"\t\telse:",
		"\t\t\tthrow_history[throw_cursor] = v",
		"\t\t\tthrow_cursor = (throw_cursor + 1) % 8",
		"\tdrag_point = new_point",
		"\tprev_drag_point = new_point",
		"",
		"func _end_drag(apply_throw: bool, reason: String) -> void:",
		"\tdrop_reason = reason",
		"\tsnapped_uid = -1",
		"\tvar did_snap := false",
		"\tif apply_throw and is_snapping_flag:",
		"\t\thost.global_position = snap_target",
		"\t\tdid_snap = true",
		"\t\tfor id in snap_uids:",
		"\t\t\tvar n := instance_from_id(id)",
		"\t\t\tif is_instance_valid(n) and n.global_position.distance_to(snap_target) < 0.01:",
		"\t\t\t\tsnapped_uid = id",
		"\t\t\t\tbreak",
		"\tif apply_throw and not did_snap:",
		"\t\tif has_throw_override:",
		"\t\t\tthrow_vel = override_throw",
		"\t\telse:",
		"\t\t\tvar sum := Vector2.ZERO",
		"\t\t\tfor v in throw_history:",
		"\t\t\t\tsum += v",
		"\t\t\tthrow_vel = sum / throw_history.size() if throw_history.size() > 0 else Vector2.ZERO",
		"\telse:",
		"\t\tthrow_vel = Vector2.ZERO",
		"\tthrow_speed = throw_vel.length()",
		"\tdragging = false",
		"\tfollow_uid = -1",
		"\thas_throw_override = false",
		"\tis_snapping_flag = false",
		"\tthrow_history = PackedVector2Array()",
		"\tif apply_throw:",
		"\t\tdropped.emit()",
		"\telse:",
		"\t\tdrag_cancelled.emit()",
		"\tif did_snap:",
		"\t\tsnapped.emit()"
	]))
	sheet.events.append(block)

	# Per-frame follow / direction-lock / magnet / throw-history / break-distance.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not enabled or not dragging or host == null:",
		"\treturn",
		"if follow_uid != -1:",
		"\tvar n := instance_from_id(follow_uid)",
		"\tif is_instance_valid(n):",
		"\t\t_sample_throw(n.global_position)",
		"\telse:",
		"\t\tfollow_uid = -1",
		"var target := drag_point + grab_offset",
		"if directions != 0:",
		"\ttarget = host.global_position + _constrain_step(target - host.global_position)",
		"if snap_radius > 0.0 and magnet_strength > 0.0 and not _snap_points().is_empty():",
		"\tvar near := _nearest_snap(target)",
		"\tvar dist := target.distance_to(near)",
		"\tif dist <= snap_radius:",
		"\t\tvar proximity := clampf(1.0 - dist / snap_radius, 0.0, 1.0)",
		"\t\tvar factor := clampf(magnet_strength * proximity, 0.0, 1.0)",
		"\t\ttarget = target.lerp(near, factor)",
		"if follow_speed > 0.0 and delta > 0.0:",
		"\thost.global_position = host.global_position.move_toward(target, follow_speed * delta)",
		"else:",
		"\thost.global_position = target",
		"distance_from_point = host.global_position.distance_to(drag_point)",
		"var ref := host.global_position if snap_mode == 0 else drag_point",
		"var near2 := _nearest_snap(ref)",
		"# Overlap mode (1) gates on a derived proximity so snap_radius==0 still engages;",
		"# radius mode (0) keeps the exact snap_radius gate.",
		"var gate := _overlap_proximity() if snap_mode == 1 else snap_radius",
		"if not _snap_points().is_empty() and ref.distance_to(near2) <= gate:",
		"\tsnap_target = near2",
		"\tis_snapping_flag = true",
		"else:",
		"\tis_snapping_flag = false",
		"\tsnap_target = near2 if not _snap_points().is_empty() else host.global_position",
		"if break_distance > 0.0 and distance_from_point > break_distance:",
		"\t_end_drag(break_action != 1, \"broke_distance\")"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# Actions.
	Lib.append_function(sheet, "start_drag", "Start Drag", "Drag & Drop",
		"Begins a drag at a point. grab_mode 0 = keep offset from the host; 1 = centre on the point.",
		[["drag_point_x", "float"], ["drag_point_y", "float"], ["grab_mode", "int"]], "\n".join(PackedStringArray([
		"if not enabled or dragging or host == null:",
		"\treturn",
		"drag_point = Vector2(drag_point_x, drag_point_y)",
		"prev_drag_point = drag_point",
		"grab_offset = (host.global_position - drag_point) if grab_mode == 0 else Vector2.ZERO",
		"dragging = true",
		"follow_uid = -1",
		"drop_reason = \"manual\"",
		"has_throw_override = false",
		"throw_history = PackedVector2Array()",
		"throw_cursor = 0",
		"is_snapping_flag = false",
		"drag_started.emit()"
	])))

	Lib.append_function(sheet, "start_drag_at_object", "Start Drag At Object", "Drag & Drop",
		"Begins a drag that follows the given object each tick.",
		[["target", "Node2D"], ["grab_mode", "int"]], "\n".join(PackedStringArray([
		"if target == null:",
		"\treturn",
		"start_drag(target.global_position.x, target.global_position.y, grab_mode)",
		"if dragging:",
		"\tfollow_uid = target.get_instance_id()"
	])))

	Lib.append_function(sheet, "drop_drag", "Drop", "Drag & Drop",
		"Ends the drag. how 0 = apply throw/snap; 1 = cancel silently.",
		[["how", "int"]], "\n".join(PackedStringArray([
		"if not dragging:",
		"\treturn",
		"drop_reason = \"manual\"",
		"_end_drag(how == 0, \"manual\")"
	])))

	Lib.append_function(sheet, "set_drag_point", "Set Drag Point", "Drag & Drop",
		"Updates the drag point (call each tick from your input source).",
		[["x", "float"], ["y", "float"]], "\n".join(PackedStringArray([
		"if is_finite(x) and is_finite(y):",
		"\t_sample_throw(Vector2(x, y))",
		"follow_uid = -1"
	])))

	Lib.append_function(sheet, "set_drag_point_to_object", "Set Drag Point To Object", "Drag & Drop",
		"Sets the drag point to an object's current position (one-shot).",
		[["target", "Node2D"]], "\n".join(PackedStringArray([
		"if target != null:",
		"\t_sample_throw(target.global_position)",
		"\tfollow_uid = -1"
	])))

	Lib.append_function(sheet, "set_follow_speed", "Set Follow Speed", "Drag & Drop",
		"Max catch-up speed (px/s); 0 = instant snap each tick.",
		[["speed", "float"]], "\n".join(PackedStringArray([
		"follow_speed = maxf(0.0, speed)"
	])))

	Lib.append_function(sheet, "set_directions", "Set Directions", "Drag & Drop",
		"Direction lock: 0 free, 1 up/down, 2 left/right, 3 four-dir, 4 eight-dir.",
		[["dirs", "int"]], "\n".join(PackedStringArray([
		"directions = clampi(dirs, 0, 4)"
	])))

	Lib.append_function(sheet, "set_break_distance", "Set Break Distance", "Drag & Drop",
		"Auto-end the drag past this gap; action 0 = drop, 1 = cancel. 0 distance disables.",
		[["distance", "float"], ["action", "int"]], "\n".join(PackedStringArray([
		"break_distance = maxf(0.0, distance)",
		"break_action = action"
	])))

	Lib.append_function(sheet, "set_throw_velocity", "Set Throw Velocity", "Drag & Drop",
		"Overrides the auto-measured throw velocity for the next drop.",
		[["velocity_x", "float"], ["velocity_y", "float"]], "\n".join(PackedStringArray([
		"override_throw = Vector2(velocity_x, velocity_y)",
		"has_throw_override = true"
	])))

	Lib.append_function(sheet, "set_dragdrop_enabled", "Set Enabled", "Drag & Drop",
		"Enables/disables; disabling mid-drag cancels silently.",
		[["is_enabled", "bool"]], "\n".join(PackedStringArray([
		"enabled = is_enabled",
		"if not is_enabled and dragging:",
		"\tdragging = false",
		"\tfollow_uid = -1",
		"\thas_throw_override = false",
		"\tis_snapping_flag = false",
		"\tthrow_history = PackedVector2Array()"
	])))

	Lib.append_function(sheet, "add_snap_position", "Add Snap Position", "Drag & Drop",
		"Registers a fixed snap/magnet position.",
		[["x", "float"], ["y", "float"]], "\n".join(PackedStringArray([
		"snap_positions.append(Vector2(x, y))"
	])))

	Lib.append_function(sheet, "add_snap_object", "Add Snap Object", "Drag & Drop",
		"Registers an object whose position is a live snap/magnet target.",
		[["target", "Node2D"]], "\n".join(PackedStringArray([
		"if target != null:",
		"\tvar id := target.get_instance_id()",
		"\tif not snap_uids.has(id):",
		"\t\tsnap_uids.append(id)"
	])))

	Lib.append_function(sheet, "clear_snap_targets", "Clear Snap Targets", "Drag & Drop",
		"Removes every snap position and object.",
		[], "\n".join(PackedStringArray([
		"snap_positions.clear()",
		"snap_uids.clear()",
		"is_snapping_flag = false"
	])))

	Lib.append_function(sheet, "set_snap_radius", "Set Snap Radius", "Drag & Drop",
		"Distance within which snapping/magnetism engages.",
		[["radius", "float"]], "\n".join(PackedStringArray([
		"snap_radius = maxf(0.0, radius)"
	])))

	Lib.append_function(sheet, "set_snap_mode", "Set Snap Mode", "Drag & Drop",
		"0 = host-position proximity; 1 = drag-point overlap (v1 radius approximation).",
		[["mode", "int"]], "\n".join(PackedStringArray([
		"snap_mode = clampi(mode, 0, 1)"
	])))

	Lib.append_function(sheet, "set_magnet_strength", "Set Magnet Strength", "Drag & Drop",
		"How strongly the drag is pulled toward a nearby snap target (0..1).",
		[["strength", "float"]], "\n".join(PackedStringArray([
		"magnet_strength = clampf(strength, 0.0, 1.0)"
	])))

	return Lib.save_pack(sheet, "res://eventsheet_addons/drag_drop/drag_drop_behavior")
