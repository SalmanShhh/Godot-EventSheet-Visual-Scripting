# A goblin wearing a material eleven other goblins wear too - the sharpest shader trap there is. The
# rows are exactly what anybody would write, and every one of them burns the whole tribe. Nothing here
# takes a copy first, which is what the head band says and what the health check offers to fix.
extends Sprite2D


func _ready() -> void:
	material.set_shader_parameter(&"dissolve", 0.4)
	$Torch.material.set_shader_parameter(&"dissolve", 0.9)
