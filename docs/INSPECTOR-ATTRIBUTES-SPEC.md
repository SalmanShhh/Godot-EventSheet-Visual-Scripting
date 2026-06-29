# Inspector Attributes — Spec

Unity-style (and Odin-Inspector-style) **attributes on exported variables**, mapped onto
what Godot actually supports. Status: **Tiers 1–2 SHIPPED** (tooltip/group/range/multiline; clamp/on-changed
setters, Show If / Lock Unless via generated `_validate_property`, static read-only —
`tests/inspector_attributes_test.gd`); tool buttons SHIPPED; **Tier 3 SHIPPED IN FULL** — all five drawers
(`progress_bar`, `vector_dial`, `swatch_row`, `texture_preview`, `curve_editor`) via the `eventsheet:<drawer>`
marker, each round-tripping into an editable `attributes.drawer` (not a stray `@export_custom` block), with a
per-type picker + live widget preview in the Variable dialog and four new host value types (Vector2 / Color /
Texture2D / Curve) — `tests/inspector_drawer_roundtrip_test.gd`. This documents the design so the constraints
don't have to be re-derived.

## Goal

Sheet variables (and behavior-pack properties) already compile to `@export` /
`@export_enum` / typed declarations. This phase lets the **Variable dialog** attach
richer *inspector attributes* — range sliders, headers, tooltips, conditional
visibility, buttons — so sheet-built nodes and behaviors feel as polished in the
Inspector as hand-tuned Unity/Odin components.

Everything must obey the two standing contracts:

- **Parity contract** — attributes compile to plain, idiomatic GDScript (annotations,
  doc comments, setters, `_validate_property`). No plugin runtime, no reflection layer.
- **Lossless rule** — every emitted construct must round-trip: the importer/lifter
  recovers the attribute from the generated code, and re-emission is byte-identical.

## Tiers (implementation phases)

### Tier 1 — pure annotations (cheap: emit one line, lift one line)

| Unity / Odin | EventSheets attribute | Godot mechanism / emitted code |
|---|---|---|
| `[Range(0,100)]` | **Range** (min, max, step, slider) | `@export_range(0, 100, 1)` (+ `or_greater`/`or_less` flags) |
| `[Min(0)]` | Range with open top | `@export_range(0, 1e10, 0.01, "or_greater")` |
| `[Tooltip("…")]` | **Tooltip** | `## text` doc comment line above the export — Godot shows it natively as the Inspector tooltip |
| `[Header("Combat")]` / Odin `[FoldoutGroup]` | **Group / Subgroup / Category** | `@export_group("Combat")`, `@export_subgroup`, `@export_category` |
| `[Multiline]` / `[TextArea]` | **Multiline** | `@export_multiline` |
| `[HideInInspector]` (still saved) | **Hidden (stored)** | `@export_storage` |
| Unity file pickers | **File / Dir** (with filter) | `@export_file("*.ogg")`, `@export_dir`, `@export_global_file` |
| color without alpha | **Color (no alpha)** | `@export_color_no_alpha` |
| layer masks | **Layers** | `@export_flags_2d_physics` / `_2d_render` / `_3d_physics` / `_3d_render` / `_navigation` / `_avoidance` |
| flag enums | **Flags** | `@export_flags("Fire", "Ice", "Poison")` |
| node/resource refs | **Node / Resource (typed)** | `@export var target: Area2D` (typed export), `@export_node_path("Area2D")` |
| exponential sliders | **Range (exp)** | `@export_range(…, "exp")` |
| degrees-as-radians | **Angle** | `@export_range(…, "radians_as_degrees")` |

Already shipped and folded into this table when the phase lands: **Combo** (enums →
`@export_enum`) and collection types.

### Tier 2 — generated support code (setters / callbacks / buttons / warnings)

