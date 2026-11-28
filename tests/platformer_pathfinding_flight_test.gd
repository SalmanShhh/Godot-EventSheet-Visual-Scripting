# Godot EventSheets - Platformer Pathfinding: a jump link is a jump the body can really make.
#
# A jump is flown with the movement sibling's own numbers (acceleration, top speed, gravity, jump
# speed, the early release of a variable jump) and becomes a link only if it comes down over the
# landing cell. A gap that is only crossed with a running start becomes a link that asks for one.
# The test names every jump that stopped being a link (wrongly allowed before) and every one that
# became a link (wrongly refused before), and pins the running start's numbers.
@tool
class_name PlatformerPathfindingFlightTest
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
	ok = _default_numbers(script) and ok
	ok = _running_start(script) and ok
	ok = _overrides(script) and ok
	return ok


# ── The default numbers: no sibling, so the fallback driver's 400 px/s jump and 980 gravity ─────────
static func _default_numbers(script: GDScript) -> bool:
	var ok: bool = true
	# Floor y=5 x 0..15 with a gap at x=8..9; a stair tile at (4,4); a platform y=3 x 12..14.
	var map: TileMapLayer = _make_map()
	for x in range(0, 16):
		if x != 8 and x != 9:
			map.set_cell(Vector2i(x, 5), 0, Vector2i.ZERO)
	map.set_cell(Vector2i(4, 4), 0, Vector2i.ZERO)
	for x in range(12, 15):
		map.set_cell(Vector2i(x, 3), 0, Vector2i.ZERO)
	var nav: Node = script.new()
	nav.build_nav_graph(map)
	ok = _check("a 3-cell gap is still a jump", _kind(nav, Vector2i(7, 4), Vector2i(10, 4)), "jump") and ok
	ok = _check("a jump that lands cleanly has no running start", _run_up(nav, Vector2i(7, 4), Vector2i(10, 4)), 0) and ok
	# Wrongly allowed before: 5 cells across and 2 up needs a flight the jump cannot make (the apex is 2.5 cells).
	ok = _check("5 across and 2 up from (7,4) to the platform is no longer a link", _kind(nav, Vector2i(7, 4), Vector2i(12, 2)), "") and ok
	# Wrongly refused before: the chord between these cells clips the platform's far corner, the flight does not.
	ok = _check("the coarse chord refuses the hop down off the platform's end", nav._arc_clear(Vector2i(12, 2), Vector2i(15, 4), nav.get("_blocking_down")), false) and ok
	ok = _check("the flight clears it, so it is a link now", _kind(nav, Vector2i(12, 2), Vector2i(15, 4)), "jump") and ok
	ok = _check("the other direction of the same kind is a link too", _kind(nav, Vector2i(14, 2), Vector2i(11, 4)), "jump") and ok
	# The route that crossed before still does.
	ok = _check("the whole floor is still crossable", nav._astar(Vector2i(0, 4), Vector2i(15, 4)).is_empty(), false) and ok

	# ── The flight table itself ──
	nav.call("_begin_links")
	var flight: Dictionary = nav.call("_flight", 3, 0, 0, false)
	ok = _check("a 3-cell flat jump lands", flight["lands"], true) and ok
	ok = _check("a 9-cell flat jump does not", nav.call("_flight", 9, 0, 0, false)["lands"], false) and ok
	ok = _check("a 3-cell climb does not (the apex is 2.5 cells)", nav.call("_flight", 0, -3, 0, false)["lands"], false) and ok
	ok = _check("a 2-cell climb does", nav.call("_flight", 0, -2, 0, false)["lands"], true) and ok
	ok = _check("a flight is made once and shared", nav.call("_flight", 3, 0, 0, false) == flight, true) and ok
	# Letting go of the jump early shortens it; holding it to the end reaches further.
	ok = _check("a 5-cell flat jump is only made holding the button", nav.call("_flight", 5, 0, 0, false)["lands"], false) and ok
	ok = _check("holding the button the whole way makes it", nav.call("_flight", 5, 0, 0, true)["lands"], true) and ok
	ok = _check("so the 5-cell link is flown holding", _hold(nav, Vector2i(2, 4), Vector2i(7, 4)), true) and ok
	nav.free()
	map.free()
	return ok


