# EventForge — EventFunction resource
# Callable event-sheet function compiled to a GDScript function.
@tool
extends Resource
class_name EventFunction

@export var enabled: bool = true
@export var function_name: String = ""
@export var description: String = ""
@export var params: Array[ACEParam] = []
@export var parameters: Array[String] = [] # Backwards-compatible alias.
@export var return_type: int = TYPE_NIL
@export var is_async: bool = false
@export var events: Array[Resource] = []
@export var rows: Array[Resource] = [] # Backwards-compatible alias.
@export var local_variables: Dictionary = {}
