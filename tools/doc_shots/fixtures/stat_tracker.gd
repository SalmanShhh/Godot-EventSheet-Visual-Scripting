class_name RunStats
extends Node
## Tracks how the run is going.

@export_group("Movement")
@export var speed: float = 200.0
@export var jump_force: float = 400.0
@export_group("")
var hp: int = 100
var alive: bool = true
const MAX_HP: int = 100
static var spawned: int = 0


func _process(_delta: float) -> void:
	var dealt: float = 0.0
	dealt = speed * 2
	hp -= int(dealt)
