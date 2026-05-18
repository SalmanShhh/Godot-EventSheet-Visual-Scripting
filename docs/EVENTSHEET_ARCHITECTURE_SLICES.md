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
- **Drag/drop source kind clarity:**
  - A floating badge near the cursor now shows "Event", "Group", "Condition", "Action", or "Comment" while dragging so the user always knows what they are moving.
  - Row drag source kind tracked in `_drag_row_source_kind`.
  - ACE drag source kind tracked in `_drag_ace_source_kind`.
- **Drop zone visual distinction:**
  - `before`/`after` drop modes render as a thin bright-blue horizontal line (unchanged).
  - `inside` drop mode now renders as a rounded rect fill with a blue border to clearly indicate sub-event insertion rather than sibling insertion.
- **Global variable `@export` badge:**
  - Global variable rows now show an `@export` badge to communicate that the variable is exposed to the Godot Inspector.
  - `exposed` flag in variable descriptor defaults to `true`; set to `false` to suppress.

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
- **Expression Editor Dialog (`ExpressionEditorDialog`):**
  - Standalone dialog with expression text input, variable browser, and clear button.
  - Opened automatically from `ACEParamsDialog` when a parameter has `"expression": true` in its descriptor.
  - `ACEParamsDialog.init_dialog()` now accepts an optional `ExpressionEditorDialog` reference.
  - Expression-type params render a `LineEdit` preview + `…` button in the params form.
  - Variable browser shows global + local sheet variables and inserts name at cursor on double-click.
  - Wired in `EventSheetDock._ready()` and `_get_sheet_variable_names()` added to supply variables.

### Scaffolded / partial
- Expression editor is integrated as an expression-entry path in parameter flows, but not yet a standalone full-screen expression workbench.

### Deferred
- Advanced expression authoring features (history snippets, validation previews, rich syntax editing, autocomplete).

## Slice 4 — Spec alignment (phases 1–5)

Status summary:

- **Phase 1 (resources/registry/serialization):** **Implemented + extended**
  - Else/ElseIf and ACE enable-state rendering consume existing resource schema fields.
  - Global variable exposure semantics are now explicit in saved descriptors.
- **Phase 2 (editor panel/row rendering/undo-redo):** **Implemented + extended**
  - Viewport interaction extraction, selection model improvements, row/ACE enabled toggles, and renderer updates are wired into existing undoable workflows.
  - Drag/drop visual clarity improvements (source badge, inside-drop indicator).
- **Phase 3 (picker/params/expression):** **Partial → extended**
  - Params dialog gained stronger flow awareness and re-edit cues.
  - Expression editor dialog added and wired into params dialog.
  - Picker/params workflows remain central; full expression tooling still scaffolded.
- **Phase 4 (runtime execution engine):** **Deferred**
  - Runtime/compiler changes were intentionally limited in this push.
- **Phase 5 (optimization/virtualization/extensions):** **Partial**
  - Existing custom-rendered viewport architecture remains and is further modularized.
  - Full virtualization/extension API expansion is still deferred.

## Slice 5 — Documentation

### Implemented
- `docs/EVENTSHEET_C3_UI_UX_TRANSLATION_SPEC.md` — C3-to-Godot 1:1 UX bridge document covering all interaction flows, divergences, and the interaction model summary.
- `docs/EVENTSHEET_COMPILER_ALIGNMENT_NOTES.md` — Compiler spec alignment reference explaining resource contracts, ACE semantics, Else/ElseIf chain semantics, variable compilation, and what remains for compiler work.
- `tests/docs_integrity_test.gd` updated with markers for both new docs.
