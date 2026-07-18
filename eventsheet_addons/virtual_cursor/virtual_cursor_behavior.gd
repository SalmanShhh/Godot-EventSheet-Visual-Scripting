## @ace_category("Virtual Cursor")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/virtual_cursor/icon.svg")
class_name VirtualCursor
extends Node
## Turns a CharacterBody2D into an input-agnostic pointer: it accelerates and decelerates, bumps into solids, bounces off walls, snaps to targets with a homing magnet, stays inside a play area, reports what it is hovering, and fires named interact buttons. Drive it with the mouse, keys, an analog axis, or scripted moves - it is any thing you steer, not the OS pointer.

## The node this behavior acts on (its parent). Required host: CharacterBody2D.
var host: CharacterBody2D = null

func _enter_tree() -> void:
	host = get_parent() as CharacterBody2D
	if host == null:
		push_warning("VirtualCursor behavior requires a CharacterBody2D parent.")

## @ace_trigger
## @ace_name("On Interact Pressed")
signal interact_pressed(id: String)
## @ace_trigger
## @ace_name("On Interact Released")
signal interact_released(id: String)
## @ace_trigger
## @ace_name("On Layout Edge Hit")
signal layout_edge_hit
## @ace_trigger
## @ace_name("On Cursor Arrived")
signal cursor_arrived
## @ace_trigger
## @ace_name("On Homing Target Entered")
signal homing_target_entered
## @ace_trigger
## @ace_name("On Homing Target Exited")
signal homing_target_exited
## @ace_trigger
## @ace_name("On Homing Snapped")
signal homing_snapped
## @ace_trigger
## @ace_name("On Solid Hit")
signal solid_hit
## @ace_trigger
## @ace_name("On Bounce")
signal bounce_triggered

## Speed-up rate while axis held (px/s^2).
@export var acceleration: float = 1800.0
## AI drive: read ai_move_x/ai_move_y instead of the ui_* actions (a sheet or AI driver flips this on to steer the cursor).
@export var ai_controlled: bool = false
var ai_move_x: float = 0.0
var ai_move_y: float = 0.0
## Slide along solids instead of hard-stop.
@export var allow_sliding: bool = true
var blocked_this_tick: bool = false
## Clamp inside the viewport/constraint bounds.
@export var constrain_to_layout: bool = false
## Slow-down rate when axis released (px/s^2).
@export var deceleration: float = 2400.0
## Read ui_left/right/up/down each tick (keyboard+gamepad).
@export var default_controls: bool = true
var edge_hit_prev: bool = false
## Master on/off.
@export var enabled: bool = true
var has_constraint_bounds: bool = false
var has_mouse_target: bool = false
var has_simulated_axis: bool = false
var homing_enabled: bool = false
var homing_mode: int = 0
var homing_radius: float = 120.0
var homing_snapped_uid: int = -1
var homing_strength: float = 0.5
var homing_targets: Array = []
var hovered_uid: int = -1
var ignoring_input: bool = false
var in_homing_range: bool = false
var interact_states: Dictionary = {}
var last_pressed_id: String = ""
var last_released_id: String = ""
## Max cursor speed (px/s).
@export var max_speed: float = 600.0
var mouse_smoothing: float = 0.15
var nearest_homing_dist: float = -1.0
var nearest_homing_uid: int = -1
var solid_collision: bool = true
var solid_uid: int = -1
var solids: Array = []

## Movement axis constraint.
@export_enum("up_down", "left_right", "four", "eight") var direction_mode: int = 3
## Point = origin inside shape; Overlap = shapes overlap.
@export_enum("point", "overlap") var hover_mode: int = 0
## Which surfaces reflect the cursor losslessly.
@export_enum("none", "solids", "constraints", "both") var bounce_mode: int = 0
var vel: Vector2 = Vector2.ZERO
var report_vel: Vector2 = Vector2.ZERO
var axis: Vector2 = Vector2.ZERO
var simulated_axis: Vector2 = Vector2.ZERO
var mouse_target: Vector2 = Vector2.ZERO
var constraint_bounds: Rect2 = Rect2()

