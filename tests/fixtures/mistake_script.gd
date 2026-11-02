extends Node2D

signal hit(damage: int)

var lives: int = 3
var score: int = 0


func go() -> void:
	hit.emit()


func grind() -> void:
	while lives > 0:
		score += 1
