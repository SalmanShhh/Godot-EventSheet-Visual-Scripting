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

# ── Editor parameter exposure ────────────────────────────────────────────────

## When true, this ACE's parameters can be surfaced in the Godot inspector.
## Inferred automatically by the generator for exported properties and
## primitive-typed methods.  Signals are not editor-exposed by default.
var editor_exposed: bool = false

## Optional PropertyHint constant (e.g. PROPERTY_HINT_RANGE) applied when the
## parameter is rendered in a custom inspector widget.
var property_hint: int = PROPERTY_HINT_NONE

## Companion string for property_hint (e.g. "0,100,1" for a range hint).
var hint_string: String = ""

## Optional widget hint tag for richer inspector rendering
## (e.g. "color", "file", "node_path").
var widget_hint: String = ""

## Override the category shown in the inspector panel for this ACE.
## When empty the regular category field is used.
var category_override: String = ""

func get_identifier() -> String:
    return "%s::%s" % [provider_id, id]

func get_search_text() -> String:
    return "%s %s %s %s" % [display_name, category, description, str(metadata.get("source_name", ""))]

## Returns the category to display in the inspector (respects category_override).
func get_inspector_category() -> String:
    return category_override if not category_override.is_empty() else category

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