func _point_shape() -> Shape2D:
	var s := CircleShape2D.new()
	s.radius = 0.5
	return s
## Transform a local-space Rect2 into a world-space AABB by mapping its four corners.
func _xform_rect(xform: Transform2D, r: Rect2) -> Rect2:
	var p0 := xform * r.position
	var out := Rect2(p0, Vector2.ZERO)
	out = out.expand(xform * Vector2(r.position.x + r.size.x, r.position.y))
	out = out.expand(xform * Vector2(r.position.x, r.position.y + r.size.y))
	out = out.expand(xform * (r.position + r.size))
	return out
func _resolve_bounds() -> Rect2:
	if has_constraint_bounds:
		return constraint_bounds
	if host != null and host.get_viewport() != null:
		return host.get_viewport().get_visible_rect()
	return Rect2(0, 0, 1920, 1080)

func _physics_process(delta: float) -> void:
	if not enabled or host == null:
		report_vel = Vector2.ZERO
		return
	# 1) VELOCITY: resolve axis.
	if ignoring_input:
		axis = Vector2.ZERO
	elif has_simulated_axis:
		axis = simulated_axis.limit_length(1.0)
		simulated_axis = Vector2.ZERO
		has_simulated_axis = false
	elif ai_controlled:
		# The AI seam: a driver holds ai_move_x/ai_move_y - the same persistent-axis
		# contract the movement packs carry (one write drives until changed).
		axis = Vector2(ai_move_x, ai_move_y).limit_length(1.0)
	elif default_controls:
		axis = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	else:
		axis = Vector2.ZERO
	if direction_mode == 0:
		axis.x = 0.0
	elif direction_mode == 1:
		axis.y = 0.0
	elif direction_mode == 2:
		if absf(axis.x) >= absf(axis.y):
			axis.y = 0.0
		else:
			axis.x = 0.0
	if has_mouse_target:
		var lerp_t := 1.0 - pow(1.0 - mouse_smoothing, delta * 60.0)
		var to := mouse_target - host.global_position
		var target_speed := minf(to.length() * mouse_smoothing * 60.0, max_speed)
		vel = vel.lerp(to.normalized() * target_speed, lerp_t)
		if to.length() < 0.5:
			vel *= 0.5
			has_mouse_target = false
			# The glide landed - the sequencing hook for scripted/AI cursor moves
			# (glide with Simulate Mouse, then press interact On Cursor Arrived).
			cursor_arrived.emit()
	elif axis != Vector2.ZERO:
		var dir := axis.normalized()
		var spd := minf(vel.length() + acceleration * delta, max_speed)
		vel = dir * spd
	else:
		var spd := maxf(vel.length() - deceleration * delta, 0.0)
		vel = vel.normalized() * spd if vel.length() > 0.0 else Vector2.ZERO
	# 2) HOMING (steer/snap, pre-move).
	if homing_enabled and not homing_targets.is_empty():
		var pruned: Array = []
		for id in homing_targets:
			if is_instance_valid(instance_from_id(id)):
				pruned.append(id)
		homing_targets = pruned
		var best_uid := -1
		var best_dist := -1.0
		var best_pos := host.global_position
		for id in homing_targets:
			var n := instance_from_id(id) as Node2D
			if n == null:
				continue
			var d: float = host.global_position.distance_to(n.global_position)
			if best_dist < 0.0 or d < best_dist:
				best_dist = d
				best_uid = id
				best_pos = n.global_position
		var within := best_uid != -1 and best_dist <= homing_radius
		if within and not in_homing_range:
			homing_target_entered.emit()
		elif not within and in_homing_range:
			homing_target_exited.emit()
		in_homing_range = within
		nearest_homing_uid = best_uid if within else -1
		nearest_homing_dist = best_dist if within else -1.0
		if within:
			var dir_to := (best_pos - host.global_position).normalized()
			if homing_mode == 0:
				homing_snapped_uid = -1
				vel = vel.lerp(dir_to * max_speed * homing_strength, minf(1.0, homing_strength * 6.0 * delta))
			else:
				if axis != Vector2.ZERO:
					homing_snapped_uid = -1
					vel += dir_to * max_speed * homing_strength * 4.0 * delta
					vel = vel.limit_length(max_speed)
				else:
					host.global_position = best_pos
					vel = Vector2.ZERO
					report_vel = Vector2.ZERO
					# Latch: emit once on a fresh snap, not every frame the cursor rests here.
					if homing_snapped_uid != best_uid:
						homing_snapped_uid = best_uid
						homing_snapped.emit()
		else:
			homing_snapped_uid = -1
	else:
		if in_homing_range:
			homing_target_exited.emit()
		in_homing_range = false
		nearest_homing_uid = -1
		nearest_homing_dist = -1.0
		homing_snapped_uid = -1
	# 3) MOVE + SOLIDS.
	host.velocity = vel
	host.move_and_slide()
	blocked_this_tick = host.get_slide_collision_count() > 0
	if blocked_this_tick:
		var col := host.get_last_slide_collision()
		solid_uid = col.get_collider().get_instance_id() if col != null and col.get_collider() != null else -1
		solid_hit.emit()
		if bounce_mode == 1 or bounce_mode == 3:
			for i in host.get_slide_collision_count():
				vel = vel.bounce(host.get_slide_collision(i).get_normal())
			bounce_triggered.emit()
		if not allow_sliding:
			vel = Vector2.ZERO
		else:
			vel = host.velocity
	# 4) CONSTRAIN.
	if constrain_to_layout:
		var b := _resolve_bounds()
		var p := host.global_position
		var cp := Vector2(clampf(p.x, b.position.x, b.end.x), clampf(p.y, b.position.y, b.end.y))
		var edge := cp != p
		if edge:
			host.global_position = cp
			if bounce_mode == 2 or bounce_mode == 3:
				if cp.x != p.x:
					vel.x = -vel.x
				if cp.y != p.y:
					vel.y = -vel.y
				bounce_triggered.emit()
			else:
				if cp.x != p.x:
					vel.x = 0.0
				if cp.y != p.y:
					vel.y = 0.0
		if edge and not edge_hit_prev:
			layout_edge_hit.emit()
		edge_hit_prev = edge
	# 5) report.
	report_vel = vel

