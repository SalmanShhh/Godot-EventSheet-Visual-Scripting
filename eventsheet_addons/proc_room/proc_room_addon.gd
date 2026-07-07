## @ace_tags(procedural, roguelite)
## @ace_category("ProcRoom")
@icon("res://eventsheet_addons/behavior.svg")
class_name ProcRoomAddon
extends Node

## @ace_trigger
## @ace_name("On Graph Generated")
## @ace_category("ProcRoom")
signal on_graph_generated
## @ace_trigger
## @ace_name("On Room Entered")
## @ace_category("ProcRoom")
signal on_room_entered
## @ace_trigger
## @ace_name("On Traversal Blocked")
## @ace_category("ProcRoom")
signal on_traversal_blocked

# id ("d{depth}_{index}") -> {type, depth, index, from:Array, to:Array, visited, revealed, locked}.
var _rooms: Dictionary = {}
# type id -> {weight, min_depth, max_depth (-1=none), max_per_depth (-1=none)}.
var _types: Dictionary = {}
var _by_depth: Array = []
var _start_type: String = "start"
var _boss_type: String = "boss"
var _seed: String = ""
var _depths: int = 0
var _max_per: int = 3
var _current: String = ""
var _previous: String = ""
var _entered_id: String = ""
var _entered_type: String = ""
var _blocked_id: String = ""
var _block_reason: String = ""
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _use_shared: bool = false

## @ace_action
## @ace_name("Register Room Type")
## @ace_category("ProcRoom")
## @ace_description("Registers a room type that Generate may place: a weight (higher = commoner), the depth range it may appear in (max_depth -1 = anywhere), and a per-depth cap (-1 = no cap).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.register_room_type({type_id}, {weight}, {min_depth}, {max_depth}, {max_per_depth})")
func register_room_type(type_id: String, weight: float, min_depth: int, max_depth: int, max_per_depth: int) -> void:
	_types[type_id] = {"weight": maxf(weight, 0.0), "min_depth": min_depth, "max_depth": max_depth, "max_per_depth": max_per_depth}

## @ace_action
## @ace_name("Set Start Type")
## @ace_category("ProcRoom")
## @ace_description("The type name given to the single depth-0 room (default "start").")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.set_start_type({type_id})")
func set_start_type(type_id: String) -> void:
	_start_type = type_id

## @ace_action
## @ace_name("Set Boss Type")
## @ace_category("ProcRoom")
## @ace_description("The type name given to the single final-depth room (default "boss").")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.set_boss_type({type_id})")
func set_boss_type(type_id: String) -> void:
	_boss_type = type_id

## @ace_action
## @ace_name("Use Advanced Random")
## @ace_category("ProcRoom")
## @ace_description("When on, ProcRoom draws its randomness from the shared AdvancedRandom autoload, so one seed can drive every procedural system at once. When off (the default) it uses its own seeded generator. Set the AdvancedRandom seed before Generate for reproducible maps. Needs the Advanced Random pack installed (it safely falls back to the local generator if not).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.use_advanced_random({enabled})")
func use_advanced_random(enabled: bool) -> void:
	_use_shared = enabled

## @ace_action
## @ace_name("Generate")
## @ace_category("ProcRoom")
## @ace_description("Builds a reproducible tiered map from a seed: `depths` tiers (start at 0, boss at the last), up to `max_rooms_per_depth` rooms per interior tier. Same seed = same map. Fires On Graph Generated.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.generate({seed_text}, {depths}, {max_rooms_per_depth})")
func generate(seed_text: String, depths: int, max_rooms_per_depth: int) -> void:
	_seed = seed_text
	_depths = maxi(depths, 2)
	_max_per = maxi(max_rooms_per_depth, 1)
	_build()

## @ace_action
## @ace_name("Regenerate")
## @ace_category("ProcRoom")
## @ace_description("Rebuilds the map from the SAME seed + settings as the last Generate (a fresh run of the same layout).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.regenerate()")
func regenerate() -> void:
	if not _seed.is_empty():
		_build()

