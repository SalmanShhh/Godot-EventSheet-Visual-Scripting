## @ace_tags(movement, platformer, ai, pathfinding)
## @ace_category("Platformer Pathfinding")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/behavior.svg")
class_name PlatformerPathfinding
extends Node

## The node this behavior acts on (its parent). Required host: CharacterBody2D.
var host: CharacterBody2D = null

func _enter_tree() -> void:
	host = get_parent() as CharacterBody2D
	if host == null:
		push_warning("PlatformerPathfinding behavior requires a CharacterBody2D parent.")

## @ace_trigger
## @ace_name("On Portal Taken")
signal portal_taken
## @ace_trigger
## @ace_name("On Waypoint Stuck")
signal waypoint_stuck
## @ace_trigger
## @ace_name("On Repath")
signal repathed
## @ace_trigger
## @ace_name("On Hazard Entered")
signal hazard_entered
## @ace_trigger
## @ace_name("On Path Found")
signal path_found
## @ace_trigger
## @ace_name("On Path Failed")
signal path_failed
## @ace_trigger
## @ace_name("On Path Complete")
signal path_complete
## @ace_trigger
## @ace_name("On Waypoint Reached")
signal waypoint_reached
## @ace_trigger
## @ace_name("On Nav Graph Built")
signal nav_graph_built

## How close (px, horizontally) counts as reaching a waypoint.
@export var arrive_distance: float = 10.0
## Drive the sibling PlatformerMovement automatically. Off = paths still compute; read Path Move Axis / Path Wants Jump and steer yourself.
@export var auto_control: bool = true
## Grace window (s) for AI jumps just after running off the takeoff ledge - a frame-late jump still fires.
@export var coyote_time: float = 0.12
## Draw the active path as a line in the world.
@export var debug_draw: bool = false
## The fallback driver's gravity.
@export var fallback_gravity: float = 980.0
## The fallback driver's jump velocity (negative = up). Also sizes jump arcs when nothing can be derived.
@export var fallback_jump_velocity: float = -400.0
## No movement sibling? The built-in fallback driver moves the CharacterBody2D itself at this speed.
@export var fallback_move_speed: float = 200.0
## Max jump distance in px (0 = derive it from the sibling PlatformerMovement's speed and air time).
@export var jump_distance_override: float = 0.0
## Max jump height in px (0 = derive it from the sibling PlatformerMovement's jump_velocity/gravity).
@export var jump_height_override: float = 0.0
## relaxed: jump as soon as a jump leg starts. strict: walk onto the exact takeoff spot first - slower but precise on tight arcs.
@export_enum("relaxed", "strict") var jump_positioning: String = "relaxed"
## With Ledge Restriction on, drops up to this many pixels are still allowed (0 = no drops at all).
@export var ledge_leniency: float = 0.0
## Patrol discipline: routes may only WALK - no jumps, no portals, and no drops beyond Ledge Leniency. The agent stays on its platform.
@export var ledge_restriction: bool = false
## The furthest safe drop (px) the graph will route through.
@export var max_fall_distance: float = 320.0
## While following a node (Find Path To Node), how often the route may refresh.
@export var repath_interval: float = 0.5
## The route only refreshes when the followed node has moved at least this many pixels from where the current path was aimed.
@export var repath_threshold: float = 24.0
## No progress toward the current waypoint for this long fires On Waypoint Stuck and re-routes from wherever the agent actually is.
@export var stuck_timeout: float = 1.5
## Release the jump at the height each arc actually needs (short hops for flat gaps, full rises for tall ledges) - smoother-looking movement. Off = every jump is full height.
@export var variable_jump: bool = true

# --- Internal state (the graph lives per agent in P1) ---
var _tilemap: TileMapLayer = null
var _movement: Node = null
## Standable cells (the cell the agent's feet occupy) -> true.
var _nodes: Dictionary = {}
## cell -> Array of {"to": Vector2i, "kind": "walk"/"jump"/"fall", "cost": float}.
var _edges: Dictionary = {}
## The active path: Array of {"world": Vector2, "action": String}.
var _path: Array = []
var _path_index: int = 0
var _jumped_this_segment: bool = false
var _jump_released: bool = false
var _jump_release_velocity: float = 0.0
var _move_axis: float = 0.0
var _debug_line: Line2D = null
## Registered portals: {"from": Vector2, "to": Vector2, "both": bool} - survive regenerate.
var _portals: Array = []
## World-space hazard rects: {"rect": Rect2, "deadly": bool}. Applied at ROUTING time (no
## rebuild needed when they change): deadly blocks edges outright, danger multiplies cost.
var _hazards: Array = []
var _was_in_hazard: bool = false
## Registered moving platforms: {"node": Node2D, "a": Vector2, "b": Vector2} - survive
## regenerate. Each becomes a "platform" edge; the drive waits, boards, and rides it.
var _moving_platforms: Array = []
# Follow mode (Find Path To Node): the tracked node + where the current path was aimed.
var _follow_target: Node = null
var _path_goal: Vector2 = Vector2.ZERO
var _goal_mode: String = "nearest"
var _repath_clock: float = 0.0
# Coyote grace: seconds since the host last stood on the floor.
var _floor_grace: float = 0.0
# Stuck watchdog: best distance seen toward the current waypoint + time without progress.
var _best_waypoint_distance: float = INF
var _stuck_clock: float = 0.0
# Budget-deferred request (this agent is queued for a later tick).
var _path_pending: bool = false
var _pending_goal: Vector2 = Vector2.ZERO
var _pending_goal_mode: String = "nearest"
# The SHARED path budget: statics are one value across every agent of this behavior, so
# N chasers repathing at once spread their A* runs over frames instead of spiking one.
static var _shared_max_paths_per_tick: int = 8
static var _shared_tick_id: int = -1
static var _shared_paths_this_tick: int = 0
## The sibling movement pack, duck-typed: any child of the host with a move_speed and a
## jump() (PlatformerMovement, or your own driver with the same surface).
## @ace_hidden
func _find_movement() -> Node:
	if _movement != null and is_instance_valid(_movement):
		return _movement
	if host == null:
		return null
	for child in host.get_children():
		if child != self and child.has_method("jump") and child.get("move_speed") != null:
			_movement = child
			return _movement
	return null
