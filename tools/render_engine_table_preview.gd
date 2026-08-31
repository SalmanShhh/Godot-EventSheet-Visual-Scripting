# EventForge - render harness (dev tool) for the engine-reader table read: opens the params dialog on
# Table Of File so the path field's place lead, the separator picker and the First line choice (one
# record per row, or every line a plain row) can be eyeballed together. Run NON-headless:
#   godot --path . --script tools/render_engine_table_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _dialog: ACEParamsDialog = null


func _init() -> void:
	root.title = "Table Of File"
	root.size = Vector2i(900, 600)
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
		_dialog.open(EventSheetACEAdapter.from_eventforge_descriptor(
			ACERegistry.find_descriptor("Core", "FileTable")), {})
		return
	if _frames < 12 or _dialog == null:
		return
	var image: Image = _dialog._dialog.get_texture().get_image()
	image.save_png("res://docs/images/engine-table-read.png")
	print("[preview] engine table read %dx%d" % [image.get_width(), image.get_height()])
	quit(0)
