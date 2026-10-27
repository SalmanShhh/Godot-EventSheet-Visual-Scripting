## @ace_tags(movement, platformer, ai, pathfinding)
## @ace_category("Platformer Pathfinding")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
class_name PlatformerPathfinding
extends Node
## Jump-aware navigation for 2D platformers: builds a jump graph from your TileMapLayer so an enemy can actually chase through the level - walking where walking works and jumping where a jump is needed. Attach as a sibling of PlatformerMovement, build the graph once, and call Find Path To; jump reach is derived from the movement pack's real physics and the agent is driven through its ai_move_axis seam.

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

## Drive the sibling PlatformerMovement automatically. Off = paths still compute; read Path Move Axis / Path Wants Jump and steer yourself.
@export var auto_control: bool = true
## How close (px, horizontally) counts as reaching a waypoint.
@export var arrive_distance: float = 10.0
## The furthest safe drop (px) the graph will route through. Negative = no limit.
@export var max_fall_distance: float = 320.0
## Max jump height in px (0 = derive it from the sibling PlatformerMovement's jump_velocity/gravity).
@export var jump_height_override: float = 0.0
## Max jump distance in px (0 = derive it from the sibling PlatformerMovement's speed and air time).
@export var jump_distance_override: float = 0.0
## Draw the active path as a line in the world.
@export var debug_draw: bool = false
## Release the jump at the height each arc actually needs (short hops for flat gaps, full rises for tall ledges) - smoother-looking movement. Off = every jump is full height.
@export var variable_jump: bool = true
## Patrol discipline: routes may only WALK - no jumps, no portals, and no drops beyond Ledge Leniency. The agent stays on its platform.
@export var ledge_restriction: bool = false
## With Ledge Restriction on, drops up to this many pixels are still allowed (0 = no drops at all).
@export var ledge_leniency: float = 0.0
## relaxed: jump as soon as a jump leg starts. strict: walk onto the exact takeoff spot first - slower but precise on tight arcs.
@export_enum("relaxed", "strict") var jump_positioning: String = "relaxed"
## Grace window (s) for AI jumps just after running off the takeoff ledge - a frame-late jump still fires. Long enough a window (capped by the movement sibling's own) also builds COYOTE JUMP links: run off a ledge, then leap for gaps a standing jump cannot clear.
@export var coyote_time: float = 0.12
## While following a node (Find Path To Node), how often the route may refresh. Also the cooldown between drift re-routes.
@export var repath_interval: float = 0.5
## The route only refreshes when the followed node has moved at least this many pixels from where the current path was aimed.
@export var repath_threshold: float = 24.0
## No progress toward the current waypoint for this long fires On Waypoint Stuck and re-routes from wherever the agent actually is.
@export var stuck_timeout: float = 1.5
## No movement sibling? The built-in fallback driver moves the CharacterBody2D itself at this speed.
@export var fallback_move_speed: float = 200.0
## The fallback driver's jump velocity (negative = up). Also sizes jump arcs when nothing can be derived.
@export var fallback_jump_velocity: float = -400.0
## The fallback driver's gravity.
@export var fallback_gravity: float = 980.0
## Off = the agent freezes with its route, graph and settings kept, and route requests are ignored until it is switched back on (Set Enabled).
@export var nav_enabled: bool = true
## How routes are picked. balanced: distance and difficulty weighed together. shortest: fewest pixels, long jumps welcome. safest: chains of short hops over long leaps and deep drops. ground_hugging: walks whenever any walking route exists. no_falling: never descends by jump or fall (Max Traversal Drop raises the allowance). walk_only: never leaves its platform except by portal or moving platform.
@export_enum("balanced", "shortest", "safest", "ground_hugging", "no_falling", "walk_only") var path_strategy: String = "balanced"
## Drop the in-between waypoints of a straight walk so the agent walks the stretch in one leg.
@export var smooth_paths: bool = true
## The most nodes one route search may expand before it gives up (Path Fail Reason max_nodes_reached). Raise it for very large levels.
@export var max_search_nodes: int = 2000
## Jumps and falls that land more than this many pixels lower are left out of routes (fall damage, heavy units). -1 = no limit.
@export var max_traversal_drop: float = -1.0
## Knocked more than this many pixels off the leg it is walking, the agent re-plans from where it is (fires On Repath). 0 = off.
@export var drift_repath_distance: float = 0.0
## When the movement sibling has max_jumps of 2 or more, build DOUBLE JUMP links to ledges a single jump cannot reach.
@export var double_jump_links: bool = true
## Every hazard is surrounded by a danger buffer this many pixels wide: links through it cost more, so routes keep their distance.
@export var hazard_margin: float = 0.0
## How much more a link through a non-deadly hazard (or a hazard's margin) costs than a clean one.
@export var danger_cost_multiplier: float = 4.0
## A route asked for before any graph exists builds one from the first TileMapLayer with physics in the running scene.
@export var auto_build: bool = true
## Agents with the same non-empty tag SHARE one graph, obstacle edits, portals, hazards and moving platforms - built once for all of them. Give agents with different jump physics different tags. Empty = this agent keeps its own.
@export var map_tag: String = ""
## Cell size in pixels for a map with no TileMapLayer (Create Obstacle Map, Load Obstacle Map JSON). A tilemap's own tile size always wins.
@export var grid_cell_size: float = 32.0
## Agents routing to the same spot each claim a landing node; later arrivals take the nearest free node beside it instead of stacking.
@export var crowd_arrivals: bool = false
## Routes pay extra for the cells other agents stand on or are about to walk, so agents fan out over different ways.
@export var multi_agent_avoidance: bool = false
## Personal space in pixels for an agent with no route: closer than this to another agent on the same map, it steps away - never off a ledge. 0 = off.
@export var idle_separation: float = 0.0
## Seconds an agent rests after giving up on idle separation (a crowd too dense to spread).
@export var separation_cooldown: float = 5.0
## Seconds an agent keeps trying to separate before it gives up and rests.
@export var separation_give_up_time: float = 2.0
## Draw every node and link of the graph in the world, links coloured by kind (walk, jump, fall, portal...).
@export var debug_draw_graph: bool = false
## Print each route found (waypoints, cost) and each failure with its reason to the Output panel.
@export var debug_log: bool = false

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

## The cell a world position falls in. Tree-safe: outside a scene tree (tools, tests) the
## tilemap's own offset stands in for the global transform.
## @ace_hidden
func _world_to_cell(world: Vector2) -> Vector2i:
	if _tilemap != null:
		var local: Vector2 = _tilemap.to_local(world) if _tilemap.is_inside_tree() else world - _tilemap.position
		return _tilemap.local_to_map(local)
	var tile: float = _tile_px()
	return Vector2i(floori((world.x - _grid_origin.x) / tile), floori((world.y - _grid_origin.y) / tile))

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
## Jump reach in CELLS, rounded up (the graph's standing jump box).
## @ace_hidden
func _jump_reach_cells() -> Vector2i:
	var tile: float = _tile_px()
	var reach: Vector2 = _jump_reach_px()
	return Vector2i(maxi(int(ceil(reach.x / tile)), 1), maxi(int(ceil(reach.y / tile)), 1))
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

## @ace_action
## @ace_featured
## @ace_name("Build Nav Graph From Tilemap")
## @ace_category("Platformer Pathfinding")
## @ace_description("Scans a TileMapLayer's physics tiles into the navigation graph: standable cells become nodes, adjacent cells (one step up or down - stairs and tile slopes) become WALK links, and jump arcs / fall drops connect the rest, sized to the sibling PlatformerMovement's real jump. One-way tiles become jump-through platforms an agent can drop through. Call once on ready; Regenerate after level edits. Fires On Nav Graph Built.")
## @ace_display_template("Build nav graph from [i]{tilemap}[/i]")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.build_nav_graph({tilemap})")
func build_nav_graph(tilemap: Node) -> void:
	_tilemap = tilemap as TileMapLayer
	_custom_grid = false
	if _tilemap != null and _bind_shared_map(_tilemap.get_instance_id()):
		# Another agent on this map tag already built this exact map: share it.
		nav_graph_built.emit()
		_refresh_graph_overlay()
		return
	regenerate_nav_graph()

## @ace_action
## @ace_name("Regenerate Nav Graph")
## @ace_category("Platformer Pathfinding")
## @ace_description("Rebuilds the graph from the same map (after runtime tile edits, Set Tile State or Scan Collision Bodies).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.regenerate_nav_graph()")
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

## @ace_action
## @ace_featured
## @ace_name("Find Path To")
## @ace_category("Platformer Pathfinding")
## @ace_description("Routes to a world position and starts moving. Mode "reach" fails (On Path Failed) when the spot itself is unreachable; "nearest" never fails on a cut-off spot - it goes as close as it can get. Fires On Path Found / On Path Failed.")
## @ace_display_template("Find path to ([b]{x}[/b], [b]{y}[/b]) mode [b]{mode}[/b]")
## @ace_param_options(mode nearest, reach)
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.find_path_to({x}, {y}, "{mode}")")
func find_path_to(x: float, y: float, mode: String) -> void:
	_end_patrol()
	_side_request = {}
	_exact_final = NAN
	_route(x, y, mode)

