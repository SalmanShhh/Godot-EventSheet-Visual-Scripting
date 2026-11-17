# EventSheets - the platformer router picks its next node from a heap, and the routes are the ones
# the old front-to-back scan chose.
#
# The search used to walk every open node to find the best one, so a large map cost the square of what
# it held. The heap must hand back the same node the scan would have (the best estimate, and among equal
# estimates the one that joined the open set first), so every route stays exactly as it was. The scan
# is kept here as the reference and both are run over grids of random link costs, ties included.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "platformer_pathfinding_open_set_test"
const PACK := "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"


static func run() -> bool:
	var script: GDScript = load(PACK)
	var rows: Array = []
	var seeds: Array = [3, 11, 29]
	for seed_value: int in seeds:
		var grid: Dictionary = _grid(script, 24, 18, seed_value)
		var nav: Node = grid["nav"]
		var goal: Vector2i = Vector2i(23, 17)
		var heap_route: Array = nav._astar(Vector2i(0, 0), goal)
		var scan_route: Array = _scan_astar(nav, Vector2i(0, 0), goal)
		rows.append(["seed %d: the heap finds the route the scan found" % seed_value, heap_route, scan_route])
		rows.append(["seed %d: and it is a route" % seed_value, heap_route.is_empty(), false])
		var partial_heap: Array = nav._astar(Vector2i(0, 0), Vector2i(40, 40), true)
		var partial_scan: Array = _scan_astar(nav, Vector2i(0, 0), Vector2i(40, 40), true)
		rows.append(["seed %d: a goal off the map gives the same closest route" % seed_value, partial_heap, partial_scan])
		nav.free()
	# A large open map is searched whole; the scan is not asked here, it took the square of the map.
	var big: Dictionary = _grid(script, 90, 60, 5)
	var big_nav: Node = big["nav"]
	big_nav.set("max_search_nodes", 100000)
	var big_route: Array = big_nav._astar(Vector2i(0, 0), Vector2i(89, 59))
	rows.append(["a 5,400 node map has a route", big_route.is_empty(), false])
	rows.append(["and it ends on the goal", big_route[big_route.size() - 1], Vector2i(89, 59)])
	big_nav.free()
	return SUPPORT.pins(P, rows)


## A grid of walk links between neighbours with costs drawn from a few values, so many estimates tie.
static func _grid(script: GDScript, width: int, height: int, seed_value: int) -> Dictionary:
	var nav: Node = script.new()
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = seed_value
	var edges: Dictionary = {}
	for y: int in range(height):
		for x: int in range(width):
			var cell: Vector2i = Vector2i(x, y)
			var list: Array = []
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var other: Vector2i = cell + step
				if other.x < 0 or other.y < 0 or other.x >= width or other.y >= height:
					continue
				list.append(_edge(script, other, float(generator.randi_range(1, 3))))
			edges[cell] = list
	nav.set("_edges", edges)
	return {"nav": nav}


static func _edge(script: GDScript, to: Vector2i, cost: float) -> RefCounted:
	var nav_edge: Variant = script.get_script_constant_map().get("NavEdge")
	var edge: RefCounted = (nav_edge as GDScript).new()
	edge.set("to", to)
	edge.set("cost", cost)
	return edge


## The search as it was written before the heap: scan the open list for the best estimate, first wins a tie.
static func _scan_astar(nav: Node, start: Vector2i, goal: Vector2i, allow_partial: bool = false) -> Array:
	var open: Array = [start]
	var came_from: Dictionary = {}
	var cost_so_far: Dictionary = {start: 0.0}
	var closest: Vector2i = start
	var closest_gap: float = Vector2(goal - start).length()
	var expanded: int = 0
	var edges: Dictionary = nav.get("_edges")
	while not open.is_empty():
		if expanded >= maxi(int(nav.get("max_search_nodes")), 1):
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
			return _walk_back(current, came_from)
		for edge: Variant in (edges.get(current, []) as Array):
			var next_cell: Vector2i = (edge as RefCounted).get("to")
			var next_cost: float = cost_so_far[current] + float((edge as RefCounted).get("cost"))
			if not cost_so_far.has(next_cell) or next_cost < float(cost_so_far[next_cell]):
				cost_so_far[next_cell] = next_cost
				came_from[next_cell] = current
				if not open.has(next_cell):
					open.append(next_cell)
	if allow_partial:
		return _walk_back(closest, came_from)
	return []


static func _walk_back(end: Vector2i, came_from: Dictionary) -> Array:
	var cells: Array = [end]
	var current: Vector2i = end
	while came_from.has(current):
		current = came_from[current]
		cells.push_front(current)
	return cells
