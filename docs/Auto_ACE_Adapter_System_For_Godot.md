# Auto-ACE Adapter System for Godot Event Sheets

> **Historical record (early era).** This document predates the overhaul arcs and the
> v0.5/v0.6 feature waves — treat its claims as a design-time snapshot, not current
> behavior. Current truth: `CHANGELOG.md`, `README.md`, and the maintained specs in
> `docs/` (EDITOR-UI-SPEC, GDSCRIPT-PAIRING-SPEC, the per-feature specs).


## Objective

Create a fully automatic ACE (Actions / Conditions / Expressions) generation system for a Construct 3-style event sheet editor in Godot 4.

The system must:
- automatically discover gameplay capabilities
- infer semantic meanings from GDScript
- minimize manual adapter authoring
- expose gameplay language instead of engine APIs
- support optional annotations for refinement
- allow user scripts to instantly become visual scripting vocabulary

The end goal is:

> Users write normal GDScript and automatically gain Construct-style event sheet integration.

---

# Core Philosophy

The system should expose:

- gameplay semantics
- designer-friendly vocabulary
- event-driven logic concepts

NOT:
- raw Godot APIs
- inheritance trees
- engine internals

---

# Desired Workflow

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

The event sheet automatically gains:

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

No manual adapter creation required.

---

# SYSTEM ARCHITECTURE

```text
Script Reflection
    ↓
Semantic Analyzer
    ↓
ACE Generator
    ↓
Category Inference
    ↓
Annotation Overrides
    ↓
ACE Registry
    ↓
Event Sheet UI
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
│
└── runtime/
```

---

# ACE TYPES

## Conditions

Boolean gameplay checks.

Examples:
- Is On Floor
- Is Dead
- Has Item
- Can Jump

---

## Actions

Gameplay operations.

Examples:
- Jump
- Take Damage
- Play Animation
- Destroy

---

## Expressions

Value-returning queries.

Examples:
- Health
- Velocity
- Current Animation
- Score

---

## Triggers

Signal-based events.

Examples:
- On Died
- On Pressed
- On Body Entered

---

# REFLECTION SYSTEM

Use Godot reflection APIs:

```gdscript
get_method_list()
get_property_list()
get_signal_list()
```

The reflection layer discovers:
- methods
- signals
- exported vars
- typed properties
- inheritance
- script composition

---

# METHOD CLASSIFICATION RULES

## CONDITIONS

Methods returning bool become Conditions.

Example:

```gdscript
func is_dead() -> bool
```

Auto-generates:

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

Auto-generates:

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

Auto-generates:

```text
Expression: Health
```

---

# PROPERTY MAPPING

Exported variables automatically generate:
- expressions
- setters
- arithmetic operations

Example:

```gdscript
@export var health := 100
```

Auto-generates:

```text
Expressions:
- Health

Actions:
- Set Health
- Add To Health
- Subtract From Health
```

---

# SIGNAL MAPPING

Signals automatically become triggers.

Example:

```gdscript
signal died
```

Auto-generates:

```text
Trigger: On Died
```

---

# SEMANTIC ANALYZER

The semantic analyzer infers gameplay meaning from:
- naming conventions
- return types
- parameter types
- inheritance
- neighboring APIs

---

# METHOD NAME HEURISTICS

## Conditions

Methods beginning with:

```text
is_
has_
can_
should_
was_
```

strongly imply Conditions.

---

# CATEGORY INFERENCE

Infer gameplay categories automatically.

---

## Movement Keywords

```text
move
jump
velocity
floor
wall
slide
dash
```

Category:
```text
Movement
```

---

## Combat Keywords

```text
damage
health
attack
hurt
kill
heal
```

Category:
```text
Combat
```

---

## Animation Keywords

```text
animation
sprite
frame
play
blend
```

Category:
```text
Animation
```

---

## Inventory Keywords

```text
item
inventory
equip
loot
consume
```

Category:
```text
Inventory
```

---

# COMPONENT AGGREGATION

The system must support component-based ACE aggregation.

Example scene:

```text
Player
 ├─ HealthComponent
 ├─ InventoryComponent
 ├─ Hurtbox
 └─ AnimationPlayer
```

Automatically becomes:

```text
Player
 ├─ Health
 ├─ Inventory
 ├─ Collision
 └─ Animation
```

The parent object exposes child gameplay capabilities.

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

# REQUIRED ACE TYPES ENUM

```gdscript
enum ACEType {
    CONDITION,
    ACTION,
    EXPRESSION,
    TRIGGER
}
```

---

# USER OVERRIDES

Users must be able to refine automatic generation without creating adapters manually.

---

# RECOMMENDED ANNOTATION SYSTEM

Support optional metadata annotations.

Example:

```gdscript
@ace_category("Combat")
@ace_name("Take Damage")
func take_damage(amount):
```

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

Also support docstring metadata.

Example:

```gdscript
## @ace_category Combat
## @ace_name Take Damage
## @ace_description Deals damage.
func take_damage(amount):
```

This avoids requiring special parser syntax.

---

# USER EXPERIENCE GOALS

The user should feel:

> "I made gameplay systems."

NOT:

> "I authored adapters."

Adapters should mostly disappear behind:
- reflection
- conventions
- inference
- annotations

---

# ACE REGISTRY

The registry stores:
- generated ACEs
- category mappings
- icons
- search indices
- autocomplete data

---

# REQUIRED REGISTRY RESPONSIBILITIES

```text
Discover scripts
Generate ACEs
Cache ACE metadata
Build search indices
Expose autocomplete
Track dependencies
Reload changed scripts
```

---

# CACHING

Generated ACE metadata must be cached.

Reason:
- avoid full project rescans
- reduce editor lag
- support large projects

---

# CACHE INVALIDATION

Invalidate cache when:
- script changes
- scene changes
- annotations change
- exported vars change
- signals change

---

# SEARCH UX

The Add Condition / Action dialogs must prioritize:
- fuzzy search
- semantic matching
- gameplay terminology

Search is more important than tree navigation.

---

# IDEAL SEARCH EXPERIENCE

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

Even across different components.

---

# ACE ORGANIZATION

Group ACEs by gameplay semantics.

NOT inheritance.

---

# GOOD

```text
Movement
Combat
Animation
Inventory
UI
Audio
Physics
Signals
```

---

# BAD

```text
Node
Node2D
CanvasItem
Object
```

---

# EVENT SHEET INTEGRATION

Generated ACEs feed directly into:
- autocomplete
- Add Condition dialog
- Add Action dialog
- expression editors
- semantic text rendering

---

# HOT RELOAD

Changing scripts should immediately refresh:
- ACEs
- categories
- search results
- autocomplete

without restarting the editor.

---

# PERFORMANCE TARGETS

Must support:
- thousands of ACEs
- instant search
- instant autocomplete
- live regeneration

---

# OPTIONAL FUTURE FEATURES

## AI Semantic Categorization

Use embeddings or local AI to improve:
- category detection
- naming cleanup
- gameplay grouping

---

## User Tagging

Allow users to manually tag:
- gameplay systems
- categories
- keywords

---

## Visual Documentation

Auto-generate:
- tooltip docs
- parameter descriptions
- usage examples

from annotations and docstrings.

---

# MOST IMPORTANT RULE

The system must expose:
- gameplay language

NOT:
- engine APIs

That distinction determines whether the system feels:
- magical
or
- overwhelming.

---

# FINAL UX GOAL

The user writes ordinary gameplay code.

The event sheet automatically transforms the project into:
- designer-readable logic
- searchable gameplay vocabulary
- visual scripting semantics

without requiring manual adapter authoring.
