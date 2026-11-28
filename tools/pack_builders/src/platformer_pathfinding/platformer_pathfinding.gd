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
var watch_tile_edits: bool = false
var build_budget_ms: float = 4.0

#region state
## The version written into an exported obstacle map, and the newest one this behaviour reads.
const OBSTACLE_MAP_VERSION: int = 1
## Set Tile Hazard word: no hazard on the cell.
const HAZARD_CLEAR: String = "clear"
## Set Tile Hazard word: a costly cell routes pay extra to cross.
const HAZARD_DANGER: String = "danger"
## Set Tile Hazard word: a cell routes never cross.
const HAZARD_DEADLY: String = "deadly"
## Set Patrol Setting word: seconds to wait at each end or marker.
const PATROL_DWELL_TIME: String = "dwell_time"
## Set Patrol Setting word: pixels to turn short of each platform edge.
const PATROL_EDGE_DISTANCE: String = "edge_distance"
## Set Patrol Setting word: random seconds added to or taken from each wait.
const PATROL_DWELL_VARIATION: String = "dwell_variation"
## Set Patrol Setting word: percent of the run speed while a patrol walks.
const PATROL_SPEED: String = "speed"
## Set Patrol Setting word: seconds a cancelled patrol waits before it starts again.
const PATROL_RESUME_AFTER: String = "resume_after"
## Set Patrol Option word: turn round when another agent stands in the way.
const PATROL_TURN_AT_AGENTS: String = "turn_at_agents"
## Set Patrol Option word: turn round before stepping somewhere more hazardous.
const PATROL_TURN_BEFORE_DANGER: String = "turn_before_danger"
## Start Patrol Between Markers order: 1, 2, 3, 2, 1.
const PATROL_ORDER_PING_PONG: String = "ping_pong"
## Start Patrol Between Markers order: 1, 2, 3, 1, 2, 3.
const PATROL_ORDER_LOOP: String = "loop"
## Graph build step: reading the painted tiles of the map.
const BUILD_SCAN: int = 0
## Graph build step: adding the cells scanned from collision bodies.
const BUILD_BODIES: int = 1
## Graph build step: applying the hand-set tile states.
const BUILD_OVERRIDES: int = 2
## Graph build step: marking the cells that stop a body.
const BUILD_BLOCKING: int = 3
## Graph build step: finding the standable cells.
const BUILD_NODES: int = 4
## Graph build step: joining the standable cells with links.
const BUILD_LINKS: int = 5
## Graph build step: nothing left to do.
const BUILD_DONE: int = 6
## Link pass: walks to the cells beside a cell.
const LINK_PASS_WALK: int = 0
## Link pass: jumps and falls.
const LINK_PASS_JUMP: int = 1
## Link pass: double jumps.
const LINK_PASS_DOUBLE_JUMP: int = 2
## Link pass: jumps after running off a ledge.
const LINK_PASS_COYOTE: int = 3
## Link pass: drops through a one-way platform.
const LINK_PASS_FALL_THROUGH: int = 4
## How many link passes there are; every cell gets each pass before the next one starts.
const LINK_PASS_COUNT: int = 5
## One link out of a cell in the search graph.
class NavEdge extends RefCounted:
	## The cell the link leads to.
	var to: Vector2i = Vector2i.ZERO
	## What kind of link it is: walk, jump, double_jump, coyote_jump, fall, fall_through, portal, portal_gradual or platform.
	var kind: String = "walk"
	## What the router pays to take the link, before the Path Strategy re-prices an airborne one.
	var cost: float = 1.0
	## The id of the portal that made this link; -1 when it is not a portal link.
	var portal_id: int = -1

## One stop on the active route.
class NavWaypoint extends RefCounted:
	## Where the host heads for, in pixels.
	var world: Vector2 = Vector2.ZERO
	## What the host does to get here: walk, jump, double_jump, coyote_jump, fall, fall_through, portal, portal_gradual or platform.
	var action: String = "walk"
	## The graph cell this stop stands for.
	var cell: Vector2i = Vector2i.ZERO
	## The id of the portal this stop enters; -1 when it is not a portal stop.
	var portal_id: int = -1

## One registered portal: a link between two spots that survives a regenerate.
class NavPortal extends RefCounted:
	## The id Add Portal handed out.
	var id: int = 0
	## Where the portal is entered, in pixels.
	var from: Vector2 = Vector2.ZERO
	## Where the portal comes out, in pixels.
	var to: Vector2 = Vector2.ZERO
	## True when the portal can be taken in both directions.
	var both: bool = false
	## "instant" blinks across; "gradual" carries the host at its speed.
	var type: String = "instant"
	## Scales the cost of taking the portal in a route.
	var cost: float = 1.0
	## Pixels per second a gradual portal carries the host.
	var speed: float = 100.0
	## Comma-separated tags the portal answers to; empty for none.
	var tag: String = ""
	## True when a route may take the portal through a deadly hazard.
	var ignore_hazards: bool = false
	## The node the entrance follows; it may be freed from outside, so it is checked before use.
	var from_node: Node2D = null
	## True when the entrance follows from_node (a freed node reads as null, so the flag remembers).
	var from_follows: bool = false
	## The node the exit follows.
	var to_node: Node2D = null
	## True when the exit follows to_node.
	var to_follows: bool = false
	## Where the entrance was when the graph was last linked, so a node that creeps does not relink every tick.
	var linked_from: Vector2 = Vector2.ZERO
	## Where the exit was when the graph was last linked.
	var linked_to: Vector2 = Vector2.ZERO

## One stop of an elevator group: a fixed spot, or a node the stop follows.
class NavStop extends RefCounted:
	## The stop's position when it was added.
	var at: Vector2 = Vector2.ZERO
	## The node the stop follows, or null for a fixed stop.
	var node: Node2D = null

## One registered hazard: a rectangle, a circle, a circle that follows a node, the collision
## shape of a node, or one painted cell.
class NavHazard extends RefCounted:
	## The id Add Hazard handed out.
	var id: int = 0
	## "rect", "circle", "tracked", "shape" (a node's collision shapes) or "tile" (one cell).
	var kind: String = "rect"
	## The covered area of a rect, shape or tile hazard, in pixels. A shape hazard refreshes it
	## from its node every tick.
	var rect: Rect2 = Rect2()
	## The cell a tile hazard covers.
	var cell: Vector2i = Vector2i.ZERO
	## Where a shape hazard's node was when its bounds were last read.
	var seen_at: Transform2D = Transform2D()
	## The middle of a circle hazard, in pixels.
	var center: Vector2 = Vector2.ZERO
	## The reach of a circle or tracked hazard, in pixels.
	var radius: float = 0.0
	## The node a tracked hazard follows; it may be freed from outside, so it is checked before use.
	var node: Node = null
	## True when a route may never cross the hazard; false makes it a costly danger.
	var deadly: bool = false

## A platform being watched while it moves, until one trip there and back tells where its two ends are.
class NavLearn extends RefCounted:
	## The platform; it may be freed from outside, so it is checked before use.
	var node: Node2D = null
	## The two furthest-apart points seen so far: the ends of its travel.
	var end_a: Vector2 = Vector2.ZERO
	## The other end of its travel.
	var end_b: Vector2 = Vector2.ZERO
	## Where it was at the last look.
	var last: Vector2 = Vector2.ZERO
	## The direction of its travel, fixed once it has moved a tile; zero until then.
	var axis: Vector2 = Vector2.ZERO
	## Which way along that direction it is heading: 1, -1 or 0 before it has moved.
	var heading: int = 0
	## How far it has moved against its heading since it last moved with it.
	var against: float = 0.0
	## How many times it has turned round.
	var reversals: int = 0

## One registered moving platform: the node and the two ends of its travel.
class NavRide extends RefCounted:
	## The platform node; it may be freed from outside, so it is checked before use.
	var node: Node2D = null
	## One end of the platform's travel, in pixels.
	var a: Vector2 = Vector2.ZERO
	## The other end of the platform's travel, in pixels.
	var b: Vector2 = Vector2.ZERO

## A pending request to stand on one side of a node.
class NavSideRequest extends RefCounted:
	## The node to stand beside; it may be freed from outside, so it is checked before use.
	var node: Node = null
	## Which side: -1 left, 1 right.
	var side: int = 1
	## The spot the route is aimed at, in pixels.
	var spot: Vector2 = Vector2.ZERO

## What every agent on one map tag shares: the graph, the obstacle edits, the portals, the hazards and the platforms.
class NavSharedMap extends RefCounted:
	## The grid the shared graph was built over.
	var grid_id: int = 0
	## Standable cells.
	var nodes: Dictionary = {}
	## Links out of each cell.
	var edges: Dictionary = {}
	## Obstacle map the last build read.
	var states: Dictionary = {}
	## Cells that stop a body.
	var blocking: Dictionary = {}
	## Every cell holding anything.
	var blocking_down: Dictionary = {}
	## Hand-set tile states.
	var overrides: Dictionary = {}
	## Tile states scanned from collision bodies.
	var bodies: Dictionary = {}
	## Registered portals.
	var portals: Array[NavPortal] = []
	## Registered hazards.
	var hazards: Array[NavHazard] = []
	## Registered moving platforms.
	var platforms: Array[NavRide] = []
	## Elevator groups: group name -> stops (a position, or a node the stop follows).
	var elevators: Dictionary = {}
	## The id the next portal added on this map gets, so two agents never hand out the same one.
	var next_portal_id: int = 1
	## The id the next hazard added on this map gets.
	var next_hazard_id: int = 1
	## True while one agent is still building the graph over several frames.
	var building: bool = false
	## The instance id of the agent building it.
	var builder_id: int = 0

