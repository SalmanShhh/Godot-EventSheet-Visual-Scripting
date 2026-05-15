# EventForge — EventFunction resource
@tool
extends Resource
class_name EventFunction

@export var enabled: bool = true
@export var function_name: String = ""
@export var parameters: Array[String] = []
@export var rows: Array[Resource] = []
