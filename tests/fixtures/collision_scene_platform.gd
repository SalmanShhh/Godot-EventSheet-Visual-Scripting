# A moving one-way platform, turned over. It carries whoever is standing on it, and its shape only
# blocks from underneath - so nobody ever stands on it and the row that carries them never runs.
extends AnimatableBody2D


func _physics_process(_delta: float) -> void:
	for rider in get_tree().get_nodes_in_group("riders"):
		if rider.is_on_floor():
			rider.position += Vector2(1.0, 0.0)