## Jump reach in CELLS, derived from the movement pack's physics (the overrides win when
## set): height = v^2/2g, distance = speed * full air time, both with a 0.9 safety margin.
## @ace_hidden
func _jump_reach_cells() -> Vector2i:
	var tile: float = float(_tilemap.tile_set.tile_size.y)
	var height_px: float = jump_height_override
	var distance_px: float = jump_distance_override
	var movement: Node = _find_movement()
	if movement != null:
		var rise: float = absf(float(movement.get("jump_velocity")))
		var fall_pull: float = maxf(float(movement.get("gravity")), 1.0)
		if height_px <= 0.0:
			height_px = rise * rise / (2.0 * fall_pull) * 0.9
		if distance_px <= 0.0:
			distance_px = float(movement.get("move_speed")) * (2.0 * rise / fall_pull) * 0.9
	# No sibling to derive from: size arcs from the fallback driver's own physics.
	var fallback_rise: float = absf(fallback_jump_velocity)
	if height_px <= 0.0:
		height_px = fallback_rise * fallback_rise / (2.0 * maxf(fallback_gravity, 1.0)) * 0.9
	if distance_px <= 0.0:
		distance_px = fallback_move_speed * (2.0 * fallback_rise / maxf(fallback_gravity, 1.0)) * 0.9
	return Vector2i(maxi(int(ceil(distance_px / tile)), 1), maxi(int(ceil(height_px / tile)), 1))
## The standable node nearest a world position (within max_cells), or Vector2i.MAX.
## Tree-safe: outside a scene tree (tools, tests) the tilemap's own offset stands in for
## the global transform.
## @ace_hidden
func _nearest_node(world: Vector2, max_cells: int) -> Vector2i:
	var local: Vector2 = _tilemap.to_local(world) if _tilemap.is_inside_tree() else world - _tilemap.position
	var around: Vector2i = _tilemap.local_to_map(local)
	var best: Vector2i = Vector2i.MAX
	var best_distance: float = float(max_cells) + 0.51
	for cell in _nodes:
		# A node inside a deadly hazard is never a start or goal.
		if _point_in_hazard(_cell_world(cell), true):
			continue
		var cell_distance: float = Vector2(cell - around).length()
		if cell_distance < best_distance:
			best_distance = cell_distance
			best = cell
	return best

