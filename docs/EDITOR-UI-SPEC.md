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

- Event rows render with side-by-side lanes:
  - left lane: run context + conditions
  - right lane: actions
- Current polish direction is compact, readable lane headers and tighter row chrome (header controls, lane tinting, hover cues).
- Condition and action summaries are clickable for focused editing.
- Delete affordances are implemented:
  - event delete via header `✕` action
  - condition delete via condition context menu (`Delete Condition`)
  - action delete via action context menu (`Delete Action`)
- When deleting a focused condition/action, inspector selection falls back to the owning event view.

### 2.4 Sub-event support status

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
- Event row lanes/menus: `addons/eventforge/editor/event_row_ui.gd`
- Group groundwork row: `addons/eventforge/editor/group_row_ui.gd`

Current selection state is tracked by entry kind (`event`, `condition`, `action`, `variable`, `group`) plus row/index references in `EventSheetEditor`.
