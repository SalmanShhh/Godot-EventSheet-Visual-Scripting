# Pack builder - streamer (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Streamer: a 2D world larger than memory, as a folder of scenes and one row. The grid is
## cells of `cell_size` pixels, the scene for cell (3, -2) is the file `chunk_3_-2.tscn`, and
## Stream Chunks Around loads the ones within a radius of a node on a thread and frees the ones
## behind. The layout is FILES, not a format: make the folder by hand, or with the Split Scene
## Into Chunks tool, and nothing is baked into a map only this pack can read.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("streamer", "Node2D", "StreamerBehavior",
		"Streams a 2D world that is bigger than memory: a folder of chunk scenes named by cell, loaded on a thread within a radius of a node and freed behind it. One threaded request per frame and a millisecond budget keep the frame rate flat, a keep radius stops a player on a cell border reloading what they just left, and On Chunk Unloading fires before the free so a sheet can save what the player changed.",
		Lib.manifest().behavior().category("Streamer").tags(["world", "loading", "performance"]))
	src.note("Streamer: attach to the node your chunks should live under, then Stream Chunks Around a player. Cell size, the millisecond budget and the keep radius are Inspector properties; the chunk scenes are a folder of files named chunk_X_Y.tscn. This pack is an event sheet - extend it by editing it.")
	src.block("block_1")
	src.block("block_2")
	src.block("block_3")
	src.on_ready()
	src.on_process()
	src.verb("stream_around", "Stream Chunks Around",
		"Follows a node and keeps the chunk scenes within this many cells of it loaded, freeing the ones behind. The folder holds one scene per cell, named chunk_X_Y.tscn.",
		[["around", "Node2D"], ["radius_cells", "int"], ["folder", "String"]])
	src.verb("stop_streaming", "Stop Streaming",
		"Stops following. Loaded chunks stay exactly where they are - use Release Chunk, or a new Stream Chunks Around, to move them.",
		[])
	src.verb("keep_chunk", "Keep Chunk",
		"Pins one cell's chunk: it is loaded if it is not already, and distance never releases it. The hub, the shop, the room the quest is in.",
		[["cell", "Vector2i"]])
	src.verb("release_chunk", "Release Chunk",
		"Unpins one cell's chunk and takes it out of the world now, firing On Chunk Unloading first.",
		[["cell", "Vector2i"]])
	src.verb("preload_chunks_around", "Preload Chunks Around",
		"Asks for the chunks within this many cells of a point before anything goes there - the row a teleport, a fast travel or a cutscene runs while the screen is still covered.",
		[["point", "Vector2"], ["radius_cells", "int"]])
	src.condition("chunk_is_loaded_at", "Chunk Is Loaded At",
		"Whether the chunk covering this world point is in the world right now. The guard for waking a boss, spawning a patrol or aiming a camera at ground that may not be there yet.",
		[["point", "Vector2"]])
	src.condition("is_loading_chunks", "Is Loading Chunks",
		"Whether anything is still on its way in: a request in flight, or a cell waiting for one. False is the moment the world around the player is complete.",
		[])
	src.expression("loaded_chunk_count", "Loaded Chunk Count",
		"How many chunk scenes are in the world right now - the number a debug overlay shows and a memory budget is measured against.",
		[], TYPE_INT)
	src.expression("chunk_of", "Chunk Of",
		"The cell a world point falls in, as a Vector2i. Feed it to Keep Chunk or Release Chunk, or compare two of them to notice a border being crossed.",
		[["point", "Vector2"]], TYPE_VECTOR2I)
	Lib.verb_sentences(src.sheet, {
		"stream_around": "Stream chunks around [i]{around}[/i], [b]{radius_cells}[/b] cells, from [b]{folder}[/b]",
		"preload_chunks_around": "Preload chunks around [b]{point}[/b], [b]{radius_cells}[/b] cells",
		"keep_chunk": "Keep chunk [b]{cell}[/b] loaded",
		"release_chunk": "Release chunk [b]{cell}[/b]",
	})
	Lib.feature_verbs(src.sheet, ["stream_around", "chunk_is_loaded_at"])
	return Lib.publish(src, "res://eventsheet_addons/streamer/streamer_behavior")
