# The gate's scene exactly - the same mask, watching the same wrong layer - and a sheet that puts it
# right itself before anything can arrive. This is the code the collision vocabulary teaches people
# to write, so no check here may accuse it: the numbers in the `.tscn` are where the node starts, and
# a sheet that sets its own mask has said what it watches more recently than the scene file has.
extends Area2D


func _ready() -> void:
	set_collision_mask_value(3, true)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		queue_free()
