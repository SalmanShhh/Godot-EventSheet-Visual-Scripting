# EventForge - render harness (dev tool) for a HAND-WRITTEN script opened as a sheet.
#
# The pack previews show compiler output read back; this one shows ordinary GDScript nobody wrote for
# the plugin - the shapes a beginner writes most: one-line guard clauses, an `and`/`or` test, a run of
# awaits, and a lambda handed to `connect`. It writes:
#   docs/images/opened-script-structure.png
# Run NON-headless (headless runs cannot render):
#   godot --path . --script tools/render_opened_script_structure.gd
@tool
extends SceneTree

const FIXTURE_PATH: String = "user://eventsheets_opened_script_structure.gd"

const FIXTURE_SOURCE: String = """@tool
class_name DoorController
extends Node

var hp: int = 10
var seconds_left: int = 3
var host: Node = null


func _ready() -> void:
	$Timer.timeout.connect(func(): seconds_left -= 1)
	host.hit.connect(func(body):
		seconds_left += 1
		if seconds_left <= 0:
			$Timer.stop()
	)
	await get_tree().process_frame
	await get_tree().physics_frame
	await host.tree_exited


func check() -> void:
	if host == null: return
	if hp <= 0: close()
	elif hp < 5: open()
	else: open()
	if hp > 0 and hp < 100:
		open()
	if hp <= 0 or seconds_left <= 0:
		close()


func wall_normal_x() -> float:
	return host.get_wall_normal().x if host != null and host.is_on_wall() else 0.0


func open() -> void:
	pass


func close() -> void:
	pass
"""

var _frames: int = 0
var _viewport: EventSheetViewport = null
var _scroll: ScrollContainer = null
var _sheet: EventSheetResource = null


func _init() -> void:
	root.title = "Opened script"
	root.size = Vector2i(1500, 900)
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
	var writer: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
	writer.store_string(FIXTURE_SOURCE)
	writer.close()
	_sheet = GDScriptImporter.new().import_external(FIXTURE_PATH)
	# The dock opens a .gd as a read-only preview; the importer leaves the flag alone.
	_sheet.read_only = true
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	_sheet.editor_style = style
	_viewport.set_sheet(_sheet)
	_viewport.set_reading_mode(true)
	# The Helpers bar and the verb blocks fold closed by default; the shapes this shot exists for all
	# live under them. Opened pass by pass, because unfolding a bar is what reveals the next bar.
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
		# The shot opens on the handler, so the connect readings and the one-line blocks under
		# Helpers share one frame; the file's head is what a reader scrolls past anyway.
		_scroll.scroll_vertical = int(_handler_top())
		_frames = 0
		return
	var image: Image = root.get_texture().get_image()
	image.save_png("res://docs/images/opened-script-structure.png")
	print("[preview] opened script %dx%d" % [image.get_width(), image.get_height()])
	print("[preview] round-trips: %s" % str(str(SheetCompiler.new().compile(_sheet).get("output", "")) == FIXTURE_SOURCE))
	_print_rows()
	quit(0)


## The scroll offset that puts the `_ready` handler at the top of the frame.
func _handler_top() -> float:
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
			if not span.text.strip_edges().is_empty():
				texts.append(span.text)
		print("  row: [%s]" % " | ".join(texts))
