# Godot EventSheets

**Visual event sheets for Godot 4 that compile to plain, readable GDScript.**

The point is **speed-to-game**: whether you've never written code, want logic to pour out faster, or you're mid-jam - events get you from idea to *playing it* in minutes, and keep up when the project balloons to thousands of events.

> [!NOTE]
> **Early.** Every feature ships with tests (4,800+ CI-gated assertions, byte-exact round-trip gates, performance-parity contracts), but the project hasn't yet earned real-world mileage and may see sweeping changes between releases. Pin a release tag and report what you hit - issues are read and acted on.

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

1. Copy `addons/eventforge/` and `addons/eventsheet/` into your Godot **4.5+** project (tested through **4.7 stable**). Optional: `eventsheet_addons/` for the 70 behavior packs. Removal is clean - see [uninstall](docs/GUIDE-UNINSTALL.md).
2. **Project Settings → Plugins** → enable **Godot EventSheets**.
3. Open the **EventSheet** tab in the main editor strip (next to 2D/3D/Script).
4. **New… → Platformer Starter**, add events (live search understands C3 phrases like *"every tick"*), and Run.

Browse everything in the **[documentation index](docs/README.md)**. Coming from Construct? The [C3 migration guide](docs/GUIDE-C3-MIGRATION.md) maps every concept, behavior, and plugin to its home here. Extending the plugin? The [Custom ACEs guide](docs/GUIDE-CUSTOM-ACES.md) and [Custom Blocks guide](docs/GUIDE-CUSTOM-BLOCKS.md) cover both extension surfaces, [Designing user-friendly ACEs](docs/GUIDE-DESIGNING-USER-FRIENDLY-ACES.md) is the craft guide (naming, parameters, picker UX - make verbs beginners can use first try), [Creating custom modules](docs/GUIDE-CREATING-CUSTOM-MODULES.md) walks you through adding your own vocabulary, [Data-driven addons](docs/GUIDE-DATA-DRIVEN-ADDONS.md) and [Building a data-driven game](docs/GUIDE-DATA-DRIVEN-GAMES.md) show how to author content as Inspector-edited Custom Resources, [Composition and systems](docs/GUIDE-COMPOSITION-SYSTEMS.md) covers the ECS-lite pattern (entities as grouped nodes, systems as sheets that run over them), [Procedural generation](docs/GUIDE-PROCEDURAL-GENERATION.md) shows how one Advanced Random seed drives maps, loot, and cosmetics (and how to generate content in editor tools and resources), and [Building editor tools](docs/GUIDE-BUILDING-EDITOR-TOOLS.md) shows how a sheet becomes a Godot editor tool, and [Player and AI input](docs/GUIDE-PLAYER-AND-AI-INPUT.md) is the one-seam convention that lets every input-reading pack be driven by the player or by your AI (pathfinding chasers, bot hands on a Virtual Cursor, replays). Learning by building? The [recipes](docs/GUIDE-RECIPES.md) walk a platformer, health, pickups, and debugging end to end. Saving a game? [Saving and loading](docs/GUIDE-SAVING-AND-LOADING.md) covers the whole story - slot files in six formats, the persist group that snapshots a scene with zero rows, and the `save_state`/`load_state` seam that lets any behavior (including your own) travel with the save; the [Save Studio guide](docs/GUIDE-USING-THE-SAVE-STUDIO.md) walks the editor window that previews, exports, and generates save support. Authoring a reusable verb without code? [Using the ACE Studio](docs/GUIDE-USING-THE-ACE-STUDIO.md) walks the Define-a-Verb dialog field by field. Existing project? [Using EventSheets with your code](docs/GUIDE-USING-WITH-EXISTING-CODE.md) shows how sheets call (and are called by) your GDScript.

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
- **2D-first.** Most packs target 2D; the 3D side has the Node3D/CharacterBody3D/Camera3D vocabularies, raycast/world-query ACEs, First/Third-Person starters, the FPS Controller (with crouch/slide/wall tech), Nav Agent 3D navmesh pathfinding, Juice 3D camera feel, and the Sine/Orbit/Bullet/Move To/Line of Sight 3D packs - deeper 3D still reaches for ƒx.
- **Some C3 plugins have no equivalent** (Multiplayer, Drawing Canvas, XML) - routed to the native Godot feature.
- **Experimental.** A large CI suite stands in for mileage it hasn't earned.

## Feature tour

