# Godot EventSheets

**Visual event sheets for Godot 4 that compile to plain, readable GDScript.**

The point is **speed-to-game**: whether you've never written code, want logic to pour out faster, or you're mid-jam - events get you from idea to *playing it* in minutes, and keep up when the project balloons to thousands of events.

> [!NOTE]
> **Early.** Every feature ships with tests (20,791 CI-gated assertions across 725 test files, byte-exact round-trip gates, performance-parity contracts), but the project hasn't yet earned real-world mileage and may see sweeping changes between releases. Pin a release tag and report what you hit - issues are read and acted on.

Godot EventSheets (engine codename *EventForge*, the prefix on internal class names) brings the C3 event-sheet workflow into the Godot editor: a fast visual editor where events read like sentences, and a compiler that turns every sheet into **typed, idiomatic GDScript** - no runtime interpreter, no plugin dependency in your exported game, and **zero performance difference from hand-written code** (a tested contract).

![The EventSheet workspace inside the Godot editor: a plain platformer_shooter.gd opened as numbered two-lane event rows that call behaviour verbs like $Player/PlatformerMovement.jump() and $Player/WeaponKit.fire(), with the Scene dock showing the PlatformerMovement and WeaponKit behaviour children and the Inspector showing that behaviour's own knobs - Gravity Angle, Max Jumps, Coyote Time.](docs/previews/editor-hero.png)

It is a real Godot workspace, beside 2D / 3D / Script, and it opens an ordinary `.gd` as events: the sheet above *is* `platformer_shooter.gd`. Behaviours attach as child nodes and expose their knobs in the Inspector like any other node.

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

Delete the plugin and this script still runs. The reverse works too: **open *any* `.gd` as a sheet** - the round-trip is lossless and byte-identical, so you edit visually or in Godot's script editor with the two in sync. Measured over this repo's own 920 hand-written files, every code line but nine opens as structure in the sheet's own words; anything the vocabulary cannot match stays an honest, editable row rather than being reformatted behind your back.

**View > Generated GDScript** puts the compiled output beside the sheet, refreshed live as you edit:

![The same sheet with the Generated GDScript panel open beside it inside the Godot editor: on the left the numbered event rows, on the right the typed GDScript they compile to - class_name, an @export var, and a _physics_process reading Input.is_action_just_pressed - captioned as read-only and refreshed live as you edit.](docs/previews/editor-generated-code.png)

## Quick start

1. Copy `addons/eventforge/` and `addons/eventsheet/` into your Godot **4.5+** project (tested through **4.7 stable**). Optional: `eventsheet_addons/` for the 114 behavior packs. Removal is clean - see [uninstall](docs/GUIDE-UNINSTALL.md).
2. **Project Settings → Plugins** → enable **Godot EventSheets**.
3. Open the **EventSheet** tab in the main editor strip (next to 2D/3D/Script).
4. **New… → Platformer Starter**, add events (live search understands C3 phrases like *"every tick"*), and Run.

Everything else is in the **[documentation index](docs/README.md)** and inside the editor (**Tools > Manual**, or F1 on anything selected) - including the [migration guide for Construct users](docs/GUIDE-MOVING-FROM-ANOTHER-EVENT-SHEET-EDITOR.md), [common game patterns](docs/GUIDE-COMMON-GAME-PATTERNS.md), and [using EventSheets with your existing code](docs/GUIDE-USING-WITH-EXISTING-CODE.md).

## Why event sheets in Godot? (honest pros & cons)

**Pros**

- **You ship GDScript, not a black box.** Delete the plugin and your game still runs. Performance parity is a permanent, test-enforced contract.
- **It teaches Godot while you use it.** Every action's tooltip shows the GDScript it generates; ƒx expressions *are* GDScript; the GDScript panel maps every row to its lines and back.
- **Debug it like any GDScript.** Real breakpoints in the generated `.gd`, conditional breakpoints and paused-at-row from the sheet, Live Values / Event Trace on top.
- **A sheet is just `.gd`.** No `.tres`. Open any `.gd` as a sheet, edit it either way, paste GDScript and it converts to events.
- **C3 muscle memory works.** The grammar, the picker, behaviors-as-components and the input/audio vocabularies are designed against C3 conventions on purpose.
- **Scales.** A custom-drawn virtualized viewport keeps 10,000+ rows fluid with no per-row widgets.

**Cons**

- **It's a bridge, not a wall.** Complex logic eventually pulls you toward GDScript by design; to *never* see code, C3 still hides it better.
- **2D-first.** The 3D vocabularies, raycasts and movement packs are real, but deeper 3D still reaches for ƒx.
- **Some C3 plugins have no equivalent** (XML) - routed to the native Godot feature.
- **Experimental.** A large CI suite stands in for mileage it hasn't earned.

The deeper belief, in one line: the condition/action grid is the shape code already has - a trigger is a signal handler, conditions are the `if`, actions are its body, sub-events are nesting - so everything learned in a sheet transfers straight to scripting, and "graduating" to code is noticing you already understand the code your sheets have been writing.

## Feature tour

- **The editor** - two-lane rows, groups, regions, comments, drag/drop, batch edit, full undo/redo; Find & Replace, project-wide Find all references, Outline, Command Palette, type-a-sentence Ghost Row, Properties bar, Simple and Reading modes, themes, split views, session restore.
- **The language** - events, sub-events, Else / Else-if, the full loop and picking set, typed functions, enums, signals, match rows, setters/getters, Script blocks, `await`, autoload sheets, and the Custom Block API for your own row kinds.
- **Any script opens as a sheet** - lifecycle handlers as triggers, input branches as Keyboard/Mouse events, signal wiring as triggers, whole `.tscn` files as composite sheets; a coverage chip says how much reads as events, and every lift is byte-gated.
- **1,846 native ACEs** (98 triggers) across scenes, spawning, nodes, tweens, audio, cameras, lights, shaders, collisions, raycasts, files, multiplayer, UI, particles, tilemaps, input rebinding and more - plus a Helpers escape hatch so unmapped code stays an editable row.
- **114 behavior packs**, all authored as event sheets - movement and feel, AI, combat and stats, narrative, drawing and UI, lighting, shader effects, and system packs. See [docs/Addons/](docs/Addons/README.md).
- **Your own code is vocabulary with zero setup** - the picker lists your classes and autoloads as Actions / Conditions / Expressions; curate with a project catalog or `## @ace_*` comments; the ACE Studio, Extract to Function and Teach a Verb publish your own; `EventSheets.publish_pack` ships it.
- **The Manual, inside the editor** - Tools > Manual, F1 on anything, a reference page per object and behavior, tutorials you follow in your open sheet, and What's new.
- **Updating never rewrites your sheets** - a superseded verb keeps its id, its line and its place in the picker forever, and carries the address of the newer spelling; migrating, renaming and taking a pack's new version are receipts you read and buttons you press, each one undo step. Four contracts check themselves from a command line. ([guide](docs/GUIDE-UPDATING-AND-REFACTORING.md))
- **Tooling** - Project Doctor (dock / CLI / CI), live debugging (Live Values, Watch, Event Trace, Why didn't this fire?), Save Studio, Translation Studio (nine editor languages), a public [`EventSheets` API](docs/GUIDE-BUILDING-ON-EVENTSHEETS.md) and an opt-in MCP server.

## Current status

The latest tagged release is **`v0.17.0` - "Adopt Anything, Read Anything & Ask Why"**. Since then, on `main` and heading for the next tag ([CHANGELOG](CHANGELOG.md) has the full story):

- **The readability program** - every pack, script and scene opens in the sheet's own words, down to the long tail: patterns, match rows, the Hierarchy, and the 3D words.
- **The sheet's own chrome** - variable rows with their compiled echo, one Compare dialog, the Properties bar, Saved Views, Workspaces, Sheet ▸ Export.
- **Working with the running game** - one debugger with four tabs, runtime errors landed on their row, the Scene dock and sheet sharing one selection.
- **The editor-tool family** - all fifteen shapes Godot can be extended in, each a starter sheet - and the editor reading its own source.
- **Adopting a project you did not start** - the foreign-sheet importer, the tidiness sweep, one-click fixes.
- **Genre kits and accessibility** - pity, stealth noise, boss phases, mission clocks; reduced motion, dyslexia-friendly text, a no-flashing dial.
- **Playing together** - Godot's high-level multiplayer in sentences, byte-exact both ways, with the four silent networking mistakes caught by the Doctor.
- **Lighting, effects and collisions** - the light and the shader dial are the OBJECT; layers speak the project's own names; the Doctor knows the silent ways each does nothing.
- **The API is the vocabulary** - ordinary calls and property writes on known classes read as rows with zero authoring; curated tables upgrade them in place.
- **Files, and what a game may trust** - `user://` vs `res://` taught at the path field, guards written into the emitted line, user content arriving as data, never code.
- **An object's own state is a variable** - Declare states…, Is in / Go to / On entering, the live band and the Trail; the hand-written `match state:` machine opens as rows byte-exact. ([guide](docs/GUIDE-STATES.md))
- **Scenes, in the engine's own words** - layouts on top of the running game, `%name` as a word, 3D spawning, the tree's join/leave announcements, saving what a player built behind a data-only trust check, and undoable editor-tool edits. ([guide](docs/GUIDE-SCENES.md))
- **The refactor contract** - a moved verb carries a forwarding address, the head counts the rows that have one, and Migrate… shows every rewrite in both languages before proving each one twice. Renames list what they touch first; a pack update is a proposal with a tri-list; a merge's doubled local and half-finished file are named rather than met at runtime. ([guide](docs/GUIDE-UPDATING-AND-REFACTORING.md))
- **Autocomplete everywhere** - one seam, one popup, every name field; Quick add reads a whole typed sentence.

**Performance, measured** - on a fabricated project ten times this one (1,000 scripts, 300 scenes, 100 shaders, every pack installed): enabling the plugin costs **270 ms**, the first sheet tab **2,310 ms**, one keystroke in a completing field **2.2 ms**, and a 4,000-line script opens in **7.4 s**; eleven such budgets are tests.

**The editor reads itself** - the plugin's own source opens as event sheets: **920 files, 918 of them at zero script blocks, and 89% of those rows in the sheet's own words**, round-tripped byte-exact under a measured ceiling on every run.

**Quality** - 20,791 assertions across 725 test files, all green, CI-gated on every push; byte-exact golden round-trips guard the lossless rules; generated code never depends on the plugin and is performance-identical to hand-written GDScript - all test-enforced. **Verified on Godot 4.7 stable.**

## Milestones

Every release has full notes in [CHANGELOG.md](CHANGELOG.md); the one-line themes:

| Release | Theme |
|---|---|
| `v0.1` - `v0.5` | Editor + compiler + lossless pairing, rich variables, C3 coverage, 3D vocabulary, breakpoints, Audio, node picker |
| `v0.6` - `v0.8` | Inspector attributes, addon composition, Live Values, singleton sheets; Rename Everywhere, snippets, if/elif/else reverse-lift; Godot 4.7, merge driver, Find References, opt-in MCP |
| `v0.9.0` / `v0.9.5` | Frame-spreading, Juice, code-free authoring, first-class UI / raycast / particles / tilemaps / shaders; `.gd`-default sheets, `@export` variables + drawers |
| `v0.10.0` | In-sheet authoring: ACE Studio, per-function shell-lift, Ghost Row, error→row, the Custom Block API |
| `v0.11.0` | Structure and vocabulary: regions, Look Gallery, localisation vocabulary, terse providers, Extract / Teach a Verb, the public `EventSheets` API |
| `v0.12.0` | The Inspector Designer: eight drawers, custom resources, HUD Kit / Scene Flow / Dialogue Kit, a lazily-built editor |
| `v0.13.0` | Genre toolkits: the idle kit, ECS-lite Systems, Advanced Random behind one seed, auto-registering pack builders |
| `v0.14.0` | Pathfinding and game feel: Platformer Pathfinding + Nav Agent 3D, the AI drive seam, FPS movement tech, Juice cameras, the Input Map picker, a ~21x faster boot |
| `v0.15.0` | Save anything: the save-state seam on 18 packs, six formats, the Save Studio, the player-or-AI input seam, BBCode comments |
| `v0.16.0` | Open anything, publish anything: nine editor languages, the Custom Resource wizard, `publish_pack`, the reads-like-code pass, 88 raycasting verbs + two labs, the curation pass |
| `v0.17.0` | Adopt anything, read anything: real `.gd` files open as rows byte-exact, your classes as vocabulary, Construct-style reading, the pattern / dev-experience / i18n waves, docs inside the editor |
| _Next_ | Everything under **Current status** above - all on `main` now; then whatever you ask for |

## Project layout

| Path | What it is |
|---|---|
| `addons/eventforge/` | Data model, compiler, importer, builtin ACEs, runtime bridge |
| `addons/eventsheet/` | The editor: dock, virtualized viewport, renderer, picker, themes, lint, the Manual, MCP server |
| `eventsheet_addons/` | Zero-config ACE addons + the 114 behavior packs |
| `demo/` | 28 showcases (each a `.gd` that is BOTH the sheet and the compiled script, with a scene where it is playable) and the bundled themes |
| `tests/` | Headless suite - `run_tests.gd` (full) and `run_perf.gd` (fast gate) |
| `docs/` | Contract specs + guides (migration, recipes, MCP, glossary, uninstall) |

## Verifying a change

```text
godot --headless --path . --script tests/run_perf.gd     # fast, headless-safe suite
godot --headless --path . --script tests/run_tests.gd    # full suite
```

Every feature lands with tests, a CHANGELOG entry, and its spec updated. Pushes and PRs run the headless suite; pushing a `v*` tag stamps `plugin.cfg` and publishes a GitHub Release.

## Contributing & license

[CONTRIBUTING.md](CONTRIBUTING.md) has the dev setup, the compatibility covenant, and how to add ACEs, addons, packs, and themes. The project improves fastest through real-world reports - [open an issue](../../issues/new/choose) if something breaks or a C3 workflow feels wrong. MIT licensed (`LICENSE`).

## 🙏 Acknowledgments

This plugin stands on the shoulders of the tools that made visual, code-optional game logic mainstream:

- **[Construct](https://www.construct.net/)** - the direct inspiration. The event-sheet grammar, the ACE (Action / Condition / Expression) model, the picker, and behaviors-as-components are all designed against Construct 3's conventions on purpose, so C3 muscle memory carries over.
- **[Clickteam Fusion 2.5](https://www.clickteam.com/clickteam-fusion-2-5)** - a foundational event-editor whose event-grid lineage shaped the whole "events read like sentences" idea.
- **[Scratch](https://scratch.mit.edu/)** - for proving that visual, block-based programming is a real on-ramp to building software, not a toy.
- **[Godot Engine](https://godotengine.org/)** - the open-source engine this is built on and for; every sheet compiles to plain, idiomatic GDScript that runs with zero dependency on this plugin.

These are independent projects and trademarks of their respective owners; this plugin is not affiliated with or endorsed by any of them.

## 🤖 AI Use Disclosure

**This project is built with heavy use of AI tooling, and I want that to be completely clear
up front - not something you discover later.** Much of the implementation work across the
plugin's code, the bundled behavior packs, the documentation, and the test suite was produced
with large language models. The direction, design, and domain knowledge are mine: what to
build, how event sheets should feel, which C3 conventions matter and why, what is correct
Godot practice, and what ships versus what gets rejected. Every change is reviewed and gated
by the project's own verification: the full test suite, byte-exact round-trip checks on
generated code, and rendered previews of UI work.

It started as a pet project and it still is one: an experiment to see whether a full
visual-scripting solution could actually be built this way - steering AI with deep
domain-specific knowledge of event sheets (Construct, Clickteam Fusion, GDevelop lineage)
and of Godot itself - and how far that approach could carry a real, working tool. This
repository is the honest answer so far.

**If you choose not to use this addon because of ethical concerns about AI, that is a
completely legitimate choice and I respect it fully - no argument, no judgment, and no hard
feelings.** People draw this line in different places for real reasons, and I do not fault
anyone for drawing it somewhere other than where I did. The project is MIT licensed and will
still be here if that ever changes; if it does not, I wish you well and thank you for reading
this far.
