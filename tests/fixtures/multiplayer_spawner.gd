# The scene side, as a script says it: a spawner addressed by node path, one addressed through a
# variable, and the spawn function the spawner points at. Everything else about replication lives in
# the .tscn, which is why there is so little here.
extends Node2D

@export var spawn_root: NodePath


func welcome(id: int) -> void:
	$Spawner.spawn(id)


func welcome_named(spawner: MultiplayerSpawner) -> void:
	spawner.spawn({"name": "Player", "id": 2})


func make_player(data) -> Node:
	var player := Node2D.new()
	player.name = str(data)
	return player
