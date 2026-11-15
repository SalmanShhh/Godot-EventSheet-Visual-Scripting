extends Node
## A script written before the node was renamed: it names the old class three ways, so any
## change that loses the old class name makes this file stop loading.

@export var p: FeedbackPlayer


func answers() -> Dictionary:
	var made: FeedbackPlayer = FeedbackPlayer.new()
	var out: Dictionary = {"p_is_feedback_player": p is FeedbackPlayer,
		"made_is_feedback_player": made is FeedbackPlayer}
	made.free()
	return out