func _physics_process(delta: float) -> void:
	if host == null:
		return
	# Coyote bookkeeping: seconds since the host last stood on the floor (the jump gate
	# below accepts a frame-late takeoff within Coyote Time).
	if host.is_on_floor():
		_floor_grace = 0.0
	else:
		_floor_grace += delta
	# Hazard presence (any kind) fires On Hazard Entered on the way in - the damage hook.
	var in_hazard_now: bool = _point_in_hazard(host.global_position, false)
	if in_hazard_now and not _was_in_hazard:
		hazard_entered.emit()
	_was_in_hazard = in_hazard_now
	# Budget-deferred retries and follow-mode refreshes run even without an active path.
	_repath_clock += delta
	if _path_pending:
		find_path_to(_pending_goal.x, _pending_goal.y, _pending_goal_mode)
	elif _follow_target != null and is_instance_valid(_follow_target) and _follow_target is Node2D and _repath_clock >= repath_interval:
		_repath_clock = 0.0
		var followed: Vector2 = (_follow_target as Node2D).global_position
		if followed.distance_to(_path_goal) > repath_threshold:
			find_path_to(followed.x, followed.y, _goal_mode)
			repathed.emit()
	if _path.is_empty():
		return
	var waypoint: Dictionary = _path[_path_index]
	var target: Vector2 = waypoint["world"]
	# Portal traversal: the waypoint IS the exit - blink there and continue.
	if waypoint["action"] == "portal":
		host.global_position = target
		host.velocity = Vector2.ZERO
		portal_taken.emit()
		_advance_waypoint()
		return
	var dx: float = target.x - host.global_position.x
	_move_axis = clampf(dx / 24.0, -1.0, 1.0) if absf(dx) > 2.0 else 0.0
	var movement: Node = _find_movement()
	var tile: float = float(_tilemap.tile_set.tile_size.y) if _tilemap != null else 32.0
	# Jump on jump arcs, and STEP-ASSIST on raised walk waypoints: a full-block stair stops
	# a walking body, so a close-and-higher waypoint gets a hop (slope tiles just walk).
	var wants_jump: bool = waypoint["action"] == "jump"
	if not wants_jump and waypoint["action"] == "walk":
		wants_jump = target.y < host.global_position.y - 8.0 and absf(dx) < tile * 1.5
	# Strict jump positioning: walk onto the exact takeoff spot before leaping (relaxed
	# leaps the moment the jump leg starts - faster, but looser on tight arcs).
	if waypoint["action"] == "jump" and jump_positioning == "strict" and not _jumped_this_segment and _path_index > 0:
		var takeoff_dx: float = (_path[_path_index - 1]["world"] as Vector2).x - host.global_position.x
		if absf(takeoff_dx) > 4.0:
			_move_axis = clampf(takeoff_dx / 24.0, -1.0, 1.0)
			wants_jump = false
	# Moving-platform leg: wait beside the track, board, ride, walk off - the platform carries.
	if waypoint["action"] == "platform":
		_move_axis = _platform_move_axis(target, _move_axis)
		wants_jump = false
	# A platform leg coming up within the next few waypoints: its boarding nodes sit under
	# the track, so the wait-beside steering engages EARLY - the agent stands clear until
	# the platform parks instead of idling beneath a descending one.
	else:
		for ahead in range(_path_index + 1, mini(_path_index + 4, _path.size())):
			if _path[ahead]["action"] == "platform":
				_move_axis = _platform_approach_axis(_path[ahead]["world"], _move_axis)
				wants_jump = false
				break
	# The final waypoint is the chase goal, and a chased body physically OCCUPIES its node -
	# arrival there accepts standing beside it (a body-width radius) instead of pressing
	# into the target forever (two CharacterBody2Ds grind, and the loser gets bulldozed).
	var arrive_radius: float = arrive_distance if _path_index < _path.size() - 1 else maxf(arrive_distance, tile)
	# Arrival is checked BEFORE the drive: the arrival tick must not also steer, or every
	# instant-complete refind leaks one frame of drive and a parked agent creeps off ledges.
	if absf(dx) <= arrive_radius and absf(target.y - host.global_position.y) <= tile:
		_advance_waypoint()
		if debug_draw:
			_refresh_debug()
		return
	# Stuck watchdog: no progress toward the waypoint for Stuck Timeout -> On Waypoint Stuck
	# and a fresh route from wherever the agent actually is.
	var waypoint_gap: float = host.global_position.distance_to(target)
	if waypoint_gap < _best_waypoint_distance - 1.0:
		_best_waypoint_distance = waypoint_gap
		_stuck_clock = 0.0
	else:
		_stuck_clock += delta
		if _stuck_clock >= maxf(stuck_timeout, 0.1):
			_stuck_clock = 0.0
			_best_waypoint_distance = INF
			waypoint_stuck.emit()
			find_path_to(_path_goal.x, _path_goal.y, _goal_mode)
			repathed.emit()
	if auto_control:
		var start_jump: bool = wants_jump and not _jumped_this_segment and (host.is_on_floor() or _floor_grace <= coyote_time)
		if start_jump:
			_jumped_this_segment = true
			_jump_released = false
			_jump_release_velocity = _release_velocity_for(target)
			# An arc that needs (nearly) the whole jump must never be cut - releasing a
			# near-max jump on its first frames kills the climb. Variable jump only arms
			# when there is clear headroom.
			var full_rise: float = absf(float(movement.get("jump_velocity"))) if movement != null else absf(fallback_jump_velocity)
			if _jump_release_velocity >= full_rise * 0.85:
				_jump_release_velocity = 0.0
		# Variable jump: once remaining upward speed is just enough for THIS arc's rise,
		# release - flat gap hops stay low, tall ledges get the full jump.
		var release_now: bool = variable_jump and _jumped_this_segment and not _jump_released and host.velocity.y < 0.0 and absf(host.velocity.y) <= _jump_release_velocity
		if movement != null:
			# The standard drive seam on the movement sibling - its accel, coyote time, and
			# jump feel all still apply under AI control.
			movement.set("ai_controlled", true)
			movement.set("ai_move_axis", _move_axis)
			if start_jump:
				movement.jump()
			if release_now and movement.has_method("jump_released"):
				_jump_released = true
				movement.jump_released()
		else:
			# No movement sibling: the built-in fallback drives the CharacterBody2D itself,
			# so ANY body pathfinds out of the box (attach one behavior, done).
			host.velocity.y = minf(host.velocity.y + fallback_gravity * delta, 1000.0)
			host.velocity.x = _move_axis * fallback_move_speed
			if start_jump:
				host.velocity.y = fallback_jump_velocity
			if release_now:
				_jump_released = true
				host.velocity.y *= 0.45
			host.move_and_slide()
	if debug_draw:
		_refresh_debug()

## @ace_action
## @ace_name("Build Nav Graph From Tilemap")
## @ace_category("Platformer Pathfinding")
## @ace_description("Scans a TileMapLayer's physics tiles into the navigation graph: standable cells become nodes, adjacent cells (one step up or down - stairs and tile slopes) become WALK edges, and jump arcs / fall drops connect the rest, sized to the sibling PlatformerMovement's real jump. Call once on ready; Regenerate after level edits. Fires On Nav Graph Built.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.build_nav_graph({tilemap})")
func build_nav_graph(tilemap: Node) -> void:
	_tilemap = tilemap as TileMapLayer
	regenerate_nav_graph()

