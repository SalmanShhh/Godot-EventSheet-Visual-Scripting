# Godot EventSheets

**Construct 3-style event sheets for Godot 4 that compile to plain, readable GDScript.**

**The point is speed-to-game.** Whether you've never written a line of code, you're an
experienced dev who wants game logic to pour out faster, or you're 6 hours into a 48-hour
jam — events get you from idea to *playing it* in minutes, and the tool keeps up when the
project balloons to thousands of events.

> [!WARNING]
> **Purely experimental — early, vibecoded, and not yet validated.** This plugin is an
> experiment, not a production tool: it has been built almost entirely through
> AI-assisted ("vibe") coding. The test suite is large (2,000+ CI-gated assertions)
> and every feature ships with regression tests, but the project has **not yet been
> validated by real-world use**. It is **very early in development** and **subject to
> large, sweeping changes** between releases — do not build anything you can't afford
> to rework on it yet. Pin a release tag if you experiment with it, expect rough
> edges, and please report what you hit.

Godot EventSheets (engine codename *EventForge* — you'll see that prefix on internal
class names) brings the event-sheet workflow C3 users love into the Godot editor: a fast
visual editor where events read like sentences, and a compiler that turns every sheet
into **typed, idiomatic GDScript** — no runtime interpreter, no plugin dependency in your
exported game, and **zero performance difference from hand-written code** (a guarded,
tested contract).

```text
Conditions                        | Actions
----------------------------------+--------------------------------
▶ Every tick                      |
   [icon] System  Is on floor     | [icon] System  Queue free
								  | GDScript  health -= 1
```

## Quick start

1. Copy `addons/eventforge/` and `addons/eventsheet/` into your Godot **4.5+** project
   (tested through **Godot 4.7 stable**; 4.6+ recommended for the native "Modern" theme look).
   Optional: `eventsheet_addons/` for the 27 behavior packs and demo ACEs. Removing the
   plugin later is clean and reversible — see the [uninstall guide](docs/UNINSTALL.md).
2. **Project → Project Settings → Plugins** → enable **Godot EventSheets**.
3. Open the **EventSheet** tab in the main editor strip (next to 2D/3D/Script).
4. **New…** → *Platformer Starter* (or open `demo/sheets/player.tres`), add events —
   live search understands C3 phrases like *"every tick"* or *"go to layout"* — and
   press **Compile**. The generated `.gd` is the script you attach and ship.
5. Coming from Construct? Read the [C3 migration guide](docs/C3-MIGRATION-GUIDE.md) —
   it maps every C3 concept, behavior, and plugin to its home here.

## Why event sheets in Godot? (the honest pros & cons)

**Pros**

- **You ship GDScript, not a black box.** Delete the plugin and your game still runs —
  generated scripts are plain code with no runtime hooks ([clean-removal guide](docs/UNINSTALL.md),
  gated by `clean_removal_test`). Performance parity with hand-written GDScript is a
  permanent, test-enforced contract.
- **It teaches Godot while you use it.** Every action's tooltip shows the GDScript it
  generates; ƒx expressions *are* GDScript with live validation and autocomplete; the
  GDScript panel maps every row to its generated lines (and back).
- **Two-way street.** Open *any* `.gd` file as a sheet (lossless, byte-identical
  round-trips), paste GDScript and it converts to events, write GDScript that calls
  sheet-built classes like any other class.
- **C3 muscle memory works.** The grammar, the picker, behaviors-as-components, combos,
  waits, press-a-key capture, the 27-pack addon set (including ports of custom C3 addons —
  Virtual Cursor, an event-driven Drag & Drop, a Health pack with absorption + shield
  pools, a Weapon Kit, and a utility-driven HTN planner), System/Keyboard/Mouse/Gamepad/
  Touch/Audio vocabularies — designed against C3 conventions on purpose.
- **Scales.** The custom-drawn virtualized viewport keeps 10,000+ rows fluid (no
  per-row widgets — a measured ~490 ms build for a 10k sheet, 8-row draw window).

**Cons (knowing them is part of trusting the tool)**

