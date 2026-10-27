# Godot EventSheets - Platformer Pathfinding: link kinds, strategies, maps, portals, crowds.
#
# Loads the COMPILED pack and pins the graph and router work the second wave of the pack added:
# one-way tiles (jump-through nodes + fall-through drops), slope tiles read off their polygons,
# double jump and coyote jump links sized from a real PlatformerMovement sibling, the six path
# strategies' link prices and filters, the nearest-mode partial route, the search cap, path
# smoothing, ledges and platforms, patrol ends, side-of-node goals, crowd claims, shared map tags,
# portal ids / tags / gradual links / elevators, circle / tracked hazards and margins, custom
# obstacle maps with the JSON round trip, and body scanning. Values are pinned, not counts. The
# physical half (does a body really drop through, double jump, ride a gradual portal) needs
# stepped physics and is verified by a non-headless runtime smoke, not here.
@tool
class_name PlatformerPathfindingLinksTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"
const MOVEMENT := "res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd"


static func run() -> bool:
	var ok: bool = true
	var script: GDScript = load(PACK)
	ok = _check("pack loads", script != null, true) and ok
	if script == null:
		return ok
	var probe: Node = script.new()
	# Every route below runs inside ONE physics frame (no main loop in the runner), so lift the
	# shared per-tick budget for the test and put it back at the end.
	probe.set_max_paths_per_tick(1000000)
	ok = _links(script) and ok
	ok = _movement_links(script) and ok
	ok = _strategies_and_search(script) and ok
	ok = _routes_and_platforms(script) and ok
	ok = _crowds_and_tags(script) and ok
	ok = _portals(script) and ok
	ok = _hazards(script) and ok
	ok = _obstacle_maps(script) and ok
	probe.set_max_paths_per_tick(8)
	(probe.get("_shared_maps") as Dictionary).clear()
	(probe.get("_goal_claims") as Dictionary).clear()
	(probe.get("_agent_ids") as Dictionary).clear()
	probe.free()
	return ok


# ── One-way tiles, slopes ─────────────────────────────────────────────────────────────
static func _links(script: GDScript) -> bool:
	var ok: bool = true
	# Floor y=10 x 0..19; a one-way platform y=7 x 3..6; a "/" slope tile at (12, 9).
	var map: TileMapLayer = _make_map()
	for x in range(0, 20):
		map.set_cell(Vector2i(x, 10), 0, Vector2i(0, 0))
	for x in range(3, 7):
		map.set_cell(Vector2i(x, 7), 0, Vector2i(1, 0))
	map.set_cell(Vector2i(12, 9), 0, Vector2i(2, 0))
	var nav: Node = script.new()
	nav.build_nav_graph(map)
	ok = _check("a one-way tile reads jump_thru", nav.tile_state(4, 7), "jump_thru") and ok
	ok = _check("a / slope tile reads slope_left", nav.tile_state(12, 9), "slope_left") and ok
	ok = _check("a full tile reads solid", nav.tile_state(0, 10), "solid") and ok
	ok = _check("an empty cell reads clear", nav.tile_state(0, 2), "clear") and ok
	ok = _check("standing ON the one-way platform is a node", nav.graph_node_exists(4, 6), true) and ok
	ok = _check("the floor UNDER the one-way platform keeps its headroom", nav.graph_node_exists(4, 9), true) and ok
	ok = _check("dropping off the one-way platform is a fall_through link", _kind(nav, Vector2i(4, 6), Vector2i(4, 9)), "fall_through") and ok
	ok = _check("jumping up through it from below is a jump link", _kind(nav, Vector2i(4, 9), Vector2i(4, 6)), "jump") and ok
	ok = _check("solid ground gets no fall_through link", _kind(nav, Vector2i(10, 9), Vector2i(10, 12)), "") and ok
	ok = _check("tile_has_state agrees", nav.tile_has_state(4, 7, "jump_thru"), true) and ok
	nav.free()
	map.free()
	return ok


