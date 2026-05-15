# EventForge — ACEParam resource
# Describes a typed parameter accepted by an ACE descriptor.
@tool
extends Resource
class_name ACEParam

@export var id: String = ""
@export var name: String = "" # Backwards-compatible alias for early Phase 1 code.
@export var display_name: String = ""
@export var description: String = ""
@export var type: int = TYPE_STRING
@export var type_name: String = "String" # Human-readable convenience field.
@export var default_value: Variant = ""
@export var options: Array[String] = []
@export var required: bool = false