# --- Internal state (the graph lives per agent, or per map tag when one is set) ---
## The tile map the route is searched over.
var _tilemap: TileMapLayer = null
## The platformer movement behaviour that carries out the route.
var _movement: Node = null
## True once the warning about a tilted gravity has been printed.
var _gravity_angle_warned: bool = false
## True once the movement sibling has been checked for the members this behaviour drives.
var _movement_members_checked: bool = false
## Members this behaviour drives on the movement sibling without asking first; a sibling lacking one is reported once, not refused.
const MOVEMENT_MEMBERS: PackedStringArray = ["jump_velocity", "gravity", "ai_controlled", "ai_move_axis"]
## Standable cells (the cell the agent's feet occupy) -> true.
var _nodes: Dictionary = {}
## Links out of each cell: cell -> Array of NavEdge.
var _edges: Dictionary = {}
## Cells that stop a body (solid ground and slopes), for the arc clearance test.
var _blocking: Dictionary = {}
## Every cell holding anything, for the clearance test of a drop (it lands on a jump-through floor too).
var _blocking_down: Dictionary = {}
## The obstacle map the last build read: cell -> "solid" / "jump_thru" / "slope_left" / "slope_right". Clear cells are simply absent.
var _states: Dictionary = {}
## Hand-set tile states (Set Tile State, Load Obstacle Map JSON) layered over the scan; they survive Regenerate. "clear" erases whatever the scan found.
var _tile_overrides: Dictionary = {}
## Tile states scanned from collision bodies (Scan Collision Bodies); they survive Regenerate.
var _body_states: Dictionary = {}
## True when the map is a tilemap-less grid made by Create Obstacle Map or Load Obstacle Map JSON.
var _custom_grid: bool = false
## Width and height in tiles of the tilemap-less grid.
var _custom_size: Vector2i = Vector2i.ZERO
## Where the tile grid starts, in pixels.
var _grid_origin: Vector2 = Vector2.ZERO
## The active path, one NavWaypoint per stop.
var _path: Array[NavWaypoint] = []
## Which point of the route the host is heading for.
var _path_index: int = 0
## True once the host has jumped on the current leg.
var _jumped_this_segment: bool = false
## True once the jump button has been let go to cut the jump short.
var _jump_released: bool = false
## Upward speed at which the jump is cut short.
var _jump_release_velocity: float = 0.0
## True once the double jump has been used on the current leg.
var _second_jump_done: bool = false
## True once the host has dropped through a platform on the current leg.
var _dropped_this_segment: bool = false
## Counts every route the router has built, so a handler that asks for a new route while an old step is running can tell.
var _route_serial: int = 0
## A route asked for while a gradual portal carried the host; it runs the moment the portal is done.
var _held_goal: Vector2 = Vector2.ZERO
## How the held route treats an unreachable goal.
var _held_mode: String = "nearest"
## True while a route is held for the end of a portal.
var _held: bool = false
## Horizontal input the route asks for this frame, from -1 to 1.
var _move_axis: float = 0.0
## Line drawn along the route when debug drawing is on.
var _debug_line: Line2D = null
## Node that draws the whole search graph when debug drawing is on.
var _debug_graph: Node2D = null
## Registered portals - they survive regenerate.
var _portals: Array[NavPortal] = []
## Id given to the next portal that is added.
var _next_portal_id: int = 1
## Id of the portal used most recently; -1 when none.
var _last_portal_id: int = -1
## Elevator groups: group name -> Array of NavStop.
var _elevator_stops: Dictionary = {}
## Portal execution: the portal being taken, whether the sheet paused it, and the gradual move.
var _current_portal: NavPortal = null
## Where the host comes out of the portal it is using.
var _current_portal_exit: Vector2 = Vector2.ZERO
## True while the host walks into a portal.
var _portal_entering: bool = false
## True while the host waits inside a portal.
var _portal_paused: bool = false
## True while the host is being carried through a portal.
var _portal_traversing: bool = false
## Where the current portal trip starts.
var _portal_from: Vector2 = Vector2.ZERO
## Where the current portal trip ends.
var _portal_to: Vector2 = Vector2.ZERO
## How far through the current portal trip the host is, from 0 to 1.
var _portal_progress: float = 0.0
# Hazards are applied at ROUTING time (no rebuild needed when they change):
# deadly blocks links outright, danger multiplies their cost.
## World-space hazards.
var _hazards: Array[NavHazard] = []
## Id given to the next hazard that is added.
var _next_hazard_id: int = 1
## Id of the hazard touched most recently; 0 when none.
var _last_hazard_id: int = 0
## True if the host was inside a hazard on the previous frame.
var _was_in_hazard: bool = false
## Registered moving platforms, each a link the agent waits for, boards and rides.
var _moving_platforms: Array[NavRide] = []
# Follow mode (Find Path To Node): the tracked node + where the current path was aimed.
## Platforms watched by Learn Moving Platform until they have made one full trip.
var _learning: Array[NavLearn] = []
## The tiles the edit watch last saw: cell -> (source, atlas x, atlas y, alternative).
var _watch_seen: Dictionary = {}
## The cells the edit watch walks through, a slice per tick.
var _watch_cells: Array[Vector2i] = []
## Where the next slice starts in the watched cells.
var _watch_cursor: int = 0
## True once the watch has taken its first picture of the tiles.
var _watch_ready: bool = false
## True while this agent is building the graph over several frames.
var _build_active: bool = false
## True when another agent on the same map tag is building the graph this agent asked for.
var _build_waiting: bool = false
## Which step of the build is running (a BUILD_ word).
var _build_phase: int = BUILD_DONE
## The painted cells the scan step walks.
var _build_tiles: Array[Vector2i] = []
## The cells of the obstacle map in the order they were added, so later steps need no key list of their own.
var _build_keys: Array = []
## The cells the running step walks.
var _build_list: Array = []
## How far into the running step's list the build has got.
var _build_cursor: int = 0
## The standable cells, in the order they were found.
var _build_nodes: Array = []
## Which link pass is running (a LINK_PASS word).
var _build_pass: int = 0
## What to do the moment the build is done (a patrol or ledge request that came in while it ran).
var _after_build: Callable = Callable()
## The size of a cell in pixels while links are made.
var _link_tile: float = 32.0
## The jump reach in pixels while links are made (x distance, y height).
var _link_reach_px: Vector2 = Vector2.ZERO
## The jump reach in cells while links are made.
var _link_reach: Vector2i = Vector2i.ONE
## How many cells deep a fall may go while links are made.
var _link_fall: int = 1
## True while double jump links are made.
var _link_double: bool = false
## The double jump reach in cells while links are made.
var _link_double_reach: Vector2i = Vector2i.ONE
## How many cells a coyote jump may cover while links are made; 0 when there are none.
var _link_coyote_cells: int = 0
## The node the host keeps routing toward.
var _follow_target: Node = null
## The point the current route leads to.
var _path_goal: Vector2 = Vector2.ZERO
## The tile the current route leads to.
var _path_goal_cell: Vector2i = Vector2i.ZERO
## Total cost of the current route.
var _path_cost: float = 0.0
## Why the most recent route failed, as a word.
var _fail_reason: String = ""
## Why the most recent search found no route.
var _last_search_fail: String = ""
## The legs of the most recent route, in order.
var _last_route_edges: Array[NavEdge] = []
## How a goal that cannot be reached is handled: nearest point or fail.
var _goal_mode: String = "nearest"
## Seconds since the route was last worked out.
var _repath_clock: float = 0.0
## A route whose last waypoint must land on an exact x (patrol ends, side-of-node, ledge offsets).
var _exact_final: float = NAN
## True when the host must reach the exact point, not just near it.
var _exact_arrival: bool = false
# Coyote grace: seconds since the host last stood on the floor.
## Seconds left in which losing the floor is not counted as falling off the route.
var _floor_grace: float = 0.0
# Stuck watchdog: best distance seen toward the current waypoint + time without progress.
## Closest the host has been to the current point, used to spot it getting stuck.
var _best_waypoint_distance: float = INF
## Seconds the host has made no progress toward the current point.
var _stuck_clock: float = 0.0
## True for a moment after the host is moved by hand, so it is not counted as stuck.
var _teleport_grace: bool = false
# Budget-deferred request (this agent is queued for a later tick).
## True while a route is waiting for its turn to be searched.
var _path_pending: bool = false
## The point the waiting route leads to.
var _pending_goal: Vector2 = Vector2.ZERO
## How the waiting route treats an unreachable goal.
var _pending_goal_mode: String = "nearest"
# Patrol: the two ends of the platform, the walking direction, and the dwell at each end.
## True while the host walks back and forth between two ends.
var _patrolling: bool = false
## The two points the host patrols between.
var _patrol_ends: Array = []
## Walking direction: 1 toward the second end, -1 toward the first, 0 when not patrolling.
var _patrol_dir: int = 0
## Seconds the host rests at each end.
var _patrol_dwell: float = 0.0
## True while the host is resting at an end.
var _patrol_dwelling: bool = false
## Seconds spent resting at the current end.
var _patrol_clock: float = 0.0
## Pixels the patrol turns short of each platform edge.
var _patrol_edge: float = 0.0
## Random seconds added to or taken from each wait, so guards do not move in step.
var _patrol_dwell_variation: float = 0.0
## Percent of the movement sibling run speed used while a patrol walks.
var _patrol_speed_percent: float = 100.0
## Seconds a patrol waits after the route that cancelled it ends, before it starts again (0 = never).
var _patrol_resume_after: float = 0.0
## True while a patrol turns around when another agent stands in its way.
var _patrol_turn_at_agents: bool = true
## True while a patrol turns around before stepping somewhere more hazardous than where it stands.
var _patrol_turn_before_danger: bool = true
## Seconds left before a patrol may turn for an agent again (stops two patrollers turning back and forth).
var _patrol_bump_clock: float = 0.0
## The markers a between-markers patrol visits (empty for a plain platform patrol).
var _patrol_markers: Array[Node2D] = []
## Which marker the patrol heads for.
var _patrol_marker_index: int = -1
## 1 or -1: which way a ping-pong patrol steps through the markers.
var _patrol_marker_step: int = 1
## True when the markers are visited in a loop instead of back and forth.
var _patrol_loop: bool = false
## Markers in a row the patrol could not reach.
var _patrol_marker_fails: int = 0
## True while the short wait before trying a marker again is running.
var _patrol_retry: bool = false
## The run speed the movement sibling had before a patrol slowed it; negative when it is untouched.
var _patrol_base_speed: float = -1.0
## What a route cancelled, for Resume After: empty for nothing, "platform" or "markers".
var _patrol_memory_kind: String = ""
## The group of markers of a cancelled between-markers patrol.
var _patrol_memory_group: String = ""
## The group of markers the running between-markers patrol visits.
var _patrol_group: String = ""
## Whether the cancelled markers patrol looped.
var _patrol_memory_loop: bool = false
## Seconds the host has stood idle since the route that cancelled its patrol ended.
var _patrol_resume_clock: float = 0.0
# Jump Toward: a pathless full-strength leap at a point.
## True while a Jump Toward is in progress.
var _jump_toward_active: bool = false
## True once the Jump Toward jump has left the ground.
var _jump_toward_launched: bool = false
## True while the Jump Toward jump is in the air.
var _jump_toward_airborne: bool = false
## The point a Jump Toward is aiming at.
var _jump_toward_target: Vector2 = Vector2.ZERO
# Find Path To Node Side: the node, the side and the spot the route was aimed at.
## The pending request to stand on a given side of a target.
var _side_request: NavSideRequest = null
## Which side of the target the host arrived on: -1 left, 1 right, 0 none.
var _reached_side: int = 0
# Idle separation: time spent trying, and the rest after giving up.
## Seconds the host has spent trying to separate from a neighbour.
var _separation_clock: float = 0.0
## Seconds still to rest after giving up on separating.
var _separation_rest: float = 0.0
## True while the host is stepping away from a neighbour.
var _separating: bool = false
# Crowd arrivals: the goal-claim key this agent holds.
## Key of the goal spot this agent has claimed.
var _claimed_key: String = ""
# The SHARED path budget: statics are one value across every agent of this behavior, so
# N chasers repathing at once spread their A* runs over frames instead of spiking one.
## Most routes all agents together may search in one frame.
static var _shared_max_paths_per_tick: int = 8
## The frame the shared route count belongs to.
static var _shared_tick_id: int = -1
## Routes searched so far this frame by all agents.
static var _shared_paths_this_tick: int = 0
# Every agent that has routed or ticked (instance id -> true), for crowd, avoidance and spacing.
## Instance ids of every agent that has routed or ticked, shared by all agents.
static var _agent_ids: Dictionary = {}
# Crowd arrivals: "<map key>|<cell>" -> the instance id of the agent that claimed that goal.
## Goal spots claimed by agents, so two do not pick the same one.
static var _goal_claims: Dictionary = {}
# Map tags: tag -> the shared graph, obstacle edits, portals, hazards and platforms.
## Shared graph, obstacle edits, portals, hazards and platforms for each map tag.
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

## True while the nav graph is still being built a few milliseconds per frame (see Build Budget Ms). A
## route asked for meanwhile waits, and On Nav Graph Built fires when the graph is done.
## @ace_condition
## @ace_name("Is Building Nav Graph")
func is_building_nav_graph() -> bool:
	return _graph_building()

## How much of the running graph build is done, from 0 to 1 (1 when no build is running).
## @ace_expression
## @ace_name("Build Progress")
func build_progress() -> float:
	if _build_active:
		return _build_fraction()
	if _graph_building():
		var shared: NavSharedMap = _shared_maps.get(map_tag, null) as NavSharedMap
		var builder: PlatformerPathfinding = instance_from_id(shared.builder_id) as PlatformerPathfinding
		return builder._build_fraction() if builder != null else 0.0
	return 1.0

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
	var waypoint: NavWaypoint = _path[_path_index]
	if waypoint.action == "jump" or waypoint.action == "double_jump":
		return true
	if waypoint.action == "coyote_jump":
		return not host.is_on_floor() and _floor_grace >= _coyote_window() * 0.5
	# Step assist: a close-and-higher walk waypoint needs a hop on full-block stairs.
	var tile: float = _tile_px()
	var target: Vector2 = waypoint.world
	return waypoint.action == "walk" and target.y < host.global_position.y - 8.0 and absf(target.x - host.global_position.x) < tile * 1.5

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
	return _path[_path_index].world.x if not _path.is_empty() else 0.0

## @ace_expression
## @ace_name("Current Waypoint Y")
func current_waypoint_y() -> float:
	return _path[_path_index].world.y if not _path.is_empty() else 0.0

## @ace_expression
## @ace_name("Current Path Action")
func current_path_action() -> String:
	return _path[_path_index].action if not _path.is_empty() else ""
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

## The merged obstacle map as a fresh dictionary: painted tiles, then scanned bodies, then the hand-set overrides.
## @ace_hidden
func _merged_states() -> Dictionary:
	var merged: Dictionary = {}
	if _tilemap != null:
		for cell in _tilemap.get_used_cells():
			var tile_data: TileData = _tilemap.get_cell_tile_data(cell)
			if tile_data != null:
				var painted: String = _tile_state_of(tile_data)
				if painted != "":
					merged[cell] = painted
	for cell in _body_states:
		merged[cell] = _body_states[cell]
	for cell in _tile_overrides:
		if str(_tile_overrides[cell]) == "clear":
			merged.erase(cell)
		else:
			merged[cell] = _tile_overrides[cell]
	return merged

## Joins a map tag's shared map (or leaves the agent its own when the tag is empty): every
## container below is the SAME object for every agent on the tag, so one build serves them all.
## Returns true when the shared map is already built over this grid.
## @ace_hidden
func _bind_shared_map(grid_id: int) -> bool:
	if map_tag == "":
		return false
	var shared: NavSharedMap = _shared_maps.get(map_tag, null) as NavSharedMap
	if shared == null:
		shared = NavSharedMap.new()
		_shared_maps[map_tag] = shared
	var built: bool = shared.grid_id == grid_id and not shared.nodes.is_empty() and not shared.building
	shared.grid_id = grid_id
	_nodes = shared.nodes
	_edges = shared.edges
	_states = shared.states
	_blocking = shared.blocking
	_blocking_down = shared.blocking_down
	_tile_overrides = shared.overrides
	_body_states = shared.bodies
	_portals = shared.portals
	_hazards = shared.hazards
	_moving_platforms = shared.platforms
	_elevator_stops = shared.elevators
	return built

## True when another live agent on this map tag is still building the graph over this grid, so a
## second build would only repeat it.
## @ace_hidden
func _joined_running_build(grid_id: int) -> bool:
	if map_tag == "":
		return false
	var shared: NavSharedMap = _shared_maps.get(map_tag, null) as NavSharedMap
	return shared != null and shared.building and shared.grid_id == grid_id and shared.builder_id != get_instance_id() and is_instance_id_valid(shared.builder_id)

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
		if (not deadly_only or hazard.deadly) and _hazard_hit(hazard, world, 0.0):
			return true
	return false

## Whether one hazard covers a point, grown by `margin` pixels.
## @ace_hidden
func _hazard_hit(hazard: NavHazard, world: Vector2, margin: float) -> bool:
	if hazard.kind == "circle":
		return world.distance_to(hazard.center) <= hazard.radius + margin
	if hazard.kind == "tracked":
		var followed: Variant = hazard.node
		if not is_instance_valid(followed) or not (followed is Node2D):
			return false
		return world.distance_to((followed as Node2D).global_position) <= hazard.radius + margin
	return hazard.rect.grow(margin).has_point(world)

## Drops hazards whose node has been freed, and re-reads the bounds of node-shape hazards whose
## node has moved since the last read.
## @ace_hidden
func _prune_tracked_hazards() -> void:
	for index in range(_hazards.size() - 1, -1, -1):
		var hazard: NavHazard = _hazards[index]
		if hazard.kind != "tracked" and hazard.kind != "shape":
			continue
		if not is_instance_valid(hazard.node):
			_hazards.remove_at(index)
		elif hazard.kind == "shape":
			_refresh_shape_hazard(hazard)

## Re-reads a node-shape hazard's world bounds when its node has moved, turned or scaled.
## @ace_hidden
func _refresh_shape_hazard(hazard: NavHazard) -> void:
	var followed: Node2D = hazard.node as Node2D
	if followed == null:
		return
	var now: Transform2D = _world_transform_of(followed)
	if hazard.seen_at == now and hazard.rect.size != Vector2.ZERO:
		return
	hazard.seen_at = now
	hazard.rect = _node_shape_bounds(followed)

## A node's transform in the world. Tree-safe: outside a scene tree (tools, tests) the transforms of its
## 2D parents are multiplied by hand, the way a tilemap stands in for its global transform.
## @ace_hidden
func _world_transform_of(node: Node2D) -> Transform2D:
	if node.is_inside_tree():
		return node.global_transform
	var world: Transform2D = node.transform
	var up: Node = node.get_parent()
	while up is Node2D:
		world = (up as Node2D).transform * world
		up = up.get_parent()
	return world

