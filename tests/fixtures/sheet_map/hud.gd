# A fixture project for the Sheet map: the object that listens for the player's signal.
extends Node

@export var player: Node


func _ready() -> void:
	player.sheet_map_fixture_died.connect(_on_died)


func _on_died() -> void:
	pass
