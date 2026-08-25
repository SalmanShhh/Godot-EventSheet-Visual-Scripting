# EventForge - render harness (dev tool) for batch 5's readings of an opened script.
#
# Two approved items in one file:
#   A script that does not compile shows WHICH rows are broken - the engine's own message on the
#       rows built from the offending lines (the errors here are real: the file is written into the
#       project and put to the same --check-only run the open job uses)
#   `_draw`, `_enter_tree`, `_exit_tree` and a `_notification` whose body is a `match what:` read
#       as the object's own lifecycle triggers instead of as helper functions
#
# It writes:
#   docs/images/opened-script-structure5.png
# Run NON-headless (headless runs cannot render):
#   godot --path . --script tools/render_opened_script_structure5.gd
@tool
extends SceneTree

const FIXTURE_PATH: String = "res://opened_script_structure5_preview.gd"

## Deliberately does not compile: `speed`, `walk_speed` and `max_hp` are never declared, which is the
## exact shape the approved reading shows (`hp < max_hp` wearing "max_hp is not declared").
const FIXTURE_SOURCE: String = """extends Node2D

var trail_color: Color = Color.RED
var alive: bool = false
var hp: int = 10


func _enter_tree() -> void:
	alive = true


func _physics_process(delta: float) -> void:
	speed = walk_speed * delta
	if hp < max_hp:
		hp += 1


func _draw() -> void:
	draw_line(Vector2(0, 0), Vector2(100, 0), trail_color)
	draw_circle(Vector2(0, 0), 8.0, trail_color)


func _exit_tree() -> void:
	alive = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			alive = false
		NOTIFICATION_APPLICATION_RESUMED:
			alive = true
"""

var _frames: int = 0
var _viewport: EventSheetViewport = null
var _scroll: ScrollContainer = null
var _sheet: EventSheetResource = null
var _shot: SubViewport = null
var _errors: Array = []


func _init() -> void:
	root.title = "Opened script structure"
	root.size = Vector2i(1200, 700)
	var modern_base := Color("#252525")
	_shot = SubViewport.new()
	_shot.size = Vector2i(1500, 600)
	_shot.transparent_bg = false
	_shot.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_shot)
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shot.add_child(background)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shot.add_child(_scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	_scroll.add_child(_viewport)
	_write(FIXTURE_PATH, FIXTURE_SOURCE)
	_sheet = GDScriptImporter.new().import_external(FIXTURE_PATH)
	# The dock opens a .gd as a read-only preview; the importer leaves the flag alone.
	_sheet.read_only = true
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	_sheet.editor_style = style
	_viewport.set_sheet(_sheet)
	_viewport.set_reading_mode(true)
	for _pass: int in 4:
		for entry: Dictionary in _viewport.get_flat_rows():
			var row_data: EventRowData = entry.get("row")
			if row_data != null and not row_data.row_uid.is_empty():
				_viewport._fold_state[row_data.row_uid] = false
		_viewport.set_sheet(_sheet)
	# End to end: the real check, the real source map, the real row join.
	_errors = EventSheetParseErrors.check_file(FIXTURE_PATH)
	EventSheetParseErrors.store_on_sheet(_sheet, _errors)
	var source_map: Array = SheetCompiler.compile(_sheet, FIXTURE_PATH).get("source_map", [])
	_viewport.set_row_diagnostics(EventSheetParseErrors.row_diagnostics(_errors, source_map))
	_viewport.set_sheet(_sheet)
	root.gui_disable_input = true
	process_frame.connect(_on_frame)


func _write(path: String, source: String) -> void:
	var writer: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	writer.store_string(source)
	writer.close()


func _on_frame() -> void:
	_frames += 1
	if _frames < 12:
		return
	var image: Image = _shot.get_texture().get_image()
	image.save_png("res://docs/images/opened-script-structure5.png")
	print("[preview] opened script structure %dx%d" % [image.get_width(), image.get_height()])
	print("[preview] round-trips: %s" % str(str(SheetCompiler.compile(_sheet, FIXTURE_PATH).get("output", "")) == FIXTURE_SOURCE))
	print("[preview] parse errors the engine reported: %d" % _errors.size())
	for error_entry: Variant in _errors:
		print("    line %d: %s" % [int((error_entry as Dictionary).get("line", 0)), str((error_entry as Dictionary).get("message", ""))])
	_print_rows()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_PATH))
	quit(0)


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
		var flag: String = ""
		if not row_data.error_message.is_empty():
			flag = "  [!] %s" % row_data.error_message
		print("  row: [%s]%s" % [" | ".join(texts), flag])
