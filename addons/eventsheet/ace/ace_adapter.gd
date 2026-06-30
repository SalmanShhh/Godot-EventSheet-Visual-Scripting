@tool
class_name EventSheetACEAdapter
extends RefCounted

static func from_eventforge_descriptor(descriptor: ACEDescriptor) -> ACEDefinition:
    var definition := ACEDefinition.new()
    definition.provider_id = descriptor.provider_id
    definition.id = descriptor.ace_id
    definition.display_name = descriptor.get_list_name()
    definition.category = descriptor.category if not descriptor.category.is_empty() else EventSheetCategoryInference.infer_category(descriptor.get_list_name(), _map_ace_type(descriptor.ace_type), descriptor.return_type)
    definition.ace_type = _map_ace_type(descriptor.ace_type)
    definition.description = descriptor.description
    definition.return_type = descriptor.return_type
    definition.icon = "legacy"
    definition.parameters = _map_params(descriptor.params)
    definition.metadata = {
        "semantic_source": "eventforge",
        "source_kind": "legacy_descriptor",
        "source_name": descriptor.ace_id,
        "display_template": descriptor.get_display_text(),
        "codegen_template": descriptor.codegen_template,
        "member_template": descriptor.member_template,
        "codegen_prelude": descriptor.codegen_prelude,
        "codegen_on_true": descriptor.codegen_on_true,
        "node_type": descriptor.node_type,
        # Deprecation flows through metadata so the picker can hide it + the hover can flag it, without
        # adding typed fields to ACEDefinition. A blank note means "not deprecated".
        "deprecated": descriptor.is_deprecated,
        "deprecation_note": descriptor.deprecation_note(),
        "replacement_ace_id": descriptor.replacement_ace_id
    }
    return definition

static func _map_ace_type(ace_type: int) -> int:
    match ace_type:
        ACEDescriptor.ACEType.CONDITION:
            return ACEDefinition.ACEType.CONDITION
        ACEDescriptor.ACEType.EXPRESSION:
            return ACEDefinition.ACEType.EXPRESSION
        ACEDescriptor.ACEType.TRIGGER:
            return ACEDefinition.ACEType.TRIGGER
        _:
            return ACEDefinition.ACEType.ACTION

static func _map_params(params: Array[ACEParam]) -> Array:
    var output: Array = []
    for param in params:
        if param == null:
            continue
        var key: String = param.id if not param.id.is_empty() else param.name
        # Options are normalized to {key, label}: a plain string is key == label; a {"key"/"value", "label"}
        # dict keeps a friendly label distinct from the inserted value (e.g. "Warning" → `push_warning`).
        var normalized_options: Array = []
        for option in param.options:
            if option is Dictionary:
                var option_dict: Dictionary = option as Dictionary
                var option_key: String = str(option_dict.get("key", ""))
                if option_key.is_empty():
                    option_key = str(option_dict.get("value", ""))
                if option_key.is_empty():
                    option_key = str(option_dict.get("label", ""))
                if option_key.is_empty():
                    continue
                normalized_options.append({"key": option_key, "label": str(option_dict.get("label", option_key))})
            else:
                var option_text: String = str(option)
                if option_text.is_empty():
                    continue
                normalized_options.append({"key": option_text, "label": option_text})
        var autocomplete_values: Array = []
        for suggestion in param.autocomplete:
            var suggestion_text: String = str(suggestion)
            if not suggestion_text.is_empty():
                autocomplete_values.append(suggestion_text)
        output.append({
            "id": key,
            "display_name": param.display_name if not param.display_name.is_empty() else key,
            "description": param.get_param_description(),
            "type": param.type,
            "type_name": param.type_name,
            "default_value": param.get_initial_value(),
            "hint": param.hint,
            "options": normalized_options,
            "autocomplete": autocomplete_values
        })
    return output
