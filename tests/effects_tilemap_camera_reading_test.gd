@tool
class_name EffectsTilemapCameraReadingTest
extends RefCounted

# Pins the three families of line batch eight gave the sheet's own words to:
#
#   A ShaderMaterial parameter IS an effect parameter - Set effect parameter / the effect
#        parameter expression / Set effect / Remove effect, and the tween_method-with-a-shader-lambda
#        idiom as ONE Tween effect parameter row on the material it drives
#   A tilemap cell IS a tile at a cell - Set tile at / Erase tile at with the layer and the
#        tileset said quietly, TileAt / PositionToTile / TileToPosition for the three coordinate
#        questions, and a tile's custom data as one condition
#   The camera page - Make current, Set zoom, Set scroll limits (the run of limit_* writes read
#        as one row), Scroll toward, Set smoothing on
#
# Four gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the whole path - a hand-written file opened as a sheet, walked row by row;
#   3. the pattern registry - each of the three shapes claimed on the event that owns it;
#   4. the promise all of them rest on - the file still saves byte-identically.
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason its sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions.

const SOURCE_PATH := "user://eventforge_effects_tilemap_camera.gd"

const SOURCE: String = """extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var tilemap: TileMap = $TileMap
@onready var camera: Camera2D = $Camera2D
var mat: ShaderMaterial
var tween: Tween
var target: Node2D

func _ready() -> void:
	camera.make_current()
	camera.zoom = Vector2(2, 2)
	camera.limit_left = 0
	camera.limit_right = 1920
	camera.position_smoothing_enabled = true

func _process(delta: float) -> void:
	camera.global_position = camera.global_position.lerp(target.global_position, 5 * delta)

func _on_hit() -> void:
	sprite.material.set_shader_parameter("flash", 1.0)
	var f = sprite.material.get_shader_parameter("flash")
	tween.tween_method(func(v): mat.set_shader_parameter("dissolve", v), 0.0, 1.0, 0.5)

func _on_healed() -> void:
	sprite.material = null

func _on_selected() -> void:
	sprite.material = preload("res://outline.tres")

func _on_paint(cell: Vector2i) -> void:
	tilemap.set_cell(0, cell, 1, Vector2i(2, 0))

func _on_erase(cell: Vector2i) -> void:
	tilemap.erase_cell(0, cell)

func tile_under_player() -> void:
	var cell = tilemap.local_to_map(position)
	var id = tilemap.get_cell_source_id(0, cell)
	var pos = tilemap.map_to_local(cell)
	var data = tilemap.get_cell_tile_data(0, cell)
	if data and data.get_custom_data("solid"):
		stop()
"""

## Every reading the opened file must contain, one per shape these three items claim.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	# The effect verbs
	"sprite ▸ Set effect parameter flash to 1",
	"sprite ▸ Remove effect",
	"sprite ▸ Set effect to outline",
	"mat ▸ Tween effect parameter dissolve from 0 to 1 in 0.5 seconds",
	# The tile verbs and the tile question
	"tilemap ▸ Set tile at cell to 2, 0 (layer 0 · tileset 1)",
	"tilemap ▸ Erase tile at cell (layer 0)",
	"tilemap ▸ tile at cell has solid set",
	# The camera page. The four adjacent limit writes are ONE row.
	"camera ▸ Make current",
	"camera ▸ Set zoom to 200%",
	"camera ▸ Set scroll limits 0 to 1920",
	"camera ▸ Set smoothing on",
	"camera ▸ Scroll toward target at 5 (per second)"
])

## Readings the file must NOT contain: the words each shape replaced. A reading that silently stopped
## firing would otherwise pass the list above by never being asked about.
static var FORBIDDEN_READINGS: PackedStringArray = PackedStringArray([
	"camera ▸ Set as active camera",
	"camera ▸ Set limit_left to 0",
	"camera ▸ Set limit_right to 1920",
	"camera ▸ Set position_smoothing_enabled to true",
	"sprite ▸ Set material to null"
])

