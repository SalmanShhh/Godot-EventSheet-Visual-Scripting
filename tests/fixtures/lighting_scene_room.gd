# A room that was lit by hand, long before any sheet opened it: four lights and every spelling a
# project reaches for - the `$` path, the variable it was held in, the `get_node()` call, and the
# one-line tween a fade is. Nothing here was written for the sheet, which is the whole point of the
# fixture: opening it changes not one byte of it.
extends Node2D

@onready var torch: PointLight2D = $Torch
@onready var lantern := $Props/Lantern


func _ready() -> void:
	$Torch.energy = 1.2
	torch.color = Color("ffd9a1")
	$Torch.shadow_enabled = true
	get_node("Props/Lantern").texture_scale = 1.5
	$Moonlight.enabled = false
	create_tween().tween_property(lantern, "energy", 1.0, 0.5)
