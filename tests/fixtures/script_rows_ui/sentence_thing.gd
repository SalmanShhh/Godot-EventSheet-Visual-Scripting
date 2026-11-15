class_name ScriptRowsSentenceThing
extends Node
## A script of yours that writes a sentence for one function and leaves its name to the reader.


## @ace_display_template("Take {amount} damage")
func take_damage(amount: int = 10) -> void:
	pass


## @ace_condition
func alive() -> bool:
	return true
