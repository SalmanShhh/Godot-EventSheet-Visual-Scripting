# Includes — Spec (Construct 3 "Include event sheet" → EventSheets)

How Construct 3's **Include event sheet** concept maps onto EventSheets: what's shipped (a compile-time merge),
what already matches C3, and the parity gaps worth closing. Grounded in the actual implementation
(`sheet_compiler._merge_includes`, `event_sheet.includes`, the Include Manager). Marks SHIPPED vs PROPOSED so
a later phase can act without re-deriving the constraints.

Status at a glance: the **core feature is SHIPPED** — an `includes: Array[String]` list that compile-merges
other sheets' variables/functions/rows, with a depth limit, cycle detection, policy gating, an Include Manager
(add/remove/reorder + read-only provenance preview), and Extract-to-Include. The **execution-order gap is now
SHIPPED too** (commit 5164393): included events run **before** the root's own events, matching C3's
"include the library at the top". **One semantically-important gap remains PROPOSED**: includes **don't
round-trip through a `.gd` sheet** (the default format), so a `.gd`-backed sheet silently drops them — and
that one is **blocked on a design decision** (see "Parity gaps" below), not just effort.

## What Construct 3 does (the reference)

C3's *Include event sheet* is a **live, by-reference composition**:

- An event sheet references **other whole sheets**; the included sheet's events run **in place at the position
  of the include node**, top-to-bottom, **every tick** — as if pasted there, but still pointing at the one
  canonical sheet.
- **By-reference:** edit the included sheet once and behavior updates everywhere it's included. In the editor,
  included events appear **read-only in context** with a link to jump to and edit the source.
- **Position matters + is reorderable:** includes are conventionally placed at the very **top** so shared
  logic (a global/library sheet) runs *before* the layout's own events.
- **The classic use:** one **global / library / functions** sheet (reusable functions + shared events)
  included across many layouts' sheets — author once, reuse project-wide. Functions in an included sheet are
  callable from the includer.
- **Nested / transitive:** an included sheet may include others; the whole chain flattens into the running
  sheet.
- **Granularity:** you include a *whole* sheet (not a fragment), but you choose *where* the include sits.

(Sources: Construct 3 manual — *Event sheet includes*.)

## What EventSheets does today (SHIPPED — a compile-time merge)

EventSheets reproduces the **end goal** (reuse, library sheets, function sharing, an Include Manager with a
provenance preview) via a different **mechanism**: a **compile-time merge** that flattens included sheets into
the generated GDScript. There is no runtime include node; the merge happens once, at compile.

**The model** — `addons/eventforge/resources/event_sheet.gd:64` `@export var includes: Array[String]` (paths
to other event sheets). Merged by `addons/eventforge/compiler/sheet_compiler.gd` `_merge_includes` (~lines
622–685), called once from `compile()` (~84–94) **before** all emission:

- **What merges, root-seeded-first:** the root sheet's `events` / `functions` / `variables` are copied first,
  then each include's content is **appended**:
  - **Variables** (the `variables` Dictionary) — root wins on a name collision (the included value is dropped).
  - **Functions** (`EventFunction` resources) — root wins by `function_name`; non-colliding ones are appended.
  - **Event rows** (`all_events.append_array(included.events)`) — appended **unconditionally**. Everything in
    `events` rides along here: EventRows, groups, comments, enums, signals, tree/local variables, and
    class-level GDScript blocks (`RawCodeRow`). So enums/signals/blocks merge *through* the events channel, not
    as dedicated cases.
