## @ace_tags(movement, platformer, ai, pathfinding)
## @ace_category("Platformer Pathfinding")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/behavior.svg")
class_name PlatformerPathfinding
extends Node

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

## How close (px, horizontally) counts as reaching a waypoint.
@export var arrive_distance: float = 10.0
## Drive the sibling PlatformerMovement automatically. Off = paths still compute; read Path Move Axis / Path Wants Jump and steer yourself.
@export var auto_control: bool = true
## Draw the active path as a line in the world.
@export var debug_draw: bool = false
## The fallback driver's gravity.
@export var fallback_gravity: float = 980.0
## The fallback driver's jump velocity (negative = up). Also sizes jump arcs when nothing can be derived.
@export var fallback_jump_velocity: float = -400.0
## No movement sibling? The built-in fallback driver moves the CharacterBody2D itself at this speed.
@export var fallback_move_speed: float = 200.0
## Max jump distance in px (0 = derive it from the sibling PlatformerMovement's speed and air time).
@export var jump_distance_override: float = 0.0
## Max jump height in px (0 = derive it from the sibling PlatformerMovement's jump_velocity/gravity).
@export var jump_height_override: float = 0.0
## The furthest safe drop (px) the graph will route through.
@export var max_fall_distance: float = 320.0
## Release the jump at the height each arc actually needs (short hops for flat gaps, full rises for tall ledges) - smoother-looking movement. Off = every jump is full height.
@export var variable_jump: bool = true

# --- Internal state (the graph lives per agent in P1) ---
var _tilemap: TileMapLayer = null
var _movement: Node = null
## Standable cells (the cell the agent's feet occupy) -> true.
var _nodes: Dictionary = {}
## cell -> Array of {"to": Vector2i, "kind": "walk"/"jump"/"fall", "cost": float}.
var _edges: Dictionary = {}
## The active path: Array of {"world": Vector2, "action": String}.
var _path: Array = []
var _path_index: int = 0
var _jumped_this_segment: bool = false
var _jump_released: bool = false
var _jump_release_velocity: float = 0.0
var _move_axis: float = 0.0
var _debug_line: Line2D = null
## Registered portals: {"from": Vector2, "to": Vector2, "both": bool} - survive regenerate.
var _portals: Array = []
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
			return _movement
	return null
## Jump reach in CELLS, derived from the movement pack's physics (the overrides win when
## set): height = v^2/2g, distance = speed * full air time, both with a 0.9 safety margin.
## @ace_hidden
func _jump_reach_cells() -> Vector2i:
	var tile: float = float(_tilemap.tile_set.tile_size.y)
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
	return Vector2i(maxi(int(ceil(distance_px / tile)), 1), maxi(int(ceil(height_px / tile)), 1))
## The standable node nearest a world position (within max_cells), or Vector2i.MAX.
## Tree-safe: outside a scene tree (tools, tests) the tilemap's own offset stands in for
## the global transform.
## @ace_hidden
func _nearest_node(world: Vector2, max_cells: int) -> Vector2i:
	var local: Vector2 = _tilemap.to_local(world) if _tilemap.is_inside_tree() else world - _tilemap.position
	var around: Vector2i = _tilemap.local_to_map(local)
	var best: Vector2i = Vector2i.MAX
	var best_distance: float = float(max_cells) + 0.51
	for cell in _nodes:
		var cell_distance: float = Vector2(cell - around).length()
		if cell_distance < best_distance:
			best_distance = cell_distance
			best = cell
	return best

