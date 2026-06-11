# Godot EventSheets

**Construct 3-style event sheets for Godot 4 that compile to plain, readable GDScript.**

**The point is speed-to-game.** Whether you've never written a line of code, you're an
experienced dev who wants game logic to pour out faster, or you're 6 hours into a 48-hour
jam — events get you from idea to *playing it* in minutes, and the tool keeps up when the
project balloons to thousands of events.

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
   (optional: `eventsheet_addons/` for the 18 behavior packs and demo ACEs).
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
  generated scripts are plain code with no runtime hooks. Performance parity with
  hand-written GDScript is a permanent, test-enforced contract.
- **It teaches Godot while you use it.** Every action's tooltip shows the GDScript it
  generates; ƒx expressions *are* GDScript with live validation and autocomplete; the
  GDScript panel maps every row to its generated lines (and back).
- **Two-way street.** Open *any* `.gd` file as a sheet (lossless, byte-identical
  round-trips), paste GDScript and it converts to events, write GDScript that calls
  sheet-built classes like any other class.
- **C3 muscle memory works.** The grammar, the picker, behaviors-as-components, combos,
  waits, press-a-key capture, the 18-pack behavior set, System/Keyboard/Mouse/Gamepad/
  Touch/Audio vocabularies — designed against C3 conventions on purpose.
- **Scales.** The custom-drawn virtualized viewport keeps 10,000+ rows fluid (no
  per-row widgets — a measured ~490 ms build for a 10k sheet, 8-row draw window).

**Cons (knowing them is part of trusting the tool)**

- **It's a bridge, not a wall.** Complex logic will eventually pull you toward writing
  GDScript directly — by design. If you want to never see code, C3 itself is better at
  hiding it.
- **2D-first.** Most behavior packs target 2D; a 3D starter exists (Node3D/
  CharacterBody3D/RigidBody3D/Camera3D vocabularies + Sine/Orbit/Bullet/Move To 3D
  packs) but 3D depth still comes from ƒx/GDScript blocks.
- **Some C3 plugins intentionally have no equivalent** (Multiplayer, Drawing Canvas,
  XML): the migration guide points to the native Godot feature instead — that honesty
  keeps the project maintainable.
- **Young project.** The test suite is large (1,100+ assertions, CI-gated) but real-world
  mileage is still accumulating; expect rough edges and report them.

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
  (Platformer / Top-down), multi-view (split / detached / linked panes).
- **Theming**: every color/metric is a token; bundled presets include **Dracula, Nord,
  Gruvbox Dark, Monokai, Solarized Light, Catppuccin Mocha**, plus a Godot-adaptive
  default derived from *your* editor theme. A live visual theme editor is built in.
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
  library sheets), **Wait / Wait For Signal** (`await`).
- **Input vocabulary**: InputMap actions with dropdowns, plus **Keyboard / Mouse /
  Gamepad / Touch** groups — key params capture with C3's *press-a-key* workflow.
- **75+ native ACEs**: Tween (ease/transition combos), Scene flow (incl. multi-line
  Spawn Scene At), **Audio** (fire-and-forget one-shots, player control, bus mixing —
  with ▶ sound preview in the dialog), AnimatedSprite2D, Camera2D, Label,
  NavigationAgent2D, time scale & window control, the C3 System text functions, shader
  params, date/time/platform info, Math & Random (`choose()` included).

### Behaviors & addons (zero configuration, no JSON)
- **18 behavior packs** (14 C3 classics + Sine/Orbit/Bullet/Move To in 3D), all authored as event sheets: Platformer, 8-Direction,
  Timer, Flash, State Machine, Sine (7 movements × 5 wave shapes), Orbit (ellipses),
  Bullet, Move To (waypoint queues), Follow (smooth + delayed history modes),
  Drag & Drop (axis locking), Car (drift), Tile Movement (simulate control, grid
  helpers), Line of Sight (cone + raycast conditions).
- **Custom ACE addons**: drop a script in `res://eventsheet_addons/` — `class_name` is
  the provider, `@ace_*` annotations shape everything (`@ace_param_options` for combos,
  `@ace_param_hint` for ƒx/color/signal pickers). Annotated signals become triggers.
