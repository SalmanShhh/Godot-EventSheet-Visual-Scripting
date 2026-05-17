@tool
class_name ACEDefinition
extends Resource

enum ACEType {
    CONDITION,
    ACTION,
    EXPRESSION,
    TRIGGER
}

var provider_id: String = ""
var id: String = ""
var display_name: String = ""
var category: String = ""
var ace_type: int = ACEType.ACTION
var description: String = ""
var parameters: Array = []
var return_type: Variant.Type = TYPE_NIL
var icon: String = ""
var metadata := {}

func get_identifier() -> String:
    return "%s::%s" % [provider_id, id]

func get_search_text() -> String:
    return "%s %s %s %s" % [display_name, category, description, str(metadata.get("source_name", ""))]

func format_display(params_dict: Dictionary = {}) -> String:
    var template: String = str(metadata.get("display_template", display_name))
    if template.is_empty():
        return display_name
    var output: String = template
    for index: int in range(parameters.size()):
        var parameter: Variant = parameters[index]
        if not (parameter is Dictionary):
            continue
        var parameter_dict: Dictionary = parameter
        var key: String = str(parameter_dict.get("id", ""))
        if key.is_empty():
            continue
        var fallback: Variant = parameter_dict.get("default_value", parameter_dict.get("default", ""))
        var value: Variant = params_dict.get(key, fallback)
        output = output.replace("{%d}" % index, str(value))
        output = output.replace("{%s}" % key, str(value))
    return output
