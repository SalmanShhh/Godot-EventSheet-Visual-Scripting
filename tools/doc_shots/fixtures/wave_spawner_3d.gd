extends Node3D

const Enemy: PackedScene = preload("res://tools/doc_shots/fixtures/empty_stage.tscn")

var __gfirst_u1: int = -1


func __group_first_u1(group_name: String) -> bool:
	var count: int = get_tree().get_nodes_in_group(group_name).size()
	var previous: int = __gfirst_u1
	__gfirst_u1 = count
	return previous == 0 and count > 0


func _ready() -> void:
	$Timer.timeout.connect(_on_timeout)


func _process(_delta: float) -> void:
	if __group_first_u1("spawners"):
		if $SpawnBox is CollisionShape3D:
			var new_enemy = Enemy.instantiate()
			$Enemies.add_child(new_enemy)
			new_enemy.global_position = ($SpawnBox as Node3D).to_global(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * (($SpawnBox as CollisionShape3D).shape as BoxShape3D).size)
		else:
			var new_enemy = Enemy.instantiate()
			$Enemies.add_child(new_enemy)
			new_enemy.global_position = ($SpawnBox as Node3D).to_global(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * ($SpawnBox as CSGBox3D).size)


func _on_timeout() -> void:
	var flanker = Enemy.instantiate()
	$Enemies.add_child(flanker)
	flanker.global_position = $Player.global_position + Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * 8.0
