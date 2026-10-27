# Pack source - platformer_pathfinding. The behaviour code this pack ships, as real GDScript:
# highlighted, checked and breakpointable here, and assembled into the pack by
# Lib.pack_from_source. Every #region, and the body of every top-level func, is one piece of the
# sheet; everything else is scaffolding the pack declares for itself at build time and never
# reads from here.
extends Node

# The behaviour's host and its Inspector variables. The builder's manifest emits them (with their
# tooltips and dropdowns); these lines exist so this file parses and type-checks on its own.
var host: CharacterBody2D = null
var auto_control: bool = true
var arrive_distance: float = 10.0
var max_fall_distance: float = 320.0
var jump_height_override: float = 0.0
var jump_distance_override: float = 0.0
var debug_draw: bool = false
var variable_jump: bool = true
var ledge_restriction: bool = false
var ledge_leniency: float = 0.0
var jump_positioning: String = "relaxed"
var coyote_time: float = 0.12
var repath_interval: float = 0.5
var repath_threshold: float = 24.0
var stuck_timeout: float = 1.5
var fallback_move_speed: float = 200.0
var fallback_jump_velocity: float = -400.0
var fallback_gravity: float = 980.0
var nav_enabled: bool = true
var path_strategy: String = "balanced"
var smooth_paths: bool = true
var max_search_nodes: int = 2000
var max_traversal_drop: float = -1.0
var drift_repath_distance: float = 0.0
var double_jump_links: bool = true
var hazard_margin: float = 0.0
var danger_cost_multiplier: float = 4.0
var auto_build: bool = true
var map_tag: String = ""
var grid_cell_size: float = 32.0
var crowd_arrivals: bool = false
var multi_agent_avoidance: bool = false
var idle_separation: float = 0.0
var separation_cooldown: float = 5.0
var separation_give_up_time: float = 2.0
var debug_draw_graph: bool = false
var debug_log: bool = false

#region state
# --- Internal state (the graph lives per agent, or per map tag when one is set) ---
var _tilemap: TileMapLayer = null
var _movement: Node = null
var _gravity_angle_warned: bool = false
## Standable cells (the cell the agent's feet occupy) -> true.
var _nodes: Dictionary = {}
## cell -> Array of {"to": Vector2i, "kind": String, "cost": float} (portal links also carry
## "portal_id"). Kinds: walk, jump, double_jump, coyote_jump, fall, fall_through, portal,
## portal_gradual, platform.
var _edges: Dictionary = {}
## The obstacle map the last build read: cell -> "solid" / "jump_thru" / "slope_left" /
## "slope_right". Clear cells are simply absent.
var _states: Dictionary = {}
## Hand-set tile states (Set Tile State, Load Obstacle Map JSON) layered over the scan; they
## survive Regenerate. "clear" erases whatever the scan found.
var _tile_overrides: Dictionary = {}
## Tile states scanned from collision bodies (Scan Collision Bodies); they survive Regenerate.
var _body_states: Dictionary = {}
## A tilemap-less grid (Create Obstacle Map / Load Obstacle Map JSON): its size and origin.
var _custom_grid: bool = false
var _custom_size: Vector2i = Vector2i.ZERO
var _grid_origin: Vector2 = Vector2.ZERO
## The active path: Array of {"world": Vector2, "action": String, "cell": Vector2i} (portal
## waypoints also carry "portal_id").
var _path: Array = []
var _path_index: int = 0
var _jumped_this_segment: bool = false
var _jump_released: bool = false
var _jump_release_velocity: float = 0.0
var _second_jump_done: bool = false
var _dropped_this_segment: bool = false
var _move_axis: float = 0.0
var _debug_line: Line2D = null
var _debug_graph: Node2D = null
## Registered portals: {"id", "from", "to", "both", "type" ("instant"/"gradual"), "cost",
## "speed", "tag", "ignore_hazards"} - they survive regenerate.
var _portals: Array = []
var _next_portal_id: int = 1
var _last_portal_id: int = -1
## Elevator groups: group name -> Array of stop positions (Vector2).
var _elevator_stops: Dictionary = {}
## Portal execution: the portal being taken, whether the sheet paused it, and the gradual move.
var _current_portal: Dictionary = {}
var _current_portal_exit: Vector2 = Vector2.ZERO
var _portal_entering: bool = false
var _portal_paused: bool = false
var _portal_traversing: bool = false
var _portal_from: Vector2 = Vector2.ZERO
var _portal_to: Vector2 = Vector2.ZERO
var _portal_progress: float = 0.0
## World-space hazards: {"id", "kind" ("rect"/"circle"/"tracked"), "rect" or "center"/"radius"
## or "node"/"radius", "deadly"}. Applied at ROUTING time (no rebuild needed when they change):
## deadly blocks links outright, danger multiplies their cost.
var _hazards: Array = []
var _next_hazard_id: int = 1
var _last_hazard_id: int = 0
var _was_in_hazard: bool = false
## Registered moving platforms: {"node": Node2D, "a": Vector2, "b": Vector2} - survive
## regenerate. Each becomes a "platform" link; the drive waits, boards, and rides it.
var _moving_platforms: Array = []
# Follow mode (Find Path To Node): the tracked node + where the current path was aimed.
var _follow_target: Node = null
var _path_goal: Vector2 = Vector2.ZERO
var _path_goal_cell: Vector2i = Vector2i.ZERO
var _path_cost: float = 0.0
var _fail_reason: String = ""
var _last_search_fail: String = ""
var _last_route_edges: Array = []
var _goal_mode: String = "nearest"
var _repath_clock: float = 0.0
## A route whose last waypoint must land on an exact x (patrol ends, side-of-node, ledge offsets).
var _exact_final: float = NAN
var _exact_arrival: bool = false
# Coyote grace: seconds since the host last stood on the floor.
var _floor_grace: float = 0.0
# Stuck watchdog: best distance seen toward the current waypoint + time without progress.
var _best_waypoint_distance: float = INF
var _stuck_clock: float = 0.0
var _teleport_grace: bool = false
# Budget-deferred request (this agent is queued for a later tick).
var _path_pending: bool = false
var _pending_goal: Vector2 = Vector2.ZERO
var _pending_goal_mode: String = "nearest"
# Patrol: the two ends of the platform, the walking direction, and the dwell at each end.
var _patrolling: bool = false
var _patrol_ends: Array = []
var _patrol_dir: int = 0
var _patrol_dwell: float = 0.0
var _patrol_dwelling: bool = false
var _patrol_clock: float = 0.0
# Jump Toward: a pathless full-strength leap at a point.
var _jump_toward_active: bool = false
var _jump_toward_launched: bool = false
var _jump_toward_airborne: bool = false
var _jump_toward_target: Vector2 = Vector2.ZERO
# Find Path To Node Side: the node, the side and the spot the route was aimed at.
var _side_request: Dictionary = {}
var _reached_side: int = 0
# Idle separation: time spent trying, and the rest after giving up.
var _separation_clock: float = 0.0
var _separation_rest: float = 0.0
var _separating: bool = false
# Crowd arrivals: the goal-claim key this agent holds.
var _claimed_key: String = ""
# The SHARED path budget: statics are one value across every agent of this behavior, so
# N chasers repathing at once spread their A* runs over frames instead of spiking one.
static var _shared_max_paths_per_tick: int = 8
static var _shared_tick_id: int = -1
static var _shared_paths_this_tick: int = 0
# Every agent that has routed or ticked (instance id -> true), for crowd, avoidance and spacing.
static var _agent_ids: Dictionary = {}
# Crowd arrivals: "<map key>|<cell>" -> the instance id of the agent that claimed that goal.
static var _goal_claims: Dictionary = {}
# Map tags: tag -> the shared graph, obstacle edits, portals, hazards and platforms.
static var _shared_maps: Dictionary = {}
#endregion

#region signals
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

## Fires when the agent reaches a portal's entrance, BEFORE the portal moves it. Call Pause At
## Portal here to play a door animation first; Current Portal Id names the portal.
## @ace_trigger
## @ace_name("On Portal Entered")
signal portal_entered

## Fires when Jump Toward actually leaves the ground. Jump Toward Target is the aimed point.
## @ace_trigger
## @ace_name("On Jump Toward Launched")
signal jump_toward_launched

## Fires each time a patrolling agent reaches one end of its platform, before it turns.
## @ace_trigger
## @ace_name("On Patrol End Reached")
signal patrol_end_reached

## Fires when a patrolling agent starts waiting at an end (not fired for a dwell of 0).
## @ace_trigger
## @ace_name("On Patrol Dwell Started")
signal patrol_dwell_started

## Fires when the wait at a patrol end is over and the agent turns; Patrol Direction already
## reads the new direction inside it.
## @ace_trigger
## @ace_name("On Patrol Dwell Finished")
signal patrol_dwell_finished

## Fires when a Find Path To Node Side route arrives beside the node; Reached Side says which.
## @ace_trigger
## @ace_name("On Node Side Reached")
signal node_side_reached

## Fires when Clear Nav Graph drops the graph and the obstacle map.
## @ace_trigger
## @ace_name("On Nav Graph Cleared")
signal nav_graph_cleared
#endregion

#region queries
## @ace_condition
## @ace_name("Is Path Pending")
func is_path_pending() -> bool:
	return _path_pending

## @ace_condition
## @ace_name("Is In Hazard")
func is_in_hazard() -> bool:
	return host != null and _point_in_hazard(host.global_position, false)

## @ace_condition
## @ace_name("Has Path")
func has_path() -> bool:
	return not _path.is_empty()

## @ace_condition
## @ace_name("Path Wants Jump")
func path_wants_jump() -> bool:
	if _path.is_empty() or _jumped_this_segment or host == null:
		return false
	var waypoint: Dictionary = _path[_path_index]
	if waypoint["action"] == "jump" or waypoint["action"] == "double_jump":
		return true
	if waypoint["action"] == "coyote_jump":
		return not host.is_on_floor() and _floor_grace >= _coyote_window() * 0.5
	# Step assist: a close-and-higher walk waypoint needs a hop on full-block stairs.
	var tile: float = _tile_px()
	var target: Vector2 = waypoint["world"]
	return waypoint["action"] == "walk" and target.y < host.global_position.y - 8.0 and absf(target.x - host.global_position.x) < tile * 1.5

## @ace_expression
## @ace_name("Path Move Axis")
func path_move_axis() -> float:
	return _move_axis

## @ace_expression
## @ace_name("Waypoint Count")
func waypoint_count() -> int:
	return _path.size()

## @ace_expression
## @ace_name("Current Waypoint Index")
func current_waypoint_index() -> int:
	return _path_index

## @ace_expression
## @ace_name("Current Waypoint X")
func current_waypoint_x() -> float:
	return (_path[_path_index]["world"] as Vector2).x if not _path.is_empty() else 0.0

## @ace_expression
## @ace_name("Current Waypoint Y")
func current_waypoint_y() -> float:
	return (_path[_path_index]["world"] as Vector2).y if not _path.is_empty() else 0.0

## @ace_expression
## @ace_name("Current Path Action")
func current_path_action() -> String:
	return str(_path[_path_index]["action"]) if not _path.is_empty() else ""
#endregion

#region grid
## The grid's cell size in pixels: the TileMapLayer's tile height, or Grid Cell Size for a
## tilemap-less map.
## @ace_hidden
func _tile_px() -> float:
	if _tilemap != null and _tilemap.tile_set != null:
		return float(_tilemap.tile_set.tile_size.y)
	return maxf(grid_cell_size, 1.0)

## The cell a world position falls in. Tree-safe: outside a scene tree (tools, tests) the
## tilemap's own offset stands in for the global transform.
## @ace_hidden
func _world_to_cell(world: Vector2) -> Vector2i:
	if _tilemap != null:
		var local: Vector2 = _tilemap.to_local(world) if _tilemap.is_inside_tree() else world - _tilemap.position
		return _tilemap.local_to_map(local)
	var tile: float = _tile_px()
	return Vector2i(floori((world.x - _grid_origin.x) / tile), floori((world.y - _grid_origin.y) / tile))

