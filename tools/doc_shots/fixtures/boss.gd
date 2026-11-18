extends CharacterBody2D

signal defeated

@export var max_hp: float = 500.0
var hp: float = 500.0
var phase: int = 1


func take_damage(amount: float) -> void:
	hp -= amount
	if phase == 1 and hp <= max_hp * 0.6:
		phase = 2
		_enter_phase_2()
	if phase == 2 and hp <= max_hp * 0.25:
		phase = 3
		_enter_phase_3()
	if hp <= 0.0:
		defeated.emit()


func _enter_phase_2() -> void:
	velocity = Vector2.ZERO


func _enter_phase_3() -> void:
	velocity = Vector2.ZERO
