## @ace_category("Drag & Drop")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/drag_drop/icon.svg")
class_name DragDropBehavior
extends Node
## Makes any 2D node something you can pick up, move, snap into place, and throw, with follow lag, axis locking, magnetism, break-distance auto-drop, and a measured throw velocity on release. Event-driven: you feed it a drag point from any source (mouse, touch, gamepad, AI) and it handles the rest.

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("DragDropBehavior behavior requires a Node2D parent.")

## @ace_trigger
## @ace_name("On Drag Started")
signal drag_started
## @ace_trigger
## @ace_name("On Dropped")
signal dropped
## @ace_trigger
## @ace_name("On Drag Cancelled")
signal drag_cancelled
## @ace_trigger
## @ace_name("On Snapped")
signal snapped

var break_action: int = 0
## Gap that auto-ends the drag; 0 disables.
@export var break_distance: float = 0.0
var distance_from_point: float = 0.0
var dragging: bool = false
var drop_reason: String = "manual"
## Active at start; disabling mid-drag cancels silently.
@export var enabled: bool = true
## Max catch-up speed (px/s); 0 = instant snap each tick.
@export var follow_speed: float = 0.0
var follow_uid: int = -1
var has_throw_override: bool = false
var is_snapping_flag: bool = false
var magnet_strength: float = 0.0
var snap_mode: int = 0
var snap_positions: Array = []
var snap_radius: float = 0.0
var snap_uids: Array[int] = []
var snapped_uid: int = -1
var throw_cursor: int = 0
var throw_speed: float = 0.0

## Per-tick movement lock (8Direction style).
@export_enum("free", "up_down", "left_right", "four_dir", "eight_dir") var directions: int = 0
var drag_point: Vector2 = Vector2.ZERO
var prev_drag_point: Vector2 = Vector2.ZERO
var grab_offset: Vector2 = Vector2.ZERO
var throw_vel: Vector2 = Vector2.ZERO
var override_throw: Vector2 = Vector2.ZERO
var snap_target: Vector2 = Vector2.ZERO
var throw_history: PackedVector2Array = PackedVector2Array()

func _process(delta: float) -> void:
	if not enabled or not dragging or host == null:
		return
	if follow_uid != -1:
		var n := instance_from_id(follow_uid)
		if is_instance_valid(n):
			_sample_throw(n.global_position)
		else:
			follow_uid = -1
	var target := drag_point + grab_offset
	if directions != 0:
		target = host.global_position + _constrain_step(target - host.global_position)
	if snap_radius > 0.0 and magnet_strength > 0.0 and not _snap_points().is_empty():
		var near := _nearest_snap(target)
		var dist := target.distance_to(near)
		if dist <= snap_radius:
			var proximity := clampf(1.0 - dist / snap_radius, 0.0, 1.0)
			var factor := clampf(magnet_strength * proximity, 0.0, 1.0)
			target = target.lerp(near, factor)
	if follow_speed > 0.0 and delta > 0.0:
		host.global_position = host.global_position.move_toward(target, follow_speed * delta)
	else:
		host.global_position = target
	distance_from_point = host.global_position.distance_to(drag_point)
	var ref := host.global_position if snap_mode == 0 else drag_point
	var near2 := _nearest_snap(ref)
	# Overlap mode (1) gates on a derived proximity so snap_radius==0 still engages;
	# radius mode (0) keeps the exact snap_radius gate.
	var gate := _overlap_proximity() if snap_mode == 1 else snap_radius
	if not _snap_points().is_empty() and ref.distance_to(near2) <= gate:
		snap_target = near2
		is_snapping_flag = true
	else:
		is_snapping_flag = false
		snap_target = near2 if not _snap_points().is_empty() else host.global_position
	if break_distance > 0.0 and distance_from_point > break_distance:
		_end_drag(break_action != 1, "broke_distance")

