# Fixture for param_authoring_test: one provider exercising each way a param's shape can be authored.
# Deliberately has NO class_name - the test loads it by path, and a new global class would mean
# regenerating the editor class cache for a file only one test reads.
@tool
extends Node


## @ace_action
## @ace_name("Drive Toward")
## Bare GDScript defaults and no param annotation at all: the picker should read 1.0 and 5.0 straight
## off the signature, while `angle` (which has none) stays at type-zero.
func drive_toward(angle: float, throttle: float = 1.0, tolerance: float = 5.0) -> void:
	pass


## @ace_action
## @ace_name("Set Quality")
## @ace_param(level, options: low=Potato|med=Balanced|high=Ultra, default: "med")
## Labeled options plus an explicit starting value: the row reads "Balanced" and inserts `med`.
func set_quality(level: String) -> void:
	pass


## @ace_condition
## @ace_name("Stat Compares")
## @ace_param(op, hint: comparison)
## The whole operator dropdown from one word, seeded to == so the row is a sentence on drop.
func stat_compares(op: String, value: float) -> bool:
	return true