# ── Slow acceleration: a gap only a running start crosses ────────────────────────────────────────
static func _running_start(script: GDScript) -> bool:
	var ok: bool = true
	# Floor x 0..11 at y=10, then six empty columns, then floor x 18..25.
	var map: TileMapLayer = _make_map()
	for x in range(0, 12):
		map.set_cell(Vector2i(x, 10), 0, Vector2i.ZERO)
	for x in range(18, 26):
		map.set_cell(Vector2i(x, 10), 0, Vector2i.ZERO)
	var body: CharacterBody2D = CharacterBody2D.new()
	var movement: Node = (load(MOVEMENT) as GDScript).new()
	movement.set("acceleration", 400.0)
	movement.set("move_speed", 260.0)
	movement.set("jump_velocity", -420.0)
	body.add_child(movement)
	var nav: Node = script.new()
	body.add_child(nav)
	nav.set("host", body)
	nav.build_nav_graph(map)
	var take: Vector2i = Vector2i(11, 9)
	var land: Vector2i = Vector2i(18, 9)
	ok = _check("the gap is crossed with a jump", _kind(nav, take, land), "jump") and ok
	ok = _check("which needs one cell of running start", _run_up(nav, take, land), 1) and ok
	ok = _check("and is flown holding the button all the way", _hold(nav, take, land), true) and ok
	ok = _check("Graph Node Connection Run Up says so", nav.graph_node_connection_run_up(11, 9, _link_index(nav, take, land)), 1) and ok
	ok = _check("a link that needs a run costs a little more than one that does not", float(_edge(nav, take, land).get("cost")) > Vector2(7.0, 0.0).length() * 1.5, true) and ok
	ok = _check("a shorter hop from the same cell needs no run", _run_up(nav, take, Vector2i(8, 9)), 0) and ok
	# Standing still, a flight of that size does not land; with the run it does.
	nav.call("_begin_links")
	ok = _check("from a standstill the 7-cell flight falls short", nav.call("_flight", 7, 0, 0, true)["lands"], false) and ok
	ok = _check("with one cell of run it lands", nav.call("_flight", 7, 0, 1, true)["lands"], true) and ok
	ok = _check("two more cells of run are not needed (the link asks for the least)", _run_up(nav, take, land), 1) and ok
	# Run Up Jumps off: every jump leaves from a standstill, so this gap is not crossed.
	nav.set("run_up_jumps", false)
	nav.regenerate_nav_graph()
	ok = _check("with Run Up Jumps off the gap is not crossed", _kind(nav, take, land), "") and ok
	nav.set("run_up_jumps", true)
	# No room behind the takeoff: a platform one cell wide cannot give a run.
	map.erase_cell(Vector2i(10, 10))
	map.erase_cell(Vector2i(9, 10))
	nav.regenerate_nav_graph()
	ok = _check("with no runway behind the takeoff the gap is not crossed", _kind(nav, take, land), "") and ok
	# A runway too short for the speed needed is refused rather than half used.
	map.set_cell(Vector2i(10, 10), 0, Vector2i.ZERO)
	nav.regenerate_nav_graph()
	ok = _check("a run of one cell is the room the link asked for", _kind(nav, take, land), "jump") and ok
	body.free()
	map.free()
	return ok


# ── An override keeps the old box: a size set by hand is believed ───────────────────────────────
static func _overrides(script: GDScript) -> bool:
	var ok: bool = true
	var map: TileMapLayer = _make_map()
	for x in range(0, 12):
		map.set_cell(Vector2i(x, 10), 0, Vector2i.ZERO)
	for x in range(18, 26):
		map.set_cell(Vector2i(x, 10), 0, Vector2i.ZERO)
	var nav: Node = script.new()
	nav.build_nav_graph(map)
	ok = _check("with the default numbers a 7-cell gap is out of reach", _kind(nav, Vector2i(11, 9), Vector2i(18, 9)), "") and ok
	nav.set_movement_limit("jump_distance", 240.0)
	nav.regenerate_nav_graph()
	ok = _check("a jump distance set by hand is believed (the old box)", _kind(nav, Vector2i(11, 9), Vector2i(18, 9)), "jump") and ok
	ok = _check("and needs no running start", _run_up(nav, Vector2i(11, 9), Vector2i(18, 9)), 0) and ok
	ok = _check("Run Up Jumps ships on", nav.get("run_up_jumps"), true) and ok
	for method_name: String in ["set_run_up_jumps", "graph_node_connection_run_up"]:
		ok = _check("method %s exists" % method_name, nav.has_method(method_name), true) and ok
	nav.free()
	map.free()
	return ok


static func _edge(nav: Node, from_cell: Vector2i, to_cell: Vector2i) -> RefCounted:
	for edge: RefCounted in (nav.get("_edges").get(from_cell, []) as Array):
		if edge.get("to") == to_cell and str(edge.get("kind")) == "jump":
			return edge
	return null


static func _link_index(nav: Node, from_cell: Vector2i, to_cell: Vector2i) -> int:
	var links: Array = nav.get("_edges").get(from_cell, [])
	for index in range(links.size()):
		if (links[index] as RefCounted).get("to") == to_cell:
			return index
	return -1


static func _kind(nav: Node, from_cell: Vector2i, to_cell: Vector2i) -> String:
	for edge: RefCounted in (nav.get("_edges").get(from_cell, []) as Array):
		if edge.get("to") == to_cell:
			return str(edge.get("kind"))
	return ""


static func _run_up(nav: Node, from_cell: Vector2i, to_cell: Vector2i) -> int:
	var edge: RefCounted = _edge(nav, from_cell, to_cell)
	return int(edge.get("run_up")) if edge != null else -1


static func _hold(nav: Node, from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var edge: RefCounted = _edge(nav, from_cell, to_cell)
	return edge != null and bool(edge.get("hold_jump"))


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


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("platformer_pathfinding_flight_test", label, actual, expected)