## The statements whose sentence these three items settle, as "object ▸ sentence".
static var STATEMENT_READINGS: Dictionary = {
	"sprite.material.set_shader_parameter(\"flash\", 1.0)":
		"sprite ▸ Set effect parameter flash to 1",
	"material.set_shader_parameter(&\"flash\", 1.0)":
		"Player ▸ Set effect parameter flash to 1",
	"sprite.material = null": "sprite ▸ Remove effect",
	"sprite.material = preload(\"res://outline.tres\")": "sprite ▸ Set effect to outline",
	"tween.tween_method(func(v): mat.set_shader_parameter(\"dissolve\", v), 0.0, 1.0, 0.5)":
		"mat ▸ Tween effect parameter dissolve from 0 to 1 in 0.5 seconds",
	# Both node generations
	"tilemap.set_cell(0, cell, 1, Vector2i(2, 0))":
		"tilemap ▸ Set tile at cell to 2, 0 (layer 0 · tileset 1)",
	"tilemap.set_cell(cell, 1, Vector2i(2, 0))": "tilemap ▸ Set tile at cell to 2, 0 (tileset 1)",
	"tilemap.erase_cell(0, cell)": "tilemap ▸ Erase tile at cell (layer 0)",
	"tilemap.erase_cell(cell)": "tilemap ▸ Erase tile at cell",
	"camera.make_current()": "camera ▸ Make current",
	"camera.zoom = Vector2(2, 2)": "camera ▸ Set zoom to 200%",
	"camera.position_smoothing_enabled = true": "camera ▸ Set smoothing on",
	"camera.position_smoothing_enabled = false": "camera ▸ Set smoothing off",
	"camera.global_position = camera.global_position.lerp(target.global_position, 5 * delta)":
		"camera ▸ Scroll toward target at 5 (per second)"
}

## The questions these items settle, as "object ▸ sentence". Both spellings of the tile question
## answer alike: the local a line above filled, and the call written out the way a picked row writes it.
static var CONDITION_READINGS: Dictionary = {
	"data and data.get_custom_data(\"solid\")": "tilemap ▸ tile at cell has solid set",
	"data != null and data.get_custom_data(\"solid\")": "tilemap ▸ tile at cell has solid set",
	"tilemap.get_cell_tile_data(cell) != null and tilemap.get_cell_tile_data(cell).get_custom_data(\"solid\")":
		"tilemap ▸ tile at cell has solid set"
}

## The values these items name, and what the sheet calls them.
static var EXPRESSION_READINGS: Dictionary = {
	"sprite.material.get_shader_parameter(\"flash\")": "sprite's effect parameter \"flash\"",
	"tilemap.get_cell_source_id(0, cell)": "tilemap.TileAt(cell)",
	"tilemap.get_cell_source_id(cell)": "tilemap.TileAt(cell)",
	"tilemap.local_to_map(position)": "tilemap.PositionToTile(position)",
	"tilemap.map_to_local(cell)": "tilemap.TileToPosition(cell)"
}

