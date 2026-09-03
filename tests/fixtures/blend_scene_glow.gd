# A sprite that already wears a shader of its own, and three blend rows aimed at three nodes - one
# that clashes with that shader, one that cannot (a native mode sets a field and replaces nothing),
# and one aimed at a node the scene gives no material at all. Only the first is a finding, and this
# fixture is what says so.
extends Sprite2D


func _ready() -> void:
	BlendModes.blend_as(self, "screen", 1.0)
	BlendModes.blend_as($Ring, "add", 1.0)
	BlendModes.blend_as($Plain, "overlay", 1.0)
