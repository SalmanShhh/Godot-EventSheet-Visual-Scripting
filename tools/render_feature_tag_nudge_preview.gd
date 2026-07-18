# EventForge - render harness (dev tool) for the unknown-feature-tag nudge: the Platform
# Has Feature dialog commits a tag no preset defines, and the Add-To-Preset(s) / Keep-As-Is
# confirmation pops over it. Run NON-headless:
#   godot --path . --script tools/render_feature_tag_nudge_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _dialog: ACEParamsDialog = null


func _init() -> void:
	root.title = "Feature Tag Nudge"
	root.size = Vector2i(720, 560)
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
		_dialog.params_confirmed.connect(func(_d: ACEDefinition, _v: Dictionary, _c: Dictionary) -> void: pass)
		_dialog.open_with_values(definition, {}, {"feature": "\"vr_build\""})
		return
	if _frames == 6:
		_dialog._on_confirmed()
		return
	if _frames < 14 or _dialog == null:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/feature-tag-nudge.png")
	print("[preview] feature tag nudge %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
