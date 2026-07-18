# EventForge - render harness (dev tool) for the Platform Has Feature suggest combo: the
# params dialog opens on the real registry definition and pops the tag suggestions. Run
# NON-headless:
#   godot --path . --script tools/render_feature_tags_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _dialog: ACEParamsDialog = null


func _init() -> void:
	root.title = "Feature Tags"
	root.size = Vector2i(660, 560)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		var registry: EventSheetACERegistry = EventSheetACERegistry.new()
		registry.refresh_from_sources([])
		var definition: ACEDefinition = registry.find_definition("Core", "HasOSFeature")
		_dialog = ACEParamsDialog.new()
		_dialog.init_dialog(root)
		_dialog.open(definition, {})
		return
	if _frames == 6:
		for menu_button: Node in _dialog._dialog.find_children("", "MenuButton", true, false):
			var popup: PopupMenu = (menu_button as MenuButton).get_popup()
			popup.about_to_popup.emit()
			popup.position = Vector2i((menu_button as MenuButton).get_screen_position() + Vector2(-140.0, 28.0))
			popup.reset_size()
			popup.popup()
		return
	if _frames < 14 or _dialog == null:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/feature-tags.png")
	print("[preview] feature tags %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
