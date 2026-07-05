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

- **P1 - the widgets that matter most:** `min_max` (SHIPPED) + `info` + `header` decor (SHIPPED) + `required` markers, Look Gallery tiles + preview-card sentences, byte-gated round-trip tests, the `required` Doctor check.
- **P2 - the table drawer:** columns schema, grid widget (add/remove/reorder rows), dialog UX for defining columns in plain language, round-trip + a loot-table recipe.
- **P3 - the Inspector Designer view:** the whole-Inspector live mock with reorder/group/decor gestures and the combined Ships-as panel.
- **P4 - polish:** `validate` custom rules, preview drawers (audio/scene thumbnails), and a "Design its Inspector" entry in the Custom Resource flow + docs images.
- **P5 - the parity long tail (owner directive: get as close to full attribute-catalog parity as Godot allows):** enum toggle-button row (an enum as one row of toggle buttons instead of a dropdown), inline field button (a small per-field button calling a sheet function, riding at the end of the default editor), suggestion dropdown (a String that offers choices but accepts free text - native `PROPERTY_HINT_ENUM_SUGGESTION`), field tint (a `# @inspector_tint #rrggbb` decor arg colouring the property's editor), and label override (display a friendlier property label, editor-side).

## 5. The parity matrix (catalog -> Godot mechanism -> status)

The full attribute catalog of the best-known rich-inspector tooling, mapped honestly. "Native" = stock Godot already does it; "shipped" = EventSheets does it today; a phase tag = planned above; "won't" = Godot's Inspector model makes a faithful version dishonest, with the reason.

| Capability | Godot mechanism | Status |
|---|---|---|
| Range / Min / Max sliders | `@export_range` (+ modifier tail) | shipped |
| Min-max range slider | `min_max` drawer (Vector2) | shipped |
| Progress bar | `progress_bar` drawer | shipped |
| Color palette row | `swatch_row` drawer | shipped |
| Texture/object preview | `texture_preview` drawer + Godot's resource thumbnails | shipped |
| Curve in the field | `curve_editor` drawer | shipped |
| Tooltip | `##` doc comment (native hover) | shipped |
| Title / section header (+ accent) | `# @inspector_header` decor | shipped |
| Info box | `# @inspector_info` decor | shipped |
| Foldout / box grouping | `@export_group` / `subgroup` / `category` | shipped |
| Show If / Hide If | generated `_validate_property` | shipped |
| Enable If / Disable If | Lock Unless -> `_validate_property` READ_ONLY | shipped |
| Read-only | `@export_custom(..., READ_ONLY)` | shipped |
| On value changed | generated setter -> sheet function | shipped |
| Buttons | `@export_tool_button` | shipped |
| Multiline text | `@export_multiline` | shipped |
| File / folder paths | `@export_file` / `@export_dir` (+ filters) | shipped |
| Value dropdown (fixed) | `@export_enum` | shipped |
| Flags / layer grids | `@export_flags*` families | shipped |
| Hidden but saved | `@export_storage` | shipped |
| Clamped values | generated clamp setter | shipped |
| Searchable inspector | Godot's built-in Inspector filter box | native |
| Inline resource editing | Godot's native sub-resource foldout | native |
| Serialized dictionaries | typed Dictionary/Array exports | native |
| Required field | `required` marker + the Doctor's project-wide scan for unset instances | shipped |
| Custom validation with inline message | `# @inspector_validate` -> sheet function (needs @tool to run in-editor) | shipped |
| Table list (arrays as grids) | `table` drawer + columns schema | shipped |
| The visual designer surface | the Inspector Designer view (✎ edit + ▲ reorder) | shipped |
| Enum toggle buttons | `toggle_row` drawer (choices ride the marker) | shipped |
| Suggestion dropdown (free text + choices) | `PROPERTY_HINT_ENUM_SUGGESTION` via `@export_custom` | shipped |
| Inline field button | `# @inspector_action` -> a per-field button calling a sheet function | shipped |
| Field tint | - | won't: Godot gives no seam to restyle the STOCK editor of a property without replacing it wholesale; a fake color strip above would claim more than it does |
| Label override | - | deferred: only possible where a drawer already replaces the editor (`add_property_editor`'s label arg); revisit as a drawer option rather than a general attribute |
| Horizontal field groups | - | won't: Godot's Inspector is a single column; faking columns breaks every other plugin and theme |
| Tab groups | - | deferred: possible as an editor-side reskin of categories, but it hides properties from Godot's own search; revisit after P3 |
| Static/global inspector | - | won't: no Godot equivalent surface; the closest honest home is the autoload's own Inspector, which already works |

## 6. Verification

Per phase: marker parse + emission byte-gates (the drawer pattern's existing tests extend), a render-harness image per widget (the docs standard), the Doctor check pinned like `check_debug_residue`, and for P3 a dock-level test driving reorder through the funnel + drift=0 on a pack. The Inspector preview card's sentence matrix grows one row per new look.
