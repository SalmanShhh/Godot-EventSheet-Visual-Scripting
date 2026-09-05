# Streamer - A 2D World Bigger Than Memory

Your world is a **folder of scenes named by cell**. `chunk_3_-2.tscn` is the piece three cells
right and two cells up. **Stream Chunks Around** a node keeps the pieces within a radius of it
loaded, on a thread, and frees the ones behind - one request per frame, a millisecond budget, and
a keep radius so walking back over a border reloads nothing.

## Where this pack shines

- **An open world that opens in a second.** The editor never holds the whole map, so the scene
  you are editing is one square of it.
- **A world as large as the disk.** Nothing is in memory except what is near the player.
- **Nothing proprietary.** The layout is files. Make them by hand, in a file browser, or with the
  Split Scene Into Chunks tool - and read them the same way.

## Setup

1. Attach `StreamerBehavior` as a child of the node your chunks should live under (your World
   node). Chunks are added as ITS children.
2. Set **Cell Size** to the size of one chunk in pixels. Every chunk scene is authored around its
   own origin, and the grid puts it in the world.
3. Make a folder of chunk scenes named `chunk_X_Y.tscn` - by hand, or by pressing **Ctrl+P** and
   running **Split Scene Into Chunks** on the big scene you have already built.
4. On the world's ready event, stream around your player.

```
On Ready -> Streamer | Stream Chunks Around  Player, 2, "res://world/chunks/"
```

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references
in *italic*, exactly as the rows draw them:

- Stream chunks around *Player*, **2** cells, from **res://world/chunks/**
- Keep chunk **(0, 0)** loaded

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Stream Chunks Around | `around` (Node2D), `radius_cells`, `folder` | Follows a node and keeps the chunk scenes within this many cells of it loaded, freeing the ones behind. |
| Action | Stop Streaming | (none) | Stops following. Loaded chunks stay exactly where they are. |
| Action | Keep Chunk | `cell` (Vector2i) | Pins one cell's chunk: it loads if it is not already, and distance never releases it. |
| Action | Release Chunk | `cell` (Vector2i) | Unpins one cell's chunk and takes it out now, firing On Chunk Unloading first. |
| Action | Preload Chunks Around | `point` (Vector2), `radius_cells` | Asks for the chunks around a point before anything goes there - a teleport, a fast travel, a cutscene. |
| Condition | Chunk Is Loaded At | `point` (Vector2) | Whether the chunk covering this world point is in the world right now. |
| Condition | Is Loading Chunks | (none) | Whether anything is still on its way in. False is the moment the world around the player is complete. |
| Expression | Loaded Chunk Count | (none) | How many chunk scenes are in the world right now. |
| Expression | Chunk Of | `point` (Vector2) | The cell a world point falls in, as a Vector2i. Feed it to Keep Chunk or Release Chunk. |
| Trigger | On Chunk Loaded | `chunk` (Node), `cell` (Vector2i) | Fired once per chunk, with the node, just after it joins the world. |
| Trigger | On Chunk Unloading | `chunk` (Node), `cell` (Vector2i) | Fired BEFORE the chunk is dropped, so a row can save what the player changed in it. |
| Trigger | On Streaming Idle | (none) | Fired once when nothing is left to load, and not again until something is. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `cell_size` | `(1024, 1024)` | How big one chunk is, in pixels. A point's cell is the point divided by this, floored. |
| `budget_ms` | `4` | How long one frame may spend taking finished chunks in. The rest wait for the next frame. |
| `keep_radius_cells` | `1` | How many rings beyond the radius a chunk is kept before it is released - the hysteresis. |
| `chunk_prefix` | `chunk` | The words before the cell numbers. Do not end it with a digit: the numbers at the END of a name are the address. |

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs as ready-to-insert chains once the behaviour is attached:

- `$StreamerBehavior.cell_size` inserts the **Cell Size** entry straight into any expression
- `$StreamerBehavior.keep_radius_cells` inserts the **Keep Radius Cells** entry

The `$StreamerBehavior` token stays selected after insert, so retargeting to your child's actual
name is one keystroke, or a node drag.

## The two editor tools

Press **Ctrl+P** for the command palette:

- **Split Scene Into Chunks** reads one scene, moves each direct child of its root into the cell
  that child's own position falls in, re-bases it to that cell's origin, and writes the folder.
- **Merge Chunks** is the way back: it reads the folder, puts every child where its cell says, and
  saves one scene you can edit as a whole again.

