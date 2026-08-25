# A boss somebody gave a burn effect by hand, long before any sheet opened it: the material copied so
# the other bosses do not burn with it, four dials turned in the four spellings people really write -
# no receiver at all, the $ path, the % unique name, the get_node() call and the variable the node was
# held in - and the one-line tween a fade is. One line names a dial the shader does not declare, and
# stays the free-string row it has always been. Opening this file changes not one byte of it.
extends Sprite2D

@onready var aura: Sprite2D = $Aura


func _ready() -> void:
	material = preload("res://tests/fixtures/effect_dissolve_material.tres")
	material = material.duplicate()
	material.set_shader_parameter(&"dissolve", 0.7)
	material.set_shader_parameter(&"edge_tint", Color("ff9b3c"))
	$Aura.material.set_shader_parameter(&"glow", 2.0)
	%Aura.material.set_shader_parameter(&"glow", 1.5)
	get_node("Aura").material.set_shader_parameter("glow", 1.0)
	aura.material.set_shader_parameter(&"glow", 0.5)
	material.set_shader_parameter(&"disolve", 1.0)
	create_tween().tween_method(func(v): material.set_shader_parameter(&"dissolve", v), 0.0, 1.0, 0.8)
	RenderingServer.global_shader_parameter_set("wind_strength", 2.0)
