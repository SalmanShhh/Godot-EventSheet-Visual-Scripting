@tool
class_name AutoACESample
extends Node

signal died

@export var health: int = 100
@export var stamina: float = 10.0


## @ace_category Combat
func take_damage(amount: int) -> void:
    health -= amount


## @ace_category Combat
func heal(amount: int) -> void:
    health += amount


func is_dead() -> bool:
    return health <= 0


## @ace_name Status Text
func get_status_label() -> String:
    return "Alive"


## @ace_hidden
func hidden_editor_helper() -> void:
    pass
