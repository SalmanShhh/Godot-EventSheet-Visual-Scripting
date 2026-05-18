# EventSheet Editor Progress Report

## Completed in this branch

- Empty-canvas right-click bug fixed by ensuring viewport canvas height tracks scroll viewport height.
- Empty-space context menu remains available with: **New Event**, **New Condition**, **Add New Variable**.
- Empty-space double-click continues to add a new event row.
- Right-click on already selected rows now preserves multi-selection.
- Drag-box selection added from empty canvas area to select multiple rows and condition/action spans.
- Theme workflow expanded with toolbar actions: **Load Theme**, **Default Theme**, **Reload Theme**.
- Theme hot-reload path supported through style-change refresh and explicit reload.
- Added docs integrity regression test for required `/docs` artifacts.

## Gaps / partial

- Box selection currently starts from empty canvas; row-start drag still prioritizes row drag/reorder.
- Theme packs are file-based resources; no in-editor theme marketplace/installer UI yet.
- Multi-selection copy/paste remains row/ACE-focused and does not yet include every future structure permutation.

## Next steps

1. Extend box selection gestures (range modifiers and row-origin marquee behavior).
2. Add explicit theme profile list/dropdown with per-project presets.
3. Expand copy/paste semantics for broader mixed selections (group/comment/event combinations with richer conflict handling).
4. Add screenshot-based visual regression checks when CI environment can run Godot UI tests.
