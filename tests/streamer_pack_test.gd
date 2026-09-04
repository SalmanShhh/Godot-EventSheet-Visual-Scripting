# Godot EventSheets - the Streamer pack, driven directly.
#
# A streamer is four promises about TIMING, and not one of them is visible in a screenshot of a
# world: which cells it decides it wants, that it starts no more than one threaded request per
# frame, that a chunk is kept for an extra ring so a player standing on a cell border does not
# reload what they just left, and that On Chunk Unloading reaches the sheet while the chunk is
# still a node. So this file loads the COMPILED pack, extends it with a stub loader - the four
# seams the pack keeps small on purpose - and drives `_process` by hand, with no scene tree, no
# physics and no disk.
#
# The traps it exists to catch, each one a rule the guide states and a reader would otherwise
# have to trust:
#   - every published verb addresses the behavior by name, so a row emits plain code;
#   - a point one pixel left of the origin is cell -1, not cell 0 (the seam through the middle
#     of every world built around (0, 0));
#   - the wanted set is the square of rings around the followed node, nearest ring FIRST;
#   - exactly one threaded request is started per frame, however many cells are wanted;
#   - the keep radius is hysteresis: a chunk leaves the wanted set one ring before it is freed;
#   - a pinned chunk is never released by distance, and Release Chunk unpins and frees it;
#   - On Chunk Unloading fires BEFORE the free, with the node still valid in the handler;
#   - On Streaming Idle fires once when the world settles, not every frame afterwards;
#   - a cell whose scene is not on disk is skipped in silence rather than requested for ever.
@tool
class_name StreamerPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/streamer/streamer_behavior.gd"
const TEST := "streamer_pack_test"
const STUB_PATH := "user://streamer_pack_test_stub.gd"

