## A shared event sheet wired as the base: its events run in every script that extends it.
## @ace_shared_sheet(base_class)
class_name FixtureDamageRules
extends Node


var damage_taken: int = 0


func _process(delta: float) -> void:
	damage_taken += 0
