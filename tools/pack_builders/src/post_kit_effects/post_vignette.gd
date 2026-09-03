## Vignette: the frame darkens towards its corners, so the middle is where the eye goes. The oldest
## trick a lens plays, and the one a game reaches for when it wants a player to look at one thing.
## @ace_version(1.0.0)
@tool
extends "post_effect.gd"

## The colour the corners shade towards. Black is a lens; a deep red is a warning.
## @ace_hidden
@export var shade: Color = Color.BLACK

## Where the shading starts, measured from the middle of the frame outwards. Small values shade
## almost the whole frame; large ones leave a wide clear middle and only touch the corners.
## @ace_hidden
@export_range(0.0, 1.0, 0.01) var inner_edge: float = 0.35


func _shader_file() -> String:
	return "post_vignette.glsl"


func _effect_colour() -> Color:
	return shade


func _effect_dials() -> Vector4:
	return Vector4(inner_edge, 0.0, 0.0, 0.0)
