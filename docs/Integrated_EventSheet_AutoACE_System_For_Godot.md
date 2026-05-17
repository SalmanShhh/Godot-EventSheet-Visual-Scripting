# Construct 3 Style Event Sheet + Auto-ACE System for Godot 4

## Objective

Create a fully custom Construct 3-style Event Sheet editor for Godot 4 with a deeply integrated automatic ACE (Actions / Conditions / Expressions) generation system.

The combined system must:

- feel like a semantic gameplay IDE
- behave like a code editor
- automatically expose gameplay vocabulary
- avoid inspector-style UI
- avoid graph/node scripting UX
- scale to large projects
- support automatic reflection-based ACE generation
- support semantic rendering
- support keyboard-first workflows
- support runtime debugging overlays
- support hot-reloading gameplay capabilities

This is NOT:
- GraphEdit
- visual node scripting
- form-based UI
- nested Godot controls

This IS:
- a semantic gameplay rule editor
- a visual AST editor
- a custom-rendered gameplay language interface

---

# CORE DESIGN PHILOSOPHY

The system should feel like:

```text
VSCode
+
Construct 3
+
Gameplay rule editor
```

The user should feel:
> "I am reading gameplay logic."

NOT:
> "I am manipulating widgets."

---

# PRIMARY ARCHITECTURE

```text
Game Scripts
    ↓
Reflection System
    ↓
Semantic Analyzer
    ↓
Auto-ACE Generator
    ↓
ACE Registry
    ↓
Event Sheet Renderer
    ↓
Semantic Gameplay UI
```

---

# CRITICAL RULES

## NEVER BUILD ROWS USING:

- VBoxContainer
- HBoxContainer
- PanelContainer
- Button
- Label
- LineEdit

Rows must NOT be composed from nested controls.

---

# EVENT SHEET RENDERING MODEL

The Event Sheet must:
- manually paint rows
- manually hit-test spans
- virtualize rendering
- render semantic text
- behave like a code editor

---

# REQUIRED NODE HIERARCHY

```text
EventSheetDock
 └── ScrollContainer
      └── EventSheetViewport
```

---

# REQUIRED FILE STRUCTURE

```text
addons/eventsheet/
│
├── ace/
│   ├── ace_registry.gd
│   ├── ace_generator.gd
│   ├── semantic_analyzer.gd
│   ├── category_inference.gd
│   ├── ace_adapter.gd
│   ├── ace_definition.gd
│   ├── reflection/
│   ├── annotations/
│   └── cache/
│
├── editor/
│   ├── event_sheet_dock.gd
│   ├── event_sheet_viewport.gd
│   ├── event_row_renderer.gd
│   ├── semantic_span.gd
│   ├── row_layout_cache.gd
│   ├── ace_dialog/
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

# THE MOST IMPORTANT ARCHITECTURAL INSIGHT

The event sheet should NOT expose:
- engine APIs
- inheritance trees
- raw Godot internals

It should expose:
- gameplay language
- gameplay capabilities
- semantic actions
- designer-readable logic

---

# EVENT SHEET ROW STRUCTURE

Each row is rendered manually.

A row contains:

```text
Indent
Fold Arrow
Icon
Semantic Text Spans
Selection State
Hover State
Debug Overlay
```

---

# SEMANTIC SPANS

Rows are built from semantic text spans.

NOT widgets.

---

# GOOD

```text
▶ Player overlaps Enemy
    → Enemy.Health -= 10
```

---

# BAD

```text
[Player] [overlaps] [Enemy]
```

---

# REQUIRED SPAN TYPES

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

# SEMANTIC SPAN MODEL

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

# AUTO-ACE SYSTEM

The ACE system automatically generates:
- conditions
- actions
- expressions
- triggers

from ordinary GDScript gameplay code.

---

# TARGET USER EXPERIENCE

User writes:

```gdscript
extends CharacterBody2D

signal died

@export var health := 100

func take_damage(amount):
    health -= amount

func heal(amount):
    health += amount

func is_dead() -> bool:
    return health <= 0
```

The Event Sheet automatically gains:

```text
Health
 ├─ Health
 ├─ Set Health
 ├─ Add To Health
 ├─ Subtract From Health
 ├─ Take Damage
 ├─ Heal
 ├─ Is Dead
 └─ On Died
```

WITHOUT manual adapter creation.

---

# REFLECTION LAYER

Use:

```gdscript
get_method_list()
get_property_list()
get_signal_list()
```

The reflection layer discovers:
- methods
- exported vars
- typed vars
- signals
- inheritance
- components

---

# ACE GENERATION RULES

## CONDITIONS

Methods returning bool become Conditions.

Example:

```gdscript
func is_dead() -> bool
```

Becomes:

```text
Condition: Is Dead
```

---

## ACTIONS

Void methods become Actions.

Example:

```gdscript
func jump():
```

Becomes:

```text
Action: Jump
```

---

## EXPRESSIONS

Methods returning values become Expressions.

Example:

```gdscript
func get_health() -> int
```

Becomes:

```text
Expression: Health
```

---

# PROPERTY MAPPING

Exported variables automatically generate:
- expressions
- setters
- arithmetic actions

Example:

```gdscript
@export var health := 100
```

Auto-generates:

```text
Expression:
- Health

Actions:
- Set Health
- Add To Health
- Subtract From Health
```

---

# SIGNAL MAPPING

Signals automatically become Triggers.

Example:

```gdscript
signal died
```

Becomes:

```text
Trigger:
- On Died
```

---

# COMPONENT AGGREGATION

Child gameplay components automatically contribute ACEs.

Example:

```text
Player
 ├─ HealthComponent
 ├─ InventoryComponent
 ├─ AnimationPlayer
