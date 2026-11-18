extends Node2D

signal opened(rarity: String)

@export var base_chance: float = 0.05
@export var pity_step: float = 0.02
@export var pity_cap: int = 30
var pity: int = 0


func open() -> String:
	pity += 1
	var chance := base_chance + pity_step * float(pity)
	if pity >= pity_cap or randf() < chance:
		pity = 0
		opened.emit("rare")
		return "rare"
	opened.emit("common")
	return "common"
