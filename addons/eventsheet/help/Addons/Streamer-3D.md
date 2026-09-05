# Streamer 3D - A 3D World Bigger Than Memory

The same words as the 2D pack, on a `Vector3i` grid. `chunk_3_0_-2.tscn` is the piece three cells
east and two cells north. **Stream Chunks Around** a node keeps the pieces within a radius of it
loaded, on a thread, and frees the ones behind. **Stream Height** decides whether the grid is flat
(what an open world wants) or stacks - and it is off by default.

## Where this pack shines

- **A terrain you can actually open.** The editor holds one square kilometre, not the whole map.
- **A station, a cave, a tower.** Turn Stream Height on and cells stack, so a vertical world is the
  same nine words.
- **Nothing proprietary.** The layout is files. Make them by hand, in a file browser, or with the
  Split Scene Into Chunks tool.

## Setup

1. Attach `Streamer3DBehavior` as a child of the node your chunks should live under (your World
   node). Chunks are added as ITS children.
2. Set **Cell Size** to the size of one chunk in metres. Every chunk scene is authored around its
   own origin, and the grid puts it in the world.
3. Leave **Stream Height** off unless your world is genuinely stacked - see the warning below.
4. Make a folder of chunk scenes named `chunk_X_Y_Z.tscn` - by hand, or by pressing **Ctrl+P** and
   running **Split Scene Into Chunks** on the big scene you have already built.

```
On Ready -> Streamer3D | Stream Chunks Around  Player, 2, "res://world/chunks/"
```

## Flat or stacked - the one decision this pack asks for

With **Stream Height** off, the grid is flat: every cell's Y is `0` however high the player climbs,
so a mountain and the valley beside it are the same chunk. That is what an open world wants, and it
is why the default is off.

With it on, height becomes a cell axis. A radius of 1 goes from **nine** chunks to **twenty-seven**,
and a radius of 2 from twenty-five to a hundred and twenty-five. Turn it on for a space station, a
cave system or a tower, where the world really is stacked - and lower the radius when you do.

## ACE reference

On the canvas these rows read as styled sentences - parameter values in **bold**, node references
in *italic*, exactly as the rows draw them:

- Stream chunks around *Player*, **2** cells, from **res://world/chunks/**
- Keep chunk **(0, 0, 0)** loaded

| Kind | Name | Parameters | Description |
|---|---|---|---|
| Action | Stream Chunks Around | `around` (Node3D), `radius_cells`, `folder` | Follows a node and keeps the chunk scenes within this many cells of it loaded, freeing the ones behind. |
| Action | Stop Streaming | (none) | Stops following. Loaded chunks stay exactly where they are. |
| Action | Keep Chunk | `cell` (Vector3i) | Pins one cell's chunk: it loads if it is not already, and distance never releases it. |
| Action | Release Chunk | `cell` (Vector3i) | Unpins one cell's chunk and takes it out now, firing On Chunk Unloading first. |
| Action | Preload Chunks Around | `point` (Vector3), `radius_cells` | Asks for the chunks around a point before anything goes there - a teleport, a fast travel, a cutscene. |
| Condition | Chunk Is Loaded At | `point` (Vector3) | Whether the chunk covering this world point is in the world right now. |
| Condition | Is Loading Chunks | (none) | Whether anything is still on its way in. False is the moment the world around the player is complete. |
| Expression | Loaded Chunk Count | (none) | How many chunk scenes are in the world right now. |
| Expression | Chunk Of | `point` (Vector3) | The cell a world point falls in, as a Vector3i. Feed it to Keep Chunk or Release Chunk. |
| Trigger | On Chunk Loaded | `chunk` (Node), `cell` (Vector3i) | Fired once per chunk, with the node, just after it joins the world. |
| Trigger | On Chunk Unloading | `chunk` (Node), `cell` (Vector3i) | Fired BEFORE the chunk is dropped, so a row can save what the player changed in it. |
| Trigger | On Streaming Idle | (none) | Fired once when nothing is left to load, and not again until something is. |

### Inspector properties

