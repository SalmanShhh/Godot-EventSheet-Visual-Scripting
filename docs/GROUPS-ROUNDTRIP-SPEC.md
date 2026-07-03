# Event Groups - Round-trip Spec (EventSheet groups ↔ GDScript)

How C3-style **event groups** survive a GDScript round-trip - compile a sheet to `.gd`, reopen the
`.gd` as a sheet, and get your groups back. **SHIPPED** (commit 90367eb): the compiler emits recoverable group
markers and the importer reconstructs the `EventGroup` rows, verify-lift-gated. Grounded in the actual
compiler/importer.

> Not to be confused with **`@export_group`** - that's the *variable* Inspector-grouping feature, which already
> round-trips (see INSPECTOR-ATTRIBUTES-SPEC + `_absorb_tree_variable_group`). This spec is about **event
> groups** (`EventGroup` rows - the named, collapsible, toggleable containers of *events*).

Status at a glance: event groups **round-trip** - **SHIPPED** (commit 90367eb). A group's rows are flattened
*and re-bucketed by trigger* at compile, so they don't stay contiguous in the output; round-trip is recovered
by a class-scope `## @ace_group(...)` declaration per group plus a per-row `# @group:<slug>` membership tag,
and the importer reassembles a group from all rows carrying its slug regardless of which handler function each
scattered into. The whole pass is verify-lift-gated, so a sheet that can't round-trip degrades to flat/verbatim
rather than corrupting.

## What Construct 3 groups are (the reference)

A C3 **group** is a named, collapsible container of events that is part of the event structure and is
preserved: it has a **title** + optional **description**, can be **enabled/disabled** (and toggled at runtime
via *Activate/Deactivate group*), can **nest**, and folds in the editor. Common use: organizing a sheet into
labelled sections (Movement, Combat, UI) and toggling whole behaviors on/off.

## What EventSheets does today (SHIPPED - groups dissolve at compile)

The `EventGroup` resource (`addons/eventforge/resources/event_group.gd`) carries: `name` (+ `group_name`
alias), `description`, `enabled`, `collapsed` (+ `expanded` alias), `color_tag`, `custom_color`, `group_uid`,
`runtime_toggleable`, `events` (+ `rows` alias), `local_variables`. In the editor a group is a real,
foldable, colorable container. **At compile it is dissolved:**

- **Flatten** - `_flatten_trigger_rows` (`sheet_compiler.gd` ~690–714) recurses an *enabled* group and
  appends its `EventRow`s directly into a flat list with **no surrounding marker**. A **disabled** group is
  skipped at `if group.enabled:` - **every child row is dropped, silently** (no breadcrumb).
- **Re-bucket by trigger** - `_emit_grouped_trigger_functions` (~736–750) then re-buckets the flat rows by
  *trigger key*, so a group's rows **scatter across handler functions** (its `OnProcess` rows land in
  `_process`, its `OnReady` rows in `_ready`) and intermix with other groups' rows sharing a trigger. Group
  **adjacency is not preserved**.
- **The only surviving traces:**
  - **runtime_toggleable** groups emit a `var __group_<snake>_active: bool = true` member and AND-wrap every
    contained event's condition with it (`if __group_<snake>_active and …`). The snake-cased name is embedded
    in those guards - but lossily (`to_snake_case()` collides `"Enemy AI!"`→`enemy_ai`; an empty name →
    literal `"group"`), and it marks the guard, not the group's row bounds.
  - **group-local variables** emit under a `# <name> - group locals` header comment - the *only* place a
    plain group's name appears, and only when the group has locals; it's free-text, not a parseable marker.
- **No recovery.** The importer reconstructs `RawCodeRow` / `LocalVariable` / `EnumRow` / `SignalRow` and the
  class-scope metadata (`@ace_tags` / `@ace_family` / `@icon` / `class_name`), and the deeper `ace_lifter`
  reverse-matches events/functions/conditions - but **nothing in the import path reconstructs an `EventGroup`
  from `.gd`**: the editor creates groups interactively (the dock's *Add Group* / snippets), yet neither
  `gdscript_importer` nor `ace_lifter` ever does - `ace_lifter` only *descends into* already-existing groups. So
  group structure is **one-way: lost on compile, never recovered on lift**. The `__group_<name>_active` guard
  re-imports as plain GDScript (a member + `if` lines), not as a toggleable group.

This applies to both the `.tres` path and the external/`.gd`-backed path (`_compile_external` ~490 funnels
groups into the same flatten+dissolve). Since **`.gd` is now the default sheet format**, opening any `.gd`
sheet returns flat, ungrouped events.

## The loss surface (what a `.gd` round-trip loses today)

| Group property | Round-trips? | Severity |
|---|---|---|
| The `EventGroup` container itself (which rows are grouped) | ✗ lost | high |
| `name` / `group_name` | ✗ (only a lossy snake-case for toggleable groups) | high |
| `description` | ✗ emitted nowhere | high |
| `runtime_toggleable` + its `__group_<name>_active` guard | ✗ (guard becomes plain code) | high |
| Nesting (groups within groups) | ✗ lost | high |
| `collapsed` / `expanded` fold state | ✗ emitted nowhere | medium |
| `color_tag` / `custom_color` | ✗ emitted nowhere | medium |
| `local_variables` (the `# … - group locals` block) | ◑ the vars survive as class members; the grouping doesn't | medium |
| A disabled group's child rows | ✗ **silently dropped** | high |

## The constraint that makes this non-trivial

Because rows are **re-bucketed by trigger**, a group's rows are **not contiguous** in the output (a group
spanning `OnProcess` + `OnReady` is split across `_process` and `_ready`). So a single `#region <name>` /
`#endregion` boundary **cannot** bracket a group in general. Any round-trip scheme must carry **per-row group
membership** that survives the scattering, plus a per-group metadata declaration.