## @ace_action
## @ace_name("Find Path To Node")
## @ace_category("Platformer Pathfinding")
## @ace_description("Routes to another node's position AND keeps following it: the route auto-refreshes every Repath Interval once the node has moved Repath Threshold pixels (firing On Repath) - one call chases forever. Stop Pathfinding ends the follow.")
## @ace_param_options(mode nearest, reach)
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.find_path_to_node({target}, "{mode}")")
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
## @ace_description("Clears the path (and any patrol, Jump Toward or portal in progress) and releases the movement pack back to the keyboard (ai_controlled off).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.stop_pathfinding()")
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

## @ace_action
## @ace_name("Set Auto Control")
## @ace_category("Platformer Pathfinding")
## @ace_description("On (default): the behavior drives the sibling PlatformerMovement. Off: paths still compute - read Path Move Axis / Path Wants Jump / Current Waypoint X/Y and drive anything you like.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
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
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_ledge_restriction({enabled})")
func set_ledge_restriction(enabled: bool) -> void:
	ledge_restriction = enabled

## @ace_action
## @ace_name("Set Ledge Leniency")
## @ace_category("Platformer Pathfinding")
## @ace_description("With Ledge Restriction on, drops up to this many pixels are still allowed (a patroller may hop down one step but never off the tower).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_ledge_leniency({pixels})")
func set_ledge_leniency(pixels: float) -> void:
	ledge_leniency = pixels

## @ace_action
## @ace_name("Set Jump Positioning")
## @ace_category("Platformer Pathfinding")
## @ace_description("relaxed (default): leap the moment a jump leg starts. strict: walk onto the exact takeoff spot first - slower but precise on tight arcs.")
## @ace_param_options(mode relaxed, strict)
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_jump_positioning("{mode}")")
func set_jump_positioning(mode: String) -> void:
	jump_positioning = mode

## @ace_action
## @ace_name("Set Coyote Time")
## @ace_category("Platformer Pathfinding")
## @ace_description("Grace window (s) for AI jumps just after running off the takeoff ledge.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_coyote_time({seconds})")
func set_coyote_time(seconds: float) -> void:
	coyote_time = seconds

## @ace_action
## @ace_name("Set Repath Interval")
## @ace_category("Platformer Pathfinding")
## @ace_description("While following a node, how often the route may refresh (chase freshness vs cost).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_repath_interval({seconds})")
func set_repath_interval(seconds: float) -> void:
	repath_interval = seconds

## @ace_action
## @ace_name("Set Repath Threshold")
## @ace_category("Platformer Pathfinding")
## @ace_description("The route only refreshes when the followed node has moved at least this many pixels.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_repath_threshold({pixels})")
func set_repath_threshold(pixels: float) -> void:
	repath_threshold = pixels

## @ace_action
## @ace_name("Set Max Paths Per Tick")
## @ace_category("Platformer Pathfinding")
## @ace_description("The SHARED budget across every agent: at most this many route computations per physics tick - extras defer a tick (Is Path Pending) instead of spiking the frame. The difference between 20 chasers working and not.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_max_paths_per_tick({count})")
func set_max_paths_per_tick(count: int) -> void:
	_shared_max_paths_per_tick = count

## @ace_action
## @ace_name("Add Portal")
## @ace_category("Platformer Pathfinding")
## @ace_description("Links two world positions as an instant PORTAL: an agent whose route uses it walks to the entrance and blinks to the exit (fires On Portal Entered, then On Portal Taken). Bidirectional works both ways. Portals join the graph immediately and survive Regenerate. Add Instant Portal adds a cost and a tag; Add Gradual Portal moves the agent instead of blinking it.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.add_portal({from_x}, {from_y}, {to_x}, {to_y}, {bidirectional})")
func add_portal(from_x: float, from_y: float, to_x: float, to_y: float, bidirectional: bool) -> void:
	_add_portal_record(Vector2(from_x, from_y), Vector2(to_x, to_y), bidirectional, "instant", 1.0, 0.0, "")

## @ace_action
## @ace_name("Clear Portals")
## @ace_category("Platformer Pathfinding")
## @ace_description("Removes every registered portal and elevator stop (takes effect on the next Regenerate Nav Graph).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.clear_portals()")
func clear_portals() -> void:
	_portals.clear()
	_elevator_stops.clear()
	regenerate_nav_graph()

## @ace_action
## @ace_name("Add Hazard")
## @ace_category("Platformer Pathfinding")
## @ace_description("Marks a world-space rectangle as hazardous. Deadly: routes NEVER pass through it (spikes, lava). Not deadly: routes pay Danger Cost Multiplier to cross, so it is taken only when no clean way exists (fire patches, slow mud). Applies to routing instantly - no rebuild - and On Hazard Entered fires if the agent ends up inside one anyway. Last Hazard Id names it for Remove Hazard.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.add_hazard({x}, {y}, {width}, {height}, {deadly})")
func add_hazard(x: float, y: float, width: float, height: float, deadly: bool) -> void:
	_hazards.append({"id": _next_hazard_id, "kind": "rect", "rect": Rect2(x, y, width, height), "deadly": deadly})
	_last_hazard_id = _next_hazard_id
	_next_hazard_id += 1
	# A hazard is watched per frame (On Hazard Entered fires on the way in), so a parked
	# agent starts paying for its tick again the moment one exists.
	set_physics_process(true)

## @ace_action
## @ace_name("Clear Hazards")
## @ace_category("Platformer Pathfinding")
## @ace_description("Removes every hazard of every kind (routing sees the change immediately).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.clear_hazards()")
func clear_hazards() -> void:
	_hazards.clear()

## @ace_action
## @ace_name("Add Moving Platform")
## @ace_category("Platformer Pathfinding")
## @ace_description("Registers a moving platform (an AnimatableBody2D you animate) by its two travel endpoints: the graph gains a PLATFORM link between them, and an agent routed across it walks to the track, WAITS for the platform, boards, rides, and walks off at the far side. Survives Regenerate. The pack never moves the platform - your sheet animates it between exactly these endpoints.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
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
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.clear_moving_platforms()")
func clear_moving_platforms() -> void:
	_moving_platforms.clear()
	regenerate_nav_graph()

## @ace_action
## @ace_name("Set Nav Debug Draw")
## @ace_category("Platformer Pathfinding")
## @ace_description("Draws the active path as a line in the world (great while tuning a level).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_nav_debug_draw({enabled})")
func set_nav_debug_draw(enabled: bool) -> void:
	debug_draw = enabled
	_refresh_debug()

## @ace_action
## @ace_name("Set Enabled")
## @ace_category("Platformer Pathfinding")
## @ace_description("Off freezes the agent where it stands with its route, graph and settings kept, and ignores route requests; on resumes exactly where it left off.")
## @ace_param(state, desc: "On to navigate, off to freeze.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_enabled({state})")
func set_enabled(state: bool) -> void:
	nav_enabled = state
	if not state:
		_move_axis = 0.0
		var movement: Node = _find_movement()
		if movement != null:
			movement.set("ai_move_axis", 0.0)
	else:
		_wake()

## @ace_condition
## @ace_name("Is Enabled")
## @ace_category("Platformer Pathfinding")
## @ace_description("True while the behavior is enabled (Set Enabled, or the Nav Enabled property).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.is_enabled()")
func is_enabled() -> bool:
	return nav_enabled

## @ace_action
## @ace_name("Set Path Strategy")
## @ace_category("Platformer Pathfinding")
## @ace_description("How routes are picked from now on: balanced, shortest (fewest pixels, long jumps welcome), safest (short hops over long leaps and deep drops), ground_hugging (walks whenever it can), no_falling (never descends by air) or walk_only (never leaves its platform except by portal or moving platform).")
## @ace_display_template("Pick routes by [b]{strategy}[/b]")
## @ace_param(strategy, options: balanced|shortest|safest|ground_hugging|no_falling|walk_only, default_word: balanced, desc: "The strategy routes are priced by.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_path_strategy("{strategy}")")
func set_path_strategy(strategy: String) -> void:
	path_strategy = strategy

## @ace_action
## @ace_name("Set Max Traversal Drop")
## @ace_category("Platformer Pathfinding")
## @ace_description("Jumps and falls landing more than this many pixels lower are left out of this agent's routes, so it goes down by slopes, portals and short hops instead (fall damage, heavy units). -1 = no limit.")
## @ace_param(pixels, desc: "The deepest drop allowed, in pixels (-1 = no limit).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_max_traversal_drop({pixels})")
func set_max_traversal_drop(pixels: float) -> void:
	max_traversal_drop = pixels

