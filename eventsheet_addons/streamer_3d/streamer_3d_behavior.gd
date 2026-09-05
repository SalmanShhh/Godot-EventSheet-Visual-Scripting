## @ace_tags(world, loading, performance, 3d)
## @ace_category("Streamer 3D")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/streamer_3d/icon.svg")
class_name Streamer3DBehavior
extends Node
## Streams a 3D world that is bigger than memory: a folder of chunk scenes named by cell, loaded on a thread within a radius of a node and freed behind it. The grid is flat by default - height only becomes a cell axis when Stream Height is on - and one threaded request per frame with a millisecond budget keeps the frame rate flat while a vehicle crosses it.

## The node this behavior acts on (its parent). Required host: Node3D.
var host: Node3D = null

func _enter_tree() -> void:
	host = get_parent() as Node3D
	if host == null:
		push_warning("Streamer3DBehavior behavior requires a Node3D parent.")

## @ace_trigger
## @ace_name("On Chunk Loaded")
signal chunk_loaded(chunk: Node, cell: Vector3i)
## @ace_trigger
## @ace_name("On Chunk Unloading")
signal chunk_unloading(chunk: Node, cell: Vector3i)
## @ace_trigger
## @ace_name("On Streaming Idle")
signal streaming_idle

# --- Designer knobs (tune in the Inspector) ---
## How big one chunk is, in metres. A point's cell is the point divided by this and floored,
## so the scene for cell (3, 0, -2) is the file named chunk_3_0_-2.tscn.
@export var cell_size: Vector3 = Vector3(64.0, 64.0, 64.0)
## How long one frame may spend taking finished chunks in, in milliseconds. When the budget
## is spent the rest wait for the next frame, so a fast vehicle never hitches on the frame
## three chunks happen to finish together.
@export var budget_ms: float = 4.0
## How many rings BEYOND the streaming radius a loaded chunk is kept before it is released.
## 1 means a player walking back and forth across a cell border never reloads the chunk they
## just left - the hysteresis a hand-written loader is usually missing.
@export var keep_radius_cells: int = 1
## Whether HEIGHT takes part in the grid. Off is the usual open world: the grid is flat, cells
## differ only in X and Z, and every chunk's Y is 0 however high the player climbs. On stacks
## cells vertically as well, for a space station, a cave system or a tower - which multiplies
## how many chunks a radius asks for, so raise it deliberately.
@export var stream_height: bool = false
## What the chunk scenes are called: this word, then the cell numbers, joined with "_".
## chunk_3_0_-2.tscn at the default.
@export var chunk_prefix: String = "chunk"

# --- Internal state ---
## The node the radius is measured around. Stream Chunks Around sets it; Stop Streaming
## clears it.
var _around: Node3D = null
## The radius in cells the wanted set is built from.
var _radius_cells: int = 0
## The folder the chunk scenes are read from, with exactly one trailing slash.
var _folder: String = ""
## Whether Stream Chunks Around is currently following anything. Requests already in flight
## are still finished when this is false, which is what makes Stop Streaming instant.
var _streaming: bool = false
## Cell -> the chunk node in the world. The loaded set, and what Loaded Chunk Count counts.
var _loaded: Dictionary = {}
## Cell -> the scene path the threaded loader was given. The requests in flight.
var _requested: Dictionary = {}
## Cell -> true for a chunk Keep Chunk pinned. A pinned chunk is never released by distance.
var _pinned: Dictionary = {}
## Cell -> true for a cell the folder has no scene for. A hole in the grid is a level-design
## fact rather than an error, so it is remembered once and never asked for again - otherwise
## the streamer would want it every frame and never call the world settled.
var _absent: Dictionary = {}
## Cell -> true for a cell whose scene is there and could not be made into a chunk: the
## threaded load failed, the loader refused the request, or the file turned out not to be a
## scene at all. It is remembered for the same reason a hole is - a cell nothing recorded is
## wanted again the very next frame, which is one engine error per frame for ever and a world
## that never settles. Stream Chunks Around clears it, so fixing the file and starting again
## is the way back.
var _refused: Dictionary = {}
## Cells the radius wants, nearest ring first, rebuilt every frame from where the followed
## node is now.
var _wanted: Array[Vector3i] = []
## Cells a ROW asked for by name - Keep Chunk, Preload Chunks Around. They are drained before
## the radius's own list and are never cleared by it, so a teleport's preload cannot be
## thrown away by the player taking one step.
var _asked: Array[Vector3i] = []
## Whether On Streaming Idle has already been told about this quiet moment, so it fires once
## when the world settles rather than every frame afterwards.
var _idle_announced: bool = true