| Property | Default | What it does |
|---|---|---|
| `cell_size` | `(64, 64, 64)` | How big one chunk is, in metres. A point's cell is the point divided by this, floored. |
| `budget_ms` | `4` | How long one frame may spend taking finished chunks in. The rest wait for the next frame. |
| `keep_radius_cells` | `1` | How many rings beyond the radius a chunk is kept before it is released - the hysteresis. |
| `stream_height` | `false` | Whether height is a cell axis. Off is a flat grid; on stacks cells, and multiplies how many a radius asks for. |
| `chunk_prefix` | `chunk` | The words before the cell numbers. Do not end it with a digit: the numbers at the END of a name are the address. |

## Reading it from expressions - the Self section

Type `self` in any ƒx field, or open the ƒx **Expressions dictionary**, and **Self ▸ Behaviours**
lists this pack's knobs as ready-to-insert chains once the behaviour is attached:

- `$Streamer3DBehavior.cell_size` inserts the **Cell Size** entry straight into any expression
- `$Streamer3DBehavior.stream_height` inserts the **Stream Height** entry

The `$Streamer3DBehavior` token stays selected after insert, so retargeting to your child's actual
name is one keystroke, or a node drag.

## The two editor tools

Press **Ctrl+P** for the command palette:

- **Split Scene Into Chunks** reads one scene, moves each direct child of its root into the cell
  that child's own position falls in, re-bases it to that cell's origin, and writes the folder.
  Tick **Height is a cell axis** for a stacked world.
- **Merge Chunks** is the way back: it reads the folder, puts every child where its cell says, and
  saves one scene you can edit as a whole again.

Neither tool changes what it reads, so splitting and merging are both reversible.

## Use cases

### 1. The whole feature

```
On Ready -> Streamer3D | Stream Chunks Around  Player, 2, "res://world/chunks/"
```

That is a streamed world. A radius of 2 on a flat grid is a five-by-five block around the player.

### 2. Save what the player changed

```
On Chunk Unloading -> Save | Save Node State  chunk, "chunk_state"
On Chunk Loaded    -> Save | Load Node State  chunk, "chunk_state"
```

A felled tree stays felled, because the chunk's last moment is a row rather than a race.

### 3. Wake the boss when its ground exists

```
On Every Tick
  Condition: Streamer 3D - Chunk Is Loaded At  Boss.position -> Boss | wake up
```

### 4. A fast travel that does not land in the sky

```
On Fast Travel Chosen -> Streamer3D | Preload Chunks Around  destination, 1
                      -> Screen     | fade to black
On Streaming Idle     -> Player     | set position to destination
                      -> Screen     | fade from black
```

### 5. Pin the hangar

```
On Ready -> Streamer3D | Keep Chunk  (0, 0, 0)
```

### 6. A loading screen that ends when the world is ready

```
On Ready          -> Streamer3D | Stream Chunks Around  Player, 2, "res://world/chunks/"
On Streaming Idle -> LoadingScreen | hide
```

### 7. Notice a border being crossed

```
On Every Tick
  Condition: Streamer 3D - Chunk Of  Player.position  ≠  last_cell
    -> set last_cell to Streamer3D.Chunk Of  Player.position
    -> Music | play the track for this region
```

### 8. A memory budget you can see

```
On Every 1 seconds -> Debug Overlay | watch "chunks", Streamer3D.Loaded Chunk Count
```

On a stacked grid this number is the first thing to look at: twenty-seven chunks is three times the
scenery of nine, and the frame time follows.

### 9. A flight sim needs a bigger radius, not a bigger budget

The radius is how far ahead the world exists. A plane at 200 metres a second crosses three cells a
second, so it needs four rings of them.

```
On Take Off -> Streamer3D | Stream Chunks Around  Plane, 4, "res://world/chunks/"
On Land     -> Streamer3D | Stream Chunks Around  Pilot, 2, "res://world/chunks/"
```

### 10. A space station, stacked

Turn Stream Height on and drop the radius: a station is small in every direction and tall in one.

```
On Ready -> Streamer3D | set stream_height to true
         -> Streamer3D | Stream Chunks Around  Player, 1, "res://station/chunks/"
```

### 11. A cave system under a flat overworld

Two folders, two worlds. The cave is stacked, the surface is not, and entering one stops the other.

