# SPEC — Automatically preview a `.gd` as an event sheet

**Status:** spec (awaiting the user's answers to the clarifying questions before implementation).
**Goal (user):** "create a UI/UX solution for previewing the GDScripts as eventsheets automatically."

## What already exists (the foundation is done)

- **The lift is rich.** Phases 1–4 mean a hand-written `.gd` renders almost entirely as rows —
  variables, statements, loops, branches, conditions, helper functions, hinted exports — and saving an
  untouched preview reproduces the file byte-for-byte. The `fidelity_ratchet_test` proves it.
- **Manual open works.** `EventForgePlugin._open_sheet_in_workspace(path)` switches to the Event Sheets
  main screen and calls `_load_sheet_from_path(path)`, which opens a `.gd` as a **read-only preview**
  (a banner offers "Edit Events" to unlock). Reachable today from native entry points (context menus,
  the script editor's "Go to Sheet Row").
- **Plugin shape.** `EventForgePlugin` is a *main-screen* editor (`_has_main_screen`), with
  `_handles(object)` claiming `EventSheetResource` only (NOT `.gd`), `_edit(object)`, and
  script↔sheet provenance (`_goto_sheet_row_from_script`).

So the engine for "show this `.gd` as events" is built. What's missing is the **automatic UX** — the
trigger and the surface — which is a design choice with real trade-offs (chiefly: how much it competes
with Godot's own Script editor, which owns `.gd` double-click today).

## The design space (the options the questions resolve)

### A. Trigger — how the preview activates
1. **Right-click → "View as Event Sheet"** in the FileSystem dock (and/or a Script-editor toolbar
   button). Explicit, one click, zero conflict with the Script editor.
2. **Auto-preview on FileSystem selection** — single-clicking a `.gd` in the FileSystem dock live-loads
   it into the Event Sheets tab. Most "automatic"; needs a FileSystem-selection hook + a guard so it
   doesn't fight the Inspector/Script editor.
3. **Script-editor companion** — while editing a `.gd` in the Script editor, a docked "Events" view
   renders it (code on one side, events on the other), updating as you switch scripts.
4. **Open-as-events** — make opening a `.gd` land in the Event Sheets view (via `_handles(GDScript)`),
   augmenting/overriding the Script editor. Most automatic, most invasive.

### B. Surface — where the events render
1. The existing **Event Sheets main-screen tab** (switch to it, show the `.gd`).
2. A **companion panel beside the Script editor** (code + events side-by-side, never leaving the script
   workspace).
3. A **bottom panel** under the script.

### C. Live update
- Re-render automatically when the `.gd` changes on disk (file-watch), or only on (re)select/open.

### D. Editability (proposed default, not a question)
- Keep today's behaviour: open as a **read-only preview**, with "Edit Events" in the banner to unlock
  two-way editing. Safe by default; no accidental overwrite of a hand-written script.

## Recommendation (pending confirmation)

Trigger **A + B** (a right-click entry now, plus optional auto-preview-on-select as the "automatic"
mode behind a setting), Surface **1** (the main-screen tab — reuses everything), Live update **on**
(the file already round-trips, so re-render is cheap and safe), Editability **read-only by default**.
This is the least invasive path that still feels automatic and never fights the Script editor.

## Open questions → asked of the user before building.
