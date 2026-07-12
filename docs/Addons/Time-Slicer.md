# Time Slicer - Spread Heavy Work Across Frames, No Hitch

Time Slicer is a Godot EventSheets behavior pack that turns "do this to a big pile of things" into "do a little of it every frame until it is done". You attach a `TimeSlicerBehavior` to a Node and it becomes a managed work queue. You **enqueue** items (nodes, numbers, dictionaries, positions - anything) in one event, and the slicer drains them a slice at a time each frame, emitting **On Process Item** for each one, until a per-frame **budget** runs out. Reacting to On Process Item feels exactly like reacting to a signal: you write the heavy per-item work once, and the slicer decides how many items to run this frame so the game never stalls. Spawning 500 enemies, deserializing a save, carving a dungeon, damaging a whole crowd - work that would freeze the frame if done all at once self-spreads across as many frames as the budget needs, with no manual loop, no `await`, and no coroutine bookkeeping. Attach one per node, or register a single `TimeSlicerBehavior` as an autoload for one global slicer the whole game shares.

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

- **Spawning a big wave.** Enqueue 500 spawn requests and let a handful hatch each frame instead of instancing all of them in one hitch-inducing burst.
- **Applying area damage to a crowd.** Push every enemy in a group through the queue so a nuke that hits 300 units spreads its damage math over a few frames rather than spiking one.
- **Procedural generation.** Carve a dungeon room by room, or place tiles chunk by chunk, one queued step per On Process Item, and fire a "done" hook on On Drained.
- **Warming an object pool.** Pre-instance bullets, particles, or enemies at scene start over several frames so the loading beat stays smooth.
- **Streaming a save file.** Enqueue each saved record and deserialize one per On Process Item, keeping the load screen animating while data comes in.
- **Updating thousands of entities.** Refresh AI, pathfinding, or fog-of-war for a slice of your entity list each frame instead of the whole army at once.
- **Loading-screen progress.** Drive a progress bar straight off Items Remaining and hide the screen on On Drained - the queue size is your progress meter for free.
- **Batch node processing.** Run "do X to every node in this group" (open all doors, reset all pickups, rebake all lights) evenly across frames with Enqueue Group.
- **Loot and pickup explosions.** Queue each drop from a slain boss so a hundred coins scatter over a few frames instead of one dropped-frame pop.
- **Fixed-rate drip.** Set the mode to count and cap items per frame to release work at an exact, predictable pace (a steady spawner, a metered particle emitter).
- **Deferred cross-scene work.** Register one slicer as an autoload and have any scene enqueue background jobs onto the single shared queue.
- **Anything that currently freezes.** Any `for` loop over a big list that drops a frame is a candidate: enqueue the list, move the loop body into On Process Item, and the freeze becomes a smooth spread.

---

## Core concepts

The whole pack is one idea - a queue that empties itself within a budget - plus a few dials. Learn these and you know the pack.

**The work queue.** The slicer holds a list of pending **items**. An item is a `Variant`: a node, an integer index, a `Vector2` spawn position, a dictionary of spawn data, a string id - whatever your per-item work needs. Nothing happens to an item when you enqueue it; it just waits its turn.

**Enqueue adds work.** You fill the queue with **Enqueue Item** (one item), **Enqueue Items** (a whole array at once), or **Enqueue Group** (every node in a scene-tree group). You can keep enqueuing at any time; new items land at the back of the line.

**The drain loop runs every frame.** On its own, each frame, the slicer pulls items off the front of the queue and emits **On Process Item(item)** for each one. That trigger is where your heavy per-item work goes - spawn the enemy, apply the damage, place the tile. It reads like reacting to a signal: one item in, one reaction out.

**The budget decides how many run this frame.** The loop does not drain the whole queue in one frame; it stops when it hits the per-frame budget. Two limits govern it:

- `frame_budget_ms` - a wall-clock time fence. The loop keeps processing items until this many milliseconds have elapsed this frame, then stops and resumes next frame.
- `max_items_per_frame` - a hard cap on how many items process in a single frame.

**Mode picks which limits apply.** The `mode` Inspector knob chooses between them:

- `both` (default) - the loop stops at whichever limit comes first (the time fence OR the count cap). This is the safe general choice: it will not overrun the frame time and it will not stampede.
- `ms` - only the time fence matters; the count cap is ignored. Use all the budget, however many items that turns out to be. Best raw throughput.
- `count` - only the count cap matters; the time fence is ignored. Exactly up to `max_items_per_frame` items every frame. Best for a predictable, fixed-rate drip.

**On Drained fires when the queue empties.** The frame the last item is processed and the queue becomes empty, the slicer emits **On Drained**. This is your "the batch is finished" hook - hide the loading screen, start the wave, run the next phase.

