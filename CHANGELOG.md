# Changelog

## [Unreleased]

### Added - @onready variables + node-drag into GDScript blocks

- **@onready variables.** A tree-placed variable can now be set on `_ready()`: tick the new
  **On ready** box in the Variable dialog and the Default becomes a GDScript expression (a node
  reference like `$Player`, or `get_node(...)`), compiling to `@onready var name: Type = <expr>`. A new
  variable is typed `Variant` (safe for any node reference - a numeric type would crash assigning a Node);
  const and `@export` are disabled since the compiler emits only `@onready var`.
- **`@onready var` round-trips.** Opening a `.gd` that already has `@onready var x = $Path` now lifts it
  to an editable onready variable row (byte-verify gated, so it stays lossless), preserving its declared
  type - editing a hand-authored `@onready var s: Sprite2D = $S` keeps the `Sprite2D` type.
- **Drag a node into a raw GDScript block.** Dropping a Scene-dock node into the raw-GDScript-block editor
  inserts its `$Path` / `%Name` reference at the caret (a FileSystem asset becomes a quoted `res://` path) -
  the same converter the ACE param fields already use.

### Added - Attach Event Sheet is now .gd-first

- **Attach Event Sheet is now `.gd`-first.** The Scene-dock right-click "Attach Event Sheet" writes a
  single hand-editable `.gd` beside the scene (the `.gd` IS the sheet, no `.tres` companion) and attaches
  it to the node - identical to how FileSystem "Create New > Event Sheet" and every other sheet is born.
  One right-click takes a bare node to an editable event sheet, opened straight in the workspace.

### Added - two AI showcases

- **Two AI showcases**, one per bundled AI pack, each a self-driving demo that compiles to plain GDScript
  and round-trips byte-exactly (pinned in `tests/showcase_examples_test.gd`):
  - **Guard Brain** (Utility AI) - a guard with no input whose `UtilityBrain` scores patrol / chase / flee
    from an oscillating threat signal and a stamina wave; each action is shaped by a response curve and the
    highest score wins. Set Input -> Evaluate -> read Current Action, the whole utility loop.
  - **Chef Planner** (HTN Agent) - a planner with no input whose compound task `make_meal` decomposes (via
    a method whose world-state condition holds) into an ordered plan gather -> cook -> serve, walked to the
    end one primitive per tick. Add tasks + methods, Request Plan, Mark Complete, the whole HTN loop.
- The style-guide gate no longer scans `demo/showcase`: the showcases are compiler output
  (`build_examples.gd` emits them like the packs, byte-pinned as round-trip artifacts), so they follow the
  emitter's single-blank contract, the same exemption `eventsheet_addons` and `demo/sheets` already have.

### Fixed - showcase regeneration is now byte-reproducible

- **Regenerating the showcases is deterministic.** `build_examples.gd` now strips the random
  `unique_id=NNNN` token Godot stamps onto every node at pack time (editor scene-merge metadata, unused by
  the plugin and by scene loading), which was the sole source of `.tscn` churn - running the builder twice
  now produces byte-identical output. All showcases were regenerated to the current single-blank emitter
  output, so `demo/showcase` is uniform and a rebuild leaves a clean working tree.

## [0.13.0] - 2026-07-08 - The Genre Toolkits Update

### Added - auto-registered pack builders, data-driven Simple Abilities, and Advanced Random everywhere

- **Pack builders now auto-register.** `tools/build_sample_behaviors.gd` discovers every `*.gd` in
  `tools/pack_builders/` (skipping the leading-underscore helpers) and calls its `static func build()`,
  the same zero-config discovery the helper ACE modules use - drop a new builder in and it registers
  itself, no list to edit. Builds run in sorted order so a rebuild stays deterministic.
- **Simple Abilities is now data-driven.** A new **AbilitySetResource** Custom Resource holds a whole
  loadout as a `.tres` (a grid of id / cooldown / max stacks / temporary / tags); the behavior gained an
  **Ability Set** slot that auto-creates the loadout on ready, and a **Load Ability Set** action to swap
  loadouts at runtime. The events-driven way still works exactly as before.
- **Advanced Random can drive the procedural packs.** ProcRoom, Loot Table (LootBox), SkinVault, and
  Storylets each gained a **Use Advanced Random** action: when on, that pack draws from the shared
  `AdvancedRandom` autoload instead of its own generator, so one seed reproduces a whole run (map + loot +
  cosmetics + narrative). Off by default (behaviour is byte-identical), and it falls back safely to the
  local generator when Advanced Random is not installed.
- **Data-driven odds.** A new **RandomTableResource** Custom Resource (a value / weight grid) plus
  Advanced Random's new **Pick From Table** expression, which reads the resource and picks in proportion
  to weight - author drop rates as a `.tres`, not events.
- **A Procedural module for tools and resources.** A new "Procedural" ACE section of STATELESS seeded
  expressions (**Seeded Value / Seeded Int / Seeded Pick / Seeded Sign / Seeded Chance**) that need no
  autoload, so they work inside Editor Tool sheets and while filling Custom Resources, as well as at
  runtime - a seed plus an index always gives the same value.
- **A procedural-generation guide**, [docs/GUIDE-PROCEDURAL-GENERATION.md](docs/GUIDE-PROCEDURAL-GENERATION.md),
  with 20+ worked cases pairing Advanced Random with the other addons and a start-to-finish seeded-run
  workflow; the Simple Abilities guide gained a data-driven section. Pinned in
  `tests/random_integration_test.gd` (drift gate green, audited=58).

### Added - the incremental / idle game suite (7 packs)

A cohesive toolkit for building clicker, idle, and incremental games. The existing Currency Ledger owns
the wallet; these seven new packs add the rest of the genre loop, each compiling to plain Godot with zero
plugin dependency. Runtime math is pinned in `tests/incremental_packs_test.gd` and every pack round-trips
byte-exactly (drift gate green, audited=56). The design was pressure-tested against the genre and the
formulas verified before any ace_id was frozen, then a follow-up adversarial review of the shipped code
hardened seven edge cases - Decimal Power and Compare at fractional exponents, a Buy Max hang on a sub-1
cost growth, a prestige gain that wrapped negative past int64 at idle scale, a boost-restart clobber, and
a milestone progress bar that regressed after latching - each now pinned in the test.

- **Big Numbers** (`BigNumber` autoload) - the number formatting an idle game lives on: Format Short with
  short-scale suffixes past a trillion (Qa, Qi ... Dc, then scientific), scientific + engineering
  notation, time, ordinals, commas, percent, and a **Decimal type** (an `[mantissa, exponent]` array, so
  the mantissa keeps full 64-bit precision) with Add / Multiply / Power / Compare / Format Big for values
  past a float's 1.8e308 ceiling. The classic formatter traps are fixed: the floor(log/log10)
  off-by-one at exact powers of ten (a +1e-9 epsilon), the mantissa-rounding carry, and the past-Dc
  fall-through to scientific.
- **Idle Generator** (`IdleGeneratorBehavior`) - a producer/building you attach to a node. Geometric cost
  curve (base * growth^owned) with an **exact closed-form Buy Max** (no loop), Next Cost / Cost For(n) /
  Max Affordable / Cost To Buy Max, continuous Output Per Second, and an optional fill-and-collect **cycle
  mode**. Stays decoupled from the wallet - the Buy actions record Last Cost for your sheet to Spend.
- **Click Power** (`ClickPower` autoload) - manual-tap income: Do Click computes a tap's yield (base +
  flat bonus + a fraction of production, times a multiplier), rolls a crit, and fires On Click / On Crit.
- **Boosts** (`Boost` autoload) - temporary timed multipliers (golden-cookie frenzies) that count
  themselves down and fire On Boost Expired; Total Multiplier folds every active boost into production.
- **Upgrades** (`Upgrades` autoload) - stacking one-time/repeatable buffs with add or mult modes and a
  tag; Try Purchase buys against a budget you pass, Total Multiplier(tag) / Total Bonus(tag) aggregate a
  whole group into one number.
- **Prestige** (`Prestige` autoload) - reset for a permanent multiplier: Track Earned, preview Prestige
  Gain (floor((run earned / requirement) ^ exponent)), Do Prestige banks points and resets the run (a
  run/all-time split means points are never double-awarded), Prestige Multiplier = 1 + points * bonus.
- **Milestones** (`Milestones` autoload) - threshold achievements that GRANT a reward: Update Progress
  latches them once, and Total Reward sums every reached milestone's bonus so achievements make the
  player stronger, not just light up.
- **Seven guides** in `docs/Addons/` (a new "Incremental and idle" section in the index), each with a
  full ACE reference and 12+ worked use cases, plus a data pack test and the `_lib` `condition()` /
  `number()` helpers hoisted for every data pack to share.

### Added - composition / systems vocabulary (ECS-lite)

- **A "Systems" ACE section** for the composition pattern (entities = nodes in a group, systems = sheets
  that run over that group). Seven verbs in `addons/eventforge/registration/modules/composition_aces.gd`:
  **Entities In Group** and **Any Entity In Group** (query one group as a set of entities), **Entities In
  Both Groups** / **Count In Both Groups** / **First In Both Groups** / **Is In Both Groups** (the
  archetype intersection - "in group A and group B"), and **Run On Tagged Entities** (call a method on
  every entity in a group that also has a tag - a whole system in one action). They compile to plain
  `get_tree().get_nodes_in_group(...)` + `is_in_group(...)` with zero plugin dependency, honouring the
  parity covenant.
- **An "Entity System (Autoload)" starter** in the New... menu (a Systems section) - an autoload with an
  On Process event that iterates a group each frame and moves every entity. Scaffolds the systems pattern
  in one click. Pinned in `tests/script_intent_test.gd`.
- **A composition guide**, [docs/GUIDE-COMPOSITION-SYSTEMS.md](docs/GUIDE-COMPOSITION-SYSTEMS.md): the
  entity/tag/system model, the Systems vocabulary, a worked status-effect system, honest performance
  guidance (trigger over poll, tick slow things slowly, query once per frame), and a frank "when NOT to
  use this" - it is node iteration, not a data-oriented ECS.

### Added - data-driven addon config with Custom Resources (Loot Table + SkinVault)

- **SkinVault is now data-driven too.** A new **SkinCatalogResource** holds a whole cosmetics catalog as
  a `.tres` (a rarities grid and a skins grid you edit in the Inspector); **SkinVault gained a Load
  Catalog action**, and the new **Skin Catalog Loader** behavior (`SkinCatalogLoader`) loads it into the
  SkinVault autoload on ready, with the same required-slot Inspector warning. Pinned in
  `tests/skin_catalog_test.gd`.
- **A guide to data-driven design**, [docs/GUIDE-DATA-DRIVEN-ADDONS.md](docs/GUIDE-DATA-DRIVEN-ADDONS.md):
  the Custom Resource + loader pattern, the missing-resource warning, and a recipe for making your own
  addon data-driven.


- **Author a loot table as data, not events.** A new **LootTableResource** Custom Resource holds a
  table's drops as a `.tres` asset you fill in the Inspector (an item / weight / tags grid, plus optional
  pity), instead of building it with a string of Add Entry actions. Load it in one step: **LootBox
  gained a Load From Resource action**, or drop the `.tres` on the new **Loot Table Loader** behavior
  (`LootTableLoader`), which loads it into the LootBox autoload on ready.
- **A "you forgot to attach it" Inspector warning.** The Loot Table Loader's resource slot is marked
  required, so the Inspector flags it with a warning while it is empty - a beginner cannot silently ship
  a loader with no data. This is built into the pack-authoring toolkit as `_lib.require_resource(...)`,
  so any behavior pack can declare a required resource slot (an exported Resource plus the required
  warning) in one line - reuse it to make other addons data-driven.
- Pinned in `tests/loot_resource_test.gd` (a LootTableResource loads into LootBox and rolls; a null
  resource is safe). LootTableResource is a `Resource`-host sheet that round-trips byte-exactly (drift
  gate green, audited=47).

### Added - a scaffolder for creating new helper ACE modules

- **`tools/new_ace_module.gd`** - the helper for creating helper modules. Set a name, run it, and it
  writes a compiling `*_aces.gd` module skeleton (an example Action, Condition, and Expression plus a
  section description) into `addons/eventforge/registration/modules/`, where the registry auto-discovers
  it. A beginner starts from something that already builds and passes the gates, then swaps in their own
  ACEs. It never overwrites an existing module, and the skeleton's templates are plain Godot per the
  parity covenant.

### Added - the ObjectPool pack: reuse nodes instead of spawning and freeing

- **ObjectPool** - register as the `ObjectPool` autoload to reuse nodes instead of creating and freeing
  them every frame (which makes a game hitch). Two ways to pool: the easy way, **Create Pool** from a
  scene (.tscn) with an optional **Prewarm**; and the custom way, **Create Empty Pool** then **Add To
  Pool** your own nodes. **Spawn** hands out a ready node (reusing a free one, else making a new copy) -
  added to the scene, shown, and returned so you can position it - and **Despawn** parks it back
  (hidden, processing off) to be reused, rather than freeing it. **Despawn All**, **Clear Pool**, a Has
  Pool condition, Free / Active / Pool Size counts, Spawn / Last Spawned / Last Despawned, and On
  Spawned / On Despawned triggers round it out. Pinned in `tests/object_pool_test.gd`; drift gate green
  (audited=45).

### Added - the Fade and Slide Movement behavior packs

- **Fade** - a `FadeBehavior` you attach to any sprite or UI node (a CanvasItem): **Fade In**, **Fade
  Out** (fires On Fade Out Started then On Faded Out, optionally freeing the node), **Start Fade** (the
  whole fade-in / hold / fade-out sequence from the Inspector times), **Stop Fade**, and **Set Opacity**,
  with an Is Fading condition and an Opacity expression. Pinned in `tests/fade_test.gd`.
- **Slide Movement** - a `SlideMove` behavior for grid movement where a tap sends the character sliding
  until it hits a wall (the Tomb-of-the-Mask feel), distinct from the step-per-press Tile Movement pack.
  It finds the farthest open tile with a physics ray on a configurable wall layer, then glides there at
  a constant speed and snaps to the grid. **Slide** (left/right/up/down), **Stop Slide**, **Snap To
  Grid**, **Teleport To Tile**, **Set Grid Size**; Is Sliding / Can Slide conditions; Slide Direction /
  Tile X / Tile Y expressions; On Slide Started / On Slide Stopped / On Hit Wall triggers; arrow keys
  drive it by default. Pinned in `tests/slide_move_test.gd`. Both drift gate green (audited=44).

### Added - four helper ACE modules: Game Window, Game Options, Input, Vibration

- **Game Window** - go fullscreen / windowed / exclusive, toggle fullscreen, set window size / position,
  center, set vsync, cap the FPS, always-on-top, minimize / maximize, Is Fullscreen, Max FPS.
- **Game Options** - the options-menu knobs: set the master or a named bus's volume from a 0-100 percent
  (not decibels), read a bus's volume back as a percent, Is Bus Muted, Save Setting (writes one value to
  `user://settings.cfg` while keeping the rest), and Has Saved Settings.
- **Input** - Add Input Action, Rebind Action To Key (clear + bind in one action), Has Input Action, and
  the movement reads Move Vector / Move Axis / Action Strength (beyond the core is-pressed checks).
- **Vibration** - Stop Gamepad Vibration, Vibrate Phone (handheld), and Gamepad Vibration Strength (the
  rumble already had a Vibrate Gamepad action; this rounds it out).

  All bake to plain Godot (`get_window()`, `DisplayServer`, `AudioServer`, `ConfigFile`, `InputMap`,
  `Input`, `Engine`) with zero plugin references, honouring the parity covenant, and are auto-discovered
  by drop-in. They pass the builtin-compile and duplicate-id gates (checked=556, failed=0), and each
  declares its picker section description.

### Added - descriptions on ACE picker section headers

- **Category / sub-section / node-type headers in the ACE picker now carry a short description**, shown
  in the picker's info panel when you select the header (and as its hover tooltip) - so a newcomer
  browsing the list learns what a whole group is for, not just individual ACEs. Selecting a header shows
  its blurb and keeps Add disabled (a header is not an ACE). Descriptions come from a new
  `EventSheetSectionInfo` registry seeded with the core categories, from each ACE module's optional
  `static func section_descriptions() -> Dictionary`, and - for a pack's own category - automatically
  from the pack's class doc comment, with no extra wiring. Extensions add their own with
  `EventSheetSectionInfo.describe(name, text)`. Pinned in `tests/picker_layout_test.gd`.

### Added - guides for the ported packs + a guide to building editor tools

- **A `docs/Addons/` guide library** with a deep-dive per bundled pack (when to use it, the full ACE
  reference, a dozen-plus worked use cases as event-sheet rows, and the gotchas): Currency Ledger, Loot
  Table, Storylet Weaver, SkinVault, ProcRoom, UtilityBrain, Physics Car, and ComboBox, with a
  `docs/Addons/README.md` index. More packs to follow.
- **`docs/GUIDE-BUILDING-EDITOR-TOOLS.md`** - making custom Godot editor tools with event sheets: the
  Tool sheet (`@tool` + EditorScript + On Editor Run), the new Editor Tools ACEs, and interfacing with
  the `EventSheets` API from an EditorPlugin, with 12 worked examples. `GUIDE-BUILDING-ON-EVENTSHEETS.md`
  now documents `new_sheet()` and `simple_block_kind()`.

### Added - Editor Tools ACEs + a friendlier extension API for building on EventSheets

- **A new builtin "Editor Tools" ACE module** (17 ACEs) for authoring `@tool` / EditorScript sheets by
  events instead of code: **Open Scene In Editor**, **Save Current Scene** / **Save Scene As**, **Play
  Current Scene** / **Stop Playing**, **Rescan Project Files**, **Select Node In Editor**, **Inspect In
  Editor**, **Save Resource To File**, **Make Sure Folder Exists**, **Resource Exists**, **Is In
  Editor**, and the read-backs **Edited Scene Root** / **Selected Nodes** / **Editor Scale** - plus two
  combined builders that fold three lines into one pickable row: **Add Node To Edited Scene** (create +
  add child + set owner so it saves with the scene) and **Save Node As Scene** (pack a node and its
  children into a `.tscn`). Every one bakes to plain Godot (`EditorInterface`, `ResourceSaver`,
  `DirAccess`, `Engine`) with zero plugin references, honouring the parity covenant. Pair them with a
  Tool sheet (Sheet Type -> Tool: emits `@tool` + `extends EditorScript` + the On Editor Run trigger).

- **Two beginner-friendly additions to the public `EventSheets` API** (both a frozen compatibility
  promise, like every method there):
  - **`EventSheets.new_sheet(config)`** builds a ready-to-fill `EventSheetResource` from a plain
    Dictionary (`class_name` / `host_class` / `behavior_mode` / `autoload_mode` / `tool_mode` /
    `category` / `tags` / `description`) - the one public way to author a sheet, behavior, autoload, or
    tool script from code. Append events and functions, then `compile()` it.
  - **`EventSheets.simple_block_kind(config)`** builds a whole Custom Block kind from a Dictionary (an
    `emit` template with `{field}` placeholders, a `summary` template, and a `fields` schema) with **no
    subclassing** - backed by the new `EventSheetSimpleBlockKind` helper. Forward emission and the
    viewport summary work immediately; reverse recovery stays opt-in via a `lift` Callable, and without
    one the block still emits perfectly and re-imports as a verbatim GDScript block (the safe
    degrade-never-corrupt fallback).
  - Both pinned in `tests/eventsheets_api_test.gd`; the Editor Tools ACEs pass the builtin-compile and
    duplicate-id gates (checked=527, failed=0).

### Added - the ComboBox pack: an input-sequence detector

- **A 42nd behavior pack, ComboBox** (a Construct 3 addon port): register as the `ComboBox` autoload
  to turn strings of inputs into fighting-game specials, cheat codes, rune gestures, or combination
  locks. It keeps a rolling buffer of named input **tokens** and, after every input, matches the buffer
  against your registered **sequences**. **Register Combo** (a comma-separated token sequence like
  "down,forward,punch" plus a timing window in seconds), then **Press Input** a token from your own
  keyboard / gamepad / touch / network events - it reads no hardware itself, so it works with any input
  source. **On Combo Matched** fires when a sequence completes; **On Partial Progress** and **On Combo
  Failed** drive input-history UI and stalled-motion resets; **On Buffer Cleared** on a **Clear Buffer**.
  Refine combos with **Set Combo Tags** / **Set Combo Priority** / **Set Combo Strict**, gate them with
  **Enable / Disable Combo** and the by-tag batch actions, and read the buffer, partials, and registry
  through the expressions. Beginner-friendly over the C3 original: discrete typed ACEs instead of
  hand-written JSON registration; timing windows in **seconds** (Godot's unit) off an internal clock,
  not milliseconds; per-gap timing so a slow first input still counts; a `"*"` wildcard; interleave
  tolerant matching by default with an optional strict mode; and **one combo wins per input** (highest
  priority, then longest) so a sub-combo does not also fire when the longer combo completes. Pinned in
  `tests/combo_box_test.gd`; drift gate green (audited=42 drifted=0).

### Added - the Physics Car pack: a force-driven arcade car

- **A 41st behavior pack, Physics Car** (a Construct 3 addon port): attach a `PhysicsCar` behavior to a
  **RigidBody2D** and it becomes a car - the body keeps handling collisions and impacts while the
  behavior adds drive, steering, lateral grip (so it stops sliding sideways like ice), and drift
  detection, replacing the per-project steering / grip / drift math. Drive it with **Set Throttle** /
  **Set Brake** / **Set Steer**, the keyboard-style **Simulate Control** ("up" / "down" / "left" /
  "right" / "stop"), or point it at a target for AI with **Drive Toward Angle** / **Drive Toward
  Position** (fires **On Drive Target Reached**). **Enable Handbrake** slides the back out, **Teleport**
  respawns, and **Set Surface Grip** / **Set Surface Resistance** / **Reset Surface** make mud, ice, and
  grass one action each. Conditions Is Moving / Is Reversing / Is Drifting / Is At Max Speed / Has
  Reached Drive Target / Has Surface Override / Is Driving Toward Angle-or-Position; expressions for
  speed, forward / lateral / slip, drift duration, inputs, heading error, effective grip, and the
  collision context; triggers On Collided / On Drift Started / On Drift Ended. Godot-native over the C3
  original: the host IS the RigidBody2D (no separate physics component to add and keep in sync), motion
  is real forces and impulses so collisions stay physical, and the whole feel is Inspector knobs. Pinned
  in `tests/physics_car_test.gd`; drift gate green (audited=42 drifted=0).

### Added - the UtilityBrain pack: scoring-based AI, one brain per node

- **A 40th behavior pack, UtilityBrain** (a Construct 3 UtilityAI port): a per-node decision engine
  that replaces brittle if/else state machines with utility scoring. Attach one to each enemy /
  companion / NPC, then **Add Action** (a candidate behaviour with an optional cooldown,
  interruptible flag, and priority), give it **Add Consideration**s (each reads a world-state input
  and maps it through a friendly named response curve - **linear / inverse / quadratic /
  inverse_quadratic / logistic / threshold / bell**, tuned with a center + slope - to a 0-1 score),
  push state with **Set Input**, and call **Evaluate**: the highest-scoring action wins and fires **On
  Decision Made**, plus **On Action Started** / **On Action Changed** when the choice moves. Round it
  out with **Force Action** (scripted overrides), **Mark Action Complete** (starts the cooldown, then
  re-evaluates), **Interrupt Action**, **Set Action Cooldown** / **Clear Cooldowns**, and the
  **weighted-random** selection mode (sample among the top N) for less robotic behaviour. Conditions Is
  Running / Has Action / Is Action Enabled / Is On Cooldown / Was Last Action / Is Idle; expressions
  for the current/previous action, decision + per-action scores, action history, cooldown remaining,
  and inputs. Beginner-friendly over the raw C3 addon: **the node IS the agent**, so every "agent id"
  argument the C3 version threaded through every ACE is gone; considerations are discrete typed ACEs
  (no hand-written JSON, no consideration-id typos to silently drop a factor); response curves are a
  named dropdown instead of raw curve math; a consideration-less action scores a flat fallback, so
  registering an "idle" action IS the always-keep-a-fallback best practice with nothing extra to wire;
  and inertia only nudges an already-viable action rather than rescuing a vetoed one. Pinned in
  `tests/utility_ai_test.gd`; drift gate green (audited=40 drifted=0).

### Added - the ProcRoom pack: a seeded room-graph generator

- **A 39th behavior pack, ProcRoom** (a Construct 3 addon port): register as the `ProcRoom`
  autoload to lay out a Slay-the-Spire-style **tiered map** of rooms - discrete depths from a start
  room to a boss, with forward branches between them - from a single seed string, so the whole run is
  reproducible. **Register Room Type** (id, weight, min/max depth, max-per-depth), **Set Start Type** /
  **Set Boss Type**, then **Generate** (seed, depths, max rooms per depth) or **Regenerate** with a new
  seed, firing **On Graph Generated**. Rooms are placed by weighted random honouring the depth limits,
  and every room is wired to at least one parent, so the start always connects through to the boss (no
  orphan rooms). Traverse with **Enter Room** (fires **On Room Entered**, or **On Traversal Blocked**
  with a reason of "unreachable" / "locked" when the move is illegal), **Force Enter Room** (skip the
  checks), **Lock / Unlock Room**, **Reveal Room**, and **Reset Traversal**. Conditions Is Graph Ready /
  Is Room Visited / Is Room Available / Is Room Locked / Is Room Connected; expressions for the seed,
  totals, the current/entered/blocked room and its type/depth, rooms and connections at a depth, and the
  visited count. Beginner-friendly over the raw C3 version: reachability is guaranteed by construction
  (you can never strand the boss), the seed is a plain string, and the ids are stable `d{depth}_{index}`
  handles you can key art and encounters off. Pinned in `tests/proc_room_test.gd`; drift gate green
  (audited=39 drifted=0).

### Added - the SkinVault pack: cosmetic ownership + gacha unlocks

- **A 38th behavior pack, SkinVault** (a Construct 3 addon port): register as the `SkinVault`
  autoload to own WHAT the player has and can still get (you build the UI). **Register Rarity**
  (weight + an explicit tier rank) and **Register Skin** (id, name, rarity, cost, tags), then unlock
  via three paths that all funnel into **On Skin Unlocked**: **Roll** (weighted-random over the
  unowned pool, with hard pity), **Purchase** (fires **On Purchase Requested** carrying the cost -
  your wallet, e.g. the Currency Ledger pack, confirms - then **Confirm/Cancel Purchase**), and
  **Grant** (free). **Revoke** removes a skin. Conditions Is Owned / Is Registered / Is Unlockable /
  Is Pool Empty; expressions for counts, skin lookups, Pity Counter / Progress, Owned Ids (save), and
  the roll/unlock/purchase event context. Pity uses an explicit rarity **tier** integer (so
  "guarantee an epic-or-better after N misses" no longer depends on the C3 addon's fragile
  registration order), and currency stays external. Pinned in `tests/skin_vault_test.gd`; drift gate
  green (audited=38 drifted=0).

### Added - the Storylet Weaver pack: quality-based narrative from any sheet

- **A 37th behavior pack, Storylet Weaver** (a Construct 3 addon port): register as the
  `Storylets` autoload for quality-based narrative - instead of one giant branching web of
  if/else, register many small **storylets**, each with its own requirements, and **Draw** the best
  eligible one. **Define Storylet** (id + title + body), **Add Requirement** (a quality compared with
  a >= / > / <= / < / = / != dropdown), **Add Choice**, then mirror game state with **Set Quality** /
  **Increment Quality** and call **Draw** (highest weight) or **Draw Weighted** (random by weight),
  firing **On Storylet Drawn** or **On None Available**. **Choose** resolves a choice (**On Choice
  Made**). Beginner-friendly fixes over the C3 version: a missing quality reads as 0 / "" (so
  `courage >= 3` is simply false, not the C3 addon's surprising "every op but != fails" rule);
  cooldowns run off an internal clock that ticks automatically; and Draw is evaluate + pick + activate
  in one call. One-shots via Max Plays, cooldowns, and play history round it out. Discrete typed ACEs
  replace JSON-blob registration. Pinned in `tests/storylet_weaver_test.gd`; drift gate green
  (audited=37 drifted=0).

### Added - the Loot Table pack: a weighted loot roller from any sheet

- **A 36th behavior pack, Loot Table** (a Construct 3 addon port): register as the `LootBox`
  autoload and build weighted drop tables with discrete ACEs - **Create Table**, **Add Entry**
  (item + weight), **Add Rare Entry** (weight + quantity + tags), and **Add Table Reference**
  (an entry that rolls another table inline). **Roll** / **Roll Times** fire **On Roll Result**
  once per drop (read Roll Item / Roll Quantity / Roll Tags / Roll Index) then **On Roll Complete**.
  Balance is editing weight numbers, not rewiring events. Extras over a plain weighted pick:
  **Set Guarantee** (a tag drops at least N times per batch), **Set Pity** (HARD pity - a tag is
  GUARANTEED after N straight misses, firing On Pity Triggered, instead of the C3 addon's soft
  weight-doubling), and **Set Seed** for reproducible rolls via a seeded RandomNumberGenerator.
  This is the full runtime engine, distinct from the plugin's EnemyStats "loot table" drawer
  showcase (a grid-edited Array with no rolling). Pinned in `tests/loot_table_test.gd`; drift gate
  green (audited=36 drifted=0).

### Added - the Currency Ledger pack: a named-currency economy from any sheet

- **A 35th behavior pack, Currency Ledger** (the first of several Construct 3 addon ports
  reimagined for Godot): register as the `CurrencyLedger` autoload and manage any number of
  named currencies (gold, gems, energy, xp, hunger...) from any sheet. **Define Currency**
  (starting amount + optional max), then **Add** (a signed amount that clamps to the
  currency's min and max and respects a daily earn cap), **Spend** (fails atomically when you
  can't afford it), **Set Amount**, **Allow Debt** (a negative floor for hunger/heat/overdraft),
  **Set Daily Cap** / **Reset Daily Caps**, and **Apply Offline Gain** (credits rate x seconds in
  ONE call). Conditions Can Afford / Is At Cap / Is Daily Cap Reached / Is In Debt; expressions for
  Balance / Cap / counts and a **Format Amount** with K/M/B/T suffixes; triggers On Amount Changed /
  Spend Failed / Cap Hit / Daily Cap Hit / Offline Gain with getter expressions for the event
  context. The port fixes the C3 addon's debt/non-negative contradiction with one clean min/max
  model and replaces JSON-blob registration with discrete typed ACEs. Pinned in
  `tests/currency_ledger_test.gd`; drift gate green (audited=35 drifted=0).

### Added - Hitstop in the Juice pack

- **Hitstop** joins the Juice pack (the punchy hit-pause you feel on a connecting
  blow): freeze `Engine.time_scale` (0 = full stop) for a few frames, then snap
  back to whatever it was. It runs on a **realtime** `SceneTree` timer so it
  un-freezes even at a full stop (a scaled timer would never elapse at time_scale
  0), ignores repeat hits already mid-freeze, and **pauses any active Slowmo** for
  the duration so the two effects compose. An **On Hitstop Finished** trigger and
  an **Is Hitstopped** condition round it out, and the pack's tree-exit teardown
  now un-freezes the game if you leave the scene mid-freeze (so quitting to a menu
  during a hitstop can never leave it frozen). Params: freeze duration (default
  0.06s) and freeze scale (default 0). Pinned in `tests/juice_pack_test.gd`;
  drift gate green (audited=34 drifted=0).

## [0.12.0] - 2026-07-06 - The Inspector Designer Update

### Added - create an event sheet from the FileSystem, and a faster plugin load

- **FileSystem "Create New > Event Sheet..."** - right-click a folder in the FileSystem dock and
  the native Create-New submenu now offers **Event Sheet...** beside Folder / Scene / Script /
  Resource / TextFile. It opens a compact dialog (a name plus a **Start from** picker - Blank,
  Platformer, Top-down, Behavior Component, Custom Resource, or Editor Tool) and writes a
  hand-editable `.gd` sheet into that folder, then opens it ready to edit. The starter picker and
  the in-workspace New-Sheet menu now share one `build_starter` source of truth. Backed by a pure,
  headless-tested `EventSheetWorkflow.write_sheet_file` core (collision-safe naming, compiles to the
  default `.gd` format, byte round-trips).
- **The workspace editor now loads lazily.** Enabling the plugin - or opening a project that never
  touches event sheets - no longer pays for building the whole editor (the dock, its ~45 delegates,
  every dialog, and the addon-folder vocabulary scans) at editor startup. It is constructed on first
  use (opening the EventSheet tab, or any native entry point like Open/Attach/Create) behind an
  idempotent `_ensure_editor()` seam. The top-strip tab still appears immediately. The one visible
  change: the first-run welcome now greets you the first time you open the workspace rather than at
  editor boot.

### Added - the guides are illustrated with feature images

- **Eleven guides now open with a picture of the feature they teach.** Six reuse
  existing renders (Custom ACEs shows the ACE Studio, Make a Behaviour shows the
  Anatomy panel, C3 Migration and Building On show the picker, Recipes and Using
  With Existing Code show a real sheet). Three are freshly rendered: **Custom
  Blocks** (preload / enum / signal / region rows between events), **Theming**
  (the same sheet under the bundled Dracula package), and **Translating Your Game**
  (the lit globe toggle on a string param). Every image carries descriptive alt
  text; the render harnesses were temporary and are not committed.

### Changed - the docs are organized by prefix, and every guide teaches by example

- **Every doc file now wears its kind as a prefix**: `GUIDE-` for how-tos (12 of
  them, including GUIDE-CUSTOM-INSPECTORS, renamed from the drawers guide to match
  how people search for it), `REFERENCE-` for lookups (MCP server, performance,
  glossary), and design records live under `docs/internal/SPEC-*` - eight shipped
  specs moved there from the root (inspector attributes, progressive disclosure,
  includes, groups round-trip, GDScript pairing, addon composition, open-sheets
  panel, layout alignment). The fully-delivered v0.11 roadmap spec was removed
  (the changelog is its record). Every cross-link in the README, AGENTS.md,
  CLAUDE.md, the guides, and the docs-integrity test was swept and verified.
- **Six more guides gained brief Use Cases sections** (~30 new recipes): Custom
  ACEs (SDK wrapping, safe verbs, hardware triggers), Using With Existing Code
  (legacy signals, gradual adoption, glue sheets), Translating Your Game (jam
  bilingual, plurals, contexts, translator handoff), Make a Behaviour Without Code
  (coin magnet, shared cooldowns, prototype-to-pack), Version Control (PR review
  as code, semantic merges, bisect), C3 Migration (weekend ports, Wait cutscenes),
  and Theming (accessibility and streaming presets).

### Added - context-menu parity: Insert Above, Cut, and Copy as Text

- Three right-click gestures Construct 3 users reach for: the **Insert ▸** submenu
  now leads with **Event Above** (slot a new event before the current one), **Cut**
  joins Copy/Paste (copy plus delete as ONE undo step - undoing a Cut restores the
  rows and the clipboard keeps the copy), and **Copy as Text** (More ▸) puts the
  selection on the OS clipboard as READABLE text - the same plain-language
  sentences the hover tooltips use, ready for an issue or a chat message (plain
  Copy already writes the machine-shareable snippet form).

### Fixed - "Save Selection as Snippet" was unreachable from the row menu

- ROW_MENU_SURROUND_REGION shipped sharing its id with ROW_MENU_SAVE_SNIPPET, so
  clicking "Save Selection as Snippet…" silently ran Surround with Region instead
  (first match in the dispatch wins). The ids are distinct now and pinned so they
  stay that way.

### Added - the Doctor enforces required fields project-wide

- A new built-in Doctor check, **required-field**: every scene node and saved
  resource using a script with Required (and empty-by-default) variables is scanned;
  any that leaves one unset gets a warning naming the exact file and property -
  Godot omits default-equal properties from .tscn/.tres, so a missing override line
  means the empty default ships. Runs everywhere the Doctor runs (dock panel, CLI,
  CI, MCP); demo/showcase and the packs are exempt (the showcase's unset portrait IS
  the required-badge demo). The pure halves (watch-list extraction, container-gap
  detection) are pinned in tests/required_fields_doctor_test.gd. This was the last
  open item of the Inspector Designer spec - the parity matrix is now fully closed.

### Added - the Dialogue Kit pack: conversations with a typewriter, zero systems code

- **A 34th behavior pack, Dialogue Kit** (the final item of the packs roadmap row):
  **Queue Line** (speaker + text), **Start Dialogue**, **Advance** (mid-line advance
  completes the line instantly; otherwise next line or end), and **End Dialogue** -
  played with a **typewriter reveal** into NAMED labels at a tunable speed, with the
  panel shown/hidden automatically and a configurable input action advancing the
  whole conversation. Four triggers (dialogue/line started/finished) hang portraits,
  sounds, and camera moves off the sheet; Is Dialogue Active / Is Typing /
  Speaker Is conditions and Current Speaker / Current Text / Lines Remaining
  expressions round it out. Terse provider style, drift gate green
  (audited=34 drifted=0). The README milestones updated: the Menu/HUD + transitions
  + dialogue roadmap row is fully delivered.

### Added - the Scene Flow pack: scene changes with a polished fade

- **A 33rd behavior pack, Scene Flow** (the scene-transition roadmap item): **Fade To
  Scene**, **Fade Reload Scene**, **Go To Scene**, **Reload Scene**, and **Quit
  Game**, plus the **Is Transitioning** condition and **Current Scene Path**
  expression; fade duration and cover colour are exported tunables. The fade runner
  parents itself to the TREE ROOT (not the dying scene), so the fade-out, the swap,
  and the fade-in all survive the change - the classic "my transition died with my
  scene" trap, solved once; a group flag makes double-triggering impossible.
  Terse provider style, drift gate green (audited=33 drifted=0).

### Added - the Menu Starter: a whole menu flow as one copyable scene

- **demo/showcase/menu_starter.tscn + .gd** - the "UI starter": title, settings,
  game HUD (live clock + health bar), and a pause overlay, ALL driven by one HUD Kit
  behavior. Screens switch by name, the HUD updates by name, and every button routes
  through the pack's single On Button Pressed trigger into one `handle_button()`
  match - the scene contains ZERO connected signals. Copy it as your project's UI
  starting point. Byte-round-trip + scene wiring pinned in
  tests/showcase_examples_test.gd.

### Added - the HUD Kit pack: menus and HUDs by name, zero wiring

- **A 32nd behavior pack, HUD Kit** (first item of the Menu/HUD roadmap milestone):
  drop it under your UI root (CanvasLayer or Control) and drive named descendants -
  **Set Text**, **Set Bar** (any ProgressBar/TextureProgressBar), **Show / Hide /
  Toggle Panel**, **Switch Screen** (shows the named panel, hides its siblings - one
  call flips a whole menu), and **Show Toast** (a bottom-centre message that fades
  after a tunable delay). The headliner: **every descendant Button auto-wires into
  one On Button Pressed trigger** (with the Button Is condition and Last Button Name
  expression), so an entire menu needs zero connected signals; a Connect Buttons
  action re-wires after spawning UI. Named lookups are cached; freed nodes fall out
  on the next miss. Terse provider style, drift gate green (audited=32 drifted=0).

### Added - field buttons: a per-property action right where it belongs

- **"Field button"** on any exported variable renders a small button WITH the
  property that calls a sheet function on click - "Reroll" next to the seed,
  "Refresh preview" next to the path. Function plus optional label
  (`reroll_stats Reroll`); rides the decor channel as
  `# @inspector_action <function> <Label>`; needs a `@tool` sheet to act in-editor
  (the button disables itself with the reason otherwise). Unlike a Tool button -
  its own Inspector entry generated from a function - this one sits with the
  variable it concerns. Verify-gated round-trip; preview sentence + card mock.
  This closes the parity matrix's P5 tail. Pinned in
  tests/inspector_drawer_roundtrip_test.gd.

### Added - inline validation: a sheet function's warning shown at the field

- **"Validate with"** on any exported variable names a sheet function returning a
  warning String ("" = valid); the Inspector calls it a few times a second while the
  property is edited and shows the message right above the field - cross-field rules
  ("starting health must not exceed max health") surface where the mistake happens.
  Rides the decor channel as `# @inspector_validate <function>`; needs a `@tool`
  sheet to run in-editor and stays silent otherwise (never a false alarm).
  Verify-gated round-trip into the dialog field; stated in the preview sentence and
  mocked in the card. Pinned in tests/inspector_drawer_roundtrip_test.gd.
- The spec's parity matrix updated to the shipped reality; **field tint** recorded
  as a won't (Godot gives no seam to restyle a stock editor without replacing it)
  and **label override** as deferred to a drawer option.

### Added - toggle buttons: a String's choices as one visible row

- **An eighth drawer, `toggle_row`**: fill Options on a String and choose "Toggle
  buttons" - the Inspector shows every choice as a toggle button (the pressed one IS
  the value) instead of hiding them behind a dropdown. The choices ride the marker
  (`eventsheet:toggle_row:easy,normal,hard`) INSTEAD of `@export_enum` - one
  annotation slot - so without the plugin the field degrades to plain text, editor
  convenience only. Verify-gated lift back into editable choices (they reopen in the
  familiar Options field), a value outside the set is never clobbered, live dialog
  preview + preview-card sentence and mini row.
  Pinned in tests/inspector_drawer_roundtrip_test.gd.

### Added - the Inspector Designer edits: ✎ per row + ▲ reorder through the funnel

- The Designer is no longer view-only: every row gains **✎** (opens that variable in
  the shared Variable dialog - the same apply path as everywhere else - and the
  Designer refreshes on confirm) and, for sheet (tree) variables, **▲** (swaps the
  variable with the previous one in Inspector order as ONE undo step through the
  edit funnel). The first variable's ▲ is disabled; top-level variables sort
  alphabetically, so they edit but do not reorder. The Designer itself never
  mutates the sheet - every gesture routes back through the dock, and variables are
  resolved LIVE by name at click time (the funnel replaces resources on commit).
  Handlers unwired (tests, harnesses) keep the pure view. Pinned in
  tests/inspector_designer_test.gd, including the refuse-at-top case.

### Fixed - a clamped variable kept its drawer when reopened

- A variable carrying BOTH a drawer marker AND a clamp setter (the setter-suffixed
  `= 120:` line) lost its drawer on lift: the drawer emission quoted the expression
  default, the extraction's byte-verify failed, and the marker stranded as a verbatim
  hint - the Inspector then showed a plain field instead of the progress bar. The
  drawer branch now re-emits expression defaults verbatim, exactly like the
  structured-hint branch. Found by the Inspector Designer rendering EnemyStats;
  pinned with a full byte-round-trip in tests/inspector_drawer_roundtrip_test.gd.

### Added - the Inspector Designer: the whole sheet's Inspector as one view

- **Sheet ▸ Inspector Designer…** renders EVERY Inspector-visible variable of the
  sheet top-to-bottom as one live view - decor, grouping, and widgets through the
  same preview-card builders the Variable dialog uses (one source of truth: the
  view cannot drift from the per-variable previews), with the plain-language
  sentence under each. Sheet-level variables come first (the compiler's emission
  order), then tree variables in sheet order; unexported ones are skipped. This
  first slice is a pure read-only view - reorder/regroup gestures layer on next.
  Pinned in tests/inspector_designer_test.gd.
- The EnemyStats showcase gained a **loot table** (the new table drawer) - three
  drop rows in enemy_stats_example.tres, columns item/count/rare.

### Added - the table drawer: arrays edited as a grid

- **A seventh drawer, `table`**: an `Array` of `Dictionary` rows edited as a GRID in
  the Inspector - one row per element, one typed cell per column (text / number /
  checkbox), add / remove / move-up controls. Loot tables, wave definitions, and
  dialogue lines stop being Godot's generic array editor and become a spreadsheet.
  Define columns in the dialog as `name:type` pairs; the schema rides the marker
  (`eventsheet:table:item=String,count=int`), round-trips back into the Columns
  field, and the data is plain Dictionaries - the exported game needs nothing but
  the Array. Type-gated (Array only), live dialog preview, preview-card sentence +
  mini grid, cell edits guarded against mid-keystroke rebuilds.
  Pinned in tests/inspector_drawer_roundtrip_test.gd.

### Added - the suggestions dropdown (choices + free typing)

- A new String Inspector look, **"Dropdown with free typing (suggestions)"**: list
  choices in Details and the Inspector offers them as a dropdown while STILL
  accepting anything typed - the jam-friendly middle ground between a locked
  `@export_enum` and a bare text field. Emits Godot's native
  `@export_custom(PROPERTY_HINT_ENUM_SUGGESTION, "a,b,c")`, round-trips structured
  back into the Details field, gallery tile + preview-card sentence included.

### Added - required fields + the EnemyStats Custom Resource showcase

- **Required**: tick "Required" on an exported variable and the Inspector shows a red
  "⚠ Required - assign a value" badge above the field until it is set (a Resource
  left null, a String left blank; zero is a value, not missing). Rides the decor
  channel as a bare `# @inspector_required` comment - editor-only, parity untouched,
  verify-gated round-trip back into the dialog checkbox, stated in the preview
  card's sentence.
- **The showcase**: `demo/showcase/enemy_stats.gd` - a `class_name EnemyStats
  extends Resource` built entirely from a sheet, using the whole rich-inspector
  surface: accent section headers (Combat / Identity / Spawning), an info note, a
  REQUIRED portrait slot, a min-max damage range, a clamped health bar, swatches,
  an inline falloff curve, a placeholder, tooltips, and a `roll_damage()` helper.
  Click `enemy_stats_example.tres` in the FileSystem and the Inspector reads like a
  hand-built tool (the portrait is deliberately unset so the required warning shows).
  Byte-round-trip pinned in tests/showcase_examples_test.gd; regenerated by
  tools/build_examples.gd.

### Changed - the Inspector guide refreshed to the current feature set

- docs/INSPECTOR-DRAWERS-GUIDE.md now covers everything shipped this cycle - the
  min-max range slider, section-header + info-note decor, and the hover preview -
  and its Use Cases section grew from 8 to 14 brief recipes (spawn intervals,
  zoom bounds that cannot invert, shared-resource warnings, boss chapter headers,
  placeholder hints, and the hover-audit workflow).

### Added - hover a variable, see its Inspector + the Inspector toolkit for extensions

- **Hover preview**: hovering an exported variable row in the sheet pops a small live
  mock of its Inspector - decor, grouping, the chosen widget, and the plain-language
  sentence - so a whole sheet's Inspector can be audited without opening one dialog.
  Rides Godot's native tooltip pipeline (the `_make_custom_tooltip` seam), works for
  tree variables and sheet-level variables alike, and skips unexported ones.
- **EventSheets API grows the Inspector toolkit** (dock-free, same source of truth as
  the editor): `build_inspector_preview(...)` returns the live preview card for YOUR
  dialogs, `describe_inspector(...)` the one-sentence description, and
  `variable_code(variable)` the exact "Ships as:" GDScript a variable compiles to.
- **Custom Block API: the hover seam** - a block kind may override
  `hover_text(entry)` to explain its rows on hover (BBCode renders styled); the
  viewport asks the registered kind before its generic tooltips.

### Added - Inspector Designer P1: section headers + info notes (decor)

- **Two decor fields on every exported variable**: a **Section header** (an
  accent-colored label above the property; end it with `#rrggbb` to tint, e.g.
  `Combat #e06666`) and an **Info note** (a quiet panel for a sentence the designer
  must read - "Shared resource - edits affect every user."). They compose with any
  drawer and mock live in the Inspector preview card, which also states them in its
  plain sentence.
- Mechanism: plain `#` comments (`# @inspector_header ...` / `# @inspector_info ...`)
  emitted above the tooltip - never `##`, which would merge into the hover tooltip.
  The drawers plugin reads them from script source (cached per script) and injects
  the label/panel above the property; without the plugin (or in an exported game)
  they are inert comments - parity by construction. Verify-gated absorb lifts them
  back into editable dialog fields; both variable paths (dict + tree) emit one
  canonical shape. Pinned in tests/inspector_drawer_roundtrip_test.gd.

### Added - Inspector Designer P1: the min-max range slider drawer

- **A sixth Inspector drawer, `min_max`**: a Vector2 shown as ONE track with two
  draggable handles - the variable's `x` is the low end, `y` the high end. Spawn
  intervals, damage ranges, zoom bounds: "between A and B" as a single control instead
  of two disconnected number boxes. Same seams as the other five: an
  `eventsheet:min_max:<min>:<max>` marker on `@export_custom` (plain field without the
  plugin - parity untouched), bounds from the dialog's Range, verify-gated lift back
  into an editable `attributes.drawer`, live widget preview in the Variable dialog and
  the Inspector preview card. Vector2 is the first type to host TWO drawers (dial +
  range), so the "Show as" picker and its reopen re-select now handle a list.
  First slice of docs/internal/SPEC-inspector-designer.md; pinned in
  tests/inspector_drawer_roundtrip_test.gd.
- Docs sweep alongside: the drawers guide gained the Min-max range section, and stale
  third-party product naming was removed from docs and code comments.

### Added - 2D overlap queries: "what is HERE right now", no Area2D needed

- Three one-shot query actions in the new **Overlap 2D** category: **Query Bodies At
  Point**, **In Circle**, and **In Rectangle** - each collects the overlapping physics
  objects into a variable of your choice, so For Each picks over the results and
  Expression Is True gates on `not hits.is_empty()`. Explosion radii, pickup magnets,
  selection boxes, and room checks without wiring an Area2D. Multi-line templates with
  per-row {uid} locals (they carry the →N compression cue); parse-teeth pinned in
  tests/overlap_query_aces_test.gd. First item off the post-v0.11 roadmap.

## [0.11.0] - 2026-07-04 - The Structure & Vocabulary Update

### Changed - documentation overhaul: pictures, freshness, and a sharper README

- **Feature images shipped into the docs**: the ACE Studio (verb-kind cards + live
  picker preview + Ships-as signature), the Look Gallery (choose-by-picture Inspector
  looks), and the Anatomy panel (a behaviour's organs at a glance) - embedded in the
  behaviour and inspector guides. The README's hero screenshot regenerated to show the
  current editor: a colored region bubble, the group fingerprint, tempo badges, the →N
  compression cue, and badges/chips; the picker preview regenerated with featured verbs.
- **README refreshed to the current reality**: the "On main since v0.10.0" ledger
  (regions, Look Gallery, localisation, any-node reflection, terse providers, the
  abstraction levers, the public API), a v0.11 milestones row, and the abstraction
  story added to the feature tour. The early-project note now leads with the test
  discipline, and the MCP server moved to a single line at the tail of Tooling.
- **Stale docs removed**: the delivered code-free roadmap (its content lives on as
  shipped features and the behaviour guide).

### Changed - Extract to Function turns captured locals into parameters

- Extracting actions that use an event-scoped name no longer refuses outright. The
  capture plan is per-name: For-Each iterators always become typed parameters (the
  loop stays behind, the call passes the live value); a local whose `var` declaration
  travels WITH the extraction needs nothing; a local declared in a KEPT action becomes
  a parameter. Only a name declared nowhere visible still refuses - always-valid
  generated GDScript remains the load-bearing invariant, and the parameterized output
  is parse-verified in the test. The status message names any new parameters so the
  signature is no surprise.

### Changed - Extract to Function honours a partial selection

- Multi-select a run of an event's action cells and Extract All Actions to Function
  now extracts JUST those, leaving the rest in place with the call where the first
  extracted action was. The subset must be contiguous - extracting around a kept
  action would silently reorder execution, so a gapped selection refuses with a
  status hint. No selection (or all actions) keeps the original whole-pile gesture.
  Pinned in tests/extract_to_function_test.gd (subset core, selection read-back,
  gapped refusal).

### Added - the Anatomy panel's Uses entries jump to the behaviour

- Double-clicking a Uses entry opens that provider's script AS A SHEET - the same
  go-to-definition as Ctrl+Click on one of its verbs, with Alt+Left walking straight
  back. The last organ of the panel is now clickable like the rest. Pinned in
  tests/anatomy_panel_test.gd.

### Added - un-teach: taught verbs are managed where providers live

- The Manage ACE Providers dialog now also lists scripts taught project-wide (marked
  "taught project-wide"), and Remove is the inverse gesture: the verbs leave every
  picker while the sheet and its functions stay untouched. Settings-only, like
  teaching itself. Pinned in tests/teach_a_verb_test.gd (teach → list → un-teach →
  vocabulary gone).

### Added - featured verbs: the picker leads with intentions

- **The curated featured list grew from statements to intentions**: Wait, Every X
  Seconds, Play Sound, Play Animation, Destroy, Emit Signal, and Move Toward join the
  everyday set - featured verbs render bold and float to the top of their category,
  so a fresh sheet's picker reads like a verb menu, not an API listing. The curation
  lives in one visible const, typo-gated by a test against the live registry.
- **Addons can feature their hero verbs**: `.featured()` chains on a built-in
  descriptor and `## @ace_featured` annotates an addon member - both flow through
  definition metadata to the same highlight. Reserve it: featuring everything
  features nothing.
- The bold now synthesizes outside a themed editor too (embolden fallback), and the
  highlight is objectively pinned (featured tree rows carry the bold font, plain rows
  none) in tests/featured_aces_test.gd.

### Added - Teach a Verb: your project's vocabulary grows as you build

- **Sheet > Teach a Verb - Share Published Verbs** makes a sheet's exposed ƒ functions
  available in EVERY sheet's picker, node-targeted at $<ClassName> and retargetable -
  exactly like a behavior pack's ACEs. The verb keeps living in its home sheet (correct
  self-semantics: the code runs on the node that owns it); teaching only publishes the
  vocabulary, persisted in project settings so it survives sessions. Extract actions to
  a function (right-click an event), then teach it - two gestures from a pile of
  actions to a reusable project-wide verb.
- Teaching writes settings, never the sheet: no undo step needed, round-trips
  untouched. Guards refuse politely when the sheet has no class name or no published
  verbs, with the status line saying exactly what to do next.
- Pinned end to end by tests/teach_a_verb_test.gd (including a second sheet's registry
  seeing the taught verb) and render-verified in the picker.

### Removed - the row-type square that sat on every single row

- Every row (events, groups, comments, region markers, the add-event footers) carried a
  small colored square at its left edge - a vestigial "row type icon" that never became
  a real icon and said nothing the row itself doesn't (tempo badges, chips, and labels
  already carry the type). Gone everywhere; row geometry is untouched, so cached span
  positions and hit-tests are unaffected.

### Added - the compression cue: rows that compile to more than one line say so

- An action whose baked codegen spans N > 1 lines now shows a quiet muted "→N" after
  its text - abstraction is visible at a glance: compressing rows read as earned
  leverage, and plain 1:1 rows read as Extract-to-Function candidates. Completes the
  "show abstraction level" lever alongside the ƒ verb chip (function calls), "For
  each" loop rendering, and behaviour object labels. View-only; pinned by
  tests/abstraction_badge_test.gd and render-verified.

### Changed - every pack opts into @ace_expose_all(node); hand-written own-node templates gone

- **All 28 builder-backed packs now carry the one-line expose-all opt-in** weapon_kit
  pioneered, and the 39 hand-written `@ace_codegen_template("$<Class>.method(...)")`
  lines in their authored blocks are gone - the node-form synthesis produces the exact
  same templates from the method signatures. Templates that point anywhere OTHER than
  the pack's own node (host-targeted forms) correctly stay authored.
- **Proven a pure no-op on the vocabulary**: all 844 definitions dumped before and
  after - zero rows added, removed, renamed, recategorized, or retemplated. Same
  language, terser source; and no pack leaked an unannotated public into the picker.

### Changed - every pack teaches the class-level category default (one picker group per pack)

- **All 28 builder-backed packs migrated** to `sheet.addon_category` - the class-level
  `## @ace_category("...")` default weapon_kit pioneered - and their redundant
  per-member category lines were stripped from the authored blocks. Every shipped pack
  now demonstrates the current terse authoring style instead of the verbose one.
- **The vocabulary was characterization-gated at scale**: all 844 published definitions
  were dumped before and after - zero added, zero removed, zero name/type/codegen
  changes. The only diffs are 384 deliberate category moves: members that previously
  fell into inferred generic groups ("Gameplay" and friends) now join their pack's one
  tidy picker group, C3-behavior style.

### Fixed - the picker's codegen line is never blank for a working ACE

- Instance-backed reflected methods bake their owned-instance call at APPLY time, so the
  picker's info panel showed no codegen for them and the expression picker inserted the
  display NAME as if it were code. The synthesis now lives ON ACEDefinition
  (`instance_backed_template()`), and the apply-time bake, the info panel, and the
  expression insert all call it - what the UI shows is provably what gets baked (pinned
  in runtime_provider_test).

### Fixed - a twice-registered provider no longer double-lists in the picker

- The same provider reachable through two registration channels in one build (a scanned
  addon that is ALSO a registered autoload, or a sheet re-registering a scanned script)
  appended its definitions twice to the registry's flat list - every ACE showed twice in
  the picker and search, though keyed lookups were unaffected. The store now replaces in
  both structures (newest wins). Pinned in ace_registry_cache_test.

### Fixed - autoload providers call THE singleton, never a second copy

- **Template-less methods on an autoload provider used to bake to the owned-instance
  form** - spawning a second bus whose state the game never reads - and reflected
  properties baked to the $-node form, which resolves against the wrong branch of the
  tree. The generator now detects the registration (autoload path match) and
  synthesizes `<SingletonName>.member` for methods, property writes, and property
  reads, with no retarget param (you do not retarget a singleton).
- **Node-form templates no longer break on class_name-less scripts**: the $-default
  derives from the PascalCase filename ($BusFixture), never the spaced display id
  ("$Bus Fixture" is not a valid bare node path and silently defeated the {target}
  parameterization).
- Pinned by tests/autoload_provider_codegen_test.gd (registered vs unregistered forms).

### Added - every shipped pack is audited against the ACE provider system, permanently

- **tests/pack_provider_audit_test.gd sweeps every scanned addon script** (the exact
  list the live registry consumes - 33 scripts, 848 definitions) and holds each one to
  the provider covenant: the script instantiates, no unknown @ace_* annotations, and
  every action/condition/expression BAKES to real code (explicit template or reflected
  synthesis - never the silent-empty no-op). Triggers are exempt by design (signals
  bake through the trigger-connection path). Zero violations on landing; the gate now
  runs in every suite, so a pack can never drift out of date with the provider system
  unnoticed.

### Changed - Weapon Kit is the terse-provider showcase (and sheets can author class-level defaults)

- **Two new sheet fields close the authoring gap**: `addon_category` emits a class-level
  `## @ace_category("...")` (every member without its own category joins ONE picker
  group) and `ace_expose_all_mode` emits `## @ace_expose_all` / `(node)` - both
  metadata-only lines recovered by the importer exactly like `@ace_tags` (header-anchored,
  so a member's category can never be mistaken for the default).
- **Weapon Kit migrated to the terse form**: class-level category + expose_all(node)
  replace ~40 per-member annotation lines; members keep `@ace_name` only where the
  curated name genuinely differs (On Fire, On Empty, On Reload Complete, Is Full,
  Is Reloading). One deliberate vocabulary change: property ACEs moved from the
  inferred "Gameplay" category into the pack's "Weapon" group.
- **The whole vocabulary is pinned**: tests/weapon_kit_characterization_test.gd freezes
  all 52 published definitions (id, type, name, category, codegen) so the terse form
  provably publishes the same language - and any future row change must be a deliberate,
  changelog-noted decision.

### Fixed - reflected property actions compiled to NOTHING; now they write real code

- **The covenant gap is closed**: an @export var on a provider script reflects as Set /
  Add To / Subtract From actions plus a read expression - and those actions used to
  carry NO codegen, silently compiling to empty output. The generator now synthesizes
  the real assignment at generation time: Node providers write through the behavior
  node with a retargetable "On node" param defaulting to $Provider (exactly like
  reflected methods), while RefCounted/Resource utility providers write through the
  compiler-declared owned instance. The read expression inserts real code too (it used
  to insert the display NAME). Bonus: the picker's codegen strip now shows the true
  emission for property ACEs.
- **Autoload trigger baking no longer misses class_name-less scripts**: the
  class-to-singleton map keyed its fallback as PascalCase while provider ids derive
  with capitalize() - the lookup could never match, so trigger baking silently skipped.
  The map now uses the same derivation.
- Pinned by tests/expose_all_properties_test.gd (node form, utility form, and an
  end-to-end retargeted compile).

### Changed - the em-dash ban now covers code, not just docs

- Swept " — " to " - " across 438 .gd files (~1,900 comment and display-string lines:
  warnings, status text, lift-report messages, dialog copy) plus the few remaining
  text files. Six compiler-emitted strings are deliberately EXEMPT and frozen (the
  DO-NOT-EDIT banner, the group-locals header, the unknown-row and disabled-group
  breadcrumbs, the Inspector-conditions header): they are part of the emitted shape,
  and changing them would break byte-identical re-emission of existing generated
  files. Suite green, drift=0, doctor 0 errors after the sweep.

### Added - Doctor checks are an extension point + the run_doctor MCP tool

- **Packs and plugins can ship project-health checks**: `EventSheets.register_doctor_check(id, callable)`
  adds a check that runs after the built-ins everywhere the Doctor runs - the dock's
  Tools panel, the headless CLI, CI and MCP. A check receives every sheet path plus the
  shared findings array and appends `{severity, check, path, message}` findings under the
  same covenant as built-ins (never write inside res://). Re-registering an id replaces,
  so plugin reloads never duplicate. `EventSheets.doctor()` runs the whole audit as a
  dock-free service.
- **Dogfooded end to end**: the Doctor panel and `tools/project_doctor.gd` now route
  through `EventSheets.doctor()`, so extension checks report in every runner exactly
  like built-ins.
- **New MCP tool `run_doctor`**: AI assistants get the full health audit (findings +
  error/warning/info counts) as a read-only tool, seventh in the toolset.
- Guide grew a Project Health section (docs/BUILDING-ON-EVENTSHEETS.md); em-dash residue
  swept from the doctor/MCP files' comments and finding messages.

### Added - the EventSheets public API: one class to build on

- **`EventSheets`** (`addons/eventsheet/api/eventsheets.gd`): the all-static facade every
  extension calls instead of reaching into editor internals, with the same stability
  covenant as `ace_id`s - shapes never rename once shipped. Three service groups:
  VOCABULARY (`register_provider_script`, `register_block_kind`, `find_ace`,
  `class_vocabulary`), EDITOR (`current_sheet`, `open_sheet`, the `edit()` undo funnel -
  one labelled undo step with refresh + dirty handled, `set_status`, Command Palette
  registration), and CODEGEN (`compile`, `open_gd_as_sheet`, and `round_trips()` - the
  byte gate as a one-line service). Editor services no-op safely with no dock open;
  vocabulary and codegen work anywhere, including headless CI.
- **The plugin dogfoods its own API**: the four region fold commands now reach the
  Command Palette through `EventSheets.register_palette_command` (the palette merges
  extension entries after the built-ins), and the MCP server's compile and import tools
  route through `EventSheets.compile` / `EventSheets.open_gd_as_sheet`.
- **`docs/BUILDING-ON-EVENTSHEETS.md`**: what you can build, the one-minute EditorPlugin
  tour, per-group walkthroughs, the full reference table, and the mistakes that bite
  (cached rows across `edit()`, mutating shared definitions, the `"output"` result key).
- Pinned by `tests/eventsheets_api_test.gd`: dock-free codegen + vocabulary, the `edit()`
  funnel against a real dock, palette register/replace/unregister, and the fold commands
  arriving through the public seam.

### Changed - mega-file breakdown: five new commented subsystem modules

- **The viewport sheds four subsystems** (3,752 -> 2,753 lines, UNDER 3k): folding + region fold
  persistence (`interaction/viewport_folding.gd`), the 260-line per-row geometry pass
  (`interaction/viewport_layout_builder.gd`), and the box-selection + row/ACE drag gestures
  (`interaction/viewport_drag.gd`), and the four input handlers behind _gui_input
  (`interaction/viewport_input.gd`).
- **The dock sheds eight** (4,624 -> 3,313 lines): the five UI construction passes
  (`dock/dock_ui_builder.gd`), the input dispatch layer - row-menu routing, workspace
  shortcuts, Surround with Region (`dock/dock_input_dispatch.gd`), and the side-panel
  glue - provenance highlighting, the Functions list, the raw-GDScript dialog flow, the
  Open Sheets panel prefs (`dock/code_panel_glue.gd`), provider registration
  (`dock/provider_registry_glue.gd`), the Sheet Type dialog glue (`dock/sheet_type_glue.gd`),
  the sheet/selection query helpers (`dock/sheet_queries.gd`), and the add-row request
  handlers (`dock/add_row_requests.gd`), and the Extract-to-Function / Extract-to-Include
  operations (`dock/extract_ops.gd`).
- Every move is VERBATIM behind the established `_dock.`/`_viewport.` back-reference with
  one-line delegates keeping all call sites (and tests) untouched; each new module opens
  with a header explaining what lives there and why state stays on the host. Suite green
  after every step.

### Added - any-node reach, part 3: your own classes reflect too

- **User `class_name` scripts reflect like engine classes**: the sheet's host class being a
  custom node resolves through the project's global class list, and the script's own methods,
  signals, and exported properties become the same "All of <Class>" vocabulary. The Custom
  ACEs guide opens with the reflected-vocabulary story ("Every node speaks EventSheet") and
  where curated providers still win.

### Added - any-node reach, part 2: reflected properties, class-aware member pickers

- **Every editor-visible property reflects as a pair**: "Set <Property>" (plain assignment)
  and a read expression, in the same "All of <Class>" section as the reflected methods and
  signals - curated verbs still shadow their reflected twins.
- The Helper ACEs' Call Method / Set Property member fields already complete from the host
  class (reflected, inherited members included); now pinned alongside the ClassDB source so
  the two reflection surfaces stay in step.

### Added - any-node reach, part 1: every Godot class is browsable vocabulary

- **ClassDB reflection on demand**: the picker grows an "All of <host class>" section for
  the sheet's own class - its methods classify by return type (void = Action, bool =
  Condition, anything else = Expression) and its own signals become triggers, all reflected
  live from the running engine, so ANY class works (including classes future Godot versions
  add) without a hand-authored module.
- **Parity and safety intact**: every reflected verb emits the same plain
  `{target.}member(...)` call the curated vocabulary uses; curated verbs are never shadowed
  (exact-template filter); definitions are session-cached and immutable; Simple Mode skips
  the deep end; reverse-lift stays as conservative as ever. Pinned in `classdb_source_test`
  with engine-drift-safe floors.

### Added - localisation, part 3: the Doctor nudge + the Translating Your Game guide

- **Project Doctor**: sheets that translate text (tr / Set Language) while the project has
  no translation catalog registered get an advisory pointing at Godot's own pipeline (POT
  Generation over the compiled .gd, catalogs under Localization > Translations).
- **`docs/TRANSLATING-YOUR-GAME.md`**: the end-to-end walkthrough - mark with the globe,
  generate the POT, add a language via CSV or .po, switch live with Set Language, refresh
  on On Language Changed - including the sharp edges (never wrap variable DEFAULTS in tr();
  never mark identifiers like node paths or group names).

### Added - the Translation vocabulary: switch languages from events

- **Seven new built-in ACEs under Translation**: Set Language (`TranslationServer.set_locale`),
  Current Language, Translate / Translate With Context / Translate Plural (`tr`, two-arg `tr`,
  `tr_n`) - each a bare native call, parity-clean.
- **On Language Changed**: a trigger for the engine's translation-changed notification. It
  compiles to the `_notification` virtual and applying it auto-adds the "Language Just
  Changed" gate condition - visible in the sheet, deletable, round-tripping as the plain
  event + condition it is (the same apply-time-baking idiom as `{uid}`).

### Added - translatable text params: localisation the Godot way, part 1

- **A globe toggle on plain string params** (the params dialog): lit, the value ships
  wrapped in `tr("...")` at its usage site - so Godot's own localisation pipeline does the
  rest with zero plugin runtime: Project Settings > Localization > POT Generation finds the
  call in the compiled `.gd`, translators fill `.po`/`.csv`, and `TranslationServer` swaps
  languages live. The convention lives IN the value, so emission, the reverse-lift, and the
  byte round-trip are untouched by construction (pinned in `translatable_params_test`).
- The toggle stays dim until lit (most params are not player-facing text) and unwraps an
  incoming `tr("...")` value back into plain text with the globe on; the two-argument
  context form stays verbatim (it belongs to the expression field).

### Added - region folds survive reopen (editor state, never the bytes)

- **Fold state persists per project**: folded regions are remembered across editor sessions
  in per-project editor metadata, keyed by the sheet's path and a stable "label#occurrence"
  region key - the `.gd` never changes by a byte (a fold is editor state, not code). Only
  folded regions are stored, session fold state still wins within a session, and an all-open
  sheet stores nothing. Pinned in `region_folding_test`.

### Added - region fold commands: Fold All, bracket shortcuts, Surround with Region

- **Command Palette**: Fold All Regions, Unfold All Regions, and Fold/Unfold Everything
  (regions + groups) sweep the whole sheet in one step.
- **Ctrl+Shift+[ / ]** fold and unfold the region CONTAINING the selection (script-editor
  muscle memory); folding lands the selection on the opener so it never vanishes.
- **"Surround with Region…"** on the row context menu (More) wraps the selected top-level
  rows in a fresh fence pair as one undo step, then opens the fence editor so the region
  gets its name, description, and color immediately.

### Added - regions grow up: color, description, drag-in glow, and everything nests

- **Editable color + description per region** (the fence's edit dialog gains a color picker
  and a description field, group-style): the label and the bubble outline wear the region's
  color, and the description reads inline on the opener row. Region rows carry NO kind pill -
  the fold arrow, the colored label, the bubble, and the description say what the row is, and
  the closing fence reads as a dim "end of <name>" marker. Styled openers round-trip via
  an `## @ace_region(#color, "description")` marker line above the fence - byte-gated, and
  a plain `#region` line stays byte-identical to what it always was.
- **Groups and every block kind nest inside regions**: whatever sits between the fences
  (groups, enums, signals, preloads, variables, notes) folds with the range.
- **Drag-in glow**: while dragging any event or code row, the region range the drop would
  land inside brightens its bubble (thicker border + faint fill), so "this goes in the
  region" is visible before you let go.

### Added - collapsible regions: #region fences fold like the script editor

- **Matched `#region` / `#endregion` fence rows now pair into foldable ranges**: the rows
  between them become the opening fence's children (with the closing fence riding dimly at
  the bottom), the familiar fold arrow collapses the range, and a folded region names its
  hidden content ("Combat · 12 rows hidden"). Left/Right arrow folding and search reveal
  work unchanged because regions ride the existing fold machinery.
- **The Discord-bubble outline**: an unfolded region draws a thin rounded accent line around
  the whole range it covers (the same treatment variable folders get), nesting with nested
  regions and insetting with the opener's indent, so a region reads as one enclosed span.
- **View layer only, by construction**: the sheet still stores flat fence rows, so emission
  and the byte round-trip cannot be affected - pinned by `region_folding_test` alongside the
  pairing shape, nesting, and the wart-not-error rule (unbalanced fences stay flat rows).

### Changed - Simple Mode reaches the Variable dialog; grouping gets a menu route

- **Simple Mode now gates the Variable dialog**: the Advanced tier (show-if, lock-unless,
  on-changed, clamp, read-only, grouping fields) hides entirely - it is wiring, not looks.
  Display-only: attributes already on a variable round-trip untouched, and the tier returns
  the moment Simple Mode turns off (pinned by `variable_dialog_simple_mode_test`).
- **"Group Under a Heading..."** on the variable right-click menu folds the multi-selection
  (or the clicked row) into a new Inspector group and opens the same naming popup the drag
  gesture uses - grouping stays discoverable for users who never find the drag.
- The drawers guide gains a "Choosing by Picture" walkthrough (gallery, preview card,
  sentence, Simple Mode); the progressive-disclosure spec records the audience axis as
  reaching the dialog.

### Added - the Inspector preview card: see the final Inspector before you press OK

- **A live mock above "Ships as:"** shows what the Inspector will actually display for the
  variable being edited: the group header, the subgroup indent, the humanized property name,
  and the chosen widget (progress bar, slider, folder picker, direction dial, swatches...) -
  reusing the Look Gallery's miniature builders so the two previews cannot diverge. Hidden
  for unexported variables.
- **A plain-sentence summary** beneath the mock states the same choices in C3-first language:
  "A whole number, from 0 to 100, shown as a progress bar, grouped under Combat > Defense."
  The sentence builder is pinned as exact strings across an 11-case matrix
  (`inspector_preview_test`); the "Ships as:" strip stays the code truth below it.

### Added - the Look Gallery: choose an Inspector look by picture

- **"Browse..." next to the Inspector-look dropdown** opens a gallery of picture tiles - one
  per look, each showing a non-interactive miniature of the real Inspector widget (checkbox
  flags, layer grids, file pickers, easing curves, linked axes...) with a plain name and a
  one-line explanation. A beginner recognizes a slider long before they know the phrase
  "export hint".
- **One source of truth**: the dropdown, the gallery, and the tests all read the new
  `EventSheetInspectorLooks` preset table + type filter, and a chosen tile drives the same
  dropdown + fold path, so the surfaces cannot drift. Looks that need details (flag labels,
  file filters) land with the Details field focused.
- Pinned by `look_gallery_test`: exact per-type preset id lists, a preview miniature for
  every look, mouse-transparent previews, and gallery tiles == Default + the filtered set.

### Added - the terse provider dialect, part 3: the typed registrar + authoring aids

- **`static func _eventforge_register(reg: EventForgeRegistrar)`**: a fluent, fully typed
  alternative to the comment dialect - the script editor autocompletes the whole vocabulary
  and a typo is a compile error. Registrar calls annotate existing members, merge onto
  comment annotations field by field, and produce definitions identical to the comment
  dialect (equivalence pinned member-for-member across twin fixtures).
- **Copy-ready stubs**: right-click any ACE in the picker for "Copy annotation stub" or
  "Copy registrar snippet" - a paste-ready, fully-annotated skeleton of that exact ACE
  (params, hints, options, and the typed func/signal line included).
- **New Script template**: the script dialog gains an "EventForge ACE Provider" template
  whose skeleton teaches the terse dialect.

### Added - the terse provider dialect, part 2: one-line params + convention widgets

- **`@ace_param(name, hint: expression, options: a|b, desc: "text")`**: everything about one
  parameter in a single annotation - widget hint, fixed dropdown, editable suggestions, and
  (new) a per-param description that finally reaches the params dialog. Options split on `|`
  so commas stay free; a quoted desc keeps its commas. The long `@ace_param_*` forms all
  still work.
- **Convention widgets**: with no hint at all, a param named `color`/`*_color` gets the color
  picker, `anim`/`*_anim`/`*_animation` the animation picker, `*_signal`/`signal_name` the
  signal picker, `*_scene`/`scene_path` the scene picker, `*_audio`/`audio_path` the audio
  picker. Explicit hints always win; pinned by tests.

### Added - the terse provider dialect, part 1: write less, typos warn

- **Your doc comment is the description**: plain `##` prose above a provider member now becomes
  the ACE's tooltip text; `@ace_description` is only needed when the picker text should differ
  from the code documentation.
- **Pack-wide defaults**: class-level `@ace_category` / `@ace_icon` (above `class_name`, like
  `@ace_expose_all`) default every member; member-level annotations still win. Precedence is
  member > class default > automatic fallback, pinned by tests.
- **Typos warn instead of vanishing**: an unrecognized `@ace_*` token prints a warning naming
  the script and token. Annotation dispatch is exact-token now, so a typo like `@ace_names`
  can no longer prefix-match a real annotation and silently rename an ACE (it used to).
- A fully-described, categorized action is now 3 lines: one prose doc line, the class-level
  category (once per pack), and the func. Suite + 31-pack drift gate green throughout.

### Added - the v0.11 roadmap spec

- **`docs/internal/SPEC-v0.11-roadmap.md`**: five census-grounded feature specs for the next
  release - localisation the Godot way (a translatable mark on string params that emits `tr()`
  so Godot's own POT/TranslationServer pipeline does the rest, plus a small Translation ACE
  module), a choose-by-picture Look Gallery + live Inspector preview for designing exported
  properties, collapsible `#region` fences riding the existing fold machinery (pairing in the
  view layer only, fold state persisted outside the bytes), a terser ACE provider dialect
  (doc-comment-as-description, pack-level defaults, one-line param specs) plus a typed
  registrar that gets real script-editor autocomplete, and on-demand ClassDB reflection so any
  existing or future Godot node class is browsable vocabulary without hand-authored modules.

## [0.10.0] - 2026-07-04 - The In-Sheet Authoring Update

### Removed - vestigial designer template scenes; theme tokens are now the single source of truth

- **`addons/eventsheet/elements/` deleted** (the three preview `.tscn` scenes and their two
  template scripts, plus `docs/elements/`): these were designer-preview vestiges of the removed
  Control-widget editor era. The live virtualized renderer never instantiated them; their only
  real job was seeding default token values into a fresh `EventSheetEditorStyle`.
- **Default look now baked in code**: `EventSheetEditorStyle.ensure_defaults()` seeds the exact
  same token values the scenes used to provide (proven token-identical by a before/after dump
  of every token in a fresh style). Bundled themes, the manifest template, and the style tests
  no longer reference any scene; the theme `.tres` token resources are the single source of
  truth for the renderer.

### Changed - every user guide restyled to one house structure; the Custom Block API gets a real guide

- **`docs/CUSTOM-BLOCKS-GUIDE.md`**: the Custom Block API's dedicated user guide - intro + TOC,
  scenarios-first, the full kind-contract reference table, schema-vs-resource kinds, the free
  add/edit UX, the byte-gate safety chapter, built-in kinds reference, seven worked use cases,
  a headless testing recipe, and tips. The internal spec file is retired; the ACEs guide's
  blocks chapter is now a pointer.
- **All nine user guides restyled to the same shape** (recipes, C3 migration, using-with-code,
  code-free behaviours, performance, MCP server, glossary, uninstall, version control): an
  intro paragraph, a linked Table of Contents, a scenarios-first opener, tables for reference
  material, and a derived Tips and Common Mistakes section - with every audited factual claim,
  command, and code example preserved verbatim.
- **`CLAUDE.md`** added: operational guidance for AI-assisted sessions (commands, verification
  traps, standing contracts, house rules); AGENTS.md's stale indentation-split claim fixed
  (the whole plugin is tabs, suite-enforced).


### Fixed - a silent block-registry init bug + cache hardening (from the dedicated hunt)

- **A rescan-first registry touch silently lost the built-in block kinds** (enum, signal,
  preload, region) for the whole session - `rescan_pack_kinds()` marked built-ins as
  registered without registering them, masked in the shipped editor only by UI-build order.
  Rescan now ensures the built-ins first; a cold-order test pins it.
- **Cache hardening**: the definition-cache key gained the file's byte length (mtime alone has
  seconds resolution - two same-second saves would have served stale definitions), stale keys
  for a re-saved script are pruned, and the registry dropped a dead `hot_reload` path that
  retained references to freed provider instances. An independent silent-bug hunt verified the
  rest: shared definitions are never mutated post-generation, freed sources are unreachable
  from cached definitions, and the new attribute round-trips reject bad data loudly.

### Changed - the editor opens and switches tabs much faster

- **ACE definitions are cached across registry refreshes.** Reflecting the 30+ provider
  scripts into ~1,400 definitions cost ~200 ms and ran on EVERY tab activation; measured
  refreshes now take ~5 ms warm. Safe because definitions are immutable after generation (the
  apply path bakes templates into row copies, never back into a definition); builtins cache
  per session, and script-backed sources key on path + saved mtime so saving a provider
  script self-invalidates its entry - no manual invalidation to forget.
  (`tests/ace_registry_cache_test.gd`)


### Added - the Custom Block API is complete: edit seam + plugin-to-plugin registration

- **Kinds own their editors.** `EventSheetBlockKind.edit(dock, block)` lets a kind open its own
  dialog instead of the generic schema form, and the dock now routes EVERY block edit through
  the registry - dogfooded immediately: the built-in enum and signal rows dispatch to their
  dedicated dialogs through the hook, so built-ins and pack kinds edit through one seam.
- **Other plugins can register kinds in code**: `EventForgeBridgeRuntime.register_block_kind()`,
  the sibling of `register_script_as_provider`, for tools that cannot drop files into
  `eventsheet_addons/`. The Custom Blocks guide documents both.


### Fixed - three bugs from the adversarial code review

- **Renaming a variable subgroup now reaches members nested under an event's sub-rows** - the
  rename walker recursed groups but not `sub_events`, so a buried member silently kept the old
  `@export_subgroup` name while its siblings renamed.
- **Switching a sheet to Autoload keeps its forced `Node` host** - the Sheet Type dialog's
  prefilled host text used to overwrite it back, compiling a singleton as
  `extends CharacterBody2D`.
- **Clearing a variable group also clears its subgroup** - an orphaned `@export_subgroup`
  nested the members under whatever unrelated group came earlier in the Inspector.


### Added - the export-coverage tail: password/expression/link + flagged easing

- **The annotation-less PropertyHints are now named presets**: "Password field",
  "Expression field", and "Linked axes" ship as canonical `@export_custom(PROPERTY_HINT_…)`
  lines, round-trip byte-gated like every other family, and appear in the Inspector-look
  picker for their types (String / vectors). **Flagged exp-easing**
  (`@export_exp_easing("attenuation")`, `"positive_only"`) rounds out the easing story with
  two dedicated looks for floats.

### Added - subgroups by the same drag, and a starter that teaches the options

- **One level deeper, same gesture**: dropping a variable onto a variable it ALREADY shares a
  folder with nests both into a **subgroup** - the same name-it-afterwards popup opens (now
  saying "names the subgroup"), and it ships as `@export_subgroup` under the group. Renaming
  reaches every member, dict globals and tree variables alike.
- **The LootTable starter now demonstrates two real inspector options in context**: a bounded
  `rolls` slider with an open top (`or_greater`) and a `pickup_sound` file picker
  (`*.ogg, *.wav`) - a newcomer's first custom resource shows the vocabulary working.

### Added - the "Inspector look" picker: every export option in plain language

- **The variable dialog teaches the whole export surface.** A type-filtered **Inspector look**
  picker offers each option as what the Inspector SHOWS - "File picker (project files)",
  "Checkbox flags (Fire, Ice…)", "2D physics layers grid", "Node picker with a type filter",
  "Saved but hidden (storage)" - with one contextual Details field (filters / labels / node
  types) and **Slider extras** (no upper/lower limit + a unit suffix) beside the Range. A live
  **"Ships as:"** strip renders the exact annotation those choices compile to, straight from
  the compiler's own prefix builder, so the plain-language names teach the annotations instead
  of hiding them (the ACE Studio pattern).

### Added - full inspector export coverage, P1 (every hint family round-trips editable)

- **The wider @export families are now structured, dialog-ready attributes** instead of
  verbatim hints: range WITH its modifier tail (`or_greater` / `or_less` / `exp` /
  `hide_slider` / `radians_as_degrees` / `degrees` / `suffix:px`), checkbox **flags** (with
  explicit values, `"Fire:1"`), the seven **layer-mask** grids (2D/3D physics, render,
  navigation, avoidance), **file/folder pickers** (`@export_file("*.ogg")`, global variants),
  **node-path type filters**, **int-backed enums** (`"Slow:30"`), `@export_storage`, and
  `@export_category`. One canonical builder drives BOTH variable paths (dict and tree row), the
  importer upgrades each recognized hint into the same editable attributes verify-gated, and
  anything hand-written outside the canon stays a verbatim hint - degradation, never
  corruption. (`tests/full_export_coverage_test.gd`; spec: SPEC-full-export-coverage)
- Fixed on the way: int-backed `@export_enum` was mis-parsed as a String combo (the variable
  then failed its byte gate and stayed a raw block), and expression defaults
  (`NodePath("")`) were re-quoted by the hinted/structured emission branches.


### Changed - the whole codebase follows the GDScript style guide, gated

- **495 hand-written scripts swept to the official GDScript style guide**: `class_name` now
  precedes `extends` everywhere (362 files), and every top-level function/class is surrounded
  by two blank lines (480 files reflowed, multiline-string aware so test fixtures with
  column-0 `func` inside `"""` strings were untouched). A new suite test
  (`tests/style_guide_test.gd`) enforces header order, the two-blank-line rule, and snake_case
  naming on every run, so compliance cannot silently regress. Documented deviations: four
  public-API resource properties keep their legacy camelCase names (renaming breaks saved
  `.tres` files and the pack-author compatibility covenant), and compiler OUTPUT keeps its
  single-blank-line contract (changing it would churn every golden fixture and user resave).

### Added - script intent: custom resources + editor tools are first-class destinations

- **The New menu now asks what you are making.** Starters group under intent sections -
  Scripts on a node / Behaviours / Autoloads / **Custom Resources - data assets (.tres)** /
  **Editor Tools - run inside the editor** - so a newcomer discovers resources and tools the
  moment they create their first sheet, with no wizard slowing creation down. Two new starters
  model each idiom small: **Custom Resource (data + logic)** (a LootTable: exported fields ARE
  the designer-editable asset, logic lives in a callable function) and **Editor Tool
  (one-click chore)** (an @tool EditorScript with an On Editor Run event).
- **Sheet Type gained "Custom Resource (data asset)"**: keeps a Resource-subclass host
  (AudioStream, a project class) and falls back to plain `Resource` for node-ish hosts, so the
  choice always yields a valid asset script.
- **`EventSheetScriptIntent`** - one derived-not-stored classification (behaviour / autoload /
  editor tool / custom resource / custom node / plain) driving all the intent-aware UX from a
  single extendable table: the identity banner now pins each type distinctly (Custom Resource,
  Editor Tool, Autoload - autoloads were previously invisible in the banner), and an **empty
  sheet shows intent-specific advice** (resources: exported variables + functions instead of
  events; tools: On Editor Run; autoloads: project-wide signals and functions).
  (`tests/script_intent_test.gd`)

### Added - custom-return helpers lift too (the pack audit's last blocked class)

- **`_get_pool(type: String) -> HealthPool`-style helpers now lift to real, editable
  EventFunctions.** The lifter refused any function returning a custom/engine class because it
  could only emit functions at the file's end; with in-place anchors that refusal is obsolete on
  the ANCHOR path - `return_type_name` carries the class verbatim and each helper still passes
  the per-anchor byte gate. The trailing scan deliberately keeps refusing them (claiming one
  there would reorder the file and revert the whole run - the health pack went 34 lifted
  functions to 0 during development when both paths were opened; the flag split fixed it).
  Health now lifts 35 functions with `_get_pool` anchored in place.

### Added - mid-file functions lift in place (FunctionAnchorRow)

- **A helper function in the MIDDLE of a hand-written `.gd` now lifts to a real, editable
  EventFunction.** Before, only a trailing run of functions could reverse-lift (functions emit
  in the trailing section, so a mid-file lift would reorder the file and fail the byte-verify).
  Now the lifter replaces the helper's slot with a `FunctionAnchorRow` and the compile path
  emits the function exactly there. Every anchor is gated individually - it lifts only when the
  compiler's re-emission reproduces the source lines byte-for-byte - so a file that lifts today
  can never regress; an unreproducible helper just stays a GDScript block. Engine virtual
  callbacks (`_enter_tree`, `_process`, `_get_configuration_warnings`, …) are excluded: they are
  structure, not vocabulary. Anchors render as a muted "ƒ name() - defined here" marker; the
  function itself is edited through its Define block / the Functions panel.
  (`tests/mid_file_function_lift_test.gd`)

### Added - Custom Block API P1 (the core, shipped)

- **Register your own non-ACE row kinds.** `EventSheetBlockKind` (one stateless descriptor per
  kind: field schema + pure `emit()` + byte-verify-gated `lift()` + `summary()` display) +
  `CustomBlockRow` (ONE generic resource per row, so sheets still load and read as plain
  GDScript when a kind is absent) + `EventSheetBlockRegistry`. The compiler, importer, and
  viewport are wired ONCE generically: blocks emit in array position on `.gd` sheets, lift only
  when re-emission reproduces the source byte-exactly (a permissive kind can never corrupt a
  sheet), and render as a kind badge + one-line summary.
- **Two built-in proof kinds**: **Preload Resource** (`const Sfx := preload("res://…")`) and
  **Region marker** (`#region Name` / `#endregion`) - both now open as first-class rows in any
  `.gd` sheet instead of raw GDScript blocks. (`tests/custom_block_test.gd`)
- **P2: packs define block kinds zero-config.** Drop a script extending `EventSheetBlockKind`
  into `res://eventsheet_addons/` and it registers automatically (the same scan that finds ACE
  providers; detection walks the base-class chain so ordinary provider scripts are never
  instantiated). kind_ids from packs are namespaced `<pack>.<name>` (warned otherwise). Living
  proof ships in-repo: `eventsheet_addons/demo_note_block.gd`, a 30-line "Note" kind that turns
  `## NOTE: …` lines into first-class highlighted rows. `docs/CUSTOM-ACES-GUIDE.md` gained a
  "Custom Blocks" chapter walking through it line by line.
- **The API is dogfooded: the plugin's own enum AND signal rows now RUN on it.** `EventSheetBlockKind`
  gained a resource-kind layer (`handles()` / `emit_lines()` / `summary_for()` / lift claims
  that return a ready resource), and `EnumRow` registered as the built-in "enum" kind: the
  compiler's enum emission, the importer's enum lift, and the viewport's enum summary all
  dispatch through `EventSheetBlockRegistry`, and `SignalRow`'s declaration contract followed
  as the "signal" kind (the trigger-annotation fold stays with the importer - it is cross-row
  pending surgery, not a per-row contract) - byte-identical output (drift=0 over all 31 packs),
  saved sheets and the dedicated dialogs untouched. Resource kinds are excluded from the
  generic add surfaces (`addable_kinds()`); their row classes keep their dedicated flows.
- **P3: custom blocks in the command palette.** Ctrl+P now lists "Add <kind>…" for every
  registered kind (built-ins and pack-defined alike), built per open so a freshly dropped pack's
  kinds appear without a restart.
- **Add + edit UX, zero UI code per kind**: every registered kind gets an entry in the
  **Add ▾** menu and a schema-driven dialog (a text field per String, a checkbox per bool, a
  number spinner per int/float) built straight from its `fields()` schema
  (`dock/custom_block_dialog.gd`); double-clicking a block row opens the same dialog prefilled.
  Both paths apply through the undo funnel.

### Added - Custom Block API design

- **`docs/internal/SPEC-custom-block-api.md`**: the design for registering NON-ACE row kinds
  (preloads, region markers, includes-as-rows, config blocks, pack-defined data blocks) without
  touching the plugin. One `EventSheetBlockKind` contract (fields schema + pure `emit` +
  byte-verify-gated `lift` + `summary` render) wired ONCE through the compiler, importer,
  row builder, and a generic schema dialog; a single `CustomBlockRow` resource so sheets degrade
  gracefully to plain GDScript when a kind is missing. Phased P1 (core + two proof kinds) →
  P2 (zero-config pack kinds via the addon scanner) → P3 (picker integration).

### Changed - maintainability

- **Quick prompt popups extracted from the dock** into `dock/quick_prompt_dialogs.gd`
  (`EventSheetQuickPromptDialogs`): the Extract-to-Function name prompt, the Conditional
  Breakpoint expression prompt, and the Group editor (name + description). Pure move - the dock
  keeps thin delegates so menus, viewport signals, and tests are unchanged; the dock drops to
  ~4,100 lines (from 8,500 before the breakdown campaign).

### Changed - documentation cleanup

- **Docs freshness pass** (three parallel code-verified audits over every guide and spec):
  fixed RECIPES.md's stale "Tools > behaviors" attach path (it is **Tools > Attach to Selected
  Node**), UNINSTALL.md's removed "Eject EventSheets" menu item and nonexistent `tools/eject.gd`
  (it is **Tools > Project Doctor** / `tools/project_doctor.gd`), AGENTS.md's outdated
  groups-dissolve-through-`.gd` note (the round-trip shipped) and screenshots-impossible note
  (the `tools/render_*.gd` harness renders real editor PNGs), and stamped the Open Sheets panel
  spec SHIPPED (the panel mounts in-workspace). Deleted the banner-marked historical
  `EVENTSHEET_ARCHITECTURE_SLICES.md` tracker. Everything else verified accurate.

- **All documentation is now em-dash-free.** Every hand-written doc (README, CHANGELOG, docs/,
  AGENTS.md, CONTRIBUTING.md) plus every GENERATED surface: the vocabulary-doc and pack-README
  formatters and all pack-builder ACE description strings now use plain dashes, so regenerated
  docs stay clean. Packs rebuilt (drift=0).
- **Eleven superseded internal docs deleted**: the seven early-era "historical record" snapshots
  (Auto-ACE/C3 alignment statuses, progress report, the three original design pitches) and four
  fully-shipped specs whose outcomes live in this changelog (construct parity, ACE-picker cleanup,
  condition blocks, preview-gd-as-eventsheets). Specs with live deferred work remain, and the
  behaviour-parity + code-free-UX specs now say SHIPPED instead of "proposed".

### Added - the ACE Studio: define and edit a behaviour's verbs in plain language

- The sheet-function dialog is now the **ACE Studio**: "What kind of verb is this?" is three
  plain-language cards - **Does something** (Action, amber) · **Is it true?** (Condition, teal) ·
  **A value** (Expression, violet) - with a **live picker preview** ("this is what other people will
  see") and a quiet **"Ships as:" `func …` strip** built from the compiler's own formatters, so the
  preview can never disagree with the generated code. (`tests/ace_studio_signature_test.gd`)
- **Edit a verb in place**: double-clicking a Define block on the canvas opens the same Studio
  pre-filled (name, kind card, params, expose block). Confirming with nothing changed is a hard
  no-op - an accidental open-and-OK on a reverse-lifted helper stays byte-identical on save.
  (`tests/function_edit_dialog_test.gd`)
- **Starter recipes** in the New Behaviour Addon dialog: alongside the teaching skeleton, "Start
  from" offers two small complete behaviours - **Cooldown** (start / is-ready / time-left) and
  **Stat pool** (spend / restore / percent) - every verb annotated, so a freshly created addon opens
  code-free immediately. (`tests/recipe_scaffold_test.gd`)

### Added - per-function shell-lift: opened packs' verbs become real, editable functions

- Opening a behaviour `.gd` used to lift its annotated verbs into real EventFunctions only when
  EVERY function in the trailing run lifted - one hairy body reverted the whole file to raw code.
  The lift now recovers **per function**: anything unliftable stays as raw code in place and the
  longest cleanly-lifting trailing run still becomes real functions, byte-verified as always.
  In practice: abilities opens with 49 real verbs, virtual_cursor 54, drag_drop 36, spring 22,
  weapon_kit 18, juice 17, platformer 13 - each a Define block you can double-click into the ACE
  Studio, instead of an annotation wall. Every pack still round-trips byte-identically (drift = 0).
  (`tests/per_function_lift_test.gd`)
- **Untyped parameters now lift**: a bare parameter (`final_value` with no `: Type`) was re-emitted
  with ACEParam's default type (`final_value: String`), failing the byte-verify and blocking the
  whole pack. It now round-trips bare - unlocking htn_agent (23 verbs), tween (10), and
  time_slicer (10).
- **Every pack now lifts - 331 real functions in total.** The last blocker: a statement INSIDE an
  unlifted control block (e.g. `pool.amount = maxf(…)` nested in health's absorption loop) could
  template-match as a standalone action and re-emit one tab shallower, failing the verify. Deeper
  lines now always stay raw with their nesting intact - unlocking **health (34 verbs)**, follow, and
  tile_movement. An error-jump into a lifted verb now unfolds the Published-verbs section to reach
  its Define block. The few remaining raw helpers (custom return types like `-> HealthPool`) keep
  their verb shells.

### Added - variable folders: drag one variable onto another to group them

- **Grouping variables is now a drag**: drop a variable onto another (its middle band highlights
  with a fold-into outline) and both join one Inspector-group folder - a naming popup opens already
  selected, so the flow is drag → type the name → Enter, exactly like creating a Discord folder.
  Dropping onto an already-grouped variable joins its folder. Edges of the row still mean reorder.
- **Grouped variables render inside a bubble**: each folder's members sit adjacent and wrapped in a
  rounded outline + soft tint, so a group reads as one visual unit rather than rows repeating a chip.
- **Double-click the group chip to rename** the folder everywhere at once; clearing the name in that
  popup dissolves the folder (every member ungroups).
- Folders ARE the shipped `@export_group` attribute underneath - they show up as Inspector sections
  in Godot and round-trip through the `.gd` exactly like groups set from the Variable dialog.
  (`tests/variable_grouping_test.gd`)

### Added - the sheet at a glance: badges, sentences, manifest, anatomy

- **Trigger tempo badges**: every trigger row shows how often it runs - ⟳ every tick · ⌨ input ·
  ▶ once · ➜ signal - as a coloured badge classified from the trigger id. (`tests/trigger_tempo_test.gd`)
- **Rows read as sentences on hover** ("then 3 lines of code" for raw blocks - honest, never
  invented); **typed value tints** (numbers/strings/bools each get a hue); **group fingerprints**
  ("4 events · ⟳1 · ➜2 · ⚠1" on collapsed group headers). (`tests/row_sentence_test.gd`,
  `tests/typed_value_tint_test.gd`, `tests/group_fingerprint_test.gd`)
- **Publishes-Manifest banner**: a second banner band counts what the sheet publishes - "➜ 8 triggers ·
  ⚡ 16 actions · cond 5 · ƒx 12 · @ 3 knobs" - including un-lifted annotated verbs in opened packs;
  plus a save-time **health chip** ("✓ no issues" / "⚠ N flagged").
  (`tests/banner_manifest_counts_test.gd`)
- **Define blocks**: a sheet's functions (previously invisible outside the Functions dialog) render
  as a foldable **Published verbs** section - role badge · friendly name · `→ type` chip · category
  chip · the compiler-emitted signature. (`tests/define_block_rows_test.gd`)
- **Published-verb shells**: an opened pack's `## @ace_*` annotation walls render as ONE Define-style
  header line each ("Action · Take Damage · Health · publishes the func below"), a pure view - the
  byte round-trip is untouched. (`tests/raw_shell_render_test.gd`)
- **The Functions overview is its own dockable panel**: it used to be welded inside the
  Generated-GDScript side panel, so seeing your functions meant opening the code view. It now docks
  in the left rail behind a fold header ("▸ Functions · N" - the count reads even collapsed), expands
  on demand, keeps its ＋ add / right-click delete behaviour, and remembers its expand state
  per-project. (`tests/functions_panel_test.gd`)
- **Behaviour Anatomy panel**: a left-rail read model showing the active sheet as seven organs -
  Properties · State · Triggers · Actions · Conditions · Expressions · Uses - with counts in role
  colours; double-click an entry to jump to its row. Works identically for editor-authored sheets
  and opened packs. Entries render in the same pill/badge language as the canvas's Define blocks
  (role-coloured pills per organ, accent-underlined headers, click a header to fold its organ) -
  drawn read-only, so the rail can never mutate the sheet. (`tests/anatomy_panel_test.gd`)

### Added - GDScript as an action (Construct 3-style script blocks)

- **Add Code** on the toolbar (and *Add ▾ → Code (GDScript) on Selected Event*, and the row
  right-click menu) drops a GDScript block straight into the selected event's actions and opens the
  code editor on it immediately - the deliberate "drop to code here" escape hatch C3 users reach for,
  now a discoverable first-class action instead of only appearing as un-lifted residue. The block
  runs right after the event's conditions pass with the sheet's variables + host in scope, renders as
  a distinct merged **GDScript** code cell, and seeds an editable comment rather than a bare `pass`.
  (`tests/inflow_gdscript_test.gd`)

### Added - speed-of-thought editing: Ghost Row, Param Hop, bulk retune

- **The Ghost Row**: pressing E / C / A opens a type-a-sentence popup at the selected row instead of
  the full picker - `A → heal 5 ⏎` appends the action with zero dialogs (Ctrl+Enter still opens the
  browsable picker). **Post-insert continuation**: leave a param out (`heal ⏎`) and the one-field
  editor opens straight onto it, pre-filled and select-all'd. (`tests/ghost_row_test.gd`)
- **The Param Hop**: Enter on a row with parameter values starts a keyboard cursor; Tab / Shift+Tab
  cycle the values (with a muted param-name hint at the cursor); Enter opens the one-field editor
  anchored at the value; Esc returns to row scope - retuning `300 → 450` is Enter · Tab · type · Enter,
  zero mouse. (`tests/param_hop_test.gd`)
- **Bulk retune**: box-select N rows, edit one shared value, **Ctrl+Enter applies it to the same
  verb's same param on every selected row** in one undo step - structure-aware, so `amount` on Heal
  never bleeds into `amount` on Poison. (`tests/bulk_param_apply_test.gd`)
- **Single-key grammar**: **B** adds a blank sub-event, **I** inverts the selected condition, **R**
  replaces the selected ACE - all rebindable. (`tests/single_key_reflexes_test.gd`)

### Added - navigate like the script editor

- **Ctrl+Click a behaviour's name opens it as a sheet** (go-to-definition across the
  consumer-sheet → behaviour boundary); unresolvable cells keep Ctrl multi-select.
  (`tests/navigate_test.gd`)
- **Alt+Left / Alt+Right jump history**, path-deduped so going Back re-focuses the existing tab
  instead of opening a duplicate. (`tests/navigate_history_test.gd`)
- **Ctrl+P prefixes**: `#` fuzzy-searches project sheets and opens one; `@` searches the current
  sheet's symbols (functions ƒ · signals ➜ · variables @) and jumps to the row.
  (`tests/palette_sheet_search_test.gd`, `tests/palette_symbol_search_test.gd`)

### Added - generated code stays joined to the sheet

- **What Changed Since Save**: a Sheet ▸ command (also in Ctrl+P) that shows which rows a save would
  touch, in event language - each row labelled from its emitted code and double-clickable to jump,
  plus any lines a save would remove. Compiles to a scratch path only, so asking never writes the
  real file. (`tests/sheet_diff_test.gd`)
- **Paste an error line, land on the row**: paste any Godot error or stack-trace line
  (`res://….gd:42` anywhere in the text) into the command palette (Ctrl+P) and its single entry
  opens that generated `.gd` **as a sheet** and selects the row that emitted the line - a runtime
  error goes straight back to the event that caused it, and Alt+Left returns.
  (`tests/palette_error_jump_test.gd`)

- **EventSheetLineRowMapper**: one shared generated-line ↔ sheet-row lookup over the compiler's
  source map (most-specific range first, walks past freed resources). The GDScript panel's
  click-to-select and row-highlight delegate to it; runtime-error → row deep-links build on it next.
  (`tests/line_row_mapper_test.gd`)
- **Paused-at-row**: when a running game hits a sheet breakpoint, the sheet now shows WHICH row -
  the generated code announces its row id right before pausing (debugger-guarded, zero cost in
  exported games), and the editor switches to that sheet's tab and selects the event. Works through
  the same live channel as Live Values; no core-debugger access needed. (`tests/paused_row_test.gd`)
- **Debug-residue Doctor check**: a sheet saved with breakpoints / live-values / event-trace emission
  still enabled ships `breakpoint` + telemetry lines in the committed `.gd` - the Doctor now flags it
  and offers a one-click strip. (`tests/doctor_debug_residue_test.gd`)

### Fixed

- **The empty band of an event row is now an obvious whole-event drag handle.** An event is often
  taller than its condition lane (its action lane has more lines), leaving empty space below the
  trigger/conditions. Pressing there always dragged the whole event (to reorder or nest it) - but
  with no cursor change it read as dead space, ambiguous with the conditions. That band now shows a
  move cursor and brightens the row's grip dots on hover, so "grab here to move the event" is
  unmistakable; clicking an actual ACE cell still grabs that ACE. (`tests/event_drag_zone_test.gd`)
- **Opened-pack line↔row mapping was a few rows off**: on the external (opened `.gd`) compile path a
  doc-commented `@export` variable emits its `##` line plus the declaration but the source map counted
  it as one line, cascading a small offset onto every row after it - so click-to-select, error→row,
  paused-at-row, and the sheet diff landed a few rows off on opened packs. The variable now records
  its true multi-line span; a golden test proves every raw row's map points at its own code across
  all packs, with the byte-exact round-trip (drift=0) intact. (`tests/external_source_map_test.gd`)
- **Quick-add and Ghost-Row actions appended a brand-new event** instead of landing on the selected
  one (the apply's default branch wrapped them); they now use the same append mode as the toolbar's
  Add Action. (`tests/ghost_row_test.gd`)
- **A bodiless typed verb broke the whole generated script**: the empty-body stub was always `pass`,
  which only parses for void - each return type now stubs its own default (`return false`, `0.0`,
  `""`, `Vector2.ZERO`, …), so "publish the verb first, implement after" can't take the sheet down.
  (`tests/type_correct_stub_test.gd`)
- **The generated file's source map drifted after member insertion**: provider/stateful declarations
  are inserted near the top after the map is built, so line → row lookups (click-to-select) landed a
  few rows off on any sheet using a provider-instance ACE. The map now shifts with the text.
  (`tests/line_row_mapper_test.gd`)
- **Double-clicking a value on an object-labelled row edited the wrong spot**: the hit-test measured
  from the span origin while the text draws after the icon/label prefixes - both now share one
  geometry helper. (`tests/param_hop_test.gd`)
- The read-only `.gd` preview banner showed the previous tab's counts after a tab switch; it now
  recomputes per refresh. (`tests/preview_banner_tab_test.gd`)
- The New Behaviour dialog clipped at the right edge (the recipe dropdown forced the width) and cut
  off its buttons; it now ellipsizes and fits its whole form.

### Changed

- **Colour-law sweep**: the banner manifest pills, health chip, and structural row badges now draw
  from named `EventSheetPalette` constants instead of per-file hex; the two ad-hoc category-chip
  purples were unified with the ACE Studio's chip colours.

### Added - more inspector export options: color-no-alpha, easing curve, placeholder

- Three more Godot `@export_*` flavours are now dialog-authored options in the Variable dialog's "More
  options", each compiling to the native annotation and **round-tripping structurally** (the dialog control
  re-fills on reopen and survives editing, verify-lift-gated like the drawers):
  - **`@export_color_no_alpha`** - a Color-only "No alpha (solid RGB, no transparency)" tick.
  - **`@export_exp_easing`** - a float-only "Easing curve" tick (an exponential-ease handle in the Inspector).
  - **`@export_placeholder("…")`** - a String-only "Placeholder" field (grey hint text shown when empty).
  - (`tests/color_no_alpha_test.gd`)
- New how-to **[Inspector Drawers & Export Options Guide](docs/INSPECTOR-DRAWERS-GUIDE.md)** with rendered
  images: the five Tier-3 drawers (progress bar / dial / swatch / texture / curve), every export option, and
  the Tier-2 behaviours (clamp / on-changed / show-if), each with the exact emitted GDScript + use cases.

### Added - RegEx text module (Construct 3-style Regex functions)

- A new **RegEx** ACE module (its own file) of pattern-matching verbs, Godot-`RegEx`-backed and
  parity-clean: **Text Matches Regex** (condition), **Regex Replace** (replace every match), **Regex First
  Match**, **Regex Match Count**, **Regex All Matches**, and **Regex Capture Group** - mirroring C3's
  `RegexReplace` / `RegexSearch` / `RegexMatchCount`. The `search_all`-based verbs are **null-safe** (empty
  string / empty array on a miss, never an error). Plus **Format Decimals** (`String.num`) for the
  decimal-places gap. Each compiles to a direct `RegEx.create_from_string(…)` one-liner - no editor plugin or
  pre-built RegEx object. (`tests/regex_aces_test.gd` pins runtime behaviour, not just parse.)

### Added - Global-signal triggers (On Post Tick, On Close Requested)

- Triggers can now connect a signal on a **global source** - `get_tree()` or `get_window()` - not just
  self / an autoload / a node path. Adds three triggers: **On Post Tick** (`get_tree().process_frame` - runs
  once *after* every node's `_process` this frame, for logic that must come last, e.g. a camera that follows
  after movement), **On Physics Post Tick** (`get_tree().physics_frame`), and **On Close Requested**
  (`get_window().close_requested` - the window's X / an app-quit request, for save-on-quit or a confirm
  dialog). (`tests/global_trigger_test.gd`)
- New **Handle Quit Myself** action (`get_tree().set_auto_accept_quit(…)`, friendly Intercept/Allow
  dropdown): set it to *Intercept* in On Ready so the window's X no longer quits instantly - On Close
  Requested runs first (save / confirm), then you call **Quit Game** explicitly. The full save-on-quit flow,
  no GDScript.
- *(The scene **actions** already shipped - Quit Game, Go To Scene, Restart Scene - so this fills in the
  missing exit/post-frame **triggers** + the quit-interception action.)*

### Added - Console logging ACEs (combo-driven) + friendly label↔value dropdowns

- A **Console** vocabulary of C3 Browser/console-style logging verbs, each driven by a single **"As"**
  dropdown - **Message / Warning / Error** - that *shows* a friendly label but *inserts* the matching Godot
  call (`print` / `push_warning` / `push_error` / `print_rich`): **Log** (one verb for all four streams),
  **Log If** (write only when a condition holds, no wrapping event row), **Log (Debug Builds Only)**
  (`if OS.is_debug_build(): …` - skipped in exported release games), **Log Value** ("name = value" to any
  stream), and **To Text** (`var_to_str(...)`). All emit bare native one-liners (parity-clean).
  (`tests/console_aces_test.gd`)
- The bare **Log** round-trips *as itself* via a trailing `# @ace:Core.ConsoleLog` marker: the emitted
  `push_warning("x")  # @ace:Core.ConsoleLog` line runs untouched in-game (the comment is inert), but reopens
  as the combined Log rather than collapsing to the specific Push Warning - while a *plain* hand-written
  `push_warning("x")` still lifts to Push Warning. The other Console verbs need no marker (their templates are
  already distinct).
- **New: friendly combo labels.** A fixed-options ("combo") param can now carry `{"key": <inserted value>,
  "label": <shown text>}` entries, so a dropdown reads "Warning" while inserting `push_warning`. `ACEParam.options`
  is untyped, `make_param` accepts the dict form, and the adapter preserves the label↔value split - reusable for
  any future combo (e.g. comparison operators could read "equals" instead of `==`).
  - *Note:* the plain immediate **Print / Push Warning / Push Error** verbs are kept (not deprecated). The
    reverse-lift is most-specific-first, so a *plain* `push_warning("x")` still lifts to Push Warning; the
    combined **Log** stays distinct only because of its `# @ace:Core.ConsoleLog` marker (above).

### Added - Event groups round-trip through `.gd` (docs/GROUPS-ROUNDTRIP-SPEC.md)

- Event groups now **survive a `.gd` round-trip**. Compiling a grouped sheet emits a class-scope
  `## @ace_group(uid="…", name, parent?, description?, color?, collapsed?, toggleable?)` declaration per group plus a
  per-row `# @group:<slug>` membership tag; reopening the `.gd` reconstructs the `EventGroup` rows (name,
  colour, collapsed/toggleable, nesting) even though the compiler scatters a group's rows across trigger
  handlers. The whole pass is **verify-lift-gated** - a sheet that can't re-emit identically degrades to a
  flat/verbatim block rather than corrupting; the group `uid` is a deterministic name-slug so re-saves stay
  byte-stable. (`tests/group_roundtrip_test.gd`; demoed in `demo/showcase/showcase_carousel.gd`; commit 90367eb)

### Changed - Compiler: includes run first; disabled groups leave a breadcrumb

- An **included** (library) sheet's events now compile/run **before** the root sheet's own events (matching
  Construct's "include the library at the top"), so shared setup / `_ready` initialises first. Sheets with no
  includes stay byte-identical. A **disabled** event group is no longer dropped silently: the generated `.gd`
  now carries a `# (disabled group "<name>" - N rows omitted)` breadcrumb (the group's events still don't run).
  (`tests/include_order_disabled_group_test.gd`; commit 5164393)

### Added - Visual expression builder: operator palette + variable/member picking

- The `ƒx` "Insert Expression" window now leads with an **operator palette** (`+ - * / % == != < > and or not
  ( )`) that inserts at the caret, lists the sheet's own **variables** as one-click leaves, and - while
  searching - reflects a class-backed variable's members as ready-to-insert `enemy.velocity` /
  `enemy.get_velocity()` fragments. Non-coders build comparisons and reach other objects' members without
  typing. (`tests/expression_builder_test.gd`; commits d6ab5e6, fde24a1)
- **Fixed (silent bug):** picking a result from the expression tree used to silently do nothing - the insert
  path only handled `LineEdit`, but the expression field is always a `CodeEdit`. The palette and the tree
  results now share a caret-insert helper that handles `CodeEdit`/`TextEdit` and `LineEdit`.

### Added - Open Sheets panel (open + recently-closed, in-workspace)

- A filterable list of **open and recently-closed sheets** now lives in the EventSheet workspace (left of the
  viewport, like the script editor's Filter Scripts list). One click switches to an open sheet or reopens a
  recent one. Toggle it from **View › Open Sheets Panel**, or collapse it to a thin strip with the header
  arrow - both states persist per-project. (`tests/open_sheets_dock_test.gd`; commits a777758, e6c2fd4)

### Changed - Friendly variable types (Number / Text / Yes-No)

- The Variable dialog's Type dropdown leads with beginner-friendly **Number / Text / Yes-No** labels, with the
  Godot types (Vector2, Color, Array, …) under an "Advanced types" separator. **int vs float** collapses into
  "Number" + a **"Whole numbers only"** tick; Text → String, Yes-No → bool. A `_selected_stored_type()` alias
  layer keeps the **stored** type a real Godot type, so only the dropdown's display changes - the `.gd`
  round-trip is byte-unchanged. (`tests/friendly_types_test.gd`; commit 7fb473e)

### Changed - Constant variables round-trip from a hand-written `.gd`

- A `const NAME: T = v` declaration written directly in a `.gd` now **lifts back into a first-class constant
  variable** when reopened as a sheet (its green **"const"** pill + dialog editing), instead of degrading to a
  verbatim GDScript block. Authoring a constant (the dialog's "Constant (can't change at runtime)" tick + the
  row's right-click toggle), compiling to `const x: T = v`, and the const pill were already shipped - this
  closes the import half, so constants are end-to-end. Byte-verify-gated, so a non-canonical const (inferred
  type, expression default) still degrades safely to verbatim. (`tests/const_roundtrip_test.gd`; commit fe770c2)

### Changed - Consistent inset-card theming across dialogs & panels

- Dialogs and panels (the Variable dialog, the ACE params dialog + its node/expression pickers, the dock's
  multi-section popups) now share the same editor-theme-aware **sunken inset-card** surfaces, with new
  `section_header` / `titled_card` legibility helpers. Cosmetic only - no behaviour change.
  (commits 18b4cf9, fa63b3e, 5df8ea8, a1e7903)

## [0.9.5] - 2026-06-29 - Code-Free Authoring & First-Class Variables

### Changed - Progressive disclosure in the Variable dialog (docs/PROGRESSIVE-DISCLOSURE-SPEC.md)

- The Inspector-attribute block no longer throws ~10 fields at once. It's **two tiers**: a **Basic** "More
  options" (Tooltip, Range, "Show as" drawer + live preview, Multiline) and a nested **Advanced** disclosure
  (grouping, show-if/lock-unless/on-changed, clamp, read-only). The Advanced tier auto-unfurls only when the
  variable actually uses one of its attributes - a tooltip-only variable no longer opens the whole block.
- **Drawer config de-overloaded:** the Range field accepts a **bare max** (so a dial's reach is just "150",
  not "min, max, step") with a forgiving parser shared by the apply and preview; a Vector2 prompts "max reach";
  the preview caption shows the relevant bound ("· reach 150" / "· 0–100"); "Curve editor" → "Curve preview".
- **C3-first wording:** "Editable in the Inspector (like a C3 property)" (the `@export` term moves to the
  tooltip), "Group under heading" / "Sub-heading", "Constant (can't change at runtime)", and plain-language
  per-type hover hints on the Type dropdown - Godot jargon stays out of the primary labels.
- **Simple Mode is discoverable:** the Welcome dialog's first run offers a "Simple mode" checkbox, so a
  newcomer meets the audience choice instead of getting the full registry by default.
  (`inspector_drawer_roundtrip_test`; renders of the tiered/relabeled dialog + the Welcome; suite green.)

### Added - Tier 3 Inspector drawers: dial, swatches, texture, curve (the full set)

- The Inspector drawers (docs/INSPECTOR-ATTRIBUTES-SPEC.md) go from one drawer to **five**: a numeric
  **progress bar**, a Vector2 **direction dial** (drag a handle to set direction + magnitude), a Color
  **swatch row** (palette presets + picker), a **texture preview** thumbnail (Texture2D / path), and an inline
  **curve** render. Each compiles to an `@export_custom(PROPERTY_HINT_NONE, "eventsheet:<drawer>")` marker that
  an `EditorInspectorPlugin` swaps for the rich control - and **without** the plugin (or in an exported game)
  the property is a plain field, so the parity covenant is untouched.
- **They round-trip.** A drawer reopened from a `.gd` sheet is recovered into an editable `attributes.drawer`
  (with its bounds), not stranded as a verbatim `@export_custom` block - verify-lift-gated, so a wrong guess
  reverts to a byte-stable block rather than corrupting. One emitter (`_drawer_export_prefix`) drives both the
  dict-var and tree-var paths identically. A variable that carries BOTH a drawer **and** an `@export_group`
  round-trips correctly - the group absorb now *merges* with (rather than overwrites) the drawer the
  hint-extraction recovered (a bug the Inspector Playground showcase surfaced).
- **New host value types.** Vector2, Color, Texture2D and Curve are now first-class sheet-variable types
  (so the dial/swatch/texture/curve drawers have something to attach to); Vector2/Color literals emit and lift
  back byte-exact.
- **Authoring UX.** The Variable dialog offers exactly the one drawer the chosen type can host and shows a
  **live preview of the actual widget** - the same reusable Controls that render in the Inspector - updating as
  the type / drawer / bounds change.
- **Showcase.** A new **Inspector Playground** (`demo/showcase/inspector_playground.tscn`) puts all five
  drawers + `@export` grouping across the new value types on one tunable node - select it to see the rich
  grouped Inspector, press Play and the ship drifts/tints/scales from those same designer-tweakable variables.
  (`inspector_drawer_roundtrip_test`, `inspector_attributes_test`, `showcase_examples_test`; render harnesses
  `render_drawer_widgets_preview` + `render_variable_drawer_dialog`; suite 3474 green, zero showcase drift.)

### Fixed - Inspector grouping + tooltips survive reopening a `.gd` sheet

- A variable's **`@export_group` / `@export_subgroup`** now round-trips through a `.gd` reopen. Before, those
  lines couldn't be lifted, so a reopened grouped variable **degraded into a stray `@export_group` GDScript
  block + an ungrouped variable** (violating "no GDScript block" and losing the grouping). Now the importer
  **absorbs the group lines onto the variable** - gated by the verify-lift rule, so it's byte-exact-safe (a
  wrong guess just leaves a block, never corrupts) - and the reopened variable reads as a clean grouped
  variable with its **"Group › Subgroup"** chip. `LocalVariable` gained an `attributes` dict; the tree-var
  emission re-emits the group lines matching the dict-var path exactly. The reopened variable is also fully
  **editable** - the dialog now populates its group/subgroup and the apply saves them for tree variables
  (previously the tree path ignored attributes, so a reopened group was stuck or silently cleared on edit).
  The variable **tooltip** round-trips the same way - a `## doc` immediately before the variable is recovered
  as its tooltip (Godot's doc-comment convention), no longer stranded as a `## …` GDScript block; a `## @ace…`
  annotation line is excluded so it's never mistaken for a tooltip.
  (`variable_group_roundtrip_test`; zero showcase drift.)

### Added - `@export_subgroup` for nested Inspector grouping

- A variable can now also carry an **Inspector subgroup** (the variable dialog's new "Inspector subgroup"
  field), compiling to `@export_subgroup("…")` nested under its `@export_group`. For a complex object with
  many tunables, this organizes the Inspector into nested sections (e.g. *Combat ▸ Melee* / *Combat ▸
  Ranged*). The row chip reads **"Group › Subgroup"** so the nesting is legible in the sheet too.
  (`variable_export_group_test`.)

### Added - Drop a scene node onto a param to reference it (no dialog)

- Dragging a node from the **Scene dock** straight onto a **condition/action param value** now fills that
  param with the node reference - preferring a scene-unique **`%Name`** for deep nodes (the same converter
  the params dialog uses), undoable. The deep-node-friendly, Construct-style gesture: no dialog, and dropping
  on a *specific* param value resolves the "which parameter?" ambiguity. The drop is only accepted when the
  cursor is over such a value, so it reads as droppable exactly where it works. (`node_drop_on_cell_test`.)

### Added - "New Behaviour Addon…" - author a custom addon in one step

- **Sheet ▸ New Behaviour Addon…** opens a small dialog (name, base class, category, description) that
  scaffolds a **ready-to-edit, richly-commented behaviour script** under `res://eventsheet_addons/` - where
  it's auto-discovered as a custom ACE provider. The skeleton **teaches the `@ace_*` vocabulary by example**:
  a `signal` → trigger, methods → action / condition / expression, an `@export var` → a property, each with
  the common annotations (`@ace_name`/`@ace_category`/`@ace_description`/`@ace_param_hint`) in place and a
  "more knobs" reference (`@ace_hidden`/`@ace_deprecated`/`@ace_display_template`/…). It validates the class
  name, previews the target path, writes the file, refreshes the registry, and opens it for editing. The
  generated skeleton is guaranteed to be valid GDScript for every offered base class. (`behaviour_addon_scaffold_test`.)

### Added - BBCode in condition/action cell text + ACE descriptions on hover

- BBCode-lite (`[b]`/`[i]`/`[color=…]`) already styled **comments**; it now also renders in the **display
  text of condition/action cells** (e.g. a custom ACE's `@ace_display_template("[color=red]Destroy[/color]
  {object}")`) and in **ACE descriptions on hover**. In a cell, the parsed text drives layout (the stripped
  text, so the colour swatch + width stay aligned) and the author's styling supersedes the auto
  value-highlight for that cell; the markup detector is conservative, so a plain value like `[1, 2, 3]` is
  never mistaken for markup. The hover tooltip becomes a rich (BBCode) panel only when the description has
  markup - plain descriptions keep the native tooltip. The picker's description panel already rendered
  BBCode. (`bbcode_and_pill_test`.)

### Removed - The confusing scope pill on variable rows

- Variable rows no longer show a scope pill. The "global" pill was already hidden as redundant; the "local"
  pill on event-scoped variables read as noise too - scope is already obvious from the row's nesting under
  its event, and the `@export` badge carries the meaningful distinction (Inspector-visible vs. internal).

### Changed - Dragging a node into a field prefers its scene-unique `%Name`

- Dropping a Scene-dock node onto an expression / path field already inserted a `$Path` reference; it now
  prefers a scene-unique **`%Name`** when the dragged node carries one - a flat handle that collapses a deep
  `$A/B/C/D` path to `%D` and survives the node being moved - the same handle the node picker hands back.
  The deep-node-friendly way to reference Godot's node-heavy objects by dragging. (`node_drag_reference_test`.)

### Added - Inline colour picker on the cell swatch (no dialog)

- The little **colour swatch** drawn on a condition/action cell (for any ACE with a `Color` param) is now
  **clickable**: a single click opens a **ColorPicker right there** - no params dialog - and the picked
  colour is written straight back into the ACE, exactly like Construct. The pick commits **once on close**,
  so dragging the picker is one clean undo step. (`color_swatch_picker_test`.)

### Added - Deprecate an ACE without breaking existing projects

- An ACE can now be marked **deprecated** (the Construct-style covenant): it **keeps compiling** so sheets
  that already use it never break, but it is **hidden from the picker** (can't be added to new work),
  **flagged on hover** with its suggested replacement, and **warned about at compile time** (one nudge per
  distinct deprecated ACE - never an error).
- Built-ins use a chainable `.deprecated("why", "Provider::NewId")` next to the descriptor; custom behaviour
  addons use a `## @ace_deprecated("Use X instead")` annotation - both flow to the same
  `ACEDefinition.metadata` the picker and hover read. This is the compatibility covenant in code: never
  rename or delete a shipped `ace_id`, deprecate it instead. (`ace_deprecation_test`.)

### Added - "@export" badge + Inspector-group chip on variable rows

- A sheet variable exposed to the Godot Inspector now carries a blue **"@export"** pill on its row, so
  while scrolling a sheet you can tell at a glance which variables show in the Inspector vs. stay internal.
  Tracks the compiler's default (exported unless explicitly off). (`variable_export_badge_test`.)
- A variable assigned an **Inspector group** (the variable dialog's "Inspector group" field, which compiles
  to `@export_group("Name")`) now shows that **group name as a chip** on its row - so it's legible in the
  sheet which exported variables share an Inspector section, the "group them in the sheet" half of the
  `@export_group` feature. (`variable_export_group_test`, which also pins the `@export_group` emission.)

### Added - Plain-language descriptions on hover (every ACE, function, and parameter)

- Hovering a **condition / action / function-call** row in the sheet now shows its **plain-language
  description** - what it does, in friendly English - instead of the GDScript it compiles to. (Parameters
  already showed their description on hover in the editor; ACEs in the picker already had a description
  panel.) A Call-Function row shows the targeted function's own description.
- Built-in ACEs carried **no** written description before (their `make_descriptor` calls set none), so a
  concise one-liner was authored for **all 523** of them (e.g. *Add Child* → "Attaches another node as a
  child of this one at runtime, e.g. spawning a bullet."), populating the picker's description panel +
  tooltips everywhere too. (`ace_descriptions_test`.)
- **Descriptions live in the files, next to the ACE.** Each built-in's description is now authored **inline**
  on its descriptor via a chainable `.described("…")` - `make_descriptor(…).described("…")` - so an ACE's
  help sits in the same module file as its definition, exactly how a custom behaviour addon authors it
  (addons already use `## @ace_description(…)`). This makes packs self-contained and easy to update with no
  central registry to edit; the old generated `ace_descriptions.json` is gone. The test now **enforces full
  coverage** - a new built-in without a `.described(…)` fails, so no undescribed ACE can ship.

### Changed - Fewer syntax errors: auto-closed brackets + an always-on structural guard

- The editable code fields - the **ƒx expression boxes** and the **GDScript-block dialog** - now
  **auto-close brackets and quotes** (`(` → `()`, `"` → `""`, with the caret inside) and highlight
  matching brackets, so the most common user syntax error (an unbalanced pair) is rarely typed in the
  first place.
- A new **structural syntax check** (unbalanced `()[]{}` / unterminated strings - always an error,
  unlike an undeclared identifier that may be a runtime-spawned node) now **blocks Apply** in the param
  dialog with a clear message, and runs **even when the symbol-aware lint can't** (an "unhealthy" lint
  context), closing the one path where malformed code could slip through.
- The **GDScript-block dialog live-disables Save** the instant a bracket goes unbalanced (immediate
  feedback rather than a reject-on-click). Safe to hard-disable because a structural error is *never*
  valid - no lockout from a lint false positive. (`syntax_guardrails_test`.)

### Changed - Node picker prefers scene-unique names (`%Name`) for deep nodes

- Picking a node that carries a **scene-unique name** now hands back **`%Name`** - a flat handle that
  collapses a deep `$A/B/C/D` path to `%D` and survives the node being moved - instead of the brittle
  relative path. The picker tree also shows the `%`handle so you can see which deep nodes are
  `%`-accessible at a glance. Godot's own answer to node-heavy objects, surfaced where you pick.
- And a one-click **"Make %unique"** button in the picker turns *any* selected deep node into a
  scene-unique node (undoable) and hands back its `%Name` - so you don't have to leave the sheet for the
  scene editor to get a path-free handle. Offered only for a non-root node that isn't already unique.
  (`node_picker_test`.)

### Changed - Function calls read as named verbs (show abstraction level)

- A **Call to a sheet Function** now renders as **"ƒ <Verb Name>"** (its friendly name, under a `ƒ` chip)
  instead of the generic "System → `Call my_function()`". The abstractions you *create* - e.g. via Extract
  to Function - read as first-class verbs, so a sheet is **less verbose** and you can see at a glance which
  rows are higher-level vs. 1:1 with code. Pure editor view-state - no codegen change. (`function_verb_rendering_test`.)

### Added - Pick nodes by TYPE (Godot's node-heavy objects, without the path pain)

- A Godot object is a deep node tree - a player can be dozens of nodes - so reaching "the AnimationPlayer
  of this object" used to mean a brittle path (`$Body/Visuals/Anim`) or a GDScript block. New **Nodes:
  Picking** ACEs resolve a child by **class anywhere in the subtree** instead: **Find Children Of Type**
  (every match, for a For Each), **First Child Of Type** (the first, null-safe via `pop_front`), and
  **Has Child Of Type** (a gate). Target the type, not the path - no code. (`node_type_aces_test`.)
- Built on that, **object-level component verbs** (the Construct mental model - act on the *object*, not
  its deep node): **Play / Stop / Play Sprite / Restart Animation**, **Is Animating**, **Flip Sprite**,
  **Set Sprite Frame**, and **Emit Particles** - all "(in object)" - auto-find the object's
  `AnimationPlayer` / `AnimatedSprite2D` / `GPUParticles2D` and act on it. "Play animation walk on Player",
  "flip Player", "emit Player's particles" now need no path to the deep child and no GDScript block -
  null-safe and collision-safe (the same `{uid}`-baked temp-var pattern the audio Play Sound ACEs use).

### Added - Extract to Function: turn a pile of rows into one named verb

- Right-click an event's actions → **"Extract Actions to Function…"** → name them, and a stack of
  statement-level rows becomes ONE reusable, named function - the *create-abstraction* gesture. Answers
  the "why not just type the line?" question directly: you write it once, **name the concept** ("Apply
  Physics"), and never type it again; the function shows in the picker as a verb callable from any sheet.
- Elevates the old GDScript-only extractor: now works on **structured ACE actions** too (not just code
  blocks) and **preserves them as rows** in the function body. The typed name is snake_cased to a valid
  method (`apply_physics`) while the readable label is kept for the picker. Undoable; exposed as an ACE.
  Reachable from the action right-click menu and the event **More ▸** menu. (`extract_to_function_test`.)
- **Keeps the generated `.gd` valid** (the load-bearing invariant): a name that's a GDScript keyword or a
  host/native method (`queue_free`) is uniquified past it rather than emitting an override; and extracting
  actions that reference an event-local variable or For-Each iterator is **refused with the offending
  name** instead of silently producing a script that won't parse.

### Added - Families: one rule for every instance of a type (Construct-style horizontal abstraction)

- A sheet can now be marked a **Family** (Sheet Type ▸ "Family", on a Custom Node / Behavior): its
  instances are collected into the group `family_<class>`, so **other sheets can write ONE rule over all
  of them** - a family-scoped For Each compiles to `get_tree().get_nodes_in_group("family_enemy")`. The
  sheet's variables become the family's per-instance variables and its exposed functions become its
  per-object ACEs. This is the *horizontal* reuse event sheets were missing (logic-per-type, not
  per-object). See `docs/internal/SPEC-families-instance-vars-custom-aces.md`.
- **Lossless + honest:** the Family is recorded as a metadata-only `## @ace_family(<Class>)` annotation
  (exactly like `@ace_tags` - no emitted code, so it round-trips byte-exact and can never double-emit).
  Membership is an explicit **Add To Group** action with the family's group, never auto-injected code.
  The compiler warns if a sheet is flagged a Family but has no class name.
- **Showcase:** **Family Arena** (`demo/showcase/family_arena.tscn`) - an `Enemy` Family (instance vars
  `health`/`fall_speed`, a `take_damage` ACE) driven entirely by family-scoped rules. Pinned by
  `families_test` + `showcase_examples_test` (the byte-identity gate is also the `@ace_family` round-trip
  proof). This is v1; loose families + implicit picking are designed and deferred.

### Changed - GDScript blocks read as logic, not boilerplate

- An opened `.gd`'s **class scaffolding** (the `class_name`/`extends`/`@icon`/`@ace_*` prelude, the
  host-binding `_enter_tree`, blank separators) now collapses into ONE foldable **"Class setup" strip**
  (folded by default, one click to expand) instead of a wall of grey blocks. Real logic is never swept in
  - the classifier (`is_scaffolding_code`, unit-tested) is conservative: any unrecognized line keeps the
  whole block as logic. A lone scaffold row stays inline.
- **Type-aware block styling:** boilerplate renders dimmer + labelled "setup"; real logic keeps the
  brighter "GDScript" badge. A block the importer couldn't lift now shows an inline amber **"⚠ code"**
  badge (its `lift_note`) beside the hover tooltip - a wall of blocks becomes a triage list.
- Pure editor view-state - **zero codegen change**, the `.gd` stays byte-exact. See
  `docs/internal/SPEC-code-blocks-as-event-rows.md` (P1) + `blocks_scaffolding_test`.

### Changed - "Open as Event Sheet" is easier to find

- Right-clicking **any `.gd`** (or an EventSheet `.tres`) in the **FileSystem dock** offers **"Open as
  Event Sheet"** - a GDScript-backed sheet opens an arbitrary script losslessly. The item now carries the
  Script icon so it stands out among Godot's native file actions (the script editor's right-click item too).
  The availability decision is now a pure, unit-tested seam (`should_offer_open_as_sheet`,
  `open_as_sheet_menu_test`) so the entry point can't silently regress. You can also open any `.gd` via the
  dock's **Sheet ▸ Open…** browser (`.gd` is the first filter).

### Changed - Faster Construct-style event authoring

- **Double-click empty space opens the ACE picker** (new-event mode) instead of dropping a blank event you
  then have to fill. Every "new event" path - the **Add Event** toolbar button, the "+ Add event…" footer,
  the empty-space right-click menu, and now double-click - opens the same picker.
- **Triggers can no longer be "inverted."** The condition right-click menu disables "Invert Condition" for
  a trigger (there's no "not On X"). This also fixed a **silent no-op**: the compiler never read
  `trigger.negated`, so the old item claimed to invert a trigger while the generated code never changed -
  and it no longer leaves a misleading inverted-trigger on the sheet. Regular conditions still invert
  (compiled `not (…)`).
- Confirmed + regression-tested (`interaction_features_test`): **OR / AND condition blocks** (right-click
  an event → "Convert to OR Block" / "Make AND Block") and **selecting an event from its conditions-lane
  bounds** (right-click the lane background → the event menu with the OR/AND toggle) both work.

### Added - Design spec: GDScript blocks as event rows

- `docs/internal/SPEC-code-blocks-as-event-rows.md` - a UI/UX spec for improving how GDScript blocks render
  in event sheets (collapse structural scaffolding, clarify un-lifted logic, on-demand convert-to-rows,
  vocabulary expansion), to push the code-free experience further without breaking the byte-exact round-trip.

### Changed - Behaviour packs are single `.gd` files (no `.tres`)

Every bundled behaviour/addon pack - and the 5 demo showcases - is now ONE hand-editable `.gd`: the `.gd`
**is** the event sheet AND the runtime script. The paired `.tres` sources and the "AUTO-GENERATED / DO NOT
EDIT" banner are gone (31 pack `.tres` + 5 showcase `.tres` deleted). Opening a `.gd` re-derives its rows
losslessly; `tools/audit_addons.gd` is now self-hosting (import each pack `.gd`, recompile, assert
byte-identical: `audited=31 drifted=0`), and `showcase_examples_test` pins the same round-trip per showcase.

- **Safe by construction:** behaviour discovery already scanned `.gd` (the `## @ace_*` annotations live
  there, not the `.tres`), scenes attach the `.gd` by `class_name`, and no pack referenced another via
  Includes - so deleting the `.tres` changes nothing at runtime or in the picker.
- **Builder:** `tools/pack_builders/_lib.gd` compiles straight to a banner-less `.gd`
  (`omit_generated_banner=true`); no `ResourceSaver.save`.
- **Pairing reconceived:** `output_path_for(pack.gd)` / `sheet_for_script(pack.gd)` resolve to the `.gd`
  itself (it compiles in place and IS its own sheet) rather than a `.tres` sibling.
- **Lint completeness:** opening a behaviour `.gd` recovers its `host` accessor as a variable row; the
  block linter no longer double-declares `var host` (which had spuriously errored on every behaviour pack).
- **Variable pills:** a behaviour's class-level members (`host`, tuning + private state) no longer carry a
  scope pill - class scope is the default; only genuinely event-scoped `local`s are badged.

### Changed - Clearer ACE editing, variables, and startup

- **No more redundant "global" pill on variables.** Class/sheet-level variables (every variable a
  behaviour declares) rendered a blue `global` pill on each row - pure noise, since they're *all*
  global, and "global" misreads a behaviour's per-instance properties as project-wide. The pill is gone
  for the default scope; a genuinely event-scoped **`local`** variable still gets its pill (the one case
  worth flagging). Matches how Construct lists globals without tagging each one.
- **Consistent "Back to picker" across ACE edits.** Editing an action or condition that has parameters
  opens a params editor with a **Back** button that returns to the picker *preselected on that ACE*.
  **Triggers** - and any ACE with no parameters - open the picker directly, preselected, since clicking
  a trigger means "change what fires this event" and a paramless ACE has nothing to edit. Right-click
  **Replace Condition / Replace Action** now also preselect the current ACE instead of opening on the
  first match. (Previously conditions jumped to the picker while actions got a params dialog, which read
  as inconsistent.)
- **"Open in Godot" → "Open in Godot Script Editor".** All four buttons (block popup, provider dialog,
  generated panel, toolbar) and the preview hints now use the clearer, consistent label.

### Fixed

- **Two untitled sheets on project open.** The dock's `_ready()` seeded a demo sheet *and* the plugin
  called `setup()` again right after `add_child()` (which had already run `_ready()`) - two untitled
  tabs. `setup(null)` is now idempotent (no-op once a tab exists) and `_ready()` restores the last
  session first, only seeding a blank sheet when nothing was restored. Covered by `dock_startup_test`.

### Added - Behaviour bodies read as Construct event sheets (if/else + signals as rows)

The bundled behaviours stopped reading like event sheets exactly where it mattered most: a behaviour's
`OnProcess`/`OnPhysicsProcess` tick was one big GDScript cell (no if/else/elseif rows), and its trigger
signals were hand-written `## @ace_trigger` code blocks. Both now de-code automatically at build time
(`docs/internal/SPEC-construct-parity-eventsheets.md`):

- **Event bodies de-code into if/else/elseif condition rows.** A new `lift_event_bodies` pass reverse-
  lifts an event's single RawCode body into the same ordered condition/action rows a function body uses
  (folded into the event's sub-events), kept **only** where the whole sheet still recompiles
  byte-identically (a per-event gate). The Platformer Movement tick now reads as ~15 if/else rows
  (gravity → Apply Gravity + Add, wall-slide conditions, Move And Slide…) instead of a code cell; the
  shipped GDScript is unchanged. Only the irreducible leaves (an early `return`, a `var x :=` inferred
  local) remain as small cells.
- **Trigger signals become Trigger rows.** A new `lift_signal_declarations` pass converts
  `## @ace_trigger … signal X` blocks into `SignalRow` rows (name/category/params recovered), so a
  behaviour's signals read as keyword-badged Trigger rows and feed the On Signal / Emit Signal pickers.
  Applied to all 17 bundled packs that declared signals as code.
- **Zero-arg `signal.emit()` lifts to an Emit Signal row.** The reverse-match now accepts an empty
  argument list, so `landed.emit()` / `jump()` / `super()` reverse-lift to Emit Signal / Call rows
  instead of staying code (byte-safe - an empty match can only land on a literal `()`).
- **Helper functions become Function rows.** A behaviour's class-level `func` block - exposed
  `@ace_condition`/`@ace_expression` methods (Is Moving, Can Jump…) *and* private helpers - lifts into
  `EventFunction` rows (`lift_function_declarations`). The Platformer Movement pack is now **fully
  code-free**: signals + one if/else event + 13 Function rows, no RawCode. Exposed functions gain the
  sheet's `@ace_icon` (their picker entries show the behaviour icon); `return <expr>` bodies de-code
  via the **Return Value** ACE; a private helper's leading comment relocates into its body so nothing
  is lost. Opening the regenerated `.gd` recovers all of it byte-identically.
- Covered by `event_body_lift_test`, `signal_row_lift_test`, `function_declaration_lift_test`; all 31
  packs + showcases regenerate byte-stable (drift = 0).

### Changed - Picker dialogs match the editor theme

- The **Pick Node** and **Insert Expression** popups were bare `Window`s - they opened as separate
  native OS windows (default Godot icon, content flush to the edges) instead of editor-embedded dialogs.
  Both are now `AcceptDialog`s like every other plugin dialog: editor-themed panel + title bar, standard
  12px content margins, a search clear button, and a confirm button (**Use Node** / **Insert**, enabled
  only when a row is selected) alongside the existing double-click / Enter. The result tree is
  height-bounded by a holder so the dialog opens at a comfortable size and scrolls internally.
- The ACE picker's **⭐ Favorites** and **★ Recent** side panes now sit in filled inset cards - a new
  `EventSheetPopupUI.panel_section()` helper (editor `dark_color_2` fill, hairline border, rounded
  corners, falling back to a neutral dark fill outside the editor), matching Godot's *Create New Node*
  dialog. The description panel gets the same card. The bare lists floating on the dialog background are
  gone. Covered by `tools/render_node_picker_preview.gd` + the existing `render_picker_preview.gd`.

### Added - Behaviour class descriptions

- A sheet now has a **Description** (`class_description`), set in the **Sheet Type…** dialog. It
  compiles to a `##` documentation comment right after `extends` - Godot's class-doc position - so a
  behaviour/custom node shows its blurb in the *Create Node* dialog and the script docs. The importer
  recovers it, so it round-trips byte-identically (`class_description_roundtrip_test`).

### Added - Unsaved-close guard

- Closing a sheet tab with unsaved changes now asks **Save / Discard / Cancel** instead of silently
  dropping work. Save writes the tab and closes only if the save succeeds; a clean tab still closes
  instantly. `has_unsaved_tabs()` exposes the dirty state for editor-level prompts (`unsaved_close_test`).

### Added - Functions overview panel

- The side panel now lists every sheet **Function** at a glance (Construct's function list) above the
  generated GDScript: each shows its signature and an ✦ when it's exposed as an ACE. **＋** opens the
  Add Function dialog; right-clicking a function deletes it (undoable). Covered by `functions_panel_test`.

### Added - Construct-style function dialog

- The **New Sheet Function** dialog is rebuilt to match Construct 3:
  - **Usable as** picks Action / Condition / Expression in one control - the easy get/set toggle. An
	Expression is a getter that returns a typed value, a Condition is a yes/no test (bool), an Action
	is a void doer (a setter); it sets the return type for you.
  - **Parameters** are full C3 rows: name · type · **default value** · **description**. Defaults emit
	as optional GDScript args (`amount: int = 5`) via a dedicated `ACEParam.gdscript_default` (kept
	separate from the picker pre-fill, and validated trailing so the function always parses).
  - **Run only when** adds guard conditions - GDScript boolean expressions that wrap the function body
	in an `if` (e.g. *only run when a node setting is enabled*), authored as Expression Is True rows.
  - Covered by `function_dialog_test`; param defaults round-trip through the importer.

### Added - Behaviour-as-ACEs parity (foundation)

Toward authoring whole behaviour packs as event sheets with **no GDScript blocks** - so a behaviour
like Platformer Movement can be built from ACEs instead of RawCode (`docs/internal/SPEC-behaviour-as-aces-parity.md`):

- **Node-scoped ACEs now work inside a behaviour.** A behaviour sheet compiles to `extends Node`
  with a `host` member (its parent), but ACEs like **Move And Slide**, **Is On Floor**, **Set
  Velocity**, and the wall/floor/ceiling slide queries emitted *bare* calls that hit the behaviour
  Node itself - useless on a host, forcing a RawCode block. They now use a `{host.}` idiom that
  targets the parent host inside a behaviour and stays bare on a normal CharacterBody2D sheet
  (byte-identical output - no regeneration churn). Reverse-lift round-trips it unchanged.
- **A movement vocabulary so a CharacterBody2D behaviour needs no GDScript:** **Set Velocity X/Y**,
  **Add To Velocity**, **Apply Gravity** (with a baked terminal-velocity clamp) and a simple
  variant, **Accelerate Velocity X/Y Toward** (`move_toward` on a component), and the **Velocity
  X/Y** reads - all host-targeted, filed under a new **Movement** picker category.
- **Read Input Axis Into** - the consuming action for the existing Input Axis expression, so "read
  input, then move" is two ACE rows, not a RawCode line. **Set Local Variable (typed)** declares a
  statically-typed event-local, so dense typed temporaries stop forcing RawCode.
- **Trigger signals as rows.** A signal row can publish itself as a trigger ACE (`## @ace_trigger`,
  with optional name/category), so a behaviour declares a code-free trigger signal instead of a
  hand-written GDScript block - the last primitive needed for a signal-emitting behaviour with zero
  RawCode.
- **The first bundled behaviour authored with ZERO GDScript blocks.** The **Flash** pack is now built
  entirely from ACE rows - a trigger `SignalRow`, a gated *On Process* tick with sub-events
  (`Expression Is True` / `Is Valid` / `Compare Variable` → `Add/Set Variable`, `Set Property`,
  `Emit Signal`), and two ACE-action function bodies - instead of RawCode. It compiles to GDScript
  equivalent to the old hand-written version and its demo stays byte-identical. Proves the
  behaviour-as-ACEs path end to end.
- **A movement behaviour, now code-free.** The **8-Direction Movement** pack (a CharacterBody2D mover -
  the very "why is movement GDScript?" case) is the second zero-RawCode pack: an *On Physics Process*
  event reads a typed input-vector local, then **Set Velocity** + **Move And Slide**, all host-targeted.
  `pack_rawcode_budget_test` ratchets each converted pack - **Flash, 8-Direction, Timer, State
  Machine, and Move To** so far - at 0 RawCode so a GDScript block can never creep back. Remaining packs convert incrementally;
  numeric-kernel packs (spring/juice/bullet integrators - continuous `cos`/`sin`/spring math) keep
  documented RawCode per the spec's honest criterion.
- **Functions publish by return type (C3-style three-way expose).** An exposed sheet function now
  becomes the right kind of ACE automatically: a **void** function is an **action**, a **bool**
  function is a **condition**, and any other return is an **expression** - so a value-returning
  behaviour function (e.g. `load_value`, `random_range`, `has_save_key`) is usable directly in ƒx
  fields and conditions instead of being mis-published as a call-and-discard action. The Save System
  and Advanced Random packs' getters/queries are correctly typed now, and the reverse-lift round-trips
  all three directives. The **State Machine** pack is now fully converted off RawCode on the strength
  of this - its **Is In State** condition is a bool sheet function (`is_in_state(state_name) -> bool`)
  published as a condition ACE; the health / abilities condition+expression getters follow.
- **Loops are code-free (and now tested); the collection vocabulary is complete.** A behaviour can
  loop without a GDScript block - *Add Pick Filter → "While (condition)" or "Repeat N times"* compiles
  to a real `while` / `for` loop wrapping the event body (pinned by `while_loop_test`). Combined with
  the existing rich **Array / Dictionary** ACEs (append, pop/push front+back, insert, erase, find,
  sort, contains, is-empty, size, `get`-with-default, keys/values, …), collection- and loop-driven
  logic is authorable entirely as ACE rows - the vocabulary needed to build your own behaviours via
  event sheets.
- **Fewer raw blocks when authoring (near-zero-RawCode roadmap, Phase 0).** New everyday ACEs that
  previously forced a GDScript block: **Subtract / Multiply / Divide Variable** (the `-=` / `*=` / `/=`
  siblings to Add Variable), **Type Of** (`typeof`), and an **`@onready var`** declaration row for node
  refs (`@onready var sprite: Sprite2D = $Sprite2D`, the default emitted verbatim). The compound-assigns
  also **reverse-lift**, so `health -= 1` in a hand-written `.gd` opens as a *Subtract Variable* row
  instead of a code cell. (For an `is` class check, use *Expression Is True* with `self is Area2D`.)
  Roadmap: `docs/internal/SPEC-near-zero-rawcode-roadmap.md`.
- **More of an opened `.gd` renders as rows (near-zero-RawCode roadmap, Phase 2).** Inside an
  already-lifted trigger body, a property assignment `a.b = c` reverse-lifts to a **Set Property** row
  and a method call `a.b()` to a **Call Method** row - instead of staying an in-flow GDScript cell. A
  specific ACE always wins (`$Sprite.modulate = …` still lifts to *Set Modulate*, `$Sprite.play(…)` to
  *Play*); only what no ACE claims falls to the generic catch-alls, admitted at lowest specificity. The
  byte-identical recompile gates every match, and no functions move, so the GDScript-backed-sheet
  "events append" contract is untouched.
- **Loops and `match` open as control-flow rows (near-zero-RawCode roadmap, Phase 3).** When a trigger
  body is reverse-lifted, a `for X in EXPR:` becomes a **For-Each** loop row, `for i in range(N):` a
  **Repeat** row, `while COND:` a **While** row, and `match EXPR:` a **Match** row (Construct's switch,
  arms kept verbatim) - instead of the whole construct staying an in-flow GDScript cell. Loops nest
  their body as sub-rows, built on the same nesting the editor already used for `if`/`elif`/`else`, so
  a loop can hold conditioned sub-events too. The minimal loop shape (no predicate / order-by / first-N
  / frame-spread) round-trips byte-identically; anything richer - or a statement after a nested block
  inside the loop, or a blank line inside a `match` - safely stays a code cell. The byte-identical
  recompile gates every lift, and no functions move, so the "events append" contract is untouched.
- **Unusual `if` conditions stay real events (near-zero-RawCode roadmap, Phase 3.5).** When a
  reverse-lifted `if` has a term no specific condition ACE claims, it becomes an **Expression Is True**
  condition (a bare boolean expression) - so the branch stays a real event with sub-events instead of
  collapsing to a code cell, and matched + expression terms mix freely (e.g. `if health > 100 and
  is_ready:` → *Compare Variable* + *Expression Is True*). The corrected part: `and`-splitting is now
  **top-level only** - an `and` inside parentheses, brackets, or a string literal no longer fragments a
  compound term, so `if f(a and b):` lifts to one clean condition instead of the nonsensical `"f(a"` +
  `"b)"`. Negation (`not (…)`) and the byte-identical round-trip are preserved.
- **Hand-written helper functions open as sheet functions (near-zero-RawCode roadmap, Phase 1 - the
  unlock).** A plain `func foo(args) -> Type:` in an opened `.gd` - with no `## @ace_*` annotation -
  now reverse-lifts to an **un-exposed sheet function** (its body rendered as event rows: statements,
  loops, and branches via Phases 2-3) instead of staying one opaque code block. The `@ace_hidden`
  marker the source never had is suppressed (a new `lifted_unannotated` flag), so the file round-trips
  byte-identically; generated `@ace_hidden` functions keep their marker untouched. A function with no
  return type, or a blank line in its body, safely stays a block. Opening + saving a `.gd` untouched
  stays byte-identical; an event added afterward lands in the events section (standard sheet layout) -
  before any lifted helper functions, a clean single-insert diff.
- **Math expression vocabulary + local-variable lift (near-zero-RawCode roadmap, Phase 4 - polish).**
  New ƒx-field expressions sit beside Abs/Min/Max: **Square Root**, **Power**, **Floor**, **Ceil**,
  **Float Modulo**, **Ease**, **Snapped**, **Load Resource** (`load(path)`), and a trig/interp set -
  **Sine**, **Cosine**, **Tangent**, **Arc Tangent (y, x)**, **Clamp (float)**, **Degrees↔Radians** -
  so oscillation / rotation / smoothing math (sine wobble, orbit, look-at) is authorable as an
  expression instead of a RawCode block. The common one-liners that used to need a RawCode expression. And **Set Local Variable** (`var x = …`) and its typed sibling
  now reverse-lift, so a local declaration in a hand-written body opens as a row instead of a code cell.
  A new **fidelity ratchet** test proves a representative hand-written script lifts *completely* - every
  variable, statement, loop, condition, and helper function becomes a row (only the `extends` prelude
  stays verbatim) and round-trips byte-identically; the ratchet can only tighten, never silently loosen.
- **Hinted exports open as variable rows (Phase 4).** Inspector-tuned declarations - `@export_range(0,
  100)`, `@export_file`, `@export_flags("A", "B")`, and any other `@export_*` variant - now lift to a
  variable **row** with the annotation kept verbatim (a new `export_hint`), instead of staying a RawCode
  block. So a real tuned script renders as a sheet and round-trips byte-identically; the per-line
  verify-lift gate rejects any annotation it can't reproduce exactly (those stay blocks).
- **Behaviour addons + showcases are code-free by default.** A build-time pass (`lift_function_bodies`)
  reverse-lifts every behaviour pack's and showcase's function bodies into ACE rows - the *same* lifter
  that opens a `.gd` as events - keeping the lifted rows only when the sheet still recompiles
  **byte-identically** (a per-function gate). So algorithmic kernels (spring integrators, sine
  oscillators, physics ticks, weapon/health logic) now read as **Add/Set Variable**, **Set Property**,
  and **Call Method** rows instead of GDScript blocks, across all 31 packs - while shipping the **exact
  same GDScript** (0 generated `.gd` changed; drift=0). Bodies that can't round-trip (inner classes,
  exotic control flow) keep their RawCode - the honest irreducible limit. The showcases' most visible
  cells (HUD text, position clamps, spawns) were also hand-authored as **Set Text (formatted)** / **Set
  Property** / **Spawn Scene (Full)** rows; their remaining loop-heavy event blocks (nested
  hit-detection with `break`, grid spawn) stay code cells, where they read better than a pile of rows.

### Editor UX + behaviour icons

- **Behaviour addons now carry an icon.** Every generated behaviour pack emits `@icon(...)` before its
  `class_name`, so it shows a recognizable EventForge behaviour icon in Godot's **Create New Node**
  dialog and the sheet banner (instead of the generic script icon). The icon ships *with* the packs
  (`res://eventsheet_addons/behavior.svg`), never the editor addon, so a behaviour stays self-contained
  (clean-removal verified). A pack builder can pass its own icon to `save_pack`, and opening a generated
  `.gd` recovers the icon back into `custom_class_icon` (round-trips byte-identically).
- **Generated-GDScript preview refreshes live.** The preview panel now recompiles when you open a sheet
  or switch tabs - not only on edit - so it never shows the previous sheet's output. Hint text corrected
  to "refreshed live as you edit".
- **ACE picker matches the native node dialog.** Favorites/Recent rows no longer tint their label by ACE
  type; they render plain like the main category tree and Godot's Create-New-Node dialog (the per-row
  icon carries the type).
- **Preview any `.gd` as an event sheet, automatically.** Right-click a `.gd` in the FileSystem (or
  script editor) → "Open as Event Sheet" renders it as rows; a new **Auto-preview** project setting
  (`eventsheets/editor/auto_preview_gd_on_select`, off by default) makes *selecting* a liftable `.gd`
  open it straight into the Event Sheets workspace as a read-only preview. And the preview now
  **re-renders live** - a read-only `.gd` preview silently re-imports the moment the file changes on
  disk (edit it in the script editor, refocus the Event Sheets tab, the rows track it). Design +
  rationale in `docs/internal/SPEC-preview-gd-as-eventsheets.md`.

### Fixed

- **Selecting an event block by clicking outside the condition cell** is pinned: a click in a block's
  empty lane or the left gutter resolves to a whole-row selection (so the block selects, and Delete acts
  on it rather than falling through to the scene tree).
- **The welcome demo sheet now matches its Generated GDScript.** Its events used the bundled demo
  actor's reflected ACEs (which the compiler's registry doesn't carry) and set `.trigger` instead of
  `trigger_id`, so they silently produced no code - the preview showed only the variables + a comment
  while the viewport showed events. Rebuilt from Core ACEs with real triggers; the panel now compiles
  to a `_process` function that matches the rows (`event_sheet_editor_test` asserts the match).

- **Pressing Delete in the event sheet no longer deletes a node from the open scene.** The dock
  handled Delete only in `_unhandled_key_input`, which runs *after* the editor's Scene-tree dock's
  delete shortcut - so with the event sheet focused, Delete could remove the selected scene node
  instead of the selected event/ACE. The focused viewport now consumes Delete/Backspace in
  `_gui_input` (emitting `delete_requested` to the dock), winning Godot's input ordering so it can
  never reach the scene tree.
- **Clicking just outside an event block now selects that event instead of clearing the selection.**
  The inter-block separator gap was dead space - `_find_row_index_at_y` returned -1 there - so a click
  "outside the condition cell" deselected everything (and, with nothing selected, Delete fell through
  to the scene tree). A gap click now resolves to the adjacent event (`viewport_hit_select_test`).
- **Duplicate built-in ACE ids are now caught.** The registry indexed descriptors by
  `provider::ace_id` and silently overwrote on collision (the later one shadowed the earlier, and
  both doubled up in the picker). It now `push_error`s at load time, with
  `ACERegistry.find_duplicate_ids()` as the test hook (`duplicate_ace_id_test`).
- **The GDScript escape-hatch block is calmer and theme-consistent.** Its badge and cell tint were a
  saturated blue that fought the editor theme; they're now muted neutral, so a code block still reads
  as "this is code" without the eye strain.

## [0.9.0] - 2026-06-22 - Performance & Game Feel

### Fixed
- **The generated `.gd` is now only rewritten when its content actually changed**, so the Godot
  editor stops prompting *"Files have been modified outside Godot"* every time you open, close, or
  test a scene. `SheetCompiler.compile()` rewrote the output file unconditionally on every recompile
  (sheet save, Attach to Node, Test Bench, export - all funnel through it); because the generated
  code is byte-stable, that bumped the file's mtime without changing a byte and tripped Godot's
  external-change watcher, alarming users into thinking they had broken something. The compiler now
  compares the fresh output against what is already on disk and skips the write when identical
  (`_output_is_current` / `_write_output_if_changed`), pinned by `write_if_changed_test`. Resolves
  the long-deferred post-save reload-prompt item.
- **The ACE parameter dialog no longer errors with "Trying to cast a freed object" when focusing its first field.**
  `_focus_first_field` cast every entry in its field map to `Control` guarded only by `!= null`, which doesn't
  catch a *freed* widget (the dialog can close before the deferred focus runs). It now skips freed entries via
  `is_instance_valid` - no more console-error spam when ACE dialogs open and close quickly.
- **Nine built-in ACEs that compiled but crashed, leaked, or misbehaved at runtime - surfaced by a new
  compile-coverage test and an adversarial template audit, each reproduced and fixed against Godot 4.7:**
  - **Save JSON File** guards the `FileAccess` handle (and closes it) instead of chaining `.store_string()`
	on a possible `null` - a missing parent dir or read-only path crashed the save outright.
  - **Focus Next / Focus Previous** guard the `null` from `find_next/prev_valid_focus()` before calling
	`grab_focus()` - single / edge-case menus no longer null-deref.
  - **Find Children (by name)** passes `owned = false`, so it finds runtime-spawned nodes instead of
	silently returning `[]` (the `owned` default excluded instantiated enemies - the advertised use case).
  - **Nearest / Furthest Node In Group** are host-typed to `Node2D` (they read `global_position`), so the
	picker no longer offers them on plain-Node / Control sheets where they fail to compile.
  - **Every X Seconds** accumulates with `get_process_delta_time()` instead of a bare `delta`, so it
	compiles under any trigger, not only `_process` / `_physics_process`.
  - **Look At (3D)** defaults its target to `Vector3(0, 0, -1)` rather than the node's own origin, which
	otherwise error-spammed "look_at() failed" every call on a node at the world origin.
  - **Play Sound / Play Sound At** free the throwaway one-shot player when the stream fails to load,
	instead of leaking it while waiting on a `finished` signal that never fires.
- **The "Set Material" ACE's default no longer breaks the build.** Its placeholder was
  `preload("res://effect_material.tres")`, and `preload` resolves at compile time - so a freshly-added
  Set Material wouldn't compile until you pointed it at a real material. The default is now `null`; the
  description shows the `preload(...)` form for when your material exists.
- **The Quick-Start demo and bundled showcases were sharpened for the release (release-readiness review).**
  The `player` sheet's On-Body-Entered check now tests the *colliding body* (`body.is_in_group("enemy")`)
  instead of the host node - the headline demo previously compiled a handler with a dead `body` parameter
  and an inverted group test. The five showcases now ship with Live Values **off**, so their generated
  `.gd` are clean, hook-free GDScript (the "it's just GDScript" proof artifacts a skeptic opens first;
  Live Values stays a toggle on your own sheets). Doc counts/links reconciled across the README, demo
  README, glossary, and this file (pack count 24→31, ACE count, a dead spec link, a phantom theme).
- **The Juice pack restores `Engine.time_scale` when it leaves the tree.** A scene change *during* a slow-mo
  used to leave the whole game running slow (the global `time_scale` was never reset); the behavior now
  calls `clear_slowmo()` on `tree_exiting`.

### Removed
- **Seven design/UX spec docs - development scaffolding now redundant with the feature documentation:**
  `SPEC.md`, `EDITOR-UI-SPEC.md`, `EventSheet_EditorParam_Exposure_Spec.md`, `FRAME-SPREADING-SPEC.md`,
  `EVENTSHEET_THEME_TOKEN_SPEC.md`, and both `docs/spec/*` (the folder is gone). The three *contract* specs
  their feature tests point at as the spec-of-record stay - `GDSCRIPT-PAIRING-SPEC`, `INSPECTOR-ATTRIBUTES-SPEC`,
  `ADDON-COMPOSITION-SPEC`. Every reference across code comments, docs, README/AGENTS/CONTRIBUTING, and
  `docs_integrity_test` was scrubbed or retargeted (frame-spreading pointers now go to `PERFORMANCE.md`); the
  usage docs (`RECIPES`, `PERFORMANCE`, `USING-WITH-EXISTING-CODE`, `GLOSSARY`, `C3-MIGRATION-GUIDE`) cover it.

### Changed
- **The "Emit Signal On" helper now emits the modern `signal.emit()` form** instead of the legacy
  `emit_signal("name")`. With a bare signal identifier it compiles to e.g. `enemy.died.emit(payload)` -
  idiomatic Godot 4 and parity-clean (the old form matched a banned substring in the codegen parity guard,
  even though only the helper itself, never a bundled pack, used it). The signal parameter is now a bare
  identifier rather than a quoted string. New `emit_signal_modern_test` pulls the live descriptor and runs
  its output through the project's own `BANNED_PATTERNS` scan so the helper can't regress to the legacy form.
- **The Core "Emit Signal" ACE now emits the modern `signal.emit()` form too** - matching the "Emit Signal On"
  helper. `emit_signal(&"name", args)` becomes `name.emit(args)`; the signal parameter is a bare identifier, so
  the signal must be declared (the Quick-Start player demo now declares `signal damage_taken(amount: int)` via a
  Signal row). `emit_signal_modern_test` was extended to pull the live Core descriptor and scan its compiled
  output through the parity `BANNED_PATTERNS`, so neither signal ACE can regress to the legacy form.
- **Internal development-scaffolding docs moved out of the user-facing `docs/` folder** into `docs/internal/`:
  seven status / progress-report / alignment-status / adapter-design notes (`*_STATUS`, `*_PROGRESS_REPORT`,
  `Auto_ACE_Adapter_*`, …). A newcomer browsing `docs/` now finds guides and contract specs, not dev
  scaffolding; the user-facing Layout/Alignment **guide** and the blessed architecture-slices tracker stay put.

### Added
- **Every behavior-pack ACE is now node-targetable** - pick *which* node carries the behavior
  instead of being locked to a direct child literally named after the pack. A pack ACE authored as
  `$WeaponKit.can_fire()` now exposes an editable **"On node"** field defaulting to the conventional
  path (so existing sheets compile byte-for-byte identically - drift stays 0), retargetable with
  `$`-autocomplete to `$Player/WeaponKit`, `%Weapon`, or any node path. This is Construct's "the ACE
  acts on the object instance you picked" model in Godot terms - and it's *why* a pack condition like
  **Weapon Kit → Can Fire** can now be used on a sheet whose behavior lives under another node, instead
  of forcing a raw GDScript block to write the correct path. One change in the auto-ACE generator
  (`ace_generator._parameterize_node_target`) covers all packs at once; only a bare `$Identifier`
  prefix is parameterized - `$"Quoted"`, `%Unique`, and multi-segment `$A/B` paths stay verbatim, and a
  method whose own arg is named `target` (e.g. `spring_host_scale(target)`) uses `on_node` for the node
  field to avoid the clash.
- **The flagship `platformer_shooter` showcase's shoot + jump logic is now fully code-free** - the exact event
  a user pointed at as "dropping to GDScript" is re-authored with its conditions on the left (Is Action
  Pressed + the Weapon Kit's own **Can Fire**, targeting `$Player/WeaponKit`) and its actions on the
  right (the pack's **Fire** + **Spawn Scene (Full)**, aimed by the Platformer pack's facing direction).
  The demo now *teaches* Construct-style legibility instead of a raw `if` block - proof the plugin can
  author real game logic with zero GDScript. Made possible by the node-targetable pack ACEs above. The
  jump/release handler likewise split into **Is Action Just Pressed/Released** conditions + the Platformer
  pack's **Jump / Jump Released** actions - byte-identical generated output, drift unchanged.
- **`@ace_expose_all` - one-line custom addons, near-zero annotations.** A single class-level
  `## @ace_expose_all(node)` (or plain `## @ace_expose_all` for an owned RefCounted helper) publishes
  every own public method/signal of a class as an ACE with **zero per-member annotations**: type inferred
  from the return type (`bool`→condition, `void`→action, value→expression, `signal`→trigger), name from
  the identifier, and - under `(node)` - codegen synthesized as the node-targeted `{target}.method(args)`
  form (reusing the new "On node" param). A behavior no longer needs an
  `@ace_codegen_template`/`@ace_condition`/`@ace_name` line per method; per-member `@ace_*` annotations
  stay available as optional overrides, and `_`-prefixed + inherited engine members stay out. Drops into
  a pre-existing project with one line via the existing per-sheet / `eventsheet_addons/` /
  annotated-autoload registration surfaces (no project-wide scan, so a big project never floods the
  picker). New `expose_all_node_test`; existing packs unaffected (drift=0). Properties + the autoload
  singleton form are documented follow-ups (`docs/internal/SPEC-low-verbosity-custom-addons.md`).
- **The ACE picker reads cleaner - a single muted column** (Godot "Create New Node" style). The
  redundant **"Type" column** and the per-row type **tint** that made the picker visually busy are gone;
  an ACE's type is conveyed by its row **icon**, its tooltip, and the description panel instead.
  Presentation-only - search, relevance ranking, Favorites/Recent, and keyboard nav are unchanged -
  and pinned by `picker_layout_test` (the tree has one column and populating it no longer touches a
  removed column). The bright per-kind category colours are also muted to one theme-driven "quiet
  divider" colour (the node-type distinction is carried by the section's class icon), and the codegen
  in the description panel is now **visible-but-muted** (kept for the "it's just GDScript" value, just
  de-emphasized). And the everyday **featured** verbs (Compare, Set/Add Variable, Print, Wait/Spawn,
  On Process/Ready - a curated default you can extend) are **bolded and floated to the top of their
  group** (C3's `highlight` idea), so the common picks stand out. This completes the picker visual
  cleanup (`docs/internal/SPEC-ace-picker-visual-cleanup.md`).
- **A generic "Expression Is True" condition** - the code-free escape hatch for a boolean
  expression. Use any GDScript that returns a bool (a behavior method like
  `$Player/WeaponKit.can_fire()`, `health > 0 and shielded`, `%Door.is_open()`) directly as a
  condition instead of dropping the whole row to a raw GDScript block. Emitted verbatim, inverts to
  `not (...)` for free, and lives in **General Conditions** beside Compare Values. New
  `expression_is_true_test`. (Prefer a named pack condition where one exists - see the pack
  node-target spec.)
- **The Pick Filter (For Each) dialog blocks saving a loop whose collection / where / order-by doesn't compile.**
  On Save it runs the same lint the on-save "Check Sheet for Errors" pass uses (the collection wrapped per kind,
  the predicate / order-by with the loop iterator stubbed) and, if an expression is broken, refuses to commit -
  re-opening the dialog with the exact compile error instead of writing a For Each that fails later at codegen
  time. Fail-open: if the linter can't run (no active sheet) the save proceeds, so a glitch never traps a valid edit.
- **The Pick Filter (For Each) "Where" and "Order by" fields now autocomplete.** They became single-line
  GDScript code editors with the same completion the raw-code blocks use - sheet variables / functions,
  host-class members, `$Child` nodes - plus the loop's own iterator name, so `item.health` and distance
  expressions complete against the exact vocabulary the on-save linter validates them with. Enter still
  confirms the dialog (newlines are stripped to keep the field single-line).
- **Built-in ACE compile-coverage + runtime-safety regression tests.** `builtin_ace_compile_test` compiles
  every built-in ACE template (params filled with values of their type, in its declared host class) and
  asserts it parses - 446 covered, with the handful that need a loop / return / call-target context listed
  explicitly rather than skipped silently. `ace_safety_test` locks in each of the nine runtime-safety fixes
  in this release so they can't silently regress.
- **On-save linting + "Check Sheet for Errors" now cover For Each (pick filter) fields.** A typo in a
  loop's collection, predicate, or order-by used to slip past every author-time check; the diagnostics now
  lint all three - the collection wrapped per kind (so a GROUP name isn't read as bare GDScript) and the
  predicate / order-by with the loop iterator stubbed (so a valid `item.field` resolves but a typo flags).
- **The Project Doctor flags a coroutine under a per-frame trigger.** A `Wait` / `Wait For Signal` /
  `Await Next Frame` / `Await If Over Budget` action (or a raw `await`) under On Process / On Physics Process
  overlaps itself - the next tick fires while the previous run is still suspended, double-processing. The
  Doctor (Tools → Check Project) now warns and points to a one-shot trigger or the Time Slicer pack (the
  codebase documented this footgun but shipped no detector).
- **On Signal can now receive the signal's parameters.** The generic **On Signal** trigger (react to any
  signal by name - on self, a node path, or an autoload) gained an optional **Arguments** field: type the
  signal's signature (e.g. `amount: int`) and the generated handler takes those typed parameters, so the
  event's conditions and actions can use them - the same typed-args capability the reflected `signal:NAME`
  triggers already had, now for hand-typed signals too. Empty = a no-argument handler (unchanged). New
  `on_signal_args_test`.
- **A runnable "Swarm" showcase - frame-spreading you can watch** (`demo/showcase/swarm.tscn`). Open and
  run it: 800 sprites spawn into a group and a single **Budgeted For Each** (90/frame) wobbles them, so the
  colour refresh visibly *sweeps* through the crowd while the FPS stays pinned - the frame-spreading made
  literal. Built by `tools/build_examples.gd` (with a new `dot.tscn` sub-scene) and guarded by
  `showcase_examples_test` (compiles → parses → instantiates). Also refreshes the demo README, which had
  gone stale on the `platformer_shooter` showcase.
- **Recipe 12 - "The game-feel toolkit"** (`docs/RECIPES.md`): a self-contained reference for the Juice
  pack's feel actions - hit-stop/slow-mo (with a realtime hold), trauma-based screenshake, squash & stretch
  plus spring squash, and punch-zoom - with exact signatures and how to layer them into one satisfying hit.
- **Recipe 11 - "Crowds without the hitch"** (`docs/RECIPES.md`): a self-contained, end-to-end showcase of
  the frame-spreading stack - the Time Slicer pack (enqueue + On Process Item), the Budgeted For Each
  Inspector tick, and Run In Background for pure off-thread compute - with a "which one?" table.
- **A "Using EventSheets with your existing code" guide** (`docs/USING-WITH-EXISTING-CODE.md`). Answers the
  common adoption question - *does it work with code that has no ACEs?* - and is self-contained: calling
  existing GDScript / autoloads / host members from a sheet (verbatim ƒx expressions + the Helpers ACEs +
  RawCode blocks), reacting to your own signals (On Signal / reflected `signal:NAME` / lifecycle triggers),
  the one-script-per-node rule and the behavior-pack child-node solution for already-scripted nodes, calling
  a sheet *from* your code via the zero-dependency parity contract, reverse-lift, and the honest
  stringly/compile-time-validation limitations. Verified against the compiler by a multi-agent investigation.
- **Budgeted For Each - tick a frame-spread budget on a loop and it stops hitching.** Setting
  `frame_spread_count` (iterations/frame) and/or `frame_spread_budget_ms` (a wall-clock fence) on a pick
  filter now compiles the `For Each` into an in-place loop that processes a slice per frame and resumes on
  the next - no behavior to attach, no `await`, no restructuring. It snapshots the collection once per pass
  (a persistent class-member cursor survives across frames), skips items freed mid-pass
  (`is_instance_valid`), and restarts a fresh pass at the end; both the budget break and the pass-restart
  sit at the top of the loop (the body is emitted by the caller). Drive it from a per-frame trigger; not
  yet combined with While/Repeat, order-by, or pick-first-N (those emit a normal loop + a compile warning).
  New `budgeted_for_each_test` covers count/ms/fallback/regression shapes and that each output parses; the
  Doctor's unbounded-loop nudge goes quiet once a loop is budgeted. (Frame-spreading Solution 2 - completes
  the stack.)
- **A "Run In Background" pack - off-thread heavy compute (the 31st addon).** The "too heavy even to
  spread across frames" lane: hand a **pure** function to the engine's `WorkerThreadPool` with **Run In
  Background(callable)** (or **Run Batch In Background** to fan an array across threads); the main thread
  only polls, so it never hitches, and **On Done(result)** fires on the main thread when the work
  finishes - for procgen, pathfinding bakes, data crunching that would stutter even spread across frames.
  Advanced-gated: the callable must touch no nodes / scene tree (unenforceable - see
  [docs/PERFORMANCE.md](docs/PERFORMANCE.md)). Each call gets a unique id and the worker stores its result
  in a `Mutex`-guarded slot for the poll to emit. (Frame-spreading Solution 4.)
- **The Project Doctor flags an unbounded loop that runs every frame.** A heavy **For Each** under On
  Process / On Physics Process that's neither capped (pick first N) nor budgeted hitches the game; the
  Doctor (Tools → Check Project) now adds an info-tier advisory when such a loop carries ≥ N actions,
  pointing at the Time Slicer pack or a Budgeted For Each. It flags the *pattern*, not a cost estimate (so
  it never alert-fatigues); threshold via `eventsheets/doctor/loop_cost_threshold` (default 3); bundled
  packs and While/Repeat loops are exempt. Adds the `PickFilter.frame_spread_count` /
  `frame_spread_budget_ms` fields (the Budgeted For Each schema - the loop codegen is a follow-up).
  (Frame-spreading Solution 5.)
- **Budget ACEs - hand-rolled frame-spreading (advanced).** Three Performance actions for power users:
  **Await Next Frame** (`await get_tree().process_frame`), **Begin Frame Budget(ms)** (arms a per-frame
  fence), and **Await If Over Budget(ms)** (drop it at the bottom of a `For Each` body; it yields + re-arms
  when the budget is spent). They reuse the Wait/await machinery, so the handler becomes an implicit
  coroutine - **advanced-gated**, for one-shot triggers only (never a re-firing On Process; see the
  re-entrancy warning in the new [docs/PERFORMANCE.md](docs/PERFORMANCE.md)). The easy path stays the Time
  Slicer pack. (Frame-spreading Solution 3.)
- **A "Time Slicer" pack - spread heavy work across frames (the 30th addon).** The first of the
  frame-spreading tools (see [docs/PERFORMANCE.md](docs/PERFORMANCE.md)): a managed
  work queue that drains within a per-frame budget - **time (ms)**, **count**, or both. Enqueue items
  (or a whole group) in one event and react to **On Process Item(item)** in another, like reacting to a
  signal; heavy work (spawning hundreds of objects, updating thousands of entities) self-spreads across
  as many frames as the budget needs - no loop, no await, no hitch - then fires **On Drained**. Inspector
  knobs for the ms/count budget; Pause/Resume, Set Frame Budget, Is Busy, Items Remaining. Attach as a
  component, or register it as an autoload for one global slicer.
- **Nearest / Furthest node picking - auto-attack targeting with no loop.** Two project-level expressions
  in the *Nodes: Picking* row - **Nearest Node In Group** / **Furthest Node In Group** - pick the closest
  or farthest member of a group by distance to the calling node (the `reduce()` idiom, since Godot 4 has
  no `Array.min_by`; one expression serves both 2D and 3D via `global_position.distance_to`; empty group →
  `null`). Pair them with a *Has Line Of Sight To* condition for "attack the nearest enemy I can see," or
  use the new occlusion-correct **Nearest Visible In Group** expression added to both Line of Sight packs
  (2D + 3D), which scans the group and skips a nearer-but-blocked target so a wall can't shadow a visible
  farther enemy.
- **A "Juice" pack - game feel in one behavior (the 29th addon).** Trauma-based **screenshake** (the
  C3 scroll-behavior idea, but additive on the camera's `offset`/`rotation` so it composes with camera
  follow instead of fighting it; squared-trauma ramp, FastNoiseLite for organic motion, stacks + decays
  on its own), smooth **zoom** in three flavours - by percent, **Zoom To Position** (glide so a point
  becomes the screen centre) and **Zoom Toward Point** (keep a world point pinned under the same screen
  spot, mouse-wheel-to-cursor style) - and volume-preserving **Squash & Stretch** that springs back
  elastically, on a **Node2D *or* a Control** (UI juice too). The camera is **auto-found** from the active
  viewport, so Shake/Zoom work from anywhere with no wiring; every effect is fire-and-forget (Tween-driven),
  pre-filled with sensible defaults, exposes its feel as Inspector knobs, and emits an **On Shake Stopped /
  Zoom Finished / Squash Finished / Slowmo Finished** trigger to chain the next beat. It also does
  **Slowmo** (eases `Engine.time_scale` to a target, holds for a duration, eases back - with a toggle for
  whether the hold counts in realtime or scaled game time via `Tween.set_ignore_time_scale`, and
  Inspector-tunable fade-in/out curves), plus a **Spring Squash** variant that springs the scale back with
  a real per-frame spring integrator (stiffness/damping, organic overshoot) instead of the elastic tween,
  and a **Clear Slowmo** reset.
- **Four stateful packs now use typed inner classes instead of `float()`/`int()`/`bool()`-cast
  Dictionaries.** **Spring** (`SpringEntry` / `ColorSpringEntry`, each with an `integrate(delta)`),
  **Health** (`HealthPool`), **Simple Abilities** (`AbilityData`), and the **HTN Agent** (`HTNMethod` /
  `HTNCondition`). Their hot paths - the spring integrator, damage absorption + pool decay, cooldown /
  stack / expiry regen, and the planner's utility sort + precondition checks - now read typed fields, so a
  field typo fails at compile and the casts are gone. Behavior is unchanged: each pack ships a runtime test
  that drives its real logic (spring settling, damage/decay/death/revive, cooldown regen + temporary
  expiry, HTN decomposition with precondition gating + utility ordering) to prove byte-for-byte equivalence.
- **Discrete transition signals on the Car and Follow packs.** **Car** edge-fires **On Drift Started /
  On Drift Recovered** when its velocity slides off the heading past a `drift_angle_threshold` knob;
  **Follow** edge-fires **On Reached Target** at the `min_distance` boundary (mirroring Move To's On
  Arrived). Follow's `following` flag is now internal state driven by Start/Stop Following, not a stray
  exported designer knob.
- **Pack polish.** **Tile Movement**'s *Simulate Step* `direction` is now a left/right/up/down dropdown
  (was free text); **Sine 3D** gains `phase_degrees` parity with the 2D Sine pack (exported knob + a *Set
  Phase* action that offsets the wave time); **Drag & Drop**'s `snap_uids` is a typed `Array[int]`; and the
  **Save System**'s *On Save Written* is now **truthful** - `_write_all` captures the FileAccess /
  ConfigFile write error and *Save Game* emits the signal only on a genuinely successful write, instead of
  optimistically on every *Save Value*.
- **Tree-membership triggers - react to a node entering/leaving, don't poll.** Five new signal triggers
  - **On Tree Entered / Tree Exiting / Tree Exited / Renamed / Child Entered Tree** - so "when this
  *other* node enters or leaves the scene" is a reactive event, not a per-frame `IsInsideTree` check
  inside On Process (the Construct poll habit). Surface them as *source-node* triggers (react to another
  node); for the host's own first entry, On Ready stays the idiomatic answer. Tree Exiting fires while
  the node is still in the tree, Tree Exited after removal; Child Entered Tree hands you the entering
  child. They compile to a `_ready` connection and round-trip back to the named trigger.
- **The Project Doctor flags a fan-out god-sheet - by node count, not row count.** A common Construct
  habit is one big event sheet doing everything; in Godot, a sheet reaching into *many different nodes*
  is usually several nodes' jobs crammed together. The Doctor now adds an advisory when a plain sheet
  targets ≥ N distinct external nodes - counted by the same node-path parser that powers `$`-validation
  (the With-node scope, "On node" targets, `$path` / `%unique` refs, raw GDScript), **not** row count,
  since a long coherent state machine on one host is perfectly fine - pointing at a behavior-per-node
  split or a deliberately-named coordinator. Info-tier; behavior + autoload sheets are exempt; threshold
  via `eventsheets/doctor/fanout_threshold` (default 6).
- **The Project Doctor nudges duplicated globals toward an autoload.** In Construct, a global is just
  global; in Godot, the same value declared in several scripts is N copies of one truth, and the idiom is
  a single **autoload** (a Game State singleton). The Doctor (Tools → Check Project) now adds an advisory
  when the same global name appears across two or more sheets - listing them and pointing at New Sheet →
  Game State (Autoload). Info-tier only (never fails CI); autoload sheets and packs are skipped, and a
  name a GameState autoload already publishes is exempt (the solved case).
- **A "Behavior Component" starter teaches composition by example.** The bundled gameplay starters
  (Platformer, Top-down…) are one big sheet on the root node that polls every physics frame - so the
  first thing a newcomer copies models the Construct god-sheet habit. The New Sheet menu now also offers
  **Behavior Component (signal-driven)**: a small **Pickup** behavior you attach as a *child* of the node
  it controls (the Godot answer to a Construct behavior). It compiles to an attachable Node with a typed
  `host` accessor (its parent), **reacts to the host's `body_entered` signal** instead of checking every
  frame, and **emits its own** (On Collected) so other sheets stay decoupled - with `value` an exported
  designer knob. Composition + reactivity + the Inspector, in one copyable artifact. (The existing
  monolithic starters stay; this is purely an addition.)
- **"Designer-tweakable (Inspector)" is now a separate choice from "global", and off by default.** In
  Construct, a global variable is just global; Godot has two distinct things a value can be - a *designer
  knob* you tweak per-instance in the Inspector (`@export var speed`), or *internal script state* (a
  counter/timer the script just manages). The plugin used to auto-`@export` **every** new global, leaking
  internal state onto the Inspector. Now the Access checkbox reads **"Designer-tweakable in the Inspector
  (@export)"** and a new variable defaults **off** - a plain private `var` - so you opt into Inspector
  exposure deliberately. The Inspector-options disclosure (tooltip / range / show-if…) stays hidden until
  you tick it, so you can't set attributes that would silently no-op. Existing variables keep their
  exported flag (sheets untouched).
- **The picker nudges you from polling toward signals.** When you look at a polling condition that has a
  clean reactive twin - Overlaps Body / Area, Is Timer Stopped, Is Animation Playing, Is Button Pressed -
  the picker's info panel now shows a one-line tip pointing at the signal trigger that reacts *once*
  instead (On Body Entered, On Timeout, On Animation Finished, On Pressed). It's informational only - the
  condition stays fully pickable - and is driven by a small, curated, shared poll→signal map
  (`ACEDescriptor.REACTS_TO`) that deliberately omits conditions with no real signal (is_on_floor, held
  input-action checks) so it never suggests a cargo-cult signal. The Construct "check every tick" reflex
  meets Godot's "react to it" idiom at the moment you're choosing. **And it's the default now:** when a
  search surfaces a polling condition that has a twin, the reactive trigger is shown right beside it and
  becomes the type-and-Enter pre-selection (so "overlap" lands on **On Body Entered**) - unless you type
  the condition's exact name, which always keeps the condition. The visible list and its order are
  unchanged; only which item is highlighted shifts, and every condition stays one keystroke away.
- **Migration guide: a "Polling vs reacting" section** - the biggest mental shift from Construct 3 (one
  big *every-tick* sheet → *react to a signal*), with a polling/reacting before-after, the
  `_process` vs `_physics_process` rule of thumb, and - crucially - an explicit "when polling **is**
  correct" carve-out (continuous values: camera follow, smoothing, axis input, `is_on_floor`) so
  readers don't over-correct into contorted signal usage. The "Every tick → On Process" mapping keeps
  its literal translation but now points at the signal-first reflex.
- **Unique-name (`%Name`) references are validated + autocompleted** - Godot's stable, refactor-proof
  way to reach a node, and the closest thing to a Construct *object name*: mark a node **Access as
  Unique Name** in the scene tree and `%ScoreLabel` then resolves no matter where you move it (unlike a
  brittle `$HUD/Margin/VBox/ScoreLabel` path). The editor used to ignore `%` refs entirely - so reaching
  for the *stabler* reference got you no help. Now `%Name` and `%"Quoted Name"` get the same amber
  "no such node" warning as `$paths` (with a tooltip pointing you at "Access as Unique Name"), and
  typing `%` lists the scene's unique nodes as completions. Printf-style format specifiers (`"%d"`,
  `"%.2f"`) and the modulo operator (`a % b`) are left alone, and resolution is owner-scoped (an
  instanced sub-scene's own uniques stay encapsulated). Same warning-not-error policy as `$`.
- **"With node X:" scope blocks (Construct-style "pick once, act many").** Right-click an event →
  **Scope Actions To Node…** and give a node ($Enemy, get_node("…"), a variable): every action in that
  event - and in its sub-events - that leaves its "On node" target on the host now acts on X instead, so
  you write the target once rather than on every action. It renders as a "With node  X" chip in the
  condition lane (double-click to edit), composes with conditions and nesting, and leaves
  non-targetable actions (Print, Wait) and any action you explicitly targeted untouched. Compiles
  inline per action ($Enemy.play(); $Enemy.modulate = …), so the generated GDScript stays readable and
  a re-imported .gd lifts each line back to an individual targeted ACE. Clearing the field drops the
  scope. The target field defaults empty, so existing sheets are byte-for-byte unchanged.
- **Node paths are validated as you type, with `$` autocomplete.** Expression fields (every node-reference
  param, including the new "On node" target) now flag a node reference that does not exist in the edited
  scene - `$Enmy`, `get_node("UI/Scrore")` - in amber with a "no node here yet" tooltip, so a typo is
  caught at author time instead of failing silently in the running game. It is a *warning*, not an error:
  a path may legitimately point at a node spawned at runtime. Typing `$` also offers the scene's node
  paths as completions, so a path can be typed-and-picked, not only chosen through the 🔍 picker.
- **Node-scoped ACEs can target another node now.** Every host-scoped node ACE (Set Modulate, Set
  Volume, Play Animation, Set Camera Zoom, Set Label Text, the particle/joint/range/button setters - 180+
  in all) gained an optional **"On node"** field: leave it blank to act on this node as before, or pick a
  node / type a path (`$Enemy`, `get_node("UI/Score")`) to redirect the whole operation to another node.
  This is powered by a new covenant-safe codegen idiom, the optional-prefix `{target.}` (a blank value
  emits nothing, so existing sheets compile **byte-for-byte unchanged** - verified by the drift audit),
  and the importer round-trips both shapes (`play()` and `$Enemy.play()`) back to the same ACE. The
  spawn-a-new-node and already-targeted ACEs (e.g. Play Sound At, the Joint body setters) are left as-is.
- **Group aggregate expressions** - roll a numeric member up across a whole group with no loop: **Sum
  In Group**, **Average In Group**, **Lowest In Group**, **Highest In Group** (joining the existing
  Count Nodes In Group, under the **Groups** category). The "average health of all enemies" case is now
  one expression instead of an accumulator loop. Each compiles to a bare `reduce` one-liner over
  `get_tree().get_nodes_in_group(...)` (zero runtime); Sum/Average seed at 0, Min/Max seed at +/-INF so
  an empty group returns the sentinel rather than crashing. A runtime test exercises the reduce math.
- **Custom ACEs guide** ([docs/CUSTOM-ACES-GUIDE.md](docs/CUSTOM-ACES-GUIDE.md)) - a complete how-to
  for authoring your own Actions / Conditions / Expressions / Triggers: the three extension paths
  (auto-ACE provider scripts, custom descriptors via the EventForgeBridge autoload, and built-in
  modules), the codegen-template language (`{param}`, `{uid}`, multi-line, optional-comma, stateful
  conditions), full descriptor + parameter + widget-hint reference tables, the picker / category /
  Simple-Mode rules, and a compile-and-run testing recipe. Linked from the README.
- **JSON is its own module now, with two new ACEs.** The JSON vocabulary (To / From JSON Text, JSON
  Is Valid, Save / Load JSON File) was consolidated out of the Collections module into a dedicated
  **JSON** category, and gained **To JSON Text (pretty)** (indented, human-readable output) and
  **Parse JSON Into Variable** (parse JSON text - a server response, the clipboard - straight into a
  variable). The five moved ACEs keep their ace_ids and codegen templates, so existing sheets are
  unaffected; only the picker category changed (from "Variables: JSON"). Once parsed the value is a
  normal Dictionary / Array, so the Variables: Dictionary / Array ACEs read and edit it.
- **File-management ACEs** - a **Files** vocabulary so save systems, config files and level data never
  force a drop to GDScript: **Read Text File**, **Write Text File**, **Append To File**, **File Size**,
  **File Exists**, plus **Delete / Copy / Move-or-Rename** a file, and a **Files: Directories** set
  (**Make / Remove / Exists**, **List Files / Subdirectories**). Each compiles to the exact native
  FileAccess / DirAccess call: reads use the null-safe static accessors (return "" / [] on error
  instead of crashing) and writes guard the handle *and close it* (so a later op on the same file
  isn't blocked by a still-open write - caught by a runtime round-trip test). Path hints nudge user://
  (res:// is read-only in an exported game). FileExists moved here from the JSON set; JSON file
  save/load stay under Variables: JSON.
- **Remappable keyboard shortcuts** - Tools ▸ Keyboard Shortcuts is now an *editor*, not just a cheat
  sheet: click any of the ~18 authoring shortcuts (Add Event / Condition / Action, Save, Duplicate,
  Copy / Paste, Undo / Redo, …) and press a new combination to rebind it. Clashes are flagged inline
  but allowed (you resolve them); per-action and "Reset all" restore the defaults; the fixed
  structural keys (Tab nesting, Delete, Enter/F2, Escape, Command Palette, zoom) stay read-only for
  reference. Custom bindings save **per-user** to a `user://` file - local to each developer,
  consistent across projects, and never committed to git. (The rebinding backend already existed
  behind ProjectSettings; this adds the UI and moves persistence to per-user storage.)

### Changed
- **Built-in ACE modules are auto-discovered.** Adding a vocabulary module no longer means editing
  `builtin_aces.gd`: any script in `addons/eventforge/registration/modules/` that exposes
  `static func get_descriptors() -> Array[ACEDescriptor]` is now loaded and registered automatically
  (in a stable sorted order, with the generic `helper_aces` module kept last so its catch-all
  templates never shadow a specific ACE in the reverse-lifter). Drop a module file and its ACEs
  appear on the next load. ace_ids and templates remain the compatibility covenant. The **test runner
  auto-discovers tests the same way** (any `tests/*.gd` with `static func run() -> bool`, with the
  shared-state teardown tests forced to run last), so adding a built-in module plus its test is now
  **zero registration edits** - just drop the files.
- **Plainer wording for beginners.** The dock no longer surfaces the insider acronym "ACE" in
  beginner-facing places: the node-drop preview reads "Dropped Node Preview", the row-comment dialog is
  "Row Comment", and the "couldn't edit this row" / "nothing found on this node" messages use plain
  "actions and conditions" language. The advanced custom-ACE provider and export features keep the term
  (it matches the Custom ACEs guide).
- **Removed the redundant "Group" badge on group headers** - a group's accent bar + tinted background
  already read unmistakably as a group, so the leading "Group" text badge was just visual clutter.
  Headers now show only the inline-editable title (and its optional description); selection, the
  group-editor popup, and descendant-block selection are all unchanged.

### Editor UX - plain-language picker, relevance ranking, dialog consistency (UI-audit pass 2)
The user-approved wide clusters from the UI audit:
- **Picker de-jargoned for newcomers** - the picker hints no longer surface the insider acronym
  "ACE"; they read in plain *condition / action / trigger* language (Construct 3 / GDevelop never
  show "ACE" to users). The Sheet / View / Tools menus gained tooltips, the GDScript panel opens with
  a one-line orientation ("the plain GDScript your sheet compiles to - read-only, no runtime"), and
  the behavior-sheet empty state keeps the plain-language search tip it previously dropped.
- **Picker relevance ranking** - type-and-Enter now commits the *best* match instead of "first in the
  grouped tree": matches are scored (exact name > prefix > word-start > substring in name > substring
  elsewhere) so typing "hide" pre-selects **Hide**. The grouped tree is unchanged - only the
  pre-selected target is smarter; a small length penalty favours the shorter, more specific name.
- **Recents persist across editor restarts** - last-used ACEs save per-user and per-project to a
  `user://` file (deliberately **not** project.godot, which would churn on every ACE use), so the
  ★ Recent pane survives a restart the way ⭐ Favorites already do.
- **Variable dialog matches the shared form styling** - it now uses the standard content margin and
  the shared 120px label column (it previously hand-rolled 130px rows and added its form flush).

### Editor UX - keyboard-first dialogs & picker polish (UI-audit pass)
A multi-agent audit of the editor UI found it broadly healthy; the gaps clustered in keyboard/focus
mechanics and the ACE picker. This pass ships the narrow, low-risk wins:
- **Variable dialog is now keyboard-first** - opening it focuses the Name field (and selects it for
  quick overtype when editing), and Enter confirms, matching function_dialog and the ACE picker.
- **ACE picker: Down from the search box enters the results, Escape closes** - typing then pressing
  Down hands focus to the result tree (its native arrow navigation takes over from the pre-selected
  first match), and Escape closes the picker from either the search box or the tree, so the whole
  pick is keyboard-only (the code's prior "arrow/Enter work" claim is now actually true).
- **No-match search now guides instead of going blank** - a search that finds nothing nudges the C3
  vocabulary bridge ("try a plainer word like move, spawn, or hide") rather than showing an empty tree.
- **Node & expression sub-pickers honour Enter** - type-and-Enter commits the first result, matching
  the main picker (those two search boxes previously swallowed Enter).
- **Add Condition / Add Action toolbar buttons now carry editor icons** (MemberConstant / MemberMethod),
  finishing a primary toolbar that previously left two of five buttons text-only.

### Fixed
- **Silent-bug sweep - six defects that shipped invalid or wrong behaviour without ever crashing at
  compile time** (each reproduced by an adversarial sweep, now pinned by `silent_bug_regression_test`):
  - **Awaited multi-statement actions emitted `await var …`.** Marking a multi-line ACE (Spawn Scene
	At…) as awaited prefixed `await` onto the whole joined template, so it landed on the `var`
	declaration line - a parse error that only surfaced at reload. `await` now wraps only the
	trailing statement of a multi-line template.
  - **Distinct trigger sources could collide into one handler.** Two sources that normalised to the
	same token (`A/B` and `A_B` both → `_a_b`) emitted two same-named `func _on_…` handlers (a parse
	error). The token is now injective - an illegal-char path gets a short stable hash suffix - while
	legitimate snake_cased autoload names (`event_bus`) keep their readable handler names unchanged.
  - **Unresolvable conditions silently OPENED the gate.** A condition whose ACE couldn't be resolved
	(addon uninstalled / stale id) was dropped, so the event body ran unconditionally every tick. It
	now fails **closed** (`if false`) with a warning - a vanished gate can never run.
  - **Negating "Every X Seconds…" broke the interval.** Inverting a stateful condition wrapped its
	header in `not (…)`, leaving the timer reset to run in the wrong branch (it fired nearly every
	frame, then went silent). Stateful conditions now refuse the negation, with a warning.
  - **Reverse-lift shadowed specific ACEs with generic catch-alls.** Importing generated GDScript
	matched the generic Core ACEs (SetVar, Call Function…) before specific ones, so `position = …`
	lifted as **Set Variable**, `add_child(…)` as **Call Function**, etc. Reverse entries are now
	tried most-specific-first (by literal-char count), so the round-trip preserves the real ACE id.
	(The byte-roundtrip gate never caught this - the generic re-emits the identical line.)
  - **Charge abilities spent only one stack per regen cycle.** The Simple Abilities pack gated
	activation on the per-stack regen cooldown, so a 3-charge dash used 1 of 3. Activation now gates
	on available stacks alone; the per-stack cooldown stays the regen timer.
  - **Phantom row selection from a span toggle.** Ctrl-toggling an ACE span on then off on a
	previously-unselected row left the row highlighted and drag/delete/edit-eligible. The viewport
	now tracks span-only selection provenance and releases the row when its last span is toggled off.
- **Duplicate `Core::GetFrameCount`** - the dev-helper "Frame Count" reused the same provider+id as
  the canonical Time-category one, so the registry index silently overwrote one entry. Removed the
  duplicate (Frame Count stays under **Time**), and added a suite guard that fails on any repeated
  `provider::ace_id` so this can't regress.
- **Alt+Up / Alt+Down row reordering** - the plain arrow-key selection branches matched first and
  swallowed the modifier, leaving the advertised "move row up/down" shortcut as dead code. The
  selection branches now require Alt to be up, so the move shortcut fires as documented.
- **Param values containing `{…}` were re-substituted** - `_apply_template` replaced placeholders
  iteratively per key, so a param value that itself contained `{anotherparam}` got expanded by the
  later key (e.g. `{a}-{b}` with `a="{b}"` produced `X-X` instead of `{b}-X`). It now runs a single
  left-to-right pass with **opaque** values - your input is emitted verbatim. Behaviour is identical
  on every existing template (golden/parity green, drift = 0); a new test pins the edge cases.
- **Event-trace highlighting was dead without Live Values** - the per-frame trace buffer and its
  debugger send were emitted only inside the `emit_live_values` block, so turning on the event trace
  alone produced no instrumentation. The trace now rides the same throttled `_process` independently
  (a shared "throttle emitted" flag keeps the synthesized and injected `_process` from duplicating);
  trace-only compiles stream `eventsheets:fired_events` correctly. Live-values output is unchanged.
- **Baked `{uid}` locals could collide** - the per-instance token for multi-line ACEs (Spawn Scene,
  Wait, Every-X-Seconds…) was a masked random draw, so two such ACEs in one event body could (very
  rarely) bake the same local and produce invalid GDScript. A central minting helper now tracks
  every token issued this session and re-draws on a clash, guaranteeing distinct locals; the 8-hex
  format is unchanged.
- **Shift+Down from an empty selection** skipped the first row (landed on row 2). It now starts the
  range on the first row, matching Shift+Up.

### Dev helper ACEs - Debug · Groups · Metadata · Nodes (the everyday tools)
- **25 developer-helper ACEs** (`dev_aces`) for the native operations you reach for constantly,
  so common dev/debug chores never force a drop to GDScript. **Debug**: Print, Print Labeled,
  Print Rich, Push Warning, Push Error, Assert, Print Scene Tree, Breakpoint.
  **Groups**: Add/Remove/Is-In Group, Get First / Count In Group, Call Method On Group.
  **Metadata**: Set/Get/Has/Remove Meta. **Nodes**: Get Parent, Get Child / Child Count, Find
  Child, Get Node Or Null, Has Node, Get Scene Owner, Is Ancestor Of - scene-tree navigation that
  was previously uncovered. Each compiles to the exact one-liner you'd hand-write (`print(…)`,
  `add_to_group(…)`, `set_meta(…)`, `get_parent()`); registry + category + codegen unit-tested.
- **12 more math ACEs** under **Math & Random** - Snap To Step, Inverse Lerp, Smoothstep,
  Ping-Pong, Angle Difference, Rotate Toward / Lerp Angle, Deg↔Rad, Positive Modulo, and Is
  Equal / Is Zero (approx) - the movement/animation/AI idioms the existing lerp/clamp/distance set
  was missing.
- **7 Color helper ACEs** under a new **Color** category - Lighten, Darken, Lerp Color, Color With
  Alpha, Color From HSV, Color From Hex, Invert Color - so hit-flashes, fades, and tints stay
  code-free (only the `Set Color Tint` action existed before). The colour params are full
  expressions, so they compose; the generated templates are parse-checked in the suite.
- **7 more helper ACEs** surfaced by a verified gap audit - **Tween Callback** and **Call After
  Delay** (fire a method after N seconds without a Timer node or a blocking `await`), **Set Camera
  Limits** (Camera2D), **Has All Keys** (Dictionary), **Repeat Text** (String), and **Seed Random**
  / **Randomize Seed** (Math & Random). Each compiles to the native one-liner; the multi-line and
  callback templates are parse-checked.
- **4 more from the audit** - **Signal Is Connected** (condition) and **Emit Signal On** (emit a
  signal on any target, reusing the existing optional-args idiom), **Set Text (formatted)** (set any
  node's `text` from a printf template + args in one row - replaces a raw-code block the showcase
  demos used), and **Move By** for 2D (relative translate; 3D already had it). A compile test proves
  Emit Signal On drops the trailing comma when there are no args.
- **Spawn Scene (Full)** - instance a scene with position, rotation, and an optional group tag in
  one row (a per-instance `{uid}` local, like Spawn Scene At). Replaces the raw `load().instantiate()`
  block the showcase demos used. A compile+parse test bakes the `{uid}` the way the dock does.
- **10 more ACEs from a second gap audit** - **Set Anchors Preset** and **Override Theme Color**
  (Control), **File Exists** (save-slot / config guard), **Set Self Tint** (CanvasItem - tint a node
  without affecting its children), **Apply Central Force** + **Apply Torque Impulse** (RigidBody2D),
  **Rotate (3D)** (Node3D), and **Set Speed Scale** for GPU + CPU particles (slow-mo / fast-forward a
  burst). Registry + node-type scoping + method-call templates are all tested.
- **On Body Exited / On Area Exited** triggers (Area2D) - the *entered* triggers existed but not
  *exited* (detecting something leaving a zone). Wired through the resolver and the importer so they
  codegen to a real `body_exited`/`area_exited` connection and round-trip byte-identically.
- **Project utility ACEs** (in the Core module) - the broad non-gameplay glue most games need:
  **Settings** (save/load values to a `ConfigFile` in `user://`), **Window** (set title, window /
  screen size, clipboard get/set), **Debug** (read live `Performance` monitors, static memory),
  **Time** (format seconds as `mm:ss`, system time/date strings), and **Reparent To**. Each compiles
  to the native call; the multi-line and formatting templates are parse-checked.
- **Node manipulation + picking ACEs** (`node_aces`) - build, rearrange, and select scene-tree
  nodes. **Nodes**: Add / Remove / Move Child, Free Node, Duplicate Node, Set / Get Node Name, Node
  Path, Index In Parent, Is Inside Tree, Current Scene Root. **Nodes: Picking**: Get Children, Find
  Children (by name), Nodes In Group, Random Node In Group. Complements the existing Node-navigation
  (Get Parent / Child / Find Child) and Groups sets.

### Simple Abilities behavior pack (the 28th addon)
- A per-instance **ability manager**, authored as an event sheet and compiled to a plain
  `SimpleAbilitiesBehavior` (`extends Node`, zero runtime dependency) - ported from the Simple
  Abilities C3 addon and expanded for Godot. Grant abilities by string id; **cooldowns**; **stack
  charges** that auto-regenerate; **temporary** abilities that auto-expire; per-ability **custom
  data**; and **tags** for bulk enable/remove/reset. 7 triggers (activated / ready / created /
  removed / stack consumed / gained / max reached), 7 conditions, 16 expressions, and 24 actions.
- **Godot-suited extras over the C3 original**: a **Current Ability ID** expression (the C3
  `_currentAbilityID` had no reader - the guide flagged it as missing), an exported global
  **cooldown multiplier** (built-in cooldown reduction the original did by hand), a **Current Ability
  Is** condition for per-id trigger filtering, and a **Ready Abilities** list. The pack rebuilds
  byte-identically (no-drift covenant) and its ACEs are registration-tested.
- **Shift-range row selection** - Shift+click extends a whole-row selection from the anchor to the
  clicked row, and Shift+↑/↓ grows or shrinks that range from the same origin. The anchor is
  preserved across moves (so the range can shrink, not just grow), and it's listed in the Keyboard
  Shortcuts cheat sheet.
- **Simple Mode now filters the ACE picker** - with Simple Mode on (View ▸ Simple Mode), the
  picker hides the advanced "drop to code" + debug rows (Run GDScript, Evaluate GDScript / Expression,
  Breakpoint, Assert, Print Rich) so newcomers see only the friendly, code-free vocabulary. Turning
  Simple Mode off restores everything. Previously Simple Mode only hid advanced *rows*, not picker
  entries.
- **Go back to re-pick an ACE while editing (C3-style)** - the `◀ Back` button in the params dialog
  now appears when editing *any* existing ACE (previously only when adding), and Back re-opens the
  picker **preselected on the current ACE** - so editing an action or expression can go back and
  swap it, exactly like editing a condition already did. Closes the one gap in the existing
  back-navigation flow.

### Editor DX - popup polish, error→row deep-linking, shadow guard, picker, watch + event trace
- **Consistent popups** - a shared `EventSheetPopupUI` helper gives the plugin's dialogs one look:
  aligned **Label  [field]** form rows (fixed label width, fields expand), standard content
  margins, and muted hint labels - matching the Godot 4.7 editor styling instead of each dialog
  inventing its own. The group-editor, breakpoint-condition, function-definition, and
  variable-definition popups adopt it - and the function and variable dialogs each drop a private,
  duplicate form-row helper (`_labeled_row` / `_attr_field_row`) in favour of the shared one. The
  factory helpers are unit-tested.
- **Keyboard Shortcuts cheat sheet** - Tools ▸ **Keyboard Shortcuts** opens an in-editor reference
  (Editing / Search / Debug / View / File & history) so the ~20 shortcuts are discoverable instead
  of learnable only from tooltips. Built from a static, unit-tested catalog via the popup helper.
- **Live event trace** - Tools ▸ **Event Trace** instruments each event (debug compiles only,
  opt-in behind a new `emit_event_trace` flag so normal output is byte-for-byte untouched) to
  stream its UID as it fires over the Live Values channel; the editor **highlights the firing rows
  in real time** (a cyan marker) so you can see which events actually run. Plain core Godot
  (`EngineDebugger`), piggybacking on the Live Values stream. Compiler emission + the viewport
  highlight are unit-tested. With conditional breakpoints, editable Live Values, and the Watch
  panel, this is the step/watch debugging set - automated step-to-next-event (editor-driven
  pause/step) stays out of reach until Godot exposes debugger step control to plugins.
- **Watch panel** - the Live Values window gains a **Watch** box: pin any expression over the
  sheet's variables (e.g. `health <= 0`, `score + lives`) and it's evaluated **editor-side**
  against each streamed values frame via `Expression` and shown live - no compiler instrumentation
  and no new debug protocol (reuses the existing Live Values stream). `evaluate_watch()` is pure +
  unit-tested.
- **Shadowing-variable guard** - naming a variable after a host-class member (e.g. `position` on a
  `Node2D` sheet) breaks the generated script. The variable dialog now **warns live + blocks** it
  (via `EventSheetProjectDoctor.shadowed_member_class`), and the row diagnostics flag any local
  variable already on the sheet that shadows a member.
- **Picker speed - pre-select first match** - the ACE picker now highlights the first result on
  open + as you type, so the description panel populates and arrow/Enter pick it without a first
  click (search auto-focus, "Apply & Add Another", and inline value editing were already in place).
- **Recipes + glossary** - new [`docs/RECIPES.md`](docs/RECIPES.md) (platformer, health, pickups,
  debugging, custom ACEs, common pitfalls) and a one-page [`docs/GLOSSARY.md`](docs/GLOSSARY.md)
  C3 ↔ Godot ↔ EventSheets Rosetta Stone, linked from the README quick start.
- **Error → row deep-linking** - when a ƒx expression or inline GDScript block doesn't compile,
  the editor now flags the **offending row** (a red left-stripe + wash, the message in the row
  tooltip) and jumps to the first one, instead of a status-bar line you have to hunt down. A
  pure, unit-tested `EventSheetDiagnostics.analyze()` lints every block + expression-hinted
  param against the sheet context (reusing the GDScript lint), keyed by the row's instance id so
  the viewport marks it directly - no source-map line mapping needed. Runs on save (the common
  bad-ƒx case the structural compile misses) and on demand via **Tools ▸ Check Sheet for Errors**;
  a bare typo'd identifier also gets a "did you mean …?" suggestion.
- **Group editor popup** - double-click / slow-click / Enter on a group header (and the naming
  step after Add Group) opens a Name + **Description** popup, replacing the inline title edit
  that could never *add* a description (it renders only once non-empty).
- **ACE picker - Create-Node parity** - the Add Action/Condition dialog now mirrors Godot's
  Create New Node: dedicated **⭐ Favorites + ★ Recent** left panes (same persisted data), a ⭐
  star toggle, a real description panel (name · type · category + what it does + codegen), and
  Cancel / Add buttons.

### Advanced Random addon (C3 parity) + ACE sub-categories + read-only .gd preview
- **Advanced Random** autoload pack (27th pack) - a faithful port of Construct 3's Advanced
  Random plugin: seeded numbers / range / int / **dice** / **normal (Gaussian)**,
  **Perlin/Simplex noise** (1D/2D/3D with fractal octaves, via `FastNoiseLite`),
  **permutation tables**, **shuffle bags** (pick without repeats), **weighted** + uniform
  picks, and a **Chance(%)** condition. One shared seed = reproducible runs; 22 ACEs under a
  nested "Advanced Random" picker section.
- **ACE sub-categories** - the picker nests `"Parent: Sub"` categories one level, so related
  ACEs cluster (e.g. the Array/Dictionary/Vector/String helpers under **Variables**).
- **Read-only `.gd` preview** - opening a GDScript file as a sheet defaults to a safe
  read-only preview (gated edits + save, a plain-language banner with Edit Events / Open in
  Script Editor, inline lift-fidelity), so a casual look never overwrites a hand-written script.

### Code-free authoring - stay in the event sheet
Five editor-only conveniences that keep authoring in the sheet instead of dropping to a raw
GDScript block; each reuses the reflection helper or compiles to the same GDScript unchanged.
- **Visual expression builder** - the Insert Expression picker now also lists the sheet host
  class's own reflected members under **This Object - Properties** and **This Object -
  Methods**; picking one inserts `name` (property) or `name()` (method). Editor-only.
- **Reflection-driven method / property pickers** - the Helpers ACEs **Call Method**, **Call
  Method (value)**, **Set Property** and **Get Property** offer the host class's real members
  as an editable suggest-combo (pick a real member, or still type one reflection misses).
  Editor-only; generated code unchanged.
- **Promote block to Function** - a row's More menu gains **Extract GDScript to Function**: it
  gathers that event's inline GDScript (RawCode) actions into a new reusable EventFunction
  (auto-exposed as an ACE under Functions) and replaces them with a call.
- **Visual data editor** - Array / Dictionary variable defaults get an **Edit items…** button
  in the Variable dialog: a one-item-per-line editor instead of typing a literal like
  `[1, 2, 3]` by hand. Round-trips losslessly through the literal.
- **Conditional breakpoints** - a row's More menu gains **Set Breakpoint Condition…**: it
  stores a GDScript boolean expression and the compiler emits `if <cond>: breakpoint` instead
  of a bare breakpoint, so you pause only on the frame that matters (e.g. `health <= 0`)
  rather than every pass; blank clears the guard. Builds on the existing F9 breakpoints, the
  Tools-menu Debug Breakpoints toggle and editable Live Values.

### New ACE vocabulary - UI, particles, tilemaps, animation, shaders, input rebinding, joints, 2D raycast, loops
First-class events for the biggest gaps from the capability audit (roadmap Phases 0/1/2/4/5):
- **UI & menus** (`ui_aces`) - Button **On Pressed** / **On Toggled** triggers (real signal
  connections via new `trigger_resolver` arms), focus navigation (grab / next / previous /
  neighbor), and Range / LineEdit / BaseButton get-set.
- **2D physics queries** - `RayCast2D` + host-agnostic `Node2D` world raycasts
  (`intersect_ray`), mirroring the existing 3D set.
- **Particles** (`particle_aces`) - emit / restart / one-shot / amount + **On Particles
  Finished**, for GPU and CPU particles.
- **AnimationTree** - travel-to-state, set/get tree params, is-in-state, current state.
- **Tilemaps** (`tilemap_aces`) - TileMapLayer set / erase / clear / get-cell + local↔map
  coordinate conversion.
- **Shader materials** - assign / swap / clear a material + read a uniform (completes the
  one-uniform `SetShaderParameter`).
- **Runtime input remapping** - bind / clear / query InputMap action events (settings-menu
  rebinding), built on the captured `event` from On Input.
- **Physics joints** (`physics_aces`) - wire Joint2D/3D bodies, tune pin/spring params,
  break at runtime.
- **Loop control** (`loop_aces`) - Break / Continue / Current Item.
- **Else / Else-If authoring** - a row right-click menu sets the chaining the compiler
  already emitted; **Pick-Filter conditions** now compile (iterator-scoped, AND/OR) instead
  of warning.
- **Collision helpers** (`collision_aces`) - 24 ACEs for body/area physics queries:
  **CharacterBody2D** on-wall / on-ceiling, wall / floor normals, and slide info (Get Slide
  Collision Count, Get Last Slide Collider, Get Last Slide Normal), with **CharacterBody3D**
  carrying the on-wall / on-ceiling / wall / floor-normal subset; **Area2D** overlaps (Overlaps
  Body, Overlaps Area, Has Overlapping Bodies / Areas, Get Overlapping Bodies / Areas), with
  **Area3D** Has / Get Overlapping Bodies; **CollisionObject2D** layer/mask bits (Set Collision
  Layer Bit, Set Collision Mask Bit, Is On Collision Layer); and **CollisionShape2D** Enable /
  Disable Shape (via `set_deferred`).

All compile to plain typed GDScript (parity contract); covered by `phase0_aces_test` and
`new_modules_test`. Bare loop keywords are excluded from the reverse-lifter so generated
`break`/`continue` stay verbatim. (Deferred: a Menu/HUD behavior pack + UI starter demo,
2D point/shape overlap queries, and the Phase-3 dialogue/transition packs.)

## [0.8.0] - 2026-06-20 - "The Team & Scale Update"

### Team & navigation - merge driver, Find References, includes manager + provenance
- **Semantic 3-way git merge driver** (`tools/sheet_merge`) - merges sheets at the row level
  keyed on the now-stable UIDs: two people editing different rows merge cleanly; a genuine
  same-row edit keeps both versions (fenced by ⚠ comment rows) for resolution in the editor,
  instead of an unmergeable `.tres`. Opt-in per clone - see `docs/VERSION-CONTROL.md`.
- **Symbol-aware Find References + Go-to-Definition** - whole-symbol matching (`\bname\b`)
  across params/code/pick/comment/group surfaces, so `speed` finds the variable but never
  `move_speed`; resolves a symbol to its definition; backs a rename **preview** (count what
  it'll touch first).
- **Includes, made usable** - **Edit ▸ Extract Selection to Include…** moves selected events
  into a new library sheet and wires the include (copy-paste → modularization in one step);
  a summarize core powers an include-manager preview (events/functions/variables each
  contributes), with a cycle guard; and a provenance core resolves a sheet's includes into
  their rows for read-only display.
- **AI-assisted event generation** is enabled through the MCP server today (ground via
  `list_aces`/`read_sheet` → the model writes GDScript → `apply_snippet` lifts it losslessly
  into editable events, with `dry_run` preview) - see `docs/MCP-SERVER.md`.
- **In-editor AI generation + a live MCP on/off switch** - **Edit ▸ Generate from Description
  (AI)…** turns plain English into editable event rows in the editor (opt-in via an
  `eventsheets/ai/api_key` setting), and **View ▸ MCP Server (AI tools)** is a checkbox that
  activates/deactivates the MCP server at will: off → connected AI clients see no tools and
  can't read or change your sheets, live, without reconnecting.

### HTN Agent behavior - utility-driven planning (port of the custom C3 DHTN addons)
- A new **HTN Agent** pack: a world-state blackboard + a task network of primitive and
  compound tasks, where each compound's methods carry preconditions, an ordered subtask list
  and a utility score. **Request Plan** decomposes the root task, picking the highest-utility
  *applicable* method at each compound (with backtracking), and yields a plan of primitive
  tasks the sheet runs via **Current Task** + **Mark Complete / Mark Failed**. Triggers: On
  Task Started / On Plan Complete / On Plan Failed. The C3 manager+agent split is collapsed
  into one per-object behavior (the natural event-sheet fit); squad/slot coordination and
  decaying alert stimuli are an honest scope cut. **26 behavior packs total.**

### Theme Editor - "Quick Style" (re-skin without learning every token)
- The visual theme editor gains a **Quick Style** section at the top: pick a **base**,
  **accent** and **text** colour, click **Generate Theme**, and the whole sheet palette is
  regenerated via `EventSheetGodotTheme.apply` (the same derivation the editor-theme adapter
  uses) - plus **Reset To Default**. The full reflective per-token form (every colour/spacing/
  toggle) still sits below for fine-tuning, and now rebuilds to reflect a just-generated palette.

### Platformer-Shooter showcase
- A new playable demo (`demo/showcase/platformer_shooter.tscn`) combining the **Platformer**
  and **Weapon Kit** packs: run + double-jump on a floor, hold to fire (fire-rate + ammo +
  auto-reload), shots destroy targets drifting in. Verified by `showcase_examples_test`.

### Editor UX - naming a new group is immediate
- **Add Group** now drops you straight into renaming the group's title inline (the standard
  "new folder → type its name" flow), instead of leaving a generic "Group" you had to know to
  double-click. The inline title/description edit was already there; this just makes it obvious.

### Version control - byte-stable pack/showcase regeneration (no more diff churn)
- Row UIDs (`event_uid`/`group_uid`) used to be **minted at random** every time a resource
  was created, so rebuilding a single behavior pack rewrote the `.tres` of **every** pack -
  exploding `git diff` with meaningless UID churn, and meaning the "stable" per-row UIDs were
  never actually stable. The pack/showcase builders now stamp **deterministic UIDs** derived
  from each row's structural path, so regenerating unchanged content is **byte-for-byte
  identical** (verified: two consecutive builds produce zero new diff). Each row also keeps a
  genuinely stable identity for diff/blame. Scoped to the builders - hand-authored sheets keep
  the persistent UID assigned when the row was first created.
- (Already in place, for reference: `.gitattributes` enforces LF and wires a readable
  `diff=eventsheet` textconv so `git diff` renders `.tres` sheets as legible event text via
  `tools/sheet_diff.sh` + `EventSheetTextDump`.)

### Behavior packs - C3-addon parity (Platformer juice, Spring colors, new Weapon Kit)
- **Platformer** rebuilt with the feel features from the author's C3 "Physics Platformer":
  **coyote time, jump buffering, variable jump height** (Jump Released), **multi/double jump**
  (max_jumps + Reset Jumps), **wall slide + wall jump**, **acceleration/deceleration** and
  **terminal velocity** - all kinematic on a CharacterBody2D. New conditions (Is Moving /
  Jumping / Falling / Wall Sliding / Can Jump), triggers (On Landed / Double Jumped / Wall
  Jumped) and expressions (Jumps Remaining / Air Time / Facing Direction). The original
  Jump / Set Move Speed / On Jumped ACEs keep their ids (compatibility covenant).
- **Spring** gains the missing pieces of the C3 "Simple Spring": **colour springs**
  (Spring Color / Set Color Value / Color Value - perfect for hit flashes), **spring
  lifecycle** (Pause / Resume / Remove / Reset All), and an **On Spring Started** trigger.
  (Mesh deformation stays an honest skip - that's shader/skeleton territory in Godot.)
- **Weapon Kit** - a new pack ported from the C3 "WeaponKit": ammo + reserve pools,
  fire-rate cooldown, **single / auto / burst** fire modes, **timed + instant reload** with
  auto-reload, and a full HUD surface (Ammo % / Reload Progress / Cooldown Progress,
  Can Fire / Has Ammo / Is Full / Is Reloading, On Fire / Empty / Reload Started / Reload
  Complete). It owns no projectile - Fire manages state and triggers On Fire, so the sheet
  spawns the bullet however it likes. **25 behavior packs total.**

### Richer variable helpers - Array, Dictionary, Vector & String manipulation
- **16 more Array ops** so list work rarely needs a raw block: First/Last item, Index Of,
  Count Of, Reverse, Push To Front, Pop First/Last, Append Array, Slice, Join To Text,
  Array Max/Min, Copy, Resize, Fill.
- **Dictionary**: Copy Dictionary, Has Value (alongside the existing Set/Get/Has Key, Merge,
  Keys/Values, Size).
- **New Vector category**: Make Vector2/3, Length, Normalized, Distance Between, Direction
  To, Angle, Dot Product, Rotated, Lerp, Clamp Length.
- **New String category**: Text Contains / Begins With / Ends With, Split Text, Text→Int,
  Text→Float, Pad Number.
- Every one is a direct GDScript one-liner (parity-safe), so the row doubles as a GDScript
  lesson - a beginner learns `.front()`, `.distance_to()`, `.split()` by using them.

### Behavior-declared autocomplete for string params (Construct-style editable combo)
- A behavior/addon can mark a string parameter for **autocomplete** purely from its own
  code: `## @ace_param_autocomplete(anim "idle", "run", "jump")`. In the params dialog that
  param becomes an **editable combo** - type any value, or open the ▾ list (Down-arrow also
  opens it) and **filter/pick** a suggestion. Unlike `@ace_param_options` (a fixed dropdown),
  free text is always allowed. Toggled entirely by whether the annotation is present.
- Plumbed end-to-end: annotation → semantic analyzer → generator → adapter → `ACEParam`,
  with `make_param(..., autocomplete)` available to builtin/Helper ACEs too.

### Helper ACEs - a structured escape hatch for hard-to-translate GDScript
- A new **Helpers** vocabulary (24 ACEs) for the GDScript a user would otherwise drop to a
  raw block for, so more logic stays as editable rows that still compile to the exact
  one-line GDScript you'd hand-write: **Set/Get Property**, **Call Method** (action +
  value), **Get Node**, **Run GDScript** / **Evaluate GDScript** / **Evaluate Expression**
  (a raw statement/expression as a real ACE), **Inline If (ternary)**, **Toggle Boolean**,
  **Set Local Variable**, **Is Valid** / **Is Null**, **Connect/Disconnect Signal**, and the
  math/string idioms not already covered (**Abs/Min/Max/Round/Sign/Move Toward/Wrap/Remap/
  Format String**).
- The Helper templates are deliberately generic, so they're registered **last** and
  **excluded from the reverse-lifter** - they never shadow a specific ACE on import or
  swallow a line that should stay a verbatim block.
- **Escape-hatch provenance, working together:** raw GDScript blocks now carry an optional
  `note` (a human label, shown on hover) and an importer-set `lift_note` - when a line
  couldn't lift into a structured ACE, hovering the block says *why* ("no matching ACE
  template"), turning an opaque wall of code into an actionable triage list. Both are
  non-emitted (no codegen / round-trip impact) and complement the verbatim-codegen tooltip.

### Health pack
- Renamed **Temporary Health → Health Pools** throughout the Health behavior addon (ACE
  names and the generated API: `add_health_pool`, `on_health_pool_*`, `clear_all_health_pools`).

### New behavior packs + C3-addon parity (24 packs total)
- **Line of Sight 3D** - the 3D twin of the LoS pack (Node3D host, `PhysicsRayQueryParameters3D`
  raycasts, cone-of-view from the host's -Z forward).
- **Health** - a faithful port of the Simple Health C3 addon: max/current HP, damage with a
  resistance/absorption multiplier, **named temporary-health pools** (shields/armour that
  intercept damage in priority order and decay over time), heal/revive/invulnerability, and
  `On Damaged/Death/Healed/Revived/Health Changed` + temp-pool triggers.
- **Virtual Cursor** - a port of the custom C3 Virtual Cursor addon (axis/mouse-driven cursor
  with homing, solids, bounce, constraints) that can **drive the Drag & Drop pack** for
  gamepad/touch dragging.
- **Drag & Drop, rewritten event-driven** - replaces the old mouse-only poller with the C3
  surface (Start Drag / Set Drag Point / Drop, follow-speed lag, direction lock, break-distance
  auto-drop, measured throw velocity, snap/magnet targets) so any input source can drive it.
- All packs stay faithfulness-gated (`audit_addons` drifted=0) and covered by
  `sample_behavior_pack_test` (load-as-behavior, no-drift golden, instantiation).

### 3D, GDScript-escape & install/uninstall improvements
- **3D spatial-query ACEs** - a RayCast3D node set (Is Colliding / Collider / Hit Point /
  Hit Normal / Force Update) plus host-agnostic Node3D **world raycasts** (single-line direct
  space-state queries), closing the biggest functional 3D gap.
- **3D starter templates** - "First-Person Controller (3D)" and "Third-Person Mover (3D)" in
  the New Sheet menu (CharacterBody3D, `Input.get_vector` planar movement + gravity).
- **Raw-block codegen tooltip** - hovering a GDScript block now advertises that it compiles
  verbatim into the generated script (the escape hatch is transparent, not a black box).
- **Clean removal made provable** - [docs/UNINSTALL.md](docs/UNINSTALL.md) (keep/remove table),
  a `clean_removal_test` that parses every generated/pack script with no plugin classes on the
  path and forbids any `EventForge*`/`EventSheet*` reference, and a `plugin_teardown_test`
  asserting every `_enter_tree` `add_*` has a paired `_exit_tree` `remove_*`.

### Showcases refreshed - three playable demos for complex tasks
- Replaced the single version-pinned showcase (`showcase_v070.*`) with **three** playable
  demos in `demo/showcase/`, each authored as event sheets and compiled to plain GDScript:
  - **`showcase_carousel.*` - Carousel of Juice (flagship):** a rainbow ring driven by a
	reused `juice_tile()` function, a runtime-toggleable group, an if/elif/else keypress
	chain, and four behaviors (Spring/Tween/Sine/Flash). Streams to Live Values.
  - **`starfall.*` (+ `star.tscn`) - arcade game:** an enum+match state machine
	(PLAYING/GAME_OVER), a group pick-filter that scores & culls falling stars, an Every-2s
	spawner instancing a sub-scene, and if/elif input branches.
  - **`quest_fsm.*` - software-logic FSM:** a self-driving quest engine using a Dictionary
	inventory + Array quest log, signals (`item_collected`/`quest_advanced`), a reused
	`grant_item()` function, and match dispatch.
- **Stable, un-versioned names** end the per-release churn: only the flagship matches the
  `showcase_*` discovery prefix (so `EventForgePlugin._find_showcase_scene` returns it
  deterministically - no plugin edit), and the two secondaries can never go stale via the
  version-pin smell. Future refreshes regenerate in place via the new single builder,
  `tools/build_examples.gd` (replaces `tools/build_showcase.gd`).
- New `tests/showcase_examples_test.gd` guards all three: each compiles, parses, contains
  its advertised power-feature constructs, and instantiates.

### Adoption: friendlier for newcomers, faster for power users
- **Simple Mode (View menu)** - progressive disclosure for artist-first / first-time users:
  hides the advanced/code-leaning right-click entries (GDScript blocks, sub-conditions, pick
  filters, match, signals/enums) so the everyday authoring verbs stand alone. Persists
  per-project; Expert mode (default) is unchanged.
- **Command Palette (Ctrl+P)** - keyboard-first access to every dock action with a fuzzy
  (prefix › substring › subsequence) filter.
- **Export Generated GDScript… (Sheet menu)** - writes the sheet's standalone, plugin-free
  GDScript to a file you choose: concrete proof you can leave the addon with your code.
- **"Did you mean …?" quick-fix** - an unknown identifier in an expression field that's one
  or two edits from a name the sheet knows offers a one-click swap (alongside the existing
  create-variable fix).
- **Less jargon in the UI** - the C3-internal term "ACE" no longer leaks into the core
  authoring loop ("Add Action / Condition" picker, "Parameters" dialog, "Custom Actions…",
  "Edit Note…", "Expose as a reusable action"); the beginner empty-state drops "host accessor"
  wording.

### Godot 4.7 support
- **Verified on Godot 4.7 stable** - the full headless suite (1869 assertions) and an
  editor smoke run are green on 4.7. Fixed the cases 4.7's stricter `set_script` typing and
  detached-Control theme access exposed (dialog init now also runs from `setup()`, not only
  `_ready()`, so headless paths initialize correctly).
- **Fixed a live-values crash** - the dock called `ensure_window()` but the panel defined
  `_ensurewindow()`; opening Live Values would error. Names now match.

### 4.7 "Modern" theme alignment
- The editor-theme adapter's color math is extracted into a pure `EventSheetGodotTheme.apply()`
  so the sheet's neutral grayscale chrome (4.6+ "Modern" default), light themes, and custom
  accents are now preview-able in the render harness and covered by regression tests.

### Less clutter when getting started
- **Calmer empty sheet** - the dense one-line wall of shortcuts is replaced with a clear
  heading, one call to action, and a single muted tip. It now also shows when the sheet holds
  only the "+ Add event…" footer (previously the footer suppressed it).
- **"Add-Event Rows" toggle** in the View menu hides the trailing "+ Add event…" affordances.
- **"System" object labels are dimmed** - kept (C3 always shows the object) but de-emphasized
  so rows read as the action, not a column of identical "System" labels.
- **"+ Add action" is revealed on hover/selection** instead of repeating under every event
  (events with no actions yet keep it visible for discoverability).

### Context menu, truncated
- **The row right-click menu is rebuilt per click for the row you clicked** - it
  used to be one flat ~30-item list shown for everything (an event right-click
  still offered "Edit Group Description", "Add Enum Below", etc.). Now an event
  shows ~9 items, a group shows group items, a comment shows comment items.
- **The "Add … Below" family folds into an `Insert Below ▸` submenu**, and the
  advanced/rare authoring (sub-condition, pick filter, match, find usages, open
  in split, snippets) folds into a `More ▸` submenu.
- **Bulk-selection items only appear when more than one row is selected** -
  otherwise Copy/Paste/Duplicate/Disable act on the clicked row directly.
- **Insert Snippet moved to the empty-canvas menu** (you're adding to the sheet,
  not acting on a row).

### Godot-native polish
- **The GDScript panel reads like the script editor** - it adopts the editor's
  code font + size, the built-in minimap, current-line highlight and tab
  rendering, so the honest output looks like a Godot script, not a foreign box.
  It re-skins live when you switch editor themes.
- **The default theme is labeled "Match Editor"** - it always derived from your
  editor's base/accent colors; now the picker says so, and it re-derives the
  moment you change your editor theme.
- **Key toolbar buttons carry editor icons** (Save, Run/Play, Add, Script) - the
  same glyphs the rest of the editor uses.
- (Most of the obvious native gaps were already closed: editor-theme colors,
  font + size, row-cell editor icons, Ctrl+wheel zoom, and node drag from the
  Scene dock into expression fields all shipped earlier.)

### Bug-review fixes (silent bugs)
- **Selecting a multi-line block by clicking any line but the first showed no
  highlight** - single-click selects the clicked line's span (usually not the
  block head), but the merged-cell renderer only drew selection at the head. The
  block grouping is now a tested helper (`resolve_block_groups`) and selection
  draws once at the union whichever member line is clicked.
- **A leftover Range/Clamp/Drawer value errored about an invisible field** - after
  switching a variable from numeric to String/bool (which hides those fields), the
  values persisted and the confirm guardrail rejected them with a message about a
  field the user could no longer see. Numeric-only attributes are now inert when
  the type isn't numeric.

### Tier-1 authoring speed: value memory + add-another chaining
- **Apply & Add Another** on the params dialog (append modes) - apply a condition
  or action and the picker reopens for the next one, so building a three-condition
  event no longer means re-summoning the picker each time.
- **Per-ACE value memory** - re-adding an ACE prefills the values you used last
  time (session memory, keyed by ace id) instead of the bare descriptor default.
  The numbers you type repeatedly stop being re-typed.
- (Apply-with-defaults was held back: auto-applying from the picker would hide the
  remembered values and remove the chance to set params - it fights both features
  above.)

### Field-test round 2: the replace flow, fixed for real
- **Shadowed variables are caught at both ends** - naming a sheet variable after
  a host member (`velocity` on a CharacterBody2D sheet…) breaks the generated
  script at load and blinds expression lint. The variable dialog now refuses the
  name with a suggestion, and the Project Doctor flags pre-existing ones at the
  error tier, pointing at Rename Everywhere… (behavior/autoload sheets scope to
  Node - their host members live safely behind `host.`).
- **Preselect now actually shows** - the entry WAS being selected, but inside a
  collapsed picker group, which reads as nothing happening. Preselect expands
  the ancestor chain, runs after the popup settles (carried via the picker
  context instead of racing the open sequence), and scrolls to the entry.
- **OK can never be locked out again** - when a sheet variable shadows a host
  member (e.g. `velocity` on a CharacterBody2D sheet), the lint scratch breaks
  and EVERY expression "failed", so the params dialog just closed and reopened
  without applying. The guardrail now checks the lint baseline first: a broken
  context skips the expression gate instead of locking the user out.

### Field-test round 1: author tooling
- **The Theme Editor is actually editable now** - both panes carry real minimum
  sizes (the token controls used to collapse to an invisible sliver, leaving
  only the preview: "it's just highlighting things"), and the editor-level
  tokens (hover, selection, lanes) join the form, so emphasis strength is
  user-tunable per theme.
- **Sheet functions get a dialog** (Add ▾ → Function…) - the first authoring UI
  for them: parameters expand row by row with auto-unique suggested names,
  function/param names auto-snake_case, duplicates are refused with the reason
  named, and the expose-as-ACE fields stay behind their checkbox. Built for the
  first-time developer: hard to make an invalid function.

### Field-test round 1: dialog UX
- **Double-clicking a condition opens the replace picker, preselected on it** -
  pick another to swap it out, or re-pick the same one to edit its params
  (existing values prefill either way). The "I expect to replace it" reflex.
- **Edit Variable stopped throwing everything at once** - the Inspector
  attributes live behind a disclosure (collapsed for new variables, auto-expanded
  when the variable already uses any); combo options appear only for Strings;
  range/clamp/drawer only for numerics; multiline only for Strings.
- **Sheet enums fill combos in one click** - a "From enum" menu on the combo
  field lists the sheet's enums and fills the options with member names
  (explicit values stripped).
- **Lone Vector2/Vector3 params split into per-axis fields** - positions edit as
  x / y (/ z), each axis still a full GDScript expression, recomposed on apply.

### Field-test round 1: the renderer pass
- **A multi-line GDScript action is ONE cell now** - block lines merge into a
  single vertically-resized code cell instead of stacked per-line cells (the
  per-line spans stay the layout/hit-test truth, so selection, drag and delete
  behave exactly as before).
- **Code cells look like code** - in-flow GDScript gets a cool tint and a left
  code stripe, so "this action is just GDScript" reads at a glance.
- **Comments in the action lane look like action cells** - they carry the same
  cell chrome as their siblings (comment text color kept), merge into one cell,
  and keep growing vertically as lines are added.
- **Hover and selection are easier on the eyes** - whole-row hover (comments
  especially) is a faint tint with no outline; whole-row selection is tempered
  for single-cell rows; span hover is softer and thinner. Selection stays
  unmistakable via the outline and accent bar.

### Field-test round 1: quick fixes
- **Welcome window actually fits now** - rebuilt as a self-sizing dialog (the
  fixed-size window clipped buttons and text at the edges twice); every label
  wraps, the checkbox text is short, and the tooltip carries the detail.
- **Theme switches are no longer undo steps** - undo history is for sheet
  content (ACEs, variables), never presentation. Switching themes still marks
  the sheet dirty (the style is saved with it).
- **The Construct3-stacked theme is removed** - it wasn't a faithful C3 look
  and earned no keep.
- **Toggles explain themselves on hover** - the GDScript toggle, Split/Detach/
  Link, Debug Breakpoints and Live Values all carry tooltips; param dialogs get
  hover descriptions on every label and field.
- **Param dialogs stopped overflowing** - fields fit the dialog width (no more
  horizontal scrollbar under long enum defaults); dropdowns clip long entries.

### Toolbar redesign + welcome fixes
- **The workspace toolbar is grouped and never clips**: Sheet ▾ (file lifecycle +
  identity), Add ▾, Edit ▾, View ▾ (panels, multi-view, zoom, theming) and the
  existing Tools ▾ replace ~28 loose buttons; the C3 reflexes (Add Event /
  Condition / Action), Save, Run Scene, the GDScript toggle, the theme picker and
  Quick add stay one click. The bar is a flow container now - when the panel is
  narrow it wraps to a second row instead of clipping off-screen.
- **Welcome window fixed and reopenable**: content sits in real margins (the
  first cut jammed text against the window edges), the Godot-native checkbox
  reflects the current setting on every open, and **Tools → Welcome…** reopens
  it any time (it previously appeared exactly once per project, with no way to
  see it again).

## [0.7.0] - 2026-06-12 - “The Native Workflow Update”

**EventSheets meets you where you work.** Three arcs in one release: the tedium
killers (rename everywhere, snippets, bulk ops, session restore, asset drops,
one-click attach and run), the Godot-native entry points (right-click a node →
Attach Event Sheet, the Inspector's Edit button, discoverable settings,
rebindable shortcuts, go-to-sheet-row from the script editor), and a GDScript
bridge that explains itself (recursive if/elif/else reverse-lift + the Lift
Report). Showcase: `demo/showcase/showcase_v070.tscn` - press ui_accept /
ui_cancel for the interactive if/elif chain.

### Review + sweep (pre-release)
- A seven-angle code review of the whole range confirmed one bug and four
  cleanups, all fixed: **Run Scene now targets the source `.gd` for
  GDScript-backed sheets** (pairing-rule resolution invented a `_generated.gd`
  for them); the doctor's scene-attachment check reads scene texts once again
  (the shared-lookup refactor had made it O(sheets × scenes)); shortcut
  bindings are parse-memoized per keystroke; the Inspector pairing check is
  memoized by script mtime; the welcome panel discovers the newest showcase
  instead of hardcoding the versioned filename.
- Sweep catches: the export-integrity pass no longer compiles template
  blueprints, and Save/Save As persists the session immediately.

### GDScript coverage: branching lifts, and the boundary explains itself
- **if/elif/else reverse-lift** - opening a `.gd` as a sheet now lifts branching
  into real structure: `if` blocks become conditioned events, adjacent
  `elif`/`else:` become chained else-rows, and *nested* branches become
  sub-events, recursively. Anything unrepresentable falls back to the old
  in-flow GDScript behavior, and the byte-identical recompile still gates every
  lift (lossless, as ever).
- **The Lift Report** (Tools → Lift Report…, plus the open-status summary) -
  after a `.gd` opens, every block explains itself: what lifted into events,
  and why each remaining block stayed code with the closest ACE named ("uses
  await - the Wait action is the structured equivalent"). For C3 users learning
  Godot the boundary becomes the curriculum; for Godot devs it's trust through
  transparency.

### Godot-native workflow (3/3): the first-run hook
- **Welcome panel** on first enable (per project, stored in editor metadata -
  nothing committed, never shows headless): open the playable showcase, jump to
  the workspace starters, and one checkbox - *"I'm Godot-native"* - that opens
  the generated-GDScript panel beside every sheet from then on
  (`eventsheets/editor/open_code_panel_by_default`), so the first thing a
  skeptical Godot dev sees is the honest output.
- Asset Library submission kit deliberately deferred until v1.0.
- Drag-a-sheet-onto-a-node explored and dropped: the Scene dock's drop surface
  isn't reachable from plugins - the Scene dock's "Attach Event Sheet" context
  entry covers the intent.

### Godot-native workflow (2/3): debug, docs and shortcuts like Godot
- **Go to Sheet Row** (script-editor context menu on generated scripts): carries
  the caret line through the compiler's source map into the sheet - the GDScript
  panel opens and the emitting row is selected. Errors and stack traces land on
  rows, not on generated code.
- **Rebindable shortcuts** - every authoring/editing key reads its binding from
  `eventsheets/editor/shortcuts/*` in Project Settings ("Ctrl+D", "Q",
  "Ctrl+Shift+S"); matching is exact on modifiers so chords never shadow plain
  forms. Structural keys (Tab nesting, Delete, Enter/F2, Escape) stay fixed -
  grammar, not preference. (The Editor-Settings shortcut dialog isn't exposed to
  GDScript plugins; this is the rebindable-the-Godot-way alternative.)
- **View in Godot Docs** - native-node ACEs link to the engine's built-in class
  reference from the params dialog: the vocabulary IS Godot, one click away.

### Godot-native workflow (1/3): entry points + discoverable settings
- **Right-click a node → Attach Event Sheet** (Scene dock): creates a sheet whose
  host class matches the node, saves it beside the scene (suffix, never
  overwrite), compiles and attaches the generated script, and lands you in the
  sheet - the "Attach Script" reflex, for sheets.
- **Open as Event Sheet** on FileSystem and script-editor context menus (sheet
  `.tres` files and any `.gd` - GDScript-backed sheets open scripts losslessly);
  sheets now carry a **distinct FileSystem icon** instead of reading as generic
  resources.
- **Inspector "Edit Event Sheet" button** on any node whose attached script is
  sheet-generated (paired via the script's `# Source:` header, pack siblings via
  the pairing rule) - one click from where Godot devs already live.
- **Every `eventsheets/*` setting is now registered in Project Settings** with
  type hints and ranges - discoverable and documented the Godot way, value-neutral
  (defaults match the in-code fallbacks; unchanged values never touch
  project.godot).

### Tedium reduction (Tier 3): the loop closers - attach + run
- **Attach to Selected Node** (Tools) - one click compiles the open behavior sheet
  and parents it under the node selected in the Scene dock (owner set, scene
  marked unsaved). Host-class mismatches warn but attach - the in-scene
  configuration warning already covers it. The save→find scene→add child→attach
  loop the Doctor used to nag about is now the fix-it button.
- **Run Scene** (toolbar) - saves the sheet (compile-on-save keeps the script
  fresh), finds the scene(s) attaching it via the Doctor's reverse lookup, and
  plays: one scene runs immediately, several offer a pick menu, none explains
  what to wire. Sheet → playing game in one click; behaviors are routed to the
  Test Bench.

### Tedium reduction (Tier 3): session restore + asset drops with intent
- **Session restore** - the editor reopens last session's tabs (and re-activates
  the one you were on) on startup; `eventsheets/editor/restore_session` (default
  on) gates it, deleted sheets are skipped silently. Every launch stops starting
  from zero.
- **Asset drops with intent** - drop a `.tscn` from the FileSystem dock onto an
  event row and it becomes a pre-filled **Spawn Scene At** action; drop an
  `.ogg/.wav/.mp3` and it's **Play Sound** - undoable, templates baked exactly
  like a picker apply. The C3 drag-into-layout reflex, grafted onto events
  (empty-space drops explain themselves instead of silently bouncing).

### Tedium reduction (Tier 2): row snippets + bulk selection ops
- **Row snippets** - Save Selection as Snippet… files the selection in
  `res://eventsheet_snippets/` using the SAME text format Copy puts on the
  clipboard (one serializer); Insert Snippet… pastes any library entry through
  the normal paste path (fresh uids, missing variables created). Committed
  files = team-shared patterns, exactly like templates and packs.
- **Bulk selection ops** on the row context menu: Disable/Enable Selection
  (uniform, never a mixed toggle), Duplicate Selection (copies land under their
  sources, uids re-baked), Group Selection into New Group (same-parent
  selections only - cross-depth reparenting is refused, not guessed). Each is
  one undo step.

### Tedium reduction (Tier 2): True Rename + create-variable quick-fix
- **Rename Everywhere…** on variable rows: a word-boundary rename across every
  model surface (params, raw code, pick filters, attributes, comments - prose
  stays honest) in the open sheet *and* every sheet that includes it (saved
  directly, named in the status). Baked codegen templates are never touched -
  a variable named `value` can't rewrite a `{value}` placeholder. Functions
  rename through the same core (`EventSheetRefactor`).
- **Create-variable quick-fix**: an undeclared identifier in an expression field
  grows a one-click **+ var** button - declares it as a float (the C3 "number"
  default) and re-lints, instead of cancel → Add Variable → retype.

## [0.6.2] - 2026-06-12

**The project-usability release** - the whole accepted automation arc: the editor now
keeps generated scripts, project health, documentation and history current *by
itself*. Showcase note: these headliners are workflow tooling, so the playable
`demo/showcase/` from v0.6.0 remains current; this release's living demonstrations
are in the repo itself - the committed [EVENTSHEETS-VOCABULARY.md](EVENTSHEETS-VOCABULARY.md),
the Project Doctor gate in CI, and the sheet-diff textconv driver in CONTRIBUTING.

### Project-usability slice 4: sheet backups + project-local templates
- **Sheet backups** - every save of an existing sheet first rings the file's
  pre-save bytes into `user://eventsheet_backups/` (newest 10 kept;
  `eventsheets/editor/backup_count`, 0 disables). Tools → Sheet Backups… restores
  a backup INTO the editor as an unsaved change - review, then Save to keep; a
  restore never silently rewrites a file. Git-grade safety for projects that
  don't have git discipline yet.
- **Project-local templates** - drop a sheet `.tres` into
  `res://eventsheet_templates/` (or `eventsheets/project/templates_dir`) and it
  joins the New… menu under "Project templates"; Tools → Save as Template writes
  the current sheet in (suffixing, never overwriting). Adopting a template is a
  deep, path-less copy - edits can't leak back into the blueprint. Templates are
  skipped by the Project Doctor and the vocabulary doc (blueprints, not live code).

### Project-usability slice 3: the project vocabulary doc
- **Vocabulary Doc** - one committed markdown reference answering "what can I say
  in this project?": every sheet's class, properties and published
  triggers/conditions/actions/expressions (straight from the model), plus
  hand-written script packs parsed from their `@ace_*` annotations. Deterministic
  by contract (sorted, no timestamps) so it diffs cleanly in PRs - for teammates
  and AI assistants alike. Generate from the dock (Tools → Vocabulary Doc) or
  `tools/vocabulary_doc.gd`; path configurable via
  `eventsheets/project/vocabulary_doc_path`.
- The Project Doctor gains an opt-in staleness note: once a vocabulary doc exists,
  it's flagged (advisory) whenever the project's published surface drifts from it.
- The pack-README section renderer is now shared (`surface_markdown`) between the
  Export Addon README and the vocabulary doc - one rendering, two documents.

### Project-usability slice 2: the Project Doctor
- **Project Doctor** - one audit for the cross-file drift no single check sees,
  identical from the dock (Tools → Project Doctor…), the headless CLI
  (`godot --headless --path . --script tools/project_doctor.gd`, `-- --strict`
  to fail on warnings) and CI (a new gate fails the build on errors).
  - **errors**: a committed generated script no longer matches what its sheet
	compiles to, or a sheet stopped compiling - the pack-golden byte-identity
	contract, generalized to every sheet in the project.
  - **warnings**: never-compiled sheets, autoload sheets that aren't registered
	(or point at the wrong script).
  - **infos**: private variables nothing references, packs no sheet/scene/autoload
	uses, compiled sheets attached to no scene - advisory, never fails CI.
  The doctor never writes inside `res://`; verification recompiles go to a
  `user://` scratch file.
- First catch on this very repo: `demo/showcase/showcase_v060_generated.gd` was a
  committed orphan (the scene attaches `showcase_v060.gd`) - removed, and the doctor
  exposed the silent bug that kept recreating it: default output resolution always
  invented `<name>_generated.gd`, so the export-integrity pass (and compile-on-save)
  duplicated outputs next to builder-shipped pairs like the showcase and every pack.
  `_resolve_output_path` now refreshes the sheet's EXISTING pair - adopting a sibling
  `<name>.gd` only when its `# Source:` header proves the compiler wrote it for that
  sheet, so a hand-written same-name script is never clobbered.

### Project-usability slice 1: compile-on-save + reviewable sheet diffs
- **Compile-on-save** (default on; `eventsheets/editor/compile_on_save` to disable):
  saving a sheet also writes its `<name>_generated.gd`, so F5 can never play-test a
  stale script - the last manual step between editing and playing is gone. A sheet
  that doesn't compile says so at save time instead of at run time.
- **Reviewable sheet diffs**: `EventSheetTextDump` renders any sheet as stable,
  readable rows; `tools/sheet_to_text.gd` + the shipped git `textconv` driver
  (one-line setup in CONTRIBUTING) make `.tres` PRs show events, conditions and
  actions instead of serialized-resource noise - the team-adoption unblock.

### Community-feedback groundwork
- GitHub issue templates: the bug form asks for versions + a minimal sheet or text
  snippet (the two things that make fixes fast); the feature form asks for the game
  situation and the current workaround, and routes C3 requests through the migration
  guide first. README gains a Feedback section.

### Pack builders: one file per pack
- The 1,968-line `build_sample_behaviors.gd` monolith split into
  `tools/pack_builders/` - one builder file per pack (21) plus a shared `_lib.gd`
  scaffold; the runner is a thin ordered orchestrator. **Faithfulness proven by the
  drift audit: all 21 regenerated packs are byte-identical** to the monolith's
  output (`audited=21 drifted=0`).

### Review fixes for the param-picker slice
- A nine-angle code review of the slice confirmed three bugs, all fixed: the scene
  Browse… dialog is now **one cached EditorFileDialog** parented to the persistent
  params dialog (no per-press accumulation, can't be destroyed mid-pick by a form
  rebuild, cancel-safe); **FileSystem drag-and-drop restored** on scene and audio
  path fields (same converter as expression fields, so they can never disagree);
  **Enter applies the dialog** from the new fields (and audio path, which shared the
  gap). Also: the animation walk dedupes in O(n), dropdown entries are
  metadata-tagged instead of index-guessed, and quoting has a single helper.
- Both deferred cleanups are now in too: path-style fields share one scaffold
  (`_build_path_field_base` - container, drag-drop, Enter, registration), and
  exact-match field hints dispatch through a **hint→factory registry** (the next
  hint is one registration line, not another branch).

### C3 param-type parity completed: scene + animation pickers
- **`scene_path` hint** - Browse… opens the editor's file dialog filtered to scenes;
  the chosen path inserts quoted (Spawn Scene At uses it).
- **`animation_reference` hint** - a dropdown of every animation on every
  AnimationPlayer in the edited scene, with free-text fallback for runtime-only names
  (Play Animation uses it). With these, every C3 ACE parameter type is covered
  outright, mapped to a Godot idiom, or an explicit honest skip (layer pickers).
- Hints are dialog-UX only - templates and ace_ids untouched (covenant).

## [0.6.1] - 2026-06-12

**Maintenance release** - no user-facing feature changes; the v0.6.0 showcase remains
current. Structure, hygiene and review actions only:

### Repo re-review + sweep 13
- **Committed scratch removed**: six one-shot patch scripts had slipped into `tools/`
  when their cleanup steps were skipped by mid-script failures - deleted, and
  `tools/_*.py` is gitignored so the class of mistake is closed.
- **Two orphan `.uid` sidecars** removed (their `.gd` files were deleted in earlier
  eras; the sidecars survived).
- Verified clean: no extraction residue (`_dock._dock`, mangled names) in any
  `dock/` helper; the author-loop statics are dock-free; the legacy
  `EventForgeBuiltinACEs._*` delegates have a real consumer (the input/time test)
  and work.

### Dock decomposition (steps 1–4): four subsystems extracted
- The god-object dock (6,455 lines - the repo review's top finding) shed four
  cohesive subsystems into `editor/dock/`: **project find**
  (`project_find.gd`), the **addon-author loop** (`author_loop.gd` - publish
  surface/README statics + preview window/Test Bench), the **Live Values panel**
  (`live_values_panel.gd`) and the **bookmarks panel** (`bookmarks_panel.gd`).
- The dock keeps thin delegates and forwarding properties, so the entire public/test
  surface (1,279 assertions) passed unchanged - pure structure, zero behavior.

### Repo review actions (post-v0.6.0 hygiene)
- **Module split finished**: the remaining Core vocabulary (triggers, InputMap
  conditions, variables, the native-node action set) moved to
  `registration/modules/core_aces.gd`; `builtin_aces.gd` is now a pure ordered
  registry (~50 lines) with the legacy `_make_*` helpers kept as factory delegates
  for external callers.
- **Dead code removed**: three 8-line "Phase 4" importer stubs whose functionality
  shipped inside `ace_lifter.gd` long ago.
- **Era-stale strings**: the compiler's "Phase 1" TODO comments now say what they
  mean (unknown row types are preserved as comments); `plugin.cfg` carries the
  released version in-repo.
- **Eight early-era docs stamped as historical records** (status reports and
  pre-overhaul design briefs that predate the feature waves).

## [0.6.0] - 2026-06-12

### Bug sweep 12 (pre-release)
- **Runtime-group guards on OR-mode events** joined into the OR list - silently
  disabling the gate (`guard or a or b`); guards now AND-wrap the whole condition
  (`guard and (a or b)`), regression-asserted.
- Find in Project now also searches per-ACE `⊳` notes (parity with Replace All).

### Release showcase
- `demo/showcase/showcase_v060.tscn` - the v0.6.0 features in one playable scene: a
  color-tagged **runtime-toggleable group** pulses the host every 2 seconds
  (**Every X Seconds**) through the **Spring** behavior while **Tween** spins it,
  with **Live Values** streaming (watch `pulses` climb - then double-click and
  rewrite it in the running game). Regenerate with `tools/build_showcase.gd`.

### Power-user trio: nested live values, fuzzy picker, keyboard flow
- **Nested Live Values**: dictionaries and arrays expand into read-only subtrees
  (GDevelop's variables-debugger style - `stats → hp / mp`); scalars stay editable.
- **Fuzzy picker matching**: `stt` finds *Set Time Scale* - subsequence matching joins
  after exact + synonym hits, capped at 12 so it never buries real matches.
- **Keyboard flow**: **Enter in the picker search applies the first match**, and Enter
  in any params-dialog field presses OK - `E → type → Enter → type → Enter` authors an
  event without touching the mouse.

### Editable Live Values - C3's debugger, both directions
- The Live Values window is now an **editable tree**: double-click a value while the
  game runs and the change lands in the running game (typed - `3.5`, `true`,
  `Vector2(1, 2)` all parse; plain words stay strings). Streaming frames update rows
  in place so an in-progress edit is never stomped.
- Debug compiles register a tiny `EngineDebugger` edit-back receiver alongside the
  stream (first streaming sheet wins, noted in the window); **normal compiles carry
  neither direction** - the covenant story is unchanged.

### Save System v2 - strategy in the Inspector, extension through signals
- **Every former opinion is now a property**: save directory, file pattern, section,
  **format** (`config` / `json`), and **encryption** (one key field - encrypted
  ConfigFile or encrypted JSON; the suite verifies no plaintext leaks).
- **Variant-typed core**: Save Value / Load Value persist *anything* (Vector2, Color,
  dictionaries…); Save/Load Number/Text remain as thin conveniences (ace_ids are API
  - fully backward-compatible, asserted).
- **Lifecycle broadcasts**: **Save Game** fires *On Before Save* (every sheet writes
  its own state - the pack never needs to know contributors exist), then On Save
  Written; **Load Game** fires *On After Load*. Plus **optional autosave**
  (interval property, 0 = off).
- **Slot metadata for menus**: Slot Exists, List Slots, Slot Modified Time.
- The compiler gained a **Variant-return sentinel** (`TYPE_MAX` → `-> Variant`,
  lifter-aware) to support the Variant-typed core.

### Advanced C3/GDevelop workflows: runtime groups, project-wide find, Save System
- **Runtime-toggleable groups** (C3's *Set Group Active*, opt-in): right-click a group
  → *Runtime Toggleable* - it compiles a `__group_<name>_active` flag guarding every
  contained event (nested groups inherit the innermost guard), with **Set Group
  Active** / **Is Group Active** ACEs. Default stays zero-cost compile-time
  organization.
- **Find in Project** (Tools menu): search every sheet in the project (same surfaces
  Replace All covers), jump to matches, and **Replace in Project** (open sheet goes
  through undo; touched files are named). **Find Usages** on a variable/group row
  pre-fills it.
- **Save System addon (pack 21)**: slot-based persistence as an autoload sheet -
  Save/Load Number/Text, Has Save Key, Delete Slot, On Save Written; human-readable
  ConfigFile underneath; suite round-trips a real save file.
- Release ritual recorded in CONTRIBUTING: every release refreshes the demo showcase
  to exercise its headline features.

### Audits: UI/UX + compiler + sweep 11
- **Sweep 11 (silent bugs)**: the Test Bench wrote (and once committed!) scratch files
  at the repo root - the bench script now rides next to the scene path and the pattern
  is gitignored; the autoload provider scan would have published **every public method
  of every autoload** (including the plugin's own bridge) into every picker - only
  scripts with real `## @ace_` annotations publish now (a doc-comment *mention* of
  @ace_* doesn't count; regression-asserted).
- **UI/UX audit**: the toolbar had grown past 30 buttons - the six workflow tools
  (Debug Breakpoints, Live Values, Bookmarks, Register Autoload, Publish Preview,
  Test Bench) now live in one **Tools** menu.
- **Compiler audit**: pipeline order re-verified end-to-end; the `on_changed` typo
  warning no longer silently skips sheets with zero functions (the case most likely
  to be a mistake).
- **README milestones truncated** to one row per release (the table had drifted to 26
  rows with shipped entries stranded below "planned").

### The addon-author loop: Publish Preview, auto-READMEs, Test Bench
- **Publish Preview** (toolbar): a live window showing exactly what this sheet
  publishes to other sheets' pickers - triggers, conditions, actions, expressions and
  exported properties - straight from the model, so renaming a function updates the
  surface instantly (no compile-and-reopen loop).
- **Export Addon… now writes a README.md** into the pack: tags, host class, properties
  (with their attribute tooltips/defaults), the full ACE surface, and composition
  dependencies - shared packs are documented by default.
- **Test Bench** (toolbar): one click compiles the behavior, builds a host +
  behavior scene, and runs it - verify a behavior without hand-building a scene
  (pairs with Live Values).

### Event-bus triggers - autoload signals fire events in ANY sheet
- The Event Bus pattern is complete: signals on a **registered autoload** publish as
  project-wide triggers ("On Game Paused - EventBus"), and consumer sheets compile a
  direct by-name connection (`EventBus.game_paused.connect(_on_event_bus_game_paused)`)
  - the non-self connection codegen the pairing spec has anticipated since the
  behaviors era. No node paths, works from every scene.
- Registered autoloads with annotated scripts now **join the provider scan
  automatically** (zero-config, like `eventsheet_addons/`): their triggers/ACEs appear
  in every sheet's picker under the singleton's name.

### Autoload (Singleton) sheets - a new pillar
- **New sheet type: Autoload (Singleton)** - Game State, Event Bus, Save System and
  friends, built as event sheets. Set the type + a global name in the Sheet Type
  dialog, then **Register Autoload** (toolbar) compiles next to the sheet and writes
  the ProjectSettings entry in one click - guarded against missing names, unsaved
  sheets, broken compiles, and **name collisions** (it never overwrites a different
  autoload).
- **Project-wide ACEs**: exposed functions on an autoload sheet publish ACEs that call
  **through the singleton name** (`GameState.add_score(10)`) - no node paths, callable
  from every sheet and from hand-written GDScript alike.
- **Three singleton starters** in the New… menu: **Game State** (score/lives with
  Inspector attributes + On Score Changed), **Event Bus** (project-wide signals,
  documented usage), **Save System** (ConfigFile save/load with a typed return).
- Covered by `tests/singleton_sheets_test.gd` (11 assertions).

### Group color tags + picker favorites (the suggestion list, completed)
- **Group colors** (C3 parity): right-click a group → *Group Color…* - the picked
  color tints the group's accent bar and background (clear returns to theme tokens;
  mirrors per-comment colors). Organize big sheets by color.
- **⭐ Favorites in the picker**: right-click any entry to pin it; favorites sit above
  ★ Recent and **persist in ProjectSettings** - per-project and PR-shareable, so team
  vocabularies travel with the repo (same philosophy as the composition policy).

### Single-param inline editing + picker info pane
- **C3's fastest gesture**: double-click a highlighted *value* inside any condition or
  action and edit just that parameter in a one-field popup - no full dialog. Values map
  back to their params verbatim (equal values disambiguate by occurrence order);
  commits are undoable.
- **Picker info pane**: selecting an entry shows its description **and the exact
  GDScript it generates** at the bottom of the picker - C3's info bar doubled as the
  teach-Godot surface.

### Spring + Tween behavior packs (packs 19 & 20) + sweep 10
- **SpringBehavior** - a cleaned-up Godot port of the author's C3 *simple_spring*
  addon: **named numeric springs** (per-spring stiffness/damping/precision), Spring
  To / Between, impulses, Stop/Configure, **On Spring Reached**, Is Springing, and
  value/velocity/progress expressions - plus host helpers (Spring Host X/Y/Angle/
  **Scale** for one-action squash & stretch). Framerate-independent semi-implicit
  integration (damping = fraction of velocity lost per second); the suite *simulates*
  a spring and asserts convergence + the reached-trigger. Mesh deformation from the
  C3 original is an honest skip (shader territory).
- **TweenBehavior** - Godot Tweens the C3-behavior way: transition + easing as
  Inspector **combos** (all 12 Godot transitions), default duration with range
  attributes, one-action Tween Position/Scale/Rotation/Alpha/any-property,
  Stop Tweens, Is Tweening and **On Tween Finished**.
- Both packs showcase Inspector attributes shipping inside packs (ranges + tooltips
  on their exports). Pack counts refreshed everywhere (20).
- **Sweep 10**: live-value chips positioned with the control width *inside the zoomed
  transform* - drifted at zoom ≠ 100% (now uses the logical canvas width); the early
  architecture-slices tracker is stamped as a historical record (its "scaffolded"
  claims all shipped).

### UX polish: C3 reflexes + the general polish set
- **E / C / A single keys** add an event / condition / action on the selection - the
  C3 keyboard reflexes, joining Q (comment) and G (group).
- **★ Recent in the picker**: your last-used ACEs pin to the top while not searching
  (newest first, deduped, capped at 8).
- **Onboarding watermark**: empty sheets now teach the keys and the C3-phrase search.
- **Inline live values (rung 3)**: streamed frames draw `= value` chips next to
  variable rows in every pane - the window remains for the full list.
- **Drag-handle grip dots** on the hovered row's edge - reordering is discoverable.
- **Bookmarks panel**: a toolbar window listing every Ctrl+B row; activate to jump.
- **Find → Split**: the find bar's "Open in Split" jumps the split pane to the current
  match.
- `AGENTS.md` refreshed (architecture map, standing contracts, docs map, suites/tools).
- Covered by `tests/ux_polish_test.gd` (6 assertions).

### Full audit: features, themes, addons, docs (sweep 9)
- **Themes**: 4 of 10 presets (Construct3-stacked, high-contrast, soft-light, designer
  template) predated the column-header tokens and rendered headers with generic
  defaults - backfilled from each preset's own palette
  (`tools/backfill_theme_headers.gd` kept as a maintenance tool). All 10 presets now
  cover every token.
- **Addons**: all 18 behavior packs audited (`tools/audit_addons.gd`) - every pack's
  `.tres` recompiles **byte-identical** to its shipped `.gd` (zero drift since the
  last regeneration) and every shipped script loads cleanly.
- **Silent bugs (sweep 9)**: pasting the same event twice into one trigger duplicated
  the baked `__spawn_`/`__sfx_` locals in a single function body (same bug class as
  the Every-X-Seconds accumulator, action-template side) - uids now re-bake on
  duplicate/paste; Replace All now also covers per-ACE `⊳` notes.
- **Stale docs corrected**: Live Values and the MCP server are no longer "planned/
  candidate" in `EDITOR-UI-SPEC` (both shipped); bookmarks marked shipped in the
  parity matrix; `GDSCRIPT-PAIRING-SPEC`'s "Planned" section renamed
  **Planned → Delivered** (behavior packs, the C3 coverage program and ACE-level
  lifting all shipped); export-integrity hook noted as shipped.

### Theme Editor preview brought current
- The live preview's sample sheet now exercises the newest renderer vocabulary:
  **BBCode comments**, **per-ACE `⊳` notes**, **Repeat/pick loop rows**, and a
  **disabled row** (strikethrough) - so restyling shows everything the renderer can
  draw. (The token form was already current by construction - it reflects over the
  style resource - and `EVENTSHEET_THEME_TOKEN_SPEC.md` needed no changes: the newer
  vocabulary reuses existing span tokens.)

### Inspector attributes Tier 3 (custom drawers) + bug sweep 8
- **Custom drawers** (the cosmetics tier): pick *Progress bar* in the Variable
  dialog and the Inspector renders the value as a bar (range-aware). Mechanism: the
  compiler bakes an `eventsheet:progress_bar:<min>:<max>` marker into
  `@export_custom`, and one `EditorInspectorPlugin` recognizes it - **without the
  plugin the property degrades to a plain field**, so generated scripts stay plain
  GDScript (the parity covenant, by construction). The marker format is the extension
  point for future drawers (swatch rows, dials).
- **The Inspector-attributes spec is now fully delivered** (Tiers 1–3 + tool buttons).
- **Sweep 8**: the duplicate-hook guard now also covers `_process`/`_ready`/
  `_physics_process` - a raw GDScript block colliding with a generated trigger
  function (or the Live Values standalone `_process`) warns by name instead of
  silently emitting a script that won't compile; combos report ignored drawers too.
- `tests/inspector_attributes_test.gd` grew to 30 assertions.

### Live Values (debugging rung 2) + bug sweep 7
- **Live Values**: toggle it on the toolbar, recompile, run - the sheet's variables
  stream to an editor window every 0.25s while the debugger is attached (C3's debugger
  panel, the Godot way). Debug compiles inject a throttled `EngineDebugger` send into
  `_process` (merging with an existing process trigger, or emitting a standalone one);
  **normal compiles never carry the stream** - same covenant story as breakpoints,
  plain core-Godot API only. Sheets without variables warn instead of emitting.
- New editor pieces: `EventSheetLiveValuesDebugger` (EditorDebuggerPlugin capturing
  `eventsheets:live_values`) registered by the plugin entry point and wired to the
  workspace editor's Live Values window.
- **Sweep 7 (silent bugs)**: duplicating/pasting an **Every X Seconds** condition no
  longer shares one accumulator between the copies (the member uid re-bakes on
  fresh-uid assignment - C3 copies are independent timers); combo variables now
  **warn** when Tier-2 attributes are ignored instead of dropping them silently;
  Show If / Lock Unless targeting an unknown variable warns at compile (typo guard).
- Covered by `tests/live_values_test.gd` (11 assertions).

### Tool buttons + MCP policy awareness
- **Tool buttons** (the classic `[Button]`): give a sheet function a *Tool Button Label*
  and the Inspector shows a clickable button running it
  (`@export_tool_button("Label") var _btn_x: Callable = x`, Godot 4.4+). Non-@tool
  sheets get a compile warning pointing at the Sheet Type toggle - the button needs a
  tool sheet to act in-editor.
- **MCP is now policy-bound**: with `include_sources = tagged:approved`, untagged
  addon ACEs disappear from `list_aces` (Core builtins always list) - an AI assistant
  told "only approved addons" is enforced, not advised. This completes the composition
  spec's four enforcement points.
- Suite: inspector test 24 assertions; composition test 25.

### Inspector attributes Tier 2 + doc refresh + sweep 6
- **Tier 2 attributes** on exported globals: **Clamp to range** (`clampi`/`clampf`
  setters), **On Changed** (setter calls a sheet function - typos warn at compile),
  **Show If** / **Lock Unless** (one aggregated, canonical `_validate_property()` -
  hidden or read-only until a bool variable is true), and static **Read-only**
  (`@export_custom` usage flags). All from the Variable dialog, validated before
  commit; behavior packs inherit everything.
- **Sweep 6**: a GDScript block that also defines `_validate_property`/
  `_get_configuration_warnings` now warns (duplicate functions don't compile - the
  cause is named instead of a mystery parse error); GDScript-backed sheets now say
  they ignore Includes/Uses/Requires instead of silently dropping them.
- **Doc refresh**: implementation-status sections added to the two reference design
  studies (`docs/spec/`) and the three `docs/elements/` notes now explain their
  relationship to the live virtualized renderer (preview templates vs theme tokens).
- `tests/inspector_attributes_test.gd` grew to 20 assertions.

### Addon composition Lane B.2 - sibling-behavior requirements
- Behavior packs can declare **Requires (sibling behaviors)** in the Sheet Type
  dialog: the compiler emits a canonical `_get_configuration_warnings()` that checks
  the parent's children by class (native or script class), so Godot shows its **⚠
  badge** the moment a dependency is missing - the Unity *RequireComponent* idiom,
  warning-only by design (no silent auto-mutation of the user's scene).
- Invalid class names warn and skip; sheets without requirements emit nothing.
- `tests/addon_composition_test.gd` grew to 22 assertions. The composition arc
  (Lane A + policy + B.1 uses-instances + B.2 requirements) is complete.

### Addon composition Lane B (v1) + maintainability & sweep 5
- **Uses (addon classes)** in the Sheet Type dialog: declared classes emit owned helper
  instances (`var __uses_screen_shake := ScreenShake.new()`) so ƒx/blocks call shared
  provider addons without duplication - has-a composition, still plain GDScript.
  Invalid class names warn and skip. (Node-behavior auto-attach is the planned B.2.)
- **Maintainability**: `sheet_compiler.gd` now opens with a full pipeline overview
  (the 7 emission phases, both compile paths, and the four standing contracts) - the
  file is the plugin's heart and now reads like it.
- **Sweep 5**: unsaved sheets no longer produce a blank name in the composition-off
  policy error; match-row branches joined the node-reference audit; the variable
  dialog's attribute prefill (incl. the range field) is now regression-covered.
- `tests/addon_composition_test.gd` grew to 17 assertions; inspector test to 11.

### Addon composition Lane A - meta-packs / jam kits, with project policy
- **Addons can now include other addons** (compile-time bake): the Sheet Type dialog
  gains an *Includes (addon sheets)* field, and the merged result compiles to one
  standalone class - a *Jam Kit* meta-pack is one include away, with zero runtime
  coupling (the compatibility covenant untouched).
- **Project policy knobs** under `eventsheets/addons/*` in ProjectSettings (versioned,
  PR-reviewable, CI-readable): `composition_mode`, `max_include_depth` (the
  anti-addon-hell rail), `collision_policy` (warn/error/silent), `include_sources`
  (`tagged:approved` turns the tag system into enforcement), `deprecated_tag_blocks`,
  `export_bundling`. **Defaults are permissive - jams never meet the policy system.**
- **The invariant** (test-pinned): policy never changes emitted bytes - it only gates.
- **Export Addon… bundles included sheets** so packs travel complete.
- Covered by `tests/addon_composition_test.gd` (12 assertions). Spec status updated.

### Spec: addon composition (addon includes addon)
- `docs/ADDON-COMPOSITION-SPEC.md` - analysis + design for addons building on other
  addons: compile-time inclusion (meta-packs / jam kits - first), has-a runtime
  dependencies with auto-attach (second), inheritance honestly skipped; pros/cons by
  project size and the anti-"addon hell" rationale (bake-at-compile, shallow chains,
  collision warnings, export bundling).

### Inspector attributes, Tier 1 (Unity-style, the Godot way)
- Exported globals can now carry **Tooltip** (emitted as the `##` doc comment Godot
  shows natively on hover), **Group** (`@export_group` Inspector sections), **Range**
  (`@export_range` sliders on int/float) and **Multiline** (`@export_multiline` on
  String) - set from the Variable dialog's new *Inspector* section, validated before
  commit (range demands `min, max, step` on a numeric type).
- Canonical emission order (tooltip → group → annotated export line); combos keep
  their `@export_enum` prefix alongside attributes; behavior-pack properties get all
  of this for free. External `.gd` files with attribute lines round-trip
  byte-identically (raw fallback - the lossless rule).
- Spec: `docs/INSPECTOR-ATTRIBUTES-SPEC.md` (Tier 1 now shipped; Tiers 2–3 still
  planned). Covered by `tests/inspector_attributes_test.gd` (9 assertions).

### Builtin vocabularies fully modularized
- The legacy groups in `builtin_aces.gd` moved into per-module files under
  `registration/modules/` - **System** (time/display/text/comparisons/stateful/spawn/
  shader/date/platform), **Device input**, **3D vocabulary**, **Collections** - joining
  Audio on the documented module contract (`ace_factory.gd`). Each C3-equivalent
  "addon" is now one readable, standalone-shippable file.
- Shared helpers (`COMPARISON_OPERATORS`, InputMap option builders) moved to the
  factory as the canonical home; the registry concatenates modules **in their original
  order**, and every ace_id/template is byte-identical (compatibility covenant - the
  full suite, golden round-trips and lift tests gate the move).

## [0.5.0] - 2026-06-12

### Node picker, large-project edition + bug sweep 4
- The node picker grows the full large-project toolkit: **filter chips**
  (2D/3D/UI/Audio/Physics), **`group:`** and **`script:`** queries, **`scene:`
  cross-scene search** (scans `.tscn` node headers project-wide), **pinned recents**,
  and a **"Used in sheet" audit** listing every `$Ref` the sheet makes - missing nodes
  flag red (broken-reference detection after scene restructures).
- Sweep 4 fixes: the audio preview now stops when the params dialog closes (it kept
  playing); keypad keys capture as their real constants (`KEY_KP_ADD`, not `KEY_KPADD`).
- README refreshed around the core philosophy (speed-to-game, newcomer-to-expert,
  jam-ready, scales with the project).
- Covered by `tests/node_picker_test.gd` (10 assertions).

### Spec: Inspector attributes (Unity-style, the Godot way)
- `docs/INSPECTOR-ATTRIBUTES-SPEC.md` - design for Range/Tooltip/Group/Multiline/
  Show-If/On-Changed/Tool-Button/Read-only attributes on sheet variables, tiered by
  mechanism (pure annotations → generated setters/`_validate_property` →
  EditorInspectorPlugin drawers), with data model, dialog UX, canonical emission
  shapes and lifting rules. Later phase; parity + lossless contracts preserved.

### Searchable scene-node picker
- Expression params gain a **🔍 Pick Node** browser next to ƒx: a filterable tree of the
  edited scene - the filter matches **name, class or path** (type `Area2D` to see every
  area, `UI/` to scope to a branch), double-click inserts the `$Path` reference
  (identifier-safe quoting) at the caret. Built for large scenes where drag-drop means
  scrolling hundreds of nodes.

### Audio module (the C3 Audio addon, the Godot way) + the new module structure
- **Play Sound / Play Sound At (2D)** - C3's fire-and-forget Play: a throwaway
  AudioStreamPlayer(2D) that frees itself when finished (multi-line `{uid}` template;
  zero bookkeeping, zero plugin runtime), with bus + volume params.
- **Player-scoped group** (attach to an AudioStreamPlayer - music & controlled playback):
  Play (from seconds), Play Sound File, Stop, Seek, Set Volume, Set Playback Rate,
  Is Playing, Playback Position.
- **Godot extras C3 fakes with tags**: Set Bus Volume / Mute Bus / Bus Volume
  (AudioServer) - master/music/SFX sliders in one action.
- **▶ Sound preview in the params dialog**: audio params show a preview button - hear
  the file before applying (■ stops).
- **Maintainability**: vocabularies now live in per-module files
  (`registration/modules/audio_aces.gd` first) built through a shared
  `EventForgeACEFactory`, with a documented module contract - each C3-equivalent
  "addon" is one readable file that can ship standalone or be curated into packs.
  Existing groups migrate over time; ace_ids/templates frozen (compatibility covenant).
- Covered by `tests/audio_aces_test.gd` (9 assertions).

### Device input vocabulary (C3 Keyboard / Mouse / Gamepad / Touch)
- **Keyboard**: Key Is Down (`is_physical_key_pressed`), On Key Pressed/Released
  (event-scoped, for On Input events) - and key params use **C3's press-a-key
  workflow**: click the field, press the key, the `KEY_*` constant is captured
  (with a fallback dropdown for undetectable keys).
- **Mouse**: button-down condition, world/screen position expressions, Set Mouse Mode
  (visible/hidden/captured/confined - the Godot-contextual extra).
- **Gamepad**: button-down (12-button dropdown), axis expression (sticks + triggers),
  is-connected, and **Vibrate Gamepad** (weak/strong motors).
- **Touch**: touchscreen-available, On Touch / Touch Released (event-scoped), touch
  position. Plus C3 search synonyms for all four devices.
- **Dialog-width fix**: long helper labels in the variable/enum/signal/match/pick dialogs
  now autowrap, so dialogs open compact instead of stretching to the longest sentence.
- Covered by `tests/device_input_test.gd` (13 assertions).

### Per-ACE comments + starter templates
- **ACE comments** (C3's per-condition/action notes): right-click any condition or
  action → "Edit ACE Comment…" - the note renders dimmed after the ACE text (`⊳ why
  this exists`), undoable, persisted on the resource.
- **New… templates**: a toolbar menu with **Blank**, **Platformer Starter** (move +
  gravity + grounded jump) and **Top-down Starter** (8-way `get_vector` movement) -
  adopted unsaved, compile-verified, the C3 new-project feel.

### Debug & polish: breakpoint UX, Find & Replace, shader/date/platform vocabulary
- **Breakpoints are fully wired**: F9 persists onto the event resource, and the new
  **Debug BP** toolbar toggle turns debug compiles on per sheet (`breakpoint`
  statements pause the real Godot debugger; normal compiles untouched).
- **Find & Replace**: the find bar gains a replace field + **Replace All** - one
  undoable substitution across comments, GDScript blocks, string params, pick-filter
  expressions, group names/descriptions and match branches, with a count.
- **Set Shader Parameter** (C3 effects → Godot materials, StringName idiom),
  **Date & Time** (datetime string, unix time) and **Platform** (OS Name,
  Has Feature with the mobile/web/pc dropdown) vocabularies.
- **Families** mapped honestly in the migration guide (node groups + behavior packs);
  the **live-values overlay** is spec'd as the next debugging rung (EngineDebugger
  channel design, deferred to its own slice).
- Covered by `tests/debug_polish_test.gd` (9 assertions).

### Language gaps closed: C3 Loops, Pick Instances, returns, group locals, real breakpoints
- **The full C3 Loops set** in the pick-filter dialog (with a C3-named preset menu):
  **For** (indexed), **For Each**, **For Each (ordered)**, **Repeat**, **While** - Repeat
  compiles to `for i in range(n)`, While to a real `while`, all reusing the picking
  pipeline (predicates and first-N still apply).
- **The C3 Pick Instances set** as presets: Pick all, **by comparison/evaluate**
  (predicate), **by highest/lowest value** (ordered + first-1), **nth**, **random**
  (`[….pick_random()]`), **last created**, **overlapping point** - powered by **ordered
  picking finally compiling** (`order_by` sorts a copy via `sort_custom`; descending
  flips the comparator). *Pick nearest* is `order by distance, first 1`.
- **Function return types**: `EventFunction.return_type` (Variant.Type) emits
  `-> int:` etc., **Return Value / Return** actions author it, and typed functions
  **verify-lift round-trip**. Non-void functions are usable in ƒx expressions.
- **Group-local variables** (C3): variables attached to a group compile as class members
  under a `# <Group> - group locals` header.
- **Real breakpoints**: gutter-flagged events (persisted as `EventRow.debug_break`) emit
  a `breakpoint` statement when the sheet's debug-compile toggle is on - pausing the
  actual Godot debugger. Normal compiles are untouched.
- Covered by `tests/language_gaps_test.gd` (16 assertions).

### Bug sweep 3 (stateful-condition hardening)
- **GDScript-backed sheets compiled broken scripts when a stateful condition was added**
  (Every X Seconds referenced a member the external path never declared) - members now
  insert before the first function, skipping any already present verbatim so untouched
  round-trips stay byte-identical.
- Disabled stateful conditions no longer leave orphan member declarations behind.
- Stateful conditions in OR-mode events now **warn** (the accumulator rebases whenever
  ANY condition passes - usually not what you meant; use a dedicated event).
- All three regression-asserted in `tests/stateful_aces_test.gd` (now 15 assertions).

### C3 System coverage, batch 2: stateful conditions + multi-statement actions
- **Every X Seconds** - C3's most-used System condition, done the parity-safe way:
  each applied instance bakes a **private class member** (fresh uid), a prelude line
  accumulates `delta` before the `if`, and an on-true line rebases the accumulator
  inside it. Plain members, plain statements, zero indirection; per-frame triggers only
  (documented). Stateful events never chain as Else/Else-If (warned + emitted
  standalone).
- The machinery is generic: descriptors can declare `member_template` /
  `codegen_prelude` / `codegen_on_true` - future latches and cooldowns ride the same
  rails, including from addons.
- **Multi-statement action templates**: baked templates may span lines (each emitted at
  body indent, `{uid}` locals baked per instance) - enabling **Spawn Scene At**
  (instance + position + add_child in one action, C3's create-object-at-position).
- Covered by `tests/stateful_aces_test.gd` (11 assertions).

### C3 System coverage, batch 1: time, display, text, comparisons
- **Time group**: Set Time Scale (`Engine.time_scale` - C3's slow-motion staple) + Time
  Scale / Game Time / FPS / Frame Count expressions.
- **Display group**: Set Fullscreen Mode (window-mode dropdown), Set Window Size, Window
  Width/Height expressions.
- **Text group** (the C3 System string functions, as direct String methods): Token At /
  Token Count (`get_slice`), Find, Left/Right/Mid, Upper/Lowercase, Length, Replace,
  Trim, **Zero Pad** (`"%0*d" %`).
- **Generic comparisons**: Compare Values (`{a} {op} {b}` with the operator dropdown) and
  Is Between Values - plus C3 search synonyms for all of it.
- Covered by `tests/system_aces_test.gd` (9 assertions).

### BBCode-lite comments
- Comments now style with a small BBCode subset: **[b]bold[/b]**, *[i]italic[/i]*, and
  **[color=#ff7777]…[/color]** (hex or named colors), rendered natively on the
  virtualized canvas with nesting support.
- **No data loss, ever**: the raw text (tags included) remains the editing and
  serialization truth - inline editing shows the tags, styling only shapes the pixels.
  Unknown tags strip gracefully (inner text survives), unclosed tags degrade sanely, and
  plain bracket text like `array[0]` is never mistaken for markup.
- Covered by `tests/bbcode_comments_test.gd` (13 assertions).

### 3D behavior packs (starter quartet)
- **Sine 3D** (oscillate along x/y/z or around Y, full wave set), **Orbit 3D** (XZ-plane
  circling), **Bullet 3D** (launch along the host's forward with gravity + distance
  tracking, relaunchable), and **Move To 3D** (Vector3 waypoint queue + On Arrived) -
  eighteen packs bundled total, all sheet-built and covered by the pack test's
  no-drift/load/publish assertions.

## [0.4.0] - 2026-06-10

The polish-and-reach release: the starter **3D vocabulary**, a **five-fix silent-bug
sweep** (plus a second sweep fixing stale addon tags on plain sheets), **find that
reaches folded groups**, **addon tags** (searchable, MCP-filterable, with documented use
cases), the **showcase demo README**, an up-to-date Theme Editor preview, and
**CONTRIBUTING.md** for open-source readiness. Details below (newest first).

### Sweep 2 (pre-tag)
- Plain sheets now clear `addon_tags` on type switch (no stale never-emitted tags), and
  the analyzer's directive handling is regression-tested against the generated-pack
  layout (`@ace_tags` above `@icon(...)` above `class_name`).

### Open-source readiness: CONTRIBUTING.md
- A contributor guide distilling the project's institutional knowledge: the verification
  loop (with its known quirks), the house rules (compatibility covenant, performance
  parity, lossless rule, zero-config addons, hidden optimization, guardrails), canonical
  emission + golden-regeneration workflow, how-to-add recipes (ACEs, addons, packs,
  themes), and the GDScript gotcha list that has bitten before.

### Find reaches folded groups + addon tags
- **Ctrl+F now searches the FULL tree**: matches inside collapsed groups are found, and
  stepping onto one **unfolds the path to it** and lands on the row (the sweep's known
  limitation, fixed properly via tree search + reveal).
- **Addon tags**: tag any addon with a class-level `@ace_tags(movement, retro, jam)`
  annotation - or the **Tags field** in the Sheet Type dialog for sheet-built addons
  (emitted into the generated script, zero-config as always). Tags are **searchable in
  the picker**, ride along on every ACE the provider publishes, and are **exposed and
  filterable over MCP** (`list_aces` now matches tags and reports them).
- Covered by `tests/addon_tags_test.gd` (7 assertions) + the folded-find assertion in
  `tests/godot_feel_test.gd`.

### Silent-bug sweep (five fixes)
- **Linked panes stole the active view**: mirroring a selection re-emitted
  `selection_changed` in the mirrored panes, silently rerouting Ctrl+/, copy/paste and
  every selection-driven op to the wrong pane. Mirrored selections are now inert
  (regression-asserted).
- **Find-step used stale indices**: matches captured at typing time pointed at the wrong
  rows after any edit - F3 now recomputes matches on every step.
- **Closing one secondary pane reset the active view** even when the *other* pane was
  active; the reset is now conditional.
- **"Open in Split" silently did nothing** for rows inside folded groups in the split
  pane - it now unfolds and retries.
- **MCP server served stale sheets**: the long-lived server read `.tres` files through
  Godot's resource cache; reads now bypass the cache (`CACHE_MODE_IGNORE`).
- Known limitation surfaced by the sweep (deferred, by design of the flat-row model):
  Ctrl+F doesn't match rows hidden inside folded groups.

### Starter 3D vocabulary
- **14 native 3D ACEs** under their node-type groups: **Node3D** (Set Position/Rotation/
  Scale, Move By, Look At, position expression), **CharacterBody3D** (Is On Floor,
  Move And Slide, Set/Get Velocity), **RigidBody3D** (Apply Central Impulse), and
  **Camera3D** (Make Current, Set FOV) - plus the **Input Vector** expression
  (`Input.get_vector`, StringName idiom, InputMap dropdowns) for 2D and 3D movement
  alike.
- Tween, visibility/tint, math & random, scene flow, and audio were already
  dimension-agnostic; signal/collision triggers work on 3D nodes unchanged. The README's
  "2D-first" con is softened accordingly.
- Covered by `tests/native_3d_aces_test.gd` (7 assertions).

## [0.3.0] - 2026-06-10

The multi-view release: the same sheet in split panes, detached OS windows, and linked
follow-selection views - all full editors over one source of truth - plus experimental
tool sheets (`@tool` + EditorScript with the On Editor Run trigger: editor tooling
authored as events). Details below (newest first).

### Tool sheets (Phase D - EXPERIMENTAL): build editor tooling from events
- **`@tool` sheets**: a Sheet Type checkbox emits `@tool` ahead of
  `class_name`/`extends`, so sheet-built nodes and behaviors run inside the editor.
- **Editor Tool preset** (Sheet Type → "Editor Tool"): an `EditorScript` host paired
  with the new **On Editor Run** trigger - your events run from **File > Run**
  (Ctrl+Shift+X). Batch renames, scene generation, project chores: event-sheet style.
- Full citizen: generated tools **verify-lift back** (On Editor Run round-trips
  byte-identically) and `tool_mode` recovers when re-opening a generated `.gd`.
- Explicitly **experimental and editor-version-coupled** (editor APIs are Godot's most
  volatile surface - runtime ACEs stay on stable APIs only, per the covenant).
- Covered by `tests/tool_sheets_test.gd` (10 assertions).

### Multi-view complete: detached windows + linked panes (P2/P3)
- **Detach** (toolbar): a floating OS window hosting another full-editing pane over the
  same sheet - drag it to a second monitor while debugging. Same shared per-sheet state
  (breakpoints/bookmarks/disabled) and the same refresh bus as the split pane.
- **Link** (toolbar): follow-selection across panes - selecting a row in any pane
  scrolls/selects it in the others. Keep the split zoomed out as an overview and click
  rows to focus them in your detail pane (recursion-guarded; unlink any time).
- With Split (P1) + full dual-pane editing (P1.5), the multi-view arc from the spec is
  **complete**. Covered by the extended `tests/multi_view_test.gd` (21 assertions).

### Multi-view phase 1.5: both panes are full editors
- The split pane graduated from read-only companion to a **full editor**: double-click
  edits, dialogs, drag/drop, context menus, find - everything works in either pane (the
  dock's handlers are payload-driven, so one handler set serves both).
- **Active-view routing**: selection-driven toolbar ops (copy/paste, Ctrl+/, Alt+arrows,
  Add Condition/Action, quick-add anchors) follow the **last-focused pane**; closing the
  split falls back to the primary.
- **"Open in Split"** (row context menu): pins the row in the other pane - opening the
  split automatically if needed - the "keep this visible while I work over there" move.
- Covered by the extended `tests/multi_view_test.gd` (14 assertions).

### Multi-view phase 1: split view (same sheet, two panes)
- A **Split** toolbar toggle opens a second pane over the SAME sheet (VSCode's
  one-file-two-editors gesture) - read a handler while editing the function it calls,
  keep a group pinned while debugging another.
- **Per-sheet state is shared by reference** (`EventSheetViewState`): breakpoints,
  bookmarks, and the disabled overlay agree across panes instantly. Scroll, zoom,
  selection, and folds stay per-pane.
- Every edit refreshes both panes (the refresh bus); the companion pane is
  read/navigate-only in phase 1 (inline editing stays in the primary - full
  active-view editing is the spec'd phase 1.5). Closing the split restores the layout.
- Covered by `tests/multi_view_test.gd` (10 assertions).

## [0.2.0] - 2026-06-10

Thirty-five features since 0.1.0 - the C3 coverage program (38 native-node ACEs, all 14
behavior packs with C3-capability parity), first-class rich variables (enums, collections,
combos, the Dictionary/Array/JSON ACE set), signals/match/input vocabulary, the importer's
function verify-lift, gutter bookmarks, sheet includes, find-in-sheet + script-editor
shortcuts, editor-theme inheritance + six iconic theme presets, color params with sheet
swatches, the MCP server, Export Addon Pack, drag-from-docks, scene-aware completion, and
the group-compile fix. Highlights below (newest first).

### Export Addon Pack, Godot-native affordances, README overhaul
- **Export Addon… (toolbar)**: one click turns the current behavior sheet into a
  published pack folder (`eventsheet_addons/<class_snake>/` - editable `.tres` +
  compiled `.gd`, no-drift rule honored, FileSystem rescanned) with guardrails for
  non-behavior sheets and invalid class names. The addon-builder loop is now fully
  in-editor: author behavior → annotate → Export → ACEs published project-wide.
- **Drag from the docks into ƒx fields**: drop a FileSystem file → its quoted `res://`
  path; drop a Scene-dock node → a `$Path` reference (relative to the edited scene,
  quoted automatically when the name needs it).
- **Scene-tree-aware completion**: `$Child.` now completes against the OPEN scene's
  actual nodes - script methods, signals, and class members - and direct children appear
  as `$Name` candidates in flat completion.
- **README rewritten** as a proper front door: honest pros & cons, current status,
  milestones table, and a quick start - kept current with every major update from now on.
- Covered by `tests/phase_c_affordances_test.gd` (12 assertions).

### Behavior packs aligned with their C3 capabilities
- **Sine**: seven movement types (horizontal, vertical, forwards-backwards, size, angle,
  opacity, value-only) and **five wave shapes** (sine, triangle, sawtooth,
  reverse-sawtooth, square) - both Inspector combos - plus phase, Update Initial State
  (C3's `updateInitialState`), and a readable `wave_value`.
- **Orbit**: elliptical orbits (primary/secondary radii), offset angle, match-rotation,
  total-rotation tracking. **Bullet**: distance-travelled tracking + enable toggle.
- **Move To**: a real **waypoint queue** (Move To Position replaces, Add Waypoint
  appends; On Arrived fires at the final stop) + rotate-toward-motion.
- **Follow**: a **delayed mode replaying the target's position history** (C3's
  delay-based Follow) alongside the smooth-chase mode. **Drag & Drop**: axis locking
  (both/horizontal/vertical). **Car**: `drift_recover` (low = drifty) and
  turn-while-stopped.
- **Tile Movement**: **Simulate Step** (C3 simulate control), a default-controls toggle,
  and grid-space helpers (`to_grid`/`from_grid`). **Line of Sight**: a **cone of view**
  and a second condition, *Has LOS Between* arbitrary positions.
- All regenerated through the pack pipeline (no-drift goldens updated) and guarded by
  `tests/pack_parity_test.gd` (17 functional assertions on real instantiated behaviors).

### Combo properties + color params (C3's Combo/Color, the Godot way)
- **Combo variables**: String variables can declare allowed values ("Options" in the
  variable dialog, comma-separated). Exported combos compile to **`@export_enum`** - a
  real Inspector dropdown - and **verify-lift back** with their options intact
  (byte-identical round-trips). Guardrail: the default must be one of the options.
  The Sine pack's `movement` showcases it (horizontal/vertical/angle dropdown).
- **`@ace_param_options(param a, b, c)`** annotation: addon ACE params render as
  dropdowns in the params dialog - the C3 Combo for addon authors, zero config.
- **Sheet-enum-driven params**: the `enum:State` param hint offers the enum's members
  (`State.IDLE`, …) as a dropdown - combos backed by real enums.
- **Color params**: the `color` hint (or a Color-typed param) renders a **color picker**
  in the params dialog, values round-trip as canonical `Color(r, g, b, a)` literals, and
  **conditions/actions with a color param draw a small swatch** next to their text in
  the sheet (C3-style color preview). Set Color Tint now uses it.
- Covered by `tests/combo_color_test.gd` (15 assertions).

### Nine new behavior packs (C3 coverage, Phase B - all fourteen C3-style behaviors bundled)
- **Sine** (oscillate position/angle), **Orbit** (circle a point), **Bullet** (angle-of-
  motion movement with acceleration/gravity), **Move To** (glide to a point + On
  Arrived), **Follow** (smoothly trail a node path), **Drag & Drop** (mouse grab within
  a radius + On Drag Start / On Dropped), **Car** (accelerate/brake/steer, speed-scaled
  steering, `move_and_slide`), **Tile Movement** (grid stepping + On Step Finished), and
  **Line of Sight** (a raycast-backed *Has Line Of Sight To* condition).
- All built as event sheets through the established pack pipeline (`.tres` source +
  generated `.gd`, zero-config ACE publishing, behaviors attach as child nodes,
  properties in the Inspector) and guarded by the pack test's no-drift goldens,
  class-load, and publish assertions - the compatibility covenant in action.

### Native-node ACE providers (C3 coverage, Phase A)
- **38 new builtin ACEs wrapping native Godot features** - lane 1 of the C3 coverage
  program (the engine maintains the implementation; we maintain vocabulary):
  - **Tween Property** (Godot `create_tween` with transition/ease dropdowns - the C3
	Tween behavior's job, natively),
  - **Scene** group (Go To Scene, Restart Scene, Quit, Set Paused, Spawn Scene
	Instance, Is Paused - C3's layout actions),
  - **AudioStreamPlayer**, **AnimatedSprite2D**, **Camera2D**, **Label**,
	**NavigationAgent2D** (C3 Pathfinding), and **CanvasItem** visibility/tint groups,
  - **Math & Random** expressions: Random, Random Integer, **Choose** (C3's `choose()`
	as `[…].pick_random()`), Clamp, Lerp, Distance To, Angle Toward.
- **C3 search synonyms** for the new vocabulary ("go to layout" → scene, "choose",
  "play sound", "set text", "fade"/"animate" → tween, "find path"…), and the migration
  guide gains the full **three-lane behavior/plugin mapping table**.
- Covered by `tests/native_node_aces_test.gd` (18 assertions).

### Iconic theme presets (Dracula and friends)
- Six new bundled themes built from the palettes people already live in: **Dracula,
  Nord, Gruvbox Dark, Monokai, Solarized Light, and Catppuccin Mocha** - every token
  mapped deliberately (conditions take the palette's cool accent, actions the
  warm/green, groups the signature color, comments the comment color; lanes get a
  whisper of their accent over the background).
- Generated by `tools/build_theme_presets.gd` (rerun after token additions); the
  existing presets (high-contrast, soft-light, C3-stacked, designer template) remain.
  All presets are load-verified by the style test.

### Signal rows + match rows (GDScript language parity)
- **Signals are first-class rows** (the enum-row treatment): add via the row menu
  ("Add Signal Below") or double-click to edit - name plus typed params one-per-line
  (`damage: int`). They compile canonically (after enums, before variables),
  **verify-lift** back from generated code (non-canonical formats stay blocks,
  byte-identical round-trips guarded), travel in **snippets**, feed the **On Signal /
  Emit Signal pickers**, lint (`hit.emit(3)` validates), and **validate custom-signal
  trigger connections** at compile time. Names/params pass the identifier guardrails.
- **Match rows** (C3's switch, GDScript's `match`): a structured action-lane row with an
  ƒx subject expression and branch text in real GDScript match-body syntax - enum members
  complete in patterns. Renders as indented action cells; double-click opens the match
  dialog, whose commit guardrail **lint-checks the whole construct** (broken matches
  never commit). Compiles in-flow inside the event body, source-mapped.
- Covered by `tests/signal_match_rows_test.gd` (16 assertions).

### Hidden codegen optimization + signal autocomplete (C3 object-signal parity)
- **ACEs now emit expert idioms behind the scenes** (new spec rule, "Hidden
  optimization"): hot-path builtin templates use `&"name"` **StringName literals**
  (input polling, `is_in_group`, `play`), skipping the per-call String→StringName hash
  in per-frame code. The picker shows the same friendly labels; user ƒx expressions and
  GDScript blocks are **never** rewritten; existing sheets keep their baked templates.
  EmitSignal's template also got fixed to emit a valid `emit_signal(&"name")`.
- **Signal autocomplete everywhere** (like C3's object signals/tags):
  - Dot-completion now offers **signals** alongside methods/properties - typed
	variables (`zone.` → `body_entered`), behavior `host.`, and `$GlobalClass.`
	including script-declared signals (`$PlatformerMovement.` → `jumped`).
  - Signal params (On Signal, Emit Signal) render as a **dropdown** of the host
	class's signals plus signals declared in the sheet's GDScript blocks - pick,
	don't type. Custom values persist as the first option.
- Covered by `tests/signal_autocomplete_test.gd` (8 assertions) + updated input tests.

### Godot-feel batch: find-in-sheet, script-editor shortcuts, editor-theme inheritance
- **Ctrl+F find bar**: script-editor-style find-in-sheet (matches visible row text AND
  GDScript block code, case-insensitive); Enter/F3 next, Shift+F3 previous, Esc closes,
  with an "n of m" counter and wrap-around.
- **Script-editor shortcut conventions**: **F9** toggles breakpoints (Ctrl+B stays as an
  alias), **Ctrl+/** toggles the selected rows' enabled state - the "comment out" of
  event sheets - and **Alt+Up/Down** moves the selected row (reusing the drag machinery,
  fully undoable).
- **The sheet inherits your editor theme**: when no explicit theme is chosen, default
  visual tokens derive from the editor's base + accent colors (dark/light/custom-accent
  editors all match out of the box), and the initial zoom honors the editor display
  scale on hi-DPI. Theme presets and per-sheet themes still override.
- Covered by `tests/godot_feel_test.gd` (14 assertions).

### Input vocabulary + Wait/Await (Godot-familiarity batch 1)
- **Input ACE group** - the most-used trigger family finally has first-class vocabulary:
  Is Action Pressed / On Action Just Pressed / On Action Just Released conditions,
  Action Strength + Input Axis expressions, and **On Input / On Unhandled Input**
  lifecycle triggers (`_input(event)` / `_unhandled_input(event)`) that compile AND
  verify-lift back from generated code.
- **Action params are dropdowns read from the project's InputMap** (custom actions
  first, then the `ui_*` defaults) - pick real actions instead of typing strings.
- **Wait / Wait For Signal** actions (C3's System → Wait): compile to
  `await get_tree().create_timer(s).timeout` / `await <signal>` - handlers are implicit
  coroutines in GDScript, so awaiting mid-event is safe and idiomatic.
- Covered by `tests/input_time_aces_test.gd` (14 assertions).

### MCP server - AI tooling (the backlog's final item)
- **A pure-GDScript Model Context Protocol server** ships in the addon
  (`addons/eventsheet/mcp/`): the Godot binary itself is the server process - no
  Python/Node dependencies. Setup guide: `docs/MCP-SERVER.md`.
- Six tools for AI assistants: `list_sheets`, `read_sheet` (structured JSON of rows/
  variables/enums/functions; also opens any `.gd` as a sheet), `list_aces` (the full
  vocabulary incl. zero-config addons), `compile_sheet` (**dry-run by default**),
  `lint_block` (compile-check against sheet context), and `apply_snippet` (append rows
  from snippet text or plain GDScript via the lossless paste pipeline - the only
  mutating tool, `.tres`-only, append-only).
- Transport-free protocol core (`EventSheetMCPServer.handle_message`) covered by
  `tests/mcp_server_test.gd` (21 assertions); the stdio loop is a thin newline-delimited
  JSON-RPC wrapper (launch with `--headless --quiet`).

### Curated collection ACE set (rich-variables phase 3 of 3 - the 1.0 arc is complete)
- **27 ready-made Dictionary / Array / JSON ops** as builtin Core descriptors, grouped in
  the picker as **Variables: Dictionary** (Set/Delete Key, Clear, Merge, Has Key,
  Is Empty, Get-with-default, Size, Keys, Values), **Variables: Array** (Append, Insert
  At, Remove At, Erase, Clear, Sort, Shuffle, Contains, Is Empty, Value At, Size, Pick
  Random), and **Variables: JSON** (To/From JSON Text, JSON Is Valid, Save/Load JSON
  File - `user://` paths survive exports).
- Every op compiles to a **single direct GDScript line** (`inventory["sword"] = 1`,
  `scores.append(10)`, `JSON.parse_string(...)`) - parity-safe, reverse-lift-eligible,
  and the templates double as GDScript teachers. The long tail stays one ƒx away.
- **Type-aware variable dropdowns**: `variable_reference:Array` / `:Dictionary` hints
  filter the dropdown to matching variables (typed containers match their base;
  Variant/untyped always qualify) - with a clear "No Array variables - add one first"
  block when none exist.
- **C3 migration guide** gains a data-plugins table (Dictionary/Array/JSON addons → the
  Variables groups; XML → intentionally unsupported, use JSON).
- Covered by `tests/collection_aces_test.gd` (15 assertions). With enums (phase 1) and
  collection variables (phase 2), **the first-class rich-variables feature is complete**.

### Collection variables (rich-variables phase 2 of 3 - 1.0 scope)
- **Array and Dictionary variables are first-class**, including Godot 4 typed containers
  (`Array[int]`, `Dictionary[String, int]`, …) offered in the variable dialog's type list.
- **Defaults edit as GDScript literals** (`{"sword": 1}`, `[1, 2, 3]`) with a live ✓/✗
  hint while typing, and a commit guardrail: invalid literals never save (wrong container
  kind, garbage, or **element-type mismatches** against the declared `Array[T]` /
  `Dictionary[K, V]` - with int→float allowed, as in GDScript).
- **Canonical emission**: containers compile through a recursive, escape-correct,
  deterministic literal formatter (`{"k": 1, "nested": {"ids": [1, 2.5]}}`); editing an
  existing collection variable shows that same canonical literal.
- **Verify-lift round-trips**: canonical collection declarations in generated `.gd` files
  re-open as editable variable rows with their values intact; non-canonical formatting
  stays a verbatim block - byte-identical round-trips guarded.
- Covered by `tests/collection_variables_test.gd` (17 assertions).

### C3-familiarity batch: group descriptions, slow-click editing, rename refactoring, commit guardrails
- **Group events now actually compile** - the batch's tests exposed that events inside
  groups were silently dropped with a TODO comment (a long-standing compiler hole).
  Groups flatten inline at emission, with C3 semantics: **disabling a group drops all of
  its children from the compiled output**; group comments compile as comment lines.
- **Group descriptions** (C3-style): a muted, inline-editable second line on the group
  header (`EventGroup.description` - also via the row menu "Edit Group Description…");
  travels in snippets. Group titles were already double-click renameable.
- **Slow double-click editing** (Explorer-style): click an already-selected editable
  cell again after the double-click window (450–1600 ms) to start editing - comments,
  group names/descriptions, variable rows; multiline comments route to their dialog.
- **Variable rename refactoring**: renaming a variable rewrites every reference across
  the sheet - GDScript blocks (class-level, in-flow, function bodies), ƒx/string params,
  pick-filter expressions, and **baked codegen templates** (placeholders like `{amount}`
  are never touched). Whole-word matching; the status bar reports how many references
  updated. A rename can no longer silently break compiled code.
- **Commit-time guardrails** ("you can't enter broken stuff"): variable and enum names
  auto-correct where fixable (`my var` → `my_var`, digit-led names prefixed) and are
  **blocked with a clear message** when not (GDScript keywords); broken GDScript blocks
  never commit (the dialog reopens with your text intact); the params dialog refuses to
  apply while any ƒx expression fails its compile-check.
- Covered by `tests/ux_guardrails_test.gd` (29 assertions).

### First-class enums (rich-variables phase 1 of 3 - 1.0 scope)
- **Enums are sheet rows**: add via the row menu ("Add Enum Below") or double-click to
  edit (name + members, optional explicit values like `HURT = 4`). They compile to
  canonical class enums **before variables**, so `var state: State` works - and exported
  enum-typed variables get Godot's **Inspector dropdown for free**.
- Full citizen everywhere: rendered as keyword-badged rows; **verify-lifted** back from
  generated code (non-canonical/multi-line enums stay verbatim blocks; byte-identical
  round-trip guarded); travel in **snippets**; expressions referencing them **lint**
  correctly; `State.` **dot-completes the members** in ƒx fields and GDScript blocks;
  source-mapped for provenance.
- Scope decisions recorded: rich variables (collections UX + curated Dictionary/Array/
  JSON ACE set) are **required for 1.0**; **XML support is dropped** - JSON is the
  interchange format. Covered by `tests/enum_row_test.gd` (16 assertions).

### Inspector polish: widget_hint editors + per-row "Selected ACE" properties
- **widget_hint-specific inspector editors**: exposed ACE params with `widget_hint`
  (or an `@ace_param_hint`) now render custom controls in Godot's Inspector - `slider`/
  `range` → HSlider (bounds from `range: "min,max,step"` metadata), `multiline` →
  TextEdit, `expression` → the ƒx-style line editor. Unknown hints keep Godot's default
  widgets. (Construction is editor-only; class mapping is headless-tested.)
- **Per-row "Selected ACE" section**: selecting a condition/trigger/action in the sheet
  surfaces *that row's* parameters as live Inspector properties. Edits route through the
  dock's undoable write path (the exposed node never mutates sheet resources itself) and
  refresh the viewport immediately; deselecting clears the section. This closes the last
  two open items from the editor param-exposure spec.
- Covered by `tests/inspector_polish_test.gd` (15 assertions).

### Gutter bookmarks + compile-time sheet includes
- **Bookmarks**: Ctrl+M toggles a session bookmark on the selected row (gold pennant in
  the gutter beside the breakpoint dot); **F4 / Shift+F4** cycle forward/backward through
  bookmarked rows with wrap-around. Session-scoped navigation aids (not persisted),
  synced through the central row-state pass so they survive refreshes.
- **Sheet includes are real** (the `includes` field finally has semantics, C3-style):
  list other sheets' `res://….tres` paths in the Inspector and their **variables,
  class-level blocks, events, and functions merge into this sheet's generated script** at
  compile time. The root sheet wins name collisions (warned), cycles and missing files
  are skipped with warnings, and included rows never enter the editing model - a shared
  "library sheet" pattern. Ignored for GDScript-backed sheets. (Field retyped
  `Array[NodePath]` → `Array[String]`; it was never used or serialized before.)
- Covered by `tests/bookmarks_includes_test.gd` (18 assertions).

### Importer completed: function verify-lift + comment preservation (two-pass safe)
- **Sheet functions lift back** when opening generated `.gd` files: their `@ace_*`
  annotation blocks reverse into `expose_as_ace`/name/category/description, parameters
  parse with types, and bodies use the event grammar with **lenient ifs** - unmatched
  control flow becomes in-flow GDScript inside the event instead of failing the file
  (trigger bodies got the same upgrade). Codegen templates and icons are regenerated
  rather than stored (behavior identity - `class_name`, host, behavior mode - is now
  recovered from the prelude so `$Class.fn()` templates verify).
- **Trailing top-level comments lift** into comment rows; the external compile path now
  emits top-level comments (it silently dropped them before - found by the byte-verify).
- **Two-pass safety**: when the full lift can't verify byte-identically, the event-only
  lift retries, so these upgrades can never regress previously-lifting files. Also fixed
  a latent revert leak (the shallow backup left a boundary row's stripped newline behind
  after a failed verify, corrupting round-trips).
- End-to-end fixture: the shipped **PlatformerMovement pack re-opens fully** - events,
  exposed functions, annotations, comments - with only the `_enter_tree` host-binding
  scaffold staying a verbatim block (external emission keeps the prelude untouched by
  design). Covered by `tests/function_lift_test.gd` (13 assertions).

### Intellisense upgrades: dot-context completion, signature hints, quick-add bar
- **Dot-context completion** in GDScript blocks and ƒx fields: typing `host.` offers the
  host class's members, a typed sheet variable offers *its* class's members, and
  `$TimerBehavior.` offers that behavior's script methods + base-class members (resolved
  via ClassDB + the global class list). Unresolvable tokens offer nothing rather than
  guessing; non-dot contexts keep the flat sheet/host candidates. One shared choke point:
  `EventSheetGDScriptLint.completion_for_context`.
- **Signature hints**: while typing inside a call, the editor shows the signature -
  sheet functions from their declared params, host methods from ClassDB
  (`signature_hint`, displayed via CodeEdit's code-hint popup in both editors).
- **Quick-add bar** (toolbar): C3's "type to insert" - `every tick` creates the On
  Process event (synonym phrasing honored), `heal 5` applies the Heal action with
  `amount = 5` (trailing words fill parameters positionally). Ties prefer the most
  specific name ("process" picks On Process, not On Physics Process); unknown queries
  report and decline. Covered by `tests/intellisense_test.gd` (16 assertions).

### Three more behavior packs: Timer, Flash, State Machine
- **TimerBehavior** (host: any Node): Start Timer / Stop Timer ACEs, exported
  `duration`/`repeating`, and the **On Timer** trigger (repeats when repeating).
- **FlashBehavior** (host: CanvasItem): Flash / Stop Flash ACEs blink the host's
  visibility at an exported `interval` for a duration, restore it, and fire
  **On Flash Finished** - the C3 Flash behavior.
- **StateMachineBehavior** (host: any Node): Set State action, **On State Changed**
  trigger `(previous, next)`, and an **Is In State condition** authored as an annotated
  class-level GDScript block - the reference example for mixing expose-as-ACE functions
  with hand-annotated block ACEs (including a custom codegen template) in one behavior.
- All authored as behavior sheets via `tools/build_sample_behaviors.gd` (editable `.tres`
  beside compiled `.gd`), no-drift goldens + publish assertions extended in
  `tests/sample_behavior_pack_test.gd`.

### Signal-handler lifting (round-trip for signal triggers)
- **Sheets that use signal triggers now lift back into events.** Previously any generated
  file with a signal trigger failed the all-or-nothing lift entirely (handlers aren't
  lifecycle functions). Now `_ready`'s leading connect lines are parsed into a handler →
  {signal, source node} map: Core signals reverse to their trigger ids (`_on_body_entered`
  → On Body Entered), custom ones become `signal:<name>` triggers with the handler's
  argument signature as `trigger_args` and the connect's `get_node("…")` path as
  `trigger_source_path`. Connect lines themselves are skipped (emission regenerates
  them), so a connects-only `_ready` produces no phantom OnReady event.
- Handlers with no connect entry (scene-wired) keep the whole file as verbatim blocks -
  the lossless byte-identical contract is unchanged and still gates every lift. This also
  upgrades paste-GDScript-as-events for pasted scripts containing signal handlers.
  Covered by `tests/signal_lift_test.gd` (13 assertions).

### Post-1.0 polish: pick filters compile, fx autocomplete, external-sheet watcher
- **Pick filters compile** - the last event-flow TODO is gone. C3's "for each" picking,
  the Godot way: each filter wraps the event body in a direct `for` loop over a node
  group / the children / any GDScript iterable, with an optional iterator-scoped `where`
  predicate and a first-N cap; conditions gate the loop and multiple filters nest. Pick
  rows render as "For each item in group \"enemies\"…" lines in the condition lane,
  author via the row context menu ("Add Pick Filter (For Each)…") and edit/delete via
  double-click. order_by and condition-based filtering warn honestly (predicate is the
  supported path). Plain loops - the performance-parity contract holds.
  Covered by `tests/pick_filter_test.gd` (17 assertions).
- **fx expression autocomplete**: expression fields are now single-line CodeEdits with
  completion popups (sheet variables, sheet functions, host members - the same candidate
  source as the GDScript-block editor), on top of the existing live validation. Newlines
  can never reach the stored value.
- **External-sheet file watcher**: GDScript-backed sheets track their file's mtime; when
  the editor regains focus after an outside edit (script editor, git, another tool), a
  prompt offers "Reload (re-import + event lifting)" vs "Keep Editor Version" (asked once
  per change). Save/open keep the timestamp in sync.
  Both covered by `tests/fx_completion_watch_test.gd` (10 assertions).

### Docs & demo final sweep
- **EDITOR-UI-SPEC §3 rewritten** as a roadmap-status section (everything planned has
  shipped; only pick-filter compilation, ƒx autocomplete, bookmarks, includes, and the
  MCP candidate remain open) and the **C3 parity matrix updated** (inline code blocks,
  behaviors, object icons, per-comment colors → Matched).
- **Theme token spec** gains the `behavior_accent_color` row; the two `docs/spec/` design
  studies are banner-marked as reference documents pointing at the live specs.
- **Demo refreshed**: `demo/README.md` rewritten for Godot EventSheets (asset map, golden
  regeneration workflow, toolbar theme switcher/theme editor); `demo/scenes/player.tscn`
  now actually attaches the generated script (with a collision shape) instead of being an
  empty node; the committed `player_generated_test_output.gd` byproduct is removed and
  `compile_demo_test` writes to `user://` so tests never dirty the repo again; orphan
  `.uid` cleaned up.

### Release housekeeping: zero test failures, paste-GDScript-as-events, migration guide
- **The full test suite is GREEN for the first time: 594 passing, 0 failures.** The four
  legacy `event_sheet_editor_test` failures are fixed for real:
  - the built-in demo sheet stamped its ACEs with provider "Core" while reflection
	registers the demo actor as `EventSheetDemoGameplayActor` - the resolver now matches
	by name (and no longer depends on registry refresh order), so demo rows render
	"On Died"/"Take Damage 10" again;
  - non-event spans (comments/variables/blocks) clamp 2px tighter, accounting for the
	chip rect's expansion - long comments stay inside the row width at any zoom;
  - the context-menu test re-acquires live row data between undoable edits (snapshot
	restore replaces row resources; the old assertion toggled an orphan).
  Only the long-known harmless tail segfault remains (after the summary prints); CI now
  fails on ANY `[FAIL]`.
- **Paste GDScript → events**: pasting raw GDScript from anywhere converts through the
  open-as-sheet pipeline - trigger functions ACE-lift into real events, declarations
  become variable rows, everything else lands as verbatim GDScript blocks (the lossless
  rule). Non-code clipboard text falls through to the normal paste paths untouched.
  Covered by `tests/gdscript_paste_test.gd` (9 assertions).
- **C3 migration guide** (`docs/C3-MIGRATION-GUIDE.md`): concept map (behaviors, layouts,
  picking, expressions) + common System vocabulary table + habits that transfer vs.
  habits to relearn.
- **Perf re-baseline** (10,801 flat rows): sheet build ~490 ms, zero per-row widgets,
  visible draw window 8 rows - the virtualization contract holds post-1.0-features.

### 1.0 feature-complete: visual completeness, export integrity, theme editor, rename
- **The plugin is now "Godot EventSheets"** (plugin.cfg, README, release artifacts -
  internal class names keep the EventForge prefix as the engine codename). Release zips
  are now `godot-eventsheets-<v>.zip` / `godot-eventsheets-samples-<v>.zip`.
- **Comments reach C3 parity**: multiline comment rows (one cell per line, row height
  follows), **per-comment background colors**, a comment dialog (multiline text + color
  picker - double-click multiline comments or use "Edit Comment…"; single-line comments
  keep fast inline editing), and **comment ↔ action-cell conversion** ("Attach Comment To
  Event Above" / "Detach Comment To Row"). Action-cell comments render per line inside the
  action lane, edit via double-click, and **compile to `#` lines inside the body**;
  top-level comments also compile as real comment text (the last "TODO: row type" case for
  comments is gone). Covered by `tests/visual_completeness_test.gd` (13 assertions).
- **Export-integrity hook**: an `EditorExportPlugin` recompiles every event sheet when an
  export starts (loud per-sheet errors on failure; GDScript-backed sheets skipped - their
  `.gd` is already the truth). The same pass is a static headless API
  (`EventSheetExportIntegrityPlugin.recompile_all_sheets`), tested in CI.
- **Visual theme editor** (the final planned phase): toolbar "Theme Editor…" opens a live
  workbench - a real viewport rendering a sample sheet on the left, and a **reflectively
  generated token form** on the right (every exported Color/float/int/bool on the style
  resources gets a control automatically, so future tokens appear with zero editor
  changes). Edits preview live on a sandboxed copy; "Apply To Current Sheet" is undoable;
  "Save As Preset…" writes a shareable `.tres`. Covered by
  `tests/release_hardening_test.gd` (13 assertions).
- **Stale code removed**: the dead `else_codegen`/`loop_codegen`/`expression_parser`
  compiler stubs (superseded by real implementations), the unreferenced `binding/`
  scaffold, and the unused `LoopRow`/`EventGroupReference` model stubs.

### Runtime addon bridge + instance-backed ACEs, release automation, docs refresh
- **`EventForgeBridge.register_script_as_provider` is real**: scripts registered from code
  (other plugins, tools, tests) join the ACE vocabulary exactly like
  `res://eventsheet_addons/` scans - static API (works without the autoload), deduped,
  unregister supported, `providers_changed` emitted.
- **Instance-backed addon ACEs**: addon *methods without* `@ace_codegen_template` used to
  compile to nothing; applying one now bakes a call through a per-provider member
  (`__eventsheet_provider_<Class>.method({args})`), and the compiler declares each used
  provider **once** as a plain owned instance (`var __… := Class.new()`). Template-less
  addon ACEs therefore compile and run in exported games with zero EventForge dependency
  (the parity contract holds - asserted in tests). Demo addon gained `announce_heal` as a
  living example. Covered by `tests/runtime_provider_test.gd` (10 assertions).
- **GitHub Actions**: `ci.yml` (every push/PR: import must be clean, headless-safe suite
  gates, full suite checked against the known pre-existing failures) and `release.yml`
  (tag `v*` or manual: test gate → version stamped into `plugin.cfg` → publishes a GitHub
  Release with `eventforge-<v>.zip` (addons-only, Asset Library layout) and
  `eventforge-samples-<v>.zip` (behavior packs + demo) with generated notes).
- **Docs folder refreshed**: `SPEC.md` rewritten (it still pointed at the deleted widget
  editor; now documents the real architecture, the implemented translation matrix, and
  the zero-runtime boundary); Auto-ACE and C3-workflow status docs updated to current
  truth; the early progress report is marked as a historical snapshot; theme-editability
  and alignment guides gained the newer facts (preset switcher, Godot-adaptive default,
  semantic tokens, icon advance, drag-resizable divider).

### ACE-level import lifting (reverse template matching)
- **Opening EventForge-generated GDScript as a sheet now lifts it back into real events.**
  Trailing lifecycle trigger functions (`_ready`/`_process`/`_physics_process`) parse into
  EventRows: conditions and actions **reverse-match the builtin codegen templates**
  (`{param}` placeholders become named captures; params round-trip as strings, including
  `not (...)` negation), and statements matching no template become in-flow GDScript
  blocks so the event still lifts.
- **The lossless rule still always wins**: the lift is all-or-nothing per file and kept
  only when recompiling the lifted sheet reproduces the source **byte-for-byte**;
  otherwise everything reverts to verbatim block rows. Non-trigger functions and unknown
  layouts simply stay blocks. Implemented in `EventSheetACELifter`
  (`addons/eventforge/importer/ace_lifter.gd`); covered by `tests/ace_lift_test.gd`
  (11 assertions).
- **README rewritten** around the actual feature set: every major phase (editor parity,
  compiler depth, GDScript pairing, zero-config extensibility, behaviors/packs), project
  layout, verification commands, and the remaining road to 1.0.

### Pairing polish: reverse provenance, live ƒx validation, row-cell icons
- **Reverse provenance** - the pairing loop now runs both directions: clicking a line in
  the GDScript panel **selects the sheet row that generated it** (most-specific source-map
  range wins; clicking inside an in-flow block selects its enclosing event). Built on the
  new `EventSheetViewport.select_resource()`, which also scrolls the row into view.
- **Live ƒx expression validation** - expression parameter fields compile-check on every
  keystroke against the sheet context (variables, host members, behavior `host`), tinting
  red with an explanatory tooltip when the text is not a valid GDScript expression
  (`EventSheetGDScriptLint.lint_expression`).
- **Object icons in row cells** (C3's strongest visual cue): condition/action/trigger
  cells draw their ACE's icon before the object label - addon `@ace_icon` textures, Godot
  class icons for node-typed ACEs, member glyphs otherwise; Core/System uses the editor's
  Tools glyph. Same resolver as the picker, cached per provider/ACE (misses for
  not-yet-loaded providers are not cached, so addon hot-loads self-heal). Span measurement
  accounts for the icon advance, so hit-testing stays exact.
- The plugin now bundles `addons/eventsheet/icons/eventsheet.svg` (used by the demo addon
  and tests; the project previously had **no** `res://icon.svg`, which made earlier
  icon-path asserts pass vacuously - they are real now).
- Covered by `tests/pairing_polish_test.gd` (15 assertions).

### Sample behavior packs (Platformer / Eight-Direction)
- **Two behaviors authored as event sheets ship in `res://eventsheet_addons/`** - editable
  `.tres` sources beside their compiled `.gd` scripts, built by
  `tools/build_sample_behaviors.gd` (also the reference for authoring sheets from code):
  - **PlatformerMovement** (host: CharacterBody2D): ui_left/right movement + gravity every
	physics tick, exported `move_speed`/`jump_velocity`/`gravity`, exposed ACEs **Jump** /
	**Set Move Speed**, and an annotated `jumped` signal publishing as the **On Jumped**
	trigger.
  - **EightDirectionMovement**: top-down ui_* movement with exported `move_speed` and
	**Set Move Speed**.
  Attach either under a CharacterBody2D (Create Node dialog) and it works; its ACEs appear
  in every sheet via the zero-config scanner; GDScript can call it directly
  (`$PlatformerMovement.jump()`). Guarded by `tests/sample_behavior_pack_test.gd`
  (12 assertions), including **no-drift goldens** (committed script == sheet recompile).
- Documented "Using behaviors / sheet code from hand-written GDScript" in the pairing spec
  (typed access, signals/await, extends; the don't-hand-edit-generated-files rule and the
  host lifecycle note).

### Eventsheet-authored behaviors: expose-as-ACE + sheet-type identity UX
- **Sheet functions can publish as ACEs.** Mark a function `expose_as_ace` (with optional
  display name/category) and the generated script carries the full `@ace_*` annotation
  block - including a default codegen template (`$PatrolBehavior.dash({strength})` for
  behaviors, `dash({strength})` for custom nodes/sheets) and the sheet's icon as
  `@ace_icon`. Drop the compiled script into `res://eventsheet_addons/` and the behavior's
  ACEs appear in every sheet: the **sheet → script → addon loop** is closed (verified by
  parsing the generated script back through the semantic analyzer). Unexposed functions
  emit `@ace_hidden`, making `expose_as_ace` the single publication switch.
- **Sheet-type identity UX** (dual-audience: Godot "custom node with an icon", C3
  "behavior attached to an object"): a slim **identity banner** above the sheet
  (`⚙ PatrolBehavior - Behavior · acts on host: CharacterBody2D`, click to edit), **tab
  badges** (⚙ behavior / ◆ custom node), the column header now reads
  `Conditions - host: <class>` on behavior sheets, a behavior-aware empty-state hint, and
  a new **"Sheet Type…" toolbar dialog** (Event Sheet / Custom Node / Behavior with
  name+icon+host fields) so none of it requires the Inspector. New themable
  `behavior_accent_color` token (soft purple).
- Covered by `tests/behavior_authoring_test.gd` (18 assertions).

### Behavior foundations: host accessor + real signal-trigger codegen
- **Behavior mode** (`EventSheetResource.behavior_mode`): the sheet compiles to an
  attachable **Node component** that acts on its parent - `extends Node`, a typed
  `var host: <host_class>` accessor bound in `_enter_tree` with an attach-time warning,
  and `host_class` reinterpreted as the declared/required host type. Lint/completion
  understand the behavior context (`host.velocity.x` lints clean).
- **Signal-backed triggers now actually connect.** Generated handlers used to rely on
  manual scene wiring; the compiler now emits `<signal>.connect(<handler>)` lines at the
  top of `_ready` (synthesizing `_ready` when no OnReady events exist). Works for self
  signals, **other nodes' signals** (`EventRow.trigger_source_path` → `get_node(...)`
  with source-aware handler names like `_on_platform_landed`), and **custom
  `signal:<name>` triggers** from addons/providers - which previously didn't compile at
  all. Argument signatures are baked at apply time (`trigger_args`), and applying a
  trigger definition now bakes `trigger_id` too (fixing picker-created trigger events
  silently skipping compilation).
- **Compile-time signal validation**: a self-connection is emitted only when the signal
  exists on the script's base class or is declared in a class-level GDScript block;
  otherwise it's skipped with a precise warning (emitting blindly produced a script that
  didn't parse - caught on the demo, whose CharacterBody2D sheet used OnBodyEntered).
- **Demo golden regenerated from the compiler** - `compile_demo_test` passes for the
  first time (pre-existing failures drop from 5 to 4). Covered by
  `tests/behavior_foundations_test.gd` (16 assertions).

### Custom node types from sheets + icon support
- **A sheet can now define a custom node type, exactly like GDScript.** Set
  `custom_class_name` (and optionally `custom_class_icon`) on the sheet in the Inspector
  and the generated script emits `@icon("…")` + `class_name X` + `extends Y` - the type
  appears in Godot's Create Node dialog with its icon, instances carry the sheet's
  behavior, and recompiling the sheet updates the class. Future eventsheet-authored
  Behaviors inherit this mechanism automatically (they compile to node scripts).
- **The ACE picker now shows icons** (C3 users expect the object's icon beside its name):
  addon `@ace_icon("res://…")` textures, node-type sections and entries with their Godot
  class icons, and member-kind glyphs (signal/method/property) as fallback - degrading
  gracefully to text-only when unavailable. Resolution is shared
  (`ACEPickerDialog.resolve_definition_icon`) so row rendering can reuse it next.
- Covered by `tests/custom_node_class_test.gd` (8 assertions); demo golden unchanged.

### Sub-event compilation + else/elif chains
- **Sub-events now compile**, nested inside their parent's conditions (C3 semantics): the
  parent's `if` at depth N, its actions and sub-events at depth N+1, recursively. The
  long-standing "row type not yet implemented" placeholder for sub-events/else is gone
  (only pick filters remain TODO).
- **Else / Else-If events chain onto the previous sibling's if** (`elif cond:` / `else:`,
  emitted adjacently); an Else with conditions is treated as Else-If; a chain row without
  a preceding conditioned event degrades to a standalone event with a compiler warning.
- **Event-flow extras compile too**: nested comments emit as `#` comment lines, variables
  dropped into an event's flow become **function-local `var` declarations** (with a warning
  if marked const/exported), and sibling GDScript blocks indent adaptively (pre-indented
  imported code keeps its tabs; flat editor-authored code is indented for its depth).
- **Validity guard**: an `if`/`elif`/`else` whose body emits nothing now gets `pass` -
  condition-only events can no longer produce invalid GDScript (latent bug fixed).
- All emitted rows (sub-events included) get provenance source-map entries. Demo golden
  output is unchanged. Covered by `tests/subevent_compile_test.gd` (12 assertions).

### GDScript-backed sheets: open ANY .gd as an event sheet (losslessly)
- **The Open dialog now accepts `.gd` files.** Opening one imports it as a GDScript-backed
  sheet: the file stays the **single source of truth** (no `.tres` is created), and Save
  compiles back to it. **Untouched files round-trip byte-identically** - guarded by a
  golden test with a deliberately hostile sample (annotations, comments, signals, enums,
  consts, odd formatting, default-param and non-void functions).
- **The lossless rule**: declarations lift to first-class rows only when canonical
  re-emission reproduces the source line exactly (verify-lift - e.g. `var hp: int = 100`
  becomes an editable variable row, `var speed := 5.0` stays verbatim); each top-level
  function becomes its own GDScript block row (per-function provenance); everything else
  is preserved in ordered verbatim blocks. External emission adds no generated header and
  never synthesizes `extends`.
- Events added to a GDScript-backed sheet append as standard trigger functions at the end;
  editing a lifted variable changes exactly its line. Save As `.tres` converts to a normal
  sheet (the `.gd` is left untouched). Covered by `tests/external_sheet_test.gd`
  (11 assertions).

### Performance-parity contract for generated code
- **Hard constraint, now written and guarded**: event sheets compile to GDScript that runs
  exactly as fast as hand-written code - direct statements only (no `call()`/`Callable`
  indirection, no reflection, no plugin classes in output), static types wherever known,
  signals connected once, `await` only when flagged, provenance kept as compiler metadata.
  Spelled out in GDSCRIPT-PAIRING-SPEC (Principles #5) and enforced by
  `tests/codegen_parity_test.gd`, which scans representative compiled output for banned
  indirection patterns and required typing.
- Planned export-integrity hook recorded: an `EditorExportPlugin` recompiling all sheets at
  export so stale generated scripts can never ship (EDITOR-UI-SPEC §3).

### Shareable snippets (cross-project copy/paste)
- **Copying rows now also writes a portable text snippet to the system clipboard**
  (`[eventsheet-snippet v1]` + Godot `var_to_str` data - no JSON, no script paths/UIDs), so
  events/groups/comments/GDScript blocks/variables paste across projects, editor instances,
  and forum/Discord posts. Multi-select serializes only top-most rows (children travel
  inside their parent).
- **Paste detects snippets first** (internal clipboard remains the same-session fallback):
  rows rebuild from whitelisted kinds only, pasted events get **fresh UIDs**, and sheet
  variables the snippet references are **auto-created when missing** (never overwritten),
  so pasted rows compile immediately. Baked codegen templates keep addon ACEs compiling
  without the addon installed; the paste status lists the providers the snippet uses.
- Implemented in `EventSheetSnippet` (documented serialization schema, versioned for
  forward compatibility); covered by `tests/snippet_share_test.gd` (17 assertions).

### GDScript inside the event flow (C3 inline scripting) + lint/completion
- **GDScript blocks can now live inside an event's actions.** Right-click an event →
  **"Add GDScript Action"**: the block renders line-by-line in the action lane (with a
  `GDScript` origin label and value highlighting), moves/deletes/drags as one action, and
  **compiles indented inside the event body** (under the condition `if`), with a provenance
  source-map entry. Disabled blocks are skipped.
- **Compile-check linting** in the block editor: the snippet is validated in a scratch
  script that extends the sheet's **host class** and stubs the sheet's
  **variables/functions**, so `health += 5` and `move_and_slide()` lint clean while broken
  code is flagged (✓/✗ status under the editor, live on every change).
  (`EventSheetGDScriptLint`; Godot doesn't expose the full ScriptEditor analyzer to
  plugins - this is the documented approximation.)
- **Completion**: Ctrl+Space in the block editor offers sheet variables, sheet functions,
  and host-class members; GDScript syntax highlighting in the dialog.
- Covered by `tests/inflow_gdscript_test.gd` (13 assertions).

### Zero-config ACE addons (C3-addon form, no JSON)
- **Drop a script into `res://eventsheet_addons/` and it becomes a project-wide ACE addon
  automatically** - no manifest, no JSON, no per-sheet setup (`EventSheetAddonScanner`,
  recursive, additive to existing providers/default vocabulary). Metadata derives from the
  script: provider name from `class_name`, addon description from the top `##` doc comment,
  per-ACE customization via `@ace_*` annotations.
- **New annotations**: `@ace_display_template("Heal {amount} HP")` (row/picker text),
  `@ace_codegen_template("health += {amount}")` (generated code), and
  `@ace_param_hint(amount expression)` (params-dialog field kinds: expression ƒx,
  variable_reference dropdown…).
- **Custom ACEs now genuinely compile**: codegen templates are baked onto created
  conditions/actions (`codegen_template` export on `ACECondition`/`ACEAction`, honored by
  `ConditionCodegen`/`ActionCodegen` ahead of the descriptor registry - previously
  reflection ACEs had no codegen path at all). Negation wraps baked templates correctly.
- Shipped `eventsheet_addons/demo_health_addon.gd` as the sample addon
  (documentation-by-example); ACE Providers dialog mentions the zero-config folder.
  Covered by `tests/ace_addon_test.gd` (15 assertions).

### GDScript provenance panel (pairing flagship)
- **Click an event, see its GDScript.** The compiler now returns a `source_map`
  ({uid, start, end, kind} with 1-based line ranges; kinds: event / raw / variable /
  function) alongside the output. The new **GDScript** toolbar toggle opens a read-only
  side panel (lazily-built HSplitContainer, line numbers + syntax highlighting) showing the
  generated script; **selecting any sheet row highlights and scrolls to the exact lines it
  compiles to**, and the panel live-refreshes after every edit. Selecting a
  condition/action highlights its event's range; Copy button exports the script.
- Trigger output is byte-identical (the source map is metadata only); covered end-to-end by
  `tests/provenance_test.gd` (13 assertions).

### GDScript pairing batch + spec overhaul
- **Inline GDScript blocks.** Right-click → "Add GDScript Block Below" inserts a
  `RawCodeRow` that renders line-by-line with a `GDScript` badge, moves like any row,
  double-click opens a CodeEdit dialog, and compiles **verbatim at class level** (helper
  funcs, `@onready` vars, signals). Disabled blocks are skipped.
- **Codegen tooltips**: hovering any condition/trigger/action shows the GDScript it
  compiles to (codegen template with parameter values substituted).
- **Expressions are GDScript**: expression fields are explicitly labeled/tooltipped as
  plain GDScript (no DSL).
- **C3 search synonyms** in the ACE picker: "on start of layout"→ready, "every tick"→
  process, "spawn"→instantiate, "destroy"→queue_free, etc.
- **New semantic theme tokens** (previously hardcoded): `invert_marker_color`,
  `object_label_color`, `value_highlight_color`, `cell_hover_color`.
- **Specs**: `EDITOR-UI-SPEC.md` gains an Interaction Contract, a C3 parity matrix, and a
  refreshed roadmap; `EVENTSHEET_THEME_TOKEN_SPEC.md` rewritten with defaults, the
  stability contract, and the Godot editor-theme adapter mapping; new
  `docs/GDSCRIPT-PAIRING-SPEC.md` (guarded by docs_integrity_test).
- Tests: `tests/gdscript_pairing_test.gd`; updated a stale flat-row-count assert for the
  footer rows.

### C3 easy wins: footer add rows, red ✗ invert marker, drop-line arrows, drag ghost (overhaul)
- **"Add event…" footer rows, C3-style.** The sheet ends with a muted "+ Add event…" row and
  every group keeps a "+ Add event to '<group>'…" row as its last child (one level deeper).
  Clicking opens the event picker and the new event is appended into that group / the sheet
  end. Footers are inert affordances: no selection, no context menu, never box-selected, and
  no model resource behind them. Covered by `tests/footer_rows_test.gd`.
- **Inverted conditions show C3's red ✗** (`#FF0000`, bare glyph - no circle behind it).
- **Drop lines have arrowheads at both ends** (row + ACE drags), mirroring C3's insert marker.
- **Drag ghost**: while dragging rows/conditions/actions over a target, a faint (~0.66 alpha)
  label of the dragged content follows the cursor, C3-style.

### C3 visual parity pass: crisp zoom text, solid cell blocks, value highlights, Godot-native theme (overhaul)
- **Text is crisp at every zoom level.** Zoom scales the canvas transform, which blurred
  (zoom-in) or aliased (zoom-out) glyphs rasterized at base size. All renderer text now draws
  at its final physical pixel size in identity space (`_draw_text`), then the zoom transform is
  restored - geometry scales, text stays sharp.
- **Construct 3-style contiguous cells.** Condition/action cells now fill their full line
  (1px hairline), so stacked conditions read as one solid block instead of floating bubbles.
- **Parameter values highlighted in ACE text** (C3-style): numbers, quoted strings, and
  booleans inside condition/action text draw in the value colour (ranges precomputed at span
  build, so the draw path stays cheap).
- **"+ Add action"** (was "+ Add"): muted C3-style affordance on its own line.
- **Godot-native default theme.** Sheets without an explicit theme adopt the running editor's
  colors (base/dark/accent/font via `EventSheetGodotTheme.adapt_to_editor`), so the sheet looks
  part of Godot and follows the user's editor theme. No-op outside the editor (tests stay
  deterministic); explicit sheet themes are untouched.
- Updated 3 legacy layout asserts that still encoded the old same-line "+ Add" placement.

### Collective disable + disabled-row strikethrough (overhaul)
- **Disable/enable the whole current selection at once** with the `X` key - works on a single
  condition/action/event or a multi-selection (disables all if any are enabled, else enables
  all). Covered by `tests/disable_selection_test.gd`.
- **Disabled rows now show a strikethrough**, matching disabled ACEs - so a disabled event,
  group, or comment reads as "commented out", not just dimmed.
- Confirmed (and locked with `tests/subevent_selection_test.gd`) that selecting a sub-event
  does **not** select its parent, while selecting a parent cascades to its sub-events.

### Inline-edit, comment alignment, empty-event & nesting spacing (overhaul)
- **Double-clicking a comment or group name now edits it.** `_begin_edit` falls back to the
  row's first editable span when the click lands on a non-editable part (badge/icon/padding),
  so editing starts from anywhere on a comment/group row, and commits update the resource.
  Covered by `tests/inline_edit_test.gd`.
- **Comments align with the event blocks they annotate** - comment text is indented past the
  trigger/badge column so it lines up with where condition text begins.
- **An event with no conditions shows a clear "Every Tick" cell** in the condition lane (it
  used to be bare text), so deleting the last condition leaves a visible empty event block.
- **Tighter nesting spacing**: a small gap is inserted before event/group blocks that start a
  new sibling/parent-level row, while a parent and its sub-events stay tight - so it reads at a
  glance which events are nested.

### Condition add/delete + "+ Add" placement fixes (overhaul)
- **Adding a condition no longer overwrites an existing trigger.** `append_condition` only
  fills the trigger slot when the event has none; a trigger-type ACE added to an event that
  already has a trigger (e.g. "Every tick") is appended as a condition instead of replacing it.
- **Conditions can be deleted down to zero** (an event may have no conditions - it reads as
  "every tick"). Verified by `tests/condition_edit_test.gd`.
- **"+ Add" on the action lane is now left-aligned on its own line** below the actions, so it
  stays visible at any window width (it was pinned to the lane's far-right edge and scrolled
  off-screen unless the editor was very wide). Line-count math updated to match.

### Comments nestable as sub-events (overhaul)
- **Comments can be nested inside an event as sub-events**, so a comment can describe the
  events beneath it and align under them. Right-click an event → **"Add Comment Sub-Event"**,
  or drag an existing comment onto an event (drop-inside). Nested comments render indented at
  the child level. Covered by `tests/comment_nesting_test.gd`.

### Tree-placed variables (overhaul)
- **Variables can now live in the event tree and be moved like events/comments.** A right-click
  on a row offers **"Add Variable Below"**, which drops a variable directly after that row
  (between/above/under events, inside groups). These tree variables render as variable rows,
  reorder with the normal row drag, are edited via the variable dialog (double-click), and
  compile to class-level declarations honouring the const / private-vs-`@export` flags.
  Implemented by making `LocalVariable` placeable in `sheet.events`; the compiler collects them
  recursively. Covered by `tests/tree_variable_test.gd`. (Sheet-level *global* variables still
  live in their pinned top section.)

### Reorder + variable access toggle (overhaul)
- **Dragging a condition/action to reorder it now works vertically.** The drop position
  (before/after the target cell) was decided by the horizontal cursor position, but cells
  stack vertically - so swapping the top/bottom cell never registered. It now uses the
  vertical position. Covered by `tests/ace_reorder_drag_test.gd` (full press→drag→release).
- **Global variables have a private/global access toggle.** The variable dialog now offers
  "Global (@export - usable outside the script)"; off compiles the variable to a plain
  private `var`, on to `@export var`. Local variables stay private. Covered by
  `tests/variable_export_test.gd`.

### Selection / hover / drag-preview correctness (overhaul - visual)
- **Clicking a condition/action now selects just that cell, hover now shows, and the drag
  drop-line appears** - all three were the same bug: the row layout is cached by geometry, but
  selection, hover, and drag-target state were baked into the cached dict while the cache key
  ignored them. So after a click/hover/drag the renderer read stale state - the whole event
  highlighted instead of the clicked cell, hover never appeared, and the ACE drop-line never
  drew. Selection/hover are now refreshed on every cache read; drag state is part of the cache
  key. Guarded by `tests/layout_state_test.gd`.
- **Clicking outside a cell selects the whole event.** The full-cell click fallback is now
  bounded to the lanes, so clicking the gutter / indent margin selects the event block, while
  clicking a condition/action cell (incl. its padding) selects that ACE.

### Drag-to-resize lane + hover/drag polish (overhaul - visual)
- **Drag the conditions/actions divider to resize the lanes**, C3-style. Hovering the divider
  shows a horizontal-resize cursor; dragging updates the split live and persists the ratio
  onto the sheet's editor style (a default-themed sheet is promoted to a concrete style so it
  saves). The pinned column header tracks the new divider position. Guarded by
  `tests/lane_resize_test.gd`.
- **Per-cell hover.** Hovering a condition or action highlights just that individual cell (a
  clear neutral light tint), not the whole event block - the whole-event highlight read as
  "selected" and was confusing. Whole-row hover remains for single-cell group/comment/variable
  rows.
- **Sub-event drop preview is indented.** Dragging an event so it nests inside another now
  draws the drop line at the child indent level, making "becomes a sub-event" unambiguous.

### Interaction + aesthetic fixes (overhaul - visual)
- **Dragging individual conditions/actions/events now works** (and shows its drop preview).
  The mouse-press that starts an ACE/row drag was not `accept_event()`'d, so the viewport
  stopped receiving motion/release - the drag never tracked and the drop indicator never
  drew. It now accepts the event on drag start. The drop logic (reorder within an event, move
  across events, Ctrl-to-copy) is covered by `tests/ace_drag_test.gd`.
- **Whole condition/action cell is now the click target.** Clicking anywhere on a
  condition/action line (the padding to the right of the text, or the vertical gaps between
  cells) now selects that ACE instead of falling back to selecting the whole event - fixing
  the "it selects the whole event" and "sometimes the action won't select" confusion. Guarded
  by `tests/hit_test_test.gd`.
- **Flat C3/GDevelop-style cells** replace the rounded "bubble" chips: conditions/actions are
  now flat rectangular cells with a subtle fill, a tinted hover fill, and a left accent bar +
  fill when selected (no rounded borders).

### Row rendering fixes (overhaul - visual)
- **Construct 3-style object labels.** Each condition/action/trigger now shows the object it
  acts on before the text (e.g. `System  Is on floor`, `System  Move and slide`) - "System"
  for Core ACEs, the node class for node-typed ACEs - matching the C3 event grammar. Added as
  span metadata (`object_label`) drawn in object colour by the renderer, so span structure
  (and the tests keyed on it) is preserved.
- **Fixed overlapping text on variable / group / comment rows.** Non-event rows fell through
  all of the viewport's span-positioning branches, so every span was placed at the same X and
  rendered on top of each other (e.g. `hp` + the `global` badge drew as `hpglobal`). These
  rows now flow their spans left-to-right.
- **Fixed group-name clipping**: group titles are drawn one font size larger than they were
  measured, so long names (e.g. "Gameplay") were cut off ("Gamepla"). `_measure_span_width`
  now matches the renderer's group-title size.
- Added `tests/row_layout_test.gd` (asserts single-line row spans don't overlap) and a dev
  render harness `tools/render_preview.gd` (renders the viewport to a PNG for visual review).

### GDScript importer - structural round-trip (overhaul - Phase 7)
- **Import GDScript back into an EventSheet.** `GDScriptImporter.import_source/import_script`
  parses the `extends` host class, top-level `@export var`/`var` declarations (with typed
  defaults, via `VariableParser`), and `func` signatures (name + typed params + verbatim
  body, via `FunctionParser`). Each function becomes an `EventFunction` whose body is kept
  as a `RawCodeRow` passthrough.
- **Round-trips through the compiler**: `SheetCompiler._emit_event_body` now emits
  `RawCodeRow.code` verbatim, so an imported sheet re-compiles to the same extends /
  variables / function signatures / bodies (trigger output and the demo golden are
  unaffected - the demo has no raw rows).
- _ACE-level reverse mapping (turning generated `if`/action lines back into conditions and
  actions) is intentionally future work; bodies are preserved as raw code for now._
- **Tests**: `tests/importer_test.gd` covers host-class, typed-variable, and function
  parsing plus the structural round-trip back through the compiler.

### Multiple EventSheet tabs (overhaul - Phase 6)
- **The editor now holds several open sheets at once.** A `TabBar` above the canvas lists
  open sheets; clicking a tab swaps that sheet into the shared virtualized viewport. Each
  tab keeps its own path and **independent dirty state** (shown as a `●` marker on the tab).
- `EventSheetDock` keeps `_current_sheet`/`_current_sheet_path`/`_dirty` as the *active*
  tab's live state (so all existing code is unchanged) and layers a `_open_tabs` list on
  top. `setup()` now opens a sheet in a tab - reusing the existing tab if that sheet is
  already open - and `_refresh_title_strip()` keeps the active tab's persisted state +
  title in sync. Closing a tab activates a neighbour (or a fresh demo when none remain).
- Public API: `get_open_tab_count`, `get_active_tab_index`, `activate_tab`, `is_tab_dirty`.
- **Tests**: `tests/multi_tab_test.gd` covers open/add, re-open de-duplication, per-tab
  dirty isolation across switches, sheet restoration, and close-activates-neighbour.

### Sheet functions (overhaul - Phase 5)
- **`EventFunction` resources now compile to GDScript methods.** `SheetCompiler` emits each
  enabled function as `func <name>(<typed params>) -> void:` with its events compiled into
  the body (empty functions emit `pass`), after the trigger handlers. The condition/action
  body emission was factored into a shared `_emit_event_body` so triggers and functions use
  the same code path (trigger output is byte-identical - no compiler regression).
- **Call-as-action**: new built-in `Core / CallFunction` action ("Call Function") with
  template `{function_name}({args})`, so an event action can invoke a sheet function
  (`do_thing(5)`, `reset()`).
- **Tests**: `tests/sheet_function_test.gd` covers typed-param signature emission, body vs
  `pass`, and the Call Function codegen (with and without args).
- _Authoring UX (a dedicated function-body editor) is deferred; the data model, compiler,
  and call action are in place._

### Sub-event authoring - indent / outdent (overhaul - Phase 4)
- **Reparent events with the keyboard**: **Tab** nests the selected event under the event
  directly above it (moves it into that event's `sub_events`); **Shift+Tab** un-nests a
  sub-event back out to its parent's container, just after the parent. Tab is only consumed
  when the move actually applies, so normal focus traversal still works otherwise.
- New dock handlers `_indent_selected_event` / `_outdent_selected_event` (undoable +
  dirty-tracked) with a `_find_parent_event` resolver, building on the existing
  `_find_resource_location` / sub-event rendering (events already render nested with
  indentation; "Add Sub Event" already exists in the row context menu).
- **Tests**: `tests/sub_event_authoring_test.gd` asserts indent nests under the preceding
  event, outdent restores it after the parent, and both no-op safely at boundaries.

### Custom ACE providers (overhaul - Phase 3)
- **Register your own scripts as ACE sources**: `EventSheetResource` gained an
  `ace_provider_scripts: Array[String]` field. Each registered GDScript is instantiated and
  reflected (via the existing `EventSheetACEGenerator`) so its annotated methods, signals,
  and exported variables appear in the ACE picker as conditions / actions / triggers /
  expressions, grouped under the script's provider id.
- **Dock pipeline**: `EventSheetDock` now builds the live ACE registry from the sheet's
  provider scripts (`_build_sheet_ace_sources` / `_instantiate_provider_script`), falling
  back to the demo source when none are registered. Externally supplied sources
  (`set_auto_ace_sources`) are kept separate (caller-owned, not freed).
- **Management UI**: a new "ACE Providers…" toolbar button opens a dialog listing the
  sheet's providers with Add… (GDScript file picker) / Remove. Public API:
  `add_ace_provider_script`, `remove_ace_provider_script`, `get_ace_provider_scripts`
  (undoable + dirty-tracked). Hot-reloads the picker on change.
- **Tests**: `tests/custom_ace_provider_test.gd` registers a fixture provider and asserts its
  method/signal/property ACEs surface in the registry (and disappear on removal).

### Theme switcher + token coverage (overhaul - Phase 2)
- **Toolbar theme switcher**: an `OptionButton` ("Theme:") listing **Default** plus the
  bundled themes discovered by the new `EventSheetThemePresets`
  (`addons/eventsheet/theme/event_sheet_theme_presets.gd`), which scans
  `res://addons/eventsheet/themes/` and `res://demo/themes/` for `EventSheetEditorStyle`
  resources. Selecting a preset applies it to the current sheet (Default restores the
  built-in palette look); the selection reflects the sheet's active theme on load.
  The existing "Load Theme…" (custom file) and "Reload Theme" buttons remain.
- **Column header is now themed**: added `column_header_background_color`,
  `column_header_conditions_color`, and `column_header_actions_color` tokens to
  `EventSheetEventStyle`; `SheetColumnHeader` resolves them via the new
  `EventSheetViewport.get_event_style()` (with palette fallbacks), so the header respects
  the active theme instead of hardcoded colours.
- **Tests**: `tests/theme_presets_test.gd` verifies preset discovery (all 4 bundled themes
  load as `EventSheetEditorStyle`), name humanization, the new header tokens, and that a
  bundled theme still resolves its event/condition/action styles.

### Construct 3-style ACE picker (overhaul - Phase 1)
- Rebuilt `ACEPickerDialog` (`addons/eventsheet/editor/ace_picker.gd`) as a grouped,
  colour-coded picker matching `EDITOR-UI-SPEC.md` §2.1:
  - **Node-type grouping**: entries group by `ACEDefinition.metadata.node_type` (forwarded
	from built-in descriptors) when set, otherwise by category.
  - **Group colour-coding**: node-type sections amber, Run Context / Triggers / Signals
	teal-green, Variables muted blue, Custom ACEs purple, others neutral.
  - **Per-item type colours**: trigger = green, condition = blue, action = teal,
	expression = purple; a `Type` column reinforces it.
  - **Type-labelled tooltips**: prefixed with the ACE type, e.g. `[Condition]  Is on floor`.
  - **Pre-declared event sections** (`EVENT_PICKER_GROUPS`: CharacterBody2D, Area2D, Node2D,
	RigidBody2D, Timer, AnimationPlayer) shown at the top in event-creation modes; while
	searching, empty sections are hidden so only matching groups remain.
  - **Mode-specific title + header** (Add Event / Add Sub-Event / Add Condition /
	Add Action / Replace …) in the window chrome and body.
  - Provider-aware item labels (built-in `Core` ACEs show just their name; custom-provider
	ACEs append the provider).
- **Tests**: `tests/ace_picker_logic_test.gd` covers the grouping/colour/mode/title/tooltip
  logic headlessly (without opening the popup window).

### Construct 3-style ACE parameter & expression dialog (overhaul - Phase 1)
- Rebuilt `ACEParamsDialog` (`addons/eventsheet/editor/ace_params_dialog.gd`) per
  `EDITOR-UI-SPEC.md` §2.2:
  - **Parameter descriptions** now render below their control (not just as a tooltip).
  - **Variable-reference params** (`hint == "variable_reference"`) render a dropdown of the
	sheet's variables (provided by the dock via a callable). When no variables exist, a
	disabled "No variables available" field is shown, **OK is disabled**, and the hint tells
	the user to add a variable first.
  - **Expression params** (`hint == "expression"`) render an inline `ƒx` button that opens
	an **Insert Expression** picker (EXPRESSION ACE definitions, grouped by node type and
	colour-coded like the main picker). Selecting one inserts its code template with default
	params substituted into the field.
  - **◀ Back** button (shown only when the dialog was opened from the picker) returns to the
	picker with the original mode/context, via a new `back_requested` signal handled by the
	dock.
- `EventSheetDock` now passes the ACE registry + a sheet-variable-name provider into the
  dialog and wires the Back flow (`_on_ace_params_back_requested`,
  `_collect_sheet_variable_names`).
- **Tests**: `tests/ace_params_logic_test.gd` covers expression-template substitution,
  variable-name resolution, back/re-edit flags, hint text, and value extraction headlessly.

### Construct 3-style column header (overhaul - Phase 1)
- Added a pinned **Conditions / Actions** column header (`SheetColumnHeader`,
  `addons/eventsheet/editor/sheet_column_header.gd`) above the scrolling sheet. It mirrors
  the event rows' lane divider (zoom + horizontal-scroll aware) so the two-column grid reads
  from the header straight down through every row.
- Exposed the lane geometry on the viewport: `EventSheetViewport.get_lane_divider_x(width)`
  (now the single source for both row layout and the header), plus `get_canvas_logical_width()`
  and `get_horizontal_scroll()`. The header sits outside the scroll container, so the scroll
  still has a single child (viewport).
- **Tests**: `tests/column_header_test.gd` guards the lane-divider math (the alignment
  contract) and header binding/band reservation headlessly.

### Keyboard authoring workflow (overhaul - Phase 1)
- Completed the `EDITOR-UI-SPEC.md` §2.4 keyboard map in the dock's `_unhandled_key_input`,
  adding the missing shortcuts: **Ctrl+Shift+S** (Save As), **Ctrl+E** (Add Event),
  **Ctrl+Shift+V** (Add Variable), **Ctrl+Shift+C** (Add Condition), **Ctrl+Shift+A**
  (Add Action), **Q** (Add Comment), **G** (Add Group), **Ctrl+D** (Duplicate Event) -
  alongside the existing Ctrl+C/V/S/Z/Y/O, Delete, Enter/F2.
- New dock handlers `_on_add_comment_requested`, `_on_add_group_requested`,
  `_on_duplicate_requested` (deep-clone + fresh `event_uid` via `_assign_fresh_event_uids`),
  all routed through the existing undoable-edit + insert-below-selection pipeline.
- **Text-field guard**: a `_text_field_has_focus()` check suppresses authoring shortcuts
  while a `LineEdit`/`TextEdit`/`SpinBox` owns focus, so typing never triggers actions.
- **Tests**: `tests/keyboard_actions_test.gd` drives the handlers and asserts add-group,
  add-comment, duplicate-no-op-without-selection, and duplicate-with-fresh-uid behavior.

### Large-sheet load performance (overhaul - virtualized build)
- **Cached built-in ACE descriptors** in `ACERegistry`: `get_all_descriptors()` /
  `find_descriptor()` previously rebuilt and re-normalized the entire built-in set on
  every call (a hot path when rendering sheets that reference fallback/unknown ACEs).
  Built-ins are now normalized once and indexed for O(1) lookup. Added `clear_cache()`.
- **Lazy event-row spans**: event rows now build their (expensive) visual spans on demand
  - only when laid out, hit-tested, or selected - instead of eagerly for the whole sheet.
  Row heights/metrics are derived up front from a cheap precomputed line count
  (`EventRowData.line_count`, `EventSheetViewport._count_event_lines()`), so the full sheet
  is measured without building any spans. Sheets with ≤ `EAGER_SPAN_LIMIT` (1500) rows
  still build eagerly, so small-sheet behavior is unchanged.
- **Result**: loading a 10,000-event sheet dropped from ~19,050 ms to ~370 ms (~52×).
  Scrolling already drew only the visible row range; now the build is virtualized too.
- **Box selection** now culls rows by the cheap precomputed metrics before building
  layout, so a box drag never builds layout/spans for the whole sheet.
- **Tests**: `tests/event_lazy_spans_test.gd` guards the line-count↔span invariant across
  event shapes plus the lazy/eager and hit-test/selection-trigger behavior;
  `tests/perf_smoke_test.gd` guards the 10k-row load budget + virtualization invariants;
  `tests/run_perf.gd` runs these headless-safe checks.

### Editor architecture consolidation (overhaul - Phase 0)
- Removed the parallel Control-widget editor prototypes (`EventRowUI`, `GroupRowUI`,
  `CommentRowUI`, `VariableRowUI`, `SheetToolbar`) and the unimplemented stub files
  (`ACEPalette`, `ActionPicker`, `ConditionPicker`, `DualViewSwitcher`, `ElseRowUI`,
  `ExpressionEditor`, `GDScriptPanel`) from `addons/eventforge/editor/`. The custom-rendered
  **virtualized viewport** (`EventSheetDock`/`EventSheetViewport`/`EventRowRenderer`) is now
  the sole editor architecture - it is the only model that scales to tens of thousands of
  events/ACEs without killing editor performance.
- Extracted the removed widget's variable-row text formatting into a standalone, reusable
  `VariableRowFormat` helper (`addons/eventsheet/editor/variable_row_format.gd`); retargeted
  `variable_row_format_test.gd` to it.
- Added `tests/perf_smoke_test.gd`: builds a 10k-event sheet and guards the virtualization
  invariants (no per-row widgets, bounded visible draw window, O(n) build budget).
- Re-anchored `docs/EDITOR-UI-SPEC.md`, `AGENTS.md`, and
  `docs/EVENTSHEET_ARCHITECTURE_SLICES.md` to the single virtualized architecture.

### ACE picker discoverability improvements (issue #54 – slice 2)
- **Live search/filter in ACE picker**: A `LineEdit` search box (`ACEPickerSearch`) added
  below the picker title.  Typing filters visible entries by list name, description, or
  node type in real time.  Pre-declared empty group headers are hidden when a filter is
  active so only groups with matches appear.  Clearing the search box restores the full
  grouped list.  Stored picker flags (`_ace_picker_include_triggers/conditions/actions`)
  allow the search handler to re-populate with the correct mode filters.
- **Per-item ACE type colour-coding**: Each entry in the picker tree is now tinted by its
  ACE type (triggers = soft green, conditions = soft blue, actions = soft teal) via the
  new `_get_picker_item_color()` static helper.  Group headers retain their existing
  colour scheme; item tints are deliberately softer to avoid visual conflict.
- **Type-labelled tooltips**: Picker item tooltips now carry an ACE type prefix
  (`[Trigger]`, `[Condition]`, `[Action]`) from the new `_get_ace_type_label()` helper,
  giving an at-a-glance type signal without touching the item label text.
- **Expanded built-in node-type ACEs**: Fourteen new Core ACEs added with `node_type` set
  so they appear in the correct class section in the picker:
  - `Node2D` - `SetPosition2D` (action), `SetRotationDeg` (action)
  - `CharacterBody2D` - `MoveAndSlide` (action), `SetVelocity2D` (action)
  - `Area2D` - `OnAreaEntered` (trigger)
  - `RigidBody2D` - `ApplyCentralImpulse` (action)
  - `Timer` - `StartTimer` (action), `StopTimer` (action), `IsTimerStopped` (condition),
	`OnTimeout` (trigger)
  - `AnimationPlayer` - `PlayAnimation` (action), `StopAnimation` (action),
	`IsAnimationPlaying` (condition), `OnAnimationFinished` (trigger)
- **Expanded `EVENT_PICKER_GROUPS`**: `Node2D`, `RigidBody2D`, `Timer`, and
  `AnimationPlayer` added to the pre-declared group list so their sections are always
  present at the top of the "Add Event" picker (node-type groups precede logical
  categories).
- **Tests**: Added assertions for all new built-in node-type groups, per-item colour
  helper, ACE type label helper, and search filter behaviour (filter match + empty-filter
  group count).
- **Docs**: Updated `EDITOR-UI-SPEC.md` section 2.1 and `SPEC.md` section 7 to document
  the search box, per-item colouring, type-labelled tooltips, expanded built-in ACE set,
  and updated pre-declared group list.

### Workspace shell polish (issue #59 – slice 4)
- **Central split composition**: Replaced fixed `HBox + VSeparator` canvas/inspector
  layout with a named `HSplitContainer` (`WorkspaceSplit`) so the editor body reads
  as a dedicated workspace split surface.
- **Canvas resource-tab framing**: Added `SheetCanvasResourceTab` inside
  `SheetCanvasDocumentStrip` so active sheet title + dirty state are framed as an
  editor-style document tab rather than plain strip labels.
- **Inspector surface flattening**: Inspector shell now uses square-corner framing to
  better match the main workspace/editor shell composition.
- **Tests/docs**: Extended workspace-shell and editor tests to assert split-shell and
  resource-tab presence, and updated editor UI spec for the new framing model.

### Workspace document framing improvements (issue #59 – slice 3)
- **Toolbar resource-path context**: Added a dedicated path hint label in the toolbar
  top row so the currently opened EventSheet resource path is always visible.
- **Canvas document strip**: Added `SheetCanvasDocumentStrip` at the top of the main
  canvas surface to provide document-like framing in the editor body:
  - `EventSheetResource` kind tag
  - active document title
  - dirty indicator dot
  - full resource path / unsaved hint
- **Central surface composition**: Updated the main canvas shell from rounded utility
  card framing to a flatter document surface with a top strip + content body margin,
  making it feel more like a dedicated workspace document.
- **Tests/docs**: Added test coverage for toolbar path formatting and new document-strip
  presence, and updated the editor UI spec with path/document-strip behavior.

### Workspace shell improvements (issue #59 – slice 2)
- **Toolbar flush at top**: Removed the 8px outer margin that wrapped the toolbar.
  The toolbar now spans the full workspace width with zero margin above or beside it,
  matching the Godot Script editor layout rather than a dock widget.
- **Status bar at bottom**: Added a full-width `PanelContainer` status bar at the very
  bottom of the workspace (thin, 1 px top border). All operation feedback messages
  (save, compile, add/delete events/variables/groups) are now routed here via the new
  `_set_status()` helper rather than appearing in the toolbar header row.
- **Save / Save As**: Added `Save` and `Save As…` buttons to the toolbar action strip.
  - `Save` writes the current sheet to its existing resource path; falls back to Save As
	for unsaved in-memory sheets.
  - `Save As…` opens a FileDialog to pick a path; updates `resource_path` on success via
	`take_over_path()`.
  - Both are disabled when no sheet is loaded.
  - Keyboard shortcuts: `Ctrl+S` (Save), `Ctrl+Shift+S` (Save As).
- **Dirty state tracking**: `EventSheetEditor._is_dirty` is set by `_mark_dirty()` on
  every mutation (add/replace/delete events, conditions, actions, variables, groups,
  condition inversion) and cleared by `_clear_dirty()` on sheet load or successful save.
- **Dirty indicator (●)**: Amber dot `●` appears next to the sheet name in the toolbar
  top row when `_is_dirty` is true; hidden when the sheet is clean.  Controlled via the
  new `SheetToolbar.set_dirty(dirty: bool)` method.
- **Toolbar label rename**: Toolbar header label changed from `EventForge` to `EventSheet`
  to correctly identify the workspace type rather than the plugin brand.
- **Toolbar corner radius**: Set to 0 (flush top) to match the full-width flush-at-top
  layout; previously used a 6 px all-around radius that implied a floated card widget.
- **Tests**: New `tests/workspace_shell_test.gd` covers toolbar save signals, dirty
  indicator visibility, Save/SaveAs button enabled state, and `_mark_dirty` / `_clear_dirty` toggling.
- **Docs**: Updated `docs/EDITOR-UI-SPEC.md` section 2.4 to document the new shell
  structure, toolbar layout, save flow, dirty tracking, and keyboard shortcuts.

## [0.1.0] - 2026-05-15
- Initial EventForge Phase 1 scaffold.
- Added resource model, bridge, ACE registration, and Phase 1 compiler path.
- Added demo project, hand-authored sheet, golden generated output, and test harness.
