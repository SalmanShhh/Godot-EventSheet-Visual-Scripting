# The mask is right and the layer is right, and the Area's own monitoring switch is off in the
# scene - so Godot emits no touch at all and every row waiting on one is unreachable. TWO rows wait
# on one here, which is the point: the sentence says "every row", so every one of them has to wear
# the sheet's amber state rather than only the first.
extends Area2D


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		queue_free()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("enemies"):
		print(body.name)
