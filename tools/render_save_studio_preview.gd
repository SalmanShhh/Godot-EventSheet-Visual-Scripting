# EventForge - visual render harness for the Save Studio window (dev tool).
# Instantiates EventSheetSaveStudio against a stub dock, runs a Format Preview and a
# generated save_state snippet, and screenshots all three tabs. Run NON-headless:
#   godot --path . --script tools/render_save_studio_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _studio: EventSheetSaveStudio = null
var _dock_stub: Control = null


func _init() -> void:
	root.title = "EventForge Save Studio Preview"
	root.size = Vector2i(880, 680)
	root.gui_embed_subwindows = true
	var background: ColorRect = ColorRect.new()
	background.color = Color("#2b2b2b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	_dock_stub = Control.new()
	_dock_stub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dock_stub.set_script(load("res://tools/render_save_studio_stub.gd"))
	root.add_child(_dock_stub)
	_studio = EventSheetSaveStudio.new()
	_studio.init(_dock_stub)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_studio.open()
	if _frames == 4:
		# Drive the Format Preview so the screenshot shows real save output.
		_studio._preview_addon_picker.selected = _pick_addon_index("Stat")
		_studio._preview_format_picker.selected = 1  # json
		_studio._run_format_preview()
		# Populate the generator tab too.
		_studio._support_path_edit.text = "res://eventsheet_addons/timer/timer_behavior.gd"
		_studio._scan_support_script()
		_studio._generate_support_code()
	if _frames == 8:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://_save_studio_preview.png")
		print("[save_studio_preview] saved res://_save_studio_preview.png (%dx%d)" % [image.get_width(), image.get_height()])
		# Flip to the Add Save Support tab for a second shot of the generator.
		var tabs: TabContainer = _studio._window.get_child(0).get_child(0)
		tabs.current_tab = 2
	if _frames < 12:
		return
	var support_image: Image = root.get_texture().get_image()
	support_image.save_png("res://_save_studio_support_preview.png")
	print("[save_studio_preview] saved res://_save_studio_support_preview.png (%dx%d)" % [support_image.get_width(), support_image.get_height()])
	quit(0)


func _pick_addon_index(needle: String) -> int:
	for i: int in range(_studio._preview_addon_picker.item_count):
		if _studio._preview_addon_picker.get_item_text(i).contains(needle):
			return i
	return 0
