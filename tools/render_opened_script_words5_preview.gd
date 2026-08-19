# EventForge - render harness (dev tool) for batch five's reading words (P6 / P8 / P9 / P11).
# Opens the two words5 fixtures read-only in three stacked panes and screenshots them as one image: the
# top pane is the script the SCENE ITSELF carries (its _ready reads On start of layout, and under it
# the tick switches, the process mode, the wait-then and the named chips), the middle pane is that same
# file with its folds opened, on the drawing verbs inside `_draw`, and the bottom pane is the script
# sitting on a CHILD node of that same scene (whose _ready reads that object's On created).
# Writes docs/images/opened-script-words5.png and prints what every row READS, so one run proves both
# the look (the image) and the words (the printed spans).
# Run NON-headless (headless runs cannot render):
#   godot --path . --script tools/render_opened_script_words5_preview.gd
@tool
extends SceneTree

const ROOT_FIXTURE: String = "res://tests/fixtures/opened_script_words5_root.gd"
const PART_FIXTURE: String = "res://tests/fixtures/opened_script_words5_part.gd"
const IMAGE_PATH: String = "res://docs/images/opened-script-words5.png"

var _frames: int = 0
var _shot_taken: bool = false
var _root_view: EventSheetViewport = null
var _draw_view: EventSheetViewport = null
var _part_view: EventSheetViewport = null


func _init() -> void:
	root.title = "Opened script - reading words, batch five"
	root.size = Vector2i(1280, 1000)
	var modern_base := Color("#252525")
	var background := ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var columns := VBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 10)
	root.add_child(columns)
	_root_view = _add_pane(columns, modern_base, ROOT_FIXTURE, 4).get_child(0) as EventSheetViewport
	_draw_view = _add_pane(columns, modern_base, ROOT_FIXTURE, 2).get_child(0) as EventSheetViewport
	_part_view = _add_pane(columns, modern_base, PART_FIXTURE, 1).get_child(0) as EventSheetViewport
	# No pointer input at all, so wherever the mouse rests no hover tooltip drifts into the shot.
	root.gui_disable_input = true
	process_frame.connect(_on_frame)


## One read-only preview pane: a scroll box holding a viewport with a fixture already open in reading
## mode, which is what the dock hands a .gd opened as a sheet. `weight` gives the scene's own script
## the room it needs, since that is where most of the batch lives.
func _add_pane(parent: Control, modern_base: Color, fixture_path: String, weight: int) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = float(weight)
	parent.add_child(scroll)
	var view := EventSheetViewport.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(view)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(fixture_path)
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
	_scroll_to("On start of layout", _root_view)
	# The drawing verbs live inside `_draw`, which reading mode folds closed - so this pane is the
	# same file with its folds opened, which is what a reader sees a click later.
	_open_folds(_draw_view)
	await process_frame
	await process_frame
	_scroll_to("Draw line", _draw_view)
	_scroll_to("On created", _part_view)
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	image.save_png(IMAGE_PATH)
	print("[words5] %s  %dx%d" % [IMAGE_PATH, image.get_width(), image.get_height()])
	_print_rows("the scene's own script", _root_view, 60)
	_print_rows("its drawing verbs", _draw_view, 40)
	_print_rows("a script on an object", _part_view, 20)
	quit(0)


## Opens every fold in a pane, one at a time, through the same gesture a reader's click goes through -
## so the rows this pane shows are exactly the rows a click would reveal. One fold per pass, because
## opening one rebuilds the flat list the next pass walks.
func _open_folds(view: EventSheetViewport) -> void:
	for _pass_index: int in 40:
		var opened: bool = false
		for index: int in range(view._flat_rows.size()):
			var row_data: EventRowData = view._row_at(index)
			if row_data != null and row_data.folded and not row_data.children.is_empty():
				view._folding.toggle_row_fold(index)
				opened = true
				break
		if not opened:
			return


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
				scroll.scroll_vertical = int(maxf(view._row_metrics_helper.row_top(index) - 20.0, 0.0))
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
		print("  %s%s" % ["    ".repeat(depth), " | ".join(texts)])
		printed += 1
	for child: EventRowData in row_data.children:
		printed = _print_row(view, child, printed, limit, depth + 1)
	return printed
