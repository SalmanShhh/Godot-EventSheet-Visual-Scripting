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
- Picker entries are grouped by ACE category, with Construct-style event groups shown when adding events.

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

### 2.3 Event sheet row UX

- Event rows render as compact event-sheet lines with inline authored clauses/tokens.
- Rows avoid explicit lane headers (`IF`, `THEN`, `Conditions`, `Actions`) and instead use inline flow, separators, and token rhythm.
- Clause flow uses compact inline connectors (`when` → `do`) at 10pt with distinct per-lane colors:
  - `when` prefix renders in blue (condition lane accent)
  - `do` prefix renders in green-mint (action lane accent)
- A thin vertical separator visually divides the condition area from the action area.
- Condition tokens use a blue-tinted background with a visible blue border.
- Action tokens use a teal/green-tinted background with a visible teal border — clearly distinct from condition tokens.
- A left gutter is rendered for every row, with branch guides for nested/sub-event rows.
- Condition and action summaries are clickable for focused editing.
- Delete affordances are implemented:
  - event delete via inline row `✕` action
  - condition delete via condition context menu (`Delete Condition`)
  - action delete via action context menu (`Delete Action`)
- When deleting a focused condition/action, inspector selection falls back to the owning event view.
- Variable and group rows share the same sheet-line/gutter composition model.
- Variable rows remain compact in-canvas, with rich hover tooltips that include type/default and optional variable descriptions.

### 2.4 Editor shell and document framing

- The editor uses a dedicated sheet workspace shell:
  - top chrome toolbar panel (`EventForge`) showing the loaded sheet name and document summary
  - toolbar sheet name chip displays file basename when a path exists, or `Untitled Sheet` for in-memory sheets
  - toolbar metadata tracks both document summary and current selection context
  - toolbar action strip shows workflow shortcut hints for event authoring
  - framed canvas surface for the event-sheet document
  - inspector-adjacent panel using the same dark design system
- Keyboard workflow shortcuts are supported for fast authoring:
  - `Ctrl+E` → add event
  - `Ctrl+Shift+V` → add variable
  - `Ctrl+Shift+C` → add condition on selected event row
  - `Ctrl+Shift+A` → add action on selected event row
  - `Delete` → remove selected event/condition/action/variable/group
- Document header (`SheetDocumentHeader`) shows:
  - The sheet file name (or "Untitled Sheet" / "No Sheet Loaded") as the document title
  - The sheet resource path as a secondary hint line
  - A summary of globals and root entries
  - A 3px left-accent border rail to visually anchor the header as the document root
- Document framing is sectioned into explicit shells:
  - `SheetSectionGlobals` for global variables
  - `SheetSectionEvents` for event/group rows
- Section shells use a `ColorRect` accent rail in the header instead of a bullet label, providing a design-system-consistent visual hierarchy.
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
- Clause `VSeparator` uses opacity 0.90 (up from 0.80) for slightly more visible lane division.

### 2.8 Final cross-surface polish (Phase 6)

- Inspector cards use `border_width_left = 3` for a left accent rail, visually anchoring them like row panels.
- The inspector empty state includes an `HSeparator` after the "Inspector" heading, consistent with the event/variable/group inspector cards.
- The group inspector card styles the Enabled and Collapsed labels with semantic colors: green-tinted for `true`, red-tinted for `false`, and muted blue-grey for Collapsed.
- Section header separators are tinted with the section's accent color at low opacity (0.30), replacing the previous generic border color — improving visual coherence between the section accent rail and its separator.
- The toolbar top row adds a `VSeparator` between the document-meta label and the selection-meta label for clearer visual separation of the two context streams.
- The `+ action` inline button uses teal/green font colors matching the action lane (`do` clause prefix), making lane affinity of add buttons visually consistent (blue `+ condition` → blue condition lane, teal `+ action` → teal action lane).

### 2.5 Row type badges

- Variable rows use a styled chip badge (`Global`) with a blue-tinted background and border.
- Group rows use a styled chip badge (`Group`) with a purple-tinted background and border.
- Group rows display the event count in parentheses when the group has child events (e.g., `(2)`).
- The event count label is hidden (empty string) when the group has no child events.

### 2.6 Sub-event support status

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
