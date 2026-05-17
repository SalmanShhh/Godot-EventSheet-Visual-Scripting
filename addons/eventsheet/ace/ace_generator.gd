@tool
class_name EventSheetACEGenerator
extends RefCounted

## Types considered primitive for editor exposure purposes.
const PRIMITIVE_TYPES := [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]

const COMMON_METHOD_IGNORE := {
    "_get_property_list": true,
    "_get": true,
    "_set": true,
    "_notification": true,
    "get_class": true,
    "get_method_list": true,
    "get_property_list": true,
    "get_script": true,
    "get_signal_list": true,
    "notification": true,
    "to_string": true
}

var _analyzer: EventSheetSemanticAnalyzer = EventSheetSemanticAnalyzer.new()

func generate_from_object(target: Object) -> Array[ACEDefinition]:
    var output: Array[ACEDefinition] = []
    if target == null:
        return output
    var script: Script = target.get_script() as Script
    var source_metadata: Dictionary = _analyzer.parse_source_metadata(script)
    var provider_id: String = _analyzer.get_provider_id(target, source_metadata)
    var signal_overrides: Dictionary = source_metadata.get("signals", {})
    var property_overrides: Dictionary = source_metadata.get("properties", {})
    var method_overrides: Dictionary = source_metadata.get("methods", {})

    for signal_info in target.get_signal_list():
        var signal_name: String = str(signal_info.get("name", ""))
        if signal_name.is_empty() or (script != null and not signal_overrides.has(signal_name)):
            continue
        var overrides: Dictionary = signal_overrides.get(signal_name, {})
        if bool(overrides.get("hidden", false)):
            continue
        output.append(_build_signal_definition(provider_id, signal_name, signal_info, overrides))

    for property_info in target.get_property_list():
        var property_name: String = str(property_info.get("name", ""))
        if property_name.is_empty() or (script != null and not property_overrides.has(property_name)):
            continue
        var property_overrides_entry: Dictionary = property_overrides.get(property_name, {})
        if bool(property_overrides_entry.get("hidden", false)):
            continue
        if not bool(property_overrides_entry.get("exported", false)):
            continue
        output.append_array(_build_property_definitions(provider_id, property_name, property_info, property_overrides_entry))

    for method_info in target.get_method_list():
        var method_name: String = str(method_info.get("name", ""))
        if method_name.is_empty() or method_name.begins_with("_") or COMMON_METHOD_IGNORE.has(method_name):
            continue
        if script != null and not method_overrides.has(method_name):
            continue
        var method_entry_overrides: Dictionary = method_overrides.get(method_name, {})
        if bool(method_entry_overrides.get("hidden", false)):
            continue
        output.append(_build_method_definition(provider_id, method_name, method_info, method_entry_overrides))
    return output

func _build_signal_definition(provider_id: String, signal_name: String, signal_info: Dictionary, overrides: Dictionary) -> ACEDefinition:
    var definition := ACEDefinition.new()
    definition.provider_id = provider_id
    definition.id = "signal:%s" % signal_name
    definition.display_name = _string_override(overrides, "name", _analyzer.build_trigger_display_name(signal_name))
    definition.category = _string_override(overrides, "category", "Signals")
    definition.ace_type = ACEDefinition.ACEType.TRIGGER
    definition.description = _string_override(overrides, "description", "Signal trigger generated from gameplay code.")
    definition.parameters = _build_parameter_definitions(signal_info.get("args", []), overrides)
    definition.return_type = TYPE_NIL
    definition.icon = _string_override(overrides, "icon", "signal")
    definition.metadata = {
        "semantic_source": "reflection",
        "source_kind": "signal",
        "source_name": signal_name,
        "display_template": definition.display_name
    }
    # Signals are triggers, not directly editor-exposed as inspector parameters.
    definition.editor_exposed = false
    return definition