## @ace_hidden
func _cell_world(cell: Vector2i) -> Vector2:
	if _tilemap != null:
		var local: Vector2 = _tilemap.map_to_local(cell)
		return _tilemap.to_global(local) if _tilemap.is_inside_tree() else local + _tilemap.position
	var tile: float = _tile_px()
	return _grid_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * tile

## True when a grid exists to build on (a TileMapLayer or a custom map).
## @ace_hidden
func _has_grid() -> bool:
	return _tilemap != null or _custom_grid

## What one painted tile is to the navigator, read off its collision polygons: no polygon is
## clear, all-one-way polygons are a jump-through platform, a top edge that rises by more than a
## quarter tile across the cell is a slope ("slope_left" rises to the right, "/"; "slope_right"
## rises to the left, "\"), anything else is solid.
## @ace_hidden
func _tile_state_of(tile_data: TileData) -> String:
	if _tilemap.tile_set.get_physics_layers_count() == 0:
		return ""
	var count: int = tile_data.get_collision_polygons_count(0)
	if count == 0:
		return ""
	var one_way: bool = true
	for polygon_index in range(count):
		if not tile_data.is_collision_polygon_one_way(0, polygon_index):
			one_way = false
	if one_way:
		return "jump_thru"
	var half: float = float(_tilemap.tile_set.tile_size.x) * 0.5
	var left_top: float = INF
	var right_top: float = INF
	for point: Vector2 in tile_data.get_collision_polygon_points(0, 0):
		if point.x <= -half * 0.5:
			left_top = minf(left_top, point.y)
		if point.x >= half * 0.5:
			right_top = minf(right_top, point.y)
	if left_top == INF or right_top == INF:
		return "solid"
	if right_top < left_top - half * 0.5:
		return "slope_left"
	if left_top < right_top - half * 0.5:
		return "slope_right"
	return "solid"

## The live state of one cell: a hand-set override, else a scanned body, else the painted tile.
## @ace_hidden
func _live_state(cell: Vector2i) -> String:
	if _tile_overrides.has(cell):
		return str(_tile_overrides[cell])
	if _body_states.has(cell):
		return str(_body_states[cell])
	if _tilemap != null:
		var tile_data: TileData = _tilemap.get_cell_tile_data(cell)
		if tile_data != null:
			var painted: String = _tile_state_of(tile_data)
			if painted != "":
				return painted
	return "clear"

## Whether a state stops a body (solid ground and slopes do; a jump-through platform does not).
## @ace_hidden
func _blocks_state(state: String) -> bool:
	return state == "solid" or state == "slope_left" or state == "slope_right"

## The merged obstacle map: painted tiles, then scanned bodies, then the hand-set overrides.
## @ace_hidden
func _scan_states() -> void:
	_states.clear()
	if _tilemap != null:
		for cell in _tilemap.get_used_cells():
			var tile_data: TileData = _tilemap.get_cell_tile_data(cell)
			if tile_data != null:
				var painted: String = _tile_state_of(tile_data)
				if painted != "":
					_states[cell] = painted
	for cell in _body_states:
		_states[cell] = _body_states[cell]
	for cell in _tile_overrides:
		if str(_tile_overrides[cell]) == "clear":
			_states.erase(cell)
		else:
			_states[cell] = _tile_overrides[cell]

## Joins a map tag's shared map (or leaves the agent its own when the tag is empty): every
## container below is the SAME object for every agent on the tag, so one build serves them all.
## Returns true when the shared map is already built over this grid.
## @ace_hidden
func _bind_shared_map(grid_id: int) -> bool:
	if map_tag == "":
		return false
	var entry: Dictionary = _shared_maps.get(map_tag, {})
	if entry.is_empty():
		entry = {"grid_id": 0, "nodes": {}, "edges": {}, "states": {}, "overrides": {}, "bodies": {}, "portals": [], "hazards": [], "platforms": [], "elevators": {}}
		_shared_maps[map_tag] = entry
	var built: bool = int(entry["grid_id"]) == grid_id and not (entry["nodes"] as Dictionary).is_empty()
	entry["grid_id"] = grid_id
	_nodes = entry["nodes"]
	_edges = entry["edges"]
	_states = entry["states"]
	_tile_overrides = entry["overrides"]
	_body_states = entry["bodies"]
	_portals = entry["portals"]
	_hazards = entry["hazards"]
	_moving_platforms = entry["platforms"]
	_elevator_stops = entry["elevators"]
	return built

## Builds the graph from the first physics TileMapLayer in the running scene when a route is
## asked for before any graph exists (Auto Build on).
## @ace_hidden
func _auto_build() -> void:
	if not auto_build or _has_grid() or not is_inside_tree():
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	for candidate in scene_root.find_children("*", "TileMapLayer", true, false):
		var layer: TileMapLayer = candidate as TileMapLayer
		if layer != null and layer.tile_set != null and layer.tile_set.get_physics_layers_count() > 0:
			build_nav_graph(layer)
			return
#endregion

#region helpers
## Whether a world point sits in any hazard (deadly_only narrows to deadly ones).
## @ace_hidden
func _point_in_hazard(world: Vector2, deadly_only: bool) -> bool:
	for hazard in _hazards:
		if (not deadly_only or bool(hazard["deadly"])) and _hazard_hit(hazard, world, 0.0):
			return true
	return false

## Whether one hazard covers a point, grown by `margin` pixels.
## @ace_hidden
func _hazard_hit(hazard: Dictionary, world: Vector2, margin: float) -> bool:
	var kind: String = str(hazard.get("kind", "rect"))
	if kind == "circle":
		return world.distance_to(hazard["center"]) <= float(hazard["radius"]) + margin
	if kind == "tracked":
		var followed: Variant = hazard.get("node")
		if not is_instance_valid(followed) or not (followed is Node2D):
			return false
		return world.distance_to((followed as Node2D).global_position) <= float(hazard["radius"]) + margin
	return (hazard["rect"] as Rect2).grow(margin).has_point(world)

## Drops tracked hazards whose node has been freed.
## @ace_hidden
func _prune_tracked_hazards() -> void:
	for index in range(_hazards.size() - 1, -1, -1):
		var hazard: Dictionary = _hazards[index]
		if str(hazard.get("kind", "rect")) == "tracked" and not is_instance_valid(hazard.get("node")):
			_hazards.remove_at(index)

## Hazard verdict for one link (endpoints + midpoint): 0 = clear, 1 = danger, 2 = deadly.
## Hazard Margin grows every hazard into a danger buffer.
## @ace_hidden
func _segment_hazard(from_cell: Vector2i, to_cell: Vector2i) -> int:
	if _hazards.is_empty():
		return 0
	var verdict: int = 0
	for sample in [_cell_world(from_cell), _cell_world(to_cell), (_cell_world(from_cell) + _cell_world(to_cell)) * 0.5]:
		for hazard in _hazards:
			if _hazard_hit(hazard, sample, 0.0):
				if bool(hazard["deadly"]):
					return 2
				verdict = 1
			elif hazard_margin > 0.0 and _hazard_hit(hazard, sample, hazard_margin):
				verdict = 1
	return verdict

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
			# The planner's frame is straight-down gravity: the graph, jump arcs, and
			# steering all reason in screen x/y. A rotated movement frame would make
			# every planned path wrong, so say so LOUDLY once instead of failing quietly.
			var movement_angle: Variant = _movement.get("gravity_angle")
			if movement_angle != null and not is_equal_approx(float(movement_angle), 90.0) and not _gravity_angle_warned:
				_gravity_angle_warned = true
				push_warning("[PlatformerPathfinding] The movement pack's gravity_angle is %.0f - pathfinding plans with straight-down gravity (90) and its paths will be wrong under rotated gravity." % float(movement_angle))
			return _movement
	return null

## Jump reach in PIXELS (x = distance, y = height), derived from the movement pack's physics
## (the overrides win when set): height = v^2/2g, distance = speed * full air time, both with a
## 0.9 safety margin.
## @ace_hidden
func _jump_reach_px() -> Vector2:
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
	return Vector2(distance_px, height_px)

## Jump reach in CELLS, rounded up (the graph's standing jump box).
## @ace_hidden
func _jump_reach_cells() -> Vector2i:
	var tile: float = _tile_px()
	var reach: Vector2 = _jump_reach_px()
	return Vector2i(maxi(int(ceil(reach.x / tile)), 1), maxi(int(ceil(reach.y / tile)), 1))

## The run speed the drive moves at (the sibling's when present).
## @ace_hidden
func _run_speed() -> float:
	var movement: Node = _find_movement()
	if movement != null and movement.get("move_speed") != null:
		return float(movement.get("move_speed"))
	return fallback_move_speed

## The coyote window an AI jump can really use: this behavior's Coyote Time, capped by the
## sibling's own (its jump() refuses a late takeoff past that).
## @ace_hidden
func _coyote_window() -> float:
	var movement: Node = _find_movement()
	if movement != null and movement.get("coyote_time") != null:
		return minf(coyote_time, float(movement.get("coyote_time")))
	return coyote_time

## True when the sibling can double jump and Double Jump Links is on.
## @ace_hidden
func _double_jump_ready() -> bool:
	if not double_jump_links:
		return false
	var movement: Node = _find_movement()
	return movement != null and movement.get("max_jumps") != null and int(movement.get("max_jumps")) >= 2

## The gravity the drive should reason with (the sibling's when present).
## @ace_hidden
func _drive_gravity() -> float:
	var movement: Node = _find_movement()
	if movement != null and movement.get("gravity") != null:
		return maxf(float(movement.get("gravity")), 1.0)
	return maxf(fallback_gravity, 1.0)

## The upward speed still needed to climb to `target` from here (plus a half-tile margin) -
## variable jump releases the button once remaining velocity drops to this, so each hop
## rises just as far as its arc requires.
## @ace_hidden
func _release_velocity_for(target: Vector2) -> float:
	var rise: float = maxf(host.global_position.y - target.y, 0.0) + 20.0
	return sqrt(2.0 * _drive_gravity() * rise)

## The registered portal with this id, or {}.
## @ace_hidden
func _portal_by_id(portal_id: int) -> Dictionary:
	for portal in _portals:
		if int(portal["id"]) == portal_id:
			return portal
	return {}

## Registers a portal and links it into the built graph; returns its id.
## @ace_hidden
func _add_portal_record(from: Vector2, to: Vector2, both: bool, portal_kind: String, cost: float, speed: float, tag: String) -> int:
	var portal: Dictionary = {"id": _next_portal_id, "from": from, "to": to, "both": both, "type": portal_kind,
		"cost": cost, "speed": speed, "tag": tag, "ignore_hazards": false}
	_next_portal_id += 1
	_portals.append(portal)
	_last_portal_id = int(portal["id"])
	if not _nodes.is_empty():
		_apply_portal(portal)
		_refresh_graph_overlay()
	return _last_portal_id

## Injects one portal into the built graph as a link between the standable nodes nearest its
## endpoints: "portal" (instant, base cost 2) or "portal_gradual" (cost from its travel time
## measured in walking cells). The portal's Cost scales either.
## @ace_hidden
func _apply_portal(portal: Dictionary) -> void:
	var from_node: Vector2i = _nearest_node(portal["from"], 2)
	var to_node: Vector2i = _nearest_node(portal["to"], 2)
	if from_node == Vector2i.MAX or to_node == Vector2i.MAX:
		return
	var scale: float = maxf(float(portal.get("cost", 1.0)), 0.01)
	var kind: String = "portal"
	var cost: float = 2.0 * scale
	if str(portal.get("type", "instant")) == "gradual":
		kind = "portal_gradual"
		var seconds: float = (portal["from"] as Vector2).distance_to(portal["to"]) / maxf(float(portal.get("speed", 100.0)), 1.0)
		cost = maxf(seconds * _run_speed() / _tile_px(), 0.5) * scale
	_add_edge(from_node, to_node, kind, cost)
	(_edges[from_node] as Array).back()["portal_id"] = portal["id"]
	if bool(portal["both"]):
		_add_edge(to_node, from_node, kind, cost)
		(_edges[to_node] as Array).back()["portal_id"] = portal["id"]

