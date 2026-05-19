# AGENTS.md

## Repo overview

GodotEventSheet (EventForge) is a Godot 4.x plugin that provides a Construct-style EventSheet editor and compiler pipeline. The active editor pass keeps a custom-rendered viewport, semantic row/span data, and Godot Resource-based authoring for themes and sheet data.

## Architecture notes

- Plugin entry: `res://addons/eventforge/plugin.gd`
- Main workspace/editor surface: `res://addons/eventsheet/editor/event_sheet_dock.gd`
- Custom-rendered row viewport: `res://addons/eventsheet/editor/event_sheet_viewport.gd`
- Row chrome/text drawing: `res://addons/eventsheet/editor/event_row_renderer.gd`
- Theme resources: `res://addons/eventsheet/theme/*.gd`
- Theme/template scenes: `res://addons/eventsheet/elements/*.tscn`
- Headless regression entrypoint: `res://tests/run_tests.gd`

## EventSheet editor structure

- `EventSheetDock` owns toolbar, dialogs, ACE picker, variable workflows, context menus, undo/redo wiring, and theme load/reload.
- `EventSheetViewport` owns hit-testing, stacked event layout, selection state, inline editing, drag/drop, zoom, and keyboard navigation.
- `EventRowRenderer` paints event/group/comment rows from `EventRowData` plus theme resources.
- `ACEPickerDialog` and `ACEParamsDialog` are the main existing extension points for adding new event/condition/action flows.

## Theme system notes

- `EventSheetEditorStyle` is the installable theme resource.
- `EventSheetEventStyle` now covers structural tokens: sheet background, event block shell, lane colors, group/comment chrome, and interaction fills.
- `EventSheetElementStyle` covers condition/action entry tokens.
- Designers can work in two modes:
  - edit `.tres` token resources directly
  - edit the preview scenes in `addons/eventsheet/elements/` and point a style resource at them
- Theme docs:
  - `docs/EVENTSHEET_THEME_EDITABILITY.md`
  - `docs/EVENTSHEET_THEME_TOKEN_SPEC.md`
  - `docs/EVENTSHEET_ALIGNMENT_GUIDE.md`

## Docs map

- `README.md` — install + high-level workflow
- `docs/SPEC.md` — broader architecture/spec context
- `docs/EDITOR-UI-SPEC.md` — editor UX details
- `docs/EVENTSHEET_THEME_EDITABILITY.md` — designer-facing theme workflow
- `docs/EVENTSHEET_THEME_TOKEN_SPEC.md` — Construct-inspired token naming/mapping
- `docs/EVENTSHEET_ALIGNMENT_GUIDE.md` — stacked layout tuning
- `docs/EVENTSHEET_ARCHITECTURE_SLICES.md` — slice-by-slice completion/scaffold/defer tracker
- `docs/elements/*.md` — template scene guidance
- `docs/spec/construct_3_system_aces_godot_variant_spec.md` — Construct 3-style System ACE vocabulary (conditions, actions, expressions) for Godot; implementation priority guide
- `docs/spec/gdevelop_c3_eventsheet_uiux_spec.md` — GDevelop/C3 row-lane-block interaction model; hover, selection, drag, group, and variable row design spec

## Current known gaps

- Condition/action name vs description cells are documented as separate roles but still share one text token in the current renderer.
- The theme package manifest is documentation/template only; it is not auto-imported yet.
- Full runtime/compiler expansion is intentionally out of scope for this PR line.
- UI screenshots still require a Godot runtime; this sandbox may only be able to do syntax-level validation.
- `EventRowUI` full-width list entry model exists in `addons/eventforge/editor/` but is not yet wired into the main `EventSheetDock`/`EventSheetViewport` pipeline; the viewport chip model is the live path.

## Guidance for future LLM-assisted work

- Keep the custom-rendered viewport/event-row approach; do not replace it with per-row Control widgets.
- Prefer surgical changes in `EventSheetDock`, `EventSheetViewport`, and theme resources over large rewrites.
- When adding interactions, preserve undo/redo and keep right-click selection preservation intact.
- When adding theme features, update both docs and bundled example themes together.
- Add focused tests in `tests/event_sheet_editor_test.gd`, `tests/event_sheet_style_test.gd`, and `tests/docs_integrity_test.gd` when changing editor behavior, theme assets, or documentation contracts.
- Use `docs/spec/construct_3_system_aces_godot_variant_spec.md` as the definitive vocabulary reference when implementing or extending System ACEs.
- Use `docs/spec/gdevelop_c3_eventsheet_uiux_spec.md` as the target interaction model when tuning hover/selection/drag/group/variable UX.