# ── Double jump + coyote jump links from a real movement sibling ─────────────────────
static func _movement_links(script: GDScript) -> bool:
	var ok: bool = true
	# Floor x 0..5 at y=10, a high ledge x 8..11 at y=6 (4 cells up, past a single jump),
	# and a far floor x 11..14 at y=10 (6 cells across, past a standing jump).
	var map: TileMapLayer = _make_map()
	for x in range(0, 6):
		map.set_cell(Vector2i(x, 10), 0, Vector2i(0, 0))
	for x in range(8, 12):
		map.set_cell(Vector2i(x, 6), 0, Vector2i(0, 0))
	for x in range(11, 15):
		map.set_cell(Vector2i(x, 10), 0, Vector2i(0, 0))
	var body: CharacterBody2D = CharacterBody2D.new()
	var movement: Node = (load(MOVEMENT) as GDScript).new()
	body.add_child(movement)
	var nav: Node = script.new()
	body.add_child(nav)
	nav.set("host", body)
	nav.build_nav_graph(map)
	ok = _check("one jump: no link to the 4-up ledge", _kind(nav, Vector2i(5, 9), Vector2i(8, 5)), "") and ok
	movement.set("max_jumps", 2)
	nav.regenerate_nav_graph()
	ok = _check("two jumps: the 4-up ledge is a double_jump link", _kind(nav, Vector2i(5, 9), Vector2i(8, 5)), "double_jump") and ok
	nav.set("double_jump_links", false)
	nav.regenerate_nav_graph()
	ok = _check("Double Jump Links off removes it", _kind(nav, Vector2i(5, 9), Vector2i(8, 5)), "") and ok
	movement.set("max_jumps", 1)
	ok = _check("defaults: no coyote link to the 6-across floor", _kind(nav, Vector2i(5, 9), Vector2i(11, 9)), "") and ok
	nav.set("coyote_time", 0.5)
	movement.set("coyote_time", 0.5)
	nav.regenerate_nav_graph()
	ok = _check("a 0.5 s coyote window links the far floor as coyote_jump", _kind(nav, Vector2i(5, 9), Vector2i(11, 9)), "coyote_jump") and ok
	ok = _check("coyote links only leave a LEDGE", _kind(nav, Vector2i(4, 9), Vector2i(11, 9)), "") and ok
	nav.set("ledge_restriction", true)
	nav.regenerate_nav_graph()
	ok = _check("Ledge Restriction builds no coyote links", _kind(nav, Vector2i(5, 9), Vector2i(11, 9)), "") and ok
	ok = _check("calculated jump distance (px)", "%.3f" % nav.calculated_jump_distance(), "146.939") and ok
	ok = _check("calculated jump height (px)", "%.3f" % nav.calculated_jump_height(), "73.469") and ok
	body.free()
	map.free()
	return ok


