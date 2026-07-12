# Godot EventSheets - Platformer Pathfinding pack (graph build + A* routing).
#
# Loads the COMPILED pack and builds a real TileMapLayer level (a floor with a gap, a two-step
# stair, and a raised platform), then pins the GRAPH: which cells become standable nodes, that
# stairs connect through WALK edges (one step up), that the gap and the platform connect through
# JUMP arcs sized by the derived reach, and that A* routes across all of it. Values are pinned
# (specific cells and edge kinds), not counts. World-position driving needs a scene tree +
# stepped physics - that half is verified live in the path_chase showcase.
@tool
class_name PlatformerPathfindingTest
extends RefCounted

const PACK := "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("pathfinding pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	# ── The level (cells; tile size 32) ─────────────────────────────────────────────
	#   floor y=5 x 0..15 with a gap at x=8..9; a stair tile at (4,4); a platform y=3 x 12..14
	#   (low enough that the floor beneath it loses its headroom).
	var map: TileMapLayer = _make_map()
	for x in range(0, 16):
		if x != 8 and x != 9:
			map.set_cell(Vector2i(x, 5), 0, Vector2i.ZERO)
	map.set_cell(Vector2i(4, 4), 0, Vector2i.ZERO)
	for x in range(12, 15):
		map.set_cell(Vector2i(x, 3), 0, Vector2i.ZERO)

	var behavior: Node = script.new()
	behavior.build_nav_graph(map)
	var nodes: Dictionary = behavior.get("_nodes")

	# ── Standable nodes ────────────────────────────────────────────────────────────
	all_passed = _check("floor cells are standable", nodes.has(Vector2i(0, 4)) and nodes.has(Vector2i(15, 4)), true) and all_passed
	all_passed = _check("the gap is NOT standable", nodes.has(Vector2i(8, 4)) or nodes.has(Vector2i(9, 4)), false) and all_passed
	all_passed = _check("the stair top is standable", nodes.has(Vector2i(4, 3)), true) and all_passed
	all_passed = _check("the stair tile blocks standing on the floor below it", nodes.has(Vector2i(4, 4)), false) and all_passed
	all_passed = _check("the platform is standable", nodes.has(Vector2i(13, 2)), true) and all_passed
	all_passed = _check("under the platform there is no headroom", nodes.has(Vector2i(13, 4)), false) and all_passed

	# ── Edges: stairs walk, gaps jump ──────────────────────────────────────────────
	all_passed = _check("stepping UP the stair is a walk edge", _edge_kind(behavior, Vector2i(3, 4), Vector2i(4, 3)), "walk") and all_passed
	all_passed = _check("stepping DOWN the stair is a walk edge", _edge_kind(behavior, Vector2i(4, 3), Vector2i(5, 4)), "walk") and all_passed
	all_passed = _check("crossing the gap is a jump arc", _edge_kind(behavior, Vector2i(7, 4), Vector2i(10, 4)), "jump") and all_passed
	all_passed = _check("no walk edge across the gap", _edge_kind(behavior, Vector2i(7, 4), Vector2i(8, 4)), "") and all_passed
	all_passed = _check("jumping up to the platform is a jump arc", _edge_kind(behavior, Vector2i(11, 4), Vector2i(12, 2)), "jump") and all_passed
	all_passed = _check("dropping off the platform is a fall edge", _edge_kind(behavior, Vector2i(12, 2), Vector2i(11, 4)), "fall") and all_passed

	# ── A*: routes exist and use the right connections ────────────────────────────
	var across: Array = behavior._astar(Vector2i(0, 4), Vector2i(15, 4))
	all_passed = _check("A* crosses the whole floor (gap included)", not across.is_empty(), true) and all_passed
	all_passed = _check("the route starts and ends where asked",
		not across.is_empty() and across.front() == Vector2i(0, 4) and across.back() == Vector2i(15, 4), true) and all_passed
	var jumped_gap: bool = false
	for index in range(1, across.size()):
		if absi((across[index] as Vector2i).x - (across[index - 1] as Vector2i).x) > 1:
			jumped_gap = true
	all_passed = _check("the route jumps the gap (a >1-cell hop is on the path)", jumped_gap, true) and all_passed
	var up_top: Array = behavior._astar(Vector2i(0, 4), Vector2i(13, 2))
	all_passed = _check("A* reaches the raised platform", not up_top.is_empty() and up_top.back() == Vector2i(13, 2), true) and all_passed
	all_passed = _check("an unreachable goal returns an empty route", behavior._astar(Vector2i(0, 4), Vector2i(30, 30)).is_empty(), true) and all_passed

	# ── Portals: linked into the graph, surviving regenerate, cleared on demand ───
	behavior.add_portal(16.0, 144.0, 432.0, 80.0, true)
	all_passed = _check("a portal links its endpoints' nearest nodes", _edge_kind(behavior, Vector2i(0, 4), Vector2i(13, 2)), "portal") and all_passed
	all_passed = _check("bidirectional portals link back too", _edge_kind(behavior, Vector2i(13, 2), Vector2i(0, 4)), "portal") and all_passed
	behavior.regenerate_nav_graph()
	all_passed = _check("portals survive Regenerate Nav Graph", _edge_kind(behavior, Vector2i(0, 4), Vector2i(13, 2)), "portal") and all_passed
	var through_portal: Array = behavior._astar(Vector2i(0, 4), Vector2i(13, 2))
	all_passed = _check("A* takes the portal shortcut (start straight to goal)", through_portal, [Vector2i(0, 4), Vector2i(13, 2)]) and all_passed
	behavior.clear_portals()
	all_passed = _check("Clear Portals removes the link", _edge_kind(behavior, Vector2i(0, 4), Vector2i(13, 2)), "") and all_passed

	# ── The universal AI drive seam: every input-reading movement pack carries it ─
	all_passed = _check("variable jump ships on (toggleable)", behavior.get("variable_jump"), true) and all_passed
	all_passed = _check("the fallback driver knobs exist", behavior.get("fallback_move_speed") != null and behavior.get("fallback_jump_velocity") != null and behavior.get("fallback_gravity") != null, true) and all_passed
	var seam_specs: Array = [
		["res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd", ["ai_controlled", "ai_move_axis"]],
		["res://eventsheet_addons/eight_direction/eight_direction_movement_behavior.gd", ["ai_controlled", "ai_move_x", "ai_move_y"]],
		["res://eventsheet_addons/fps_controller/fps_controller_behavior.gd", ["ai_controlled", "ai_move_x", "ai_move_z"]],
	]
	for seam_spec: Array in seam_specs:
		var pack_script: GDScript = load(str(seam_spec[0]))
		var pack_instance: Node = pack_script.new()
		for seam_var: String in (seam_spec[1] as Array):
			all_passed = _check("%s carries the %s seam" % [str(seam_spec[0]).get_file(), seam_var], pack_instance.get(seam_var) != null, true) and all_passed
		all_passed = _check("%s seam is INERT by default" % str(seam_spec[0]).get_file(), pack_instance.get("ai_controlled"), false) and all_passed
		pack_instance.free()

	# ── Derived reach with no movement sibling comes from the fallback driver knobs
	# (speed 200, jump -400, gravity 980 -> 147px across, 73px up -> 5 x 3 cells).
	var reach: Vector2i = behavior._jump_reach_cells()
	all_passed = _check("fallback jump reach derives from the fallback knobs (5 across, 3 up)", reach, Vector2i(5, 3)) and all_passed

	# ── The pack's public surface exists ───────────────────────────────────────────
	for method_name: String in ["build_nav_graph", "regenerate_nav_graph", "find_path_to", "find_path_to_node", "stop_pathfinding", "set_auto_control", "set_nav_debug_draw", "has_path", "path_wants_jump", "path_move_axis", "waypoint_count", "current_waypoint_x", "current_waypoint_y", "current_path_action"]:
		all_passed = _check("method %s exists" % method_name, behavior.has_method(method_name), true) and all_passed
	for signal_name: String in ["path_found", "path_failed", "path_complete", "waypoint_reached", "nav_graph_built"]:
		all_passed = _check("signal %s exists" % signal_name, behavior.has_signal(signal_name), true) and all_passed

	behavior.free()
	map.free()
	return all_passed


## A 32px TileSet with one full-square physics tile at atlas (0,0), source id 0.
static func _make_map() -> TileMapLayer:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	tile_set.add_physics_layer()
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(32, 32)
	# The source must join the TileSet BEFORE tile data is configured - a detached source's
	# TileData does not know the set's physics layers, so add_collision_polygon(0) errors.
	tile_set.add_source(source, 0)
	source.create_tile(Vector2i.ZERO)
	var tile_data: TileData = source.get_tile_data(Vector2i.ZERO, 0)
	tile_data.add_collision_polygon(0)
	tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]))
	var map: TileMapLayer = TileMapLayer.new()
	map.tile_set = tile_set
	return map


static func _edge_kind(behavior: Node, from_cell: Vector2i, to_cell: Vector2i) -> String:
	for edge in (behavior.get("_edges").get(from_cell, []) as Array):
		if edge["to"] == to_cell:
			return str(edge["kind"])
	return ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] platformer_pathfinding_test: %s" % label)
		return true
	print("[FAIL] platformer_pathfinding_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
