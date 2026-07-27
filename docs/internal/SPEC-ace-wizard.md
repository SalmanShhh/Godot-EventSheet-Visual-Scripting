# SPEC - Generate ACEs from an existing script (the ACE Wizard)

Status: Phases 0-3 built, with one deliberate limit - see Phase 3.

## The problem

A user has their own system - `res://systems/wave_manager.gd`, a score keeper, an inventory - written
before they ever met this plugin. They want its verbs in the picker. Today they can point at the file
(Sheet > Custom ACE Providers) and the whole thing is reflected in one shot, but they cannot **see what
they will get before committing**, cannot **choose which members** publish, and cannot **name or describe
them** without hand-writing `## @ace_*` annotations into the file.

## What already exists (verified, do not rebuild)

The generation engine is done. `EventSheetACEGenerator.generate_from_object()`
(`addons/eventsheet/ace/ace_generator.gd:43`) reflects a live instance into ACEDefinitions:

| Member | Becomes |
| --- | --- |
| `signal wave_started(index)` | Trigger **On Wave Started** |
| `@export var difficulty` | Expression **Difficulty** + actions **Set / Add To / Subtract From Difficulty** |
| `func start_wave(index) -> void` | Action **Start Wave** |
| `func is_wave_active() -> bool` | Condition **Wave Active** (the `is_` is dropped) |
| `func current_multiplier() -> float` | Expression **Current Multiplier** |

Facts that shape the design, each verified by running it:

- **Annotations are refinement, not an on-switch.** An unannotated script yields exactly the same ACEs as
  the same script carrying `## @ace_expose_all`. The gate in `ace_generator.gd:64/75/91` is "is this member
  declared in THIS file" (which is what excludes inherited `Node` methods), because
  `semantic_analyzer.parse_source_metadata()` records an entry for every top-level `signal` / `func` /
  `@export var` whether annotated or not. So today's model is **opt-out, whole-file**.
- **`@tool` is NOT required.** The discovery gate is `script.can_instantiate()`
  (`event_sheet_dock.gd:_instantiate_provider_script`), not `is_tool()`.
- **Registration already has four seams**: the `eventsheet_addons/` folder scan; the in-memory
  `EventForgeBridgeRuntime.register_script_as_provider`; the durable project-wide ProjectSettings list
  `eventsheets/vocabulary/taught_provider_scripts`; and annotated autoloads. Per-sheet registration is
  `ace_provider_scripts` on the sheet resource (`provider_registry_glue.add_ace_provider_script`).
- **Nothing writes `@ace_*` into an existing file.** Both annotation generators
  (`editor/ace_annotation_stub.gd`) only produce clipboard text.

## What actually goes wrong on real user code

1. **Untyped signatures collapse the vocabulary.** `func is_wave_active():` without `-> bool` is generated
   as an **Action**, not a Condition, and every parameter is `TYPE_NIL`. Most hand-written game code is
   untyped, so raw reflection alone produces a poor result. This is the single strongest argument for a
   curation step rather than a one-click import.
2. **Whole-file exposure is vocabulary pollution.** The codebase already knows this: annotated autoloads
   are gated precisely because reflection would otherwise "dump every public method of e.g. the plugin's
   own bridge into every picker".
3. **A `class_name`-less non-Node provider emitted invalid GDScript.** FIXED (see below).

## Compatibility rule (the one that constrains everything later)

An `ace_id` is derived from the member name - `method:start_wave`, `set:difficulty`. So:

- Renaming the **display label** is always safe (it is not the identity).
- Renaming the **function** changes the id and orphans existing rows.

The wizard must therefore make label edits the default, and treat member renames as a deliberate,
warned-about action. Never silently rewrite a member name.

---

## Phase 0 - the provider id bug (DONE)

`get_provider_id`'s fallback used `capitalize()`, so `score_keeper.gd` with no `class_name` became the
provider id `"Score Keeper"`. That id is interpolated into a GDScript identifier for non-Node providers:

```
__eventsheet_provider_Score Keeper.high_score = {value}
```

The compiler's declaration scan (`sheet_compiler.gd:805`, regex `__eventsheet_provider_([A-Za-z_]\w*)`)
then read that as `__eventsheet_provider_Score` and declared `Score.new()`. Fixed by pascal-casing the
fallback, which also makes it agree with the Node path (`ace_generator.gd:55`) that already pascal-cased.
The autoload mirror in `event_sheet_dock.gd` was updated in lockstep - its comment explicitly warns that
the two must match or autoload trigger baking silently stops. Pinned by `expose_all_properties_test.gd`.

## Phase 1 - Preview and Register (this phase)

**Goal: turn "point at a file and hope" into "see exactly what you will get, then decide."** No file
writes, no annotation authoring - that is Phase 2. This phase is pure read + register, which is why it is
safe to ship on its own and why it de-risks Phase 2 (it proves the preview model first).

### Flow

