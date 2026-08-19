## The Object pool pattern, hand-written: objects are kept and reused instead of created and
## destroyed. Printed as the HAND-WRITTEN column of the Manual's Common Game Patterns page and read
## for the AS EVENTS column beside it.
extends Node2D

const BULLET: PackedScene = preload("res://tests/fixtures/head_bullet.tscn")

var pool: Array = []


func spawn() -> void:
	var bullet = pool.pop_back() if not pool.is_empty() else BULLET.instantiate()
	bullet.visible = true
	add_child(bullet)


func retire(bullet) -> void:
	bullet.visible = false
	remove_child(bullet)
	pool.push_back(bullet)
