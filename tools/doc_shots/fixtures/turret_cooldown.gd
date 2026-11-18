extends Node2D

var cooldown: float = 0.0
var fire: bool = false


func _process(delta: float) -> void:
	cooldown -= delta
	if cooldown <= 0.0 and fire:
		shoot()
		cooldown = 0.5


func shoot() -> void:
	print("bang")
