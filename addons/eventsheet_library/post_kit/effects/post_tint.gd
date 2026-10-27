## Tint: every colour in the frame is multiplied by one colour. A cold blue night, a sick green
## corridor, a gold afternoon - the shading stays where it was and only the hue moves.
## @ace_version(1.0.0)
@tool
extends "post_effect.gd"

## The colour the frame is multiplied by. White changes nothing.
## @ace_hidden
@export var tint: Color = Color(1.0, 0.85, 0.7)

## How much light is left after the tint. Below 1 the frame also darkens, which is what most tints
## a game actually wants are made of.
## @ace_hidden
@export_range(0.0, 2.0, 0.01) var gain: float = 1.0


func _shader_file() -> String:
	return "post_tint.glsl"


func _effect_colour() -> Color:
	return tint


func _effect_dials() -> Vector4:
	return Vector4(gain, 0.0, 0.0, 0.0)
