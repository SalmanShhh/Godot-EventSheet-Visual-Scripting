extends Node

var __every_tick: float = 0.0


func _process(delta: float) -> void:
	__every_tick += delta
	if __every_tick >= maxf(2.0, 0.001):
		__every_tick = fmod(__every_tick, maxf(2.0, 0.001))
		print("tick")
