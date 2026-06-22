# Frame-Spreading & Time-Budgeting — design spec

**Status: ALL FIVE SOLUTIONS BUILT & SHIPPED.** This was the agreed design for making "time slicing" /
"frame spreading" and time-budgeting easy in event-sheet code — for beginners *and* advanced Godot users
focused on performance — and it is now fully implemented. Solution 1 (Time Slicer pack), 3 (budget /
coroutine ACEs), 4 (Run In Background pack), and 5 (Project Doctor unbounded-loop advisory) ship as
described; Solution 2 (Budgeted For Each) compiles in-place from a pick filter's `frame_spread_count` /
`frame_spread_budget_ms`. The user-facing how-to lives in `PERFORMANCE.md` and `RECIPES.md` (Recipe 11),
and there's a runnable demo at `demo/showcase/swarm.tscn`. This file is kept as the design rationale and
the record of locked decisions.

## The problem (and the C3 → Godot framing)

In Construct 3, a **For Each** runs the whole list in a single tick, and there's no native
per-frame budget — you'd hack one with a manual counter. That's fine until the list is big or the
per-item work is heavy (thousands of entities, pathfinding, procedural generation, bulk spawning):
the frame that does it all **hitches**. The Godot-idiomatic answers are to *spread* the work across
frames, *yield* with `await`, or push pure computation *off-thread* with `WorkerThreadPool`. These
five solutions map the C3 habit onto those idioms, from "drop a behavior in" to "raw coroutine".

## The one shared primitive — a per-frame millisecond budget

Every runtime solution below speaks the same budget language: a wall-clock fence measured with
`Time.get_ticks_usec()` (microsecond-precise), checked *after each unit of work*:

```gdscript
var __budget_end := Time.get_ticks_usec() + int(frame_budget_ms * 1000.0)
# ... do one item ...
if Time.get_ticks_usec() >= __budget_end:
    break   # (or: await / return) — resume next frame
```

This is distinct from the existing `Every X Seconds` delta-accumulator: that spaces work *across*
frames; this caps work *within* a frame. Standardizing on this one fence means "frame budget (ms)"
means exactly the same thing in the Time Slicer pack, the Budgeted For Each, and the budget ACEs.

---

## Solution 1 — Time Slicer / Frame Budget pack (beginner) · effort S · ✅ feasible as-described

A drop-in behavior pack (a new addon, `tools/pack_builders/time_slicer.gd` →
`eventsheet_addons/time_slicer/`) that owns a work queue and drains it within a per-frame budget.
The beginner never sees a loop or an `await`: they **Enqueue** in one event and react to **On Process
Item(item)** in another — exactly like reacting to On Body Entered.

- **Inspector knobs:** Frame Budget (ms), Max Items Per Frame (count cap), Mode (ms / count / both).
- **Actions:** Enqueue Item(item), Enqueue Items(array), Clear Queue, Set Frame Budget(ms), Pause/Resume.
- **Triggers:** On Process Item(item) — once per item inside the budget; On Drained — the frame the queue empties.
- **Condition:** Is Busy. **Expressions:** Queue Length, Items Remaining, Last Frame Item Count.

**Compiles to** (`behavior_mode`, `host_class = Node`) an OnProcess tick whose RawCodeRow is the
canonical budget loop:

```gdscript
func _process(_delta: float) -> void:
    if _paused or _queue.is_empty():
        return
    var __budget_end := Time.get_ticks_usec() + int(frame_budget_ms * 1000.0)
    var __n := 0
    while not _queue.is_empty():
        process_item.emit(_queue.pop_front())
        __n += 1
        if mode != MODE_COUNT and Time.get_ticks_usec() >= __budget_end: break
        if mode != MODE_MS and __n >= max_items_per_frame: break
    _last_count = __n
    if _queue.is_empty():
        drained.emit()
```

Signals are authored as annotated RawCode (`## @ace_trigger` / `signal process_item(item: Variant)`),
exactly like `spring_reached` / juice's signals; actions are `Lib.append_function` one-liners. Works
as a component (many slicers) or registered as an autoload (one global slicer).

- **Pros:** zero new compiler infrastructure — pure pack from proven patterns (juice/weapon_kit tick +
  save_system signal-with-param). C3-native enqueue-react model, no await/threading. Inspector knobs.
- **Cons:** reactive, not in-place — you restructure heavy work into enqueue + a handler. Per-item
  signal emit has small overhead (fine for thousands, not millions of trivial ops). Items must be
  self-describing data.

---

## Solution 2 — Budgeted For Each (both) · effort M · ✅ feasible (with documented semantics)

The in-place answer: your normal **For Each**, with a **"Spread across frames"** checkbox plus a
Per-Frame Count and/or Per-Frame Budget (ms). It processes a slice each frame, **resumes where it
left off**, and restarts when the pass completes. Beginners tick a box on a loop they already
understand; advanced users get a deterministic cursor-based slice with no coroutine semantics.