## The world-space box around every enabled collision shape and collision polygon at or under
## a node (a rotated shape is covered by its bounding box). A node with no shape is a box one
## tile wide around its origin, so a hazard from it still means something.
## @ace_hidden
func _node_shape_bounds(root: Node2D) -> Rect2:
	var corners: PackedVector2Array = PackedVector2Array()
	var shape_nodes: Array = root.find_children("*", "CollisionShape2D", true, false)
	if root is CollisionShape2D:
		shape_nodes.append(root)
	for shape_node: Node in shape_nodes:
		var collider: CollisionShape2D = shape_node as CollisionShape2D
		if collider == null or collider.shape == null or collider.disabled:
			continue
		var local: Rect2 = collider.shape.get_rect()
		var shape_world: Transform2D = _world_transform_of(collider)
		for corner: Vector2 in [local.position, local.position + Vector2(local.size.x, 0.0), local.end, local.position + Vector2(0.0, local.size.y)]:
			corners.append(shape_world * corner)
	var polygon_nodes: Array = root.find_children("*", "CollisionPolygon2D", true, false)
	if root is CollisionPolygon2D:
		polygon_nodes.append(root)
	for polygon_node: Node in polygon_nodes:
		var polygon: CollisionPolygon2D = polygon_node as CollisionPolygon2D
		if polygon == null or polygon.disabled:
			continue
		var polygon_world: Transform2D = _world_transform_of(polygon)
		for point: Vector2 in polygon.polygon:
			corners.append(polygon_world * point)
	if corners.is_empty():
		var half: float = _tile_px() * 0.5
		return Rect2(_world_transform_of(root).origin - Vector2(half, half), Vector2(half, half) * 2.0)
	var bounds: Rect2 = Rect2(corners[0], Vector2.ZERO)
	for corner: Vector2 in corners:
		bounds = bounds.expand(corner)
	return bounds

## Watches every platform being learned: once it has turned round twice (a trip there and back),
## its two furthest points are registered like Add Moving Platform would.
## @ace_hidden
func _learn_platforms() -> void:
	for index in range(_learning.size() - 1, -1, -1):
		var learner: NavLearn = _learning[index]
		if not is_instance_valid(learner.node):
			_learning.remove_at(index)
			continue
		var here: Vector2 = _world_transform_of(learner.node).origin
		if here.distance_to(learner.end_a) > learner.end_a.distance_to(learner.end_b):
			learner.end_b = here
		elif here.distance_to(learner.end_b) > learner.end_a.distance_to(learner.end_b):
			learner.end_a = here
		var step: Vector2 = here - learner.last
		learner.last = here
		if learner.axis == Vector2.ZERO:
			if learner.end_a.distance_to(learner.end_b) >= _tile_px():
				learner.axis = (learner.end_b - learner.end_a).normalized()
				learner.heading = 1 if step.dot(learner.axis) >= 0.0 else -1
			continue
		var along: float = step.dot(learner.axis) * float(learner.heading)
		if along >= 0.0:
			learner.against = 0.0
			continue
		learner.against -= along
		if learner.against >= 3.0:
			learner.against = 0.0
			learner.heading = -learner.heading
			learner.reversals += 1
		if learner.reversals >= 2:
			_learning.remove_at(index)
			add_moving_platform(learner.node, learner.end_a.x, learner.end_a.y, learner.end_b.x, learner.end_b.y)

## The tile painted in a cell, as one comparable value (source, atlas column, atlas row, alternative).
## @ace_hidden
func _tile_signature(cell: Vector2i) -> Vector4i:
	var atlas: Vector2i = _tilemap.get_cell_atlas_coords(cell)
	return Vector4i(_tilemap.get_cell_source_id(cell), atlas.x, atlas.y, _tilemap.get_cell_alternative_tile(cell))

## Watch Tile Edits: compares a slice of the painted tiles with the picture it took (about two
## thousand a tick), and when a pass over every tile ends, looks for tiles painted or erased since.
## Whatever changed is rescanned together as one region.
## @ace_hidden
func _watch_tiles() -> void:
	if not watch_tile_edits or _tilemap == null or _nodes.is_empty() or _graph_building():
		return
	if not _watch_ready:
		_watch_ready = true
		_watch_seen.clear()
		_watch_cells = _tilemap.get_used_cells()
		_watch_cursor = 0
		for cell in _watch_cells:
			_watch_seen[cell] = _tile_signature(cell)
		return
	var changed: Rect2i = Rect2i()
	var any_change: bool = false
	var budget: int = 2000
	while budget > 0:
		if _watch_cursor >= _watch_cells.size():
			# The pass is over: tiles painted since are new cells, erased ones leave the picture.
			var now: Array[Vector2i] = _tilemap.get_used_cells()
			var present: Dictionary = {}
			for cell in now:
				present[cell] = true
				if not _watch_seen.has(cell):
					_watch_seen[cell] = _tile_signature(cell)
					changed = Rect2i(cell, Vector2i.ONE) if not any_change else changed.expand(cell)
					any_change = true
			for cell in _watch_seen.keys():
				if not present.has(cell):
					_watch_seen.erase(cell)
					changed = Rect2i(cell, Vector2i.ONE) if not any_change else changed.expand(cell)
					any_change = true
			_watch_cells = now
			_watch_cursor = 0
			break
		var cell: Vector2i = _watch_cells[_watch_cursor]
		_watch_cursor += 1
		budget -= 1
		var signature: Vector4i = _tile_signature(cell)
		if _watch_seen.get(cell, Vector4i(-2, 0, 0, 0)) != signature:
			_watch_seen[cell] = signature
			changed = Rect2i(cell, Vector2i.ONE) if not any_change else changed.expand(cell)
			any_change = true
	if any_change:
		# expand() leaves the far corner out of the box, so the box grows by one cell.
		changed.size += Vector2i.ONE
		_regenerate_cells(changed)

## Whether a box (a tile-sized patch of ground) touches a hazard, grown by `margin` pixels. A
## hazard narrower than a tile is still found, which a test at the tile's centre alone would miss.
## @ace_hidden
func _hazard_touches(hazard: NavHazard, box: Rect2, margin: float) -> bool:
	if hazard.kind == "circle" or hazard.kind == "tracked":
		var center: Vector2 = hazard.center
		if hazard.kind == "tracked":
			var followed: Variant = hazard.node
			if not is_instance_valid(followed) or not (followed is Node2D):
				return false
			center = (followed as Node2D).global_position
		var nearest: Vector2 = Vector2(clampf(center.x, box.position.x, box.end.x), clampf(center.y, box.position.y, box.end.y))
		return nearest.distance_to(center) < hazard.radius + margin
	return hazard.rect.grow(margin).intersects(box)

## Hazard verdict for one link: 0 = clear, 1 = danger, 2 = deadly. Each end is judged as the whole
## tile-sized patch of ground it stands on (so a hazard narrower than a tile is never missed); the
## middle of a jump or fall arc, which is in the air, is judged as the point it passes through.
## Hazard Margin grows every hazard into a danger buffer.
## @ace_hidden
func _segment_hazard(from_cell: Vector2i, to_cell: Vector2i) -> int:
	if _hazards.is_empty():
		return 0
	var verdict: int = 0
	var tile: float = _tile_px()
	var reach: Vector2 = Vector2(tile, tile) * 0.5
	var from_world: Vector2 = _cell_world(from_cell)
	var to_world: Vector2 = _cell_world(to_cell)
	for sample in [from_world, to_world]:
		var box: Rect2 = Rect2(sample - reach, reach * 2.0)
		for hazard in _hazards:
			if _hazard_touches(hazard, box, 0.0):
				if hazard.deadly:
					return 2
				verdict = 1
			elif hazard_margin > 0.0 and _hazard_touches(hazard, box, hazard_margin):
				verdict = 1
	var step: Vector2i = to_cell - from_cell
	if absi(step.x) > 1 or absi(step.y) > 1:
		var middle: Vector2 = (from_world + to_world) * 0.5
		for hazard in _hazards:
			if _hazard_hit(hazard, middle, 0.0):
				if hazard.deadly:
					return 2
				verdict = 1
			elif hazard_margin > 0.0 and _hazard_hit(hazard, middle, hazard_margin):
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
			_check_movement_members(child)
			# The planner's frame is straight-down gravity: the graph, jump arcs, and
			# steering all reason in screen x/y. A rotated movement frame would make
			# every planned path wrong, so say so LOUDLY once instead of failing quietly.
			var movement_angle: Variant = _movement.get("gravity_angle")
			if movement_angle != null and not is_equal_approx(float(movement_angle), 90.0) and not _gravity_angle_warned:
				_gravity_angle_warned = true
				push_warning("[PlatformerPathfinding] The movement pack's gravity_angle is %.0f - pathfinding plans with straight-down gravity (90) and its paths will be wrong under rotated gravity." % float(movement_angle))
			return _movement
	return null

## Says, once, which of the members this behaviour drives are missing from the movement sibling it
## found. It probed only a jump() and a move_speed to accept it, so a driver of your own that lacks
## the rest would otherwise be ignored without a word.
## @ace_hidden
func _check_movement_members(movement: Node) -> void:
	if _movement_members_checked:
		return
	_movement_members_checked = true
	var missing: PackedStringArray = PackedStringArray()
	for member: String in MOVEMENT_MEMBERS:
		if not (member in movement):
			missing.append(member)
	if not missing.is_empty():
		push_warning("[PlatformerPathfinding] The movement sibling %s has no %s - the paths and the driving that need %s will not work." % [
			movement.name, ", ".join(missing), "it" if missing.size() == 1 else "them"])

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
			distance_px = _sibling_move_speed(movement) * (2.0 * rise / fall_pull) * 0.9
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

## The sibling's own run speed, not the slower one a patrol may have set for the walk.
## @ace_hidden
func _sibling_move_speed(movement: Node) -> float:
	if _patrol_base_speed >= 0.0:
		return _patrol_base_speed
	return float(movement.get("move_speed"))

## The run speed the drive moves at (the sibling's when present).
## @ace_hidden
func _run_speed() -> float:
	var movement: Node = _find_movement()
	if movement != null and movement.get("move_speed") != null:
		return _sibling_move_speed(movement)
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

## The registered portal with this id, or null.
## @ace_hidden
func _portal_by_id(portal_id: int) -> NavPortal:
	for portal in _portals:
		if portal.id == portal_id:
			return portal
	return null

## The next portal id: one counter per shared map, so two agents on a map tag never hand out the same id.
## @ace_hidden
func _take_portal_id() -> int:
	var shared: NavSharedMap = _shared_maps.get(map_tag, null) as NavSharedMap if map_tag != "" else null
	if shared != null:
		shared.next_portal_id += 1
		return shared.next_portal_id - 1
	_next_portal_id += 1
	return _next_portal_id - 1

## The next hazard id, counted the same way.
## @ace_hidden
func _take_hazard_id() -> int:
	var shared: NavSharedMap = _shared_maps.get(map_tag, null) as NavSharedMap if map_tag != "" else null
	if shared != null:
		shared.next_hazard_id += 1
		return shared.next_hazard_id - 1
	_next_hazard_id += 1
	return _next_hazard_id - 1

## Registers a portal and links it into the built graph; returns its id.
## @ace_hidden
func _add_portal_record(from: Vector2, to: Vector2, both: bool, portal_kind: String, cost: float, speed: float, tag: String) -> int:
	var portal: NavPortal = NavPortal.new()
	portal.id = _take_portal_id()
	portal.from = from
	portal.to = to
	portal.both = both
	portal.type = portal_kind
	portal.cost = cost
	portal.speed = speed
	portal.tag = tag
	_portals.append(portal)
	_last_portal_id = portal.id
	if not _nodes.is_empty():
		_apply_portal(portal)
		_refresh_graph_overlay()
	return _last_portal_id

## Injects one portal into the built graph as a link between the standable nodes nearest its
## endpoints: "portal" (instant, base cost 2) or "portal_gradual" (cost from its travel time
## measured in walking cells). The portal's Cost scales either.
## @ace_hidden
func _apply_portal(portal: NavPortal) -> void:
	# A graph still being built gets its portals when it is done (Finish Build applies every one).
	if _graph_building():
		return
	portal.linked_from = portal.from
	portal.linked_to = portal.to
	var from_node: Vector2i = _nearest_node(portal.from, 2)
	var to_node: Vector2i = _nearest_node(portal.to, 2)
	if from_node == Vector2i.MAX or to_node == Vector2i.MAX:
		return
	var scale: float = maxf(portal.cost, 0.01)
	var kind: String = "portal"
	var cost: float = 2.0 * scale
	if portal.type == "gradual":
		kind = "portal_gradual"
		var seconds: float = portal.from.distance_to(portal.to) / maxf(portal.speed, 1.0)
		cost = maxf(seconds * _run_speed() / _tile_px(), 0.5) * scale
	_add_edge(from_node, to_node, kind, cost).portal_id = portal.id
	if portal.both:
		_add_edge(to_node, from_node, kind, cost).portal_id = portal.id

## Removes every link a portal put into the graph.
## @ace_hidden
func _unlink_portal(portal_id: int) -> void:
	for cell in _edges:
		var kept: Array[NavEdge] = []
		for edge: NavEdge in (_edges[cell] as Array):
			if edge.portal_id != portal_id:
				kept.append(edge)
		_edges[cell] = kept

## Re-links one portal after its position, cost or speed changed.
## @ace_hidden
func _relink_portal(portal: NavPortal) -> void:
	_unlink_portal(portal.id)
	if not _nodes.is_empty():
		_apply_portal(portal)
	_refresh_graph_overlay()

## Whether a tag matches a portal's comma-separated tags (an empty tag matches every portal).
## @ace_hidden
func _portal_has_tag(portal: NavPortal, tag: String) -> bool:
	if tag == "":
		return true
	for token in portal.tag.split(","):
		if token.strip_edges() == tag:
			return true
	return false

## Adds a stop to an elevator group: a two-way gradual portal to every stop already in it.
## @ace_hidden
func _add_elevator_stop(group: String, at: Vector2, node: Node2D, speed: float, tag: String) -> void:
	var stop: NavStop = NavStop.new()
	stop.at = at
	stop.node = node
	var stops: Array = _elevator_stops.get(group, [])
	for other: NavStop in stops:
		var portal_id: int = _add_portal_record(other.at, at, true, "gradual", 1.0, speed, tag)
		var portal: NavPortal = _portal_by_id(portal_id)
		portal.from_node = other.node
		portal.from_follows = other.node != null
		portal.to_node = node
		portal.to_follows = node != null
	stops.append(stop)
	_elevator_stops[group] = stops
	if node != null:
		set_physics_process(true)

