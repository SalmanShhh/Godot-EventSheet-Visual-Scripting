# Godot EventSheets

**Visual event sheets for Godot 4 that compile to plain, readable GDScript.**

The point is **speed-to-game**: whether you've never written code, want logic to pour out faster, or you're mid-jam - events get you from idea to *playing it* in minutes, and keep up when the project balloons to thousands of events.

> [!NOTE]
> **Early.** Every feature ships with tests (17,695 CI-gated assertions across 624 test files, byte-exact round-trip gates, performance-parity contracts), but the project hasn't yet earned real-world mileage and may see sweeping changes between releases. Pin a release tag and report what you hit - issues are read and acted on.

Godot EventSheets (engine codename *EventForge*, the prefix on internal class names) brings the C3 event-sheet workflow into the Godot editor: a fast visual editor where events read like sentences, and a compiler that turns every sheet into **typed, idiomatic GDScript** - no runtime interpreter, no plugin dependency in your exported game, and **zero performance difference from hand-written code** (a tested contract).

![The EventSheet workspace inside the Godot editor: a plain platformer_shooter.gd opened as numbered two-lane event rows that call behaviour verbs like $Player/PlatformerMovement.jump() and $Player/WeaponKit.fire(), with the Scene dock showing the PlatformerMovement and WeaponKit behaviour children and the Inspector showing that behaviour's own knobs - Gravity Angle, Max Jumps, Coyote Time.](docs/previews/editor-hero.png)

It is a real Godot workspace, beside 2D / 3D / Script, and it opens an ordinary `.gd` as events: the sheet above *is* `platformer_shooter.gd`. Behaviours attach as child nodes and expose their knobs in the Inspector like any other node.

![The event sheet canvas up close: two-lane condition/action rows, type-annotated variables with @export badges and an Inspector-grouping chip, a colored Combat region wrapping a Gameplay group, trigger arrows, a negated condition, an inline GDScript block, comments, and a sheet-built heal() function.](docs/previews/editor-event-sheet.png)

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

Delete the plugin and this script still runs. The reverse works too: **open *any* `.gd` as a sheet** - the round-trip is lossless and byte-identical, so you edit visually or in Godot's script editor with the two in sync. And "opens as a sheet" means it *reads* as one: measured over the 628 hand-written files of this repo's own source, **every code line but nine arrives as structure** (functions, events, actions, notes, declarations - 626 of the 628 files at zero verbatim code blocks, 9 block lines across 186,504 lines), in the sheet's own words - lifecycle handlers as triggers, `_unhandled_input` branches as Keyboard / Mouse events, hand-written signal handlers with payload chips, `A if C else B` as a sub-event pair with Else, and every published function as a Function block. A statement the vocabulary does not match stays an honest single-statement row, never a mangled one, and a shape the compiler cannot reproduce byte-exactly is left as an editable Script block rather than reformatted behind your back.

**View > Generated GDScript** puts the compiled output beside the sheet, refreshed live as you edit:

![The same sheet with the Generated GDScript panel open beside it inside the Godot editor: on the left the numbered event rows, on the right the typed GDScript they compile to - class_name, an @export var, and a _physics_process reading Input.is_action_just_pressed - captioned as read-only and refreshed live as you edit.](docs/previews/editor-generated-code.png)

## Quick start

1. Copy `addons/eventforge/` and `addons/eventsheet/` into your Godot **4.5+** project (tested through **4.7 stable**). Optional: `eventsheet_addons/` for the 102 behavior packs. Removal is clean - see [uninstall](docs/GUIDE-UNINSTALL.md).
2. **Project Settings → Plugins** → enable **Godot EventSheets**.
3. Open the **EventSheet** tab in the main editor strip (next to 2D/3D/Script).
4. **New… → Platformer Starter**, add events (live search understands C3 phrases like *"every tick"*), and Run.

Everything is in the **[documentation index](docs/README.md)** and inside the editor (**Tools > Manual**, or F1 on anything selected). The ones most people want first:

- **Coming from Construct?** The [migration guide](docs/GUIDE-MOVING-FROM-ANOTHER-EVENT-SHEET-EDITOR.md) maps every concept, behavior, and plugin to its home here.
- **Learning by building?** [Common game patterns](docs/GUIDE-COMMON-GAME-PATTERNS.md), [Block Styles](docs/GUIDE-BLOCK-STYLES.md) (the one-page field guide to reading any sheet), the [recipes](docs/GUIDE-RECIPES.md), [GDScript-basics coverage](docs/GDSCRIPT-BASICS-COVERAGE.md), [Working with lists](docs/GUIDE-WORKING-WITH-LISTS.md) and [raycasting](docs/GUIDE-SEEING-WHAT-IS-THERE-RAYCASTING.md).
- **Making your own stuff?** [Custom resources](docs/GUIDE-CUSTOM-RESOURCES.md), [editor tools](docs/GUIDE-EDITOR-TOOLS.md), [Custom ACEs](docs/GUIDE-CUSTOM-ACES.md) + [Custom Blocks](docs/GUIDE-CUSTOM-BLOCKS.md), and [the ACE Studio](docs/GUIDE-USING-THE-ACE-STUDIO.md).
- **Existing project?** [Using EventSheets with your code](docs/GUIDE-USING-WITH-EXISTING-CODE.md) - sheets call (and are called by) your GDScript, and any of it opens as a readable sheet.

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
- **2D-first.** Most packs target 2D; the 3D side has the Node3D/CharacterBody3D/Camera3D vocabularies, raycast/world-query ACEs, the FPS Controller, Nav Agent 3D, Juice 3D and the 3D movement packs - deeper 3D still reaches for ƒx.
- **Some C3 plugins have no equivalent** (Multiplayer, XML) - routed to the native Godot feature.
- **Experimental.** A large CI suite stands in for mileage it hasn't earned.

## Why I believe event sheets line up with real scripting

Most visual scripting asks you to learn a model you'll throw away the day you write code. I believe the event-sheet model is different in kind, not degree: **the condition/action grid is the shape code already has**, so everything you learn in a sheet transfers straight to scripting - and everything you know from scripting reads straight off a sheet.

- **Every row is the code it becomes.** A trigger is a signal handler. The condition column is the `if`. A For-Each or pick filter is the `for` loop. The action column is the statements in its body. Sub-events are nesting. This project's compiler makes the mapping literal: those exact rows become that exact GDScript, byte for byte, both directions.
- **Node graphs don't have that property.** In a wire-and-node graph, control flow is spatial and the picture resembles nothing in the code it becomes - the gap Godot retired VisualScript over. A sheet keeps what code is made of - order, guards, loops, nesting - and only replaces the *syntax* with a picker and readable sentences.
- **The discipline is enforced.** A standing rule in this codebase: branching is a condition, an effect is an action, iteration is a loop row - never a text blob or a special panel. OR-blocks, switch/case, functions, setters/getters, async waits and For-Each rows from behavior packs all landed on the same grid.
- **Expressions stay textual on purpose.** Where visual stops paying (arithmetic, comparisons), the ƒx field *is* a GDScript expression with live validation - the honest boundary between structure and computation.
- **So the exit ramp is flat.** The sheet and the script are the same artifact; "graduating" to code is noticing you already understand the code your sheets have been writing.

## Feature tour

- **The editor** - two-lane condition/action rows with object icons, event numbers, groups, regions, BBCode comments; drag/drop, multi-select, batch edit, Replace Object References, full undo/redo; Find & Replace with a live filter, **Find all references** across the whole project with a results bar under the sheet, Outline, Command Palette, bookmarks, Go to event; type-a-sentence adds through the **Ghost Row** (suggestion chips that learn your vocabulary), recent values per parameter, number scrubbing, node-drop onto parameters; a **Properties bar** beside the canvas that edits the selected row's parameters in place; **Simple mode**, **Reading mode**, Compact rows, the **Object bar**, **Object properties**, an **Instance variables** table you edit, Collapse / Expand to level, 50% to 200% zoom remembered per layout, copy the selection as plain text, session restore, split / detached views, ten bundled themes.
- **The language** - events, sub-events, Else / Else-if, the full loop and picking set (For / For Each / Repeat / While + `loopindex`), functions (typed params, returns, publishable as actions, conditions and expressions, Inspector buttons), stateful conditions, enums, signals, match rows, setters / getters, doc comments, Script blocks, `await`, autoload sheets, variables with every Inspector option in plain language, the Custom Block API for your own row kinds.
- **Any script opens as a sheet** - functions as Function blocks, bodies as condition / action rows, comments as comment rows, `#region` as groups, commented-out code as disabled rows, collection literals as editable Declare rows, and the sheet's own words throughout (On start of layout / On created / On destroyed, Every tick, Keyboard / Mouse / Gamepad / Touch triggers, Wait X seconds then …, Set return value, Is same object, ≥ / ≤, project names for input actions and physics layers, enum members by name, clean numbers). A property's setter reads as an **On &lt;name&gt; set** trigger and its getter as an expression, a `Timer` node reads as the sheet's Timer behavior, a tween chain reads as one Tween action per row, a signal the editor wired in the scene reads as the trigger calling that object's function, and a whole `.tscn` opens as one sheet with an object bar per script. A parse error shows on the row it belongs to; a coverage chip on the Include bar says how much of the file reads as events. Every one of those lifts is byte-gated.
- **1,578 native ACEs** (and 54 triggers) - Tween, Scene flow, Audio, sprites and cameras, Nav, Math and Random, Color, every kind of raycast in 2D and 3D, Collision queries, Nodes, Project / File utilities, runtime signal wiring, UI, particles, AnimationTree, tilemaps, shaders, physics joints, input rebinding, seeded procedural generation, ECS-lite Systems, plus a **Helpers** escape hatch so unmapped code still stays an editable row.
- **102 behavior packs**, all authored as event sheets - 84 of them with an icon, starred hero actions and a 15+ use-case guide, the other 18 companion data assets and loaders documented inside their partner's guide - movement and feel (Platformer + Pathfinding, 8-Direction, Car, FPS Controller, Juice 2D / 3D …), AI (State Machine, Line of Sight, UtilityBrain, HTN / UHTN), combat and stats, the idle kit, narrative and content (Storylet Weaver, Dialogue Kit, Quest, Encounter Timeline …), drawing and UI, and system packs (Save System, Event Bus, Named Scenes, Game Settings, Debug Overlay, Platform Info …). See [docs/Addons/](docs/Addons/README.md).
- **Your own code is vocabulary with zero setup** - the picker lists your project's classes and autoloads with methods as Actions / Conditions / Expressions, properties as Set / Get and signals as triggers; rename / recategorize / hide from a project catalog or bake `## @ace_*` comments in; **Sheet ▸ Custom Actions…** and the ACE Studio author actions, conditions and expressions without code; **Extract to Function** and **Teach a Verb** publish your own; drop a `class_name` script in `eventsheet_addons/` and it is a provider; `EventSheets.publish_pack` ships it.
- **The Manual, inside the editor** - Tools > Manual / F1 = help for the selected item / `?` prefix: the guides, every addon and module guide, a reference page per object and behavior, a glossary for readers coming from another event-sheet editor, one search box (Ctrl+Enter adds the action at the caret), examples that draw themselves from real rows, Explain This Row, step-by-step **tutorials** you follow in a throwaway scratch sheet, and a **What's new** page.
- **Tooling** - Project Doctor (dock / CLI / CI), export integrity, compile-on-save, git-`textconv` diffs, live debugging (Live Values, Watch, Event Trace, hit counts, Why didn't this fire?), Test Sheets, Save Studio, Translation Studio (nine editor languages), Report an Issue, a public **`EventSheets` API** ([guide](docs/GUIDE-BUILDING-ON-EVENTSHEETS.md)) and an opt-in MCP server.

## Current status

The latest tagged release is **`v0.17.0` - "Adopt Anything, Read Anything & Ask Why"**: a hand-written `.gd` opens as rows (88.1% verbatim blocks to zero over 206 real files, byte-exact), your own classes as zero-setup vocabulary, rows that read like Construct's, the pattern and developer-experience waves, save slots and recovery, shipping in nine languages, and the documentation inside the editor. Since then, on `main` and heading for the next tag:

- **The readability program** - every pack, script and scene opens in the sheet's own words (Function blocks, Object ▸ action rows, Reading mode, one sentence grammar shared by typed and picked rows, the Object bar and Object properties, the Input Map as an object, one sentence per variable, events named by their number, threaded open with a progress strip, parse errors on rows, Collapse / Expand), now reaching the long tail: the PATTERNS several lines make together, the Godot systems a script is built from, match rows and data types, the **Hierarchy** in its two words (add child, remove from parent, with the follow-flags read back off whatever wrote them) and a Hierarchy pane in Object properties, and **the 3D words** - directions, orbits, blend trees, and the world's look.
- **The parts of a sheet that are not events** - one sentence per variable (`Instance number speed = 200`) with the declaration it compiles to echoed beside it and a **View ▸ Variable rows** dial for how much of it is drawn, a head that is the head of the file (one band per line, nothing folded, each with its own control), one **Compare** dialog in place of five, one-line group heads with a bracket down the body, regions drawn as the fold marks they are, and a parameters dialog titled with the row it is about to write.
- **The sheet's own chrome** - a Properties bar, Find all references with a results bar, zoom, the sheet as plain text, an Instance variables table, global variables added from any sheet, Arrange by, Saved Views, Workspaces, and **Sheet ▸ Export** to a picture, a PDF or Markdown with figures.
- **Working with the running game** - one debugger with four tabs, runtime errors re-said in the sheet's own words and landed on the row they belong to, and the Scene dock and the sheet sharing one selection in both directions.
- **The editor-tool family** - all fifteen shapes Godot can be extended in, each a starter sheet with a Run now button where you write it, and **the editor reading its own source**: the plugin's own repository opens as sheets, measured per group by the Doctor.
- **Adopting a project you did not start** - an event sheet from another editor imported honestly (what came across, and what it says instead of what did not), the Doctor's tidiness sweep, and one-click fixes.
- **Genre kits and accessibility** - four game shapes the sheet says by name (pity, stealth noise, boss phases, mission clocks) with a starter apiece, Tilt and swipe input, and the accessibility work on both sides: reduced motion, dyslexia-friendly text and rows read aloud in the editor, a text-size scale and a no-flashing dial for the player.
- **The Manual** - docked, F1 = help for the selected item, reference pages, glossary, search, tutorials in a scratch sheet, What's new, and the optional **Ask** box that answers in rows rather than in code.

Opening the FPS Controller pack as a sheet went from 6.8 s to 0.9 s and the editor boot subtree from 583 ms to 193 ms.

**The editor reads itself** - the plugin's own source opens as event sheets in its own repository: **628 files, 626 of them at zero script blocks (9 block lines in 145,101 rows), and 89% of those rows in the sheet's own words**. A rotating sample is round-tripped byte-exact and held under a measured per-group ceiling on every run (`tests/plugin_reads_itself_test.gd`), and Tools ▸ Project Doctor reports the same numbers per group.

**Quality** - 17,695 assertions across 624 test files, all green, CI-gated on every push; byte-exact golden round-trips guard the lossless rules; the save backend is pinned across all 18 seams and six formats; showcases are live-verified on camera. **Verified on Godot 4.7 stable.** Generated code never depends on the plugin, templates bake at apply time, and output is performance-identical to hand-written GDScript - all test-enforced.

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
| _Next_ | The readability program down to the long tail, the Hierarchy and the 3D words, the sheet's own chrome, the debugger and scene linking, the fifteen editor-tool shapes, the editor reading its own source, the foreign-sheet importer, the genre kits, accessibility and the Manual - all on `main` now; then whatever you ask for |

## Project layout

| Path | What it is |
|---|---|
| `addons/eventforge/` | Data model, compiler, importer, builtin ACEs, runtime bridge |
| `addons/eventsheet/` | The editor: dock, virtualized viewport, renderer, picker, themes, lint, the Manual, MCP server |
| `eventsheet_addons/` | Zero-config ACE addons + the 102 behavior packs |
| `demo/` | 27 showcases (each a `.gd` that is BOTH the sheet and the compiled script, with a scene where it is playable) and the bundled themes |
| `tests/` | Headless suite - `run_tests.gd` (full) and `run_perf.gd` (fast gate) |
| `docs/` | Contract specs + guides (migration, recipes, MCP, glossary, uninstall) |

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
