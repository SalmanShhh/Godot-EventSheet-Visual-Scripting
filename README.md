# EventForge (GodotEventSheet)

EventForge is a Construct/GDevelop-style event sheet visual scripting plugin for Godot 4.x. Event sheets compile to deterministic, readable GDScript.

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

## Editor usage flow (Phase 2.3)

EventForge sheets are **vertical, scrollable documents** modelled after
Construct / GDevelop event sheets.

1. Open the repository root project.
2. Enable the EventForge plugin.
3. Open the EventForge panel (bottom panel is currently a fallback shell).
4. Create a new sheet or open an existing `.tres` sheet.
5. Global sheet variables appear as **variable rows at the top of the canvas**:
   ```
   Global int health = 100
   Global String player_name = "Player"
   ```
   Click a variable row to edit its type, default value, and export flag in the
   inspector.
6. Add an event row.  Build each event as **Conditions + Actions**:
   - Run-context conditions (`On Ready`, `On Process`, `On Physics Process`,
     `On Signal`, `On Body Entered`) determine when the event runs.
   - If an event has no run context, it runs every frame.
   - At most one run context is supported per event.
7. Click a **condition or action entry** inside an event row to open focused
   inspector editing for that entry only.  Use **← Back to Event** to return to
   the full event inspector.
8. Edit run context / condition / action parameters in the inspector.
   - For `SetVar`, `AddVar`, and `CompareVar`, the `var_name` param shows a
     variable dropdown populated from Sheet Variables.
9. Use the **Sheet Variables** sidebar panel (below the ACE palette) to add,
   rename, and delete variables.  Variables also appear as canvas rows.
10. Copy, Paste, Duplicate, and Delete selected event rows via the toolbar
    buttons or keyboard shortcuts: Ctrl+C / Ctrl+V / Ctrl+D / Delete.
    - Pasted rows receive a new unique `event_uid`.
11. Refresh/compile preview in read-only GDScript mode.
12. Save the sheet.

### UX and document-flow notes

- The sheet canvas is a **vertical document** of ordered blocks:
  - `Global variable` rows (top of canvas)
  - `Group` header rows (planned: contain local variables + nested events)
  - `Event` rows (Conditions + Actions)
- EventForge direction is Script-editor-style workspace UX:
  - left sidebar (ACE palette + sheet variables)
  - center event canvas
  - right inspector/preview
- The sheet canvas is a **vertical document** of ordered blocks:
  - `Global variable` rows (top of canvas)
  - `Group` header rows (planned: contain local variables + nested events)
  - `Event` rows (Conditions + Actions, `Runs: ...` summary)
- Event blocks follow a GDevelop-style model:
  - `Runs: ...`
  - `Conditions` (shows `Always` when no regular conditions exist)
  - `Actions`
- Run-context ACEs are **not** shown as a separate `Trigger` section.
  Use `Runs: ...` summary and `Run Context` label instead.
- Condition and action entries are **clickable** for focused inspector editing.
- Active sheet header always indicates:
  - `No Event Sheet Open`
  - `Unsaved Event Sheet`
  - `Event Sheet: <name>`
  - `*` marker for unsaved/preview-dirty state
- Empty event canvas supports click-to-add:
  `No events yet. Click here or press Add Event to create one.`
- Copy requires open sheet + selected row; paste requires open sheet and inserts
  after selection or at end.
- Preview refresh is auto-debounced after edits, while manual `Refresh Preview`
  remains available.
- Naming/grouping follows Construct/GDevelop-style event-sheet wording adapted
  to Godot UI conventions (for example `On Ready` / `On Process` under `System`).
- Godot Signals are the primary run-context equivalent for event-driven logic.
  `On Signal` connects the chosen signal in `_ready()` and runs the event body
  in a generated callback.

> **Tip:** Create sheet variables before using `SetVar`, `AddVar`, or
> `CompareVar`. These ACEs can select sheet variables from the inspector
> dropdown. Variable rows appear both in the canvas and in the sidebar panel.

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
| Global variable rows in canvas (Phase 2.3) | ✅ |
| Clickable condition/action entries (Phase 2.3) | ✅ |
| Group block UI groundwork (Phase 2.3) | ✅ |
| Multiple EventSheet tabs (Phase 2.4) | ⏳ Planned |
| Group local variable scoping (Phase 2.5) | ⏳ Planned |
| Import/binding pipelines | ⏳ Deferred |
| Editable GDScript round-trip | ⏳ Deferred |

## Roadmap

See `docs/SPEC.md` for consolidated specification and phased roadmap.

## License

MIT. See `LICENSE`.
