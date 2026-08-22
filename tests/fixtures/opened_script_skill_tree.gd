# Fixture - a skill tree written out by hand: costs, prerequisites, a table of unlocked ids, a
# points number, a walk over the requires list, and two stats with an upgrade's level inside them.
extends Node

signal skill_unlocked(id: String)

var costs: Dictionary = {"toughness": 1, "swift": 1, "sprint": 2, "double_jump": 2}
var requires: Dictionary = {"swift": ["toughness"], "sprint": ["swift"], "double_jump": ["toughness"]}
var unlocked: Dictionary = {}
var levels: Dictionary = {}
var skill_points: int = 3
var base_speed: float = 120.0
var base_damage: float = 10.0


func can_unlock(id: String) -> bool:
	for required: String in requires.get(id, []):
		if not unlocked.has(required):
			return false
	return skill_points >= int(costs.get(id, 0))


func jumps_allowed() -> int:
	if unlocked.has("double_jump"):
		return 2
	return 1


func level_of(id: String) -> int:
	return int(levels.get(id, 0))


func speed() -> float:
	return base_speed * (1.0 + level_of("speed") * 0.1)


func damage() -> float:
	return base_damage + 5.0 * level_of("power")


func unlock(id: String) -> void:
	if not can_unlock(id):
		return
	skill_points -= int(costs.get(id, 0))
	unlocked[id] = true
	levels[id] = int(levels.get(id, 0)) + 1
	skill_unlocked.emit(id)
