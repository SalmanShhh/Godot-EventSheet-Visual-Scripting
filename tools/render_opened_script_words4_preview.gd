# EventForge - render harness (dev tool) for batch four's reading words (N5 - N11).
# Opens tests/fixtures/reading_words4_fixture.gd read-only in two stacked panes and screenshots them
# as one image: the top pane on the actions (saving, files, JSON, the behaviour words, the debug
# verbs) and the bottom pane on the conditions (what an object is and has, the comparison glyphs, the
# input phases). Writes docs/images/opened-script-words4.png and prints what every row READS, so one
# run proves both the look (the image) and the words (the printed spans).
# Run NON-headless (headless runs cannot render):
#   godot --path . --script tools/render_opened_script_words4_preview.gd
@tool
extends SceneTree

const FIXTURE_PATH: String = "res://tests/fixtures/reading_words4_fixture.gd"
const IMAGE_PATH: String = "res://docs/images/opened-script-words4.png"

var _frames: int = 0
var _shot_taken: bool = false
var _actions_view: EventSheetViewport = null
var _conditions_view: EventSheetViewport = null


func _init() -> void:
	root.title = "Opened script - reading words, batch four"
	root.size = Vector2i(1280, 1080)
	var modern_base := Color("#252525")
	var background := ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var columns := VBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 10)
	root.add_child(columns)
	_actions_view = _add_pane(columns, modern_base).get_child(0) as EventSheetViewport
	_conditions_view = _add_pane(columns, modern_base).get_child(0) as EventSheetViewport
	# No pointer input at all, so wherever the mouse rests no hover tooltip drifts into the shot.
	root.gui_disable_input = true
	process_frame.connect(_on_frame)


## One read-only preview pane: a scroll box holding a viewport with the fixture already open in
## reading mode, which is what the dock hands a .gd opened as a sheet.
func _add_pane(parent: Control, modern_base: Color) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var view := EventSheetViewport.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(view)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE_PATH)
	sheet.read_only = true
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = style
	view.set_sheet(sheet)
	view.set_reading_mode(true)
	return scroll


func _on_frame() -> void:
	_frames += 1
	if _frames < 12 or _shot_taken:
		return
	_shot_taken = true
	# Top pane on the saving / files / JSON / debug run, bottom pane on the behaviour words and the
	# questions under them - between the two, one of every shape batch four claims is on screen.
	# The whole On Ready event is ONE row, so the top pane is nudged into the middle of its action
	# stack by pixels - a marker search would only ever land on the row's own top edge.
	_scroll_to("On Ready", _actions_view)
	(_actions_view.get_parent() as ScrollContainer).scroll_vertical += 390
	_scroll_to("Apply impulse", _conditions_view)
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	image.save_png(IMAGE_PATH)
	print("[words4] %s  %dx%d" % [IMAGE_PATH, image.get_width(), image.get_height()])
	_print_rows("actions", _actions_view, 90)
	quit(0)


## Opens a pane on the row whose text names `marker`, so each pane shows the half it is there for.
func _scroll_to(marker: String, view: EventSheetViewport) -> void:
	var scroll: ScrollContainer = view.get_parent() as ScrollContainer
	for index: int in range(view._flat_rows.size()):
		var row_data: EventRowData = view._flat_rows[index].get("row")
		if row_data == null:
			continue
		# Spans are built lazily, so a row further down has none yet - and a marker search over rows
		# that have not been built would always stop on whatever the first pass happened to fill.
		view._row_builder._ensure_event_spans(row_data)
		for span: SemanticSpan in row_data.spans:
			if span != null and span.text.contains(marker):
				scroll.scroll_vertical = int(maxf(view._row_metrics_helper.row_top(index) - 60.0, 0.0))
				return


## Prints what each row READS as. The image proves the look; this proves the words, so a lens that
## silently stopped firing fails the run visibly instead of quietly.
func _print_rows(label: String, view: EventSheetViewport, limit: int) -> void:
	print("-- %s --" % label)
	var printed: int = 0
	for index: int in range(view._flat_rows.size()):
		printed = _print_row(view, view._flat_rows[index].get("row"), printed, limit, 0)
		if printed >= limit:
			return


## One row and, indented under it, its children - reading mode folds the setting groups and the code
## cards closed, and a row hidden behind a fold still has to be checkable.
func _print_row(view: EventSheetViewport, row_data: EventRowData, printed: int, limit: int, depth: int) -> int:
	if row_data == null or printed >= limit:
		return printed
	view._row_builder._ensure_event_spans(row_data)
	if not row_data.spans.is_empty():
		var texts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			texts.append(span.text)
		print("  %s%s%s" % ["    ".repeat(depth), "[break] " if row_data.breakpoint_enabled else "", " | ".join(texts)])
		printed += 1
	for child: EventRowData in row_data.children:
		printed = _print_row(view, child, printed, limit, depth + 1)
	return printed
