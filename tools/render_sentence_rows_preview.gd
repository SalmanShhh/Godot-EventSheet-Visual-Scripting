# EventForge - render harness (dev tool) for the Construct row grammar.
# Opens the FPS Controller pack as a read-only sheet and screenshots the verb bodies, where the
# statements that have no ACE of their own read as Object ▸ Verb rows:
#   docs/images/opened-pack-sentences.png
# Run NON-headless (headless runs cannot render):
#   godot --path . --script tools/render_sentence_rows_preview.gd
@tool
extends SceneTree

const PACK_PATH: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"
## The verb the shot opens on - its body carries a destroy, a signal, a local and a guard in a row.
const ANCHOR_VERB: String = "add_look"

var _frames: int = 0
var _shot: bool = false
var _viewport: EventSheetViewport = null
var _scroll: ScrollContainer = null


func _init() -> void:
	root.title = "Opened pack - row grammar"
	root.size = Vector2i(1400, 820)
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
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(PACK_PATH)
	# The dock opens a .gd as a read-only preview; the importer leaves the flag alone, so the
	# harness sets what the dock would set.
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = style
	_viewport.set_sheet(sheet)
	_viewport.set_reading_mode(true)
	# No pointer input at all, so no hover tooltip drifts across the screenshot.
	root.gui_disable_input = true
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 10:
		return
	if not _shot:
		_scroll.scroll_vertical = int(_anchor_top())
		_shot = true
		_frames = 0
		return
	var image: Image = root.get_texture().get_image()
	image.save_png("res://docs/images/opened-pack-sentences.png")
	print("[preview] sentences %dx%d" % [image.get_width(), image.get_height()])
	_print_rows()
	quit(0)


## Where the shot opens: on the anchor verb's header, so its body fills the frame.
func _anchor_top() -> float:
	for index in range(_viewport._flat_rows.size()):
		var row_data: EventRowData = _viewport._flat_rows[index].get("row")
		if row_data == null:
			continue
		var verb: EventFunction = row_data.source_resource as EventFunction
		if verb != null and verb.function_name == ANCHOR_VERB:
			return maxf(_viewport._row_metrics_helper.row_top(index) - 24.0, 0.0)
	return 0.0


## Prints what the shot's rows READ as, so a run doubles as a text check of the words.
func _print_rows() -> void:
	var printed: int = 0
	for index in range(_viewport._flat_rows.size()):
		var row_data: EventRowData = _viewport._flat_rows[index].get("row")
		if row_data == null or row_data.spans.is_empty():
			continue
		var cells: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			var label: String = str(span.metadata.get("object_label", ""))
			cells.append(("%s ▸ %s" % [label, span.text]) if not label.is_empty() else span.text)
		print("  %s" % " | ".join(cells))
		printed += 1
		if printed >= 60:
			return
