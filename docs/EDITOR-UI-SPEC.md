# EventForge Editor UI Spec (Phase 2 MVP)

## 1) Purpose

Define a practical, implementation-facing editor UI architecture for EventForge that supports visual event authoring and generated code preview, while keeping GDScript read-only in Phase 2.

## 2) Main screen architecture

The editor shell is hosted by the EventForge plugin and mounted as an editor panel (Phase 2 fallback: bottom panel). The shell owns:

- Active `EventSheetResource`
- Row selection state
- Generated preview text
- Active view mode

Core components:

- `SheetToolbar`
- `ACEPalette`
- Event row canvas/list
- `GDScriptPanel`
- Status bar

## 3) Layout

Top-to-bottom structure:

1. Toolbar row
2. Main content region
3. Status bar

Content region can display event UI, code UI, or both depending on mode.

## 4) Core interactions

- New Sheet: creates in-memory sheet (`host_class = "Node"`)
- Add Event: appends blank `EventRow`
- Row selection: click row card to select/highlight
- Add Condition / Add Action: use filtered popups and append ACE instance to selected row
- Compile / Refresh Preview: run `SheetCompiler.compile(...)` and update code panel

## 5) Row rendering model

Each row card displays:

- Enabled checkbox
- Trigger label (`<no trigger>` fallback)
- Condition count
- Action count
- Add condition button
- Add action button
- Delete button

Selection is visualized by a highlighted card background.

## 6) Toolbar behavior

Toolbar controls:

- New Sheet
- Add Event
- Compile
- Refresh Preview
- View mode switcher

Toolbar emits intent signals only; editor controller performs mutations.

## 7) ACE palette behavior

ACE palette lists built-in descriptors from `ACERegistry.get_builtin_descriptors()` grouped by type:

- Triggers
- Conditions
- Actions
- Expressions

Search filters by descriptor display name / ID.

## 8) Inspector / config editing

Phase 2 MVP does not provide full property inspector/parameter editing. Picker-created conditions/actions use empty default params.

## 9) Generated code panel

`GDScriptPanel` is read-only and source-oriented. It displays latest compiler output text from `SheetCompiler.compile(...)`.

For in-memory sheets, compile output writes to a preview path (for example `res://eventforge_preview_generated.gd`) so preview works without a saved `.tres`.

## 10) Dual View / Split View modes

Required mode enum:

```gdscript
enum ViewMode {
EVENT_SHEET,
GDSCRIPT,
SPLIT
}
```

### Event Sheet mode

Shows only visual authoring area (palette + sheet canvas + status).

### GDScript mode

Shows only generated code preview panel.

### Split mode

Shows event sheet UI and generated code side-by-side.

### Read-only scope for Phase 2

Generated GDScript remains read-only in this phase. Editable round-trip code synchronization is deferred until importer support matures.

### Wireframes

Event Sheet mode:

```text
┌ Toolbar: [New] [Add Event] [Compile] [Refresh] [Sheet|Split|Code] ─────────────┐
├ ACE Palette ┬ Event Sheet Canvas / Row List ────────────────────────────────────┤
└ Status Bar ───────────────────────────────────────────────────────────────────────┘
```

GDScript mode:

```text
┌ Toolbar: [New] [Add Event] [Compile] [Refresh] [Sheet|Split|Code] ─────────────┐
├ Generated GDScript Preview (read-only) ──────────────────────────────────────────┤
└ Status Bar ───────────────────────────────────────────────────────────────────────┘
```

Split mode:

```text
┌ Toolbar: [New] [Add Event] [Compile] [Refresh] [Sheet|Split|Code] ─────────────┐
├ ACE Palette ┬ Event Sheet Canvas ┬ GDScript Preview (read-only) ────────────────┤
└ Status Bar ───────────────────────────────────────────────────────────────────────┘
```

## 11) Validation UX

- Success: `Compile succeeded.`
- Success + warnings: `Compile succeeded with warnings: ...`
- Failure: `Compile failed: ...`
- Dirty state after edits: `Preview may be out of date — click Refresh Preview.`

## 12) Phase breakdown

- Phase 1: data model, registry, compiler path, runtime bridge
- Phase 1.1: cleanup and project structure alignment
- Phase 2 MVP: functional editor shell + dual/split view + read-only preview
- Later phases: inspector depth, drag/drop authoring, importer-backed round-trip editing

## 13) Implementation notes

- UI built programmatically (no `.tscn` dependency required)
- Keep plugin startup behavior and autoload bridge compatibility
- Keep bridge class name as `EventForgeBridgeRuntime` while autoload singleton remains `EventForgeBridge`
- Bottom panel integration is acceptable Phase 2 fallback for reduced complexity

## 14) MVP success criteria

Reviewer can:

1. Open repository root project in Godot.
2. Enable EventForge and see `[EventForge] v0.1.0 loaded`.
3. Open EventForge UI panel.
4. Create new sheet and add event row(s).
5. Switch between Event Sheet, GDScript, and Split modes.
6. Refresh/Compile and see read-only generated code preview update.
7. Observe status feedback (success/error/dirty preview).