func _physics_process(delta: float) -> void:
	if host == null or _path.is_empty():
		return
	var waypoint: Dictionary = _path[_path_index]
	var target: Vector2 = waypoint["world"]
	# Portal traversal: the waypoint IS the exit - blink there and continue.
	if waypoint["action"] == "portal":
		host.global_position = target
		host.velocity = Vector2.ZERO
		portal_taken.emit()
		_advance_waypoint()
		return
	var dx: float = target.x - host.global_position.x
	_move_axis = clampf(dx / 24.0, -1.0, 1.0) if absf(dx) > 2.0 else 0.0
	var movement: Node = _find_movement()
	var tile: float = float(_tilemap.tile_set.tile_size.y) if _tilemap != null else 32.0
	# Jump on jump arcs, and STEP-ASSIST on raised walk waypoints: a full-block stair stops
	# a walking body, so a close-and-higher waypoint gets a hop (slope tiles just walk).
	var wants_jump: bool = waypoint["action"] == "jump"
	if not wants_jump and waypoint["action"] == "walk":
		wants_jump = target.y < host.global_position.y - 8.0 and absf(dx) < tile * 1.5
	if auto_control:
		var start_jump: bool = wants_jump and not _jumped_this_segment and host.is_on_floor()
		if start_jump:
			_jumped_this_segment = true
			_jump_released = false
			_jump_release_velocity = _release_velocity_for(target)
			# An arc that needs (nearly) the whole jump must never be cut - releasing a
			# near-max jump on its first frames kills the climb. Variable jump only arms
			# when there is clear headroom.
			var full_rise: float = absf(float(movement.get("jump_velocity"))) if movement != null else absf(fallback_jump_velocity)
			if _jump_release_velocity >= full_rise * 0.85:
				_jump_release_velocity = 0.0
		# Variable jump: once remaining upward speed is just enough for THIS arc's rise,
		# release - flat gap hops stay low, tall ledges get the full jump.
		var release_now: bool = variable_jump and _jumped_this_segment and not _jump_released and host.velocity.y < 0.0 and absf(host.velocity.y) <= _jump_release_velocity
		if movement != null:
			# The standard drive seam on the movement sibling - its accel, coyote time, and
			# jump feel all still apply under AI control.
			movement.set("ai_controlled", true)
			movement.set("ai_move_axis", _move_axis)
			if start_jump:
				movement.jump()
			if release_now and movement.has_method("jump_released"):
				_jump_released = true
				movement.jump_released()
		else:
			# No movement sibling: the built-in fallback drives the CharacterBody2D itself,
			# so ANY body pathfinds out of the box (attach one behavior, done).
			host.velocity.y = minf(host.velocity.y + fallback_gravity * delta, 1000.0)
			host.velocity.x = _move_axis * fallback_move_speed
			if start_jump:
				host.velocity.y = fallback_jump_velocity
			if release_now:
				_jump_released = true
				host.velocity.y *= 0.45
			host.move_and_slide()
	if absf(dx) <= arrive_distance and absf(target.y - host.global_position.y) <= tile:
		_advance_waypoint()
	if debug_draw:
		_refresh_debug()

## @ace_action
## @ace_name("Build Nav Graph From Tilemap")
## @ace_category("Platformer Pathfinding")
## @ace_description("Scans a TileMapLayer's physics tiles into the navigation graph: standable cells become nodes, adjacent cells (one step up or down - stairs and tile slopes) become WALK edges, and jump arcs / fall drops connect the rest, sized to the sibling PlatformerMovement's real jump. Call once on ready; Regenerate after level edits. Fires On Nav Graph Built.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.build_nav_graph({tilemap})")
func build_nav_graph(tilemap: Node) -> void:
	_tilemap = tilemap as TileMapLayer
	regenerate_nav_graph()

## @ace_action
## @ace_name("Regenerate Nav Graph")
## @ace_category("Platformer Pathfinding")
## @ace_description("Rebuilds the graph from the same TileMapLayer (after runtime tile edits).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.regenerate_nav_graph()")
func regenerate_nav_graph() -> void:
	_nodes.clear()
	_edges.clear()
	if _tilemap == null:
		return
	var solid: Dictionary = {}
	for cell in _tilemap.get_used_cells():
		var tile_data: TileData = _tilemap.get_cell_tile_data(cell)
		if tile_data != null and tile_data.get_collision_polygons_count(0) > 0:
			solid[cell] = true
	# A standable node = a solid cell with two cells of headroom above it.
	for cell in solid:
		var stand: Vector2i = cell + Vector2i(0, -1)
		if not solid.has(stand) and not solid.has(stand + Vector2i(0, -1)):
			_nodes[stand] = true
	# WALK edges: neighbours one cell over, up to one step up/down - stairs and slopes
	# included, at plain euclidean cost so ramps beat jumps in the router.
	for cell in _nodes:
		for dx in [-1, 1]:
			for dy in [-1, 0, 1]:
				var to: Vector2i = cell + Vector2i(dx, dy)
				if _nodes.has(to):
					_add_edge(cell, to, "walk", Vector2(float(dx), float(dy)).length())
	# JUMP arcs + FALL drops within the derived reach, clearance-checked coarsely.
	var reach: Vector2i = _jump_reach_cells()
	var fall_cells: int = maxi(int(ceil(max_fall_distance / float(_tilemap.tile_set.tile_size.y))), 1)
	for cell in _nodes:
		for dx in range(-reach.x, reach.x + 1):
			for dy in range(-reach.y, fall_cells + 1):
				if absi(dx) <= 1 and absi(dy) <= 1:
					continue
				var to: Vector2i = cell + Vector2i(dx, dy)
				if not _nodes.has(to) or not _arc_clear(cell, to, solid):
					continue
				var kind: String = "fall" if dy > 0 and absi(dx) <= 2 else "jump"
				var span: float = Vector2(float(dx), float(dy)).length()
				_add_edge(cell, to, kind, span * (1.5 if kind == "jump" else 1.1))
	# Registered portals survive every rebuild.
	for portal in _portals:
		_apply_portal(portal)
	nav_graph_built.emit()

