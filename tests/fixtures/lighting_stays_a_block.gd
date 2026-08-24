# The lines a light row must NOT claim, in a script that sits in the same scene as the lights.
# Each one is written the way a light row is written, and each one is about something else: a door
# that is merely hidden, a variable that happens to be called energy, and a toggle no row can say.
# A row that guessed here would relabel somebody's code, so the promise is that none of it lifts.
extends Node2D

var energy: float = 1.0


func _ready() -> void:
	$Door.visible = false
	energy = 2.0
	$Torch.shadow_enabled = not $Torch.shadow_enabled