## @ace_action
## @ace_featured
## @ace_name("Start Drag")
## @ace_category("Drag & Drop")
## @ace_description("Begins a drag at a point. grab_mode 0 = keep offset from the host; 1 = centre on the point.")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.start_drag({drag_point_x}, {drag_point_y}, {grab_mode})")
func start_drag(drag_point_x: float, drag_point_y: float, grab_mode: int) -> void:
	if not enabled or dragging or host == null:
		return
	drag_point = Vector2(drag_point_x, drag_point_y)
	prev_drag_point = drag_point
	grab_offset = (host.global_position - drag_point) if grab_mode == 0 else Vector2.ZERO
	dragging = true
	follow_uid = -1
	drop_reason = "manual"
	has_throw_override = false
	throw_history = PackedVector2Array()
	throw_cursor = 0
	is_snapping_flag = false
	drag_started.emit()

## @ace_action
## @ace_name("Start Drag At Object")
## @ace_category("Drag & Drop")
## @ace_description("Begins a drag that follows the given object each tick.")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.start_drag_at_object({target}, {grab_mode})")
func start_drag_at_object(target: Node2D, grab_mode: int) -> void:
	if target == null:
		return
	start_drag(target.global_position.x, target.global_position.y, grab_mode)
	if dragging:
		follow_uid = target.get_instance_id()

## @ace_action
## @ace_featured
## @ace_name("Drop")
## @ace_category("Drag & Drop")
## @ace_description("Ends the drag. how 0 = apply throw/snap; 1 = cancel silently.")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.drop_drag({how})")
func drop_drag(how: int) -> void:
	if not dragging:
		return
	drop_reason = "manual"
	_end_drag(how == 0, "manual")

## @ace_action
## @ace_name("Set Drag Point")
## @ace_category("Drag & Drop")
## @ace_description("Updates the drag point (call each tick from your input source).")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.set_drag_point({x}, {y})")
func set_drag_point(x: float, y: float) -> void:
	if is_finite(x) and is_finite(y):
		_sample_throw(Vector2(x, y))
	follow_uid = -1

## @ace_action
## @ace_name("Set Drag Point To Object")
## @ace_category("Drag & Drop")
## @ace_description("Sets the drag point to an object's current position (one-shot).")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.set_drag_point_to_object({target})")
func set_drag_point_to_object(target: Node2D) -> void:
	if target != null:
		_sample_throw(target.global_position)
		follow_uid = -1

## @ace_action
## @ace_name("Set Follow Speed")
## @ace_category("Drag & Drop")
## @ace_description("Max catch-up speed (px/s); 0 = instant snap each tick.")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.set_follow_speed({speed})")
func set_follow_speed(speed: float) -> void:
	follow_speed = maxf(0.0, speed)

## @ace_action
## @ace_name("Set Directions")
## @ace_category("Drag & Drop")
## @ace_description("Direction lock: 0 free, 1 up/down, 2 left/right, 3 four-dir, 4 eight-dir.")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.set_directions({dirs})")
func set_directions(dirs: int) -> void:
	directions = clampi(dirs, 0, 4)

## @ace_action
## @ace_name("Set Break Distance")
## @ace_category("Drag & Drop")
## @ace_description("Auto-end the drag past this gap; action 0 = drop, 1 = cancel. 0 distance disables.")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.set_break_distance({distance}, {action})")
func set_break_distance(distance: float, action: int) -> void:
	break_distance = maxf(0.0, distance)
	break_action = action

## @ace_action
## @ace_name("Set Throw Velocity")
## @ace_category("Drag & Drop")
## @ace_description("Overrides the auto-measured throw velocity for the next drop.")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.set_throw_velocity({velocity_x}, {velocity_y})")
func set_throw_velocity(velocity_x: float, velocity_y: float) -> void:
	override_throw = Vector2(velocity_x, velocity_y)
	has_throw_override = true

## @ace_action
## @ace_name("Set Enabled")
## @ace_category("Drag & Drop")
## @ace_description("Enables/disables; disabling mid-drag cancels silently.")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.set_dragdrop_enabled({is_enabled})")
func set_dragdrop_enabled(is_enabled: bool) -> void:
	enabled = is_enabled
	if not is_enabled and dragging:
		dragging = false
		follow_uid = -1
		has_throw_override = false
		is_snapping_flag = false
		throw_history = PackedVector2Array()

