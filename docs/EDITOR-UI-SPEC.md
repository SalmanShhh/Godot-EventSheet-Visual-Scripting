# EventForge Editor UI Specification

## 1. Overview

This document captures the **currently implemented** EventForge editor UX and the immediate refinement direction.
It intentionally avoids describing unbuilt behavior as complete.

## 2. Current implemented UX

### 2.1 ACE picker window

- ACE selection uses a dedicated popup **Window** (`ACEPickerPopup`), not an inline inspector list.
- The picker window is titled and movable by the editor user.
- Picker title is mode-specific and visible in the window chrome and body header:
  - `Add Event`
  - `Add Condition`
  - `Replace Condition`
  - `Add Action`
- **Live search/filter**: A `LineEdit` (`ACEPickerSearch`) below the title allows real-time filtering of entries by name, description, or node type.  When the search box is non-empty, pre-declared empty group headers are hidden so only groups that contain a matching entry are shown.  Clearing the search restores the full grouped list.
- Picker entries are grouped by ACE category, with Construct-style event groups shown when adding events.
- ACE groups are colour-coded by type:
  - **Node-type groups** (e.g. `CharacterBody2D`, `Area2D`, `Node2D`, `Timer`, `AnimationPlayer`, `RigidBody2D`) use **amber** text — these group ACEs by the Godot class they belong to.
  - `Run Context / Triggers` uses teal-green.
  - `Variables` uses muted blue.
  - `Custom ACEs` (runtime providers) uses purple.
  - Other logical category groups use a neutral muted colour.
- **Per-item type colour-coding**: Each ACE entry in the picker tree has its text coloured by ACE type so conditions, actions, and triggers are visually distinguishable within a mixed group:
  - **Triggers** use soft green.
  - **Conditions** use soft blue.
  - **Actions** use soft teal.
- **Type-labelled tooltips**: Item tooltips are prefixed with the ACE type in brackets (e.g. `[Condition]  Is on floor`) so hovering immediately reveals whether an entry is a condition, action, or trigger.
- `ACEDescriptor` carries a `node_type` field that determines the primary group.  When `node_type` is non-empty it takes priority over `category`.
- `EVENT_PICKER_GROUPS` pre-declares node-type sections so they appear before descriptor scanning in the "Add Event" picker.  Pre-declared node types:
  - `CharacterBody2D`, `Area2D`, `Node2D`, `RigidBody2D`, `Timer`, `AnimationPlayer`
- Built-in ACEs tagged with their Godot class origin:
  - `IsOnFloor`, `MoveAndSlide`, `SetVelocity` → `CharacterBody2D`
  - `OnBodyEntered`, `OnAreaEntered` → `Area2D`
  - `SetPosition2D`, `SetRotationDeg` → `Node2D`
  - `ApplyCentralImpulse` → `RigidBody2D`
  - `StartTimer`, `StopTimer`, `IsTimerStopped`, `OnTimeout` → `Timer`
  - `PlayAnimation`, `StopAnimation`, `IsAnimationPlaying`, `OnAnimationFinished` → `AnimationPlayer`

### 2.2 ACE parameter dialog

- ACE params use a compact `ConfirmationDialog` popup (`ACE Parameters`) sized for fast edit/apply flow.
- Field layout is left-label / right-control per row.
- Parameter descriptions render below their corresponding control when present.
- If params were opened from the picker, the dialog shows `◀ Back` and returns to the same picker mode/context.
- If an ACE has zero editable params, it is applied immediately in single-apply mode (no redundant param dialog loop).
- Variable-reference params use a dropdown of current sheet variables.
  - When no variables exist, the dropdown shows `No variables available` disabled.
  - Apply is blocked for missing variable references.
  - The dialog hint explicitly tells the user to add a variable first.
- String params tagged with `hint = "expression"` show an inline `ƒx` button.
  - `ƒx` opens an **Insert Expression** picker popup backed by ACE descriptors of type `EXPRESSION`.
  - Expression entries are grouped by node type / namespace using the same grouping rules as the event picker (`node_type` first, then category/provider fallback).
  - Selecting an expression inserts its code template (with descriptor default params) into the target field.

### 2.3 Event sheet row UX

