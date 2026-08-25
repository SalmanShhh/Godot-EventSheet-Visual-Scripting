# A fixture project for the Sheet map: the object that raises the signal the HUD listens for.
extends Node

signal sheet_map_fixture_died


func take_damage() -> void:
	sheet_map_fixture_died.emit()
