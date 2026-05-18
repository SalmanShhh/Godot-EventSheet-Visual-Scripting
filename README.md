# EventForge (GodotEventSheet)

EventForge is a Construct-style event sheet plugin for Godot 4.x. Event sheets compile to deterministic, readable GDScript.

## Install

1. Copy `addons/eventforge/` into your Godot project.
2. In **Project > Project Settings > Plugins**, enable **EventForge**.
3. Confirm the `EventForgeBridge` autoload is available.
4. Open the **EventSheet** workspace tab in the main editor strip (next to Script/2D/3D) to author sheets in the central editor surface.

## Quickstart with the demo assets

1. Open the repository root project (`project.godot`) in Godot 4.3+.
2. Inspect `demo/sheets/player.tres`.
3. Run the compiler script path used in tests (`tests/compile_demo_test.gd`) or call `SheetCompiler.compile(...)` manually.
4. Verify output matches `demo/sheets/player_generated.gd`.

## Editing EventSheet editor styles in Godot

`EventSheetResource` now exposes an `editor_style` Resource slot for structured editor styling.

1. Select an EventSheet resource in Godot.
2. In the Inspector, create or assign an `EventSheetEditorStyle` resource to `editor_style`.
3. Edit the nested `event_style`, `condition_style`, and `action_style` resources to tune:
   - event-row backgrounds, lane padding, divider width, and trigger badge colours
   - condition chip colors, padding, font-size delta, and spacing
   - action chip colors, padding, font-size delta, and spacing

The custom-rendered EventSheet viewport reads this resource directly, so style assets can be reused across sheets while keeping sensible defaults when `editor_style` is left empty.

## Current status

| Area | Status |
|---|---|
| Plugin scaffold | ✅ |
| Resources/data model | ✅ |
| Runtime bridge | ✅ |
| Built-in ACE registry | ✅ |
| End-to-end compile (`.tres` -> `.gd`) | ✅ (current subset) |
| Editor UI foundation (custom-rendered viewport, virtualization, semantic spans) | ✅ Stable and kept as the primary row architecture |
| Event-sheet authoring workflow milestone | ✅ Open/save/save-as, ACE picker + params, copy/paste, drag/drop reorder, global/local vars, inline edits, node drag-in ACE preview, inspector param exposure |
| Undo/redo coverage (editor + tests) | ✅ Core workflows wired (ACE apply, variables, paste, reorder, inline edits, inspector params) |
| Import/binding pipelines | ⏳ Planned |

## EventSheet UI/editor milestone status

The current EventSheet editor pass is intended to be **usable for real project authoring** while remaining extensible for later runtime/compiler phases. The next major phase can now focus on execution/compiler depth rather than core editor-surface viability.

## Roadmap

See `docs/EDITOR-UI-SPEC.md` for current editor UX details, `docs/EDITOR_PARAM_EXPOSURE_STATUS.md` for the parameter-exposure checklist/status, and `docs/SPEC.md` for architecture and next-phase compiler planning.

## License

MIT. See `LICENSE`.
