## The player object of the scene fixture: an ordinary object script with one function the level
## wires a signal to, so the wired-up call has a real project function to name.
class_name OpenedScenePlayer
extends CharacterBody2D

var lives: int = 3


func reset() -> void:
	lives = 3
