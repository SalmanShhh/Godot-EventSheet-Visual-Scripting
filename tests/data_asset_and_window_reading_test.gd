@tool
class_name DataAssetAndWindowReadingTest
extends RefCounted

# Pins the two readings batch eleven adds - the last two families a plain Godot script is made of
# that had no words of their own:
#
#   Data assets: a Resource script is a DATA TYPE (its @exports are Fields), a field read off
#       one reads with the possessive, `load("x.tres") as Type` is "the data asset x.tres", and
#       ResourceSaver.save is "Save data asset r as path"
#   The window, render and screenshot lines: size / title / fullscreen / vsync on the Window
#       object, the frame cap and the anti-aliasing level on System, a screenshot as one phrase and
#       a saved picture as one row
#
# Four gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the whole path - a hand-written file opened as a sheet, walked row by row, so a reading that
#      stops reaching the canvas is caught even when the grammar still answers on its own;
#   3. the pattern claims - "data_asset" and "window" recorded on the event that owns them, which is
#      what every chip, hover and Doctor note downstream reads;
#   4. the promise both rest on - the file still saves byte-identically, because every one of these
#      is a lens over a value the row already holds.
#
# The sources live here as strings rather than in tests/fixtures/ for the same reason the sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions, so a checked-in two-blank-line file could
# never lift and the fixture would silently test nothing.

const WINDOW_PATH := "user://eventforge_window_reading.gd"

const WINDOW_SOURCE: String = """extends Node

var img: Image
var tex: Texture2D

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	get_window().title = "My Game"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = 60
	get_viewport().msaa_2d = Viewport.MSAA_4X

func take_shot() -> void:
	img = get_viewport().get_texture().get_image()
	img.save_png("user://shot.png")
	tex = $SubViewport.get_texture()
"""

const ASSET_PATH := "user://eventforge_data_asset_reading.gd"

const ASSET_SOURCE: String = """extends Node

@export var stats: Resource
var hp: int = 0
var s: Resource

func _ready() -> void:
	hp = stats.hp
	s = load("res://data/slime.tres")
	ResourceSaver.save(stats, "res://data/slime.tres")
"""

## The statements whose sentence this parcel settles, as "object ▸ sentence".
static var STATEMENT_READINGS: Dictionary = {
	# The window
	"get_window().size = Vector2i(1280, 720)": "Window ▸ Set size to 1280 × 720",
	"get_window().title = \"My Game\"": "Window ▸ Set title to \"My Game\"",
	"get_window().mode = Window.MODE_FULLSCREEN": "Window ▸ Set fullscreen on",
	"get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN": "Window ▸ Set fullscreen on (exclusive)",
	"get_window().mode = Window.MODE_WINDOWED": "Window ▸ Set fullscreen off",
	"get_window().mode = Window.MODE_MAXIMIZED": "Window ▸ Maximize",
	"DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)": "Window ▸ Set vsync on",
	"DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)": "Window ▸ Set vsync off",
	# The picked row writes the switch as a ternary; both spellings are one sentence.
	"DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if true else DisplayServer.VSYNC_DISABLED)":
		"Window ▸ Set vsync on",
	# The render and screenshot half
	"Engine.max_fps = 60": "System ▸ Set max FPS to 60",
	"get_viewport().msaa_2d = Viewport.MSAA_4X": "System ▸ Set anti-aliasing to 4×",
	"get_viewport().msaa_3d = Viewport.MSAA_DISABLED": "System ▸ Set anti-aliasing to off",
	"img.save_png(\"user://shot.png\")": "System ▸ Save image img as shot.png",
	# The data assets
	"ResourceSaver.save(stats, \"res://data/slime.tres\")":
		"System ▸ Save data asset stats as slime.tres"
}

## The whole-expression readings: a value that is ONE settled phrase rather than a chain to repeat
## back. Each is asked of `expression_text`, which is what fills the value of every Set row.
static var EXPRESSION_READINGS: Dictionary = {
	"get_viewport().get_texture().get_image()": "a screenshot",
	"get_window().get_texture().get_image()": "a screenshot",
	"$SubViewport.get_texture()": "SubViewport rendered as an image",
	"load(\"res://data/slime.tres\")": "the data asset slime.tres",
	"load(\"res://data/slime.tres\") as EnemyStats": "the data asset slime.tres",
	"preload(\"res://data/slime.tres\")": "the data asset slime.tres",
	# A field read off a declared data asset says whose field it is.
	"stats.hp": "stats's hp"
}