## @ace_action
## @ace_name("Set Drift Repath Distance")
## @ace_category("Platformer Pathfinding")
## @ace_description("Knocked more than this many pixels off the leg it is walking, the agent re-plans from where it is (fires On Repath), at most once per Repath Interval. 0 = off.")
## @ace_param(pixels, desc: "How far off its leg the agent may be pushed before it re-plans (0 = off).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_drift_repath_distance({pixels})")
func set_drift_repath_distance(pixels: float) -> void:
	drift_repath_distance = pixels

## @ace_action
## @ace_name("Set Movement Limit")
## @ace_category("Platformer Pathfinding")
## @ace_description("Overrides a movement limit the graph is built from instead of deriving it from the movement sibling: jump_height, jump_distance (pixels, 0 = derive again) or max_fall (pixels, negative = no limit). Regenerate Nav Graph afterwards.")
## @ace_param(limit, options: jump_height|jump_distance|max_fall, default_word: jump_height, desc: "Which limit to override.")
## @ace_param(value, desc: "The new limit in pixels.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_movement_limit("{limit}", {value})")
func set_movement_limit(limit: String, value: float) -> void:
	if limit == "jump_height":
		jump_height_override = value
	elif limit == "jump_distance":
		jump_distance_override = value
	elif limit == "max_fall":
		max_fall_distance = value
	else:
		push_warning("[PlatformerPathfinding] Set Movement Limit: unknown limit '%s' (jump_height, jump_distance, max_fall)." % limit)

## @ace_action
## @ace_name("Jump Toward")
## @ace_category("Platformer Pathfinding")
## @ace_description("A full-strength jump straight at a point with no route at all - a lunge, a pounce, a boss leap. Works from the ground (or mid-air when the movement sibling has a jump left). Ends any route or patrol. Fires On Jump Toward Launched as it leaves the ground.")
## @ace_display_template("Jump toward ([b]{x}[/b], [b]{y}[/b])")
## @ace_param(x, desc: "World X to leap toward.")
## @ace_param(y, desc: "World Y to leap toward.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.jump_toward({x}, {y})")
func jump_toward(x: float, y: float) -> void:
	if not nav_enabled or host == null:
		return
	stop_pathfinding()
	_jump_toward_target = Vector2(x, y)
	_jump_toward_active = true
	_jump_toward_launched = false
	_jump_toward_airborne = false
	_wake()

## @ace_action
## @ace_name("Teleport To")
## @ace_category("Platformer Pathfinding")
## @ace_description("Moves the agent to a world position instantly without throwing its route away (the drift re-route skips that tick).")
## @ace_param(x, desc: "World X.")
## @ace_param(y, desc: "World Y.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.teleport_to({x}, {y})")
func teleport_to(x: float, y: float) -> void:
	if host == null:
		return
	host.global_position = Vector2(x, y)
	host.velocity = Vector2.ZERO
	_teleport_grace = true
	_best_waypoint_distance = INF
	_stuck_clock = 0.0

## @ace_action
## @ace_name("Start Patrol")
## @ace_category("Platformer Pathfinding")
## @ace_description("Patrols the platform the agent stands on: walks to one end, waits Dwell seconds, turns, and repeats. The ends are found from the graph (ledges and walls, slopes and stairs included); Edge Distance keeps it that many pixels back from each end. Any route request ends the patrol.")
## @ace_display_template("Patrol the platform, waiting [b]{dwell}[/b] s at each end, [b]{edge_distance}[/b] px back from it")
## @ace_param(dwell, desc: "Seconds to wait at each end (0 = turn straight around).")
## @ace_param(edge_distance, desc: "Pixels to stay back from each end.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.start_patrol({dwell}, {edge_distance})")
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

## @ace_action
## @ace_name("Stop Patrol")
## @ace_category("Platformer Pathfinding")
## @ace_description("Ends the patrol; the agent stands where it is.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.stop_patrol()")
func stop_patrol() -> void:
	stop_pathfinding()

## @ace_condition
## @ace_name("Is Patrolling")
## @ace_category("Platformer Pathfinding")
## @ace_description("True while a Start Patrol patrol is running (walking or dwelling).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.is_patrolling()")
func is_patrolling() -> bool:
	return _patrolling

## @ace_expression
## @ace_name("Patrol Direction")
## @ace_category("Platformer Pathfinding")
## @ace_description("-1 walking left, 1 walking right, 0 while dwelling at an end or not patrolling. Handy for flipping the sprite.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.patrol_direction()")
func patrol_direction() -> int:
	return _patrol_dir if _patrolling and not _patrol_dwelling else 0

## @ace_action
## @ace_name("Find Path To Nearest Ledge")
## @ace_category("Platformer Pathfinding")
## @ace_description("Routes to the nearest edge of the agent's platform in a direction, stopping Distance pixels back from it. Fails (On Path Failed, reason no_ledge) when the platform has no ledge that way.")
## @ace_param(direction, options: left|right, default_word: left, desc: "Which way to look for the ledge.")
## @ace_param(distance, desc: "Pixels to stop short of the edge.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.find_path_to_nearest_ledge("{direction}", {distance})")
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

## @ace_action
## @ace_name("Find Path To Node Side")
## @ace_category("Platformer Pathfinding")
## @ace_description("Routes to a spot BESIDE a node instead of onto it, Distance pixels clear of it: left, right, or any (the nearer side, falling back to the other when it has no ground). Fires On Node Side Reached on arrival there; Reached Side says which side.")
## @ace_param(target, desc: "The node to stand beside.")
## @ace_param(side, options: any|left|right, default_word: any, desc: "Which side of it to stand on.")
## @ace_param(distance, desc: "Gap in pixels between the two (one tile is always kept).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.find_path_to_node_side({target}, "{side}", {distance})")
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

## @ace_expression
## @ace_name("Reached Side")
## @ace_category("Platformer Pathfinding")
## @ace_description("Which side Find Path To Node Side arrived on: -1 left, 1 right, 0 none yet.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.reached_side()")
func reached_side() -> int:
	return _reached_side

## @ace_expression
## @ace_name("Jump Toward Target")
## @ace_category("Platformer Pathfinding")
## @ace_description("The point the running Jump Toward is aimed at (zero when none is running).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.jump_toward_target()")
func jump_toward_target() -> Vector2:
	return _jump_toward_target if _jump_toward_active else Vector2.ZERO

## @ace_expression
## @ace_name("Coyote Timer")
## @ace_category("Platformer Pathfinding")
## @ace_description("Seconds of coyote grace left after running off a ledge (0 on the ground or once it has run out).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.coyote_timer()")
func coyote_timer() -> float:
	if host == null or host.is_on_floor():
		return 0.0
	return maxf(_coyote_window() - _floor_grace, 0.0)

## @ace_expression
## @ace_name("Estimated Velocity X")
## @ace_category("Platformer Pathfinding")
## @ace_description("The horizontal speed (px/s) the route is asking for right now - Path Move Axis times the run speed.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.estimated_velocity_x()")
func estimated_velocity_x() -> float:
	return _move_axis * _run_speed() if not _path.is_empty() else 0.0

## @ace_expression
## @ace_name("Path Cost")
## @ace_category("Platformer Pathfinding")
## @ace_description("The total cost of the active route under the current strategy (0 with no route).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.path_cost()")
func path_cost() -> float:
	return _path_cost if not _path.is_empty() else 0.0

## @ace_expression
## @ace_name("Path End")
## @ace_category("Platformer Pathfinding")
## @ace_description("Where the active route actually ends - in nearest mode this can differ from the asked-for spot.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.path_end()")
func path_end() -> Vector2:
	return _path.back()["world"] if not _path.is_empty() else Vector2.ZERO

## @ace_expression
## @ace_name("Path Target")
## @ace_category("Platformer Pathfinding")
## @ace_description("The world position the last route was asked for.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.path_target()")
func path_target() -> Vector2:
	return _path_goal

## @ace_expression
## @ace_name("Path Goal Cell")
## @ace_category("Platformer Pathfinding")
## @ace_description("The grid cell the last route ended on (the asked-for spot snapped to walkable ground).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.path_goal_cell()")
func path_goal_cell() -> Vector2i:
	return _path_goal_cell

## @ace_expression
## @ace_name("Path Fail Reason")
## @ace_category("Platformer Pathfinding")
## @ace_description("Why the last route failed: no_graph, no_start_node, no_goal_node, no_path, max_nodes_reached, no_ledge or no_target. Empty after a success.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.path_fail_reason()")
func path_fail_reason() -> String:
	return _fail_reason

## @ace_expression
## @ace_name("Path Queue Size")
## @ace_category("Platformer Pathfinding")
## @ace_description("How many agents are waiting on the shared per-tick route budget right now.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.path_queue_size()")
func path_queue_size() -> int:
	var waiting: int = 0
	for agent_id in _agent_ids.keys():
		if is_instance_id_valid(agent_id) and bool(instance_from_id(agent_id).get("_path_pending")):
			waiting += 1
	return waiting

