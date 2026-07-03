## Test fixture: an ACE provider registered VIA CODE (EventForgeBridge), not via the
## res://eventsheet_addons/ folder scan — proves other plugins can extend the vocabulary.
@tool
class_name RuntimeProviderFixture
extends RefCounted


## @ace_action
## @ace_name("Emit Pulse")
## @ace_category("Runtime Fixture")
## @ace_codegen_template("pulse_strength = {strength}")
func emit_pulse(strength: float) -> void:
	pass
