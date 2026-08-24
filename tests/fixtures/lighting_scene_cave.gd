# The 3D half of the same story. Godot spells every light knob differently here - `light_energy`
# rather than `energy`, `visible` rather than `enabled`, a range per light kind - and the sheet says
# the same five words about all of it.
extends Node3D

@onready var flashlight: SpotLight3D = $Flashlight


func _ready() -> void:
	$Flashlight.light_energy = 2.0
	flashlight.spot_range = 12.0
	flashlight.spot_angle = 30.0
	$Flashlight.visible = false
	$Bulb.omni_range = 8.0
	$Sun.light_color = Color(0.9, 0.8, 0.7)
	create_tween().tween_property($Bulb, "light_energy", 0.0, 1.5)