## Removes every link a portal put into the graph.
## @ace_hidden
func _unlink_portal(portal_id: int) -> void:
	for cell in _edges:
		var kept: Array = []
		for edge in (_edges[cell] as Array):
			if int(edge.get("portal_id", -1)) != portal_id:
				kept.append(edge)
		_edges[cell] = kept

## Re-links one portal after its position, cost or speed changed.
## @ace_hidden
func _relink_portal(portal: Dictionary) -> void:
	_unlink_portal(int(portal["id"]))
	if not _nodes.is_empty():
		_apply_portal(portal)
	_refresh_graph_overlay()

## Whether a tag matches a portal's comma-separated tags (an empty tag matches every portal).
## @ace_hidden
func _portal_has_tag(portal: Dictionary, tag: String) -> bool:
	if tag == "":
		return true
	for token in str(portal["tag"]).split(","):
		if token.strip_edges() == tag:
			return true
	return false

## Injects one moving platform as a slow bidirectional "platform" link between the
## standable nodes nearest its two travel endpoints.
## @ace_hidden
func _apply_moving_platform(ride: Dictionary) -> void:
	var from_node: Vector2i = _nearest_node(ride["a"], 3)
	var to_node: Vector2i = _nearest_node(ride["b"], 3)
	if from_node == Vector2i.MAX or to_node == Vector2i.MAX:
		return
	var span: float = (ride["a"] as Vector2).distance_to(ride["b"]) / _tile_px()
	_add_edge(from_node, to_node, "platform", span * 1.3)
	_add_edge(to_node, from_node, "platform", span * 1.3)

## The registered platform serving this waypoint (one of its endpoints is near it).
## @ace_hidden
func _platform_for_waypoint(target: Vector2) -> Dictionary:
	for ride in _moving_platforms:
		if not is_instance_valid(ride["node"]):
			continue
		if (ride["a"] as Vector2).distance_to(target) < 96.0 or (ride["b"] as Vector2).distance_to(target) < 96.0:
			return ride
	return {}

## Steering for a platform leg: wait BESIDE the track (a descending platform must land on
## empty space), board when it arrives at the near side, stand centered while it travels,
## and walk off once it reaches the far side. Waiting and riding legitimately stall
## progress, so the stuck watchdog is held off for the leg.
## @ace_hidden
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

## Steering while a platform leg is still AHEAD in the path: the walk nodes feeding a
## boarding point sit inside the track's crush zone, so the agent holds STILL at the wait
## spot beside the track and only walks in once the platform is parked at the boarding
## side (never strolls under a platform that is about to land on it).
## @ace_hidden
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

## True while standing on a registered platform that is BETWEEN its endpoints - the
## window where a fresh route would mis-start from a ground node and steer the rider
## off the shaft in mid-air.
## @ace_hidden
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
	_second_jump_done = false
	_dropped_this_segment = false
	_best_waypoint_distance = INF
	_stuck_clock = 0.0
	_path_index += 1
	waypoint_reached.emit()
	if _path_index >= _path.size():
		var side: Dictionary = _side_request
		_finish_path()
		path_complete.emit()
		if not side.is_empty():
			_side_request = {}
			_check_side_reached(side)
		if _patrolling and not _patrol_dwelling and _path.is_empty():
			_on_patrol_end()

## Clears the active route and hands the movement sibling back (ai_controlled off) - what Stop
## Pathfinding and an arrival both do.
## @ace_hidden
func _finish_path() -> void:
	_path = []
	_path_index = 0
	_move_axis = 0.0
	_jumped_this_segment = false
	_second_jump_done = false
	_dropped_this_segment = false
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

## Turns physics processing back on for a parked agent (the coyote window starts closed).
## @ace_hidden
func _wake() -> void:
	if not is_physics_processing():
		_floor_grace = INF
		set_physics_process(true)

## Records why a route failed and fires On Path Failed.
## @ace_hidden
func _fail(reason: String) -> void:
	_fail_reason = reason
	if debug_log:
		print("[PlatformerPathfinding] %s: no route (%s)" % [str(host.name) if host != null else "?", reason])
	path_failed.emit()

## The route core every request funnels through: budget, auto build, nearest nodes, crowd
## claims, A*, the waypoint list and smoothing. Public verbs add their own intent around it.
## @ace_hidden
func _route(x: float, y: float, mode: String) -> void:
	if not nav_enabled:
		return
	_register_agent()
	# A route to walk is work every frame again. Coming back from parked the floor
	# bookkeeping was not being kept, so the coyote window starts closed rather than
	# handing out a takeoff the agent did not earn while it stood still.
	_wake()
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
	if _nodes.is_empty():
		_auto_build()
	if _nodes.is_empty():
		push_warning("[PlatformerPathfinding] Find Path To called before the nav graph exists - call Build Nav Graph From Tilemap (usually On Ready) first.")
		_fail("no_graph")
		return
	if host == null:
		_fail("no_host")
		return
	var start: Vector2i = _nearest_node(host.global_position, 3)
	var goal: Vector2i = _nearest_node(Vector2(x, y), 2 if mode == "reach" else 1000000)
	if start == Vector2i.MAX or goal == Vector2i.MAX:
		_finish_path()
		_fail("no_start_node" if start == Vector2i.MAX else "no_goal_node")
		return
	if crowd_arrivals and not _patrolling:
		goal = _claim_goal(goal)
	# "nearest" never fails on a cut-off goal: it routes to the closest node it can reach.
	var cells: Array = _astar(start, goal, mode != "reach")
	if cells.is_empty():
		_finish_path()
		_fail(_last_search_fail)
		return
	_path_goal = Vector2(x, y)
	_path_goal_cell = cells.back()
	_goal_mode = mode
	_fail_reason = ""
	_path = []
	_path_cost = 0.0
	for index in range(cells.size()):
		var edge: Dictionary = _last_route_edges[index]
		var action: String = "walk" if index == 0 else str(edge.get("kind", "walk"))
		var waypoint: Dictionary = {"world": _cell_world(cells[index]), "action": action, "cell": cells[index]}
		if edge.has("portal_id"):
			waypoint["portal_id"] = edge["portal_id"]
		if index > 0:
			_path_cost += _edge_cost(cells[index - 1], edge)
		_path.append(waypoint)
	if smooth_paths:
		_smooth_path()
	# A route aimed at an exact spot (patrol ends, beside a node, back from a ledge) lands its
	# last waypoint on that x while the spot is still over the goal node's own ground.
	_exact_arrival = false
	if not is_nan(_exact_final) and absf(_exact_final - (_path.back()["world"] as Vector2).x) <= _tile_px() * 1.5:
		_path.back()["world"] = Vector2(_exact_final, (_path.back()["world"] as Vector2).y)
		_exact_arrival = true
	_path_index = 0
	# A fresh route starts at OUR nearest node - when we already stand on it, aim at the
	# next waypoint instead (a repath mid-stride must never walk the agent backward, or a
	# chaser re-finding on a timer thrashes in place at node boundaries).
	if _path.size() > 1 and host.global_position.distance_to(_path[0]["world"]) <= _tile_px():
		_path_index = 1
	_jumped_this_segment = false
	_second_jump_done = false
	_dropped_this_segment = false
	_best_waypoint_distance = INF
	_stuck_clock = 0.0
	if debug_log:
		print("[PlatformerPathfinding] %s: route of %d waypoints, cost %.1f" % [str(host.name), _path.size(), _path_cost])
	path_found.emit()

## Drops the walk waypoints in the middle of a straight same-row walk: the agent then walks
## the whole stretch in one leg instead of stopping at every cell.
## @ace_hidden
func _smooth_path() -> void:
	var index: int = 1
	while index < _path.size() - 1:
		var before: Dictionary = _path[index - 1]
		var here: Dictionary = _path[index]
		var after: Dictionary = _path[index + 1]
		var flat: bool = (before["cell"] as Vector2i).y == (here["cell"] as Vector2i).y and (here["cell"] as Vector2i).y == (after["cell"] as Vector2i).y
		if flat and here["action"] == "walk" and after["action"] == "walk" and (index > 1 or before["action"] == "walk"):
			_path.remove_at(index)
		else:
			index += 1

## Coarse clearance for a jump/fall arc: the cells along the chord, lifted one cell for
## the rise, must be free. Coarse on purpose - it favours routing in open layouts.
## @ace_hidden
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

