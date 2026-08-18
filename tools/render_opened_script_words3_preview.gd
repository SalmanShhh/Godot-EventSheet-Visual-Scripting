# EventForge - render harness (dev tool) for the Construct NOUNS an opened script reads in
# (M38 - M47). Opens tests/fixtures/reading_nouns_fixture.gd twice, stacked:
#   top    - as it reads by default (Godot's nouns: scene, CanvasLayer)
#   bottom - with View ▾ "Construct Words" on (layout, time scale, layer)
# Writes docs/images/opened-script-words3.png and prints what every row READS, so one run proves
# both the look (the image) and the words (the printed spans).
# Run NON-headless (headless runs cannot render):
#   godot --path . --script tools/render_opened_script_words3_preview.gd
@tool
extends SceneTree

const FIXTURE_PATH: String = "res://tests/fixtures/reading_nouns_fixture.gd"
const IMAGE_PATH: String = "res://docs/images/opened-script-words3.png"

## The event is ONE row of many action lines, so the shot scrolls INTO it - far enough to land on
## the lines the glossary changes (the scene switch and the layer).
const ACTION_SCROLL: int = 560

var _frames: int = 0
var _shot_taken: bool = false
var _plain_view: EventSheetViewport = null
var _construct_view: EventSheetViewport = null


func _init() -> void:
	root.title = "Opened script - Construct nouns"
	root.size = Vector2i(1900, 900)
	var modern_base := Color("#252525")
	var background := ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var columns := VBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 10)
	root.add_child(columns)
	_plain_view = _add_pane(columns, modern_base, false).get_child(0) as EventSheetViewport
	_construct_view = _add_pane(columns, modern_base, true).get_child(0) as EventSheetViewport
	# No pointer input at all, so wherever the mouse rests no hover tooltip drifts into the shot.
	root.gui_disable_input = true
	process_frame.connect(_on_frame)


## One read-only preview pane: a scroll box holding a viewport with the fixture already open in
## reading mode, which is what the dock hands a .gd opened as a sheet.
func _add_pane(parent: Control, modern_base: Color, construct_words: bool) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var view := EventSheetViewport.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.set_ace_registry(EventSheetACERegistry.new())
	# Before the sheet: the words are baked into span text at build time.
	view.construct_words = construct_words
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
	# Both panes open on the rows the glossary actually changes, so the shot shows the same file
	# reading in Godot's nouns on the left and Construct's on the right.
	(_plain_view.get_parent() as ScrollContainer).scroll_vertical = int(_row_top("Go to", _plain_view)) + ACTION_SCROLL
	(_construct_view.get_parent() as ScrollContainer).scroll_vertical = int(_row_top("Go to", _construct_view)) + ACTION_SCROLL
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	image.save_png(IMAGE_PATH)
	print("[nouns] %s  %dx%d" % [IMAGE_PATH, image.get_width(), image.get_height()])
	_print_rows("godot nouns", _plain_view, 40)
	_print_rows("construct words", _construct_view, 40)
	quit(0)


## Where a pane opens: on the row whose text names `marker`, or the top when there is none.
func _row_top(marker: String, view: EventSheetViewport) -> float:
	for index: int in range(view._flat_rows.size()):
		var row_data: EventRowData = view._flat_rows[index].get("row")
		if row_data == null:
			continue
		view._row_builder._ensure_event_spans(row_data)
		for span: SemanticSpan in row_data.spans:
			if span != null and span.text.contains(marker):
				return maxf(view._row_metrics_helper.row_top(index) - 40.0, 0.0)
	return 0.0


## Prints what each row READS as. The image proves the look; this proves the words, so a lens that
## silently stopped firing fails the run visibly instead of quietly.
func _print_rows(label: String, view: EventSheetViewport, limit: int) -> void:
	print("── %s ──" % label)
	var printed: int = 0
	for index: int in range(view._flat_rows.size()):
		printed = _print_row(view, view._flat_rows[index].get("row"), printed, limit, 0)
		if printed >= limit:
			return


## One row and, indented under it, its children.
func _print_row(view: EventSheetViewport, row_data: EventRowData, printed: int, limit: int, depth: int) -> int:
	if row_data == null or printed >= limit:
		return printed
	view._row_builder._ensure_event_spans(row_data)
	if not row_data.spans.is_empty():
		var texts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			var icon_mark: String = ""
			if span.metadata is Dictionary and (span.metadata as Dictionary).get("object_icon") is Texture2D:
				icon_mark = "[icon]"
			texts.append(icon_mark + span.text)
		print("  %s%s" % ["    ".repeat(depth), " | ".join(texts)])
		printed += 1
	for child: EventRowData in row_data.children:
		printed = _print_row(view, child, printed, limit, depth + 1)
	return printed
