# EventForge - visual render harness (dev tool) for the ACE Studio ("Define a Verb")
# guide image. Builds the real dialog filled in with a concrete example (a Take Damage
# action published to the Combat category) so the live preview and the "Ships as" line
# show a realistic signature. Parameters and guards are NOT authored here - the dialog no
# longer carries either; a parameter is a cell on the verb's row. Run NON-headless:
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
		# A concrete Action verb: Take Damage, published to Combat. Its doc comment shows as the
		# authoring detail a real verb carries; parameters live on the verb's row, not here.
		_dialog._name_edit.text = "Take Damage"
		_dialog._doc_comment_edit.text = "Subtract an amount of health and react to it."
		_dialog._description_edit.text = "Deals damage to this object."
		_dialog._expose_check.button_pressed = true
		_dialog._expose_card.visible = true
		_dialog._expose_category_edit.text = "Combat"
		_dialog._refresh_studio()
		return
	if _frames == 4 and _dialog != null:
		# Snug the window to its content so the buttons sit under the publish card, not below a band of
		# dead space (removing the two cards left the min height taller than the content needs).
		_dialog._dialog.size = _dialog._dialog.get_contents_minimum_size()
		return
	if _frames == 10 and _dialog != null:
		var image: Image = _dialog._dialog.get_texture().get_image()
		image.get_region(Rect2i(0, 0, mini(580, image.get_width()), image.get_height())).save_png("res://docs/images/ace-studio-example.png")
		print("[ace_studio_example] saved docs/images/ace-studio-example.png (%dx%d)" % [image.get_width(), image.get_height()])
		quit(0)