**The editor** - Two-lane condition/action rows, object icons + labels, flat cells, drag/drop with insertion arrows, groups, colored BBCode comments, inline colour-swatch picking, drag-a-node-onto-a-param, multi-select, copy/paste, full undo/redo. **Find & Replace (Ctrl+F)**, script-editor shortcuts (F9 breakpoints, Ctrl+/ toggle, Alt+↑↓ move), a **Command Palette (Ctrl+P)**, **Simple Mode**, multi-view (split/detached/linked), themeable down to every token (Dracula, Nord, Gruvbox, Monokai, Solarized, Catppuccin, + a Godot-adaptive default).

<img src="docs/previews/editor-ace-picker.png" alt="The ACE picker: live search across actions, conditions, and triggers, favorites and recents rails, and a plain-language description of the selected ACE with the GDScript it ships as." width="620">

<img src="docs/images/variable-dialog.png" alt="The Variable dialog: a plain-language Number variable with a tooltip, a range, a Show as: Progress bar drawer with its live preview, and Inspector access - it ships as one @export_range line." width="547">

**The language** - Events, sub-events, Else/Else-If, the **full C3 loop & picking set** (For / For Each / ordered / Repeat / While; pick by comparison, highest/lowest, nearest, nth, random), **functions** (typed params + custom return types, publishable as ACEs), stateful conditions (Every X Seconds), enums, signals, match rows, collection & combo variables, **Inspector-grouped `@export` variables** (drag one onto another for a folder, again for a subgroup), **every Godot inspector option** (range modifiers, flags, layer grids, file/folder pickers, node-path filters, password/expression/link, storage - chosen in plain language with a live "Ships as:" annotation strip), a **visually-designed Inspector** (a live editable view of every exported variable, eight drawers including min-max range sliders and editable tables, plus decor / required / inline-validation / field-button markers), GDScript blocks, includes, Wait / Wait For Signal (`await`), Autoload sheets, and a **Custom Block API** - register your own non-ACE row kinds (preloads, region markers, notes, pack-defined data blocks) with a 30-line script; each gets Add-menu + dialog UX and byte-exact round-trips automatically.

**550+ native ACEs** - Tween, Scene flow, Audio, sprites & cameras, Nav, Math & Random, Color, 2D/3D raycast & Collision queries, Nodes, Project/File utilities, runtime signal wiring, UI/menu, particles, AnimationTree, tilemaps, shaders, physics joints, input rebinding, seeded procedural generation, ECS-lite Systems queries over groups, and a **Helpers** escape hatch (Set/Get Property, Call Method, Run GDScript, Inline If) so unmapped code still stays an editable row.

