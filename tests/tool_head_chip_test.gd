@tool
extends RefCounted

# A `@tool` script says it runs in the editor ON its head bar - a violet "Runs in the editor" chip
# beside what it extends, the `@tool` line in its hover - and no second head row under the bar says
# it again. Read off a user's own script with no class_name, written to disk the way it is met in a
# project, in a dark look and a light one (the chip wears the design's violet pair on each, the
# one the range tile wears).

const SUPPORT := preload("res://tests/support.gd")
const P := "tool_head_chip_test"
const EDITOR_THEME_DERIVER := preload("res://addons/eventsheet/theme/editor_theme_deriver.gd")

const DIR := "user://tool_head_chip_test"
const SOURCE := """@tool
extends Node2D

@export var radius: float = 32.0:
	set(value):
		radius = value
		queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color.WHITE)
"""


static func run() -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path: String = DIR + "/spike_ring.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(SOURCE)
	file.close()
	var dark: Array = _head_rows(path, false)
	var light: Array = _head_rows(path, true)
	var chip: SemanticSpan = _span(dark[0], "Runs in the editor")
	var light_chip: SemanticSpan = _span(light[0], "Runs in the editor")
	var second_row: String = _words_of(dark[1]) if dark.size() > 1 else ""
	return SUPPORT.pins(P, [
		["the head bar reads the chip beside what it extends", _words_of(dark[0]),
			"◆ spike_ring.gd Script · extends Node2D Runs in the editor 1 variable · 1 event"],
		["the chip wears the dark pair on a dark bar",
			[chip.metadata.get("badge_bg"), chip.metadata.get("badge_fg")] if chip != null else [],
			[Color("#3A2F4D"), Color("#C9A6FF")]],
		["and the light pair on a light bar",
			[light_chip.metadata.get("badge_bg"), light_chip.metadata.get("badge_fg")] if light_chip != null else [],
			[Color("#DDD0F5"), Color("#502793")]],
		["its hover says the line it stands for",
			str(chip.metadata.get("hover_note", "")).get_slice("\n\n", 1).get_slice("\n", 0) if chip != null else "",
			"@tool"],
		["no head row under the bar says it again", second_row.contains("runs in the editor"), false],
	])


static func _head_rows(path: String, light: bool) -> Array:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	if sheet == null:
		return [EventRowData.new()]
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	# A light editor gives the default look the light hand of its marks.
	if light:
		EDITOR_THEME_DERIVER.dress_new_marks(style.get_event_style(), true)
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var rows: Array = viewport._root_rows.duplicate()
	viewport.free()
	return rows


static func _span(row_data: EventRowData, text: String) -> SemanticSpan:
	for span: SemanticSpan in row_data.spans:
		if span.text == text:
			return span
	return null


static func _words_of(row_data: EventRowData) -> String:
	var words: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		var text: String = span.text.strip_edges()
		if not text.is_empty():
			words.append(text)
	return " ".join(words)
