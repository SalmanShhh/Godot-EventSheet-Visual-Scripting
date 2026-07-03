# EventForge — ACEAction resource
# Serializable instance of an action ACE in an event row.
@tool
class_name ACEAction
extends Resource

@export var provider_id: String = "Core"
@export var ace_id: String = ""
@export var params: Dictionary = {}
@export var parameters: Dictionary = {} # Backwards-compatible alias for early Phase 1 .tres files.
@export var is_awaited: bool = false
@export var await_call: bool = false # Backwards-compatible alias for early Phase 1 .tres files.
@export var comment: String = ""
@export var enabled: bool = true
## Baked codegen template (from a custom ACE's @ace_codegen_template). When non-empty it
## takes precedence over the descriptor registry, so addon ACEs compile without one.
@export var codegen_template: String = ""