- Event rows use a **two-lane composition**: a condition lane (left) and an action lane (right), separated by a 2 px `ColorRect` lane divider — closely matching Construct 3's event sheet grammar.
- Rows avoid explicit lane headers (`IF`, `THEN`, `Conditions`, `Actions`, `when`, `do`) — the column position alone conveys lane identity.
- The condition lane occupies approximately 35 % of the row width (`COND_LANE_RATIO = 1.0`); the action lane occupies approximately 65 % (`ACTION_LANE_RATIO = 1.85`). These ratios are constant across all rows, providing cross-row column alignment.
- Each lane is a `PanelContainer` with a subtly distinct background tint:
  - Condition lane: `COND_LANE_BG` — slightly blue-tinted.
  - Action lane: `ACTION_LANE_BG` — near-neutral, leans teal.
- The outer `PanelContainer` (the row itself) carries zero content margins so the lane panels extend flush from the depth-accent left border to the right edge — lanes read as the row, not as widgets inside the row.
- **Condition lane** composition (top-to-bottom, then left-to-right):
  - Header row: `⋮` select handle · run-context/trigger button (expands) · `+` add-condition button.
  - `VBoxContainer` of condition entries, one per line — **C3-style vertical list**, not horizontal token chips.
- **Action lane** composition:
  - Header row: spacer (expands) · `+Add` action button.
  - `VBoxContainer` of action entries, one per line — **C3-style vertical list**, not horizontal token chips.
- Each condition/action entry is a full-width flat `Button` (left-aligned text, transparent background, subtle hover tint) that spans the entire column — no chip borders, no chip backgrounds. This matches Construct 3's text-based row grammar.
- The 2 px `LANE_DIVIDER_COLOR` `ColorRect` between lanes provides a clear, stable vertical boundary that creates the horizontal eventsheet rhythm.
- Condition entries use blue-tinted text; action entries use teal/green-tinted text — clearly distinct from each other.
- Entry text color uses C3-style column affinity: blue for conditions (cold/left), teal for actions (warm/right).
- A left gutter is rendered for every row, with branch guides for nested/sub-event rows.
- Condition and action entries are clickable (left-click to edit, right-click for context menu).
- Delete affordances are implemented:
  - event delete via inline row `✕` action (positioned right of the action lane)
  - condition delete via condition context menu (`Delete Condition`)
  - action delete via action context menu (`Delete Action`)
- Row-level insertion affordances are in-flow with the sheet row surface:
  - event rows expose `+↑` / `+↓` controls to insert a new event above or below
  - group rows expose `+↑` / `+↓` controls to insert sibling events above or below the group
  - comment rows expose `+↑` / `+↓` controls to insert inline comment rows above or below
  - insertion respects structural containers (root events, nested sub-events, and group child arrays) so above/below behavior stays local to hierarchy depth
- Events now provide a paired in-flow anchor: `Add Event` and `Add Comment`.
- **Comment rows** are now **full-width amber banner rows** — no lane split. Layout:
  - A 3 px amber left-accent `ColorRect` (type indicator).
  - `//` prefix label.
  - Inline `LineEdit` spanning the full remaining width (transparent background, amber text).
  - `+↑` / `+↓` / `✎` / `×` contextual controls (dimmed at rest, brightened on hover/selection).
  - Comments are visually distinctive through amber background color, not through a lane split.
- Comment rows support direct inline text editing, with inspector text editing kept in sync.
- Condition/action entries support drag-and-drop reordering and cross-event moves (via `EntryTokenButton`).
- Comment rows support drag-and-drop relocation above/below event rows and relative to other comment rows.
- Row-level insertion controls are intentionally de-emphasized at rest and become full-emphasis on row hover/selection.
- When deleting a focused condition/action, inspector selection falls back to the owning event view.
- Variable and group rows share the same sheet-line/gutter composition model.
- **Group rows** are now **full-width header rows** — no lane split. Layout:
  - A 3 px purple/indigo left-accent `ColorRect`.
  - Collapse/expand `▶/▼` button.
  - `Group` type label.
  - Group name label (expands).
  - Event count label (e.g. `(2)`).
  - `+↑` / `+↓` / `✎` / `×` controls.
  - Groups are visually distinctive through purple/indigo background color.
- Variable rows remain compact in-canvas, with rich hover tooltips that include type/default and optional variable descriptions.

### 2.4 Editor shell and document framing