## The cell a world point falls in. Floored rather than truncated, so a point one metre left
## of the origin is cell -1 and not cell 0 - the off-by-one that puts a seam through the
## middle of every world built around the origin. With Stream Height off the Y of every cell
## is 0, which is what makes a flat grid flat.
## @ace_hidden
func _cell_of_point(point: Vector3) -> Vector3i:
	var width: float = cell_size.x if absf(cell_size.x) > 0.001 else 1.0
	var height: float = cell_size.y if absf(cell_size.y) > 0.001 else 1.0
	var depth: float = cell_size.z if absf(cell_size.z) > 0.001 else 1.0
	var level: int = int(floor(point.y / height)) if stream_height else 0
	return Vector3i(int(floor(point.x / width)), level, int(floor(point.z / depth)))
## Every cell exactly this many rings out from a center, in a fixed order so two machines
## streaming the same walk ask for the same chunks in the same sequence. The Y range collapses
## to the center's own level when Stream Height is off.
## @ace_hidden
func _ring_cells(center: Vector3i, ring: int) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	var levels: int = ring if stream_height else 0
	for dx: int in range(-ring, ring + 1):
		for dy: int in range(-levels, levels + 1):
			for dz: int in range(-ring, ring + 1):
				var reach: int = maxi(absi(dx), absi(dz))
				if stream_height:
					reach = maxi(reach, absi(dy))
				if reach == ring:
					cells.append(center + Vector3i(dx, dy, dz))
	return cells

## The finished load as a chunk node. Null means the file loaded but was not a scene, which
## is a broken chunk rather than a missing one.
## @ace_hidden
func _take_chunk(path: String) -> Node:
	var scene: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
	return null if scene == null else scene.instantiate()

func _ready() -> void:
	# A streamer that has not been told what to follow costs nothing per frame. Stream Chunks
	# Around starts the tick; it stops itself again when there is nothing left in flight.
	set_process(false)

func _process(delta: float) -> void:
	if _streaming and (_around == null or not is_instance_valid(_around)):
		# What was being followed is gone - the player died, the level was thrown away. There is
		# no centre to build a wanted set around any more, so the streamer stops following rather
		# than asking an unanswerable question every frame for the rest of the game.
		_around = null
		_streaming = false
	if _streaming and _around != null and is_instance_valid(_around):
		var center: Vector3i = _cell_of_point(_point_of(_around))
		_refill_wanted(center)
		_release_far_chunks(center)
	_start_one_request()
	_collect_finished()
	_announce_idle_when_settled()
	if not _streaming and _asked.is_empty() and _wanted.is_empty() and _requested.is_empty():
		# Nothing to follow and nothing in flight: park the tick rather than spend a frame
		# every frame asking an empty question.
		set_process(false)

## @ace_action
## @ace_featured
## @ace_name("Stream Chunks Around")
## @ace_category("Streamer 3D")
## @ace_description("Follows a node and keeps the chunk scenes within this many cells of it loaded, freeing the ones behind. The folder holds one scene per cell, named chunk_X_Y_Z.tscn.")
## @ace_display_template("Stream chunks around [i]{around}[/i], [b]{radius_cells}[/b] cells, from [b]{folder}[/b]")
## @ace_icon("res://eventsheet_addons/streamer_3d/icon.svg")
## @ace_codegen_template("$Streamer3DBehavior.stream_around({around}, {radius_cells}, {folder})")
func stream_around(around: Node3D, radius_cells: int, folder: String) -> void:
	_around = around
	_radius_cells = maxi(radius_cells, 0)
	_folder = _tidy_folder(folder)
	_absent.clear()
	_refused.clear()
	_streaming = around != null and not _folder.is_empty()
	_idle_announced = false
	if _streaming:
		set_process(true)

