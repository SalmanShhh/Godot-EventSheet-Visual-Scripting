# Godot EventSheets

**Visual event sheets for Godot 4 that compile to plain, readable GDScript.**

The point is **speed-to-game**: whether you've never written code, want logic to pour out faster, or you're mid-jam - events get you from idea to *playing it* in minutes, and keep up when the project balloons to thousands of events.

> [!WARNING]
> **Experimental - early, vibecoded, not yet validated.** Built almost entirely through AI-assisted coding. The suite is large (4,700+ CI-gated assertions) and every feature ships with tests, but the project hasn't been proven by real-world use and is **subject to sweeping changes** between releases. Pin a release tag, expect rough edges, and report what you hit.

Godot EventSheets (engine codename *EventForge*, the prefix on internal class names) brings the C3 event-sheet workflow into the Godot editor: a fast visual editor where events read like sentences, and a compiler that turns every sheet into **typed, idiomatic GDScript** - no runtime interpreter, no plugin dependency in your exported game, and **zero performance difference from hand-written code** (a tested contract).

![The event sheet editor: two-lane condition/action rows, type-annotated variables with @export badges and an Inspector-grouping chip, trigger arrows, a negated condition, BBCode in a comment, an inline GDScript block, and a sheet-built heal() function.](docs/previews/editor-event-sheet.png)

## What it compiles to

A sheet isn't interpreted - it **compiles to a plain `.gd` script** you attach and ship. Rows like:

- **On Ready** → *Print* `"Spawned"`
- **Every tick** · *Is action pressed* `"ui_right"` → *Move by* `Vector2(speed * delta, 0)`
- **On Body Entered** *(body)* · *body is in group* `"enemy"` → *Add* `-10` *to health*

become exactly this - typed GDScript with zero references to the plugin:

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

Delete the plugin and this script still runs. The reverse works too: **open *any* `.gd` as a sheet** - the round-trip is lossless and byte-identical, so you edit visually or in Godot's script editor with the two in sync.

## Quick start

1. Copy `addons/eventforge/` and `addons/eventsheet/` into your Godot **4.5+** project (tested through **4.7 stable**). Optional: `eventsheet_addons/` for the 31 behavior packs. Removal is clean - see [uninstall](docs/UNINSTALL.md).
2. **Project Settings → Plugins** → enable **Godot EventSheets**.
3. Open the **EventSheet** tab in the main editor strip (next to 2D/3D/Script).
4. **New… → Platformer Starter**, add events (live search understands C3 phrases like *"every tick"*), and Run.

Coming from Construct? The [C3 migration guide](docs/C3-MIGRATION-GUIDE.md) maps every concept, behavior, and plugin to its home here. Extending the plugin? The [Custom ACEs guide](docs/CUSTOM-ACES-GUIDE.md) and [Custom Blocks guide](docs/CUSTOM-BLOCKS-GUIDE.md) cover both extension surfaces. Learning by building? The [recipes](docs/RECIPES.md) walk a platformer, health, pickups, and debugging end to end. Existing project? [Using EventSheets with your code](docs/USING-WITH-EXISTING-CODE.md) shows how sheets call (and are called by) your GDScript.

## Why event sheets in Godot? (honest pros & cons)

**Pros**

- **You ship GDScript, not a black box.** Delete the plugin and your game still runs. Performance parity is a permanent, test-enforced contract.
- **It teaches Godot while you use it.** Every action's tooltip shows the GDScript it generates; ƒx expressions *are* GDScript with live validation; the GDScript panel maps every row to its lines and back.
- **Debug it like any GDScript.** Output is plain code - real breakpoints, step through the generated `.gd`. F9 conditional breakpoints and a paused-at-row jump work from the sheet; Live Values / Event Trace are optional on top.
- **A sheet is just `.gd`.** No `.tres`. Open any `.gd` as a sheet, edit it either way, paste GDScript and it converts to events, call sheet-built classes from regular code.
- **C3 muscle memory works.** The grammar, the picker, behaviors-as-components, and the System/Keyboard/Mouse/Gamepad/Touch/Audio vocabularies are all designed against C3 conventions on purpose.
- **Scales.** A custom-drawn virtualized viewport keeps 10,000+ rows fluid with no per-row widgets.

**Cons**

- **It's a bridge, not a wall.** Complex logic eventually pulls you toward GDScript by design. Code-free authoring and the Helpers ACE set narrow the gap, but to *never* see code, C3 still hides it better.
- **2D-first.** Most packs target 2D; the 3D side has the Node3D/CharacterBody3D/Camera3D vocabularies, raycast/world-query ACEs, First/Third-Person starters, and Sine/Orbit/Bullet/Move To/Line of Sight 3D packs - deeper 3D still reaches for ƒx.
- **Some C3 plugins have no equivalent** (Multiplayer, Drawing Canvas, XML) - routed to the native Godot feature.
- **Experimental.** A large CI suite stands in for mileage it hasn't earned.

