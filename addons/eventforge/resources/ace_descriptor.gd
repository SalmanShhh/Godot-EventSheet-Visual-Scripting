# EventForge — ACEDescriptor resource
# Defines a registerable trigger, condition, action, or expression.
@tool
extends Resource
class_name ACEDescriptor

enum ACEType {
	TRIGGER,
	CONDITION,
	ACTION,
	EXPRESSION
}

@export var ace_type: ACEType = ACEType.ACTION
@export var provider_id: String = "Core"
@export var ace_id: String = ""
@export var display_name: String = ""
@export var list_name: String = ""
@export var listName: String = "" # Construct-style alias.
@export var description: String = ""
@export_multiline var display_text: String = ""
@export_multiline var displayText: String = "" # Construct-style alias.
@export var category: String = ""
@export var params: Array[ACEParam] = []
@export var signal_name: String = ""
@export var return_type: int = TYPE_NIL
@export var codegen_template: String = ""

## Returns the display label used in ACE pickers.
func get_list_name() -> String:
	if not list_name.is_empty():
		return list_name
	if not listName.is_empty():
		return listName
	if not display_name.is_empty():
		return display_name
	return ace_id

## Returns the template used for human-friendly summaries.
func get_display_text() -> String:
	if not display_text.is_empty():
		return display_text
	if not displayText.is_empty():
		return displayText
	return get_list_name()

## Returns params dictionary pre-populated from descriptor defaults.
func build_default_params() -> Dictionary:
	var output: Dictionary = {}
	for param: ACEParam in params:
		if param == null:
			continue
		var key: String = param.id
		if key.is_empty():
			key = param.name
		if key.is_empty():
			continue
		output[key] = param.get_initial_value()
	return output

## Formats display_text/list_name with values from params.
func format_display(params_dict: Dictionary) -> String:
	var template: String = get_display_text()
	if template.is_empty():
		return ace_id
	var output: String = template
	for i: int in range(params.size()):
		var param: ACEParam = params[i]
		if param == null:
			continue
		var key: String = param.id
		if key.is_empty():
			key = param.name
		if key.is_empty():
			continue
		var value: Variant = params_dict.get(key, param.get_initial_value())
		output = output.replace("{%d}" % i, str(value))
		output = output.replace("{%s}" % key, str(value))
	return output