## @ace_action
## @ace_featured
## @ace_name("Press Interact")
## @ace_category("Virtual Cursor")
## @ace_description("Marks a named interact button held and fires On Interact Pressed.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.press_interact({id})")
func press_interact(id: String) -> void:
	interact_states[id] = true
	last_pressed_id = id
	interact_pressed.emit(id)

## @ace_action
## @ace_name("Release Interact")
## @ace_category("Virtual Cursor")
## @ace_description("Marks a named interact button released and fires On Interact Released.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.release_interact({id})")
func release_interact(id: String) -> void:
	interact_states[id] = false
	last_released_id = id
	interact_released.emit(id)

## @ace_action
## @ace_name("Simulate Interact")
## @ace_category("Virtual Cursor")
## @ace_description("Fires a press+release of a named button in one tick.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.simulate_interact({id})")
func simulate_interact(id: String) -> void:
	if ignoring_input:
		return
	last_pressed_id = id
	last_released_id = id
	interact_pressed.emit(id)
	interact_released.emit(id)

## @ace_action
## @ace_name("Set Max Speed")
## @ace_category("Virtual Cursor")
## @ace_description("Sets the max cursor speed (px/s).")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_max_speed({speed})")
func set_max_speed(speed: float) -> void:
	max_speed = speed

