@tool
extends RefCounted
# Godot EventSheets - node, scene, resource and typed-list variables on an Inspector-style row
#
# A variable can hold any Godot type, and an Inspector-style row lists it the way the Inspector
# lists the slot: the type exactly as written, the name, and the value as written. Pinned as values:
#   1. `@export var target: Node2D` reads `Node2D target = null`, the null muted and not typed over;
#   2. `@export var bullet_scene: PackedScene = preload(...)` stays a variable row - type, name, the
#      file it holds, the eye tile, the resource chip - where it used to become a preload reading;
#   3. a project Resource class (`EnemyStats`) reads the same way, its chip included;
#   4. `@onready var muzzle: Marker2D = $Muzzle` keeps its on-ready tile, `Array[Node2D] = []` its `[]`;
#   5. a sentence-row look (Classic Sheet) keeps its own readings for the same file;
#   6. which types start as null, and the engine base a project class comes down to;
#   7. the variable window's Inspector preview shows a preloaded file by its name, as the Inspector does.

const SUPPORT := preload("res://tests/support.gd")
const NativeVariableMarks := preload("res://addons/eventsheet/editor/interaction/native_variable_marks.gd")
const TEST_NAME := "object_variable_rows_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const SOURCE_PATH := "user://object_variable_rows_turret.gd"
const SCENE_PATH := "res://tests/fixtures/collision_scene_door.tscn"
const STATS_PATH := "res://demo/showcase/enemy_stats/enemy_stats_example.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _test_types() and ok
	ok = _test_native_rows(_native_viewport(), "Editor Native") and ok
	ok = _test_native_rows(_derived_viewport(), "the look a fresh install derives") and ok
	ok = _test_classic_rows() and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SOURCE_PATH))
	return ok


static func _test_types() -> bool:
	return SUPPORT.pins(TEST_NAME, [
		["a node slot starts as null", NativeVariableMarks.starts_null("Node2D"), true],
		["so does a scene", NativeVariableMarks.starts_null("PackedScene"), true],
		["and the project's own resource class", NativeVariableMarks.starts_null("EnemyStats"), true],
		["and a plain Object", NativeVariableMarks.starts_null("Object"), true],
		["a number does not", NativeVariableMarks.starts_null("float"), false],
		["nor a value type GDScript builds in", NativeVariableMarks.starts_null("Rect2"), false],
		["nor a typed list", NativeVariableMarks.starts_null("Array[Node2D]"), false],
		["nor an enum of the sheet", NativeVariableMarks.starts_null("State", PackedStringArray(["State"])), false],
		["nor an undeclared type", NativeVariableMarks.starts_null(""), false],
		["a project class comes down to its engine base", NativeVariableMarks.project_class_base("EnemyStats"), "Resource"],
		["a name the project does not declare has none", NativeVariableMarks.project_class_base("NoSuchClassAnywhere"), ""],
		["so its family is the object family", NativeVariableMarks.type_family("EnemyStats", null), NativeVariableMarks.FAMILY_OBJECT],
		["the window's Inspector preview shows a preloaded file by its name",
			EventSheetInspectorPreviewCard.slot_text("preload(\"res://bullet.tscn\")"), "bullet.tscn"],
		["and a loaded one too", EventSheetInspectorPreviewCard.slot_text("load(\"res://stats/turret_stats.tres\")"),
			"turret_stats.tres"],
		["anything else as written", EventSheetInspectorPreviewCard.slot_text("$Muzzle"), "$Muzzle"],
	])