## The stub loader: the seams the pack keeps together so a project with its own loader - and a
## test with no disk at all - can answer them differently. Written to a real file and loaded,
## because a GDScript built from a string in memory has no path for `extends` to resolve. The
## drop seam frees rather than queues, because a test has no main loop for a deferred free to
## happen in - which is exactly the reason that line is a seam and not a call site.
const STUB_SOURCE := """@tool
extends \"res://eventsheet_addons/streamer/streamer_behavior.gd\"

var requested_paths: Array[String] = []
var absent_paths: Array[String] = []

func _chunk_scene_exists(path: String) -> bool:
	return not absent_paths.has(path)

func _request_load(path: String) -> int:
	requested_paths.append(path)
	return OK

func _load_state(_path: String) -> int:
	return ResourceLoader.THREAD_LOAD_LOADED

func _take_chunk(_path: String) -> Node:
	return Node2D.new()

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
	passed = _a_point_left_of_the_origin_is_the_cell_before_it(stub) and passed
	passed = _the_wanted_set_is_the_rings_around_the_node(stub) and passed
	passed = _one_request_per_tick(stub) and passed
	passed = _the_keep_radius_is_hysteresis_on_the_border(stub) and passed
	passed = _a_pinned_chunk_survives_distance(stub) and passed
	passed = _unloading_reaches_the_sheet_before_the_free(stub) and passed
	passed = _idle_fires_once_when_the_world_settles(stub) and passed
	passed = _a_missing_chunk_scene_is_skipped_in_silence(stub) and passed
	return passed


## The stub, written out and loaded. `extends "res://..."` needs a real file on both sides, so
## the source is written to user:// rather than built from a string in memory.
static func _stub_script() -> GDScript:
	var file: FileAccess = FileAccess.open(STUB_PATH, FileAccess.WRITE)
	if file == null:
		return null
	file.store_string(STUB_SOURCE)
	file.close()
	return load(STUB_PATH) as GDScript


# ── What the pack publishes ───────────────────────────────────────────────────────────────────


## A pack row must emit plain code that names the behavior, because that is what a reader opening
## the generated script sees. Pinned against the SHIPPED bytes rather than against the builder's
## intent, and counted, so a verb quietly losing its template is a red line rather than a gap.
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
		if not line.begins_with("## @ace_codegen_template(\"$StreamerBehavior."):
			not_the_behavior += 1
	return SUPPORT.pins(TEST, [
		["every published verb addresses the behavior by name", not_the_behavior, 0],
		["and all nine of them are published", templates, 9],
		["the three triggers are declared as signals", triggers, 3],
		["the host is a Node2D, because a radius is measured in world space",
			source.contains("var host: Node2D = null"), true],
	])


# ── The grid ──────────────────────────────────────────────────────────────────────────────────


## Flooring, not truncation. `int(-0.5)` is 0 in GDScript, which would put cells (0, 0) and
## (-1, -1) both at the origin and leave a double-width seam through the middle of any world
## built around it.
static func _a_point_left_of_the_origin_is_the_cell_before_it(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	streamer.cell_size = Vector2(100.0, 100.0)
	var pins: Array = [
		["a point inside the first cell is cell (0, 0)", streamer.chunk_of(Vector2(1.0, 1.0)), Vector2i(0, 0)],
		["one pixel left of the origin is cell (-1, -1)", streamer.chunk_of(Vector2(-1.0, -1.0)), Vector2i(-1, -1)],
		["the cell border belongs to the cell it opens", streamer.chunk_of(Vector2(100.0, 0.0)), Vector2i(1, 0)],
		["and a long way out counts in whole cells", streamer.chunk_of(Vector2(350.0, -250.0)), Vector2i(3, -3)],
	]
	streamer.free()
	return SUPPORT.pins(TEST, pins)


## The wanted set is the SQUARE of cells within the radius, asked for nearest ring first, so the
## ground under the player arrives before the horizon does. Pinned as the whole request order,
## because "nearest first" is the difference between a world that pops in around you and one that
## fills in from a corner.
static func _the_wanted_set_is_the_rings_around_the_node(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node2D = Node2D.new()
	around.position = Vector2(50.0, 50.0)
	streamer.cell_size = Vector2(100.0, 100.0)
	streamer.stream_around(around, 1, "res://world/chunks")
	for tick: int in range(12):
		streamer._process(0.016)
	var requested: Array = streamer.requested_paths.duplicate()
	var loaded: int = streamer.loaded_chunk_count()
	streamer.free()
	around.free()
	return SUPPORT.pins(TEST, [
		["the centre cell is asked for first, then its ring, in a fixed order", requested, [
			"res://world/chunks/chunk_0_0.tscn",
			"res://world/chunks/chunk_-1_-1.tscn",
			"res://world/chunks/chunk_-1_0.tscn",
			"res://world/chunks/chunk_-1_1.tscn",
			"res://world/chunks/chunk_0_-1.tscn",
			"res://world/chunks/chunk_0_1.tscn",
			"res://world/chunks/chunk_1_-1.tscn",
			"res://world/chunks/chunk_1_0.tscn",
			"res://world/chunks/chunk_1_1.tscn",
		]],
		["a radius of one cell is nine chunks in the world", loaded, 9],
		["and twelve frames asked for no more than the nine", requested.size(), 9],
	])


## ONE threaded request per frame, however many cells the radius wants. This is the whole reason
## a streamed world does not stutter, and it is invisible in any screenshot.
static func _one_request_per_tick(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node2D = Node2D.new()
	streamer.cell_size = Vector2(100.0, 100.0)
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
## past radius + keep, so a player stepping back and forth across a cell border reloads nothing -
## the thrash bug in every hand-written loader.
static func _the_keep_radius_is_hysteresis_on_the_border(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node2D = Node2D.new()
	streamer.cell_size = Vector2(100.0, 100.0)
	streamer.keep_radius_cells = 1
	around.position = Vector2(50.0, 50.0)
	streamer.stream_around(around, 1, "res://world/chunks")
	for tick: int in range(12):
		streamer._process(0.016)
	var settled: int = streamer.loaded_chunk_count()
	# One step over the border into cell (1, 0): the column at x = -1 is now two rings out,
	# which the keep radius covers, so nothing is freed and nothing is loaded twice.
	around.position = Vector2(150.0, 50.0)
	for tick: int in range(6):
		streamer._process(0.016)
	var after_one_step: int = streamer.loaded_chunk_count()
	var requests_after_one_step: int = streamer.requested_paths.size()
	# Two more cells out, and the far column is past the keep radius at last.
	around.position = Vector2(350.0, 50.0)
	for tick: int in range(12):
		streamer._process(0.016)
	var far_column_gone: bool = not streamer.chunk_is_loaded_at(Vector2(-50.0, 50.0))
	streamer.free()
	around.free()
	return SUPPORT.pins(TEST, [
		["a radius of one settles at nine chunks", settled, 9],
		["stepping over the border keeps the column behind, and adds the one ahead",
			after_one_step, 12],
		["and nothing already loaded was asked for a second time", requests_after_one_step, 12],
		["three cells out, the first column is finally released", far_column_gone, true],
	])


## A pinned chunk is the hub, the shop, the room the quest is in: distance never takes it, and
## only Release Chunk does.
static func _a_pinned_chunk_survives_distance(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node2D = Node2D.new()
	streamer.cell_size = Vector2(100.0, 100.0)
	streamer.keep_radius_cells = 0
	streamer.stream_around(around, 0, "res://world/chunks")
	streamer.keep_chunk(Vector2i(0, 0))
	for tick: int in range(4):
		streamer._process(0.016)
	var pinned_loaded: bool = streamer.chunk_is_loaded_at(Vector2(50.0, 50.0))
	around.position = Vector2(950.0, 950.0)
	for tick: int in range(6):
		streamer._process(0.016)
	var pinned_survived: bool = streamer.chunk_is_loaded_at(Vector2(50.0, 50.0))
	streamer.release_chunk(Vector2i(0, 0))
	var released: bool = not streamer.chunk_is_loaded_at(Vector2(50.0, 50.0))
	streamer.free()
	around.free()
	return SUPPORT.pins(TEST, [
		["Keep Chunk loads the cell it pins", pinned_loaded, true],
		["ten cells away, the pinned chunk is still there", pinned_survived, true],
		["and Release Chunk is the only thing that takes it", released, true],
	])


# ── The two triggers that have to reach the sheet ─────────────────────────────────────────────


## On Chunk Unloading fires BEFORE the free, with the node still valid, which is the only thing
## that makes "save what the player changed in this chunk" a row rather than a race.
static func _unloading_reaches_the_sheet_before_the_free(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node2D = Node2D.new()
	streamer.cell_size = Vector2(100.0, 100.0)
	streamer.keep_radius_cells = 0
	var seen: Array = []
	streamer.chunk_unloading.connect(func(chunk: Node, cell: Vector2i) -> void:
		seen.append([is_instance_valid(chunk), chunk.get_parent() != null, cell]))
	streamer.stream_around(around, 0, "res://world/chunks")
	for tick: int in range(3):
		streamer._process(0.016)
	var loaded_first: int = streamer.loaded_chunk_count()
	around.position = Vector2(950.0, 50.0)
	for tick: int in range(3):
		streamer._process(0.016)
	streamer.free()
	around.free()
	return SUPPORT.pins(TEST, [
		["the cell under the node loaded", loaded_first, 1],
		["and leaving it told the sheet exactly once", seen.size(), 1],
		["with the chunk still a node in the world when the row runs", seen[0] if seen.size() == 1 else [],
			[true, true, Vector2i(0, 0)]],
	])


## On Streaming Idle is the row a loading screen waits on, so it must fire when the world settles
## and then stay quiet - not once per frame for the rest of the game.
static func _idle_fires_once_when_the_world_settles(stub: GDScript) -> bool:
	var streamer: Node = stub.new()
	var around: Node2D = Node2D.new()
	streamer.cell_size = Vector2(100.0, 100.0)
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
	var around: Node2D = Node2D.new()
	streamer.cell_size = Vector2(100.0, 100.0)
	streamer.absent_paths = ["res://world/chunks/chunk_0_0.tscn"] as Array[String]
	streamer.stream_around(around, 1, "res://world/chunks")
	for tick: int in range(12):
		streamer._process(0.016)
	var requested: Array = streamer.requested_paths.duplicate()
	var loaded: int = streamer.loaded_chunk_count()
	var quiet: bool = not streamer.is_loading_chunks()
	streamer.free()
	around.free()
	return SUPPORT.pins(TEST, [
		["the missing cell is never requested", requested.has("res://world/chunks/chunk_0_0.tscn"), false],
		["the other eight of the ring still arrive", loaded, 8],
		["and the streamer settles instead of retrying the hole for ever", quiet, true],
	])
