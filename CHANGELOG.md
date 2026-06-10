# Changelog

## [Unreleased]

### 3D behavior packs (starter quartet)
- **Sine 3D** (oscillate along x/y/z or around Y, full wave set), **Orbit 3D** (XZ-plane
  circling), **Bullet 3D** (launch along the host's forward with gravity + distance
  tracking, relaunchable), and **Move To 3D** (Vector3 waypoint queue + On Arrived) —
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
  annotation — or the **Tags field** in the Sheet Type dialog for sheet-built addons
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
  rows after any edit — F3 now recomputes matches on every step.
- **Closing one secondary pane reset the active view** even when the *other* pane was
  active; the reset is now conditional.
- **"Open in Split" silently did nothing** for rows inside folded groups in the split
  pane — it now unfolds and retries.
- **MCP server served stale sheets**: the long-lived server read `.tres` files through
  Godot's resource cache; reads now bypass the cache (`CACHE_MODE_IGNORE`).
- Known limitation surfaced by the sweep (deferred, by design of the flat-row model):
  Ctrl+F doesn't match rows hidden inside folded groups.

### Starter 3D vocabulary
- **14 native 3D ACEs** under their node-type groups: **Node3D** (Set Position/Rotation/
  Scale, Move By, Look At, position expression), **CharacterBody3D** (Is On Floor,
  Move And Slide, Set/Get Velocity), **RigidBody3D** (Apply Central Impulse), and
  **Camera3D** (Make Current, Set FOV) — plus the **Input Vector** expression
  (`Input.get_vector`, StringName idiom, InputMap dropdowns) for 2D and 3D movement
  alike.
- Tween, visibility/tint, math & random, scene flow, and audio were already
  dimension-agnostic; signal/collision triggers work on 3D nodes unchanged. The README's
  "2D-first" con is softened accordingly.
- Covered by `tests/native_3d_aces_test.gd` (7 assertions).

## [0.3.0] - 2026-06-10

The multi-view release: the same sheet in split panes, detached OS windows, and linked
follow-selection views — all full editors over one source of truth — plus experimental
tool sheets (`@tool` + EditorScript with the On Editor Run trigger: editor tooling
authored as events). Details below (newest first).

### Tool sheets (Phase D — EXPERIMENTAL): build editor tooling from events
- **`@tool` sheets**: a Sheet Type checkbox emits `@tool` ahead of
  `class_name`/`extends`, so sheet-built nodes and behaviors run inside the editor.
- **Editor Tool preset** (Sheet Type → "Editor Tool"): an `EditorScript` host paired
  with the new **On Editor Run** trigger — your events run from **File > Run**
  (Ctrl+Shift+X). Batch renames, scene generation, project chores: event-sheet style.
- Full citizen: generated tools **verify-lift back** (On Editor Run round-trips
  byte-identically) and `tool_mode` recovers when re-opening a generated `.gd`.
- Explicitly **experimental and editor-version-coupled** (editor APIs are Godot's most
  volatile surface — runtime ACEs stay on stable APIs only, per the covenant).
- Covered by `tests/tool_sheets_test.gd` (10 assertions).

### Multi-view complete: detached windows + linked panes (P2/P3)
- **Detach** (toolbar): a floating OS window hosting another full-editing pane over the
  same sheet — drag it to a second monitor while debugging. Same shared per-sheet state
  (breakpoints/bookmarks/disabled) and the same refresh bus as the split pane.
- **Link** (toolbar): follow-selection across panes — selecting a row in any pane
  scrolls/selects it in the others. Keep the split zoomed out as an overview and click
  rows to focus them in your detail pane (recursion-guarded; unlink any time).
- With Split (P1) + full dual-pane editing (P1.5), the multi-view arc from the spec is
  **complete**. Covered by the extended `tests/multi_view_test.gd` (21 assertions).