- **Order:** **includes-first** (an included sheet's events run *before* the root's — `all_events` is seeded
  with the includes and the root's own events are appended last; `sheet_compiler.gd` ~94–108), recursion
  **depth-first** (a chain A→B→C emits A, B, C). Root always wins variable/function collisions; among includes,
  the first-merged wins.
- **Depth limit:** policy `max_include_depth` (default **2**); past it, a warning (default) or error.
- **Cycles / duplicates:** a `visited` set keyed by include **path string** breaks cycles (A→B→A) and dedupes
  diamonds (the same path merges at most once).
- **Loading:** `load(include_path) as EventSheetResource` — a `.tres` or imported `.gd`-backed sheet, read into
  the local compile arrays only.
- **Policy-gated:** `_addon_policy` (ProjectSettings `eventsheets/addons/*`, see ADDON-COMPOSITION-SPEC) —
  `include_sources` (where includes may come from), `collision_policy`, `depth_overflow`. Gates affect
  warnings/errors, never the emitted bytes.
- **Invariant:** *compile-time only — included rows never enter the editing model.* The root sheet stays
  authored as itself; the merge is a property of the compiled output.

**The UX** — a **Manage Includes** window (add via FileDialog / remove / reorder), a read-only **provenance
preview** pane, and **Extract-to-Include** (turn selected events into a library include in one action — no
direct C3 equivalent; C3 users hand-move events to a new sheet). `EventSheetIncludes.included_rows()` resolves
the transitive chain for the preview.

## Parity — what already matches C3

| C3 concept | EventSheets |
|---|---|
| Reuse logic across sheets | ✅ compile-merge of variables/functions/rows |
| Library / functions sheet | ✅ any sheet can be included; its functions are callable |
| Edit-once-affects-all (by-reference) | ≈ by-reference at **compile** time — consumers pick up changes on the next recompile (which compile-on-save / attach / export already trigger) |
| Nested / transitive includes | ✅ depth-first recursion (depth-limited) |
| Right-click "Include event sheet" | ✅ Manage Includes → Add… |
| Read-only included events + jump-to-source | ◑ a read-only **provenance preview** in the Manage Includes window (not yet inline in the main viewport) |
| Extract events to a shared sheet | ✅ **Extract-to-Include** (one action; better than C3's manual move) |

## Parity gaps

### Must-fix — semantics & default-path parity

- **Execution ORDER (HIGH — was the only semantically *wrong* difference) — ✅ SHIPPED (commit 5164393).**
  Included events now run **before** the root sheet's own events: `compile()` seeds `all_events` with the
  includes and appends the root's events last (`sheet_compiler.gd` ~94–108), matching C3's "include the library
  at the top" so shared/library logic initialises first. A no-includes sheet stays byte-identical. Pinned by
  `tests/include_order_disabled_group_test.gd`.

- **`.gd` sheets don't round-trip includes (HIGH) — PROPOSED, but blocked on a design decision.** The compiler
  merges included rows inline with **no marker/comment**, and the importer recovers no include list — so saving
  a sheet as `.gd` and reopening it **silently drops its includes** (the external/`.gd` path explicitly skips
  includes — `_compile_external` warns "GDScript-backed sheets ignore Includes/Uses/Requires", ~`sheet_compiler.gd:505`).
  Since **`.gd` is now the default sheet format**, includes are effectively unavailable on the default path. This
  is the only major sheet-level metadata *without* a round-trip marker — contrast `@ace_tags` / `@ace_family` /
  `@icon`, which round-trip via class-scope comment markers recovered in `gdscript_importer.gd`.
  **The blocker isn't effort — it's a contract conflict.** A `.gd` is a single-file, byte-exact, *self-contained*
  source of truth. Flattening merged foreign rows inline makes the file unable to distinguish authored-here from
  merged-from-include on the next import (they'd duplicate/double-emit on every round-trip); keeping them out
  keeps the file self-contained but means includes do nothing. **Resolve first:** should a `.gd` stay
  self-contained byte-exact (then includes can only be marker-persisted metadata that re-merges at compile,
  making the file depend on foreign sheets), or stay literally lossless 1:1 (then foreign rows can't be merged)?
  **Safe first step:** emit an `## @ace_includes(res://a.tres, res://b.tres)` marker recovered by the importer
  (alongside `@ace_tags`) as **metadata-only**, so the list stops silently vanishing — and defer the re-merge
  semantics until the contract decision is made. ⚠️ A re-merge implementation is **NOT** bounded by the
  byte-verify net: a single-compile byte check won't catch rows silently *doubling* on each resave, so any test
  must be compile → import → compile → diff.

### Feature gaps — closer to C3

- **Include-at-a-point (MEDIUM).** Includes are whole-sheet, declaration-order-only, with no row placed among
  the events. C3 drops an **include node** anywhere in the list and reorders it.
  **Fix:** represent an include as a real, placeable **include row** in the events tree; the merge splices the
  included events at the row's index instead of appending. *This subsumes the order fix.*

- **Project-global / auto-include (MEDIUM).** C3's most common pattern is one library/functions sheet included
  *everywhere*; here each sheet must add it by hand.
  **Fix:** a ProjectSettings **always-include** list (e.g. `eventsheets/includes/always`) or a per-sheet
  "global library" flag that auto-prepends a common sheet to every compile.

- **Unify the two Extract-to-Include implementations (MEDIUM).** The dock's `_do_extract_to_include`
  (`event_sheet_dock.gd:~1669`) **duplicates** rows, while the unit-tested helper
  `EventSheetIncludes.extract_to_include` (`sheet_includes.gd:~64`) **moves** them preserving uids
  (byte-for-byte relocation). They diverge, and the dock path violates the helper's uid-preservation contract.
  **Fix:** the dock should call the helper (or delete the helper and test the dock path).

### Polish

- **Inline provenance (LOW).** Provenance shows only inside the Manage Includes window, never inline in the
  main viewport, so a merged sheet doesn't "read as one whole" while editing — despite the design intent.
  `included_rows()` already resolves the data; render it read-only (with jump-to-source) in
  `event_sheet_viewport.gd`.
- **An Includes panel showing the chain (LOW).** Render the transitive chain as a **tree** (root → includes →
  nested) with the read-only provenance, so the full composition + order is legible at a glance.
- **Event-row collision detection (LOW).** The event-row merge has no name-collision check (unlike variables /
  functions), so two includes contributing same-named enums / signals / class-level helpers can emit
  duplicate, non-parsing declarations with no merge-time warning. Add a warning (parallel to the
  variable/function collision messages).
- **Canonical cycle keying (LOW).** `visited` keys on the raw path **string**, so two spellings / a UID alias
  of the same sheet bypass dedupe. Normalize (UID / absolute path) before keying.
- **Depth default (LOW).** `max_include_depth` defaults to **2** — shallow for a library-of-libraries. Raise
  the permissive default, and prefer warn-never-error so jam users don't hit a wall.
- **Field-doc nuance.** `event_sheet.gd:64–68` lists "class-level blocks" as a distinct merged category, but
  there's no separate block-merge — blocks ride inside `included.events` as `RawCodeRow` rows. Accurate in
  effect; the wording implies a channel that doesn't exist. Tidy the comment.

## Suggested phasing (highest parity-value first)

1. **`.gd` round-trip** — the remaining semantically-important item (the **order fix shipped** in 5164393). Needs
   the contract decision first (see "Parity gaps"); safe first step is the metadata-only `## @ace_includes(...)`
   marker so the list stops silently vanishing, deferring re-merge semantics. Test compile → import → compile.
2. **Unify Extract-to-Include** — point the dock at the uid-preserving helper; add a dock-flow test.
3. **Include-at-a-point** — a placeable include row (subsumes #1's order fix into a positional model).
4. **Project-global auto-include** — the always-include list / global-library flag.
5. **Polish** — inline provenance, the chain tree panel, event-row collision warnings, canonical cycle keying,
   depth default.

Each lands the usual way: a test where behavior is testable (`bookmarks_includes_test` covers the merge
semantics today; add coverage for the `.gd` round-trip, the dock Extract-to-Include flow, and execution
order), a CHANGELOG entry, and this spec updated as items move PROPOSED → SHIPPED.
