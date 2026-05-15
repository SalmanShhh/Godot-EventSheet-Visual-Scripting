# EventForge — ACEAction resource
@tool
extends Resource
class_name ACEAction

@export var provider_id: String = "Core"
@export var ace_id: String = ""
@export var parameters: Dictionary = {}
@export var await_call: bool = false
@export var enabled: bool = true
