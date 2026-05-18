# EventSheet Editor Progress Report

## Completed in this branch

- Interaction architecture extraction started:
  - `ViewportSelectionHelper` for selection/hover state bookkeeping
  - `ViewportHitTestHelper` for row/span hit resolution
  - `ViewportDragPreviewHelper` for ACE drag snap-preview geometry
- Event body selection now selects the full event subtree (event + sub-events), with Ctrl/Cmd row toggles supporting per-sub-event unselect.
- Condition/action hover emphasis now avoids full event-row hover fill when hovering a condition/action span.
- Empty-condition fallback text now reads `Every Tick` instead of `Always`.
- Else / ElseIf markers now render from `EventRow.else_mode`.
- Enable/disable controls now exist across row + ACE contexts (row toggle and condition/action/trigger toggles).
- Global variable writes now persist an explicit exposed/script-facing flag (`exposed = true`).
- Params dialog now includes mode-aware hints, edit-flow cue text, and first-field focus behavior.

## Gaps / partial

- Box selection and drag-target orchestration still live in `event_sheet_viewport.gd` (helper extraction is partial, not complete).
- Else/ElseIf currently aligns rendering + schema usage but still lacks a dedicated guided authoring flow.
- Condition/action enable state is represented in editor UX and resources, but full runtime behavior parity is still partial.
- Expression editing remains integrated into parameter flows, not a dedicated advanced expression editor surface.

## Next steps

1. Continue extraction of drag target validation and box-selection controllers from viewport monolith.
2. Add explicit Else/ElseIf creation/edit affordances in picker/row context workflows.
3. Expand runtime/compiler handling for ACE enabled/disabled and else-mode execution semantics.
4. Expand expression tooling beyond inline insertion (validation, snippets, richer authoring UX).