## @ace_action
## @ace_name("Add Snap Position")
## @ace_category("Drag & Drop")
## @ace_description("Registers a fixed snap/magnet position.")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.add_snap_position({x}, {y})")
func add_snap_position(x: float, y: float) -> void:
	snap_positions.append(Vector2(x, y))

## @ace_action
## @ace_name("Add Snap Object")
## @ace_category("Drag & Drop")
## @ace_description("Registers an object whose position is a live snap/magnet target.")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.add_snap_object({target})")
func add_snap_object(target: Node2D) -> void:
	if target != null:
		var id := target.get_instance_id()
		if not snap_uids.has(id):
			snap_uids.append(id)

## @ace_action
## @ace_name("Clear Snap Targets")
## @ace_category("Drag & Drop")
## @ace_description("Removes every snap position and object.")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.clear_snap_targets()")
func clear_snap_targets() -> void:
	snap_positions.clear()
	snap_uids.clear()
	is_snapping_flag = false

## @ace_action
## @ace_name("Set Snap Radius")
## @ace_category("Drag & Drop")
## @ace_description("Distance within which snapping/magnetism engages.")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.set_snap_radius({radius})")
func set_snap_radius(radius: float) -> void:
	snap_radius = maxf(0.0, radius)

## @ace_action
## @ace_name("Set Snap Mode")
## @ace_category("Drag & Drop")
## @ace_description("0 = host-position proximity; 1 = drag-point overlap (v1 radius approximation).")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.set_snap_mode({mode})")
func set_snap_mode(mode: int) -> void:
	snap_mode = clampi(mode, 0, 1)

## @ace_action
## @ace_name("Set Magnet Strength")
## @ace_category("Drag & Drop")
## @ace_description("How strongly the drag is pulled toward a nearby snap target (0..1).")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.set_magnet_strength({strength})")
func set_magnet_strength(strength: float) -> void:
	magnet_strength = clampf(strength, 0.0, 1.0)

## @ace_condition
## @ace_name("Is Dragging")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.is_dragging()")
func is_dragging() -> bool:
	return dragging

## @ace_condition
## @ace_name("Is Enabled")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.is_dragdrop_enabled()")
func is_dragdrop_enabled() -> bool:
	return enabled

## @ace_condition
## @ace_name("Is Snapping")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.is_snapping()")
func is_snapping() -> bool:
	return is_snapping_flag

## @ace_expression
## @ace_name("Drag Point X")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.drag_point_x()")
func drag_point_x() -> float:
	return drag_point.x

## @ace_expression
## @ace_name("Drag Point Y")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.drag_point_y()")
func drag_point_y() -> float:
	return drag_point.y

## @ace_expression
## @ace_name("Drag Point Object UID")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.drag_point_object_uid()")
func drag_point_object_uid() -> int:
	return follow_uid

## @ace_expression
## @ace_name("Distance From Point")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.distance_from_point_value()")
func distance_from_point_value() -> float:
	return distance_from_point

## @ace_expression
## @ace_name("Throw Velocity X")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.throw_velocity_x()")
func throw_velocity_x() -> float:
	return throw_vel.x

## @ace_expression
## @ace_name("Throw Velocity Y")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.throw_velocity_y()")
func throw_velocity_y() -> float:
	return throw_vel.y

## @ace_expression
## @ace_name("Throw Speed")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.throw_speed_value()")
func throw_speed_value() -> float:
	return throw_speed

## @ace_expression
## @ace_name("Drop Reason")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.drop_reason_value()")
func drop_reason_value() -> String:
	return drop_reason

## @ace_expression
## @ace_name("Snap Target X")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.snap_target_x()")
func snap_target_x() -> float:
	return snap_target.x

## @ace_expression
## @ace_name("Snap Target Y")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.snap_target_y()")
func snap_target_y() -> float:
	return snap_target.y

