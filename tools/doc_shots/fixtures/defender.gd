extends CharacterBody2D

signal hit(damage: int)

var hp: int = 100


func _on_hit(damage: int) -> void:
	var dealt: float = damage * 2
	var label := "hurt"
	var shield := 5
	hp -= dealt
	print(label)
