extends Control

var player_hp: int = 100
var score: int = 0


func _process(_delta: float) -> void:
	if player_hp < 25:
		%HealthBar.show_percentage = false
		%HealthBar.indeterminate = false
		%ScoreLabel.set_modulate(Color(1.0, 0.3, 0.3))
		%ScoreLabel.text = "%d" % score