## @ace_action
## @ace_name("Regenerate Nav Graph")
## @ace_category("Platformer Pathfinding")
## @ace_description("Rebuilds the graph from the same TileMapLayer (after runtime tile edits).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.regenerate_nav_graph()")
func regenerate_nav_graph() -> void:
	_nodes.clear()
	_edges.clear()
	if _tilemap == null:
		return
	var solid: Dictionary = {}
	for cell in _tilemap.get_used_cells():
		var tile_data: TileData = _tilemap.get_cell_tile_data(cell)
		if tile_data != null and tile_data.get_collision_polygons_count(0) > 0:
			solid[cell] = true
	# A standable node = a solid cell with two cells of headroom above it.
	for cell in solid:
		var stand: Vector2i = cell + Vector2i(0, -1)
		if not solid.has(stand) and not solid.has(stand + Vector2i(0, -1)):
			_nodes[stand] = true
	# WALK edges: neighbours one cell over, up to one step up/down - stairs and slopes
	# included, at plain euclidean cost so ramps beat jumps in the router.
	for cell in _nodes:
		for dx in [-1, 1]:
			for dy in [-1, 0, 1]:
				var to: Vector2i = cell + Vector2i(dx, dy)
				if _nodes.has(to):
					_add_edge(cell, to, "walk", Vector2(float(dx), float(dy)).length())
	# JUMP arcs + FALL drops within the derived reach, clearance-checked coarsely.
	var reach: Vector2i = _jump_reach_cells()
	var fall_cells: int = maxi(int(ceil(max_fall_distance / float(_tilemap.tile_set.tile_size.y))), 1)
	for cell in _nodes:
		for dx in range(-reach.x, reach.x + 1):
			for dy in range(-reach.y, fall_cells + 1):
				if absi(dx) <= 1 and absi(dy) <= 1:
					continue
				var to: Vector2i = cell + Vector2i(dx, dy)
				if not _nodes.has(to) or not _arc_clear(cell, to, solid):
					continue
				var kind: String = "fall" if dy > 0 and absi(dx) <= 2 else "jump"
				var span: float = Vector2(float(dx), float(dy)).length()
				_add_edge(cell, to, kind, span * (1.5 if kind == "jump" else 1.1))
	# Registered portals and moving platforms survive every rebuild.
	for portal in _portals:
		_apply_portal(portal)
	for ride in _moving_platforms:
		_apply_moving_platform(ride)
	nav_graph_built.emit()

## @ace_action
## @ace_name("Find Path To")
## @ace_category("Platformer Pathfinding")
## @ace_description("Routes to a world position and starts moving. Mode "reach" fails (On Path Failed) when the spot itself is unreachable; "nearest" never fails - it goes to the closest reachable node instead. Fires On Path Found / On Path Failed.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.find_path_to({x}, {y}, {mode})")
func find_path_to(x: float, y: float, mode: String) -> void:
	# A repath while riding a mid-travel moving platform is DEFERRED (the current path
	# keeps driving): a fresh route would start from a ground node and steer the rider
	# off the shaft in mid-air.
	if _riding_moving_platform():
		return
	# The shared budget: at most Max Paths Per Tick A* runs per physics tick ACROSS all
	# agents - extra requests defer to the next tick (Is Path Pending) instead of spiking.
	var frame: int = Engine.get_physics_frames()
	if frame != _shared_tick_id:
		_shared_tick_id = frame
		_shared_paths_this_tick = 0
	if _shared_paths_this_tick >= maxi(_shared_max_paths_per_tick, 0):
		_pending_goal = Vector2(x, y)
		_pending_goal_mode = mode
		_path_pending = true
		return
	_shared_paths_this_tick += 1
	_path_pending = false
	if _tilemap == null or _nodes.is_empty():
		push_warning("[PlatformerPathfinding] Find Path To called before the nav graph exists - call Build Nav Graph From Tilemap (usually On Ready) first.")
		path_failed.emit()
		return
	if host == null:
		path_failed.emit()
		return
	var start: Vector2i = _nearest_node(host.global_position, 3)
	var goal: Vector2i = _nearest_node(Vector2(x, y), 2 if mode == "reach" else 1000000)
	if start == Vector2i.MAX or goal == Vector2i.MAX:
		stop_pathfinding()
		path_failed.emit()
		return
	var cells: Array = _astar(start, goal)
	if cells.is_empty():
		stop_pathfinding()
		path_failed.emit()
		return
	_path_goal = Vector2(x, y)
	_goal_mode = mode
	_path = []
	for index in range(cells.size()):
		var action: String = "walk" if index == 0 else _edge_kind(cells[index - 1], cells[index])
		_path.append({"world": _cell_world(cells[index]), "action": action})
	_path_index = 0
	# A fresh route starts at OUR nearest node - when we already stand on it, aim at the
	# next waypoint instead (a repath mid-stride must never walk the agent backward, or a
	# chaser re-finding on a timer thrashes in place at node boundaries).
	if _path.size() > 1 and host.global_position.distance_to(_path[0]["world"]) <= float(_tilemap.tile_set.tile_size.y):
		_path_index = 1
	_jumped_this_segment = false
	_best_waypoint_distance = INF
	_stuck_clock = 0.0
	path_found.emit()

