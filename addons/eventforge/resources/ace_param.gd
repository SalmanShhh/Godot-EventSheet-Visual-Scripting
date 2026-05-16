# EventForge — ACEParam resource
# Describes a typed parameter accepted by an ACE descriptor.
#
# Supported type_name values (GDScript-aligned):
#   "bool" / "boolean"        → checkbox / bool dropdown
#   "int" / "integer"         → integer SpinBox
#   "float" / "double"        → float SpinBox
#   "String" / "string"       → text field (default)
#   Any type with options[]   → enum dropdown
#   Any type with hint = "variable_reference"
#                             → variable dropdown populated from sheet variables
#   String params with hint = "expression"
#                             → text field with expression picker button
@tool
extends Resource
class_name ACEParam

@export var id: String = ""
@export var name: String = "" # Backwards-compatible alias for early Phase 1 code.
@export var display_name: String = ""
@export var description: String = ""
@export var desc: String = "" # Construct-style alias.
@export var type: int = TYPE_STRING
## Human-readable GDScript type name. Drives the UI control choice.
@export var type_name: String = "String"
@export var default_value: Variant = ""
@export var initial_value: Variant = null
@export var initialValue: Variant = null # Construct-style alias.
@export var options: Array[String] = []
@export var required: bool = false
## UI hint for richer control selection.
## Use "variable_reference" to show a dropdown of available sheet variables.
## Use "expression" to show an expression picker button beside text input.
@export var hint: String = ""

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