## True when a link already joins these two cells.
## @ace_hidden
func _has_edge(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	for edge in (_edges.get(from_cell, []) as Array):
		if edge["to"] == to_cell:
			return true
	return false

## The standable node nearest a world position (within max_cells), or Vector2i.MAX.
## @ace_hidden
func _nearest_node(world: Vector2, max_cells: int) -> Vector2i:
	if not _has_grid():
		return Vector2i.MAX
	var around: Vector2i = _world_to_cell(world)
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

## Which side of a node is a LEDGE (no walk link that way and open air beside it): -1 left,
## 1 right, 2 both (an island), 0 neither.
## @ace_hidden
func _ledge_side(cell: Vector2i) -> int:
	var left: bool = _is_ledge_toward(cell, -1)
	var right: bool = _is_ledge_toward(cell, 1)
	if left and right:
		return 2
	if left:
		return -1
	if right:
		return 1
	return 0

## @ace_hidden
func _is_ledge_toward(cell: Vector2i, direction: int) -> bool:
	if not _nodes.has(cell):
		return false
	for dy in [-1, 0, 1]:
		if _nodes.has(cell + Vector2i(direction, dy)):
			return false
	return not _blocks_state(str(_states.get(cell + Vector2i(direction, 0), "")))

## Every node reachable from `start` by WALK links only - the platform it stands on, slopes
## and stairs included.
## @ace_hidden
func _walk_component(start: Vector2i) -> Dictionary:
	var seen: Dictionary = {start: true}
	var frontier: Array = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for edge in (_edges.get(cell, []) as Array):
			if str(edge["kind"]) == "walk" and not seen.has(edge["to"]):
				seen[edge["to"]] = true
				frontier.append(edge["to"])
	return seen

## The nearest ledge on this agent's platform in a direction (-1 left, 1 right), or MAX.
## @ace_hidden
func _nearest_ledge_cell(direction: int) -> Vector2i:
	if host == null:
		return Vector2i.MAX
	var here: Vector2i = _nearest_node(host.global_position, 3)
	if here == Vector2i.MAX:
		return Vector2i.MAX
	var best: Vector2i = Vector2i.MAX
	var best_gap: int = 1000000
	for cell in _walk_component(here):
		var gap: int = (cell.x - here.x) * direction
		if gap >= 0 and gap < best_gap and _is_ledge_toward(cell, direction):
			best_gap = gap
			best = cell
	return best

## Builds the waypoint list behind A*'s cell path, from the links it came through.
## @ace_hidden
func _reconstruct(goal: Vector2i, came_from: Dictionary, came_edge: Dictionary) -> Array:
	var current: Vector2i = goal
	var cells: Array = [current]
	var edges: Array = [came_edge.get(current, {})]
	while came_from.has(current):
		current = came_from[current]
		cells.push_front(current)
		edges.push_front(came_edge.get(current, {}))
	edges[0] = {}
	_last_route_edges = edges
	return cells

## A* over the graph's links under the active strategy, filters and hazards. Returns the cell
## path or []. With allow_partial a cut-off goal yields the route to the closest node reached.
## @ace_hidden
func _astar(start: Vector2i, goal: Vector2i, allow_partial: bool = false) -> Array:
	_last_route_edges = []
	_last_search_fail = ""
	var avoid: Dictionary = _agent_avoidance_costs() if multi_agent_avoidance else {}
	var open: Array = [start]
	var came_from: Dictionary = {}
	var came_edge: Dictionary = {}
	var cost_so_far: Dictionary = {start: 0.0}
	var closest: Vector2i = start
	var closest_gap: float = Vector2(goal - start).length()
	var expanded: int = 0
	while not open.is_empty():
		if expanded >= maxi(max_search_nodes, 1):
			_last_search_fail = "max_nodes_reached"
			break
		var best_index: int = 0
		for index in range(1, open.size()):
			var here: Vector2i = open[index]
			if cost_so_far[here] + Vector2(goal - here).length() < cost_so_far[open[best_index]] + Vector2(goal - (open[best_index] as Vector2i)).length():
				best_index = index
		var current: Vector2i = open.pop_at(best_index)
		expanded += 1
		var gap: float = Vector2(goal - current).length()
		if gap < closest_gap:
			closest_gap = gap
			closest = current
		if current == goal:
			return _reconstruct(current, came_from, came_edge)
		for edge in (_edges.get(current, []) as Array):
			if not _edge_allowed(current, edge):
				continue
			var next_cell: Vector2i = edge["to"]
			# Danger (non-deadly) hazards stay traversable but cost Danger Cost Multiplier -
			# taken only when no clean route exists.
			var danger: bool = not _ignores_hazards(edge) and _segment_hazard(current, next_cell) == 1
			var next_cost: float = cost_so_far[current] + _edge_cost(current, edge) * (danger_cost_multiplier if danger else 1.0) + float(avoid.get(next_cell, 0.0))
			if not cost_so_far.has(next_cell) or next_cost < float(cost_so_far[next_cell]):
				cost_so_far[next_cell] = next_cost
				came_from[next_cell] = current
				came_edge[next_cell] = edge
				if not open.has(next_cell):
					open.append(next_cell)
	if _last_search_fail == "":
		_last_search_fail = "no_path"
	if allow_partial:
		return _reconstruct(closest, came_from, came_edge)
	return []

## Whether a link is a portal set to ignore hazards.
## @ace_hidden
func _ignores_hazards(edge: Dictionary) -> bool:
	if not edge.has("portal_id"):
		return false
	return bool(_portal_by_id(int(edge["portal_id"])).get("ignore_hazards", false))

## A link's cost under the active Path Strategy. Walking, portals and platforms keep their own
## cost; airborne links are re-priced: shortest = raw distance plus a landing fee per jump,
## safest = long leaps and deep drops cost more the bigger they are, ground_hugging = every
## jump and fall carries a heavy fee so walking wins whenever it can.
## @ace_hidden
func _edge_cost(from_cell: Vector2i, edge: Dictionary) -> float:
	var base: float = float(edge.get("cost", 1.0))
	var kind: String = str(edge.get("kind", "walk"))
	var is_jump: bool = kind == "jump" or kind == "double_jump" or kind == "coyote_jump"
	var is_fall: bool = kind == "fall" or kind == "fall_through"
	if not is_jump and not is_fall:
		return base
	var span: float = Vector2((edge["to"] as Vector2i) - from_cell).length()
	var drop: float = maxf(float((edge["to"] as Vector2i).y - from_cell.y), 0.0)
	if path_strategy == "shortest":
		return span + (2.0 if is_jump else 0.0)
	if path_strategy == "safest":
		if is_jump:
			return span * 2.5 * minf(6.0, 1.0 + pow(span / 4.0, 2.0))
		return span * 1.5 * minf(5.0, 1.0 + drop / 3.0)
	if path_strategy == "ground_hugging":
		return span * 4.0 + 10.0 if is_jump else span * 2.0 + 4.0
	return base

## The router's link filter: deadly hazards block outright; a patrol only walks; with ledge
## restriction on, walking is always fine, drops only within the leniency, jumps and portals
## never; Walk Only never leaves the ground and the drop limit (No Falling forces it to at
## least 0) removes airborne links that land too far down.
## @ace_hidden
func _edge_allowed(from_cell: Vector2i, edge: Dictionary) -> bool:
	if not _ignores_hazards(edge) and _segment_hazard(from_cell, edge["to"]) == 2:
		return false
	var kind: String = str(edge["kind"])
	if _patrolling and kind != "walk":
		return false
	var drop: float = float(((edge["to"] as Vector2i).y - from_cell.y)) * _tile_px()
	if ledge_restriction:
		if kind == "walk":
			return true
		if kind == "fall" or kind == "fall_through":
			return drop <= ledge_leniency
		return false
	if kind == "walk" or kind == "portal" or kind == "portal_gradual" or kind == "platform":
		return true
	if path_strategy == "walk_only":
		return false
	var limit: float = max_traversal_drop
	if path_strategy == "no_falling":
		limit = maxf(limit, 0.0)
	return not (limit >= 0.0 and drop > limit)

## The link kind walking cell A -> B (the first link joining them).
## @ace_hidden
func _edge_kind(from_cell: Vector2i, to_cell: Vector2i) -> String:
	for edge in (_edges.get(from_cell, []) as Array):
		if edge["to"] == to_cell:
			return str(edge["kind"])
	return "walk"

## The map identity crowd claims and agent spacing compare: the grid plus the map tag.
## @ace_hidden
func _map_key() -> String:
	return "%d|%s" % [_tilemap.get_instance_id() if _tilemap != null else 0, map_tag]

## @ace_hidden
func _register_agent() -> void:
	_agent_ids[get_instance_id()] = true

## The other live agents on the same map (same grid, same map tag), freed ones pruned.
## @ace_hidden
func _other_agents() -> Array:
	var others: Array = []
	for agent_id in _agent_ids.keys():
		if agent_id == get_instance_id():
			continue
		if not is_instance_id_valid(agent_id):
			_agent_ids.erase(agent_id)
			continue
		var agent: Object = instance_from_id(agent_id)
		if not (agent is Node) or not (agent as Node).is_inside_tree():
			continue
		if agent.get("_tilemap") != _tilemap or str(agent.get("map_tag")) != map_tag:
			continue
		if not (agent.get("host") is Node2D):
			continue
		others.append(agent)
	return others

## Multi-agent avoidance: extra cost on the cells other agents stand on or are about to walk.
## @ace_hidden
func _agent_avoidance_costs() -> Dictionary:
	var costs: Dictionary = {}
	for agent in _other_agents():
		var at: Vector2i = _nearest_node((agent.get("host") as Node2D).global_position, 1)
		if at != Vector2i.MAX:
			costs[at] = float(costs.get(at, 0.0)) + 3.0
		var their_path: Array = agent.get("_path")
		var their_index: int = int(agent.get("_path_index"))
		for index in range(their_index, mini(their_index + 4, their_path.size())):
			var cell: Vector2i = their_path[index].get("cell", Vector2i.MAX)
			costs[cell] = float(costs.get(cell, 0.0)) + 1.5
	return costs

## Whether another live agent still holds the claim on this goal cell.
## @ace_hidden
func _claimed_by_other(cell: Vector2i) -> bool:
	var key: String = "%s|%s" % [_map_key(), str(cell)]
	if not _goal_claims.has(key):
		return false
	var owner_id: int = int(_goal_claims[key])
	if owner_id == get_instance_id():
		return false
	if not is_instance_id_valid(owner_id) or str(instance_from_id(owner_id).get("_claimed_key")) != key:
		_goal_claims.erase(key)
		return false
	return true

## Crowd arrivals: claims the goal node, or the nearest unclaimed node walkable from it when
## another agent already holds it, so a crowd spreads out instead of stacking on one spot.
## @ace_hidden
func _claim_goal(goal: Vector2i) -> Vector2i:
	_release_claim()
	var chosen: Vector2i = goal
	if _claimed_by_other(goal):
		var seen: Dictionary = {goal: true}
		var frontier: Array = [goal]
		var found: bool = false
		while not frontier.is_empty() and not found:
			var next_frontier: Array = []
			for cell in frontier:
				for edge in (_edges.get(cell, []) as Array):
					if str(edge["kind"]) != "walk" or seen.has(edge["to"]):
						continue
					seen[edge["to"]] = true
					if not _claimed_by_other(edge["to"]):
						chosen = edge["to"]
						found = true
						break
					next_frontier.append(edge["to"])
				if found:
					break
			frontier = next_frontier
	_claimed_key = "%s|%s" % [_map_key(), str(chosen)]
	_goal_claims[_claimed_key] = get_instance_id()
	return chosen

## @ace_hidden
func _release_claim() -> void:
	if _claimed_key != "" and int(_goal_claims.get(_claimed_key, 0)) == get_instance_id():
		_goal_claims.erase(_claimed_key)
	_claimed_key = ""

## Whether a body standing at this world point is over walkable ground (ledge-safe nudges).
## @ace_hidden
func _standable_at(world: Vector2) -> bool:
	var cell: Vector2i = _world_to_cell(world)
	return _nodes.has(cell) or _nodes.has(cell + Vector2i(0, 1)) or _nodes.has(cell + Vector2i(0, -1))

## Drives the host with a plain axis while no route is active (an idle separation step).
## @ace_hidden
func _drive_axis(axis: float, delta: float) -> void:
	var movement: Node = _find_movement()
	if movement != null:
		movement.set("ai_controlled", true)
		movement.set("ai_move_axis", axis)
		return
	host.velocity.y = minf(host.velocity.y + fallback_gravity * delta, 1000.0)
	host.velocity.x = axis * fallback_move_speed
	host.move_and_slide()

## Ends an idle separation step: the movement sibling is handed back exactly as an arrival does.
## @ace_hidden
func _stop_separating() -> void:
	if not _separating:
		return
	_separating = false
	var movement: Node = _find_movement()
	if movement != null:
		movement.set("ai_move_axis", 0.0)
		movement.set("ai_controlled", false)
	elif host != null:
		host.velocity.x = 0.0

## Idle separation: an idle agent closer than Idle Separation to another agent on the same
## map steps away from it - never off a ledge or into a wall. It gives up after Separation
## Give Up Time and rests for Separation Cooldown. Returns true while it is pushing.
## @ace_hidden
func _separate(delta: float) -> bool:
	if _separation_rest > 0.0:
		_separation_rest -= delta
		_stop_separating()
		return false
	if not host.is_on_floor():
		return false
	var push: int = 0
	var nearest_gap: float = INF
	for agent in _other_agents():
		var other: Node2D = agent.get("host")
		if absf(other.global_position.y - host.global_position.y) > _tile_px():
			continue
		var dx: float = host.global_position.x - other.global_position.x
		if absf(dx) < idle_separation and absf(dx) < nearest_gap:
			nearest_gap = absf(dx)
			if absf(dx) > 0.5:
				push = 1 if dx > 0.0 else -1
			else:
				push = 1 if get_instance_id() > agent.get_instance_id() else -1
	if push == 0:
		_separation_clock = 0.0
		_stop_separating()
		return false
	_separation_clock += delta
	if _separation_clock >= separation_give_up_time:
		_separation_clock = 0.0
		_separation_rest = separation_cooldown
		_stop_separating()
		return false
	var ahead: Vector2 = host.global_position + Vector2(float(push) * _tile_px() * 0.5, 0.0)
	_separating = true
	_drive_axis(0.6 * float(push) if _standable_at(ahead) else 0.0, delta)
	return true

## Patrol: arrived at one end - fire the hooks, then dwell or turn straight around.
## @ace_hidden
func _on_patrol_end() -> void:
	patrol_end_reached.emit()
	if not _patrolling:
		return
	if _patrol_dwell > 0.0:
		_patrol_dwelling = true
		_patrol_clock = _patrol_dwell
		patrol_dwell_started.emit()
		_wake()
		return
	_patrol_dir = -_patrol_dir
	_patrol_walk()

## Routes to the patrol end the agent is facing.
## @ace_hidden
func _patrol_walk() -> void:
	var end: Vector2 = _patrol_ends[1] if _patrol_dir > 0 else _patrol_ends[0]
	_exact_final = end.x
	_route(end.x, end.y, "nearest")

## @ace_hidden
func _end_patrol() -> void:
	_patrolling = false
	_patrol_dwelling = false
	_patrol_dir = 0

## Side-of-node arrival: the agent stands on the requested side at the requested distance.
## @ace_hidden
func _check_side_reached(side: Dictionary) -> void:
	if host == null or not is_instance_valid(side.get("node")):
		return
	var spot: Vector2 = side["spot"]
	if absf(host.global_position.x - spot.x) <= _tile_px() and absf(host.global_position.y - spot.y) <= _tile_px() * 2.0:
		_reached_side = int(side["side"])
		node_side_reached.emit()

## Pauses or resumes the sibling movement's own physics (a gradual portal moves the body).
## @ace_hidden
func _set_movement_processing(active: bool) -> void:
	var movement: Node = _find_movement()
	if movement != null:
		movement.set_physics_process(active)

## A portal waypoint has been reached: fire On Portal Entered, then run the portal unless the
## sheet paused it there.
## @ace_hidden
func _enter_portal(waypoint: Dictionary) -> void:
	_current_portal = _portal_by_id(int(waypoint.get("portal_id", -1)))
	_current_portal_exit = waypoint["world"]
	_portal_paused = false
	_portal_entering = true
	portal_entered.emit()
	_portal_entering = false
	if _portal_paused or _path.is_empty():
		return
	_run_portal(waypoint)

## Instant: blink to the exit. Gradual: start the straight-line move at the portal's speed with
## the movement sibling paused.
## @ace_hidden
func _run_portal(waypoint: Dictionary) -> void:
	if str(waypoint["action"]) == "portal_gradual":
		_portal_traversing = true
		_portal_from = host.global_position
		_portal_to = waypoint["world"]
		_portal_progress = 0.0
		host.velocity = Vector2.ZERO
		_set_movement_processing(false)
		return
	host.global_position = waypoint["world"]
	host.velocity = Vector2.ZERO
	_finish_portal()

## One tick of a gradual portal move.
## @ace_hidden
func _step_gradual_portal(delta: float) -> void:
	var speed: float = maxf(float(_current_portal.get("speed", 100.0)), 1.0)
	var span: float = _portal_from.distance_to(_portal_to)
	_portal_progress = 1.0 if span <= 0.5 else minf(_portal_progress + speed * delta / span, 1.0)
	host.global_position = _portal_from.lerp(_portal_to, _portal_progress)
	host.velocity = Vector2.ZERO
	if _portal_progress >= 1.0:
		_finish_portal()

## The portal is done: the movement sibling resumes, On Portal Taken fires, the route goes on.
## @ace_hidden
func _finish_portal() -> void:
	var was_traversing: bool = _portal_traversing
	_portal_traversing = false
	_portal_paused = false
	if was_traversing:
		_set_movement_processing(true)
	portal_taken.emit()
	if not _path.is_empty():
		_advance_waypoint()

## Holds the host still (a paused portal).
## @ace_hidden
func _hold_still(delta: float) -> void:
	_move_axis = 0.0
	var movement: Node = _find_movement()
	if movement != null:
		movement.set("ai_controlled", true)
		movement.set("ai_move_axis", 0.0)
		return
	host.velocity.x = 0.0
	host.velocity.y = minf(host.velocity.y + fallback_gravity * delta, 1000.0)
	host.move_and_slide()

## One tick of Jump Toward: launch at full strength, steer toward the point in the air, and
## hand the body back on landing.
## @ace_hidden
func _step_jump_toward(delta: float) -> void:
	var dx: float = _jump_toward_target.x - host.global_position.x
	_move_axis = clampf(dx / 24.0, -1.0, 1.0) if absf(dx) > 2.0 else 0.0
	var movement: Node = _find_movement()
	if not _jump_toward_launched:
		var can_leave: bool = host.is_on_floor() or _floor_grace <= _coyote_window()
		if movement != null and movement.has_method("can_jump"):
			can_leave = bool(movement.call("can_jump"))
		if not can_leave:
			_jump_toward_active = false
			_move_axis = 0.0
			return
		_jump_toward_launched = true
		if movement != null:
			movement.set("ai_controlled", true)
			movement.set("ai_move_axis", _move_axis)
			movement.jump()
		else:
			host.velocity.y = fallback_jump_velocity
		jump_toward_launched.emit()
	elif not host.is_on_floor():
		_jump_toward_airborne = true
	elif _jump_toward_airborne:
		_jump_toward_active = false
		_move_axis = 0.0
	if movement != null:
		movement.set("ai_move_axis", _move_axis)
		if not _jump_toward_active:
			movement.set("ai_controlled", false)
		return
	host.velocity.y = minf(host.velocity.y + fallback_gravity * delta, 1000.0)
	host.velocity.x = _move_axis * fallback_move_speed
	host.move_and_slide()

## The distance from a point to the segment a -> b.
## @ace_hidden
func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b))

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