## The values that must NOT be claimed - the guard on every reading here. A load of a SCENE is not a
## data asset, a texture on a node is not a viewport's picture, and a plain member read on something
## that is not a data asset stays the chain it is.
static var UNCLAIMED_EXPRESSIONS: Dictionary = {
	"load(\"res://levels/level_2.tscn\")": "the data asset",
	"load(path)": "the data asset",
	"hp.value": "'s"
}

## Every reading the opened window file must contain. Some of these lines LIFT to the shipped Game
## Window rows and some stay verbatim, and both are pinned on purpose: the point of this parcel is
## that a picked row and a typed line say the SAME sentence and wear the same object, so a rename on
## either side has to be made on both.
static var EXPECTED_WINDOW_READINGS: PackedStringArray = PackedStringArray([
	"Window ▸ Set size to 1280 × 720",
	"Window ▸ Set title to \"My Game\"",
	"Window ▸ Set vsync on",
	"System ▸ Set max FPS to 60",
	"System ▸ Set img to a screenshot",
	"System ▸ Set tex to SubViewport rendered as an image"
])

## Every reading the opened data file must contain.
static var EXPECTED_ASSET_READINGS: PackedStringArray = PackedStringArray([
	"System ▸ Set s to the data asset slime.tres"
])


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	ok = _type_words() and ok
	ok = _opened_file() and ok
	ok = _claims() and ok
	ok = _round_trip(WINDOW_PATH, WINDOW_SOURCE) and ok
	ok = _round_trip(ASSET_PATH, ASSET_SOURCE) and ok
	return ok


## Gate one: the grammar answering on its own, value by value.
static func _grammar_values() -> bool:
	var ok: bool = true
	for code: String in STATEMENT_READINGS:
		ok = _check("statement \"%s\"" % code, _sentence_of(code), str(STATEMENT_READINGS[code])) and ok
	for value: String in EXPRESSION_READINGS:
		ok = _check("value \"%s\"" % value,
			EventSheetSentence.expression_text(value, _context()), str(EXPRESSION_READINGS[value])) and ok
	for value: String in UNCLAIMED_EXPRESSIONS:
		ok = _check("value \"%s\" is left alone" % value,
			EventSheetSentence.expression_text(value, _context()).contains(str(UNCLAIMED_EXPRESSIONS[value])),
			false) and ok
	# A window member nobody has words for keeps the plain property write it is.
	ok = _check("an unknown window mode is not claimed",
		EventSheetSentence.window_statement("get_window().mode = some_mode", _context()).is_empty(),
		true) and ok
	ok = _check("a save of something that is not a data asset is not claimed",
		EventSheetSentence.data_asset_statement("ResourceSaver.save(stats)", _context()).is_empty(),
		true) and ok
	return ok


## Which declared types ARE data assets - the question the possessive rests on. Resource itself
## and every engine Resource subclass; a node class and a number are not.
static func _type_words() -> bool:
	var ok: bool = true
	ok = _check("Resource is a data type", EventSheetSentence.is_data_asset_type("Resource"), true) and ok
	ok = _check("AudioStream is a data type",
		EventSheetSentence.is_data_asset_type("AudioStream"), true) and ok
	ok = _check("CharacterBody2D is not a data type",
		EventSheetSentence.is_data_asset_type("CharacterBody2D"), false) and ok
	ok = _check("int is not a data type", EventSheetSentence.is_data_asset_type("int"), false) and ok
	# A picture reads as a picture whichever of Godot's two spellings holds it.
	ok = _check("an Image is an image", EventSheetSentence.type_word("Image"), "image") and ok
	ok = _check("a Texture2D is an image", EventSheetSentence.type_word("Texture2D"), "image") and ok
	return ok


## Gate two: the file opened as a sheet, walked row by row.
static func _opened_file() -> bool:
	var ok: bool = true
	_write(WINDOW_PATH, WINDOW_SOURCE)
	var readings: PackedStringArray = _open_and_read(WINDOW_PATH)
	for expected: String in EXPECTED_WINDOW_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	_write(ASSET_PATH, ASSET_SOURCE)
	var asset_readings: PackedStringArray = _open_and_read(ASSET_PATH)
	for expected: String in EXPECTED_ASSET_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, asset_readings.has(expected), true) and ok
	# The words each shape replaced. A reading that silently stopped firing would pass the lists
	# above by never being asked about.
	ok = _check("no row still reads the raw frame cap",
		readings.has("System ▸ Set max_fps to 60"), false) and ok
	ok = _check("no window row is still filed under System",
		readings.has("System ▸ Set size to 1280 × 720"), false) and ok
	return ok


