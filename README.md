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

## Editing EventSheet editor visuals in Godot

`EventSheetResource` exposes an `editor_style` slot, and `EventSheetEditorStyle` now includes
scene-based visual templates for Event, Condition, and Action elements:

- `event_visual_scene` → `addons/eventsheet/elements/event_visual_element.tscn`
- `condition_visual_scene` → `addons/eventsheet/elements/condition_visual_element.tscn`
- `action_visual_scene` → `addons/eventsheet/elements/action_visual_element.tscn`

Designer workflow:

1. Select an EventSheet resource.
2. Assign/create an `EventSheetEditorStyle` in `editor_style`.
3. Open one of the visual template `.tscn` files above and edit it visually in Godot (colors, styleboxes, chip look, lane previews).
4. Save the template scene (or duplicate it and point the style resource to your custom scene).

The custom-rendered viewport keeps the existing performant row renderer, but it now resolves its
Event/Condition/Action look from these Godot-editable visual scene templates (hybrid scene-driven styling).

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
