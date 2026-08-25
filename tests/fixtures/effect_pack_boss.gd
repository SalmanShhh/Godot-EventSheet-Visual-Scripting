# A boss dressed by the effect packs. It wears the dissolve material the pack copied into the project,
# and the rows under each moment are the packs' own verbs - one word each, with the timing as their
# only argument. Nothing here names a dial: the packs know their own, and the shader names them.
extends Sprite2D

signal died
signal hurt(amount: float)


func _ready() -> void:
	died.connect(_on_died)
	hurt.connect(_on_hurt)


func _on_died() -> void:
	$DissolveBehavior.dissolve(0.8)


func _on_hurt(amount: float) -> void:
	$HitFlashBehavior.flash(Color.WHITE, 0.2)
	material.set_shader_parameter(&"edge_width", amount * 0.01)
