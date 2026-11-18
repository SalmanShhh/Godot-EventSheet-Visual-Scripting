@tool
extends CharacterBody2D

enum Kind { SCOUT, BRUISER, SNIPER }

var hp := 100


func is_ranged(kind: Kind) -> bool:
	return kind == Kind.SNIPER


func take_hit(amount: int) -> void:
	hp -= amount
