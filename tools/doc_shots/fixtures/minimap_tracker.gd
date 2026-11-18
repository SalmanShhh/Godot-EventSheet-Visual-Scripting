extends Node


func _ready() -> void:
	get_tree().node_added.connect(_on_node_joined_group)
	get_tree().node_removed.connect(_on_node_left_group)


func _on_node_joined_group(node: Node) -> void:
	if node.is_in_group("minimap"):
		$UI/Minimap.add_marker(node)
		if not node.tree_exiting.is_connected(_on_marked_node_leaving):
			node.tree_exiting.connect(_on_marked_node_leaving)


func _on_node_left_group(node: Node) -> void:
	if node.is_in_group("minimap"):
		$UI/Minimap.remove_marker(node)


func _on_marked_node_leaving() -> void:
	print("marker gone")