## @ace_expression
## @ace_name("Waypoint Position")
## @ace_category("Platformer Pathfinding")
## @ace_description("The world position of a waypoint of the active route (zero out of range).")
## @ace_param(index, desc: "Waypoint index, from 0.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.waypoint_position({index})")
func waypoint_position(index: int) -> Vector2:
	return _path[index]["world"] if index >= 0 and index < _path.size() else Vector2.ZERO

## @ace_expression
## @ace_name("Waypoint Cell")
## @ace_category("Platformer Pathfinding")
## @ace_description("The grid cell of a waypoint of the active route ((-1, -1) out of range).")
## @ace_param(index, desc: "Waypoint index, from 0.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.waypoint_cell({index})")
func waypoint_cell(index: int) -> Vector2i:
	return _path[index]["cell"] if index >= 0 and index < _path.size() else Vector2i(-1, -1)

## @ace_expression
## @ace_name("Waypoint Action")
## @ace_category("Platformer Pathfinding")
## @ace_description("How a waypoint is reached: walk, jump, double_jump, coyote_jump, fall, fall_through, portal, portal_gradual or platform (empty out of range).")
## @ace_param(index, desc: "Waypoint index, from 0.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.waypoint_action({index})")
func waypoint_action(index: int) -> String:
	return str(_path[index]["action"]) if index >= 0 and index < _path.size() else ""

## @ace_expression
## @ace_name("Distance To Waypoint")
## @ace_category("Platformer Pathfinding")
## @ace_description("Pixels from the agent to its current waypoint (0 with no route).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.distance_to_waypoint()")
func distance_to_waypoint() -> float:
	if _path.is_empty() or host == null:
		return 0.0
	return host.global_position.distance_to(_path[_path_index]["world"])

## @ace_expression
## @ace_name("Angle To Waypoint")
## @ace_category("Platformer Pathfinding")
## @ace_description("Degrees from the agent to its current waypoint (0 with no route).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.angle_to_waypoint()")
func angle_to_waypoint() -> float:
	if _path.is_empty() or host == null:
		return 0.0
	return rad_to_deg(host.global_position.angle_to_point(_path[_path_index]["world"]))

## @ace_action
## @ace_name("Set Crowd Arrivals")
## @ace_category("Platformer Pathfinding")
## @ace_description("On: agents routing to the same spot each claim a landing node, so later arrivals stand beside it instead of stacking on one pixel.")
## @ace_param(enabled, desc: "On to spread arrivals.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_crowd_arrivals({enabled})")
func set_crowd_arrivals(enabled: bool) -> void:
	crowd_arrivals = enabled
	if not enabled:
		_release_claim()

## @ace_action
## @ace_name("Set Multi Agent Avoidance")
## @ace_category("Platformer Pathfinding")
## @ace_description("On: routes pay extra for cells other agents stand on or are about to walk, so a pack fans out over different ways.")
## @ace_param(enabled, desc: "On to avoid other agents' routes.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_multi_agent_avoidance({enabled})")
func set_multi_agent_avoidance(enabled: bool) -> void:
	multi_agent_avoidance = enabled

## @ace_action
## @ace_name("Set Separation Setting")
## @ace_category("Platformer Pathfinding")
## @ace_description("Changes an idle separation setting: distance (personal space in pixels, 0 = off), cooldown (seconds of rest after giving up) or give_up_time (seconds of trying before resting).")
## @ace_param(setting, options: distance|cooldown|give_up_time, default_word: distance, desc: "Which setting to change.")
## @ace_param(value, desc: "Its new value.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_separation_setting("{setting}", {value})")
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

## @ace_expression
## @ace_name("Nearby Agent Count")
## @ace_category("Platformer Pathfinding")
## @ace_description("How many other agents on the same map stand within a radius of this one.")
## @ace_param(radius, desc: "Radius in pixels.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.nearby_agent_count({radius})")
func nearby_agent_count(radius: float) -> int:
	if host == null:
		return 0
	var count: int = 0
	for agent in _other_agents():
		if (agent.get("host") as Node2D).global_position.distance_to(host.global_position) <= radius:
			count += 1
	return count

## @ace_condition
## @ace_name("Is At Ledge")
## @ace_category("Platformer Pathfinding")
## @ace_description("True while the agent stands on the edge node of its platform.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.is_at_ledge()")
func is_at_ledge() -> bool:
	if host == null:
		return false
	var here: Vector2i = _nearest_node(host.global_position, 1)
	return here != Vector2i.MAX and _ledge_side(here) != 0

## @ace_condition
## @ace_name("Is At Island")
## @ace_category("Platformer Pathfinding")
## @ace_description("True while the agent stands on a one-node platform.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.is_at_island()")
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

## @ace_condition
## @ace_name("Is On Same Platform")
## @ace_category("Platformer Pathfinding")
## @ace_description("True when the agent could WALK to the node - no jump or fall needed (slopes and stairs count).")
## @ace_param(target, desc: "The node to test.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.is_on_same_platform({target})")
func is_on_same_platform(target: Node) -> bool:
	if not (target is Node2D):
		return false
	return is_position_on_same_platform((target as Node2D).global_position.x, (target as Node2D).global_position.y)

## @ace_condition
## @ace_name("Is Position On Same Platform")
## @ace_category("Platformer Pathfinding")
## @ace_description("True when the agent could WALK to a world position - no jump or fall needed.")
## @ace_param(x, desc: "World X.")
## @ace_param(y, desc: "World Y.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.is_position_on_same_platform({x}, {y})")
func is_position_on_same_platform(x: float, y: float) -> bool:
	if host == null:
		return false
	var here: Vector2i = _nearest_node(host.global_position, 3)
	var there: Vector2i = _nearest_node(Vector2(x, y), 3)
	if here == Vector2i.MAX or there == Vector2i.MAX:
		return false
	return _walk_component(here).has(there)

## @ace_expression
## @ace_name("Nearest Ledge")
## @ace_category("Platformer Pathfinding")
## @ace_description("The nearest ledge of the agent's platform in a direction (zero when there is none).")
## @ace_param(direction, options: left|right, default_word: left, desc: "Which way to look.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.nearest_ledge("{direction}")")
func nearest_ledge(direction: String) -> Vector2:
	var ledge: Vector2i = _nearest_ledge_cell(-1 if direction == "left" else 1)
	return _cell_world(ledge) if ledge != Vector2i.MAX else Vector2.ZERO

## @ace_expression
## @ace_name("Node On Platform")
## @ace_category("Platformer Pathfinding")
## @ace_description("The nearest or furthest node of a group that stands on the agent's own platform (reachable by walking alone), or null - pick a target it can walk to.")
## @ace_param(group, default_code: "", desc: "The group to search, in quotes.")
## @ace_param(which, options: nearest|furthest, default_word: nearest, desc: "Nearest or furthest.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.node_on_platform({group}, "{which}")")
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

## @ace_action
## @ace_name("Create Obstacle Map")
## @ace_category("Platformer Pathfinding")
## @ace_description("Starts an empty map with no TileMapLayer: Width x Height cells of Cell Size pixels from the world origin, every cell clear. Fill it with Set Tile State or Scan Collision Bodies, then Regenerate Nav Graph.")
## @ace_param(width, desc: "Width in cells.")
## @ace_param(height, desc: "Height in cells.")
## @ace_param(cell_size, desc: "Cell size in pixels (0 keeps Grid Cell Size).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.create_obstacle_map({width}, {height}, {cell_size})")
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

## @ace_action
## @ace_name("Set Tile State")
## @ace_category("Platformer Pathfinding")
## @ace_description("Overrides one cell of the map: solid, clear, jump_thru (a one-way platform), slope_left (rises to the right) or slope_right (rises to the left). Overrides survive Regenerate; call Regenerate Nav Graph after a batch of them.")
## @ace_param(gx, desc: "Grid X.")
## @ace_param(gy, desc: "Grid Y.")
## @ace_param(state, options: solid|clear|jump_thru|slope_left|slope_right, default_word: solid, desc: "The cell's new state.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_tile_state({gx}, {gy}, "{state}")")
func set_tile_state(gx: int, gy: int, state: String) -> void:
	if not ["solid", "clear", "jump_thru", "slope_left", "slope_right"].has(state):
		push_warning("[PlatformerPathfinding] Set Tile State: unknown state '%s'." % state)
		return
	_tile_overrides[Vector2i(gx, gy)] = state

## @ace_action
## @ace_name("Set Tile State At")
## @ace_category("Platformer Pathfinding")
## @ace_description("Set Tile State for the cell under a world position.")
## @ace_param(x, desc: "World X.")
## @ace_param(y, desc: "World Y.")
## @ace_param(state, options: solid|clear|jump_thru|slope_left|slope_right, default_word: solid, desc: "The cell's new state.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_tile_state_at({x}, {y}, "{state}")")
func set_tile_state_at(x: float, y: float, state: String) -> void:
	var cell: Vector2i = _world_to_cell(Vector2(x, y))
	set_tile_state(cell.x, cell.y, state)