- **It's a bridge, not a wall.** Complex logic will eventually pull you toward writing
  GDScript directly — by design. The **Helpers** ACE set softens the cliff (Set/Get
  Property, Call Method, Run GDScript, ternary, is-valid, connect signal, math/string
  idioms keep more logic as rows), but if you want to never see code, C3 itself is better
  at hiding it.
- **2D-first, but 3D is catching up.** Most behavior packs target 2D; the 3D side has the
  Node3D/CharacterBody3D/RigidBody3D/Camera3D vocabularies, **raycast / world-query ACEs**,
  First-Person & Third-Person starter templates, and the Sine/Orbit/Bullet/Move To/Line of
  Sight 3D packs — deeper 3D still reaches for ƒx/GDScript blocks.
- **Some C3 plugins intentionally have no equivalent** (Multiplayer, Drawing Canvas,
  XML): the migration guide points to the native Godot feature instead — that honesty
  keeps the project maintainable.
- **Purely experimental, vibecoded project.** Built AI-first with a large CI-gated suite (2,000+
  assertions) standing in for mileage it hasn't earned yet — real-world validation is
  still ahead, and large sweeping changes between releases are likely (see the warning
  up top).

### Scope — what's first-class, and what isn't (yet)

EventSheets covers **game logic** as first-class visual events: control flow, variables,
functions, signals, loops/picking, timers, movement & AI behaviors, audio, save/load,
scene flow, and the full math/string/array/dictionary/vector toolkit — all compiling to
clean typed GDScript. A few engine subsystems are deliberately **not** first-class event
vocabulary yet, and lean on Helper ACEs / GDScript blocks instead:

- **On the roadmap (escape-hatch for now):** a **UI / menu** vocabulary (only `Label`
  text is first-class today — no Button/focus-navigation ACEs), **particles**,
  **tilemap** cell editing, **2D physics queries** (raycast/overlap — the 3D side already
  has these), **shaders** beyond a single uniform, **dialogue/cutscene** systems, and
  scene-**transition** helpers.
- **Intentional non-goals** — routed to native Godot, not reimplemented: **networking /
  multiplayer** and **localization (i18n)**. The [C3 migration guide](docs/C3-MIGRATION-GUIDE.md)
  maps each to its native feature.

The sweet spot is logic-heavy 2D action / arcade / puzzle / RPG games; anything the
vocabulary doesn't cover is always reachable through the `ƒx`/GDScript escape hatch (and
still ships as plain GDScript).

## Feature tour

### The editor (C3-parity UX on a virtualized canvas)
- Two-lane condition/action rows, object icons + labels, flat cells, whole-cell click
  targets, drag/drop with insertion arrows, groups (with descriptions), comments
  (multiline, colored, color swatches for Color params), multi-select, copy/paste,
  enable/disable with strikethrough, full undo/redo.