## @ace_action
## @ace_name("Stop Streaming")
## @ace_category("Streamer 3D")
## @ace_description("Stops following. Loaded chunks stay exactly where they are - use Release Chunk, or a new Stream Chunks Around, to move them.")
## @ace_icon("res://eventsheet_addons/streamer_3d/icon.svg")
## @ace_codegen_template("$Streamer3DBehavior.stop_streaming()")
func stop_streaming() -> void:
	_streaming = false
	_around = null
	_wanted.clear()
	_asked.clear()

## @ace_action
## @ace_name("Keep Chunk")
## @ace_category("Streamer 3D")
## @ace_description("Pins one cell's chunk: it is loaded if it is not already, and distance never releases it. The hub, the hangar, the room the quest is in.")
## @ace_display_template("Keep chunk [b]{cell}[/b] loaded")
## @ace_icon("res://eventsheet_addons/streamer_3d/icon.svg")
## @ace_codegen_template("$Streamer3DBehavior.keep_chunk({cell})")
func keep_chunk(cell: Vector3i) -> void:
	_pinned[cell] = true
	_queue_cell(_asked, cell)
	if not _asked.is_empty():
		set_process(true)

## @ace_action
## @ace_name("Release Chunk")
## @ace_category("Streamer 3D")
## @ace_description("Unpins one cell's chunk and takes it out of the world now, firing On Chunk Unloading first.")
## @ace_display_template("Release chunk [b]{cell}[/b]")
## @ace_icon("res://eventsheet_addons/streamer_3d/icon.svg")
## @ace_codegen_template("$Streamer3DBehavior.release_chunk({cell})")
func release_chunk(cell: Vector3i) -> void:
	_pinned.erase(cell)
	_asked.erase(cell)
	_unload_cell(cell)

## @ace_action
## @ace_name("Preload Chunks Around")
## @ace_category("Streamer 3D")
## @ace_description("Asks for the chunks within this many cells of a point before anything goes there - the row a teleport, a fast travel or a cutscene runs while the screen is still covered.")
## @ace_display_template("Preload chunks around [b]{point}[/b], [b]{radius_cells}[/b] cells")
## @ace_icon("res://eventsheet_addons/streamer_3d/icon.svg")
## @ace_codegen_template("$Streamer3DBehavior.preload_chunks_around({point}, {radius_cells})")
func preload_chunks_around(point: Vector3, radius_cells: int) -> void:
	var center: Vector3i = _cell_of_point(point)
	var reach: int = maxi(radius_cells, 0)
	for ring: int in range(reach + 1):
		for cell: Vector3i in _ring_cells(center, ring):
			_queue_cell(_asked, cell)
	if not _asked.is_empty():
		_idle_announced = false
		set_process(true)

## @ace_condition
## @ace_featured
## @ace_name("Chunk Is Loaded At")
## @ace_category("Streamer 3D")
## @ace_description("Whether the chunk covering this world point is in the world right now. The guard for waking a boss, spawning a patrol or aiming a camera at ground that may not be there yet.")
## @ace_icon("res://eventsheet_addons/streamer_3d/icon.svg")
## @ace_codegen_template("$Streamer3DBehavior.chunk_is_loaded_at({point})")
func chunk_is_loaded_at(point: Vector3) -> bool:
	return _loaded.has(_cell_of_point(point))

## @ace_condition
## @ace_name("Is Loading Chunks")
## @ace_category("Streamer 3D")
## @ace_description("Whether anything is still on its way in: a request in flight, or a cell waiting for one. False is the moment the world around the player is complete.")
## @ace_icon("res://eventsheet_addons/streamer_3d/icon.svg")
## @ace_codegen_template("$Streamer3DBehavior.is_loading_chunks()")
func is_loading_chunks() -> bool:
	return not _requested.is_empty() or not _wanted.is_empty() or not _asked.is_empty()

