# Pack builder - proc_room (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## ProcRoom: a seeded procedural room-GRAPH generator as an AUTOLOAD sheet (ProcRoom) - a
## "Slay-the-Spire map as a data service". Register weighted room types, call Generate(seed), and you
## get a reproducible tiered map (depth 0 = start, depth N-1 = boss) plus visited/available/locked
## traversal bookkeeping as the player moves. It renders nothing - you read room ids and draw your own
## map. Ported from the Construct 3 addon, Godot-native + beginner-friendly:
##  - Discrete typed ACEs (Register Room Type / Generate) instead of the escaped-JSON blobs the C3
##    version used, and ONE API (the C3 addon doubled every verb with a JSON-string variant).
##  - Reproducible from a seed string via a seeded RandomNumberGenerator; every room is reachable
##    (each room gets at least one parent, so start always connects through to boss).
##  - Real getters return collections (Rooms At Depth, connection counts) instead of only Count+ByIndex.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "ProcRoom"
	sheet.host_class = "Node"
	sheet.custom_class_name = "ProcRoomAddon"
	sheet.class_description = "Seeded procedural room-map generation as the ProcRoom autoload: register weighted room types, call Generate with a seed string, and read back a tiered graph with one start room, branching depths, and a single boss room at the end. It draws nothing - you read stable room ids and paint your own map, and the same seed always rebuilds the exact same run."
	sheet.addon_category = "ProcRoom"
	sheet.addon_tags = PackedStringArray(["procedural", "roguelite"])
	var about: CommentRow = CommentRow.new()
	about.text = "ProcRoom: register as the ProcRoom autoload. Register weighted room types, Generate a seeded tiered map (start at depth 0, boss at the last depth), then move the player with Enter Room and read the visited/available/locked state to draw your own map. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Graph Generated\")",
		"## @ace_category(\"ProcRoom\")",
		"signal on_graph_generated()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Room Entered\")",
		"## @ace_category(\"ProcRoom\")",
		"signal on_room_entered()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Traversal Blocked\")",
		"## @ace_category(\"ProcRoom\")",
		"signal on_traversal_blocked()",
		"",
		"# id (\"d{depth}_{index}\") -> {type, depth, index, from:Array, to:Array, visited, revealed, locked}.",
		"var _rooms: Dictionary = {}",
		"# type id -> {weight, min_depth, max_depth (-1=none), max_per_depth (-1=none)}.",
		"var _types: Dictionary = {}",
		"var _by_depth: Array = []",
		"var _start_type: String = \"start\"",
		"var _boss_type: String = \"boss\"",
		"var _seed: String = \"\"",
		"var _depths: int = 0",
		"var _max_per: int = 3",
		"var _current: String = \"\"",
		"var _previous: String = \"\"",
		"var _entered_id: String = \"\"",
		"var _entered_type: String = \"\"",
		"var _blocked_id: String = \"\"",
		"var _block_reason: String = \"\"",
		"var _rng: RandomNumberGenerator = RandomNumberGenerator.new()",
		"var _use_shared: bool = false",
		"",
		"# Randomness source: the shared AdvancedRandom autoload when Use Advanced Random is on and the",
		"# pack is installed, otherwise this pack's own seeded generator (the default - unchanged behaviour).",
		"func _rand_float() -> float:",
		"\tif _use_shared and is_inside_tree():",
		"\t\tvar shared: Node = get_node_or_null(\"/root/AdvancedRandom\")",
		"\t\tif shared != null:",
		"\t\t\treturn shared.random_value()",
		"\treturn _rng.randf()",
		"",
		"func _rand_int(minimum: int, maximum: int) -> int:",
		"\tif _use_shared and is_inside_tree():",
		"\t\tvar shared: Node = get_node_or_null(\"/root/AdvancedRandom\")",
		"\t\tif shared != null:",
		"\t\t\treturn shared.random_int(minimum, maximum)",
		"\treturn _rng.randi_range(minimum, maximum)",
		"",
		"func _connect(a: String, b: String) -> void:",
		"\tif not (b in (_rooms[a].to as Array)):",
		"\t\t(_rooms[a].to as Array).append(b)",
		"\t\t(_rooms[b].from as Array).append(a)",
		"",
		"# Weighted-picks a room type valid at this depth, respecting min/max depth + per-depth caps.",
		"func _pick_type(depth: int, counts: Dictionary) -> String:",
		"\tvar eligible: Array = []",
		"\tvar weights: Array = []",
		"\tfor id: String in _types:",
		"\t\tvar t: Dictionary = _types[id]",
		"\t\tif depth < int(t.min_depth):",
		"\t\t\tcontinue",
		"\t\tif t.max_depth >= 0 and depth > int(t.max_depth):",
		"\t\t\tcontinue",
		"\t\tif t.max_per_depth >= 0 and counts.get(id, 0) >= int(t.max_per_depth):",
		"\t\t\tcontinue",
		"\t\teligible.append(id)",
		"\t\tweights.append(maxf(t.weight, 0.0001))",
		"\tif eligible.is_empty():",
		"\t\treturn \"room\"",
		"\tvar total: float = 0.0",
		"\tfor w: float in weights:",
		"\t\ttotal += w",
		"\tvar r: float = _rand_float() * total",
		"\tfor i: int in eligible.size():",
		"\t\tr -= weights[i]",
		"\t\tif r <= 0.0:",
		"\t\t\treturn str(eligible[i])",
		"\treturn str(eligible[eligible.size() - 1])",
		"",
		"func _build() -> void:",
		"\t_rooms.clear()",
		"\t_by_depth.clear()",
		"\t_rng.seed = _seed.hash()",
		"\tvar per_depth_counts: Dictionary = {}",
		"\tfor d: int in _depths:",
		"\t\tvar count: int = 1 if (d == 0 or d == _depths - 1) else _rand_int(1, _max_per)",
		"\t\tvar ids: Array = []",
		"\t\tper_depth_counts[d] = {}",
		"\t\tfor i: int in count:",
		"\t\t\tvar id: String = \"d%d_%d\" % [d, i]",
		"\t\t\tvar rtype: String = _start_type if d == 0 else (_boss_type if d == _depths - 1 else _pick_type(d, per_depth_counts[d]))",
		"\t\t\tper_depth_counts[d][rtype] = int(per_depth_counts[d].get(rtype, 0)) + 1",
		"\t\t\t_rooms[id] = {\"type\": rtype, \"depth\": d, \"index\": i, \"from\": [], \"to\": [], \"visited\": false, \"revealed\": false, \"locked\": false}",
		"\t\t\tids.append(id)",
		"\t\t_by_depth.append(ids)",
		"\tfor d: int in range(_depths - 1):",
		"\t\tvar here: Array = _by_depth[d]",
		"\t\tvar nxt: Array = _by_depth[d + 1]",
		"\t\tfor child: String in nxt:",
		"\t\t\t_connect(str(here[_rand_int(0, here.size() - 1)]), child)",
		"\t\tfor parent: String in here:",
		"\t\t\tif _rand_float() < 0.5 and nxt.size() > 0:",
		"\t\t\t\t_connect(parent, str(nxt[_rand_int(0, nxt.size() - 1)]))",
		"\t_current = \"d0_0\"",
		"\t_previous = \"\"",
		"\tif _rooms.has(_current):",
		"\t\t_rooms[_current].visited = true",
		"\t\t_rooms[_current].revealed = true",
		"\ton_graph_generated.emit()"
	]))
	sheet.events.append(block)

	# --- Registry ---
	Lib.append_function(sheet, "register_room_type", "Register Room Type", "ProcRoom", "Registers a room type that Generate may place: a weight (higher = commoner), the depth range it may appear in (max_depth -1 = anywhere), and a per-depth cap (-1 = no cap).",
		[["type_id", "String"], ["weight", "float"], ["min_depth", "int"], ["max_depth", "int"], ["max_per_depth", "int"]],
		"_types[type_id] = {\"weight\": maxf(weight, 0.0), \"min_depth\": min_depth, \"max_depth\": max_depth, \"max_per_depth\": max_per_depth}")
	Lib.append_function(sheet, "set_start_type", "Set Start Type", "ProcRoom", "The type name given to the single depth-0 room (default \"start\").",
		[["type_id", "String"]],
		"_start_type = type_id")
	Lib.append_function(sheet, "set_boss_type", "Set Boss Type", "ProcRoom", "The type name given to the single final-depth room (default \"boss\").",
		[["type_id", "String"]],
		"_boss_type = type_id")
	Lib.append_function(sheet, "use_advanced_random", "Use Advanced Random", "ProcRoom", "When on, ProcRoom draws its randomness from the shared AdvancedRandom autoload, so one seed can drive every procedural system at once. When off (the default) it uses its own seeded generator. Set the AdvancedRandom seed before Generate for reproducible maps. Needs the Advanced Random pack installed (it safely falls back to the local generator if not).",
		[["enabled", "bool"]],
		"_use_shared = enabled")

	# --- Generation ---
	Lib.append_function(sheet, "generate", "Generate", "ProcRoom", "Builds a reproducible tiered map from a seed: `depths` tiers (start at 0, boss at the last), up to `max_rooms_per_depth` rooms per interior tier. Same seed = same map. Fires On Graph Generated.",
		[["seed_text", "String"], ["depths", "int"], ["max_rooms_per_depth", "int"]],
		"_seed = seed_text\n_depths = maxi(depths, 2)\n_max_per = maxi(max_rooms_per_depth, 1)\n_build()")
	Lib.append_function(sheet, "regenerate", "Regenerate", "ProcRoom", "Rebuilds the map from the SAME seed + settings as the last Generate (a fresh run of the same layout).",
		[],
		"if not _seed.is_empty():\n\t_build()")

	# --- Traversal ---
	Lib.append_function(sheet, "enter_room", "Enter Room", "ProcRoom", "Moves to a room if it's connected forward from the current room and not locked; otherwise fires On Traversal Blocked (read Block Reason). On success marks it visited + fires On Room Entered.",
		[["room_id", "String"]],
		"\n".join(PackedStringArray([
			"if not _rooms.has(room_id):",
			"\treturn",
			"if not (_current.is_empty() or room_id in (_rooms[_current].to as Array)):",
			"\t_blocked_id = room_id",
			"\t_block_reason = \"unreachable\"",
			"\ton_traversal_blocked.emit()",
			"\treturn",
			"if _rooms[room_id].locked:",
			"\t_blocked_id = room_id",
			"\t_block_reason = \"locked\"",
			"\ton_traversal_blocked.emit()",
			"\treturn",
			"_previous = _current",
			"_current = room_id",
			"_rooms[room_id].visited = true",
			"_rooms[room_id].revealed = true",
			"_entered_id = room_id",
			"_entered_type = str(_rooms[room_id].type)",
			"on_room_entered.emit()"
		])))
	Lib.append_function(sheet, "force_enter_room", "Force Enter Room", "ProcRoom", "Moves to any room ignoring connection + lock checks (for teleports / debug). Fires On Room Entered.",
		[["room_id", "String"]],
		"if not _rooms.has(room_id):\n\treturn\n_previous = _current\n_current = room_id\n_rooms[room_id].visited = true\n_rooms[room_id].revealed = true\n_entered_id = room_id\n_entered_type = str(_rooms[room_id].type)\non_room_entered.emit()")
	Lib.append_function(sheet, "lock_room", "Lock Room", "ProcRoom", "Locks a room so Enter Room is blocked until unlocked (a key door).",
		[["room_id", "String"]],
		"if _rooms.has(room_id):\n\t_rooms[room_id].locked = true")
	Lib.append_function(sheet, "unlock_room", "Unlock Room", "ProcRoom", "Unlocks a locked room.",
		[["room_id", "String"]],
		"if _rooms.has(room_id):\n\t_rooms[room_id].locked = false")
	Lib.append_function(sheet, "reveal_room", "Reveal Room", "ProcRoom", "Marks a room as revealed (for fog-of-war maps).",
		[["room_id", "String"]],
		"if _rooms.has(room_id):\n\t_rooms[room_id].revealed = true")
	Lib.append_function(sheet, "reset_traversal", "Reset Traversal", "ProcRoom", "Clears visited/revealed/locked and returns to the start room, keeping the same map (a fresh run of the same layout).",
		[],
		"for id: String in _rooms:\n\t_rooms[id].visited = false\n\t_rooms[id].revealed = false\n\t_rooms[id].locked = false\n_current = \"d0_0\"\n_previous = \"\"\nif _rooms.has(_current):\n\t_rooms[_current].visited = true\n\t_rooms[_current].revealed = true")

	# --- Conditions ---
	_condition(sheet, "is_graph_ready", "Is Graph Ready", "ProcRoom", "Whether a map has been generated.", [],
		"return not _rooms.is_empty()")
	_condition(sheet, "is_room_visited", "Is Room Visited", "ProcRoom", "Whether a room has been entered.", [["room_id", "String"]],
		"return _rooms.has(room_id) and bool(_rooms[room_id].visited)")
	_condition(sheet, "is_room_available", "Is Room Available", "ProcRoom", "Whether a room can be entered right now (connected forward from current and unlocked).", [["room_id", "String"]],
		"return _rooms.has(room_id) and room_id in (_rooms.get(_current, {\"to\": []}).to as Array) and not bool(_rooms[room_id].locked)")
	_condition(sheet, "is_room_locked", "Is Room Locked", "ProcRoom", "Whether a room is locked.", [["room_id", "String"]],
		"return _rooms.has(room_id) and bool(_rooms[room_id].locked)")
	_condition(sheet, "is_room_connected", "Is Room Connected", "ProcRoom", "Whether room A connects forward to room B.", [["from_id", "String"], ["to_id", "String"]],
		"return _rooms.has(from_id) and to_id in (_rooms[from_id].to as Array)")

	# --- Expressions: graph ---
	_expr(sheet, "graph_seed", "Graph Seed", "ProcRoom", "The seed of the current map.", [],
		"return _seed", TYPE_STRING)
	_expr(sheet, "total_rooms", "Total Rooms", "ProcRoom", "How many rooms the map has.", [],
		"return _rooms.size()", TYPE_INT)
	_expr(sheet, "total_depths", "Total Depths", "ProcRoom", "How many depth tiers the map has.", [],
		"return _depths", TYPE_INT)
	# --- Expressions: current room ---
	_expr(sheet, "current_room", "Current Room", "ProcRoom", "The room the player is in (\"\" before entry).", [],
		"return _current", TYPE_STRING)
	_expr(sheet, "current_room_type", "Current Room Type", "ProcRoom", "The type of the current room.", [],
		"return str(_rooms[_current].type) if _rooms.has(_current) else \"\"", TYPE_STRING)
	_expr(sheet, "current_depth", "Current Depth", "ProcRoom", "The depth tier of the current room.", [],
		"return int(_rooms[_current].depth) if _rooms.has(_current) else 0", TYPE_INT)
	_expr(sheet, "previous_room", "Previous Room", "ProcRoom", "The room entered just before the current one.", [],
		"return _previous", TYPE_STRING)
	# --- Expressions: any room ---
	_expr(sheet, "room_type", "Room Type", "ProcRoom", "A room's type (\"\" if unknown).", [["room_id", "String"]],
		"return str(_rooms[room_id].type) if _rooms.has(room_id) else \"\"", TYPE_STRING)
	_expr(sheet, "room_depth", "Room Depth", "ProcRoom", "A room's depth tier (-1 if unknown).", [["room_id", "String"]],
		"return int(_rooms[room_id].depth) if _rooms.has(room_id) else -1", TYPE_INT)
	_expr(sheet, "rooms_at_depth", "Rooms At Depth", "ProcRoom", "How many rooms are at a depth tier.", [["depth", "int"]],
		"return int(_by_depth[depth].size()) if depth >= 0 and depth < _by_depth.size() else 0", TYPE_INT)
	_expr(sheet, "room_at_depth", "Room At Depth", "ProcRoom", "The room id at a depth + index (\"\" out of range).", [["depth", "int"], ["index", "int"]],
		"if depth < 0 or depth >= _by_depth.size():\n\treturn \"\"\nvar row: Array = _by_depth[depth]\nreturn str(row[index]) if index >= 0 and index < row.size() else \"\"", TYPE_STRING)
	# --- Expressions: connections + traversal ---
	_expr(sheet, "connections_from", "Connections From", "ProcRoom", "How many rooms a room connects forward to.", [["room_id", "String"]],
		"return int(_rooms[room_id].to.size()) if _rooms.has(room_id) else 0", TYPE_INT)
	_expr(sheet, "connection_from", "Connection From", "ProcRoom", "The Nth room a room connects forward to (\"\" out of range).", [["room_id", "String"], ["index", "int"]],
		"if not _rooms.has(room_id):\n\treturn \"\"\nvar to: Array = _rooms[room_id].to\nreturn str(to[index]) if index >= 0 and index < to.size() else \"\"", TYPE_STRING)
	_expr(sheet, "visited_count", "Visited Count", "ProcRoom", "How many rooms have been visited.", [],
		"var n: int = 0\nfor id: String in _rooms:\n\tif bool(_rooms[id].visited):\n\t\tn += 1\nreturn n", TYPE_INT)
	# --- Expressions: On Room Entered / Blocked context ---
	_expr(sheet, "entered_id", "Entered Id", "ProcRoom", "The room just entered (inside On Room Entered).", [],
		"return _entered_id", TYPE_STRING)
	_expr(sheet, "entered_type", "Entered Type", "ProcRoom", "The type of the room just entered (inside On Room Entered).", [],
		"return _entered_type", TYPE_STRING)
	_expr(sheet, "blocked_id", "Blocked Id", "ProcRoom", "The room that couldn't be entered (inside On Traversal Blocked).", [],
		"return _blocked_id", TYPE_STRING)
	_expr(sheet, "block_reason", "Block Reason", "ProcRoom", "Why entry was blocked - \"locked\" or \"unreachable\" (inside On Traversal Blocked).", [],
		"return _block_reason", TYPE_STRING)

	# Save-state seam - deliberately unpublished; the Save System provides the user-facing verbs.
	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"# Generator config (_types, _start_type, _boss_type, _depths, _max_per) is skipped -",
		"# sheets re-register it on ready; only the generated run state is snapshotted.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"rooms\": _rooms.duplicate(true),",
		"\t\t\"by_depth\": _by_depth.duplicate(true),",
		"\t\t\"current\": _current,",
		"\t\t\"previous\": _previous,",
		"\t\t\"seed\": _seed",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_rooms = (state.get(\"rooms\", {}) as Dictionary).duplicate(true)",
		"\t_by_depth = (state.get(\"by_depth\", []) as Array).duplicate(true)",
		"\t_current = str(state.get(\"current\", \"\"))",
		"\t_previous = str(state.get(\"previous\", \"\"))",
		"\t_seed = str(state.get(\"seed\", \"\"))"
	]))
	sheet.events.append(persistence)

	return Lib.save_pack(sheet, "res://eventsheet_addons/proc_room/proc_room_addon")


static func _condition(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = TYPE_BOOL
	sheet.functions.append(fn)


static func _expr(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String, ret: int) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = ret
	sheet.functions.append(fn)
