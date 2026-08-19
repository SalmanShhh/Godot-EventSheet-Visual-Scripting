## The Cooldown pattern, hand-written: a number counted down every tick, and something that happens
## when it reaches zero. The Manual's Common Game Patterns page prints this file as its HAND-WRITTEN
## column and reads it for the AS EVENTS column, so the two can never disagree.
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
