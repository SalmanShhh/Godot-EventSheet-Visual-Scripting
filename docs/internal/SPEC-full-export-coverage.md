# SPEC - Full inspector export coverage: every @export option, approachable to a newcomer

**Status:** P1 SHIPPED (all nine hint families: canonical emission on both variable paths, verify-gated structured lift, byte-identical round-trips, verbatim fallback for non-canonical shapes; `tests/full_export_coverage_test.gd`). P2's core SHIPPED too (the type-filtered Inspector-look picker + contextual Details + Slider extras + the live Ships-as strip in the variable dialog). P3's subgroup drag SHIPPED (same gesture, one level deeper, @export_subgroup underneath) and the LootTable starter teaches a ranged int + file-picker String. The optional tail SHIPPED too: the @export_custom presets (password/expression/link) and flagged exp-easing round-trip byte-gated with dialog looks. The empty-panel nudge was DROPPED on investigation: its assumed surface (a live variables ItemList) does not exist, and the dialog's auto-expanding attributes card + the look picker already carry the discoverability. Spec complete.
**Author trigger (user):** *"add support for all the inspector options (gdscript_exports +
PropertyHint) + make use of some of the existing features to help make that experience easier
to a new user to understand via UI/UX of the project e.g how you can group variables by
dragging them into each other."*

The variable system already ships a strong core (attributes dict on `LocalVariable`, canonical
emission + verify-gated lift, the Basic/Advanced dialog tiers, five custom drawers, and the
drag-into-a-bubble grouping). This spec closes the remaining distance to the FULL Godot export
surface and, more importantly, makes the whole surface discoverable through plain language and
live previews instead of annotation names.

---

## 1. Census: every @export annotation vs today

Verified against `sheet_compiler.gd` (emission), `gdscript_importer.gd` + `variable_parser.gd`
(lift), and `variable_dialog.gd` (UX). "Verbatim fallback" = the line round-trips as an
unhinted raw declaration today (nothing breaks, but it is not editable as a form).

| Annotation | Today | Gap |
|---|---|---|
| `@export` | SHIPPED (exported flag) | - |
| `@export_group` / `@export_subgroup` | SHIPPED (drag-to-group emits it) | subgroups have no gesture; prefix arg unsupported |
| `@export_category` | verbatim fallback | **P1** |
| `@export_range(min, max, step)` | SHIPPED | **P1**: the modifier tail - `or_greater`, `or_less`, `exp`, `hide_slider`, `radians_as_degrees`, `degrees`, `suffix:<unit>` |
| `@export_enum("A", "B")` on String | SHIPPED (combo) | **P1**: int-backed enums + explicit values (`"Slow:30"`) |
| `@export_multiline` | SHIPPED | - |
| `@export_placeholder("hint")` | SHIPPED | - |
| `@export_color_no_alpha` | SHIPPED | - |
| `@export_exp_easing` | SHIPPED | `attenuation` / `positive_only` flags (P2) |
| `@export_file("*.ext")` / `@export_global_file` | verbatim fallback | **P1** (with filter list) |
| `@export_dir` / `@export_global_dir` | verbatim fallback | **P1** |
| `@export_node_path("Type", ...)` | verbatim fallback | **P1** (with type filters) |
| `@export_flags("Fire", "Ice")` | verbatim fallback | **P1** (with explicit values `"Fire:1"`) |
| `@export_flags_2d_physics` / `_2d_render` / `_2d_navigation` | verbatim fallback | **P1** (one "layers" attribute, six + avoidance variants) |
| `@export_flags_3d_physics` / `_3d_render` / `_3d_navigation` / `_avoidance` | verbatim fallback | **P1** |
| `@export_storage` | verbatim fallback | **P1** (saved, hidden from the Inspector) |
| `@export_custom(hint, hint_string, usage)` | internal (drawer markers ride it) | **P2**: preset surface for hints with no dedicated annotation |
| `@export_tool_button` | SHIPPED (tool buttons) | - |

PropertyHint members with no `@export_*` annotation (PROPERTY_HINT_PASSWORD,
PROPERTY_HINT_EXPRESSION, PROPERTY_HINT_LINK) become **named presets over `@export_custom`**
in P2 - the dialog shows "Password field", the emission is a canonical `@export_custom(...)`
line, and the lift recognizes exactly those canonical shapes. Hints that only make sense from
C++/plugin property lists (OBJECT_ID, NODE_PATH_VALID_TYPES internals, and friends) are out of
scope on purpose: they are not reachable from GDScript exports either.

## 2. Schema: one attributes key per option (extends the shipped dict)

