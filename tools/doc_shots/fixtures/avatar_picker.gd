extends Node

var avatar: Texture2D


func _ready() -> void:
	get_window().files_dropped.connect(_on_files_dropped)


func _on_files_dropped(files: PackedStringArray) -> void:
	avatar = ImageTexture.create_from_image(Image.load_from_file(files[0]))