## Creates, redraws or hides the whole-graph overlay (Debug Draw Graph).
## @ace_hidden
func _refresh_graph_overlay() -> void:
	if not debug_draw_graph:
		if _debug_graph != null and is_instance_valid(_debug_graph):
			_debug_graph.visible = false
		return
	if host == null:
		return
	if _debug_graph == null or not is_instance_valid(_debug_graph):
		_debug_graph = Node2D.new()
		_debug_graph.top_level = true
		_debug_graph.z_index = 50
		_debug_graph.draw.connect(_draw_graph_overlay)
		host.add_child(_debug_graph)
	_debug_graph.visible = true
	_debug_graph.queue_redraw()

## The colour each link kind draws in on the graph overlay.
## @ace_hidden
func _kind_color(kind: String) -> Color:
	match kind:
		"walk":
			return Color(0.55, 0.85, 1.0, 0.55)
		"jump":
			return Color(1.0, 0.85, 0.2, 0.55)
		"double_jump":
			return Color(1.0, 0.5, 0.1, 0.6)
		"coyote_jump":
			return Color(0.9, 1.0, 0.4, 0.6)
		"fall":
			return Color(1.0, 0.4, 0.75, 0.5)
		"fall_through":
			return Color(1.0, 0.2, 1.0, 0.7)
		"portal", "portal_gradual":
			return Color(0.7, 0.45, 1.0, 0.85)
		"platform":
			return Color(1.0, 0.6, 0.2, 0.85)
	return Color(1.0, 1.0, 1.0, 0.5)

## Draws every node as a dot and every link as a line coloured by kind.
## @ace_hidden
func _draw_graph_overlay() -> void:
	if _debug_graph == null:
		return
	for cell in _edges:
		var from: Vector2 = _cell_world(cell)
		for edge in (_edges[cell] as Array):
			_debug_graph.draw_line(from, _cell_world(edge["to"]), _kind_color(str(edge["kind"])), 1.5)
	for cell in _nodes:
		_debug_graph.draw_circle(_cell_world(cell), 2.5, Color(1.0, 1.0, 1.0, 0.9))
#endregion

func _physics_process(delta: float) -> void:
	if host == null:
		return
	_register_agent()
	# Coyote bookkeeping: seconds since the host last stood on the floor (the jump gate
	# below accepts a frame-late takeoff within Coyote Time).
	if host.is_on_floor():
		_floor_grace = 0.0
	else:
		_floor_grace += delta
	# Hazard presence (any kind) fires On Hazard Entered on the way in - the damage hook.
	_prune_tracked_hazards()
	var in_hazard_now: bool = _point_in_hazard(host.global_position, false)
	if in_hazard_now and not _was_in_hazard:
		hazard_entered.emit()
	_was_in_hazard = in_hazard_now
	# Disabled: frozen in place with every bit of state kept for the resume.
	if not nav_enabled:
		return
	# A portal mid-execution, a held portal, and a Jump Toward own the body this tick.
	if _portal_traversing:
		_step_gradual_portal(delta)
		return
	if _portal_paused:
		_hold_still(delta)
		return
	if _jump_toward_active:
		_step_jump_toward(delta)
		return
	# Budget-deferred retries and follow-mode refreshes run even without an active path.
	_repath_clock += delta
	if _path_pending:
		_route(_pending_goal.x, _pending_goal.y, _pending_goal_mode)
	elif _follow_target != null and is_instance_valid(_follow_target) and _follow_target is Node2D and _repath_clock >= repath_interval:
		_repath_clock = 0.0
		var followed: Vector2 = (_follow_target as Node2D).global_position
		if followed.distance_to(_path_goal) > repath_threshold:
			_route(followed.x, followed.y, _goal_mode)
			repathed.emit()
	# Patrol dwell: wait at the end, then turn and walk to the other one.
	if _patrolling and _patrol_dwelling:
		_hold_still(delta)
		_patrol_clock -= delta
		if _patrol_clock <= 0.0:
			_patrol_dwelling = false
			_patrol_dir = -_patrol_dir
			patrol_dwell_finished.emit()
			_patrol_walk()
	if _path.is_empty():
		if idle_separation > 0.0 and _separate(delta):
			return
		# No route, no deferred request, nobody being followed, no patrol, no spacing to keep
		# and no hazard to watch means there is nothing this tick could do - a parked agent
		# costs nothing per frame until a path verb or Add Hazard turns processing back on.
		if not _path_pending and (_follow_target == null or not is_instance_valid(_follow_target)) and _hazards.is_empty() and not _patrolling and idle_separation <= 0.0:
			set_physics_process(false)
		return
	var waypoint: Dictionary = _path[_path_index]
	var target: Vector2 = waypoint["world"]
	# Portal traversal: On Portal Entered, then the blink or the gradual move.
	if waypoint["action"] == "portal" or waypoint["action"] == "portal_gradual":
		_enter_portal(waypoint)
		return
	var dx: float = target.x - host.global_position.x
	_move_axis = clampf(dx / 24.0, -1.0, 1.0) if absf(dx) > 2.0 else 0.0
	var movement: Node = _find_movement()
	var tile: float = _tile_px()
	var action: String = str(waypoint["action"])
	# Jump on jump arcs, and STEP-ASSIST on raised walk waypoints: a full-block stair stops
	# a walking body, so a close-and-higher waypoint gets a hop (slope tiles just walk).
	# A coyote jump runs off the ledge first and leaps half way through the coyote window.
	var wants_jump: bool = action == "jump" or action == "double_jump"
	if action == "coyote_jump":
		wants_jump = not host.is_on_floor() and _floor_grace >= _coyote_window() * 0.5
	if not wants_jump and action == "walk":
		wants_jump = target.y < host.global_position.y - 8.0 and absf(dx) < tile * 1.5
	# Strict jump positioning: walk onto the exact takeoff spot before leaping (relaxed
	# leaps the moment the jump leg starts - faster, but looser on tight arcs).
	if (action == "jump" or action == "double_jump") and jump_positioning == "strict" and not _jumped_this_segment and _path_index > 0:
		var takeoff_dx: float = (_path[_path_index - 1]["world"] as Vector2).x - host.global_position.x
		if absf(takeoff_dx) > 4.0:
			_move_axis = clampf(takeoff_dx / 24.0, -1.0, 1.0)
			wants_jump = false
	# Fall-through: stand over the drop, then slip below the one-way platform's surface - it
	# stops colliding once the body is past its margin, and gravity does the rest.
	if action == "fall_through" and host.is_on_floor() and absf(dx) <= arrive_distance and not _dropped_this_segment:
		_dropped_this_segment = true
		host.global_position.y += 6.0
		host.velocity.y = maxf(host.velocity.y, 60.0)
	# Moving-platform leg: wait beside the track, board, ride, walk off - the platform carries.
	if action == "platform":
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
	# An exact-spot route (patrol end, beside a node) arrives within Arrive Distance.
	var arrive_radius: float = arrive_distance if _path_index < _path.size() - 1 or _exact_arrival else maxf(arrive_distance, tile)
	# Arrival is checked BEFORE the drive: the arrival tick must not also steer, or every
	# instant-complete refind leaks one frame of drive and a parked agent creeps off ledges.
	if absf(dx) <= arrive_radius and absf(target.y - host.global_position.y) <= tile:
		_advance_waypoint()
		if debug_draw:
			_refresh_debug()
		return
	# Drift re-route: knocked well off the leg it is walking (and on the ground again), the
	# agent re-plans from where it actually is - once per Repath Interval at most.
	if drift_repath_distance > 0.0 and not _teleport_grace and host.is_on_floor() and _repath_clock >= repath_interval and _path_index > 0:
		var leg_start: Vector2 = _path[_path_index - 1]["world"]
		if _distance_to_segment(host.global_position, leg_start, target) > drift_repath_distance:
			_repath_clock = 0.0
			_route(_path_goal.x, _path_goal.y, _goal_mode)
			repathed.emit()
			return
	_teleport_grace = false
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
			_route(_path_goal.x, _path_goal.y, _goal_mode)
			repathed.emit()
	if auto_control:
		var takeoff_window: float = coyote_time if action != "coyote_jump" else _coyote_window()
		var start_jump: bool = wants_jump and not _jumped_this_segment and (host.is_on_floor() or _floor_grace <= takeoff_window)
		if start_jump:
			_jumped_this_segment = true
			_jump_released = false
			_jump_release_velocity = _release_velocity_for(target)
			# An arc that needs (nearly) the whole jump must never be cut - releasing a
			# near-max jump on its first frames kills the climb. Variable jump only arms
			# when there is clear headroom, and never on a double or coyote jump (both need
			# every bit of air time the jump has).
			var full_rise: float = absf(float(movement.get("jump_velocity"))) if movement != null else absf(fallback_jump_velocity)
			if _jump_release_velocity >= full_rise * 0.85 or action == "double_jump" or action == "coyote_jump":
				_jump_release_velocity = 0.0
		# Double jump: the second leap fires at the top of the first.
		var second_jump: bool = action == "double_jump" and _jumped_this_segment and not _second_jump_done and not host.is_on_floor() and host.velocity.y >= -40.0
		if second_jump:
			_second_jump_done = true
		# Variable jump: once remaining upward speed is just enough for THIS arc's rise,
		# release - flat gap hops stay low, tall ledges get the full jump.
		var release_now: bool = variable_jump and _jumped_this_segment and not _jump_released and host.velocity.y < 0.0 and absf(host.velocity.y) <= _jump_release_velocity
		if movement != null:
			# The standard drive seam on the movement sibling - its accel, coyote time, and
			# jump feel all still apply under AI control.
			movement.set("ai_controlled", true)
			movement.set("ai_move_axis", _move_axis)
			if start_jump or second_jump:
				movement.jump()
			if release_now and movement.has_method("jump_released"):
				_jump_released = true
				movement.jump_released()
		else:
			# No movement sibling: the built-in fallback drives the CharacterBody2D itself,
			# so ANY body pathfinds out of the box (attach one behavior, done).
			host.velocity.y = minf(host.velocity.y + fallback_gravity * delta, 1000.0)
			host.velocity.x = _move_axis * fallback_move_speed
			if start_jump or second_jump:
				host.velocity.y = fallback_jump_velocity
			if release_now:
				_jump_released = true
				host.velocity.y *= 0.45
			host.move_and_slide()
	if debug_draw:
		_refresh_debug()