## @ace_action
## @ace_name("Scan Collision Bodies")
## @ace_category("Platformer Pathfinding")
## @ace_description("Marks every cell covered by the StaticBody2D shapes under a node as solid (one-way shapes as jump-through) - for levels built from bodies instead of tiles. Needs a grid first (Build Nav Graph From Tilemap or Create Obstacle Map); Regenerate Nav Graph afterwards.")
## @ace_param(root, desc: "The node whose StaticBody2D descendants are scanned.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.scan_collision_bodies({root})")
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

## @ace_action
## @ace_name("Clear Nav Graph")
## @ace_category("Platformer Pathfinding")
## @ace_description("Drops the graph, the obstacle map and every tile override (portals and hazards stay registered), stops the agent and fires On Nav Graph Cleared.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.clear_nav_graph()")
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

## @ace_action
## @ace_name("Load Obstacle Map JSON")
## @ace_category("Platformer Pathfinding")
## @ace_description("Rebuilds the map and graph from a string Obstacle Map JSON produced - a saved or pre-baked level, no TileMapLayer needed.")
## @ace_param(json, default_code: "", desc: "The JSON text, in quotes or from a variable.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.load_obstacle_map_json({json})")
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

## @ace_expression
## @ace_name("Obstacle Map JSON")
## @ace_category("Platformer Pathfinding")
## @ace_description("The current obstacle map (tiles, scanned bodies and overrides) as a JSON string, to save or ship with a level.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.obstacle_map_json()")
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

## @ace_expression
## @ace_name("Obstacle Map Source")
## @ace_category("Platformer Pathfinding")
## @ace_description("Where the map comes from: tilemap, custom or none.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.obstacle_map_source()")
func obstacle_map_source() -> String:
	if _custom_grid:
		return "custom"
	if _tilemap != null:
		return "tilemap"
	return "none"

## @ace_expression
## @ace_name("Tile State")
## @ace_category("Platformer Pathfinding")
## @ace_description("A cell's state: solid, clear, jump_thru, slope_left or slope_right (empty with no map or outside a custom map).")
## @ace_param(gx, desc: "Grid X.")
## @ace_param(gy, desc: "Grid Y.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.tile_state({gx}, {gy})")
func tile_state(gx: int, gy: int) -> String:
	if not _has_grid():
		return ""
	var cell: Vector2i = Vector2i(gx, gy)
	if _custom_grid and (gx < 0 or gy < 0 or gx >= _custom_size.x or gy >= _custom_size.y):
		return ""
	return _live_state(cell)

## @ace_condition
## @ace_name("Tile Has State")
## @ace_category("Platformer Pathfinding")
## @ace_description("True when a cell has the given state.")
## @ace_param(gx, desc: "Grid X.")
## @ace_param(gy, desc: "Grid Y.")
## @ace_param(state, options: solid|clear|jump_thru|slope_left|slope_right, default_word: solid, desc: "The state to test for.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.tile_has_state({gx}, {gy}, "{state}")")
func tile_has_state(gx: int, gy: int, state: String) -> bool:
	return tile_state(gx, gy) == state

## @ace_condition
## @ace_name("Tile Has State At")
## @ace_category("Platformer Pathfinding")
## @ace_description("True when the cell under a world position has the given state.")
## @ace_param(x, desc: "World X.")
## @ace_param(y, desc: "World Y.")
## @ace_param(state, options: solid|clear|jump_thru|slope_left|slope_right, default_word: solid, desc: "The state to test for.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.tile_has_state_at({x}, {y}, "{state}")")
func tile_has_state_at(x: float, y: float, state: String) -> bool:
	var cell: Vector2i = _world_to_cell(Vector2(x, y))
	return tile_state(cell.x, cell.y) == state

## @ace_expression
## @ace_name("World To Grid")
## @ace_category("Platformer Pathfinding")
## @ace_description("The grid cell under a world position.")
## @ace_param(x, desc: "World X.")
## @ace_param(y, desc: "World Y.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.world_to_grid({x}, {y})")
func world_to_grid(x: float, y: float) -> Vector2i:
	return _world_to_cell(Vector2(x, y)) if _has_grid() else Vector2i.ZERO

## @ace_expression
## @ace_name("Grid To World")
## @ace_category("Platformer Pathfinding")
## @ace_description("The world position of a cell's centre.")
## @ace_param(gx, desc: "Grid X.")
## @ace_param(gy, desc: "Grid Y.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.grid_to_world({gx}, {gy})")
func grid_to_world(gx: int, gy: int) -> Vector2:
	return _cell_world(Vector2i(gx, gy)) if _has_grid() else Vector2.ZERO

## @ace_expression
## @ace_name("Grid Size")
## @ace_category("Platformer Pathfinding")
## @ace_description("The map's size in cells (a tilemap's used area, or a custom map's size).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.grid_size()")
func grid_size() -> Vector2i:
	if _custom_grid:
		return _custom_size
	if _tilemap != null:
		return _tilemap.get_used_rect().size
	return Vector2i.ZERO

## @ace_expression
## @ace_name("Grid Tile Size")
## @ace_category("Platformer Pathfinding")
## @ace_description("The map's cell size in pixels (0 with no map).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.grid_tile_size()")
func grid_tile_size() -> float:
	return _tile_px() if _has_grid() else 0.0

## @ace_action
## @ace_name("Log Graph Stats")
## @ace_category("Platformer Pathfinding")
## @ace_description("Prints the graph's size to the Output panel: nodes, links by kind, portals, hazards, platforms and the jump reach.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.log_graph_stats()")
func log_graph_stats() -> void:
	var counts: Dictionary = {}
	var total: int = 0
	for cell in _edges:
		for edge in (_edges[cell] as Array):
			counts[edge["kind"]] = int(counts.get(edge["kind"], 0)) + 1
			total += 1
	print("[PlatformerPathfinding] nodes=%d links=%d %s portals=%d hazards=%d platforms=%d jump_reach=%s cells" % [_nodes.size(), total, str(counts), _portals.size(), _hazards.size(), _moving_platforms.size(), str(_jump_reach_cells())])

## @ace_action
## @ace_name("Set Debug Draw Graph")
## @ace_category("Platformer Pathfinding")
## @ace_description("Draws every node and link of the graph in the world, links coloured by kind.")
## @ace_param(enabled, desc: "On to draw the graph.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_debug_draw_graph({enabled})")
func set_debug_draw_graph(enabled: bool) -> void:
	debug_draw_graph = enabled
	_refresh_graph_overlay()

## @ace_condition
## @ace_name("Graph Node Exists")
## @ace_category("Platformer Pathfinding")
## @ace_description("True when a cell is a standable node of the graph.")
## @ace_param(gx, desc: "Grid X.")
## @ace_param(gy, desc: "Grid Y.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.graph_node_exists({gx}, {gy})")
func graph_node_exists(gx: int, gy: int) -> bool:
	return _nodes.has(Vector2i(gx, gy))

## @ace_condition
## @ace_name("Graph Node Exists At")
## @ace_category("Platformer Pathfinding")
## @ace_description("True when the cell under a world position is a standable node.")
## @ace_param(x, desc: "World X.")
## @ace_param(y, desc: "World Y.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.graph_node_exists_at({x}, {y})")
func graph_node_exists_at(x: float, y: float) -> bool:
	return _has_grid() and _nodes.has(_world_to_cell(Vector2(x, y)))

## @ace_condition
## @ace_name("Is Ledge Node")
## @ace_category("Platformer Pathfinding")
## @ace_description("True when a node is the edge of its platform (left, right or both).")
## @ace_param(gx, desc: "Grid X.")
## @ace_param(gy, desc: "Grid Y.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.is_ledge_node({gx}, {gy})")
func is_ledge_node(gx: int, gy: int) -> bool:
	return _ledge_side(Vector2i(gx, gy)) != 0

## @ace_expression
## @ace_name("Ledge Side")
## @ace_category("Platformer Pathfinding")
## @ace_description("Which side of a node is a ledge: -1 left, 1 right, 2 both (a one-node island), 0 neither.")
## @ace_param(gx, desc: "Grid X.")
## @ace_param(gy, desc: "Grid Y.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.ledge_side({gx}, {gy})")
func ledge_side(gx: int, gy: int) -> int:
	return _ledge_side(Vector2i(gx, gy))

## @ace_expression
## @ace_name("Graph Node Count")
## @ace_category("Platformer Pathfinding")
## @ace_description("How many standable nodes the graph has.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.graph_node_count()")
func graph_node_count() -> int:
	return _nodes.size()

## @ace_expression
## @ace_name("Graph Node Cell")
## @ace_category("Platformer Pathfinding")
## @ace_description("The grid cell of the node at an index ((-1, -1) out of range).")
## @ace_param(index, desc: "Node index, from 0.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.graph_node_cell({index})")
func graph_node_cell(index: int) -> Vector2i:
	if index < 0 or index >= _nodes.size():
		return Vector2i(-1, -1)
	return _nodes.keys()[index]