## @ace_action
## @ace_name("Find Path To")
## @ace_category("Platformer Pathfinding")
## @ace_description("Routes to a world position and starts moving. Mode "reach" fails (On Path Failed) when the spot itself is unreachable; "nearest" never fails - it goes to the closest reachable node instead. Fires On Path Found / On Path Failed.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.find_path_to({x}, {y}, {mode})")
func find_path_to(x: float, y: float, mode: String) -> void:
	if host == null or _tilemap == null or _nodes.is_empty():
		path_failed.emit()
		return
	var start: Vector2i = _nearest_node(host.global_position, 3)
	var goal: Vector2i = _nearest_node(Vector2(x, y), 2 if mode == "reach" else 1000000)
	if start == Vector2i.MAX or goal == Vector2i.MAX:
		stop_pathfinding()
		path_failed.emit()
		return
	var cells: Array = _astar(start, goal)
	if cells.is_empty():
		stop_pathfinding()
		path_failed.emit()
		return
	_path = []
	for index in range(cells.size()):
		var action: String = "walk" if index == 0 else _edge_kind(cells[index - 1], cells[index])
		_path.append({"world": _cell_world(cells[index]), "action": action})
	_path_index = 0
	_jumped_this_segment = false
	path_found.emit()

## @ace_action
## @ace_name("Find Path To Node")
## @ace_category("Platformer Pathfinding")
## @ace_description("Routes to another node's position (the player, a pickup) - Find Path To with the position read for you. Re-call it on a timer to chase.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.find_path_to_node({target}, {mode})")
func find_path_to_node(target: Node, mode: String) -> void:
	if target is Node2D:
		find_path_to((target as Node2D).global_position.x, (target as Node2D).global_position.y, mode)
	else:
		path_failed.emit()

## @ace_action
## @ace_name("Stop Pathfinding")
## @ace_category("Platformer Pathfinding")
## @ace_description("Clears the path and releases the movement pack back to the keyboard (ai_controlled off).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.stop_pathfinding()")
func stop_pathfinding() -> void:
	_path = []
	_path_index = 0
	_move_axis = 0.0
	_jumped_this_segment = false
	var movement: Node = _find_movement()
	if movement != null:
		movement.set("ai_move_axis", 0.0)
		movement.set("ai_controlled", false)
	if _debug_line != null and is_instance_valid(_debug_line):
		_debug_line.clear_points()

## @ace_action
## @ace_name("Set Auto Control")
## @ace_category("Platformer Pathfinding")
## @ace_description("On (default): the behavior drives the sibling PlatformerMovement. Off: paths still compute - read Path Move Axis / Path Wants Jump / Current Waypoint X/Y and drive anything you like.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_auto_control({enabled})")
func set_auto_control(enabled: bool) -> void:
	auto_control = enabled
	if not enabled:
		var movement: Node = _find_movement()
		if movement != null:
			movement.set("ai_controlled", false)

## @ace_action
## @ace_name("Add Portal")
## @ace_category("Platformer Pathfinding")
## @ace_description("Links two world positions as a PORTAL: an agent whose route uses it walks to the entrance and blinks to the exit (fires On Portal Taken). Bidirectional works both ways. Portals join the graph immediately and survive Regenerate - doors, teleporters, ladders, and elevators all model as portals.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.add_portal({from_x}, {from_y}, {to_x}, {to_y}, {bidirectional})")
func add_portal(from_x: float, from_y: float, to_x: float, to_y: float, bidirectional: bool) -> void:
	var portal: Dictionary = {"from": Vector2(from_x, from_y), "to": Vector2(to_x, to_y), "both": bidirectional}
	_portals.append(portal)
	if not _nodes.is_empty():
		_apply_portal(portal)

## @ace_action
## @ace_name("Clear Portals")
## @ace_category("Platformer Pathfinding")
## @ace_description("Removes every registered portal (takes effect on the next Regenerate Nav Graph).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.clear_portals()")
func clear_portals() -> void:
	_portals = []
	regenerate_nav_graph()

## @ace_action
## @ace_name("Set Nav Debug Draw")
## @ace_category("Platformer Pathfinding")
## @ace_description("Draws the active path as a line in the world (great while tuning a level).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.set_nav_debug_draw({enabled})")
func set_nav_debug_draw(enabled: bool) -> void:
	debug_draw = enabled
	_refresh_debug()

## @ace_condition
## @ace_name("Has Path")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.has_path()")
func has_path() -> bool:
	return not _path.is_empty()