- **Find & Replace (Ctrl+F)** — one undoable Replace All across comments, params,
  blocks and pick filters; script-editor shortcuts (**F9 real breakpoints** that pause
  the Godot debugger in debug compiles, **Ctrl+/** to toggle rows, Alt+Up/Down to move
  rows), slow-double-click rename, quick-add bar ("type to insert" with C3 synonyms),
  **BBCode comments** (`[b]`/`[i]`/`[color]`), per-ACE notes, **starter templates**
  (Platformer / Top-down / First-Person 3D / Third-Person 3D), a **Command Palette
  (Ctrl+P)**, a **Simple Mode** that hides advanced rows for newcomers, and multi-view
  (split / detached / linked panes).
- **Theming**: every color/metric is a token; bundled presets include **Dracula, Nord,
  Gruvbox Dark, Monokai, Solarized Light, Catppuccin Mocha**, plus a Godot-adaptive
  default derived from *your* editor theme. A live visual theme editor is built in, with a
  **Quick Style** mode that re-skins the whole sheet from a base + accent colour (no
  token-by-token tuning) and per-token fine-tuning below.
- Guardrails everywhere: invalid names auto-correct or block, broken GDScript never
  commits, renaming a variable refactors every reference (blocks, params, pick filters,
  templates) automatically.

### The language (GDScript constructs as first-class rows)
- Events, sub-events, Else/Else-If, **the full C3 loop & picking set** (For / For Each
  / ordered / Repeat / While; pick by comparison, highest/lowest, nearest, nth, random —
  all plain for/while loops), **functions** (params + **return types**, publishable as
  ACEs), **stateful conditions** (Every X Seconds via baked private members),
  **enums** (Inspector dropdowns for
  free), **signals** (declared as rows, validated connections), **match rows** (C3's
  switch), **collection variables** (`Array[int]`, `Dictionary[String, int]`, literal
  defaults with live validation), **combo variables** (`@export_enum` dropdowns),
  GDScript blocks (class-level and in-flow), local variables, includes (C3-style
  library sheets), **Wait / Wait For Signal** (`await`), and **Autoload (Singleton)
  sheets** — Game State / Event Bus / Save System built as sheets, registered
  project-wide in one click, their functions callable from everywhere.
- **Input vocabulary**: InputMap actions with dropdowns, plus **Keyboard / Mouse /
  Gamepad / Touch** groups — key params capture with C3's *press-a-key* workflow.
- **100+ native ACEs**: Tween (ease/transition combos), Scene flow (incl. multi-line
  Spawn Scene At), **Audio** (fire-and-forget one-shots, player control, bus mixing —
  with ▶ sound preview in the dialog), AnimatedSprite2D, Camera2D, Label,
  NavigationAgent2D, time scale & window control, the C3 System text functions, shader
  params, date/time/platform info, Math & Random (`choose()` included), **3D raycast /
  world-query** ACEs, and a **Helpers** set — the structured escape hatch (Set/Get
  Property, Call Method, Run GDScript, Inline If, Is Valid, Connect Signal, and the
  math/string idioms) so code that doesn't map to a specific ACE still stays an editable
  row.

### Behaviors & addons (zero configuration, no JSON)
- **26 addon packs**, all authored as event sheets: the C3 classics (**Platformer** —
  coyote time, jump buffering, variable jump height, double jump, wall slide + wall jump,
  accel/decel — 8-Direction, Timer, Flash, State Machine, Sine with wave shapes, Orbit,
  Bullet, Move To, Follow, Car, Tile Movement, Line of Sight **2D & 3D**), a 3D quartet
  (Sine/Orbit/Bullet/Move To), the juice duo (**Spring** — named numeric **and colour**
  springs, squash & stretch in one action — and **Tween** with Inspector combos), the
  **Save System** singleton, and five ports of custom C3 addons: an **event-driven
  Drag & Drop** (Start/Set Drag Point/Drop with follow-speed, direction lock, throw and
  snapping), a **Virtual Cursor** that can drive it for gamepad/touch, a **Health**
  pack (current/max HP, damage absorption, named **Health Pools** = decaying shields,
  death/revive), a **Weapon Kit** (ammo + reserve, fire-rate cooldown, single/auto/
  burst modes, timed + instant reload — Fire triggers, you spawn the bullet), and an
  **HTN Agent** (utility-driven Hierarchical Task Network: world-state blackboard +
  primitive/compound tasks whose methods carry preconditions, subtasks and a utility score).
- **Custom ACE addons**: drop a script in `res://eventsheet_addons/` — `class_name` is
  the provider, `@ace_*` annotations shape everything (`@ace_param_options` for fixed
  combos, `@ace_param_autocomplete` for an editable type-or-pick combo, `@ace_param_hint`
  for ƒx/color/signal pickers). Annotated signals become triggers.
- **Export Addon…** turns the current behavior sheet into a published pack folder with
  one click. Custom node types (`class_name` + `@icon`) appear in Godot's Create Node
  dialog.

### Tooling
- **Scripting & automation API** (pure-GDScript MCP server): drive the plugin from
  external tools or AI assistants — list/read/compile/lint sheets and apply snippets,
  policy-bound and opt-in (toggle live in **View ▸ MCP Server**) — `docs/MCP-SERVER.md`.
- **Searchable node picker** on every expression param: filter the scene by name, class,
  `group:`, or `script:`, search *other* scenes with `scene:`, pin recents, and audit
  every node reference the sheet makes (missing ones flag red).
- **Export integrity**: every sheet recompiles when an export starts; stale scripts
  can never ship — and **compile-on-save** keeps F5 just as safe during development.
- **Reviewable sheet diffs**: a one-line git `textconv` setup makes `.tres` PRs show
  readable events instead of serialized-resource noise.
- **Project Doctor**: one audit (dock / CLI / CI) for cross-file drift — stale outputs,
  unregistered autoloads, unused vocabulary, unattached scripts.
- **Vocabulary doc**: a generated, committed reference of everything your sheets and
  packs publish ([this repo's own](EVENTSHEETS-VOCABULARY.md) is the living example).
- **Sheet backups** (save-time ring + restore) and **project-local templates**
  (drop a sheet in `eventsheet_templates/`, it joins the New… menu).
- Shareable text snippets (paste events into another project or a forum post).

## Current status

- **Version**: **`v0.8.0` — “The Team & Scale Update”**: EventSheets built to survive
  growing projects and teams. Collaboration & navigation — a **semantic 3-way git merge
  driver** (row-level, UID-keyed, no more unmergeable `.tres`), symbol-aware **Find
  References** + Go-to-Definition, an **includes manager** with **Extract Selection to
  Include** and read-only **provenance**, and **byte-stable regeneration** so diffs stay
  small. A bigger behavior library — **C3-addon parity** packs (Platformer juice:
  coyote/buffer/variable-jump/wall-jump, Spring colour springs, **Weapon Kit**,
  utility-driven **HTN Agent** — 26 total), richer Array/Dict/Vector/String **Helper
  ACEs**, behavior-declared **autocomplete**, and theme-editor **Quick Style**. (An
  optional scripting/automation integration — the MCP server, which can also generate
  events from a description — ships opt-in and off by default.) Playable showcases:
  `showcase_carousel.tscn` (flagship), `starfall.tscn`, `quest_fsm.tscn`, and
  `platformer_shooter.tscn`. See [CHANGELOG.md](CHANGELOG.md).
- **Quality**: 2,000+ test assertions, all green, CI-gated on every push (any `[FAIL]`
  fails the build, and the Project Doctor gate fails it on sheet/output drift);
  byte-exact golden round-trips guard the lossless rules. **Verified on Godot 4.7 stable**
  (full suite + an in-editor smoke run).
- **Compatibility covenant**: generated code never depends on the plugin; templates bake
  at apply (updates never rewrite your sheets); upgrades can never corrupt a file; and the
  output is **performance-identical to hand-written GDScript** — a test-enforced contract.

## Milestones

| Milestone | Status |
|---|---|
| `v0.1.0` — editor + compiler + lossless GDScript pairing (virtualized viewport, parity contract) | ✅ shipped |
| `v0.2.0` — rich variables, C3 coverage (native ACEs + packs), input/Wait, MCP server, themes | ✅ shipped |
| `v0.3.0` — multi-view (split / detached / linked), tool sheets | ✅ shipped |
| `v0.4.0` — 3D vocabulary, addon tags, hardening sweeps, contributor docs | ✅ shipped |
| `v0.5.0` — C3 System ACEs, full loops & picking, real breakpoints, devices, Audio, node picker | ✅ shipped |
| `v0.6.0` — Inspector attributes (all tiers), addon composition + policy + MCP enforcement, **editable Live Values**, Singleton sheets + event-bus triggers, Spring & Tween & Save System packs, the addon-author loop, the C3-reflex UX arc | ✅ shipped |
| `v0.6.1` — maintenance: dock decomposed into subsystems, module split completed, repo hygiene (no behavior changes) | ✅ shipped |
| `v0.6.2` — project usability: compile-on-save, sheet diffs (textconv), Project Doctor (dock/CLI/CI), vocabulary doc, sheet backups + restore, project templates; C3 param parity completed; per-pack builders; issue templates | ✅ shipped |
| `v0.7.0` — **The Native Workflow Update**: Rename Everywhere, snippets, bulk ops, session restore, asset drops, attach + Run Scene; Godot-native entry points (Scene-dock attach, Inspector button, settings, rebindable shortcuts, go-to-sheet-row, docs links, welcome); if/elif/else reverse-lift + Lift Report | ✅ shipped |
| `v0.8.0` — **The Team & Scale Update**: Godot 4.7 support + Modern-theme visuals & onboarding declutter (Simple Mode, Command Palette, Export-GDScript eject); **team/VCS** — semantic 3-way **merge driver**, symbol-aware **Find References** + Go-to-Definition, **includes manager** + Extract-to-Include + **provenance**, **byte-stable regeneration**; new packs (Drag & Drop, Virtual Cursor, Health, Line of Sight 3D, **Weapon Kit**, utility-driven **HTN Agent** — 26 total) + **C3-addon parity** (Platformer juice, Spring colour springs); **3D raycast/world-query ACEs** + 3D starters; richer Array/Dict/Vector/String **Helper ACEs** + import "why-it-stayed-code" hints; behavior-declared **autocomplete**; theme **Quick Style**; clean-removal guide + gate; platformer-shooter showcase; opt-in MCP scripting/automation (off by default) | ✅ shipped |
| `Unreleased` — first-class **UI/menu vocabulary** (Button On Pressed/Toggled + focus navigation), native **2D raycast** ACEs, **particles**, **AnimationTree**, **tilemaps**, **shader materials**, **runtime input rebinding**, **physics joints**, **loop** Break/Continue/Current-Item, **Else/Else-If** authoring + compiled Pick-Filter conditions | ✅ shipped |
| _Roadmap_ — a Menu/HUD behavior pack + UI starter demo; 2D **point/shape overlap** queries; **scene-transition** + **dialogue** packs; a **loop-index** expression; community feedback rounds | 🗺 planned |

Full feature-by-feature ledger: [CHANGELOG.md](CHANGELOG.md).

## Project layout

| Path | What it is |
|---|---|
| `addons/eventforge/` | Data model, compiler, importer, builtin ACEs, runtime bridge |
| `addons/eventsheet/` | The editor: dock, virtualized viewport, renderer, picker, themes, lint, MCP server |
| `eventsheet_addons/` | Zero-config ACE addons + the 27 behavior packs |
| `demo/` | Demo sheets, themes, and the golden compiled output |
| `tests/` | Headless suite — `tests/run_tests.gd` (full) and `tests/run_perf.gd` (headless-safe gate) |
| `docs/` | Specs: GDScript pairing, editor UI, theme tokens, MCP, C3 migration |

## Verifying a change

```text
godot --headless --path . --script tests/run_perf.gd    # fast, headless-safe suite
godot --headless --path . --script tests/run_tests.gd   # full suite
```

Every feature lands with tests, a CHANGELOG entry, and its spec updated — see
`docs/GDSCRIPT-PAIRING-SPEC.md` and `docs/EDITOR-UI-SPEC.md` for authoritative
feature-by-feature status.

## Releases & CI

Pushes and PRs run the headless suite (`.github/workflows/ci.yml`). Pushing a tag like
`v0.2.0` runs the test gate, stamps `plugin.cfg`, and publishes a GitHub Release with
`godot-eventsheets-<v>.zip` (drop-in addons) and `godot-eventsheets-samples-<v>.zip`
(behavior packs + demo project).

## Feedback

This experiment lives or dies by real-world reports. If something breaks or a C3
workflow feels wrong here, [open an issue](../../issues/new/choose) — the bug template
asks for the two things that make fixes fast (your versions + a minimal sheet or text
snippet), and the feature template asks what you're trying to *make*, which is how
this project designs. Permanent non-goals are documented in the
[migration guide](docs/C3-MIGRATION-GUIDE.md) so nobody waits on something that isn't
coming.

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) has the dev setup, the verification loop, the house
rules (compatibility covenant, canonical-emission rules, the gotcha list), and how to add
ACEs, addons, behavior packs, and theme presets.

## License

MIT. See `LICENSE`.
