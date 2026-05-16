# EventForge Specification (Consolidated)

## 1. Scope

EventForge provides Construct-style event sheet authoring for Godot and compiles sheets to GDScript.

## 2. Phase 1 Deliverables

- Plugin scaffold at `addons/eventforge/`
- Runtime bridge autoload
- Full resource/data model
- ACE registration and minimum Core built-ins
- Functional compiler subset:
  - triggers: OnReady, OnProcess, OnPhysicsProcess, OnBodyEntered, OnSignal
  - AND-only condition emission
  - template-based action emission
  - await action support
  - deterministic output with sorted dictionary keys

## 3. Deferred from Phase 1

- Visual editor UX implementation
- Else/Elif logic execution
- Sub-events
- Loops
- Event groups/functions runtime behavior
- Full importer and binding pipeline

## 4. Directory layout

`addons/eventforge/` contains:

- `editor/` UI stubs
- `compiler/` functional Phase 1 codegen entry path and stubs for later modules
- `importer/` stubs
- `binding/` stubs
- `resources/` resource classes
- `runtime/` bridge autoload
- `registration/` built-ins and lookup helpers

## 5. Compiler contract

```gdscript
SheetCompiler.compile(sheet: EventSheetResource, output_path: String) -> Dictionary
```

Return dictionary keys:

- `success: bool`
- `errors: Array[String]`
- `warnings: Array[String]`
- `output: String`

Generated files include a stable header and are emitted with `\n` line endings.

## 6. ACE metadata normalization

ACE descriptors can be provided either as `ACEDescriptor` resources or dictionary metadata.
Dictionary metadata supports both snake_case and Construct-style camelCase keys.

Supported descriptor aliases:

- `list_name` / `listName`
- `display_text` / `displayText`
- `description` / `desc`
- `params` entries with:
  - `id`
  - `name` / `display_name` / `displayName`
  - `description` / `desc`
  - `type`
  - `default_value` / `defaultValue` / `initial_value` / `initialValue`

Normalized metadata is used by pickers and event/action initialization defaults.
