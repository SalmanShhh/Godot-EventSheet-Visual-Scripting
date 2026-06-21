# Recipes — build something, end to end

Short, concrete walkthroughs. Each assumes the plugin is enabled and you've opened the
**EventSheet** tab. New to the vocabulary? Keep the [glossary](GLOSSARY.md) open. Coming from
Construct 3? The [migration guide](C3-MIGRATION-GUIDE.md) maps every concept.

The golden loop for all of these: **New sheet → set the host class → add events (pick
Conditions + Actions) → Compile → attach the generated `.gd` to your node → Run.**

---

## 1. Hello, Jump — a platformer character in minutes

The fast path is the bundled **Platformer** behavior pack (coyote time, jump buffering, variable
jump height, wall jump — all the juice).

1. Make a `CharacterBody2D` scene with a sprite + a collision shape.
2. New sheet → **Sheet Type** → host class `CharacterBody2D`.
3. Attach the **Platformer** pack as a child node (Tools ▸ behaviors, or drop the pack node in);
   set its speed/jump in the Inspector.
4. One event: trigger **On Process** → action **Move And Slide**. The pack reads input and drives
   `velocity`; Move And Slide applies it.
5. **Compile**, attach the `.gd`, press Play.

Want it from scratch instead of the pack? Three events: *On Process* → set horizontal velocity
from input; *Is on floor* + *jump pressed* → set `velocity.y`; *On Process* → Move And Slide.

---

## 2. Health & damage

Use the **Health** pack for HP, damage absorption, decaying shield **pools**, and
On Damaged / On Death triggers — or roll your own with a variable.

**With the pack:** attach **Health**, set max HP in the Inspector. On a hit, call its *Take
Damage* action. Add an event: trigger **On Death** → action *Queue Free* (or play an animation).

**From scratch:** add a global **Variable** `health : int = 100`. On a hit event → *Subtract from
variable* `health`, amount `10`. Add an event: condition `health <= 0` → action *Queue Free*.

---

## 3. A pickup counter

1. Global **Variable** `score : int = 0`.
2. Give coins an `Area2D` in the `"coins"` group.
3. Event: trigger **On Area Entered** (or condition **Overlaps Body**) → actions: *Add to
   variable* `score` by `1`, then *Queue Free* the coin.
4. Show it: a `Label` + an event *On Process* → **Set Property** `text` = `"Score: %d" % score`.

---

## 4. Debugging 101

When something misbehaves, you have three tools — no `print()` required.

- **Check the sheet first.** Tools ▸ **Check Sheet for Errors** lints every ƒx expression and
  GDScript block; a bad one gets a **red marker on its row** and the editor jumps to it (hover the
  row for the reason + a "did you mean …?"). This also runs automatically on save.
- **Breakpoints.** Click the gutter (or F9) to pause the Godot debugger on a row in a debug run.
  Need it to stop only sometimes? **More ▸ Set Breakpoint Condition…** (e.g. `health <= 0`) — it
  pauses only on the frame that matters.
- **Live Values + Watch.** Tools ▸ Live Values streams the sheet's variables while it runs (and
  you can *edit* them live to test branches). The **Watch** box in that window evaluates any
  expression over those variables each frame — e.g. `health <= 0` or `score + lives` — so you can
  see a condition flip in real time without adding a label.
- **Event Trace.** Tools ▸ Event Trace highlights the rows whose events *fire* during a debug run
  (a cyan marker, updated live) — so "is this event even running?" is answered at a glance. It
  rides the Live Values stream, so turn that on too.

---

## 5. Author your own behavior / ACEs

No JSON, no boilerplate. Two routes:

- **A behavior pack:** build the logic as an event sheet, then **Export Addon…** turns it into a
  published pack folder.
- **Custom ACEs from a script:** drop a `.gd` into `res://eventsheet_addons/`. Its `class_name`
  becomes the provider; methods/exported vars become Actions/Conditions/Expressions; annotated
  signals become Triggers. `@ace_param_options` / `@ace_param_autocomplete` / `@ace_param_hint`
  shape the parameter fields. It registers project-wide automatically.

---

## 6. Common pitfalls (and what the editor does about them)

- **Naming a variable after a host member.** Calling a variable `position` on a `Node2D` sheet
  shadows the node's own `position` — the generated script won't load. The **variable dialog now
  warns + blocks** this as you type, and **Rename Everywhere…** fixes existing references safely.
