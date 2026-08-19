# EventForge - render harness (dev tool) for the batch-seven reading words (R4 - R11).
# Writes a platformer script to user://, opens it as a sheet in reading mode and shoots it, so one
# run proves both the look (the image) and the words (the printed spans).
# Run NON-headless (headless runs cannot render):
#   godot --path . --script tools/render_batch7_words_preview.gd
@tool
extends SceneTree

const SOURCE_PATH: String = "user://eventforge_batch7_preview.gd"
const IMAGE_PATH: String = "res://docs/images/opened-script-words7.png"

const SOURCE: String = """extends CharacterBody2D

var hp: int = 3
var max_hp: int = 10
var last_shot: int = 0
var target_angle: float = 0.0

func _physics_process(delta: float) -> void:
	if is_on_floor():
		hp = 3
	if velocity.y < 0:
		hp = 4
	if 0 < hp and hp < max_hp:
		hp = 5
	if Time.get_ticks_msec() - last_shot > 500:
		last_shot = Time.get_ticks_msec()
	if abs(angle_difference(rotation, target_angle)) < deg_to_rad(10):
		hp = 6
	if position.distance_to(Vector2.ZERO) < 100:
		hp = 7
	if Rect2(0, 0, 640, 360).has_point(position):
		hp = 8
	if is_zero_approx(velocity.length()):
		hp = 9
	if position.x < 0 or position.x > get_viewport_rect().size.x:
		hp = 10
	if randf() < 0.3:
		hp = 11
	get_tree().paused = true
	Engine.time_scale = 0.5
	get_tree().change_scene_to_file("res://levels/level_2.tscn")
	get_tree().quit()
"""

var _frames: int = 0
var _shot_taken: bool = false
var _view: EventSheetViewport = null


func _init() -> void:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	root.title = "Opened script - batch seven words"
	root.size = Vector2i(1500, 1000)
	var modern_base := Color("#252525")
	var background := ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scroll)
	_view = EventSheetViewport.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_view)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	sheet.read_only = true
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = style
	_view.set_sheet(sheet)
	_view.set_reading_mode(true)
	root.gui_disable_input = true
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 12 or _shot_taken:
		return
	_shot_taken = true
	await process_frame
	var image: Image = root.get_texture().get_image()
	image.save_png(IMAGE_PATH)
	print("[batch7] %s  %dx%d" % [IMAGE_PATH, image.get_width(), image.get_height()])
	for index: int in range(_view._flat_rows.size()):
		_print_row(_view._flat_rows[index].get("row"), 0)
	quit(0)


func _print_row(row_data: EventRowData, depth: int) -> void:
	if row_data == null:
		return
	_view._row_builder._ensure_event_spans(row_data)
	if not row_data.spans.is_empty():
		var texts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			texts.append(span.text)
		print("  %s%s" % ["    ".repeat(depth), " | ".join(texts)])
	for child: EventRowData in row_data.children:
		_print_row(child, depth + 1)
