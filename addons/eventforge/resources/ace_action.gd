# EventForge - ACEAction resource
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
## The row's LAST STORED READING - the display template it was applied under, slots and all
## ("Set {property} to {value}"), never the filled-in sentence. Baked at apply time beside the
## codegen template, for exactly one reason: a row whose verb the installed vocabulary no longer
## has must still READ as what it was written as. Without it such a row falls back to its raw id
## and the sentence a person wrote turns into "Pack::DoTheThing" in the one lane they read first.
##
## Slots rather than a finished sentence, so the reading still follows the row's own values when a
## parameter is edited. Empty on every row applied before this existed, and on every row lifted from
## a file whose verb is still installed - both read through the live vocabulary as they always did.
@export var display_text: String = ""
