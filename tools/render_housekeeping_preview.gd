# EventForge - render harness (dev tool) for the Housekeeping dialog. Run NON-headless.
#
#   godot --path . --script tools/render_housekeeping_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _dialog: EventSheetDocsHousekeepingDialog = null


func _init() -> void:
	var root: Window = get_root()
	root.size = Vector2i(820, 700)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_dialog = EventSheetDocsHousekeepingDialog.new()
		get_root().add_child(_dialog)
		_dialog.popup_centered(Vector2i(760, 640))
		return
	if _frames == 12:
		var image: Image = get_root().get_texture().get_image()
		image.save_png("res://docs/images/docs-housekeeping.png")
		print("[preview] housekeeping %dx%d" % [image.get_width(), image.get_height()])
		quit(0)
