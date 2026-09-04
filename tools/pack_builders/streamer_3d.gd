# Pack builder - streamer_3d (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Streamer 3D: the same words as the 2D pack, on a Vector3i grid with a height option. Cells
## are boxes of `cell_size` metres and the scene for cell (3, 0, -2) is the file
## `chunk_3_0_-2.tscn`. Stream Height off is the usual open world - a flat grid, every cell's Y
## is 0 however high the player climbs; on, cells stack vertically for a station or a cave.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("streamer_3d", "Node3D", "Streamer3DBehavior",
		"Streams a 3D world that is bigger than memory: a folder of chunk scenes named by cell, loaded on a thread within a radius of a node and freed behind it. The grid is flat by default - height only becomes a cell axis when Stream Height is on - and one threaded request per frame with a millisecond budget keeps the frame rate flat while a vehicle crosses it.",
		Lib.manifest().behavior().category("Streamer 3D").tags(["world", "loading", "performance", "3d"]))
	src.note("Streamer 3D: attach to the node your chunks should live under, then Stream Chunks Around a player. Cell size, the millisecond budget, the keep radius and Stream Height are Inspector properties; the chunk scenes are a folder of files named chunk_X_Y_Z.tscn. This pack is an event sheet - extend it by editing it.")
	src.block("block_1")
	src.block("block_2")
	src.block("block_3")
	src.on_ready()
	src.on_process()
	src.verb("stream_around", "Stream Chunks Around",
		"Follows a node and keeps the chunk scenes within this many cells of it loaded, freeing the ones behind. The folder holds one scene per cell, named chunk_X_Y_Z.tscn.",
		[["around", "Node3D"], ["radius_cells", "int"], ["folder", "String"]])
	src.verb("stop_streaming", "Stop Streaming",
		"Stops following. Loaded chunks stay exactly where they are - use Release Chunk, or a new Stream Chunks Around, to move them.",
		[])
	src.verb("keep_chunk", "Keep Chunk",
		"Pins one cell's chunk: it is loaded if it is not already, and distance never releases it. The hub, the hangar, the room the quest is in.",
		[["cell", "Vector3i"]])
	src.verb("release_chunk", "Release Chunk",
		"Unpins one cell's chunk and takes it out of the world now, firing On Chunk Unloading first.",
		[["cell", "Vector3i"]])
	src.verb("preload_chunks_around", "Preload Chunks Around",
		"Asks for the chunks within this many cells of a point before anything goes there - the row a teleport, a fast travel or a cutscene runs while the screen is still covered.",
		[["point", "Vector3"], ["radius_cells", "int"]])
	src.condition("chunk_is_loaded_at", "Chunk Is Loaded At",
		"Whether the chunk covering this world point is in the world right now. The guard for waking a boss, spawning a patrol or aiming a camera at ground that may not be there yet.",
		[["point", "Vector3"]])
	src.condition("is_loading_chunks", "Is Loading Chunks",
		"Whether anything is still on its way in: a request in flight, or a cell waiting for one. False is the moment the world around the player is complete.",
		[])
	src.expression("loaded_chunk_count", "Loaded Chunk Count",
		"How many chunk scenes are in the world right now - the number a debug overlay shows and a memory budget is measured against.",
		[], TYPE_INT)
	src.expression("chunk_of", "Chunk Of",
		"The cell a world point falls in, as a Vector3i. Feed it to Keep Chunk or Release Chunk, or compare two of them to notice a border being crossed.",
		[["point", "Vector3"]], TYPE_VECTOR3I)
	Lib.verb_sentences(src.sheet, {
		"stream_around": "Stream chunks around [i]{around}[/i], [b]{radius_cells}[/b] cells, from [b]{folder}[/b]",
		"preload_chunks_around": "Preload chunks around [b]{point}[/b], [b]{radius_cells}[/b] cells",
		"keep_chunk": "Keep chunk [b]{cell}[/b] loaded",
		"release_chunk": "Release chunk [b]{cell}[/b]",
	})
	Lib.feature_verbs(src.sheet, ["stream_around", "chunk_is_loaded_at"])
	return Lib.publish(src, "res://eventsheet_addons/streamer_3d/streamer_3d_behavior")
