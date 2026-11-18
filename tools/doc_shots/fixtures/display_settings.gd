extends Node

var img: Image
var tex: Texture2D


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	get_window().title = "My Game"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = 60
	get_viewport().msaa_2d = Viewport.MSAA_4X


func take_shot() -> void:
	img = get_viewport().get_texture().get_image()
	img.save_png("user://shot.png")
	tex = $SubViewport.get_texture()
