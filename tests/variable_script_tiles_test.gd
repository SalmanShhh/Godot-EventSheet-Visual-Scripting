# EventForge - a variable's row carries the tiles for what the script does with it, not only the
# window: a setter runs code on change, `@onready` fills it as the scene starts. The tiles stand
# after the Inspector's own, in the fixed order every row uses, and each has its card's code line.
# And the value is the code's own: `220.0` as written, nothing at all where the file wrote none.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NativeVariableMarks := preload("res://addons/eventsheet/editor/interaction/native_variable_marks.gd")
const P := "variable_script_tiles_test"
const SOURCE_PATH := "user://variable_script_tiles_probe.gd"

const SOURCE := """@tool
extends Node2D

@export var radius: float = 32.0:
	set(value):
		radius = maxf(value, 4.0)
		queue_redraw()

var health: int = 3:
	set = _set_health

var plain: int = 0
@export var speed: float = 220.0
var _start_x: float

@onready var sprite: Sprite2D = $Sprite2D


func _set_health(value: int) -> void:
	health = value
"""


static func run() -> bool:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var ok: bool = SUPPORT.pins(P, [
		["an inline setter earns the on-change tile after the eye", _tiles(view, "radius"),
			PackedStringArray(["inspector", "on_change"])],
		["a named setter earns it too", _tiles(view, "health"), PackedStringArray(["on_change"])],
		["a plain variable earns none", _tiles(view, "plain"), PackedStringArray()],
		["an @onready earns the on-ready tile", _tiles(view, "sprite"), PackedStringArray(["on_ready"])],
		["a float reads as the code writes it", _words(view, "speed").has("220.0"), true],
		["a declaration with no value written shows none", _words(view, "_start_x").has("null"), false],
		["the on-change card quotes the setter as written",
			str(NativeVariableMarks.badge_card("on_change", _variable(sheet, "radius")).get("mono", "")), "set(value):"],
		["and the named one by its function",
			str(NativeVariableMarks.badge_card("on_change", _variable(sheet, "health")).get("mono", "")), "set = _set_health"],
	])
	# The window's two script tiles quote the line they add, not a placeholder shape: a show-if is the
	# test _validate_property asks, and an On changed with no setter of its own is the setter it writes.
	var shown: LocalVariable = LocalVariable.new()
	shown.name = "jump_height"
	shown.attributes = {"show_if": "can_jump", "on_changed": "_refresh_jump"}
	ok = SUPPORT.pins(P, [
		["the show-if card quotes the test that hides it",
			str(NativeVariableMarks.badge_card("show_if", shown).get("mono", "")),
			"if str(property.name) == \"jump_height\" and not bool(can_jump):"],
		["the on-changed card quotes the setter it writes",
			str(NativeVariableMarks.badge_card("on_change", shown).get("mono", "")),
			"set(value): jump_height = value; _refresh_jump()"],
	]) and ok
	view.free()
	return ok


static func _tiles(view: EventSheetViewport, variable_name: String) -> PackedStringArray:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource is LocalVariable \
				and (row_data.source_resource as LocalVariable).name == variable_name:
			view._row_builder._ensure_event_spans(row_data)
			return NativeVariableMarks.row_badges(row_data)
	return PackedStringArray(["(no row)"])


static func _words(view: EventSheetViewport, variable_name: String) -> PackedStringArray:
	var words := PackedStringArray()
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource is LocalVariable \
				and (row_data.source_resource as LocalVariable).name == variable_name:
			view._row_builder._ensure_event_spans(row_data)
			for span: SemanticSpan in row_data.spans:
				words.append(span.text.strip_edges())
	return words


static func _variable(sheet: EventSheetResource, variable_name: String) -> LocalVariable:
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == variable_name:
			return entry as LocalVariable
	return null