# ── Strategy prices, filters, the partial route and the search cap ──────────────────
static func _strategies_and_search(script: GDScript) -> bool:
	var ok: bool = true
	var map: TileMapLayer = _classic_map()
	var nav: Node = script.new()
	nav.build_nav_graph(map)
	var gap_jump: Dictionary = _edge(nav, Vector2i(7, 4), Vector2i(10, 4))
	var prices: Dictionary = {"balanced": 4.5, "shortest": 5.0, "safest": 11.719, "ground_hugging": 22.0}
	for strategy: String in prices:
		nav.set_path_strategy(strategy)
		ok = _check("%s prices the 3-cell gap jump" % strategy, snappedf(nav._edge_cost(Vector2i(7, 4), gap_jump), 0.001), prices[strategy]) and ok
	var drop: Dictionary = _edge(nav, Vector2i(12, 2), Vector2i(11, 4))
	nav.set_path_strategy("walk_only")
	ok = _check("walk_only: the gap jump is filtered out", nav._edge_allowed(Vector2i(7, 4), gap_jump), false) and ok
	ok = _check("walk_only: the platform drop is filtered out", nav._edge_allowed(Vector2i(12, 2), drop), false) and ok
	ok = _check("walk_only: walking stays", nav._edge_allowed(Vector2i(0, 4), _edge(nav, Vector2i(0, 4), Vector2i(1, 4))), true) and ok
	nav.set_path_strategy("no_falling")
	ok = _check("no_falling: a level jump is fine", nav._edge_allowed(Vector2i(7, 4), gap_jump), true) and ok
	ok = _check("no_falling: the 64px drop is filtered out", nav._edge_allowed(Vector2i(12, 2), drop), false) and ok
	nav.set_max_traversal_drop(70.0)
	ok = _check("no_falling + 70px allowance: the drop is back", nav._edge_allowed(Vector2i(12, 2), drop), true) and ok
	nav.set_path_strategy("balanced")
	nav.set_max_traversal_drop(40.0)
	ok = _check("a 40px drop limit works with any strategy", nav._edge_allowed(Vector2i(12, 2), drop), false) and ok
	nav.set_max_traversal_drop(-1.0)
	# The partial route: walk_only cannot cross the gap, so "nearest" stops at the gap's edge.
	nav.set_path_strategy("walk_only")
	ok = _check("reach mode: a cut-off goal is no route", nav._astar(Vector2i(0, 4), Vector2i(15, 4)), []) and ok
	ok = _check("the search says why", nav.get("_last_search_fail"), "no_path") and ok
	var partial: Array = nav._astar(Vector2i(0, 4), Vector2i(15, 4), true)
	ok = _check("nearest mode: the route ends at the closest reachable node", partial.back() if not partial.is_empty() else null, Vector2i(7, 4)) and ok
	nav.set_path_strategy("balanced")
	nav.set("max_search_nodes", 2)
	ok = _check("a 2-node search cap gives up", nav._astar(Vector2i(0, 4), Vector2i(15, 4)), []) and ok
	ok = _check("and says max_nodes_reached", nav.get("_last_search_fail"), "max_nodes_reached") and ok
	nav.set("max_search_nodes", 2000)
	nav.free()
	map.free()
	return ok


