## A hand-written UI script of the commonest kind: nothing connects anything, because the project
## wired both signals in the Godot editor - so the .tscn beside this file holds the connections and
## these two functions are all the script has. Fixture for the scene-connection reading (M42).
class_name Structure3Menu
extends Control

var clicks: int = 0
var elapsed: float = 0.0


func _on_start_button_pressed() -> void:
	clicks += 1


func _on_countdown_timeout() -> void:
	elapsed += 1.0
