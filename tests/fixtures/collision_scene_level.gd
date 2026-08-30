# A level made of scenes, which is how nearly every real project is laid out. The enemy in it is an
# INSTANCE: its header carries no type at all, and the layer it really sits on is the one this file
# overrides. A reader blind to that sees no enemy here, tells this trigger that the enemies sit
# somewhere else, and accuses a mask that is exactly right.
extends Area2D


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		queue_free()
