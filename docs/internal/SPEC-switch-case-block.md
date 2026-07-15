# SPEC - switch/case block: a structured `match` you build like an event sheet

Status: DESIGN (2026-07-15). Requested by the user: "create a custom block for doing switch-cases! that's
engaged with similar to all the other event rows, with ACEs and all - spec first! it needs to read similar
to regular code but abstracted and visually distinct but still look part of a regular eventsheet/gdscript."

## Where we are today (what exists, and why it is not enough)

A `match` block already ships as `MatchRow` (`addons/eventforge/resources/match_row.gd`): an action-lane
resource with a `match_expression` (the subject) plus `branches_text` - ONE `@export_multiline` blob of
verbatim GDScript match-body lines (patterns + bodies). It compiles in-flow inside an event body
(`sheet_compiler.gd:1381` emits `match <subject>:` then each `branches_text` line one level deeper), renders
as a match header + branch lines as action cells (`viewport_row_builder.gd:1942`), double-click opens a
single-textarea dialog, and it byte-gate-lifts from a real GDScript `match` (`tests/match_lift_test.gd`).

The gap the user is naming: `branches_text` is a raw code blob. You cannot add a condition or an action to a
case the way you do to any other event row - the case bodies are text, not event-sheet vocabulary. It reads
as code pasted into a cell, not as part of the sheet. This is the SAME confusion the enum "one text field"
task calls out: structure that should be first-class rows is hidden inside one string.

## Goal

A switch/case that you build like the rest of the sheet: a `Switch on <subject>` container whose children
are CASE branches, and each case is itself a small event body you fill with conditions and actions (ACEs),
sub-events, comments, or - as the escape hatch - a raw GDScript block. It compiles to a plain GDScript
`match`, reads like `match subject:` with `Case <pattern>:` branches (abstracted, visually distinct, but
unmistakably part of the event sheet), and never breaks the byte-exact round-trip.

```
  Switch on   state                       ->     match state:
    Case  State.IDLE                                State.IDLE:
      + set  velocity = Vector2.ZERO                    velocity = Vector2.ZERO
    Case  State.RUN                                  State.RUN:
      When  is on floor                                 if is_on_floor():
        + play  "run"                                       $AnimationPlayer.play("run")
    Otherwise                                        _:
      + set  velocity = Vector2.ZERO                     velocity = Vector2.ZERO
```

## The covenant (non-negotiable, same as every lift)

1. Byte-exact round-trip: opening a `.gd` with a `match` and saving untouched reproduces it byte for byte.
2. A structured lift is verify-lifted: reconstruct the `match` text from the structured model, compare to
   the source byte for byte, and only replace the raw form when identical. Any case body that does not fully
   lift to ACEs degrades - the case keeps a verbatim in-flow GDScript block for that body, or the whole
   construct stays a raw `MatchRow`. Never corrupt.
3. Emission is deterministic. `tools/audit_addons.gd` (audited=72 drifted=0) is the whole-corpus proof; a
   per-pattern round-trip test is RED before the structured emit and GREEN after.
4. `MatchRow`'s existing `kind_id`/shape stays a compatibility promise - the structured model is ADDITIVE
   (see Data model); an old raw-text MatchRow keeps working and re-emitting unchanged.

## Foundations to reuse (do not rebuild)

- **Container rendering + foldable children**: `EventGroup` and the `region` CustomBlockRow already render a
  tinted, foldable container whose children ARE real resources in the tree (so selection / drag / delete /
  ACE-add all work and stay byte-safe - unlike the data-class field rows, which are synthetic). A case body
  is exactly this: a bounded list of event rows. Reuse `EventRowData.children` + `.folded` + the region
  bubble/tint chrome (`viewport_row_builder.gd` region path; `render_preview.gd` shows the look).
- **Event-body compile**: `_emit_event_body` / the action-lane emitter already turns a list of
  EventRow/ACEAction/CommentRow/RawCodeRow into indented GDScript. A case body compiles through the SAME
  emitter, just one indent deeper under its pattern - so ACEs inside a case need zero new codegen.
- **Custom Block API** (`EventSheetBlockKind` / `CustomBlockRow` / registry, `docs/GUIDE-CUSTOM-BLOCKS.md`)
  is the registration surface; `dock/ace_apply.gd` + `_find_resource_location` route add/edit/delete/drag to
  the right container (extend it to resolve a row into a case body, exactly like it resolves into a group or
  a function body).
- **The `match` reverse-lift** (`ace_lifter.gd`, `tests/match_lift_test.gd`) already recognises a GDScript
  `match`; extend it to lift each case body through the normal ACE lifter instead of dumping to
  `branches_text`.
- **Add-event / +condition / +action affordances** and the ghost-row zero-dialog add already work on any
  event body; a case body inherits them once its rows live in the tree.

## Data model

Additive on `MatchRow` so the frozen shape and old raw-text rows keep working:
- Keep `match_expression: String` (the subject) and `branches_text: String` (the raw-text fallback / escape
  hatch, still emitted when a case is not structured).
- Add `cases: Array[MatchCase]` where `MatchCase` (new resource) = `{ pattern: String, events: Array }`.
  `events` holds the same row resources any event body holds (EventRow, ACEAction, ACECondition via its
  EventRow, CommentRow, RawCodeRow, nested MatchRow). `pattern` is the fx-validated match pattern text
  (`State.IDLE`, `1, 2, 3`, `var x`, `_` for default), enum members completing as today.