## Gate three: both patterns claimed on the event that owns them, with the source lines as evidence.
static func _claims() -> bool:
	var ok: bool = true
	_write(WINDOW_PATH, WINDOW_SOURCE)
	_write(ASSET_PATH, ASSET_SOURCE)
	var window_claims: Dictionary = _claims_of(WINDOW_PATH)
	ok = _check("the window file claims the window pattern", window_claims.has("window"), true) and ok
	# A half-lifted event is the normal case, so the ids of the rows that DID lift count as evidence
	# beside the lines that stayed verbatim - which is why the gate asks for either spelling.
	var window_evidence: String = "\n".join(
		window_claims.get("window", PackedStringArray()) as PackedStringArray)
	ok = _check("the window claim keeps what it saw as evidence",
		window_evidence.contains("Engine.max_fps") or window_evidence.contains("WindowSetMaxFps"),
		true) and ok
	var asset_claims: Dictionary = _claims_of(ASSET_PATH)
	ok = _check("the data file claims the data_asset pattern", asset_claims.has("data_asset"), true) and ok
	var asset_evidence: String = "\n".join(
		asset_claims.get("data_asset", PackedStringArray()) as PackedStringArray)
	ok = _check("the data claim keeps what it saw as evidence",
		asset_evidence.contains("ResourceSaver.save") or asset_evidence.contains("SaveDataAsset"),
		true) and ok
	return ok


## {pattern: every evidence line claimed for it} for one opened file.
static func _claims_of(path: String) -> Dictionary:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	EventSheetPatternFacts.clear(sheet)
	EventSheetViewportReadingRows.claim_godot_systems_patterns(sheet)
	var found: Dictionary = {}
	for entry: Variant in EventSheetPatternFacts.claims(sheet):
		var claim: Dictionary = entry
		var pattern: String = str(claim.get("pattern", ""))
		var lines: PackedStringArray = found.get(pattern, PackedStringArray())
		lines.append_array(claim.get("evidence", PackedStringArray()))
		found[pattern] = lines
	return found


## Gate four: the promise every reading here rests on. Each is a lens over a value the row already
## holds, so opening the file and saving it untouched puts back every byte.
static func _round_trip(path: String, source: String) -> bool:
	_write(path, source)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	var output: String = str(SheetCompiler.compile(sheet, path).get("output", ""))
	return _check("%s saves every byte back" % path.get_file(), output, source)


## One statement as "object ▸ sentence", the way a row draws it.
static func _sentence_of(code: String) -> String:
	var reading: Dictionary = EventSheetSentence.statement(code, _context())
	if reading.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in (reading.get("segments", []) as Array):
		parts.append(str((entry as Dictionary).get("text", "")))
	var object_label: String = str(reading.get("object", ""))
	var sentence: String = "".join(parts).strip_edges()
	return "%s ▸ %s" % [object_label, sentence] if not object_label.is_empty() else sentence


## Every row's reading in an opened file, as "object ▸ sentence".
static func _open_and_read(path: String) -> PackedStringArray:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	var viewport := EventSheetViewport.new()
	viewport.set_sheet(sheet)
	var readings: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		for span: SemanticSpan in row_data.spans:
			var object_label: String = str(span.metadata.get("object_label", ""))
			var text: String = span.text.strip_edges()
			readings.append("%s ▸ %s" % [object_label, text] if not object_label.is_empty() else text)
	viewport.free()
	return readings


## Every row in the tree, parents before children.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


static func _write(path: String, source: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(source)
		file.close()


## The sentence context an opened script hands the grammar.
static func _context() -> Dictionary:
	return {
		"self_object": "Enemy",
		"script_object": "Enemy",
		"self_class": "Node",
		"variable_types": {"stats": "Resource", "hp": "int", "img": "Image"}
	}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] data_asset_and_window_reading_test: %s" % label)
		return true
	print("[FAIL] data_asset_and_window_reading_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
