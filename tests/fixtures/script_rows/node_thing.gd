class_name ScriptRowsNodeThing
extends Node2D
## A plain Node script, written the way a user writes one: no annotations at all.

signal hit(amount: int)

@export var max_health: int = 100
@export var label_text: String = "hello"
var internal_count: int = 0


## Hurts this thing.
func take_damage(amount: int = 10, from: Node = null) -> void:
	internal_count += amount


func is_dead() -> bool:
	return internal_count >= max_health


func get_health() -> int:
	return max_health - internal_count


func pick():
	return label_text


static func make_label(prefix: String) -> String:
	return prefix + "!"


func _hidden_helper() -> void:
	pass