## @ace_expression
## @ace_name("Loaded Chunk Count")
## @ace_category("Streamer 3D")
## @ace_description("How many chunk scenes are in the world right now - the number a debug overlay shows and a memory budget is measured against.")
## @ace_icon("res://eventsheet_addons/streamer_3d/icon.svg")
## @ace_codegen_template("$Streamer3DBehavior.loaded_chunk_count()")
func loaded_chunk_count() -> int:
	return _loaded.size()

## @ace_expression
## @ace_name("Chunk Of")
## @ace_category("Streamer 3D")
## @ace_description("The cell a world point falls in, as a Vector3i. Feed it to Keep Chunk or Release Chunk, or compare two of them to notice a border being crossed.")
## @ace_icon("res://eventsheet_addons/streamer_3d/icon.svg")
## @ace_codegen_template("$Streamer3DBehavior.chunk_of({point})")
func chunk_of(point: Vector3) -> Vector3i:
	return _cell_of_point(point)

## Where the scene for one cell lives.
## @ace_hidden
func _path_of_cell(cell: Vector3i) -> String:
	return "%s%s_%d_%d_%d.tscn" % [_folder, chunk_prefix, cell.x, cell.y, cell.z]

## The folder as something a file name can be joined to: exactly one trailing slash, and an
## empty folder stays empty so a path is never built out of nothing.
## @ace_hidden
func _tidy_folder(folder: String) -> String:
	var tidied: String = folder.strip_edges()
	if tidied.is_empty():
		return ""
	return tidied if tidied.ends_with("/") else tidied + "/"

## How far one cell is from another ON THE GRID: the largest axis distance, which is what a
## radius counted in cells means - a box of rings, not a sphere. Height only counts when the
## grid has a height at all.
## @ace_hidden
func _ring_of(cell: Vector3i, center: Vector3i) -> int:
	var flat: int = maxi(absi(cell.x - center.x), absi(cell.z - center.z))
	return maxi(flat, absi(cell.y - center.y)) if stream_height else flat

## Where the followed node is, in world space. A node that is not inside the tree has no
## global transform to ask for, so its own position is the honest answer - and asking through
## one helper is what lets this pack be driven a frame at a time with no tree at all.
## @ace_hidden
func _point_of(node: Node3D) -> Vector3:
	return node.global_position if node.is_inside_tree() else node.position

## Adds a cell to a list unless it is already loaded, already requested or already on it.
## @ace_hidden
func _queue_cell(into: Array[Vector3i], cell: Vector3i) -> void:
	if _loaded.has(cell) or _requested.has(cell) or _absent.has(cell) or _refused.has(cell) \
			or into.has(cell):
		return
	into.append(cell)

## The handful of lines that touch Godot's threaded loader and the scene tree, kept together
## and kept small on purpose. They are the only part of this pack that needs the resource
## system, so a project with a loader of its own - and a test with no disk at all - can extend
## this script and answer them differently without touching anything above.
## @ace_hidden
func _chunk_scene_exists(path: String) -> bool:
	return ResourceLoader.exists(path)

## @ace_hidden
func _request_load(path: String) -> int:
	return ResourceLoader.load_threaded_request(path)

## @ace_hidden
func _load_state(path: String) -> int:
	return ResourceLoader.load_threaded_get_status(path)

## How a chunk leaves the world. Deferred, so a chunk never disappears out of a signal a
## sheet is still inside. It is a seam of its own because a project that pools its scenery
## returns the node to the pool here instead of freeing it.
## @ace_hidden
func _drop_chunk(chunk: Node) -> void:
	chunk.queue_free()

## Rebuilds the radius's own wanted list from the cell the followed node is standing in,
## nearest ring first, so the ground under the player arrives before the horizon does.
## @ace_hidden
func _refill_wanted(center: Vector3i) -> void:
	_wanted.clear()
	for ring: int in range(_radius_cells + 1):
		for cell: Vector3i in _ring_cells(center, ring):
			_queue_cell(_wanted, cell)