## @ace_action
## @ace_name("Set Acceleration")
## @ace_category("Virtual Cursor")
## @ace_description("Sets the speed-up rate while an axis is held.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_acceleration({rate})")
func set_acceleration(rate: float) -> void:
	acceleration = rate

## @ace_action
## @ace_name("Set Deceleration")
## @ace_category("Virtual Cursor")
## @ace_description("Sets the slow-down rate when the axis is released.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_deceleration({rate})")
func set_deceleration(rate: float) -> void:
	deceleration = rate

## @ace_action
## @ace_name("Set Velocity")
## @ace_category("Virtual Cursor")
## @ace_description("Sets the cursor velocity directly.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_cursor_velocity({vel_x}, {vel_y})")
func set_cursor_velocity(vel_x: float, vel_y: float) -> void:
	vel = Vector2(vel_x, vel_y)
	report_vel = vel

## @ace_action
## @ace_name("Simulate Direct Mouse Position")
## @ace_category("Virtual Cursor")
## @ace_description("Teleports the cursor to a position, reporting the implied velocity.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.simulate_direct_mouse_position({target_x}, {target_y})")
func simulate_direct_mouse_position(target_x: float, target_y: float) -> void:
	if ignoring_input or host == null:
		return
	var dt: float = get_physics_process_delta_time()
	var new_pos := Vector2(target_x, target_y)
	if dt > 0.0:
		report_vel = (new_pos - host.global_position) / dt
	host.global_position = new_pos
	vel = Vector2.ZERO

## @ace_action
## @ace_name("Simulate Mouse")
## @ace_category("Virtual Cursor")
## @ace_description("Drives the cursor toward a target with smoothing (mouse-follow).")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.simulate_mouse({target_x}, {target_y}, {smoothing})")
func simulate_mouse(target_x: float, target_y: float, smoothing: float) -> void:
	if ignoring_input:
		return
	mouse_target = Vector2(target_x, target_y)
	mouse_smoothing = clampf(smoothing, 0.0, 1.0)
	has_mouse_target = true

## @ace_action
## @ace_featured
## @ace_name("Simulate Axis")
## @ace_category("Virtual Cursor")
## @ace_description("Feeds an analog axis for this tick (accel/decel applies).")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.simulate_axis({x}, {y})")
func simulate_axis(x: float, y: float) -> void:
	if ignoring_input:
		return
	simulated_axis += Vector2(x, y)
	has_simulated_axis = true

## @ace_action
## @ace_name("Simulate Control")
## @ace_category("Virtual Cursor")
## @ace_description("Feeds a cardinal direction (0 up, 1 down, 2 left, 3 right) for this tick.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.simulate_control({direction})")
func simulate_control(direction: int) -> void:
	if ignoring_input:
		return
	var dirs := [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]
	if direction >= 0 and direction < 4:
		simulated_axis += dirs[direction]
		has_simulated_axis = true

## @ace_action
## @ace_name("Set Homing Enabled")
## @ace_category("Virtual Cursor")
## @ace_description("Turns the homing magnet on/off.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_homing_enabled({is_enabled})")
func set_homing_enabled(is_enabled: bool) -> void:
	homing_enabled = is_enabled

## @ace_action
## @ace_name("Set Homing Mode")
## @ace_category("Virtual Cursor")
## @ace_description("0 steer, 1 snap-radius, 2 snap-overlap.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_homing_mode({mode})")
func set_homing_mode(mode: int) -> void:
	homing_mode = clampi(mode, 0, 2)

## @ace_action
## @ace_name("Set Homing Radius")
## @ace_category("Virtual Cursor")
## @ace_description("Sets the homing engagement radius.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_homing_radius({radius})")
func set_homing_radius(radius: float) -> void:
	homing_radius = maxf(0.0, radius)

