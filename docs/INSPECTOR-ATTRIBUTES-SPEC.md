# Inspector Attributes — Spec (later phase)

Unity-style (and Odin-Inspector-style) **attributes on exported variables**, mapped onto
what Godot actually supports. Status: **SPEC ONLY — not scheduled**. This documents the
design so a later phase can implement it without re-deriving the constraints.

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

### Tier 3 — Odin-level custom drawers (EditorInspectorPlugin; optional, last)

Progress bars, color palettes, preview thumbnails, inline curve editors. Mechanism: a
single `EditorInspectorPlugin` shipped with the *editor* plugin (NOT with generated
code) that recognizes an `@export_custom(PROPERTY_HINT_…, "eventsheet:<drawer>")` hint
string. Critically: **generated scripts stay plain GDScript** — without the plugin the
property still renders as a normal field (graceful degradation, parity preserved).
Candidates: `progress_bar`, `swatch_row`, `vector_dial`. This tier is cosmetic; ship
last, behind the same editor-version caution as tool sheets.

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

## Suggested phasing when scheduled

1. Tier 1 (schema + dialog expander + emission + lift + tests) — one slice.
2. Tier 2 setters/On-Changed/Show-If — one slice (the `_validate_property` canonical
   shape is the risky bit; spec the exact bytes first in tests).
3. Tool buttons + configuration warnings — small follow-up.
4. Tier 3 drawers — optional, after user demand proves itself.
