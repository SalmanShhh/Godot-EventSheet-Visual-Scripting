extends CharacterBody2D

var ticks: int = 0


func _ready() -> void:
	ticks = 0


func _enter_tree() -> void:
	ticks = 1


func _exit_tree() -> void:
	ticks = -1
