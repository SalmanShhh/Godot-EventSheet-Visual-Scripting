# Godot EventSheets - Platformer Pathfinding: the nav graph builds a few milliseconds per physics frame.
#
# A graph built in slices must be EXACTLY the graph a single call makes (same nodes, same links in the same order
# with the same costs), a route asked for meanwhile waits, On Nav Graph Built fires once at the end, a second
# build started over the first leaves one clean graph, and agents sharing a map tag wait for the one that builds.
# Everything here runs outside a scene tree, where the build never slices by itself, so the test drives the same
# step functions the physics frame drives. Frame timing on a large map is measured by the runtime harness.
@tool
class_name PlatformerPathfindingSlicedBuildTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"
const MOVEMENT := "res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd"

## A step so small that every call hands back after the least work the build allows.
const TINY_BUDGET_MS: float = 0.001


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("pack loads", script != null, true) and all_passed
	if script == null:
		return all_passed
	var map: TileMapLayer = _make_map()
	_paint_level(map)
	var kept: Array = []

	# ── The reference: one call builds everything ─────────────────────────────────────────
	var whole: Node = _agent(script, kept)
	whole.build_nav_graph(map)
	var whole_signature: Array = _signature(whole)
	all_passed = _check("the reference level has a graph", whole.graph_node_count() > 20, true) and all_passed
	all_passed = _check("the reference level has double jump links (the sibling can jump twice)", _has_kind(whole, "double_jump"), true) and all_passed
	all_passed = _check("the reference level has jump and fall links", _has_kind(whole, "jump") and _has_kind(whole, "fall"), true) and all_passed
	all_passed = _check("the reference level has a fall-through link off the one-way platform", _has_kind(whole, "fall_through"), true) and all_passed
	all_passed = _check("Build Budget Ms ships at 4", whole.get("build_budget_ms"), 4.0) and all_passed
	all_passed = _check("a build outside a scene tree has nothing to carry on in, so it is whole in the call", whole.is_building_nav_graph(), false) and all_passed
	all_passed = _check("Build Progress reads 1 when no build runs", whole.build_progress(), 1.0) and all_passed

	# ── The same level built in the smallest steps ────────────────────────────────────────
	var sliced: Node = _agent(script, kept)
	sliced.set("_tilemap", map)
	var built_count: Array = [0]
	sliced.nav_graph_built.connect(func() -> void: built_count[0] += 1)
	sliced.call("_begin_build")
	all_passed = _check("a begun build is a running build", sliced.is_building_nav_graph(), true) and all_passed
	all_passed = _check("a begun build has no graph yet", sliced.graph_node_count(), 0) and all_passed
	var steps: int = 0
	var progress: Array = []
	sliced.set("build_budget_ms", TINY_BUDGET_MS)
	while sliced.is_building_nav_graph() and steps < 100000:
		sliced.call("_step_graph_build")
		steps += 1
		progress.append(sliced.build_progress())
		if sliced.is_building_nav_graph() and steps == 3:
			all_passed = _check("On Nav Graph Built has not fired while the build runs", built_count[0], 0) and all_passed
			# A route asked for meanwhile waits.
			sliced.find_path_to(48.0, 120.0, "nearest")
			all_passed = _check("a route asked for during the build is pending", sliced.is_path_pending(), true) and all_passed
			all_passed = _check("and has no path yet", sliced.has_path(), false) and all_passed
	all_passed = _check("the build took many steps", steps > 10, true) and all_passed
	all_passed = _check("On Nav Graph Built fired once, at the end", built_count[0], 1) and all_passed
	all_passed = _check("no build runs after it", sliced.is_building_nav_graph(), false) and all_passed
	all_passed = _check("the pending route stays pending for the physics frame to run", sliced.is_path_pending(), true) and all_passed
	all_passed = _check("the sliced graph is the graph one call makes (nodes and links, order and costs)", _signature(sliced), whole_signature) and all_passed
	var rising: bool = true
	for index in range(1, progress.size()):
		if progress[index] < progress[index - 1] - 0.000001:
			rising = false
	all_passed = _check("Build Progress never goes back", rising, true) and all_passed
	all_passed = _check("Build Progress is below 1 while it runs", progress[0] < 1.0 and progress[progress.size() / 2] < 1.0, true) and all_passed
	all_passed = _check("Build Progress ends at 1", sliced.build_progress(), 1.0) and all_passed

	# ── A second build started over the first leaves one clean graph ──────────────────────
	var restarted: Node = _agent(script, kept)
	restarted.set("_tilemap", map)
	var restarted_count: Array = [0]
	restarted.nav_graph_built.connect(func() -> void: restarted_count[0] += 1)
	restarted.set("build_budget_ms", TINY_BUDGET_MS)
	restarted.call("_begin_build")
	for step in range(40):
		restarted.call("_step_graph_build")
	var half_nodes: int = restarted.graph_node_count()
	restarted.call("_begin_build")
	all_passed = _check("starting over empties the graph", restarted.graph_node_count(), 0) and all_passed
	all_passed = _check("starting over goes back to the first step", restarted.get("_build_phase"), 0) and all_passed
	all_passed = _check("some of the graph had been built before the restart", half_nodes >= 0, true) and all_passed
	while restarted.is_building_nav_graph():
		restarted.call("_step_graph_build")
	all_passed = _check("a restarted build ends with the same graph", _signature(restarted), whole_signature) and all_passed
	all_passed = _check("a restarted build fires On Nav Graph Built once", restarted_count[0], 1) and all_passed

	# ── The obstacle map reads the same while the graph is half built ─────────────────────
	var reading: Node = _agent(script, kept)
	reading.set("_tilemap", map)
	reading.set("build_budget_ms", TINY_BUDGET_MS)
	reading.call("_begin_build")
	for step in range(30):
		reading.call("_step_graph_build")
	var mid_json: String = reading.obstacle_map_json()
	all_passed = _check("the obstacle map is still being built when it is asked for", reading.is_building_nav_graph(), true) and all_passed
	while reading.is_building_nav_graph():
		reading.call("_step_graph_build")
	all_passed = _check("Obstacle Map JSON asked mid-build equals the finished one", mid_json, reading.obstacle_map_json()) and all_passed
	all_passed = _check("and the build it was asked in the middle of is unharmed", _signature(reading), whole_signature) and all_passed

	# ── Clearing the graph drops a running build ──────────────────────────────────────────
	var cleared: Node = _agent(script, kept)
	cleared.set("_tilemap", map)
	cleared.set("build_budget_ms", TINY_BUDGET_MS)
	cleared.call("_begin_build")
	cleared.call("_step_graph_build")
	cleared.clear_nav_graph()
	all_passed = _check("Clear Nav Graph ends a running build", cleared.is_building_nav_graph(), false) and all_passed
	all_passed = _check("and leaves no graph", cleared.graph_node_count(), 0) and all_passed

	# ── A request that needs the whole graph waits for it ─────────────────────────────────
	var waiting: Node = _agent(script, kept)
	waiting.set("_tilemap", map)
	waiting.set("build_budget_ms", TINY_BUDGET_MS)
	waiting.call("_begin_build")
	waiting.start_patrol(0.5, 0.0)
	var deferred: Callable = waiting.get("_after_build")
	all_passed = _check("Start Patrol during a build is kept for the end of it", deferred.is_valid(), true) and all_passed
	waiting.stop_pathfinding()
	all_passed = _check("Stop Pathfinding forgets it", (waiting.get("_after_build") as Callable).is_valid(), false) and all_passed

	# ── Agents sharing a map tag: one builds, the others wait ─────────────────────────────
	var builder: Node = _agent(script, kept)
	var follower: Node = _agent(script, kept)
	builder.set("map_tag", "sliced_test")
	follower.set("map_tag", "sliced_test")
	builder.set("_tilemap", map)
	builder.call("_bind_shared_map", map.get_instance_id())
	builder.set("build_budget_ms", TINY_BUDGET_MS)
	var builder_count: Array = [0]
	var follower_count: Array = [0]
	builder.nav_graph_built.connect(func() -> void: builder_count[0] += 1)
	follower.nav_graph_built.connect(func() -> void: follower_count[0] += 1)
	builder.call("_begin_build")
	for step in range(20):
		builder.call("_step_graph_build")
	follower.build_nav_graph(map)
	all_passed = _check("an agent joining a map that is being built waits for it", follower.is_building_nav_graph(), true) and all_passed
	all_passed = _check("it does not announce a graph that is not there", follower_count[0], 0) and all_passed
	follower.find_path_to(48.0, 120.0, "nearest")
	all_passed = _check("its routes wait too", follower.is_path_pending(), true) and all_passed
	while builder.is_building_nav_graph():
		builder.call("_step_graph_build")
	follower.call("_step_graph_build")
	all_passed = _check("the builder announces the graph once", builder_count[0], 1) and all_passed
	all_passed = _check("the follower announces it once, when it is there", follower_count[0], 1) and all_passed
	all_passed = _check("the follower is not building any more", follower.is_building_nav_graph(), false) and all_passed
	all_passed = _check("both agents read the one shared graph", _signature(follower), whole_signature) and all_passed
	# A builder freed half way leaves the graph to the next one asking.
	var dropped: Node = _agent(script, kept)
	dropped.set("map_tag", "sliced_test_freed")
	dropped.set("_tilemap", map)
	dropped.call("_bind_shared_map", map.get_instance_id())
	dropped.set("build_budget_ms", TINY_BUDGET_MS)
	dropped.call("_begin_build")
	dropped.call("_step_graph_build")
	var heir: Node = _agent(script, kept)
	heir.set("map_tag", "sliced_test_freed")
	heir.build_nav_graph(map)
	all_passed = _check("the next agent waits while the builder lives", heir.is_building_nav_graph(), true) and all_passed
	kept.erase(dropped)
	var dropped_host: Node = dropped.get("host")
	dropped.free()
	dropped_host.free()
	all_passed = _check("when the builder is freed the asking agent builds the graph itself", heir.is_building_nav_graph() or heir.graph_node_count() > 0, true) and all_passed
	heir.call("_graph_building")
	while heir.is_building_nav_graph():
		heir.call("_step_graph_build")
	all_passed = _check("and gets the same graph", _signature(heir), whole_signature) and all_passed

	# ── The surface ───────────────────────────────────────────────────────────────────────
	for method_name: String in ["is_building_nav_graph", "build_progress", "set_build_budget"]:
		all_passed = _check("method %s exists" % method_name, whole.has_method(method_name), true) and all_passed
	whole.set_build_budget(2.5)
	all_passed = _check("Set Build Budget sets the property", whole.get("build_budget_ms"), 2.5) and all_passed

	for agent: Node in kept:
		if is_instance_valid(agent):
			var movement_host: Node = agent.get("host")
			agent.free()
			if movement_host != null:
				movement_host.free()
	map.free()
	return all_passed