- A MatchRow is STRUCTURED when `cases` is non-empty; then `branches_text` is ignored on emit. A lifted
  match whose bodies did not all lift stays raw (cases empty, branches_text verbatim) - the covenant fallback.
- Open question for build time: whether `MatchRow` stays action-lane (in-flow, inside one event's actions)
  or a structured switch may ALSO live at tree level like a group. Recommendation: keep it action-lane first
  (matches today's placement + compile path, smallest correct slice), revisit tree-level after Phase 2.

## Rendering (reads like code, unmistakably part of the sheet)

- Header row: a `Switch` badge (its own accent in the palette role family) + the subject as an editable
  value (`Switch on state`), double-click edits the subject inline (reuse the inline value editor). Folds
  like a group; a fingerprint cue shows case count.
- Each case: a nested, faintly tinted branch (region-style bubble/left accent, one hue for the whole switch)
  whose header reads `Case <pattern>` - the default `_` reads as `Otherwise` with the literal `_` shown
  muted so it still maps visibly to code. The pattern is an editable value (double-click).
- Case body: the case's `events` rendered as normal indented event rows, with the usual `+ Add condition /
  + Add action` cells and an `Add event` footer, so you fill a case exactly like any event. A case whose body
  is a raw GDScript block shows the existing GDScript block row inside it (escape hatch preserved).
- Visual distinctness without leaving the sheet: switch accent on the header + a single case-tint, thin
  connective rail down the cases (like a group's spine), pattern chips styled like enum/value chips. No new
  widget - all custom-drawn spans + children, same as groups/regions.

## Interaction (engaged with like every other event row)

- Add a case: a `+ Case` affordance on the switch header (and in its context menu); inserts a `MatchCase`
  with an empty body and a placeholder pattern, focused for rename. An `Otherwise` (`_`) case is offered once.
- Edit subject / pattern: double-click (inline value edit, fx-validated + enum completion, same gate the
  current dialog uses so an invalid pattern never commits).
- Add / edit / delete / reorder ACEs inside a case: routes through the undo funnel; `_find_resource_location`
  resolves a body row into its `MatchCase.events` (extend it, as was done for group and function bodies),
  and `_move_rows` refuses a cross-container drop (a case body row cannot be dragged into `sheet.events` or
  another case and alias into two arrays - the exact class of bug the function-body work fixed).
- Reorder / delete cases; convert a structured case to/from a raw block (the escape hatch both ways).
- Re-fetch resources by identity after each commit (the funnel snapshot-duplicates) - never hold a row ref
  across an edit.

## Compilation

Deterministic, plain GDScript, through the existing emitters:
```
<indent>match <subject>:
<indent>\t<pattern-1>:
<indent>\t\t<compiled MatchCase[0].events, one body deeper>
<indent>\t<pattern-2>:
<indent>\t\t<compiled MatchCase[1].events>
```
Each case body reuses `_emit_event_body` at `body_indent + 2 tabs`. An empty case body emits `pass` (a
`match` case may not be empty). A raw-text (unstructured) MatchRow emits exactly as today (byte-frozen). The
`source_map` gains per-case spans so a selected case highlights its generated lines.

## Phasing

- **Phase 0 - this spec.**
- **Phase 1 - structured model + read-only render + compile.** Add `MatchCase` + `cases`; emit structured
  cases (each body through `_emit_event_body`); render the switch container + case branches + bodies
  READ-ONLY (bodies inert first, like the data-class Phase 1a, to de-risk). Byte round-trip proven by
  authoring a structured match and compiling, plus a fixture that round-trips. drift=0.
- **Phase 2 - editing.** Un-inert case bodies: add/edit/delete/reorder ACEs and cases through the undo
  funnel; extend `_find_resource_location` + guard `_move_rows` cross-container (the reviewer-flagged
  aliasing bug). Adversarial tests: expand a switch, add an action to a case, delete a case body row, drag a
  case row out (refused) - each re-emits deterministically and never aliases across arrays. A fresh
  plan-reviewer pass on the container gate.
- **Phase 3 - byte-gated structured lift.** Extend the `match` reverse-lift so each case body lifts through
  the ACE lifter; verify-lift byte-gates the WHOLE match; any case body that does not fully lift keeps a
  verbatim in-flow block (or the whole match stays raw). RED-before/GREEN-after test over a real match with
  mixed liftable + unliftable case bodies. drift=0 across all 72.

## Verification bar (every phase)

Suite green (add the per-pattern test) + `drift=0` (audited=72) + demo golden byte-stable + a rendered
preview shown to the user + a fresh `plan-reviewer` pass focused on the byte-gate, the verbatim fallback,
and the cross-container aliasing guard + commit + push. New `MatchCase` `class_name` needs the editor
class-cache regenerate-then-revert ritual.

## Relationship to the enum "+" task

Same root idea from the other queued task (enum values as first-class fields instead of one comma-joined
string): both replace a confusing single text field with first-class, individually editable structure. The
switch/case case-list and the enum value-list can share the "+ add a row to a small owned list, edited
inline, byte-gated on re-emit" interaction pattern - build the enum one first (smaller) to prove the pattern,
then reuse it for cases.
