# EventForge Editor UI Specification

## 1. Overview

EventForge event sheets behave like vertical Construct/GDevelop-style sheet documents.
A sheet is a scrollable document containing global variable rows followed by event blocks.
Each event block shows its run context, conditions, and actions in a summary-first layout.
All entries are clickable for focused editing in the inspector panel.

---

## 2. Phase table

| Phase   | Description                                                            | Status        |
|---------|------------------------------------------------------------------------|---------------|
| 2 MVP   | Editor shell, dual/split view (sheet canvas + GDScript preview)        | Implemented   |
| 2.1     | Editable rows, param inspector, save/load                              | Implemented   |
| 2.2     | Sheet variables, variable-aware params, copy/paste/duplicate/delete    | Implemented   |
| 2.3     | Construct/GDevelop-style document flow foundation                      | Implemented   |
| 2.4     | Multiple EventSheet tabs                                               | Planned       |
| 2.5     | Group-local variables and nested group bodies                          | Planned       |
| 3       | Sheet functions and local subsheets                                    | Planned       |
| 4       | Scripted ACE providers                                                 | Planned       |
| 5       | Scripted structural blocks                                             | Planned       |
| 6       | GDScript importer / round-trip                                         | Planned       |

---

## 3. Current intended UX (Phase 2.3)

The event sheet canvas is a scrollable document. It renders top-to-bottom:

```
Event Sheet Document
════════════════════════════════════

Global Variables
────────────────────────────────────
  Global  int  health = 100
  Global  String  player_name = "Player"

Events
────────────────────────────────────

  ┌─ Event ──────────────────────────────┐
  │ Runs: Every Frame                     │
  │ Conditions                            │
  │   Always                              │
  │ Actions                               │
  │   Print "Hello"                       │
  └───────────────────────────────────────┘

  ┌─ Event ──────────────────────────────┐
  │ Runs: On Signal "pressed" from Button │
  │ Conditions                            │
  │   health > 0                          │
  │ Actions                               │
  │   health = health - 1                 │
  └───────────────────────────────────────┘
```

Groups appear as purple-tinted headers and are groundwork only in Phase 2.3:

```
  ▶ Group: Player
```

---

## 4. Canvas layout rules

### 4.1 Document header

The canvas has a visible top header:

```
Event Sheet Document
```

### 4.2 Section headings

Two section headings divide the document:

- `Global Variables`
- `Events`

### 4.3 Empty variable hint

When no global variables are defined, an inline canvas hint is shown:

```
No global variables yet. Use + Add Var to create one.
```

### 4.4 Global variable rows

When variables exist each is rendered as a green-tinted card:

```
Global  int  health = 100
Global  String  player_name = "Player"
```

Variable rows are:
- visually stronger than plain text (green tint, left accent border, badge-like `Global` label)
- clickable/selectable
- backed by `current_sheet.variables` as the single source of truth
- editable via the inspector panel when selected

### 4.5 Event blocks

Event blocks read like document sections:

```
┌─ Event ────────────────────────────────┐
│ Runs: Every Frame                       │
│ Conditions                              │
│   Always                                │
│ Actions                                 │
│   Print "Hello"                         │
└─────────────────────────────────────────┘
```

Each condition and action entry is a clickable summary. Clicking opens a focused inspector
for that entry. The focused inspector has a `← Back to Event` button.

### 4.6 Run context language

The `Runs:` label uses plain run-context language, not user-facing "Trigger":

| trigger_id          | Displayed as                            |
|---------------------|-----------------------------------------|
| OnProcess           | Every Frame                             |
| OnReady             | On Ready                                |
| OnPhysicsProcess    | On Physics Process                      |
| OnBodyEntered       | On Body Entered                         |
| OnSignal            | On Signal "<signal>" from <source>      |
| (empty)             | Choose when this event runs…            |

The word "Trigger" is reserved for internal ACEDescriptor enum compatibility and compiler
identifiers. It must not appear in user-facing event sheet UI labels.

---

## 5. Inspector panel

The inspector panel on the right side shows context-sensitive editing UI.

| Selection              | Inspector shows                                   |
|------------------------|---------------------------------------------------|
| Nothing                | (empty / hint text)                               |
| Event row              | Full event inspector: run context, conditions list, actions list |
| Condition entry        | Focused condition editor + `← Back to Event`      |
| Action entry           | Focused action editor + `← Back to Event`         |
| Variable row           | Variable editor: name, type, default value        |
| Group row              | Group editor: name, description, enabled/collapsed |

### 5.1 Focused entry removal

Removing a focused condition or action from the focused inspector must:
1. Remove the entry from the event row.
2. Return the inspector to the full event view for the **same** event row.

### 5.2 Group inspector note

The group inspector shows name, description, and enabled/collapsed fields.
It must display a note:

```
Nested local variables and group event bodies are planned.
```

Do not fake local variable compiler scoping in the group inspector.

---

## 6. Sheet Variables panel

A side Sheet Variables panel provides supporting access to `current_sheet.variables`.
It is **not** the primary representation; global variable rows in the canvas document are.
Both the panel and the canvas rows use `current_sheet.variables` as the single backing store.

---

## 7. Planned features (not yet implemented)

The following features are planned but must **not** be partially faked:

- **Multiple EventSheet tabs** (Phase 2.4): tab bar for switching between multiple open sheets.
- **Group-local variables** (Phase 2.5): variables scoped to a group with compiler enforcement.
  Until Phase 2.5 compiler support exists, the group inspector only notes this is planned.
- **Sheet functions / local subsheets** (Phase 3): reusable named sub-sheets.
- **Scripted ACE providers** (Phase 4): GDScript-defined custom conditions/actions/expressions.
- **Scripted structural blocks** (Phase 5): loops, sub-events, pick filters via scripted providers.
- **GDScript importer / round-trip** (Phase 6): import existing GDScript into event sheets.

---

## 8. Implementation notes

- UI is constructed programmatically in GDScript; no extra `.tscn` scenes are added unless
  already natural to the existing plugin structure.
- Godot 4.5 compatibility is required.
- `VariableRowUI` renders global variable rows with `format_summary(var_name, info)`.
- `EventRowUI` emits `condition_selected(row, index)` and `action_selected(row, index)` signals.
- `GroupRowUI` is lightweight groundwork; it does not implement nested event bodies.
- `EventSheetEditor` tracks `_selected_entry_kind` (one of `"none"`, `"event"`, `"condition"`,
  `"action"`, `"variable"`, `"group"`) along with the relevant row/index references.
