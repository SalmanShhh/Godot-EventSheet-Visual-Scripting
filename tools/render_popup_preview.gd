# EventForge — visual render harness for the shared popup layout (dev tool). Builds a dialog with
# EventSheetPopupUI form rows (as the group editor now does) and saves a PNG. Run NON-headless:
#   godot --path . --script tools/render_popup_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _dialog: ConfirmationDialog = null

func _init() -> void:
	root.title = "Popup Preview"
	root.size = Vector2i(540, 320)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#252525")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_dialog = ConfirmationDialog.new()
		_dialog.title = "Edit Group"
		_dialog.ok_button_text = "Apply"
		_dialog.min_size = Vector2i(420, 0)
		var box: VBoxContainer = EventSheetPopupUI.form_box()
		var name_edit: LineEdit = LineEdit.new()
		name_edit.placeholder_text = "Group name"
		box.add_child(EventSheetPopupUI.form_row("Name", name_edit))
		var desc_edit: TextEdit = TextEdit.new()
		desc_edit.custom_minimum_size = Vector2(0.0, 80.0)
		desc_edit.placeholder_text = "Shown as a muted second line on the group header."
		box.add_child(EventSheetPopupUI.form_row("Description", desc_edit))
		_dialog.add_child(EventSheetPopupUI.margined(box))
		root.add_child(_dialog)
		_dialog.popup_centered()
		return
	if _frames < 8 or _dialog == null:
		return
	var image: Image = _dialog.get_texture().get_image()
	image.save_png("res://_popup_preview.png")
	print("[popup_preview] saved res://_popup_preview.png (%dx%d)" % [image.get_width(), image.get_height()])
	quit(0)
