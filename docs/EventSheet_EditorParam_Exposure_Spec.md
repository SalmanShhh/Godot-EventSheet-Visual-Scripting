# Event Sheet System — Editor Parameter Exposure Expansion Spec

> **Historical record (early era).** This document predates the overhaul arcs and the
> v0.5/v0.6 feature waves — treat its claims as a design-time snapshot, not current
> behavior. Current truth: `CHANGELOG.md`, `README.md`, and the maintained specs in
> `docs/` (EDITOR-UI-SPEC, GDSCRIPT-PAIRING-SPEC, the per-feature specs).


**Expanding:** Integrated EventSheet + AutoACE System for Godot 4  
**Expansion Module:** `Public Editor Parameter Exposure`  
**Scope:** Inspector integration, editor property widgets, project settings, runtime linkage, serialization

---

## Objective

Extend the Event Sheet + AutoACE system so that:

1. Event Sheet nodes and resources surface meaningful configuration **in the Godot Inspector**
2. ACE parameters defined in GDScript are **visible and editable** from the editor without opening the Event Sheet
3. Gameplay designers can override ACE-generated defaults per-scene, per-node, and per-resource
4. All editor-exposed values **serialize correctly**, round-trip through scenes/resources, and survive hot-reload

This expansion does NOT:
- Replace the Event Sheet as the primary authoring surface
- Expose raw engine internals through the Inspector
- Create form-based gameplay authoring (that remains the Event Sheet's job)

This DOES:
- Allow designers to tweak parameters directly on a node in the Inspector
- Allow the ACE system to read editor-set values as parameter defaults
- Allow event data to be stored and versioned as Godot Resources

---

## Why This Is Non-Trivial

Godot's Inspector is property-list-driven. To appear there, a value must be declared through one of three mechanisms:

| Mechanism | When to use |
|---|---|
| `@export` annotation | Simple per-instance values on `@tool` nodes |
| `_get_property_list()` override | Dynamic, conditional, or categorized properties |
| `EditorInspectorPlugin` | Custom widget rendering inside the Inspector panel |

The AutoACE system generates definitions at runtime from reflection. Those definitions must be mapped **back** into Godot's property model so the Inspector can present them as real properties — not phantom data.

---

## Architecture Overview

```
ACE Registry
    ↓
ACE → EditorProperty Bridge
    ↓ ↙─────────────────────────────────────┐
EditorParamStore (Resource)     EventSheetNode (_tool)
    ↓                                    ↓
_get_property_list()            @export var event_sheet
    ↓                                    ↓
Inspector Panel            Inspector shows sheet + param overrides
    ↓
Serialized .tres / scene
```

Three concrete systems implement this:

1. **`EditorParamStore`** — a `Resource` that holds designer-set overrides for ACE parameters
2. **`EventSheetNode`** — a `@tool` node that exposes `_get_property_list()` to surface ACE categories in the Inspector
3. **`EventSheetInspectorPlugin`** — an `EditorInspectorPlugin` that renders custom property widgets for complex ACE types

---

## File Structure Additions

```
addons/eventsheet/
│
├── editor/
│   ├── inspector/
│   │   ├── event_sheet_inspector_plugin.gd   ← registers custom property widgets
│   │   ├── ace_param_property.gd             ← custom EditorProperty for ACE params
│   │   ├── event_sheet_node.gd               ← @tool node; exposes property list
│   │   └── param_category_header.gd          ← category separator widget
│   │
│   └── [existing editor files]
│
├── resources/
│   ├── editor_param_store.gd                 ← Resource; serializes param overrides
│   ├── event_sheet_resource.gd               ← Resource; serializes event sheet data
│   └── ace_param_override.gd                 ← per-param override entry
│
├── ace/
│   ├── [existing ace files]
│   └── param_default_resolver.gd             ← resolves override vs ACE default
│
└── project_settings/
    └── eventsheet_project_settings.gd        ← registers ProjectSettings entries
```

---

## System 1 — `EventSheetNode` (@tool Node)

This is the node designers place in their scene to attach an Event Sheet. It must appear fully configured in the Inspector without designers ever opening GDScript.

### Declaration

```gdscript
@tool
extends Node
class_name EventSheetNode

## The event sheet resource to use for this node.
@export var event_sheet: EventSheetResource

## Whether this node's ACE parameters are shown in the Inspector.
@export var expose_params_in_inspector: bool = true

## Per-param overrides set in the Inspector.
var _param_store: EditorParamStore
```

### Dynamic Property List

The key is `_get_property_list()`. This is called by Godot's Inspector system whenever it needs to know what properties an object exposes. The Event Sheet node uses this to inject ACE parameter categories dynamically, based on whatever `event_sheet` resource is assigned.

```gdscript
func _get_property_list() -> Array[Dictionary]:
    var props: Array[Dictionary] = []

    if not expose_params_in_inspector:
        return props

    if not event_sheet:
        return props

    var registry := ACERegistry.get_singleton()
    var categories := registry.get_categories_for_sheet(event_sheet)

    for category in categories:
        # Category group header
        props.append({
            "name": category.name,
            "type": TYPE_NIL,
            "usage": PROPERTY_USAGE_GROUP,
            "hint_string": category.name + "/"
        })

        for param in category.exposed_params:
            props.append({
                "name": category.name + "/" + param.id,
                "type": param.godot_type,
                "usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR,
                "hint": param.property_hint,
                "hint_string": param.hint_string
            })

    return props
```

### `_get` and `_set` Overrides

To make these dynamic properties round-trip through serialization, `_get` and `_set` must be implemented:

```gdscript
func _get(property: StringName) -> Variant:
    if _param_store:
        return _param_store.get_param(property)
    return null

func _set(property: StringName, value: Variant) -> bool:
    if not property.contains("/"):
        return false
    if not _param_store:
        _param_store = EditorParamStore.new()
    _param_store.set_param(property, value)
    notify_property_list_changed()
    return true
```

`notify_property_list_changed()` must be called after `_set` so the Inspector redraws if a change affects which properties are visible (e.g. showing/hiding sub-params based on a toggle).

---

## System 2 — `EditorParamStore` (Resource)

This `Resource` is what gets serialized into the scene file. It holds a dictionary of param overrides. It is NOT the ACE definition — it is only the designer's overrides.

```gdscript
class_name EditorParamStore
extends Resource

## Flat dict of property path → value.
## e.g. { "Combat/base_damage": 25, "Movement/max_speed": 400.0 }
@export var overrides: Dictionary = {}

func get_param(path: StringName) -> Variant:
    return overrides.get(path, null)

func set_param(path: StringName, value: Variant) -> void:
    overrides[path] = value

func clear_param(path: StringName) -> void:
    overrides.erase(path)

func has_override(path: StringName) -> bool:
    return overrides.has(path)
```

### Why a Resource and Not a Dictionary Directly on the Node

Storing overrides in a `Resource` means:
- It can be **shared** across multiple nodes (a shared param profile)
- It can be saved as a `.tres` file for version control
- It **serializes cleanly** as a sub-resource in `.tscn` files
- Hot-reload doesn't destroy it (Godot preserves resource identity)

---

## System 3 — `ParamDefaultResolver`

The ACE runtime and Event Sheet must know which value to use for a parameter at execution time. The resolver applies this priority:

```
Priority 1: Value set in the Event Sheet row (hardcoded in the event)
Priority 2: Per-node override from EditorParamStore
Priority 3: ACE definition's declared default
Priority 4: Godot type zero-value fallback
```

```gdscript
class_name ParamDefaultResolver
extends RefCounted

static func resolve(
    param_id: StringName,
    ace_definition: ACEDefinition,
    param_store: EditorParamStore,
    row_override: Variant = null
) -> Variant:

    # Row-level override wins first
    if row_override != null:
        return row_override

    # Inspector/editor override second
    if param_store and param_store.has_override(param_id):
        return param_store.get_param(param_id)

    # ACE default third
    for param in ace_definition.parameters:
        if param.id == param_id and param.has("default"):
            return param["default"]

    # Type zero-value fallback
    return _zero_for_type(ace_definition.return_type)

static func _zero_for_type(t: Variant.Type) -> Variant:
    match t:
        TYPE_INT: return 0
        TYPE_FLOAT: return 0.0
        TYPE_STRING: return ""
        TYPE_BOOL: return false
        TYPE_VECTOR2: return Vector2.ZERO
        _: return null
```

---

## System 4 — `EventSheetInspectorPlugin`

For ACE parameters with complex types (Object references, enum dropdowns, curve editors, color pickers), the default Inspector widgets are wrong. The `EventSheetInspectorPlugin` intercepts property drawing for Event Sheet nodes and substitutes custom `EditorProperty` widgets.

```gdscript
@tool
class_name EventSheetInspectorPlugin
extends EditorInspectorPlugin

func _can_handle(object: Object) -> bool:
    return object is EventSheetNode

func _parse_property(
    object: Object,
    type: Variant.Type,
    name: String,
    hint_type: PropertyHint,
    hint_string: String,
    usage_flags: int,
    wide: bool
) -> bool:

    if not name.contains("/"):
        return false  # let default Inspector handle top-level props

    var parts := name.split("/")
    var category := parts[0]
    var param_id := parts[1]

    var ace_param := _get_ace_param(object, category, param_id)
    if not ace_param:
        return false

    match ace_param.widget_hint:
        "object_picker":
            add_property_editor(name, AceObjectPickerProperty.new(ace_param))
            return true
        "enum_dropdown":
            add_property_editor(name, AceEnumDropdownProperty.new(ace_param))
            return true
        "expression_field":
            add_property_editor(name, AceExpressionFieldProperty.new(ace_param))
            return true
        _:
            return false  # use default widget
```

The plugin must be registered in the main `EditorPlugin`:

```gdscript
# in event_sheet_editor_plugin.gd

var _inspector_plugin: EventSheetInspectorPlugin

func _enter_tree() -> void:
    _inspector_plugin = EventSheetInspectorPlugin.new()
    add_inspector_plugin(_inspector_plugin)

func _exit_tree() -> void:
    remove_inspector_plugin(_inspector_plugin)
```

---

## System 5 — ACE Parameter Exposure Metadata

For a parameter to be surfaced in the Inspector, the `ACEDefinition` must declare which of its parameters are "editor-exposable". Add the following fields to the parameter definition:

```gdscript
# Inside ACEDefinition.parameters Array entries:
{
    "id": "base_damage",
    "name": "Base Damage",
    "type": TYPE_INT,
    "default": 10,
    "description": "The base damage dealt before modifiers.",

    # New fields for editor exposure:
    "editor_exposed": true,           # show in Inspector
    "property_hint": PROPERTY_HINT_RANGE,
    "hint_string": "0,9999,1",
    "widget_hint": "default",         # or "object_picker", "enum_dropdown", etc.
    "category_override": "Combat",    # force a specific Inspector group
}
```

### Auto-Inference of Editor Exposure

The `ACEGenerator` should auto-infer `editor_exposed` using these rules:

| Rule | Inferred |
|---|---|
| `@export` variable | `editor_exposed: true` |
| Method parameter of primitive type (int, float, bool, String) | `editor_exposed: true` |
| Method parameter of Object type | `editor_exposed: true`, `widget_hint: "object_picker"` |
| Method parameter with `@ace_hidden` annotation | `editor_exposed: false` |
| Return-only expression (no params) | `editor_exposed: false` |
| Signal (trigger) | `editor_exposed: false` |

---

## System 6 — Annotation Extensions for Editor Exposure

Add the following annotations to the supported annotation set:

```gdscript
## @ace_export              → force this param/var into the Inspector
## @ace_export_hidden       → suppress from Inspector even if auto-inferred
## @ace_range(0, 100, 1)   → PROPERTY_HINT_RANGE shorthand
## @ace_enum(A, B, C)      → PROPERTY_HINT_ENUM shorthand
## @ace_group("Combat")    → places param under a named Inspector group
```

Example usage:

```gdscript
## @ace_export
## @ace_range(0, 500, 5)
## @ace_group("Combat")
@export var base_damage := 10

## @ace_export_hidden
var _internal_cooldown_timer := 0.0

## @ace_enum(Slash, Pierce, Blunt)
## @ace_export
@export var damage_type := 0
```

Docstring equivalents (for users who avoid custom annotations):

```gdscript
## @ace_export true
## @ace_range 0 500 5
## @ace_group Combat
@export var base_damage := 10
```

---

## System 7 — Project Settings Integration

Global configuration for the Event Sheet plugin should live in ProjectSettings, not in any scene or node. This makes it version-controllable and accessible from both editor and runtime.

```gdscript
class_name EventSheetProjectSettings
extends RefCounted

const PREFIX := "eventsheet/"

const SETTINGS := {
    "expose_all_exports_by_default": {
        "default": true,
        "type": TYPE_BOOL,
        "hint": PROPERTY_HINT_NONE,
        "description": "Auto-expose @export vars from gameplay scripts into the Inspector."
    },
    "inspector_category_prefix": {
        "default": "ACE/",
        "type": TYPE_STRING,
        "hint": PROPERTY_HINT_NONE,
        "description": "Prefix used for ACE parameter groups in the Inspector."
    },
    "max_inspector_params_per_category": {
        "default": 20,
        "type": TYPE_INT,
        "hint": PROPERTY_HINT_RANGE,
        "hint_string": "1,100,1",
        "description": "Max params shown per Inspector category before collapsing."
    },
    "show_ace_descriptions_as_tooltips": {
        "default": true,
        "type": TYPE_BOOL,
        "hint": PROPERTY_HINT_NONE,
        "description": "Show ACE parameter descriptions as Inspector tooltips."
    },
}

static func register() -> void:
    for key in SETTINGS:
        var path := PREFIX + key
        var entry: Dictionary = SETTINGS[key]
        if not ProjectSettings.has_setting(path):
            ProjectSettings.set_setting(path, entry["default"])
        ProjectSettings.set_initial_value(path, entry["default"])
        ProjectSettings.add_property_info({
            "name": path,
            "type": entry["type"],
            "hint": entry.get("hint", PROPERTY_HINT_NONE),
            "hint_string": entry.get("hint_string", ""),
        })

static func get(key: String) -> Variant:
    return ProjectSettings.get_setting(PREFIX + key)
```

Register in `_enter_tree()` of the main EditorPlugin.

---

## System 8 — `EventSheetResource` Serialization

Event sheet data — rows, conditions, actions, parameter values — must be storable as `.tres` resources so they are:
- tracked in version control
- shareable across scenes
- loadable at runtime without the editor

```gdscript
class_name EventSheetResource
extends Resource

## Human-readable name shown in the Event Sheet tab.
@export var sheet_name: String = "Untitled Sheet"

## Ordered list of event rows.
@export var rows: Array[EventRowResource] = []

## Param overrides that apply to ALL nodes using this sheet.
@export var shared_param_store: EditorParamStore


class_name EventRowResource
extends Resource

enum RowKind { EVENT, SUB_EVENT, COMMENT, GROUP }

@export var kind: RowKind = RowKind.EVENT
@export var enabled: bool = true
@export var folded: bool = false
@export var indent_level: int = 0

## Conditions on this row.
@export var conditions: Array[ACECallResource] = []

## Actions on this row.
@export var actions: Array[ACECallResource] = []


class_name ACECallResource
extends Resource

## ID of the ACE definition this call targets.
@export var ace_id: String = ""

## Object reference or NodePath to the target object.
@export var target: NodePath = NodePath("")

## Parameter values, keyed by param id.
@export var param_values: Dictionary = {}
```

### Serialization Rules

- All `@export` fields serialize automatically into `.tres`
- `NodePath` is used instead of direct node references to survive scene reloads
- `param_values` stores only overridden values — the resolver fills unset params from ACE defaults
- `EventSheetResource` can be embedded in `.tscn` or saved as a standalone `.tres`

---

## System 9 — Hot Reload Integration

When a gameplay script is modified, the ACE registry refreshes. This must propagate to:

1. The `EventSheetNode`'s property list (call `notify_property_list_changed()`)
2. The Inspector panel (it re-queries `_get_property_list()` automatically after step 1)
3. The `EventSheetResource` rows (validate that all `ace_id` references still exist)
4. Any open Event Sheet viewport (trigger a full re-render)

```gdscript
# In ace_registry.gd
signal aces_refreshed

func _on_script_changed(script: GDScript) -> void:
    _regenerate_for_script(script)
    aces_refreshed.emit()


# In event_sheet_node.gd
func _ready() -> void:
    ACERegistry.get_singleton().aces_refreshed.connect(_on_aces_refreshed)

func _on_aces_refreshed() -> void:
    notify_property_list_changed()
```

---

## System 10 — Undo/Redo Support

All Inspector edits on `EventSheetNode` properties must be undoable. Since the node uses `_set()` rather than direct `@export` writes, the EditorPlugin must register undo actions manually.

```gdscript
# In event_sheet_inspector_plugin.gd or the EditorProperty subclasses:

func _commit_value(node: EventSheetNode, property: StringName, new_value: Variant) -> void:
    var undo_redo := EditorInterface.get_editor_undo_redo()
    var old_value := node._get(property)

    undo_redo.create_action("Set ACE Param: " + property)
    undo_redo.add_do_method(node, "_set", property, new_value)
    undo_redo.add_undo_method(node, "_set", property, old_value)
    undo_redo.add_do_method(node, "notify_property_list_changed")
    undo_redo.add_undo_method(node, "notify_property_list_changed")
    undo_redo.commit_action()
```

This is mandatory. Editor plugins that write to object state without undo registration are a known source of data loss.

---

## Inspector UX Layout

When a designer selects an `EventSheetNode` in the scene tree, they should see:

```
EventSheetNode
─────────────────────────────────
event_sheet          [EventSheetResource ▼]
expose_params_in_inspector  [✓]

─── Combat ───────────────────────
Combat/base_damage          25
Combat/damage_type          [Slash ▼]
Combat/attack_range         150.0

─── Movement ─────────────────────
Movement/max_speed          400.0
Movement/acceleration       800.0

─── Script ───────────────────────
[standard Node script field]
```

Category group headers come from ACE `category` fields. Hovering any param shows the ACE `description` as a tooltip. Params set to their ACE default are shown in a dimmed color to indicate "no override active."

---

## Critical Rules

**NEVER** use `@export` for ACE-generated params directly on the `EventSheetNode`. `@export` is static — it cannot react to the assigned `event_sheet` resource changing. Always use `_get_property_list()` for dynamic ACE-driven properties.

**ALWAYS** call `notify_property_list_changed()` after:
- `event_sheet` resource is set or changed
- ACE registry refreshes
- Any param is set that might affect visibility of other params

**NEVER** cache `NodePath`-resolved node references in `constructor()` or `_ready()`. Resolve them fresh inside action/condition execution. Cached refs go stale after layout changes.

**ALWAYS** register undo actions for any Inspector edit that modifies `EditorParamStore` state.

**NEVER** expose raw engine class names (`Node2D`, `CharacterBody2D`, `CanvasItem`) as Inspector categories. All grouping must use semantic gameplay vocabulary from the ACE category system.

---

## Integration Checklist

- [ ] `EventSheetNode` is `@tool` and implements `_get_property_list`, `_get`, `_set`
- [ ] `EditorParamStore` is a `Resource` with `@export var overrides: Dictionary`
- [ ] `EventSheetInspectorPlugin` is registered/unregistered in the EditorPlugin lifecycle
- [ ] `ParamDefaultResolver` priority chain: row > inspector override > ACE default > type zero
- [ ] All `ACEDefinition` parameter entries carry `editor_exposed`, `property_hint`, `hint_string`
- [ ] `ACEGenerator` auto-infers `editor_exposed` from `@export` and primitive-type params
- [ ] Project Settings entries registered via `EventSheetProjectSettings.register()`
- [ ] `EventSheetResource` and `EventRowResource` and `ACECallResource` all extend `Resource` with `@export` fields
- [ ] Hot reload: `aces_refreshed` signal propagates to `notify_property_list_changed()`
- [ ] All Inspector edits go through `EditorUndoRedoManager` — no silent state mutations
- [ ] Inspector category names come from ACE categories (semantic) not Godot class names (raw)
- [ ] Tooltips show ACE `description` fields for every exposed parameter
- [ ] Params at their ACE default render visually distinct from overridden params