## @ace_action
## @ace_name("Enter Room")
## @ace_category("ProcRoom")
## @ace_description("Moves to a room if it's connected forward from the current room and not locked; otherwise fires On Traversal Blocked (read Block Reason). On success marks it visited + fires On Room Entered.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.enter_room({room_id})")
func enter_room(room_id: String) -> void:
	if not _rooms.has(room_id):
		return
	if not (_current.is_empty() or room_id in (_rooms[_current].to as Array)):
		_blocked_id = room_id
		_block_reason = "unreachable"
		on_traversal_blocked.emit()
		return
	if _rooms[room_id].locked:
		_blocked_id = room_id
		_block_reason = "locked"
		on_traversal_blocked.emit()
		return
	_previous = _current
	_current = room_id
	_rooms[room_id].visited = true
	_rooms[room_id].revealed = true
	_entered_id = room_id
	_entered_type = str(_rooms[room_id].type)
	on_room_entered.emit()

## @ace_action
## @ace_name("Force Enter Room")
## @ace_category("ProcRoom")
## @ace_description("Moves to any room ignoring connection + lock checks (for teleports / debug). Fires On Room Entered.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.force_enter_room({room_id})")
func force_enter_room(room_id: String) -> void:
	if not _rooms.has(room_id):
		return
	_previous = _current
	_current = room_id
	_rooms[room_id].visited = true
	_rooms[room_id].revealed = true
	_entered_id = room_id
	_entered_type = str(_rooms[room_id].type)
	on_room_entered.emit()

## @ace_action
## @ace_name("Lock Room")
## @ace_category("ProcRoom")
## @ace_description("Locks a room so Enter Room is blocked until unlocked (a key door).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.lock_room({room_id})")
func lock_room(room_id: String) -> void:
	if _rooms.has(room_id):
		_rooms[room_id].locked = true

## @ace_action
## @ace_name("Unlock Room")
## @ace_category("ProcRoom")
## @ace_description("Unlocks a locked room.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.unlock_room({room_id})")
func unlock_room(room_id: String) -> void:
	if _rooms.has(room_id):
		_rooms[room_id].locked = false

## @ace_action
## @ace_name("Reveal Room")
## @ace_category("ProcRoom")
## @ace_description("Marks a room as revealed (for fog-of-war maps).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.reveal_room({room_id})")
func reveal_room(room_id: String) -> void:
	if _rooms.has(room_id):
		_rooms[room_id].revealed = true

## @ace_action
## @ace_name("Reset Traversal")
## @ace_category("ProcRoom")
## @ace_description("Clears visited/revealed/locked and returns to the start room, keeping the same map (a fresh run of the same layout).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.reset_traversal()")
func reset_traversal() -> void:
	for id: String in _rooms:
		_rooms[id].visited = false
		_rooms[id].revealed = false
		_rooms[id].locked = false
	_current = "d0_0"
	_previous = ""
	if _rooms.has(_current):
		_rooms[_current].visited = true
		_rooms[_current].revealed = true

## @ace_condition
## @ace_name("Is Graph Ready")
## @ace_category("ProcRoom")
## @ace_description("Whether a map has been generated.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.is_graph_ready()")
func is_graph_ready() -> bool:
	return not _rooms.is_empty()

## @ace_condition
## @ace_name("Is Room Visited")
## @ace_category("ProcRoom")
## @ace_description("Whether a room has been entered.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.is_room_visited({room_id})")
func is_room_visited(room_id: String) -> bool:
	return _rooms.has(room_id) and bool(_rooms[room_id].visited)

## @ace_condition
## @ace_name("Is Room Available")
## @ace_category("ProcRoom")
## @ace_description("Whether a room can be entered right now (connected forward from current and unlocked).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.is_room_available({room_id})")
func is_room_available(room_id: String) -> bool:
	return _rooms.has(room_id) and room_id in (_rooms.get(_current, {"to": []}).to as Array) and not bool(_rooms[room_id].locked)

## @ace_condition
## @ace_name("Is Room Locked")
## @ace_category("ProcRoom")
## @ace_description("Whether a room is locked.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.is_room_locked({room_id})")
func is_room_locked(room_id: String) -> bool:
	return _rooms.has(room_id) and bool(_rooms[room_id].locked)

## @ace_condition
## @ace_name("Is Room Connected")
## @ace_category("ProcRoom")
## @ace_description("Whether room A connects forward to room B.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.is_room_connected({from_id}, {to_id})")
func is_room_connected(from_id: String, to_id: String) -> bool:
	return _rooms.has(from_id) and to_id in (_rooms[from_id].to as Array)

