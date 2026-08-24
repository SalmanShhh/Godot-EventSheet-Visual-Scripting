# A crypt somebody set the mood of by hand, long before any sheet opened it: the layer darkened to a
# colour, the same layer eased darker still, and the world's fog, ambient and glow written straight
# through the WorldEnvironment. Every spelling here is one somebody really writes - the `$` path, the
# variable the node was held in, and the two one-line tweens - and opening this file changes not one
# byte of it.
extends Node2D

@onready var level: CanvasModulate = $Level


func _ready() -> void:
	$Level.color = Color(0.3, 0.3, 0.36)
	level.color = Color("111522")
	create_tween().tween_property($Level, "color", Color(0.1, 0.1, 0.15), 10.0)
	$World.environment.fog_enabled = true
	$World.environment.fog_density = 0.03
	$World.environment.ambient_light_energy = 0.15
	$World.environment.glow_enabled = true
	create_tween().tween_property($World.environment, "glow_intensity", 1.2, 4.0)
