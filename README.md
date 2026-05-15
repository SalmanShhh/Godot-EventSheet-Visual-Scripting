# EventForge (GodotEventSheet)

EventForge is a Construct 3-style event sheet visual scripting plugin for Godot 4.x. Event sheets compile to deterministic, readable GDScript.

## Install

1. Copy `addons/eventforge/` into your Godot project.
2. In **Project > Project Settings > Plugins**, enable **EventForge**.
3. Confirm the `EventForgeBridge` autoload is available.

## Quickstart with demo

1. Open the `demo/` project in Godot 4.3+.
2. Inspect `demo/sheets/player.tres`.
3. Run the compiler script path used in tests (`tests/compile_demo_test.gd`) or call `SheetCompiler.compile(...)` manually.
4. Verify output matches `demo/sheets/player_generated.gd`.

## Phase 1 status

| Area | Status |
|---|---|
| Plugin scaffold | ✅ |
| Resources/data model | ✅ |
| Runtime bridge | ✅ |
| Built-in ACE registry | ✅ |
| End-to-end compile (`.tres` -> `.gd`) | ✅ (Phase 1 subset) |
| UI editor implementation | ⏳ Deferred |
| Import/binding pipelines | ⏳ Deferred |

## Roadmap

See `docs/SPEC.md` for consolidated specification and phased roadmap.

## License

MIT. See `LICENSE`.
