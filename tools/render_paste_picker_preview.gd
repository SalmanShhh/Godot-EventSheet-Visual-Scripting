# EventForge - render harness (dev tool) for the Drawing Canvas Paste verbs in the ACE picker. Loads the
# drawing_canvas pack as a provider source (builtins included) and pre-filters the picker to "Paste" so the
# four new actions read as first-class picker rows. Run NON-headless:
#   godot --path . --script tools/render_paste_picker_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _picker: ACEPickerDialog = null


func _init() -> void:
	root.title = "Paste verbs in the picker"
	root.size = Vector2i(900, 640)
	root.gui_embed_subwindows = true
	var background: ColorRect = ColorRect.new()
	background.color = Color("#252525")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		var registry: EventSheetACERegistry = EventSheetACERegistry.new()
		var provider: Object = load("res://eventsheet_addons/drawing_canvas/drawing_canvas_behavior.gd").new()
		var sources: Array[Object] = [provider]
		registry.refresh_from_sources(sources, true)   # true = also include the builtin vocabulary
		_picker = ACEPickerDialog.new()
		_picker.init_dialog(root, registry)
		_picker.open("append_action", false, null)
		return
	if _frames == 4 and _picker != null:
		_picker._search.text = "Paste"
		_picker._search.text_changed.emit("Paste")
		return
	if _frames < 9 or _picker == null or _picker._window == null:
		return
	var image: Image = _picker._window.get_texture().get_image()
	image.save_png("res://docs/images/paste-picker.png")
	print("[paste_picker] saved (%dx%d)" % [image.get_width(), image.get_height()])
	quit(0)
