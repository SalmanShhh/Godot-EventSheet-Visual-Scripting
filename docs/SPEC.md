# EventForge Specification (Consolidated)

## 1. Scope

EventForge provides Construct-style event sheet authoring for Godot and compiles sheet resources to deterministic GDScript.

## 2. Current implemented architecture

### 2.1 Resource/data model (source of truth)

The canonical model is resource-driven (`EventSheetResource` and row/ACE resources under `addons/eventforge/resources/`).

- UI edits this model directly.
- Save/load and compile operate on the same resource graph.

### 2.2 Editor layer (active, implemented)

The editor under `addons/eventforge/editor/` is no longer a placeholder.

Implemented foundation includes:
- sheet canvas + inspector workflow
- ACE picker and param dialogs
- variable-aware param input handling
- event/condition/action delete flows
- event lane rendering with limited sub-event indentation groundwork

### 2.3 Compiler/runtime boundary

- **Editor/UI responsibility:** author and mutate sheet resources.
- **Compiler/runtime responsibility:** consume those resources and emit/execute generated behavior.

This boundary is intentional: UI polish can evolve without changing compiler contracts, and compiler expansion can proceed against a stable resource model.

## 3. Current compiler contract

```gdscript
SheetCompiler.compile(sheet: EventSheetResource, output_path: String) -> Dictionary
```

Return dictionary keys:
- `success: bool`
- `errors: Array[String]`
- `warnings: Array[String]`
- `output: String`

Generated files include a stable header and use `\n` line endings.

## 4. Next planned phase: translation/compiler matrix

Next phase focus is specification-first compiler expansion from current sheet concepts to generated GDScript.

### 4.1 Translation matrix (planned deliverable)

Define and maintain a matrix mapping event-sheet constructs to emitted script patterns, including at minimum:

- run contexts/triggers → lifecycle hooks / signal wiring / guard structures
- condition chains (AND subset first) → boolean guard emission
- action rows → ordered action statement emission
- variable references/defaults → typed value conversion and fallback handling
- nested row groundwork → explicit "supported vs deferred" translation behavior

### 4.2 Expression conversion and mapping rules (planned deliverable)

Specify deterministic conversion rules for ACE params/expressions into GDScript-safe values:

- numeric/bool/string coercion rules
- identifier and variable reference resolution order
- operator mapping expectations (including compare/operator enums)
- quoting/escaping rules for emitted literals
- validation/error behavior for unsupported or malformed expressions

### 4.3 Practical outputs expected from this phase

- a documented translation matrix in specs
- compiler-side implementation coverage for the mapped subset
- fixture-style tests that lock expected output for mapped constructs
- explicit warnings/errors for constructs still outside the mapped subset

### 4.4 First implemented slice (current)

The first compiler-matrix slice now translates this deterministic subset:

- **Triggers/run contexts:** `OnReady`, `OnProcess`, `OnPhysicsProcess`, `OnSignal`
- **Conditions:** `Always`, `CompareVar`
- **Actions:** `SetVar`, `PrintLog`

Constructs outside this slice are not silently treated as supported. The compiler emits explicit warnings for unsupported triggers, conditions, and actions.

## 5. Explicitly out of scope for this phase

- drag/drop sorting/reordering UX
- full sub-event authoring UX (move/reparent/advanced nesting tools)
- complete round-trip importer fidelity

These remain planned tracks and should not be implied as complete by compiler-matrix work.

## 6. Directory layout (current)

`addons/eventforge/` contains:

- `editor/` active editor implementation
- `compiler/` code generation entry path plus expanding translation modules
- `resources/` event sheet/resource model
- `registration/` built-ins and descriptor lookup helpers
- `runtime/` runtime bridge autoload
- `importer/` importer groundwork
- `binding/` binding groundwork

## 7. ACE metadata normalization

ACE descriptors can be provided as `ACEDescriptor` resources or dictionary metadata.
Dictionary metadata accepts snake_case and Construct-style camelCase aliases (for example `list_name/listName`, `display_text/displayText`, `description/desc`, and param default/name aliases).

Normalized metadata is used consistently by picker display and ACE param initialization.