## @ace_action
## @ace_name("Find Path To Node")
## @ace_category("Platformer Pathfinding")
## @ace_description("Routes to another node's position AND keeps following it: the route auto-refreshes every Repath Interval once the node has moved Repath Threshold pixels (firing On Repath) - one call chases forever. Stop Pathfinding ends the follow.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.find_path_to_node({target}, {mode})")
func find_path_to_node(target: Node, mode: String) -> void:
	if target is Node2D:
		find_path_to((target as Node2D).global_position.x, (target as Node2D).global_position.y, mode)
		_follow_target = target
		_goal_mode = mode
		_repath_clock = 0.0
	else:
		path_failed.emit()

## @ace_action
## @ace_name("Stop Pathfinding")
## @ace_category("Platformer Pathfinding")
## @ace_description("Clears the path and releases the movement pack back to the keyboard (ai_controlled off).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.stop_pathfinding()")
func stop_pathfinding() -> void:
	_path = []
	_path_index = 0
	_move_axis = 0.0
	_jumped_this_segment = false
	_follow_target = null
	_path_pending = false
	_stuck_clock = 0.0
	_best_waypoint_distance = INF
	var movement: Node = _find_movement()
	if movement != null:
		movement.set("ai_move_axis", 0.0)
		movement.set("ai_controlled", false)
	if _debug_line != null and is_instance_valid(_debug_line):
		_debug_line.clear_points()

## @ace_action
## @ace_name("Set Auto Control")
## @ace_category("Platformer Pathfinding")
## @ace_description("On (default): the behavior drives the sibling PlatformerMovement. Off: paths still compute - read Path Move Axis / Path Wants Jump / Current Waypoint X/Y and drive anything you like.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_auto_control({enabled})")
func set_auto_control(enabled: bool) -> void:
	auto_control = enabled
	if not enabled:
		var movement: Node = _find_movement()
		if movement != null:
			movement.set("ai_controlled", false)

## @ace_action
## @ace_name("Set Ledge Restriction")
## @ace_category("Platformer Pathfinding")
## @ace_description("Patrol discipline: on, routes may only WALK - no jumps, no portals, and no drops beyond Ledge Leniency, so the agent stays on its platform. Applies from the next Find Path To.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_ledge_restriction({enabled})")
func set_ledge_restriction(enabled: bool) -> void:
	ledge_restriction = enabled

## @ace_action
## @ace_name("Set Ledge Leniency")
## @ace_category("Platformer Pathfinding")
## @ace_description("With Ledge Restriction on, drops up to this many pixels are still allowed (a patroller may hop down one step but never off the tower).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_ledge_leniency({pixels})")
func set_ledge_leniency(pixels: float) -> void:
	ledge_leniency = pixels

## @ace_action
## @ace_name("Set Jump Positioning")
## @ace_category("Platformer Pathfinding")
## @ace_description("relaxed (default): leap the moment a jump leg starts. strict: walk onto the exact takeoff spot first - slower but precise on tight arcs.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_jump_positioning({mode})")
func set_jump_positioning(mode: String) -> void:
	jump_positioning = mode

## @ace_action
## @ace_name("Set Coyote Time")
## @ace_category("Platformer Pathfinding")
## @ace_description("Grace window (s) for AI jumps just after running off the takeoff ledge.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_coyote_time({seconds})")
func set_coyote_time(seconds: float) -> void:
	coyote_time = seconds

## @ace_action
## @ace_name("Set Repath Interval")
## @ace_category("Platformer Pathfinding")
## @ace_description("While following a node, how often the route may refresh (chase freshness vs cost).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_repath_interval({seconds})")
func set_repath_interval(seconds: float) -> void:
	repath_interval = seconds

## @ace_action
## @ace_name("Set Repath Threshold")
## @ace_category("Platformer Pathfinding")
## @ace_description("The route only refreshes when the followed node has moved at least this many pixels.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_repath_threshold({pixels})")
func set_repath_threshold(pixels: float) -> void:
	repath_threshold = pixels

## @ace_action
## @ace_name("Set Max Paths Per Tick")
## @ace_category("Platformer Pathfinding")
## @ace_description("The SHARED budget across every agent: at most this many route computations per physics tick - extras defer a tick (Is Path Pending) instead of spiking the frame. The difference between 20 chasers working and not.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_max_paths_per_tick({count})")
func set_max_paths_per_tick(count: int) -> void:
	_shared_max_paths_per_tick = count

## @ace_action
## @ace_name("Add Portal")
## @ace_category("Platformer Pathfinding")
## @ace_description("Links two world positions as a PORTAL: an agent whose route uses it walks to the entrance and blinks to the exit (fires On Portal Taken). Bidirectional works both ways. Portals join the graph immediately and survive Regenerate - doors, teleporters, ladders, and elevators all model as portals.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.add_portal({from_x}, {from_y}, {to_x}, {to_y}, {bidirectional})")
func add_portal(from_x: float, from_y: float, to_x: float, to_y: float, bidirectional: bool) -> void:
	var portal: Dictionary = {"from": Vector2(from_x, from_y), "to": Vector2(to_x, to_y), "both": bidirectional}
	_portals.append(portal)
	if not _nodes.is_empty():
		_apply_portal(portal)

