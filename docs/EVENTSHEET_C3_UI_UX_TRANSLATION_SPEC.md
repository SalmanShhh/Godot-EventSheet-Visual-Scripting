# EventSheet C3 UI/UX Translation Spec

This document maps Construct-style EventSheet authoring flows to the current Godot EventSheet editor so interaction semantics stay close to 1:1 where practical.

## Selection model translation

- **Row body click** maps to selecting a structural row (event/group/comment/variable).
- **ACE click** maps to selecting a single condition/action entry instead of relying on row-only highlight.
- **Group click** maps to selecting the group header and its contained rows.
- **Ctrl/Cmd click** maps to additive/toggle multi-selection.
- **Shift click** maps to anchored range selection for rows and ACE spans on the same row.

## Drag/drop translation

- Dragging a condition/action keeps source-chip emphasis and shows a destination insertion band in the target lane.
- Target rows also show lane-level highlight so the destination block is obvious before drop.
- Condition/action insertion resolves by stacked-line position (before/after based on vertical position), matching Construct-style stacked ACE flows.
- Event/group row drag still resolves between **before / inside / after** to differentiate reorder vs nesting.

## Keyboard shortcut translation

- `Q` inserts a comment row using the current structural selection context (below selected row, or at root when no selection exists).
- `Delete` removes selected ACE entries first, then selected rows.
- Multi-selected condition/action entries can be enabled/disabled together through the existing ACE toggle flow.

## Godot-specific deviations

- Rendering is custom-drawn in a viewport instead of per-row Control trees, so selection/drag cues are drawn overlays.
- Trigger validation remains compiler-aware (single trigger-like entry per event) and blocks invalid drops with explicit feedback.
- Theme tokens can adjust lane/chip visuals while preserving selection and drag semantics defined above.
