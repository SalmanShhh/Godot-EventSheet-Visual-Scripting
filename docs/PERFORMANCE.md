# Performance - frame-spreading & time-budgeting

Heavy work done all in one frame **hitches** the game: spawning hundreds of objects, updating thousands
of entities, pathfinding for a crowd. In Construct 3 a `For Each` runs the whole list in one tick; the
Godot-idiomatic fix is to *spread* the work across frames within a per-frame **budget**. This page covers
the tools that ship today.

Every tool speaks the same budget language: a wall-clock millisecond fence,
`Time.get_ticks_usec() + int(ms * 1000.0)`, checked as work proceeds.

## The easy path - the Time Slicer pack (beginner, no caveats)

Attach the **Time Slicer** behavior as a child (or register it as an autoload for one global slicer). It
owns a work queue and drains it within a per-frame budget - **time (ms)**, **count**, or both. You never
write a loop or an `await`:

1. **Enqueue** the work in one event - `Enqueue Item`, `Enqueue Items` (an array), or `Enqueue Group`
   (every node in a group).
2. **React** to **On Process Item(item)** in another event and do the per-item work - exactly like
   reacting to a signal. The slicer hands you items only as fast as the budget allows.
3. **On Drained** fires the frame the queue empties.

Tune `frame_budget_ms` / `max_items_per_frame` / `mode` in the Inspector; `Set Frame Budget` changes it
at runtime; `Pause`/`Resume` and `Is Busy` / `Items Remaining` round it out. A 50,000-item queue
self-spreads across as many frames as the budget needs, with no hitch. This is the right tool for ~90% of
frame-spreading needs.

## The in-place tick-box - Budgeted For Each

Already have a `For Each` loop and just want it to stop hitching? Give the loop a frame-spread budget -
a per-frame **count** (`frame_spread_count`) and/or a **ms budget** (`frame_spread_budget_ms`) on the pick
filter - and it processes a slice per frame and resumes on the next. No behavior to attach, no `await`, no
restructuring. It snapshots the collection once per pass (a persistent cursor survives across frames),
skips items freed mid-pass (`is_instance_valid`), and starts a fresh pass when it reaches the end.

```gdscript
# A For Each over "enemies" with frame_spread_count = 50 compiles to roughly:
if __loop_cursor_<id> >= __loop_items_<id>.size():
    __loop_cursor_<id> = 0                 # finished a pass - start over next frame
if __loop_cursor_<id> == 0:
    __loop_items_<id> = Array(get_tree().get_nodes_in_group("enemies"))   # snapshot once per pass
var __done_<id> := 0
while __loop_cursor_<id> < __loop_items_<id>.size():
    if 50 > 0 and __done_<id> >= 50:       # this frame's slice is done
        break
    var enemy = __loop_items_<id>[__loop_cursor_<id>]
    __loop_cursor_<id> += 1
    __done_<id> += 1
    if enemy is Object and not is_instance_valid(enemy):
        continue                            # snapshot entry was freed since last frame
    # ... your loop body ...
```

> [!NOTE]
> Drive a Budgeted For Each from a **per-frame** trigger (On Process) - that's what re-enters the loop each
> frame to continue the pass; under a one-shot trigger it would only ever process the first slice. It isn't
> yet combined with While/Repeat, order-by, or pick-first-N (those emit a normal same-frame loop and a
> compile warning). The Project Doctor's unbounded-loop nudge goes quiet once a loop is budgeted this way.

## The power tools - budget ACEs (ADVANCED)

For hand-rolling a spread loop with raw coroutine control, three actions live under the **Performance**
category:

- **Await Next Frame** - `await get_tree().process_frame`; the rest of the event resumes next frame.
- **Begin Frame Budget (ms)** - arms a per-frame budget for the loop that follows.
- **Await If Over Budget (ms)** - drop it at the bottom of a `For Each` body; when the budget is spent it
  yields to the next frame and re-arms. The loop self-paces to the budget.

```gdscript
# On a one-shot trigger (On Ready / On Signal / a custom function):
begin_frame_budget(8.0)          # 8 ms/frame
for enemy in get_tree().get_nodes_in_group("enemies"):
    _expensive_update(enemy)
    await_if_over_budget(8.0)     # yields + re-arms when the frame budget is spent
```

> [!WARNING]
> **These make the handler an implicit coroutine.** Use them ONLY inside a **one-shot** trigger
> (On Ready, On Signal, a custom function) - ideally with a "run once" guard variable. **Never** inside a
> re-firing **On Process**: the next tick fires while the previous run is still suspended, so the loop
> overlaps itself and double-processes. `Begin Frame Budget` and `Await If Over Budget` must be in the
> **same** handler (the budget fence is function-local). If you're not sure, use the Time Slicer pack.

## Too heavy even to spread - Run In Background (ADVANCED)

When the work is genuinely CPU-bound (procedural generation, a pathfinding bake, image/data crunching),
spreading it across frames still blocks the main thread each frame. The **Run In Background** pack hands
the work to the engine's `WorkerThreadPool` - the main thread only polls, so it never hitches, and
**On Done(result)** fires on the main thread when the work finishes (safe to apply the result to the scene
there). *Run Batch In Background* fans an array across worker threads.

> [!WARNING]
> **The work callable must be PURE.** No scene-tree access, no Node methods, no non-thread-safe Resource
> touches - data in, data out only. Touching a node off-thread crashes or produces heisenbugs, and nothing
> enforces this at compile time. Compute off-thread, then apply the result in the On Done handler (which
> runs on the main thread). To mutate the scene *incrementally*, use the Time Slicer instead.

```gdscript
# On Ready (or any trigger): kick off a pure computation
run_in_background(_bake_navmesh.bind(grid))   # _bake_navmesh returns data; touches no nodes

# On Done(result): apply it on the main thread
$NavRegion.navigation_polygon = result
```

## Rules of thumb

- **Spread when one frame's worth of the work would be felt** - a visible stutter, not a few items.
- **Budget in milliseconds, not item counts,** when per-item cost varies (a raycast vs a `Set Variable`):
  the ms fence adapts; a fixed count doesn't.
- **Reacting beats polling.** Prefer signals/triggers over per-frame `for` scans: a signal fires only when
  the event happens, so the work - and its frame cost - only occurs when it has to, instead of every tick.