## @ace_action
## @ace_name("Clear Portals")
## @ace_category("Platformer Pathfinding")
## @ace_description("Removes every registered portal (takes effect on the next Regenerate Nav Graph).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.clear_portals()")
func clear_portals() -> void:
	_portals = []
	regenerate_nav_graph()

## @ace_action
## @ace_name("Add Hazard")
## @ace_category("Platformer Pathfinding")
## @ace_description("Marks a world-space rectangle as hazardous. Deadly: routes NEVER pass through it (spikes, lava). Not deadly: routes pay 4x to cross, so it is taken only when no clean way exists (fire patches, slow mud). Applies to routing instantly - no rebuild - and On Hazard Entered fires if the agent ends up inside one anyway.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.add_hazard({x}, {y}, {width}, {height}, {deadly})")
func add_hazard(x: float, y: float, width: float, height: float, deadly: bool) -> void:
	_hazards.append({"rect": Rect2(x, y, width, height), "deadly": deadly})

## @ace_action
## @ace_name("Clear Hazards")
## @ace_category("Platformer Pathfinding")
## @ace_description("Removes every hazard (routing sees the change immediately).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.clear_hazards()")
func clear_hazards() -> void:
	_hazards = []

## @ace_action
## @ace_name("Add Moving Platform")
## @ace_category("Platformer Pathfinding")
## @ace_description("Registers a moving platform (an AnimatableBody2D you animate) by its two travel endpoints: the graph gains a PLATFORM edge between them, and an agent routed across it walks to the track, WAITS for the platform, boards, rides, and walks off at the far side. Survives Regenerate. The pack never moves the platform - your sheet animates it between exactly these endpoints.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.add_moving_platform({platform}, {from_x}, {from_y}, {to_x}, {to_y})")
func add_moving_platform(platform: Node, from_x: float, from_y: float, to_x: float, to_y: float) -> void:
	if not (platform is Node2D):
		return
	var ride: Dictionary = {"node": platform, "a": Vector2(from_x, from_y), "b": Vector2(to_x, to_y)}
	_moving_platforms.append(ride)
	if not _nodes.is_empty():
		_apply_moving_platform(ride)

## @ace_action
## @ace_name("Clear Moving Platforms")
## @ace_category("Platformer Pathfinding")
## @ace_description("Unregisters every moving platform (takes effect on the next Regenerate Nav Graph).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.clear_moving_platforms()")
func clear_moving_platforms() -> void:
	_moving_platforms = []
	regenerate_nav_graph()

## @ace_action
## @ace_name("Set Nav Debug Draw")
## @ace_category("Platformer Pathfinding")
## @ace_description("Draws the active path as a line in the world (great while tuning a level).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_nav_debug_draw({enabled})")
func set_nav_debug_draw(enabled: bool) -> void:
	debug_draw = enabled
	_refresh_debug()

## @ace_condition
## @ace_name("Is Path Pending")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.is_path_pending()")
func is_path_pending() -> bool:
	return _path_pending

## @ace_condition
## @ace_name("Is In Hazard")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.is_in_hazard()")
func is_in_hazard() -> bool:
	return host != null and _point_in_hazard(host.global_position, false)

func _point_in_hazard(world: Vector2, deadly_only: bool) -> bool:
	for hazard in _hazards:
		if (not deadly_only or bool(hazard["deadly"])) and (hazard["rect"] as Rect2).has_point(world):
			return true
	return false

func _segment_hazard(from_cell: Vector2i, to_cell: Vector2i) -> int:
	if _hazards.is_empty():
		return 0
	var verdict: int = 0
	for sample in [_cell_world(from_cell), _cell_world(to_cell), (_cell_world(from_cell) + _cell_world(to_cell)) * 0.5]:
		for hazard in _hazards:
			if (hazard["rect"] as Rect2).has_point(sample):
				if bool(hazard["deadly"]):
					return 2
				verdict = 1
	return verdict

## @ace_condition
## @ace_name("Has Path")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.has_path()")
func has_path() -> bool:
	return not _path.is_empty()

## @ace_condition
## @ace_name("Path Wants Jump")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.path_wants_jump()")
func path_wants_jump() -> bool:
	if _path.is_empty() or _jumped_this_segment or host == null:
		return false
	var waypoint: Dictionary = _path[_path_index]
	if waypoint["action"] == "jump":
		return true
	# Step assist: a close-and-higher walk waypoint needs a hop on full-block stairs.
	var tile: float = float(_tilemap.tile_set.tile_size.y) if _tilemap != null else 32.0
	var target: Vector2 = waypoint["world"]
	return waypoint["action"] == "walk" and target.y < host.global_position.y - 8.0 and absf(target.x - host.global_position.x) < tile * 1.5

## @ace_expression
## @ace_name("Path Move Axis")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.path_move_axis()")
func path_move_axis() -> float:
	return _move_axis

## @ace_expression
## @ace_name("Waypoint Count")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.waypoint_count()")
func waypoint_count() -> int:
	return _path.size()

