# EventSheet C3-to-Godot UI/UX Translation Spec

This document is the **source-of-truth UX bridge** between Construct 3 (C3) event sheet
behavior and the Godot EventSheet editor. It defines how the C3 model maps to Godot's
architecture, where parity is 1:1, where intentional divergence exists, and what the
interaction model should feel like from a designer's perspective.

---

## 1. Top-Level Event Creation Flow

### C3 behavior
- Double-clicking on empty canvas opens a quick-add menu with category tree
- Type to search for triggers, conditions, or actions
- Selecting a trigger creates a new event with that trigger pre-filled
- ESC cancels

### Godot EventSheet behavior (implemented)
- "Add Event" toolbar button or double-click on empty space opens `ACEPickerDialog`
- Search field at top, category tree below
- Selecting a trigger/condition creates a new event and opens params dialog if needed
- ESC or clicking outside the picker closes it
- "Add Signal Event" creates a signal-trigger event directly

### Intentional divergences
- Godot uses an explicit "Add Event / Add Signal Event" split in the toolbar to make
  signal-based events clearly distinct from process/condition-based events
- Categories come from the auto-ACE registry (Godot scene nodes, custom providers) rather
  than hard-coded C3 categories — this makes the picker extensible without code changes

---

## 2. Condition / Action Editing Flow

### C3 behavior
- Double-click a condition/action chip to open its parameter editor
- Re-editing keeps previous values loaded
- Escape cancels, Enter/OK commits
- Conditions live in the left lane, actions in the right lane

### Godot EventSheet behavior (implemented)
- Double-click a condition/action chip → `ACEPickerDialog` opens in replace mode **or**
  `ACEParamsDialog` opens directly if the ACE is already known
- Dialog title shows "(Edit)" for re-edit flows
- First field is auto-focused on open
- Hint text is context-aware: "Re-editing an existing ACE entry." vs "Adding a condition…"
- Conditions in left lane (condition lane), actions in right lane (action lane)

### Expression parameter editing
- When a parameter type is `expression`, an `ExpressionEditorDialog` should open instead
  of a plain text field — see Section 10 for the expression editor spec

### Intentional divergences
- Godot uses a two-step flow (picker → params) for new ACE creation because Godot's
  ACE registry is dynamic — the picker must query available options before showing params
- Re-editing skips the picker step and goes straight to params, matching C3 feel

---

## 3. Drag/Drop Semantics

### C3 behavior
- Rows (events, groups, comments) can be dragged vertically
- Dragging near the top third of a row inserts above; bottom third inserts below;
  middle third inserts as child (sub-event)
- A horizontal line preview indicates insert position
- Dragging inside a group shows a nested insertion indicator
- Conditions can be reordered within a row by dragging left/right
- Actions can be reordered within a row by dragging left/right (or vertically if stacked)
- Visual distinction between drag type (event vs condition vs action) via cursor change

### Godot EventSheet behavior (implemented + extended)
- Row drag: `_drag_row_index` → `_drag_target_index` with mode `before`/`after`/`inside`
  - `before` = thin horizontal line above the target row
  - `after` = thin horizontal line below the target row
  - `inside` = rectangular highlight on the target row (indicates sub-event insertion)
- ACE drag: `_drag_ace_entries` → vertical insertion bar within the lane
  - Condition drag: vertical bar in the condition lane at the insert point
  - Action drag: vertical bar in the action lane at the insert point
- **Drag source type indicator**: a floating badge near cursor shows "Event", "Group",
  "Condition", or "Action" while dragging, so it is always clear what is being moved

### Drop zone visual guide

| Mode     | Visual                                      |
|----------|---------------------------------------------|
| `before` | 2px blue line above target row              |
| `after`  | 2px blue line below target row              |
| `inside` | Rounded rect fill on target row (sub-event) |
| ACE slot | 3px vertical bar between/beside chips       |

### Intentional divergences
- Godot splits row drag and ACE drag into completely separate state paths for clarity
- Multi-row drag is supported (select multiple rows, drag as a group) — not in C3

