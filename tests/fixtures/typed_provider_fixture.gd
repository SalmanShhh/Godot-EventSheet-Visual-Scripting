## Test fixture: the same system written with types, so every verb lands in its proper lane. Pins the
## inference contract the provider preview reports.
@tool
class_name TypedProviderFixture
extends RefCounted

signal wave_started(index: int)

@export var difficulty: float = 1.0


func start_wave(index: int) -> void:
	pass


func is_wave_active() -> bool:
	return true


func current_multiplier() -> float:
	return difficulty
