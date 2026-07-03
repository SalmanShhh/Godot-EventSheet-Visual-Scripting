# Progressive Disclosure - Spec

How the EventSheets UI reveals complexity **on demand** instead of all at once - so a newcomer (especially a
Construct 3 migrant) meets the simple case simply, while a Godot expert still reaches every advanced surface.
This documents the principle, the canonical tier model, the **existing** disclosure backbone (much of it already
shipped), and the per-surface targets so a later phase can implement the refinements without re-deriving them.

Status at a glance: the **backbone is shipped** (export-gating, the collapsible Inspector-options section,
type-gating, the per-type drawer picker, Simple Mode, the ACE-picker three-tier model). **Phases 1–4 of the
refinements are now SHIPPED**: the variable-dialog Basic/Advanced tiering + refined auto-expand (P1), the
forgiving Range parser + dial-reach prompt + magnitude-in-the-preview + "Curve preview" rename (P2), the
C3-first relabels + per-type hover hints (P3), the Simple Mode choice on the Welcome dialog (P4), and the Type
dropdown's **Number / Text / Yes-No** restructure with a "Whole numbers only" tick + advanced Godot types under
a separator (P5, commit 7fb473e). The type-alias layer is `_selected_stored_type()` / `_select_stored_type()`,
which keeps the **stored** type a real Godot type (int/float/String/bool/…), so only the dropdown's *display*
changes - the `.gd` round-trip is byte-unchanged.

## Why - the user model and the cost of overload

Three audiences share every surface, and the design must not optimize one into the others' way:

- **Construct 3 migrants** - the most likely first users. Their mental model: *"show me what I already know;
  don't make me learn engine plumbing to make a variable."* In C3 an instance variable has three types
  (Number / Text / Boolean) and is *by definition* a designer-editable property in the Properties Bar. They
  expect to set a name, a type, and a starting value - and little else up front.
- **Godot experts** - want the full depth (typed exports, `@export_group`, setters, custom drawers) reachable
  without ceremony, ideally in Godot's own vocabulary.
- **True newcomers** - want the obvious path to be the only thing they see, and to discover the rest gradually.

The failure mode is **information overload**: a dialog or picker that "throws everything at once" makes the
*simple* case feel hard and pushes C3 migrants back to C3. The codebase already names this complaint - the
Variable dialog's attribute block carries the comment *"the dialog threw everything at once"*
(`variable_dialog.gd`, above the `_attr_toggle`). Progressive disclosure is the standing answer.

**The rule:** surface the minimum the common case needs; reveal the rest on demand; lead with the vocabulary
the user already owns; and **never strand the newcomer** - disclosure hides chrome, it never hides the one
control an empty/unconfigured row still needs.

## The disclosure-tier model

Two orthogonal axes govern every surface.

**Depth tiers** - how far a control is from first sight:

| Tier | Name | What lives here | Reveal |
|---|---|---|---|
| **T0** | Always visible | The essentials for the common case, zero engine jargon | (shown) |
| **T1** | One expander away | The friendly polish a designer reaches for occasionally | a single collapse/expander |
| **T2** | Advanced | Wiring / organizational / expert surfaces that assume other state exists or Godot fluency | a nested "More…" disclosure **and/or** Simple Mode |

**Audience axis (Simple ↔ Expert)** - orthogonal to depth. **Simple Mode is the canonical audience flag**
(`event_sheet_dock.gd` `_simple_mode`, persisted in editor project metadata). Expert is the default; Simple
hides T2-class surfaces entirely. New advanced surfaces **join the existing Simple-Mode gates** (the picker's
`_SIMPLE_MODE_DENYLIST`, the right-click submenu skips) rather than inventing a parallel toggle. The
established framing - *"Everything still works in Expert mode"* - is part of the contract.

A control's home = its depth tier, gated by the audience axis. Example: *On Changed* is T2 (advanced wiring),
so it's behind the dialog's nested "Advanced" disclosure **and** absent in Simple Mode.

## The existing disclosure vocabulary (reuse, don't reinvent)

These mechanisms already ship. A new disclosed surface should be built from this set, not a new idiom:

1. **Export-gating** (`variable_dialog._update_attr_gating`) - the entire Inspector-options block is hidden
   unless `@export` is on. The single biggest lever: a plain internal variable never sees any attributes.
