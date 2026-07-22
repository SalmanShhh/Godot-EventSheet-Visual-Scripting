# Recipes - Build Something, End to End

Short, concrete walkthroughs that each build one real thing - a platformer character, a health system, an auto-attacking shooter with game feel - and show the exact GDScript it compiles to. Each recipe assumes the plugin is enabled and you've opened the **EventSheet** tab. New to the vocabulary? Keep the [glossary](REFERENCE-GLOSSARY.md) open. Coming from Construct 3? The [migration guide](GUIDE-C3-MIGRATION.md) maps every concept.

![A platformer character sheet in the editor: two-lane condition/action rows, a colored Combat region, an inline GDScript block, exported variables with @export badges, and a sheet-built heal() function](previews/editor-event-sheet.png)

## Table of Contents

1. [Scenarios Where These Recipes Help](#1-scenarios-where-these-recipes-help)
2. [The Golden Loop](#2-the-golden-loop)
3. [Hello, Jump - A Platformer Character in Minutes](#3-hello-jump---a-platformer-character-in-minutes)
4. [Health and Damage](#4-health-and-damage)
5. [A Pickup Counter](#5-a-pickup-counter)
6. [Debugging 101](#6-debugging-101)
7. [Author Your Own Behavior and ACEs](#7-author-your-own-behavior-and-aces)
8. [Helper ACEs That Save a Code Drop](#8-helper-aces-that-save-a-code-drop)
9. [Coordinating Many Nodes - With Node, Groups and Aggregates](#9-coordinating-many-nodes---with-node-groups-and-aggregates)
10. [Building the Godot Way - A Steering Tour](#10-building-the-godot-way---a-steering-tour)
11. [Auto-Attack with Game Feel - Picking, Line of Sight and the Juice Pack](#11-auto-attack-with-game-feel---picking-line-of-sight-and-the-juice-pack)
12. [Crowds Without the Hitch - Frame-Spreading](#12-crowds-without-the-hitch---frame-spreading)
13. [The Game-Feel Toolkit - Hit-Stop, Screenshake, Squash and Punch-Zoom](#13-the-game-feel-toolkit---hit-stop-screenshake-squash-and-punch-zoom)
14. [Designer Knobs - First-Class Variables and Inspector Drawers](#14-designer-knobs---first-class-variables-and-inspector-drawers)
15. [Reuse and Scale - Extract-to-Function and Families](#15-reuse-and-scale---extract-to-function-and-families)
16. [Tips and Common Mistakes](#16-tips-and-common-mistakes)

---

## 1. Scenarios Where These Recipes Help

- **Your first sheet, a blank editor.** [Hello, Jump](#3-hello-jump---a-platformer-character-in-minutes) gets a playable platformer character moving in minutes, pack or from scratch.
- **The classic game-loop pieces.** Health and damage, pickups and a score HUD - recipes [4](#4-health-and-damage) and [5](#5-a-pickup-counter) cover the staples every game needs.
- **Something misbehaves and you're about to add `print()`.** [Debugging 101](#6-debugging-101) shows the built-in lint, breakpoints, Live Values + Watch, and Event Trace instead.
- **You keep re-typing the same rows.** [Extract-to-Function and Families](#15-reuse-and-scale---extract-to-function-and-families) turn repetition into named, reusable abstractions; [recipe 7](#7-author-your-own-behavior-and-aces) turns your logic into a shareable pack.
- **Hits don't *land*.** The [game-feel toolkit](#13-the-game-feel-toolkit---hit-stop-screenshake-squash-and-punch-zoom) layers hit-stop, trauma screenshake, squash & stretch, and punch-zoom, all fire-and-forget.
- **The game stutters under crowds.** [Frame-spreading](#12-crowds-without-the-hitch---frame-spreading) spreads heavy work across frames with a budget - three tools, easiest first.
- **You want to build the Godot way, not the polling way.** The [steering tour](#10-building-the-godot-way---a-steering-tour) walks every nudge: signals over polling, autoloads, behavior components.
- **A twin-stick horde shooter, and you want it to feel great.** The [auto-attack recipe](#11-auto-attack-with-game-feel---picking-line-of-sight-and-the-juice-pack) picks the nearest *visible* enemy with no per-frame scan, then layers the [game-feel toolkit](#13-the-game-feel-toolkit---hit-stop-screenshake-squash-and-punch-zoom) so each kill kicks, slows, and squashes.
- **A boss fight that reacts to its minions.** [Coordinating many nodes](#9-coordinating-many-nodes---with-node-groups-and-aggregates) reads a group's average HP and broadcasts a retreat with two loop-free group queries - the boss enrages off a signal, not a tick.
- **A jam build hitting a wave-spawner wall on the last night.** [Frame-spreading](#12-crowds-without-the-hitch---frame-spreading) drops an 800-enemy AI recompute into a Time Slicer queue with one Inspector tick, so the crunch-hour horde stops stuttering without a rewrite.
- **Your designer wants to tune values without touching the sheet.** [Designer knobs](#14-designer-knobs---first-class-variables-and-inspector-drawers) turns a variable into an @export with a live drawer - a direction dial for a Vector2, a swatch for a Color - so balancing happens in the Inspector at Play time.
- **You built one great mechanic and want the whole team to reuse it.** [Author your own behavior and ACEs](#7-author-your-own-behavior-and-aces) exports your dash or shield logic as a published pack that drops into any teammate's project as picker rows, with `@ace_expose_all` surfacing a script's whole API at once.
- **One rule that should run across every enemy in the scene.** [Families](#15-reuse-and-scale---extract-to-function-and-families) set the Sheet Type to Family so a single sheet iterates the whole group, instead of copy-pasting the same on-death flash onto forty separate enemy sheets.

---

## 2. The Golden Loop

Every recipe below rides the same loop: **New sheet (a `.gd`) → set the host class → add events (pick
Conditions + Actions) → save → set the `.gd` as your node's script → Run.** A sheet *is* just
GDScript now (no `.tres` needed) - so "Open in Godot" edits the same file in the script editor, and
any `.gd` auto-previews as an event sheet.

---

## 3. Hello, Jump - A Platformer Character in Minutes

The fast path is the bundled **Platformer** behavior pack (coyote time, jump buffering, variable
jump height, wall jump - all the juice).

1. Make a `CharacterBody2D` scene with a sprite + a collision shape.
2. New sheet → **Sheet Type** → host class `CharacterBody2D`.
3. Attach the **Platformer** pack as a child node (open the pack sheet and use Tools ▸ Attach to Selected Node, or drop the pack node in);
   set its speed/jump in the Inspector.
4. One event: trigger **On Process** → action **Move And Slide**. The pack reads input and drives
   `velocity`; Move And Slide applies it.
5. **Save** - the sheet *is* the `.gd`; set it as the node's script and press Play.

Want it from scratch instead of the pack? Three events: *On Process* → set horizontal velocity
from input; *Is on floor* + *jump pressed* → set `velocity.y`; *On Process* → Move And Slide.

---

## 4. Health and Damage

Use the **Health** pack for HP, damage absorption, decaying shield **pools**, and
On Damaged / On Death triggers - or roll your own with a variable.

**With the pack:** attach **Health**, set max HP in the Inspector. On a hit, call its *Take
Damage* action. Add an event: trigger **On Death** → action *Queue Free* (or play an animation).

**From scratch:** add a global **Variable** `health : int = 100`. On a hit event → *Subtract from
variable* `health`, amount `10`. Add an event: condition `health <= 0` → action *Queue Free*.

---

## 5. A Pickup Counter

1. Global **Variable** `score : int = 0`.
2. Give coins an `Area2D` in the `"coins"` group.
3. Event: trigger **On Area Entered** (or condition **Overlaps Body**) → actions: *Add to
   variable* `score` by `1`, then *Queue Free* the coin.
4. Show it: a `Label` + an event *On Process* → **Set Property** `text` = `"Score: %d" % score`.

---

## 6. Debugging 101

When something misbehaves, you have four tools - no `print()` required.

- **Check the sheet first.** Tools ▸ **Check Sheet for Errors** lints every ƒx expression and
  GDScript block; a bad one gets a **red marker on its row** and the editor jumps to it (hover the
  row for the reason + a "did you mean …?"). This also runs automatically on save.
- **Breakpoints.** Click the gutter (or F9) to pause the Godot debugger on a row in a debug run.
  Need it to stop only sometimes? **More ▸ Set Breakpoint Condition…** (e.g. `health <= 0`) - it
  pauses only on the frame that matters.
- **Live Values + Watch.** Tools ▸ Live Values streams the sheet's variables while it runs (and
  you can *edit* them live to test branches). The **Watch** box in that window evaluates any
  expression over those variables each frame - e.g. `health <= 0` or `score + lives` - so you can
  see a condition flip in real time without adding a label.
- **Event Trace.** Tools ▸ Event Trace highlights the rows whose events *fire* during a debug run
  (a cyan PULSE: full glow the instant an event fires, fading over half a second, held bright while it keeps firing) - so "is this event even running?" AND "what just fired?" are answered at a glance. It
  rides the Live Values stream, so turn that on too.

---

## 7. Author Your Own Behavior and ACEs

No JSON, no boilerplate. Every bundled behaviour pack is a single `.gd` file that compiles with
**zero GDScript blocks** - you can author yours the same way. Start from **Sheet ▸ New Behaviour
Addon…** (it scaffolds a ready-to-edit provider), and **`@ace_expose_all`** exposes a whole script's
public API as ACEs at once. Full walkthrough: [GUIDE-MAKE-A-BEHAVIOUR-WITHOUT-CODE.md](GUIDE-MAKE-A-BEHAVIOUR-WITHOUT-CODE.md).
Two routes:

- **A behavior pack:** build the logic as an event sheet, then **Export Addon…** publishes it
  through the same pipeline the bundled packs use - the exported `.gd` IS the pack (editable
  sheet and runtime script in one), its verbs live in every picker.
- **Custom ACEs from a script:** drop a `.gd` into `res://eventsheet_addons/`. Its `class_name`
  becomes the provider; methods/exported vars become Actions/Conditions/Expressions; annotated
  signals become Triggers. `@ace_param_options` / `@ace_param_autocomplete` / `@ace_param_hint`
  shape the parameter fields. It registers project-wide automatically.

---

## 8. Helper ACEs That Save a Code Drop

The picker has a row for most things you'd otherwise hand-write. A few that come up constantly:

- **HUD text** - `Set Text (formatted)` writes `"Score: %d  Lives: %d" % [score, lives]` to any
  Label / RichTextLabel in one row (no GDScript block).
- **Hit flashes & fades** - the **Color** category composes: `Lerp Color`, `Lighten` / `Darken`,
  `Color With Alpha`, `Color From HSV`. Feed the result straight into `Set Color Tint` (modulate).
- **Spawning** - `Spawn Scene (Full)` instances a scene and sets position + rotation + an optional
  group tag in one action; `Spawn Scene At` when you only need a position.
- **Timing without a Timer node** - `Call After Delay` / `Tween Callback` fire a method after N
  seconds without suspending the event; `Wait` (await) when you *do* want to suspend it.
- **Scene-tree queries** - `Get Parent`, `Find Child`, `Has Node`, `Get Child Count`, plus node
  **Groups** (Add / Is In / Call Method On Group) - no `get_node(...)` boilerplate.
- **Signals at runtime** - `Connect` / `Disconnect` / `Emit Signal On` / `Signal Is Connected`,
  without a `_ready` block.

Everything compiles to the exact one-liner you'd type by hand, so it stays a searchable, editable
row instead of a raw block.

---

## 9. Coordinating Many Nodes - With Node, Groups and Aggregates

A boss enrages: flash it, then sound the retreat if the wave it commands is nearly dead. One event,
three Godot idioms - react to a **signal**, scope to a **node**, query a **group** with no loop.

**Setup:** enemies are nodes in the `"enemies"` group (each with a `health`); a `Boss` node with an
`enraged` signal; a HUD `Label` at `$HUD/Label`.

1. **React to the signal, don't poll.** Event → trigger **On Signal** `enraged`, source `Boss`. The
   compiler wires the `_ready` connection for you - no per-frame check.
2. **Scope the boss's actions once.** Right-click the event → **Scope Actions To Node… → `$Boss`**. A
   `With node  $Boss` chip appears in the condition lane. Add **Play Animation** `"roar"` and **Set
   Color Tint** red - you set the target *once*, not on every action. (Need one action on a *different*
   node? Give just that action an explicit **On node** - it wins over the scope.)
3. **Show the wave's average HP** (no loop): a HUD event → **Set Text (formatted)** on `$HUD/Label`,
   value `"Avg HP: %d"` with the **Average In Group** expression (`"enemies"`, `health`) as the arg.
4. **Broadcast a retreat** when the weakest is nearly dead: a sub-event → condition **Lowest In Group**
   `"enemies"` `health` `< 10` → action **Call Method On Group** `"enemies"` → `retreat`.

Compiles to plain, readable GDScript - exactly what you'd hand-write:

```gdscript
func _ready() -> void:
    get_node("Boss").enraged.connect(_on_boss_enraged)

func _on_boss_enraged() -> void:
    $Boss.play(&"roar")            # both lines scoped by "With node $Boss"
    $Boss.modulate = Color.RED
    $HUD/Label.text = "Avg HP: %d" % [get_tree().get_nodes_in_group("enemies").reduce(func(__acc, __n): return __acc + __n.health, 0.0) / maxf(float(get_tree().get_nodes_in_group("enemies").size()), 1.0)]
    if get_tree().get_nodes_in_group("enemies").reduce(func(__acc, __n): return min(__acc, __n.health), INF) < 10:
        get_tree().call_group("enemies", "retreat")
```

No god-object reaching out every frame, no manual node lists - a signal handler, a scoped target, and
two group queries, all as editable rows.

---

## 10. Building the Godot Way - A Steering Tour

The plugin actively *nudges* a Construct user toward Godot idioms (signals over polling, small
scenes-as-components, the Inspector, one source of truth) - always as suggestions with the old path one
click away. This tour builds a tiny coin game using each nudge. The biggest shift from C3 is *reacting*
instead of *polling*: rather than checking a condition every tick (a per-frame `for`/overlap scan), you
connect to a signal that fires only when the thing actually happens - fewer wasted checks, and the intent
reads straight off the event row.

**1. A coin is a behavior component, not a god-sheet.** New Sheet → **Behavior Component (signal-driven)**.
You get a `PickupBehavior` you attach as a *child* of each Coin's `Area2D` (the Godot answer to a C3
behavior). It *reacts* to the host's `body_entered` signal - no per-frame overlap check - and *emits*
`collected`; `value` is an exported knob you tune per coin in the Inspector. It compiles to:

```gdscript
extends Node
class_name PickupBehavior

@export var value: int = 1
signal collected(by: Node, amount: int)
var host: Area2D = null

func _ready() -> void:
    host = get_parent() as Area2D
    if host != null:
        host.body_entered.connect(func(body: Node) -> void:
            collected.emit(body, value)
            host.queue_free())
```

**2. The score lives in one place - an autoload.** Don't declare `score` in five sheets. New Sheet →
**Game State (Autoload)**, add `score`, register it (Tools → Register Autoload). If you *do* sprinkle it
around, the **Project Doctor** (Tools → Check Project) flags it: *"Global 'score' is declared in 3
sheets - promote it to an autoload (one source of truth)."*

**3. Internal state vs designer knobs.** When you add a variable, the **"Designer-tweakable in the
Inspector (@export)"** box is *off* by default - so an internal `_combo_count` stays a private `var`,
and you tick the box only for values a designer should tune. Your Inspector stays a clean panel of real
knobs, not an everything-bucket.

**4. React, and reference by name.** On a Game sheet: trigger **On Signal** `collected` (source: a coin)
→ `GameState.score += amount`. Update the HUD without a brittle path: in the scene tree mark the deep
`ScoreLabel` **Access as Unique Name**, then write `%ScoreLabel` - type `%` in a ƒx field and it
autocompletes; typo it and it warns amber. And when you reach for a polling condition like *Overlaps
Body*, the picker tips you toward **On Body Entered** and lands "overlap" + Enter on the reactive
trigger by default.

**5. React to coins *appearing*, don't poll.** Spawning coins at runtime? Instead of checking
`IsInsideTree` every frame, use **On Child Entered Tree** (source: the coins container) to act the
moment a coin is added.

**6. Stay composed.** If a sheet starts reaching into a dozen different nodes, the Doctor's *fan-out*
advisory suggests splitting into per-node behaviors or naming it a coordinator - flagged by **node
count, never row count** (a long, focused state machine on one host is fine).

Every step has an escape hatch: the polling condition, the global, the deep `$path`, the one big sheet
all still compile and work. The plugin just makes the Godot way the *easy default*.

---

## 11. Auto-Attack with Game Feel - Picking, Line of Sight and the Juice Pack

A top-down shooter that auto-fires at the closest enemy it can actually *see*, and makes every hit land:
the screen kicks, the kill drops into slow motion, and the player squashes on recoil. Every piece here
shipped together - the **Nearest** picking expressions, the **Line of Sight** pack's occlusion-correct
target, and the **Juice** behavior (whose camera effects auto-find the active camera, so nothing is wired).

**Setup:** enemies are `Area2D`s in the `"enemies"` group (each with a **Health** behavior); the player
has a **Line of Sight** and a **Juice** behavior attached as children.

1. **Target only what you can see.** On a 0.2s Timer → set a local `target` = **Nearest Visible In Group**
   `"enemies"`. The LoS pack scans the group and range/cone/raycasts each candidate, so a closer enemy
   *behind a wall* is skipped in favour of a visible farther one - exactly what auto-attack AI wants. (No
   LoS behavior? Compose it: **Nearest Node In Group** then a **Has Line Of Sight To** condition on it.)
2. **Fire at it.** Sub-event `if target != null` → spawn a bullet toward `target.global_position`.
3. **Kick the screen on each hit.** On the bullet's **On Body Entered** → **Shake** `0.3`. Trauma *stacks*,
   so a burst of hits builds a bigger shake, then decays on its own.
4. **Slow-mo the kill.** On the enemy Health's **On Death** → **Slowmo** `target_scale 0.15`, `hold 0.12`,
   clock **realtime** - a 120 ms hit-stop that makes the kill land. The fade curves are tuned once in the
   Inspector, not per call.
5. **Squash the player on recoil.** On fire → **Spring Squash** `-0.2` (a quick wide squash that springs
   back bouncily), or **Squash & Stretch** `-0.2, 0.15` for the tween version.
6. **Punch in on the boss.** When the boss spawns → **Zoom To Position** `boss.global_position, 130, 0.4`
   to frame it; pull back with **Zoom By Percent** `100, 0.3` when it dies.

It compiles to plain, readable GDScript - the pick is a one-line `reduce`, the camera is found for you:

```gdscript
func _on_attack_timer_timeout() -> void:
    var target = $LOSBehavior.nearest_visible_in_group("enemies")
    if target != null:
        _fire_at(target.global_position)
        $JuiceBehavior.spring_squash(-0.2)          # recoil

func _on_bullet_body_entered(body: Node) -> void:
    $JuiceBehavior.shake(0.3)                        # screen kick (stacks + decays)
    body.take_damage(10.0)

func _on_enemy_died() -> void:
    $JuiceBehavior.slowmo(0.15, 0.12, "realtime")   # 120 ms hit-stop
```

No per-frame target scan, no camera wiring, no hand-rolled tweens - a loop-free pick, an auto-found
camera, and a handful of fire-and-forget juice calls. Want it bouncier or snappier? Every feel knob
(shake decay, slowmo curves, squash stiffness) lives in the Inspector.

---

## 12. Crowds Without the Hitch - Frame-Spreading

A wave of 800 enemies all recomputing their AI on one frame, a big level streaming in, a navmesh baking -
do it all in a single frame and the game **stutters**. The fix is to spread the work across frames within a
per-frame **budget**. Three tools, easiest first; pick by how heavy the work is. (Not sure a loop needs it?
**Tools ▸ Check Project** flags a heavy For Each running every frame that isn't capped or budgeted.)

**The easy path - the Time Slicer pack (no loop, no `await`).** Attach **Time Slicer** as a child (or make
it an autoload for one global slicer). It owns a queue and drains it within a per-frame budget:

1. **Enqueue** the work in one event - **Enqueue Group** `"enemies"` (every node in a group), **Enqueue
   Items** (an array), or **Enqueue Item** (one).
2. **React** to **On Process Item(item)** in another event and do the per-item work - like reacting to a
   signal. The slicer hands you items only as fast as the budget allows.
3. **On Drained** fires the frame the queue empties.

Tune `frame_budget_ms` / `max_items_per_frame` / `mode` (ms, count, or both) in the Inspector. An 800-item
queue self-spreads across as many frames as the budget needs, no hitch - the right tool for ~90% of cases.

```gdscript
# Enqueue once, then react per item - the slicer paces it to the budget:
func _ready() -> void:
    $TimeSlicer.enqueue_group("enemies")

func _on_time_slicer_process_item(item) -> void:
    item.recalculate_ai()        # runs for only as many enemies as fit this frame's budget
```

**The one-liner - Budgeted For Each.** Already have a **For Each** loop? Don't attach anything - on the
loop's pick filter set **frame_spread_count** (items/frame) and/or **frame_spread_budget_ms** (a wall-clock
fence) in the Inspector. The loop then does a slice each frame and resumes on the next, over a snapshot
taken once per pass, skipping anything freed mid-pass. Drive it from **On Process** (that's what re-enters
the loop each frame to continue the pass):

```gdscript
# A For Each over "enemies" with frame_spread_count = 50 compiles to a self-pacing loop -
# ~50 per frame, resuming next frame (the cursor + snapshot persist as members):
while __loop_cursor < __loop_items.size():
    if __done > 0 and __done >= 50:
        break
    var enemy = __loop_items[__loop_cursor]
    __loop_cursor += 1
    __done += 1
    ...                          # your loop body
```

**Too heavy even to spread - Run In Background.** When the work is pure CPU crunching (procedural
generation, a pathfinding bake), spreading still blocks the main thread each frame. **Run In Background**
hands a **pure** function to a worker thread; **On Done(result)** fires on the main thread when it finishes:

```gdscript
# On Ready: kick off the bake off-thread
run_in_background(_bake_navmesh.bind(grid))   # _bake_navmesh touches NO nodes - data in, data out

# On Done(result): apply it on the main thread (safe to touch the scene here)
$NavRegion.navigation_polygon = result
```

> The background callable must be **pure** - no scene-tree / node access, since it runs off the main
> thread. Compute off-thread, then apply the result in the On Done handler.

**Which one?**

| The work | Reach for |
| --- | --- |
| Touch many nodes, spread over frames | **Time Slicer**, or tick a **Budgeted For Each** |
| An existing For Each that hitches | **Budgeted For Each** (one Inspector tick) |
| Pure number-crunching, no nodes | **Run In Background** |
| A hand-rolled loop, want raw control | **Begin Frame Budget** + **Await If Over Budget** (advanced) |

---

## 13. The Game-Feel Toolkit - Hit-Stop, Screenshake, Squash and Punch-Zoom

*Game feel* is the difference between a hit that registers and one that *lands*. The **Juice** behavior packs
the whole toolkit into fire-and-forget actions: attach it as a child (its camera effects **auto-find the
active camera**, so nothing is wired) and tune every knob - decay, fade curves, spring stiffness - in the
Inspector. Nothing here needs scheduling or cleanup: the shake decays, the slow-mo eases back, the squash
springs home on its own.

**Hit-stop / slow motion.** *Slowmo* `target_scale, hold, clock` drops `Engine.time_scale` to `target_scale`
for `hold` seconds, then eases back (fade curves are Inspector knobs; it emits *On Slowmo Finished*). Set
`clock` to **realtime** so the hold isn't itself slowed - that's true hit-stop:

```gdscript
$JuiceBehavior.slowmo(0.05, 0.08, "realtime")   # an 80 ms freeze on a big hit
```

**Screenshake (trauma-based).** *Shake* `amount` (0-1) adds **trauma**; the shake is trauma-*squared* (small
= subtle, big = violent), **decays on its own**, and **stacks** - a burst of hits builds a bigger shake. Fire
it on every hit and forget it:

```gdscript
$JuiceBehavior.shake(0.4)
```

**Squash & stretch.** Two flavours, both volume-preserving (negative = squash wide for a landing, positive =
stretch tall for a jump): *Squash & Stretch* `amount, duration` is a tween; *Spring Squash* `amount` uses a
real spring (the stiffness/damping knobs) - bouncier and more organic.

```gdscript
$JuiceBehavior.squash_and_stretch(-0.3, 0.2)   # land: a quick wide squash
$JuiceBehavior.spring_squash(0.25)             # jump: a bouncy stretch
```

**Punch-zoom.** *Zoom To Position* `pos, zoom%, duration` glides the camera so a world point becomes screen
centre; *Zoom By Percent* `%, duration` is relative (100 = no change); *Zoom Toward Point* pins a point under
the same screen spot (map-zoom style).

```gdscript
$JuiceBehavior.zoom_to_position(boss.global_position, 130, 0.4)   # frame the boss…
$JuiceBehavior.zoom_by_percent(100, 0.3)                          # …then pull back
```

**Layer them.** A satisfying impact is all of these at once, each one fire-and-forget - the only thing you
tune is *feel*:

```gdscript
func _on_big_hit() -> void:
    $JuiceBehavior.shake(0.5)
    $JuiceBehavior.slowmo(0.05, 0.08, "realtime")
    $JuiceBehavior.spring_squash(0.3)
```

---

## 14. Designer Knobs - First-Class Variables and Inspector Drawers

Turn a variable into a tunable knob your designers see in the Inspector, with a **live widget** for
its type - no custom editor code.

1. Add a **Variable** (e.g. `aim_dir : Vector2`). In the dialog, tick **"Editable in the Inspector"**
   (`@export`) - an **@export badge** appears on the row.
2. Pick a **"Show as"** drawer for the type and watch the **live preview**: a Vector2 gets a
   **direction dial**, a Color a **swatch row**, an `int`/`float` a **progress bar** (set the reach,
   e.g. just `150`), a Texture2D a **preview thumbnail**, a Curve an inline **curve**.
3. Organize many knobs with **"Group under heading"** / **"Sub-heading"** (`@export_group` /
   `@export_subgroup`) - they show a **"Group › Subgroup"** chip on the row and nest in the Inspector.
4. Select the node and the Inspector shows the rich, grouped drawers; press Play and the game reads
   from those same designer-tweaked values. The **Inspector Playground** showcase
   (`demo/showcase/inspector_playground/inspector_playground.tscn`) demonstrates five of the eight drawers at once - the curve editor, progress bar, swatch row, texture preview and vector dial.

Without the editor plugin (or in an exported game) each property is just a plain field - the parity
covenant is untouched. New here? The dialog starts simple (Basic "More options") and only unfurls the
Advanced knobs when a variable actually uses them; first run also offers a **Simple Mode**.

---

## 15. Reuse and Scale - Extract-to-Function and Families

Two ways to stop repeating yourself.

- **Extract-to-Function.** Select a run of actions you keep re-typing → **Extract to Function…** →
  name it. The selection becomes one named, reusable **ƒ verb** you can call anywhere; the original
  rows are replaced by the call. It's the "create an abstraction" gesture - a named verb, not a copy.
- **Families.** When the same logic should run across *many* objects, set **Sheet Type → Family**:
  the sheet's events iterate over a whole **family** of nodes (family-scoped), so one sheet drives the
  group. The **Family Arena** showcase (`demo/showcase/family_arena/family_arena.tscn`) shows it end to end.

---

## 16. Tips and Common Mistakes

- **Naming a variable after a host member.** Calling a variable `position` on a `Node2D` sheet
  shadows the node's own `position` - the generated script won't load. The **variable dialog now
  warns + blocks** this as you type, and **Rename Everywhere…** fixes existing references safely.
- **A ƒx expression that doesn't compile.** You'll see the red row marker (recipe 6). The ƒx field
  also has live validation + autocomplete as you type.
- **"It compiled but nothing happens."** Check the script is actually **attached** to the node
  (Tools ▸ Attach to Selected Node) and the **host class** matches the node type.
- **Editing the `.gd` in Godot's script editor.** Go ahead - a sheet *is* its `.gd`, so your edits
  round-trip back to events (function bodies, `if/else`, loops, and `match` all de-code into rows);
  re-open it as a sheet to keep editing visually. (Only the *output* of a legacy `.tres`-sourced sheet
  is overwritten on recompile - there, edit the sheet, not the output. For verbatim code that should
  stay untouched, a **GDScript block** row is still emitted as-is and round-trips.)
- **Run In Background needs a pure callable.** No scene-tree or node access inside it - it runs off
  the main thread. Compute off-thread, then apply the result in the On Done handler (main thread).
- **A Budgeted For Each only advances when re-entered.** Drive it from **On Process** - that's what
  resumes the pass each frame. It works over a snapshot taken once per pass and skips anything freed
  mid-pass.
- **Event Trace rides the Live Values stream.** If the cyan fire markers never appear, turn on
  Tools ▸ Live Values too.
- **For true hit-stop, set the Slowmo clock to realtime.** Otherwise the hold duration is itself
  slowed by the time scale.
- **Don't wire the Juice camera.** Its camera effects auto-find the active camera; attach the
  behavior and call the actions.
- **A long sheet is not automatically a bad sheet.** The Project Doctor's fan-out advisory flags by
  **node count, never row count** - a long, focused state machine on one host is fine.

---

More vocabulary in the generated [EVENTSHEETS-VOCABULARY.md](../EVENTSHEETS-VOCABULARY.md); the
honest pros/cons + scope are in the [README](../README.md).
