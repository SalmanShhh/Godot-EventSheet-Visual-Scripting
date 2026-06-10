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
and `@ace_param_hint(amount expression)`. Codegen templates are **baked onto created
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
in params. Whole sheets continue to share as self-contained `.tres` files.

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
   planned export-integrity hook covers exports).
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

### Importer round-trip (structural)

`GDScriptImporter` parses generated or handwritten GDScript back into a sheet: `extends`
→ host class, top-level `var`/`@export var` → variables (typed defaults), `func`
signatures → `EventFunction`s with bodies preserved as `RawCodeRow`. Compiling the
imported sheet reproduces the structure. ACE-level body parsing (generated `if` chains →
conditions/actions) is planned.

## Planned
- **Eventsheet-authored Behaviors (C3 behaviors, built with sheets)**: a behavior is an
  event sheet that compiles to an **attachable Node component script** — add the node as a
  child of any object (Godot's component idiom) and it runs. Key design points: a
  first-class **`host`** accessor (the parent node) so behavior ACEs act on the object they
  are attached to, with the sheet declaring its required host class (drives lint +
  completion + attach-time warnings); the behavior's exported variables compile to
  `@export` properties (per-instance inspector config); sheet functions marked "expose as
  ACE" compile **with `@ace_*` annotations emitted**, so dropping the compiled script into
  `res://eventsheet_addons/` publishes the behavior's own ACEs to every sheet —
  zero-config, closing the loop (sheet → script → addon). Distribution = the compiled `.gd`
  (runtime truth) + the source `.tres` (editable); behaviors are plain nodes at runtime, so
  no runtime registry/bridge is required. Known considerations: tick ordering between host
  sheets and behavior nodes (document Godot's tree processing order; optionally explicit
  tick functions), triggers on a behavior's signals from the host sheet require
  non-self signal connection codegen, and multiple instances of one behavior are naturally
  supported as separate child nodes.
- **More behavior packs**: tweens and beyond (platformer, 8-direction, timer, flash, and
  state machine ship today — see Implemented).
- **C3 migration guide**: implemented — `docs/C3-MIGRATION-GUIDE.md` (concept map + System
  vocabulary table); future nicety: link it from the picker UI.

## Testing

`tests/gdscript_pairing_test.gd` guards: verbatim class-level block emission (top-level,
group-nested, disabled-skip), multi-line block rendering, codegen template substitution
and Core descriptor preview, picker synonym expansion, and the semantic theme token
defaults. `tests/importer_test.gd` guards the structural round-trip.
