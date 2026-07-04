# EventForge - render harness (dev tool) for the themed ACE params dialog. Builds a 2-parameter
# ACE and opens the dialog so the sunken form card + per-param descriptions can be eyeballed and
# the dialog confirmed not to balloon. Run NON-headless:
#   godot --path . --script tools/render_themed_ace_params.gd
@tool
extends SceneTree

var _frames: int = 0
var _dialog: ACEParamsDialog = null


func _init() -> void:
	root.title = "Themed ACE Params"
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
		d.display_name = "Apply Damage"
		d.parameters = [
			{"id": "amount", "display_name": "Amount", "default_value": "10",
				"description": "How much health to subtract from the target each time this runs."},
			{"id": "target", "display_name": "Target", "default_value": "%Enemy",
				"description": "The node to damage - drag a scene node onto the field or pick one."},
		]
		_dialog.open(d, {})
		return
	if _frames < 9 or _dialog == null:
		return
	var img: Image = _dialog._dialog.get_texture().get_image()
	img.save_png("res://_themed_ace_params.png")
	print("[themed] ace params %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