**Compiles to** an extension of `PickFilter` (add `frame_spread_count: int = 0` and
`frame_spread_budget_ms: float = 0.0`, mirroring the `pick_first_n = 0 = unbounded` convention). When
either is non-zero, `_emit_pick_filters` (sheet_compiler.gd ~1032–1080) emits two per-loop **class
members** (via the existing stateful-member pass) — a resume cursor and a cached snapshot — and the
budgeted while-loop:

```gdscript
# class members, one pair per budgeted loop uid:
var __loop_cursor_<uid>: int = 0
var __loop_items_<uid>: Array = []

# at loop entry (under the per-frame trigger):
if __loop_cursor_<uid> == 0:
    __loop_items_<uid> = Array(<collection>)          # snapshot once per pass (order-by sorts here)
var __loop_end_<uid> := Time.get_ticks_usec() + int(frame_spread_budget_ms * 1000.0)
var __done_<uid> := 0
while __loop_cursor_<uid> < __loop_items_<uid>.size():
    var <iterator> = __loop_items_<uid>[__loop_cursor_<uid>]
    __loop_cursor_<uid> += 1
    if <iterator> is Object and not is_instance_valid(<iterator>): continue   # freed mid-pass
    # ... existing predicate / continue / filter / body / sub-events emit UNCHANGED ...
    __done_<uid> += 1
    if frame_spread_count and __done_<uid> >= frame_spread_count: break
    if frame_spread_budget_ms and Time.get_ticks_usec() >= __loop_end_<uid>: break
if __loop_cursor_<uid> >= __loop_items_<uid>.size():
    __loop_cursor_<uid> = 0                            # pass complete → restart next entry
```

The body stays **fully synchronous** — no `await` injection, so the "handlers are synchronous `void`"
invariant is preserved.

- **Pros:** most in-place / least-disruptive — a heavy For Each becomes smooth by ticking one box, no
  restructuring; fully visual, nested logic compiles unchanged; deterministic + debuggable. Pairs with
  the Doctor advisory (Solution 5) as its one-click fix.
- **Cons:** real work in the hottest, most-tested file (PickFilter codegen) + a resource-schema add +
  editor UI for two knobs. Snapshot caching is subtle (see Decision below). Only meaningful under
  per-frame triggers (warn otherwise, mirroring the `Every X Seconds` context guard); forbid/warn on
  nested budgeted loops.

---

## Solution 3 — Budget ACEs (advanced) · effort S · ⚠️ feasible, re-entrancy footgun

Three tiny ACTION ACEs (in `collection_aces.gd` next to Wait/AwaitSignal) advanced users drop into
any loop body to hand-roll spreading:

- **Await Next Frame** → `await get_tree().process_frame` (single awaited line).
- **Begin Frame Budget(ms)** → `var __ace_budget_end := Time.get_ticks_usec() + int(<ms> * 1000.0)`.
- **Await If Over Budget** → multi-line, `await` on the *last* line so the existing await-last-line
  rule (sheet_compiler.gd ~966–974) keeps it parse-valid and re-arms the fence before yielding:

```gdscript
if Time.get_ticks_usec() >= __ace_budget_end:
    __ace_budget_end = Time.get_ticks_usec() + int(<ms> * 1000.0)
    await get_tree().process_frame
```

- **Pros:** tiny build, maximal flexibility; reuses the proven await-last-line emission (no compiler
  change); teaches the idiomatic `await get_tree().process_frame`.
- **⚠️ Footgun (the vetter flagged this hardest):** handlers are emitted as `func _h(...) -> void:`
  but **silently become implicit coroutines** when they contain `await` — the signature stays `void`,
  not async. An **On Process** handler that awaits will have *overlapping invocations* (the prior one
  is still suspended when the next tick fires) → duplicated work / heisenbugs. Also `__ace_budget_end`
  is function-scoped, so Begin Frame Budget and Await If Over Budget must be in the **same** handler,
  in order. **Both unenforceable at compile time.** → Gate behind ADVANCED; document for one-shot
  triggers (On Ready, On Signal, a custom function) + a "run once" guard variable, **never** inside a
  re-firing On Process. Pair with a Doctor warning for "await in On Process".

---

## Solution 4 — Run In Background → On Done (advanced) · effort M · ⚠️ feasible, scene-tree footgun

A behavior/autoload pack for genuinely heavy **pure** computation (procgen, pathfinding bake, image
/ data crunching) that would hitch even when spread across frames — the literal "too heavy for one
thread" lane. **DECISION: include it**, advanced-gated, with strong docs + a worked example,
sequenced last of the runtime features.

- **Action:** Run In Background(callable, payload) → hands a pure function + data to
  `WorkerThreadPool`. Optional Run Batch In Background(items, callable) fans an array across threads.
- **Trigger:** On Done(result) — fires on the **main thread**. **Condition:** Is Running. **Expression:** Result.

**Compiles to** (same shape as the Time Slicer — internal `_tasks: Array`, an OnProcess poll):

