# EventSheet Editor Progress Report

> **Historical record (early era).** This document predates the overhaul arcs and the
> v0.5/v0.6 feature waves — treat its claims as a design-time snapshot, not current
> behavior. Current truth: `CHANGELOG.md`, `README.md`, and the maintained specs in
> `docs/` (GDSCRIPT-PAIRING-SPEC, the per-feature specs).


> **Historical snapshot** (early overhaul branch). Class names like `EventRowUI` /
> `VariableRowUI` refer to the since-removed widget prototype — that behavior now lives in
> the virtualized viewport/renderer. For current, maintained status see `CHANGELOG.md`
> (per-phase) and the specs (`GDSCRIPT-PAIRING-SPEC.md`). Kept for
> the rationale it records (contrast values, selection rules).

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
- **[This PR]** Hover/selection contrast significantly improved:
  - `COLOR_HOVER` raised from alpha 0.045 → 0.10 (much more visible row hover)
  - `COLOR_SELECTION` raised from alpha 0.22 → 0.38 (clearer row selection)
  - `chip_hover_color` default raised from 0.14 → 0.28 (stronger chip hover)
  - `CHIP_HOVER_MIN_ALPHA` raised from 0.24 → 0.42
  - `CHIP_SELECT_ALPHA_SINGLE` raised from 0.30 → 0.55
  - `CHIP_SELECT_ALPHA_MULTI` raised from 0.34 → 0.62
  - Non-chip span hover opacity raised to 0.46 with 1.5px outline
- **[This PR]** Group selection now always includes all contained events/sub-events regardless of which span was clicked (previously only worked when clicking the row background, not the badge/title span).
- **[This PR]** `VariableRowUI` "Global" badge text is now vertically centered (`VERTICAL_ALIGNMENT_CENTER`).
- **[This PR]** `VariableRowUI` double-click now emits `variable_edit_requested` signal for immediate edit launch.
- **[This PR]** `EventRowUI` entry buttons now show clear selected state via `set_selected_condition(index)` and `set_selected_action(index)` with strong fill + left accent border.
- **[This PR]** `EventRowUI` entry button hover strengthened: alpha raised to 0.52, left accent border added on hover.

## Gaps / partial

- Box selection and drag-target orchestration still live in `event_sheet_viewport.gd` (helper extraction is partial, not complete).
- Else/ElseIf currently aligns rendering + schema usage but still lacks a dedicated guided authoring flow.
- Condition/action enable state is represented in editor UX and resources, but full runtime behavior parity is still partial.
- Expression editing remains integrated into parameter flows, not a dedicated advanced expression editor surface.
- `EventRowUI` full-width list entry model exists but is not yet wired into the main `EventSheetDock`/`EventSheetViewport` pipeline.
- System ACE implementation (runtime/compiler registration pending).

## Next steps

1. Continue extraction of drag target validation and box-selection controllers from viewport monolith.
2. Add explicit Else/ElseIf creation/edit affordances in picker/row context workflows.
3. Expand runtime/compiler handling for ACE enabled/disabled and else-mode execution semantics.
4. Expand expression tooling beyond inline insertion (validation, snippets, richer authoring UX).
5. Begin implementing System ACEs (Construct 3 System ACE vocabulary as the guide).
6. Wire `EventRowUI` full-width list entry model into `EventSheetDock`/`EventSheetViewport` pipeline as an alternative rendering mode.
