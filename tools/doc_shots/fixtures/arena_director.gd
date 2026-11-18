extends Node2D

var wave: int = 1
var score: int = 0


func _ready() -> void:
	print("arena open")


#region Enemies
func _on_enemy_died() -> void:
	score += 10
	if score >= 50:
		wave += 1


func _on_wave_timer_timeout() -> void:
	print("next wave")
#endregion


#region Player
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"ui_accept"):
		score += 1
#endregion
