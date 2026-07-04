# SPEC: The Inspector Designer - rich inspectors, designed visually

**Status:** proposed · **Date:** 2026-07-04 · **Owner ask:** expand custom inspector support so designing a polished, production-grade Inspector - especially for **Custom Resources** - is a visual act inside the sheet, with per-property widgets, validation, conditional display, and structured list editing that match the best-in-class inspector tooling in other engines.

The point: an Inspector is a game team's most-used UI, and today making a GOOD one in Godot means memorizing annotation trivia. EventSheets already turned single properties into plain-language choices (the Look Gallery, the Inspector preview card, drawers, Show If / Lock Unless, tool buttons). This spec scales that from "one property at a time" to "the whole Inspector, designed as one visual surface" - and closes the remaining widget gaps.

## 1. What already ships (the foundation census, verified)

| Capability | Mechanism | Where |
|---|---|---|
| Every `@export` hint family | plain-language looks + "Ships as:" strip | Variable dialog, `inspector_looks.gd` (21 looks) |
| Choose by picture | Look Gallery tiles + live Inspector preview card | `look_gallery_dialog.gd`, `inspector_preview_card.gd` |
| Custom widgets (drawers) | `## eventsheet:<kind>:<args>` marker + `EditorInspectorPlugin` | `attribute_drawers.gd` (progress_bar, dial, swatch, texture, curve) |
| Conditional display | Show If / Lock Unless → emitted `_validate_property` | compiler ~1735 |
| Buttons | `@export_tool_button` from a sheet function's button label | compiler ~360 |
| Grouping | groups + subgroups (drag-to-bubble), `@export_group`/`@export_subgroup` | variable folders |
| Reactivity | `on_changed` attribute → setter calling a named function | variable attributes |
| Clamp / read-only / tooltip | attributes → setters / `@export_storage` / `##` doc line | variable attributes |

**Covenant constraints (unchanged, load-bearing):** everything compiles to plain GDScript with zero plugin dependency in the exported game; drawers and decor are EDITOR-side sugar keyed off comment markers, so deleting the plugin costs only editor chrome, never behavior; every new emitted shape is byte-gated (emit → lift → re-emit identical, else the lift refuses and the line stays raw).

## 2. The gaps this spec closes

1. **Inline validation.** A property can be *required* (a Resource slot that must be set, a String that must be non-empty) or carry a *custom rule* ("max_health >= starting_health"). Today nothing surfaces in the Inspector; teams find out at runtime.
2. **Structured list editing.** `Array[Dictionary]` and arrays of Resources render as Godot's generic array UI - the single most painful editing surface for data-driven design (loot tables, wave definitions, dialogue lines). A **table drawer** with a columns schema turns them into an editable grid.
3. **Min-max ranges.** A two-headed slider writing a `Vector2` (min, max) - spawn intervals, damage ranges, zoom bounds. Constantly needed, currently two separate floats.
4. **Decor.** Info boxes ("this resource is shared - edits affect every user"), section headers with accent color, and a read-only computed line (`preview: 2.5s per wave`). Groups organize; decor *explains*.
5. **The Designer itself.** Per-variable dialogs cannot answer "what does my WHOLE Inspector look like?" A Custom Resource with 15 tunables needs one live canvas: every property rendered as the real Inspector will show it, drag to reorder and regroup, click any row to jump into its Variable dialog, one combined "Ships as:" panel.

## 3. Design

### 3a. New drawers and markers (same seams as the shipped five)

| New kind | Marker shape | Widget | Emits underneath |
|---|---|---|---|
| `min_max` | `## eventsheet:min_max:0:100` | two-headed range slider | `@export var x: Vector2` (x=min, y=max) |
| `table` | `## eventsheet:table:name:int,hp:int,drop:String` | editable grid, one row per element, add/remove/reorder | `@export var x: Array[Dictionary]` |
| `info` | `## eventsheet:info:Shared resource - edits affect every user.` | a quiet info panel above the next property | comment line only (decor never emits code) |
| `header` | `## eventsheet:header:Combat:#e06666` | accent-colored section label | comment line only |
| `required` | `## eventsheet:required` | red outline + "(required)" suffix while unset/empty | comment line only; ALSO a Doctor check flags scenes/resources saved with required fields empty |
| `validate` | `## eventsheet:validate:is_valid_range` | inline warning row when the named sheet function returns a non-empty String | comment line; the validator is a plain sheet function (bool/String), callable in the editor via the existing tool-mode path |

Rules: markers stay comment-only (byte-safe by construction, exactly like the shipped drawers); type-gated at emission (a `table` on a non-Array refuses in the dialog, not at compile); every marker round-trips through the existing generic marker parse (`attribute_drawers._parse_config`).

### 3b. The Inspector Designer view

A dialog (Sheet ▸ Inspector Designer, and a button in the Custom Resource empty-sheet advice) built like the Look Gallery + preview card, but for the WHOLE sheet:

- **Left: the live mock** - every exported variable rendered top-to-bottom with its group headers, subgroup indents, drawers, decor, and conditional-display state, using the same miniature builders the Look Gallery tiles use (one source of truth: `EventSheetInspectorLooks`).
- **Interactions:** drag a row to reorder (rewrites the variable's position in the sheet - the same array-order move the round-trip already supports); drag onto another to group (the shipped bubble gesture, surfaced here); double-click opens that variable's dialog; right-click adds decor (header / info box) above.
- **Right: the whole story** - the plain-sentence summary per property (the shipped `describe()` strings, stacked) and one combined "Ships as:" strip showing the full `@export` block the Inspector compiles to.
- **PURE VIEW + the undo funnel:** the mock only reads; every mutation routes through `_perform_undoable_sheet_edit`, so reorders and grouping are single undo steps and round-trips stay byte-exact.

### 3c. Custom Resources are the hero

The script-intent flow already lands people on a Custom Resource sheet; the Designer is its natural next click. The empty-sheet advice gains "Design its Inspector…"; the recipes gain a data-asset example (an `EnemyStats` resource with a table of attacks, a min-max damage range, a required icon, and a validation rule).

## 4. Phases

- **P1 - the widgets that matter most:** `min_max` + `info` + `header` + `required` drawers/markers, Look Gallery tiles + preview-card sentences for each, byte-gated round-trip tests, the `required` Doctor check.
- **P2 - the table drawer:** columns schema, grid widget (add/remove/reorder rows), dialog UX for defining columns in plain language, round-trip + a loot-table recipe.
- **P3 - the Inspector Designer view:** the whole-Inspector live mock with reorder/group/decor gestures and the combined Ships-as panel.
- **P4 - polish:** `validate` custom rules, preview drawers (audio/scene thumbnails), and a "Design its Inspector" entry in the Custom Resource flow + docs images.

## 5. Verification

Per phase: marker parse + emission byte-gates (the drawer pattern's existing tests extend), a render-harness image per widget (the docs standard), the Doctor check pinned like `check_debug_residue`, and for P3 a dock-level test driving reorder through the funnel + drift=0 on a pack. The Inspector preview card's sentence matrix grows one row per new look.