---

## 4. Event vs Sub-Event Mental Model

### C3 behavior
- Events can contain sub-events indented one level
- Sub-events only run when the parent event's conditions are true
- You can nest deeply (sub-sub-events)
- Folding a parent hides all children

### Godot EventSheet behavior (implemented)
- `EventRow.sub_events` holds child events; `EventGroup.children` holds group children
- Sub-events are indented visually via `row_data.indent`
- Fold arrow on parent collapses children
- Selection of a parent event also selects all descendants for multi-row operations
- Ctrl/Cmd toggles individual child deselection from a grouped selection

---

## 5. Group Behavior

### C3 behavior
- Groups are named containers for events
- Groups can be activated/deactivated at runtime (independent of individual event enable)
- Clicking the group header folds/unfolds all events in the group
- Groups can be nested

### Godot EventSheet behavior (implemented)
- `EventGroup` resource with `enabled` flag and `name`/`group_name` fields
- Group rows render with accent sidebar, fold arrow, and group title label
- `EventGroup.children` holds child events/groups
- Group enable/disable via context menu → `ROW_MENU_TOGGLE_ENABLED`
- Group fold via fold arrow or context menu → `ROW_MENU_TOGGLE_GROUP_FOLD`
- Group name is inline-editable (double-click title)

### Intentional divergences
- Godot groups also serve as organizational containers that can hold local variables
  (future: group-scoped variable block)

---

## 6. Comments

### C3 behavior
- Comments are full-width rows with styled text
- They are non-executing decorative markers
- Draggable, folding not applicable

### Godot EventSheet behavior (implemented)
- `CommentRow` resource with `text` and `enabled` flag
- Rendered as full-width styled row with comment-style background
- Inline-editable (double-click)
- Draggable as a row (before/after mode only, no inside)
- Enable/disable supported

---

## 7. Else / ElseIf / Or Block Flow

### C3 behavior
- An event can be marked as "Else" (runs if previous event did not run)
- An event can be marked as "ElseIf" with additional conditions
- Multiple conditions in an event can be set to OR mode (any condition suffices)

### Godot EventSheet behavior (implemented)
- `EventRow.else_mode` enum: `NONE`, `ELSE`, `ELIF`
- `Else` events render "Else" badge in condition lane, no conditions required
- `ElseIf` events render "Else If" badge followed by their conditions
- `EventRow.condition_mode` enum: `AND`, `OR`
  - In OR mode, each condition line shows an "OR" badge before it
- Context menu → "Convert to OR Block" toggles the condition mode

### Planned UX improvement
- Add right-click → "Mark as Else" / "Mark as Else If" / "Mark as AND block" / "Mark as OR block"
  options directly on event rows for discoverable access to these semantics

---

## 8. Selection Behavior

### C3 behavior
- Click event row selects it; click condition/action chip selects that chip
- Multi-select: Ctrl/Cmd+click adds/removes from selection
- Selecting an event block visually highlights the block, not individual chips
- Shift-click range-selects rows

### Godot EventSheet behavior (implemented)
- Click row → selects row; if span (condition/action chip) is clicked, selects span
- Ctrl/Cmd+click → toggles individual row or span in selection
- Event-body click (no specific span) → selects event and all descendant rows
- Ctrl/Cmd+click child → removes child from the grouped selection
- Box-select (drag on empty space) → selects overlapping rows and spans
- Span-level selection shows a highlight on the chip, not the full row background

### Intentional divergences
- Godot adds box-selection (not in C3) for power-users
- Godot preserves selection through context-menu actions where possible

---

## 9. Enable / Disable Semantics

### C3 behavior
- Individual conditions, actions, and events can be enabled/disabled
- Disabled items render dimmed and are skipped at runtime
- Groups can be disabled, which disables all their children

