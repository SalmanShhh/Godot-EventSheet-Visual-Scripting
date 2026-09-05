# Godot EventSheets - the Streamer 3D pack, driven directly.
#
# The 3D twin says the same words as the 2D pack and answers one question the 2D pack does not
# have: whether HEIGHT is a cell axis. Off - the default, and what an open world wants - the grid
# is flat, every cell's Y is 0 however high the player climbs, and a radius of one is nine chunks.
# On, cells stack, and the same radius is twenty-seven. That difference is invisible in a
# screenshot and expensive to get wrong, so it is pinned by value here.
#
# Everything else is the pack's timing, which no picture of a world shows either: the wanted set,
# one threaded request per frame, the keep radius that stops a border step reloading what it just
# freed, and On Chunk Unloading reaching the sheet while the chunk is still a node. The file loads
# the COMPILED pack, extends it with a stub loader - the seams the pack keeps small on purpose -
# and drives `_process` by hand, with no scene tree, no physics and no disk.
@tool
class_name Streamer3DPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/streamer_3d/streamer_3d_behavior.gd"
const TEST := "streamer_3d_pack_test"
const STUB_PATH := "user://streamer_3d_pack_test_stub.gd"

## The stub loader. The drop seam frees rather than queues, because a test has no main loop for a
## deferred free to happen in - which is exactly the reason that line is a seam and not a call
## site. Written to a real file, because `extends "res://..."` needs a path on both sides.
const STUB_SOURCE := """@tool
extends \"res://eventsheet_addons/streamer_3d/streamer_3d_behavior.gd\"

var requested_paths: Array[String] = []
var absent_paths: Array[String] = []
var failed_paths: Array[String] = []
var broken_paths: Array[String] = []

func _chunk_scene_exists(path: String) -> bool:
	return not absent_paths.has(path)

func _request_load(path: String) -> int:
	requested_paths.append(path)
	return OK

func _load_state(path: String) -> int:
	if failed_paths.has(path):
		return ResourceLoader.THREAD_LOAD_FAILED
	return ResourceLoader.THREAD_LOAD_LOADED

func _take_chunk(path: String) -> Node:
	return null if broken_paths.has(path) else Node3D.new()

func _drop_chunk(chunk: Node) -> void:
	chunk.free()
"""


static func run() -> bool:
	var script: GDScript = load(PACK)
	var passed: bool = SUPPORT.check(TEST, "the pack loads and parses", script != null, true)
	if script == null:
		return passed
	var stub: GDScript = _stub_script()
	passed = SUPPORT.check(TEST, "the stub loader extends the shipped pack", stub != null, true) and passed
	if stub == null:
		return false
	passed = _every_verb_addresses_the_behavior() and passed
	passed = _a_flat_grid_ignores_height(stub) and passed
	passed = _stream_height_makes_height_a_cell_axis(stub) and passed
	passed = _the_wanted_set_is_the_rings_around_the_node(stub) and passed
	passed = _one_request_per_tick(stub) and passed
	passed = _the_keep_radius_is_hysteresis_on_the_border(stub) and passed
	passed = _a_pinned_chunk_survives_distance(stub) and passed
	passed = _unloading_reaches_the_sheet_before_the_free(stub) and passed
	passed = _idle_fires_once_when_the_world_settles(stub) and passed
	passed = _a_missing_chunk_scene_is_skipped_in_silence(stub) and passed
	passed = _a_chunk_that_will_not_build_is_asked_for_once(stub) and passed
	passed = _the_world_a_row_sees_while_a_chunk_leaves(stub) and passed
	passed = _a_streamer_whose_node_is_gone_parks_its_tick(stub) and passed
	return passed


## The stub, written out and loaded.
static func _stub_script() -> GDScript:
	var file: FileAccess = FileAccess.open(STUB_PATH, FileAccess.WRITE)
	if file == null:
		return null
	file.store_string(STUB_SOURCE)
	file.close()
	return load(STUB_PATH) as GDScript


# ── What the pack publishes ───────────────────────────────────────────────────────────────────