- EventForge registers as a **main editor workspace** via `EditorPlugin._has_main_screen()`.
- EventSheet editing is hosted in the central editor viewport, not a bottom dock panel.
- Selecting an `EventSheetResource` in the editor routes into this workspace via plugin `_handles()`/`_edit()` integration.
- The editor uses a main-screen workspace shell modelled after Godot's Script editor:
  - **Toolbar** spans the full workspace width, flush at the top with no outer margin — no dock-panel-era padding above or beside it.
  - Toolbar background has zero corner radius so it sits flush at the top edge of the workspace.
  - Toolbar bottom border (1 px) provides the only visual separation from the content area below.
  - Top row of the toolbar: `EventSheet` label | separator | sheet name | dirty indicator | document meta | separator | selection meta | spacer
  - Top row now also includes a **document path hint** between document meta and selection meta so the active resource path is always visible.
  - Action row of the toolbar: `New Sheet` | `Open` | `Save` | `Save As…` | separator | `+ Event` | `+ Variable` | shortcut hints | spacer | `Compile Preview`
  - **Dirty indicator** `●` (amber dot) appears next to the sheet name when the sheet has unsaved changes; hidden when the sheet is clean.
  - **Save / Save As** buttons are present and enabled whenever a sheet is loaded.
  - Canvas section and inspector section have small 6 px breathing margins on left/right/top and 4 px bottom margin — just enough visual separation from the toolbar, no bottom-dock-era outer padding.
  - **Status bar** sits at the very bottom of the workspace, full-width, with a 1 px top border — matches the Godot editor idiom for script-editor feedback lines.
  - Status bar shows operation results (save, compile, add/delete events and variables) replacing the old toolbar top-row status text.
- Keyboard workflow shortcuts:
  - `Ctrl+S` → save sheet in place (Save As if no path)
  - `Ctrl+Shift+S` → save sheet to new path (Save As)
  - `Ctrl+E` → add event
  - `Ctrl+Shift+V` → add variable
  - `Ctrl+Shift+C` → add condition on selected event row
  - `Ctrl+Shift+A` → add action on selected event row
  - `Q` → add comment row using current structural selection context
  - `Ctrl+C` → copy selected event row (including nested sub-events)
  - `Ctrl+V` → paste copied event row below current selection context
  - `Delete` → remove selected event/condition/action/variable/group
- **Dirty state tracking**: `EventSheetEditor._is_dirty` is set on every mutation (add/edit/delete events, conditions, actions, variables, groups, condition inversion) and cleared on sheet load or successful save.
- Document header (`SheetDocumentHeader`) inside the canvas shows:
  - The sheet file name (or "Untitled Sheet" / "No Sheet Loaded") as the document title
  - The sheet resource path as a secondary hint line (`Unsaved (in-memory)` for unsaved sheets)
  - A summary of globals and root entries
  - A 3px left-accent border rail to visually anchor the header as the document root
- Canvas uses a **document strip** (`SheetCanvasDocumentStrip`) above the scroll surface:
  - Shows `EventSheetResource` kind tag
  - Shows an active-resource tab shell (`SheetCanvasResourceTab`) with document title + dirty dot
  - Shows resource path hint beside the active tab shell
  - Uses a 1px bottom border like editor tab/resource strips
- Central workspace composition now uses `HSplitContainer` (`WorkspaceSplit`) for
  canvas/inspector, matching the dedicated-editor split model instead of a fixed
  panel stack + separator.
- Document framing keeps `SheetSectionGlobals` as a shell, while `SheetSectionEvents` is now a flatter continuous host so authored rows dominate the canvas.
- Section headers use a `ColorRect` accent rail in the header instead of a bullet label, providing a design-system-consistent visual hierarchy.
- Each section header is separated from its body by an `HSeparator` to create a clear visual tier.
- Section empty states are rendered as styled `PanelContainer` cards, providing a consistent visual affordance.
- Empty states are presented as centered onboarding cards with direct create/open actions.
- The inspector empty state is rendered as a contextual card to keep selection/idle surfaces visually consistent with canvas sections.
- Inspector content for selected events, variables, and groups is wrapped in consistently styled card shells using the same design system as the empty state card.
- Each inspector card includes a tinted `HSeparator` immediately after the heading label, separating the card type label from its content rows.

### 2.7 Dense-sheet readability (Phase 5)

