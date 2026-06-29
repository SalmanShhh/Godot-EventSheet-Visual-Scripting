# GDScript Pairing Spec

How the EventSheet editor pairs with GDScript so users arriving from Construct 3 are
continuously *taught* the code their sheets write. This is the project's differentiator:
the sheet is a bridge to GDScript, not a wall beside it.

## Principles

1. **One language.** There is no proprietary expression or scripting language anywhere in
   the system. Everything the user types beyond ACE picking is plain GDScript; everything
   the sheet produces is readable GDScript.
2. **Always show the mapping.** Whenever the editor can cheaply reveal the generated code
   (tooltips, previews, provenance), it should.
3. **Escape hatches stay inside the sheet.** When no ACE fits, the user writes GDScript
   *in the sheet* (blocks, expressions) rather than abandoning it.
4. **Two-way traffic.** Generated GDScript can be imported back into a sheet; hand-edits
   should not strand the user outside the sheet.
5. **Performance parity with hand-written GDScript (hard constraint).** Generated code must
   run exactly as fast as the equivalent hand-written script. Codegen rules that guarantee
   it — binding on every current and future feature:
   - Direct statements only: conditions compile to `if` expressions, actions to direct
     calls/assignments. **Never** `call()` / `Callable` indirection, reflection, dictionary
     param lookups, or wrapper helpers in generated code.
   - **Zero plugin dependency in output**: generated scripts reference no EventForge/
     EventSheet classes; exported games run without the addon. The planned runtime addon
     bridge is registration/discovery only — it must never sit in a per-frame path.
   - Emit static types wherever known (typed vars, typed function signatures) so Godot's
     typed-instruction optimizations apply.
   - Signal triggers connect once (in `_ready`), never poll; `await` is emitted only when
     explicitly flagged on the action.
   - Provenance/source maps are compiler **metadata**, never emitted into the script body.
   - Behaviors compile to plain node component scripts — the same cost as a hand-written
     component node, which is the hand-written design being mirrored.
   - Guarded by `tests/codegen_parity_test.gd`, which scans representative compiled output
     for banned indirection patterns and required typing.

## Implemented pairing features

### Provenance panel (sheet → code source map)

`SheetCompiler.compile` returns a `source_map`: `{uid, start, end, kind}` entries with
1-based inclusive line ranges into the output, where `uid` is the source resource's
instance id and `kind` ∈ `event | raw | variable | function`. The dock's **GDScript**
toolbar toggle opens a read-only side panel (HSplitContainer, built lazily) showing the
generated script with line numbers and syntax highlighting; **selecting any sheet row
highlights and scrolls to the exact lines it compiles to**, live-refreshing after every
edit. Selecting a condition/action highlights its event's range.

### Zero-config ACE addons (no JSON, no manifest)

