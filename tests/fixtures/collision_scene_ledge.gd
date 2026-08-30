# The clean twin of the platform: the same rows, the same one-way shape, and the shape the right way
# up. A one-way collider is not a problem - being turned over is - so this one says nothing.
extends AnimatableBody2D


func _physics_process(_delta: float) -> void:
	for rider in get_tree().get_nodes_in_group("riders"):
		if rider.is_on_floor():
			rider.position += Vector2(1.0, 0.0)
