# Godot EventSheets - Platformer Pathfinding: one-way slope tiles.
#
# A tile whose collision polygons are all one-way and whose top edge slopes is a jump-through slope:
# an agent walks along it from above, passes up through it from below and drops through it, the way
# plain one-way tiles already work. A solid slope and a flat one-way tile read as they always did.
@tool
class_name PlatformerPathfindingSlopePassTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"

## The atlas columns of the test tile set.
const SOLID_TILE: Vector2i = Vector2i(0, 0)
const FLAT_ONE_WAY_TILE: Vector2i = Vector2i(1, 0)
const SOLID_SLOPE_TILE: Vector2i = Vector2i(2, 0)
const ONE_WAY_SLOPE_UP_TILE: Vector2i = Vector2i(3, 0)
const ONE_WAY_SLOPE_DOWN_TILE: Vector2i = Vector2i(4, 0)


static func run() -> bool:
	var ok: bool = true
	var script: GDScript = load(PACK)
	ok = _check("pack loads", script != null, true) and ok
	if script == null:
		return ok
	# Floor y=10 x 0..19; a flight of one-way "/" slopes at (5,9) (6,8) (7,7); a one-way "\" slope at (12,8);
	# a flat one-way tile at (14,8); a solid "/" slope at (17,9).
	var map: TileMapLayer = _make_map()
	for x in range(0, 20):
		map.set_cell(Vector2i(x, 10), 0, SOLID_TILE)
	map.set_cell(Vector2i(5, 9), 0, ONE_WAY_SLOPE_UP_TILE)
	map.set_cell(Vector2i(6, 8), 0, ONE_WAY_SLOPE_UP_TILE)
	map.set_cell(Vector2i(7, 7), 0, ONE_WAY_SLOPE_UP_TILE)
	map.set_cell(Vector2i(12, 8), 0, ONE_WAY_SLOPE_DOWN_TILE)
	map.set_cell(Vector2i(14, 8), 0, FLAT_ONE_WAY_TILE)
	map.set_cell(Vector2i(17, 9), 0, SOLID_SLOPE_TILE)
	var nav: Node = script.new()
	nav.build_nav_graph(map)

	# ── What each tile reads as ──
	ok = _check("a one-way slope that rises to the right reads jump_thru_slope_left", nav.tile_state(6, 8), "jump_thru_slope_left") and ok
	ok = _check("a one-way slope that rises to the left reads jump_thru_slope_right", nav.tile_state(12, 8), "jump_thru_slope_right") and ok
	ok = _check("a flat one-way tile still reads jump_thru", nav.tile_state(14, 8), "jump_thru") and ok
	ok = _check("a solid slope still reads slope_left", nav.tile_state(17, 9), "slope_left") and ok
	ok = _check("Tile Has State agrees", nav.tile_has_state(6, 8, "jump_thru_slope_left"), true) and ok
	ok = _check("a one-way slope is not a flat jump_thru", nav.tile_has_state(6, 8, "jump_thru"), false) and ok

	# ── Walkable from above, along the slope ──
	ok = _check("the cell above a one-way slope is a node", nav.graph_node_exists(5, 8) and nav.graph_node_exists(6, 7) and nav.graph_node_exists(7, 6), true) and ok
	ok = _check("walking up the flight is a walk link", _kind(nav, Vector2i(5, 8), Vector2i(6, 7)) == "walk" and _kind(nav, Vector2i(6, 7), Vector2i(7, 6)) == "walk", true) and ok
	ok = _check("and walking down it is too", _kind(nav, Vector2i(7, 6), Vector2i(6, 7)), "walk") and ok
	ok = _check("a route from the floor to the top of the flight walks all the way", _walks_only(nav, Vector2i(2, 9), Vector2i(7, 6)), true) and ok

	# ── Passable from below: no headroom is taken, and a jump goes up through ──
	ok = _check("the floor under a one-way slope keeps its headroom", nav.graph_node_exists(6, 9), true) and ok
	ok = _check("the floor under the highest step too", nav.graph_node_exists(7, 9), true) and ok
	ok = _check("a jump from below goes up through the slope", _kind(nav, Vector2i(6, 9), Vector2i(6, 7)), "jump") and ok
	ok = _check("a one-way slope blocks nothing (it is not a solid cell)", nav.get("_blocking").has(Vector2i(6, 8)), false) and ok
	ok = _check("a solid slope does", nav.get("_blocking").has(Vector2i(17, 9)), true) and ok

	# ── Drop-through, as plain one-way tiles ──
	ok = _check("dropping off a one-way slope is a fall_through link", _kind(nav, Vector2i(7, 6), Vector2i(7, 9)), "fall_through") and ok
	ok = _check("and off a one-way slope that falls to the right", _kind(nav, Vector2i(12, 7), Vector2i(12, 9)), "fall_through") and ok
	ok = _check("the flat one-way tile still has its drop", _kind(nav, Vector2i(14, 7), Vector2i(14, 9)), "fall_through") and ok
	ok = _check("a solid slope gets no drop", _kind(nav, Vector2i(17, 8), Vector2i(17, 11)), "") and ok

	# ── Set by hand ──
	nav.set_tile_state(3, 9, "jump_thru_slope_right")
	nav.regenerate_nav_graph()
	ok = _check("Set Tile State takes a one-way slope word", nav.tile_state(3, 9), "jump_thru_slope_right") and ok
	ok = _check("and its cell is walkable from above", nav.graph_node_exists(3, 8), true) and ok
	nav.set_tile_state(3, 9, "nonsense")
	ok = _check("an unknown word changes nothing", nav.tile_state(3, 9), "jump_thru_slope_right") and ok
	# The saved map keeps the word and reads back the same.
	var json: String = nav.obstacle_map_json()
	var other: Node = script.new()
	other.load_obstacle_map_json(json)
	ok = _check("a saved obstacle map keeps the one-way slope", str(other.get("_tile_overrides").get(Vector2i(6, 8), "")), "jump_thru_slope_left") and ok
	ok = _check("and its cell is walkable from above in the loaded graph", other.get("_nodes").has(Vector2i(6, 7)), true) and ok
	other.free()
	nav.free()
	map.free()
	return ok