```gdscript
# Run In Background:
var __tid := WorkerThreadPool.add_task(func() -> Variant: return callable.call(payload))
_tasks.append(__tid)

# OnProcess poll (reverse iterate):
for __i in range(_tasks.size() - 1, -1, -1):
    var __t = _tasks[__i]
    if WorkerThreadPool.is_task_completed(__t):
        var __r = WorkerThreadPool.wait_for_task_completion(__t)   # immediate: already complete
        _tasks.remove_at(__i)
        done.emit(__r)                                             # main thread → safe to touch nodes
```

- **Pros:** the only solution for work too heavy for one thread — real CPU parallelism via the
  engine's own pool (no raw Thread/Mutex). Main thread only polls, so it never hitches; On Done is a
  clean reactive trigger.
- **⚠️ Footgun:** the worker callable **must be pure** — no scene-tree access, no Node methods, no
  non-thread-safe Resource touches, no captured Godot objects. A callable that touches a Node crashes
  or produces heisenbugs off-thread. **Unenforceable at compile time** (GDScript can't). → BOLD
  warning in the action description/tooltip; a "Pure Functions Only" section + worked example in
  `docs/PERFORMANCE.md`; On Done (main thread) is where you apply the result to the scene. Optional
  later: a debug-build regex scan / Doctor check for node access in the callable.

---

## Solution 5 — Project Doctor "unbounded For Each in On Process" advisory · effort S · ✅ feasible

A steering nudge (not a runtime feature): a new **info-tier** `check_unbounded_loops` in
`project_doctor.gd` that flags a sheet with a For Each / PickFilter where `pick_first_n == 0` AND no
frame-spread budget, nested under a per-frame trigger, with ≥ N actions in the body, and points at
Solution 1/2 as the fix. Threshold via `ProjectSettings` `eventsheets/doctor/loop_cost_threshold`
(default 3). **Must ship after Solution 2** (so it doesn't flag already-budgeted loops and its
one-click fix has a target). Flags the *pattern*, never estimates cost (action count is a weak proxy
— avoid alert fatigue). Matches the existing nudges-not-walls Doctor surface.

---

## Decisions (locked)

1. **Budgeted For Each resume semantics → snapshot + validity guard.** Capture the collection once at
   pass start, cache it as a member, skip freed nodes with `is_instance_valid()`. Gives deterministic
   "each item covered once per pass"; members added mid-pass are picked up on the **next** pass. (This
   matches how order-by already snapshots.) *Documented caveat:* if a node is freed and a new node is
   allocated at the same address before the loop resumes, the guard can false-pass — acceptable, rare.
2. **Off-thread pack (Solution 4) → include it**, advanced-gated, with strong docs + a worked
   pure-callable example; trust the documented contract (nudges-not-walls). Sequenced last; a
   debug-build access guard is a fine later follow-up, not a blocker.

## Recommended build order

| Order | Solution | Tier | Effort | Why here |
|------:|----------|------|:------:|----------|
| 1 | Time Slicer pack | beginner | S | Zero compiler risk; establishes the canonical budget loop in one reviewable pack |
| 2 | Budgeted For Each | both | M | The in-place answer; reuses the pack's exact budget fence; touches hot PickFilter codegen so it comes after #1 proves the shape |
| 3 | Budget ACEs | advanced | S | Power-tool escape hatch; ship after #2 so the simpler path is obvious; advanced-gated + Doctor warning |
| 4 | Run In Background | advanced | M | The off-thread lane; needs the most docs/examples, so last of the runtime tier |
| 5 | Doctor advisory | both | S | Makes the set discoverable; needs #2's fields to exist so it doesn't flag budgeted loops |

Solutions 1–2 cover ~90% of real hitching (the beginner queue + the one-checkbox loop); 3–4 are
surgical power tools for the long tail; 5 makes them findable without being a wall.

## Cross-cutting deliverables

- `docs/PERFORMANCE.md` — Editor / Runtime / Game perf; polling vs reacting; loop costs; the four
  frame-spreading tools ranked by use case; the two footguns; escape hatches.
- `docs/RECIPES.md` — "Recipe 10: Heavy loops & frame-spreading" with worked examples.
- Tests per solution: pack build + `drift=0` (1, 4); `pick_filter_test`-style codegen + a frame-spread
  integration test (2); compile-shape tests (3); a "does not touch scene tree" guard test (4);
  Doctor-finding test (5).

## Key risks (from the feasibility pass)

1. **Coroutine re-entrancy (#3):** await-in-On-Process overlaps invocations — advanced-gate + Doctor nudge.
2. **WorkerThreadPool purity (#4):** impure callables crash off-thread — docs + worked example (+ optional debug guard).
3. **Snapshot staleness (#2):** handled by `is_instance_valid()`; document the address-reuse edge case.
4. **Budget precision:** `int(ms * 1000.0)` rounding — document.
5. **Signal-connection timing (#1, #4):** the OnProcess tick connects in `_ready`; emissions before `_ready` are missed — note in pack docs.
6. **Doctor threshold tuning (#5):** action-count is a weak proxy; good default (3) + a "how to adjust" tip.