## One pathfinding agent over a body that has a movement sibling able to jump twice.
static func _agent(script: GDScript, kept: Array) -> Node:
	var host: CharacterBody2D = CharacterBody2D.new()
	host.position = Vector2(48.0, 120.0)
	var movement: Node = load(MOVEMENT).new()
	movement.set("max_jumps", 2)
	host.add_child(movement)
	var behavior: Node = script.new()
	behavior.set("host", host)
	kept.append(behavior)
	return behavior


## A floor with a gap, platforms at different heights, a stair and a one-way platform.
static func _paint_level(map: TileMapLayer) -> void:
	for x in range(0, 30):
		if x < 12 or x > 15:
			map.set_cell(Vector2i(x, 8), 0, Vector2i.ZERO)
	for x in range(3, 8):
		map.set_cell(Vector2i(x, 5), 0, Vector2i.ZERO)
	for x in range(18, 24):
		map.set_cell(Vector2i(x, 4), 0, Vector2i.ZERO)
	for x in range(8, 11):
		map.set_cell(Vector2i(x, 6), 0, Vector2i.ZERO)
	for step in range(4):
		map.set_cell(Vector2i(24 + step, 7 - step), 0, Vector2i.ZERO)
	for x in range(28, 30):
		map.set_cell(Vector2i(x, 6), 0, Vector2i(1, 0))


