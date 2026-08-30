# A turned-over one-way shape on a sheet that never asks about landing. Turning a one-way shape over
# is a choice somebody can make on purpose - the finding about it only means anything where the sheet
# is plainly waiting for the landing the shape blocks - so this earns nothing at all, however many
# touch triggers it has.
extends Area2D


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		queue_free()