## @ace_expression
## @ace_name("Graph Seed")
## @ace_category("ProcRoom")
## @ace_description("The seed of the current map.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.graph_seed()")
func graph_seed() -> String:
	return _seed

## @ace_expression
## @ace_name("Total Rooms")
## @ace_category("ProcRoom")
## @ace_description("How many rooms the map has.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.total_rooms()")
func total_rooms() -> int:
	return _rooms.size()

## @ace_expression
## @ace_name("Total Depths")
## @ace_category("ProcRoom")
## @ace_description("How many depth tiers the map has.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.total_depths()")
func total_depths() -> int:
	return _depths

## @ace_expression
## @ace_name("Current Room")
## @ace_category("ProcRoom")
## @ace_description("The room the player is in ("" before entry).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.current_room()")
func current_room() -> String:
	return _current

## @ace_expression
## @ace_name("Current Room Type")
## @ace_category("ProcRoom")
## @ace_description("The type of the current room.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.current_room_type()")
func current_room_type() -> String:
	return str(_rooms[_current].type) if _rooms.has(_current) else ""

## @ace_expression
## @ace_name("Current Depth")
## @ace_category("ProcRoom")
## @ace_description("The depth tier of the current room.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.current_depth()")
func current_depth() -> int:
	return int(_rooms[_current].depth) if _rooms.has(_current) else 0

## @ace_expression
## @ace_name("Previous Room")
## @ace_category("ProcRoom")
## @ace_description("The room entered just before the current one.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.previous_room()")
func previous_room() -> String:
	return _previous

## @ace_expression
## @ace_name("Room Type")
## @ace_category("ProcRoom")
## @ace_description("A room's type ("" if unknown).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.room_type({room_id})")
func room_type(room_id: String) -> String:
	return str(_rooms[room_id].type) if _rooms.has(room_id) else ""

## @ace_expression
## @ace_name("Room Depth")
## @ace_category("ProcRoom")
## @ace_description("A room's depth tier (-1 if unknown).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.room_depth({room_id})")
func room_depth(room_id: String) -> int:
	return int(_rooms[room_id].depth) if _rooms.has(room_id) else -1

## @ace_expression
## @ace_name("Rooms At Depth")
## @ace_category("ProcRoom")
## @ace_description("How many rooms are at a depth tier.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.rooms_at_depth({depth})")
func rooms_at_depth(depth: int) -> int:
	return int(_by_depth[depth].size()) if depth >= 0 and depth < _by_depth.size() else 0

## @ace_expression
## @ace_name("Room At Depth")
## @ace_category("ProcRoom")
## @ace_description("The room id at a depth + index ("" out of range).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.room_at_depth({depth}, {index})")
func room_at_depth(depth: int, index: int) -> String:
	if depth < 0 or depth >= _by_depth.size():
		return ""
	var row: Array = _by_depth[depth]
	return str(row[index]) if index >= 0 and index < row.size() else ""

## @ace_expression
## @ace_name("Connections From")
## @ace_category("ProcRoom")
## @ace_description("How many rooms a room connects forward to.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.connections_from({room_id})")
func connections_from(room_id: String) -> int:
	return int(_rooms[room_id].to.size()) if _rooms.has(room_id) else 0

## @ace_expression
## @ace_name("Connection From")
## @ace_category("ProcRoom")
## @ace_description("The Nth room a room connects forward to ("" out of range).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.connection_from({room_id}, {index})")
func connection_from(room_id: String, index: int) -> String:
	if not _rooms.has(room_id):
		return ""
	var to: Array = _rooms[room_id].to
	return str(to[index]) if index >= 0 and index < to.size() else ""

## @ace_expression
## @ace_name("Visited Count")
## @ace_category("ProcRoom")
## @ace_description("How many rooms have been visited.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.visited_count()")
func visited_count() -> int:
	var n: int = 0
	for id: String in _rooms:
		if bool(_rooms[id].visited):
			n += 1
	return n

## @ace_expression
## @ace_name("Entered Id")
## @ace_category("ProcRoom")
## @ace_description("The room just entered (inside On Room Entered).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.entered_id()")
func entered_id() -> String:
	return _entered_id

