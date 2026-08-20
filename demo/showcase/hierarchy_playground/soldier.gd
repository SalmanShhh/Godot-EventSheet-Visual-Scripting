class_name HierarchySoldier
extends Node3D
## One member of the squad, carrying the hp a per-child heal adds to.

## This soldier's health. Healing the squad walks the leader's children and tops each one up.
@export var hp: int = 40

func _ready() -> void:
	self.add_to_group("soldier")
