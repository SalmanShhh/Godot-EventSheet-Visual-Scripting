# A fixture project for the Sheet map (U17): the object that raises the signal the HUD listens for.
extends Node

signal sheet_map_fixture_died


func take_damage() -> void:
	sheet_map_fixture_died.emit()
