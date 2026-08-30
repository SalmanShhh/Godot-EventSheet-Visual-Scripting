extends Node

## The stats block every project grows: numbers that cannot be set carelessly. Health and armour
## point at named functions, the way older Godot code is written; shield writes its accessor inline,
## the way newer code is. Both are properties, and a sheet has to read both.

signal health_changed(amount: int)
signal died

const MAX_HEALTH: int = 100

var health: int = 100:
	set = _set_health,
	get = _get_health

var armour: int = 0:
	set = _set_armour

var shield: float = 0.0:
	set(value):
		shield = clampf(value, 0.0, 1.0)
	get:
		return shield


func _set_health(value: int) -> void:
	health = clampi(value, 0, MAX_HEALTH)
	health_changed.emit(health)
	if health <= 0:
		died.emit()


func _get_health() -> int:
	return health


func _set_armour(value: int) -> void:
	armour = maxi(value, 0)


func take_damage(amount: int) -> void:
	var through: int = maxi(amount - armour, 0)
	health -= through


func heal(amount: int) -> void:
	health += amount