## @ace_action
## @ace_name("Set Homing Strength")
## @ace_category("Virtual Cursor")
## @ace_description("How strongly the cursor is pulled toward a homing target (0..1).")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_homing_strength({strength})")
func set_homing_strength(strength: float) -> void:
	homing_strength = clampf(strength, 0.0, 1.0)

## @ace_action
## @ace_name("Add Homing Target")
## @ace_category("Virtual Cursor")
## @ace_description("Registers a node as a homing target.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.add_homing_target({target})")
func add_homing_target(target: Node2D) -> void:
	if target != null:
		var id := target.get_instance_id()
		if not homing_targets.has(id):
			homing_targets.append(id)

## @ace_action
## @ace_name("Remove Homing Target")
## @ace_category("Virtual Cursor")
## @ace_description("Unregisters a homing target.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.remove_homing_target({target})")
func remove_homing_target(target: Node2D) -> void:
	if target != null:
		homing_targets.erase(target.get_instance_id())

## @ace_action
## @ace_name("Clear Homing Targets")
## @ace_category("Virtual Cursor")
## @ace_description("Removes every homing target.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.clear_homing_targets()")
func clear_homing_targets() -> void:
	homing_targets.clear()
	in_homing_range = false
	nearest_homing_uid = -1
	nearest_homing_dist = -1.0
	homing_snapped_uid = -1

## @ace_action
## @ace_name("Add Solid")
## @ace_category("Virtual Cursor")
## @ace_description("Registers a node as a tracked solid (for SolidUID reporting).")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.add_solid({target})")
func add_solid(target: Node2D) -> void:
	if target != null:
		var id := target.get_instance_id()
		if not solids.has(id):
			solids.append(id)

## @ace_action
## @ace_name("Remove Solid")
## @ace_category("Virtual Cursor")
## @ace_description("Unregisters a tracked solid.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.remove_solid({target})")
func remove_solid(target: Node2D) -> void:
	if target != null:
		solids.erase(target.get_instance_id())

## @ace_action
## @ace_name("Clear Solids")
## @ace_category("Virtual Cursor")
## @ace_description("Clears the tracked-solids list.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.clear_solids()")
func clear_solids() -> void:
	solids.clear()

## @ace_action
## @ace_name("Set Solid Collision")
## @ace_category("Virtual Cursor")
## @ace_description("Toggles solid push-out via move_and_slide.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_solid_collision({is_enabled})")
func set_solid_collision(is_enabled: bool) -> void:
	solid_collision = is_enabled

## @ace_action
## @ace_name("Set Allow Sliding")
## @ace_category("Virtual Cursor")
## @ace_description("Slide along solids (true) or hard-stop (false).")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_allow_sliding({state})")
func set_allow_sliding(state: bool) -> void:
	allow_sliding = state

## @ace_action
## @ace_name("Set Bounce")
## @ace_category("Virtual Cursor")
## @ace_description("0 none, 1 solids, 2 constraints, 3 both.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_bounce({mode})")
func set_bounce(mode: int) -> void:
	bounce_mode = clampi(mode, 0, 3)

## @ace_action
## @ace_name("Set Direction Mode")
## @ace_category("Virtual Cursor")
## @ace_description("0 up/down, 1 left/right, 2 four-way, 3 eight-way.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_direction_mode({mode})")
func set_direction_mode(mode: int) -> void:
	direction_mode = clampi(mode, 0, 3)

## @ace_action
## @ace_name("Set Default Controls")
## @ace_category("Virtual Cursor")
## @ace_description("Read ui_left/right/up/down each tick.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_default_controls({state})")
func set_default_controls(state: bool) -> void:
	default_controls = state

## @ace_action
## @ace_name("Set Enabled")
## @ace_category("Virtual Cursor")
## @ace_description("Master on/off.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_cursor_enabled({is_enabled})")
func set_cursor_enabled(is_enabled: bool) -> void:
	enabled = is_enabled

