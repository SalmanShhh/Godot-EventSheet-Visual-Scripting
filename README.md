# Godot EventSheets

**Visual event sheets for Godot 4 that compile to plain, readable GDScript.**

**The point is speed-to-game.** Whether you've never written a line of code, you want game logic to pour out faster, or you're mid-jam — events get you from idea to *playing it* in minutes, and keep up when the project balloons to thousands of events.

> [!WARNING]
> **Purely experimental — early, vibecoded, not yet validated.** Built almost entirely through AI-assisted ("vibe") coding. The suite is large (3,400+ CI-gated assertions) and every feature ships with regression tests, but the project has **not** been proven by real-world use and is **subject to large, sweeping changes** between releases. Pin a release tag, expect rough edges, and please report what you hit.

Godot EventSheets (engine codename *EventForge* — the prefix you'll see on internal class names) brings the event-sheet workflow C3 users love into the Godot editor: a fast visual editor where events read like sentences, and a compiler that turns every sheet into **typed, idiomatic GDScript** — no runtime interpreter, no plugin dependency in your exported game, and **zero performance difference from hand-written code** (a guarded, tested contract).

![The event sheet editor: two-lane condition/action rows, type-annotated variables (with @export badges and a "Combat › Defense" Inspector-grouping chip), trigger arrows, a negated condition, BBCode in a comment, an inline GDScript block, and a sheet-built heal() function.](docs/previews/editor-event-sheet.png)

![The ACE picker: search actions, conditions, and triggers by their Construct-style vocabulary, with Favorites and Recent panes and the generated GDScript shown live in the description panel.](docs/previews/editor-ace-picker.png)

```text
Conditions                        | Actions
----------------------------------+--------------------------------
▶ Every tick                      |
   [icon] System  Is on floor     | [icon] System  Queue free
								  | GDScript  health -= 1
```

## What it compiles to

A sheet isn't interpreted at runtime — it **compiles to a plain `.gd` script** you attach and ship. A handful of rows like:

- **On Ready** → *Print* `"Spawned"`
- **Every tick** · *Is action pressed* `"ui_right"` → *Move by* `Vector2(speed * delta, 0)`
- **On Body Entered** *(body)* · *body is in group* `"enemy"` → *Add* `-10` *to health*

become exactly this — typed, idiomatic GDScript with zero references to the plugin:

```gdscript
extends CharacterBody2D

@export var speed: float = 200.0
@export var health: int = 100

func _ready() -> void:
	print("Spawned")

func _process(delta: float) -> void:
	if Input.is_action_pressed(&"ui_right"):
		position += Vector2(speed * delta, 0)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		health += -10
```

Delete the plugin and this script still runs — see [`demo/sheets/player_generated.gd`](demo/sheets/player_generated.gd) for a full regenerated example.

## Quick start

1. Copy `addons/eventforge/` and `addons/eventsheet/` into your Godot **4.5+** project (tested through **4.7 stable**; 4.6+ for the native "Modern" theme). Optional: `eventsheet_addons/` for the 31 behavior packs. Removing the plugin later is clean and reversible — see the [uninstall guide](docs/UNINSTALL.md).
2. **Project Settings → Plugins** → enable **Godot EventSheets**.
3. Open the **EventSheet** tab in the main editor strip (next to 2D/3D/Script).
4. **New… → Platformer Starter.** A sheet is a plain **`.gd` file** by default (no `.tres`) — add events (live search understands C3 phrases like *"every tick"*) and Run. Prefer code? **Open in Godot** edits the same `.gd` in Godot's script editor, and the two stay in sync.
5. Coming from Construct? The [C3 migration guide](docs/C3-MIGRATION-GUIDE.md) maps every C3 concept, behavior, and plugin to its home here.
6. Learning by building? The [recipes](docs/RECIPES.md) walk a platformer, health, pickups, and debugging end to end; the [glossary](docs/GLOSSARY.md) is a C3 ↔ Godot ↔ EventSheets Rosetta Stone.
7. Existing project? [Using EventSheets with your existing code](docs/USING-WITH-EXISTING-CODE.md) shows how sheets call (and are called by) your GDScript, autoloads, nodes, and signals — no ACEs required.

## Why event sheets in Godot? (the honest pros & cons)

**Pros**

- **You ship GDScript, not a black box.** Delete the plugin and your game still runs — generated scripts are plain code with no runtime hooks ([clean-removal guide](docs/UNINSTALL.md), gated by `clean_removal_test`). Performance parity is a permanent, test-enforced contract.
- **It teaches Godot while you use it.** Every action's tooltip shows the GDScript it generates; ƒx expressions *are* GDScript with live validation and autocomplete; the GDScript panel maps every row to its lines and back.
- **Debug it like any GDScript.** Output is plain code, so you set breakpoints and step through the generated `.gd` in Godot's own debugger. F9 conditional breakpoints work from the sheet; in-editor Live Values / Event Trace are an optional convenience on top.
- **A sheet is just `.gd` — no `.tres`.** Open *any* `.gd` as a sheet (lossless, byte-identical round-trips), edit it visually **or** in Godot's script editor (**Open in Godot**) with the two in sync, paste GDScript and it converts to events, and call sheet-built classes from regular code.
- **C3 muscle memory works.** The grammar, the picker, behaviors-as-components, combos, waits, press-a-key capture, the 31-pack addon set (including custom-C3-addon ports — Virtual Cursor, event-driven Drag & Drop, a Health pack with absorption + shield pools, a Weapon Kit, a utility-driven HTN planner), and the System/Keyboard/Mouse/Gamepad/Touch/Audio vocabularies — all designed against C3 conventions on purpose.
- **Scales.** The custom-drawn virtualized viewport keeps 10,000+ rows fluid with no per-row widgets (~490 ms build for a 10k sheet, 8-row draw window).

**Cons (knowing them is part of trusting the tool)**

- **It's a bridge, not a wall.** Complex logic will eventually pull you toward GDScript — by design. **Code-free authoring** (visual expression builder, reflection-driven Call Method / Set/Get Property pickers, visual Array/Dictionary editor, promote-a-block-to-a-Function) and the **Helpers** ACE set (Run GDScript, ternary, is-valid, connect signal, math/string idioms) narrow the gap — but to *never* see code at all, C3 still hides it better.
- **2D-first, but 3D is catching up.** Most packs target 2D; the 3D side has the Node3D/CharacterBody3D/RigidBody3D/Camera3D vocabularies, **raycast / world-query ACEs**, First/Third-Person starters, and the Sine/Orbit/Bullet/Move To/Line of Sight 3D packs — deeper 3D still reaches for ƒx/GDScript.
- **Some C3 plugins intentionally have no equivalent** (Multiplayer, Drawing Canvas, XML): the migration guide points to the native Godot feature instead.
- **Purely experimental, vibecoded.** A large CI-gated suite (3,400+ assertions) stands in for mileage it hasn't earned — real-world validation is still ahead (see the warning above).

### Scope — what's first-class, and what isn't (yet)

EventSheets covers **game logic** as first-class visual events: control flow, variables, functions, signals, loops/picking, timers, movement & AI, audio, save/load, scene flow, and the full math/string/array/dictionary/vector toolkit — all compiling to clean typed GDScript. A few subsystems aren't first-class vocabulary yet and lean on Helper ACEs / GDScript blocks:

- **Now first-class (recently landed):** a **UI / menu** vocabulary (Button On Pressed / Toggled + focus navigation), **particles**, **AnimationTree**, **tilemap** cell editing, **2D raycast**, **shader materials**, **physics joints**, **runtime input rebinding**, and a **Collision** query set (CharacterBody / Area / CollisionObject).
- **Still on the roadmap (escape-hatch for now):** 2D **point / shape overlap** queries, **dialogue / cutscene** systems, and **scene-transition** helpers.
- **Intentional non-goals** — routed to native Godot: **networking / multiplayer** and **localization (i18n)**. The [migration guide](docs/C3-MIGRATION-GUIDE.md) maps each to its native feature.

The sweet spot is logic-heavy 2D action / arcade / puzzle / RPG; anything the vocabulary misses is always reachable via the `ƒx`/GDScript escape hatch (still shipping as plain GDScript).

## Feature tour

### The editor (C3-parity UX on a virtualized canvas)
- Two-lane condition/action rows, object icons + labels, flat cells, whole-cell click targets, drag/drop with insertion arrows, groups (with descriptions), multiline colored comments, **inline colour-swatch picking** on Color params (a `ColorPicker` on the cell — no dialog), **drag a Scene-dock node onto a param** to fill its `%reference`, multi-select (box / Ctrl / Shift-range), copy/paste, enable/disable with strikethrough, full undo/redo.
- **Find & Replace (Ctrl+F)** — one undoable Replace All across comments, params, blocks, and pick filters. Script-editor shortcuts (**F9 real breakpoints**, **Ctrl+/** toggle rows, Alt+Up/Down move rows), slow-double-click rename, a quick-add bar (C3 synonyms), **BBCode** (`[b]`/`[i]`/`[color]`) in comments, condition/action cell text, and hover descriptions, **plain-language hover descriptions** on every ACE & function, per-ACE notes, **starter templates** (Platformer / Top-down / First/Third-Person 3D), a **Command Palette (Ctrl+P)**, a **Simple Mode** (hides advanced rows + picker entries), and multi-view (split / detached / linked panes).
- **Theming**: every color/metric is a token; presets include **Dracula, Nord, Gruvbox Dark, Monokai, Solarized Light, Catppuccin Mocha**, plus a Godot-adaptive default from *your* editor theme. A live visual theme editor with a **Quick Style** mode re-skins the whole sheet from a base + accent colour.
- Guardrails everywhere: invalid names auto-correct or block, broken GDScript never commits, renaming a variable refactors every reference (blocks, params, pick filters, templates).

### The language (GDScript constructs as first-class rows)
- Events, sub-events, Else/Else-If, **the full C3 loop & picking set** (For / For Each / ordered / Repeat / While; pick by comparison, highest/lowest, nearest, nth, random — all plain for/while loops), **functions** (params + **return types**, publishable as ACEs), **stateful conditions** (Every X Seconds via baked private members), **enums** (free Inspector dropdowns), **signals** (declared as rows, validated connections), **match rows** (C3's switch), **collection variables** (`Array[int]`, `Dictionary[String, int]`, literal defaults with live validation), **combo variables** (`@export_enum`), **Inspector-grouped `@export` variables** (`@export_group` / `@export_subgroup`, badged + "Group › Subgroup"-chipped, lossless and editable across a `.gd` reopen), **Inspector drawers** (progress bar / Vector2 dial / Color swatch row / texture preview / curve — see status below), GDScript blocks (class-level and in-flow), local variables, includes (C3-style library sheets), **Wait / Wait For Signal** (`await`), and **Autoload (Singleton) sheets** (Game State / Event Bus / Save System, registered project-wide in one click).
- **Input vocabulary**: InputMap actions with dropdowns, plus **Keyboard / Mouse / Gamepad / Touch** groups — key params capture with C3's *press-a-key* workflow.
- **450+ native ACEs**: Tween (ease/transition combos + inline **Tween Callback**), Scene flow (**Spawn Scene At / (Full)** — position + rotation + group tag), **Audio** (one-shots, player control, bus mixing, ▶ preview in the dialog), AnimatedSprite2D, Camera2D (incl. limits), Label (incl. **Set Text formatted**), NavigationAgent2D, time scale & window control, the C3 System text functions, shader params, date/time/platform info, **Math & Random** (`choose()`, lerp / clamp / snapped, angle / rotate-toward, seeded RNG), **Color** (lighten / darken / lerp / HSV / alpha), **3D raycast / world-query**, **Collision** (CharacterBody/Area/CollisionObject layer/mask queries, shape enable/disable), **Dev helpers** (debug print/assert, Groups, Metadata), **Nodes** (navigate parent/child/find, plus add / remove / move / free / duplicate / rename / find-children / nodes-in-group), **Project utilities** (config settings, window / screen / clipboard, performance monitors, time formatting), **File management** (read / write / append, size / exists, copy / move / delete, make / remove / list dirs — null-safe reads, guarded writes), runtime **signal wiring** (connect / disconnect / emit-on / is-connected), and a **Helpers** set — the structured escape hatch (Set/Get Property, Call Method, Run GDScript, Inline If, Is Valid, math/string idioms) so unmapped code still stays an editable row.

### Behaviors & addons (zero configuration, no JSON)
- **31 addon packs**, all authored as event sheets:
  - The C3 classics: **Platformer** (coyote time, jump buffering, variable jump height, double jump, wall slide + jump, accel/decel), 8-Direction, Timer, Flash, State Machine, Sine (wave shapes), Orbit, Bullet, Move To, Follow, Car, Tile Movement, Line of Sight (**2D & 3D**), plus a 3D quartet (Sine/Orbit/Bullet/Move To).
  - The motion duo: **Spring** (named numeric **and colour** springs, squash & stretch in one action) and **Tween** (Inspector combos); the **Save System** singleton.
  - Custom-C3-addon ports: an event-driven **Drag & Drop** (follow-speed, direction lock, throw, snapping), a **Virtual Cursor** to drive it for gamepad/touch, a **Health** pack (current/max HP, damage absorption, named decaying **Health Pools**, death/revive), a **Weapon Kit** (ammo + reserve, fire-rate cooldown, single/auto/burst, timed + instant reload — you spawn the bullet), an **HTN Agent** (utility-driven Hierarchical Task Network: world-state blackboard + primitive/compound tasks with preconditions, subtasks, utility scores), and **Simple Abilities** (grant by id, cooldowns, auto-regen stack charges, temporary abilities, tags for bulk ops, plus Godot extras — Current Ability ID, global cooldown multiplier, Ready Abilities list).
  - Game-feel & performance: a **Juice** pack (trauma **screenshake**, smooth/anchored **zoom**, volume-preserving **squash & stretch** — camera auto-found from the active viewport), a **Time Slicer** (a per-frame ms/count-budgeted work queue — enqueue, react to *On Process Item*, spreads across frames), and a **Run In Background** runner (a pure function on a worker thread → *On Done*).
- **Custom ACE addons**: drop a script in `res://eventsheet_addons/` — `class_name` is the provider, `@ace_*` annotations shape everything (`@ace_param_options`, `@ace_param_autocomplete`, `@ace_param_hint`); annotated signals become triggers. **Sheet ▸ New Behaviour Addon…** scaffolds a richly-commented skeleton; **`## @ace_deprecated("…")`** retires an ACE without breaking old sheets (keeps compiling, hidden from the picker, flagged on hover with its replacement). Full how-to: the [Custom ACEs guide](docs/CUSTOM-ACES-GUIDE.md).
- **Export Addon…** turns the current behavior sheet into a published pack folder in one click. Custom node types (`class_name` + `@icon`) appear in Godot's Create Node dialog.

### Tooling
- **Scripting & automation API** (pure-GDScript MCP server): drive the plugin from external tools or AI — list/read/compile/lint sheets and apply snippets, policy-bound and opt-in (**View ▸ MCP Server**) — `docs/MCP-SERVER.md`.
- **Searchable node picker** on every expression param: filter by name, class, `group:`, `script:`, or `scene:`, pin recents, and audit every node reference (missing ones flag red).
- **Export integrity**: every sheet recompiles when an export starts, so stale scripts can't ship; **compile-on-save** keeps F5 safe in development.
- **Reviewable sheet diffs**: a one-line git `textconv` setup makes `.tres` PRs show readable events, not serialized-resource noise.
- **Project Doctor**: one audit (dock / CLI / CI) for cross-file drift — stale outputs, unregistered autoloads, unused vocabulary, unattached scripts.
- **Error → row deep-linking**: a bad ƒx expression or GDScript block flags the offending row (red marker + reason in tooltip) and jumps to it — on save and via **Tools ▸ Check Sheet for Errors**.
- **Live debugging**: editable **Live Values**, a **Watch** box (any expression, evaluated live), conditional **breakpoints**, and **Event Trace** (firing rows highlight in real time).
- **Vocabulary doc**: a generated, committed reference of everything your sheets and packs publish ([this repo's own](EVENTSHEETS-VOCABULARY.md)).
- **Sheet backups** (save-time ring + restore), **project-local templates** (`eventsheet_templates/`), and shareable text snippets.

## Current status

- **Since `v0.9.5` (unreleased).**
  - **Event groups round-trip through `.gd`.** A grouped sheet compiles to a `## @ace_group(…)` declaration per group plus a per-row `# @group:<slug>` tag, and reopening the `.gd` rebuilds the groups (name, colour, collapsed/toggleable, nesting) even though the compiler scatters a group's rows across trigger handlers — **verify-lift-gated**, so it degrades to a flat/verbatim block rather than corrupting. Demoed in `showcase_carousel`.
  - **Friendly variable types.** The Variable dialog's Type dropdown leads with **Number / Text / Yes-No** (a **"Whole numbers only"** tick splits int/float; Text → String, Yes-No → bool), with the Godot types under an "Advanced types" separator. The *stored* type stays a real Godot type, so the `.gd` round-trip is byte-unchanged.
  - **Visual expression builder.** The `ƒx` "Insert Expression" window gains an **operator palette** (`+ - * / % == != < > and or not ( )`), lists the sheet's own **variables** as one-click leaves, and — while searching — reflects a class-backed variable's members as ready-to-insert `enemy.velocity` fragments. (Also fixed a silent bug where picking a tree result no-op'd into the expression field.)
  - See [CHANGELOG.md](CHANGELOG.md).
- **Version `v0.9.5` — "Code-Free Authoring & First-Class Variables".**
  - **`.gd` is the default sheet format** (no `.tres`): a sheet is just GDScript, with a lossless, editable round-trip, **Open in Godot**, auto-preview, and sheet-metadata recovery. **Code-free behaviour authoring**: every bundled pack compiles with **zero GDScript blocks**, a behaviour-building ACE vocabulary + the `{host.}` idiom, and an importer that **opens any `.gd` as events** (de-coding bodies / loops / `match` to rows). **Families** (declare a sheet as a Family + family-scoped iteration), **collapsible GDScript blocks**, and **Extract-to-Function** (turn a selection into a named, reusable verb). **Node-heavy picking** relief: pick children by **type**, "Make %unique", prefer scene-unique `%Name`.
  - **Variables**: an **`@export` badge** on the row, and **`@export_group` / `@export_subgroup`** grouping (with "Group › Subgroup" chips) that now **survives reopening a `.gd` and stays editable** (the importer absorbs the group lines back onto the variable, gated by the verify-lift rule). Variable **tooltips** round-trip the same way.
  - **Tier 3 Inspector drawers** (complete): a numeric **progress bar**, a Vector2 **direction dial**, a Color **swatch row**, a **texture preview**, and an inline **curve** — each round-tripping into an editable drawer, authored via a per-type picker with a **live widget preview**. Vector2/Color/Texture2D/Curve are first-class variable types now; without the editor plugin the property is a plain field, so generated games stay parity-clean. A new **Inspector Playground** showcase (`demo/showcase/inspector_playground.tscn`) puts all five drawers + `@export` grouping on one tunable node.
  - **Addon authoring**: a **"New Behaviour Addon…"** scaffold teaching the `@ace_*` vocabulary, **plain-language hover descriptions on every built-in ACE** (authored *inline*, so packs are self-contained), and **ACE deprecation** (a deprecated ACE keeps compiling, is hidden, flagged with its replacement, and warned at compile).
  - **Cell legibility**: **BBCode** now renders in condition/action cell text *and* hover descriptions (comments already did), an **inline colour picker** opens from the cell swatch, **dragging a Scene node onto a param** fills its `%reference` (prefers scene-unique `%Name`), and the confusing scope pill was removed.
  - See [CHANGELOG.md](CHANGELOG.md).
- **Version `v0.9.0` — "Performance & Game Feel".**
  - **Frame-spreading**: a **Time Slicer** pack, an in-place **Budgeted For Each**, raw budget/coroutine ACEs, a **Run In Background** off-thread pack, and a Project Doctor unbounded-loop advisory — with a runnable **Swarm** demo.
  - **Game feel**: a **Juice** pack — trauma **screenshake**, smooth/anchored **zoom**, squash & stretch (tween + spring), and **slow-mo** with easing, all auto-finding the camera.
  - **AI/combat**: **Nearest/Furthest** picking that composes with **Line of Sight**.
  - **Adoption**: the *"Using EventSheets with your existing code"* guide. **Errors**: on-save For-Each linting, a coroutine-under-*On Process* Doctor check, typed *On Signal* parameters. A pre-release **ACE safety audit** compile-verifies all 446 built-in ACEs and fixed nine runtime-safety bugs; plus the editor-DX batch (error → row deep-linking, a Create-Node-parity **ACE picker**, live **event-trace**, a shadowing-variable guard) and the code-free authoring set. **31 behavior packs.** Showcases: `showcase_carousel.tscn`, `starfall.tscn`, `quest_fsm.tscn`, `platformer_shooter.tscn`, `swarm.tscn`.
- **Quality**: 3,400+ assertions, all green, CI-gated on every push (any `[FAIL]` fails the build; the Project Doctor gate fails it on drift); byte-exact golden round-trips guard the lossless rules. **Verified on Godot 4.7 stable.**
- **Compatibility covenant**: generated code never depends on the plugin; templates bake at apply (updates never rewrite your sheets); upgrades can't corrupt a file; output is **performance-identical to hand-written GDScript** — all test-enforced.

## Milestones

| Milestone | Status |
|---|---|
| `v0.1.0` — editor + compiler + lossless GDScript pairing (virtualized viewport, parity contract) | ✅ shipped |
| `v0.2.0` — rich variables, C3 coverage (native ACEs + packs), input/Wait, MCP server, themes | ✅ shipped |
| `v0.3.0` — multi-view (split / detached / linked), tool sheets | ✅ shipped |
| `v0.4.0` — 3D vocabulary, addon tags, hardening sweeps, contributor docs | ✅ shipped |
| `v0.5.0` — C3 System ACEs, full loops & picking, real breakpoints, devices, Audio, node picker | ✅ shipped |
| `v0.6.0` — Inspector attributes (all tiers), addon composition + policy + MCP enforcement, editable Live Values, Singleton sheets + event-bus triggers, Spring & Tween & Save System packs, the addon-author loop | ✅ shipped |
| `v0.6.1` — maintenance: dock decomposed into subsystems, module split, repo hygiene (no behavior changes) | ✅ shipped |
| `v0.6.2` — project usability: compile-on-save, sheet diffs (textconv), Project Doctor (dock/CLI/CI), vocabulary doc, sheet backups, project templates; C3 param parity; per-pack builders | ✅ shipped |
| `v0.7.0` — **The Native Workflow Update**: Rename Everywhere, snippets, bulk ops, session restore, asset drops, attach + Run Scene; Godot-native entry points (Scene-dock attach, Inspector button, settings, rebindable shortcuts, docs links, welcome); if/elif/else reverse-lift + Lift Report | ✅ shipped |
| `v0.8.0` — **The Team & Scale Update**: Godot 4.7 + Modern-theme visuals & onboarding (Simple Mode, Command Palette, Export-GDScript eject); team/VCS (semantic 3-way **merge driver**, symbol-aware **Find References** + Go-to-Definition, **includes manager** + Extract-to-Include + provenance, byte-stable regeneration); new packs (Drag & Drop, Virtual Cursor, Health, Line of Sight 3D, Weapon Kit, HTN Agent — 26 total) + C3-addon parity; **3D raycast/world-query ACEs** + 3D starters; richer Helper ACEs; behavior-declared autocomplete; theme **Quick Style**; clean-removal gate; opt-in MCP scripting | ✅ shipped |
| `v0.9.0` — **Performance & Game Feel**: frame-spreading (**Time Slicer**, **Budgeted For Each**, budget/coroutine ACEs, **Run In Background**, Doctor loop advisory) + **Swarm** demo; a **Juice** pack (screenshake, zoom, squash & stretch, slow-mo); **Nearest/Furthest** picking; the "existing code" guide; **On Signal** typed params; an error-prevention sweep; the editor-DX batch (error → row deep-linking, group editor, ACE picker, Watch box + event-trace, shadowing guard); **code-free authoring** (expression builder, reflection pickers, Promote-Block-to-Function, visual data editor, conditional breakpoints); first-class **UI/menu**, **2D raycast**, **particles**, **AnimationTree**, **tilemaps**, **shader materials**, **input rebinding**, **physics joints**, **24 Collision ACEs**, loop Break/Continue/Current-Item, Else/Else-If + Pick-Filter conditions; **Advanced Random** pack, ACE sub-categories, `.gd` preview, an **ACE safety audit** (446 ACEs + nine fixes), pick-filter authoring | ✅ shipped |
| `v0.9.5` — **Code-Free Authoring & First-Class Variables**: **`.gd` is the default sheet format** (no `.tres` — lossless editable round-trip, Open in Godot, auto-preview, metadata recovery); **code-free behaviour authoring** — every bundled pack compiles with **zero GDScript blocks** (flash / timer / 8-direction / state-machine / move-to…), a behaviour-building ACE vocabulary + the `{host.}` idiom, and a near-zero-RawCode importer that **opens any `.gd` as events** (de-codes bodies / loops / `match` to rows); **Families** (declare-a-sheet-as-Family + family-scoped iteration + Family Arena) and **collapsible GDScript blocks**; **abstraction levers** — Extract-to-Function (selection → named reusable verb) + function calls as first-class verbs; **node-heavy picking** relief (pick children by **type**, "Make %unique", prefer scene-unique `%Name`, **drop a node onto a param**); **first-class variables** — **`@export` badge** + **`@export_group`/`@export_subgroup`** + tooltips with **lossless, editable `.gd` round-trip**; the full **Tier 3 Inspector drawers** (progress bar / dial / swatches / texture / curve) + Vector2/Color/Texture2D/Curve types + **Inspector Playground**; **progressive disclosure** (tiered Variable dialog, C3-first labels, Simple Mode, Clamp↔Range); **"New Behaviour Addon…"** scaffold + **inline ACE descriptions** + `@ace_expose_all` + **ACE deprecation** + **BBCode cells**; syntax-error prevention (auto-closed brackets, structural guard); four grounded specs (inspector-attributes, progressive-disclosure, includes, event-group round-trip) | ✅ shipped |
| _Roadmap_ — a Menu/HUD behavior pack + UI starter; 2D point/shape overlap queries; scene-transition + dialogue packs; a loop-index expression; community feedback | 🗺 planned |

Full feature-by-feature ledger: [CHANGELOG.md](CHANGELOG.md).

## Project layout

| Path | What it is |
|---|---|
| `addons/eventforge/` | Data model, compiler, importer, builtin ACEs, runtime bridge |
| `addons/eventsheet/` | The editor: dock, virtualized viewport, renderer, picker, themes, lint, MCP server |
| `eventsheet_addons/` | Zero-config ACE addons + the 31 behavior packs |
| `demo/` | Demo sheets, themes, and the golden compiled output |
| `tests/` | Headless suite — `tests/run_tests.gd` (full) and `tests/run_perf.gd` (headless-safe gate) |
| `docs/` | Contract specs (GDScript pairing, inspector attributes, addon composition, progressive disclosure, includes, event-group round-trip) + guides (C3 migration, recipes, performance, MCP, glossary, uninstall) |

## Verifying a change

```text
godot --headless --path . --script tests/run_perf.gd    # fast, headless-safe suite
godot --headless --path . --script tests/run_tests.gd   # full suite
```

Every feature lands with tests, a CHANGELOG entry, and its spec updated — see `docs/GDSCRIPT-PAIRING-SPEC.md` for authoritative status.

## Releases & CI

Pushes and PRs run the headless suite (`.github/workflows/ci.yml`). Pushing a tag like `v0.2.0` runs the test gate, stamps `plugin.cfg`, and publishes a GitHub Release with `godot-eventsheets-<v>.zip` (drop-in addons) and `godot-eventsheets-samples-<v>.zip` (behavior packs + demo).

## Feedback

This experiment lives or dies by real-world reports. If something breaks or a C3 workflow feels wrong, [open an issue](../../issues/new/choose) — the bug template asks for your versions + a minimal sheet, and the feature template asks what you're trying to *make*. Permanent non-goals are documented in the [migration guide](docs/C3-MIGRATION-GUIDE.md).

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) has the dev setup, the verification loop, the house rules (compatibility covenant, canonical-emission rules, the gotcha list), and how to add ACEs, addons, behavior packs, and theme presets.

## License

MIT. See `LICENSE`.
