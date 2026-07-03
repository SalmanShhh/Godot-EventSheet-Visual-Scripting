# SPEC - The Custom Block API: register your own non-ACE row kinds

**Status:** P1 SHIPPED (registry + CustomBlockRow + all four generic seams + the schema-driven
add/edit dialog + Add-menu entries + the Preload Resource and Region proof kinds;
`tests/custom_block_test.gd`). P2 SHIPPED too (zero-config pack kinds via the addon scan; living proof eventsheet_addons/demo_note_block.gd + the guide chapter). P3 (picker integration, custom-dialog hook) remains optional polish.
**Author trigger (user, verbatim):** *"design a Custom API for making custom event blocks for
special blocks that aren't ACEs that can be used for a myriad of things such as Variables,
Includes, custom functions or anything else!"*

ACEs answer "what can a row DO" (actions/conditions/expressions inside events). This API answers
"what KINDS of rows exist" - the structural blocks that live between events: variables, includes,
signals, enums, region markers, preloads, config blocks, anything a sheet needs that is not an
event. Today every such kind is hardcoded; this spec makes new kinds registerable by packs and
projects with zero plugin edits, the same way ACE providers already are.

---

## 1. What exists today (the five seams every block kind wires through)

Every first-class block kind in the plugin passes through the same five contracts, each wired by
hand today:

| Seam | Where (verified) | What it does per kind |
|---|---|---|
| **Model** | a dedicated Resource class (`signal_row.gd`, `enum_row.gd`, `match_row.gd`, `comment_row.gd`, `raw_code_row.gd`) stored in `EventSheetResource.events: Array[Resource]` (mixed with `EventRow`/`EventGroup`) | holds the block's fields |
| **Emit** | `sheet_compiler.gd` type-dispatch (`_emit_enum_line` at :202, SignalRow at :212, and the external-path `elif entry is …` chain at :527-540) | deterministic GDScript lines + a `source_map` entry |
| **Lift** | `gdscript_importer.gd` per-kind probes (`_try_lift_enum` :365, `_try_lift_signal` :383), each **verify-gated**: the lifted row must re-emit the source line byte-exactly or the line stays a RawCode block | recovers the block from an opened `.gd` |
| **Render** | `viewport_row_builder.gd` type-dispatch building a `RowType.SECTION` row with spans (no per-row widgets) | how the block looks in the sheet |
| **Edit** | a dock dialog (`dock/struct_row_dialogs.gd` for enum/signal/match; `dock/quick_prompt_dialogs.gd` for groups) through the undo funnel `_perform_undoable_sheet_edit` | how the user changes it |

Adding a kind today means touching all five files. The precedents that prove the shape works:
the custom **trigger row** (fold `## @ace_trigger` annotations onto a SignalRow, 461b1e9), the
**host-binding row** (9dffe49), and the **drawer markers** (metadata-as-attributes) - each is a
bespoke instance of exactly this contract.

## 2. Design overview

Three new pieces, mirroring the ACE provider architecture (`EventSheetAddonScanner` +
`ACEDescriptor` + registry):

```
EventSheetBlockKind      (RefCounted descriptor - the contract, one per kind)
CustomBlockRow           (Resource - one instance per row in a sheet; kind_id + fields)
EventSheetBlockRegistry  (static registry - built-ins + scanner-discovered kinds)
```

### 2.1 `EventSheetBlockKind` - the contract

```gdscript
@tool
class_name EventSheetBlockKind
extends RefCounted

## Stable public id ("preload", "region", "my_pack.spawn_table"). Public API once shipped
## (compat covenant, same as ace_ids). Namespace pack kinds with "<pack>.".
var kind_id: String
var title: String            # picker/dialog display name ("Preload Resource")
var category: String = "Blocks"
var accent_color: Color      # the row's kind pill tint (defaults to the section tint)

## Field schema drives BOTH the generic edit dialog and (de)serialization.
## Each field: {id, label, type: Variant.Type, default, hint (optional drawer hint)}.
func fields() -> Array[Dictionary]: return []

## Deterministic GDScript for this block. MUST be pure (same fields -> same bytes).
func emit(block: CustomBlockRow) -> PackedStringArray: return PackedStringArray()

## Try to claim source lines starting at index i. Return {} when not yours; else
## {fields: Dictionary, lines_consumed: int}. The importer verify-gates the claim:
## emit(recovered) must reproduce the consumed lines byte-exactly or the claim is dropped.
func lift(lines: PackedStringArray, i: int) -> Dictionary: return {}

## One-line sheet display ("preload Sfx = res://sfx/jump.ogg"). Rendered as spans, never widgets.
func summary(block: CustomBlockRow) -> String: return title

## Optional: problems to surface in the diagnostics lane. Empty = valid.
func validate(block: CustomBlockRow) -> PackedStringArray: return PackedStringArray()
```

### 2.2 `CustomBlockRow` - the instance

```gdscript
@tool
class_name CustomBlockRow
extends Resource

@export var kind_id: String = ""
@export var fields: Dictionary = {}   # field id -> value, per the kind's schema
@export var enabled: bool = true
```

One generic resource, not one class per kind: sheets stay loadable even when a kind's descriptor
is missing (see 2.5), `duplicate(true)` in the undo snapshot funnel works unchanged, and the
`.tres`/`.gd` formats never learn new class names.

### 2.3 Registration and discovery

