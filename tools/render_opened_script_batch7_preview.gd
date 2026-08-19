# EventForge - render harness (dev tool) for batch 7 of the opened-script reading: the cursor, the
# click and the gamepad cable on their own objects, a one-line tween chain, a node-scoped snap setter
# and the Inspector button as a setting row.
# Shoots tests/fixtures/opened_script_batch7.gd with every head bar unfolded and writes
# docs/images/opened-script-batch7.png.
# Run NON-headless (headless runs cannot render):
#   godot --path . --script tools/render_opened_script_batch7_preview.gd
@tool
extends SceneTree

const BASE_COLOR := Color("#252525")
const FIXTURE := "res://tests/fixtures/opened_script_batch7.gd"

var _frames: int = 0
var _view: EventSheetViewport = null


func _init() -> void:
	root.title = "Opened script reading - batch 7"
	root.size = Vector2i(1140, 680)
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
	# Every fold opened, a level per pass - the point of the image is the words inside them, and a
	# child row only appears in the flat list once its parent is open.
	for pass_index: int in 4:
		_view.set_sheet(sheet)
		_view.set_reading_mode(true)
		# The action lane carries the longest sentences here, so the divider sits left of centre.
		_view._get_event_style().condition_lane_ratio = 0.32
		for entry: Variant in _view._flat_rows:
			var row_data: EventRowData = (entry as Dictionary).get("row")
			if row_data != null and not row_data.children.is_empty():
				_view._fold_state[row_data.row_uid] = false
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
	image.get_region(Rect2i(0, 0, image.get_width(), height)).save_png("res://docs/images/opened-script-batch7.png")
	print("[preview] opened script batch 7 %dx%d" % [image.get_width(), height])
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
