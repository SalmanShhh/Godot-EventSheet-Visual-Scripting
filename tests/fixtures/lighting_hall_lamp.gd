# A sheet that lives ON the light it is about, with every row's "On node" left blank - which is what
# that field's own description tells an author to do for this node, and therefore the commonest shape
# a lit sheet writes. The file says the bare property and nothing else, and opening it has to hand
# back the rows that wrote it rather than four assignments to variables nobody declared.
extends PointLight2D


func _ready() -> void:
	energy = 1.2
	color = Color("ffd9a1")
	shadow_enabled = true
	texture_scale = 1.5