**Pause, Resume, and Clear.** **Pause** stops the drain without losing the queue (items stay parked until you Resume). **Resume** starts it draining again. **Clear Queue** throws away all pending items without processing them - use it when the work is no longer wanted (the player left the area, the round ended).

**Inspecting the queue.** **Is Busy** is true while items remain. **Items Remaining** is the current queue size (a ready-made progress value). **Last Frame Item Count** is how many items the loop processed on the most recent frame (handy for tuning the budget by eye).

**Runtime budget tuning.** **Set Frame Budget** changes `frame_budget_ms` on the fly, so you can dial the slicer down during an already-heavy scene and back up when things calm.

---

## Setup

**1. Attach the slicer (per-node).** Add a `TimeSlicerBehavior` as a child of the node that owns the work - a spawner, a level manager, a boss. It reads its parent as its host, so any Node parent works. Open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in as a child.

**2. Or register one as an autoload (global).** If you want a single queue the whole game shares, add one `TimeSlicerBehavior` as an autoload in Project Settings and call its ACEs on that global node. One slicer, one queue, available from every scene.

**3. Set the Inspector knobs.** Select the slicer node and tune the budget:

| Property | Default | What it does |
|---|---|---|
| `frame_budget_ms` | `4.0` | Max milliseconds per frame spent draining the queue (used when the mode includes ms). Range 0.1 - 16. |
| `max_items_per_frame` | `64` | Hard cap on items processed per frame (used when the mode includes count). |
| `mode` | `both` | Which limits apply: `both` stops at whichever comes first, `ms` uses only the time fence, `count` uses only the item cap. |

**4. Wire the loop.** Two moves: enqueue the work, then react in On Process Item (and optionally On Drained). Here is a complete first slicer - spawn 500 enemies smoothly instead of all at once:

```
On Ready
  -> Spawner | Time Slicer: Enqueue Items  range(500)

On Process Item  (item)
  -> Spawner: instance one enemy at a random point

On Drained
  -> Spawner: print "wave fully spawned"
```

`range(500)` drops 500 index items into the queue in one call. The slicer then hatches only as many per frame as the 4 ms budget allows, emitting On Process Item for each, and fires On Drained the frame the last one spawns. You never wrote a loop - the queue is the loop.

---

## ACE reference

All ACEs live in the **Time Slicer** category and act on the `TimeSlicerBehavior` of the node they are placed on (or on your autoload slicer if you registered one). There is no queue-id parameter - the node is the queue.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Enqueue Item | `item` (Variant) | Adds one item to the work queue (processed later within the per-frame budget). |
| Enqueue Items | `items` (Array) | Adds every element of an array to the work queue. |
| Enqueue Group | `group` (String) | Adds every node in a scene-tree group to the work queue (for example, process all enemies, spread over frames). |
| Clear Queue | (none) | Drops all pending items without processing them. |
| Set Frame Budget | `ms` (float) | Sets the per-frame millisecond budget at runtime (dial it down during heavy scenes). |
| Pause | (none) | Stops draining (items stay queued). |
| Resume | (none) | Resumes draining the queue. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Busy | (none) | Whether the queue still has pending items (true while draining). |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Items Remaining | (none) | int | How many items are still waiting in the queue. |
| Last Frame Item Count | (none) | int | How many items the loop processed on the most recent frame. |

### Triggers

| Trigger | Parameter | Fires when |
|---|---|---|
| On Process Item | `item` (Variant) | The loop pulls an item off the queue this frame. Runs once per item, up to the per-frame budget. Do the heavy per-item work here. |
| On Drained | (none) | The queue becomes empty (the last pending item was just processed). |

### Inspector properties

| Property | Type | Default | Range / options |
|---|---|---|---|
| `frame_budget_ms` | float | `4.0` | 0.1 - 16 |
| `max_items_per_frame` | int | `64` | any positive int |
| `mode` | String | `both` | `both`, `ms`, or `count` |

---

## Use cases

Each example acts on the `TimeSlicerBehavior` of the named node. Enqueue in one event, react in On Process Item, and use On Drained for the finish hook.

### 1. Spawn a huge wave without a hitch

Instancing 300 enemies in one frame drops the frame. Queue them and let the budget spread the spawns.

```
On Wave Start
  -> Spawner | Time Slicer: Enqueue Items  range(300)

On Process Item  (item)
  -> Spawner: instance one enemy at a random spawn point
```

Each On Process Item spawns exactly one enemy; the 4 ms budget decides how many that is per frame, so the wave fills in smoothly over a handful of frames.

### 2. Process every node in a group evenly

