# EventForge - render harness (dev tool) for the opened-sheet READING LENSES.
# Opens two read-only previews stacked and screenshots them as one image:
#   top    - the FPS Controller pack (its published verbs and its physics tick)
#   bottom - tests/fixtures/reading_lenses_fixture.gd, a hand-written script carrying an @onready
#            node, an inverted condition, a nested if and a call with named arguments
# Stacked rather than side by side on purpose: a two-lane sheet in half a window wraps every
# cell to two or three characters per line, which proves nothing about how the rows read.
# Writes docs/images/opened-pack-lenses.png, and prints what each row READS as, so one run
# proves both the look (the image) and the words (the printed spans).
# Run NON-headless (headless runs cannot render):
#   godot --path . --script tools/render_opened_pack_lenses_preview.gd
@tool
extends SceneTree

const PACK_PATH: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"
const FIXTURE_PATH: String = "res://tests/fixtures/reading_lenses_fixture.gd"
const IMAGE_PATH: String = "res://docs/images/opened-pack-lenses.png"

var _frames: int = 0
var _shot_taken: bool = false
var _pack_view: EventSheetViewport = null
var _fixture_view: EventSheetViewport = null
var _pack_scroll: ScrollContainer = null


func _init() -> void:
	root.title = "Opened sheet - reading lenses"
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
	_pack_scroll = _add_pane(columns, PACK_PATH, modern_base)
	_pack_view = _pack_scroll.get_child(0) as EventSheetViewport
	_fixture_view = _add_pane(columns, FIXTURE_PATH, modern_base).get_child(0) as EventSheetViewport
	# No pointer input at all, so wherever the mouse rests no hover tooltip drifts into the shot.
	root.gui_disable_input = true
	process_frame.connect(_on_frame)


## One read-only preview pane: a scroll box holding a viewport with the sheet already open in
## reading mode, which is what the dock hands a .gd opened as a sheet.
func _add_pane(parent: Control, source_path: String, modern_base: Color) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var view := EventSheetViewport.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(view)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(source_path)
	# The dock opens a .gd as a read-only preview; the importer leaves the flag alone, so the
	# harness sets what the dock would set.
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
	# Scroll the pack pane to its physics tick, which is where the sentence lenses do their work;
	# the fixture pane is short enough to read whole from the top.
	_pack_scroll.scroll_vertical = int(_physics_tick_top())
	# The fixture's head (its identity bar and two folded groups) is proved by the printed rows;
	# the shot wants the EVENTS, where the lenses do their work.
	(_fixture_view.get_parent() as ScrollContainer).scroll_vertical = 108
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	image.save_png(IMAGE_PATH)
	print("[lenses] %s  %dx%d" % [IMAGE_PATH, image.get_width(), image.get_height()])
	_print_rows("pack", _pack_view, 26)
	_print_rows("fixture", _fixture_view, 40)
	quit(0)


## Where the pack shot opens: on _physics_process, the handler whose body the lenses rewrite.
## Falls back to the top when the row is not found.
func _physics_tick_top() -> float:
	for index: int in range(_pack_view._flat_rows.size()):
		var row_data: EventRowData = _pack_view._flat_rows[index].get("row")
		if row_data == null:
			continue
		for span: SemanticSpan in row_data.spans:
			if span != null and span.text.contains("_physics_process"):
				return maxf(_pack_view._row_metrics_helper.row_top(index) - 40.0, 0.0)
	return 0.0


## Prints what each row READS as. The image proves the look; this proves the words, so a lens
## that silently stopped firing fails the run visibly instead of quietly.
func _print_rows(label: String, view: EventSheetViewport, limit: int) -> void:
	print("── %s ──" % label)
	var printed: int = 0
	for index: int in range(view._flat_rows.size()):
		printed = _print_row(view, view._flat_rows[index].get("row"), printed, limit, 0)
		if printed >= limit:
			return


## One row and, indented under it, its children - reading mode folds the setting groups and the
## code cards closed, and a row hidden behind a fold still has to be checkable.
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