## @ace_expression
## @ace_name("Graph Node Position")
## @ace_category("Platformer Pathfinding")
## @ace_description("The world position of the node at an index (zero out of range).")
## @ace_param(index, desc: "Node index, from 0.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.graph_node_position({index})")
func graph_node_position(index: int) -> Vector2:
	if index < 0 or index >= _nodes.size():
		return Vector2.ZERO
	return _cell_world(_nodes.keys()[index])

## @ace_expression
## @ace_name("Graph Node Connection Count")
## @ace_category("Platformer Pathfinding")
## @ace_description("How many links leave a node.")
## @ace_param(gx, desc: "Grid X.")
## @ace_param(gy, desc: "Grid Y.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.graph_node_connection_count({gx}, {gy})")
func graph_node_connection_count(gx: int, gy: int) -> int:
	return (_edges.get(Vector2i(gx, gy), []) as Array).size()

## @ace_expression
## @ace_name("Graph Node Connection Kind")
## @ace_category("Platformer Pathfinding")
## @ace_description("The kind of one link leaving a node (walk, jump, fall, portal...).")
## @ace_param(gx, desc: "Grid X.")
## @ace_param(gy, desc: "Grid Y.")
## @ace_param(index, desc: "Link index, from 0.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.graph_node_connection_kind({gx}, {gy}, {index})")
func graph_node_connection_kind(gx: int, gy: int, index: int) -> String:
	var links: Array = _edges.get(Vector2i(gx, gy), [])
	return str(links[index]["kind"]) if index >= 0 and index < links.size() else ""

## @ace_expression
## @ace_name("Graph Node Connection Cost")
## @ace_category("Platformer Pathfinding")
## @ace_description("The cost of one link leaving a node, under the current strategy.")
## @ace_param(gx, desc: "Grid X.")
## @ace_param(gy, desc: "Grid Y.")
## @ace_param(index, desc: "Link index, from 0.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.graph_node_connection_cost({gx}, {gy}, {index})")
func graph_node_connection_cost(gx: int, gy: int, index: int) -> float:
	var links: Array = _edges.get(Vector2i(gx, gy), [])
	return _edge_cost(Vector2i(gx, gy), links[index]) if index >= 0 and index < links.size() else 0.0

## @ace_expression
## @ace_name("Graph Node Connection Target")
## @ace_category("Platformer Pathfinding")
## @ace_description("The world position one link leaving a node lands on.")
## @ace_param(gx, desc: "Grid X.")
## @ace_param(gy, desc: "Grid Y.")
## @ace_param(index, desc: "Link index, from 0.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.graph_node_connection_target({gx}, {gy}, {index})")
func graph_node_connection_target(gx: int, gy: int, index: int) -> Vector2:
	var links: Array = _edges.get(Vector2i(gx, gy), [])
	return _cell_world(links[index]["to"]) if index >= 0 and index < links.size() else Vector2.ZERO

## @ace_expression
## @ace_name("Nearest Graph Node")
## @ace_category("Platformer Pathfinding")
## @ace_description("The world position of the node nearest a point (zero with no graph).")
## @ace_param(x, desc: "World X.")
## @ace_param(y, desc: "World Y.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.nearest_graph_node({x}, {y})")
func nearest_graph_node(x: float, y: float) -> Vector2:
	var cell: Vector2i = _nearest_node(Vector2(x, y), 1000000)
	return _cell_world(cell) if cell != Vector2i.MAX else Vector2.ZERO

## @ace_expression
## @ace_name("Nearest Graph Node Cell")
## @ace_category("Platformer Pathfinding")
## @ace_description("The grid cell of the node nearest a point ((-1, -1) with no graph).")
## @ace_param(x, desc: "World X.")
## @ace_param(y, desc: "World Y.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.nearest_graph_node_cell({x}, {y})")
func nearest_graph_node_cell(x: float, y: float) -> Vector2i:
	var cell: Vector2i = _nearest_node(Vector2(x, y), 1000000)
	return cell if cell != Vector2i.MAX else Vector2i(-1, -1)

## @ace_expression
## @ace_name("Calculated Jump Distance")
## @ace_category("Platformer Pathfinding")
## @ace_description("The jump distance in pixels the graph is built with (derived or overridden).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.calculated_jump_distance()")
func calculated_jump_distance() -> float:
	return _jump_reach_px().x

## @ace_expression
## @ace_name("Calculated Jump Height")
## @ace_category("Platformer Pathfinding")
## @ace_description("The jump height in pixels the graph is built with (derived or overridden).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.calculated_jump_height()")
func calculated_jump_height() -> float:
	return _jump_reach_px().y

## @ace_action
## @ace_name("Add Circle Hazard")
## @ace_category("Platformer Pathfinding")
## @ace_description("Marks a circle as hazardous - an explosion, a fire burst. Deadly blocks routes; not deadly makes them costly. Last Hazard Id names it.")
## @ace_param(x, desc: "Centre X.")
## @ace_param(y, desc: "Centre Y.")
## @ace_param(radius, desc: "Radius in pixels.")
## @ace_param(deadly, desc: "Deadly blocks routes; off only makes them costly.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.add_circle_hazard({x}, {y}, {radius}, {deadly})")
func add_circle_hazard(x: float, y: float, radius: float, deadly: bool) -> void:
	_hazards.append({"id": _next_hazard_id, "kind": "circle", "center": Vector2(x, y), "radius": radius, "deadly": deadly})
	_last_hazard_id = _next_hazard_id
	_next_hazard_id += 1
	set_physics_process(true)

## @ace_action
## @ace_name("Add Tracked Hazard")
## @ace_category("Platformer Pathfinding")
## @ace_description("A circular hazard that FOLLOWS a node (a patrolling saw, a burning enemy) with no per-frame events, and removes itself when the node is freed. Last Hazard Id names it.")
## @ace_param(target, desc: "The node the hazard follows.")
## @ace_param(radius, desc: "Radius in pixels.")
## @ace_param(deadly, desc: "Deadly blocks routes; off only makes them costly.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.add_tracked_hazard({target}, {radius}, {deadly})")
func add_tracked_hazard(target: Node, radius: float, deadly: bool) -> void:
	if not (target is Node2D):
		return
	_hazards.append({"id": _next_hazard_id, "kind": "tracked", "node": target, "radius": radius, "deadly": deadly})
	_last_hazard_id = _next_hazard_id
	_next_hazard_id += 1
	set_physics_process(true)

## @ace_action
## @ace_name("Remove Hazard")
## @ace_category("Platformer Pathfinding")
## @ace_description("Removes one hazard by the id Last Hazard Id gave you.")
## @ace_param(hazard_id, desc: "The hazard's id.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.remove_hazard({hazard_id})")
func remove_hazard(hazard_id: int) -> void:
	for index in range(_hazards.size() - 1, -1, -1):
		if int(_hazards[index].get("id", -1)) == hazard_id:
			_hazards.remove_at(index)

## @ace_action
## @ace_name("Set Hazard Margin")
## @ace_category("Platformer Pathfinding")
## @ace_description("Surrounds every hazard with a danger buffer this many pixels wide, so routes keep their distance.")
## @ace_param(pixels, desc: "Buffer width in pixels (0 = none).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_hazard_margin({pixels})")
func set_hazard_margin(pixels: float) -> void:
	hazard_margin = maxf(pixels, 0.0)

## @ace_condition
## @ace_name("Is Position Hazardous")
## @ace_category("Platformer Pathfinding")
## @ace_description("True when a world position is inside any hazard.")
## @ace_param(x, desc: "World X.")
## @ace_param(y, desc: "World Y.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.is_position_hazardous({x}, {y})")
func is_position_hazardous(x: float, y: float) -> bool:
	return _point_in_hazard(Vector2(x, y), false)

## @ace_expression
## @ace_name("Hazard At")
## @ace_category("Platformer Pathfinding")
## @ace_description("The hazard level at a world position: 0 clear, 1 danger (or a hazard's margin), 2 deadly.")
## @ace_param(x, desc: "World X.")
## @ace_param(y, desc: "World Y.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.hazard_at({x}, {y})")
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

## @ace_expression
## @ace_name("Hazard Count")
## @ace_category("Platformer Pathfinding")
## @ace_description("How many hazards are registered (every kind).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.hazard_count()")
func hazard_count() -> int:
	return _hazards.size()

## @ace_expression
## @ace_name("Tracked Hazard Count")
## @ace_category("Platformer Pathfinding")
## @ace_description("How many node-following hazards are registered.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.tracked_hazard_count()")
func tracked_hazard_count() -> int:
	var count: int = 0
	for hazard in _hazards:
		if str(hazard.get("kind", "rect")) == "tracked":
			count += 1
	return count

