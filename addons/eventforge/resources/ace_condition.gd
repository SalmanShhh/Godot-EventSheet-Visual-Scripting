# EventForge — ACECondition resource
@tool
extends Resource
class_name ACECondition

@export var provider_id: String = "Core"
@export var ace_id: String = ""
@export var parameters: Dictionary = {}
@export var negated: bool = false
@export var enabled: bool = true