## @ace_action
## @ace_name("Set Ignoring Input")
## @ace_category("Virtual Cursor")
## @ace_description("Ignore all input while true (movement decays to zero).")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_ignoring_input({state})")
func set_ignoring_input(state: bool) -> void:
	ignoring_input = state

## @ace_action
## @ace_name("Set Constrain To Layout")
## @ace_category("Virtual Cursor")
## @ace_description("Clamp the cursor inside the bounds.")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_constrain_to_layout({is_enabled})")
func set_constrain_to_layout(is_enabled: bool) -> void:
	constrain_to_layout = is_enabled

## @ace_action
## @ace_name("Set Constraint Bounds")
## @ace_category("Virtual Cursor")
## @ace_description("Sets explicit clamp bounds (all-zero clears them, falling back to the viewport).")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_constraint_bounds({left}, {top}, {right}, {bottom})")
func set_constraint_bounds(left: float, top: float, right: float, bottom: float) -> void:
	if left == 0.0 and top == 0.0 and right == 0.0 and bottom == 0.0:
		has_constraint_bounds = false
	else:
		constraint_bounds = Rect2(left, top, right - left, bottom - top)
		has_constraint_bounds = true

## @ace_action
## @ace_name("Set Hover Mode")
## @ace_category("Virtual Cursor")
## @ace_description("0 point (origin inside shape), 1 overlap (shapes overlap).")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.set_hover_mode({mode})")
func set_hover_mode(mode: int) -> void:
	hover_mode = clampi(mode, 0, 1)

## @ace_condition
## @ace_name("Is Interact Held")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.is_interact_held({id})")
func is_interact_held(id: String) -> bool:
	if id == "":
		for key in interact_states:
			if bool(interact_states[key]):
				return true
		return false
	return bool(interact_states.get(id, false))

## @ace_condition
## @ace_name("Is Moving")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.is_moving()")
func is_moving() -> bool:
	return report_vel.length() > 0.0

## @ace_condition
## @ace_name("Is In Homing Range")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.is_in_homing_range()")
func is_in_homing_range() -> bool:
	return in_homing_range

## @ace_condition
## @ace_name("Is Blocked")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.is_blocked()")
func is_blocked() -> bool:
	return blocked_this_tick

## @ace_condition
## @ace_name("Is Enabled")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.is_cursor_enabled()")
func is_cursor_enabled() -> bool:
	return enabled

## @ace_condition
## @ace_name("Is Ignoring Input")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.is_ignoring_input()")
func is_ignoring_input() -> bool:
	return ignoring_input

## @ace_condition
## @ace_name("Is Hovering")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.is_hovering({target})")
func is_hovering(target: Node2D) -> bool:
	hovered_uid = -1
	if host == null or target == null or target == host or not target.visible:
		return false
	var hit := false
	if hover_mode == 0:
		var shape := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape != null and shape.shape != null:
			hit = shape.shape.collide(shape.global_transform, _point_shape(), Transform2D(0.0, host.global_position))
		elif target.has_method("get_global_rect"):
			hit = target.call("get_global_rect").has_point(host.global_position)
		else:
			# Robust fallback for plain Sprite2D/CanvasItem (no CollisionShape2D, no
			# get_global_rect): derive a world rect from get_rect(), else distance check.
			var info := _target_world_rect(target)
			if bool(info["has_area"]):
				hit = (info["rect"] as Rect2).has_point(host.global_position)
			else:
				hit = host.global_position.distance_to(target.global_position) <= _target_extent(target)
	else:
		var host_node: Node = host
		if host_node is Area2D:
			var area := host_node as Area2D
			hit = area.get_overlapping_bodies().has(target) or area.get_overlapping_areas().has(target)
		else:
			# CharacterBody2D host never overlaps as an Area2D - gate on the target's
			# derived extent instead of a fixed 32px so size is respected.
			hit = host.global_position.distance_to(target.global_position) <= _target_extent(target)
	if hit:
		hovered_uid = target.get_instance_id()
	return hit

