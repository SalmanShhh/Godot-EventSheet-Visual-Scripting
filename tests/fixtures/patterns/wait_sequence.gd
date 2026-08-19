## The Wait sequence pattern, hand-written: steps that run one after another with a wait between
## them. Printed as the HAND-WRITTEN column of the Manual's Common Game Patterns page and read for
## the AS EVENTS column beside it.
extends Node2D

var armed: bool = false


func _ready() -> void:
	get_tree().create_timer(2.0).timeout.connect(func(): explode())


func explode() -> void:
	armed = false
	print("boom")
