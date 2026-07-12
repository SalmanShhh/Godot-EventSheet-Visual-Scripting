# Run In Background - Heavy Compute Off the Main Thread

Run In Background is a Godot EventSheets behavior pack that moves heavy, self-contained computation off the main thread so your game never hitches. You attach a `BackgroundRunner` behavior to a host `Node` - a generator, a loader, a save system, whatever owns the work - and that node gains the ability to hand a **pure** function to a worker thread. You call **Run In Background** with a callable that does the crunching, the action returns instantly, and your game keeps running at full frame rate while the thread works. When the thread finishes, the **On Done** trigger fires on the main thread and hands you the `result`, which is the safe moment to touch the scene. There is no polling loop to write and no thread to manage by hand: the behavior owns the worker pool, tracks in-flight tasks, and marshals every result back to the main thread for you. The one rule you own is purity - the function you background must be data in, data out, with no scene-tree access.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Procedural generation.** Build a map chunk, a dungeon layout, or a cave grid on a worker thread and paint it when it lands, so the world appears without a stutter.
- **Pathfinding and nav bakes.** Run an expensive path search or a navigation bake off-thread and follow the route the instant On Done delivers it.
- **Image and texture processing.** Blur, recolor, or generate pixel data away from the main thread, then build the texture on the main thread when the bytes come back.
- **Save-game serialization.** Turn a game snapshot into bytes off-thread and write the file on completion, so a manual save never freezes the frame.
- **Large data parsing.** Chew through a big CSV or JSON blob on a thread and fill your tables once the parsed data arrives.
- **Mesh and terrain building.** Compute vertex and index arrays for a terrain surface off-thread, then assemble the mesh on the main thread in On Done.
- **Flow fields and influence maps.** Rebuild a crowd-steering grid on a worker thread each wave and swap it in when it is ready, keeping the AI responsive.
- **Batch jobs across many items.** Fan a whole list - unit paths, inventory thumbnails, region bakes - across worker threads with a single Run Batch In Background call.
- **The lane past frame-spreading.** When work is too heavy to smooth out even by spreading it across frames, moving it off the main thread entirely is the answer.
- **Responsive loading screens.** Keep a spinner animating and a progress label counting while the real work happens on a thread instead of blocking the UI.
- **Noise and heightmap crunching.** Generate large noise fields or heightmaps off-thread and hand the finished array back for the main thread to consume.

---

## Core concepts

The pack is small on purpose. Learn these ideas and you have the whole thing.

**The node is the worker owner.** You attach a `BackgroundRunner` behavior to a host `Node`, and every Action, Condition, Expression, and Trigger targets the behavior living on that node. There is no task id to pass around; you kick off work on the behavior and react to its On Done.

**Background means off the main thread.** Your game loop runs on the main thread. Anything slow you do there - a big generation pass, a deep path search - stalls a frame and the game visibly hitches. Run In Background hands that slow work to a worker thread from the engine's thread pool, so the main thread is free to keep drawing and simulating while the thread churns.

**You background a Callable.** The `work` parameter is a Godot `Callable`: a function value. In an event sheet you usually write it as a lambda, `func(): return build_thing(seed)`, or as a reference to a method that does the work. Run In Background runs that callable on the worker thread and captures whatever it returns.

**Purity is the one rule, and it is on you.** The callable you background must be pure - it reads plain data in and returns plain data out, and it never touches a node, the scene tree, `get_node`, or a resource that is not thread-safe. Touching the scene from a worker thread crashes the game or, worse, produces heisenbugs that only show up sometimes. Capture the numbers and arrays your function needs, do the math, and return a value. Nothing more.

**On Done runs on the main thread - that is where you touch the scene.** When a worker thread finishes, the behavior notices on the next frame and fires the **On Done** trigger back on the main thread, handing you the finished value as `result`. This is the safe place, and the only safe place, to apply the work to your scene: build the texture, place the tiles, assign the path, write the file.

**It is fire-and-forget.** Run In Background returns immediately; it does not hand you a return value inline. You cannot write `x = Run In Background ...`. You start the work in one event and receive the answer later in On Done. Think of it as posting a job and getting a callback.

**Batch fans one call per item.** Run Batch In Background takes an `items` array and a `work` callable and starts one background task per item, binding each item as the callable's argument. So `work` for a batch takes one parameter, `func(item): return crunch(item)`, and **On Done fires once for every item**, each with that item's result.