## Feature tour

**The editor** - Two-lane condition/action rows, object icons + labels, flat cells, drag/drop with insertion arrows, groups, colored BBCode comments, inline colour-swatch picking, drag-a-node-onto-a-param, multi-select, copy/paste, full undo/redo. **Find & Replace (Ctrl+F)**, script-editor shortcuts (F9 breakpoints, Ctrl+/ toggle, Alt+↑↓ move), a **Command Palette (Ctrl+P)**, **Simple Mode**, multi-view (split/detached/linked), themeable down to every token (Dracula, Nord, Gruvbox, Monokai, Solarized, Catppuccin, + a Godot-adaptive default).

**The language** - Events, sub-events, Else/Else-If, the **full C3 loop & picking set** (For / For Each / ordered / Repeat / While; pick by comparison, highest/lowest, nearest, nth, random), **functions** (typed params + custom return types, publishable as ACEs), stateful conditions (Every X Seconds), enums, signals, match rows, collection & combo variables, **Inspector-grouped `@export` variables** (drag one onto another for a folder, again for a subgroup), **every Godot inspector option** (range modifiers, flags, layer grids, file/folder pickers, node-path filters, password/expression/link, storage - chosen in plain language with a live "Ships as:" annotation strip), Inspector drawers (progress bar / dial / swatch / texture / curve), GDScript blocks, includes, Wait / Wait For Signal (`await`), Autoload sheets, and a **Custom Block API** - register your own non-ACE row kinds (preloads, region markers, notes, pack-defined data blocks) with a 30-line script; each gets Add-menu + dialog UX and byte-exact round-trips automatically.

**450+ native ACEs** - Tween, Scene flow, Audio, sprites & cameras, Nav, Math & Random, Color, 2D/3D raycast & Collision queries, Nodes, Project/File utilities, runtime signal wiring, UI/menu, particles, AnimationTree, tilemaps, shaders, physics joints, input rebinding, and a **Helpers** escape hatch (Set/Get Property, Call Method, Run GDScript, Inline If) so unmapped code still stays an editable row.

**31 behavior packs**, all authored as event sheets - Platformer, 8-Direction, Timer, Flash, State Machine, Sine/Orbit/Bullet/Move To/Follow/Car/Tile Movement, Line of Sight (2D & 3D), a 3D quartet, Spring, Tween, Save System, plus C3-addon ports: Drag & Drop, Virtual Cursor, Health (absorption + shield pools), Weapon Kit, HTN Agent, Simple Abilities, a Juice pack (screenshake/zoom/squash), a Time Slicer, and a Run In Background runner. Drop a `class_name` script in `eventsheet_addons/` and it becomes a provider - `@ace_*` annotations shape everything.

**Tooling** - A pure-GDScript **MCP server** (drive the plugin from external tools/AI), a searchable node picker, export integrity + compile-on-save, git-`textconv` sheet diffs, a **Project Doctor** (dock/CLI/CI drift audit), error→row deep-linking, live debugging (Live Values, Watch box, conditional breakpoints, Event Trace), a committed vocabulary doc, sheet backups, and shareable snippets.

## Current status

**`v0.9.5` - "Code-Free Authoring & First-Class Variables"** made `.gd` the default sheet format, gave every bundled pack a zero-GDScript-block compile, added first-class `@export` variables with lossless round-trip, the full Inspector-drawer set, and the addon-author loop.

**Since v0.9.5 (unreleased)** - the authoring & in-sheet experience got a large pass toward **authoring a whole game code-free** (full ledger in [CHANGELOG.md](CHANGELOG.md)):

