# The clean twin of the gate: the same rows, the same trigger, the same question, and a mask that
# covers the layer the enemies really sit on. Nothing here earns a finding, which is the half of
# every check that keeps it from crying wolf.
extends Area2D


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		queue_free()