Drop a provider script (or folder of scripts) into `res://eventsheet_addons/` and its
annotated members become **project-wide ACEs automatically** (`EventSheetAddonScanner`,
additive — never displacing the default vocabulary or per-sheet providers). All metadata
derives from the script itself: provider name from `class_name`, addon description from
the top `##` doc comment, and per-ACE customization via annotations — including
`@ace_display_template("Heal {amount} HP")`, `@ace_codegen_template("health += {amount}")`,
`@ace_param_hint(amount expression)`, `@ace_param_options(dir north, south)` (a fixed
dropdown), and `@ace_param_autocomplete(anim "idle", "run")` (an **editable** type-or-pick
combo — Construct-style autocomplete the behavior toggles purely from its own code; free
text is always allowed, the ▾/Down-arrow popup filters the suggestions by what's typed).
Codegen templates are **baked onto created
conditions/actions** (`ACECondition`/`ACEAction.codegen_template`) and honored by
`ConditionCodegen`/`ActionCodegen`, so addon ACEs genuinely compile (previously custom
ACEs had no codegen path). See `res://eventsheet_addons/demo_health_addon.gd` — the
shipped sample addon doubles as the documentation-by-example.

### Paste GDScript as events

Pasting raw GDScript (from the script editor, a tutorial, an AI chat…) into a sheet
converts it through the same pipeline that opens `.gd` files: declarations verify-lift to
variable rows, trigger functions ACE-lift into real events (byte-identical verification,
fresh UIDs), and everything else is preserved as verbatim GDScript block rows — the
lossless rule applies to the clipboard too. Detection is conservative
(`_looks_like_gdscript`), so non-code text falls through to snippet/internal paste
untouched. Guarded by `tests/gdscript_paste_test.gd`.

### Shareable snippets (C3-style, system clipboard)

Copying rows also writes a portable, versioned text form to the **system clipboard**
(`EventSheetSnippet`: `[eventsheet-snippet v1]` + `var_to_str` data — no script
paths/UIDs, no JSON), so events paste across projects, editor instances, and forum posts.
Paste detects the marker (internal clipboard remains the same-session fallback), rebuilds
**whitelisted row kinds only**, assigns **fresh UIDs**, and **auto-creates missing
referenced variables** (`required_variables`; existing ones are never overwritten). Baked
codegen templates keep addon ACEs compiling without their addon installed; the snippet
lists the provider names it uses so the addon script can be dropped into
`res://eventsheet_addons/`. Out of scope per snippet: themes (per-project) and asset paths
in params. Whole sheets continue to share as self-contained files (`.gd` by default, or `.tres`).

### Using behaviors / sheet code FROM hand-written GDScript

Sheet-generated code is ordinary, registered GDScript — so a GDScript developer consumes
it like any class, with full typed autocomplete and editor documentation (the generated
`##` comments surface in Godot's help):

```gdscript
@onready var movement: PlatformerMovement = $PlatformerMovement
func _on_pad_pressed() -> void:
	movement.move_speed = 320.0      # @export var from the sheet
	movement.jump()                  # exposed sheet function
	await movement.jumped            # sheet-declared signal
```

`extends PlatformerMovement` also works (subclass a behavior in code). The rules to know:

1. **Never hand-edit a generated `.gd`** — recompiling the sheet overwrites it. Call into
   it, or `extends` it; both survive regeneration. (GDScript-backed sheets are the
   exception: there the `.gd` *is* the editable source.)
2. **The sheet defines the API.** Renaming a sheet function/variable changes the generated
   class — dependent GDScript breaks loudly at parse time (typed), same as any refactor.
3. **Lifecycle**: a behavior binds `host` in `_enter_tree`; attach it under its host
   before calling methods that act on the host (generated bodies null-guard, so misuse
   warns rather than crashes).
4. **Stay compiled**: stale generated scripts mean a stale API — compile on save (and the
   export-integrity hook covers exports — shipped: every sheet recompiles when an
   export starts).
5. GDScript callers hold direct references, so they are *more* robust than the sheet-side
   default templates (which address behaviors as `$ClassName` child nodes).

### Intellisense: dot-context completion, signature hints, quick-add bar

Completion in blocks and ƒx fields is context-aware: `host.` / a typed sheet variable /
`$BehaviorName.` offer that type's members (ClassDB + global class list;
`completion_for_context` is the shared choke point), with signature hints for the
innermost call (`signature_hint` → CodeEdit code-hint). The toolbar **quick-add bar** is
C3's "type to insert": synonym phrasing matches an ACE, trailing words fill parameters
positionally. Ceiling note: Godot does not expose its real completion engine
(`complete_code`/LSP) to plugins — this is the documented approximation, and
full-fidelity IntelliSense always exists one panel away because the generated script is
plain GDScript.

### Tool sheets (EXPERIMENTAL)

`tool_mode` emits `@tool` first; the Editor Tool sheet-type preset pairs an
`EditorScript` host with the **On Editor Run** trigger (`_run`, File > Run) so editor
tooling can be authored as events. Lifecycle round-trips through the standard
verify-lift; `tool_mode` recovers from the `@tool` line on re-open. Explicitly
editor-version-coupled — the compatibility covenant's stable-API rule applies to
runtime ACEs only, and tool sheets carry the experimental label for exactly that reason.

### Hidden optimization (ACEs emit expert idioms)

Because the sheet shows friendly labels — not the code — ACE templates are free to emit
*faster* GDScript than a beginner would type, as long as it stays readable: `&"name"`
StringName literals for hot-path APIs (input polling, `is_in_group`, `play`) skip the
per-call String→StringName hash; triggers sharing a lifecycle merge into ONE handler;
signal connections hoist into a single `_ready`; instance-backed addon providers declare
one member instead of constructing per call. The boundaries: **user ƒx expressions and
GDScript blocks are never rewritten** (verbatim always), optimizations apply only to
template-driven emission, and external GDScript-backed sheets stay byte-exact. Old
generated files using the previous idiom simply keep those lines as blocks when re-opened
(the lossless rule) — nothing breaks.

### MCP server (AI tooling)

A pure-GDScript MCP server (`addons/eventsheet/mcp/`) exposes sheets to AI assistants
over stdio JSON-RPC: list/read sheets, browse the ACE vocabulary (builtins + zero-config
addons via the same registry bootstrap as the editor), dry-run-by-default compilation,
context-aware lint, and append-only snippet/GDScript application through the lossless
paste pipeline. Protocol core is transport-free and unit-tested; setup in
`docs/MCP-SERVER.md`.

### First-class rich variables — complete (enums, collection variables, curated ACEs)

The full arc shipped: **enums** (below), **collection variables** (Array/Dictionary incl.
Godot 4 typed `Array[T]`/`Dictionary[K, V]`; literal defaults with live validation and a
commit guardrail; canonical recursive escape-correct emission; verify-lift round-trips),
and the **curated collection ACE set** — 27 Dictionary/Array/JSON ops as builtin Core
descriptors under "Variables: …" picker groups, each compiling to one direct GDScript
line, with type-aware variable dropdowns (`variable_reference:Array` offers only Array
variables). XML is intentionally unsupported (user decision): JSON is the format.
Guarded by `tests/collection_variables_test.gd` and `tests/collection_aces_test.gd`.

### First-class enums (rich-variables phase 1)

Enums are sheet rows (`EnumRow`: name + members, optional explicit values) compiling to
canonical single-line class enums (`enum State { IDLE, RUN, HURT = 4 }`) **before**
variables so enum-typed declarations work — exported enum variables get Godot's Inspector
dropdown for free. They render as keyword-badged rows, edit via dialog (row menu "Add
Enum Below" / double-click), verify-lift from generated code (non-canonical forms stay
verbatim blocks), travel in snippets (kind "enum"; older versions drop them via the
whitelist), feed the lint scratch (expressions referencing them validate), and `State.`
dot-completes members. Guarded by `tests/enum_row_test.gd`.

### Pick filters, ƒx autocomplete, external-sheet watcher

Pick filters compile to direct `for` loops (group / children / any iterable + iterator-
scoped predicate + first-N), authored via the row menu and edited by double-clicking the
"For each …" row. ƒx fields are single-line CodeEdits with completion (same candidates as
the block editor) plus live validation. GDScript-backed sheets watch their file's mtime
and prompt to reload (re-import + lifting) when it changes outside the editor.

### Reverse provenance, ƒx validation, and row-cell icons

The pairing loop now runs both directions: selecting a row highlights its generated lines,
and **clicking a line in the GDScript panel selects the sheet row that generated it**
(most-specific source-map range wins; lines inside an in-flow block select its event).
**ƒx parameter fields compile-check live** as GDScript expressions against the sheet
context (`EventSheetGDScriptLint.lint_expression`) — invalid input tints red with an
explanatory tooltip. **ACE cells render object icons** before their labels (addon
`@ace_icon` textures → class icons → editor glyphs; Core falls back to the Tools glyph),
resolved through the same path as the picker and cached per provider/ACE. The plugin
bundles `addons/eventsheet/icons/eventsheet.svg` as the default sheet glyph. Guarded by
`tests/pairing_polish_test.gd`.

### Provider registration API + instance-backed ACEs (the "runtime bridge", resolved)

`EventForgeBridge.register_script_as_provider(path)` registers any GDScript file as an ACE
provider from code — equivalent to placing it in `res://eventsheet_addons/` (static API,
deduped, unregisterable). And the real runtime gap is closed without any runtime bridge:
addon **methods without** `@ace_codegen_template` bake an **instance-backed** call —
`__eventsheet_provider_<Class>.method({args})` — and the compiler declares each used
provider once as a plain owned instance. Exported games need only the addon script itself
(an ordinary `class_name` class); generated output still references no EventForge classes
(parity contract). Node-extending providers should prefer behaviors/autoloads; RefCounted
is the intended provider shape.

### Expose-as-ACE sheet functions (the sheet → script → addon loop)

A sheet function marked `expose_as_ace` compiles with the full `@ace_*` annotation block —
`@ace_action`, optional `@ace_name`/`@ace_category`/`@ace_description`, the sheet's icon
as `@ace_icon`, and a default `@ace_codegen_template` (`$Class.fn({args})` for behaviors,
whose nodes default to their class name; `fn({args})` for custom nodes/sheets). Dropping
the compiled script into `res://eventsheet_addons/` therefore publishes the function as an
ACE in every sheet with zero configuration. Unexposed functions emit `@ace_hidden`, so
`expose_as_ace` is the single publication switch. Round-trip is guarded by parsing the
generated script back through `EventSheetSemanticAnalyzer`
(`tests/behavior_authoring_test.gd`).

### Behavior foundations (host accessor + signal-trigger codegen)

`behavior_mode` sheets compile to attachable Node components: `extends Node`, a typed
`var host: <host_class>` accessor bound in `_enter_tree` (with an attach-time warning when
the parent type is wrong); `host_class` is the declared required host. Lint/completion
mirror this (`host.<member>` resolves). Signal-backed triggers emit real `_ready`
connections — self signals (compile-time validated against the base class + signals
declared in class-level GDScript blocks; skipped with a warning otherwise), other nodes'
signals via `EventRow.trigger_source_path` (source-aware handler names), and custom
`signal:<name>` triggers with their `trigger_args` signature baked at apply time.

### Codegen tooltips

Hovering any condition / trigger / action shows `GDScript:` followed by the exact snippet
it compiles to — the ACE's codegen template with its parameter values substituted.
Resolution order: `ACEDefinition.metadata.codegen_template`, then the base
`ACERegistry` descriptor. Implemented in `EventSheetViewport._get_tooltip` /
`_codegen_preview_for` / `fill_codegen_template`.

### Visual expression builder (ƒx picker lists the host's own members)

The ƒx **Insert Expression** picker also lists the sheet host class's own reflected
members, grouped as **This Object — Properties** and **This Object — Methods** (alongside
the existing expression templates). Picking a property inserts `name`, a method inserts
`name()` — so referencing `host.position` or calling a host method is point-and-click
rather than recalling the API by hand. Editor-only: it reuses the same reflection helper
the pickers do and changes nothing about the emitted expression (`ace_params_dialog.gd`).

### Reflection-driven ACE pickers (real members as editable suggest-combos)

The **Helpers** ACEs **Call Method**, **Call Method (value)**, **Set Property**, and
**Get Property** now offer the host class's *real* members as an editable suggest-combo:
you pick from members reflection actually found, but you can still type a name reflection
misses (no member is ever locked out). This keeps the structured escape hatch usable
without leaving the row for a raw block, and generated code is unchanged — the combo only
fills the same parameter the ACE always took (`ace_params_dialog.gd`,
`registration/modules/helper_aces.gd`).

### Extract GDScript to Function (promote a block to a reusable ACE)

A row's **More** menu gains **Extract GDScript to Function**: it gathers that event's
inline GDScript (`RawCode`) actions into a new reusable `EventFunction` and replaces them
with a call to it. The new function is auto-exposed as an ACE under the **Functions**
category, so logic that started as a one-off block becomes a named, searchable,
re-pickable action — promoted entirely inside the sheet (`event_sheet_dock.gd`).

### Visual collection editor (Array/Dictionary defaults, one item per line)

Array / Dictionary variable defaults get an **Edit items…** button in the Variable dialog
that opens a one-item-per-line editor instead of forcing you to type a literal like
`[1, 2, 3]`. The editor round-trips losslessly through the literal, so you can author or
revise a collection's contents without writing collection syntax by hand and without
leaving the dialog (`variable_dialog.gd`).

### Conditional breakpoints (a slice of visual debugging)

A row's **More** menu gains **Set Breakpoint Condition…**: it stores a GDScript boolean
expression and the compiler emits `if <cond>: breakpoint` instead of a bare `breakpoint`,
so you pause only on the frame that matters (e.g. `health <= 0`) rather than on every pass;
a blank condition clears the guard. This builds on the existing F9 real breakpoints, the
Tools-menu Debug Breakpoints toggle, and editable Live Values — it is a bounded slice of
visual debugging, conditional breakpoints specifically, not a full step-through/watch
debugger (`event_row.gd`, `sheet_compiler.gd`, `event_sheet_dock.gd`).

### Inline GDScript blocks (class-level and in-flow)

`RawCodeRow` resources are first-class in two placements:

- **Class-level blocks** (tree rows): right-click → "Add GDScript Block Below"; rendered
  with a `GDScript` badge line-by-line; emitted **verbatim at class level** (helper
  functions, `@onready` vars, `signal` declarations…). Blocks inside `sub_events` are
  deferred until sub-event compilation exists.
- **In-flow blocks** (C3 inline scripting): right-click an event → "Add GDScript Action";
  rendered as action-lane cells (one per code line, `GDScript` origin label, value
  highlighting), moved/deleted/dragged as one action, and **compiled indented inside the
  event body** under its conditions. Both placements get provenance source-map entries.
- **Edit**: double-click opens a `CodeEdit` dialog (line numbers, GDScript syntax
  highlighting) with **compile-check linting** — the snippet is validated in a scratch
  script extending the sheet's host class with sheet variables/functions stubbed
  (`EventSheetGDScriptLint.lint`), live ✓/✗ status — and **completion** (Ctrl+Space)
  offering sheet variables, sheet functions, and host-class members.
- Imported function bodies also round-trip through `RawCodeRow` (see importer notes).

### Expressions are GDScript

Expression parameter fields are labeled and tooltipped as plain GDScript
(`ace_params_dialog.gd`); the `ƒx` picker inserts expression templates. There is no
expression DSL to learn or to lock users in.

### Helper ACEs (structured escape hatch)

The **Helpers** vocabulary (`registration/modules/helper_aces.gd`, category `"Helpers"`)
exists for the GDScript a user would otherwise drop to a raw block for, so more logic stays
as an editable, searchable, codegen-tooltipped row while compiling to the exact one-line
GDScript you'd hand-write (parity contract — single direct line, no indirection): **Set/Get
Property**, **Call Method** (action + value), **Get Node**, **Run GDScript** / **Evaluate
GDScript** / **Evaluate Expression** (a raw statement/expression as a real ACE), **Inline If
(ternary)**, **Toggle Boolean**, **Set Local Variable**, **Is Valid** / **Is Null**,
**Connect/Disconnect Signal**, and the math/string idioms not already in Core
(Abs/Min/Max/Round/Sign/Move Toward/Wrap/Remap/Format String). Because the templates are
deliberately generic, the module is registered **last** and is **excluded from the
reverse-lifter** (`ace_lifter.gd` skips `category == "Helpers"`) so a helper never shadows a
specific ACE on import or swallows a line that should stay a verbatim block — they're a
forward-authoring convenience, not a reverse-match target.

### Escape-hatch provenance (note + import "why-it-stayed-code")

`RawCodeRow` carries two **non-emitted** (never compiled, no round-trip impact) editor
fields: an optional `note` (a human label surfaced on hover) and an importer-set `lift_note`.
When the lifter can't model a line it stays verbatim and records `lift_note = "no matching
ACE template"`; the viewport's verbatim-codegen tooltip (`EventSheetViewport._get_tooltip`)
shows it, turning an opaque wall of imported blocks into an actionable "this is why it stayed
code" triage list. Together with the Helper ACEs (fewer blocks needed) and the
emitted-verbatim tooltip (the block compiles to itself, transparently), the escape hatch is
first-class, not a fallback.

### C3 vocabulary bridge

The ACE picker expands Construct 3 phrases to Godot search terms
(`ACEPickerDialog.C3_SEARCH_SYNONYMS`): "on start of layout" finds `_ready`-based
triggers, "every tick" finds `_process`, "spawn"/"create object" find instantiate,
"destroy" finds `queue_free`, "on collision" finds `body_entered`, and so on. Queries
shorter than 4 characters are not expanded.

### GDScript-backed sheets (open any .gd as a sheet, Tier 1)

Any GDScript file opens as a sheet via the Open dialog (`GDScriptImporter.import_external`)
under **the lossless rule**: every line lands in exactly one ordered row. Declarations lift
to first-class variable rows **only** when canonical re-emission reproduces the source line
byte-for-byte (verify-lift); each top-level function becomes its own GDScript block row;
everything else is preserved verbatim. The `.gd` stays the single source of truth
(`EventSheetResource.external_source_path`): Save compiles back order-preservingly with no
generated header and no synthesized `extends` (`SheetCompiler._compile_external`), so an
**untouched file round-trips byte-identically** — the golden contract in
`tests/external_sheet_test.gd`. Added events append as standard trigger functions; Save As
`.tres` converts to a normal sheet. Provenance, lint, and completion all work on external
sheets (host class parsed from the prelude).

### ACE-level import lifting (reverse template matching)

Opening a `.gd` as a sheet runs `EventSheetACELifter` after the lossless segmentation:
the trailing run of trigger functions lifts into EventRows — lifecycle handlers
(`_ready`/`_process`/`_physics_process`) by header, and **signal handlers via `_ready`'s
connect lines** (Core signals reverse to their trigger ids; custom ones become
`signal:<name>` triggers carrying the handler args as `trigger_args` and the
`get_node("…")` source as `trigger_source_path`; the connects regenerate on emission).
Sheet FUNCTIONS lift too: their `@ace_*` annotation
blocks reverse into exposure fields, parameters parse with types, and unmatched control
flow stays as in-flow GDScript (lenient ifs — trigger bodies included). Trailing
top-level comments lift into comment rows. **Two-pass**: a full lift that fails the
byte-verify retries event-only, so upgrades never regress coverage. Bodies lift by reverse-matching builtin codegen templates — `{param}`
placeholders become named captures (params round-trip as plain strings because codegen
substitutes with `str()`), `not (...)` reverses to negated conditions, ` and `-joined
expressions split into condition lists, and any statement matching no template becomes an
in-flow GDScript block so the event still lifts. **The lift is all-or-nothing per file and
kept only when recompiling reproduces the source byte-for-byte** — otherwise it reverts
and the file stays verbatim blocks (the lossless rule is never traded away). Practical
effect: EventForge-generated scripts re-open as fully editable events; hand-written files
lift opportunistically or not at all, never lossily.

Also round-tripping (verify-lift-gated, same all-or-nothing rule): variable
`@export_group`/`@export_subgroup` + tooltips, the five Tier-3 Inspector drawers
(`@export_custom(PROPERTY_HINT_NONE, "eventsheet:<drawer>")`), **sub-events** (nested `if` blocks ↔
`sub_events`), and class-scope `##` sheet metadata (tags / autoload / `@ace_tags` / `@ace_family`).
Event GROUPS and Includes don't round-trip through `.gd` yet — see `GROUPS-ROUNDTRIP-SPEC.md` /
`INCLUDES-SPEC.md`.

### Importer round-trip (structural)

`GDScriptImporter` parses generated or handwritten GDScript back into a sheet: `extends`
→ host class, top-level `var`/`@export var` → variables (typed defaults), `func`
signatures → `EventFunction`s with bodies preserved as `RawCodeRow`. Compiling the
imported sheet reproduces the structure. ACE-level body parsing SHIPPED: the lifter
(`ace_lifter.gd`) reverse-matches generated `if` chains and action templates back into
real events, gated by the byte-identical verify-lift.

## Planned → Delivered

Everything in this section SHIPPED and is kept as the design record:
- **Eventsheet-authored Behaviors (C3 behaviors, built with sheets)**: a behavior is an
  event sheet that compiles to an **attachable Node component script** — add the node as a
  child of any object (Godot's component idiom) and it runs. Key design points: a
  first-class **`host`** accessor (the parent node) so behavior ACEs act on the object they
  are attached to, with the sheet declaring its required host class (drives lint +
  completion + attach-time warnings); the behavior's exported variables compile to
  `@export` properties (per-instance inspector config); sheet functions marked "expose as
  ACE" compile **with `@ace_*` annotations emitted**, so dropping the compiled script into
  `res://eventsheet_addons/` publishes the behavior's own ACEs to every sheet —
  zero-config, closing the loop (sheet → script → addon). Distribution = a single editable `.gd`
  (it is both runtime truth and editable source via the lossless round-trip; a `.tres` companion is
  optional); behaviors are plain nodes at runtime, so
  no runtime registry/bridge is required. Known considerations: tick ordering between host
  sheets and behavior nodes (document Godot's tree processing order; optionally explicit
  tick functions), triggers on a behavior's signals from the host sheet require
  non-self signal connection codegen, and multiple instances of one behavior are naturally
  supported as separate child nodes.
- **C3 coverage program (user-confirmed direction)** — bring the C3 behavior/plugin
  surface over under a strict **three-lane rule** so nothing rots:
  **Lane 1 (Godot owns it → ACE providers over NATIVE features, never reimplementations):**
  Tween→create_tween, Physics→RigidBody2D, Pathfinding→NavigationAgent2D,
  Solid/Jump-thru→collision layers + one-way shapes, Audio→AudioStreamPlayer,
  Sprite/animation→AnimatedSprite2D/AnimationPlayer, Text→Label/RichTextLabel, Tilemap,
  Keyboard/Gamepad/Touch→Input (partly shipped), Anchor→Control anchors.
  **Lane 2 (portable gameplay logic → sheet-built behavior packs, the shipped pattern):**
  Sine, Orbit, Bullet, Move To, Follow, Drag & Drop, Car, Tile Movement, Line of Sight.
  **Lane 3 (honest out-of-scope → migration-guide rows):** Multiplayer, Drawing Canvas,
  3D plugins, Binary Data, i18n → their Godot equivalents.
  **Compatibility covenant** (binding for all of it): (1) generated GDScript never depends
  on the plugin at runtime — packs ship their .gd, projects survive plugin removal;
  (2) templates bake at apply — descriptor changes never rewrite sheets; ace_ids are API,
  retired via hiding, never renamed/deleted; (3) the lossless rule + snippet whitelist
  mean upgrades cannot corrupt files. Every pack/provider ships with publish-assert
  tests + golden round-trips + the parse gate (CI-enforced). C3 names stay as display
  names + search synonyms; tooltips teach the generated GDScript.
  Phasing: A) native-node ACE providers (+SceneTree spawn/change-scene/pause, Camera2D,
  RNG); B) the nine lane-2 packs; C) **in-editor "Export as Addon Pack…"** (the addon
  builder is ~90% shipped via behavior authoring + @ace annotations — this adds the
  one-click eventsheet_addons/<name>/ export with guardrail validation, no manifest);
  D) **tool sheets** (EventSheet Builder for Editor Tools): a `tool_mode` flag emitting
  @tool/EditorScript with an "On Editor Run" trigger — EXPLICITLY experimental and
  editor-version-coupled (editor APIs are Godot's most volatile surface; runtime ACEs
  stay on stable APIs only).
- **More behavior packs**: tweens and beyond (platformer, 8-direction, timer, flash, and
  state machine ship today — see Implemented).
- **C3 migration guide**: implemented — `docs/C3-MIGRATION-GUIDE.md` (concept map + System
  vocabulary table); future nicety: link it from the picker UI.

## Testing

`tests/gdscript_pairing_test.gd` guards: verbatim class-level block emission (top-level,
group-nested, disabled-skip), multi-line block rendering, codegen template substitution
and Core descriptor preview, picker synonym expansion, and the semantic theme token
defaults. `tests/importer_test.gd` guards the structural round-trip.