```
On Enter Cave -> Streamer3D | Stop Streaming
              -> Streamer3D | set stream_height to true
              -> Streamer3D | Stream Chunks Around  Player, 1, "res://caves/chunks/"
```

### 12. Spawn wildlife as its chunk arrives

```
On Chunk Loaded -> Object Pool | take a "deer" and put it at chunk.position
```

### 13. A cutscene that must not hitch

```
On Cutscene Start -> Streamer3D | set budget_ms to 1
On Cutscene End   -> Streamer3D | set budget_ms to 8
```

### 14. Release the room the quest is finished with

```
On Quest Complete -> Streamer3D | Release Chunk  (4, 0, -1)
```

### 15. Hold the autosave until the world is quiet

```
On Autosave Due
  Condition: Streamer 3D - Is Loading Chunks -> Save | Delay Autosave By  2
  Else                                       -> Save | Save Game
```

### 16. Turn the terrain you already built into a streamed one

Press **Ctrl+P**, run **Split Scene Into Chunks** on the scene you have, point the Streamer at the
folder it wrote, and delete the children from the original.

### Other use cases

**A survival island.** Chunk Is Loaded At doubles as "is this part of the map near the player",
which is what a spawn director and a fog-of-war map both want to know.

**A dungeon crawler with real floors.** Stacked cells make a stairwell an ordinary walk between two
chunks rather than a scene change.

**A city driving game.** Blocks are chunks and the keep radius is the rear-view mirror: what you
just drove past is still there when you reverse.

**A co-op world with one host.** The host streams around the player who is furthest ahead, and the
keep radius covers the one trailing behind.

**A level editor's preview.** Merge Chunks, edit the whole world as one scene, split it again - the
round trip is what makes a folder of chunks editable rather than a build artifact.

## Tips and common mistakes

- **Keep the chunk folder in your export.** Godot's exporter drops resources nothing references,
  and chunk scenes are referenced by NAME at run time, not by a link - so an export that filters by
  dependency ships a game whose world is empty. Add `res://world/chunks/*` to the export preset's
  **Resources ▸ Filters to export non-resource files/folders**, or keep the export mode as "all
  resources in the project". This is the one mistake that works perfectly in the editor and fails
  on the machine you sent the game to.
- **Threads are not free everywhere.** `load_threaded_request` is what this pack uses, and on an
  export without thread support (a single-threaded Web build) Godot finishes such a request on the
  main thread. The budget still spreads the work over frames, but the load itself cannot be moved
  off the main thread on a platform that has only one. There is no way around that from here.
- **The final instantiate is on the main thread, always.** A chunk with three thousand nodes in it
  costs a frame whatever the budget says. If chunks hitch, make them smaller before you make the
  budget bigger.
- **Stream Height is expensive, and quietly.** Nothing errors when you turn it on; there are simply
  three times as many chunks in the radius, and the frame time and the memory follow. Lower the
  radius in the same breath.
- **Do not end the prefix with a digit.** The numbers at the END of a name are the address.
- **A GridMap is one node, not a world of cells.** Split Scene Into Chunks moves nodes; it does not
  rewrite a GridMap's cell data. Build your world in GridMap pieces, one per chunk scene, or split
  by hand.
- **Author every chunk around its own origin.** The grid does the placing.
- **The host sits at the origin, unscaled.** A chunk is placed at its cell's own corner in the
  HOST's space, while the cell a player is in is read off their GLOBAL position. A World node moved
  away from the origin, rotated or scaled therefore puts every chunk one transform away from the
  cell it belongs to. Move the camera, not the world.
- **Keep the camera out of the chunks.** A camera saved as the **current** one takes the view the
  moment its chunk streams in, and where nothing else is current the first chunk to arrive keeps
  it. A camera that is neither changes nothing, so this is a habit rather than a crash. The Doctor's Streaming section
  reports that, and a hole in an otherwise complete grid.
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

## Already written it by hand? It reads as this pack

A `_process` that compares the player's cell with a dictionary of loaded scenes, calls
`ResourceLoader.load_threaded_request` and `queue_free`s what is behind, is exactly this pack. The
lines stay yours - open the script as a sheet and they read as themselves. Swapping them for the
pack is a choice about who maintains the loader, not about what the world is: the folder of chunk
scenes is the same folder either way.
