# The scene that makes players: a spawner addressed by node path, and the factory it is handed. The
# `spawn_function` line is GDScript because Godot never stores a Callable in a .tscn - which is why
# the reader looks for it here rather than in the scene file.
extends Node2D


func _ready() -> void:
	$Spawner.spawn_function = spawn_player


func spawn_player(data: Variant) -> Node:
	var player: Node = preload("res://tests/fixtures/multiplayer_scene_player.tscn").instantiate()
	player.name = str(data)
	return player