Neither tool changes what it reads, so splitting and merging are both reversible.

## Use cases

### 1. The whole feature

```
On Ready -> Streamer | Stream Chunks Around  Player, 2, "res://world/chunks/"
```

That is a streamed world. A radius of 2 is a five-by-five block of chunks around the player.

### 2. Save what the player changed

Pair the two triggers with the Save System pack, and a chest opened in one chunk is still open
when the player walks back into it an hour later.

```
On Chunk Unloading -> Save | Save Node State  chunk, "chunk_state"
On Chunk Loaded    -> Save | Load Node State  chunk, "chunk_state"
```

### 3. Wake the boss when its ground exists

```
On Every Tick
  Condition: Streamer - Chunk Is Loaded At  Boss.position -> Boss | wake up
```

Spawning something onto ground that has not streamed in yet is the classic streamed-world bug.
The condition is the guard.

### 4. A teleport that does not land in a void

```
On Fast Travel Chosen -> Streamer | Preload Chunks Around  destination, 1
                      -> Screen  | fade to black
On Streaming Idle     -> Player  | set position to destination
                      -> Screen  | fade from black
```

### 5. Pin the hub

The town is where the player always comes back to, and reloading it every time is a stutter they
feel. Pin it once and distance never takes it.

```
On Ready -> Streamer | Keep Chunk  (0, 0)
```

### 6. A loading screen that ends when the world is ready

```
On Ready          -> Streamer | Stream Chunks Around  Player, 2, "res://world/chunks/"
On Streaming Idle -> LoadingScreen | hide
```

### 7. Notice a border being crossed

Two Chunk Of readings, compared, is the whole of "the player entered a new region" - no trigger
volumes, no colliders.

```
On Every Tick
  Condition: Streamer - Chunk Of  Player.position  ≠  last_cell
    -> set last_cell to Streamer.Chunk Of  Player.position
    -> Music | play the track for this region
```

### 8. A memory budget you can see

```
On Every 1 seconds -> Debug Overlay | watch "chunks", Streamer.Loaded Chunk Count
```

If that number climbs and never falls, something is pinning chunks - look for a Keep Chunk with
no Release Chunk beside it.

### 9. A cutscene that must not hitch

Drop the millisecond budget while the camera is flying, and chunks arrive more slowly but never
in a lump.

```
On Cutscene Start -> Streamer | set budget_ms to 1
On Cutscene End   -> Streamer | set budget_ms to 8
```

### 10. A vehicle that outruns the loader

A car crossing two cells a second needs a bigger radius, not a bigger budget: the radius is how
far ahead the world exists.

```
On Enter Car -> Streamer | Stream Chunks Around  Car, 4, "res://world/chunks/"
On Exit Car  -> Streamer | Stream Chunks Around  Player, 2, "res://world/chunks/"
```

### 11. Two worlds, one folder each

An overworld and a dungeon are two folders. Streaming the second is the same row with a different
path - and Stop Streaming first, so the first world's chunks stop being wanted.

```
On Enter Dungeon -> Streamer | Stop Streaming
                 -> Streamer | Stream Chunks Around  Player, 1, "res://dungeon/chunks/"
```

### 12. Spawn a patrol as its chunk arrives

```
On Chunk Loaded -> Object Pool | take a "guard" and put it at chunk.position
```

The chunk node is the trigger's own parameter, so the row never has to find it.

### 13. A strip, not a square

An endless runner streams in one axis. Make the cells tall and thin, and the same pack is a
background recycler.

```
On Ready -> Streamer | set cell_size to (1024, 4096)
         -> Streamer | Stream Chunks Around  Runner, 2, "res://run/chunks/"
```

### 14. Release the room the quest is finished with

```
On Quest Complete -> Streamer | Release Chunk  (4, -1)
```

Only a pinned chunk needs releasing - everything else leaves on its own when the player does.

### 15. Hold the autosave until the world is quiet

```
On Autosave Due
  Condition: Streamer - Is Loading Chunks -> Save | Delay Autosave By  2
  Else                                    -> Save | Save Game
```

### 16. Turn the map you already built into a streamed one

You do not have to start over. Press **Ctrl+P**, run **Split Scene Into Chunks** on the scene you
have, point the Streamer at the folder it wrote, and delete the children from the original.

### Other use cases

