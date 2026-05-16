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

## Editor usage flow (Phase 2.2)

1. Open the repository root project.
2. Enable the EventForge plugin.
3. Open the EventForge panel (bottom panel is currently a fallback shell).
4. Create a new sheet or open an existing `.tres` sheet.
5. Add an event row.
6. Select trigger/conditions/actions from the ACE palette (or row pickers).
7. Edit trigger/condition/action parameters in the inspector.
   - For `SetVar`, `AddVar`, and `CompareVar`, the `var_name` param shows a
     variable dropdown populated from Sheet Variables.
8. Use the **Sheet Variables** panel (below the ACE palette) to:
   - Add variables with **+ Add Var**.
   - Edit name, type, default value, and export flag.
   - Delete variables with **X**.
   - Create a variable before using `SetVar`, `AddVar`, or `CompareVar`.
9. Copy, Paste, Duplicate, and Delete selected event rows via the toolbar buttons
   or keyboard shortcuts: Ctrl+C / Ctrl+V / Ctrl+D / Delete.
   - Pasted rows receive a new unique `event_uid`.
10. Refresh/compile preview in read-only GDScript mode.
11. Save the sheet.

### Workflow/UX notes (Phase 2.2 follow-up)

- EventForge direction is Script-editor-style workspace UX:
  - left sidebar (ACE palette + sheet variables)
  - center event canvas
  - right inspector/preview
- Active sheet header always indicates:
  - `No Event Sheet Open`
  - `Unsaved Event Sheet`
  - `Event Sheet: <name>`
  - `*` marker for unsaved/preview-dirty state
- Empty event canvas supports click-to-add:
  `No events yet. Click here or press Add Event to create one.`
- New rows are selected immediately and prompt ACE selection from the left panel.
- Copy requires open sheet + selected row; paste requires open sheet and inserts
  after selection or at end.
- Preview refresh is auto-debounced after edits, while manual `Refresh Preview`
  remains available.
- Naming/grouping follows Construct/GDevelop-style event-sheet wording adapted
  to Godot UI conventions (for example `On Ready` / `On Process` under `System`).

> **Tip:** Create sheet variables before using `SetVar`, `AddVar`, or
> `CompareVar`. These ACEs can select sheet variables from the inspector
> dropdown. If no variables exist, a fallback text field is shown with a
> suggestion to create one.

## Phase 2 MVP status

| Area | Status |
|---|---|
| Plugin scaffold | ✅ |
| Resources/data model | ✅ |
| Runtime bridge | ✅ |
| Built-in ACE registry | ✅ |
| End-to-end compile (`.tres` -> `.gd`) | ✅ (Phase 1 subset) |
| Editor shell with dual/split view | ✅ (Phase 2 MVP) |
| Sheet variables panel (Phase 2.2) | ✅ |
| Variable-aware ACE param editing (Phase 2.2) | ✅ |
| Copy/paste/duplicate/delete rows (Phase 2.2) | ✅ |
| Import/binding pipelines | ⏳ Deferred |
| Editable GDScript round-trip | ⏳ Deferred |

## Roadmap

See `docs/SPEC.md` for consolidated specification and phased roadmap.

## License

MIT. See `LICENSE`.
