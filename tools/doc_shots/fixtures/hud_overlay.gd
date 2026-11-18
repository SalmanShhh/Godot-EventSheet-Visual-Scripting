extends Node2D

@onready var label: Label = $Label
@onready var hud_layer: CanvasLayer = $HUD
var code: String = "ABCD"
var saved_id: int = 0


func _enter_tree() -> void:
	z_index = 5
	move_to_front()
	reparent(hud_layer)
	hud_layer.layer = 10
	label.add_theme_font_size_override("font_size", 32)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD


func share() -> void:
	OS.shell_open("https://example.com")
	DisplayServer.clipboard_set(code)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