- **A ƒx expression that doesn't compile.** You'll see the red row marker (recipe 4). The ƒx field
  also has live validation + autocomplete as you type.
- **"It compiled but nothing happens."** Check the script is actually **attached** to the node
  (Tools ▸ Attach to Selected Node) and the **host class** matches the node type.
- **Editing the generated `.gd` by hand.** Don't — re-compiling overwrites it. Use a **GDScript
  block** row in the sheet instead (it's emitted verbatim, and round-trips).

## 7. Helper ACEs that save a code drop

The picker has a row for most things you'd otherwise hand-write. A few that come up constantly:

- **HUD text** — `Set Text (formatted)` writes `"Score: %d  Lives: %d" % [score, lives]` to any
  Label / RichTextLabel in one row (no GDScript block).
- **Hit flashes & fades** — the **Color** category composes: `Lerp Color`, `Lighten` / `Darken`,
  `Color With Alpha`, `Color From HSV`. Feed the result straight into `Set Color Tint` (modulate).
- **Spawning** — `Spawn Scene (Full)` instances a scene and sets position + rotation + an optional
  group tag in one action; `Spawn Scene At` when you only need a position.
- **Timing without a Timer node** — `Call After Delay` / `Tween Callback` fire a method after N
  seconds without suspending the event; `Wait` (await) when you *do* want to suspend it.
- **Scene-tree queries** — `Get Parent`, `Find Child`, `Has Node`, `Get Child Count`, plus node
  **Groups** (Add / Is In / Call Method On Group) — no `get_node(...)` boilerplate.
- **Signals at runtime** — `Connect` / `Disconnect` / `Emit Signal On` / `Signal Is Connected`,
  without a `_ready` block.

Everything compiles to the exact one-liner you'd type by hand, so it stays a searchable, editable
row instead of a raw block.

---

## 8. Coordinating many nodes — `With node`, groups & aggregates

A boss enrages: flash it, then sound the retreat if the wave it commands is nearly dead. One event,
three Godot idioms — react to a **signal**, scope to a **node**, query a **group** with no loop.

**Setup:** enemies are nodes in the `"enemies"` group (each with a `health`); a `Boss` node with an
`enraged` signal; a HUD `Label` at `$HUD/Label`.

1. **React to the signal, don't poll.** Event → trigger **On Signal** `enraged`, source `Boss`. The
   compiler wires the `_ready` connection for you — no per-frame check.
2. **Scope the boss's actions once.** Right-click the event → **Scope Actions To Node… → `$Boss`**. A
   `With node  $Boss` chip appears in the condition lane. Add **Play Animation** `"roar"` and **Set
   Color Tint** red — you set the target *once*, not on every action. (Need one action on a *different*
   node? Give just that action an explicit **On node** — it wins over the scope.)
3. **Show the wave's average HP** (no loop): a HUD event → **Set Text (formatted)** on `$HUD/Label`,
   value `"Avg HP: %d"` with the **Average In Group** expression (`"enemies"`, `health`) as the arg.
4. **Broadcast a retreat** when the weakest is nearly dead: a sub-event → condition **Lowest In Group**
   `"enemies"` `health` `< 10` → action **Call Method On Group** `"enemies"` → `retreat`.

Compiles to plain, readable GDScript — exactly what you'd hand-write:

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

No god-object reaching out every frame, no manual node lists — a signal handler, a scoped target, and
two group queries, all as editable rows.

---

## 9. Building the Godot way — a steering tour

The plugin actively *nudges* a Construct user toward Godot idioms (signals over polling, small
scenes-as-components, the Inspector, one source of truth) — always as suggestions with the old path one
click away. This tour builds a tiny coin game using each nudge. New to why these are "the Godot way"?
The [migration guide's *Polling vs reacting*](C3-MIGRATION-GUIDE.md#polling-vs-reacting--the-biggest-shift-from-c3)
section is the one-page version.

**1. A coin is a behavior component, not a god-sheet.** New Sheet → **Behavior Component (signal-driven)**.
You get a `PickupBehavior` you attach as a *child* of each Coin's `Area2D` (the Godot answer to a C3
behavior). It *reacts* to the host's `body_entered` signal — no per-frame overlap check — and *emits*
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

**2. The score lives in one place — an autoload.** Don't declare `score` in five sheets. New Sheet →
**Game State (Autoload)**, add `score`, register it (Tools → Register Autoload). If you *do* sprinkle it
around, the **Project Doctor** (Tools → Check Project) flags it: *"Global 'score' is declared in 3
sheets — promote it to an autoload (one source of truth)."*

**3. Internal state vs designer knobs.** When you add a variable, the **"Designer-tweakable in the
Inspector (@export)"** box is *off* by default — so an internal `_combo_count` stays a private `var`,
and you tick the box only for values a designer should tune. Your Inspector stays a clean panel of real
knobs, not an everything-bucket.

**4. React, and reference by name.** On a Game sheet: trigger **On Signal** `collected` (source: a coin)
→ `GameState.score += amount`. Update the HUD without a brittle path: in the scene tree mark the deep
`ScoreLabel` **Access as Unique Name**, then write `%ScoreLabel` — type `%` in a ƒx field and it
autocompletes; typo it and it warns amber. And when you reach for a polling condition like *Overlaps
Body*, the picker tips you toward **On Body Entered** and lands "overlap" + Enter on the reactive
trigger by default.

**5. React to coins *appearing*, don't poll.** Spawning coins at runtime? Instead of checking
`IsInsideTree` every frame, use **On Child Entered Tree** (source: the coins container) to act the
moment a coin is added.

**6. Stay composed.** If a sheet starts reaching into a dozen different nodes, the Doctor's *fan-out*
advisory suggests splitting into per-node behaviors or naming it a coordinator — flagged by **node
count, never row count** (a long, focused state machine on one host is fine).

Every step has an escape hatch: the polling condition, the global, the deep `$path`, the one big sheet
all still compile and work. The plugin just makes the Godot way the *easy default*.

---

## 10. Auto-attack with game feel — picking, Line of Sight & the Juice pack

A top-down shooter that auto-fires at the closest enemy it can actually *see*, and makes every hit land:
the screen kicks, the kill drops into slow motion, and the player squashes on recoil. Every piece here
shipped together — the **Nearest** picking expressions, the **Line of Sight** pack's occlusion-correct
target, and the **Juice** behavior (whose camera effects auto-find the active camera, so nothing is wired).

**Setup:** enemies are `Area2D`s in the `"enemies"` group (each with a **Health** behavior); the player
has a **Line of Sight** and a **Juice** behavior attached as children.

1. **Target only what you can see.** On a 0.2s Timer → set a local `target` = **Nearest Visible In Group**
   `"enemies"`. The LoS pack scans the group and range/cone/raycasts each candidate, so a closer enemy
   *behind a wall* is skipped in favour of a visible farther one — exactly what auto-attack AI wants. (No
   LoS behavior? Compose it: **Nearest Node In Group** then a **Has Line Of Sight To** condition on it.)
2. **Fire at it.** Sub-event `if target != null` → spawn a bullet toward `target.global_position`.
3. **Kick the screen on each hit.** On the bullet's **On Body Entered** → **Shake** `0.3`. Trauma *stacks*,
   so a burst of hits builds a bigger shake, then decays on its own.
4. **Slow-mo the kill.** On the enemy Health's **On Death** → **Slowmo** `target_scale 0.15`, `hold 0.12`,
   clock **realtime** — a 120 ms hit-stop that makes the kill land. The fade curves are tuned once in the
   Inspector, not per call.
5. **Squash the player on recoil.** On fire → **Spring Squash** `-0.2` (a quick wide squash that springs
   back bouncily), or **Squash & Stretch** `-0.2, 0.15` for the tween version.
6. **Punch in on the boss.** When the boss spawns → **Zoom To Position** `boss.global_position, 130, 0.4`
   to frame it; pull back with **Zoom By Percent** `100, 0.3` when it dies.

It compiles to plain, readable GDScript — the pick is a one-line `reduce`, the camera is found for you:

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

No per-frame target scan, no camera wiring, no hand-rolled tweens — a loop-free pick, an auto-found
camera, and a handful of fire-and-forget juice calls. Want it bouncier or snappier? Every feel knob
(shake decay, slowmo curves, squash stiffness) lives in the Inspector.

---

More vocabulary in the generated [EVENTSHEETS-VOCABULARY.md](../EVENTSHEETS-VOCABULARY.md); the
honest pros/cons + scope are in the [README](../README.md).