## @ace_expression
## @ace_name("Last Hazard Id")
## @ace_category("Platformer Pathfinding")
## @ace_description("The id of the most recently added hazard, for Remove Hazard (0 before any).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.last_hazard_id()")
func last_hazard_id() -> int:
	return _last_hazard_id

## @ace_action
## @ace_name("Add Instant Portal")
## @ace_category("Platformer Pathfinding")
## @ace_description("A portal that BLINKS the agent from entrance to exit (a door, a teleporter). Cost 1 is the normal price; raise it to make routes avoid the portal. Tags (comma-separated) group portals for the by-tag actions and expressions. Last Portal Id names it.")
## @ace_param(from_x, desc: "Entrance X.")
## @ace_param(from_y, desc: "Entrance Y.")
## @ace_param(to_x, desc: "Exit X.")
## @ace_param(to_y, desc: "Exit Y.")
## @ace_param(bidirectional, desc: "Usable both ways.")
## @ace_param(cost, desc: "Price multiplier (1 = normal).")
## @ace_param(tag, default_code: "", desc: "Optional tags, comma-separated, in quotes.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.add_instant_portal({from_x}, {from_y}, {to_x}, {to_y}, {bidirectional}, {cost}, {tag})")
func add_instant_portal(from_x: float, from_y: float, to_x: float, to_y: float, bidirectional: bool, cost: float, tag: String) -> void:
	_add_portal_record(Vector2(from_x, from_y), Vector2(to_x, to_y), bidirectional, "instant", cost, 0.0, tag)

## @ace_action
## @ace_name("Add Gradual Portal")
## @ace_category("Platformer Pathfinding")
## @ace_description("A portal that MOVES the agent from entrance to exit in a straight line at Speed (a ladder, a lift, a zipline), with the movement sibling paused on the way. Cost 1 prices it by its travel time. Last Portal Id names it.")
## @ace_display_template("Add gradual portal ([b]{from_x}[/b], [b]{from_y}[/b]) to ([b]{to_x}[/b], [b]{to_y}[/b]) at [b]{speed}[/b] px/s")
## @ace_param(from_x, desc: "Entrance X.")
## @ace_param(from_y, desc: "Entrance Y.")
## @ace_param(to_x, desc: "Exit X.")
## @ace_param(to_y, desc: "Exit Y.")
## @ace_param(bidirectional, desc: "Usable both ways.")
## @ace_param(speed, desc: "Travel speed in px/s.")
## @ace_param(cost, desc: "Price multiplier (1 = priced by travel time).")
## @ace_param(tag, default_code: "", desc: "Optional tags, comma-separated, in quotes.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.add_gradual_portal({from_x}, {from_y}, {to_x}, {to_y}, {bidirectional}, {speed}, {cost}, {tag})")
func add_gradual_portal(from_x: float, from_y: float, to_x: float, to_y: float, bidirectional: bool, speed: float, cost: float, tag: String) -> void:
	_add_portal_record(Vector2(from_x, from_y), Vector2(to_x, to_y), bidirectional, "gradual", cost, speed, tag)

## @ace_action
## @ace_name("Add Elevator Stop")
## @ace_category("Platformer Pathfinding")
## @ace_description("Adds a stop to an elevator group: two-way gradual portals to every other stop of the group are created for you. One group name per elevator.")
## @ace_param(group, default_code: "", desc: "The elevator's name, in quotes.")
## @ace_param(x, desc: "Stop X.")
## @ace_param(y, desc: "Stop Y.")
## @ace_param(speed, desc: "Travel speed in px/s.")
## @ace_param(tag, default_code: "", desc: "Optional tags, comma-separated, in quotes.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.add_elevator_stop({group}, {x}, {y}, {speed}, {tag})")
func add_elevator_stop(group: String, x: float, y: float, speed: float, tag: String) -> void:
	var stop: Vector2 = Vector2(x, y)
	var stops: Array = _elevator_stops.get(group, [])
	for other in stops:
		_add_portal_record(other, stop, true, "gradual", 1.0, speed, tag)
	stops.append(stop)
	_elevator_stops[group] = stops

## @ace_action
## @ace_name("Pause At Portal")
## @ace_category("Platformer Pathfinding")
## @ace_description("Inside On Portal Entered: holds the agent at the entrance so your events can play a door or lift animation first. Then Resume Portal (the portal moves it) or Complete Portal (your events moved it).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.pause_at_portal()")
func pause_at_portal() -> void:
	if _portal_entering:
		_portal_paused = true

## @ace_action
## @ace_name("Resume Portal")
## @ace_category("Platformer Pathfinding")
## @ace_description("Runs a paused portal's own move: the blink, or the gradual travel.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.resume_portal()")
func resume_portal() -> void:
	if not _portal_paused:
		return
	_portal_paused = false
	if not _path.is_empty():
		_run_portal(_path[_path_index])

## @ace_action
## @ace_name("Complete Portal")
## @ace_category("Platformer Pathfinding")
## @ace_description("Finishes a paused portal WITHOUT its own move (your events already moved the agent), or cuts a gradual portal short where the agent is.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.complete_portal()")
func complete_portal() -> void:
	if not _portal_paused and not _portal_traversing:
		return
	_finish_portal()

## @ace_action
## @ace_name("Remove Portal")
## @ace_category("Platformer Pathfinding")
## @ace_description("Removes one portal by id; its links leave the graph immediately.")
## @ace_param(portal_id, desc: "The portal's id.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.remove_portal({portal_id})")
func remove_portal(portal_id: int) -> void:
	for index in range(_portals.size() - 1, -1, -1):
		if int(_portals[index]["id"]) == portal_id:
			_portals.remove_at(index)
	_unlink_portal(portal_id)
	_refresh_graph_overlay()

## @ace_action
## @ace_name("Remove Portal Near")
## @ace_category("Platformer Pathfinding")
## @ace_description("Removes the portal whose entrance or exit is nearest a world position.")
## @ace_param(x, desc: "World X.")
## @ace_param(y, desc: "World Y.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.remove_portal_near({x}, {y})")
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

## @ace_action
## @ace_name("Remove Portals By Tag")
## @ace_category("Platformer Pathfinding")
## @ace_description("Removes every portal carrying a tag (an empty tag removes them all).")
## @ace_param(tag, default_code: "", desc: "The tag, in quotes.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.remove_portals_by_tag({tag})")
func remove_portals_by_tag(tag: String) -> void:
	var doomed: Array = []
	for portal in _portals:
		if _portal_has_tag(portal, tag):
			doomed.append(int(portal["id"]))
	for portal_id in doomed:
		remove_portal(portal_id)

## @ace_action
## @ace_name("Set Portal Cost")
## @ace_category("Platformer Pathfinding")
## @ace_description("Changes a portal's price multiplier (higher = routes avoid it).")
## @ace_param(portal_id, desc: "The portal's id.")
## @ace_param(cost, desc: "Price multiplier (1 = normal).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_portal_cost({portal_id}, {cost})")
func set_portal_cost(portal_id: int, cost: float) -> void:
	var portal: Dictionary = _portal_by_id(portal_id)
	if not portal.is_empty():
		portal["cost"] = cost
		_relink_portal(portal)

## @ace_action
## @ace_name("Set Portal Speed")
## @ace_category("Platformer Pathfinding")
## @ace_description("Changes a gradual portal's travel speed in px/s.")
## @ace_param(portal_id, desc: "The portal's id.")
## @ace_param(speed, desc: "Travel speed in px/s.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_portal_speed({portal_id}, {speed})")
func set_portal_speed(portal_id: int, speed: float) -> void:
	var portal: Dictionary = _portal_by_id(portal_id)
	if not portal.is_empty():
		portal["speed"] = speed
		_relink_portal(portal)

## @ace_action
## @ace_name("Set Portal Tag")
## @ace_category("Platformer Pathfinding")
## @ace_description("Replaces a portal's tags.")
## @ace_param(portal_id, desc: "The portal's id.")
## @ace_param(tag, default_code: "", desc: "The new tags, comma-separated, in quotes.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_portal_tag({portal_id}, {tag})")
func set_portal_tag(portal_id: int, tag: String) -> void:
	var portal: Dictionary = _portal_by_id(portal_id)
	if not portal.is_empty():
		portal["tag"] = tag

## @ace_action
## @ace_name("Set Portal Ignore Hazards")
## @ace_category("Platformer Pathfinding")
## @ace_description("On: routes use the portal even when a hazard covers it.")
## @ace_param(portal_id, desc: "The portal's id.")
## @ace_param(ignore, desc: "On to ignore hazards.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_portal_ignore_hazards({portal_id}, {ignore})")
func set_portal_ignore_hazards(portal_id: int, ignore: bool) -> void:
	var portal: Dictionary = _portal_by_id(portal_id)
	if not portal.is_empty():
		portal["ignore_hazards"] = ignore

