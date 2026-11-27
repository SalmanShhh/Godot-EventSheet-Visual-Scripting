# @ace_version(1.0.0)
## Fade: the frame is mixed towards one flat colour. Full strength is that colour and nothing else,
## which is the moment a scene change happens behind it.
@tool
class_name PostKitFade
extends "post_effect.gd"

# @ace_hidden
## The colour the frame lands on at full strength.
@export var to_colour: Color = Color.BLACK


func _shader_file() -> String:
	return "post_fade.glsl"


func _effect_colour() -> Color:
	return to_colour
