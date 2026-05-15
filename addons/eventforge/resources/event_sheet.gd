# EventForge — EventSheet resource
# Top-level event sheet resource attached to one host node.
@tool
extends Resource
class_name EventSheetResource

@export var host_class: String = "Node"
@export var host_node_path: NodePath = NodePath(".")
@export var events: Array[Resource] = []
@export var variables: Dictionary = {}
@export var includes: Array[NodePath] = []
@export var functions: Array[Resource] = []