## @ace_expression
## @ace_name("Entered Type")
## @ace_category("ProcRoom")
## @ace_description("The type of the room just entered (inside On Room Entered).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.entered_type()")
func entered_type() -> String:
	return _entered_type

## @ace_expression
## @ace_name("Blocked Id")
## @ace_category("ProcRoom")
## @ace_description("The room that couldn't be entered (inside On Traversal Blocked).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.blocked_id()")
func blocked_id() -> String:
	return _blocked_id

## @ace_expression
## @ace_name("Block Reason")
## @ace_category("ProcRoom")
## @ace_description("Why entry was blocked - "locked" or "unreachable" (inside On Traversal Blocked).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("ProcRoom.block_reason()")
func block_reason() -> String:
	return _block_reason

func _rand_float() -> float:
	# Randomness source: the shared AdvancedRandom autoload when Use Advanced Random is on and the
	# pack is installed, otherwise this pack's own seeded generator (the default - unchanged behaviour).
	if _use_shared and is_inside_tree():
		var shared: Node = get_node_or_null("/root/AdvancedRandom")
		if shared != null:
			return shared.random_value()
	return _rng.randf()

func _rand_int(minimum: int, maximum: int) -> int:
	if _use_shared and is_inside_tree():
		var shared: Node = get_node_or_null("/root/AdvancedRandom")
		if shared != null:
			return shared.random_int(minimum, maximum)
	return _rng.randi_range(minimum, maximum)

func _connect(a: String, b: String) -> void:
	if not (b in (_rooms[a].to as Array)):
		(_rooms[a].to as Array).append(b)
		(_rooms[b].from as Array).append(a)

func _pick_type(depth: int, counts: Dictionary) -> String:
	# Weighted-picks a room type valid at this depth, respecting min/max depth + per-depth caps.
	var eligible: Array = []
	var weights: Array = []
	for id: String in _types:
		var t: Dictionary = _types[id]
		if depth < int(t.min_depth):
			continue
		if t.max_depth >= 0 and depth > int(t.max_depth):
			continue
		if t.max_per_depth >= 0 and counts.get(id, 0) >= int(t.max_per_depth):
			continue
		eligible.append(id)
		weights.append(maxf(t.weight, 0.0001))
	if eligible.is_empty():
		return "room"
	var total: float = 0.0
	for w: float in weights:
		total += w
	var r: float = _rand_float() * total
	for i: int in eligible.size():
		r -= weights[i]
		if r <= 0.0:
			return str(eligible[i])
	return str(eligible[eligible.size() - 1])

func _build() -> void:
	_rooms.clear()
	_by_depth.clear()
	_rng.seed = _seed.hash()
	var per_depth_counts: Dictionary = {}
	for d: int in _depths:
		var count: int = 1 if (d == 0 or d == _depths - 1) else _rand_int(1, _max_per)
		var ids: Array = []
		per_depth_counts[d] = {}
		for i: int in count:
			var id: String = "d%d_%d" % [d, i]
			var rtype: String = _start_type if d == 0 else (_boss_type if d == _depths - 1 else _pick_type(d, per_depth_counts[d]))
			per_depth_counts[d][rtype] = int(per_depth_counts[d].get(rtype, 0)) + 1
			_rooms[id] = {"type": rtype, "depth": d, "index": i, "from": [], "to": [], "visited": false, "revealed": false, "locked": false}
			ids.append(id)
		_by_depth.append(ids)
	for d: int in range(_depths - 1):
		var here: Array = _by_depth[d]
		var nxt: Array = _by_depth[d + 1]
		for child: String in nxt:
			_connect(str(here[_rand_int(0, here.size() - 1)]), child)
		for parent: String in here:
			if _rand_float() < 0.5 and nxt.size() > 0:
				_connect(parent, str(nxt[_rand_int(0, nxt.size() - 1)]))
	_current = "d0_0"
	_previous = ""
	if _rooms.has(_current):
		_rooms[_current].visited = true
		_rooms[_current].revealed = true
	on_graph_generated.emit()

# ProcRoom: register as the ProcRoom autoload. Register weighted room types, Generate a seeded tiered map (start at depth 0, boss at the last depth), then move the player with Enter Room and read the visited/available/locked state to draw your own map. This pack is an event sheet - extend it by editing it.
