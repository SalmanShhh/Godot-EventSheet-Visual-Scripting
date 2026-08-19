# A fixture project for the Sheet map (U17): three scripts that reach each other every way the map
# draws - an include, a signal, and a layout change. Never loaded, only read as text.
extends Node

const PLAYER := preload("res://tests/fixtures/sheet_map/player.gd")


func _ready() -> void:
	get_tree().change_scene_to_file("res://tests/fixtures/sheet_map/level_two.tscn")
