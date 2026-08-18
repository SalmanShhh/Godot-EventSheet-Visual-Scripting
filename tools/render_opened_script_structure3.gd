# EventForge - render harness (dev tool) for the THIRD batch of event-sheet habits, on a hand-written
# script nobody wrote for the plugin (tests/fixtures/opened_script_structure3.gd + its .tscn):
#
#   M36  a For-each over a group whose whole body is one `if` reads as one event on that object
#   M37  a `match` on a plain value reads as the if / else-if / else chain
#   M39  instantiate + add_child + position reads as System > Create object
#   M42  the two handlers the SCENE wires read as the triggers they are
#
# Writes docs/images/opened-script-structure3.png. Run NON-headless (headless cannot render):
#   godot --path . --script tools/render_opened_script_structure3.gd
@tool
extends SceneTree

const FIXTURE_PATH: String = "res://tests/fixtures/opened_script_structure3.gd"

var _frames: int = 0
var _viewport: EventSheetViewport = null
var _scroll: ScrollContainer = null
var _sheet: EventSheetResource = null


func _init() -> void:
	root.title = "Opened script - event-sheet habits"
	root.size = Vector2i(1500, 820)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	_scroll.add_child(_viewport)
	_sheet = GDScriptImporter.new().import_external(FIXTURE_PATH)
	# The dock opens a .gd as a read-only preview; the importer leaves the flag alone.
	_sheet.read_only = true
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	_sheet.editor_style = style
	_viewport.set_sheet(_sheet)
	_viewport.set_reading_mode(true)
	# Every bar folds closed by default, and unfolding one is what reveals the next.
	for _pass: int in 4:
		for entry: Dictionary in _viewport.get_flat_rows():
			var row_data: EventRowData = entry.get("row")
			if row_data != null and not row_data.row_uid.is_empty():
				_viewport._fold_state[row_data.row_uid] = false
		_viewport.set_sheet(_sheet)
	root.gui_disable_input = true
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 12:
		return
	if _scroll.scroll_vertical == 0:
		# The shot opens on the first trigger, so the scene-wired triggers and the three readings
		# under Helpers share one frame; the file's head is what a reader scrolls past anyway.
		_scroll.scroll_vertical = int(_first_trigger_top())
		_frames = 0
		return
	var image: Image = root.get_texture().get_image()
	image.save_png("res://docs/images/opened-script-structure3.png")
	print("[preview] opened script structure3 %dx%d" % [image.get_width(), image.get_height()])
	print("[preview] round-trips: %s" % str(
		str(SheetCompiler.new().compile(_sheet).get("output", "")) == FileAccess.get_file_as_string(FIXTURE_PATH)))
	_print_rows()
	quit(0)


## The scroll offset that puts the first lifted trigger at the top of the frame.
func _first_trigger_top() -> float:
	for index in range(_viewport._flat_rows.size()):
		var row_data: EventRowData = _viewport._flat_rows[index].get("row")
		if row_data == null or not (row_data.source_resource is EventRow):
			continue
		return maxf(_viewport._row_metrics_helper.row_top(index) - 8.0, 0.0)
	return 0.0


## What every row READS as, so a run doubles as a text check of the words behind the image.
func _print_rows() -> void:
	for entry: Dictionary in _viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		_viewport._ensure_event_spans(row_data)
		var texts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			if span.text.strip_edges().is_empty():
				continue
			var object_label: String = str(span.metadata.get("object_label", ""))
			texts.append(("%s > " % object_label if not object_label.is_empty() else "") + span.text)
		print("  row: [%s]" % " | ".join(texts))