# ── Routes, smoothing, ledges, platforms, patrol, side goals, enabled ───────────────
static func _routes_and_platforms(script: GDScript) -> bool:
	var ok: bool = true
	var map: TileMapLayer = _classic_map()
	var body: CharacterBody2D = CharacterBody2D.new()
	body.position = Vector2(16.0, 144.0)
	var nav: Node = script.new()
	body.add_child(nav)
	nav.set("host", body)
	nav.build_nav_graph(map)
	ok = _check("graph node count", nav.graph_node_count(), 14) and ok
	ok = _check("first link of the stair top walks down-left", nav.graph_node_connection_kind(4, 3, 0), "walk") and ok
	ok = _check("and lands on (3, 4)'s centre", nav.graph_node_connection_target(4, 3, 0), Vector2(112.0, 144.0)) and ok
	ok = _check("world_to_grid", nav.world_to_grid(240.0, 150.0), Vector2i(7, 4)) and ok
	ok = _check("grid_to_world", nav.grid_to_world(7, 4), Vector2(240.0, 144.0)) and ok
	ok = _check("the gap's near edge is a right ledge", nav.ledge_side(7, 4), 1) and ok
	ok = _check("the floor's far end is a left ledge", nav.ledge_side(0, 4), -1) and ok
	ok = _check("the stair top is no ledge", nav.ledge_side(4, 3), 0) and ok
	ok = _check("the agent can walk to the gap's edge", nav.is_position_on_same_platform(240.0, 144.0), true) and ok
	ok = _check("but not across it", nav.is_position_on_same_platform(330.0, 144.0), false) and ok
	ok = _check("nearest ledge to the right", nav.nearest_ledge("right"), Vector2(240.0, 144.0)) and ok
	# One route, smoothed: the flat runs collapse, the stair's up and down legs stay.
	nav.find_path_to(240.0, 144.0, "reach")
	ok = _check("smoothed route waypoints", [nav.waypoint_count(), nav.waypoint_cell(1), nav.waypoint_cell(2), nav.waypoint_cell(4)], [5, Vector2i(3, 4), Vector2i(4, 3), Vector2i(7, 4)]) and ok
	ok = _check("path cost (5 flat + 2 diagonal steps)", snappedf(nav.path_cost(), 0.001), 7.828) and ok
	ok = _check("path end", nav.path_end(), Vector2(240.0, 144.0)) and ok
	ok = _check("path goal cell", nav.path_goal_cell(), Vector2i(7, 4)) and ok
	ok = _check("waypoint action of the stair climb", nav.waypoint_action(2), "walk") and ok
	nav.set("smooth_paths", false)
	nav.find_path_to(240.0, 144.0, "reach")
	ok = _check("unsmoothed: one waypoint per cell", nav.waypoint_count(), 8) and ok
	nav.set("smooth_paths", true)
	nav.find_path_to(500.0, 900.0, "reach")
	ok = _check("reach mode on nothing fails with a reason", [nav.has_path(), nav.path_fail_reason()], [false, "no_goal_node"]) and ok
	# Side-of-node: two px clear of a node standing on (7, 4) means the cell to its left.
	var post: Node2D = Node2D.new()
	post.position = Vector2(240.0, 144.0)
	nav.find_path_to_node_side(post, "left", 0.0)
	ok = _check("side goal: the cell left of the node", nav.path_goal_cell(), Vector2i(6, 4)) and ok
	ok = _check("side goal: the last waypoint lands exactly one tile clear", nav.path_end(), Vector2(208.0, 144.0)) and ok
	post.free()
	# Patrol: the platform runs from (0, 4) to (7, 4); the far end goes first.
	nav.start_patrol(0.5, 0.0)
	ok = _check("patrol is running", nav.is_patrolling(), true) and ok
	ok = _check("patrol walks right first (the far end)", nav.patrol_direction(), 1) and ok
	ok = _check("patrol's route ends on the right end", nav.path_goal_cell(), Vector2i(7, 4)) and ok
	nav.find_path_to(16.0, 144.0, "nearest")
	ok = _check("any route request ends the patrol", nav.is_patrolling(), false) and ok
	nav.start_patrol(0.0, 0.0)
	nav.stop_patrol()
	ok = _check("Stop Patrol ends it", [nav.is_patrolling(), nav.has_path()], [false, false]) and ok
	nav.set_enabled(false)
	nav.find_path_to(240.0, 144.0, "reach")
	ok = _check("disabled: route requests are ignored", [nav.is_enabled(), nav.has_path()], [false, false]) and ok
	nav.set_enabled(true)
	nav.teleport_to(48.0, 144.0)
	ok = _check("teleport moves the host", body.position, Vector2(48.0, 144.0)) and ok
	body.free()
	map.free()
	return ok


# ── Crowd claims and shared map tags ─────────────────────────────────────────────────
static func _crowds_and_tags(script: GDScript) -> bool:
	var ok: bool = true
	var map: TileMapLayer = _classic_map()
	var first: Array = _agent(script, map, Vector2(16.0, 144.0))
	var second: Array = _agent(script, map, Vector2(16.0, 144.0))
	var nav_a: Node = first[1]
	var nav_b: Node = second[1]
	nav_a.set_crowd_arrivals(true)
	nav_b.set_crowd_arrivals(true)
	nav_a.find_path_to(240.0, 144.0, "reach")
	nav_b.find_path_to(240.0, 144.0, "reach")
	ok = _check("first arrival claims the goal node", nav_a.path_goal_cell(), Vector2i(7, 4)) and ok
	ok = _check("second arrival takes the free node beside it", nav_b.path_goal_cell(), Vector2i(6, 4)) and ok
	nav_a.stop_pathfinding()
	nav_b.find_path_to(240.0, 144.0, "reach")
	ok = _check("a released claim is free again", nav_b.path_goal_cell(), Vector2i(7, 4)) and ok
	(first[0] as Node).free()
	(second[0] as Node).free()
	# Map tags: the second agent on a tag reuses the first one's graph, portals included.
	var tagged_a: Node = script.new()
	var tagged_b: Node = script.new()
	tagged_a.set("map_tag", "test_pack")
	tagged_b.set("map_tag", "test_pack")
	tagged_a.build_nav_graph(map)
	tagged_b.build_nav_graph(map)
	ok = _check("same tag: ONE graph object", is_same(tagged_a.get("_nodes"), tagged_b.get("_nodes")), true) and ok
	tagged_a.add_portal(16.0, 144.0, 432.0, 80.0, false)
	ok = _check("same tag: a portal added by one routes for the other", _kind(tagged_b, Vector2i(0, 4), Vector2i(13, 2)), "portal") and ok
	var loner: Node = script.new()
	loner.build_nav_graph(map)
	ok = _check("no tag: an agent keeps its own graph", is_same(loner.get("_nodes"), tagged_a.get("_nodes")), false) and ok
	(tagged_a.get("_shared_maps") as Dictionary).erase("test_pack")
	tagged_a.free()
	tagged_b.free()
	loner.free()
	map.free()
	return ok