## @ace_condition
## @ace_name("Path Wants Jump")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.path_wants_jump()")
func path_wants_jump() -> bool:
	if _path.is_empty() or _jumped_this_segment or host == null:
		return false
	var waypoint: Dictionary = _path[_path_index]
	if waypoint["action"] == "jump":
		return true
	# Step assist: a close-and-higher walk waypoint needs a hop on full-block stairs.
	var tile: float = float(_tilemap.tile_set.tile_size.y) if _tilemap != null else 32.0
	var target: Vector2 = waypoint["world"]
	return waypoint["action"] == "walk" and target.y < host.global_position.y - 8.0 and absf(target.x - host.global_position.x) < tile * 1.5

## @ace_expression
## @ace_name("Path Move Axis")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.path_move_axis()")
func path_move_axis() -> float:
	return _move_axis

## @ace_expression
## @ace_name("Waypoint Count")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.waypoint_count()")
func waypoint_count() -> int:
	return _path.size()

## @ace_expression
## @ace_name("Current Waypoint Index")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.current_waypoint_index()")
func current_waypoint_index() -> int:
	return _path_index

## @ace_expression
## @ace_name("Current Waypoint X")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.current_waypoint_x()")
func current_waypoint_x() -> float:
	return (_path[_path_index]["world"] as Vector2).x if not _path.is_empty() else 0.0

## @ace_expression
## @ace_name("Current Waypoint Y")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.current_waypoint_y()")
func current_waypoint_y() -> float:
	return (_path[_path_index]["world"] as Vector2).y if not _path.is_empty() else 0.0

## @ace_expression
## @ace_name("Current Path Action")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$PlatformerPathfinding.current_path_action()")
func current_path_action() -> String:
	return str(_path[_path_index]["action"]) if not _path.is_empty() else ""

func _drive_gravity() -> float:
	var movement: Node = _find_movement()
	if movement != null and movement.get("gravity") != null:
		return maxf(float(movement.get("gravity")), 1.0)
	return maxf(fallback_gravity, 1.0)

func _release_velocity_for(target: Vector2) -> float:
	var rise: float = maxf(host.global_position.y - target.y, 0.0) + 20.0
	return sqrt(2.0 * _drive_gravity() * rise)

func _apply_portal(portal: Dictionary) -> void:
	var from_node: Vector2i = _nearest_node(portal["from"], 2)
	var to_node: Vector2i = _nearest_node(portal["to"], 2)
	if from_node == Vector2i.MAX or to_node == Vector2i.MAX:
		return
	_add_edge(from_node, to_node, "portal", 2.0)
	if bool(portal["both"]):
		_add_edge(to_node, from_node, "portal", 2.0)

## @ace_hidden
func _advance_waypoint() -> void:
	_jumped_this_segment = false
	_jump_released = false
	_path_index += 1
	waypoint_reached.emit()
	if _path_index >= _path.size():
		stop_pathfinding()
		path_complete.emit()

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

## @ace_hidden
func _cell_world(cell: Vector2i) -> Vector2:
	var local: Vector2 = _tilemap.map_to_local(cell)
	return _tilemap.to_global(local) if _tilemap.is_inside_tree() else local + _tilemap.position

func _astar(start: Vector2i, goal: Vector2i) -> Array:
	var open: Array = [start]
	var came_from: Dictionary = {}
	var cost_so_far: Dictionary = {start: 0.0}
	while not open.is_empty():
		var best_index: int = 0
		for index in range(1, open.size()):
			var here: Vector2i = open[index]
			if cost_so_far[here] + Vector2(goal - here).length() < cost_so_far[open[best_index]] + Vector2(goal - (open[best_index] as Vector2i)).length():
				best_index = index
		var current: Vector2i = open.pop_at(best_index)
		if current == goal:
			var cells: Array = [current]
			while came_from.has(current):
				current = came_from[current]
				cells.push_front(current)
			return cells
		for edge in (_edges.get(current, []) as Array):
			var next_cell: Vector2i = edge["to"]
			var next_cost: float = cost_so_far[current] + float(edge["cost"])
			if not cost_so_far.has(next_cell) or next_cost < float(cost_so_far[next_cell]):
				cost_so_far[next_cell] = next_cost
				came_from[next_cell] = current
				if not open.has(next_cell):
					open.append(next_cell)
	return []

func _edge_kind(from_cell: Vector2i, to_cell: Vector2i) -> String:
	for edge in (_edges.get(from_cell, []) as Array):
		if edge["to"] == to_cell:
			return str(edge["kind"])
	return "walk"

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

# Platformer pathfinding: attach as a SIBLING of PlatformerMovement under a CharacterBody2D. Build Nav Graph from your TileMapLayer once, then Find Path To - the behavior derives jump reach from the movement pack and drives it through the ai_move_axis seam. Stairs and tile slopes walk (adjacent cells one step up/down are WALK edges); gaps and ledges route through jump arcs and fall drops.
