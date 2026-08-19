# EventForge - render harness (dev tool) for the PROJECT-LEVEL surfaces:
#   docs/images/project-bar.png       - the Project bar tab of the Object bar
#   docs/images/beginner-toolbar.png  - the Add toolbar with the Preview buttons
# Each run also PRINTS what it drew, so it doubles as a text check: the image proves the look, the
# printout proves the words.
#
# Run NON-headless (headless runs cannot render, and have no editor theme to draw from):
#   godot --path . --script tools/render_project_level_ux_preview.gd
@tool
extends SceneTree

const BASE_COLOR := Color("#252525")

var _frames: int = 0
var _stage: int = 0
var _bar: EventSheetObjectsPanel = null
var _project_bar: EventSheetProjectBar = null
var _strip: HFlowContainer = null


func _init() -> void:
	root.title = "Project bar, Add toolbar"
	root.size = Vector2i(1000, 620)
	root.gui_embed_subwindows = true
	var background: ColorRect = ColorRect.new()
	background.color = BASE_COLOR.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	_build_project_bar_stage()
	root.gui_disable_input = true
	process_frame.connect(_on_frame)


## Stage 1 - the Object bar with its Project tab selected, built by the same panel the dock builds,
## so the image cannot show a bar the editor would not.
func _build_project_bar_stage() -> void:
	_bar = EventSheetObjectsPanel.new()
	_bar.position = Vector2(8.0, 8.0)
	_bar.size = Vector2(380.0, 560.0)
	root.add_child(_bar)
	_bar.set_expanded(true)
	_project_bar = EventSheetProjectBar.new()
	_bar.set_project_bar(_project_bar)
	_bar.set_active_tab("project")
	_project_bar.set_reading_prefs(false, true)
	_project_bar.set_expanded(true)
	print("[preview] Project bar - tab %s" % _bar.active_tab())
	var outline: Dictionary = _project_bar.outline()
	for kind: String in EventSheetProjectOutline.KIND_ORDER:
		var entries: Array = outline.get(kind, [])
		if entries.is_empty():
			continue
		print("  section: %s  (%d)" % [EventSheetProjectOutline.heading_for(kind, false), entries.size()])
		for index: int in mini(entries.size(), 6):
			print("    %s" % EventSheetProjectBar.entry_text(entries[index]))


## Stage 2 - the beginner Add toolbar, built from the same table the dock builds it from, with each
## button's hover text (which is where the key it stands in for is taught).
func _build_toolbar_stage() -> void:
	_clear_stage()
	_strip = HFlowContainer.new()
	_strip.position = Vector2(12.0, 12.0)
	_strip.size = Vector2(960.0, 80.0)
	_strip.add_theme_constant_override("h_separation", 4)
	root.add_child(_strip)
	print("[preview] Add toolbar")
	for entry: Variant in EventSheetBeginnerToolbar.BUTTONS:
		var record: Array = entry
		var button := Button.new()
		button.text = str(record[1])
		_strip.add_child(button)
		print("  %s   %s" % [str(record[1]), EventSheetBeginnerToolbar.tooltip_for(str(record[0]))])
	_strip.add_child(VSeparator.new())
	for entry: Variant in EventSheetRunControls.BUTTONS:
		var record: Array = entry
		var button := Button.new()
		button.text = str(record[1])
		_strip.add_child(button)
		print("  %s   %s" % [str(record[1]), str(record[2])])
	print("  while a game is running: %s / %s" % [
		EventSheetRunControls.label_for("preview_layout", true),
		EventSheetRunControls.label_for("preview_project", true)])


func _clear_stage() -> void:
	for child: Node in Array(root.get_children()):
		if child is ColorRect:
			continue
		root.remove_child(child)
		child.queue_free()
	_bar = null
	_project_bar = null


func _on_frame() -> void:
	_frames += 1
	if _frames < 14:
		return
	_frames = 0
	match _stage:
		0:
			_save("res://docs/images/project-bar.png", _bar)
			_build_toolbar_stage()
		1:
			_save("res://docs/images/beginner-toolbar.png", _strip)
			quit(0)
	_stage += 1


func _save(path: String, crop_to: Control = null) -> void:
	var image: Image = root.get_texture().get_image()
	if crop_to != null:
		var scale: float = float(image.get_width()) / maxf(float(root.size.x), 1.0)
		var margin: float = 8.0
		var region := Rect2i(
			Vector2i((crop_to.position - Vector2(margin, margin)) * scale),
			Vector2i((crop_to.size + Vector2(margin, margin) * 2.0) * scale)
		)
		region = region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		if region.has_area():
			image = image.get_region(region)
	image.save_png(path)
	print("[preview] wrote %s (%dx%d)" % [path, image.get_width(), image.get_height()])
