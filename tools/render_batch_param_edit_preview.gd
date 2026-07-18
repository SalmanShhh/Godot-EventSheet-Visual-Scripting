# EventForge - render harness (dev tool) for the batch param edit dialog: the ACE params
# dialog opened in batch_edit_params mode, so the "applies to all N matching actions" hint
# line can be eyeballed. Run NON-headless:
#   godot --path . --script tools/render_batch_param_edit_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _dialog: ACEParamsDialog = null


func _init() -> void:
	root.title = "Batch Param Edit"
	root.size = Vector2i(660, 520)
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
		var d: ACEDefinition = ACEDefinition.new()
		d.display_name = "Log"
		d.parameters = [
			{"id": "message", "display_name": "Message", "default_value": "\"hello\"",
				"description": "Value/expression to write to the console."},
			{"id": "level", "display_name": "As", "default_value": "print",
				"description": "Which console stream to write to."},
		]
		_dialog.open_with_values(d, {
			"mode": "batch_edit_params",
			"batch_kind": "action",
			"batch_count": 7
		}, {"message": "\"wave started\"", "level": "print"})
		return
	if _frames < 9 or _dialog == null:
		return
	var img: Image = _dialog._dialog.get_texture().get_image()
	img.save_png("res://docs/images/batch-param-edit.png")
	print("[preview] batch param edit %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