2. **Collapsible section** (`_attr_toggle` ▸/▾ + `_attr_section.visible`) - all Inspector attributes live
   behind one expander.
3. **Auto-expand-when-populated** (`open_for_edit`) - the section starts collapsed for new variables and
   auto-opens when the edited variable already carries attributes.
4. **Type-gated contextual rows** (`_refresh_contextual_rows`) - Options/Range/Multiline/Clamp show only for
   the types that can use them; re-run on every type change.
5. **Per-type drawer picker** (`_rebuild_drawer_options` / `_drawer_kind_for_type`) - offers *only* the one
   drawer the current type can host, and hides entirely for types with none.
6. **Self-hiding live preview** (`_refresh_drawer_preview`) - the drawer preview box materializes only when a
   drawer is selected.
7. **Modal sub-editor** (`_build_items_window`) - the per-line Array/Dictionary editor lives in its own
   window, off the main form, behind a type-gated "Edit items…" button.
8. **Default-hidden hint labels** - name-shadow / default / const / type help appear only on the relevant
   condition (live validation, not always-on instructions).
9. **Simple Mode** - the audience flag + `_SIMPLE_MODE_DENYLIST` (picker) and right-click submenu skips.
10. **ACE-picker three-tier model** (`ace_picker.gd`) - Favorites/Recent side panes + featured-bold rows + a
    selection-driven description card + the synonym/fuzzy/no-match-nudge search stack. The template for any new
    chooser.
11. **Generic fold machinery** (`_flatten_row` / fold arrow / `_fold_state`, gated on `children`) + the
    synthetic "Class setup" SECTION - in-sheet collapse that the viewport auto-unfolds on navigate-to.
12. **Reveal-on-hover with a newcomer carve-out** (`event_row_renderer`) - row chrome hides at rest, reveals on
    hover/select, but **stays visible when the row is empty/unconfigured** so beginners can still discover it.
13. **Tooltips as the on-demand info layer** - the project convention is that every toggle/menu item explains
    itself on hover in one plain sentence.
14. **Persistence tiers** - pick by data lifetime: `ProjectSettings` (PR-shareable prefs), editor
    `project_metadata` (per-project local flags like `simple_mode`/`welcomed`), `user://` ConfigFile (churny
    per-user data like picker recents), in-memory session state (view-only collapse).

## Per-surface application

### Variable dialog - `addons/eventsheet/editor/variable_dialog.gd`

**Shipped backbone:** T0 (Name, Type, Default) is always visible; the attribute block is export-gated +
collapsed + auto-expanding; Options/Range/Multiline/Clamp/the drawer picker are type-gated; the drawer preview
self-hides. A newcomer making a plain `int` sees only Scope, Name, Type, Default, and the two flags - the
attribute block stays hidden.

**The core overload (PROPOSED fix):** once the section *is* expanded (and it auto-expands on edit), all ~10
attributes appear as **one flat list** - Tooltip, Inspector group, Inspector subgroup, Range, Multiline, Show
if, Lock unless, On changed, Clamp, Read-only, drawer picker, preview. The collapse was the only tiering; the
fields inside were never tiered. Split them by depth:

- **T0 - Always visible:** Name, Type, Default (+ "Edit items…" for collections, + Options/From-enum for the
  list case).
- **T1 - "More options" (the friendly polish):** Tooltip, Range (presented as **Min / Max**, see below),
  **Show as** (the drawer, renamed - see C3 rules), Multiline, and the two flags (**Editable in the Inspector**
  and **Constant**), relabelled out of GDScript jargon.
- **T2 - nested "Advanced ▸" (wiring + organizational):** Inspector group, Inspector subgroup, Show if, Lock
  unless, On changed, Clamp, Read-only. Concretely: add a second collapsed `_attr_advanced_section` and move
  the group/subgroup and show_if/lock_unless/on_changed rows into it. These all assume *other* variables or
  functions already exist, or assume Godot-Inspector fluency, so they are pure friction at creation time -
  *Show if / Lock unless / On changed* can only produce the `must be a single identifier` error when there's
  nothing yet to reference.

**Auto-expand refinement (PROPOSED):** only auto-unfurl the section when **non-trivial** attributes exist -
editing a variable that merely has a tooltip shouldn't open the whole advanced block.