func _build_property_definitions(provider_id: String, property_name: String, property_info: Dictionary, overrides: Dictionary) -> Array[ACEDefinition]:
    var output: Array[ACEDefinition] = []
    var property_type: int = int(property_info.get("type", TYPE_NIL))
    var display_name: String = _string_override(overrides, "name", _analyzer.build_property_display_name(property_name))
    var category: String = _string_override(overrides, "category", EventSheetCategoryInference.infer_category(property_name, ACEDefinition.ACEType.EXPRESSION, property_type))
    var description: String = _string_override(overrides, "description", "Gameplay property generated from an exported variable.")
    var icon_name: String = _string_override(overrides, "icon", "property")

    var expression_definition := ACEDefinition.new()
    expression_definition.provider_id = provider_id
    expression_definition.id = "property:%s" % property_name
    expression_definition.display_name = display_name
    expression_definition.category = category
    expression_definition.ace_type = ACEDefinition.ACEType.EXPRESSION
    expression_definition.description = description
    expression_definition.return_type = property_type
    expression_definition.icon = icon_name
    expression_definition.metadata = {
        "semantic_source": "reflection",
        "source_kind": "property",
        "source_name": property_name,
        "display_template": display_name
    }
    # Exported properties are editor-exposed: their value can be overridden in the inspector.
    expression_definition.editor_exposed = bool(overrides.get("editor_exposed", _property_is_exposable(property_type)))
    expression_definition.property_hint = _infer_property_hint(property_type, overrides)
    expression_definition.hint_string = _string_override(overrides, "hint_string", "")
    expression_definition.widget_hint = _string_override(overrides, "widget_hint", "")
    expression_definition.category_override = _string_override(overrides, "category_override", "")
    output.append(expression_definition)

    var set_definition := _build_property_action_definition(provider_id, property_name, display_name, category, "set", "Set %s" % display_name, TYPE_NIL)
    output.append(set_definition)
    if property_type in [TYPE_INT, TYPE_FLOAT]:
        output.append(_build_property_action_definition(provider_id, property_name, display_name, category, "add", "Add To %s" % display_name, TYPE_NIL, "amount"))
        output.append(_build_property_action_definition(provider_id, property_name, display_name, category, "subtract", "Subtract From %s" % display_name, TYPE_NIL, "amount"))
    return output

func _build_property_action_definition(provider_id: String, property_name: String, display_name: String, category: String, prefix: String, action_name: String, return_type: int, parameter_name: String = "value") -> ACEDefinition:
    var definition := ACEDefinition.new()
    definition.provider_id = provider_id
    definition.id = "%s:%s" % [prefix, property_name]
    definition.display_name = action_name
    definition.category = category
    definition.ace_type = ACEDefinition.ACEType.ACTION
    definition.description = "Generated property action for %s." % display_name
    definition.parameters = [
        {
            "id": parameter_name,
            "display_name": _analyzer.build_property_display_name(parameter_name),
            "type": TYPE_NIL,
            "default_value": "0"
        }
    ]
    definition.return_type = return_type
    definition.icon = "property_action"
    definition.metadata = {
        "semantic_source": "reflection",
        "source_kind": "property_action",
        "source_name": property_name,
        "display_template": "%s {%s}" % [action_name, parameter_name]
    }
    return definition

func _build_method_definition(provider_id: String, method_name: String, method_info: Dictionary, overrides: Dictionary) -> ACEDefinition:
    var parameter_definitions: Array = _build_parameter_definitions(method_info.get("args", []), overrides)
    var parameter_types: Array = []
    for parameter_definition in parameter_definitions:
        parameter_types.append(parameter_definition.get("type", TYPE_NIL))
    var return_info: Variant = method_info.get("return", {})
    var return_type: int = TYPE_NIL
    if return_info is Dictionary:
        return_type = int((return_info as Dictionary).get("type", TYPE_NIL))
    var ace_type: int = _resolve_method_ace_type(return_type, overrides)
    var display_name: String = _string_override(overrides, "name", _analyzer.build_method_display_name(method_name, ace_type))
    var category: String = _string_override(overrides, "category", EventSheetCategoryInference.infer_category(method_name, ace_type, return_type, parameter_types))
    var definition := ACEDefinition.new()
    definition.provider_id = provider_id
    definition.id = "method:%s" % method_name
    definition.display_name = display_name
    definition.category = category
    definition.ace_type = ace_type
    definition.description = _string_override(overrides, "description", "Gameplay capability generated from a script method.")
    definition.parameters = parameter_definitions
    definition.return_type = return_type
    definition.icon = _string_override(overrides, "icon", _icon_for_ace_type(ace_type))
    definition.metadata = {
        "semantic_source": "reflection",
        "source_kind": "method",
        "source_name": method_name,
        "display_template": _build_method_display_template(display_name, parameter_definitions)
    }
    # Methods with primitive params (non-signal, non-hidden) can be editor-exposed.
    definition.editor_exposed = bool(overrides.get("editor_exposed", _method_is_exposable(ace_type, return_type, parameter_definitions)))
    definition.property_hint = int(overrides.get("property_hint", PROPERTY_HINT_NONE))
    definition.hint_string = _string_override(overrides, "hint_string", "")
    definition.widget_hint = _string_override(overrides, "widget_hint", "")
    definition.category_override = _string_override(overrides, "category_override", "")
    return definition

