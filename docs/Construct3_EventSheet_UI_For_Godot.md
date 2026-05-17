# Construct 3 Style Event Sheet UI for Godot 4

## Objective

Create a fully custom event sheet editor UI inside Godot 4 that visually and behaviorally resembles Construct 3’s event sheet system.

The UI must:

- read like code
- behave like a semantic text editor
- avoid dashboard/widget aesthetics
- scale to thousands of events
- use virtualization
- support keyboard-first workflows
- support semantic inline editing
- support runtime debugging overlays

This is NOT a node graph editor.

This is NOT a form-based UI.

This is a custom-rendered semantic logic editor.

---

# CRITICAL DESIGN RULES

## NEVER DO THIS

Do NOT build rows using:

- VBoxContainer
- HBoxContainer
- PanelContainer
- Button
- Label
- LineEdit

Do NOT compose rows from nested Godot controls.

This creates:
- ugly chrome
- visual fragmentation
- inspector aesthetics
- unreadable layouts

---

# THE CORRECT ARCHITECTURE

The UI must behave like:
- VSCode
- JetBrains editors
- spreadsheet renderers
- syntax-highlighted code editors

Rows must be:
- manually painted
- hit-tested manually
- virtualized
- semantically rendered

---

# REQUIRED NODE HIERARCHY

```text
EventSheetDock
 └── ScrollContainer
      └── EventSheetViewport
```

---

# EventSheetViewport

```gdscript
@tool
class_name EventSheetViewport
extends Control
```

Responsibilities:
- scrolling
- rendering visible rows
- virtualization
- hit testing
- keyboard navigation
- row selection
- drag/drop
- hover states
- folding
- debug overlays

This is the primary renderer.

---

# REQUIRED FILE STRUCTURE

```text
addons/eventsheet/
│
├── editor/
│   ├── event_sheet_dock.gd
│   ├── event_sheet_viewport.gd
│   ├── event_row_renderer.gd
│   ├── semantic_span.gd
│   ├── row_layout_cache.gd
│   ├── popup_editors/
│   └── autocomplete/
│
├── runtime/
│
├── resources/
│
└── theme/
```

---

# REQUIRED DATA MODEL

```gdscript
class_name EventRowData
extends Resource

var indent: int
var row_type: int
var folded: bool
var selected: bool
var hovered: bool
var spans: Array[SemanticSpan]
var children: Array[EventRowData]
```

---

# SEMANTIC SPANS

Rows are made of semantic text spans.

NOT widgets.

Example:

```text
Player overlaps Enemy
```

NOT:

```text
[Player] [overlaps] [Enemy]
```

---

# Span Types

```gdscript
enum SpanType {
    OBJECT,
    CONDITION,
    ACTION,
    VALUE,
    OPERATOR,
    KEYWORD,
    EXPRESSION,
    COMMENT
}
```

---

# SemanticSpan.gd

```gdscript
class_name SemanticSpan
extends RefCounted

var text: String
var type: SpanType
var rect: Rect2
var metadata
var hoverable := true
```

---

# VISUAL STYLE

The UI must feel:
- flat
- compact
- syntax-driven
- IDE-like

NOT:
- modern dashboard UI
- rounded cards
- inspector widgets

---

# ROW HEIGHT

```gdscript
const ROW_HEIGHT := 28
const INDENT_WIDTH := 18
```

---

# COLORS

## Background

```gdscript
const BG_0 = Color("#1e1f24")
const BG_1 = Color("#24262d")
```

## Text

```gdscript
const TEXT_PRIMARY = Color("#d7dae0")
const TEXT_SECONDARY = Color("#9aa1ad")
const TEXT_MUTED = Color("#6f7580")
```

## Semantic

```gdscript
const COLOR_OBJECT = Color("#6bb6ff")
const COLOR_ACTION = Color("#ffd166")
const COLOR_TRIGGER = Color("#d291ff")
const COLOR_VALUE = Color("#7ee787")
```

Use color sparingly.

The UI should remain mostly monochrome.

---

# TYPOGRAPHY

Use:
- JetBrains Mono
- Cascadia Code
- Inter
- or Godot editor font

Preferred size:

```gdscript
const FONT_SIZE := 13
```

---

# RENDERING STRATEGY

Everything is painted manually inside:

```gdscript
func _draw():
```

Do NOT instantiate rows as Controls.

---

# REQUIRED DRAW ORDER

Each row must render:

```text
background
indent guides
selection
hover
fold arrow
icon
semantic text
debug overlay
```

---

# VIRTUALIZATION (MANDATORY)

Only render visible rows.

Example:

```gdscript
var first_visible := floor(scroll_offset / ROW_HEIGHT)
var visible_count := ceil(size.y / ROW_HEIGHT) + 2
```

Then:

```gdscript
for i in range(first_visible, first_visible + visible_count):
    draw_row(i)
```

Never create thousands of Controls.

---

# FINAL UX GOAL

The final result should feel like:

```text
VSCode
+
Construct 3
+
Gameplay rule editor
```

NOT:
- Unreal Blueprints
- Scratch
- dashboard UI
- inspector forms
