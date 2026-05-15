# EventForge — LocalVariable resource
# Describes a scoped local variable declaration.
@tool
extends Resource
class_name LocalVariable

@export var name: String = ""
@export var type: int = TYPE_NIL
@export var type_name: String = "Variant"
@export var default_value: Variant = null
@export var description: String = ""
@export var is_constant: bool = false
