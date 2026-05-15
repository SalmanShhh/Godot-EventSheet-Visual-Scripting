# EventForge — LoopRow resource
# Serializable loop row for Construct-style iteration patterns.
@tool
extends Resource
class_name LoopRow

enum LoopKind {
	REPEAT,
	WHILE,
	FOR,
	FOR_EACH,
	FOR_EACH_ORDERED,
	FOR_EACH_WHERE
}

@export var enabled: bool = true
@export var comment: String = ""
@export var kind: LoopKind = LoopKind.REPEAT
@export var loop_kind: LoopKind = LoopKind.REPEAT # Backwards-compatible alias.
@export var loop_name: String = ""
@export var conditions: Array[ACECondition] = []
@export var actions: Array[Resource] = []
@export var sub_events: Array[Resource] = []
@export var max_iterations: int = 0
@export var repeat_count: String = "1"
@export var iterations: int = 1 # Backwards-compatible alias.
@export var while_condition: ACECondition = null
@export var while_expression: String = ""
@export var for_from: String = "0"
@export var start_value: String = "0" # Backwards-compatible alias.
@export var for_to: String = "0"
@export var end_value: String = "0" # Backwards-compatible alias.
@export var for_step: String = "1"
@export var step_value: String = "1" # Backwards-compatible alias.
@export var collection_kind: int = 0
@export var collection_value: String = ""
@export var collection_expression: String = "" # Backwards-compatible alias.
@export var iterator_name: String = "item"
@export var order_by_expression: String = ""
@export var order_descending: bool = false
@export var filter_conditions: Array[ACECondition] = []
@export var filter_mode: int = 0
@export var where_expression: String = "" # Backwards-compatible alias.
@export var body_rows: Array[Resource] = [] # Backwards-compatible alias.

## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "loop"
