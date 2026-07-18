# EventForge - render harness (dev tool) for the bbcode_text rich param: opens the params
# dialog on Print Rich with a formatted value, so the B/I/U/S toolbar and the live rendered
# preview under the field can be eyeballed. Run NON-headless:
#   godot --path . --script tools/render_bbcode_param_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _dialog: ACEParamsDialog = null


func _init() -> void:
	root.title = "BBCode Param"
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
		d.display_name = "Print Rich (BBCode)"
		d.parameters = [
			{"id": "value", "display_name": "Value", "default_value": "\"[b]Boss[/b] down - [color=yellow]+250[/color] [i]bonus[/i]\"",
				"description": "BBCode string (colors/bold) for the Output console. Select text and hit B / I / U / S to format it.", "hint": "bbcode_text"},
		]
		_dialog.open(d, {})
		return
	if _frames < 9 or _dialog == null:
		return
	var img: Image = _dialog._dialog.get_texture().get_image()
	img.save_png("res://docs/images/bbcode-param.png")
	print("[preview] bbcode param %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