Do something to all enemies (or all doors, all torches) without touching them all at once. Enqueue Group pulls the whole group into the queue in one call.

```
On Alarm Raised
  -> Manager | Time Slicer: Enqueue Group  "enemies"

On Process Item  (item)
  -> item: switch to alert state
```

The `item` handed to each On Process Item is one node from the "enemies" group.

### 3. Area damage to a crowd

A screen-clearing bomb hits everything, but resolving hundreds of damage calculations in one frame spikes. Spread them.

```
On Bomb Detonated
  -> Field | Time Slicer: Enqueue Group  "damageable"

On Process Item  (item)
  -> item: take 40 damage
```

Every damageable node flows through the queue; the crowd takes its hits over a couple of frames instead of one stutter.

### 4. Procedural generation, room by room

Carve a dungeon a step at a time. Queue the room count, build one room per item, and reveal the level when the queue drains.

```
On Generate Level
  -> Dungeon | Time Slicer: Enqueue Items  range(40)

On Process Item  (item)
  -> Dungeon: carve room number item and connect its corridors

On Drained
  -> Dungeon: place the player and fade in
```

On Drained is the clean "generation finished" hook - no polling, no timer guessing.

### 5. Warm an object pool at load

Pre-instance pooled objects across frames so the loading beat never stutters.

```
On Ready
  -> Pool | Time Slicer: Enqueue Items  range(200)

On Process Item  (item)
  -> Pool: create one pooled bullet, hide it, add it to the free list
```

Two hundred bullets get built a slice per frame while the rest of the scene keeps ticking.

### 6. Loading-screen progress bar for free

Items Remaining is already a progress value. Drive a bar off it and dismiss the screen on On Drained.

```
On Load Started
  -> Loader | Time Slicer: Enqueue Items  save_records

Every 0.1 seconds
  -> Loader: set progress bar to 1.0 - Loader | Time Slicer: Items Remaining / total_records

On Drained
  -> Loader: hide loading screen and start the game
```

No manual counter to keep in sync - the queue size is the truth.

### 7. Stream in a save file

Deserialize one saved record per item so a big save never blocks the load screen.

```
On Continue Pressed
  -> SaveIO | Time Slicer: Enqueue Items  raw_record_list

On Process Item  (item)
  -> SaveIO: rebuild one entity from the record dictionary item
```

Each `item` is one record dictionary; the world rebuilds smoothly as data streams in.

### 8. Pause during a cutscene, resume after

Background work should not chew frame time while a cutscene plays. Park the queue and pick it back up.

```
On Cutscene Start
  -> Spawner | Time Slicer: Pause

On Cutscene End
  -> Spawner | Time Slicer: Resume
```

Pause keeps every queued item intact - Resume continues exactly where it left off.

### 9. Dial the budget down in a heavy scene

When a scene is already stressed, lower the slicer's share of the frame, then restore it when things calm.

```
On Heavy Combat Begin
  -> Spawner | Time Slicer: Set Frame Budget  1.5

On Heavy Combat End
  -> Spawner | Time Slicer: Set Frame Budget  4.0
```

Set Frame Budget takes effect on the next frame, trading spawn speed for a steadier frame rate while it matters.

### 10. Cancel pending work when it stops mattering

The player left the area before the queued spawns finished - throw the rest away.

```
On Player Left Room
  -> Spawner | Time Slicer: Clear Queue
```

Clear Queue drops every pending item without processing it, so no stragglers spawn into an empty room.

### 11. Do not restart a batch that is still running

Guard a re-enqueue behind Is Busy so a button mash or repeated trigger does not stack duplicate work.

```
On Rebuild Pressed
  Condition: [NOT] Grid | Time Slicer  Is Busy
    -> Grid | Time Slicer: Enqueue Items  range(cell_count)
```

Is Busy is true while items remain, so the rebuild only queues when the last one has fully drained.

### 12. Fixed-rate drip with count mode

For an exact, predictable release pace, set `mode` to `count` and `max_items_per_frame` to a small number in the Inspector. The slicer then processes exactly that many items each frame regardless of time.

```
On Start Trickle Spawner
  -> Spawner | Time Slicer: Enqueue Items  range(120)

On Process Item  (item)
  -> Spawner: spawn one drone
```

With `mode` = `count` and `max_items_per_frame` = 2, the queue releases exactly two drones per frame - a steady, metered stream.

### 13. Maximum throughput with ms mode

When you just want the batch done as fast as the frame allows, set `mode` to `ms` so only the time fence limits it - the item cap is ignored and the loop uses the whole millisecond budget.

```
On Ready
  -> Baker | Time Slicer: Enqueue Items  range(5000)

On Process Item  (item)
  -> Baker: bake one lightmap cell
```

