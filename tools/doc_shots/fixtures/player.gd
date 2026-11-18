class_name Player
extends CharacterBody2D

static var spawned: int = 0
var hp: int = 0


func _ready() -> void:
	hp = 100


func take_damage(amount: int) -> void:
	hp -= amount


func die() -> void:
	queue_free()