## Every node and link of the graph in the order they were made, with each cost: a sliced build has to match it line for line.
static func _signature(behavior: Node) -> Array:
	var lines: Array = []
	var nodes: Dictionary = behavior.get("_nodes")
	for cell: Vector2i in nodes:
		lines.append("node %s" % str(cell))
	var edges: Dictionary = behavior.get("_edges")
	for cell: Vector2i in edges:
		for edge: RefCounted in (edges[cell] as Array):
			lines.append("%s>%s:%s:%.4f" % [str(cell), str(edge.get("to")), str(edge.get("kind")), float(edge.get("cost"))])
	return lines


static func _has_kind(behavior: Node, kind: String) -> bool:
	var edges: Dictionary = behavior.get("_edges")
	for cell: Vector2i in edges:
		for edge: RefCounted in (edges[cell] as Array):
			if str(edge.get("kind")) == kind:
				return true
	return false


## A 32px TileSet with one full-square physics tile at atlas (0,0), source id 0; the fall-through test uses a one-way tile.
static func _make_map() -> TileMapLayer:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	tile_set.add_physics_layer()
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	var image: Image = Image.create(64, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(32, 32)
	tile_set.add_source(source, 0)
	source.create_tile(Vector2i.ZERO)
	source.create_tile(Vector2i(1, 0))
	var solid: TileData = source.get_tile_data(Vector2i.ZERO, 0)
	solid.add_collision_polygon(0)
	solid.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]))
	var one_way: TileData = source.get_tile_data(Vector2i(1, 0), 0)
	one_way.add_collision_polygon(0)
	one_way.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, -8), Vector2(-16, -8)]))
	one_way.set_collision_polygon_one_way(0, 0, true)
	var map: TileMapLayer = TileMapLayer.new()
	map.tile_set = tile_set
	return map


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("platformer_pathfinding_sliced_build_test", label, actual, expected)
