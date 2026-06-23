@tool
## A Node behavior with the one-line @ace_expose_all(node) opt-in and ZERO per-method annotations.
## Every own public method should auto-publish as a NODE-TARGETED ACE (type from return type, codegen
## synthesized as {target}.method(args)). Used by expose_all_node_test.
## @ace_expose_all(node)
class_name ExposeAllNodeSample
extends Node

signal fired

func can_fire() -> bool:
	return true

func fire() -> void:
	pass

func set_rate(rate: float) -> void:
	pass

func ammo_count() -> int:
	return 0

func _private_helper() -> void:
	pass
