# Open Sheets panel - Spec (in-workspace "recent sheets" list)

A left-hand list of the **open + recently-closed event sheets**, embedded in the EventSheet
workspace, so switching between many sheets is one click instead of hunting the tab strip - the
event-sheet answer to the Godot **script editor's "Filter Scripts" list**. Toggleable and
collapsible, so anyone who doesn't want it can remove or minimise it.

## Why (and what already exists)

The workspace already has a tab strip, but with a dozen sheets open the tabs clip and you scan
left-to-right to find one. A vertical, **filterable** list is faster to scan and search - exactly
why the script editor pairs its tabs with the "Filter Scripts" panel.

A first version shipped as a **Godot editor dock** (`EventSheetOpenSheetsDock`, `open_sheets_dock.gd`):
a pure view over the tab model, with the data API already on `EventSheetDock`
(`open_tabs_changed` signal, `get_open_sheets_state()`, `activate_open_tab()`, `reopen_sheet_path()`).
It works, but it lives in the **global** left dock area (shared with Scene/FileSystem), not *inside*
the EventSheet tab like the script editor's list, and it isn't toggleable from the sheet's own menu.
**This spec moves it in-workspace and makes it explicitly user-controlled.** The control and the
data API are reused unchanged - only the *mounting* changes.

## What the panel shows (unchanged from the dock)

- A **filter** box (matches on sheet name or path, case-insensitive).
- The **open sheets**, each a row with its title (carrying the `⚙` behaviour / `◆` custom-node / `●`
  unsaved badges from `_format_tab_title`); the **active** sheet is highlighted. One click switches.
- A muted **"Recently closed"** section (an MRU of paths not currently open); one click reopens.
- An empty-state hint when nothing is open.

The list auto-refreshes on `open_tabs_changed` (open / close / activate / dirty). Re-selecting the
already-active sheet is a no-op (it must not reload and wipe undo - already handled in
`activate_open_tab`).

## Placement - in-workspace, left of the viewport

The workspace root is a `VBox`: `[toolbar, tab_bar, title_strip, content]`. The `content` area is
the viewport `_scroll`, which the **code panel** (`_ensure_code_panel` wraps it in `_split`) and
**Split/Detached View** (`_split_container` / `slot`) already reparent. A third HSplit fighting those
is fragile.

**Design:** introduce one stable wrapper - `_workspace_body` (an `HSplitContainer`) - that sits in
the `content` slot once, with two children:

```
_workspace_body (HSplit)
├─ _open_sheets_panel   ← the EventSheetOpenSheetsDock control (left, narrow, collapsible)
└─ _content_host        ← everything that exists today: the viewport _scroll and all its
                          code-panel / split-view / detached-view reparenting happens IN HERE
```

Because the panel wraps **above** `_scroll`, the viewport's existing reparenting machinery operates
entirely inside `_content_host` and never touches the panel - the entanglement is sidestepped, not
fought. `_content_host`'s initial child is whatever currently occupies the content slot (`_scroll`,
or `_split` if the code panel is open); the existing `_ensure_*` helpers keep targeting `_scroll`.

## Toggle + minimise (the user controls it)

- **Toggle (remove):** a **View ▸ Open Sheets Panel** checkbox shows/hides the whole left pane. State
  is persisted per-project in editor metadata (the same mechanism Simple Mode uses), so the choice
  sticks across restarts. Default: **on** (it's the requested convenience), but one click removes it.
- **Minimise (collapse):** a `◀` button in the panel header collapses it to a **thin vertical strip**
  showing just a `▸` reopen affordance (and an icon), reclaiming almost all the width without fully
  hiding it; clicking the strip re-expands. The `HSplitContainer` divider also lets the user drag it
  narrower/wider at will, and the width is remembered.
- The first run's **Welcome** dialog can mention it (like Simple Mode), so it's discoverable.

## Migration from the dock

Replace the global dock with the in-workspace panel:
- `plugin.gd` stops calling `add_control_to_dock` / `remove_control_from_docks` for the panel; the
  `_make_visible` attach/detach logic is removed.
- `event_sheet_dock.gd` builds `_workspace_body` + mounts `_open_sheets_panel` on the left, wires the
  same signals (`open_tabs_changed → set_state`; `activate_requested → activate_open_tab`;
  `reopen_requested → reopen_sheet_path`), and adds the View-menu toggle + collapse.
- `EventSheetOpenSheetsDock` (the control) is reused as-is, plus a tiny header with the `◀` collapse
  button. No change to the tab-model API.

## Tests + verification

- Reuse `open_sheets_dock_test` (the control + model API are unchanged).
- Add: the View-toggle hides/shows the pane; collapse/expand round-trips; the panel survives a
  Split-View toggle (the viewport reparent doesn't detach it); the toggle state persists.
- **Render-harness** the workspace with the panel expanded and collapsed.
- Full suite green; `project.godot`/`.tscn` churn reverted after any non-headless run.

## Out of scope (later)

Drag-to-reorder tabs from the panel; pinning a sheet; grouping by folder. The MRU of recently-closed
sheets is already in `EventSheetDock`; persisting it across sessions (so "recently closed" survives a
restart) is a small follow-up.
