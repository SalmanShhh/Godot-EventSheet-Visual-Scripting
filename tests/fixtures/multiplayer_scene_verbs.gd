# The scene's own two nodes as a hand-written script says them: a spawner that makes one
# copy for everybody, the three visibility calls a synchronizer takes, the function it is handed to
# answer per player, and the three signals the pair raises. Everything else about them lives in the
# .tscn, which is why the script is this short.
extends Node2D


func _ready() -> void:
	$Spawner.spawned.connect(_on_spawner_spawned)
	$Spawner.despawned.connect(_on_spawner_despawned)
	$PlayerSync.synchronized.connect(_on_playersync_synchronized)


func guard_the_view() -> void:
	$PlayerSync.add_visibility_filter(can_see)


func welcome(id: int) -> void:
	var __spawn_player = load("res://tests/fixtures/multiplayer_scene_player.tscn").instantiate()
	__spawn_player.name = str(id)
	__spawn_player.position = Vector2(0, 0)
	$Spawner.get_node($Spawner.spawn_path).add_child(__spawn_player, true)
	$PlayerSync.set_visibility_for(id, true)


func forget(id: int) -> void:
	$PlayerSync.set_visibility_for(id, false)


func open_up() -> void:
	$PlayerSync.public_visibility = true


func can_see(peer: int) -> bool:
	return peer != 0


func _on_spawner_spawned(node: Node) -> void:
	print(node.name)


func _on_spawner_despawned(node: Node) -> void:
	print(node.name)


func _on_playersync_synchronized() -> void:
	print("in step")
