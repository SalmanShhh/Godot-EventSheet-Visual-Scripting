extends Node

signal mission_failed

@export var label: Label
var mission_left: float = 180.0


func _process(delta: float) -> void:
	mission_left = maxf(0.0, mission_left - delta)
	label.text = ("%02d:%02d" % [int(mission_left) / 60, int(mission_left) % 60])
	if mission_left <= 0.0:
		mission_failed.emit()
