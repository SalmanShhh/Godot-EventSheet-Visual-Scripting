@tool
class_name EventSheetDemoGameplayActor
extends CharacterBody2D

signal died

@export var health: int = 100
@export var stamina: float = 25.0


## @ace_category Movement
func jump() -> void:
	velocity.y = -320.0


## @ace_category Combat
## @ace_description Deals damage to the actor.
func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		died.emit()


## @ace_category Combat
func heal(amount: int) -> void:
	health += amount


func is_dead() -> bool:
	return health <= 0


func get_health() -> int:
	return health


## @ace_hidden
func hidden_editor_helper() -> void:
	pass