## @ace_expression
## @ace_name("Cursor X")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.cursor_x()")
func cursor_x() -> float:
	return host.global_position.x if host != null else 0.0

## @ace_expression
## @ace_name("Cursor Y")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.cursor_y()")
func cursor_y() -> float:
	return host.global_position.y if host != null else 0.0

## @ace_expression
## @ace_name("Speed")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.speed()")
func speed() -> float:
	return report_vel.length()

## @ace_expression
## @ace_name("Velocity X")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.velocity_x()")
func velocity_x() -> float:
	return report_vel.x

## @ace_expression
## @ace_name("Velocity Y")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.velocity_y()")
func velocity_y() -> float:
	return report_vel.y

## @ace_expression
## @ace_name("Moving Angle")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.moving_angle()")
func moving_angle() -> float:
	return fposmod(rad_to_deg(report_vel.angle()), 360.0)

## @ace_expression
## @ace_name("Axis X")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.axis_x()")
func axis_x() -> float:
	return axis.x

## @ace_expression
## @ace_name("Axis Y")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.axis_y()")
func axis_y() -> float:
	return axis.y

## @ace_expression
## @ace_name("Max Speed")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.max_speed_value()")
func max_speed_value() -> float:
	return max_speed

## @ace_expression
## @ace_name("Hovered UID")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.hovered_uid_value()")
func hovered_uid_value() -> int:
	return hovered_uid

## @ace_expression
## @ace_name("Homing Target UID")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.homing_target_uid_value()")
func homing_target_uid_value() -> int:
	return nearest_homing_uid

## @ace_expression
## @ace_name("Homing Target Dist")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.homing_target_dist_value()")
func homing_target_dist_value() -> float:
	return nearest_homing_dist

## @ace_expression
## @ace_name("Count Homing Targets")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.count_homing_targets()")
func count_homing_targets() -> int:
	return homing_targets.size()

## @ace_expression
## @ace_name("Bounce Mode")
## @ace_icon("res://eventsheet_addons/virtual_cursor/icon.svg")
## @ace_codegen_template("$VirtualCursor.bounce_mode_token()")
func bounce_mode_token() -> String:
	return ["none", "solids", "constraints", "both"][bounce_mode]

## Best-effort world-space AABB for a target that has no usable CollisionShape2D.
## Sprite2D/CanvasItem expose a LOCAL get_rect(); we transform its centre + half-size
## through global_transform so hover works on plain sprites. Returns has_area=false when
## nothing usable is found (caller then falls back to a distance/extent check).
func _target_world_rect(target: Node2D) -> Dictionary:
	var shape := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape != null:
		var lr: Rect2 = shape.shape.get_rect()
		return {"has_area": true, "rect": _xform_rect(shape.global_transform, lr)}
	if target.has_method("get_rect"):
		var r: Rect2 = target.call("get_rect")
		return {"has_area": true, "rect": _xform_rect(target.global_transform, r)}
	return {"has_area": false, "rect": Rect2()}

## A representative world-space proximity radius for a target: half the larger side of
## its derived world rect, else 32px. Used by overlap-mode hover so the gate tracks the
## actual target size instead of a fixed constant.
func _target_extent(target: Node2D) -> float:
	var info := _target_world_rect(target)
	if bool(info["has_area"]):
		var r: Rect2 = info["rect"]
		var e := maxf(r.size.x, r.size.y) * 0.5
		if e > 0.0:
			return e
	return 32.0

# Virtual Cursor behavior (event-sheet parity): input-agnostic controllable cursor on a CharacterBody2D - event-driven/axis/mouse-follow movement with accel/decel and direction modes, homing magnet, solid push-out via move_and_slide with sliding, lossless bounce, layout/viewport constraints, hover detection, and named interact buttons. Drives the Drag N Drop pack.
