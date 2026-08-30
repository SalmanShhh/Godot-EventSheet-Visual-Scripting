# The mask is right and the layer is right, and the Area's own monitoring switch is off in the
# scene - so Godot emits no touch at all and every row waiting on one is unreachable.
extends Area2D


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		queue_free()