```

Automatically becomes:

```text
Player
 ├─ Health
 ├─ Inventory
 └─ Animation
```

inside the ACE dialog.

---

# EVENT SHEET + ACE INTEGRATION

The Event Sheet renderer must directly consume:
- generated ACE metadata
- semantic categories
- parameter definitions
- gameplay vocabulary

The ACE Registry becomes the primary source of:
- autocomplete
- event creation
- condition creation
- expression editing
- semantic coloring

---

# ACE REGISTRY RESPONSIBILITIES

```text
Discover scripts
Generate ACEs
Categorize gameplay systems
Build search indices
Provide autocomplete
Provide metadata
Handle hot reload
Cache reflection results
```

---

# REQUIRED ACE DATA MODEL

```gdscript
class_name ACEDefinition
extends Resource

var id: String
var display_name: String
var category: String
var ace_type: int
var description: String
var parameters: Array
var return_type: Variant.Type
var icon: String
var metadata := {}
```

---

# ACE TYPES

```gdscript
enum ACEType {
    CONDITION,
    ACTION,
    EXPRESSION,
    TRIGGER
}
```

---

# CATEGORY SYSTEM

Categories are gameplay semantic groupings.

NOT inheritance trees.

---

# GOOD CATEGORIES

```text
Movement
Combat
Animation
Inventory
Audio
UI
Physics
Signals
Navigation
AI
```

---

# BAD CATEGORIES

```text
Node
Node2D
CanvasItem
Object
```

---

# CATEGORY INFERENCE

Infer categories from:
- naming
- parameter types
- neighboring methods
- components
- semantic keywords

---

# MOVEMENT KEYWORDS

```text
move
jump
velocity
floor
wall
dash
slide
```

---

# COMBAT KEYWORDS

```text
damage
health
hurt
heal
kill
attack
```

---

# ANIMATION KEYWORDS

```text
animation
play
frame
blend
sprite
```

---

# OPTIONAL USER OVERRIDES

Users can refine ACE generation using annotations.

---

# SUPPORTED ANNOTATIONS

```gdscript
@ace_hidden
@ace_category("Combat")
@ace_name("Take Damage")
@ace_description("Deals damage")
@ace_action
@ace_condition
@ace_expression
@ace_trigger
@ace_icon("heart")
```

---

# DOCSTRING SUPPORT

Also support:

```gdscript
## @ace_category Combat
## @ace_name Take Damage
## @ace_description Deals damage.
func take_damage(amount):
```

This avoids requiring custom syntax.

---

# EVENT SHEET RENDERING REQUIREMENTS

The renderer must:
- manually paint rows
- avoid widget fragmentation
- render semantic inline text
- support large projects
- support virtualization

---

# REQUIRED DRAW ORDER

```text
Background
Indent Guides
Selection
Hover
Fold Arrow
Icon
Semantic Text
Debug Overlay
```

---

# REQUIRED DRAWING APIs

Use:

```gdscript
draw_rect()
draw_line()
draw_string()
draw_texture()
```

Recommended:
- TextLine
- Font APIs

Avoid:
- RichTextLabel
- Tree
- GraphEdit

---

# VIRTUALIZATION (MANDATORY)

Only visible rows may render.

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

---

# HIT TESTING

Every semantic span stores:
- bounding rectangle
- metadata
- ACE references

Example:

```gdscript
span.rect = Rect2(position, size)
```

Mouse interaction:

```gdscript
if span.rect.has_point(mouse_pos):
```

This replaces Buttons and Labels.

---

# INLINE EDITING MODEL

Rows are NOT permanently editable controls.

Default state:
- semantic rendered text

Editing state:
- popup editor appears

Example:
- click object name
- autocomplete popup opens
- select ACE
- popup disappears
- row rerenders

---

# ACE DIALOG DESIGN

The Add Condition / Add Action dialogs should resemble:
- command palettes
- IDE search windows
- semantic gameplay browsers

NOT:
- raw engine API trees

---

# IDEAL ACE DIALOG LAYOUT

```text
┌─────────────────────────────┐
│ Search...                   │
├────────────┬────────────────┤
│ Categories │ ACE Preview    │
│            │                │
│ Movement   │ Is On Floor    │
│ Combat     │ Returns true   │
│ Animation  │ if object is   │
│ Inventory  │ touching floor │
└────────────┴────────────────┘
```

---

# SEARCH UX

Search is MORE IMPORTANT than tree navigation.

Support:
- fuzzy search
- semantic search
- category search
- keyword matching
- autocomplete

Typing:

```text
damage
```

Should instantly show:
- Take Damage
- Health
- Hurt
- Attack
- Is Dead

---

# HOT RELOAD

Changing scripts must automatically refresh:
- ACE generation
- autocomplete
- event sheet metadata
- categories
- semantic rendering

without restarting the editor.

---

# DEBUG OVERLAYS

During gameplay:
- green rows = passed
- red rows = failed
- yellow rows = waiting

Draw overlays directly onto rows.

---

# BREAKPOINTS

Support:
- breakpoint dots
- execution highlighting
- current execution row

Like:
- VSCode
- JetBrains

---

# PERFORMANCE TARGETS

Must support:

```text
10,000+ rows
thousands of ACEs
60fps scrolling
instant hover
instant autocomplete
instant search
```

---

# MOST IMPORTANT UX GOAL

The user should feel:

> "My gameplay code automatically became a visual scripting language."

NOT:

> "I manually configured adapters and UI widgets."

---

# FINAL GOAL

The completed system should feel like:

```text
Construct 3
+
VSCode
+
Godot scene composition
+
Automatic gameplay reflection
```

A semantic gameplay IDE where:
- code becomes gameplay vocabulary
- gameplay vocabulary becomes event sheets
- event sheets remain readable like code
