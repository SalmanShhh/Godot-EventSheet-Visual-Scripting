# EventSheet Compiler Alignment Notes

This document explains how current resource/editor/runtime decisions align with the
EventForge compiler spec and what remains for future compiler work.

It is intended as a reference for anyone extending the editor or the compiler to
understand what contracts are already established and what is still open.

---

## 1. Resource / Data Model Alignment

### What is stable
- `EventSheetResource` is the canonical serialization format
  - `events: Array[Resource]` — ordered list of `EventRow`, `EventGroup`, `CommentRow`
  - `variables: Dictionary` — global variable descriptors keyed by name
  - `editor_style: EventSheetEditorStyle` — editor visual config, ignored by compiler
- `EventRow` fields consumed by the compiler:
  - `trigger: ACECondition` or `trigger_id: String` — the event trigger
  - `conditions: Array[ACECondition]` — all conditions (AND/OR mode from `condition_mode`)
  - `actions: Array[ACEAction]` — actions to execute when conditions pass
  - `sub_events: Array[Resource]` — child events (nested logic)
  - `else_mode: ElseMode` — `NONE`, `ELSE`, or `ELIF` for conditional chaining
  - `enabled: bool` — if false, event is skipped at runtime
  - `local_variables: Array[LocalVariable]` — scoped to this event's execution

### What the compiler must not touch
- `comment: String` on `EventRow` — authoring annotation only
- `EventGroup.name`/`group_name` — organizational annotation
- `CommentRow.text` — annotation only

---

## 2. ACE Resource Contracts

### ACECondition fields
- `ace_id: String` — maps to `ACEDefinition.ace_id` in the registry
- `parameters: Dictionary` — `{ param_id → typed_value }` filled by param dialog
- `negated: bool` — if true, invert the condition result
- `enabled: bool` — if false, skip this condition (treat as always-true during eval)

### ACEAction fields
- `ace_id: String` — maps to `ACEDefinition.ace_id`
- `parameters: Dictionary` — `{ param_id → typed_value }`
- `enabled: bool` — if false, skip at runtime

### Compiler note on `enabled` flags
- A disabled condition should be **excluded from evaluation** (not negated)
- A disabled action should be **excluded from execution**
- This means a row with all conditions disabled is effectively "Every Tick"
- This is intentional: designers can temporarily disable conditions without deleting them

---

## 3. Trigger vs Condition Distinction

### Resource model
- `EventRow.trigger` holds the primary trigger ACE (fires the event)
- `EventRow.conditions` holds all other conditions (filter pass/fail)
- An event without a trigger and without conditions runs every frame ("Every Tick")
- An event with `trigger_id` (string) is a signal-based event bound by id

### Compiler expected behavior
- Phase 1: Check `trigger` — if it is a signal trigger, wire a signal handler
- Phase 2: Evaluate `conditions` (AND or OR based on `condition_mode`)
- Phase 3: If conditions pass, execute `actions`
- Phase 4: Process `sub_events` recursively if parent conditions passed

---

## 4. Else / ElseIf Chain Semantics

### Resource model
- A sequence of `EventRow` resources can form an if/else chain:
  ```
  EventRow(else_mode=NONE)   → if conditions: ...
  EventRow(else_mode=ELSE)   → else: ...
  EventRow(else_mode=ELIF)   → else if conditions: ...
  ```

### Compiler expected behavior
- The compiler must track a "last event ran" flag
- An `ELSE` event runs only if the immediately preceding sibling did NOT run
- An `ELIF` event runs only if the immediately preceding sibling did NOT run AND its
  own conditions pass
- Nesting: each sub-event list is evaluated with its own "last ran" tracking

---

## 5. Variable Compilation

### Global variables
- `sheet.variables` dictionary entries with:
  - `type: String` — Godot type name ("int", "float", "String", "bool", "Variant")
  - `default: Variant` — default value for initialization
  - `const: bool` — if true, generate a `const` declaration
  - `exposed: bool` — if true, generate an `@export` annotation (future Phase 4)
- Global variables compile to class-level declarations in the generated GDScript

### Local variables
- `EventRow.local_variables` entries (`LocalVariable` resources):
  - `name: String`
  - `type_name: String`
  - `default_value: Variant`
  - `is_constant: bool`
- Local variables compile to `var` declarations inside the event's execution block

---

## 6. Phase Status

| Phase | Description | Status |
|-------|-------------|--------|
| Phase 1 | Resources / registry / serialization | **Implemented + extended** |
| Phase 2 | Editor panel / row rendering / undo-redo | **Implemented + extended** |
| Phase 3 | Picker / params / expression | **Partial** — expression dialog scaffolded |
| Phase 4 | Runtime execution engine | **Deferred** |
| Phase 5 | Optimization / virtualization / extensions | **Partial** |

---

## 7. What the Compiler Needs from the Editor (Current Contracts)

The compiler consumes the resource tree. The editor must ensure:

1. Every `ACECondition` and `ACEAction` has a valid `ace_id` string
2. `parameters` dictionaries use the `param_id` keys from the matching `ACEDefinition`
3. `EventRow.sub_events` only contains valid `Resource` subtypes
4. `EventGroup.children` preserves insertion order
5. `EventSheetResource.events` preserves authoring order

The editor **does not** need to validate ACE parameter types before saving —
validation is the compiler's responsibility.

---

## 8. Expression Parameters (Current and Future)

### Current state
- ACE parameters with `type = TYPE_STRING` are edited as plain text
- When a parameter descriptor includes `"expression": true`, the param dialog
  opens `ExpressionEditorDialog` instead of a plain `LineEdit`
- Expressions are stored as strings in `parameters`

### Compiler expected behavior (Phase 4)
- Expression strings are compiled as raw GDScript expressions
- The compiler wraps them in an `eval`-like context where sheet variables and
  node properties are in scope
- No escaping needed: the expression string is emitted verbatim within the
  generated method body

### Future: expression validation
- The expression editor may add a "validate" step that parses the GDScript expression
  before the user confirms, surfacing syntax errors early
- This requires spawning a GDScript parser — deferred to Phase 3+

---

## 9. Compiler Output Contract (Planned)

The expected output of a fully-implemented compiler:

```gdscript
# Auto-generated by EventForge — do not edit manually
extends Node

@export var health: int = 100        # global variable, exposed
@export var speed: float = 5.0       # global variable, exposed

func _ready() -> void:
    pass

func _process(_delta: float) -> void:
    _run_event_sheet()

func _run_event_sheet() -> void:
    # Event 1: Every Tick
    _event_1_actions()
    # Event 2: If health < 10
    if health < 10:
        _event_2_actions()
    else:
        # Event 3: Else
        _event_3_actions()
```

This output format is intentionally readable and auditable by the designer.

---

## 10. Known Gaps and Deferred Items

- Runtime ACE binding (calling actual Godot node methods from compiled ACE ids): **Deferred**
- Expression validation before save: **Deferred**
- `@export` generation for `exposed = true` global variables: **Deferred (Phase 4)**
- Signal handler wiring for `trigger_id`-based events: **Partial**
- Group-level enable/disable affecting child event execution in compiler: **Partial**
- Sub-event depth limit enforcement: **Not implemented**
