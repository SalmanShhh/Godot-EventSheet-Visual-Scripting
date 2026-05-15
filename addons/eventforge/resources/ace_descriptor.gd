# EventForge — ACEDescriptor resource
@tool
extends Resource
class_name ACEDescriptor

enum ACEType {
TRIGGER,
CONDITION,
ACTION,
EXPRESSION
}

@export var provider_id: String = "Core"
@export var ace_id: String = ""
@export var display_name: String = ""
@export var ace_type: ACEType = ACEType.ACTION
@export var signal_name: String = ""
@export var codegen_template: String = ""
@export var params: Array[ACEParam] = []
@export var description: String = ""
