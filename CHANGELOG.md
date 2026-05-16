# Changelog

## [Unreleased]

### Workspace shell polish (issue #59 – slice 4)
- **Central split composition**: Replaced fixed `HBox + VSeparator` canvas/inspector
  layout with a named `HSplitContainer` (`WorkspaceSplit`) so the editor body reads
  as a dedicated workspace split surface.
- **Canvas resource-tab framing**: Added `SheetCanvasResourceTab` inside
  `SheetCanvasDocumentStrip` so active sheet title + dirty state are framed as an
  editor-style document tab rather than plain strip labels.
- **Inspector surface flattening**: Inspector shell now uses square-corner framing to
  better match the main workspace/editor shell composition.
- **Tests/docs**: Extended workspace-shell and editor tests to assert split-shell and
  resource-tab presence, and updated editor UI spec for the new framing model.

### Workspace document framing improvements (issue #59 – slice 3)
- **Toolbar resource-path context**: Added a dedicated path hint label in the toolbar
  top row so the currently opened EventSheet resource path is always visible.
- **Canvas document strip**: Added `SheetCanvasDocumentStrip` at the top of the main
  canvas surface to provide document-like framing in the editor body:
  - `EventSheetResource` kind tag
  - active document title
  - dirty indicator dot
  - full resource path / unsaved hint
- **Central surface composition**: Updated the main canvas shell from rounded utility
  card framing to a flatter document surface with a top strip + content body margin,
  making it feel more like a dedicated workspace document.
- **Tests/docs**: Added test coverage for toolbar path formatting and new document-strip
  presence, and updated the editor UI spec with path/document-strip behavior.

### Workspace shell improvements (issue #59 – slice 2)
- **Toolbar flush at top**: Removed the 8px outer margin that wrapped the toolbar.
  The toolbar now spans the full workspace width with zero margin above or beside it,
  matching the Godot Script editor layout rather than a dock widget.
- **Status bar at bottom**: Added a full-width `PanelContainer` status bar at the very
  bottom of the workspace (thin, 1 px top border). All operation feedback messages
  (save, compile, add/delete events/variables/groups) are now routed here via the new
  `_set_status()` helper rather than appearing in the toolbar header row.
- **Save / Save As**: Added `Save` and `Save As…` buttons to the toolbar action strip.
  - `Save` writes the current sheet to its existing resource path; falls back to Save As
    for unsaved in-memory sheets.
  - `Save As…` opens a FileDialog to pick a path; updates `resource_path` on success via
    `take_over_path()`.
  - Both are disabled when no sheet is loaded.
  - Keyboard shortcuts: `Ctrl+S` (Save), `Ctrl+Shift+S` (Save As).
- **Dirty state tracking**: `EventSheetEditor._is_dirty` is set by `_mark_dirty()` on
  every mutation (add/replace/delete events, conditions, actions, variables, groups,
  condition inversion) and cleared by `_clear_dirty()` on sheet load or successful save.
- **Dirty indicator (●)**: Amber dot `●` appears next to the sheet name in the toolbar
  top row when `_is_dirty` is true; hidden when the sheet is clean.  Controlled via the
  new `SheetToolbar.set_dirty(dirty: bool)` method.
- **Toolbar label rename**: Toolbar header label changed from `EventForge` to `EventSheet`
  to correctly identify the workspace type rather than the plugin brand.
- **Toolbar corner radius**: Set to 0 (flush top) to match the full-width flush-at-top
  layout; previously used a 6 px all-around radius that implied a floated card widget.
- **Tests**: New `tests/workspace_shell_test.gd` covers toolbar save signals, dirty
  indicator visibility, Save/SaveAs button enabled state, and `_mark_dirty` / `_clear_dirty` toggling.
- **Docs**: Updated `docs/EDITOR-UI-SPEC.md` section 2.4 to document the new shell
  structure, toolbar layout, save flow, dirty tracking, and keyboard shortcuts.

## [0.1.0] - 2026-05-15
- Initial EventForge Phase 1 scaffold.
- Added resource model, bridge, ACE registration, and Phase 1 compiler path.
- Added demo project, hand-authored sheet, golden generated output, and test harness.
