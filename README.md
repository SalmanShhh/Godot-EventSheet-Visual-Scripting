# EventForge (GodotEventSheet)

EventForge is a Construct-style event sheet plugin for Godot 4.x. Event sheets compile to deterministic, readable GDScript.

## Install

1. Copy `addons/eventforge/` into your Godot project.
2. In **Project > Project Settings > Plugins**, enable **EventForge**.
3. Confirm the `EventForgeBridge` autoload is available.

## Quickstart with the demo assets

1. Open the repository root project (`project.godot`) in Godot 4.3+.
2. Inspect `demo/sheets/player.tres`.
3. Run the compiler script path used in tests (`tests/compile_demo_test.gd`) or call `SheetCompiler.compile(...)` manually.
4. Verify output matches `demo/sheets/player_generated.gd`.

## Current status

| Area | Status |
|---|---|
| Plugin scaffold | ✅ |
| Resources/data model | ✅ |
| Runtime bridge | ✅ |
| Built-in ACE registry | ✅ |
| End-to-end compile (`.tres` -> `.gd`) | ✅ (current subset) |
| Editor UI foundation (canvas, picker, params, delete flows) | ✅ Implemented; under active refinement |
| Import/binding pipelines | ⏳ Planned |

## Roadmap

See `docs/EDITOR-UI-SPEC.md` for current editor UX details and `docs/SPEC.md` for architecture and next-phase compiler planning.

## License

MIT. See `LICENSE`.
