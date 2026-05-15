# EventForge — ACECondition resource
# Serializable instance of a condition ACE in an event row.
@tool
extends Resource
class_name ACECondition

@export var provider_id: String = "Core"
@export var ace_id: String = ""
@export var params: Dictionary = {}
@export var parameters: Dictionary = {} # Backwards-compatible alias for early Phase 1 .tres files.
@export var negated: bool = false
@export var enabled: bool = true
