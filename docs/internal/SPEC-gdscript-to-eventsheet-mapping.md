# SPEC - the complete GDScript -> condition/action mapping

**Goal:** every line of GDScript reads as an event-sheet row - the discriminating part in a CONDITION cell,
the effect in ACTION cells - so a code beginner can read any `.gd` as a Construct-3-style sheet. This spec is
the grounded map of where we are, what is already on the model, and the ranked gaps to close. It is a living
roadmap: delete a gap section when it ships, delete the whole file when the gaps are gone.

Every claim here is cited to `file:line` and was verified against the tree, not asserted from memory.

## The two directions, and why "all GDScript already opens as rows"

- **FORWARD** (author a row, compile to `.gd`): a construct maps to a row resource plus an ACE
  `codegen_template`. `SheetCompiler.compile` (sheet_compiler.gd) walks the sheet and emits plain, typed
  GDScript with zero plugin dependency.
- **REVERSE** (open any `.gd` as a sheet): `GDScriptImporter.import_external_source`
  (addons/eventforge/importer/gdscript_importer.gd:68) does structural lifting; `EventSheetACELifter`
  (addons/eventforge/importer/ace_lifter.gd:39) does statement-level lifting. **Every lift is gated by a
  byte-identical recompile** - anything that cannot re-emit to the exact source bytes degrades to a verbatim
  `RawCodeRow` (raw_code_row.gd).

Consequence: **any `.gd` already opens as rows losslessly.** The open question is never "does it round-trip"
(it always does) but "how much of it is *structured* - readable as discrete condition/action rows - versus one
opaque code block?" This spec measures structured coverage.

## Three levels of "structured"

A construct sits at exactly one of these, and moving a construct up a level is the unit of work:

1. **Resource-structured** - a first-class row resource (`EventRow`, `MatchRow`, `LocalVariable`,
   `EventFunction`, `EnumRow`, `SignalRow`, `CommentRow`, `CustomBlockRow`, `PickFilter`). Reads and edits as
   a native row; participates in drag, undo, the picker.
2. **View-structured** - the resource stays a `RawCodeRow`, but the viewport *renders* it as foldable
   condition/action rows. The data-holder block (a pure-data `class X:`) and the host-binding block are here:
   `ViewportRowBuilder._build_data_class_row` renders the raw class as a bright event row (`class AbilityData`
   in the condition cell, its field count in the action cell) with each field as a child event row. The bytes
   never change; the *reading* is structured.
3. **Opaque** - a `RawCodeRow` shown as a code cell. Lossless, but reads as code, not as events.

The escape hatch that guarantees level 1/2 for the common cases: generic catch-alls. **Any** condition term
no specific ACE claims becomes `ExpressionIsTrue {expr}` (system_aces.gd:154); **any** call becomes
`CallMethod`/`CallFunction`; **any** assignment becomes `SetProperty`/`SetVar`; everything else is a
`RawCodeRow`. That is why every `if`, every call, and every assignment structurally lifts today.

## Coverage map (verified)

### Control flow -> the event container (all resource-structured, both directions)

| GDScript | Reads as | Where |
| --- | --- | --- |
| `if / elif / else` | CONDITION lane = `EventRow.conditions`; ACTION lane = `actions`; `elif`/`else` = sibling `EventRow.else_mode`; nested `if` = `sub_events` | event_row.gd:41-45; reverse ace_lifter.gd:1015-1052 |
| `for x in y` | CONTAINER `EventRow` + `PickFilter`; `range(...)` -> REPEAT kind, else EXPRESSION | pick_filter.gd:7-17; reverse ace_lifter.gd:1058-1082 |
| `while cond` | CONTAINER `EventRow` + `PickFilter` WHILE, `collection_value` = the condition | pick_filter.gd:16; reverse ace_lifter.gd:1226-1230 |
| `match` (switch) | ACTION `MatchRow`: subject + structured `cases:Array[MatchCase]`, each case an event row (pattern -> body). Byte-gated; falls back to verbatim branches | match_row.gd; match_case.gd; reverse ace_lifter.gd:1087-1114 |
| `return` | ACTION `ReturnValue {value}` / `ReturnEarly` | core_aces.gd:122,124 |
| `await` (stmt) | per-action `is_awaited` prepends `await`; plus `AwaitSignal` / `AwaitNextFrame` / `Wait` | ace_action.gd:11; collection_aces.gd:72-84 |
| `assert` / `breakpoint` | ACTION `Assert` / `Breakpoint` (+ F9 gutter flag `EventRow.debug_break`) | dev_aces.gd:29,35 |

