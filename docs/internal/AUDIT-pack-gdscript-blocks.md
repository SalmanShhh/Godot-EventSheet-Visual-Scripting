# Audit - GDScript blocks remaining when packs open as sheets

**Question asked:** does every `eventsheet_addons` pack open as a sheet with **zero GDScript blocks**?

**Short answer: no - and the "zero blocks" claim was always about a different path.** The v0.9.5
covenant ("every bundled pack compiles with zero GDScript blocks") is about the **build** path - you
*author* a pack as a sheet and it emits clean code with no raw blocks. This audit is the **open**
path - you open a pack's finished `.gd` back into the editor - and there the reverse-lift can't yet
turn everything into rows. The two are different problems; this doc is the open-path gap list.

Census over all 28 packs (`_probe_blocks.gd`), by why each block stays raw:

| Class | Count | Renders as | A real "GDScript block" gap? |
|---|---|---|---|
| `prelude` | 20 | The foldable **Class setup** strip | **No** - collapsed boilerplate, not a logic block |
| `comment_or_annotation` | 23 | Comment rows / **verb shells** | **No** - already first-class rows |
| `func_other` (≈ `_enter_tree`) | 28 | **GDScript block** (⚠) | **Yes - #1**, but it's boilerplate, not logic |
| `func_custom_return_type` | 12 | **Verb shell** (raw underneath) | **Partly** - shelled, but not editable as a verb |
| `member_var` | 3 | **GDScript block** | **Yes - #3** |
| `in_flow_statements` | 63 | Merged in-flow **code cell** | **Legitimate** - the escape hatch (see below) |

## The three genuine gaps + their design solutions

### #1 - The host-binding `_enter_tree` (≈20 packs) → **fold into host metadata**
Every host-targeting pack emits:
```gdscript
func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("<Behaviour> behaviour requires a Node2D parent.")
```
`is_scaffolding_code` (`event_sheet_viewport.gd`) whitelists the first two lines but **not** the
`if host == null: / push_warning(...)` guard, so the whole block drops out of the Class-setup strip
and renders as a standalone GDScript block. It carries zero authored logic - it's regenerated from
the sheet's `host_class`.

**Design solution (preferred): recover it into metadata, emit it on save, never show it as a row.**
The compiler already emits this block from `host_class`; the importer should *recognise and absorb*
the canonical host-binding `_enter_tree` (exact-shape match) back into `host_class` + the `host` var,
exactly the way trigger-signal annotation blocks fold onto their signal rows - gated by the same
byte-verify so a hand-modified `_enter_tree` stays a real block. **Cheaper interim:** extend
`is_scaffolding_code` to match the full 4-line host-binding shape so it at least folds into Class
setup. *(→ new task.)*

### #2 - Helper funcs with custom return types (12 blocks) → **`return_type_name` on EventFunction**
`_get_pool() -> HealthPool`, `_camera() -> Camera2D`, etc. lift into a **verb shell** (readable) but
not into an editable `EventFunction`, because `EventFunction.return_type` is a `Variant.Type` and
can't name a custom class. **Design solution:** add an optional `return_type_name: String` to
`EventFunction`; when non-empty the emitter uses it verbatim and the shell-lift populates it, so the
verb becomes a real (editable) Define block. Byte-verify gates it. *(Already parked from the
shell-lift campaign; promote to a task.)*

### #3 - Pack-internal state vars (juice: 3) → **lift to tree variables**
`var _base_offset: Vector2 = Vector2.ZERO` etc. are private members the pack keeps between frames.
They render as one-line GDScript blocks. **Design solution:** the importer already lifts top-level
`var`/`@export var` into tree `LocalVariable` rows on some paths; extend that to un-exported private
members (kept internal, `exported = false`) so they show as State rows in the Anatomy panel instead
of code. Low value, low risk. *(→ new task.)*

## The 63 in-flow blocks are NOT a gap - they're the point of task #50

`in_flow_statements` are real statements inside events that match no ACE template (physics math,
`velocity = …`, custom easing). Turning *these* into rows would mean an ACE for every arithmetic
line - the wrong goal. The right shape is the **opposite**: make a GDScript block a **first-class,
deliberately-added action** (like Construct 3's script blocks), so "drop to code here" is an
intentional, visually-distinct escape hatch rather than un-lifted residue. That's the sibling task
(#50) - and once it ships, an in-flow block reads as "the author chose code here", which is exactly
what C3 users expect.

## Status (all four solutions implemented)

- **#1 host-binding `_enter_tree` - DONE** (`9dffe49`). Collapses to one muted "Host binding" row via a
  strict exact-shape classifier; ~20 packs read as vocabulary instead of boilerplate. Pure view, drift=0.
- **#2 `return_type_name` - DONE (forward half)** (`ea0955e`). `EventFunction.return_type_name` lets a
  verb return a custom/engine class; the emitter, stub, and signature honour it, and it round-trips.
  Auto-lifting the mid-file custom-return HELPERS stays blocked by *emission position* (a lifted
  function emits at the file's end, reordering the output) - re-filed as its own task; the shells keep
  those readable meanwhile.
- **#3 private/expression-default vars - DONE** (`83b5c4f`). `LocalVariable.expression_default` re-emits
  a bare-expression default (`Vector2.ZERO`) verbatim instead of quoting it, so juice's 8 Vector2 state
  vars lift to State rows. Byte-verify gated, drift=0.
- **The 63 in-flow blocks are a feature, not a wart** - the GDScript-as-action affordance (`cb82030`)
  makes "drop to code here" a deliberate, discoverable C3-style action.

**Remaining:** only the mid-file lifted-function *emission position* problem (its own task) blocks the
last handful of custom-return helpers. Everything else in this audit is resolved.
