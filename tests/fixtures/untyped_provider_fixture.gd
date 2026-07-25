## Test fixture: a typical hand-written user system - NO class_name, UNTYPED signatures. Reflection can
## only guess ACTION for an untyped method, which is exactly what the provider preview must warn about.
@tool
extends RefCounted

signal wave_started(index)

@export var difficulty := 1.0


func start_wave(index):
	pass


func is_wave_active():
	return true
