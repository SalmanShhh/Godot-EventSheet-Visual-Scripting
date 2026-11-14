class_name ScriptRowsAnnotatedTwin
extends Node
## The same shape as the plain Node script, with the author's own words written in.

signal hit(amount: int)

## How much it can take.
@export var max_health: int = 100


## @ace_name("Hurt")
## @ace_display_template("Take {amount} damage")
## @ace_category("Fighting")
## @ace_param(amount, default: 5, desc: "How hard")
func take_damage(amount: int = 10) -> void:
	pass


## @ace_hidden
func internal_step() -> void:
	pass


## @ace_condition
func alive() -> bool:
	return true
