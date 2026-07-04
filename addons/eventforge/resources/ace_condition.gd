# EventForge - ACECondition resource
# Serializable instance of a condition ACE in an event row.
@tool
class_name ACECondition
extends Resource

@export var provider_id: String = "Core"
@export var ace_id: String = ""
@export var params: Dictionary = {}
@export var parameters: Dictionary = {} # Backwards-compatible alias for early Phase 1 .tres files.
@export var negated: bool = false
@export var enabled: bool = true
## Baked codegen template (from a custom ACE's @ace_codegen_template). When non-empty it
## takes precedence over the descriptor registry, so addon ACEs compile without one.
@export var codegen_template: String = ""
## Event-sheet-style per-ACE note, shown dimmed after the text in the sheet (right-click to edit).
@export var comment: String = ""
## Stateful conditions: a class member this instance owns (baked with a fresh uid at
## apply), a line run every tick BEFORE the if, and a line run just inside it.
@export var member_declaration: String = ""
@export var codegen_prelude: String = ""
@export var codegen_on_true: String = ""