## Fix design (SHIPPED - commit 90367eb)

> **As built**, matching the design below with two refinements: (1) the group `uid` is a **deterministic
> name-slug** (`to_snake_case` of the group name, de-duplicated) rather than a random id, so re-saves stay
> stable; nesting is carried by a `parent="<slug>"` key in the declaration (not a `>` in the row tag). (2) The
> byte-verify **strips the group-marker lines** before comparing, so a sheet whose groups interleave across
> triggers still recovers approximate grouping instead of falling back to a raw verbatim block. The importer
> entry point is `_reconstruct_groups` (ace_lifter.gd), not a standalone `_try_lift_group`. Test:
> `tests/group_roundtrip_test.gd`.

The pattern mirrors the proven ones - `@ace_tags`/`@ace_family` round-trip via class-scope `##` markers
(`gdscript_importer.gd` ~138–155), and `@export_group` variable grouping round-trips via
`_absorb_tree_variable_group` + the **verify-lift rule** (re-emission must reproduce the source byte-for-byte,
else it stays a verbatim block - a wrong guess degrades, never corrupts).

**1. Declare each group once (class-scope marker).** Emit, alongside `@ace_tags`:
`## @ace_group(uid="g1", name="Combat", description="…", color="#e23b3b", collapsed=false, toggleable=false)`
- one per group, carrying every editor field. Nesting is captured by a `parent="g1"` key.

**2. Tag each emitted row with its group (survives re-bucketing).** Append a trailing membership comment to
each grouped row's emitted block, e.g. `# @group:g1` (nested: `# @group:g1>g2`). Per-row tags survive the
scatter across handler functions - the importer reassembles a group from all rows carrying its uid, regardless
of which function they ended up in.

**3. Importer `_try_lift_group` pass.** Parse the `## @ace_group(...)` declarations + the per-row `# @group:`
tags, reconstruct `EventGroup` resources (name/description/color/collapsed/toggleable/nesting), and re-nest the
tagged rows under them. **Verify-lift-gated**: re-emit the reconstructed sheet; if it reproduces the source
byte-for-byte, keep the groups; otherwise leave the rows flat (never corrupt). This is the same safety net
that makes `@export_group` and the drawer round-trip safe.

**4. Coexist with the existing mechanisms (no drift for groupless sheets).**
- The `__group_<name>_active` **guard stays** the runtime toggle mechanism; the `## @ace_group(..., toggleable=true)`
  marker is what *recovers* the toggleable flag (the guard alone is lossy). They're complementary.
- The `# <name> - group locals` header folds into the group reconstruction (the locals re-nest under the group).
- **Byte-stability / drift=0**: markers + tags are emitted **only when a group exists**, so groupless sheets
  (every current showcase/test) are byte-unchanged.

**Caveat - cross-trigger ordering.** A group's rows scatter by trigger, so on reopen the group's *membership*
is recovered but the exact intra-group interleaving across triggers is approximate. The verify-lift guarantees
byte-stability regardless: if the reconstructed grouping doesn't re-emit identically, it falls back to flat.

## Minimum-viable improvements (short of full round-trip)

Cheap, high-value even before the full scheme - both align with the project's "nothing is silently dropped"
philosophy (`compile()` ~362):

- **Name the group in output.** When flattening an *enabled* group, emit a `# <group name>` comment so the
  generated `.gd` is at least human-readable as to which rows were grouped (today plain groups leave nothing).
- **Don't silently drop disabled groups.** Emit `# (disabled group "<name>" - N rows omitted)` instead of
  vanishing the children, so the information loss is visible.

## Phasing

1. **Minimum-viable traces** - the enabled-group name comment + the disabled-group breadcrumb. Tiny, no
   round-trip yet, immediately improves readability and stops silent drops.
2. **Full round-trip** - the `## @ace_group(...)` declaration + per-row `# @group:` tags + `_try_lift_group` +
   verify-lift, with a test parallel to `variable_group_roundtrip_test.gd` (build a nested, colored,
   toggleable group → compile → `import_external_source` → assert the same group comes back AND recompiles
   byte-for-byte).
3. **Full fidelity** - nesting, `collapsed`/`color`/`description`, and re-nesting group-locals; raise the
   editor's inline group provenance to match.

Phases 1–2 landed the usual way (commit 90367eb): a round-trip test (`tests/group_roundtrip_test.gd`), a
CHANGELOG entry, and a render-harness check that a reopened sheet shows its groups. Phase 3 (exact intra-group
cross-trigger ordering fidelity) remains approximate **by design** - the verify-lift keeps it byte-safe, so a
grouping that can't re-emit identically degrades to flat rather than corrupting.