func build_nav_graph(tilemap: Node) -> void:
	_tilemap = tilemap as TileMapLayer
	_custom_grid = false
	if _tilemap != null and _bind_shared_map(_tilemap.get_instance_id()):
		# Another agent on this map tag already built this exact map: share it.
		nav_graph_built.emit()
		_refresh_graph_overlay()
		return
	regenerate_nav_graph()

func regenerate_nav_graph() -> void:
	_nodes.clear()
	_edges.clear()
	if not _has_grid():
		_states.clear()
		return
	_scan_states()
	var blocking: Dictionary = {}
	var blocking_down: Dictionary = {}
	for cell in _states:
		if _blocks_state(str(_states[cell])):
			blocking[cell] = true
		blocking_down[cell] = true
	# A standable node = a cell over solid ground, a slope or a jump-through platform, with two
	# cells of headroom (a jump-through platform never takes headroom away).
	for cell in _states:
		var stand: Vector2i = cell + Vector2i(0, -1)
		if not blocking.has(stand) and not blocking.has(stand + Vector2i(0, -1)):
			_nodes[stand] = true
	# WALK links: neighbours one cell over, up to one step up/down - stairs and slopes
	# included, at plain euclidean cost so ramps beat jumps in the router.
	for cell in _nodes:
		for dx in [-1, 1]:
			for dy in [-1, 0, 1]:
				var to: Vector2i = cell + Vector2i(dx, dy)
				if _nodes.has(to):
					_add_edge(cell, to, "walk", Vector2(float(dx), float(dy)).length())
	# JUMP arcs + FALL drops within the derived reach, clearance-checked coarsely. A drop
	# treats a jump-through platform in its way as a floor (it would land there).
	var tile: float = _tile_px()
	var reach_px: Vector2 = _jump_reach_px()
	var reach: Vector2i = _jump_reach_cells()
	var fall_cells: int = maxi(int(ceil(max_fall_distance / tile)), 1)
	if max_fall_distance < 0.0:
		var used: Rect2i = Rect2i()
		for cell in _states:
			used = Rect2i(cell, Vector2i.ONE) if used.size == Vector2i.ZERO else used.expand(cell)
		fall_cells = maxi(used.size.y + 2, 1)
	for cell in _nodes:
		for dx in range(-reach.x, reach.x + 1):
			for dy in range(-reach.y, fall_cells + 1):
				if absi(dx) <= 1 and absi(dy) <= 1:
					continue
				var to: Vector2i = cell + Vector2i(dx, dy)
				if not _nodes.has(to) or not _arc_clear(cell, to, blocking_down if dy > 0 else blocking):
					continue
				var kind: String = "fall" if dy > 0 and absi(dx) <= 2 else "jump"
				var span: float = Vector2(float(dx), float(dy)).length()
				_add_edge(cell, to, kind, span * (1.5 if kind == "jump" else 1.1))
	# DOUBLE JUMP links: a sibling with two jumps reaches about twice as high and 1.7x as far;
	# only targets the single jump cannot reach get one.
	if _double_jump_ready():
		var double_reach: Vector2i = Vector2i(maxi(int(reach_px.x * 1.7 / tile), 1), maxi(int(reach_px.y * 2.0 / tile), 1))
		for cell in _nodes:
			for dx in range(-double_reach.x, double_reach.x + 1):
				for dy in range(-double_reach.y, fall_cells + 1):
					if absi(dx) <= reach.x and dy >= -reach.y:
						continue
					var to: Vector2i = cell + Vector2i(dx, dy)
					if not _nodes.has(to) or _has_edge(cell, to) or not _arc_clear(cell, to, blocking_down if dy > 0 else blocking):
						continue
					_add_edge(cell, to, "double_jump", Vector2(float(dx), float(dy)).length() * 1.8)
	# COYOTE JUMP links: run off a ledge for half the coyote window, then leap - the extra run
	# reaches gaps a standing takeoff cannot. Never with Ledge Restriction (it never runs off).
	if _coyote_window() > 0.0 and not ledge_restriction:
		var coyote_cells: int = int((reach_px.x + _run_speed() * _coyote_window() * 0.5) / tile)
		if coyote_cells > reach.x:
			for cell in _nodes:
				for direction in [-1, 1]:
					if not _is_ledge_toward(cell, direction):
						continue
					for distance in range(reach.x + 1, coyote_cells + 1):
						for dy in range(-(reach.y - 1), fall_cells + 1):
							var to: Vector2i = cell + Vector2i(direction * distance, dy)
							if not _nodes.has(to) or _has_edge(cell, to) or not _arc_clear(cell, to, blocking_down if dy > 0 else blocking):
								continue
							_add_edge(cell, to, "coyote_jump", Vector2(float(distance), float(dy)).length() * 1.6)
	# FALL-THROUGH drops: standing on a jump-through platform, drop straight down to the first
	# node below it.
	for cell in _nodes:
		if str(_states.get(cell + Vector2i(0, 1), "")) != "jump_thru":
			continue
		for depth in range(1, fall_cells + 2):
			var below: Vector2i = cell + Vector2i(0, depth)
			if blocking.has(below):
				break
			if _nodes.has(below) and depth > 1:
				_add_edge(cell, below, "fall_through", float(depth) * 1.1)
				break
	# Registered portals and moving platforms survive every rebuild.
	for portal in _portals:
		_apply_portal(portal)
	for ride in _moving_platforms:
		_apply_moving_platform(ride)
	_refresh_graph_overlay()
	nav_graph_built.emit()

func find_path_to(x: float, y: float, mode: String) -> void:
	_end_patrol()
	_side_request = {}
	_exact_final = NAN
	_route(x, y, mode)

func find_path_to_node(target: Node, mode: String) -> void:
	if target is Node2D:
		find_path_to((target as Node2D).global_position.x, (target as Node2D).global_position.y, mode)
		_follow_target = target
		_goal_mode = mode
		_repath_clock = 0.0
	else:
		path_failed.emit()

func stop_pathfinding() -> void:
	_end_patrol()
	_side_request = {}
	_jump_toward_active = false
	_release_claim()
	if _portal_traversing or _portal_paused:
		_portal_traversing = false
		_portal_paused = false
		_set_movement_processing(true)
	_finish_path()

func set_auto_control(enabled: bool) -> void:
	auto_control = enabled
	if not enabled:
		var movement: Node = _find_movement()
		if movement != null:
			movement.set("ai_controlled", false)

func set_ledge_restriction(enabled: bool) -> void:
	ledge_restriction = enabled

func set_ledge_leniency(pixels: float) -> void:
	ledge_leniency = pixels

func set_jump_positioning(mode: String) -> void:
	jump_positioning = mode

func set_coyote_time(seconds: float) -> void:
	coyote_time = seconds

func set_repath_interval(seconds: float) -> void:
	repath_interval = seconds

func set_repath_threshold(pixels: float) -> void:
	repath_threshold = pixels

func set_max_paths_per_tick(count: int) -> void:
	_shared_max_paths_per_tick = count

func add_portal(from_x: float, from_y: float, to_x: float, to_y: float, bidirectional: bool) -> void:
	_add_portal_record(Vector2(from_x, from_y), Vector2(to_x, to_y), bidirectional, "instant", 1.0, 0.0, "")

func clear_portals() -> void:
	_portals.clear()
	_elevator_stops.clear()
	regenerate_nav_graph()

func add_hazard(x: float, y: float, width: float, height: float, deadly: bool) -> void:
	_hazards.append({"id": _next_hazard_id, "kind": "rect", "rect": Rect2(x, y, width, height), "deadly": deadly})
	_last_hazard_id = _next_hazard_id
	_next_hazard_id += 1
	# A hazard is watched per frame (On Hazard Entered fires on the way in), so a parked
	# agent starts paying for its tick again the moment one exists.
	set_physics_process(true)

func clear_hazards() -> void:
	_hazards.clear()

func add_moving_platform(platform: Node, from_x: float, from_y: float, to_x: float, to_y: float) -> void:
	if not (platform is Node2D):
		return
	var ride: Dictionary = {"node": platform, "a": Vector2(from_x, from_y), "b": Vector2(to_x, to_y)}
	_moving_platforms.append(ride)
	if not _nodes.is_empty():
		_apply_moving_platform(ride)

func clear_moving_platforms() -> void:
	_moving_platforms.clear()
	regenerate_nav_graph()

func set_nav_debug_draw(enabled: bool) -> void:
	debug_draw = enabled
	_refresh_debug()

func set_enabled(state: bool) -> void:
	nav_enabled = state
	if not state:
		_move_axis = 0.0
		var movement: Node = _find_movement()
		if movement != null:
			movement.set("ai_move_axis", 0.0)
	else:
		_wake()

func is_enabled() -> bool:
	return nav_enabled

func set_path_strategy(strategy: String) -> void:
	path_strategy = strategy

func set_max_traversal_drop(pixels: float) -> void:
	max_traversal_drop = pixels

func set_drift_repath_distance(pixels: float) -> void:
	drift_repath_distance = pixels

func set_movement_limit(limit: String, value: float) -> void:
	if limit == "jump_height":
		jump_height_override = value
	elif limit == "jump_distance":
		jump_distance_override = value
	elif limit == "max_fall":
		max_fall_distance = value
	else:
		push_warning("[PlatformerPathfinding] Set Movement Limit: unknown limit '%s' (jump_height, jump_distance, max_fall)." % limit)

func set_crowd_arrivals(enabled: bool) -> void:
	crowd_arrivals = enabled
	if not enabled:
		_release_claim()

func set_multi_agent_avoidance(enabled: bool) -> void:
	multi_agent_avoidance = enabled

