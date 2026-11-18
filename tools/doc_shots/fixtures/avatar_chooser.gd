extends Control

var avatar: Texture2D


func _ready() -> void:
	$ChooseButton.pressed.connect(_on_choose_button_pressed)


func _on_choose_button_pressed() -> void:
	var __answer_u1 := func(accepted: bool, paths: PackedStringArray, _filter_index: int) -> void:
		if accepted and not paths.is_empty():
			_on_file_chosen(paths[0])
		else:
			_on_ask_cancelled()
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE) or DisplayServer.file_dialog_show("Open a file", "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, PackedStringArray(["*.png;Images"]), __answer_u1) != OK:
		var __chooser_u1 := FileDialog.new()
		__chooser_u1.title = "Open a file"
		__chooser_u1.access = FileDialog.ACCESS_FILESYSTEM
		__chooser_u1.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		__chooser_u1.filters = PackedStringArray(["*.png;Images"])
		__chooser_u1.file_selected.connect(_on_file_chosen)
		__chooser_u1.file_selected.connect(__chooser_u1.queue_free.unbind(1))
		__chooser_u1.canceled.connect(_on_ask_cancelled)
		__chooser_u1.canceled.connect(__chooser_u1.queue_free)
		add_child(__chooser_u1)
		__chooser_u1.popup_centered(Vector2i(720, 480))


func _on_file_chosen(path: String) -> void:
	avatar = ImageTexture.create_from_image(Image.load_from_file(path))


func _on_ask_cancelled() -> void:
	$StatusLabel.text = "Kept the old picture."