# ── Portals: ids, tags, gradual links, elevators, removal ───────────────────────────
static func _portals(script: GDScript) -> bool:
	var ok: bool = true
	var map: TileMapLayer = _classic_map()
	var nav: Node = script.new()
	nav.build_nav_graph(map)
	nav.add_instant_portal(16.0, 144.0, 432.0, 80.0, true, 3.0, "door,east")
	var door: int = nav.last_portal_id()
	ok = _check("the first portal is id 1", door, 1) and ok
	ok = _check("instant portal link", _kind(nav, Vector2i(0, 4), Vector2i(13, 2)), "portal") and ok
	ok = _check("its cost scales the base of 2", _edge(nav, Vector2i(0, 4), Vector2i(13, 2))["cost"], 6.0) and ok
	ok = _check("portal type", nav.portal_type(door), "instant") and ok
	ok = _check("tags match by token", [nav.portal_count_by_tag("door"), nav.portal_count_by_tag("east"), nav.portal_count_by_tag("doo")], [1, 1, 0]) and ok
	nav.add_gradual_portal(48.0, 144.0, 464.0, 80.0, false, 100.0, 1.0, "lift")
	var lift: int = nav.last_portal_id()
	ok = _check("gradual portal link", _kind(nav, Vector2i(1, 4), Vector2i(14, 2)), "portal_gradual") and ok
	ok = _check("gradual portal type", nav.portal_type(lift), "gradual") and ok
	ok = _check("nearest portal to the floor's start", nav.nearest_portal_id(10.0, 144.0, ""), door) and ok
	ok = _check("nearest portal tagged lift", nav.nearest_portal_id(10.0, 144.0, "lift"), lift) and ok
	ok = _check("furthest portal", nav.furthest_portal_id(10.0, 144.0, ""), lift) and ok
	ok = _check("portal id by tag", [nav.portal_id_by_tag("lift", 0), nav.portal_id_by_tag("lift", 1)], [lift, -1]) and ok
	nav.set_portal_position(door, 16.0, 144.0, 208.0, 144.0)
	ok = _check("a moved portal re-links", [_kind(nav, Vector2i(0, 4), Vector2i(13, 2)), _kind(nav, Vector2i(0, 4), Vector2i(6, 4))], ["", "portal"]) and ok
	nav.remove_portal(door)
	ok = _check("Remove Portal unlinks it at once", [nav.portal_count(), _kind(nav, Vector2i(0, 4), Vector2i(6, 4))], [1, ""]) and ok
	nav.remove_portals_by_tag("lift")
	ok = _check("Remove Portals By Tag", nav.portal_count(), 0) and ok
	nav.add_elevator_stop("tower", 16.0, 144.0, 120.0, "")
	nav.add_elevator_stop("tower", 432.0, 80.0, 120.0, "")
	nav.add_elevator_stop("tower", 496.0, 144.0, 120.0, "")
	ok = _check("three elevator stops link pairwise (three portals)", nav.portal_count(), 3) and ok
	ok = _check("elevator links are gradual and two-way", [_kind(nav, Vector2i(0, 4), Vector2i(13, 2)), _kind(nav, Vector2i(13, 2), Vector2i(0, 4))], ["portal_gradual", "portal_gradual"]) and ok
	nav.clear_portals()
	ok = _check("Clear Portals clears elevators too", nav.portal_count(), 0) and ok
	nav.free()
	map.free()
	return ok