func set_separation_setting(setting: String, value: float) -> void:
	if setting == "distance":
		idle_separation = maxf(value, 0.0)
		if idle_separation > 0.0:
			_register_agent()
			_wake()
	elif setting == "cooldown":
		separation_cooldown = maxf(value, 0.0)
	elif setting == "give_up_time":
		separation_give_up_time = maxf(value, 0.0)
	else:
		push_warning("[PlatformerPathfinding] Set Separation Setting: unknown setting '%s' (distance, cooldown, give_up_time)." % setting)

func set_hazard_margin(pixels: float) -> void:
	hazard_margin = maxf(pixels, 0.0)

func set_debug_draw_graph(enabled: bool) -> void:
	debug_draw_graph = enabled
	_refresh_graph_overlay()

func find_path_to_nearest_ledge(direction: String, distance: float) -> void:
	_end_patrol()
	_side_request = {}
	var facing: int = -1 if direction == "left" else 1
	if _nodes.is_empty():
		_auto_build()
	var ledge: Vector2i = _nearest_ledge_cell(facing)
	if ledge == Vector2i.MAX:
		_fail("no_ledge")
		return
	var spot: Vector2 = _cell_world(ledge) - Vector2(float(facing) * distance, 0.0)
	_exact_final = spot.x
	_route(spot.x, spot.y, "nearest")

func find_path_to_node_side(target: Node, side: String, distance: float) -> void:
	_end_patrol()
	_reached_side = 0
	if not (target is Node2D) or host == null:
		_fail("no_target")
		return
	var at: Vector2 = (target as Node2D).global_position
	var gap: float = _tile_px() + maxf(distance, 0.0)
	var facing: int = 1
	if side == "left":
		facing = -1
	elif side == "any" and host.global_position.x < at.x:
		facing = -1
	var spot: Vector2 = at + Vector2(gap * float(facing), 0.0)
	if side == "any" and _nearest_node(spot, 1) == Vector2i.MAX:
		facing = -facing
		spot = at + Vector2(gap * float(facing), 0.0)
	_side_request = {"node": target, "side": facing, "spot": spot}
	_exact_final = spot.x
	_route(spot.x, spot.y, "nearest")

func jump_toward(x: float, y: float) -> void:
	if not nav_enabled or host == null:
		return
	stop_pathfinding()
	_jump_toward_target = Vector2(x, y)
	_jump_toward_active = true
	_jump_toward_launched = false
	_jump_toward_airborne = false
	_wake()

func start_patrol(dwell: float, edge_distance: float) -> void:
	if not nav_enabled or host == null:
		return
	stop_pathfinding()
	if _nodes.is_empty():
		_auto_build()
	var here: Vector2i = _nearest_node(host.global_position, 3)
	if here == Vector2i.MAX:
		_fail("no_start_node")
		return
	var left: Vector2i = here
	var right: Vector2i = here
	for cell in _walk_component(here):
		if cell.x < left.x or (cell.x == left.x and absi(cell.y - here.y) < absi(left.y - here.y)):
			left = cell
		if cell.x > right.x or (cell.x == right.x and absi(cell.y - here.y) < absi(right.y - here.y)):
			right = cell
	var inset: float = minf(maxf(edge_distance, 0.0), absf(_cell_world(right).x - _cell_world(left).x) * 0.5)
	_patrol_ends = [_cell_world(left) + Vector2(inset, 0.0), _cell_world(right) - Vector2(inset, 0.0)]
	_patrolling = true
	_patrol_dwell = maxf(dwell, 0.0)
	_patrol_dwelling = false
	_patrol_dir = 1 if (_patrol_ends[1] as Vector2).x - host.global_position.x >= host.global_position.x - (_patrol_ends[0] as Vector2).x else -1
	_patrol_walk()

func stop_patrol() -> void:
	stop_pathfinding()

func teleport_to(x: float, y: float) -> void:
	if host == null:
		return
	host.global_position = Vector2(x, y)
	host.velocity = Vector2.ZERO
	_teleport_grace = true
	_best_waypoint_distance = INF
	_stuck_clock = 0.0

func log_graph_stats() -> void:
	var counts: Dictionary = {}
	var total: int = 0
	for cell in _edges:
		for edge in (_edges[cell] as Array):
			counts[edge["kind"]] = int(counts.get(edge["kind"], 0)) + 1
			total += 1
	print("[PlatformerPathfinding] nodes=%d links=%d %s portals=%d hazards=%d platforms=%d jump_reach=%s cells" % [_nodes.size(), total, str(counts), _portals.size(), _hazards.size(), _moving_platforms.size(), str(_jump_reach_cells())])

func create_obstacle_map(width: int, height: int, cell_size: float) -> void:
	_tilemap = null
	_custom_grid = true
	_custom_size = Vector2i(maxi(width, 1), maxi(height, 1))
	_grid_origin = Vector2.ZERO
	if cell_size > 0.0:
		grid_cell_size = cell_size
	_bind_shared_map(-1)
	_tile_overrides.clear()
	_body_states.clear()
	regenerate_nav_graph()

func set_tile_state(gx: int, gy: int, state: String) -> void:
	if not ["solid", "clear", "jump_thru", "slope_left", "slope_right"].has(state):
		push_warning("[PlatformerPathfinding] Set Tile State: unknown state '%s'." % state)
		return
	_tile_overrides[Vector2i(gx, gy)] = state

func set_tile_state_at(x: float, y: float, state: String) -> void:
	var cell: Vector2i = _world_to_cell(Vector2(x, y))
	set_tile_state(cell.x, cell.y, state)

func scan_collision_bodies(root: Node) -> void:
	if not _has_grid():
		push_warning("[PlatformerPathfinding] Scan Collision Bodies needs a grid first - Build Nav Graph From Tilemap or Create Obstacle Map.")
		return
	if root == null:
		return
	for body in root.find_children("*", "StaticBody2D", true, false):
		var static_body: StaticBody2D = body as StaticBody2D
		# Out of a scene tree (tools, tests) the body's own transform stands in for the global one.
		var body_xform: Transform2D = static_body.global_transform if static_body.is_inside_tree() else static_body.transform
		for shape_owner in static_body.get_children():
			var area: Rect2 = Rect2()
			var one_way: bool = false
			if shape_owner is CollisionShape2D and (shape_owner as CollisionShape2D).shape != null and not (shape_owner as CollisionShape2D).disabled:
				var collision_shape: CollisionShape2D = shape_owner
				area = body_xform * collision_shape.transform * collision_shape.shape.get_rect()
				one_way = collision_shape.one_way_collision
			elif shape_owner is CollisionPolygon2D and not (shape_owner as CollisionPolygon2D).disabled:
				var collision_polygon: CollisionPolygon2D = shape_owner
				var points: PackedVector2Array = body_xform * collision_polygon.transform * collision_polygon.polygon
				if points.is_empty():
					continue
				area = Rect2(points[0], Vector2.ZERO)
				for point in points:
					area = area.expand(point)
				one_way = collision_polygon.one_way_collision
			else:
				continue
			var first: Vector2i = _world_to_cell(area.position + Vector2(1.0, 1.0))
			var last: Vector2i = _world_to_cell(area.end - Vector2(1.0, 1.0))
			for gy in range(first.y, last.y + 1):
				for gx in range(first.x, last.x + 1):
					var cell: Vector2i = Vector2i(gx, gy)
					if one_way and str(_body_states.get(cell, "")) == "solid":
						continue
					_body_states[cell] = "jump_thru" if one_way else "solid"

func clear_nav_graph() -> void:
	stop_pathfinding()
	_nodes.clear()
	_edges.clear()
	_states.clear()
	_tile_overrides.clear()
	_body_states.clear()
	_tilemap = null
	_custom_grid = false
	_custom_size = Vector2i.ZERO
	_refresh_graph_overlay()
	nav_graph_cleared.emit()

func load_obstacle_map_json(json: String) -> void:
	var parsed: Variant = JSON.parse_string(json)
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("cells"):
		push_warning("[PlatformerPathfinding] Load Obstacle Map JSON: not an obstacle map.")
		return
	var data: Dictionary = parsed
	_tilemap = null
	_custom_grid = true
	grid_cell_size = maxf(float(data.get("cell_size", grid_cell_size)), 1.0)
	var size: Array = data.get("size", [0, 0])
	_custom_size = Vector2i(int(size[0]), int(size[1]))
	var origin: Array = data.get("origin", [0.0, 0.0])
	_grid_origin = Vector2(float(origin[0]), float(origin[1]))
	_bind_shared_map(-1)
	_tile_overrides.clear()
	_body_states.clear()
	for entry in (data["cells"] as Array):
		_tile_overrides[Vector2i(int(entry[0]), int(entry[1]))] = str(entry[2])
	regenerate_nav_graph()

func add_instant_portal(from_x: float, from_y: float, to_x: float, to_y: float, bidirectional: bool, cost: float, tag: String) -> void:
	_add_portal_record(Vector2(from_x, from_y), Vector2(to_x, to_y), bidirectional, "instant", cost, 0.0, tag)

func add_gradual_portal(from_x: float, from_y: float, to_x: float, to_y: float, bidirectional: bool, speed: float, cost: float, tag: String) -> void:
	_add_portal_record(Vector2(from_x, from_y), Vector2(to_x, to_y), bidirectional, "gradual", cost, speed, tag)

func add_elevator_stop(group: String, x: float, y: float, speed: float, tag: String) -> void:
	var stop: Vector2 = Vector2(x, y)
	var stops: Array = _elevator_stops.get(group, [])
	for other in stops:
		_add_portal_record(other, stop, true, "gradual", 1.0, speed, tag)
	stops.append(stop)
	_elevator_stops[group] = stops

func remove_portal(portal_id: int) -> void:
	for index in range(_portals.size() - 1, -1, -1):
		if int(_portals[index]["id"]) == portal_id:
			_portals.remove_at(index)
	_unlink_portal(portal_id)
	_refresh_graph_overlay()

func remove_portal_near(x: float, y: float) -> void:
	var best_id: int = -1
	var best_gap: float = INF
	for portal in _portals:
		var gap: float = minf((portal["from"] as Vector2).distance_to(Vector2(x, y)), (portal["to"] as Vector2).distance_to(Vector2(x, y)))
		if gap < best_gap:
			best_gap = gap
			best_id = int(portal["id"])
	if best_id >= 0:
		remove_portal(best_id)

func remove_portals_by_tag(tag: String) -> void:
	var doomed: Array = []
	for portal in _portals:
		if _portal_has_tag(portal, tag):
			doomed.append(int(portal["id"]))
	for portal_id in doomed:
		remove_portal(portal_id)

func set_portal_cost(portal_id: int, cost: float) -> void:
	var portal: Dictionary = _portal_by_id(portal_id)
	if not portal.is_empty():
		portal["cost"] = cost
		_relink_portal(portal)

func set_portal_speed(portal_id: int, speed: float) -> void:
	var portal: Dictionary = _portal_by_id(portal_id)
	if not portal.is_empty():
		portal["speed"] = speed
		_relink_portal(portal)

func set_portal_tag(portal_id: int, tag: String) -> void:
	var portal: Dictionary = _portal_by_id(portal_id)
	if not portal.is_empty():
		portal["tag"] = tag

func set_portal_ignore_hazards(portal_id: int, ignore: bool) -> void:
	var portal: Dictionary = _portal_by_id(portal_id)
	if not portal.is_empty():
		portal["ignore_hazards"] = ignore

func set_portal_position(portal_id: int, from_x: float, from_y: float, to_x: float, to_y: float) -> void:
	var portal: Dictionary = _portal_by_id(portal_id)
	if not portal.is_empty():
		portal["from"] = Vector2(from_x, from_y)
		portal["to"] = Vector2(to_x, to_y)
		_relink_portal(portal)

func pause_at_portal() -> void:
	if _portal_entering:
		_portal_paused = true

func resume_portal() -> void:
	if not _portal_paused:
		return
	_portal_paused = false
	if not _path.is_empty():
		_run_portal(_path[_path_index])

func complete_portal() -> void:
	if not _portal_paused and not _portal_traversing:
		return
	_finish_portal()

func add_circle_hazard(x: float, y: float, radius: float, deadly: bool) -> void:
	_hazards.append({"id": _next_hazard_id, "kind": "circle", "center": Vector2(x, y), "radius": radius, "deadly": deadly})
	_last_hazard_id = _next_hazard_id
	_next_hazard_id += 1
	set_physics_process(true)

