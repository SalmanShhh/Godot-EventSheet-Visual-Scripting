extends Node

var turn: int = 0
var gold: int = 0


func _ready() -> void:
	print("start")


func _process(delta: float) -> void:
	if turn > 10:
		gold += 5
		if gold > 50:
			print("rich")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		turn = 0


func _exit_tree() -> void:
	print("bye")
