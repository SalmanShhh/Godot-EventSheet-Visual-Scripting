# EventSheet Architecture Slices (Large Alignment Push)

This document tracks the broad architecture/spec-alignment PR in explicit slices and calls out what is fully implemented, scaffolded, or deferred.

## Slice 1 — Editor architecture extraction

### Implemented
- Viewport selection state logic now delegates to `ViewportSelectionHelper`:
  - single-row selection
  - descendant-aware event-block selection
  - row selection flag syncing
  - hover flag syncing
- Hit-test row/span resolution now delegates to `ViewportHitTestHelper`.
- ACE drag preview rectangle construction now delegates to `ViewportDragPreviewHelper`.

### Scaffolded / partial
- Drag target validation/placement heuristics still live in `event_sheet_viewport.gd` and should be extracted in a follow-up pass.
- Box-selection and row drag state are still managed in the viewport directly.

### Deferred
- Full interaction-controller split (separate selection/hover/drag controllers with isolated state objects).

## Slice 2 — Editor UX/features

### Implemented
- Event-block body selection now selects the event and its descendant sub-events.
- Ctrl/Cmd row toggles can unselect descendant rows individually after parent-block selection.
- Condition/action hover uses span-only emphasis without full event-row hover fill.
- Empty-condition fallback label changed from `Always` to `Every Tick`.
- Else / ElseIf markers are rendered in the condition lane from `EventRow.else_mode`.
- Enable/disable model expanded:
  - row-level toggle for event/group/comment rows
  - condition/trigger/action-level enabled toggle via context menus
  - disabled ACE spans render dimmed + struck-through
- Global variables are now persisted as exposed/script-facing by default (`exposed = true` in global descriptors).

### Scaffolded / partial
- Else/ElseIf authoring UX is still metadata-driven (resource/state + rendering), not a full dedicated creation flow.
- Condition/action enable-state execution semantics in runtime/compiler are not fully expanded yet.

### Deferred
- Full C3 parity for all advanced block-selection permutations and keyboard selection ranges.

## Slice 3 — Dialog window systems

### Implemented
- Parameter dialog now carries structured flow hints by mode.
- Replace/edit flows show explicit re-edit cue in dialog title and hint text.
- First parameter field receives focus on open.

### Scaffolded / partial
- Expression editor remains integrated as an expression-entry path in parameter flows, but not yet a standalone full-screen expression workbench.

### Deferred
- Advanced expression authoring features (history snippets, validation previews, rich syntax editing).

## Slice 4 — Spec alignment (phases 1–5)

Status summary:

- **Phase 1 (resources/registry/serialization):** **Implemented + extended**
  - Else/ElseIf and ACE enable-state rendering consume existing resource schema fields.
  - Global variable exposure semantics are now explicit in saved descriptors.
- **Phase 2 (editor panel/row rendering/undo-redo):** **Implemented + extended**
  - Viewport interaction extraction, selection model improvements, row/ACE enabled toggles, and renderer updates are wired into existing undoable workflows.
- **Phase 3 (picker/params/expression):** **Partial**
  - Params dialog gained stronger flow awareness and re-edit cues.
  - Picker/params workflows remain central; expression tooling still partially scaffolded.
- **Phase 4 (runtime execution engine):** **Deferred**
  - Runtime/compiler changes were intentionally limited in this push.
- **Phase 5 (optimization/virtualization/extensions):** **Partial**
  - Existing custom-rendered viewport architecture remains and is further modularized.
  - Full virtualization/extension API expansion is still deferred.