func add_tracked_hazard(target: Node, radius: float, deadly: bool) -> void:
	if not (target is Node2D):
		return
	_hazards.append({"id": _next_hazard_id, "kind": "tracked", "node": target, "radius": radius, "deadly": deadly})
	_last_hazard_id = _next_hazard_id
	_next_hazard_id += 1
	set_physics_process(true)

func remove_hazard(hazard_id: int) -> void:
	for index in range(_hazards.size() - 1, -1, -1):
		if int(_hazards[index].get("id", -1)) == hazard_id:
			_hazards.remove_at(index)

func is_patrolling() -> bool:
	return _patrolling

func is_at_ledge() -> bool:
	if host == null:
		return false
	var here: Vector2i = _nearest_node(host.global_position, 1)
	return here != Vector2i.MAX and _ledge_side(here) != 0

func is_at_island() -> bool:
	if host == null:
		return false
	var here: Vector2i = _nearest_node(host.global_position, 1)
	if here == Vector2i.MAX:
		return false
	for dx in [-1, 1]:
		for dy in [-1, 0, 1]:
			if _nodes.has(here + Vector2i(dx, dy)):
				return false
	return true

func is_on_same_platform(target: Node) -> bool:
	if not (target is Node2D):
		return false
	return is_position_on_same_platform((target as Node2D).global_position.x, (target as Node2D).global_position.y)

func is_position_on_same_platform(x: float, y: float) -> bool:
	if host == null:
		return false
	var here: Vector2i = _nearest_node(host.global_position, 3)
	var there: Vector2i = _nearest_node(Vector2(x, y), 3)
	if here == Vector2i.MAX or there == Vector2i.MAX:
		return false
	return _walk_component(here).has(there)

func is_position_hazardous(x: float, y: float) -> bool:
	return _point_in_hazard(Vector2(x, y), false)

func is_at_portal() -> bool:
	return _portal_paused

func is_traversing_portal() -> bool:
	return _portal_traversing

func graph_node_exists(gx: int, gy: int) -> bool:
	return _nodes.has(Vector2i(gx, gy))

func graph_node_exists_at(x: float, y: float) -> bool:
	return _has_grid() and _nodes.has(_world_to_cell(Vector2(x, y)))

func is_ledge_node(gx: int, gy: int) -> bool:
	return _ledge_side(Vector2i(gx, gy)) != 0

func tile_has_state(gx: int, gy: int, state: String) -> bool:
	return tile_state(gx, gy) == state

func tile_has_state_at(x: float, y: float, state: String) -> bool:
	var cell: Vector2i = _world_to_cell(Vector2(x, y))
	return tile_state(cell.x, cell.y) == state

func tile_state(gx: int, gy: int) -> String:
	if not _has_grid():
		return ""
	var cell: Vector2i = Vector2i(gx, gy)
	if _custom_grid and (gx < 0 or gy < 0 or gx >= _custom_size.x or gy >= _custom_size.y):
		return ""
	return _live_state(cell)

func world_to_grid(x: float, y: float) -> Vector2i:
	return _world_to_cell(Vector2(x, y)) if _has_grid() else Vector2i.ZERO

func grid_to_world(gx: int, gy: int) -> Vector2:
	return _cell_world(Vector2i(gx, gy)) if _has_grid() else Vector2.ZERO

func grid_size() -> Vector2i:
	if _custom_grid:
		return _custom_size
	if _tilemap != null:
		return _tilemap.get_used_rect().size
	return Vector2i.ZERO

func grid_tile_size() -> float:
	return _tile_px() if _has_grid() else 0.0

func obstacle_map_source() -> String:
	if _custom_grid:
		return "custom"
	if _tilemap != null:
		return "tilemap"
	return "none"

func obstacle_map_json() -> String:
	if not _has_grid():
		return ""
	_scan_states()
	var cells: Array = []
	var keys: Array = _states.keys()
	keys.sort()
	for cell in keys:
		cells.append([cell.x, cell.y, _states[cell]])
	var origin: Vector2 = _cell_world(Vector2i.ZERO) - Vector2(_tile_px(), _tile_px()) * 0.5
	var size: Vector2i = grid_size()
	return JSON.stringify({"version": 1, "cell_size": _tile_px(), "origin": [origin.x, origin.y], "size": [size.x, size.y], "cells": cells})

func graph_node_count() -> int:
	return _nodes.size()

func graph_node_cell(index: int) -> Vector2i:
	if index < 0 or index >= _nodes.size():
		return Vector2i(-1, -1)
	return _nodes.keys()[index]

func graph_node_position(index: int) -> Vector2:
	if index < 0 or index >= _nodes.size():
		return Vector2.ZERO
	return _cell_world(_nodes.keys()[index])

func graph_node_connection_count(gx: int, gy: int) -> int:
	return (_edges.get(Vector2i(gx, gy), []) as Array).size()

func graph_node_connection_kind(gx: int, gy: int, index: int) -> String:
	var links: Array = _edges.get(Vector2i(gx, gy), [])
	return str(links[index]["kind"]) if index >= 0 and index < links.size() else ""

func graph_node_connection_cost(gx: int, gy: int, index: int) -> float:
	var links: Array = _edges.get(Vector2i(gx, gy), [])
	return _edge_cost(Vector2i(gx, gy), links[index]) if index >= 0 and index < links.size() else 0.0

func graph_node_connection_target(gx: int, gy: int, index: int) -> Vector2:
	var links: Array = _edges.get(Vector2i(gx, gy), [])
	return _cell_world(links[index]["to"]) if index >= 0 and index < links.size() else Vector2.ZERO

func ledge_side(gx: int, gy: int) -> int:
	return _ledge_side(Vector2i(gx, gy))

func nearest_graph_node(x: float, y: float) -> Vector2:
	var cell: Vector2i = _nearest_node(Vector2(x, y), 1000000)
	return _cell_world(cell) if cell != Vector2i.MAX else Vector2.ZERO

func nearest_graph_node_cell(x: float, y: float) -> Vector2i:
	var cell: Vector2i = _nearest_node(Vector2(x, y), 1000000)
	return cell if cell != Vector2i.MAX else Vector2i(-1, -1)

func calculated_jump_distance() -> float:
	return _jump_reach_px().x

func calculated_jump_height() -> float:
	return _jump_reach_px().y

func path_cost() -> float:
	return _path_cost if not _path.is_empty() else 0.0

func path_end() -> Vector2:
	return _path.back()["world"] if not _path.is_empty() else Vector2.ZERO

func path_target() -> Vector2:
	return _path_goal

func path_goal_cell() -> Vector2i:
	return _path_goal_cell

func path_fail_reason() -> String:
	return _fail_reason

func path_queue_size() -> int:
	var waiting: int = 0
	for agent_id in _agent_ids.keys():
		if is_instance_id_valid(agent_id) and bool(instance_from_id(agent_id).get("_path_pending")):
			waiting += 1
	return waiting

func waypoint_position(index: int) -> Vector2:
	return _path[index]["world"] if index >= 0 and index < _path.size() else Vector2.ZERO

func waypoint_cell(index: int) -> Vector2i:
	return _path[index]["cell"] if index >= 0 and index < _path.size() else Vector2i(-1, -1)

func waypoint_action(index: int) -> String:
	return str(_path[index]["action"]) if index >= 0 and index < _path.size() else ""

func distance_to_waypoint() -> float:
	if _path.is_empty() or host == null:
		return 0.0
	return host.global_position.distance_to(_path[_path_index]["world"])

func angle_to_waypoint() -> float:
	if _path.is_empty() or host == null:
		return 0.0
	return rad_to_deg(host.global_position.angle_to_point(_path[_path_index]["world"]))

func nearby_agent_count(radius: float) -> int:
	if host == null:
		return 0
	var count: int = 0
	for agent in _other_agents():
		if (agent.get("host") as Node2D).global_position.distance_to(host.global_position) <= radius:
			count += 1
	return count

func nearest_ledge(direction: String) -> Vector2:
	var ledge: Vector2i = _nearest_ledge_cell(-1 if direction == "left" else 1)
	return _cell_world(ledge) if ledge != Vector2i.MAX else Vector2.ZERO

func node_on_platform(group: String, which: String) -> Node:
	if host == null or not is_inside_tree():
		return null
	var here: Vector2i = _nearest_node(host.global_position, 3)
	if here == Vector2i.MAX:
		return null
	var platform: Dictionary = _walk_component(here)
	var picked: Node = null
	var picked_gap: float = INF if which != "furthest" else -1.0
	for candidate in get_tree().get_nodes_in_group(group):
		if candidate == host or not (candidate is Node2D):
			continue
		var at: Vector2i = _nearest_node((candidate as Node2D).global_position, 3)
		if at == Vector2i.MAX or not platform.has(at):
			continue
		var gap: float = host.global_position.distance_to((candidate as Node2D).global_position)
		if (which == "furthest" and gap > picked_gap) or (which != "furthest" and gap < picked_gap):
			picked_gap = gap
			picked = candidate
	return picked

func reached_side() -> int:
	return _reached_side

func coyote_timer() -> float:
	if host == null or host.is_on_floor():
		return 0.0
	return maxf(_coyote_window() - _floor_grace, 0.0)

func estimated_velocity_x() -> float:
	return _move_axis * _run_speed() if not _path.is_empty() else 0.0

func jump_toward_target() -> Vector2:
	return _jump_toward_target if _jump_toward_active else Vector2.ZERO

func patrol_direction() -> int:
	return _patrol_dir if _patrolling and not _patrol_dwelling else 0

func hazard_count() -> int:
	return _hazards.size()

func tracked_hazard_count() -> int:
	var count: int = 0
	for hazard in _hazards:
		if str(hazard.get("kind", "rect")) == "tracked":
			count += 1
	return count

func last_hazard_id() -> int:
	return _last_hazard_id

func hazard_at(x: float, y: float) -> int:
	var point: Vector2 = Vector2(x, y)
	var verdict: int = 0
	for hazard in _hazards:
		if _hazard_hit(hazard, point, 0.0):
			if bool(hazard["deadly"]):
				return 2
			verdict = 1
		elif hazard_margin > 0.0 and _hazard_hit(hazard, point, hazard_margin):
			verdict = 1
	return verdict

func current_portal_id() -> int:
	return int(_current_portal.get("id", -1))

func last_portal_id() -> int:
	return _last_portal_id

func portal_count() -> int:
	return _portals.size()

func nearest_portal_id(x: float, y: float, tag: String) -> int:
	var best_id: int = -1
	var best_gap: float = INF
	for portal in _portals:
		var gap: float = (portal["from"] as Vector2).distance_to(Vector2(x, y))
		if _portal_has_tag(portal, tag) and gap < best_gap:
			best_gap = gap
			best_id = int(portal["id"])
	return best_id

func furthest_portal_id(x: float, y: float, tag: String) -> int:
	var best_id: int = -1
	var best_gap: float = -1.0
	for portal in _portals:
		var gap: float = (portal["from"] as Vector2).distance_to(Vector2(x, y))
		if _portal_has_tag(portal, tag) and gap > best_gap:
			best_gap = gap
			best_id = int(portal["id"])
	return best_id

func portal_count_by_tag(tag: String) -> int:
	var count: int = 0
	for portal in _portals:
		if _portal_has_tag(portal, tag):
			count += 1
	return count

func portal_id_by_tag(tag: String, index: int) -> int:
	var seen: int = 0
	for portal in _portals:
		if _portal_has_tag(portal, tag):
			if seen == index:
				return int(portal["id"])
			seen += 1
	return -1

func portal_tag(portal_id: int) -> String:
	return str(_portal_by_id(portal_id).get("tag", ""))

func portal_type(portal_id: int) -> String:
	return str(_portal_by_id(portal_id).get("type", ""))

func portal_exit() -> Vector2:
	return _current_portal_exit if not _current_portal.is_empty() else Vector2.ZERO

func portal_progress() -> float:
	return _portal_progress if _portal_traversing else 0.0