**Results are unlabeled and unordered.** On Done gives you one `result` at a time and does not tell you which task it came from, and across many tasks they arrive in whatever order the threads finish. If you need to know which job a result belongs to, make the callable return a dictionary that includes an id, for example `{"id": item, "data": ...}`, and read that id in On Done.

**Is Running and Tasks Running let you gate and report.** **Is Running** is true while at least one task is still in flight, which is perfect for a "do not start another one" guard or a loading spinner. **Tasks Running** returns the count of in-flight tasks, handy for a "3 jobs left" label. Inside On Done the just-finished task is already removed from the count, so when the last item of a batch lands, Tasks Running reads 0.

---

## Setup

**1. Attach the behavior.** Add a `BackgroundRunner` behavior as a child node of the host `Node` that owns the work - a generator, a loader, a save manager (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in). Any `Node` can be the host.

**2. There is nothing to configure.** This pack has no Inspector knobs. Attach it and it is ready; all the behavior it needs is in the ACEs you call.

**3. Wire the two moves.** Kick off the work with **Run In Background**, then apply the answer in **On Done**. Here is a complete first example - a generator that builds a maze off-thread and draws it when it is ready:

```
On Button Pressed "Generate"
  -> Generator | BackgroundRunner: Run In Background  func(): return build_maze(20, 20)

On Done
  -> Generator: draw the maze grid in result
```

`build_maze(20, 20)` must be a pure function - it returns a plain grid (an array of arrays, say) and touches no nodes. The action returns instantly, the game keeps running while the maze is built, and `On Done` hands back the grid as `result` on the main thread, which is where you turn it into tiles.

---

## ACE reference

All ACEs live in the **Background** category and target the `BackgroundRunner` behavior on the node it is attached to. There is no task-id parameter anywhere; you start work on the behavior and react to its On Done.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Run In Background | `work` (Callable) | Hands a PURE callable to a worker thread and returns immediately; On Done(result) fires on the main thread when it finishes. The callable must not touch nodes, the scene tree, or non-thread-safe resources - data in, data out only. |
| Run Batch In Background | `items` (Array), `work` (Callable) | Fans the array across worker threads: runs `work` bound with each item, so On Done fires once per item with that item's result. The callable must be PURE and take one argument (the item). |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Running | (none) | Whether at least one background task is still in flight. True from the moment you start work until its On Done, false when the behavior is idle. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Tasks Running | (none) | int | How many background tasks are currently in flight (0 when idle). Inside On Done the just-finished task is already removed, so the last item of a batch reads 0. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Done | A background task finishes. Runs on the main thread (safe to touch the scene) and hands back the callable's return value as `result`. Fires once per task, which means once per item for Run Batch In Background. |

### Inspector properties

This pack has no Inspector properties - there is nothing to set. Attach the behavior and call the ACEs.

---

## Use cases

Each example targets the `BackgroundRunner` behavior on the named node. Start the work with an action, keep every scene change inside `On Done`, and make sure the callable you background is pure.

### 1. Procedural map chunk generation

Build a world chunk off-thread and place its tiles when it lands. The guard stops a second generation from stacking on the first.

```
On Button Pressed "Generate"
  Condition (inverted): World | BackgroundRunner  Is Running
    -> World | BackgroundRunner: Run In Background  func(): return MapMath.build_chunk(current_seed, chunk_x, chunk_y)

On Done
  -> World: place the tiles in result
```

`MapMath.build_chunk` is a pure function that returns a plain tile array; it never touches the scene. All the placing happens in On Done on the main thread.

### 2. Pathfinding bake without a hitch

Run an expensive path search on a worker thread so a big grid never stalls the frame, then follow the route in On Done.

```
On Path Requested
  -> Level | BackgroundRunner: Run In Background  func(): return NavMath.find_path(start_cell, goal_cell, grid_snapshot)

On Done
  -> Unit: follow the path in result
```

`grid_snapshot` is a plain copy of the grid data captured on the main thread and handed in by value, so the thread never reads a live node.

### 3. Fan a whole squad's paths across threads

Issue orders to many units at once and let Run Batch In Background start one search per request. Each callable returns a dictionary carrying the unit id, so On Done can route the path back to the right unit.

```
On Orders Issued
  -> Level | BackgroundRunner: Run Batch In Background  unit_requests, func(req): return {"id": req.id, "path": NavMath.find_path(req.start, req.goal, grid_snapshot)}

On Done
  -> Level: assign result.path to the unit named result.id
```

