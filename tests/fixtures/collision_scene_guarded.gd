# The gate's bug written the OTHER way: a guard-first handler, which opens as the filtered trigger
# rather than as a bare trigger with a group question under it. Same scene, same wrong mask, same
# enemies on a layer it does not watch - so it must earn the same finding. Written by hand here
# because that is what a reader picking "On overlap with enemies" ends up with in the file.
extends Area2D


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemies"):
		return
	queue_free()
