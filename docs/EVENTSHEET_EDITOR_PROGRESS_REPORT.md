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
- Event-block selection now expands to nested sub-events, while CTRL/CMD can deselect individual child rows from that grouped selection.
- Condition/action hover now keeps feedback on the entry chip instead of washing the whole event block.
- Empty-condition events now render as **Every Tick** to better match designer expectations.
- ACE picker mode rules are now centralized, and the picker preselects the first result for keyboard-friendly Enter workflows.
- ACE parameter dialogs now show flow-aware hints and preserve loaded values more explicitly for re-editing.

## Gaps / partial

- Box selection currently starts from empty canvas; row-start drag still prioritizes row drag/reorder.
- Theme packs are file-based resources; no in-editor theme marketplace/installer UI yet.
- Multi-selection copy/paste remains row/ACE-focused and does not yet include every future structure permutation.
- The ACE picker / parameter spec work in this pass is architectural rather than complete: mode metadata, keyboard-first defaults, and re-edit hints landed, but there is still room for richer semantic grouping and custom parameter field types.

## Next steps

1. Extend box selection gestures (range modifiers and row-origin marquee behavior).
2. Add explicit theme profile list/dropdown with per-project presets.
3. Expand copy/paste semantics for broader mixed selections (group/comment/event combinations with richer conflict handling).
4. Add screenshot-based visual regression checks when CI environment can run Godot UI tests.
5. Continue the ACE picker / parameter dialog spec pass with richer semantic sections, reusable custom field widgets, and more advanced keyboard shortcuts.