With `mode` = `ms` and `frame_budget_ms` = 6.0, each frame chews through as many cells as fit in 6 ms, unbounded by count - fastest completion without overrunning the frame.

### 14. Chain phases with On Drained

Run a multi-stage pipeline where finishing one queue kicks off the next, keeping every stage frame-friendly.

```
On Build World
  -> World | Time Slicer: Enqueue Items  range(terrain_chunks)

On Drained
  Condition: World: phase == "terrain"
    -> World: set phase to "props"
    -> World | Time Slicer: Enqueue Items  range(prop_count)
  Condition: World: phase == "props"
    -> World: set phase to "done" and reveal the level
```

Each On Drained advances to the next stage and enqueues its work, so terrain finishes before props begin, all without a single blocking loop.

### 15. Tune the budget by watching Last Frame Item Count

While tuning, read Last Frame Item Count to see how much the slicer is actually chewing per frame and adjust the budget or mode accordingly.

```
On Debug Overlay Refresh
  -> HUD: set label to "per frame: " + Spawner | Time Slicer: Last Frame Item Count
  -> HUD: set label 2 to "remaining: " + Spawner | Time Slicer: Items Remaining
```

If the per-frame count is far higher than you want, drop `frame_budget_ms` or switch to count mode; if it is crawling, raise the budget.

### Other use cases

**Strategy end-turn resolution.** Pressing End Turn enqueues every unit's AI decision and resolves a budgeted slice per frame, so a 200-unit turn plays out under a spinner instead of freezing the screen.

**Spreading fire or growth.** Each burning or growing tile processes as an item and enqueues its neighbors, so wildfire, vines, or corruption creep across the map at a smooth, controllable rate.

**Hitch-free autosave capture.** Before writing a save, enqueue every entity and collect one state snapshot per On Process Item, then write the file On Drained, so the autosave moment stops being the stutter moment.

**Domino and cascade pacing.** In count mode with a small cap, queued dominoes, chain reactions, or match-cascade pops resolve at a deliberate, readable rhythm instead of all at once.

**Stadium crowd wave.** Enqueue the seating sections in order and drip them through the queue so the crowd stands and sits in a rolling wave, one cheap trigger per section.

---

## Tips and common mistakes

- **The node is the queue - there is no queue id.** Every Action, Condition, Expression, and Trigger acts on the `TimeSlicerBehavior` of the node it is placed on. Put the slicer on the object that owns the work (or use one autoload for a shared global queue) and address it directly.
- **Do the heavy work in On Process Item, not in a loop.** The whole point is that you never write the `for` loop yourself. Move the loop body into On Process Item and enqueue the list - the slicer becomes the loop and paces it for you.
- **Enqueue lightweight items, not finished results.** An item is just a token the slicer hands back to you (an index, a node, a position, a dictionary). Build the expensive thing inside On Process Item; do not do the heavy work up front and then enqueue the result, or you have spread nothing.
- **Pick the mode on purpose.** `both` is the safe default (never overruns time, never stampedes). Use `ms` when you want fastest completion within the frame. Use `count` when you want an exact, predictable number of items per frame. The wrong mode is the usual reason a spread "feels off".
- **A tiny budget can stretch a batch across many frames.** At `frame_budget_ms` = 4 a 5000-item queue can take many frames to finish - that is the trade you asked for. If a batch feels too slow, raise `frame_budget_ms`, raise `max_items_per_frame`, or switch to `ms` mode; do not assume the slicer is stuck.
- **On Drained fires once per empty, not once per batch.** It triggers the frame the queue reaches zero items. If you enqueue more before the current batch finishes, it drains as one continuous run and fires On Drained a single time at the end. Enqueue after a drain if you want a fresh On Drained per batch.
- **Pause keeps the queue; Clear Queue throws it away.** Reach for Pause when the work should continue later (a cutscene, a menu), and Clear Queue only when the pending items are genuinely no longer wanted. Mixing them up either loses work you needed or keeps work you did not.
- **Guard re-enqueues with Is Busy.** Firing the same "start batch" trigger twice stacks duplicate items onto the queue. Gate the enqueue behind a `NOT Is Busy` condition so a batch cannot be started while the previous one is still draining.
- **Items Remaining is your progress bar - use it.** You do not need a separate counter to show load progress; read Items Remaining against the total you enqueued. It is always exactly in sync with the queue.
- **Set Frame Budget only changes the ms fence.** It adjusts `frame_budget_ms` at runtime; it does not touch `max_items_per_frame` or the mode. In `count` mode, Set Frame Budget has no visible effect because the time fence is ignored - change the mode or the item cap instead.