### Godot EventSheet behavior (implemented)
- Row-level: `EventRow.enabled`, `EventGroup.enabled`, `CommentRow.enabled`
  - Disabled rows render with a semi-transparent overlay
  - Context menu → "Disable Row" / "Enable Row" toggles
- ACE-level: `ACECondition.enabled`, `ACEAction.enabled`
  - Disabled ACE chips render dimmed with strike-through
  - Context menu → "Disable Condition" / "Disable Action" toggles
- `_row_disabled_state` viewport dictionary persists enable state across refreshes

---

## 10. Expression Editing Flow

### C3 behavior
- Expression fields open a dedicated Expression Editor panel
- Panel has: input field, autocomplete dropdown, function browser, variable list
- Live syntax highlighting and basic error indicators
- History of recent expressions per field type

### Godot EventSheet behavior (planned / partially scaffolded)
- `ExpressionEditorDialog` exists as a dedicated dialog for expression-type parameters
- Opened automatically when an ACE parameter is marked `type = TYPE_EXPRESSION` or
  `"expression": true` in the parameter descriptor
- Features in initial implementation:
  - Single-line expression input
  - Available variables list from the sheet (global + local from selected event)
  - Close/OK/Cancel flow
  - Hint text with expression syntax reminder
- Deferred: autocomplete, function browser, live validation, history

---

## 11. Variable Semantics

### C3 behavior
- Instance variables are private to an object instance
- Global variables are project-wide and accessible from any event sheet

### Godot EventSheet behavior (implemented + extended)
- **Global variables** (`sheet.variables` dictionary with `scope = "global"` implied)
  - Rendered at the top of the event sheet
  - Marked as `exposed = true` by default — meaning they are exported/visible in the
    Godot Inspector when the EventSheet scene is instantiated
  - Not private: they represent script-facing exported properties of the sheet
  - `const` badge shown if `is_constant = true`
- **Local variables** (`EventRow.local_variables` as `LocalVariable` resources)
  - Rendered indented under their parent event row
  - Scoped to that event execution — not inspector-visible

### Inspector exposure
- A global variable with `exposed = true` generates an `@export` annotation in compiled
  GDScript (Phase 4 — deferred)
- The "exposed" indicator is shown as a small badge on global variable rows in the editor

---

## 12. Where Godot Intentionally Differs from C3

| Topic | C3 | Godot EventSheet | Reason |
|---|---|---|---|
| ACE categories | Hard-coded C3 categories | Auto-populated from Godot scene nodes + providers | Extensibility without code changes |
| Event creation flow | Single picker | Picker → Params two-step | Dynamic registry needs to query params per-ACE |
| Variable types | Object/Number/String/Boolean/Array | Godot Variant types | Match the Godot type system |
| Families/Groups | C3 Families for typed-object groups | Not implemented | Out of scope for initial version |
| Behaviors | C3 Behaviors as component ACE bundles | Auto-ACE discovers node/component APIs | Godot component model differs fundamentally |
| Runtime | C3 built-in runtime | Compiled GDScript + optional EventForge runtime | Godot-native execution for performance |
| Expression syntax | C3 expression language | GDScript expressions (planned) | Godot-native; no extra parser needed |
| Sub-events | C3 nested events | `EventRow.sub_events` array | Same concept, different backing store |

---

## 13. Interaction Model Summary

```
User action                        →  System response
────────────────────────────────────────────────────────────────
Double-click empty canvas          →  ACE picker (new event mode)
Double-click condition/action chip →  ACE params dialog (replace/edit mode)
Single-click event row body        →  Select row + descendants
Single-click condition/action chip →  Select that span only
Ctrl/Cmd+click row or span         →  Toggle selection
Drag row (top third of target)     →  Insert before — thin line above target
Drag row (bottom third of target)  →  Insert after — thin line below target
Drag row (middle third of target)  →  Insert as sub-event — fill highlight on target
Drag condition/action chip         →  Vertical bar in lane at insert point
Right-click row body               →  Row context menu
Right-click condition chip         →  Condition context menu
Right-click action chip            →  Action context menu
```
