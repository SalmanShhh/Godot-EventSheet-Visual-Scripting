# EventForge - render harness (dev tool) for the sprite / UI / sound / game-feel reading.
# Shoots tests/fixtures/opened_script_batch8_media.gd with every head bar unfolded and writes
# docs/images/reading-sprite-sound-juice.png.
# Run NON-headless (headless runs cannot render):
#   godot --path . --script tools/render_sprite_sound_juice_preview.gd
@tool
extends SceneTree

const BASE_COLOR := Color("#252525")
const FIXTURE := "res://tests/fixtures/opened_script_batch8_media.gd"

var _frames: int = 0
var _view: EventSheetViewport = null


func _init() -> void:
	root.title = "Opened script reading - sprites, UI, sound and game feel"
	root.size = Vector2i(1140, 1180)
	var background: ColorRect = ColorRect.new()
	background.color = BASE_COLOR.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	_view = EventSheetViewport.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.set_ace_registry(EventSheetACERegistry.new())
	root.add_child(_view)
	_show()
	root.gui_disable_input = true
	process_frame.connect(_on_frame)


func _show() -> void:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE)
	sheet.read_only = true
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(
		style, BASE_COLOR, BASE_COLOR.darkened(0.15), BASE_COLOR.darkened(0.25),
		Color("#569eff"), Color("#ced0d2")
	)
	sheet.editor_style = style
	for pass_index: int in 4:
		_view.set_sheet(sheet)
		_view.set_reading_mode(true)
		_view._get_event_style().condition_lane_ratio = 0.32
		for entry: Variant in _view._flat_rows:
			var row_data: EventRowData = (entry as Dictionary).get("row")
			if row_data != null and not row_data.children.is_empty():
				_view._fold_state[row_data.row_uid] = false
	# The variables folder stays closed: this figure is about the ROWS, and the screen cannot hold
	# both. The head still says what the file is.
	for entry: Variant in _view._flat_rows:
		var head_row: EventRowData = (entry as Dictionary).get("row")
		if head_row != null and not head_row.spans.is_empty() \
				and head_row.spans[0].text.contains("Instance variables"):
			_view._fold_state[head_row.row_uid] = true
	_view.set_sheet(sheet)
	_view.set_reading_mode(true)
	_print_rows()


func _on_frame() -> void:
	_frames += 1
	if _frames < 12:
		return
	var image: Image = root.get_texture().get_image()
	var scale: float = float(image.get_width()) / maxf(float(root.size.x), 1.0)
	var content: float = 0.0
	for index in range(_view._flat_rows.size()):
		content = maxf(content, _view._row_metrics_helper.row_top(index) + _view._row_metrics_helper.row_height(index))
	var height: int = clampi(int(content * scale) + 4, 1, image.get_height())
	image.get_region(Rect2i(0, 0, image.get_width(), height)).save_png("res://docs/images/reading-sprite-sound-juice.png")
	print("[preview] sprite sound juice %dx%d" % [image.get_width(), height])
	quit(0)


## Prints what the sheet actually READS as, so a run doubles as a text check.
func _print_rows() -> void:
	for entry: Variant in _view._flat_rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data == null:
			continue
		var texts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			texts.append(span.text)
		print("  row: [%s]" % " | ".join(texts).substr(0, 200))
