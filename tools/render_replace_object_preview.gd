# EventForge - render harness (dev tool) for the Replace Object References dialog: the
# from-dropdown filled with references a selection actually uses, the to-field ready.
# Run NON-headless:
#   godot --path . --script tools/render_replace_object_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _dialog: AcceptDialog = null


func _init() -> void:
	root.title = "Replace Object"
	root.size = Vector2i(560, 360)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_dialog = AcceptDialog.new()
		_dialog.title = "Replace Object References"
		_dialog.ok_button_text = "Replace"
		var content: VBoxContainer = VBoxContainer.new()
		content.add_theme_constant_override("separation", 8)
		content.add_child(EventSheetPopupUI.hint_label("Every matching reference across the 6 selected row(s) rewrites - params, With-Node scopes, pick filters, and GDScript blocks. Token-safe: $Enemy never touches $EnemySpawner.", 420.0))
		var from_options: OptionButton = OptionButton.new()
		for reference: String in ["$Enemy", "$EnemySpawner", "%HealthBar", "self"]:
			from_options.add_item(reference)
		content.add_child(EventSheetPopupUI.form_row("From", from_options))
		var to_edit: LineEdit = LineEdit.new()
		to_edit.text = "$EliteEnemy"
		to_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(EventSheetPopupUI.form_row("To", to_edit))
		_dialog.add_child(EventSheetPopupUI.titled_card("Retarget the selection", content))
		root.add_child(_dialog)
		_dialog.popup_centered(Vector2i(480, 260))
		return
	if _frames < 9 or _dialog == null:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/replace-object.png")
	print("[preview] replace object %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
