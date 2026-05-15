# EventForge — PickFilter resource
@tool
extends Resource
class_name PickFilter

enum CollectionKind {
ARRAY,
GROUP,
NODE_TREE,
CUSTOM
}

@export var enabled: bool = true
@export var collection_kind: CollectionKind = CollectionKind.CUSTOM
@export var source_expression: String = ""
@export var predicate_expression: String = ""