### Multi-view phase 1.5: both panes are full editors
- The split pane graduated from read-only companion to a **full editor**: double-click
  edits, dialogs, drag/drop, context menus, find — everything works in either pane (the
  dock's handlers are payload-driven, so one handler set serves both).
- **Active-view routing**: selection-driven toolbar ops (copy/paste, Ctrl+/, Alt+arrows,
  Add Condition/Action, quick-add anchors) follow the **last-focused pane**; closing the
  split falls back to the primary.
- **"Open in Split"** (row context menu): pins the row in the other pane — opening the
  split automatically if needed — the "keep this visible while I work over there" move.
- Covered by the extended `tests/multi_view_test.gd` (14 assertions).

### Multi-view phase 1: split view (same sheet, two panes)
- A **Split** toolbar toggle opens a second pane over the SAME sheet (VSCode's
  one-file-two-editors gesture) — read a handler while editing the function it calls,
  keep a group pinned while debugging another.
- **Per-sheet state is shared by reference** (`EventSheetViewState`): breakpoints,
  bookmarks, and the disabled overlay agree across panes instantly. Scroll, zoom,
  selection, and folds stay per-pane.
- Every edit refreshes both panes (the refresh bus); the companion pane is
  read/navigate-only in phase 1 (inline editing stays in the primary — full
  active-view editing is the spec'd phase 1.5). Closing the split restores the layout.
- Covered by `tests/multi_view_test.gd` (10 assertions).

## [0.2.0] - 2026-06-10

Thirty-five features since 0.1.0 — the C3 coverage program (38 native-node ACEs, all 14
behavior packs with C3-capability parity), first-class rich variables (enums, collections,
combos, the Dictionary/Array/JSON ACE set), signals/match/input vocabulary, the importer's
function verify-lift, gutter bookmarks, sheet includes, find-in-sheet + script-editor
shortcuts, editor-theme inheritance + six iconic theme presets, color params with sheet
swatches, the MCP server, Export Addon Pack, drag-from-docks, scene-aware completion, and
the group-compile fix. Highlights below (newest first).

### Export Addon Pack, Godot-native affordances, README overhaul
- **Export Addon… (toolbar)**: one click turns the current behavior sheet into a
  published pack folder (`eventsheet_addons/<class_snake>/` — editable `.tres` +
  compiled `.gd`, no-drift rule honored, FileSystem rescanned) with guardrails for
  non-behavior sheets and invalid class names. The addon-builder loop is now fully
  in-editor: author behavior → annotate → Export → ACEs published project-wide.
- **Drag from the docks into ƒx fields**: drop a FileSystem file → its quoted `res://`
  path; drop a Scene-dock node → a `$Path` reference (relative to the edited scene,
  quoted automatically when the name needs it).
- **Scene-tree-aware completion**: `$Child.` now completes against the OPEN scene's
  actual nodes — script methods, signals, and class members — and direct children appear
  as `$Name` candidates in flat completion.
- **README rewritten** as a proper front door: honest pros & cons, current status,
  milestones table, and a quick start — kept current with every major update from now on.
- Covered by `tests/phase_c_affordances_test.gd` (12 assertions).

### Behavior packs aligned with their C3 capabilities
- **Sine**: seven movement types (horizontal, vertical, forwards-backwards, size, angle,
  opacity, value-only) and **five wave shapes** (sine, triangle, sawtooth,
  reverse-sawtooth, square) — both Inspector combos — plus phase, Update Initial State
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
  variable dialog, comma-separated). Exported combos compile to **`@export_enum`** — a
  real Inspector dropdown — and **verify-lift back** with their options intact
  (byte-identical round-trips). Guardrail: the default must be one of the options.
  The Sine pack's `movement` showcases it (horizontal/vertical/angle dropdown).
- **`@ace_param_options(param a, b, c)`** annotation: addon ACE params render as
  dropdowns in the params dialog — the C3 Combo for addon authors, zero config.
- **Sheet-enum-driven params**: the `enum:State` param hint offers the enum's members
  (`State.IDLE`, …) as a dropdown — combos backed by real enums.
- **Color params**: the `color` hint (or a Color-typed param) renders a **color picker**
  in the params dialog, values round-trip as canonical `Color(r, g, b, a)` literals, and
  **conditions/actions with a color param draw a small swatch** next to their text in
  the sheet (C3-style color preview). Set Color Tint now uses it.
- Covered by `tests/combo_color_test.gd` (15 assertions).

### Nine new behavior packs (C3 coverage, Phase B — all fourteen C3-style behaviors bundled)
- **Sine** (oscillate position/angle), **Orbit** (circle a point), **Bullet** (angle-of-
  motion movement with acceleration/gravity), **Move To** (glide to a point + On
  Arrived), **Follow** (smoothly trail a node path), **Drag & Drop** (mouse grab within
  a radius + On Drag Start / On Dropped), **Car** (accelerate/brake/steer, speed-scaled
  steering, `move_and_slide`), **Tile Movement** (grid stepping + On Step Finished), and
  **Line of Sight** (a raycast-backed *Has Line Of Sight To* condition).
- All built as event sheets through the established pack pipeline (`.tres` source +
  generated `.gd`, zero-config ACE publishing, behaviors attach as child nodes,
  properties in the Inspector) and guarded by the pack test's no-drift goldens,
  class-load, and publish assertions — the compatibility covenant in action.

### Native-node ACE providers (C3 coverage, Phase A)
- **38 new builtin ACEs wrapping native Godot features** — lane 1 of the C3 coverage
  program (the engine maintains the implementation; we maintain vocabulary):
  - **Tween Property** (Godot `create_tween` with transition/ease dropdowns — the C3
	Tween behavior's job, natively),
  - **Scene** group (Go To Scene, Restart Scene, Quit, Set Paused, Spawn Scene
	Instance, Is Paused — C3's layout actions),
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
  Nord, Gruvbox Dark, Monokai, Solarized Light, and Catppuccin Mocha** — every token
  mapped deliberately (conditions take the palette's cool accent, actions the
  warm/green, groups the signature color, comments the comment color; lanes get a
  whisper of their accent over the background).
- Generated by `tools/build_theme_presets.gd` (rerun after token additions); the
  existing presets (high-contrast, soft-light, C3-stacked, designer template) remain.
  All presets are load-verified by the style test.

### Signal rows + match rows (GDScript language parity)
- **Signals are first-class rows** (the enum-row treatment): add via the row menu
  ("Add Signal Below") or double-click to edit — name plus typed params one-per-line
  (`damage: int`). They compile canonically (after enums, before variables),
  **verify-lift** back from generated code (non-canonical formats stay blocks,
  byte-identical round-trips guarded), travel in **snippets**, feed the **On Signal /
  Emit Signal pickers**, lint (`hit.emit(3)` validates), and **validate custom-signal
  trigger connections** at compile time. Names/params pass the identifier guardrails.
- **Match rows** (C3's switch, GDScript's `match`): a structured action-lane row with an
  ƒx subject expression and branch text in real GDScript match-body syntax — enum members
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
  - Dot-completion now offers **signals** alongside methods/properties — typed
	variables (`zone.` → `body_entered`), behavior `host.`, and `$GlobalClass.`
	including script-declared signals (`$PlatformerMovement.` → `jumped`).
  - Signal params (On Signal, Emit Signal) render as a **dropdown** of the host
	class's signals plus signals declared in the sheet's GDScript blocks — pick,
	don't type. Custom values persist as the first option.
- Covered by `tests/signal_autocomplete_test.gd` (8 assertions) + updated input tests.

### Godot-feel batch: find-in-sheet, script-editor shortcuts, editor-theme inheritance
- **Ctrl+F find bar**: script-editor-style find-in-sheet (matches visible row text AND
  GDScript block code, case-insensitive); Enter/F3 next, Shift+F3 previous, Esc closes,
  with an "n of m" counter and wrap-around.
- **Script-editor shortcut conventions**: **F9** toggles breakpoints (Ctrl+B stays as an
  alias), **Ctrl+/** toggles the selected rows' enabled state — the "comment out" of
  event sheets — and **Alt+Up/Down** moves the selected row (reusing the drag machinery,
  fully undoable).
- **The sheet inherits your editor theme**: when no explicit theme is chosen, default
  visual tokens derive from the editor's base + accent colors (dark/light/custom-accent
  editors all match out of the box), and the initial zoom honors the editor display
  scale on hi-DPI. Theme presets and per-sheet themes still override.
- Covered by `tests/godot_feel_test.gd` (14 assertions).

### Input vocabulary + Wait/Await (Godot-familiarity batch 1)
- **Input ACE group** — the most-used trigger family finally has first-class vocabulary:
  Is Action Pressed / On Action Just Pressed / On Action Just Released conditions,
  Action Strength + Input Axis expressions, and **On Input / On Unhandled Input**
  lifecycle triggers (`_input(event)` / `_unhandled_input(event)`) that compile AND
  verify-lift back from generated code.
- **Action params are dropdowns read from the project's InputMap** (custom actions
  first, then the `ui_*` defaults) — pick real actions instead of typing strings.
- **Wait / Wait For Signal** actions (C3's System → Wait): compile to
  `await get_tree().create_timer(s).timeout` / `await <signal>` — handlers are implicit
  coroutines in GDScript, so awaiting mid-event is safe and idiomatic.
- Covered by `tests/input_time_aces_test.gd` (14 assertions).

### MCP server — AI tooling (the backlog's final item)
- **A pure-GDScript Model Context Protocol server** ships in the addon
  (`addons/eventsheet/mcp/`): the Godot binary itself is the server process — no
  Python/Node dependencies. Setup guide: `docs/MCP-SERVER.md`.
- Six tools for AI assistants: `list_sheets`, `read_sheet` (structured JSON of rows/
  variables/enums/functions; also opens any `.gd` as a sheet), `list_aces` (the full
  vocabulary incl. zero-config addons), `compile_sheet` (**dry-run by default**),
  `lint_block` (compile-check against sheet context), and `apply_snippet` (append rows
  from snippet text or plain GDScript via the lossless paste pipeline — the only
  mutating tool, `.tres`-only, append-only).
- Transport-free protocol core (`EventSheetMCPServer.handle_message`) covered by
  `tests/mcp_server_test.gd` (21 assertions); the stdio loop is a thin newline-delimited
  JSON-RPC wrapper (launch with `--headless --quiet`).

### Curated collection ACE set (rich-variables phase 3 of 3 — the 1.0 arc is complete)
- **27 ready-made Dictionary / Array / JSON ops** as builtin Core descriptors, grouped in
  the picker as **Variables: Dictionary** (Set/Delete Key, Clear, Merge, Has Key,
  Is Empty, Get-with-default, Size, Keys, Values), **Variables: Array** (Append, Insert
  At, Remove At, Erase, Clear, Sort, Shuffle, Contains, Is Empty, Value At, Size, Pick
  Random), and **Variables: JSON** (To/From JSON Text, JSON Is Valid, Save/Load JSON
  File — `user://` paths survive exports).
- Every op compiles to a **single direct GDScript line** (`inventory["sword"] = 1`,
  `scores.append(10)`, `JSON.parse_string(...)`) — parity-safe, reverse-lift-eligible,
  and the templates double as GDScript teachers. The long tail stays one ƒx away.
- **Type-aware variable dropdowns**: `variable_reference:Array` / `:Dictionary` hints
  filter the dropdown to matching variables (typed containers match their base;
  Variant/untyped always qualify) — with a clear "No Array variables — add one first"
  block when none exist.
- **C3 migration guide** gains a data-plugins table (Dictionary/Array/JSON addons → the
  Variables groups; XML → intentionally unsupported, use JSON).
- Covered by `tests/collection_aces_test.gd` (15 assertions). With enums (phase 1) and
  collection variables (phase 2), **the first-class rich-variables feature is complete**.

### Collection variables (rich-variables phase 2 of 3 — 1.0 scope)
- **Array and Dictionary variables are first-class**, including Godot 4 typed containers
  (`Array[int]`, `Dictionary[String, int]`, …) offered in the variable dialog's type list.
- **Defaults edit as GDScript literals** (`{"sword": 1}`, `[1, 2, 3]`) with a live ✓/✗
  hint while typing, and a commit guardrail: invalid literals never save (wrong container
  kind, garbage, or **element-type mismatches** against the declared `Array[T]` /
  `Dictionary[K, V]` — with int→float allowed, as in GDScript).
- **Canonical emission**: containers compile through a recursive, escape-correct,
  deterministic literal formatter (`{"k": 1, "nested": {"ids": [1, 2.5]}}`); editing an
  existing collection variable shows that same canonical literal.
- **Verify-lift round-trips**: canonical collection declarations in generated `.gd` files
  re-open as editable variable rows with their values intact; non-canonical formatting
  stays a verbatim block — byte-identical round-trips guarded.
- Covered by `tests/collection_variables_test.gd` (17 assertions).

### C3-familiarity batch: group descriptions, slow-click editing, rename refactoring, commit guardrails
- **Group events now actually compile** — the batch's tests exposed that events inside
  groups were silently dropped with a TODO comment (a long-standing compiler hole).
  Groups flatten inline at emission, with C3 semantics: **disabling a group drops all of
  its children from the compiled output**; group comments compile as comment lines.
- **Group descriptions** (C3-style): a muted, inline-editable second line on the group
  header (`EventGroup.description` — also via the row menu "Edit Group Description…");
  travels in snippets. Group titles were already double-click renameable.
- **Slow double-click editing** (Explorer-style): click an already-selected editable
  cell again after the double-click window (450–1600 ms) to start editing — comments,
  group names/descriptions, variable rows; multiline comments route to their dialog.
- **Variable rename refactoring**: renaming a variable rewrites every reference across
  the sheet — GDScript blocks (class-level, in-flow, function bodies), ƒx/string params,
  pick-filter expressions, and **baked codegen templates** (placeholders like `{amount}`
  are never touched). Whole-word matching; the status bar reports how many references
  updated. A rename can no longer silently break compiled code.
- **Commit-time guardrails** ("you can't enter broken stuff"): variable and enum names
  auto-correct where fixable (`my var` → `my_var`, digit-led names prefixed) and are
  **blocked with a clear message** when not (GDScript keywords); broken GDScript blocks
  never commit (the dialog reopens with your text intact); the params dialog refuses to
  apply while any ƒx expression fails its compile-check.
- Covered by `tests/ux_guardrails_test.gd` (29 assertions).

### First-class enums (rich-variables phase 1 of 3 — 1.0 scope)
- **Enums are sheet rows**: add via the row menu ("Add Enum Below") or double-click to
  edit (name + members, optional explicit values like `HURT = 4`). They compile to
  canonical class enums **before variables**, so `var state: State` works — and exported
  enum-typed variables get Godot's **Inspector dropdown for free**.
- Full citizen everywhere: rendered as keyword-badged rows; **verify-lifted** back from
  generated code (non-canonical/multi-line enums stay verbatim blocks; byte-identical
  round-trip guarded); travel in **snippets**; expressions referencing them **lint**
  correctly; `State.` **dot-completes the members** in ƒx fields and GDScript blocks;
  source-mapped for provenance.
- Scope decisions recorded: rich variables (collections UX + curated Dictionary/Array/
  JSON ACE set) are **required for 1.0**; **XML support is dropped** — JSON is the
  interchange format. Covered by `tests/enum_row_test.gd` (16 assertions).

### Inspector polish: widget_hint editors + per-row "Selected ACE" properties
- **widget_hint-specific inspector editors**: exposed ACE params with `widget_hint`
  (or an `@ace_param_hint`) now render custom controls in Godot's Inspector — `slider`/
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
  are skipped with warnings, and included rows never enter the editing model — a shared
  "library sheet" pattern. Ignored for GDScript-backed sheets. (Field retyped
  `Array[NodePath]` → `Array[String]`; it was never used or serialized before.)
- Covered by `tests/bookmarks_includes_test.gd` (18 assertions).

### Importer completed: function verify-lift + comment preservation (two-pass safe)
- **Sheet functions lift back** when opening generated `.gd` files: their `@ace_*`
  annotation blocks reverse into `expose_as_ace`/name/category/description, parameters
  parse with types, and bodies use the event grammar with **lenient ifs** — unmatched
  control flow becomes in-flow GDScript inside the event instead of failing the file
  (trigger bodies got the same upgrade). Codegen templates and icons are regenerated
  rather than stored (behavior identity — `class_name`, host, behavior mode — is now
  recovered from the prelude so `$Class.fn()` templates verify).
- **Trailing top-level comments lift** into comment rows; the external compile path now
  emits top-level comments (it silently dropped them before — found by the byte-verify).
- **Two-pass safety**: when the full lift can't verify byte-identically, the event-only
  lift retries, so these upgrades can never regress previously-lifting files. Also fixed
  a latent revert leak (the shallow backup left a boundary row's stripped newline behind
  after a failed verify, corrupting round-trips).
- End-to-end fixture: the shipped **PlatformerMovement pack re-opens fully** — events,
  exposed functions, annotations, comments — with only the `_enter_tree` host-binding
  scaffold staying a verbatim block (external emission keeps the prelude untouched by
  design). Covered by `tests/function_lift_test.gd` (13 assertions).

### Intellisense upgrades: dot-context completion, signature hints, quick-add bar
- **Dot-context completion** in GDScript blocks and ƒx fields: typing `host.` offers the
  host class's members, a typed sheet variable offers *its* class's members, and
  `$TimerBehavior.` offers that behavior's script methods + base-class members (resolved
  via ClassDB + the global class list). Unresolvable tokens offer nothing rather than
  guessing; non-dot contexts keep the flat sheet/host candidates. One shared choke point:
  `EventSheetGDScriptLint.completion_for_context`.
- **Signature hints**: while typing inside a call, the editor shows the signature —
  sheet functions from their declared params, host methods from ClassDB
  (`signature_hint`, displayed via CodeEdit's code-hint popup in both editors).
- **Quick-add bar** (toolbar): C3's "type to insert" — `every tick` creates the On
  Process event (synonym phrasing honored), `heal 5` applies the Heal action with
  `amount = 5` (trailing words fill parameters positionally). Ties prefer the most
  specific name ("process" picks On Process, not On Physics Process); unknown queries
  report and decline. Covered by `tests/intellisense_test.gd` (16 assertions).

### Three more behavior packs: Timer, Flash, State Machine
- **TimerBehavior** (host: any Node): Start Timer / Stop Timer ACEs, exported
  `duration`/`repeating`, and the **On Timer** trigger (repeats when repeating).
- **FlashBehavior** (host: CanvasItem): Flash / Stop Flash ACEs blink the host's
  visibility at an exported `interval` for a duration, restore it, and fire
  **On Flash Finished** — the C3 Flash behavior.
- **StateMachineBehavior** (host: any Node): Set State action, **On State Changed**
  trigger `(previous, next)`, and an **Is In State condition** authored as an annotated
  class-level GDScript block — the reference example for mixing expose-as-ACE functions
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
- Handlers with no connect entry (scene-wired) keep the whole file as verbatim blocks —
  the lossless byte-identical contract is unchanged and still gates every lift. This also
  upgrades paste-GDScript-as-events for pasted scripts containing signal handlers.
  Covered by `tests/signal_lift_test.gd` (13 assertions).

### Post-1.0 polish: pick filters compile, fx autocomplete, external-sheet watcher
- **Pick filters compile** — the last event-flow TODO is gone. C3's "for each" picking,
  the Godot way: each filter wraps the event body in a direct `for` loop over a node
  group / the children / any GDScript iterable, with an optional iterator-scoped `where`
  predicate and a first-N cap; conditions gate the loop and multiple filters nest. Pick
  rows render as "For each item in group \"enemies\"…" lines in the condition lane,
  author via the row context menu ("Add Pick Filter (For Each)…") and edit/delete via
  double-click. order_by and condition-based filtering warn honestly (predicate is the
  supported path). Plain loops — the performance-parity contract holds.
  Covered by `tests/pick_filter_test.gd` (17 assertions).
- **fx expression autocomplete**: expression fields are now single-line CodeEdits with
  completion popups (sheet variables, sheet functions, host members — the same candidate
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
	registers the demo actor as `EventSheetDemoGameplayActor` — the resolver now matches
	by name (and no longer depends on registry refresh order), so demo rows render
	"On Died"/"Take Damage 10" again;
  - non-event spans (comments/variables/blocks) clamp 2px tighter, accounting for the
	chip rect's expansion — long comments stay inside the row width at any zoom;
  - the context-menu test re-acquires live row data between undoable edits (snapshot
	restore replaces row resources; the old assertion toggled an orphan).
  Only the long-known harmless tail segfault remains (after the summary prints); CI now
  fails on ANY `[FAIL]`.
- **Paste GDScript → events**: pasting raw GDScript from anywhere converts through the
  open-as-sheet pipeline — trigger functions ACE-lift into real events, declarations
  become variable rows, everything else lands as verbatim GDScript blocks (the lossless
  rule). Non-code clipboard text falls through to the normal paste paths untouched.
  Covered by `tests/gdscript_paste_test.gd` (9 assertions).
- **C3 migration guide** (`docs/C3-MIGRATION-GUIDE.md`): concept map (behaviors, layouts,
  picking, expressions) + common System vocabulary table + habits that transfer vs.
  habits to relearn.
- **Perf re-baseline** (10,801 flat rows): sheet build ~490 ms, zero per-row widgets,
  visible draw window 8 rows — the virtualization contract holds post-1.0-features.

### 1.0 feature-complete: visual completeness, export integrity, theme editor, rename
- **The plugin is now "Godot EventSheets"** (plugin.cfg, README, release artifacts —
  internal class names keep the EventForge prefix as the engine codename). Release zips
  are now `godot-eventsheets-<v>.zip` / `godot-eventsheets-samples-<v>.zip`.
- **Comments reach C3 parity**: multiline comment rows (one cell per line, row height
  follows), **per-comment background colors**, a comment dialog (multiline text + color
  picker — double-click multiline comments or use "Edit Comment…"; single-line comments
  keep fast inline editing), and **comment ↔ action-cell conversion** ("Attach Comment To
  Event Above" / "Detach Comment To Row"). Action-cell comments render per line inside the
  action lane, edit via double-click, and **compile to `#` lines inside the body**;
  top-level comments also compile as real comment text (the last "TODO: row type" case for
  comments is gone). Covered by `tests/visual_completeness_test.gd` (13 assertions).
- **Export-integrity hook**: an `EditorExportPlugin` recompiles every event sheet when an
  export starts (loud per-sheet errors on failure; GDScript-backed sheets skipped — their
  `.gd` is already the truth). The same pass is a static headless API
  (`EventSheetExportIntegrityPlugin.recompile_all_sheets`), tested in CI.
- **Visual theme editor** (the final planned phase): toolbar "Theme Editor…" opens a live
  workbench — a real viewport rendering a sample sheet on the left, and a **reflectively
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
  `res://eventsheet_addons/` scans — static API (works without the autoload), deduped,
  unregister supported, `providers_changed` emitted.
- **Instance-backed addon ACEs**: addon *methods without* `@ace_codegen_template` used to
  compile to nothing; applying one now bakes a call through a per-provider member
  (`__eventsheet_provider_<Class>.method({args})`), and the compiler declares each used
  provider **once** as a plain owned instance (`var __… := Class.new()`). Template-less
  addon ACEs therefore compile and run in exported games with zero EventForge dependency
  (the parity contract holds — asserted in tests). Demo addon gained `announce_heal` as a
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
- **Reverse provenance** — the pairing loop now runs both directions: clicking a line in
  the GDScript panel **selects the sheet row that generated it** (most-specific source-map
  range wins; clicking inside an in-flow block selects its enclosing event). Built on the
  new `EventSheetViewport.select_resource()`, which also scrolls the row into view.
- **Live ƒx expression validation** — expression parameter fields compile-check on every
  keystroke against the sheet context (variables, host members, behavior `host`), tinting
  red with an explanatory tooltip when the text is not a valid GDScript expression
  (`EventSheetGDScriptLint.lint_expression`).
- **Object icons in row cells** (C3's strongest visual cue): condition/action/trigger
  cells draw their ACE's icon before the object label — addon `@ace_icon` textures, Godot
  class icons for node-typed ACEs, member glyphs otherwise; Core/System uses the editor's
  Tools glyph. Same resolver as the picker, cached per provider/ACE (misses for
  not-yet-loaded providers are not cached, so addon hot-loads self-heal). Span measurement
  accounts for the icon advance, so hit-testing stays exact.
- The plugin now bundles `addons/eventsheet/icons/eventsheet.svg` (used by the demo addon
  and tests; the project previously had **no** `res://icon.svg`, which made earlier
  icon-path asserts pass vacuously — they are real now).
- Covered by `tests/pairing_polish_test.gd` (15 assertions).

### Sample behavior packs (Platformer / Eight-Direction)
- **Two behaviors authored as event sheets ship in `res://eventsheet_addons/`** — editable
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
  block — including a default codegen template (`$PatrolBehavior.dash({strength})` for
  behaviors, `dash({strength})` for custom nodes/sheets) and the sheet's icon as
  `@ace_icon`. Drop the compiled script into `res://eventsheet_addons/` and the behavior's
  ACEs appear in every sheet: the **sheet → script → addon loop** is closed (verified by
  parsing the generated script back through the semantic analyzer). Unexposed functions
  emit `@ace_hidden`, making `expose_as_ace` the single publication switch.
- **Sheet-type identity UX** (dual-audience: Godot "custom node with an icon", C3
  "behavior attached to an object"): a slim **identity banner** above the sheet
  (`⚙ PatrolBehavior — Behavior · acts on host: CharacterBody2D`, click to edit), **tab
  badges** (⚙ behavior / ◆ custom node), the column header now reads
  `Conditions — host: <class>` on behavior sheets, a behavior-aware empty-state hint, and
  a new **"Sheet Type…" toolbar dialog** (Event Sheet / Custom Node / Behavior with
  name+icon+host fields) so none of it requires the Inspector. New themable
  `behavior_accent_color` token (soft purple).
- Covered by `tests/behavior_authoring_test.gd` (18 assertions).

### Behavior foundations: host accessor + real signal-trigger codegen
- **Behavior mode** (`EventSheetResource.behavior_mode`): the sheet compiles to an
  attachable **Node component** that acts on its parent — `extends Node`, a typed
  `var host: <host_class>` accessor bound in `_enter_tree` with an attach-time warning,
  and `host_class` reinterpreted as the declared/required host type. Lint/completion
  understand the behavior context (`host.velocity.x` lints clean).
- **Signal-backed triggers now actually connect.** Generated handlers used to rely on
  manual scene wiring; the compiler now emits `<signal>.connect(<handler>)` lines at the
  top of `_ready` (synthesizing `_ready` when no OnReady events exist). Works for self
  signals, **other nodes' signals** (`EventRow.trigger_source_path` → `get_node(...)`
  with source-aware handler names like `_on_platform_landed`), and **custom
  `signal:<name>` triggers** from addons/providers — which previously didn't compile at
  all. Argument signatures are baked at apply time (`trigger_args`), and applying a
  trigger definition now bakes `trigger_id` too (fixing picker-created trigger events
  silently skipping compilation).
- **Compile-time signal validation**: a self-connection is emitted only when the signal
  exists on the script's base class or is declared in a class-level GDScript block;
  otherwise it's skipped with a precise warning (emitting blindly produced a script that
  didn't parse — caught on the demo, whose CharacterBody2D sheet used OnBodyEntered).
- **Demo golden regenerated from the compiler** — `compile_demo_test` passes for the
  first time (pre-existing failures drop from 5 to 4). Covered by
  `tests/behavior_foundations_test.gd` (16 assertions).

### Custom node types from sheets + icon support
- **A sheet can now define a custom node type, exactly like GDScript.** Set
  `custom_class_name` (and optionally `custom_class_icon`) on the sheet in the Inspector
  and the generated script emits `@icon("…")` + `class_name X` + `extends Y` — the type
  appears in Godot's Create Node dialog with its icon, instances carry the sheet's
  behavior, and recompiling the sheet updates the class. Future eventsheet-authored
  Behaviors inherit this mechanism automatically (they compile to node scripts).
- **The ACE picker now shows icons** (C3 users expect the object's icon beside its name):
  addon `@ace_icon("res://…")` textures, node-type sections and entries with their Godot
  class icons, and member-kind glyphs (signal/method/property) as fallback — degrading
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
- **Validity guard**: an `if`/`elif`/`else` whose body emits nothing now gets `pass` —
  condition-only events can no longer produce invalid GDScript (latent bug fixed).
- All emitted rows (sub-events included) get provenance source-map entries. Demo golden
  output is unchanged. Covered by `tests/subevent_compile_test.gd` (12 assertions).

### GDScript-backed sheets: open ANY .gd as an event sheet (losslessly)
- **The Open dialog now accepts `.gd` files.** Opening one imports it as a GDScript-backed
  sheet: the file stays the **single source of truth** (no `.tres` is created), and Save
  compiles back to it. **Untouched files round-trip byte-identically** — guarded by a
  golden test with a deliberately hostile sample (annotations, comments, signals, enums,
  consts, odd formatting, default-param and non-void functions).
- **The lossless rule**: declarations lift to first-class rows only when canonical
  re-emission reproduces the source line exactly (verify-lift — e.g. `var hp: int = 100`
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
  exactly as fast as hand-written code — direct statements only (no `call()`/`Callable`
  indirection, no reflection, no plugin classes in output), static types wherever known,
  signals connected once, `await` only when flagged, provenance kept as compiler metadata.
  Spelled out in GDSCRIPT-PAIRING-SPEC (Principles #5) and enforced by
  `tests/codegen_parity_test.gd`, which scans representative compiled output for banned
  indirection patterns and required typing.
- Planned export-integrity hook recorded: an `EditorExportPlugin` recompiling all sheets at
  export so stale generated scripts can never ship (EDITOR-UI-SPEC §3).

### Shareable snippets (cross-project copy/paste)
- **Copying rows now also writes a portable text snippet to the system clipboard**
  (`[eventsheet-snippet v1]` + Godot `var_to_str` data — no JSON, no script paths/UIDs), so
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
  plugins — this is the documented approximation.)
- **Completion**: Ctrl+Space in the block editor offers sheet variables, sheet functions,
  and host-class members; GDScript syntax highlighting in the dialog.
- Covered by `tests/inflow_gdscript_test.gd` (13 assertions).

### Zero-config ACE addons (C3-addon form, no JSON)
- **Drop a script into `res://eventsheet_addons/` and it becomes a project-wide ACE addon
  automatically** — no manifest, no JSON, no per-sheet setup (`EventSheetAddonScanner`,
  recursive, additive to existing providers/default vocabulary). Metadata derives from the
  script: provider name from `class_name`, addon description from the top `##` doc comment,
  per-ACE customization via `@ace_*` annotations.
- **New annotations**: `@ace_display_template("Heal {amount} HP")` (row/picker text),
  `@ace_codegen_template("health += {amount}")` (generated code), and
  `@ace_param_hint(amount expression)` (params-dialog field kinds: expression ƒx,
  variable_reference dropdown…).
- **Custom ACEs now genuinely compile**: codegen templates are baked onto created
  conditions/actions (`codegen_template` export on `ACECondition`/`ACEAction`, honored by
  `ConditionCodegen`/`ActionCodegen` ahead of the descriptor registry — previously
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
- **Inverted conditions show C3's red ✗** (`#FF0000`, bare glyph — no circle behind it).
- **Drop lines have arrowheads at both ends** (row + ACE drags), mirroring C3's insert marker.
- **Drag ghost**: while dragging rows/conditions/actions over a target, a faint (~0.66 alpha)
  label of the dragged content follows the cursor, C3-style.

### C3 visual parity pass: crisp zoom text, solid cell blocks, value highlights, Godot-native theme (overhaul)
- **Text is crisp at every zoom level.** Zoom scales the canvas transform, which blurred
  (zoom-in) or aliased (zoom-out) glyphs rasterized at base size. All renderer text now draws
  at its final physical pixel size in identity space (`_draw_text`), then the zoom transform is
  restored — geometry scales, text stays sharp.
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
- **Disable/enable the whole current selection at once** with the `X` key — works on a single
  condition/action/event or a multi-selection (disables all if any are enabled, else enables
  all). Covered by `tests/disable_selection_test.gd`.
- **Disabled rows now show a strikethrough**, matching disabled ACEs — so a disabled event,
  group, or comment reads as "commented out", not just dimmed.
- Confirmed (and locked with `tests/subevent_selection_test.gd`) that selecting a sub-event
  does **not** select its parent, while selecting a parent cascades to its sub-events.

### Inline-edit, comment alignment, empty-event & nesting spacing (overhaul)
- **Double-clicking a comment or group name now edits it.** `_begin_edit` falls back to the
  row's first editable span when the click lands on a non-editable part (badge/icon/padding),
  so editing starts from anywhere on a comment/group row, and commits update the resource.
  Covered by `tests/inline_edit_test.gd`.
- **Comments align with the event blocks they annotate** — comment text is indented past the
  trigger/badge column so it lines up with where condition text begins.
- **An event with no conditions shows a clear "Every Tick" cell** in the condition lane (it
  used to be bare text), so deleting the last condition leaves a visible empty event block.
- **Tighter nesting spacing**: a small gap is inserted before event/group blocks that start a
  new sibling/parent-level row, while a parent and its sub-events stay tight — so it reads at a
  glance which events are nested.

### Condition add/delete + "+ Add" placement fixes (overhaul)
- **Adding a condition no longer overwrites an existing trigger.** `append_condition` only
  fills the trigger slot when the event has none; a trigger-type ACE added to an event that
  already has a trigger (e.g. "Every tick") is appended as a condition instead of replacing it.
- **Conditions can be deleted down to zero** (an event may have no conditions — it reads as
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
  stack vertically — so swapping the top/bottom cell never registered. It now uses the
  vertical position. Covered by `tests/ace_reorder_drag_test.gd` (full press→drag→release).
- **Global variables have a private/global access toggle.** The variable dialog now offers
  "Global (@export — usable outside the script)"; off compiles the variable to a plain
  private `var`, on to `@export var`. Local variables stay private. Covered by
  `tests/variable_export_test.gd`.

### Selection / hover / drag-preview correctness (overhaul — visual)
- **Clicking a condition/action now selects just that cell, hover now shows, and the drag
  drop-line appears** — all three were the same bug: the row layout is cached by geometry, but
  selection, hover, and drag-target state were baked into the cached dict while the cache key
  ignored them. So after a click/hover/drag the renderer read stale state — the whole event
  highlighted instead of the clicked cell, hover never appeared, and the ACE drop-line never
  drew. Selection/hover are now refreshed on every cache read; drag state is part of the cache
  key. Guarded by `tests/layout_state_test.gd`.
- **Clicking outside a cell selects the whole event.** The full-cell click fallback is now
  bounded to the lanes, so clicking the gutter / indent margin selects the event block, while
  clicking a condition/action cell (incl. its padding) selects that ACE.

### Drag-to-resize lane + hover/drag polish (overhaul — visual)
- **Drag the conditions/actions divider to resize the lanes**, C3-style. Hovering the divider
  shows a horizontal-resize cursor; dragging updates the split live and persists the ratio
  onto the sheet's editor style (a default-themed sheet is promoted to a concrete style so it
  saves). The pinned column header tracks the new divider position. Guarded by
  `tests/lane_resize_test.gd`.
- **Per-cell hover.** Hovering a condition or action highlights just that individual cell (a
  clear neutral light tint), not the whole event block — the whole-event highlight read as
  "selected" and was confusing. Whole-row hover remains for single-cell group/comment/variable
  rows.
- **Sub-event drop preview is indented.** Dragging an event so it nests inside another now
  draws the drop line at the child indent level, making "becomes a sub-event" unambiguous.

### Interaction + aesthetic fixes (overhaul — visual)
- **Dragging individual conditions/actions/events now works** (and shows its drop preview).
  The mouse-press that starts an ACE/row drag was not `accept_event()`'d, so the viewport
  stopped receiving motion/release — the drag never tracked and the drop indicator never
  drew. It now accepts the event on drag start. The drop logic (reorder within an event, move
  across events, Ctrl-to-copy) is covered by `tests/ace_drag_test.gd`.
- **Whole condition/action cell is now the click target.** Clicking anywhere on a
  condition/action line (the padding to the right of the text, or the vertical gaps between
  cells) now selects that ACE instead of falling back to selecting the whole event — fixing
  the "it selects the whole event" and "sometimes the action won't select" confusion. Guarded
  by `tests/hit_test_test.gd`.
- **Flat C3/GDevelop-style cells** replace the rounded "bubble" chips: conditions/actions are
  now flat rectangular cells with a subtle fill, a tinted hover fill, and a left accent bar +
  fill when selected (no rounded borders).

### Row rendering fixes (overhaul — visual)
- **Construct 3-style object labels.** Each condition/action/trigger now shows the object it
  acts on before the text (e.g. `System  Is on floor`, `System  Move and slide`) — "System"
  for Core ACEs, the node class for node-typed ACEs — matching the C3 event grammar. Added as
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

### GDScript importer — structural round-trip (overhaul — Phase 7)
- **Import GDScript back into an EventSheet.** `GDScriptImporter.import_source/import_script`
  parses the `extends` host class, top-level `@export var`/`var` declarations (with typed
  defaults, via `VariableParser`), and `func` signatures (name + typed params + verbatim
  body, via `FunctionParser`). Each function becomes an `EventFunction` whose body is kept
  as a `RawCodeRow` passthrough.
- **Round-trips through the compiler**: `SheetCompiler._emit_event_body` now emits
  `RawCodeRow.code` verbatim, so an imported sheet re-compiles to the same extends /
  variables / function signatures / bodies (trigger output and the demo golden are
  unaffected — the demo has no raw rows).
- _ACE-level reverse mapping (turning generated `if`/action lines back into conditions and
  actions) is intentionally future work; bodies are preserved as raw code for now._
- **Tests**: `tests/importer_test.gd` covers host-class, typed-variable, and function
  parsing plus the structural round-trip back through the compiler.

### Multiple EventSheet tabs (overhaul — Phase 6)
- **The editor now holds several open sheets at once.** A `TabBar` above the canvas lists
  open sheets; clicking a tab swaps that sheet into the shared virtualized viewport. Each
  tab keeps its own path and **independent dirty state** (shown as a `●` marker on the tab).
- `EventSheetDock` keeps `_current_sheet`/`_current_sheet_path`/`_dirty` as the *active*
  tab's live state (so all existing code is unchanged) and layers a `_open_tabs` list on
  top. `setup()` now opens a sheet in a tab — reusing the existing tab if that sheet is
  already open — and `_refresh_title_strip()` keeps the active tab's persisted state +
  title in sync. Closing a tab activates a neighbour (or a fresh demo when none remain).
- Public API: `get_open_tab_count`, `get_active_tab_index`, `activate_tab`, `is_tab_dirty`.
- **Tests**: `tests/multi_tab_test.gd` covers open/add, re-open de-duplication, per-tab
  dirty isolation across switches, sheet restoration, and close-activates-neighbour.

### Sheet functions (overhaul — Phase 5)
- **`EventFunction` resources now compile to GDScript methods.** `SheetCompiler` emits each
  enabled function as `func <name>(<typed params>) -> void:` with its events compiled into
  the body (empty functions emit `pass`), after the trigger handlers. The condition/action
  body emission was factored into a shared `_emit_event_body` so triggers and functions use
  the same code path (trigger output is byte-identical — no compiler regression).
- **Call-as-action**: new built-in `Core / CallFunction` action ("Call Function") with
  template `{function_name}({args})`, so an event action can invoke a sheet function
  (`do_thing(5)`, `reset()`).
- **Tests**: `tests/sheet_function_test.gd` covers typed-param signature emission, body vs
  `pass`, and the Call Function codegen (with and without args).
- _Authoring UX (a dedicated function-body editor) is deferred; the data model, compiler,
  and call action are in place._

### Sub-event authoring — indent / outdent (overhaul — Phase 4)
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

### Custom ACE providers (overhaul — Phase 3)
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

### Theme switcher + token coverage (overhaul — Phase 2)
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

### Construct 3-style ACE picker (overhaul — Phase 1)
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

### Construct 3-style ACE parameter & expression dialog (overhaul — Phase 1)
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

### Construct 3-style column header (overhaul — Phase 1)
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

### Keyboard authoring workflow (overhaul — Phase 1)
- Completed the `EDITOR-UI-SPEC.md` §2.4 keyboard map in the dock's `_unhandled_key_input`,
  adding the missing shortcuts: **Ctrl+Shift+S** (Save As), **Ctrl+E** (Add Event),
  **Ctrl+Shift+V** (Add Variable), **Ctrl+Shift+C** (Add Condition), **Ctrl+Shift+A**
  (Add Action), **Q** (Add Comment), **G** (Add Group), **Ctrl+D** (Duplicate Event) —
  alongside the existing Ctrl+C/V/S/Z/Y/O, Delete, Enter/F2.
- New dock handlers `_on_add_comment_requested`, `_on_add_group_requested`,
  `_on_duplicate_requested` (deep-clone + fresh `event_uid` via `_assign_fresh_event_uids`),
  all routed through the existing undoable-edit + insert-below-selection pipeline.
- **Text-field guard**: a `_text_field_has_focus()` check suppresses authoring shortcuts
  while a `LineEdit`/`TextEdit`/`SpinBox` owns focus, so typing never triggers actions.
- **Tests**: `tests/keyboard_actions_test.gd` drives the handlers and asserts add-group,
  add-comment, duplicate-no-op-without-selection, and duplicate-with-fresh-uid behavior.

### Large-sheet load performance (overhaul — virtualized build)
- **Cached built-in ACE descriptors** in `ACERegistry`: `get_all_descriptors()` /
  `find_descriptor()` previously rebuilt and re-normalized the entire built-in set on
  every call (a hot path when rendering sheets that reference fallback/unknown ACEs).
  Built-ins are now normalized once and indexed for O(1) lookup. Added `clear_cache()`.
- **Lazy event-row spans**: event rows now build their (expensive) visual spans on demand
  — only when laid out, hit-tested, or selected — instead of eagerly for the whole sheet.
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

### Editor architecture consolidation (overhaul — Phase 0)
- Removed the parallel Control-widget editor prototypes (`EventRowUI`, `GroupRowUI`,
  `CommentRowUI`, `VariableRowUI`, `SheetToolbar`) and the unimplemented stub files
  (`ACEPalette`, `ActionPicker`, `ConditionPicker`, `DualViewSwitcher`, `ElseRowUI`,
  `ExpressionEditor`, `GDScriptPanel`) from `addons/eventforge/editor/`. The custom-rendered
  **virtualized viewport** (`EventSheetDock`/`EventSheetViewport`/`EventRowRenderer`) is now
  the sole editor architecture — it is the only model that scales to tens of thousands of
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
  - `Node2D` — `SetPosition2D` (action), `SetRotationDeg` (action)
  - `CharacterBody2D` — `MoveAndSlide` (action), `SetVelocity2D` (action)
  - `Area2D` — `OnAreaEntered` (trigger)
  - `RigidBody2D` — `ApplyCentralImpulse` (action)
  - `Timer` — `StartTimer` (action), `StopTimer` (action), `IsTimerStopped` (condition),
	`OnTimeout` (trigger)
  - `AnimationPlayer` — `PlayAnimation` (action), `StopAnimation` (action),
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