# ── Hazards: circles, tracked nodes, removal, levels and margins ───────────────────
static func _hazards(script: GDScript) -> bool:
	var ok: bool = true
	var map: TileMapLayer = _classic_map()
	var nav: Node = script.new()
	nav.build_nav_graph(map)
	nav.add_circle_hazard(272.0, 120.0, 80.0, true)
	ok = _check("a deadly circle over the gap severs the crossing", nav._astar(Vector2i(0, 4), Vector2i(15, 4)), []) and ok
	ok = _check("hazard levels: deadly / clear", [nav.hazard_at(272.0, 120.0), nav.hazard_at(16.0, 144.0)], [2, 0]) and ok
	nav.remove_hazard(nav.last_hazard_id())
	ok = _check("Remove Hazard restores the crossing", nav._astar(Vector2i(0, 4), Vector2i(15, 4)).is_empty(), false) and ok
	var saw: Node2D = Node2D.new()
	saw.position = Vector2(16.0, 144.0)
	nav.add_tracked_hazard(saw, 10.0, false)
	ok = _check("a tracked hazard follows its node", [nav.hazard_at(16.0, 144.0), nav.tracked_hazard_count()], [1, 1]) and ok
	saw.position = Vector2(400.0, 144.0)
	ok = _check("and moves with it", [nav.hazard_at(16.0, 144.0), nav.hazard_at(400.0, 144.0)], [0, 1]) and ok
	saw.free()
	nav._prune_tracked_hazards()
	ok = _check("a freed node's hazard is pruned", nav.hazard_count(), 0) and ok
	nav.add_hazard(0.0, 0.0, 10.0, 10.0, false)
	ok = _check("no margin: just outside is clear", nav.hazard_at(20.0, 5.0), 0) and ok
	nav.set_hazard_margin(16.0)
	ok = _check("a 16px margin makes it danger", nav.hazard_at(20.0, 5.0), 1) and ok
	ok = _check("Is Position Hazardous ignores the margin", nav.is_position_hazardous(20.0, 5.0), false) and ok
	nav.free()
	map.free()
	return ok


