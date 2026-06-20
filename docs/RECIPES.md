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

More vocabulary in the generated [EVENTSHEETS-VOCABULARY.md](../EVENTSHEETS-VOCABULARY.md); the
honest pros/cons + scope are in the [README](../README.md).