## True when any portal has an end that follows a node (the agent keeps ticking to follow it).
## @ace_hidden
func _has_followed_portals() -> bool:
	for portal in _portals:
		if portal.from_follows or portal.to_follows:
			return true
	return false

## Moves the ends of portals whose nodes moved, re-links the ones that crossed into another
## node's reach, and removes the portals whose node was freed.
## @ace_hidden
func _follow_portal_nodes() -> void:
	var relink_gap: float = _tile_px() * 0.5
	for index in range(_portals.size() - 1, -1, -1):
		var portal: NavPortal = _portals[index]
		if not portal.from_follows and not portal.to_follows:
			continue
		if (portal.from_follows and not is_instance_valid(portal.from_node)) or (portal.to_follows and not is_instance_valid(portal.to_node)):
			remove_portal(portal.id)
			continue
		if portal.from_follows:
			portal.from = _world_transform_of(portal.from_node).origin
		if portal.to_follows:
			portal.to = _world_transform_of(portal.to_node).origin
		if portal.from.distance_to(portal.linked_from) > relink_gap or portal.to.distance_to(portal.linked_to) > relink_gap:
			_relink_portal(portal)

## Injects one moving platform as a slow bidirectional "platform" link between the
## standable nodes nearest its two travel endpoints.
## @ace_hidden
func _apply_moving_platform(ride: NavRide) -> void:
	if _graph_building():
		return
	var from_node: Vector2i = _nearest_node(ride.a, 3)
	var to_node: Vector2i = _nearest_node(ride.b, 3)
	if from_node == Vector2i.MAX or to_node == Vector2i.MAX:
		return
	var span: float = ride.a.distance_to(ride.b) / _tile_px()
	_add_edge(from_node, to_node, "platform", span * 1.3)
	_add_edge(to_node, from_node, "platform", span * 1.3)

## The registered platform serving this waypoint (one of its endpoints is near it).
## @ace_hidden
func _platform_for_waypoint(target: Vector2) -> NavRide:
	for ride in _moving_platforms:
		if not is_instance_valid(ride.node):
			continue
		if ride.a.distance_to(target) < 96.0 or ride.b.distance_to(target) < 96.0:
			return ride
	return null

## Steering for a platform leg: wait BESIDE the track (a descending platform must land on
## empty space), board when it arrives at the near side, stand centered while it travels,
## and walk off once it reaches the far side. Waiting and riding legitimately stall
## progress, so the stuck watchdog is held off for the leg.
## @ace_hidden
func _platform_move_axis(target: Vector2, default_axis: float) -> float:
	var ride: NavRide = _platform_for_waypoint(target)
	if ride == null:
		return default_axis
	_stuck_clock = 0.0
	_best_waypoint_distance = INF
	var platform: Node2D = ride.node
	var plat: Vector2 = platform.global_position
	var dest_side: Vector2 = ride.a if ride.a.distance_to(target) <= ride.b.distance_to(target) else ride.b
	var board_side: Vector2 = ride.b if dest_side == ride.a else ride.a
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
	var ride: NavRide = _platform_for_waypoint(leg_target)
	if ride == null:
		return default_axis
	var plat: Vector2 = ride.node.global_position
	var dest_side: Vector2 = ride.a if ride.a.distance_to(leg_target) <= ride.b.distance_to(leg_target) else ride.b
	var board_side: Vector2 = ride.b if dest_side == ride.a else ride.a
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
		if not is_instance_valid(ride.node):
			continue
		var plat: Vector2 = ride.node.global_position
		if absf(host.global_position.x - plat.x) >= 40.0 or host.global_position.y > plat.y or plat.y - host.global_position.y >= 48.0:
			continue
		if plat.distance_to(ride.a) > 12.0 and plat.distance_to(ride.b) > 12.0:
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
		var side: NavSideRequest = _side_request
		_finish_path()
		path_complete.emit()
		if side != null:
			_side_request = null
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
	# A route asked for while a gradual portal carries the host waits for the portal to finish.
	if _portal_traversing:
		_held_goal = Vector2(x, y)
		_held_mode = mode
		_held = true
		return
	# A new route replaces the wait of a portal held with Pause At Portal.
	_portal_paused = false
	# A graph still being built has no routes to search yet: the request waits (Is Path Pending)
	# and runs on the first tick after On Nav Graph Built.
	if _graph_building():
		_pending_goal = Vector2(x, y)
		_pending_goal_mode = mode
		_path_pending = true
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
	if _graph_building():
		_pending_goal = Vector2(x, y)
		_pending_goal_mode = mode
		_path_pending = true
		return
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
	_route_serial += 1
	_path_goal = Vector2(x, y)
	_path_goal_cell = cells.back()
	_goal_mode = mode
	_fail_reason = ""
	_path = []
	_path_cost = 0.0
	for index in range(cells.size()):
		var edge: NavEdge = _last_route_edges[index]
		var waypoint: NavWaypoint = NavWaypoint.new()
		waypoint.world = _cell_world(cells[index])
		waypoint.action = "walk" if index == 0 else edge.kind
		waypoint.cell = cells[index]
		if index > 0:
			waypoint.portal_id = edge.portal_id
		if index > 0:
			_path_cost += _edge_cost(cells[index - 1], edge)
		_path.append(waypoint)
	if smooth_paths:
		_smooth_path()
	# A route aimed at an exact spot (patrol ends, beside a node, back from a ledge) lands its
	# last waypoint on that x while the spot is still over the goal node's own ground.
	_exact_arrival = false
	if not is_nan(_exact_final) and absf(_exact_final - _path.back().world.x) <= _tile_px() * 1.5:
		_path.back().world = Vector2(_exact_final, _path.back().world.y)
		_exact_arrival = true
	_path_index = 0
	# A fresh route starts at OUR nearest node - when we already stand on it, aim at the
	# next waypoint instead (a repath mid-stride must never walk the agent backward, or a
	# chaser re-finding on a timer thrashes in place at node boundaries).
	if _path.size() > 1 and host.global_position.distance_to(_path[0].world) <= _tile_px():
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
		var before: NavWaypoint = _path[index - 1]
		var here: NavWaypoint = _path[index]
		var after: NavWaypoint = _path[index + 1]
		var flat: bool = before.cell.y == here.cell.y and here.cell.y == after.cell.y
		if flat and here.action == "walk" and after.action == "walk" and (index > 1 or before.action == "walk"):
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
func _add_edge(from_cell: Vector2i, to_cell: Vector2i, kind: String, cost: float) -> NavEdge:
	if not _edges.has(from_cell):
		var fresh: Array[NavEdge] = []
		_edges[from_cell] = fresh
	var edge: NavEdge = NavEdge.new()
	edge.to = to_cell
	edge.kind = kind
	edge.cost = cost
	(_edges[from_cell] as Array).append(edge)
	return edge

