# Godot EventSheets

**Visual event sheets for Godot 4 that compile to plain, readable GDScript.**

The point is **speed-to-game**: whether you've never written code, want logic to pour out faster, or you're mid-jam - events get you from idea to *playing it* in minutes, and keep up when the project balloons to thousands of events.

> [!NOTE]
> **Early.** Every feature ships with tests (10,960+ CI-gated assertions across 472 test files, byte-exact round-trip gates, performance-parity contracts), but the project hasn't yet earned real-world mileage and may see sweeping changes between releases. Pin a release tag and report what you hit - issues are read and acted on.

Godot EventSheets (engine codename *EventForge*, the prefix on internal class names) brings the C3 event-sheet workflow into the Godot editor: a fast visual editor where events read like sentences, and a compiler that turns every sheet into **typed, idiomatic GDScript** - no runtime interpreter, no plugin dependency in your exported game, and **zero performance difference from hand-written code** (a tested contract).

![The EventSheet workspace inside the Godot editor: a plain platformer_shooter.gd opened as numbered two-lane event rows that call behaviour verbs like $Player/PlatformerMovement.jump() and $Player/WeaponKit.fire(), with the Scene dock showing the PlatformerMovement and WeaponKit behaviour children and the Inspector showing that behaviour's own knobs - Gravity Angle, Max Jumps, Coyote Time.](docs/previews/editor-hero.png)

It is a real Godot workspace, beside 2D / 3D / Script, and it opens an ordinary `.gd` as events: the
sheet above *is* `platformer_shooter.gd`. Behaviours attach as child nodes and expose their knobs in
the Inspector like any other node, so nothing here is a parallel universe you have to leave Godot for.

And close up, a row at a time:

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

Delete the plugin and this script still runs. The reverse works too: **open *any* `.gd` as a sheet** - the round-trip is lossless and byte-identical, so you edit visually or in Godot's script editor with the two in sync.

And "opens as a sheet" means it *reads* as one. Measured over 206 hand-written files in this repo - ordinary style-guide GDScript nobody wrote for a demo - **every code line arrives as structure** (functions, events, actions, notes, declarations): zero verbatim code blocks across 25,974 lines, with a byte-exact round-trip on every file. A statement the vocabulary does not match stays as an honest single-statement row that reads as a sentence, never a mangled one. Beginner spellings lift too - inferred `:=` variables and untyped `func _physics_process(delta):` headers re-emit exactly as written - and a hand-written `enum` + `match` state machine opens as the machine it is: one tick event, a `◆ State:` row per branch, transitions as nested condition rows whose guards read in plain words ("Can See Player", with a small ƒ badge saying the check is computed). There is a suite gate on that number, because a fixture written to suit the lifter cannot notice that real code does not look like it.

You never have to take that on trust. **View > Generated GDScript** puts the compiled output beside the
sheet, refreshed live as you edit, so the code you are shipping is always one panel away:

![The same sheet with the Generated GDScript panel open beside it inside the Godot editor: on the left the numbered event rows, on the right the typed GDScript they compile to - class_name, an @export var, and a _physics_process reading Input.is_action_just_pressed - captioned as read-only and refreshed live as you edit.](docs/previews/editor-generated-code.png)

## Quick start

1. Copy `addons/eventforge/` and `addons/eventsheet/` into your Godot **4.5+** project (tested through **4.7 stable**). Optional: `eventsheet_addons/` for the 91 behavior packs. Removal is clean - see [uninstall](docs/GUIDE-UNINSTALL.md).
2. **Project Settings → Plugins** → enable **Godot EventSheets**.
3. Open the **EventSheet** tab in the main editor strip (next to 2D/3D/Script).
4. **New… → Platformer Starter**, add events (live search understands C3 phrases like *"every tick"*), and Run.

Everything is in the **[documentation index](docs/README.md)**. The ones most people want first:

- **Coming from Construct?** The [C3 migration guide](docs/GUIDE-MOVING-FROM-ANOTHER-EVENT-SHEET-EDITOR.md) maps every concept, behavior, and plugin to its home here.
- **Learning by building?** [Common game patterns](docs/GUIDE-COMMON-GAME-PATTERNS.md) shows state machines, timers, cooldowns, pooling, timelines and saving as rows, and [Block Styles](docs/GUIDE-BLOCK-STYLES.md) is the one-page field guide to reading any sheet. The [recipes](docs/GUIDE-RECIPES.md) walk a platformer, health, pickups, and debugging end to end. [GDScript-basics coverage](docs/GDSCRIPT-BASICS-COVERAGE.md) shows every language fundamental as sheet rows. [Working with lists](docs/GUIDE-WORKING-WITH-LISTS.md) and [raycasting](docs/GUIDE-SEEING-WHAT-IS-THERE-RAYCASTING.md) are the two vocabularies most games reach for first - the raycasting guide ships two playable labs that draw every cast as it happens.
- **Making your own stuff?** [Custom resources](docs/GUIDE-CUSTOM-RESOURCES.md) (data assets from a 3-question wizard), [editor tools](docs/GUIDE-EDITOR-TOOLS.md) (one-click chores), [Custom ACEs](docs/GUIDE-CUSTOM-ACES.md) + [Custom Blocks](docs/GUIDE-CUSTOM-BLOCKS.md) (the extension surfaces), and [the ACE Studio](docs/GUIDE-USING-THE-ACE-STUDIO.md) (define a verb without code).
- **Systems + content:** [data-driven addons](docs/GUIDE-DATA-DRIVEN-ADDONS.md) and [games](docs/GUIDE-DATA-DRIVEN-GAMES.md), [composition/ECS-lite](docs/GUIDE-COMPOSITION-SYSTEMS.md), [procedural generation](docs/GUIDE-PROCEDURAL-GENERATION.md), [player-or-AI input](docs/GUIDE-PLAYER-AND-AI-INPUT.md), [saving and loading](docs/GUIDE-SAVING-AND-LOADING.md) + [the Save Studio](docs/GUIDE-USING-THE-SAVE-STUDIO.md).
- **Existing project?** [Using EventSheets with your code](docs/GUIDE-USING-WITH-EXISTING-CODE.md) - sheets call (and are called by) your GDScript.

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
- **Some C3 plugins have no equivalent** (Multiplayer, XML) - routed to the native Godot feature.
- **Experimental.** A large CI suite stands in for mileage it hasn't earned.

## Why I believe event sheets line up with real scripting

Most visual scripting asks you to learn a model you'll throw away the day you write code. I believe the event-sheet model is different in kind, not degree: **the condition/action grid is the shape code already has**, so everything you learn in a sheet transfers straight to scripting - and everything you know from scripting reads straight off a sheet.

- **Every row is the code it becomes.** A trigger is a signal handler. The condition column is the `if`. A For-Each or pick filter is the `for` loop. The action column is the statements in its body. Sub-events are nesting. Read an event left-to-right, top-to-bottom and you are reading the structure of the emitted function - the mapping is 1:1, and this project's compiler makes it literal: those exact rows become that exact GDScript, byte for byte, both directions.
- **Node graphs don't have that property.** In a wire-and-node graph, control flow is spatial - execution follows wires that can wander anywhere on a canvas, and the picture resembles nothing in the code it becomes. Godot retired VisualScript in 4.0 for exactly that gap: the graph neither beat text for programmers nor taught text to beginners. A sheet keeps what code is made of - order, guards, loops, nesting - and only replaces the *syntax* with a picker and readable sentences.
- **The discipline is enforced, not aspirational.** A standing design rule in this codebase: branching is a condition, an effect is an action, iteration is a loop row - features are never bolted on as text blobs or special panels. OR-blocks, switch/case, functions, setters/getters, async waits, and For-Each verbs from behavior packs all landed on the same left-conditions/right-actions grid, because the grid is sufficient - the same way statements and expressions are sufficient in a language.
- **Expressions stay textual on purpose.** Where visual stops paying (arithmetic, comparisons), sheets don't wrap math in boxes-and-wires - the ƒx field *is* a GDScript expression with live validation. That's the honest boundary between structure (visual) and computation (text), and it's exactly where programmers already draw it.
- **So the exit ramp is flat.** Because the sheet and the script are the same artifact here (open any `.gd` as a sheet, edit either, byte-identical round-trip), "graduating" to code isn't a rewrite - it's noticing you already understand the code your sheets have been writing all along. That is the test a visual scripting model should pass, and it's the one node graphs fail.

## Feature tour

**The editor** - Two-lane condition/action rows, object icons + labels, stable **event numbers in the margin** (with Go to Event), flat cells, drag/drop with insertion arrows, groups, colored BBCode comments, inline colour-swatch picking (click the swatch, pick visually, **saved palette** included), drag-a-node-onto-a-param, **drag a numeric parameter's label sideways to scrub its value** (Shift for fine, Ctrl for coarse), drag-an-Inspector-property-into-a-row (a pre-filled Set Property action), right-click a node > **Connect Signal to Event Sheet**, multi-select with **Select All Events Using This**, **Replace Object References** (autocompleted) and **per-param batch edit**, copy/paste, full undo/redo. **Find & Replace (Ctrl+F)** with a **live Filter lens**, script-editor shortcuts (F9 breakpoints, Ctrl+/ toggle, Alt+↑↓ move, Ctrl+M bookmarks with a C3-style panel, arrow-through-cells), an **Outline** jump panel, a **Command Palette (Ctrl+P)**, single-key **type-a-sentence adds** (E/C/A open the Ghost Row, which greets you with **suggestion chips of your most-used verbs** and **learns your vocabulary as you type**), **last-5 recent values** on every parameter field, a pinned **group breadcrumb** on long sheets, a **Compact Rows** density toggle, **Simple Mode**, session restore, multi-view (split/detached/linked), themeable down to every token, with ten bundled presets (Dracula, Nord, Gruvbox, Monokai, Solarized Light, Catppuccin Mocha, High Contrast, Soft Light, Mockup Slate and a Designer Template) plus a Godot-adaptive default - every one of them dresses published verbs in its own palette.

![The Add Condition picker open over the Godot editor: a search box across every action, condition and trigger, Favorites and Recent rails, and the category tree - Compare, Run Context, Input, Variables, Node, ShapeCast2D, ShapeCast3D, Time, General Conditions and more.](docs/previews/editor-ace-picker.png)

![The Create Variable dialog over the Godot editor: plain-language fields - Scope, Name, Type: Number with a "Whole numbers only" tick, Default, Description, a Constant flag and "Editable in the Inspector (a designer property)" - no GDScript annotation to remember.](docs/previews/editor-variable-dialog.png)

**The language** - Events, sub-events, Else/Else-If chips, the **full C3 loop & picking set** (For / For Each / ordered / Repeat / While, plus a C3-style **loopindex** on any loop), **functions** (typed params, custom returns, publishable as ACEs, one-field **Inspector buttons**), stateful conditions, enums (single- or multi-line), signals, match rows, setter/getter properties, doc comments with a BBCode bar, GDScript blocks, `await`, and Autoload sheets. Type `self` in any ƒx field and the **Self section** answers C3's `Self.` reflex - your variables, your object's properties under both spellings (`X · position.x`), your functions, and your attached behaviours as `$PackName.knob` chains, grounded to the selected node's real children and, while Live Values streams, to the **running game's** - runtime-attached behaviours included. Variables get **every Godot inspector option** in plain language with a live "Ships as:" strip, a **visually-designed Inspector** (eight drawers including editable tables), and Inspector grouping by drag. The **Custom Block API** registers your own non-ACE row kinds in ~30 lines - Add-menu, dialog, and byte-exact round-trip included.

**Existing code opens as rows, not as a code wall** - a hand-written `.gd` arrives with its functions as function rows, their bodies as condition/action rows, its comments as real comment rows you can drag and disable, and its class prelude folded into one **Class setup** strip. A multi-line collection literal becomes a **Declare** action - `Declare waves - Dictionary, 3 entries` - with each entry on its own editable row and no bracket lines anywhere; right-click for Add/Edit/Remove Entry, or double-click an entry to edit it in place. The same treatment applies to a file-scope `const` table. Every one of those lifts is byte-gated: a shape the compiler cannot reproduce exactly is left as honest, editable GDScript rather than reformatted behind your back.

**1,200+ native ACEs** - Tween, Scene flow, Audio, sprites & cameras, Nav, Math & Random, Color, **every kind of raycast in 2D and 3D** (RayCast and ShapeCast nodes, one-off ray/point/shape/motion queries, camera picking) & Collision queries, Nodes, Project/File utilities, runtime signal wiring, UI/menu, particles, AnimationTree, tilemaps, shaders, physics joints, input rebinding, seeded procedural generation, ECS-lite Systems queries over groups, and a **Helpers** escape hatch (Set/Get Property, Call Method, Run GDScript, Inline If) so unmapped code still stays an editable row.

**91 behavior packs**, all authored as event sheets, each with its own icon, class description, and starred hero verbs. By family:

- **Movement & feel** - Platformer (+ jump-graph **Platformer Pathfinding**), 8-Direction, Tile/Slide Movement, Car + **Physics Car**, Sine/Orbit/Bullet/Move To/Follow (with 3D twins + **Nav Agent 3D**) + **Follow A Path**, Spring, Tween, Fade, Flash, Rotate, Bound To + Wrap, **FPS Controller** (crouch/slide/wall tech, coyote time), **Juice** 2D + 3D (shake/recoil/bob/zoom/slowmo/hitstop/tints).
- **AI** - State Machine, Line of Sight 2D/3D, **UtilityBrain** (response-curve scoring), HTN Agent, and **UHTN Planning** (Utility AI ranking HTN methods live, whole plans as **UHTNPlanResource** `.tres` grids).
- **Combat & stats** - Health (shield pools), Weapon Kit, **Checkpoint** (respawn through the pool's `reset()` seam), Simple Abilities (+ **AbilitySetResource** loadouts), **StatForge** buff-stack stats (+ **StatSheetResource**).
- **Economy & idle** - Currency Ledger, **Loot Table** (+ `.tres` tables), **Priced Tables** (vendors, kiosks, toll gates and skill trees as one `.tres` of priced entries, spending through whatever wallet answers), SkinVault (+ catalog `.tres`), and the full idle kit: Big Numbers (+ a Decimal type), Idle Generator, Click Power, Boosts, Upgrades, Prestige, Milestones.
- **Content & narrative** - Storylet Weaver, Dialogue Kit, **Encounter Timeline** (spawn beats on a schedule - waves, boss phases, tutorial pacing, ambient traffic - pooled when a pool is there), ProcRoom (seeded room graphs), Advanced Random (one seed drives them all), Random Table `.tres`, **Quest** (`.tres` objectives and chains, journal text one expression away), **Interaction** (focus the nearest interactable), **Phase Cycle** (self-ticking day / night), **Home & Leash**.
- **Drawing & UI** - Drawing Canvas (+ prefabs), Decal Painter, HUD Kit, Scene Flow, ComboBox, Virtual Cursor, Drag & Drop.
- **System** - Save System (slots, autosave the sheet can veto, save upgrades, Local-Storage-shaped keys), Timer, Time Slicer, Run In Background, ObjectPool, **Event Bus** (named channels with a payload), **Named Scenes** (no `res://` path in a row), **Game Settings** (settings that declare themselves), **Debug Overlay** (values, bars and marks on the game, off unless a row turns it on), **Platform Info** (what is this running on - OS/screen/GPU/locale/safe areas).

**Your own code is vocabulary too, with zero setup** - the picker's object page lists the `Node`-derived classes and autoloads your project declares under **Your Project**, with methods classified as Actions/Conditions/Expressions, properties as Set/Get pairs and signals as triggers, each emitting the plain call you would have written. No annotations, no wrappers, nothing moved. Rename, recategorize or hide any of it from the right-click menu (stored in a project catalog, **never written into your script** - delete the file and everything reverts, with no sheet affected), or bake those names into the script as `## @ace_*` comments when you want it self-describing. A row that arrived as a raw `Call Method` can be **converted to the verb it matches** in one click, and when you rename a method the Project Doctor names the member you probably renamed it to.

Drop a `class_name` script in `eventsheet_addons/` and it becomes a provider - `@ace_*` annotations shape everything (`@ace_param` carries a `default:`, `value=Label` option lists, and `hint: comparison` for the whole `=`/`!=`/`<`/`<=`/`>`/`>=` dropdown in one word), and `EventSheets.publish_pack` (the same pipeline the bundled packs use) publishes yours. If you would rather not hand-write annotations at all, **Sheet ▸ Custom Actions…** turns your script's members into a table you edit in place, then writes the differences back as `## @ace_*` comments - including a deprecated forwarding stand-in so a renamed verb keeps working for sheets that already call it. Every behavior pack has a deep-dive guide with 15+ worked use cases in [docs/Addons/](docs/Addons/README.md); the companion resource/loader packs are documented inside their partner pack's guide. Authoring your own pack got its own quality-of-life set: a left-rail **Picker preview** renders how your verbs will read in the picker LIVE from the unsaved sheet, **Sheet ▸ Publish New Version…** bumps `@ace_version` semver-style with your change note recorded in the file, the Sheet Type dialog takes a **node dropped from the Scene dock** as its host, and a guide **scaffolder** (`tools/scaffold_addon_guide.gd`) emits the docs template pre-filled with your pack's real verb tables.

**Abstraction that grows with you** - a row earns its place when it does MORE than a line: multi-line ACEs show a quiet **→N** ("compiles to N lines") cue, function calls read as **ƒ named verbs**, and the picker **leads with featured intention verbs** (Wait, Play Sound, Destroy, Move Toward...). Select actions and **Extract to Function** turns the pile into one reusable verb - captured locals become typed parameters automatically - then **Teach a Verb** publishes it to every sheet's picker in the project, node-targeted and retargetable, exactly like a built-in behavior.

**Tooling** - A searchable node picker, export integrity + compile-on-save, git-`textconv` sheet diffs, a **Project Doctor** (dock/CLI/CI drift audit, extensible by packs, and an orphaned-verb check that catches a call to a provider member that no longer exists - the one failure here that compiles green and breaks at game runtime), error→row deep-linking, live debugging (Live Values, Watch box, conditional breakpoints, Event Trace with a live execution pulse - fired rows glow and fade), a committed vocabulary doc, sheet backups, shareable snippets, a public **`EventSheets` API** for building plugins on top ([guide](docs/GUIDE-BUILDING-ON-EVENTSHEETS.md)), **Tools ▸ Report an Issue…** (opens the tracker with your Godot and plugin versions filled in - and nothing else), and an opt-in MCP server for external tooling.

## Current status

The latest tagged release, **`v0.17.0` - "Adopt Anything, Read Anything & Ask Why"**, is about the code you already have and the words you read it in:

- **A hand-written `.gd` opens as rows - all of it.** Measured over 206 real files, verbatim code blocks went from **88.1% of code lines to zero**, byte-exact on every file and gated by a test that opens REAL sources: one statement is one action, comment runs are comment rows, collection literals are editable **Declare** rows, and beginner spellings (`:=`, untyped lifecycle headers, an `enum` + `match` machine) round-trip like everything else.
- **Your own classes are vocabulary with zero setup**: a **Your Project** picker section reflecting your classes and autoloads (methods as Actions / Conditions / Expressions, properties as Set / Get, signals as triggers), rename / recategorize / hide stored outside your script or baked in as `## @ace_*` on request, "convert this raw call to the verb it matches", **Sheet > Name Raw Calls**, and a Doctor that names the member you probably renamed to.
- **Rows read like Construct's**: bold parameter values in every sentence (l10n-safe, across the bundled vocabulary and every pack's featured verbs), statements as sentences and calls as Object then Verb, a **Reading Mode** lens, state machines that read like state machines (`◆ State:` headers, guards humanized), identity **bars** for the enum list / Class setup / Host binding, cells that **wrap by word**, and the **Mockup Slate** theme.
- **The everyday patterns became rows**: Has Changed, named cooldowns, **Remember Between Runs** (one toggle persists a variable), Move Toward (smooth), Toggle, As Clock Time, the **Timeline block**, coyote time as a condition, press buffering, the wave director, knockback / magnet / orbit / hold-to-charge, i-frames wired into Health, and the goals packs - **Quest**, **Checkpoint**, **Interaction**, **Phase Cycle**, **Home & Leash** - plus 72 verbs for values, text, tables and copying, and the **Common Game Patterns** guide.
- **The developer-experience wave (31 suggestions)**: Wait Until / For All Of / For Any Of with Succeeded / Timed Out read back on the next row, **On Failure Of / On Success Of** as real triggers, Retry / throttle / debounce, Only Once Per Node; the **Event Bus**, **Named Scenes**, **Game Settings**, **Debug Overlay** and **Follow A Path** packs; services, deferred calls, data-file watching, frame budgets, a spatial module and Local-Storage-shaped save keys; then **Row Hit Counts** in the gutter (off by default), **Why didn't this fire?**, **Test Sheets** that run headless and print a verdict, a **Refactor** menu (Wrap / Unwrap / Inline / Duplicate as Variant / snippet blanks), **Compare With...**, **Loose Ends** and **Find Repeated Rows**.
- **Save slots, runs and recovery** (39 verbs on the Save System pack: slot detail and thumbnails without loading, an autosave the sheet can veto, On Save Needs Upgrade, a Doctor check for values read back that nothing ever saves), Change Type Everywhere, Grid to CSV, Paste Special, Render Scene To Image, Preview Table Rolls, On Project Export, and the **Priced Tables** / **Encounter Timeline** packs.
- **Shipping in more than one language** (21 suggestions): For Each Language, Language Matches / Region Is, Set Text (follows language), Counted Text proven against Russian plurals, RTL and font fallback, Will It Fit, locale-remapped assets, the **Translation Studio**, pseudo-localization, rename-key-everywhere; the nine editor languages now carry **1,700+ keys each**.
- **Documentation inside the editor**: every shipped doc link pins to the released tag, and Tools > Documentation / F1 / `?` open all three doc sets - the guides, the 77 addon guides and **36 new module guides over all 48 builtin modules** - as natively rendered pages with **figures that draw themselves from real rows**, plus **Explain This Row** and a guide to writing the docs.
- **The authoring loop**: Ghost Row suggestion chips + learn-as-you-type ranking, recent values per parameter, the sticky group breadcrumb, Compact Rows, the Picker Preview rail, Sheet > Publish New Version, the guide scaffolder, node-drop onto the Sheet Type dialog, the colour picker's saved palette, and the **Self section** in the Expressions dictionary down to the running game answering.
- **Fifteen new packs** (91 total) - every one with an icon, a 15+ use-case guide and a runtime-proven test.

**Quality** - 10,960+ assertions, all green, CI-gated on every push; byte-exact golden round-trips guard the lossless rules, the save backend is pinned across all 18 seams and six formats (including the adversarial-review regressions), and the AI drag & drop and pathfinding showcases are live-verified on camera. **Verified on Godot 4.7 stable.** Generated code never depends on the plugin, templates bake at apply-time, and output is performance-identical to hand-written GDScript - all test-enforced.

_Recent releases before this:_ **v0.16.0** (opening a script as editable events, publishing a script as verbs, 88 raycasting verbs + two labs, nine editor languages, one `publish_pack` pipeline), **v0.15.0** (the save-state seam across 18 packs and six on-disk formats, the Save Studio, the player-or-AI input seam everywhere, pathfinding hazards and moving platforms, BBCode formatting in comments), **v0.14.0** (Platformer Pathfinding + Nav Agent 3D, the universal AI drive seam, FPS movement tech, Juice camera verbs 2D + 3D, the input overhaul), **v0.13.0** (the incremental/idle kit, ECS-lite Systems, Advanced Random behind one seed), and **v0.12.0** (the Inspector Designer + eight drawers, the UI trio packs, a faster lazily-built editor). The milestones table below and [CHANGELOG.md](CHANGELOG.md) have the full history.

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
| `v0.16.0` - **Open Anything, Publish Anything & Ask What Is There**: 9 editor languages (eight shipped translations) + hot-reload, the Custom Resource wizard + editor-tool journey, `loopindex` + the Expressions dictionary, per-pack icons + featured hero verbs + the Addon Pack chip, one `EventSheets.publish_pack` pipeline, multi-line enum blocks, the GDScript-basics coverage receipt; **the reads-like-code pass** - published verbs and triggers flipped into the two-lane condition/action model in file order, the focused Edit Parameter dialog, C3-aligned object columns + a full-height divider guide, self-explaining form labels, Report an Issue, the macOS HiDPI fix; **every kind of raycast in 2D and 3D** (88 verbs: RayCast/ShapeCast nodes, one-off ray/point/shape/motion queries, camera picking) with the **Raycast Lab** and **Raycast Lab 3D** showcases; **the curation pass** - the ACE wizard's preview table turned into an editing surface (Curate Script / Parameters / Keep Old Name write `## @ace_*` comments, a param spec, and a deprecated forwarding stand-in back into your own script), `@ace_param` defaults + `value=Label` options + the `comparison` shorthand, the **orphaned-verb** Doctor check, labeled enum columns in Inspector tables, number scrubbing on parameter labels; plus the UHTN Planning / Platform Info packs (76 packs) | ✅ shipped |
| `v0.17.0` - **Adopt Anything, Read Anything & Ask Why**: hand-written `.gd` opens as rows - 88.1% verbatim blocks to **zero** across 206 real files, byte-exact (one statement is one action, comment rows, editable Declare rows, beginner spellings, the enum + match machine shape); your own classes as zero-setup vocabulary (Your Project picker section, rename / hide overrides, convert-raw-call, Name Raw Calls, rename-following Doctor; 21 review defects fixed); rows read like Construct's (bold values, sentences + Object-Verb calls, Reading Mode, state-machine reading, identity bars, word wrap, Mockup Slate); the pattern waves (Has Changed, cooldowns, Remember Between Runs, Move Toward (smooth), Timeline block, coyote time, buffering, wave director, knockback / magnet / orbit / charge, i-frames, Quest / Checkpoint / Interaction / Phase Cycle / Home & Leash, 72 values-and-text verbs); the developer-experience wave (Wait Until / All Of / Any Of, On Failure / On Success triggers, Retry / throttle / debounce, Event Bus / Named Scenes / Game Settings / Debug Overlay / Follow A Path, hit counts, Why didn't this fire?, Test Sheets, the Refactor menu, Compare With, Loose Ends, Find Repeated Rows); save slots + autosave veto + save upgrade + the never-saved Doctor check; the i18n wave (For Each Language, Counted Text, RTL, Translation Studio, 1,700+ keys per language); documentation inside the editor with live figures + 36 module guides; Ghost Row chips, recent values, breadcrumb, Compact Rows, Picker Preview, Publish New Version, the Self section; the real macOS HiDPI fix (91 packs) | ✅ shipped |
| _Roadmap_ - community feedback, polish, and whatever you ask for next | 🗺 planned |

## Project layout

| Path | What it is |
|---|---|
| `addons/eventforge/` | Data model, compiler, importer, builtin ACEs, runtime bridge |
| `addons/eventsheet/` | The editor: dock, virtualized viewport, renderer, picker, themes, lint, MCP server |
| `eventsheet_addons/` | Zero-config ACE addons + the 91 behavior packs |
| `demo/` | 18 showcases (each a `.gd` that is BOTH the sheet and the compiled script, with a scene where it is playable) and the bundled themes |
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