Because On Done fires once per item and results are unlabeled, the `id` you fold into the return value is how you tell the paths apart.

### 4. Image or texture processing off-thread

Crunch pixel data on a worker thread, then build the texture on the main thread when the bytes come back.

```
On Filter Chosen
  -> Photo | BackgroundRunner: Run In Background  func(): return ImageMath.gaussian_blur(source_bytes, width, height, radius)

On Done
  -> Photo: build an ImageTexture from result and show it
```

The blur works on a raw byte buffer (pure data), and the texture - a resource that must be created on the main thread - is built in On Done.

### 5. Save-game serialization

Turn a game snapshot into bytes off-thread so a manual save never freezes the frame, then write the file when the bytes are ready.

```
On Save Pressed
  -> SaveSystem | BackgroundRunner: Run In Background  func(): return var_to_bytes(snapshot_dict)

On Done
  -> SaveSystem: write result to user://save.dat
  -> HUD: flash "Saved"
```

Build `snapshot_dict` as a plain data copy on the main thread before you background it; the thread only serializes, and the file write happens in On Done.

### 6. A loading spinner driven by Is Running

Show and animate a spinner exactly while work is in flight, and hide it the moment the behavior goes idle.

```
Every 0.1 seconds
  Condition: Loader | BackgroundRunner  Is Running
    -> Spinner: show and rotate
  Condition (inverted): Loader | BackgroundRunner  Is Running
    -> Spinner: hide
```

Is Running flips true the instant you start a task and false when its On Done has fired, so the spinner tracks the work with no extra bookkeeping.

### 7. Progress readout with Tasks Running

Count remaining jobs on the HUD during a big batch so the player sees progress instead of a frozen screen.

```
Every 0.25 seconds
  -> HUD: set label to str(Loader | BackgroundRunner  Tasks Running) + " jobs left"
```

Tasks Running returns the live count of in-flight tasks, dropping toward 0 as each one finishes.

### 8. Procedural mesh baking for terrain

Compute vertex and index arrays for a terrain surface off-thread, then assemble the mesh on the main thread.

```
On Chunk Needed
  -> Terrain | BackgroundRunner: Run In Background  func(): return MeshMath.build_surface(heightmap, chunk_x, chunk_y)

On Done
  -> Terrain: create a MeshInstance3D from the arrays in result
```

`MeshMath.build_surface` returns plain arrays; building the actual mesh and adding the node happen in On Done where the scene tree is safe.

### 9. Parse a large data file

Chew through a big text blob on a worker thread and fill your table once the structured data arrives.

```
On Import Pressed
  -> Importer | BackgroundRunner: Run In Background  func(): return DataMath.parse_csv(raw_text)

On Done
  -> Importer: populate the table from result
```

Read the file's text into `raw_text` on the main thread first, then background only the parsing, which is pure string-to-data work.

### 10. Batch thumbnail generation for an inventory

Render an icon for every item id across worker threads so opening a full inventory does not stall. Each callable tags its image with the id so On Done fills the right slot.

```
On Inventory Opened
  -> Grid | BackgroundRunner: Run Batch In Background  item_ids, func(id): return {"id": id, "image": IconMath.render_icon(id)}

On Done
  -> Grid: set the slot for result.id to result.image
```

One task starts per item id, and On Done fires once per icon as each finishes, filling slots as they arrive rather than all at the end.

### 11. Guard against a double run

Only start a new generation when none is in flight, and give the player feedback if they mash the button while one is running.

```
On Regenerate Pressed
  Condition (inverted): Dungeon | BackgroundRunner  Is Running
    -> Dungeon | BackgroundRunner: Run In Background  func(): return DungeonMath.layout(current_seed, room_count)
  Condition: Dungeon | BackgroundRunner  Is Running
    -> HUD: flash "Still generating..."
```

The inverted Is Running is the cheap way to make an action idempotent so you never queue a hundred duplicate jobs.

### 12. Flow field for crowd steering

Rebuild a steering grid off-thread at the start of each wave and swap it in when it is ready, keeping the AI responsive during the rebuild.

```
On Wave Start
  -> AI | BackgroundRunner: Run In Background  func(): return FieldMath.build_flow_field(obstacle_grid, goal_cell)

On Done
  -> AI: swap in the flow field in result
```

`obstacle_grid` is a plain snapshot handed in by value; the units keep using the old field until the new one lands in On Done.

### 13. Cellular-automata cave generation

