# A file whose every line is written the way an effect line is written and is about something else:
# a node that wears no material at all, and a variable that happens to be called material. Not one of
# them becomes a dial row, and every one of them reads as whatever it already read as.
extends Node2D

var material_budget: int = 4


func _ready() -> void:
	material.set_shader_parameter(&"dissolve", 0.7)
	$Door.material.set_shader_parameter(&"glow", 1.0)
	material_budget = 2
