# EventForge — PickFilter resource
# Describes a Construct-style pick/filter scope for an event.
@tool
extends Resource
class_name PickFilter

enum CollectionKind {
	GROUP,
	NODE_PATH_ARRAY,
	EXPRESSION,
	CHILDREN,
	ARRAY,
	NODE_TREE,
	CUSTOM,
	REPEAT,  # collection_value = count expression -> for i in range(n)
	WHILE,   # collection_value = condition expression -> while expr
}

@export var enabled: bool = true
@export var iterator_name: String = "item"
@export var collection_kind: CollectionKind = CollectionKind.EXPRESSION
@export var collection_value: String = ""
@export var source_expression: String = "" # Backwards-compatible alias.
@export var filter_conditions: Array[ACECondition] = []
@export var filter_mode: int = 0
@export var predicate_expression: String = "" # Backwards-compatible alias.
@export var order_by_expression: String = ""
@export var order_descending: bool = false
@export var pick_first_n: int = 0
## Frame-spreading (Budgeted For Each): when either is > 0 the loop processes a slice per frame and
## resumes next frame. frame_spread_count caps iterations/frame; frame_spread_budget_ms is a wall-clock
## ms budget. 0/0 = a normal same-frame loop. (The codegen is Solution 2; these fields also let the
## Project Doctor tell a budgeted loop from an unbounded one.)
@export var frame_spread_count: int = 0
@export var frame_spread_budget_ms: float = 0.0
