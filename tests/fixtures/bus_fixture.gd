## Test fixture: an event-bus style provider registered as an AUTOLOAD in the test
## (no class_name on purpose - exercises the filename-derived provider id). Reflected
## members must call the singleton by name, never an owned instance or a $-node path -
## pinned by autoload_provider_codegen_test.
@tool
extends Node

@export var score: int = 0


## @ace_action
func publish(value: int) -> void:
	pass
