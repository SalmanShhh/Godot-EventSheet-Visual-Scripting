# EventForge - render harness (dev tool) for the batch-9 behavior shapes: a projectile, a turret, a
# glide to a point, and the five one-liners (spin, wrap, bound, pin, fade), each read with the
# shipped behavior's own words.
# Shoots tests/fixtures/opened_script_batch9_behaviors.gd and writes
# docs/images/opened-script-behaviors.png.
# Run NON-headless (headless runs cannot render):
#   godot --path . --script tools/render_opened_script_behaviors_preview.gd
@tool
extends SceneTree

const BASE_COLOR := Color("#252525")
const FIXTURE := "res://tests/fixtures/opened_script_batch9_behaviors.gd"

var _frames: int = 0
var _view: EventSheetViewport = null


func _init() -> void:
	root.title = "Opened script reading - the hand-rolled behavior shapes"
	root.size = Vector2i(1180, 1500)
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
		_view._get_event_style().condition_lane_ratio = 0.30
		for entry: Variant in _view._flat_rows:
			var row_data: EventRowData = (entry as Dictionary).get("row")
			if row_data != null and not row_data.children.is_empty():
				_view._fold_state[row_data.row_uid] = false
	# The variables folder is twenty rows of head; the point of this image is the events under it, and
	# a window only renders what fits on the screen. So it goes back to collapsed for the shot.
	for entry: Variant in _view._flat_rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data == null:
			continue
		for span: SemanticSpan in row_data.spans:
			if span.text.strip_edges() == "Instance variables":
				_view._fold_state[row_data.row_uid] = true
	_view.set_sheet(sheet)
	_view.set_reading_mode(true)
	_print_rows()


func _on_frame() -> void:
	_frames += 1
	# Two shots, because a window only renders what fits on the screen and these readings are two
	# screens tall: the projectile and the turret first, then the five one-liners.
	if _frames == 12:
		_shoot("Set angle of motion", "res://docs/images/opened-script-behaviors.png")
		# The canvas is anchored full-rect, so pulling its top edge up scrolls it without a container.
		_view.offset_top = -_row_top("Rotate clockwise") + 40.0
		return
	if _frames < 24:
		return
	_shoot("Rotate clockwise", "res://docs/images/opened-script-behaviors-one-liners.png")
	quit(0)


## The y of the first row whose words contain `needle`, in canvas coordinates.
func _row_top(needle: String) -> float:
	for index in range(_view._flat_rows.size()):
		var row_data: EventRowData = (_view._flat_rows[index] as Dictionary).get("row")
		if row_data == null:
			continue
		var head: String = ""
		for span: SemanticSpan in row_data.spans:
			head += span.text
		if head.contains(needle):
			return _view._row_metrics_helper.row_top(maxi(index - 1, 0))
	return 0.0


## Saves the window from the row that names `needle` down to the last row that rendered.
func _shoot(needle: String, path: String) -> void:
	var image: Image = root.get_texture().get_image()
	var scale: float = float(image.get_width()) / maxf(float(root.size.x), 1.0)
	var top: float = maxf(_row_top(needle) + _view.offset_top - 24.0, 0.0)
	var start: int = clampi(int(top * scale), 0, image.get_height() - 1)
	# Stop at the last row rather than at the bottom of the window, so the picture has no dead space.
	var content: float = 0.0
	for index in range(_view._flat_rows.size()):
		content = maxf(content,
			_view._row_metrics_helper.row_top(index) + _view._row_metrics_helper.row_height(index))
	var bottom: int = clampi(int((content + _view.offset_top) * scale) + 6, start + 1, image.get_height())
	var height: int = bottom - start
	image.get_region(Rect2i(0, start, image.get_width(), height)).save_png(path)
	print("[preview] %s %dx%d from %d" % [path.get_file(), image.get_width(), height, start])


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