## Releases every loaded chunk further out than the radius plus the keep radius, except the
## ones Keep Chunk pinned. The keep radius is the hysteresis: a chunk goes out of the wanted
## set one ring before it is thrown away, so a border step never reloads what it just freed.
## @ace_hidden
func _release_far_chunks(center: Vector3i) -> void:
	var keep: int = _radius_cells + maxi(keep_radius_cells, 0)
	for cell: Vector3i in _loaded.keys():
		if _pinned.has(cell):
			continue
		if _ring_of(cell, center) > keep:
			_unload_cell(cell)

## Takes one chunk out of the world. On Chunk Unloading fires BEFORE the free, so a row still
## has the node in front of it and can save what the player changed in it; the drop that follows
## is deferred, which is what keeps a chunk from disappearing out of a signal a sheet is inside.
## The cell leaves the loaded set AFTER the signal, for the same reason: inside that trigger the
## chunk is still in the world, so Chunk Is Loaded At and Loaded Chunk Count answer about the
## world the row is looking at rather than the one it is about to become.
## @ace_hidden
func _unload_cell(cell: Vector3i) -> void:
	var chunk: Node = _loaded.get(cell, null) as Node
	if chunk == null or not is_instance_valid(chunk):
		_loaded.erase(cell)
		return
	chunk_unloading.emit(chunk, cell)
	_loaded.erase(cell)
	_drop_chunk(chunk)

## Starts AT MOST ONE threaded request this frame - the whole reason a streamed world does
## not stutter. A cell whose scene is not there is skipped in silence: a hole in the grid is
## a level-design fact, and the Doctor is where it is reported.
## @ace_hidden
func _start_one_request() -> void:
	while not _asked.is_empty() or not _wanted.is_empty():
		var cell: Vector3i = _asked.pop_front() if not _asked.is_empty() else _wanted.pop_front()
		if _loaded.has(cell) or _requested.has(cell):
			continue
		var path: String = _path_of_cell(cell)
		if path.is_empty():
			continue
		if not _chunk_scene_exists(path):
			_absent[cell] = true
			continue
		if _request_load(path) != OK:
			_refused[cell] = true
			continue
		_requested[cell] = path
		return

## Takes in the requests that have finished, until the millisecond budget for this frame is
## spent. A request that did not end in a chunk - it failed, or the file was not a scene - is
## written down as refused rather than dropped, because a cell nothing remembers is wanted
## again next frame and asked for again for ever.
## @ace_hidden
func _collect_finished() -> void:
	var deadline: int = Time.get_ticks_usec() + int(maxf(budget_ms, 0.0) * 1000.0)
	for cell: Vector3i in _requested.keys():
		var path: String = str(_requested[cell])
		var state: int = _load_state(path)
		if state == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_requested.erase(cell)
		var chunk: Node = _take_chunk(path) if state == ResourceLoader.THREAD_LOAD_LOADED else null
		if chunk == null:
			_refused[cell] = true
		else:
			_place_chunk(cell, chunk)
		if Time.get_ticks_usec() >= deadline:
			return

## Puts one finished chunk in the world at its cell's own corner, so a chunk scene is
## authored around its own origin and the grid does the placing. Then the sheet hears about
## it, with the node in hand.
## @ace_hidden
func _place_chunk(cell: Vector3i, chunk: Node) -> void:
	if chunk == null:
		return
	var parent: Node = host if host != null else self
	parent.add_child(chunk)
	if chunk is Node3D:
		(chunk as Node3D).position = Vector3(cell) * cell_size
	_loaded[cell] = chunk
	_idle_announced = false
	chunk_loaded.emit(chunk, cell)

## Fires On Streaming Idle the moment nothing is left to load, and not again until something
## is. The row a loading screen, an autosave or a boss introduction waits on.
## @ace_hidden
func _announce_idle_when_settled() -> void:
	if not _wanted.is_empty() or not _asked.is_empty() or not _requested.is_empty():
		_idle_announced = false
		return
	if _idle_announced:
		return
	_idle_announced = true
	streaming_idle.emit()

# Streamer 3D: attach to the node your chunks should live under, then Stream Chunks Around a player. Cell size, the millisecond budget, the keep radius and Stream Height are Inspector properties; the chunk scenes are a folder of files named chunk_X_Y_Z.tscn. This pack is an event sheet - extend it by editing it.