## @ace_expression
## @ace_name("Snapped Object UID")
## @ace_icon("res://eventsheet_addons/drag_drop/icon.svg")
## @ace_codegen_template("$DragDropBehavior.snapped_object_uid()")
func snapped_object_uid() -> int:
	return snapped_uid

func _constrain_step(step: Vector2) -> Vector2:
	match directions:
		1: return Vector2(0.0, step.y)
		2: return Vector2(step.x, 0.0)
		3: return Vector2(step.x, 0.0) if absf(step.x) >= absf(step.y) else Vector2(0.0, step.y)
		4:
			var ang := snappedf(atan2(step.y, step.x), PI / 4.0)
			var dir := Vector2(cos(ang), sin(ang))
			return dir * (step.x * dir.x + step.y * dir.y)
		_: return step

func _snap_points() -> Array:
	var pts: Array = snap_positions.duplicate()
	for id in snap_uids:
		var n := instance_from_id(id)
		if is_instance_valid(n) and n != host:
			pts.append(n.global_position)
	return pts

func _nearest_snap(ref: Vector2) -> Vector2:
	var best := ref
	var best_d := INF
	for p in _snap_points():
		var d: float = ref.distance_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best

## Overlap-mode proximity. With a positive snap_radius we honour it; otherwise (the v1
## radius approximation of shape-overlap) we derive a sane extent from the host's first
## CollisionShape2D so overlap snapping actually engages instead of degenerating to a
## sub-pixel threshold. Falls back to 32px when no shape is present.
func _overlap_proximity() -> float:
	if snap_radius > 0.0:
		return snap_radius
	var extent := 0.0
	if host != null:
		for child in host.get_children():
			var cs := child as CollisionShape2D
			if cs != null and cs.shape != null:
				var r: Rect2 = cs.shape.get_rect()
				extent = maxf(r.size.x, r.size.y) * 0.5
				break
	return extent if extent > 0.0 else 32.0

## Single source of truth for throw samples: push the per-frame drag-point velocity
## into the 8-slot ring buffer whenever the drag point actually moves while dragging,
## then advance it. Called from set_drag_point(_to_object) AND the glued-follow path so
## the final pre-Drop flick (which can land on the same frame as Drop) is captured.
func _sample_throw(new_point: Vector2) -> void:
	if not dragging:
		drag_point = new_point
		prev_drag_point = new_point
		return
	var dt := get_process_delta_time()
	if dt > 0.0 and new_point != drag_point:
		var v := (new_point - drag_point) / dt
		if throw_history.size() < 8:
			throw_history.append(v)
		else:
			throw_history[throw_cursor] = v
			throw_cursor = (throw_cursor + 1) % 8
	drag_point = new_point
	prev_drag_point = new_point

func _end_drag(apply_throw: bool, reason: String) -> void:
	drop_reason = reason
	snapped_uid = -1
	var did_snap := false
	if apply_throw and is_snapping_flag:
		host.global_position = snap_target
		did_snap = true
		for id in snap_uids:
			var n := instance_from_id(id)
			if is_instance_valid(n) and n.global_position.distance_to(snap_target) < 0.01:
				snapped_uid = id
				break
	if apply_throw and not did_snap:
		if has_throw_override:
			throw_vel = override_throw
		else:
			var sum := Vector2.ZERO
			for v in throw_history:
				sum += v
			throw_vel = sum / throw_history.size() if throw_history.size() > 0 else Vector2.ZERO
	else:
		throw_vel = Vector2.ZERO
	throw_speed = throw_vel.length()
	dragging = false
	follow_uid = -1
	has_throw_override = false
	is_snapping_flag = false
	throw_history = PackedVector2Array()
	if apply_throw:
		dropped.emit()
	else:
		drag_cancelled.emit()
	if did_snap:
		snapped.emit()

# Drag & Drop behavior (event-sheet parity, event-driven): the author feeds the drag point each tick (virtual cursor, gamepad, touch, AI) - never polls Input. Follow-speed lag, direction lock, break-distance auto-drop, snapping/magnetism, auto-measured throw velocity (routed by you in On Dropped). NOTE: overlap snap mode is a v1 radius-distance simplification (true shape-overlap is a follow-up).