**70 behavior packs**, all authored as event sheets - Platformer, 8-Direction, Timer, Flash, State Machine, Sine/Orbit/Bullet/Move To/Follow/Car/Tile Movement, Line of Sight (2D & 3D), a 3D quartet, Spring, Tween, Save System, plus C3-addon ports: Drag & Drop, Virtual Cursor, Health (absorption + shield pools), a **StatForge** buff-stack stat system (add/multiply/override modifiers with tags, sources, expiry timers, threshold rules, and whole loadouts as **StatSheetResource** .tres grids - two verbs run an RPG stat, the rest scales with your game), Weapon Kit, HTN Agent, Simple Abilities, a Juice pack (screenshake/recoil/head bob/zoom/squash/slowmo/hitstop, plus object + screen color TINTS with a strength dial) plus a Juice 3D camera-feel pack (shake/recoil/bob/lean/FOV punch), an **FPS Controller** (mouse look, sprint, jump, crouch + crouch slide, wall ride/jump, first/third person), **Platformer Pathfinding** (2D jump-graph navigation with portals, patrol discipline, and a shared path budget) with **Nav Agent 3D** as its navmesh twin (same verbs in 3D), a Time Slicer, a Run In Background runner, a **Currency Ledger** economy (register currencies by name, then earn/spend/cap/format from any sheet), a **Loot Table** roller (weighted drops, guarantees, hard pity, nested tables, seeded; or author drops data-driven in a **LootTableResource** `.tres` and drop it on a Loot Table Loader node, which warns in the Inspector if you forget to attach one), a **Storylet Weaver** (quality-based narrative: define storylets with requirements, then Draw the best eligible one), a **SkinVault** cosmetic-ownership manager (rarities + skins, weighted rolls with tier-based pity, a purchase handshake, grant/revoke; or author the whole catalog in a **SkinCatalogResource** `.tres` and load it via a Skin Catalog Loader node), a **ProcRoom** seeded room-graph generator (a Slay-the-Spire-style tiered map with visited/available/locked traversal), a **UtilityBrain** per-node AI (score actions by considerations + response curves, then Evaluate - the best action wins, with cooldowns/inertia/interrupts), a **Physics Car** (an arcade car on a RigidBody2D: throttle/brake/steer, keyboard or drive-toward AI, lateral grip, drift detection, terrain multipliers), a **ComboBox** input-sequence detector (register token sequences, fire On Combo Matched, with per-gap timing windows, wildcards, and partial-match tracking), a **Fade** behavior (fade any sprite or UI in and out by animating its transparency), a **Slide Movement** behavior (grid movement where a tap slides you until you hit a wall, Tomb-of-the-Mask style), a **Bound To** + **Wrap** screen-bounds duo (keep anything inside the camera view or an arena rect, or wrap it Asteroids-style per axis), a **Drawing Canvas** (draw lines, circles, cones, texture stamps, textured ribbons, and raycast **line-of-sight** fans onto a live texture - persistent paint or per-frame telegraphs) with its 3D partner the **Decal Painter** (ground-snapped blob shadows, splats with lifetimes and a FIFO cap, and 2D-canvas textures projected onto the world), an **ObjectPool** (reuse nodes instead of spawning and freeing them - Create Pool, Spawn, Despawn - so heavy scenes stay smooth), the UI trio: a **HUD Kit** (menus and HUDs by name, zero wiring), **Scene Flow** (fades and scene changes), and a **Dialogue Kit** (typewriter conversations), and a full **incremental / idle kit**: **Big Numbers** (short-scale/scientific/time formatting past a trillion, plus a Decimal type for values beyond a float's ceiling), an **Idle Generator** (geometric cost, exact closed-form Buy Max, optional fill-and-collect cycle), **Click Power**, **Boosts** (golden-cookie timed multipliers), **Upgrades**, **Prestige** (reset for a permanent multiplier), and **Milestones**. Content goes data-driven where it helps - an **AbilitySetResource** defines a Simple Abilities loadout as a `.tres`, a **RandomTableResource** holds weighted odds, and one **Use Advanced Random** toggle makes ProcRoom / Loot Table / SkinVault / Storylets share a single seed. Drop a `class_name` script in `eventsheet_addons/` and it becomes a provider - `@ace_*` annotations shape everything. Each bundled pack has a deep-dive guide with a dozen worked use cases in [docs/Addons/](docs/Addons/README.md).

**Abstraction that grows with you** - a row earns its place when it does MORE than a line: multi-line ACEs show a quiet **→N** ("compiles to N lines") cue, function calls read as **ƒ named verbs**, and the picker **leads with featured intention verbs** (Wait, Play Sound, Destroy, Move Toward...). Select actions and **Extract to Function** turns the pile into one reusable verb - captured locals become typed parameters automatically - then **Teach a Verb** publishes it to every sheet's picker in the project, node-targeted and retargetable, exactly like a built-in behavior.

**Tooling** - A searchable node picker, export integrity + compile-on-save, git-`textconv` sheet diffs, a **Project Doctor** (dock/CLI/CI drift audit, extensible by packs), error→row deep-linking, live debugging (Live Values, Watch box, conditional breakpoints, Event Trace), a committed vocabulary doc, sheet backups, shareable snippets, a public **`EventSheets` API** for building plugins on top ([guide](docs/GUIDE-BUILDING-ON-EVENTSHEETS.md)), and an opt-in MCP server for external tooling.

## Current status

The latest release, **`v0.15.0` - "Save Anything, Control Anything & BBcode it"**, is about persistence, control, and polish:

- **Save Anything - the save-state seam** - every stateful pack ships two plain methods, `save_state()` and `load_state(state)`, so any behavior (and any script of yours that adopts the pair) persists itself with no base class or registration. Put a node in the `persist` group and **Save Game** snapshots it and every seamed behavior child into the slot automatically; or reach for targeted **node / group / singleton** state verbs. Eighteen packs are seamed.
- **Six save formats, losslessly** - `config`, JSON, binary, CSV, and now **INI** and **XML**, every type round-tripped exactly (an int stays an int, a Vector2 a Vector2), all honoring the encryption key. **Read All** / **List Save Keys** / **Read Save File** load any slot or a dropped-in file, and **Save File Format** detects a file's format (by extension, then content) so a load flow accepts it without knowing it up front.
- **The Save Studio** (Tools menu) - preview any addon's save in each format before you commit, browse and export `user://` slots with optional format conversion, and point at any script to generate a copy-paste `save_state`/`load_state` pair. It is built on a new **Save group in the public `EventSheets` API**, with a **Project Doctor** check that flags stateful behaviors missing the seam. Hardened against data loss by an adversarial backend review: **atomic** writes, no silent wipe of an unreadable slot, and exact integer and backslash fidelity.
- **Control Anything - the player-or-AI input seam, everywhere** - Car, Tile Movement, Slide Movement, and Virtual Cursor join Platformer Movement, 8-Direction, and the FPS Controller: flip the exported `ai_controlled`, hold the `ai_*` intents, and the same behavior drives from a human or your AI with the same feel knobs. Virtual Cursor's new **On Cursor Arrived** trigger makes a full AI drag & drop a handful of rows, verified live end to end.
- **Pathfinding P4** - **Add Hazard** marks world rectangles deadly or costly at routing time (no graph rebuild), and **Add Moving Platform** gives the graph a platform edge with a full elevator-boarding discipline; the **Path Chase** showcase gains a spike zone the routes refuse and a ridable elevator.
- **BBcode it** - highlight text in a comment and a Discord-style **B / I / U / S** + color bar floats by the selection (inline and in the Edit Comment dialog); the custom-drawn inline editor gained real text selection to make it work, and comments render BBCode in the sheet.
- **Rounding it out** - **StatForge** stats-as-a-buff-stack (with **StatSheetResource** loadouts), **Juice** screen and object color tints, rounded sheet corners, a last-played-sound audio control, the **Rotate** pack and circular **Wrap** arenas, drawing prefabs + the **Draw Lab** showcase, two new tool guides (**Save Studio**, **ACE Studio**), a **documentation index**, and every pack guide brought to 15 worked use cases. The suite is now 70 packs.

**Quality** - 4,900+ assertions, all green, CI-gated on every push; byte-exact golden round-trips guard the lossless rules, the save backend is pinned across all 18 seams and six formats (including the adversarial-review regressions), and the AI drag & drop and pathfinding showcases are live-verified on camera. **Verified on Godot 4.7 stable.** Generated code never depends on the plugin, templates bake at apply-time, and output is performance-identical to hand-written GDScript - all test-enforced.

_Recent releases before this:_ **v0.14.0** (Platformer Pathfinding + Nav Agent 3D, the universal AI drive seam, FPS movement tech, Juice camera verbs 2D + 3D, the input overhaul), **v0.13.0** (the incremental/idle kit, ECS-lite Systems, Advanced Random behind one seed), and **v0.12.0** (the Inspector Designer + eight drawers, the UI trio packs, a faster lazily-built editor). The milestones table below and [CHANGELOG.md](CHANGELOG.md) have the full history.

## Milestones

| Milestone | Status |
|---|---|
| `v0.1` to `v0.5` - editor + compiler + lossless pairing, rich variables, C3 coverage, 3D vocabulary, breakpoints, Audio, node picker | ✅ shipped |
| `v0.6` - Inspector attributes, addon composition + policy, Live Values, Singleton sheets, Spring/Tween/Save packs; `.6.1`/`.6.2` maintenance + project usability (compile-on-save, diffs, Doctor) | ✅ shipped |
| `v0.7` - **The Native Workflow Update**: Rename Everywhere, snippets, bulk ops, Godot-native entry points, if/elif/else reverse-lift | ✅ shipped |
| `v0.8` - **The Team & Scale Update**: Godot 4.7 + Modern theme, merge driver, Find References, includes manager, new packs + 3D raycast, opt-in MCP | ✅ shipped |
| `v0.9.0` - **Performance & Game Feel**: frame-spreading, Juice pack, code-free authoring, first-class UI/raycast/particles/tilemaps/shaders, ACE safety audit | ✅ shipped |
| `v0.9.5` - **Code-Free Authoring & First-Class Variables**: `.gd`-default sheets, zero-block packs, `@export` variables + drawers, addon-author loop | ✅ shipped |
| `v0.10.0` - **The In-Sheet Authoring Update**: ACE Studio, per-function shell-lift (mid-file + custom-return helpers anchored in place), Anatomy panel, Ghost Row / Param Hop / bulk retune, error→row + paused-at-row, sheet diff, variable folders + subgroups, the Custom Block API, script-intent UX (custom resources + editor tools), full inspector-export coverage | ✅ shipped |
| `v0.11.0` - **The Structure & Vocabulary Update**: collapsible colored regions, Look Gallery + Inspector preview, localisation vocabulary, any-node reflection, terse providers (all 31 packs migrated + audit-gated), the abstraction levers (Extract/Teach/featured/compression cue), the public `EventSheets` API | ✅ shipped |
| `v0.12.0` - **The Inspector Designer Update**: the whole Inspector designed visually (a live editable view), 8 drawers (min-max sliders, editable tables, toggle buttons), decor + required + inline validation + field buttons, the EnemyStats Custom Resource showcase, the HUD Kit / Scene Flow / Dialogue Kit packs + Menu Starter scene, 2D overlap queries, FileSystem **Create New ▸ Event Sheet**, and a lazily-built (faster-loading) editor | ✅ shipped |
| `v0.13.0` - **The Genre Toolkits Update**: a complete incremental/idle kit (Big Numbers + a Decimal type, Idle Generator, Click Power, Boosts, Upgrades, Prestige, Milestones), composition/ECS-lite Systems + Entity System starter, Advanced Random driving the procedural packs behind one seed + a stateless Procedural module for tools and resources, data-driven Simple Abilities loadouts + a RandomTableResource, and auto-registering pack builders (58 packs) | ✅ shipped |
| `v0.14.0` - **The Pathfinding & Game-Feel Update**: Platformer Pathfinding (2D jump graphs with portals, patrol discipline, variable jumping, a stuck watchdog, follow mode, and a shared path budget) + Nav Agent 3D (navmesh, same verbs), the universal AI drive seam across the movement packs, FPS movement tech (crouch/slide/wall ride/wall jump), Juice camera verbs 2D + the Juice 3D pack, the live Input Map picker + the input vocabulary + the Input Rebind showcase, editor behavior previews, twelve API extension seams, EFIGS editor translations, and a ~21x faster boot (62 packs) | ✅ shipped |
| `v0.15.0` - **Save Anything, Control Anything & BBcode it**: the `save_state`/`load_state` seam on 18 packs + persist-group automation + node/group/singleton verbs, six lossless save formats (config/JSON/binary/CSV/INI/XML) with read + format-detection helpers, the Save Studio (preview/export/generate) on a new `EventSheets` Save API + a Doctor check + data-loss hardening, the player-or-AI input seam on every input-reading pack + AI drag & drop, pathfinding hazards + moving platforms, a Discord-style BBCode bar in comments, StatForge stats, Juice color tints, rounded corners, the Rotate pack + circular Wrap, and two tool guides + a docs index (70 packs) | ✅ shipped |
| _Roadmap_ - community feedback, polish, and whatever you ask for next | 🗺 planned |

## Project layout

| Path | What it is |
|---|---|
| `addons/eventforge/` | Data model, compiler, importer, builtin ACEs, runtime bridge |
| `addons/eventsheet/` | The editor: dock, virtualized viewport, renderer, picker, themes, lint, MCP server |
| `eventsheet_addons/` | Zero-config ACE addons + the 70 behavior packs |
| `demo/` | Demo sheets, themes, and golden compiled output |
| `tests/` | Headless suite - `run_tests.gd` (full) and `run_perf.gd` (fast gate) |
| `docs/` | Contract specs + guides (C3 migration, recipes, MCP, glossary, uninstall) |

## Verifying a change

```text
godot --headless --path . --script tests/run_perf.gd     # fast, headless-safe suite
godot --headless --path . --script tests/run_tests.gd    # full suite
```

Every feature lands with tests, a CHANGELOG entry, and its spec updated - see `docs/internal/SPEC-gdscript-pairing.md` for authoritative status. Pushes and PRs run the headless suite; pushing a `v*` tag stamps `plugin.cfg` and publishes a GitHub Release.

## Contributing & license

[CONTRIBUTING.md](CONTRIBUTING.md) has the dev setup, the compatibility covenant, and how to add ACEs, addons, packs, and themes. The project improves fastest through real-world reports - [open an issue](../../issues/new/choose) if something breaks or a C3 workflow feels wrong. MIT licensed (`LICENSE`).

## 🙏 Acknowledgments

This plugin stands on the shoulders of the tools that made visual, code-optional game logic mainstream:

- **[Construct](https://www.construct.net/)** - the direct inspiration. The event-sheet grammar, the ACE (Action / Condition / Expression) model, the picker, and behaviors-as-components are all designed against Construct 3's conventions on purpose, so C3 muscle memory carries over.
- **[Clickteam Fusion 2.5](https://www.clickteam.com/clickteam-fusion-2-5)** - a foundational event-editor whose event-grid lineage shaped the whole "events read like sentences" idea.
- **[Scratch](https://scratch.mit.edu/)** - for proving that visual, block-based programming is a real on-ramp to building software, not a toy.
- **[Godot Engine](https://godotengine.org/)** - the open-source engine this is built on and for; every sheet compiles to plain, idiomatic GDScript that runs with zero dependency on this plugin.

These are independent projects and trademarks of their respective owners; this plugin is not affiliated with or endorsed by any of them.