1. Open from **Sheet > Custom ACE Providers** (extend the existing dialog rather than adding a rival one).
2. Browse to a `.gd`, or pick one already registered.
3. **Preview table**, one row per generated ACE: kind badge, picker label, parameters, and the exact code
   it will emit. This is `generate_from_object()` output - the same call the registry makes, so the
   preview cannot drift from reality.
4. **Warnings panel** for what will disappoint, computed from the same scan:
   - untyped method -> "reads as an Action; add `-> bool` to make it a Condition"
   - no `class_name` -> the provider id is derived from the file name
   - member count over a threshold -> "N verbs will join every picker"
   - nothing generated -> why (not instantiable / no eligible members)
5. **Register** per-sheet (default) or project-wide, reusing the existing seams. Cancel writes nothing.

### Contract

- Read-only with respect to the user's file. The only mutation is the registration list.
- The preview is generated by the SAME code path as registration. No second implementation.
- Headless-testable: the scan + warning computation is a pure static function over a script path,
  returning a Dictionary; the dialog only renders it.

### Test plan

- Scan a typed fixture -> expected kinds/labels/params (pins the inference contract).
- Scan an untyped fixture -> the "reads as an Action" warning fires.
- Scan a `class_name`-less fixture -> provider-id warning fires, id is a valid identifier.
- Scan a non-instantiable script -> empty result plus a reason, no crash.
- Register/unregister round-trip leaves the sheet resource as it was.

## Phase 2 - Curate (BUILT)

Tick which members publish; edit label, category and KIND in the preview table. **Apply** writes
`## @ace_*` annotations into the user's file behind a diff preview and a backup.

Built as `EventSheetACEAnnotationWriter` (pure text in, text out, pinned by `annotation_writer_test`)
plus `EventSheets.curate_provider()` for the disk half, and the table itself in
`dock_ui_builder.gd` / `provider_registry_glue.gd` (pinned by `provider_curate_test`).

Two things the design did not anticipate, both found by tests rather than by reading:

- **One declaration, several rows.** A numeric `@export` publishes FOUR verbs - read, set, add,
  subtract - and all four are views of the same `var`, so all four share one annotation block. The
  writer merges edits by declaration (opting out is sticky across them); anchoring treats
  `property` / `set` / `add` / `subtract` alike, since the latter two were otherwise sent hunting
  for a `func` of that name and reported the member as missing.
- **The KIND is the headline edit.** Correcting an untyped method's lane by writing
  `@ace_condition` - never by touching the signature - is what makes the untyped-code problem
  solvable at all, and it needed no new machinery.

Why annotations rather than a side store: they are the format the analyzer already reads, so "reopen and
edit later" is round-trip by construction; they document the script for the user's teammates; and they
survive without the plugin. A parallel metadata store would be a second source of truth that can desync.

Risks to handle: an idempotent writer (re-applying must not duplicate blocks); never touching member
bodies or signatures; `@ace_hidden` for opted-out members; and NOT routing foreign scripts through the
sheet round-trip path, which stamps `@ace_hidden` on unexposed functions and refuses untyped `func`s.

## Phase 3 - Polish (BUILT, with one deliberate limit)

**Parameter shaping** ships as the table's *Parameters...* action: a hint (including the `comparison`
shorthand), labeled options, and a starting value per parameter, written as `@ace_param(id, hint: …,
options: …, default: …)`. A param has no cell in the table, so its spec is held alongside and folded
in at collection time - a member whose ONLY change is a param spec is still written.

**Deprecation-aware renames** ship as *Keep Old Name...*, and the design is not what the spec
assumed. The assumption was that `.deprecated(message, replacement)` gave us a redirect to lean on.
It does not: `replacement_ace_id` has exactly two readers and both are string formatting, and both id
lookups (`ace_registry.gd:113` editor, eventforge `ace_registry.gd:92` built-ins) are plain
exact-match gets. Deprecation is a warning plus picker-hiding, nothing more.

Worse, the failure a rename causes is SILENT. `ActionCodegen.generate_action` (action_codegen.gd:17)
prefers the template BAKED onto the row at apply time over any registry lookup, so an orphaned row
still emits `$WaveManager.start_wave(3)`, compiles with zero errors and zero warnings, and fails at
game runtime. An id alias could not have fixed that either - every already-compiled `.gd` holds the
old CALL TEXT and no id at all.

So the shipped answer is a deprecated forwarding shim, which is the only construct that satisfies
both halves: `method:start_wave` becomes a real member again (rows resolve, render and carry params),
and the baked call text in every compiled sheet stays valid. `@ace_deprecated` gained an optional
second argument naming the successor, so the hover says where the verb went.

THE DELIBERATE LIMIT: the shim is APPENDED and nothing existing is edited - no signature, no body, no
call site. Automated member renaming (rewriting the declaration and every reference to it) is a
different and far riskier operation than adding comments and one function, and it is not offered. The
author renames in their own editor; the wizard makes the old name keep working.