## The twin publishes the same nine verbs and the same three triggers as the 2D pack, each
## addressing its own behavior by name. Counted against the SHIPPED bytes, so a verb quietly
## losing its template - or the pair drifting apart - is a red line rather than a gap.
static func _every_verb_addresses_the_behavior() -> bool:
	var source: String = FileAccess.get_file_as_string(PACK)
	var templates: int = 0
	var not_the_behavior: int = 0
	var triggers: int = 0
	for line: String in source.split("\n"):
		if line.begins_with("## @ace_trigger"):
			triggers += 1
		if not line.begins_with("## @ace_codegen_template("):
			continue
		templates += 1
		if not line.begins_with("## @ace_codegen_template(\"$Streamer3DBehavior."):
			not_the_behavior += 1
	return SUPPORT.pins(TEST, [
		["every published verb addresses the behavior by name", not_the_behavior, 0],
		["and all nine of them are published, the same nine the 2D pack has", templates, 9],
		["the three triggers are declared as signals", triggers, 3],
		["the host is a Node3D, because a radius is measured in world space",
			source.contains("var host: Node3D = null"), true],
	])


# ── The one question the 2D pack does not have ────────────────────────────────────────────────


## The default grid is FLAT: an open world is wide, not tall, and a player who climbs a mountain
## must not walk out of the chunk they are standing on.
static func _a_flat_grid_ignores_height(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	streamer.cell_size = Vector3(100.0, 100.0, 100.0)
	var pins: Array = [
		["a point inside the first cell is cell (0, 0, 0)",
			streamer.chunk_of(Vector3(1.0, 1.0, 1.0)), Vector3i(0, 0, 0)],
		["one metre before the origin is the cell before it, on both flat axes",
			streamer.chunk_of(Vector3(-1.0, 0.0, -1.0)), Vector3i(-1, 0, -1)],
		["and climbing 900 metres changes nothing, because height is not an axis yet",
			streamer.chunk_of(Vector3(50.0, 900.0, 50.0)), Vector3i(0, 0, 0)],
	]
	streamer.free()
	return SUPPORT.pins(TEST, pins)


## With Stream Height on, cells stack - and a radius costs a great deal more, which is the fact
## worth knowing before switching it on. A radius of one is nine chunks flat and twenty-seven
## stacked.
static func _stream_height_makes_height_a_cell_axis(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node3D = Node3D.new()
	streamer.cell_size = Vector3(100.0, 100.0, 100.0)
	streamer.stream_height = true
	var cell_up_there: Vector3i = streamer.chunk_of(Vector3(50.0, 250.0, 50.0))
	around.position = Vector3(50.0, 50.0, 50.0)
	streamer.stream_around(around, 1, "res://world/chunks")
	for tick: int in range(40):
		streamer._process(0.016)
	var stacked: int = streamer.loaded_chunk_count()
	streamer.free()
	around.free()
	return SUPPORT.pins(TEST, [
		["height becomes a cell axis, so 250 metres up is the third level", cell_up_there,
			Vector3i(0, 2, 0)],
		["and a radius of one cell is twenty-seven chunks rather than nine", stacked, 27],
	])


# ── The grid ──────────────────────────────────────────────────────────────────────────────────


## The wanted set is the box of cells within the radius, asked for nearest ring first, so the
## ground under the player arrives before the horizon does. Pinned as the whole request order,
## because "nearest first" is the difference between a world that fills in around you and one
## that fills in from a corner.
static func _the_wanted_set_is_the_rings_around_the_node(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node3D = Node3D.new()
	around.position = Vector3(50.0, 0.0, 50.0)
	streamer.cell_size = Vector3(100.0, 100.0, 100.0)
	streamer.stream_around(around, 1, "res://world/chunks")
	for tick: int in range(12):
		streamer._process(0.016)
	var requested: Array = streamer.requested_paths.duplicate()
	var loaded: int = streamer.loaded_chunk_count()
	streamer.free()
	around.free()
	return SUPPORT.pins(TEST, [
		["the centre cell is asked for first, then its ring, in a fixed order", requested, [
			"res://world/chunks/chunk_0_0_0.tscn",
			"res://world/chunks/chunk_-1_0_-1.tscn",
			"res://world/chunks/chunk_-1_0_0.tscn",
			"res://world/chunks/chunk_-1_0_1.tscn",
			"res://world/chunks/chunk_0_0_-1.tscn",
			"res://world/chunks/chunk_0_0_1.tscn",
			"res://world/chunks/chunk_1_0_-1.tscn",
			"res://world/chunks/chunk_1_0_0.tscn",
			"res://world/chunks/chunk_1_0_1.tscn",
		]],
		["a flat radius of one cell is nine chunks in the world", loaded, 9],
		["and twelve frames asked for no more than the nine", requested.size(), 9],
	])


## ONE threaded request per frame, however many cells the radius wants. This is the whole reason
## a streamed world does not stutter, and it is invisible in any screenshot.
static func _one_request_per_tick(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node3D = Node3D.new()
	streamer.cell_size = Vector3(100.0, 100.0, 100.0)
	streamer.stream_around(around, 2, "res://world/chunks")
	var after_each_tick: Array[int] = []
	for tick: int in range(4):
		streamer._process(0.016)
		after_each_tick.append(streamer.requested_paths.size())
	var still_loading: bool = streamer.is_loading_chunks()
	streamer.free()
	around.free()
	return SUPPORT.pins(TEST, [
		["four frames start four requests, one each", after_each_tick, [1, 2, 3, 4]],
		["and a radius of two cells is still loading after them", still_loading, true],
	])


# ── The border ────────────────────────────────────────────────────────────────────────────────


## The keep radius is hysteresis. A chunk leaves the wanted set at radius + 1 and is only freed
## past radius + keep, so a vehicle crossing a cell border reloads nothing - the thrash bug in
## every hand-written loader.
static func _the_keep_radius_is_hysteresis_on_the_border(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node3D = Node3D.new()
	streamer.cell_size = Vector3(100.0, 100.0, 100.0)
	streamer.keep_radius_cells = 1
	around.position = Vector3(50.0, 0.0, 50.0)
	streamer.stream_around(around, 1, "res://world/chunks")
	for tick: int in range(12):
		streamer._process(0.016)
	var settled: int = streamer.loaded_chunk_count()
	around.position = Vector3(150.0, 0.0, 50.0)
	for tick: int in range(6):
		streamer._process(0.016)
	var after_one_step: int = streamer.loaded_chunk_count()
	var requests_after_one_step: int = streamer.requested_paths.size()
	around.position = Vector3(350.0, 0.0, 50.0)
	for tick: int in range(12):
		streamer._process(0.016)
	var far_column_gone: bool = not streamer.chunk_is_loaded_at(Vector3(-50.0, 0.0, 50.0))
	streamer.free()
	around.free()
	return SUPPORT.pins(TEST, [
		["a radius of one settles at nine chunks", settled, 9],
		["stepping over the border keeps the column behind, and adds the one ahead",
			after_one_step, 12],
		["and nothing already loaded was asked for a second time", requests_after_one_step, 12],
		["three cells out, the first column is finally released", far_column_gone, true],
	])


## A pinned chunk is the hub, the hangar, the room the quest is in: distance never takes it, and
## only Release Chunk does.
static func _a_pinned_chunk_survives_distance(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node3D = Node3D.new()
	streamer.cell_size = Vector3(100.0, 100.0, 100.0)
	streamer.keep_radius_cells = 0
	streamer.stream_around(around, 0, "res://world/chunks")
	streamer.keep_chunk(Vector3i(0, 0, 0))
	for tick: int in range(4):
		streamer._process(0.016)
	var pinned_loaded: bool = streamer.chunk_is_loaded_at(Vector3(50.0, 0.0, 50.0))
	around.position = Vector3(950.0, 0.0, 950.0)
	for tick: int in range(6):
		streamer._process(0.016)
	var pinned_survived: bool = streamer.chunk_is_loaded_at(Vector3(50.0, 0.0, 50.0))
	streamer.release_chunk(Vector3i(0, 0, 0))
	var released: bool = not streamer.chunk_is_loaded_at(Vector3(50.0, 0.0, 50.0))
	streamer.free()
	around.free()
	return SUPPORT.pins(TEST, [
		["Keep Chunk loads the cell it pins", pinned_loaded, true],
		["ten cells away, the pinned chunk is still there", pinned_survived, true],
		["and Release Chunk is the only thing that takes it", released, true],
	])


# ── The two triggers that have to reach the sheet ─────────────────────────────────────────────


## On Chunk Unloading fires BEFORE the drop, with the node still valid, which is the only thing
## that makes "save what the player changed in this chunk" a row rather than a race.
static func _unloading_reaches_the_sheet_before_the_free(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node3D = Node3D.new()
	streamer.cell_size = Vector3(100.0, 100.0, 100.0)
	streamer.keep_radius_cells = 0
	var seen: Array = []
	streamer.chunk_unloading.connect(func(chunk: Node, cell: Vector3i) -> void:
		seen.append([is_instance_valid(chunk), chunk.get_parent() != null, cell]))
	streamer.stream_around(around, 0, "res://world/chunks")
	for tick: int in range(3):
		streamer._process(0.016)
	var loaded_first: int = streamer.loaded_chunk_count()
	around.position = Vector3(950.0, 0.0, 50.0)
	for tick: int in range(3):
		streamer._process(0.016)
	streamer.free()
	around.free()
	return SUPPORT.pins(TEST, [
		["the cell under the node loaded", loaded_first, 1],
		["and leaving it told the sheet exactly once", seen.size(), 1],
		["with the chunk still a node in the world when the row runs",
			seen[0] if seen.size() == 1 else [], [true, true, Vector3i(0, 0, 0)]],
	])


## On Streaming Idle is the row a loading screen waits on, so it must fire when the world settles
## and then stay quiet - not once per frame for the rest of the game.
static func _idle_fires_once_when_the_world_settles(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node3D = Node3D.new()
	streamer.cell_size = Vector3(100.0, 100.0, 100.0)
	var idle_count: Array[int] = [0]
	streamer.streaming_idle.connect(func() -> void: idle_count[0] += 1)
	streamer.stream_around(around, 1, "res://world/chunks")
	for tick: int in range(4):
		streamer._process(0.016)
	var while_loading: int = idle_count[0]
	for tick: int in range(12):
		streamer._process(0.016)
	var once_settled: int = idle_count[0]
	streamer.free()
	around.free()
	return SUPPORT.pins(TEST, [
		["nothing is announced while chunks are still on their way", while_loading, 0],
		["the settled world is announced once, and stays quiet after it", once_settled, 1],
	])


## A hole in the chunk grid is a level-design fact, not an error: the world simply has nothing
## there. The pack skips it in silence (the Doctor is where it is reported) and carries on with
## the rest of the ring rather than stalling on it.
static func _a_missing_chunk_scene_is_skipped_in_silence(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node3D = Node3D.new()
	streamer.cell_size = Vector3(100.0, 100.0, 100.0)
	streamer.absent_paths = ["res://world/chunks/chunk_0_0_0.tscn"] as Array[String]
	streamer.stream_around(around, 1, "res://world/chunks")
	for tick: int in range(12):
		streamer._process(0.016)
	var requested: Array = streamer.requested_paths.duplicate()
	var loaded: int = streamer.loaded_chunk_count()
	var quiet: bool = not streamer.is_loading_chunks()
	streamer.free()
	around.free()
	return SUPPORT.pins(TEST, [
		["the missing cell is never requested",
			requested.has("res://world/chunks/chunk_0_0_0.tscn"), false],
		["the other eight of the ring still arrive", loaded, 8],
		["and the streamer settles instead of retrying the hole for ever", quiet, true],
	])


## The other half of the hole: a cell whose scene IS there and cannot be turned into a chunk. A
## failed threaded load and a file that is not a PackedScene both end with nothing to place, and
## a cell that nothing writes down is wanted again the very next frame - which is one engine
## error per frame for ever, a streamer that never says it is idle, and a loading screen that
## never goes away. Each is asked for exactly once.
static func _a_chunk_that_will_not_build_is_asked_for_once(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node3D = Node3D.new()
	streamer.cell_size = Vector3(100.0, 100.0, 100.0)
	streamer.failed_paths = ["res://world/chunks/chunk_0_0_0.tscn"] as Array[String]
	streamer.broken_paths = ["res://world/chunks/chunk_1_0_0.tscn"] as Array[String]
	var idle_count: Array[int] = [0]
	streamer.streaming_idle.connect(func() -> void: idle_count[0] += 1)
	streamer.stream_around(around, 1, "res://world/chunks")
	for tick: int in range(20):
		streamer._process(0.016)
	var requested: Array = streamer.requested_paths.duplicate()
	var failed_asks: int = requested.count("res://world/chunks/chunk_0_0_0.tscn")
	var broken_asks: int = requested.count("res://world/chunks/chunk_1_0_0.tscn")
	var loaded: int = streamer.loaded_chunk_count()
	var quiet: bool = not streamer.is_loading_chunks()
	var settled: int = idle_count[0]
	streamer.free()
	around.free()
	return SUPPORT.pins(TEST, [
		["a chunk whose load failed is asked for once", failed_asks, 1],
		["a file that is not a scene is asked for once", broken_asks, 1],
		["the other seven of the ring still arrive", loaded, 7],
		["the streamer stops loading instead of retrying for ever", quiet, true],
		["and the world settles exactly once", settled, 1],
	])


## Inside On Chunk Unloading the chunk is still in the world, so the two questions a row would
## ask about it there answer about the world it is looking at - not about the one it is a frame
## away from becoming.
static func _the_world_a_row_sees_while_a_chunk_leaves(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node3D = Node3D.new()
	streamer.cell_size = Vector3(100.0, 100.0, 100.0)
	streamer.keep_radius_cells = 0
	var seen: Array = []
	streamer.chunk_unloading.connect(func(_chunk: Node, cell: Vector3i) -> void:
		seen.append([streamer.chunk_is_loaded_at(Vector3(cell) * 100.0 + Vector3(50.0, 50.0, 50.0)),
			streamer.loaded_chunk_count()]))
	streamer.stream_around(around, 0, "res://world/chunks")
	for tick: int in range(3):
		streamer._process(0.016)
	around.position = Vector3(0.0, 0.0, 950.0)
	for tick: int in range(3):
		streamer._process(0.016)
	var after: int = streamer.loaded_chunk_count()
	streamer.free()
	around.free()
	return SUPPORT.pins(TEST, [
		["the leaving chunk is still loaded while the row runs", seen[0] if seen.size() == 1 else [],
			[true, 1]],
		["and it is gone once the row is over", after, 1],
	])


## A streamer whose followed node has been freed has no centre to build a wanted set around. It
## stops following rather than asking an unanswerable question every frame for the rest of the
## game, which is what lets its tick park itself.
static func _a_streamer_whose_node_is_gone_parks_its_tick(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node3D = Node3D.new()
	streamer.cell_size = Vector3(100.0, 100.0, 100.0)
	streamer.stream_around(around, 0, "res://world/chunks")
	for tick: int in range(3):
		streamer._process(0.016)
	var ticking_while_followed: bool = streamer.is_processing()
	around.free()
	for tick: int in range(3):
		streamer._process(0.016)
	var ticking_after: bool = streamer.is_processing()
	var quiet: bool = not streamer.is_loading_chunks()
	streamer.free()
	return SUPPORT.pins(TEST, [
		["a streamer following something ticks", ticking_while_followed, true],
		["a streamer whose node was freed parks its tick", ticking_after, false],
		["and it asks for nothing more", quiet, true],
	])
