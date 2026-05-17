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
        "node_type": descriptor.node_type
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
        output.append({
            "id": key,
            "display_name": param.display_name if not param.display_name.is_empty() else key,
            "type": param.type_name,
            "default_value": param.get_initial_value(),
            "hint": param.hint,
            "options": param.options.duplicate()
        })
    return output