static func _test_native_rows(viewport: EventSheetViewport, look: String) -> bool:
	var target_value: SemanticSpan = _span_with(_row_named(viewport, "target"), "variable_value_span")
	var scene_row: EventRowData = _row_named(viewport, "bullet_scene")
	var scene_value: SemanticSpan = _span_with(scene_row, "variable_value_span")
	var stats_value: SemanticSpan = _span_with(_row_named(viewport, "stats"), "variable_value_span")
	var muted: Color = viewport._get_reading_style().muted_text_color
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		[look + ": an empty node slot reads null", _words(_row_named(viewport, "target")), ["Node2D", "target", "⚙", "=", "null"]],
		[look + ": the null is muted and not typed over",
			[target_value.metadata.get("text_color"), target_value.metadata.get("editable"),
				str(target_value.metadata.get("value_glyph", ""))], [muted, false, ""]],
		[look + ": a preloaded scene is a variable row: type, name, the file",
			[scene_row != null and scene_row.variable_row, _words(scene_row)],
			[true, ["PackedScene", "bullet_scene", "⚙", "=", "collision_scene_door.tscn"]]],
		[look + ": with its eye tile and its resource chip",
			[_span_with(scene_row, "variable_name_span").metadata.get("variable_badges"), scene_value.metadata.get("value_glyph")],
			[PackedStringArray(["inspector"]), NativeVariableMarks.GLYPH_RESOURCE]],
		[look + ": typing into it edits the call the file holds", scene_value.metadata.get("edit_text"),
			"preload(\"%s\")" % SCENE_PATH],
		[look + ": the project's own resource class reads the same way",
			[_words(_row_named(viewport, "stats")), stats_value.metadata.get("value_glyph")],
			[["EnemyStats", "stats", "⚙", "=", "enemy_stats_example.tres"], NativeVariableMarks.GLYPH_RESOURCE]],
		[look + ": an on-ready node keeps its tile",
			[_words(_row_named(viewport, "muzzle")),
				_span_with(_row_named(viewport, "muzzle"), "variable_name_span").metadata.get("variable_badges")],
			[["Marker2D", "muzzle", "=", "$Muzzle"], PackedStringArray(["on_ready"])]],
		[look + ": a typed list keeps its [] as written", _words(_row_named(viewport, "_in_range")),
			["Array[Node2D]", "_in_range", "=", "[]"]],
		[look + ": a number with no value still shows none", _words(_row_named(viewport, "_start_x")),
			["float", "_start_x"]],
	])
	viewport.free()
	return ok


static func _test_classic_rows() -> bool:
	var viewport: EventSheetViewport = _viewport_with((load(CLASSIC_THEME) as EventSheetEditorStyle).duplicate(true))
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["classic: a preloaded scene keeps its object reading", _words(_row_named(viewport, "bullet_scene")), []],
		["classic: an empty node slot shows no value",
			_words(_row_named(viewport, "target")).has("null"), false],
		["classic: an empty list still reads in words",
			_span_with(_row_named(viewport, "_in_range"), "variable_value_span").text, EventSheetL10n.translate("empty")],
	])
	viewport.free()
	return ok


static func _source() -> String:
	return "\n".join([
		"extends Node2D",
		"",
		"@export_group(\"Targets\")",
		"@export var target: Node2D",
		"@export var bullet_scene: PackedScene = preload(\"%s\")" % SCENE_PATH,
		"@export var stats: EnemyStats = preload(\"%s\")" % STATS_PATH,
		"",
		"var _start_x: float",
		"var _in_range: Array[Node2D] = []",
		"",
		"@onready var muzzle: Marker2D = $Muzzle",
		"",
	])


static func _sheet() -> EventSheetResource:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(_source())
	handle.close()
	return GDScriptImporter.new().import_external(SOURCE_PATH)


static func _native_viewport() -> EventSheetViewport:
	return _viewport_with((load(NATIVE_THEME) as EventSheetEditorStyle).duplicate(true))


static func _derived_viewport() -> EventSheetViewport:
	return _viewport_with(EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE))


static func _viewport_with(style: EventSheetEditorStyle) -> EventSheetViewport:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = _sheet()
	sheet.editor_style = style
	# Opened the way a script from the FileSystem opens: read in place, its members re-read.
	sheet.read_only = true
	viewport.set_sheet(sheet)
	return viewport


static func _words(row: EventRowData) -> Array:
	var words: Array = []
	if row == null:
		return words
	for span: SemanticSpan in row.spans:
		if span != null:
			words.append(span.text)
	return words


static func _row_named(viewport: EventSheetViewport, variable_name: String) -> EventRowData:
	for index: int in range(viewport._flat_rows.size()):
		var row: EventRowData = viewport._row_at(index)
		if row == null or not row.variable_row:
			continue
		for span: SemanticSpan in row.spans:
			if span != null and span.metadata is Dictionary and str((span.metadata as Dictionary).get("variable_name", "")) == variable_name:
				return row
	return null


static func _span_with(row: EventRowData, flag: String) -> SemanticSpan:
	if row == null:
		return SemanticSpan.new()
	for span: SemanticSpan in row.spans:
		if span != null and span.metadata is Dictionary and bool((span.metadata as Dictionary).get(flag, false)):
			return span
	return SemanticSpan.new()