Generate and smooth a cave grid on a worker thread, then paint it to the TileMap on the main thread.

```
On New Level
  -> Cave | BackgroundRunner: Run In Background  func(): return CaveMath.smooth(CaveMath.random_fill(width, height, fill_pct), passes)

On Done
  -> Cave: paint the grid in result to the TileMap
```

All the smoothing passes are pure array math; only the final paint touches the TileMap, and it happens safely in On Done.

### 14. Wait for a whole batch before starting the round

Bake navigation for every region up front, apply each as it finishes, and start the round only when the last one lands - detected by Tasks Running reading 0 inside On Done.

```
On Level Load
  -> Baker | BackgroundRunner: Run Batch In Background  region_ids, func(id): return {"id": id, "nav": NavMath.bake_region(id)}

On Done
  -> Level: apply result.nav for region result.id
  Condition (expression): Baker | BackgroundRunner  Tasks Running  ==  0
    -> Game: start the round
```

Inside On Done the just-finished task is already gone from the count, so `Tasks Running == 0` is exactly the "that was the last one" signal.

### 15. Timed autosave with the Timer pack

Pair with the Timer pack for a hands-free autosave: a repeating Timer supplies the beat, and the serialization runs off-thread so the save never hitches a frame.

```
On Timer
  Condition (inverted): SaveSystem | BackgroundRunner  Is Running
    -> SaveSystem | BackgroundRunner: Run In Background  func(): return var_to_bytes(snapshot_dict)

On Done
  -> SaveSystem: write result to user://autosave.dat
```

The inverted Is Running simply skips a beat if the previous save is still in flight, so autosaves never stack.

### Other use cases

**Roguelike floor pre-baking.** Generate the next dungeon floor on a worker thread while the player finishes the current one, so taking the stairs swaps floors instantly instead of showing a loading pause.

**Leaderboard crunching.** Sort and rank thousands of score entries off-thread when the results screen opens, then fill the list in On Done so the screen itself appears immediately.

**Replay compression.** Compress a match's input recording into bytes on a worker thread when the round ends, and write the file in On Done while the players are already back in the lobby.

**Word-game move finder.** Search a huge dictionary for valid plays off-thread each turn, and light up the hint button the moment the result lands.

**Fog-of-war rebuild.** Recompute the minimap's revealed-tiles data on a worker thread whenever a region is explored, and swap the finished texture in during On Done.

---

## Tips and common mistakes

- **Purity is the one rule, and it is unenforceable.** The callable you background must not touch a node, `get_node`, the scene tree, or a resource that is not thread-safe. Reading a live node from a worker thread crashes the game or gives you heisenbugs that only appear sometimes. Capture plain numbers and arrays, do the math, return data.
- **Do every scene change in On Done.** On Done runs on the main thread, and that is the only safe place to place tiles, build a texture or mesh, assign a path, or write a file. If a change touches the scene, it belongs in On Done, never inside the backgrounded callable.
- **It is fire-and-forget - you cannot read the result inline.** Run In Background returns immediately with no value. Start the work in one event and receive the answer later in On Done; do not try to use the result on the next line.
- **Pass data in by value, not node references.** Snapshot what the callable needs (a grid copy, a byte buffer, a plain dictionary) on the main thread and let the lambda capture those, so the thread never reaches back into a live object.
- **Results are unlabeled and can arrive out of order.** On Done hands you one `result` with no "which task" tag, and across many tasks they finish in thread order, not start order. If you need to know the source, return a dictionary that includes an id and read it in On Done.
- **Only background genuinely heavy work.** Handing a job to a worker thread has overhead, so a tiny task is faster done inline. Reach for this pack when the work would otherwise stall a frame, not for trivial calculations.
- **Gate re-runs with Is Running.** Wrapping a start action in an inverted Is Running condition makes it idempotent so a mashed button or a rapid trigger does not stack dozens of duplicate jobs.
- **Run Batch In Background fires On Done once per item.** It starts one task per array element, so your On Done reactions run once for each item, not once for the whole array. Size your handling accordingly and use Tasks Running to detect the last one.
- **Results surface on the next frame, not instantly.** The behavior polls finished tasks each frame and then emits On Done, so even a quick job lands a frame or two after it finishes rather than the same instant. Do not expect the answer in the same event that started it.
- **Do not mutate shared state from the callable.** Two threads writing the same dictionary or array is a race. Have each callable build and return its own new data, and merge it into your game state in On Done.