## True when a link already joins these two cells.
## @ace_hidden
func _has_edge(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	for edge: NavEdge in (_edges.get(from_cell, []) as Array):
		if edge.to == to_cell:
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

## The graph split into groups of nodes that can reach one another by any link, biggest first.
## @ace_hidden
func _separate_regions() -> Array:
	var reverse: Dictionary = {}
	for cell in _edges:
		for edge: NavEdge in (_edges[cell] as Array):
			if not reverse.has(edge.to):
				reverse[edge.to] = []
			(reverse[edge.to] as Array).append(cell)
	var seen: Dictionary = {}
	var regions: Array = []
	for start in _nodes:
		if seen.has(start):
			continue
		var group: Array = []
		var frontier: Array = [start]
		seen[start] = true
		while not frontier.is_empty():
			var cell: Vector2i = frontier.pop_back()
			group.append(cell)
			var neighbours: Array = []
			for edge: NavEdge in (_edges.get(cell, []) as Array):
				neighbours.append(edge.to)
			neighbours.append_array(reverse.get(cell, []))
			for next_cell: Vector2i in neighbours:
				if _nodes.has(next_cell) and not seen.has(next_cell):
					seen[next_cell] = true
					frontier.append(next_cell)
		regions.append(group)
	regions.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	return regions

## Every node reachable from `start` by WALK links only - the platform it stands on, slopes
## and stairs included.
## @ace_hidden
func _walk_component(start: Vector2i) -> Dictionary:
	var seen: Dictionary = {start: true}
	var frontier: Array = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for edge: NavEdge in (_edges.get(cell, []) as Array):
			if edge.kind == "walk" and not seen.has(edge.to):
				seen[edge.to] = true
				frontier.append(edge.to)
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
	var edges: Array[NavEdge] = [came_edge.get(current, null)]
	while came_from.has(current):
		current = came_from[current]
		cells.push_front(current)
		edges.push_front(came_edge.get(current, null))
	edges[0] = null
	_last_route_edges = edges
	return cells

## A* over the graph's links under the active strategy, filters and hazards. Returns the cell
## path or []. With allow_partial a cut-off goal yields the route to the closest node reached.
## @ace_hidden
func _astar(start: Vector2i, goal: Vector2i, allow_partial: bool = false) -> Array:
	_last_route_edges = []
	_last_search_fail = ""
	var avoid: Dictionary = _agent_avoidance_costs() if multi_agent_avoidance else {}
	# The open set is a binary heap of [estimate, order, cell], so taking the best node costs a few
	# comparisons instead of a walk over every open node. `order` is when the cell JOINED the open set,
	# which settles a tie the way a front-to-back scan did (the cell that has waited longest goes
	# first), so the routes are the ones a scan would have chosen. A cell whose cost improves while it
	# waits is pushed again with its better estimate and the same order; the older entry is skipped
	# when it surfaces, because it no longer matches what the cell costs.
	var open_heap: Array = [[Vector2(goal - start).length(), 0, start]]
	var open_order: Dictionary = {start: 0}
	var next_order: int = 1
	var came_from: Dictionary = {}
	var came_edge: Dictionary = {}
	var cost_so_far: Dictionary = {start: 0.0}
	var closest: Vector2i = start
	var closest_gap: float = Vector2(goal - start).length()
	var expanded: int = 0
	while not open_order.is_empty():
		if expanded >= maxi(max_search_nodes, 1):
			_last_search_fail = "max_nodes_reached"
			break
		var current: Vector2i = start
		while true:
			var top: Array = _heap_pop(open_heap)
			var top_cell: Vector2i = top[2]
			if int(open_order.get(top_cell, -1)) != int(top[1]):
				continue
			if float(top[0]) != float(cost_so_far[top_cell]) + Vector2(goal - top_cell).length():
				continue
			current = top_cell
			open_order.erase(top_cell)
			break
		expanded += 1
		var gap: float = Vector2(goal - current).length()
		if gap < closest_gap:
			closest_gap = gap
			closest = current
		if current == goal:
			return _reconstruct(current, came_from, came_edge)
		for edge: NavEdge in (_edges.get(current, []) as Array):
			if not _edge_allowed(current, edge):
				continue
			var next_cell: Vector2i = edge.to
			# Danger (non-deadly) hazards stay traversable but cost Danger Cost Multiplier -
			# taken only when no clean route exists.
			var danger: bool = not _ignores_hazards(edge) and _segment_hazard(current, next_cell) == 1
			var next_cost: float = cost_so_far[current] + _edge_cost(current, edge) * (danger_cost_multiplier if danger else 1.0) + float(avoid.get(next_cell, 0.0))
			if not cost_so_far.has(next_cell) or next_cost < float(cost_so_far[next_cell]):
				cost_so_far[next_cell] = next_cost
				came_from[next_cell] = current
				came_edge[next_cell] = edge
				if not open_order.has(next_cell):
					open_order[next_cell] = next_order
					next_order += 1
				_heap_push(open_heap, [float(next_cost) + Vector2(goal - next_cell).length(), int(open_order[next_cell]), next_cell])
	if _last_search_fail == "":
		_last_search_fail = "no_path"
	if allow_partial:
		return _reconstruct(closest, came_from, came_edge)
	return []

## Puts an entry on a binary min-heap kept in an Array: [estimate, order, cell], smallest estimate
## first and the lower order first among equal estimates.
## @ace_hidden
func _heap_push(heap: Array, entry: Array) -> void:
	heap.append(entry)
	var child: int = heap.size() - 1
	while child > 0:
		var parent: int = (child - 1) >> 1
		if not _heap_before(heap[child], heap[parent]):
			break
		var held: Array = heap[parent]
		heap[parent] = heap[child]
		heap[child] = held
		child = parent

## Takes the first entry off the heap and puts the heap back in order.
## @ace_hidden
func _heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var parent: int = 0
		var size: int = heap.size()
		while true:
			var left: int = parent * 2 + 1
			if left >= size:
				break
			var pick: int = left
			if left + 1 < size and _heap_before(heap[left + 1], heap[left]):
				pick = left + 1
			if not _heap_before(heap[pick], heap[parent]):
				break
			var held: Array = heap[parent]
			heap[parent] = heap[pick]
			heap[pick] = held
			parent = pick
	return top

## Whether heap entry `a` comes out before `b`.
## @ace_hidden
func _heap_before(a: Array, b: Array) -> bool:
	if float(a[0]) != float(b[0]):
		return float(a[0]) < float(b[0])
	return int(a[1]) < int(b[1])

## Whether a link is a portal set to ignore hazards.
## @ace_hidden
func _ignores_hazards(edge: NavEdge) -> bool:
	if edge.portal_id < 0:
		return false
	var portal: NavPortal = _portal_by_id(edge.portal_id)
	return portal != null and portal.ignore_hazards

## A link's cost under the active Path Strategy. Walking, portals and platforms keep their own
## cost; airborne links are re-priced: shortest = raw distance plus a landing fee per jump,
## safest = long leaps and deep drops cost more the bigger they are, ground_hugging = every
## jump and fall carries a heavy fee so walking wins whenever it can.
## @ace_hidden
func _edge_cost(from_cell: Vector2i, edge: NavEdge) -> float:
	var base: float = edge.cost
	var kind: String = edge.kind
	var is_jump: bool = kind == "jump" or kind == "double_jump" or kind == "coyote_jump"
	var is_fall: bool = kind == "fall" or kind == "fall_through"
	if not is_jump and not is_fall:
		return base
	var span: float = Vector2(edge.to - from_cell).length()
	var drop: float = maxf(float(edge.to.y - from_cell.y), 0.0)
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
func _edge_allowed(from_cell: Vector2i, edge: NavEdge) -> bool:
	if not _ignores_hazards(edge) and _segment_hazard(from_cell, edge.to) == 2:
		return false
	var kind: String = edge.kind
	if _platform_patrolling() and kind != "walk":
		return false
	var drop: float = float(edge.to.y - from_cell.y) * _tile_px()
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
	for edge: NavEdge in (_edges.get(from_cell, []) as Array):
		if edge.to == to_cell:
			return edge.kind
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
func _other_agents() -> Array[PlatformerPathfinding]:
	var others: Array[PlatformerPathfinding] = []
	for agent_id in _agent_ids.keys():
		if agent_id == get_instance_id():
			continue
		if not is_instance_id_valid(agent_id):
			_agent_ids.erase(agent_id)
			continue
		var agent: PlatformerPathfinding = instance_from_id(agent_id) as PlatformerPathfinding
		if agent == null or not agent.is_inside_tree():
			continue
		if agent._tilemap != _tilemap or agent.map_tag != map_tag:
			continue
		if agent.host == null:
			continue
		others.append(agent)
	return others

## Multi-agent avoidance: extra cost on the cells other agents stand on or are about to walk.
## @ace_hidden
func _agent_avoidance_costs() -> Dictionary:
	var costs: Dictionary = {}
	for agent in _other_agents():
		var at: Vector2i = _nearest_node(agent.host.global_position, 1)
		if at != Vector2i.MAX:
			costs[at] = float(costs.get(at, 0.0)) + 3.0
		var their_path: Array = agent._path
		var their_index: int = agent._path_index
		for index in range(their_index, mini(their_index + 4, their_path.size())):
			var cell: Vector2i = their_path[index].cell
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
	var owner_agent: PlatformerPathfinding = instance_from_id(owner_id) as PlatformerPathfinding if is_instance_id_valid(owner_id) else null
	if owner_agent == null or owner_agent._claimed_key != key:
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
				for edge: NavEdge in (_edges.get(cell, []) as Array):
					if edge.kind != "walk" or seen.has(edge.to):
						continue
					seen[edge.to] = true
					if not _claimed_by_other(edge.to):
						chosen = edge.to
						found = true
						break
					next_frontier.append(edge.to)
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
		var other: Node2D = agent.host
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
	# A marker the route could only get near does not count as reached: try again shortly.
	if not _patrol_markers.is_empty() and not _at_patrol_marker():
		_patrol_marker_fails += 1
		if _patrol_marker_fails >= 2 * _patrol_markers.size():
			push_warning("[PlatformerPathfinding] Start Patrol Between Markers stopped: none of the markers can be reached.")
			_end_patrol()
			return
		if _patrol_marker_fails % 2 == 0:
			_advance_patrol_marker()
		_patrol_retry = true
		_patrol_dwelling = true
		_patrol_clock = 0.5
		_wake()
		return
	_patrol_marker_fails = 0
	patrol_end_reached.emit()
	if not _patrolling:
		return
	var wait: float = _roll_patrol_dwell()
	if wait > 0.0:
		_patrol_dwelling = true
		_patrol_clock = wait
		patrol_dwell_started.emit()
		_wake()
		return
	_patrol_turn()
	_patrol_walk()

## The wait at an end is over: turn (or step to the next marker), tell the sheet, walk on.
## @ace_hidden
func _finish_patrol_dwell() -> void:
	_patrol_dwelling = false
	if _patrol_retry:
		_patrol_retry = false
		_patrol_walk()
		return
	_patrol_turn()
	patrol_dwell_finished.emit()
	if _patrolling:
		_patrol_walk()

## Turns the patrol around, or on to the next marker.
## @ace_hidden
func _patrol_turn() -> void:
	if _patrol_markers.is_empty():
		_patrol_dir = -_patrol_dir
	else:
		_advance_patrol_marker()

## Steps the patrol on to the next marker: round the loop, or up and down the list.
## @ace_hidden
func _advance_patrol_marker() -> void:
	var count: int = _patrol_markers.size()
	if count <= 1:
		return
	if _patrol_loop:
		_patrol_marker_index = (_patrol_marker_index + 1) % count
		return
	if _patrol_marker_index + _patrol_marker_step < 0 or _patrol_marker_index + _patrol_marker_step >= count:
		_patrol_marker_step = -_patrol_marker_step
	_patrol_marker_index += _patrol_marker_step

## True when the host stands near the marker the patrol is heading for.
## @ace_hidden
func _at_patrol_marker() -> bool:
	if host == null or _patrol_marker_index < 0 or _patrol_marker_index >= _patrol_markers.size():
		return false
	var marker: Node2D = _patrol_markers[_patrol_marker_index]
	if not is_instance_valid(marker):
		return false
	var gap: Vector2 = marker.global_position - host.global_position
	return absf(gap.x) <= _tile_px() * 1.5 and absf(gap.y) <= _tile_px() * 3.0

## The wait at an end: the setting, plus or minus the variation.
## @ace_hidden
func _roll_patrol_dwell() -> float:
	if _patrol_dwell_variation <= 0.0:
		return _patrol_dwell
	return maxf(_patrol_dwell + randf_range(-_patrol_dwell_variation, _patrol_dwell_variation), 0.0)

## Routes to the patrol end (or marker) the agent is heading for.
## @ace_hidden
func _patrol_walk() -> void:
	if not _patrol_markers.is_empty():
		_patrol_walk_to_marker()
		return
	var end: Vector2 = _patrol_ends[1] if _patrol_dir > 0 else _patrol_ends[0]
	_exact_final = end.x
	_route(end.x, end.y, "nearest")

## Routes to the current marker; a marker with no route is skipped (after two misses in a row the patrol stops).
## @ace_hidden
func _patrol_walk_to_marker() -> void:
	for attempt in range(_patrol_markers.size() * 2 + 1):
		# Freed markers drop out of the list, the index staying on the same marker.
		var target: Node2D = _patrol_markers[_patrol_marker_index] if _patrol_marker_index < _patrol_markers.size() else null
		var live: Array[Node2D] = []
		for marker in _patrol_markers:
			if is_instance_valid(marker):
				live.append(marker)
		if live.is_empty():
			_end_patrol()
			return
		_patrol_marker_index = maxi(live.find(target), mini(_patrol_marker_index, live.size() - 1))
		_patrol_markers = live
		var at: Vector2 = live[_patrol_marker_index].global_position
		_exact_final = NAN
		_route(at.x, at.y, "nearest")
		if _path_pending or not _path.is_empty():
			return
		_patrol_marker_fails += 1
		if _patrol_marker_fails >= 2 * live.size():
			push_warning("[PlatformerPathfinding] Start Patrol Between Markers stopped: none of the markers can be reached.")
			_end_patrol()
			return
		_advance_patrol_marker()

## @ace_hidden
func _end_patrol() -> void:
	_patrolling = false
	_patrol_dwelling = false
	_patrol_retry = false
	_patrol_dir = 0
	_patrol_markers.clear()
	_patrol_marker_index = -1
	_patrol_marker_fails = 0
	_restore_patrol_speed()

## Finds the two ends of the platform the host stands on (ledges and walls, slopes and stairs
## included), pulled in by the patrol's edge distance; false when the host stands on no node.
## @ace_hidden
func _measure_patrol_ends() -> bool:
	var here: Vector2i = _nearest_node(host.global_position, 3)
	if here == Vector2i.MAX:
		return false
	var left: Vector2i = here
	var right: Vector2i = here
	for cell in _walk_component(here):
		if cell.x < left.x or (cell.x == left.x and absi(cell.y - here.y) < absi(left.y - here.y)):
			left = cell
		if cell.x > right.x or (cell.x == right.x and absi(cell.y - here.y) < absi(right.y - here.y)):
			right = cell
	var inset: float = minf(maxf(_patrol_edge, 0.0), absf(_cell_world(right).x - _cell_world(left).x) * 0.5)
	_patrol_ends = [_cell_world(left) + Vector2(inset, 0.0), _cell_world(right) - Vector2(inset, 0.0)]
	return true

## Starts a patrol over a list of markers, beginning at the one nearest the host.
## @ace_hidden
func _begin_marker_patrol(markers: Array[Node2D], loop: bool, dwell: float) -> void:
	_patrol_markers = markers
	_patrol_loop = loop
	_patrol_dwell = maxf(dwell, 0.0)
	_patrol_marker_fails = 0
	_patrol_marker_index = 0
	var best: float = INF
	for index in range(markers.size()):
		var gap: float = host.global_position.distance_to(markers[index].global_position)
		if gap < best:
			best = gap
			_patrol_marker_index = index
	# A ping-pong patrol heads for the end of the list that has more markers left.
	var last: int = markers.size() - 1
	_patrol_marker_step = -1 if (not loop and _patrol_marker_index > 0 and _patrol_marker_index >= last - _patrol_marker_index) else 1
	_patrolling = true
	_patrol_dwelling = false
	_patrol_dir = 0
	_patrol_walk()

## Starts a route (Find Path To and friends): a running patrol is remembered, so Resume After can bring it back.
## @ace_hidden
func _cancel_patrol_for_route() -> void:
	if _patrolling and _patrol_resume_after > 0.0:
		if _patrol_markers.is_empty():
			_patrol_memory_kind = "platform"
		else:
			_patrol_memory_kind = "markers"
			_patrol_memory_group = _patrol_group
			_patrol_memory_loop = _patrol_loop
		_patrol_resume_clock = 0.0
	_end_patrol()

## Resume After: once the route that cancelled a patrol is over and the host has stood idle for the set
## time, the patrol starts again (a platform patrol on the platform it is on now, a marker one from the
## nearest marker).
## @ace_hidden
func _resume_patrol_tick(delta: float) -> void:
	if _patrol_memory_kind == "":
		return
	if _patrol_resume_after <= 0.0:
		_patrol_memory_kind = ""
		return
	if not _path.is_empty() or _path_pending or _jump_toward_active or _portal_traversing or _portal_paused:
		_patrol_resume_clock = 0.0
		return
	_patrol_resume_clock += delta
	if _patrol_resume_clock < _patrol_resume_after:
		return
	var kind: String = _patrol_memory_kind
	var group: String = _patrol_memory_group
	var loop: bool = _patrol_memory_loop
	_patrol_memory_kind = ""
	if kind == "platform":
		start_patrol(_patrol_dwell, _patrol_edge)
	elif kind == "markers":
		start_patrol_between_markers(group, PATROL_ORDER_LOOP if loop else PATROL_ORDER_PING_PONG, _patrol_dwell)

## True while a plain platform patrol (not a marker route) is running.
## @ace_hidden
func _platform_patrolling() -> bool:
	return _patrolling and _patrol_markers.is_empty()

## Slows the movement sibling to the patrol speed while a patrol walks, and puts the run speed back for
## everything else (chases, jumps, a parked patrol).
## @ace_hidden
func _apply_patrol_speed() -> void:
	var walking: bool = _patrolling and not _patrol_dwelling and not _path.is_empty() and _path_index < _path.size() and _path[_path_index].action == "walk"
	if walking and _patrol_speed_percent != 100.0:
		var movement: Node = _find_movement()
		if movement == null:
			return
		if _patrol_base_speed < 0.0:
			_patrol_base_speed = float(movement.get("move_speed"))
		movement.set("move_speed", _patrol_base_speed * _patrol_speed_percent / 100.0)
	else:
		_restore_patrol_speed()

## Gives the movement sibling its own run speed back.
## @ace_hidden
func _restore_patrol_speed() -> void:
	if _patrol_base_speed < 0.0:
		return
	var movement: Node = _find_movement()
	if movement != null:
		movement.set("move_speed", _patrol_base_speed)
	_patrol_base_speed = -1.0

## How hazardous the ground of one cell is: 0 clear, 1 danger, 2 deadly.
## @ace_hidden
func _cell_hazard_level(cell: Vector2i) -> int:
	return _segment_hazard(cell, cell)

## True when stepping one cell in a direction means standing somewhere more hazardous than here.
## @ace_hidden
func _patrol_danger_ahead(direction: int) -> bool:
	if _hazards.is_empty():
		return false
	var here: Vector2i = _nearest_node(host.global_position, 1)
	if here == Vector2i.MAX:
		return false
	return _cell_hazard_level(here + Vector2i(direction, 0)) > _cell_hazard_level(here)

## True when another agent stands close ahead of the host, in a direction.
## @ace_hidden
func _patrol_blocked_by_agent(direction: int) -> bool:
	var tile: float = _tile_px()
	for agent in _other_agents():
		var gap: Vector2 = agent.host.global_position - host.global_position
		if signi(int(gap.x)) == direction and absf(gap.x) <= tile * 1.2 and absf(gap.y) <= tile * 1.5:
			return true
	return false

## Checks the way ahead of a walking platform patrol: danger or another agent ends the leg like a ledge does.
## @ace_hidden
func _check_patrol_way(delta: float) -> bool:
	_patrol_bump_clock = maxf(_patrol_bump_clock - delta, 0.0)
	if not _platform_patrolling() or _patrol_dwelling or _path.is_empty() or _path_index >= _path.size():
		return false
	var heading: int = signi(int(_path[_path_index].world.x - host.global_position.x))
	if heading == 0:
		return false
	var danger: bool = _patrol_turn_before_danger and _patrol_danger_ahead(heading)
	if danger and _patrol_danger_ahead(-heading):
		# Danger on both sides: stand still rather than step into it.
		_hold_still(delta)
		return true
	var bumped: bool = not danger and _patrol_turn_at_agents and _patrol_bump_clock <= 0.0 and _patrol_blocked_by_agent(heading)
	if not danger and not bumped:
		return false
	if bumped:
		_patrol_bump_clock = 0.75
	_finish_path()
	_on_patrol_end()
	return true

## Side-of-node arrival: the agent stands on the requested side at the requested distance.
## @ace_hidden
func _check_side_reached(side: NavSideRequest) -> void:
	if host == null or not is_instance_valid(side.node):
		return
	var spot: Vector2 = side.spot
	if absf(host.global_position.x - spot.x) <= _tile_px() and absf(host.global_position.y - spot.y) <= _tile_px() * 2.0:
		_reached_side = side.side
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
func _enter_portal(waypoint: NavWaypoint) -> void:
	_current_portal = _portal_by_id(waypoint.portal_id)
	_current_portal_exit = _portal_exit_for(waypoint)
	_portal_paused = false
	_portal_entering = true
	var serial: int = _route_serial
	portal_entered.emit()
	_portal_entering = false
	# A handler may have paused the portal, or asked for another route (which replaces this trip).
	if _portal_paused or _path.is_empty() or serial != _route_serial:
		return
	_run_portal(waypoint)

## Where a portal puts the host: the end of the portal the waypoint's node sits beside, exactly as the
## sheet gave it (the nearest node's centre is only where the route's last step is aimed).
## @ace_hidden
func _portal_exit_for(waypoint: NavWaypoint) -> Vector2:
	var portal: NavPortal = _portal_by_id(waypoint.portal_id)
	if portal == null:
		return waypoint.world
	if waypoint.world.distance_to(portal.to) <= waypoint.world.distance_to(portal.from):
		return portal.to
	return portal.from

## Instant: blink to the exit. Gradual: start the straight-line move at the portal's speed with
## the movement sibling paused.
## @ace_hidden
func _run_portal(waypoint: NavWaypoint) -> void:
	if waypoint.action == "portal_gradual":
		_portal_traversing = true
		_portal_from = host.global_position
		_portal_to = _portal_exit_for(waypoint)
		_portal_progress = 0.0
		host.velocity = Vector2.ZERO
		_set_movement_processing(false)
		return
	host.global_position = _portal_exit_for(waypoint)
	host.velocity = Vector2.ZERO
	_finish_portal()

## One tick of a gradual portal move.
## @ace_hidden
func _step_gradual_portal(delta: float) -> void:
	var speed: float = maxf(_current_portal.speed if _current_portal != null else 100.0, 1.0)
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
	var held: bool = _held
	var held_goal: Vector2 = _held_goal
	var held_mode: String = _held_mode
	_held = false
	if not _path.is_empty():
		_advance_waypoint()
	if held:
		_route(held_goal.x, held_goal.y, held_mode)

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
		_debug_line.add_point(_path[index].world)

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
		for edge: NavEdge in (_edges[cell] as Array):
			_debug_graph.draw_line(from, _cell_world(edge.to), _kind_color(edge.kind), 1.5)
	for cell in _nodes:
		_debug_graph.draw_circle(_cell_world(cell), 2.5, Color(1.0, 1.0, 1.0, 0.9))
## Rescans the cells of a rectangle from the tile map, scanned bodies and hand-set states, then
## rebuilds only the links that can reach them (a jump or fall away). The rest of the graph, the
## portals and the routes of agents elsewhere stay as they are; agents whose route runs through
## the changed area plan again. The rebuilt links equal what a full Regenerate Nav Graph makes.
## @ace_hidden
func _regenerate_cells(region: Rect2i) -> void:
	for column in range(region.position.x, region.end.x):
		for row in range(region.position.y, region.end.y):
			var cell: Vector2i = Vector2i(column, row)
			var state: String = _live_state(cell)
			if state == "clear":
				_states.erase(cell)
				_blocking.erase(cell)
				_blocking_down.erase(cell)
				continue
			_states[cell] = state
			_blocking_down[cell] = true
			if _blocks_state(state):
				_blocking[cell] = true
			else:
				_blocking.erase(cell)
	# A cell changes the standing nodes of its own row and the rows just above and below it.
	var nodes_area: Rect2i = region.grow(1)
	for column in range(nodes_area.position.x, nodes_area.end.x):
		for row in range(nodes_area.position.y, nodes_area.end.y):
			var stand: Vector2i = Vector2i(column, row)
			if _states.has(stand + Vector2i(0, 1)) and not _blocking.has(stand) and not _blocking.has(stand + Vector2i(0, -1)):
				_nodes[stand] = true
			else:
				_nodes.erase(stand)
				_edges.erase(stand)
	# Every node close enough to jump or fall into the area gets its links made again.
	var reach: Vector2i = _jump_reach_cells()
	var tile: float = _tile_px()
	var across: int = reach.x + 1
	if _double_jump_ready():
		across = maxi(across, int(_jump_reach_px().x * 1.7 / tile) + 1)
	if _coyote_window() > 0.0 and not ledge_restriction:
		across = maxi(across, int((_jump_reach_px().x + _run_speed() * _coyote_window() * 0.5) / tile) + 1)
	var down: int = _fall_cells()
	var up: int = reach.y + 1
	if _double_jump_ready():
		up = maxi(up, int(_jump_reach_px().y * 2.0 / tile) + 1)
	var scope_area: Rect2i = Rect2i(nodes_area.position - Vector2i(across, down + 1), nodes_area.size + Vector2i(across * 2, down + up + 2))
	var scope: Array = []
	var kept_scope: Dictionary = {}
	if scope_area.get_area() <= _nodes.size() * 4:
		for column in range(scope_area.position.x, scope_area.end.x):
			for row in range(scope_area.position.y, scope_area.end.y):
				if _nodes.has(Vector2i(column, row)):
					scope.append(Vector2i(column, row))
	else:
		for cell in _nodes:
			if scope_area.has_point(cell):
				scope.append(cell)
	for cell: Vector2i in scope:
		kept_scope[cell] = true
		# Portal and moving-platform links stay (while their far end is still a node).
		var kept: Array[NavEdge] = []
		for edge: NavEdge in (_edges.get(cell, []) as Array):
			if (edge.portal_id >= 0 or edge.kind == "platform") and _nodes.has(edge.to):
				kept.append(edge)
		_edges[cell] = kept
	_build_links(scope)
	# A portal with an end beside the area may now land on a different node.
	var world_low: Vector2 = _cell_world(nodes_area.position) - Vector2(tile, tile)
	var world_box: Rect2 = Rect2(world_low, _cell_world(nodes_area.end) - world_low + Vector2(tile, tile))
	for portal in _portals:
		if world_box.has_point(portal.from) or world_box.has_point(portal.to):
			_relink_portal(portal)
	_refresh_graph_overlay()
	# Agents whose route runs through the changed area plan it again.
	var agents: Array[PlatformerPathfinding] = _other_agents()
	agents.append(self)
	for agent in agents:
		agent._replan_through(nodes_area)

## Plans the current route again when any of its steps lies in an area of the grid.
## @ace_hidden
func _replan_through(area: Rect2i) -> void:
	if _path.is_empty():
		return
	for index in range(_path_index, _path.size()):
		if area.has_point(_path[index].cell):
			_route(_path_goal.x, _path_goal.y, _goal_mode)
			return

## How many cells deep a fall may go: the Max Fall Distance in cells, or the whole map for no limit.
## @ace_hidden
func _fall_cells() -> int:
	var tile: float = _tile_px()
	var cells: int = maxi(int(ceil(max_fall_distance / tile)), 1)
	if max_fall_distance < 0.0:
		var used: Rect2i = Rect2i()
		for cell in _states:
			used = Rect2i(cell, Vector2i.ONE) if used.size == Vector2i.ZERO else used.expand(cell)
		cells = maxi(used.size.y + 2, 1)
	return cells

## Makes the links that leave the cells of a list: walk links, jump arcs, fall drops, double
## jumps, coyote jumps and fall-throughs. A region rebuild passes the nodes whose reach touches the
## changed area; a whole build goes through the same passes a few cells at a time.
## @ace_hidden
func _build_links(scope: Array) -> void:
	_begin_links()
	for link_pass in range(LINK_PASS_COUNT):
		if not _link_pass_runs(link_pass):
			continue
		for cell: Vector2i in scope:
			_link_cell(link_pass, cell)

## Works out what every link pass reads: the cell size, the jump reach, how deep a fall may go and
## which of the optional passes (double jump, coyote jump) run at all.
## @ace_hidden
func _begin_links() -> void:
	_link_tile = _tile_px()
	_link_reach_px = _jump_reach_px()
	_link_reach = _jump_reach_cells()
	_link_fall = _fall_cells()
	_link_double = _double_jump_ready()
	_link_double_reach = Vector2i(maxi(int(_link_reach_px.x * 1.7 / _link_tile), 1), maxi(int(_link_reach_px.y * 2.0 / _link_tile), 1))
	_link_coyote_cells = 0
	# Run off a ledge for half the coyote window, then leap - the extra run reaches gaps a
	# standing takeoff cannot. Never with Ledge Restriction (it never runs off).
	if _coyote_window() > 0.0 and not ledge_restriction:
		var cells: int = int((_link_reach_px.x + _run_speed() * _coyote_window() * 0.5) / _link_tile)
		if cells > _link_reach.x:
			_link_coyote_cells = cells

## Whether a link pass has anything to do with the settings read by Begin Links.
## @ace_hidden
func _link_pass_runs(link_pass: int) -> bool:
	if link_pass == LINK_PASS_DOUBLE_JUMP:
		return _link_double
	if link_pass == LINK_PASS_COYOTE:
		return _link_coyote_cells > 0
	return true

## Moves a build on to the next link pass that has anything to do.
## @ace_hidden
func _advance_link_pass() -> void:
	_build_cursor = 0
	_build_pass += 1
	while _build_pass < LINK_PASS_COUNT and not _link_pass_runs(_build_pass):
		_build_pass += 1

## Makes the links one pass makes out of one cell.
## @ace_hidden
func _link_cell(link_pass: int, cell: Vector2i) -> void:
	if link_pass == LINK_PASS_WALK:
		# WALK links: neighbours one cell over, up to one step up/down - stairs and slopes
		# included, at plain euclidean cost so ramps beat jumps in the router.
		for dx in [-1, 1]:
			for dy in [-1, 0, 1]:
				var to: Vector2i = cell + Vector2i(dx, dy)
				if _nodes.has(to):
					_add_edge(cell, to, "walk", Vector2(float(dx), float(dy)).length())
	elif link_pass == LINK_PASS_JUMP:
		# JUMP arcs + FALL drops within the derived reach, clearance-checked coarsely. A drop
		# treats a jump-through platform in its way as a floor (it would land there).
		for dx in range(-_link_reach.x, _link_reach.x + 1):
			for dy in range(-_link_reach.y, _link_fall + 1):
				if absi(dx) <= 1 and absi(dy) <= 1:
					continue
				var to: Vector2i = cell + Vector2i(dx, dy)
				if not _nodes.has(to) or not _arc_clear(cell, to, _blocking_down if dy > 0 else _blocking):
					continue
				var kind: String = "fall" if dy > 0 and absi(dx) <= 2 else "jump"
				var span: float = Vector2(float(dx), float(dy)).length()
				_add_edge(cell, to, kind, span * (1.5 if kind == "jump" else 1.1))
	elif link_pass == LINK_PASS_DOUBLE_JUMP:
		# DOUBLE JUMP links: a sibling with two jumps reaches about twice as high and 1.7x as far;
		# only targets the single jump cannot reach get one.
		for dx in range(-_link_double_reach.x, _link_double_reach.x + 1):
			for dy in range(-_link_double_reach.y, _link_fall + 1):
				if absi(dx) <= _link_reach.x and dy >= -_link_reach.y:
					continue
				var to: Vector2i = cell + Vector2i(dx, dy)
				if not _nodes.has(to) or _has_edge(cell, to) or not _arc_clear(cell, to, _blocking_down if dy > 0 else _blocking):
					continue
				_add_edge(cell, to, "double_jump", Vector2(float(dx), float(dy)).length() * 1.8)
	elif link_pass == LINK_PASS_COYOTE:
		# COYOTE JUMP links: only from a ledge, only in the direction of its drop.
		for direction in [-1, 1]:
			if not _is_ledge_toward(cell, direction):
				continue
			for distance in range(_link_reach.x + 1, _link_coyote_cells + 1):
				for dy in range(-(_link_reach.y - 1), _link_fall + 1):
					var to: Vector2i = cell + Vector2i(direction * distance, dy)
					if not _nodes.has(to) or _has_edge(cell, to) or not _arc_clear(cell, to, _blocking_down if dy > 0 else _blocking):
						continue
					_add_edge(cell, to, "coyote_jump", Vector2(float(distance), float(dy)).length() * 1.6)
	else:
		# FALL-THROUGH drops: standing on a jump-through platform, drop straight down to the first
		# node below it.
		if str(_states.get(cell + Vector2i(0, 1), "")) != "jump_thru":
			return
		for depth in range(1, _link_fall + 2):
			var below: Vector2i = cell + Vector2i(0, depth)
			if _blocking.has(below):
				break
			if _nodes.has(below) and depth > 1:
				_add_edge(cell, below, "fall_through", float(depth) * 1.1)
				break

## True when a build step has used up its share of the frame (a zero deadline means no limit).
## @ace_hidden
func _build_timeup(deadline: int) -> bool:
	return deadline > 0 and Time.get_ticks_usec() >= deadline

## Starts reading one build step: which list it walks and from where.
## @ace_hidden
func _enter_build_phase(phase: int) -> void:
	_build_phase = phase
	_build_cursor = 0
	_build_pass = 0
	if phase == BUILD_BODIES:
		_build_list = _body_states.keys()
	elif phase == BUILD_OVERRIDES:
		_build_list = _tile_overrides.keys()
	elif phase == BUILD_BLOCKING or phase == BUILD_NODES:
		_build_list = _build_keys
	elif phase == BUILD_LINKS:
		_build_list = _build_nodes
		_begin_links()
		_build_pass = -1
		_advance_link_pass()
	else:
		_build_list = []

## Runs the running build step for as long as the deadline allows (a zero deadline means no limit);
## true when the step has walked its whole list. At least one cell is handled per call, so a build
## always moves forward.
## @ace_hidden
func _run_build_phase(deadline: int) -> bool:
	var handled: int = 0
	var phase: int = _build_phase
	if phase == BUILD_SCAN:
		var total: int = _build_tiles.size()
		while _build_cursor < total:
			var scanned: Vector2i = _build_tiles[_build_cursor]
			_build_cursor += 1
			var tile_data: TileData = _tilemap.get_cell_tile_data(scanned)
			if tile_data != null:
				var painted: String = _tile_state_of(tile_data)
				if painted != "":
					_states[scanned] = painted
					_build_keys.append(scanned)
			handled += 1
			if handled % 64 == 0 and _build_timeup(deadline):
				return _build_cursor >= total
		return true
	if phase == BUILD_LINKS:
		var count: int = _build_list.size()
		while _build_pass < LINK_PASS_COUNT:
			while _build_cursor < count:
				_link_cell(_build_pass, _build_list[_build_cursor])
				_build_cursor += 1
				if _build_timeup(deadline):
					if _build_cursor >= count:
						_advance_link_pass()
					return _build_pass >= LINK_PASS_COUNT
			_advance_link_pass()
			if _build_pass < LINK_PASS_COUNT and _build_timeup(deadline):
				return false
		return true
	var size: int = _build_list.size()
	while _build_cursor < size:
		var cell: Vector2i = _build_list[_build_cursor]
		_build_cursor += 1
		if phase == BUILD_BODIES:
			if not _states.has(cell):
				_build_keys.append(cell)
			_states[cell] = _body_states[cell]
		elif phase == BUILD_OVERRIDES:
			if str(_tile_overrides[cell]) == "clear":
				_states.erase(cell)
			else:
				if not _states.has(cell):
					_build_keys.append(cell)
				_states[cell] = _tile_overrides[cell]
		elif phase == BUILD_BLOCKING:
			if _states.has(cell):
				if _blocks_state(str(_states[cell])):
					_blocking[cell] = true
				_blocking_down[cell] = true
		elif phase == BUILD_NODES:
			if _states.has(cell):
				var stand: Vector2i = cell + Vector2i(0, -1)
				if not _blocking.has(stand) and not _blocking.has(stand + Vector2i(0, -1)):
					_nodes[stand] = true
					_build_nodes.append(stand)
		handled += 1
		if handled % 64 == 0 and _build_timeup(deadline):
			return _build_cursor >= size
	return true

## Runs the graph build for up to `budget_ms` milliseconds (0 or less = to the end); true when the
## graph is finished.
## @ace_hidden
func _step_build(budget_ms: float) -> bool:
	var deadline: int = 0
	if budget_ms > 0.0:
		deadline = Time.get_ticks_usec() + maxi(int(budget_ms * 1000.0), 1)
	while _build_phase != BUILD_DONE:
		if not _run_build_phase(deadline):
			return false
		_enter_build_phase(_build_phase + 1)
		if _build_phase != BUILD_DONE and _build_timeup(deadline):
			return false
	return true

## Whether the graph is still being built, by this agent or by another one on the same map tag. A
## builder that was freed half way leaves a half-made graph, which this agent then builds again.
## @ace_hidden
func _graph_building() -> bool:
	if _build_active:
		return true
	if map_tag == "":
		return false
	var shared: NavSharedMap = _shared_maps.get(map_tag, null) as NavSharedMap
	if shared == null or not shared.building:
		return false
	if is_instance_id_valid(shared.builder_id):
		return true
	shared.building = false
	if _has_grid():
		regenerate_nav_graph()
	else:
		shared.nodes.clear()
		shared.edges.clear()
	return _build_active

## Gets a build ready over the map as it stands now, from nothing: a build that was running is
## dropped and the graph is empty. Nothing is built yet.
## @ace_hidden
func _begin_build() -> void:
	_nodes.clear()
	_edges.clear()
	_states.clear()
	_blocking.clear()
	_blocking_down.clear()
	_watch_ready = false
	_build_keys = []
	_build_nodes = []
	_build_tiles.clear()
	if _tilemap != null:
		_build_tiles.assign(_tilemap.get_used_cells())
	_build_active = true
	_build_waiting = false
	var shared: NavSharedMap = _shared_maps.get(map_tag, null) as NavSharedMap if map_tag != "" else null
	if shared != null:
		shared.building = true
		shared.builder_id = get_instance_id()
	_enter_build_phase(BUILD_SCAN)

## Builds the graph over the map as it stands now. The first part runs in this call (the whole graph
## when it fits the frame budget, or when this agent is not in a scene tree to carry on in); the rest
## continues a few milliseconds per physics frame.
## @ace_hidden
func _start_build() -> void:
	_begin_build()
	var sliced: bool = build_budget_ms > 0.0 and is_inside_tree()
	if _step_build(build_budget_ms if sliced else 0.0):
		_finish_build()
	else:
		_wake()

## Drops a build that is running, leaving the graph as it is.
## @ace_hidden
func _abandon_build() -> void:
	_build_active = false
	_build_waiting = false
	_build_phase = BUILD_DONE
	_build_keys = []
	_build_nodes = []
	_build_list = []
	_build_tiles.clear()
	_after_build = Callable()
	var shared: NavSharedMap = _shared_maps.get(map_tag, null) as NavSharedMap if map_tag != "" else null
	if shared != null and shared.builder_id == get_instance_id():
		shared.building = false

## The graph is made: put back the portals and moving platforms, draw it, tell the sheet, and run
## the request that was waiting for it.
## @ace_hidden
func _finish_build() -> void:
	_build_active = false
	_build_keys = []
	_build_nodes = []
	_build_list = []
	_build_tiles.clear()
	var shared: NavSharedMap = _shared_maps.get(map_tag, null) as NavSharedMap if map_tag != "" else null
	if shared != null and shared.builder_id == get_instance_id():
		shared.building = false
	# Registered portals and moving platforms survive every rebuild.
	for portal in _portals:
		_apply_portal(portal)
	for ride in _moving_platforms:
		_apply_moving_platform(ride)
	_refresh_graph_overlay()
	nav_graph_built.emit()
	var waiting: Callable = _after_build
	_after_build = Callable()
	if waiting.is_valid():
		waiting.call()

## How far along the running build is, from 0 to 1: each step has a share of the whole, and the link
## passes (nearly all of the work) are counted pass by pass.
## @ace_hidden
func _build_fraction() -> float:
	if not _build_active:
		return 1.0
	var shares: Array[float] = [0.08, 0.01, 0.01, 0.03, 0.03, 0.84]
	var done: float = 0.0
	for phase in range(mini(_build_phase, BUILD_LINKS)):
		done += shares[phase]
	if _build_phase == BUILD_LINKS:
		var passes: int = 0
		var passed: int = 0
		for link_pass in range(LINK_PASS_COUNT):
			if _link_pass_runs(link_pass):
				passes += 1
				if link_pass < _build_pass:
					passed += 1
		var within: float = float(_build_cursor) / float(maxi(_build_list.size(), 1))
		done += shares[BUILD_LINKS] * (float(passed) + within) / float(maxi(passes, 1))
	elif _build_phase < BUILD_LINKS:
		var size: int = _build_tiles.size() if _build_phase == BUILD_SCAN else _build_list.size()
		done += shares[_build_phase] * float(_build_cursor) / float(maxi(size, 1))
	return clampf(done, 0.0, 1.0)

## Carries a running build on by one frame's share, and tells a sheet whose agent was waiting for
## another agent's build that the graph it asked for is there.
## @ace_hidden
func _step_graph_build() -> void:
	if _build_active:
		var shared: NavSharedMap = _shared_maps.get(map_tag, null) as NavSharedMap if map_tag != "" else null
		if shared != null and shared.builder_id != get_instance_id():
			# Another agent on this map tag started the build over: it is theirs now.
			var kept: Callable = _after_build
			_abandon_build()
			_after_build = kept
			_build_waiting = true
			return
		if _step_build(build_budget_ms):
			_finish_build()
		return
	if _build_waiting and not _graph_building():
		_build_waiting = false
		_refresh_graph_overlay()
		nav_graph_built.emit()
		var waiting: Callable = _after_build
		_after_build = Callable()
		if waiting.is_valid():
			waiting.call()

#endregion

func _physics_process(delta: float) -> void:
	_step_graph_build()
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
	_follow_portal_nodes()
	if not _learning.is_empty():
		_learn_platforms()
	_watch_tiles()
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
			_finish_patrol_dwell()
	_resume_patrol_tick(delta)
	_apply_patrol_speed()
	if _check_patrol_way(delta):
		return
	if _path.is_empty():
		if idle_separation > 0.0 and _separate(delta):
			return
		# No route, no deferred request, nobody being followed, no patrol, no spacing to keep
		# and no hazard to watch means there is nothing this tick could do - a parked agent
		# costs nothing per frame until a path verb or Add Hazard turns processing back on.
		if not _path_pending and (_follow_target == null or not is_instance_valid(_follow_target)) and _hazards.is_empty() and not _patrolling and idle_separation <= 0.0 and not _has_followed_portals() and _patrol_memory_kind == "" and _learning.is_empty() and not watch_tile_edits and not _build_active and not _build_waiting:
			set_physics_process(false)
		return
	var waypoint: NavWaypoint = _path[_path_index]
	var target: Vector2 = waypoint.world
	# Portal traversal: On Portal Entered, then the blink or the gradual move.
	if waypoint.action == "portal" or waypoint.action == "portal_gradual":
		_enter_portal(waypoint)
		return
	var dx: float = target.x - host.global_position.x
	_move_axis = clampf(dx / 24.0, -1.0, 1.0) if absf(dx) > 2.0 else 0.0
	var movement: Node = _find_movement()
	var tile: float = _tile_px()
	var action: String = waypoint.action
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
		var takeoff_dx: float = _path[_path_index - 1].world.x - host.global_position.x
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
			if _path[ahead].action == "platform":
				_move_axis = _platform_approach_axis(_path[ahead].world, _move_axis)
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
		var leg_start: Vector2 = _path[_path_index - 1].world
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
	if _tilemap != null and _joined_running_build(_tilemap.get_instance_id()):
		# Another agent on this map tag is still building it: wait for that build instead of making a second.
		_build_waiting = true
		_wake()
		return
	regenerate_nav_graph()

func regenerate_nav_graph() -> void:
	if not _has_grid():
		_abandon_build()
		_nodes.clear()
		_edges.clear()
		_states.clear()
		_blocking.clear()
		_blocking_down.clear()
		return
	_start_build()

func set_build_budget(milliseconds: float) -> void:
	build_budget_ms = milliseconds

func regenerate_region(x: float, y: float, width: float, height: float) -> void:
	if not _has_grid():
		return
	if _nodes.is_empty() or _graph_building():
		regenerate_nav_graph()
		return
	var first: Vector2i = _world_to_cell(Vector2(x, y))
	var last: Vector2i = _world_to_cell(Vector2(x + width, y + height))
	var low: Vector2i = Vector2i(mini(first.x, last.x), mini(first.y, last.y))
	var high: Vector2i = Vector2i(maxi(first.x, last.x), maxi(first.y, last.y))
	_regenerate_cells(Rect2i(low, high - low + Vector2i.ONE))

func regenerate_region_by_node(target: Node) -> void:
	if not (target is Node2D):
		return
	var box: Rect2 = _node_shape_bounds(target as Node2D)
	regenerate_region(box.position.x, box.position.y, box.size.x, box.size.y)

func find_path_to(x: float, y: float, mode: String) -> void:
	_cancel_patrol_for_route()
	_side_request = null
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
	_held = false
	_patrol_memory_kind = ""
	_after_build = Callable()
	_end_patrol()
	_side_request = null
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
	var hazard: NavHazard = NavHazard.new()
	hazard.id = _take_hazard_id()
	hazard.kind = "rect"
	hazard.rect = Rect2(x, y, width, height)
	hazard.deadly = deadly
	_hazards.append(hazard)
	_last_hazard_id = hazard.id
	# A hazard is watched per frame (On Hazard Entered fires on the way in), so a parked
	# agent starts paying for its tick again the moment one exists.
	set_physics_process(true)

func clear_hazards() -> void:
	_hazards.clear()

func add_moving_platform(platform: Node, from_x: float, from_y: float, to_x: float, to_y: float) -> void:
	if not (platform is Node2D):
		return
	var ride: NavRide = NavRide.new()
	ride.node = platform as Node2D
	ride.a = Vector2(from_x, from_y)
	ride.b = Vector2(to_x, to_y)
	_moving_platforms.append(ride)
	if not _nodes.is_empty():
		_apply_moving_platform(ride)

func learn_moving_platform(platform: Node) -> void:
	if not (platform is Node2D):
		return
	for ride in _moving_platforms:
		if ride.node == platform:
			return
	for learner in _learning:
		if learner.node == platform:
			return
	var learn: NavLearn = NavLearn.new()
	learn.node = platform as Node2D
	learn.end_a = _world_transform_of(learn.node).origin
	learn.end_b = learn.end_a
	learn.last = learn.end_a
	_learning.append(learn)
	set_physics_process(true)

func clear_moving_platforms() -> void:
	_learning.clear()
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
	_cancel_patrol_for_route()
	_side_request = null
	var facing: int = -1 if direction == "left" else 1
	if _nodes.is_empty():
		_auto_build()
	if _graph_building():
		_after_build = find_path_to_nearest_ledge.bind(direction, distance)
		return
	var ledge: Vector2i = _nearest_ledge_cell(facing)
	if ledge == Vector2i.MAX:
		_fail("no_ledge")
		return
	var spot: Vector2 = _cell_world(ledge) - Vector2(float(facing) * distance, 0.0)
	_exact_final = spot.x
	_route(spot.x, spot.y, "nearest")

func find_path_to_node_side(target: Node, side: String, distance: float) -> void:
	_cancel_patrol_for_route()
	_reached_side = 0
	if not (target is Node2D) or host == null:
		_fail("no_target")
		return
	if _graph_building():
		_after_build = find_path_to_node_side.bind(target, side, distance)
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
	_side_request = NavSideRequest.new()
	_side_request.node = target
	_side_request.side = facing
	_side_request.spot = spot
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
	if _graph_building():
		_after_build = start_patrol.bind(dwell, edge_distance)
		return
	_patrol_dwell = maxf(dwell, 0.0)
	_patrol_edge = maxf(edge_distance, 0.0)
	if not _measure_patrol_ends():
		_fail("no_start_node")
		return
	_patrolling = true
	_patrol_dwelling = false
	_patrol_dir = 1 if (_patrol_ends[1] as Vector2).x - host.global_position.x >= host.global_position.x - (_patrol_ends[0] as Vector2).x else -1
	_patrol_walk()

func start_patrol_between_markers(group: String, order: String, dwell: float) -> void:
	if not nav_enabled or host == null or not is_inside_tree():
		return
	var found: Array[Node2D] = []
	for candidate in get_tree().get_nodes_in_group(group):
		if candidate is Node2D and candidate != host:
			found.append(candidate as Node2D)
	if found.is_empty():
		push_warning("[PlatformerPathfinding] Start Patrol Between Markers: the group '%s' has no markers." % group)
		return
	stop_pathfinding()
	if _nodes.is_empty():
		_auto_build()
	_patrol_group = group
	_begin_marker_patrol(found, order == PATROL_ORDER_LOOP, dwell)

func set_patrol_setting(setting: String, value: float) -> void:
	if setting == PATROL_DWELL_TIME:
		_patrol_dwell = maxf(value, 0.0)
	elif setting == PATROL_EDGE_DISTANCE:
		_patrol_edge = maxf(value, 0.0)
		if _platform_patrolling():
			_measure_patrol_ends()
	elif setting == PATROL_DWELL_VARIATION:
		_patrol_dwell_variation = maxf(value, 0.0)
	elif setting == PATROL_SPEED:
		_patrol_speed_percent = maxf(value, 1.0)
	elif setting == PATROL_RESUME_AFTER:
		_patrol_resume_after = maxf(value, 0.0)
		if _patrol_resume_after <= 0.0:
			_patrol_memory_kind = ""

func set_patrol_option(option: String, enabled: bool) -> void:
	if option == PATROL_TURN_AT_AGENTS:
		_patrol_turn_at_agents = enabled
	elif option == PATROL_TURN_BEFORE_DANGER:
		_patrol_turn_before_danger = enabled

func patrol_point_index() -> int:
	return _patrol_marker_index if _patrolling else -1

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
		for edge: NavEdge in (_edges[cell] as Array):
			counts[edge.kind] = int(counts.get(edge.kind, 0)) + 1
			total += 1
	print("[PlatformerPathfinding] nodes=%d links=%d %s portals=%d hazards=%d platforms=%d jump_reach=%s cells" % [_nodes.size(), total, str(counts), _portals.size(), _hazards.size(), _moving_platforms.size(), str(_jump_reach_cells())])
	var regions: Array = _separate_regions()
	if regions.size() > 1:
		var sizes: PackedStringArray = PackedStringArray()
		for region: Array in regions:
			sizes.append("%d at %s" % [region.size(), str(_cell_world(region[0]).round())])
		print("[PlatformerPathfinding] %d separate regions (nodes that cannot reach each other, by any link): %s" % [regions.size(), ", ".join(sizes)])

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
	_abandon_build()
	_nodes.clear()
	_edges.clear()
	_states.clear()
	_blocking.clear()
	_blocking_down.clear()
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
	var map_version: int = int(data.get("version", OBSTACLE_MAP_VERSION))
	if map_version > OBSTACLE_MAP_VERSION:
		push_warning("[PlatformerPathfinding] Load Obstacle Map JSON: this map is version %d and this behaviour reads version %d, so parts of it may be left out." % [map_version, OBSTACLE_MAP_VERSION])
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
	_add_elevator_stop(group, Vector2(x, y), null, speed, tag)

func add_elevator_stop_from_node(group: String, stop: Node, speed: float, tag: String) -> void:
	if stop is Node2D:
		_add_elevator_stop(group, _world_transform_of(stop as Node2D).origin, stop as Node2D, speed, tag)

func add_portal_from_nodes(entrance: Node, exit: Node, bidirectional: bool, kind: String, cost: float, speed: float, tag: String) -> void:
	if not (entrance is Node2D) or not (exit is Node2D):
		return
	var portal_id: int = _add_portal_record(_world_transform_of(entrance as Node2D).origin, _world_transform_of(exit as Node2D).origin, bidirectional, kind, cost, speed, tag)
	var portal: NavPortal = _portal_by_id(portal_id)
	portal.from_node = entrance as Node2D
	portal.from_follows = true
	portal.to_node = exit as Node2D
	portal.to_follows = true
	set_physics_process(true)

func set_portal_position_from_nodes(portal_id: int, entrance: Node, exit: Node) -> void:
	var portal: NavPortal = _portal_by_id(portal_id)
	if portal == null or not (entrance is Node2D) or not (exit is Node2D):
		return
	portal.from_node = entrance as Node2D
	portal.from_follows = true
	portal.to_node = exit as Node2D
	portal.to_follows = true
	portal.from = _world_transform_of(portal.from_node).origin
	portal.to = _world_transform_of(portal.to_node).origin
	_relink_portal(portal)
	set_physics_process(true)

func remove_portal_at_node(target: Node) -> void:
	var doomed: Array = []
	for portal in _portals:
		if portal.from_node == target or portal.to_node == target:
			doomed.append(portal.id)
	for portal_id in doomed:
		remove_portal(portal_id)
	for group in _elevator_stops:
		var kept: Array = []
		for stop: NavStop in (_elevator_stops[group] as Array):
			if stop.node != target:
				kept.append(stop)
		_elevator_stops[group] = kept

func remove_portal(portal_id: int) -> void:
	for index in range(_portals.size() - 1, -1, -1):
		if _portals[index].id == portal_id:
			_portals.remove_at(index)
	_unlink_portal(portal_id)
	_refresh_graph_overlay()

func remove_portal_near(x: float, y: float) -> void:
	var best_id: int = -1
	var best_gap: float = INF
	for portal in _portals:
		var gap: float = minf(portal.from.distance_to(Vector2(x, y)), portal.to.distance_to(Vector2(x, y)))
		if gap < best_gap:
			best_gap = gap
			best_id = portal.id
	if best_id >= 0:
		remove_portal(best_id)

func remove_portals_by_tag(tag: String) -> void:
	var doomed: Array = []
	for portal in _portals:
		if _portal_has_tag(portal, tag):
			doomed.append(portal.id)
	for portal_id in doomed:
		remove_portal(portal_id)

func set_portal_cost(portal_id: int, cost: float) -> void:
	var portal: NavPortal = _portal_by_id(portal_id)
	if portal != null:
		portal.cost = cost
		_relink_portal(portal)

func set_portal_speed(portal_id: int, speed: float) -> void:
	var portal: NavPortal = _portal_by_id(portal_id)
	if portal != null:
		portal.speed = speed
		_relink_portal(portal)

func set_portal_tag(portal_id: int, tag: String) -> void:
	var portal: NavPortal = _portal_by_id(portal_id)
	if portal != null:
		portal.tag = tag

func set_portal_ignore_hazards(portal_id: int, ignore: bool) -> void:
	var portal: NavPortal = _portal_by_id(portal_id)
	if portal != null:
		portal.ignore_hazards = ignore

func set_portal_position(portal_id: int, from_x: float, from_y: float, to_x: float, to_y: float) -> void:
	var portal: NavPortal = _portal_by_id(portal_id)
	if portal != null:
		portal.from = Vector2(from_x, from_y)
		portal.to = Vector2(to_x, to_y)
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
	var hazard: NavHazard = NavHazard.new()
	hazard.id = _take_hazard_id()
	hazard.kind = "circle"
	hazard.center = Vector2(x, y)
	hazard.radius = radius
	hazard.deadly = deadly
	_hazards.append(hazard)
	_last_hazard_id = hazard.id
	set_physics_process(true)

func add_tracked_hazard(target: Node, radius: float, deadly: bool) -> void:
	if not (target is Node2D):
		return
	var hazard: NavHazard = NavHazard.new()
	hazard.id = _take_hazard_id()
	hazard.kind = "tracked"
	hazard.node = target
	hazard.radius = radius
	hazard.deadly = deadly
	_hazards.append(hazard)
	_last_hazard_id = hazard.id
	set_physics_process(true)

func add_hazard_from_node(target: Node, deadly: bool) -> void:
	if not (target is Node2D):
		return
	# One hazard per node: asking again changes its deadly flag instead of stacking a copy.
	for existing in _hazards:
		if existing.kind == "shape" and existing.node == target:
			existing.deadly = deadly
			_last_hazard_id = existing.id
			return
	var hazard: NavHazard = NavHazard.new()
	hazard.id = _take_hazard_id()
	hazard.kind = "shape"
	hazard.node = target
	hazard.deadly = deadly
	_refresh_shape_hazard(hazard)
	_hazards.append(hazard)
	_last_hazard_id = hazard.id
	set_physics_process(true)

func remove_hazard_from_node(target: Node) -> void:
	for index in range(_hazards.size() - 1, -1, -1):
		var hazard: NavHazard = _hazards[index]
		if (hazard.kind == "shape" or hazard.kind == "tracked") and hazard.node == target:
			_hazards.remove_at(index)

func set_tile_hazard(gx: int, gy: int, level: String) -> void:
	var cell: Vector2i = Vector2i(gx, gy)
	for index in range(_hazards.size() - 1, -1, -1):
		if _hazards[index].kind == "tile" and _hazards[index].cell == cell:
			_hazards.remove_at(index)
	if level != HAZARD_DANGER and level != HAZARD_DEADLY:
		return
	var hazard: NavHazard = NavHazard.new()
	hazard.id = _take_hazard_id()
	hazard.kind = "tile"
	hazard.cell = cell
	var half: Vector2 = Vector2(_tile_px(), _tile_px()) * 0.5
	hazard.rect = Rect2(_cell_world(cell) - half, half * 2.0)
	hazard.deadly = level == HAZARD_DEADLY
	_hazards.append(hazard)
	_last_hazard_id = hazard.id
	set_physics_process(true)

func remove_hazard(hazard_id: int) -> void:
	for index in range(_hazards.size() - 1, -1, -1):
		if _hazards[index].id == hazard_id:
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
	# While a build is running the map it is filling is left alone: the answer is read off a copy.
	var merged: Dictionary = _merged_states()
	if not _graph_building():
		_states.clear()
		_states.merge(merged)
	var cells: Array = []
	var keys: Array = merged.keys()
	keys.sort()
	for cell in keys:
		cells.append([cell.x, cell.y, merged[cell]])
	var origin: Vector2 = _cell_world(Vector2i.ZERO) - Vector2(_tile_px(), _tile_px()) * 0.5
	var size: Vector2i = grid_size()
	return JSON.stringify({"version": OBSTACLE_MAP_VERSION, "cell_size": _tile_px(), "origin": [origin.x, origin.y], "size": [size.x, size.y], "cells": cells})

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
	return (links[index] as NavEdge).kind if index >= 0 and index < links.size() else ""

func graph_node_connection_cost(gx: int, gy: int, index: int) -> float:
	var links: Array = _edges.get(Vector2i(gx, gy), [])
	return _edge_cost(Vector2i(gx, gy), links[index] as NavEdge) if index >= 0 and index < links.size() else 0.0

func graph_node_connection_target(gx: int, gy: int, index: int) -> Vector2:
	var links: Array = _edges.get(Vector2i(gx, gy), [])
	return _cell_world((links[index] as NavEdge).to) if index >= 0 and index < links.size() else Vector2.ZERO

func ledge_side(gx: int, gy: int) -> int:
	return _ledge_side(Vector2i(gx, gy))

func nearest_graph_node(x: float, y: float) -> Vector2:
	var cell: Vector2i = _nearest_node(Vector2(x, y), 1000000)
	return _cell_world(cell) if cell != Vector2i.MAX else Vector2.ZERO

func nearest_graph_node_cell(x: float, y: float) -> Vector2i:
	var cell: Vector2i = _nearest_node(Vector2(x, y), 1000000)
	return cell if cell != Vector2i.MAX else Vector2i(-1, -1)

func run_speed() -> float:
	return _run_speed()

func jump_speed() -> float:
	var movement: Node = _find_movement()
	if movement != null and movement.get("jump_velocity") != null:
		return absf(float(movement.get("jump_velocity")))
	return absf(fallback_jump_velocity)

func grid_origin() -> Vector2:
	if _tilemap != null:
		return _cell_world(Vector2i.ZERO) - Vector2(_tile_px(), _tile_px()) * 0.5
	return _grid_origin

func calculated_jump_distance() -> float:
	return _jump_reach_px().x

func calculated_jump_height() -> float:
	return _jump_reach_px().y

func path_cost() -> float:
	return _path_cost if not _path.is_empty() else 0.0

func path_end() -> Vector2:
	return _path.back().world if not _path.is_empty() else Vector2.ZERO

func path_target() -> Vector2:
	return _path_goal

func path_goal_cell() -> Vector2i:
	return _path_goal_cell

func path_fail_reason() -> String:
	return _fail_reason

func path_queue_size() -> int:
	var waiting: int = 0
	for agent_id in _agent_ids.keys():
		var queued: PlatformerPathfinding = instance_from_id(agent_id) as PlatformerPathfinding if is_instance_id_valid(agent_id) else null
		if queued != null and queued._path_pending:
			waiting += 1
	return waiting

func waypoint_position(index: int) -> Vector2:
	return _path[index].world if index >= 0 and index < _path.size() else Vector2.ZERO

func waypoint_cell(index: int) -> Vector2i:
	return _path[index].cell if index >= 0 and index < _path.size() else Vector2i(-1, -1)

func waypoint_action(index: int) -> String:
	return _path[index].action if index >= 0 and index < _path.size() else ""

func distance_to_waypoint() -> float:
	if _path.is_empty() or host == null:
		return 0.0
	return host.global_position.distance_to(_path[_path_index].world)

func angle_to_waypoint() -> float:
	if _path.is_empty() or host == null:
		return 0.0
	return rad_to_deg(host.global_position.angle_to_point(_path[_path_index].world))

func nearby_agent_count(radius: float) -> int:
	if host == null:
		return 0
	var count: int = 0
	for agent in _other_agents():
		if agent.host.global_position.distance_to(host.global_position) <= radius:
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
		if hazard.kind == "tracked" or hazard.kind == "shape":
			count += 1
	return count

func last_hazard_id() -> int:
	return _last_hazard_id

func hazard_at(x: float, y: float) -> int:
	var point: Vector2 = Vector2(x, y)
	var verdict: int = 0
	for hazard in _hazards:
		if _hazard_hit(hazard, point, 0.0):
			if hazard.deadly:
				return 2
			verdict = 1
		elif hazard_margin > 0.0 and _hazard_hit(hazard, point, hazard_margin):
			verdict = 1
	return verdict

func current_portal_id() -> int:
	return _current_portal.id if _current_portal != null else -1

func last_portal_id() -> int:
	return _last_portal_id

func portal_count() -> int:
	return _portals.size()

func nearest_portal_id(x: float, y: float, tag: String) -> int:
	var best_id: int = -1
	var best_gap: float = INF
	for portal in _portals:
		var gap: float = portal.from.distance_to(Vector2(x, y))
		if _portal_has_tag(portal, tag) and gap < best_gap:
			best_gap = gap
			best_id = portal.id
	return best_id

func furthest_portal_id(x: float, y: float, tag: String) -> int:
	var best_id: int = -1
	var best_gap: float = -1.0
	for portal in _portals:
		var gap: float = portal.from.distance_to(Vector2(x, y))
		if _portal_has_tag(portal, tag) and gap > best_gap:
			best_gap = gap
			best_id = portal.id
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
				return portal.id
			seen += 1
	return -1

func portal_tag(portal_id: int) -> String:
	var portal: NavPortal = _portal_by_id(portal_id)
	return portal.tag if portal != null else ""

func portal_type(portal_id: int) -> String:
	var portal: NavPortal = _portal_by_id(portal_id)
	return portal.type if portal != null else ""

func portal_exit() -> Vector2:
	return _current_portal_exit if _current_portal != null else Vector2.ZERO

func portal_progress() -> float:
	return _portal_progress if _portal_traversing else 0.0
