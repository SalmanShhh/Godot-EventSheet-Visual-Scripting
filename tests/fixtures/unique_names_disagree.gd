# One script, two scenes, and a %name they do not agree about: the bar is a ProgressBar in one and a
# Label in the other. The sheet can speak the NAME (it is the same word in both), but neither scene
# gets to say what class it is - a row offered in one class's vocabulary would not compile in the
# other, and it would have been offered silently.
extends Control


func _process(_delta: float) -> void:
	%ScoreLabel.text = "0"
