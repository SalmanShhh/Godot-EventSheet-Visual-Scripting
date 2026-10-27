## Pixelate: the frame is drawn in blocks instead of pixels. A retro screen, a censor, a teleport
## coming apart. Strength walks the block from one pixel up to the size below, so the effect can be
## faded in rather than switched on.
## @ace_version(1.0.0)
@tool
extends "post_effect.gd"

## How big a block gets at full strength, in pixels. 1 is no blocks at all.
## @ace_hidden
@export_range(1.0, 64.0, 1.0) var block_pixels: float = 8.0


func _shader_file() -> String:
	return "post_pixelate.glsl"


func _effect_dials() -> Vector4:
	return Vector4(block_pixels, 0.0, 0.0, 0.0)
