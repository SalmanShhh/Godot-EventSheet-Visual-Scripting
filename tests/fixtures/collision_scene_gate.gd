# A gate that opens for the enemies, watching the wrong layer. Everything about the rows is right:
# the trigger is the one Godot emits, the question is the one anybody would ask, and the enemies of
# this fixture sit on a layer the gate's own mask does not cover - so the trigger never fires and
# nothing in the editor says a word about it.
extends Area2D


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		queue_free()