# ── Custom obstacle maps, JSON round trip, body scanning, clearing ─────────────────
static func _obstacle_maps(script: GDScript) -> bool:
	var ok: bool = true
	var nav: Node = script.new()
	nav.create_obstacle_map(10, 6, 16.0)
	for x in range(0, 10):
		nav.set_tile_state(x, 5, "solid")
	nav.set_tile_state(4, 2, "jump_thru")
	nav.regenerate_nav_graph()
	ok = _check("custom map source", nav.obstacle_map_source(), "custom") and ok
	ok = _check("custom map size + cell size", [nav.grid_size(), nav.grid_tile_size()], [Vector2i(10, 6), 16.0]) and ok
	ok = _check("custom floor nodes", [nav.graph_node_exists(3, 4), nav.graph_node_exists(4, 1)], [true, true]) and ok
	ok = _check("custom cell to world", nav.grid_to_world(3, 4), Vector2(56.0, 72.0)) and ok
	ok = _check("outside a custom map reads empty", nav.tile_state(20, 20), "") and ok
	ok = _check("the one-way cell drops through", _kind(nav, Vector2i(4, 1), Vector2i(4, 4)), "fall_through") and ok
	var json: String = nav.obstacle_map_json()
	var copy: Node = script.new()
	copy.load_obstacle_map_json(json)
	ok = _check("JSON round trip: same nodes", [copy.graph_node_count(), copy.graph_node_exists(4, 1), copy.tile_state(4, 2)], [nav.graph_node_count(), true, "jump_thru"]) and ok
	ok = _check("JSON round trip: same JSON", copy.obstacle_map_json(), json) and ok
	copy.free()
	# Body scanning: a 64x16 one-way StaticBody2D at cells (6..9, 1) and a solid one under it.
	var level: Node2D = Node2D.new()
	level.add_child(_body(Vector2(128.0, 24.0), Vector2(64.0, 16.0), true))
	level.add_child(_body(Vector2(136.0, 72.0), Vector2(16.0, 16.0), false))
	nav.scan_collision_bodies(level)
	nav.regenerate_nav_graph()
	ok = _check("a one-way body scans as jump_thru", [nav.tile_state(6, 1), nav.tile_state(9, 1), nav.tile_state(5, 1)], ["jump_thru", "jump_thru", "clear"]) and ok
	ok = _check("a solid body scans as solid", nav.tile_state(8, 4), "solid") and ok
	ok = _check("its top is standable", nav.graph_node_exists(8, 3), true) and ok
	level.free()
	nav.clear_nav_graph()
	ok = _check("Clear Nav Graph drops everything", [nav.obstacle_map_source(), nav.graph_node_count(), nav.tile_state(0, 5)], ["none", 0, ""]) and ok
	nav.free()
	return ok


# ── Fixtures ──────────────────────────────────────────────────────────────────────────


## The classic test level: floor y=5 x 0..15 with a gap at x=8..9; a stair tile at (4,4); a
## platform y=3 x 12..14.
static func _classic_map() -> TileMapLayer:
	var map: TileMapLayer = _make_map()
	for x in range(0, 16):
		if x != 8 and x != 9:
			map.set_cell(Vector2i(x, 5), 0, Vector2i(0, 0))
	map.set_cell(Vector2i(4, 4), 0, Vector2i(0, 0))
	for x in range(12, 15):
		map.set_cell(Vector2i(x, 3), 0, Vector2i(0, 0))
	return map


## A 32px TileSet: atlas (0,0) a full block, (1,0) a ONE-WAY block, (2,0) a "/" slope.
static func _make_map() -> TileMapLayer:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	tile_set.add_physics_layer()
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	var image: Image = Image.create(96, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(32, 32)
	tile_set.add_source(source, 0)
	var full: PackedVector2Array = PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)])
	var shapes: Array = [full, full, PackedVector2Array([Vector2(-16, 16), Vector2(16, -16), Vector2(16, 16)])]
	for index in range(3):
		source.create_tile(Vector2i(index, 0))
		var tile_data: TileData = source.get_tile_data(Vector2i(index, 0), 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, shapes[index])
		if index == 1:
			tile_data.set_collision_polygon_one_way(0, 0, true)
	var map: TileMapLayer = TileMapLayer.new()
	map.tile_set = tile_set
	return map


## [body, behavior] - a CharacterBody2D at a position with the pack attached and built.
static func _agent(script: GDScript, map: TileMapLayer, at: Vector2) -> Array:
	var body: CharacterBody2D = CharacterBody2D.new()
	body.position = at
	var nav: Node = script.new()
	body.add_child(nav)
	nav.set("host", body)
	nav.build_nav_graph(map)
	return [body, nav]


static func _body(at: Vector2, size: Vector2, one_way: bool) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = at
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	shape.one_way_collision = one_way
	body.add_child(shape)
	return body


static func _edge(behavior: Node, from_cell: Vector2i, to_cell: Vector2i) -> Dictionary:
	for edge in (behavior.get("_edges").get(from_cell, []) as Array):
		if edge["to"] == to_cell:
			return edge
	return {}


static func _kind(behavior: Node, from_cell: Vector2i, to_cell: Vector2i) -> String:
	return str(_edge(behavior, from_cell, to_cell).get("kind", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("platformer_pathfinding_links_test", label, actual, expected)
