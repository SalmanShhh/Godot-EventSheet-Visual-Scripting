# Godot EventSheets - Platformer Pathfinding parity: hazards from nodes and from cells, the box test that
# finds a hazard narrower than a tile, patrols between markers and their settings, portals and
# elevator stops that follow nodes, the exact portal exit, regenerating one region, and a held route.
#
# Loads the COMPILED pack over a real TileMapLayer level and pins values (cells, edge kinds, ids), not
# counts. Everything here runs outside a scene tree; what needs stepped physics (a patrol walking, a
# lift riding) is proved by the runtime harness on the path_chase scene.
@tool
class_name PlatformerPathfindingParityTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("pack loads", script != null, true) and all_passed
	if script == null:
		return all_passed
	var map: TileMapLayer = _make_map()
	# A floor on row 5 with a gap at x 8..9.
	for x in range(0, 16):
		if x != 8 and x != 9:
			map.set_cell(Vector2i(x, 5), 0, Vector2i.ZERO)
	var behavior: Node = script.new()
	behavior.build_nav_graph(map)

	# ── A hazard narrower than a tile is found, wherever it sits inside the tile ──────────────
	# 6 px wide, placed off the centre of the cell (3, 4): a test at the cell centre alone misses it.
	behavior.add_hazard(96.0 + 2.0, 128.0, 6.0, 30.0, true)
	all_passed = _check("a thin deadly hazard off a cell centre makes the step onto that cell deadly", behavior._segment_hazard(Vector2i(2, 4), Vector2i(3, 4)), 2) and all_passed
	all_passed = _check("the cell beside it stays clear", behavior._segment_hazard(Vector2i(0, 4), Vector2i(1, 4)), 0) and all_passed
	all_passed = _check("a jump that clears the thin hazard is still allowed", behavior._segment_hazard(Vector2i(2, 4), Vector2i(5, 4)), 0) and all_passed
	behavior.clear_hazards()
	all_passed = _check("without the hazard the step is clear", behavior._segment_hazard(Vector2i(2, 4), Vector2i(3, 4)), 0) and all_passed

	# ── Hazard from a node: the bounds of its collision shapes, following the node ────────────
	var spikes: Node2D = Node2D.new()
	var body: StaticBody2D = StaticBody2D.new()
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(20.0, 8.0)
	shape_node.shape = rectangle
	body.add_child(shape_node)
	spikes.add_child(body)
	spikes.position = Vector2(112.0, 144.0)
	behavior.add_hazard_from_node(spikes, true)
	var hazard: RefCounted = behavior.get("_hazards")[0]
	all_passed = _check("a node hazard takes the bounds of its collision shape", hazard.get("rect"), Rect2(102.0, 140.0, 20.0, 8.0)) and all_passed
	all_passed = _check("a node hazard is a hazard (counted, and has an id)", behavior.hazard_count() == 1 and behavior.last_hazard_id() > 0, true) and all_passed
	all_passed = _check("a node hazard counts as a node-following hazard", behavior.tracked_hazard_count(), 1) and all_passed
	all_passed = _check("a deadly node hazard makes the step onto its cell deadly", behavior._segment_hazard(Vector2i(2, 4), Vector2i(3, 4)), 2) and all_passed
	behavior.add_hazard_from_node(spikes, false)
	all_passed = _check("asking again for the same node changes its flag, never stacks a copy", behavior.hazard_count(), 1) and all_passed
	all_passed = _check("a non-deadly node hazard is only danger", behavior._segment_hazard(Vector2i(2, 4), Vector2i(3, 4)), 1) and all_passed
	spikes.position = Vector2(400.0, 144.0)
	behavior._prune_tracked_hazards()
	all_passed = _check("the hazard follows its node when it moves", hazard.get("rect"), Rect2(390.0, 140.0, 20.0, 8.0)) and all_passed
	behavior.remove_hazard_from_node(spikes)
	all_passed = _check("Remove Hazard From Node drops it", behavior.hazard_count(), 0) and all_passed
	behavior.add_hazard_from_node(spikes, true)
	spikes.free()
	behavior._prune_tracked_hazards()
	all_passed = _check("a freed node takes its hazard with it", behavior.hazard_count(), 0) and all_passed

	# ── Set Tile Hazard: one cell, three levels ──────────────────────────────────────────────
	behavior.set_tile_hazard(3, 4, "deadly")
	all_passed = _check("a deadly tile hazard blocks the cell", behavior.is_position_hazardous(112.0, 144.0), true) and all_passed
	all_passed = _check("the tile hazard shows as deadly (2) at its cell", behavior.hazard_at(112.0, 144.0), 2) and all_passed
	behavior.set_tile_hazard(3, 4, "danger")
	all_passed = _check("setting the same cell again replaces the mark (one hazard)", behavior.hazard_count(), 1) and all_passed
	all_passed = _check("a danger tile shows as 1", behavior.hazard_at(112.0, 144.0), 1) and all_passed
	behavior.set_tile_hazard(3, 4, "clear")
	all_passed = _check("clear removes the mark", behavior.hazard_count(), 0) and all_passed

	# ── Hazard ids are unique across agents on one map tag ───────────────────────────────────
	var first: Node = script.new()
	var second: Node = script.new()
	first.set("map_tag", "parity")
	second.set("map_tag", "parity")
	first.build_nav_graph(map)
	second.build_nav_graph(map)
	first.add_hazard(0.0, 0.0, 10.0, 10.0, false)
	second.add_hazard(40.0, 0.0, 10.0, 10.0, false)
	all_passed = _check("two agents on one map never hand out the same hazard id", first.last_hazard_id() != second.last_hazard_id(), true) and all_passed
	first.add_instant_portal(16.0, 144.0, 432.0, 144.0, true, 1.0, "")
	second.add_instant_portal(16.0, 144.0, 432.0, 144.0, true, 1.0, "")
	all_passed = _check("two agents on one map never hand out the same portal id", first.last_portal_id() != second.last_portal_id(), true) and all_passed
	first.free()
	second.free()

	# ── Portals that follow nodes ───────────────────────────────────────────────────────────
	var door_a: Node2D = Node2D.new()
	var door_b: Node2D = Node2D.new()
	door_a.position = Vector2(16.0, 144.0)
	door_b.position = Vector2(432.0, 144.0)
	behavior.add_portal_from_nodes(door_a, door_b, true, "instant", 1.0, 100.0, "doors")
	var portal_id: int = behavior.last_portal_id()
	all_passed = _check("a portal from nodes registers one portal", behavior.portal_count(), 1) and all_passed
	all_passed = _check("it links the nodes' nearest standing cells", _has_link(behavior, Vector2i(0, 4), Vector2i(13, 4), "portal"), true) and all_passed
	door_b.position = Vector2(112.0, 144.0)
	behavior._follow_portal_nodes()
	all_passed = _check("moving the exit node moves the link", _has_link(behavior, Vector2i(0, 4), Vector2i(3, 4), "portal"), true) and all_passed
	all_passed = _check("and the old link is gone", _has_link(behavior, Vector2i(0, 4), Vector2i(13, 4), "portal"), false) and all_passed
	behavior.remove_portal_at_node(door_a)
	all_passed = _check("Remove Portal At Node removes the portal", behavior.portal_count(), 0) and all_passed
	behavior.add_portal_from_nodes(door_a, door_b, true, "gradual", 1.0, 100.0, "")
	door_b.free()
	behavior._follow_portal_nodes()
	all_passed = _check("a portal whose node is freed goes away", behavior.portal_count(), 0) and all_passed
	door_a.free()
	all_passed = _check("portal ids are never reused after a removal", portal_id < behavior.last_portal_id(), true) and all_passed

	# ── Elevator stops that follow nodes ─────────────────────────────────────────────────────
	var low_stop: Node2D = Node2D.new()
	var high_stop: Node2D = Node2D.new()
	low_stop.position = Vector2(16.0, 144.0)
	high_stop.position = Vector2(80.0, 144.0)
	behavior.add_elevator_stop_from_node("lift", low_stop, 120.0, "")
	behavior.add_elevator_stop_from_node("lift", high_stop, 120.0, "")
	all_passed = _check("two follow stops make a two-way gradual portal", behavior.portal_count(), 1) and all_passed
	all_passed = _check("the lift link is a gradual portal", _has_link(behavior, Vector2i(0, 4), Vector2i(2, 4), "portal_gradual"), true) and all_passed
	behavior.remove_portal_at_node(high_stop)
	all_passed = _check("removing a stop's node removes its portals", behavior.portal_count(), 0) and all_passed
	low_stop.free()
	high_stop.free()
	behavior.clear_portals()

	# ── The exit is where the sheet said, not the middle of the nearest node ───────────────────
	behavior.add_portal(16.0, 144.0, 435.0, 150.0, false)
	var waypoint_class: GDScript = script.get_script_constant_map().get("NavWaypoint") as GDScript
	var waypoint: RefCounted = waypoint_class.new()
	waypoint.set("world", behavior._cell_world(Vector2i(13, 4)))
	waypoint.set("portal_id", behavior.last_portal_id())
	all_passed = _check("a portal puts the agent at its exit point, not at the node's centre", behavior._portal_exit_for(waypoint), Vector2(435.0, 150.0)) and all_passed
	behavior.clear_portals()

	# ── Regenerate Region: the same graph as a full regenerate, built locally ─────────────────
	map.set_cell(Vector2i(4, 5), 0, Vector2i.ZERO)
	map.erase_cell(Vector2i(4, 5))
	map.erase_cell(Vector2i(5, 5))
	behavior.regenerate_region(128.0, 160.0, 64.0, 32.0)
	var local_edges: Dictionary = _edge_signature(behavior)
	var local_nodes: Array = behavior.get("_nodes").keys()
	local_nodes.sort()
	behavior.regenerate_nav_graph()
	all_passed = _check("the region update leaves exactly the graph a full rebuild makes (links)", local_edges, _edge_signature(behavior)) and all_passed
	var full_nodes: Array = behavior.get("_nodes").keys()
	full_nodes.sort()
	all_passed = _check("the region update leaves exactly the nodes a full rebuild makes", local_nodes, full_nodes) and all_passed
	all_passed = _check("the cell under the cleared floor is no longer a node", behavior.get("_nodes").has(Vector2i(4, 4)), false) and all_passed
	# And it can put a cell back.
	map.set_cell(Vector2i(4, 5), 0, Vector2i.ZERO)
	map.set_cell(Vector2i(5, 5), 0, Vector2i.ZERO)
	behavior.regenerate_region(128.0, 160.0, 64.0, 32.0)
	var restored: Dictionary = _edge_signature(behavior)
	behavior.regenerate_nav_graph()
	all_passed = _check("repainting a region and regenerating it matches a full rebuild", restored, _edge_signature(behavior)) and all_passed
	all_passed = _check("the repainted floor is standable again", behavior.get("_nodes").has(Vector2i(4, 4)), true) and all_passed

	# ── The movement's own words ─────────────────────────────────────────────────────────────
	all_passed = _check("Jump Speed with no sibling reads the fallback driver", behavior.jump_speed(), 400.0) and all_passed
	all_passed = _check("Run Speed with no sibling reads the fallback driver", behavior.run_speed(), 200.0) and all_passed
	all_passed = _check("Grid Origin of a tilemap is its top-left corner", behavior.grid_origin(), Vector2.ZERO) and all_passed

	# ── The surface ──────────────────────────────────────────────────────────────────────────
	for method_name: String in ["add_hazard_from_node", "remove_hazard_from_node", "set_tile_hazard", "start_patrol_between_markers", "set_patrol_setting", "set_patrol_option", "patrol_point_index", "add_portal_from_nodes", "add_elevator_stop_from_node", "remove_portal_at_node", "set_portal_position_from_nodes", "regenerate_region", "regenerate_region_by_node", "learn_moving_platform", "run_speed", "jump_speed", "grid_origin"]:
		all_passed = _check("method %s exists" % method_name, behavior.has_method(method_name), true) and all_passed
	all_passed = _check("Watch Tile Edits ships off", behavior.get("watch_tile_edits"), false) and all_passed

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
	tile_set.add_source(source, 0)
	source.create_tile(Vector2i.ZERO)
	var tile_data: TileData = source.get_tile_data(Vector2i.ZERO, 0)
	tile_data.add_collision_polygon(0)
	tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]))
	var map: TileMapLayer = TileMapLayer.new()
	map.tile_set = tile_set
	return map


## True when a link of that kind joins the two cells (the first link a cell pair has is not always the one asked for).
static func _has_link(behavior: Node, from_cell: Vector2i, to_cell: Vector2i, kind: String) -> bool:
	for edge: RefCounted in (behavior.get("_edges").get(from_cell, []) as Array):
		if edge.get("to") == to_cell and str(edge.get("kind")) == kind:
			return true
	return false


## Every link of the graph as a sorted list of "from>to:kind" strings (portal and platform links included).
static func _edge_signature(behavior: Node) -> Dictionary:
	var lines: Array = []
	var edges: Dictionary = behavior.get("_edges")
	for cell: Vector2i in edges:
		for edge: RefCounted in (edges[cell] as Array):
			lines.append("%s>%s:%s" % [str(cell), str(edge.get("to")), str(edge.get("kind"))])
	lines.sort()
	return {"links": lines}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("platformer_pathfinding_parity_test", label, actual, expected)
