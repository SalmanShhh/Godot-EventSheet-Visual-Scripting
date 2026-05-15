# EventForge (GodotEventSheet)

EventForge is a Construct 3-style event sheet visual scripting plugin for Godot 4.x. Event sheets compile to deterministic, readable GDScript.

## Install

1. Open the repository root as the Godot project (the canonical `project.godot` is at the root).
2. In **Project > Project Settings > Plugins**, enable **EventForge**.
3. Confirm the output log prints `[EventForge] v0.1.0 loaded`.

## Project layout notes

- `demo/` contains sample scenes and sheet assets used by tests.
- `demo/` is not a separate Godot project.
- On first open, missing `.uid` warnings are non-fatal; Godot may generate UID sidecar files automatically.

## Quickstart with demo

1. Open the repository root in Godot 4.3+.
2. Inspect `demo/sheets/player.tres`.
3. Run the compiler script path used in tests (`tests/compile_demo_test.gd`) or call `SheetCompiler.compile(...)` manually.
4. Verify output matches `demo/sheets/player_generated.gd`.
5. In the EventForge editor UI, generated GDScript is currently a read-only preview.

## Phase 2 MVP status

| Area | Status |
|---|---|
| Plugin scaffold | ✅ |
| Resources/data model | ✅ |
| Runtime bridge | ✅ |
| Built-in ACE registry | ✅ |
| End-to-end compile (`.tres` -> `.gd`) | ✅ (Phase 1 subset) |
| Editor shell with dual/split view | ✅ (Phase 2 MVP) |
| Import/binding pipelines | ⏳ Deferred |
| Editable GDScript round-trip | ⏳ Deferred |

## Roadmap

See `docs/SPEC.md` for consolidated specification and phased roadmap.

## License

MIT. See `LICENSE`.
