# A scene the current editor saved: the scene-unique mark is a property line under the node, not a flag
# on its header. The sheet reads the one name this scene marks.
extends Control

var shown: bool = true


func _process(_delta: float) -> void:
	if shown:
		%Bar.show_percentage = false