| Unity / Odin | EventSheets attribute | Emitted code |
|---|---|---|
| Odin `[OnValueChanged("m")]` | **On Changed → sheet function** | `@export var hp: int = 10: set(value): hp = value; _on_hp_changed()` — the target is a sheet function; works in-editor with tool sheets |
| Odin `[ValidateInput]` / `[MinValue]` clamp | **Clamp / Validate** | setter emitting `clampi`/`clampf` or the validation expression |
| Odin `[Button("Label")]` | **Tool Button** | `@export_tool_button("Label") var _do_x: Callable = do_x` (Godot 4.4+; gate on engine version, warn otherwise) |
| Odin `[ShowIf("use_gravity")]` / `[HideIf]` / `[EnableIf]` | **Show If / Read-only If** | generated `_validate_property(property)`: clears `PROPERTY_USAGE_EDITOR` (ShowIf) or sets `PROPERTY_USAGE_READ_ONLY` (EnableIf) when the predicate variable is false. One generated function aggregates all conditions — must stay byte-stable for the lift |
| `[ReadOnly]` | **Read-only** | `@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT \| PROPERTY_USAGE_READ_ONLY)` |
| `[RequireComponent(typeof(X))]` | **Requires sibling/child node** | generated `_get_configuration_warnings()` — already half-exists for behavior host checks; extend with per-attribute checks |

Round-trip note: Tier 2 emits **canonical shapes** (like `_emit_enum_line` /
`_export_enum_prefix` today) — one fixed formatting per attribute so `_try_lift_*`
reverse-matching stays exact. Setter bodies that the user edits by hand simply fail the
lift and stay verbatim blocks (lossless rule holds).

Variable **grouping** (`@export_group`/`@export_subgroup`) round-trips for **both** variable kinds —
sheet-level (dict) variables *and* tree-placed `LocalVariable`s. On import the standalone group lines are
recovered onto the variable's `attributes` by the importer's `_absorb_tree_variable_group()` (gated by the
byte-identical verify-lift), and `_emit_tree_variable_line` re-emits them matching `_emit_variables`
byte-for-byte — so a reopened grouped variable is a clean grouped variable, not a stray `@export_group`
GDScript block. The variable **tooltip** (`## doc`) and the Tier-2 structured attributes (Show If / Clamp /
On-Changed) are not yet lifted back — they stay byte-stable verbatim blocks on reopen (the lossless *byte*
rule holds; only the editable semantics degrade).

### Tier 3 — Odin-level custom drawers (EditorInspectorPlugin) — SHIPPED IN FULL

A single `EditorInspectorPlugin` (`addons/eventsheet/editor/attribute_drawers.gd`, registered in
`eventforge/plugin.gd`) recognizes an `@export_custom(PROPERTY_HINT_NONE, "eventsheet:<drawer>")` hint string
and swaps in a richer control. **Generated scripts stay plain GDScript** — without the plugin (or in an
exported game) the property renders as a normal field (graceful degradation, parity preserved).

The five drawers, their host types, and marker forms:

| Drawer | Host type | Marker | Control |
|---|---|---|---|
| `progress_bar` | int / float | `eventsheet:progress_bar:<min>:<max>` | drag-to-set bar |
| `vector_dial` | Vector2 | `eventsheet:vector_dial:<max>` | draggable direction + magnitude dial |
| `swatch_row` | Color | `eventsheet:swatch_row` | palette presets + picker |
| `texture_preview` | Texture2D / String | `eventsheet:texture_preview` | thumbnail + resource/path field |
| `curve_editor` | Curve | `eventsheet:curve_editor` | inline curve render + resource field |

Implementation notes:
- **One emitter, both var paths.** `SheetCompiler._drawer_export_prefix(attributes, type_name)` builds the
  marker (type-gated) for both `_emit_variables` (dict vars) and `_emit_tree_variable_line` (tree vars).
- **Round-trip.** `GDScriptImporter._extract_drawer_from_hint` recovers the marker into `attributes.drawer`
  (+ `range` bounds for progress_bar/vector_dial), verify-lift-gated — so a reopened drawer is an editable
  drawer, never a verbatim block. progress_bar/texture_preview/curve_editor have clean defaults and round-trip
  fully; vector_dial/swatch_row round-trip once the host Vector2/Color default round-trips (see below).