## @ace_action
## @ace_name("Set Portal Position")
## @ace_category("Platformer Pathfinding")
## @ace_description("Moves a portal's entrance and exit, keeping its id, type, cost, speed and tags - call it on a timer to follow a moving door.")
## @ace_param(portal_id, desc: "The portal's id.")
## @ace_param(from_x, desc: "Entrance X.")
## @ace_param(from_y, desc: "Entrance Y.")
## @ace_param(to_x, desc: "Exit X.")
## @ace_param(to_y, desc: "Exit Y.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_portal_position({portal_id}, {from_x}, {from_y}, {to_x}, {to_y})")
func set_portal_position(portal_id: int, from_x: float, from_y: float, to_x: float, to_y: float) -> void:
	var portal: Dictionary = _portal_by_id(portal_id)
	if not portal.is_empty():
		portal["from"] = Vector2(from_x, from_y)
		portal["to"] = Vector2(to_x, to_y)
		_relink_portal(portal)

## @ace_condition
## @ace_name("Is At Portal")
## @ace_category("Platformer Pathfinding")
## @ace_description("True while the agent is held at a portal entrance by Pause At Portal.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.is_at_portal()")
func is_at_portal() -> bool:
	return _portal_paused

## @ace_condition
## @ace_name("Is Traversing Portal")
## @ace_category("Platformer Pathfinding")
## @ace_description("True while a gradual portal is moving the agent.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.is_traversing_portal()")
func is_traversing_portal() -> bool:
	return _portal_traversing

## @ace_expression
## @ace_name("Current Portal Id")
## @ace_category("Platformer Pathfinding")
## @ace_description("The portal being (or last) taken - read it inside On Portal Entered / On Portal Taken (-1 before any).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.current_portal_id()")
func current_portal_id() -> int:
	return int(_current_portal.get("id", -1))

## @ace_expression
## @ace_name("Last Portal Id")
## @ace_category("Platformer Pathfinding")
## @ace_description("The id of the most recently added portal (-1 before any).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.last_portal_id()")
func last_portal_id() -> int:
	return _last_portal_id

## @ace_expression
## @ace_name("Portal Count")
## @ace_category("Platformer Pathfinding")
## @ace_description("How many portals are registered.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.portal_count()")
func portal_count() -> int:
	return _portals.size()

## @ace_expression
## @ace_name("Nearest Portal Id")
## @ace_category("Platformer Pathfinding")
## @ace_description("The portal whose entrance is nearest a point, optionally only those carrying a tag (-1 when none).")
## @ace_param(x, desc: "World X.")
## @ace_param(y, desc: "World Y.")
## @ace_param(tag, default_code: "", desc: "Only portals with this tag (empty = any), in quotes.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.nearest_portal_id({x}, {y}, {tag})")
func nearest_portal_id(x: float, y: float, tag: String) -> int:
	var best_id: int = -1
	var best_gap: float = INF
	for portal in _portals:
		var gap: float = (portal["from"] as Vector2).distance_to(Vector2(x, y))
		if _portal_has_tag(portal, tag) and gap < best_gap:
			best_gap = gap
			best_id = int(portal["id"])
	return best_id

## @ace_expression
## @ace_name("Furthest Portal Id")
## @ace_category("Platformer Pathfinding")
## @ace_description("The portal whose entrance is furthest from a point, optionally only those carrying a tag (-1 when none).")
## @ace_param(x, desc: "World X.")
## @ace_param(y, desc: "World Y.")
## @ace_param(tag, default_code: "", desc: "Only portals with this tag (empty = any), in quotes.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.furthest_portal_id({x}, {y}, {tag})")
func furthest_portal_id(x: float, y: float, tag: String) -> int:
	var best_id: int = -1
	var best_gap: float = -1.0
	for portal in _portals:
		var gap: float = (portal["from"] as Vector2).distance_to(Vector2(x, y))
		if _portal_has_tag(portal, tag) and gap > best_gap:
			best_gap = gap
			best_id = int(portal["id"])
	return best_id

## @ace_expression
## @ace_name("Portal Count By Tag")
## @ace_category("Platformer Pathfinding")
## @ace_description("How many portals carry a tag.")
## @ace_param(tag, default_code: "", desc: "The tag, in quotes.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.portal_count_by_tag({tag})")
func portal_count_by_tag(tag: String) -> int:
	var count: int = 0
	for portal in _portals:
		if _portal_has_tag(portal, tag):
			count += 1
	return count

## @ace_expression
## @ace_name("Portal Id By Tag")
## @ace_category("Platformer Pathfinding")
## @ace_description("The id of the index-th portal carrying a tag (-1 out of range).")
## @ace_param(tag, default_code: "", desc: "The tag, in quotes.")
## @ace_param(index, desc: "Index among those portals, from 0.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.portal_id_by_tag({tag}, {index})")
func portal_id_by_tag(tag: String, index: int) -> int:
	var seen: int = 0
	for portal in _portals:
		if _portal_has_tag(portal, tag):
			if seen == index:
				return int(portal["id"])
			seen += 1
	return -1

## @ace_expression
## @ace_name("Portal Tag")
## @ace_category("Platformer Pathfinding")
## @ace_description("A portal's tags (empty when it has none or does not exist).")
## @ace_param(portal_id, desc: "The portal's id.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.portal_tag({portal_id})")
func portal_tag(portal_id: int) -> String:
	return str(_portal_by_id(portal_id).get("tag", ""))

## @ace_expression
## @ace_name("Portal Type")
## @ace_category("Platformer Pathfinding")
## @ace_description("instant or gradual (empty when the portal does not exist).")
## @ace_param(portal_id, desc: "The portal's id.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.portal_type({portal_id})")
func portal_type(portal_id: int) -> String:
	return str(_portal_by_id(portal_id).get("type", ""))

## @ace_expression
## @ace_name("Portal Exit")
## @ace_category("Platformer Pathfinding")
## @ace_description("Where the current portal lets the agent out.")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.portal_exit()")
func portal_exit() -> Vector2:
	return _current_portal_exit if not _current_portal.is_empty() else Vector2.ZERO

## @ace_expression
## @ace_name("Portal Progress")
## @ace_category("Platformer Pathfinding")
## @ace_description("0 to 1 along a gradual portal while it moves the agent (0 otherwise).")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.portal_progress()")
func portal_progress() -> float:
	return _portal_progress if _portal_traversing else 0.0

## @ace_condition
## @ace_name("Is Path Pending")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.is_path_pending()")
func is_path_pending() -> bool:
	return _path_pending

## @ace_condition
## @ace_name("Is In Hazard")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.is_in_hazard()")
func is_in_hazard() -> bool:
	return host != null and _point_in_hazard(host.global_position, false)

## @ace_condition
## @ace_name("Has Path")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.has_path()")
func has_path() -> bool:
	return not _path.is_empty()

## @ace_condition
## @ace_name("Path Wants Jump")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.path_wants_jump()")
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
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.path_move_axis()")
func path_move_axis() -> float:
	return _move_axis

## @ace_expression
## @ace_name("Waypoint Count")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.waypoint_count()")
func waypoint_count() -> int:
	return _path.size()

## @ace_expression
## @ace_name("Current Waypoint Index")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.current_waypoint_index()")
func current_waypoint_index() -> int:
	return _path_index

## @ace_expression
## @ace_name("Current Waypoint X")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.current_waypoint_x()")
func current_waypoint_x() -> float:
	return (_path[_path_index]["world"] as Vector2).x if not _path.is_empty() else 0.0

## @ace_expression
## @ace_name("Current Waypoint Y")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.current_waypoint_y()")
func current_waypoint_y() -> float:
	return (_path[_path_index]["world"] as Vector2).y if not _path.is_empty() else 0.0

## @ace_expression
## @ace_name("Current Path Action")
## @ace_icon("res://eventsheet_addons/platformer_pathfinding/icon.svg")
## @ace_codegen_template("$PlatformerPathfinding.current_path_action()")
func current_path_action() -> String:
	return str(_path[_path_index]["action"]) if not _path.is_empty() else ""

## The grid's cell size in pixels: the TileMapLayer's tile height, or Grid Cell Size for a
## tilemap-less map.
## @ace_hidden
func _tile_px() -> float:
	if _tilemap != null and _tilemap.tile_set != null:
		return float(_tilemap.tile_set.tile_size.y)
	return maxf(grid_cell_size, 1.0)

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
func _add_portal_record(from: Vector2, to: Vector2, both: bool, portal_type: String, cost: float, speed: float, tag: String) -> int:
	var portal: Dictionary = {"id": _next_portal_id, "from": from, "to": to, "both": both, "type": portal_type,
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

# Platformer pathfinding: attach as a SIBLING of PlatformerMovement under a CharacterBody2D. Build Nav Graph from your TileMapLayer once, then Find Path To - the behavior derives jump reach from the movement pack and drives it through the ai_move_axis seam. Stairs and tile slopes walk (adjacent cells one step up/down are WALK links); gaps and ledges route through jump, double jump and coyote jump arcs, fall drops, fall-through drops off one-way platforms, portals and moving platforms.
