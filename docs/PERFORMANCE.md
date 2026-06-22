# Performance — frame-spreading & time-budgeting

Heavy work done all in one frame **hitches** the game: spawning hundreds of objects, updating thousands
of entities, pathfinding for a crowd. In Construct 3 a `For Each` runs the whole list in one tick; the
Godot-idiomatic fix is to *spread* the work across frames within a per-frame **budget**. This page covers
the tools that ship today. The full design (including the in-place Budgeted For Each and the off-thread
WorkerThreadPool lane) is in [FRAME-SPREADING-SPEC.md](FRAME-SPREADING-SPEC.md).

Every tool speaks the same budget language: a wall-clock millisecond fence,
`Time.get_ticks_usec() + int(ms * 1000.0)`, checked as work proceeds.

## The easy path — the Time Slicer pack (beginner, no caveats)

Attach the **Time Slicer** behavior as a child (or register it as an autoload for one global slicer). It
owns a work queue and drains it within a per-frame budget — **time (ms)**, **count**, or both. You never
write a loop or an `await`:

1. **Enqueue** the work in one event — `Enqueue Item`, `Enqueue Items` (an array), or `Enqueue Group`
   (every node in a group).
2. **React** to **On Process Item(item)** in another event and do the per-item work — exactly like
   reacting to a signal. The slicer hands you items only as fast as the budget allows.
3. **On Drained** fires the frame the queue empties.

Tune `frame_budget_ms` / `max_items_per_frame` / `mode` in the Inspector; `Set Frame Budget` changes it
at runtime; `Pause`/`Resume` and `Is Busy` / `Items Remaining` round it out. A 50,000-item queue
self-spreads across as many frames as the budget needs, with no hitch. This is the right tool for ~90% of
frame-spreading needs.

## The power tools — budget ACEs (ADVANCED)

For hand-rolling a spread loop with raw coroutine control, three actions live under the **Performance**
category:

- **Await Next Frame** — `await get_tree().process_frame`; the rest of the event resumes next frame.
- **Begin Frame Budget (ms)** — arms a per-frame budget for the loop that follows.
- **Await If Over Budget (ms)** — drop it at the bottom of a `For Each` body; when the budget is spent it
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
> (On Ready, On Signal, a custom function) — ideally with a "run once" guard variable. **Never** inside a
> re-firing **On Process**: the next tick fires while the previous run is still suspended, so the loop
> overlaps itself and double-processes. `Begin Frame Budget` and `Await If Over Budget` must be in the
> **same** handler (the budget fence is function-local). If you're not sure, use the Time Slicer pack.

## Rules of thumb

- **Spread when one frame's worth of the work would be felt** — a visible stutter, not a few items.
- **Budget in milliseconds, not item counts,** when per-item cost varies (a raycast vs a `Set Variable`):
  the ms fence adapts; a fixed count doesn't.
- **Reacting beats polling.** Prefer signals/triggers over per-frame `for` scans; see the
  [migration guide](C3-MIGRATION-GUIDE.md#polling-vs-reacting--the-biggest-shift-from-c3).