**Pre-validate dependencies (PROPOSED):** the `Clamp → Range` dependency is invisible until you check Clamp and
submit (confirm-time `Clamp needs a Range`). Disable the Clamp checkbox until a valid Range exists (mirror the
`_refresh_const_ui` disable pattern) so the dependency is visible *before* confirm, not an error after.

### Drawers & the curve editor - `attribute_drawers.gd` / `drawer_widgets.gd`

**The drawers are themselves a disclosure win:** each swaps a raw field for a visual control that hides the
numbers - a progress bar, a direction dial, a color swatch row, a texture thumbnail, an inline curve. Keep
`progress_bar`, `swatch_row`, `texture_preview`, and `curve_editor` authoring **exactly as-is**: zero or
near-zero config, sensible defaults, a self-hiding preview. They are the model, not the problem.

**The one real overload - the Range field's triple duty (PROPOSED fix):** the Vector2 dial reads its reach
from the shared **"Range"** field, so to set a dial's magnitude the user must type a 3-part `min, max, step`
string into a field that says "numeric: slider" - even though a dial has no min, no step, and no slider (only
`max` is read; min/step are silently ignored), and a wrong part-count *hard-errors* `Range needs min, max,
step`. Fixes:

- When the drawer is `vector_dial`, show a single **"Dial reach (max)"** field defaulting to a sensible value
  (100, or auto-derived from the default vector's length), instead of borrowing "Range". Keep storing it in
  `attributes.range.max` for round-trip parity - the *storage* stays; only the *authoring control* changes.
- **Relax the Range parser** to accept 1–2 parts with fallbacks (`min`→0, `step`→1) rather than hard-failing on
  ≠3 parts. Typing `300` should mean `0, 300, 1`, not an error. Config is optional; the advanced parts (min,
  step) stay hidden until wanted.
- **Make the magnitude link visible from the drawer**, not a distant row: render the current max in the
  preview caption (e.g. *"Direction dial - reach 100"*) or place the one relevant number directly under the
  picker next to the preview.
- Treat the `0, 100, 1` pre-fill as a **placeholder**, not committed text, when the field was empty - so a dial
  shows its default visually but doesn't silently bake a `100` cap the user never chose, and only a range the
  user actually edited is persisted.

**Curve editor honesty (PROPOSED):** the `curve_editor` drawer is a resource picker + a **read-only** inline
polyline - it doesn't let you shape points in place (that's Godot's stock Curve editor after assigning).
Rename the label **"Curve editor" → "Curve preview"** (or add an explicit *"Edit curve…"* affordance / a
tooltip - *"shape the curve in the Inspector after assigning"*) so it doesn't promise editing it doesn't do.

### The sheet & global surfaces ("etc")

- **Make Simple Mode discoverable (PROPOSED, highest-leverage gap):** Simple Mode is off-by-default *and*
  menu-buried, so a newcomer who skips the Welcome checkbox and never finds *View ▸ Simple Mode* gets the full
  registry by default - the ACE picker shows the entire vocabulary. Surface the **Simple / Expert** choice on
  first run in the **Welcome dialog** (reuse its existing checkbox idiom), rather than redesigning disclosure.
- **New advanced surfaces join the existing gates**, not a new toggle - add to `_SIMPLE_MODE_DENYLIST` / the
  submenu skips.
- **Menus (View ▾ / Tools ▾):** ~27 flat, undifferentiated items today. Lean on Simple Mode + per-item
  tooltips (the existing convention) and group beginner-relevant vs advanced rather than redesigning.
- **Reuse the chooser/fold/hover patterns** (#10–#12 above) for any new surface so new disclosure inherits the
  tested behavior (search synonyms, navigate-yields-to-disclosure unfold, the empty-row carve-out).

## Construct-3 migration rules (the vocabulary layer)

Disclosure isn't only *how much* you show - it's *which words*. Lead with the term the user already owns;
offer the Godot term as a parenthetical or tooltip, never as the primary label. Keep the generated GDScript
exactly as-is underneath - this is a labelling/ordering layer, not a code change.

| C3 concept | Current label | Proposed label |
|---|---|---|
| Instance-variable type (Number / Text / Boolean) | `int` / `float` / `String` / `bool` / `Variant` / 18 entries | **Number / Text / Yes-No** (+ List) up top; **int-vs-float** becomes a "Whole numbers only" checkbox under Number; `Vector2`/`Color`/`Texture2D`/`Curve`/`Variant`/`Array`/`Dictionary` move under a separated **"Advanced / Godot types"** |
| Designer-editable property (the C3 default, the whole point) | "Designer-tweakable in the Inspector (@export)", buried last | **"Editable in the Inspector (like a C3 property)"**, surfaced near Name/Type; `@export` only a trailing hint |
| (a friendly visual field) | "drawer" / "Drawer preview" | **"Show as"** (e.g. *Show as: plain field / progress bar / color swatch / dial*); preview caption just **"Preview"** |
| (ordering in the Properties Bar) | "Inspector group" / "Inspector subgroup" | **"Group under heading"** / **"Sub-heading"** |
| Properties Bar | "the Inspector" | acceptable to keep, but introduce as **"the Inspector (Godot's Properties Bar)"** on first contact |
| (no C3 concept) | "Constant (const)" | **"Constant (cannot change at runtime)"** |

**Hard rule:** `@export`, `Variant`, `const`, and "drawer" must **never** be the primary visible label. They
may appear as a trailing `(@export)`-style hint or in a tooltip, for the Godot-fluent.

## Consistency rules (invariants for any new surface)

1. **Never show a control that can't apply** - type-gate / context-gate it (the `_refresh_contextual_rows`
   pattern).
2. **Auto-reveal only for non-trivial state** - a single tooltip shouldn't unfurl an advanced block.
3. **Dependencies are pre-validated, not confirm-time-errored** - disable the dependent control until its
   prerequisite is satisfied; don't let the only feedback be an error on OK.
4. **The empty/unconfigured carve-out** - hover-revealed chrome stays visible while a row is empty, so a
   beginner can still find the action.
5. **A tooltip on every new control** - plain, one sentence, "what it does and that nothing is lost."
6. **One audience axis** - Simple Mode. Don't add a parallel beginner/expert toggle.
7. **Map each remembered disclosure state to the right persistence tier** (#14 above).

## Anti-patterns (what this spec exists to prevent)

- A flat wall of fields behind a single expander (today's `_attr_section`).
- Engine jargon (`@export`, `Variant`, `const`, "drawer") as the primary label.
- Confirm-time errors for a dependency the user couldn't see (Clamp↔Range, the dial's "Range needs min, max,
  step").
- A silent baked default the user can't distinguish from an explicit choice (the `0,100,1` dial cap).
- A second audience toggle competing with Simple Mode.
- A field whose label borrows a meaning it doesn't have (a "Range" that's really just a dial's reach; a "Curve
  editor" that only previews).

## Phasing (highest leverage first)

1. ✅ **SHIPPED - Variable-dialog tiering** - the flat `_attr_section` split into T1 ("More options") and a
   nested T2 ("Advanced"); auto-expand refined to non-trivial attributes; Clamp↔Range pre-validation (the
   Clamp checkbox is disabled, with a hint, until a valid Range is entered, instead of erroring on OK).
2. ✅ **SHIPPED - Drawer-config de-overload** - the relaxed/forgiving Range parser (a bare max works), the
   Vector2 "max reach" prompt, the magnitude-in-the-preview caption, the "Curve preview" rename. (The reach is
   prompted via the contextual Range field rather than a separate "Dial reach" field - same effect, less UI.)
3. ✅ **SHIPPED - C3-first relabelling** - "Show as", "Group under heading", "Sub-heading", "Editable
   in the Inspector (like a C3 property)", "Constant (can't change at runtime)", per-type hover hints, and the
   Type dropdown's **Number / Text / Yes-No** restructure (commit 7fb473e - round-trip-safe via
   `_selected_stored_type()`; a "Whole numbers only" tick splits int vs float).
4. ✅ **SHIPPED - Simple Mode discoverability** - the Simple/Expert checkbox on the Welcome dialog's first run.

Each lands the usual way: tests where behavior is testable (the dialog already supports headless edit-cycle
tests), a render-harness check for the visual tiers, a CHANGELOG entry, and this spec updated as items move
from PROPOSED to SHIPPED.
