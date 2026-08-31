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
	# Wide enough for a path box and the muted lead under it without either wrapping.
	root.size = Vector2i(880, 560)
	# The dialog is a real popup window, and a popup drawn by the desktop is not in this window's
	# texture - so it is embedded, which is the only way a screenshot can hold it.
	root.gui_embed_subwindows = true
	# A flat backdrop behind the dialog, so the picture is the dialog rather than the dialog over
	# whatever the driver left in the framebuffer.
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	# Frame two, not frame one: the backdrop has to have been laid out before a dialog is centred
	# over it, or the popup opens against a window that has not sized itself yet.
	if _frames == 2:
		_dialog = ACEParamsDialog.new()
		_dialog.init_dialog(root)
		# A definition built here rather than fetched from the registry, so the picture holds one
		# user:// path, one res:// path and one plain expression field side by side - the whole point
		# of the lead is the difference between those three, and no shipped verb has all three.
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
	# Ten more frames for the dialog's own layout and the help strip's text to settle.
	if _frames < 12 or _dialog == null:
		return
	# The DIALOG'S texture rather than the window's: the picture wanted is the dialog, and the
	# backdrop around it is only there to stop the popup being drawn over nothing.
	var image: Image = _dialog._dialog.get_texture().get_image()
	image.save_png("res://docs/images/file-place-field.png")
	print("[preview] place-aware path field %dx%d" % [image.get_width(), image.get_height()])
	quit(0)