All new options are keys in the existing `LocalVariable.attributes` Dictionary - the shipped
pattern (range/multiline/placeholder/... already live there), so the undo funnel, the .tres
format, the drag-grouping, and the dialog plumbing need zero structural change:

```
range: {min, max, step, or_greater: bool, or_less: bool, exp: bool, hide_slider: bool,
        angle: "" | "radians_as_degrees" | "degrees", suffix: String}   # extends shipped key
enum_values: [{label: String, value: ""|int}]        # int-backed enums; shipped combo stays for String
flags: [{label: String, value: ""|int}]              # @export_flags
layers: "2d_physics"|"2d_render"|"2d_navigation"|"3d_physics"|"3d_render"|"3d_navigation"|"avoidance"
file: {mode: "file"|"dir", global: bool, filters: [String]}
node_path_types: [String]                            # @export_node_path filters
category: String                                     # @export_category above the line
storage: bool                                        # @export_storage
custom_preset: "password"|"expression"|"link"        # P2 canonical @export_custom presets
```

Rules carried over from the shipped tiers, unchanged:
- **Canonical emission**: each key emits ONE exact shape (like `_emit_enum_line`); the lift
  recognizes exactly that shape, byte-verify gated - a hand-formatted line the emitter cannot
  reproduce stays a verbatim declaration and nothing is lost.
- **Graceful degradation**: unknown/hand-written hints keep round-tripping verbatim (the
  `hinted_export_test` contract).
- **One export prefix per variable**: hints that cannot combine in Godot cannot combine in the
  dialog (the picker is a single choice per variable, exactly like the drawer picker).

## 3. UX: plain language + existing affordances (the point of this spec)

The dialog never shows an annotation name first. Every option reads as WHAT THE INSPECTOR
SHOWS, with the annotation as the quiet second line - the ACE Studio "Ships as:" pattern:

- **The "Inspector look" picker** (Advanced tier, per-type, replacing the flat attribute
  fields): a type-filtered option list in the shipped drawer-picker style -
  float/int: `Slider (range)` · `Slider, no upper limit (or_greater)` · `Angle (degrees)` ·
  `With a unit (suffix: px)` · `Exponential (exp)`;
  String: `One line` · `Paragraph (multiline)` · `Dropdown (enum)` · `Hint text (placeholder)`
  · `File picker (*.ogg)` · `Folder picker` · `Password field`;
  int: `+ Checkbox flags (Fire, Ice)` · `+ Physics layers (2D)` ...;
  NodePath: `Node picker, only Buttons`;
  any: `Saved but hidden (storage)`.
  Each choice shows a LIVE "Ships as: `@export_range(0, 100, 1, "or_greater")`" strip, so the
  plain-language name teaches the annotation instead of hiding it.
- **Drag-into-group already teaches grouping** (the Discord-folder bubble). P3 extends the
  same gesture one level: dragging a variable onto a variable INSIDE a bubble offers
  "Subgroup" on the name-it-afterwards popup - same drag, same popup, one deeper.
- **The starters demonstrate the vocabulary**: the Custom Resource starter (LootTable) gains a
  ranged int and a file-picker String so a newcomer's first resource shows two real inspector
  options in context.
- **Empty-variable-panel nudge** (small): when a sheet has exported variables but none carry
  attributes, the variables manager shows one muted line - "Double-click a variable to choose
  how it looks in the Inspector."

## 4. Phases

- **P1 (coverage)**: schema keys + canonical emission + verify-gated lift + dialog fields for
  range modifiers, int/valued enums, flags, layer masks, file/dir pickers, node-path filters,
  category, storage. Round-trip tests per option (the inspector_drawer_roundtrip pattern).
- **P2 (the picker UX)**: the type-filtered "Inspector look" picker with Ships-as strips;
  exp-easing flags; the @export_custom presets (password/expression/link); starter updates.
- **P3 (gesture polish)**: subgroup via the existing drag gesture; the empty-panel nudge.

## 5. Risks

- **Range modifier tail order**: Godot accepts the extras in any order but emits/documents a
  conventional one; the canonical shape fixes one order (`or_greater, or_less, exp,
  hide_slider, <angle>, suffix:<u>`) so the byte gate stays deterministic. Hand-written other
  orders stay verbatim (fine).
- **Flags/enum explicit values**: `"Fire:1,Water:2"` must round-trip the exact spelling -
  values are stored as strings, never re-derived integers.
- **node_path vs typed `: NodePath`**: `@export_node_path` requires the NodePath type; the
  dialog only offers it for NodePath variables (type-filtered picker makes this automatic).
- **Layer masks are ints in disguise**: the six layer variants all store as int; the picker
  names them by what the Inspector shows ("2D physics layers grid").