- Row wrap margins are 1px top/bottom (down from 2px) for denser sheet rendering.
- Canvas `VBoxContainer` separation is 6px (down from 8px).
- Section body `VBoxContainer` separation is 3px (down from 4px).
- All row types (event, variable, group) use tighter content margins (top/bottom 3px for events, 5px for variable/group).
- Event, variable, and group rows use a `border_width_left` of 3+depth (up from 2+depth) for a stronger depth hierarchy accent.
- Depth guide `ColorRect` lines use opacity 0.80 (up from 0.68) for better visibility at depth.
- Event rows use a 2 px `ColorRect` lane divider (`LANE_DIVIDER_COLOR`) replacing the earlier `VSeparator` for a stronger, pixel-stable lane boundary.

### 2.8 Final cross-surface polish (Phase 6)

- Inspector cards use `border_width_left = 3` for a left accent rail, visually anchoring them like row panels.
- The inspector empty state includes an `HSeparator` after the "Inspector" heading, consistent with the event/variable/group inspector cards.
- The group inspector card styles the Enabled and Collapsed labels with semantic colors: green-tinted for `true`, red-tinted for `false`, and muted blue-grey for Collapsed.
- Section header separators are tinted with the section's accent color at low opacity (0.30), replacing the previous generic border color — improving visual coherence between the section accent rail and its separator.
- The toolbar top row adds a `VSeparator` between the document-meta label and the selection-meta label for clearer visual separation of the two context streams.
- The `+ action` inline button uses teal/green font colors matching the action lane (`do` clause prefix), making lane affinity of add buttons visually consistent (blue `+ condition` → blue condition lane, teal `+ action` → teal action lane).

### 2.9 Horizontal eventsheet lane composition (Phase 7)

- Event rows now use a **two-panel lane layout**: a condition lane (`PanelContainer`, ~35% width) and an action lane (`PanelContainer`, ~65% width), with a 2 px `ColorRect` divider between them.
- Both lane panels have zero outer separation (`HBoxContainer.separation = 0`) so the lanes sit flush against each other and the row border, composing a single horizontal eventsheet lane rather than floating widgets.
- The run-context (trigger) button is anchored at the top of the condition lane and expands horizontally — it reads as the event's "heading" within the lane, making the trigger identity immediately visible.
- The `+ condition` button moves into the condition lane header row, keeping add affordances visually co-located with their lane.
- The `+Add` action button sits at the trailing edge of the action lane flow, keeping it within the action lane with compact labeling.
- The `✕` delete button sits outside both lane panels at the far-right edge of the row.
- Consistent `COND_LANE_RATIO` / `ACTION_LANE_RATIO` constants ensure the lane boundary remains at the same horizontal position across all rows, creating a stable eventsheet column grid.
- Lane spacing and token padding are tightened (`h_separation`/`v_separation` and lane panel insets) to increase vertical density while keeping row readability.
- Run-context and condition/action entries use square, bordered cell styling (including a stronger left border accent on tokens) so entries read as sheet cells rather than rounded chips.
- Empty lane placeholders are lane-tinted (condition vs action) to preserve lane identity even when one side has no authored entries.
- Nested sheet gutters use tighter spacing plus stronger guide contrast to improve parent/child readability in dense lane-based rows.
- Events section now uses an in-flow `Add Event` anchor row aligned to the same gutter/row grid as authored event rows.

### 2.10 Row type badges
- Group rows use a plain `Group` type label (no chip badge panel) with subtle purple text.
- Group rows display the event count in parentheses when the group has child events (e.g., `(2)`).
- The event count label is hidden (empty string) when the group has no child events.
- Comment rows use `//` as a plain text prefix label within the amber banner row.

### 2.11 Sub-event support status

- Sub-event rendering groundwork exists:
  - nested event resources are rendered with indentation
  - recursive sub-event deletion by UID is supported in editor-side removal logic
- Full sub-event authoring UX is **not** implemented yet (no complete add/move/reparent/drag-drop authoring flow).

## 3. Still planned (not implemented yet)

- Multiple EventSheet tabs (Phase 2.4)
- Group-local variables and nested group bodies (Phase 2.5)
- Sheet functions / local subsheets (Phase 3)
- Scripted ACE providers (Phase 4)
- Scripted structural blocks (Phase 5)
- Full importer / round-trip pipeline (Phase 6)

## 4. Implementation anchors

- Main editor: `addons/eventforge/editor/event_sheet_editor.gd`
- Event row inline clauses/menus: `addons/eventforge/editor/event_row_ui.gd`
- Group groundwork row: `addons/eventforge/editor/group_row_ui.gd`

Current selection state is tracked by entry kind (`event`, `condition`, `action`, `variable`, `group`) plus row/index references in `EventSheetEditor`.
