# A hand-built second view: a SubViewport, a Camera2D and a TextureRect wired together by hand,
# exactly as somebody wrote it before the Second View pack existed.
#
# Nothing in this file may be claimed as a Second View row. A view the pack never made is not a view
# it can zoom, stop or hand a texture for, so a row saying otherwise would promise a name the autoload
# has never heard of. The plainest reading is the honest one here, and the bytes must come back
# untouched.
extends Node2D

@onready var frame: TextureRect = $HUD/Frame

var view: SubViewport = null


func _ready() -> void:
	view = SubViewport.new()
	view.size = Vector2i(200, 120)
	view.world_2d = get_viewport().find_world_2d()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var lens: Camera2D = Camera2D.new()
	lens.zoom = Vector2(0.25, 0.25)
	view.add_child(lens)
	add_child(view)
	frame.texture = view.get_texture()
