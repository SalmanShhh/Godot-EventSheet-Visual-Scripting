# EventForge - render harness (dev tool) for batch 5 of the opened-script HEAD: the reading-coverage
# chip, the Inspector facts on setting rows, and the Globals head of an autoload.
# Shoots three previews and stacks them into one image:
#   tests/fixtures/opened_script_coverage.gd - the chip with its script-block count
#   tests/fixtures/opened_script_settings.gd - range / combo / percent / file / folder / colour rows
#   tests/fixtures/opened_script_settings.gd, opened AS an autoload - the Globals head
# Writes docs/images/opened-script-head5.png.
# Run NON-headless (headless runs cannot render):
#   godot --path . --script tools/render_opened_script_head5_preview.gd
@tool
extends SceneTree

const BASE_COLOR := Color("#252525")

var _stages: Array = [
	{"path": "res://tests/fixtures/opened_script_coverage.gd", "autoload": false},
	{"path": "res://tests/fixtures/opened_script_settings.gd", "autoload": false},
	{"path": "res://tests/fixtures/opened_script_settings.gd", "autoload": true},
]
var _frames: int = 0
var _stage: int = 0
var _shots: Array[Image] = []
var _view: EventSheetViewport = null


func _init() -> void:
	root.title = "Opened script head - batch 5"
	root.size = Vector2i(1360, 460)
	var background: ColorRect = ColorRect.new()
	background.color = BASE_COLOR.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	_view = EventSheetViewport.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.set_ace_registry(EventSheetACERegistry.new())
	root.add_child(_view)
	_show(_stages[0])
	root.gui_disable_input = true
	process_frame.connect(_on_frame)


## One opened script, with every head bar unfolded - a preview folds them closed, and the point of
## this image is the words inside them.
func _show(stage: Dictionary) -> void:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(str(stage["path"]))
	sheet.read_only = true
	if bool(stage["autoload"]):
		sheet.autoload_mode = true
		sheet.autoload_name = "Game"
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(
		style, BASE_COLOR, BASE_COLOR.darkened(0.15), BASE_COLOR.darkened(0.25),
		Color("#569eff"), Color("#ced0d2")
	)
	sheet.editor_style = style
	_view.set_sheet(sheet)
	_view.set_reading_mode(true)
	for entry: Variant in _view._flat_rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data != null and row_data.row_type == EventRowData.RowType.GROUP:
			_view._fold_state[row_data.row_uid] = false
	_view.set_sheet(sheet)
	_view.set_reading_mode(true)
	_print_head_rows()


func _on_frame() -> void:
	_frames += 1
	if _frames < 12:
		return
	_frames = 0
	_shots.append(_cropped_shot())
	_stage += 1
	if _stage < _stages.size():
		_show(_stages[_stage])
		return
	_stack_and_save()
	quit(0)


## The window shot, trimmed to the rows that actually drew.
func _cropped_shot() -> Image:
	var image: Image = root.get_texture().get_image()
	var scale: float = float(image.get_width()) / maxf(float(root.size.x), 1.0)
	var content: float = 0.0
	for index in range(_view._flat_rows.size()):
		content = maxf(content, _view._row_metrics_helper.row_top(index) + _view._row_metrics_helper.row_height(index))
	var height: int = clampi(int(content * scale) + 4, 1, image.get_height())
	return image.get_region(Rect2i(0, 0, image.get_width(), height))


func _stack_and_save() -> void:
	var width: int = 0
	var height: int = 0
	for shot: Image in _shots:
		width = maxi(width, shot.get_width())
		height += shot.get_height() + 12
	var canvas: Image = Image.create_empty(width, height, false, _shots[0].get_format())
	canvas.fill(BASE_COLOR.darkened(0.4))
	var offset: int = 0
	for shot: Image in _shots:
		canvas.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i(0, offset))
		offset += shot.get_height() + 12
	canvas.save_png("res://docs/images/opened-script-head5.png")
	print("[preview] opened script head batch 5 %dx%d" % [canvas.get_width(), canvas.get_height()])


## Prints what each head actually READS as, so a run doubles as a text check.
func _print_head_rows() -> void:
	for entry: Variant in _view._flat_rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data == null:
			continue
		var texts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			texts.append(span.text)
		print("  head: [%s]" % " | ".join(texts).substr(0, 160))