**A city at night.** Each block is a chunk carrying its own lights and its own crowd, so a walk
across town is a hundred small scenes rather than one enormous one.

**A survival map with a fog of war.** Chunk Is Loaded At is also "has the player ever been near
here", which is exactly the question a discovered-region map asks.

**A racing circuit.** A track is a ring of chunks; a lap is the same eight scenes arriving in the
same order, and the pit lane is a pinned chunk.

**A co-op world with one host.** The host streams around the player who is furthest ahead, and the
keep radius covers the one trailing behind.

**A level editor's preview.** Merge Chunks, edit the whole world as one scene, split it again -
the round trip is what makes a folder of chunks editable rather than a build artifact.

## Tips and common mistakes

- **Keep the chunk folder in your export.** Godot's exporter drops resources nothing references,
  and chunk scenes are referenced by NAME at run time, not by a link - so an export that filters
  by dependency ships a game whose world is empty. Add `res://world/chunks/*` to the export
  preset's **Resources ▸ Filters to export non-resource files/folders**, or keep the export mode
  as "all resources in the project". This is the one mistake that works perfectly in the editor
  and fails on the machine you sent the game to.
- **Threads are not free everywhere.** `load_threaded_request` is what this pack uses, and on an
  export without thread support (a single-threaded Web build) Godot finishes such a request on the
  main thread. The budget still spreads the work over frames, but the load itself cannot be moved
  off the main thread on a platform that has only one. There is no way around that from here, and
  a pack claiming otherwise would be lying to you.
- **The final instantiate is on the main thread, always.** A chunk with three thousand nodes in it
  costs a frame whatever the budget says. If chunks hitch, make them smaller before you make the
  budget bigger.
- **Do not end the prefix with a digit.** The numbers at the END of a name are the address, so
  `level2_3_-2.tscn` is fine and `level_2_3_-2.tscn` reads as cell (2, 3) with a stray suffix.
- **A tilemap is one node, not a world of cells.** Split Scene Into Chunks moves nodes; it does not
  rewrite a TileMapLayer's tile data. Draw your world in tilemap pieces, one per chunk scene, or
  split by hand.
- **Author every chunk around its own origin.** The grid does the placing. A chunk whose contents
  sit at their world coordinates ends up one cell-size away from where you meant.
- **A hole in the grid is allowed.** The pack skips a cell whose scene is not there, in silence -
  a world may genuinely be island-shaped. The Doctor's Streaming section is what tells you about a
  hole in a grid that is otherwise complete.
- **A chunk scene that is THERE and will not load is refused for good.** A file that is not a scene,
  or one the loader turns down, is written off after a single attempt - remembered like a hole, so
  the world settles instead of erroring once a frame for ever. Fixing the file is not enough on its
  own: **Stream Chunks Around** is what clears that memory, so run it again (or restart) after the
  fix.
- **Ask for chunks before naming the folder and they wait.** **Keep Chunk** and **Preload Chunks
  Around** can be used before **Stream Chunks Around** has said where the chunk scenes live. Those
  cells sit in the queue and are loaded the moment a folder is named, rather than being looked for
  at a path with no folder in it and written off as holes; the streamer says so once and parks its
  tick until it has somewhere to look.
- **A streamer whose followed node is freed puts down what it was carrying.** The wanted set is an
  answer about a node that no longer exists, so it is dropped along with the follow - the radius of
  chunks around a place the game has left is never loaded in behind you. **Stream Chunks Around**
  starts it again.
- **The host sits at the origin, unscaled.** A chunk is placed at its cell's own corner in the
  HOST's space, while the cell a player is in is read off their GLOBAL position. A World node moved
  to (2000, 0), rotated or scaled therefore puts every chunk one transform away from the cell it
  belongs to. Move the camera, not the world.
- **Keep the camera out of the chunks.** A camera saved as the **current** one takes the view the
  moment its chunk streams in, and where nothing else is current the first chunk to arrive keeps
  it. A camera that is neither changes nothing, so this is a habit rather than a crash. The Doctor reports that one too.

## Already written it by hand? It reads as this pack

A `_process` that compares the player's cell with a dictionary of loaded scenes, calls
`ResourceLoader.load_threaded_request` and `queue_free`s what is behind, is exactly this pack. The
lines stay yours - open the script as a sheet and they read as themselves. Swapping them for the
pack is a choice about who maintains the loader, not about what the world is: the folder of chunk
scenes is the same folder either way.