### Statements -> actions (resource-structured)

| GDScript | Reads as | Where |
| --- | --- | --- |
| `x = v` (var / member) | ACTION `SetVar` / `SetProperty` (value is opaque expression text) | core_aces.gd:104; helper_aces.gd:32 |
| `+= -= *= /= %=` | ACTION `AddVar`/`SubtractVar`/... and the `...Property` twins | core_aces.gd:106-117; helper_aces.gd:36-43 |
| `foo()` / `obj.method()` | ACTION `CallFunction` / `CallMethod` (zero-arg round-trips) | core_aces.gd:126; helper_aces.gd:47 |
| `var n = v` (local, in flow) | ACTION `SetLocalVar` / `...Typed` / `...Inferred` | helper_aces.gd:71-80 |

### Declarations -> rows and sheet metadata (resource-structured)

| GDScript | Reads as | Where |
| --- | --- | --- |
| `var` / `const` (class level) | `LocalVariable` row (const = green pill); unquoted defaults kept verbatim | local_variable.gd; reverse gdscript_importer.gd:220-259 |
| `@export` + hint families | `LocalVariable.exported` + structured range/flags/enum/file/node_path/layers/color/etc.; unknown hints verbatim | local_variable.gd:15-35; reverse gdscript_importer.gd:265-595 |
| `@onready` | `LocalVariable.onready`; new onready vars force Variant (dodges numeric-typed node-ref crash) | local_variable.gd:22 |
| `func` | `EventFunction` (params, return type, body events) | event_function.gd; reverse ace_lifter.gd:822 |
| `signal` | `SignalRow`; optional `## @ace_trigger` publishes it as a Trigger ACE | signal_row.gd; reverse ace_lifter.gd:503 |
| `enum` (single-line) | `EnumRow` (members may carry `= value`) | enum_row.gd; reverse gdscript_importer.gd:656 |
| `class_name` / `extends` / `@tool` / `@icon` | sheet metadata (identity banner, host type) | event_sheet.gd:10-57 |
| comments / doc comments | `CommentRow` (NORMAL/NOTE/TODO/WARNING/SECTION); doc `##` -> tooltip | comment_row.gd; gdscript_importer.gd:190 |

### View-structured (RawCodeRow rendered as rows)

| GDScript | Reads as | Where |
| --- | --- | --- |
| pure-data `class X:` (only typed fields) | data-holder block: `class X` in condition cell, field count in action cell, each field a child event row (default editable) | viewport_row_builder.gd `_build_data_class_row` |
| generated `_enter_tree` host boilerplate | host-binding block: host CLASS as its own cell | viewport_row_builder.gd `_build_host_binding_row` |

### Expressions - opaque by design

Literals, arrays, dicts, operators, subscripts, attribute/method chains, ternary, `is`/`as`/`in`, string `%`,
lambdas, `$`/`%` node paths - all live as **free GDScript strings inside ACE params** (`ace_param.gd`,
"expression" hint). Convenience EXPRESSION-type ACEs build common ones via the picker (`InlineIf`, `GetNode`,
`FormatString`, ...), but the expression grammar itself is never decomposed into rows. This is deliberate:
**expressions are values, not events.** A condition row's discriminating text can be any boolean expression;
we do not (and should not) turn `a.b().c[d]` into nested rows. This is not a gap.

