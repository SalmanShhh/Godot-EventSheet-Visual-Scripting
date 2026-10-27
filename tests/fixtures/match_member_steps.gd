extends Node

## A switch on a mode, as a user writes one: each branch sets the object's own variables, one of
## them after a question of its own.

enum Mode { IDLE, WALKING }

var mode: Mode = Mode.IDLE
var direction: int = 1
var wait_left: float = 0.0


func _physics_process(delta: float) -> void:
	match mode:
		Mode.IDLE:
			if wait_left <= 0.0:
				direction = -direction
				wait_left = 2.0
		Mode.WALKING:
			wait_left -= delta