## @ace_expression
## @ace_name("Current Waypoint Index")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.current_waypoint_index()")
func current_waypoint_index() -> int:
	return _path_index

## @ace_expression
## @ace_name("Current Waypoint X")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.current_waypoint_x()")
func current_waypoint_x() -> float:
	return (_path[_path_index]["world"] as Vector2).x if not _path.is_empty() else 0.0

## @ace_expression
## @ace_name("Current Waypoint Y")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.current_waypoint_y()")
func current_waypoint_y() -> float:
	return (_path[_path_index]["world"] as Vector2).y if not _path.is_empty() else 0.0

## @ace_expression
## @ace_name("Current Path Action")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.current_path_action()")
func current_path_action() -> String:
	return str(_path[_path_index]["action"]) if not _path.is_empty() else ""

func _drive_gravity() -> float:
	var movement: Node = _find_movement()
	if movement != null and movement.get("gravity") != null:
		return maxf(float(movement.get("gravity")), 1.0)
	return maxf(fallback_gravity, 1.0)

func _release_velocity_for(target: Vector2) -> float:
	var rise: float = maxf(host.global_position.y - target.y, 0.0) + 20.0
	return sqrt(2.0 * _drive_gravity() * rise)

func _apply_portal(portal: Dictionary) -> void:
	var from_node: Vector2i = _nearest_node(portal["from"], 2)
	var to_node: Vector2i = _nearest_node(portal["to"], 2)
	if from_node == Vector2i.MAX or to_node == Vector2i.MAX:
		return
	_add_edge(from_node, to_node, "portal", 2.0)
	if bool(portal["both"]):
		_add_edge(to_node, from_node, "portal", 2.0)

func _apply_moving_platform(ride: Dictionary) -> void:
	var from_node: Vector2i = _nearest_node(ride["a"], 3)
	var to_node: Vector2i = _nearest_node(ride["b"], 3)
	if from_node == Vector2i.MAX or to_node == Vector2i.MAX:
		return
	var span: float = (ride["a"] as Vector2).distance_to(ride["b"]) / float(_tilemap.tile_set.tile_size.y)
	_add_edge(from_node, to_node, "platform", span * 1.3)
	_add_edge(to_node, from_node, "platform", span * 1.3)

func _platform_for_waypoint(target: Vector2) -> Dictionary:
	for ride in _moving_platforms:
		if not is_instance_valid(ride["node"]):
			continue
		if (ride["a"] as Vector2).distance_to(target) < 96.0 or (ride["b"] as Vector2).distance_to(target) < 96.0:
			return ride
	return {}

func _platform_move_axis(target: Vector2, default_axis: float) -> float:
	var ride: Dictionary = _platform_for_waypoint(target)
	if ride.is_empty():
		return default_axis
	_stuck_clock = 0.0
	_best_waypoint_distance = INF
	var platform: Node2D = ride["node"]
	var plat: Vector2 = platform.global_position
	var dest_side: Vector2 = ride["a"] if (ride["a"] as Vector2).distance_to(target) <= (ride["b"] as Vector2).distance_to(target) else ride["b"]
	var board_side: Vector2 = ride["b"] if dest_side == ride["a"] else ride["a"]
	var riding: bool = host.is_on_floor() and absf(host.global_position.x - plat.x) < 64.0 and host.global_position.y < plat.y + 8.0 and absf(host.global_position.y - plat.y) < 48.0
	if riding:
		if plat.distance_to(dest_side) < 40.0:
			return default_axis
		var center_dx: float = plat.x - host.global_position.x
		return clampf(center_dx / 24.0, -1.0, 1.0) if absf(center_dx) > 6.0 else 0.0
	# Board only a PARKED platform (a still-moving one can crush the walker) - give your
	# platform a dwell at each endpoint so there is a boarding window.
	if plat.distance_to(board_side) < 12.0:
		var board_dx: float = plat.x - host.global_position.x
		return clampf(board_dx / 24.0, -1.0, 1.0) if absf(board_dx) > 4.0 else 0.0
	# Wait on the DESTINATION's side of the track - clear of the descending platform.
	var wait_x: float = board_side.x - 56.0 if target.x <= board_side.x else board_side.x + 56.0
	var wait_dx: float = wait_x - host.global_position.x
	return clampf(wait_dx / 24.0, -1.0, 1.0) if absf(wait_dx) > 6.0 else 0.0

func _platform_approach_axis(leg_target: Vector2, default_axis: float) -> float:
	var ride: Dictionary = _platform_for_waypoint(leg_target)
	if ride.is_empty():
		return default_axis
	var plat: Vector2 = (ride["node"] as Node2D).global_position
	var dest_side: Vector2 = ride["a"] if (ride["a"] as Vector2).distance_to(leg_target) <= (ride["b"] as Vector2).distance_to(leg_target) else ride["b"]
	var board_side: Vector2 = ride["b"] if dest_side == ride["a"] else ride["a"]
	if plat.distance_to(board_side) < 12.0:
		return default_axis
	_stuck_clock = 0.0
	_best_waypoint_distance = INF
	var wait_x: float = board_side.x - 56.0 if leg_target.x <= board_side.x else board_side.x + 56.0
	var wait_dx: float = wait_x - host.global_position.x
	return clampf(wait_dx / 24.0, -1.0, 1.0) if absf(wait_dx) > 6.0 else 0.0

