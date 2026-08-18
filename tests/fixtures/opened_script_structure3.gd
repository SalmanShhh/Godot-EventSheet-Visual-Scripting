## An ordinary hand-written arena script - nothing here was written for the plugin. It exists to show
## the four Construct habits Godot spells differently: picking a group with a loop and an `if`, a
## `match` on a plain value, spawning as instantiate + add_child + position, and two handlers whose
## signals are wired in the scene beside this file rather than in any code.
class_name Structure3Arena
extends Node2D

const ENEMY_SCENE := preload("res://tests/fixtures/opened_script_structure3_enemy.tscn")

var difficulty: String = "normal"
var reward: int = 0
var spawn_point: Vector2 = Vector2(120, 64)
var spawned: int = 0


func sweep_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.hp < 10:
			enemy.flee()
	for child in get_children():
		if child.visible:
			child.hide()
		else:
			child.show()


func pay_out() -> void:
	match difficulty:
		"easy":
			reward = 10
		"normal", "hard":
			reward = 25
		_:
			reward = 0


func spawn_wave() -> void:
	var enemy := ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.global_position = spawn_point
	enemy.speed = 40.0
	spawned += 1


func _on_start_button_pressed() -> void:
	spawn_wave()


func _on_wave_timer_timeout() -> void:
	sweep_enemies()