## The gaps (ranked by value x fit-to-model)

Ranking axis: how common the construct is in hand-written GDScript, times how well it maps to the
condition/action reading. Each gap below is a construct that stays **opaque** (level 3) when it should reach
level 1 or 2.

### G1. OR-mode reverse-lift - `if a or b:` reads as OR'd conditions [SHIPPED]

**SHIPPED (a6ff947).** A purely-OR `if` (no top-level ` and `) now splits on top-level ` or `, lifts each
term as its own condition, and sets `condition_mode = OR`, so it reads as a C3-style "Or block". A mixed
`a or b and c` keeps the ` and ` split (GDScript binds `and` tighter) and stays AND-mode - byte-exact, not
falsely restructured. `_split_top_level_and` was generalized to `_split_top_level(expr, sep)`; the branch
lives in `_parse_conditions` (ace_lifter.gd). Byte-gated. Test: `tests/or_condition_lift_test.gd`.

### G2. break / continue reverse-lift - loop control as actions [SHIPPED]

**SHIPPED (563df13).** `break`/`continue` inside a lifted loop body (including nested in an `if` inside the
loop) now lift into Break Loop / Continue Loop action rows. They are admitted to the reverse index tagged
`loop_control` and only claimed when `in_loop` is threaded true through `_parse_body` ->
`_consume_action_line` -> `_match_entry` (a loop-control keyword is invalid GDScript elsewhere). `pass` is
deliberately NOT lifted: no ACE has that template and the compiler emits it only as an empty-body stub
(sheet_compiler.gd:1426), so an empty block reads as empty rather than gaining a spurious action. Byte-gated.
Test: `tests/loop_control_lift_test.gd`. (The statement-after-nested-block interleaving limit below still
keeps a `for`/`while` with work following an `if...continue` guard as a verbatim block.)

### G3. static func - the biggest opaque-block offender in real utility code [TOP REMAINING GAP]

`static func foo() -> T:` never lifts: the reverse header regex demands `^func ... -> Type:`
(ace_lifter.gd:830) and the emitter has no static prefix (sheet_compiler.gd:675). `EventFunction` has no
`is_static` field. Very common in singletons/utility classes; each stays a full verbatim block.

- **Fix:** add `EventFunction.is_static`; emit `static func` when set; widen the header regex to an optional
  `static ` prefix and capture it. Declaration-level (not condition/action-shaped), but high "reads as a
  sheet" value.
- **Scope:** one field + emitter branch + regex widen. Clean.

### G4. lower-value gaps (batch later)

- **static var / static members** - no field, no ACE.
- **inner class with methods** - no `ClassRow`; stays verbatim. (Pure-data classes are already
  view-structured; a methods-bearing class would need a nested-sheet concept - largest effort here.)
- **`super` / `super.method()`** - no ACE; opaque or incidentally `CallFunction`.
- **multi-line / hand-formatted `enum`** - only the canonical single-line form lifts.
- **local `const` in flow** - downgrades to a plain `var` + warning (sheet_compiler.gd:1214).
- **arbitrary annotations** (`@rpc`/`@warning_ignore`/`@abstract`/`@static_unload`/raw `@export_custom`) - stay
  verbatim; only `@ace_*` and the export-hint families are structured.
- **statements interleaved AFTER a nested block in one body** - unrepresentable (actions emit before
  `sub_events`); falls to a lenient raw block (ace_lifter.gd:1197). A structural limit, not a quick fix.

## Net assessment

Statement-level coverage is **essentially complete** for the common imperative subset in both directions, on
a rich declaration layer, and the generic catch-alls guarantee any `.gd` opens as rows. **G1 (OR-mode
reverse) and G2 (loop-control reverse) are now shipped**, so the remaining structural gaps that keep real
hand-written code reading as opaque blocks are, in priority order: **static func (G3)**, then the G4 batch.
Closing G3 would make the vast majority of everyday GDScript read as discrete condition/action rows.
