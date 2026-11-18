extends Node

var wave_number: int = 1


func plan_waves() -> void:
	# Enemies per wave on each difficulty.
	# The swarm only shows up late.
	var waves := {
		"calm": 3,
		"busy": 8,
		"swarm": 20,
	}
	wave_number = waves["busy"]
	print(waves)