- **Host value types.** Vector2 / Color / Texture2D / Curve are first-class variable types now
  (`variable_dialog.TYPE_OPTIONS`); `_to_code_literal` emits `Vector2(x, y)` / `Color(r, g, b, a)` and
  `variable_parser` lifts those constructor literals back via `str_to_var`.
- **Authoring UX.** The Variable dialog offers exactly the one drawer the chosen type can host, and shows a
  **live preview** of the actual widget (the reusable Controls in `drawer_widgets.gd`) that updates as the
  type / drawer / bounds change. Those same Controls back both the Inspector drawers and the preview.
- Tests: `tests/inspector_drawer_roundtrip_test.gd` (emission, type-gating, recovery, the new value types, the
  per-type picker); render harnesses `tools/render_drawer_widgets_preview.gd` + `render_variable_drawer_dialog.gd`.

## Data model

`LocalVariable` / the sheet `variables` schema gain one field:

```gdscript
## Inspector attributes, ordered. Each: {"kind": String, ...kind-specific keys}
## e.g. {"kind": "range", "min": 0, "max": 100, "step": 1, "flags": ["or_greater"]}
##      {"kind": "tooltip", "text": "Max health"}
##      {"kind": "show_if", "variable": "use_gravity"}
@export var inspector_attributes: Array[Dictionary] = []
```

Attributes are **ordered** (group/category placement is positional in GDScript) and
**validated at edit time** (the dialog refuses combos Godot can't express, e.g. Range on
a String — same philosophy as the existing syntax-error prevention).

## Editor UX

- Variable dialog gains an **"Inspector" expander**: an attribute list (add/remove/
  reorder) with kind-specific compact forms (min/max/step for Range, text for Tooltip,
  variable dropdown for Show If, function dropdown for On Changed / Tool Button).
- Live **preview line** renders the exact annotation(s) that will be emitted —
  consistent with the dialog's existing "what code falls out" transparency.
- Behavior packs benefit automatically: pack properties are sheet variables, so packs
  gain ranges/groups/tooltips with zero extra machinery (this is the biggest win — the
  18 bundled packs get Unity-quality inspectors).
- ACE params dialog: untouched (attributes are an Inspector concern, not a sheet-row
  concern).

## Compiler rules

- Attributes emit **immediately above** their variable in declaration order:
  doc-comment tooltip first, then group/category, then the export annotation line
  (merged with the variable's own `@export*`), then setter block if Tier 2.
- `_validate_property` / `_get_configuration_warnings` are **aggregated** functions
  emitted once, after variables, with one canonical `match`/`if` per attribute —
  deterministic ordering by variable order.
- Include-merged variables keep their attributes; the root sheet wins collisions
  (existing include semantics).

## Lifting rules

- Tier 1: one-line reverse templates (annotation → attribute dict), same pattern as
  `_export_enum_prefix` lifting.
- Tier 2: reverse-match the canonical setter/`_validate_property` shapes; any deviation
  → that variable's attributes lift partially (Tier 1 lines) and the function stays a
  verbatim block; byte-verify gates as always.
- `@export_tool_button` lifts only when the Callable target is a sheet function.

## Out of scope (honest skips)

- Unity `[ExecuteInEditMode]` → already covered by **tool sheets**.
- Odin serialized dictionaries/polymorphic fields → Godot exports typed
  Dictionary/Array natively (already shipped as collections).
- Attribute *inheritance* across sheets → follows the include rules, nothing bespoke.
- Custom property *types* (Odin value drawers for arbitrary classes) → Godot wants
  `Resource` subclasses for that; map via a doc recipe, not a feature.

## Phasing (all delivered)

1. Tier 1 (schema + dialog expander + emission + lift + tests) — ✅ shipped.
2. Tier 2 setters/On-Changed/Show-If — ✅ shipped (the `_validate_property` canonical
   shape was the risky bit; pinned byte-exact in tests).
3. Tool buttons + configuration warnings — ✅ shipped.
4. Tier 3 drawers — ✅ shipped (all five drawers via an `EditorInspectorPlugin`, round-tripped).
