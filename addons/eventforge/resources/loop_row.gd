# EventForge — LoopRow resource
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
@export var loop_kind: LoopKind = LoopKind.REPEAT
@export var iterations: int = 1
@export var while_expression: String = ""
@export var iterator_name: String = "i"
@export var start_value: String = "0"
@export var end_value: String = "0"
@export var step_value: String = "1"
@export var collection_expression: String = ""
@export var where_expression: String = ""
@export var body_rows: Array[Resource] = []

## Returns the stable row kind identifier.
func get_row_kind() -> String:
return "loop"
