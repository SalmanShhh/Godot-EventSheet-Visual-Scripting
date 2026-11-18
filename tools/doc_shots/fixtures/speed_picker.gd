extends Node2D

var speed: float = 0.0
var walk_speed: float = 120.0
var sprint_speed: float = 240.0
var sprint_held: bool = false
var score: int = 0
var tier: String = ""


func _ready() -> void:
	print("ready")
	speed = sprint_speed if sprint_held else walk_speed
	tier = "gold" if score > 100 else "silver" if score > 50 else "bronze"
