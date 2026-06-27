# EventForge — PickFilter resource
# Describes an event-sheet-style pick/filter scope for an event.
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
## resumes next frame over a snapshot taken once per pass (items added mid-pass appear next pass; items
## freed mid-pass are skipped via is_instance_valid). frame_spread_count caps items EXAMINED per frame
## (not items that survive the filter); frame_spread_budget_ms is a wall-clock ms budget — at least one
## item is always processed per frame, so a tiny budget can't stall. 0/0 = a normal same-frame loop.
## Drive a budgeted loop from a PER-FRAME trigger (On Process): under a one-shot trigger it would process
## only the first slice and never resume. Not yet combined with While/Repeat, order-by, or pick-first-N
## (those emit a normal loop + a compile warning). The Project Doctor uses these to tell a budgeted loop
## from an unbounded one.
@export var frame_spread_count: int = 0
@export var frame_spread_budget_ms: float = 0.0
