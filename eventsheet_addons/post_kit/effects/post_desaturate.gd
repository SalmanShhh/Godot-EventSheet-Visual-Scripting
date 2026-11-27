# @ace_version(1.0.0)
## Desaturate: the colour drains out of the frame. Full strength is black and white, and everything
## between is a world losing interest in itself - a death, a memory, a pause.
@tool
class_name PostKitDesaturate
extends "post_effect.gd"


func _shader_file() -> String:
	return "post_desaturate.glsl"
