# EventForge - render harness (dev tool) for the place-aware path field: opens the params dialog on
# Write Text File (in a folder) so the muted place lead beside each path box, the stated folder
# choice and the help strip's account of the two places can be eyeballed. Run NON-headless:
#   godot --path . --script tools/render_file_places_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _dialog: ACEParamsDialog = null


func _init() -> void:
	root.title = "Place-Aware Path Field"
	root.size = Vector2i(880, 560)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_dialog = ACEParamsDialog.new()
		_dialog.init_dialog(root)
		var definition: ACEDefinition = ACEDefinition.new()
		definition.display_name = "Write Text File (in a folder)"
		definition.parameters = [
			{"id": "path", "display_name": "Path", "default_value": "\"user://runs/latest.txt\"",
				"description": "File to write, inside one or more folders. OVERWRITES any existing file.",
				"hint": "file_path"},
			{"id": "shipped", "display_name": "Template", "default_value": "\"res://runs/template.txt\"",
				"description": "The file this run starts from - one of the game's own.", "hint": "file_path"},
			{"id": "text", "display_name": "Text", "default_value": "\"run finished\"",
				"description": "Text content to store.", "hint": "expression"},
			{"id": "folder", "display_name": "Folder", "default_value": "make its folder first",
				"description": "Whether to create the folders in that path before writing.",
				"options": [{"key": "make its folder first", "label": "Make the folder first"},
					{"key": "its folder is already there", "label": "The folder is already there"}]},
		]
		_dialog.open(definition, {})
		return
	if _frames < 12 or _dialog == null:
		return
	var image: Image = _dialog._dialog.get_texture().get_image()
	image.save_png("res://docs/images/file-place-field.png")
	print("[preview] place-aware path field %dx%d" % [image.get_width(), image.get_height()])
	quit(0)
