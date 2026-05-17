@tool
class_name EventSheetACEGenerator
extends RefCounted

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

    for signal_info: Dictionary in target.get_signal_list():
        var signal_name: String = str(signal_info.get("name", ""))
        if signal_name.is_empty() or (script != null and not signal_overrides.has(signal_name)):
            continue
        var overrides: Dictionary = signal_overrides.get(signal_name, {})
        if bool(overrides.get("hidden", false)):
            continue
        output.append(_build_signal_definition(provider_id, signal_name, signal_info, overrides))

    for property_info: Dictionary in target.get_property_list():
        var property_name: String = str(property_info.get("name", ""))
        if property_name.is_empty() or (script != null and not property_overrides.has(property_name)):
            continue
        var property_overrides_entry: Dictionary = property_overrides.get(property_name, {})
        if bool(property_overrides_entry.get("hidden", false)):
            continue
        if not bool(property_overrides_entry.get("exported", false)):
            continue
        output.append_array(_build_property_definitions(provider_id, property_name, property_info, property_overrides_entry))

    for method_info: Dictionary in target.get_method_list():
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
    definition.parameters = _build_parameter_definitions(signal_info.get("args", []))
    definition.return_type = TYPE_NIL
    definition.icon = _string_override(overrides, "icon", "signal")
    definition.metadata = {
        "semantic_source": "reflection",
        "source_kind": "signal",
        "source_name": signal_name,
        "display_template": definition.display_name
    }
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
    var parameter_definitions: Array = _build_parameter_definitions(method_info.get("args", []))
    var parameter_types: Array = []
    for parameter_definition: Dictionary in parameter_definitions:
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

func _build_parameter_definitions(raw_args: Variant) -> Array:
    var output: Array = []
    if not (raw_args is Array):
        return output
    for argument_info: Variant in raw_args:
        if not (argument_info is Dictionary):
            continue
        var argument_dict: Dictionary = argument_info
        var argument_name: String = str(argument_dict.get("name", ""))
        if argument_name.is_empty():
            continue
        output.append({
            "id": argument_name,
            "display_name": _analyzer.build_property_display_name(argument_name),
            "type": int(argument_dict.get("type", TYPE_NIL)),
            "default_value": _default_value_for_type(int(argument_dict.get("type", TYPE_NIL)))
        })
    return output

func _build_method_display_template(display_name: String, parameters: Array) -> String:
    if parameters.is_empty():
        return display_name
    var parts: Array[String] = [display_name]
    for parameter_definition: Dictionary in parameters:
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

func _string_override(overrides: Dictionary, key: String, default_value: String) -> String:
    var resolved: String = str(overrides.get(key, ""))
    return resolved if not resolved.is_empty() else default_value
