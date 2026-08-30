# An Area with no shape under it. Godot says so in the Scene dock, beside a node nobody is looking
# at while the row that needs it is being written here.
extends Area2D


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		queue_free()
