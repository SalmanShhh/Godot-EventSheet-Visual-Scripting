# EventForge — ACEAction resource
# Serializable instance of an action ACE in an event row.
@tool
extends Resource
class_name ACEAction

@export var provider_id: String = "Core"
@export var ace_id: String = ""
@export var params: Dictionary = {}
@export var parameters: Dictionary = {} # Backwards-compatible alias for early Phase 1 .tres files.
@export var is_awaited: bool = false
@export var await_call: bool = false # Backwards-compatible alias for early Phase 1 .tres files.
@export var comment: String = ""
@export var enabled: bool = true
