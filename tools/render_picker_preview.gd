# EventForge — visual render harness for the ACE picker dialog (dev tool, not shipped logic).
# Opens the picker with seeded Favorites + Recent and saves a PNG so the Create-Node-parity
# layout can be inspected. Run NON-headless (needs a real renderer):
#   godot --path . --script tools/render_picker_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _picker: ACEPickerDialog = null

func _init() -> void:
	root.title = "ACE Picker Preview"
	root.size = Vector2i(900, 640)
	root.gui_embed_subwindows = true
	var background: ColorRect = ColorRect.new()
	background.color = Color("#252525")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frames += 1
	# Defer picker setup until the tree is live (avoids is_inside_tree on grab_focus).
	if _frames == 2:
		var registry: EventSheetACERegistry = EventSheetACERegistry.new()
		var no_sources: Array[Object] = []
		registry.refresh_from_sources(no_sources, true)
		ProjectSettings.set_setting("eventsheets/picker/favorites", PackedStringArray(["Core/Wait", "Core/MoveAndSlide"]))
		ACEPickerDialog.note_recent("Core", "AddVar")
		ACEPickerDialog.note_recent("Core", "IsOnFloor")
		_picker = ACEPickerDialog.new()
		_picker.init_dialog(root, registry)
		_picker.open("append_action", false, null)
		return
	if _frames < 10 or _picker == null or _picker._window == null:
		return
	var image: Image = _picker._window.get_texture().get_image()
	image.save_png("res://_picker_preview.png")
	print("[picker_preview] saved res://_picker_preview.png (%dx%d)" % [image.get_width(), image.get_height()])
	quit(0)