func _riding_moving_platform() -> bool:
	if host == null or not host.is_on_floor():
		return false
	for ride in _moving_platforms:
		if not is_instance_valid(ride["node"]):
			continue
		var plat: Vector2 = (ride["node"] as Node2D).global_position
		if absf(host.global_position.x - plat.x) >= 40.0 or host.global_position.y > plat.y or plat.y - host.global_position.y >= 48.0:
			continue
		if plat.distance_to(ride["a"]) > 12.0 and plat.distance_to(ride["b"]) > 12.0:
			return true
	return false

## @ace_hidden
func _advance_waypoint() -> void:
	_jumped_this_segment = false
	_jump_released = false
	_best_waypoint_distance = INF
	_stuck_clock = 0.0
	_path_index += 1
	waypoint_reached.emit()
	if _path_index >= _path.size():
		stop_pathfinding()
		path_complete.emit()

func _arc_clear(from_cell: Vector2i, to_cell: Vector2i, solid: Dictionary) -> bool:
	if solid.has(from_cell + Vector2i(0, -1)) or solid.has(to_cell + Vector2i(0, -1)):
		return false
	for step in [0.25, 0.5, 0.75]:
		var sample: Vector2 = Vector2(from_cell).lerp(Vector2(to_cell), step) + Vector2(0.0, -1.0)
		if solid.has(Vector2i(roundi(sample.x), roundi(sample.y))):
			return false
	return true

## @ace_hidden
func _add_edge(from_cell: Vector2i, to_cell: Vector2i, kind: String, cost: float) -> void:
	if not _edges.has(from_cell):
		_edges[from_cell] = []
	(_edges[from_cell] as Array).append({"to": to_cell, "kind": kind, "cost": cost})

## @ace_hidden
func _cell_world(cell: Vector2i) -> Vector2:
	var local: Vector2 = _tilemap.map_to_local(cell)
	return _tilemap.to_global(local) if _tilemap.is_inside_tree() else local + _tilemap.position

func _astar(start: Vector2i, goal: Vector2i) -> Array:
	var open: Array = [start]
	var came_from: Dictionary = {}
	var cost_so_far: Dictionary = {start: 0.0}
	while not open.is_empty():
		var best_index: int = 0
		for index in range(1, open.size()):
			var here: Vector2i = open[index]
			if cost_so_far[here] + Vector2(goal - here).length() < cost_so_far[open[best_index]] + Vector2(goal - (open[best_index] as Vector2i)).length():
				best_index = index
		var current: Vector2i = open.pop_at(best_index)
		if current == goal:
			var cells: Array = [current]
			while came_from.has(current):
				current = came_from[current]
				cells.push_front(current)
			return cells
		for edge in (_edges.get(current, []) as Array):
			if not _edge_allowed(current, edge):
				continue
			var next_cell: Vector2i = edge["to"]
			# Danger (non-deadly) hazards stay traversable but cost 4x - taken only when
			# no clean route exists.
			var next_cost: float = cost_so_far[current] + float(edge["cost"]) * (4.0 if _segment_hazard(current, next_cell) == 1 else 1.0)
			if not cost_so_far.has(next_cell) or next_cost < float(cost_so_far[next_cell]):
				cost_so_far[next_cell] = next_cost
				came_from[next_cell] = current
				if not open.has(next_cell):
					open.append(next_cell)
	return []

func _edge_allowed(from_cell: Vector2i, edge: Dictionary) -> bool:
	if _segment_hazard(from_cell, edge["to"]) == 2:
		return false
	if not ledge_restriction:
		return true
	var kind: String = str(edge["kind"])
	if kind == "walk":
		return true
	if kind == "fall":
		var tile: float = float(_tilemap.tile_set.tile_size.y) if _tilemap != null else 32.0
		return float(((edge["to"] as Vector2i).y - from_cell.y)) * tile <= ledge_leniency
	return false

func _edge_kind(from_cell: Vector2i, to_cell: Vector2i) -> String:
	for edge in (_edges.get(from_cell, []) as Array):
		if edge["to"] == to_cell:
			return str(edge["kind"])
	return "walk"

## @ace_hidden
func _refresh_debug() -> void:
	if not debug_draw:
		if _debug_line != null and is_instance_valid(_debug_line):
			_debug_line.clear_points()
		return
	if _debug_line == null or not is_instance_valid(_debug_line):
		_debug_line = Line2D.new()
		_debug_line.width = 3.0
		_debug_line.default_color = Color(0.2, 0.9, 0.5, 0.8)
		_debug_line.top_level = true
		host.add_child(_debug_line)
	_debug_line.clear_points()
	if _path.is_empty():
		return
	_debug_line.add_point(host.global_position)
	for index in range(_path_index, _path.size()):
		_debug_line.add_point(_path[index]["world"])

# Platformer pathfinding: attach as a SIBLING of PlatformerMovement under a CharacterBody2D. Build Nav Graph from your TileMapLayer once, then Find Path To - the behavior derives jump reach from the movement pack and drives it through the ai_move_axis seam. Stairs and tile slopes walk (adjacent cells one step up/down are WALK edges); gaps and ledges route through jump arcs and fall drops.
