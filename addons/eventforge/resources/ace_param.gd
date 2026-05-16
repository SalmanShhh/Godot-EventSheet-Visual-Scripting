# EventForge — ACEParam resource
# Describes a typed parameter accepted by an ACE descriptor.
@tool
extends Resource
class_name ACEParam

@export var id: String = ""
@export var name: String = "" # Backwards-compatible alias for early Phase 1 code.
@export var display_name: String = ""
@export var description: String = ""
@export var desc: String = "" # Construct-style alias.
@export var type: int = TYPE_STRING
@export var type_name: String = "String" # Human-readable convenience field.
@export var default_value: Variant = ""
@export var initial_value: Variant = null
@export var initialValue: Variant = null # Construct-style alias.
@export var options: Array[String] = []
@export var required: bool = false

## Returns the best available display name for picker/inspector UI.
func get_param_name() -> String:
	if not display_name.is_empty():
		return display_name
	if not name.is_empty():
		return name
	return id

## Returns the best available parameter description.
func get_param_description() -> String:
	if not description.is_empty():
		return description
	return desc

## Returns the best available default/initial value.
func get_initial_value() -> Variant:
	if initial_value != null:
		return initial_value
	if initialValue != null:
		return initialValue
	return default_value
