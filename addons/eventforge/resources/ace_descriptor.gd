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
@export var description: String = ""
@export var category: String = ""
@export var params: Array[ACEParam] = []
@export var signal_name: String = ""
@export var return_type: int = TYPE_NIL
@export var codegen_template: String = ""