- **The ACE Studio** - the function dialog reframes "what kind of verb?" as three plain-language cards (Does something / Is it true? / A value) with a live picker preview and a "Ships as:" signature. Double-click a **Define block** to edit a verb in place; the New Behaviour dialog offers working **starter recipes** (Cooldown, Stat pool).
- **Opened packs become editable vocabulary** - a per-function shell-lift now turns a pack's annotated verbs into real, editable `EventFunction`s (**331 across the library**; health opens with its full 16-action / 5-condition / 12-expression vocabulary), byte-verified. Helpers **anywhere in the file** lift too - a mid-file `_get_pool() -> HealthPool` anchors in place and re-emits at its exact original slot. A left-rail **Anatomy panel** shows the sheet as seven organs (Properties · State · Triggers · Actions · Conditions · Expressions · Uses), click-to-jump.
- **Speed-of-thought editing** - a **Ghost Row** (`A → heal 5 ⏎`, zero dialogs), the **Param Hop** (Enter → Tab across a row's values), **Ctrl+Enter bulk retune** across selected rows, and single-key B/I/R.
- **Navigate like the script editor** - Ctrl+Click a behaviour name opens it as a sheet, Alt+←/→ jump history, Ctrl+P `#` sheet / `@` symbol search, and **paste an error line to land on the row that caused it**. Runtime errors and sheet breakpoints jump straight to the emitting event.
- **What Changed Since Save** - a semantic diff naming the rows a save would touch, in event language.
- **Variable folders** - drag one variable onto another to fold them into a named Inspector-group **bubble** (Discord-style); it ships as `@export_group` underneath.
- **The Custom Block API** - packs and projects register new NON-ACE row kinds (preloads, region markers, notes, data blocks) by dropping a script extending `EventSheetBlockKind` into `eventsheet_addons/`; the compiler, importer, viewport, Add menu, and a schema-driven edit dialog are all wired generically, and every kind's round-trip is byte-verify gated.

**Quality** - 4,700+ assertions, all green, CI-gated on every push; byte-exact golden round-trips guard the lossless rules. **Verified on Godot 4.7 stable.** Generated code never depends on the plugin, templates bake at apply-time, and output is performance-identical to hand-written GDScript - all test-enforced.

## Milestones

| Milestone | Status |
|---|---|
| `v0.1`–`v0.5` - editor + compiler + lossless pairing, rich variables, C3 coverage, 3D vocabulary, breakpoints, Audio, node picker | ✅ shipped |
| `v0.6` - Inspector attributes, addon composition + policy, Live Values, Singleton sheets, Spring/Tween/Save packs; `.6.1`/`.6.2` maintenance + project usability (compile-on-save, diffs, Doctor) | ✅ shipped |
| `v0.7` - **The Native Workflow Update**: Rename Everywhere, snippets, bulk ops, Godot-native entry points, if/elif/else reverse-lift | ✅ shipped |
| `v0.8` - **The Team & Scale Update**: Godot 4.7 + Modern theme, merge driver, Find References, includes manager, new packs + 3D raycast, opt-in MCP | ✅ shipped |
| `v0.9.0` - **Performance & Game Feel**: frame-spreading, Juice pack, code-free authoring, first-class UI/raycast/particles/tilemaps/shaders, ACE safety audit | ✅ shipped |
| `v0.9.5` - **Code-Free Authoring & First-Class Variables**: `.gd`-default sheets, zero-block packs, `@export` variables + drawers, addon-author loop | ✅ shipped |
| _Unreleased_ - **The In-Sheet Authoring Update**: ACE Studio, per-function shell-lift (mid-file + custom-return helpers anchored in place), Anatomy panel, Ghost Row / Param Hop / bulk retune, error→row + paused-at-row, sheet diff, variable folders + subgroups, the Custom Block API, script-intent UX (custom resources + editor tools), full inspector-export coverage | 🔨 in progress |
| _Roadmap_ - Menu/HUD pack + UI starter, 2D overlap queries, scene-transition + dialogue packs, community feedback | 🗺 planned |

## Project layout

| Path | What it is |
|---|---|
| `addons/eventforge/` | Data model, compiler, importer, builtin ACEs, runtime bridge |
| `addons/eventsheet/` | The editor: dock, virtualized viewport, renderer, picker, themes, lint, MCP server |
| `eventsheet_addons/` | Zero-config ACE addons + the 31 behavior packs |
| `demo/` | Demo sheets, themes, and golden compiled output |
| `tests/` | Headless suite - `run_tests.gd` (full) and `run_perf.gd` (fast gate) |
| `docs/` | Contract specs + guides (C3 migration, recipes, MCP, glossary, uninstall) |

## Verifying a change

```text
godot --headless --path . --script tests/run_perf.gd     # fast, headless-safe suite
godot --headless --path . --script tests/run_tests.gd    # full suite
```

Every feature lands with tests, a CHANGELOG entry, and its spec updated - see `docs/GDSCRIPT-PAIRING-SPEC.md` for authoritative status. Pushes and PRs run the headless suite; pushing a `v*` tag stamps `plugin.cfg` and publishes a GitHub Release.

## Contributing & license

[CONTRIBUTING.md](CONTRIBUTING.md) has the dev setup, the compatibility covenant, and how to add ACEs, addons, packs, and themes. This experiment lives or dies by real-world reports - [open an issue](../../issues/new/choose) if something breaks or a C3 workflow feels wrong. MIT licensed (`LICENSE`).
