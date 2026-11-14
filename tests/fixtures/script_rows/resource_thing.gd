class_name ScriptRowsResourceThing
extends Resource
## A data Resource with a little behaviour.

@export var amount: int = 3


func total() -> int:
	return amount * 2


func add(count: int) -> void:
	amount += count