func _resolve_method_ace_type(return_type: int, overrides: Dictionary) -> int:
    var forced_ace_type: int = int(overrides.get("forced_ace_type", -1))
    if forced_ace_type >= 0:
        return forced_ace_type
    if return_type == TYPE_BOOL:
        return ACEDefinition.ACEType.CONDITION
    if return_type == TYPE_NIL:
        return ACEDefinition.ACEType.ACTION
    return ACEDefinition.ACEType.EXPRESSION

func _build_parameter_definitions(raw_args: Variant, overrides: Dictionary = {}) -> Array:
    var output: Array = []
    if not (raw_args is Array):
        return output
    var param_overrides: Dictionary = overrides.get("params", {})
    for argument_info in raw_args:
        if not (argument_info is Dictionary):
            continue
        var argument_dict: Dictionary = argument_info
        var argument_name: String = str(argument_dict.get("name", ""))
        if argument_name.is_empty():
            continue
        var parameter_override: Dictionary = param_overrides.get(argument_name, {})
        var param_type: int = int(parameter_override.get("type", argument_dict.get("type", TYPE_NIL)))
        output.append({
            "id": argument_name,
            "display_name": str(parameter_override.get("display_name", _analyzer.build_property_display_name(argument_name))),
            "type": param_type,
            "default_value": parameter_override.get("default_value", _default_value_for_type(param_type)),
            "property_hint": int(parameter_override.get("property_hint", PROPERTY_HINT_NONE)),
            "hint_string": str(parameter_override.get("hint_string", "")),
            "widget_hint": str(parameter_override.get("widget_hint", ""))
        })
    return output

func _build_method_display_template(display_name: String, parameters: Array) -> String:
    if parameters.is_empty():
        return display_name
    var parts: Array[String] = [display_name]
    for parameter_definition in parameters:
        parts.append("{%s}" % str(parameter_definition.get("id", "value")))
    return " ".join(parts)

func _default_value_for_type(value_type: int) -> String:
    match value_type:
        TYPE_INT:
            return "0"
        TYPE_FLOAT:
            return "0.0"
        TYPE_BOOL:
            return "false"
        _:
            return ""

func _icon_for_ace_type(ace_type: int) -> String:
    match ace_type:
        ACEDefinition.ACEType.CONDITION:
            return "condition"
        ACEDefinition.ACEType.EXPRESSION:
            return "expression"
        ACEDefinition.ACEType.TRIGGER:
            return "trigger"
        _:
            return "action"

## Returns true when a method ACE is eligible for editor parameter exposure.
## Conditions and actions with all-primitive parameters are exposable.
## Expressions are only exposable when their return type is a primitive.
## Triggers are never editor-exposed.
func _method_is_exposable(ace_type: int, return_type: int, params: Array) -> bool:
    if ace_type == ACEDefinition.ACEType.TRIGGER:
        return false
    if ace_type == ACEDefinition.ACEType.EXPRESSION:
        if return_type not in PRIMITIVE_TYPES:
            return false
    for param in params:
        if not (param is Dictionary):
            return false
        var ptype: int = int((param as Dictionary).get("type", TYPE_NIL))
        if ptype not in PRIMITIVE_TYPES:
            return false
    return true

func _property_is_exposable(property_type: int) -> bool:
    return property_type in PRIMITIVE_TYPES

## Infer a PropertyHint for the given Variant type.
## Callers can pass a "property_hint" override in the overrides dict
## (e.g. PROPERTY_HINT_RANGE for a bounded integer).
func _infer_property_hint(value_type: int, overrides: Dictionary) -> int:
    var hint_override: int = int(overrides.get("property_hint", -1))
    if hint_override >= 0:
        return hint_override
    # Default hints by type; extend here as richer widgets are added.
    match value_type:
        TYPE_INT, TYPE_FLOAT:
            return PROPERTY_HINT_NONE
        TYPE_STRING:
            return PROPERTY_HINT_NONE
        _:
            return PROPERTY_HINT_NONE

func _string_override(overrides: Dictionary, key: String, default_value: String) -> String:
    var resolved: String = str(overrides.get(key, ""))
    return resolved if not resolved.is_empty() else default_value
