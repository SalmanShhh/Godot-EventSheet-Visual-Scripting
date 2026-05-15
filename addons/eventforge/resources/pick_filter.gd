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
	CUSTOM
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