- **Built-ins** register in code, next to `builtin_aces.gd` registration.
- **Pack/user kinds are zero-config**, exactly like ACE providers: a script in
  `res://eventsheet_addons/` whose class extends `EventSheetBlockKind` is auto-registered by the
  same scan that finds providers (`EventSheetAddonScanner.list_addon_scripts()`); the registry
  instantiates it and indexes by `kind_id`. Duplicate `kind_id`s warn and keep the first
  (deterministic: scanner output is sorted).
- Registry API: `get_kind(kind_id)`, `all_kinds()`, `lift_probes()` (kinds in registration order).

### 2.4 The five seams, wired ONCE generically

- **Emit**: the compiler's row loops get one new branch - `entry is CustomBlockRow` - that asks
  the registry for the kind and appends `kind.emit(entry)` with a `source_map` entry
  `{kind: "custom:" + kind_id}`. Blocks emit **in array position** on the external path (the same
  ordering contract enums/signals follow today).
- **Lift**: the importer's unclaimed-line path tries each registered kind's `lift()` before
  falling back to RawCode, gated by the exact same byte-verify used by `_try_lift_enum` /
  `_try_lift_signal`: re-emit must reproduce the consumed source lines or the claim is dropped.
  Fidelity is never traded for coverage - a bad lift is a no-op, not a corruption.
- **Render**: one `viewport_row_builder.gd` branch builds a SECTION row: kind pill (accent color,
  `title`) + `summary()` text span + the standard enabled/disabled treatment. No widgets; the
  virtualized-viewport covenant holds.
- **Edit**: one generic dialog auto-built from `fields()` (reusing `EventSheetPopupUI` form
  helpers + the existing attribute-drawer widgets for typed fields), applied through
  `_perform_undoable_sheet_edit`. A kind never builds UI in P1; a custom-dialog hook can come
  later if a kind outgrows the schema.
- **Add**: the Add menu (and later the picker/quick-add) lists registered kinds under their
  categories.

### 2.5 Covenants (what keeps this safe)

1. **Lossless round-trip**: `emit` is pure, `lift` is byte-verify-gated. A sheet regenerates
   byte-identically or the block never lifts.
2. **Zero runtime dependency / graceful degradation**: emitted lines are plain GDScript. If a
   sheet opens where the kind is not registered (pack removed), the lines simply do not lift and
   render as a GDScript block - readable, compilable, nothing breaks. Saving preserves them
   verbatim (the existing RawCode path).
3. **kind_id is public API** once shipped (deprecation goes through the same compatibility
   covenant as `ace_id`s).
4. **No per-row widgets**; rendering is spans only.
5. **Undo**: `CustomBlockRow` is a plain Resource in `events`; the snapshot/restore funnel
   duplicates it like every other row. Kinds hold NO per-instance state (descriptors are
   stateless singletons).

## 3. What this expresses (the "myriad of things")

Kinds the API supports without touching the plugin again - the first two are P1 proof kinds:

- **Preload Resource** (`const Sfx := preload("res://sfx/jump.ogg")`) - typed const + path field.
- **Region marker** (`#region Combat` / `#endregion`) - named folding fences that round-trip.
- **Include** rendered as a first-class row (today `includes: Array[String]` is sheet metadata
  edited in a manager window; an include block would make each include visible IN the sheet).
- **Config/Settings block** (a const Dictionary with a schema-driven editor).
- **Tool-button block** (`@export_tool_button` style dev actions).
- **Spawn-table / loot-table blocks** (pack-defined: data the pack's ACEs consume).
- Variables, signals, enums, functions **stay on their dedicated paths** (they have deep
  integrations: Inspector grouping, trigger folding, the function system). The API is for
  everything that does not exist yet; migrating the built-in struct rows onto it is optional
  future hygiene (P3), never a P1 goal.

## 4. Phasing

- **P1 (core)**: `EventSheetBlockKind` + `CustomBlockRow` + registry with built-ins only; the
  four generic seam branches; generic schema dialog; **two proof kinds** (Preload Resource,
  Region marker); round-trip + undo + render tests; docs.
- **P2 (open to packs)**: scanner discovery of pack-defined kinds; namespacing + duplicate
  guards; a pack in `eventsheet_addons/` ships a kind as living proof; CUSTOM-ACES-GUIDE gains a
  "Custom blocks" chapter.
- **P3 (polish, optional)**: picker/quick-add integration; custom-dialog hook; consider porting
  enum/signal/match rows onto the registry (pure refactor, byte-identical output required).

## 5. Risks and open questions

- **Emission position**: lifted blocks must re-emit at their source position. The external-path
  entry loop already preserves array order, so P1 inherits the same "position = array order"
  contract enums have. The known mid-file *function* emission-position issue is task #54 and is
  NOT expanded by this API (blocks are line-anchored, not function-anchored).
- **Multi-line lifts**: `lift()` may consume several lines (`#region` fences bracket other rows).
  P1 keeps fences as two paired single-line blocks to avoid nesting complexity; pairing is a
  validate() warning, not a parse construct.
- **Kind evolution**: adding a field to a shipped kind must default-fill old instances
  (`fields.get(id, default)` everywhere); removing one is a compat break (deprecate instead).
- **Security/trust**: kinds are code in the project (same trust model as ACE providers and
  `@tool` scripts generally); no new surface.