- **Export Addon…** turns the current behavior sheet into a published pack folder with
  one click. Custom node types (`class_name` + `@icon`) appear in Godot's Create Node
  dialog.

### Tooling
- **MCP server** (pure GDScript): AI assistants can list/read/compile/lint sheets and
  apply snippets — `docs/MCP-SERVER.md`.
- **Searchable node picker** on every expression param: filter the scene by name, class,
  `group:`, or `script:`, search *other* scenes with `scene:`, pin recents, and audit
  every node reference the sheet makes (missing ones flag red).
- **Export integrity**: every sheet recompiles when an export starts; stale scripts
  can never ship.
- Shareable text snippets (paste events into another project or a forum post).

## Current status

- **Version**: **`v0.5.0`** — C3 System coverage (time/display/text/comparisons,
  Every X Seconds), the full loop & picking set, function returns, real breakpoints,
  Find & Replace, device input with press-a-key, the Audio module (with sound preview),
  starter templates, the searchable node picker, per-ACE comments, and three hardening
  sweeps. See [CHANGELOG.md](CHANGELOG.md).
- **Quality**: 1,100+ test assertions, all green, CI-gated on every push (any `[FAIL]`
  fails the build); byte-exact golden round-trips guard the lossless rules.
- **Compatibility covenant**: generated code never depends on the plugin; templates bake
  at apply (updates never rewrite your sheets); upgrades can never corrupt a file.

## Milestones

| Milestone | Status |
|---|---|
| 1.0 editor + compiler + pairing (virtualized editor, parity contract, lossless `.gd` sheets) | ✅ shipped |
| Rich variables (enums, collections, combos, curated Dictionary/Array/JSON ACEs) | ✅ shipped |
| C3 coverage program (native-node ACEs, all 14 behavior packs, migration guide) | ✅ shipped |
| Godot-familiarity (find bar, shortcuts, theme inheritance, scene-aware completion, drag-from-docks) | ✅ shipped |
| MCP server (AI tooling) | ✅ shipped |
| `v0.2.0` release | ✅ shipped |
| Tool sheets (`@tool` + EditorScript / On Editor Run — experimental) | ✅ shipped |
| Multi-view (split panes, detached windows, linked follow-selection — all full editors) | ✅ shipped |
| 3D vocabulary + 3D behavior packs | ✅ shipped |
| Language completeness (loops, picking, returns, stateful conditions, group locals) | ✅ shipped |
| Debugging rung 1 (real breakpoints) + device input + Audio module | ✅ shipped |
| `v0.5.0` release (System ACEs, loops/picking, debugging, devices, Audio) | ✅ shipped |
| Inspector attributes **Tier 1** (tooltip / group / range / multiline on exported variables) | ✅ shipped |
| Inspector attributes **Tier 2** (Clamp / On Changed setters, Show If / Lock Unless, read-only) | ✅ shipped |
| Tool buttons (Inspector-clickable sheet functions) + MCP policy enforcement | ✅ shipped |
| **Live Values** (variables stream to the editor while the game runs) | ✅ shipped |
| Inspector attributes Tier 3 (custom drawers — full spec delivered) | ✅ shipped |
| Community feedback rounds | 🗺 planned |
| **Addon composition** — meta-packs / jam kits (addon includes addon, compile-time bake) | ✅ shipped |
| **Project policy** for composition (approved-tag sourcing, depth rails, collision gates) | ✅ shipped |
| Composition Lane B v1 (has-a uses-instances) | ✅ shipped |
| Lane B.2 (sibling-behavior requirements → ⚠ badge) | ✅ shipped |

| Live-values debug overlay (EngineDebugger channel), community feedback rounds | 🗺 planned |

## Project layout

| Path | What it is |
|---|---|
| `addons/eventforge/` | Data model, compiler, importer, builtin ACEs, runtime bridge |
| `addons/eventsheet/` | The editor: dock, virtualized viewport, renderer, picker, themes, lint, MCP server |
| `eventsheet_addons/` | Zero-config ACE addons + the 18 behavior packs |
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

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) has the dev setup, the verification loop, the house
rules (compatibility covenant, canonical-emission rules, the gotcha list), and how to add
ACEs, addons, behavior packs, and theme presets.

## License

MIT. See `LICENSE`.
