extends Node2D

var level_seconds: float = 0.0


func _process(delta: float) -> void:
	level_seconds += delta
