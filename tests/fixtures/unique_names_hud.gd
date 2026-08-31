# A HUD whose two named nodes are the objects its rows sit on. Both marks are Godot's own - ticked in
# the Scene dock, stored in the .tscn - and nothing here was generated: the sheet reads these lines
# exactly as they are written, and re-emits them byte for byte.
extends Control

var player_hp: int = 100
var score: int = 0


func _process(_delta: float) -> void:
	if player_hp < 25:
		%HealthBar.show_percentage = false
		%HealthBar.indeterminate = false
		%ScoreLabel.set_modulate(Color(1.0, 0.3, 0.3))
		%ScoreLabel.text = "%d" % score
