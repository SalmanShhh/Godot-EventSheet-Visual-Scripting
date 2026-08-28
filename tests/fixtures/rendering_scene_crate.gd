# A crate somebody set the drawing order of by hand, in the two spellings a 2D scene really uses: the
# visibility layer written once at the start, and a z_index kept one step in front of another node
# every frame. Both are numbers in the file and words on the row, and opening this file changes not
# one byte of it.
extends Node2D


func _ready() -> void:
	visibility_layer = 2


func _process(_delta: float) -> void:
	z_index = $Player.z_index + 1
