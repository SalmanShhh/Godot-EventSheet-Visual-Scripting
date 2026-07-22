# EventForge - visual render harness (dev tool) for the ACE Studio ("Define a Verb")
# guide image. Builds the real dialog filled in with a concrete example (a Take Damage
# action with an amount parameter, a guard, and published to the Combat category) so the
# live preview and the "Ships as" line show a realistic signature. Run NON-headless:
#   godot --path . --script tools/render_ace_studio_example.gd
@tool
extends SceneTree

var _frames: int = 0
var _dialog: EventSheetFunctionDialog = null


func _init() -> void:
	root.title = "ACE Studio Example"
	root.size = Vector2i(720, 760)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_dialog = EventSheetFunctionDialog.new()
		_dialog.set_taken_names_provider(func() -> PackedStringArray: return PackedStringArray())
		_dialog.init_dialog(root)
		_dialog.open()
		# A concrete Action verb: Take Damage(amount: float), guarded, published to Combat.
		_dialog._name_edit.text = "Take Damage"
		_dialog._description_edit.text = "Subtract an amount of health and react to it."
		_dialog._expose_check.button_pressed = true
		_dialog._expose_card.visible = true
		_dialog._expose_category_edit.text = "Combat"
		_dialog._refresh_studio()
		return
	if _frames == 8 and _dialog != null:
		var image: Image = _dialog._dialog.get_texture().get_image()
		# Crop to the authoring content (the dialog reserves extra height for its buttons).
		var cropped: Image = image.get_region(Rect2i(0, 0, mini(580, image.get_width()), mini(748, image.get_height())))
		cropped.save_png("res://_ace_studio_example.png")
		print("[ace_studio_example] saved res://_ace_studio_example.png (%dx%d)" % [cropped.get_width(), cropped.get_height()])
		quit(0)
