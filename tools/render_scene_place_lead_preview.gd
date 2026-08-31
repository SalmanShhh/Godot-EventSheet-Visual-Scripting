# EventForge - render harness (dev tool) for the Save Branch As Scene File parameters dialog: the
# place lead sitting under the Save To box, which is what the files pass's `file_path` hint buys a
# new row for free. The picture exists because the lead is the sentence a reader meets BEFORE they
# meet the export trap, and a row that writes a level the player built is exactly the row that would
# otherwise have been aimed at res://.
#
# Run NON-headless (a headless run cannot render):
#   godot --path . --script tools/render_scene_place_lead_preview.gd
@tool
extends SceneTree

const OUTPUT_PATH: String = "res://docs/images/scenes-save-place-lead.png"

var _frames: int = 0
var _dialog: ACEParamsDialog = null


func _init() -> void:
	root.title = "Save To"
	root.size = Vector2i(760, 560)
	root.gui_embed_subwindows = true
	var background: ColorRect = ColorRect.new()
	background.color = Color("#2b2b2b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		var registry: EventSheetACERegistry = EventSheetACERegistry.new()
		registry.refresh_from_sources([])
		var definition: ACEDefinition = registry.find_definition("Core", "SaveBranchAsSceneFile")
		_dialog = ACEParamsDialog.new()
		_dialog.init_dialog(root)
		_dialog.params_confirmed.connect(
			func(_d: ACEDefinition, _v: Dictionary, _c: Dictionary) -> void: pass)
		_dialog.open_with_values(definition, {},
			{"branch": "$Level", "path": "\"user://built_level.tscn\""})
		return
	if _frames < 10 or _dialog == null:
		return
	var image: Image = root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	print("[preview] scene save place lead %dx%d" % [image.get_width(), image.get_height()])
	quit(0)