## True when the best route from one cell to another uses walk links only.
static func _walks_only(nav: Node, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var cells: Array = nav._astar(from_cell, to_cell)
	if cells.is_empty():
		return false
	for index in range(1, cells.size()):
		if _kind(nav, cells[index - 1], cells[index]) != "walk":
			return false
	return true


static func _kind(nav: Node, from_cell: Vector2i, to_cell: Vector2i) -> String:
	for edge: RefCounted in (nav.get("_edges").get(from_cell, []) as Array):
		if edge.get("to") == to_cell:
			return str(edge.get("kind"))
	return ""


## A 32px tile set: solid, flat one-way, solid "/" slope, one-way "/" slope, one-way "\" slope.
static func _make_map() -> TileMapLayer:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	tile_set.add_physics_layer()
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	var image: Image = Image.create(160, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(32, 32)
	tile_set.add_source(source, 0)
	var full: PackedVector2Array = PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)])
	var thin: PackedVector2Array = PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, -8), Vector2(-16, -8)])
	var rising: PackedVector2Array = PackedVector2Array([Vector2(-16, 16), Vector2(16, -16), Vector2(16, 16)])
	var falling: PackedVector2Array = PackedVector2Array([Vector2(-16, -16), Vector2(16, 16), Vector2(-16, 16)])
	var shapes: Array = [full, thin, rising, rising, falling]
	var one_way: Array = [false, true, false, true, true]
	for index in range(5):
		source.create_tile(Vector2i(index, 0))
		var tile_data: TileData = source.get_tile_data(Vector2i(index, 0), 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, shapes[index])
		tile_data.set_collision_polygon_one_way(0, 0, one_way[index])
	var map: TileMapLayer = TileMapLayer.new()
	map.tile_set = tile_set
	return map


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("platformer_pathfinding_slope_pass_test", label, actual, expected)