## The shapes that must NOT be claimed: a lerp follow on something that is not a camera, a lambda
## that does more than hand its parameter over, and a tile question whose guard is about something
## else. A reading that is ALMOST right is worse than the code it replaced.
static var REFUSED_STATEMENTS: PackedStringArray = PackedStringArray([
	"sprite.global_position = sprite.global_position.lerp(target.global_position, 5 * delta)",
	"camera.global_position = camera.global_position.lerp(target.global_position, 0.5)",
	"tween.tween_method(func(v): mat.set_shader_parameter(\"dissolve\", v * 2), 0.0, 1.0, 0.5)"
])


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	var opened: Dictionary = _open_and_read()
	var readings: PackedStringArray = opened.get("readings", PackedStringArray())
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	for forbidden: String in FORBIDDEN_READINGS:
		ok = _check("no row still reads \"%s\"" % forbidden, readings.has(forbidden), false) and ok
	ok = _pattern_claims(opened.get("patterns", {})) and ok
	ok = _round_trip() and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] effects_tilemap_camera_reading_test: %s" % label)
		return true
	print("[FAIL] effects_tilemap_camera_reading_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


## The sentence context an opened 2D script hands the grammar: what the script is, what its object
## variables are, and which local the tile data came from.
static func _context() -> Dictionary:
	return {
		"self_object": "Player",
		"script_object": "Player",
		"self_class": "Node2D",
		"object_classes": {
			"sprite": "Sprite2D", "tilemap": "TileMap", "camera": "Camera2D", "target": "Node2D"
		},
		"engine_properties": {"position": true, "global_position": true},
		"tile_data_locals": {"data": {"object": "tilemap", "cell": "cell"}}
	}


## Gate one: the grammar answering on its own, value by value.
static func _grammar_values() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	for code: String in STATEMENT_READINGS:
		ok = _check("statement %s" % code, _joined_segments(EventSheetSentence.statement(code, context)),
			str(STATEMENT_READINGS[code])) and ok
	for expression: String in CONDITION_READINGS:
		ok = _check("condition %s" % expression,
			_joined_pieces(EventSheetSentence.condition_pieces(expression, context)),
			str(CONDITION_READINGS[expression])) and ok
	for value: String in EXPRESSION_READINGS:
		ok = _check("expression %s" % value, EventSheetSentence.expression_text(value, context),
			str(EXPRESSION_READINGS[value])) and ok
	for refused: String in REFUSED_STATEMENTS:
		ok = _check("refused %s" % refused, EventSheetSentence.statement(refused, context).has("pattern"),
			false) and ok
	# The pattern each reading carries, which is the only thing the registry is filled from.
	ok = _check("an effect row claims the effects pattern",
		str(EventSheetSentence.statement("sprite.material = null", context).get("pattern", "")),
		"effects") and ok
	ok = _check("a tile row claims the tilemap pattern",
		str(EventSheetSentence.statement("tilemap.erase_cell(cell)", context).get("pattern", "")),
		"tilemap") and ok
	ok = _check("a camera row claims the camera pattern",
		str(EventSheetSentence.statement("camera.make_current()", context).get("pattern", "")),
		"camera") and ok
	# The two spellings of an effect parameter name are the same parameter.
	ok = _check("a StringName parameter reads as its bare name",
		EventSheetSentence.effect_parameter_name("&\"flash\""), "flash") and ok
	# An effect is named after the file it lives in.
	ok = _check("an effect resource is named after its file",
		EventSheetSentence.effect_resource_name("preload(\"res://fx/outline.tres\")"), "outline") and ok
	return ok


## One condition reading as "object ▸ sentence", or the bare sentence when no object is named.
static func _joined_pieces(reading: Dictionary) -> String:
	var text: String = ""
	for piece: Variant in (reading.get("pieces", []) as Array):
		text += str((piece as Array)[0])
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() else text.strip_edges()


## One statement reading as "object ▸ sentence".
static func _joined_segments(reading: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() else text.strip_edges()


## Writes the source, opens it as a sheet, walks every row and returns {readings, patterns} - the
## cell readings as "object ▸ text", and {pattern id: how many events claimed it}.
static func _open_and_read() -> Dictionary:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var readings: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		for span: SemanticSpan in row_data.spans:
			var object_label: String = str(span.metadata.get("object_label", ""))
			var text: String = span.text.strip_edges()
			readings.append("%s ▸ %s" % [object_label, text] if not object_label.is_empty() else text)
	var patterns: Dictionary = {}
	for claim: Variant in EventSheetPatternFacts.claims(sheet):
		var pattern: String = str((claim as Dictionary).get("pattern", ""))
		patterns[pattern] = int(patterns.get(pattern, 0)) + 1
	viewport.free()
	return {"readings": readings, "patterns": patterns}


## Every row in the tree, parents before children.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


## Gate three: every one of the three shapes is claimed in the registry, on the events that own them.
## Counted rather than merely present, so a reading that stops reaching one of its events is caught.
static func _pattern_claims(patterns: Dictionary) -> bool:
	var ok: bool = true
	ok = _check("the effects pattern is claimed on its three events",
		int(patterns.get("effects", 0)), 3) and ok
	ok = _check("the tilemap pattern is claimed on its three events",
		int(patterns.get("tilemap", 0)), 3) and ok
	ok = _check("the camera pattern is claimed on its two events",
		int(patterns.get("camera", 0)), 2) and ok
	return ok


## Gate four: every reading here is a lens over a value the row already holds, so opening the file
## and saving it untouched puts back every byte.
static func _round_trip() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)
