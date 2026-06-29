# EventForge — visual probe for the Variable dialog's Tier 3 drawer picker + live preview (dev tool).
# Opens the dialog pre-set to a Vector2 variable using the direction-dial drawer, so the per-type picker and
# the live "what the drawer looks like" preview can be eyeballed. Run NON-headless (needs a renderer):
#   godot --path . --script tools/render_variable_drawer_dialog.gd
@tool
extends SceneTree

var _frames: int = 0
var _dlg: VariableDialog = null

func _init() -> void:
	root.title = "Variable Dialog — drawer preview"
	root.size = Vector2i(620, 660)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#202024")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	_dlg = VariableDialog.new()
	_dlg.init_dialog(root)
	_dlg.set_sheet_provider(func() -> Variant: return null)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_dlg.open_for_edit(
			"tree",
			{"editing": true, "attributes": {"drawer": "vector_dial", "range": {"min": "0", "max": "150"}}},
			"aim_direction", "Vector2", Vector2(0.0, 0.0), false, "Edit variable — drawer preview", false, true
		)
		return
	if _frames < 14:
		return
	var image: Image = root.get_texture().get_image()
	image.save_png("res://_variable_drawer_dialog.png")
	print("[variable_drawer_dialog] saved res://_variable_drawer_dialog.png (%dx%d)" % [image.get_width(), image.get_height()])
	quit(0)
