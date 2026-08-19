@tool
class_name ReadingVectorsColoursTest
extends RefCounted

# U1. Vectors and colours are the two value types every game line touches, and until this batch a
# reader met them as the Godot methods that built them: `normalized()`, `dot()`, `darkened(0.2)`.
# Each operation now reads as the word an event sheet already has for it, with Godot's own spelling
# one hover away.
#
# Three gates, in the order they matter:
#   1. the grammar's own values - one shape, one reading, asserted literally;
#   2. the whole path - a hand-written file opened as a sheet, walked row by row, so a reading that
#      stops reaching the canvas is caught even when the grammar still answers on its own;
#   3. the promise all of it rests on - the file still saves byte-identically, because every reading
#      here is a lens over a value the row already holds.
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason its sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions, so a checked-in two-blank-line file could
# never lift and the fixture would silently test nothing.

const SOURCE_PATH := "user://eventforge_reading_vectors_colours.gd"

const SOURCE: String = """extends Node2D

var target: Node2D = null
var facing: Vector2 = Vector2(1, 0)

func _process(delta: float) -> void:
	var dir = (target.position - position).normalized()
	var dist = velocity.length()
	var up = Vector2.UP
	var dot = facing.dot(dir)
	var ang = facing.angle_to(dir)
	var side = dir.rotated(PI / 2)
	var c = Color.from_hsv(0.3, 1, 1)
	modulate = Color.RED.darkened(0.2)
	modulate = Color(1, 0, 0, 0.5)
	modulate = modulate.lerp(Color.WHITE, 5 * delta)
	print(dir, dist, up, dot, ang, side, c)
"""

## Every reading the opened file must contain, one per shape U1 claims.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	"System ▸ Set tint to red, 20% darker",
	"System ▸ Set tint to red at 50% opacity",
	"Node2D ▸ Ease colour toward white at 5"
])

## Readings the file must NOT contain: the code each shape replaced. A reading that silently stops
## firing would otherwise pass the list above by never being asked about.
static var FORBIDDEN_READINGS: PackedStringArray = PackedStringArray([
	"System ▸ Set tint to Color.RED.darkened(0.2)",
	"System ▸ Set tint to Color(1, 0, 0, 0.5)"
])

## One value expression, one reading. These are the words the row shows in place of the call.
static var EXPRESSION_READINGS: Dictionary = {
	# The direction between two places - the one thing every chase line means.
	"(target.position - position).normalized()": "the direction from Player to target",
	"(b.position - a.position).normalized()": "the direction from a to b",
	# A vector on its own, and the one length that has a shorter name.
	"dir.normalized()": "unit vector of dir",
	"velocity.length()": "the speed",
	"linear_velocity.length()": "the speed",
	"reach.length()": "length of reach",
	# The two questions a facing vector answers.
	"facing.dot(dir)": "how much facing points along dir (-1 to 1)",
	"facing.angle_to(dir)": "angle from facing to dir",
	# A turn, written the way a turn is written.
	"dir.rotated(PI / 2)": "dir turned 90°",
	"dir.rotated(-PI / 2)": "dir turned -90°",
	"dir.rotated(TAU / 4)": "dir turned 90°",
	"dir.rotated(PI)": "dir turned 180°",
	"dir.rotated(deg_to_rad(45))": "dir turned 45°",
	# A turn by something with a NAME in it is not a number the row can show, so it keeps its code.
	"dir.rotated(PI / sides)": "dir.rotated(π / sides)",
	# The constants, by the name a reader says.
	"Vector2.UP": "up",
	"Vector2.ZERO": "(0, 0)",
	"Vector3.FORWARD": "forward",
	# Colours: the named ones, the shades, the opacity and the two builders.
	"Color.RED": "red",
	"Color.RED.darkened(0.2)": "red, 20% darker",
	"Color.BLUE.lightened(0.5)": "blue, 50% lighter",
	"Color(1, 0, 0, 0.5)": "red at 50% opacity",
	"Color(1, 1, 1)": "white",
	"Color(0.2, 0.4, 0.6)": "0.2, 0.4, 0.6",
	"Color.from_hsv(0.3, 1, 1)": "colour from hue 30%, full saturation",
	"Color.from_hsv(0.5, 0.4, 0.8)": "colour from hue 50%, 40% saturation, 80% brightness",
	"Color.from_string(\"#ff8800\", Color.WHITE)": "colour from \"#ff8800\""
}

## The statements U1 settles, as "object ▸ sentence".
static var STATEMENT_READINGS: Dictionary = {
	"modulate = modulate.lerp(Color.WHITE, 5 * delta)": "Player ▸ Ease colour toward white at 5",
	"self_modulate = self_modulate.lerp(Color.RED, fade * delta)":
		"Player ▸ Ease colour toward red at fade",
	# A blend that does NOT read the member it writes is not an ease, and keeps the Set it is.
	"modulate = other.lerp(Color.WHITE, 5 * delta)": "Player ▸ Set modulate to other.lerp(white, 5 * dt)"
}


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	var readings: PackedStringArray = _open_and_read()
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	for forbidden: String in FORBIDDEN_READINGS:
		ok = _check("no row still reads \"%s\"" % forbidden, readings.has(forbidden), false) and ok
	ok = _round_trip() and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] reading_vectors_colours_test: %s" % label)
		return true
	print("[FAIL] reading_vectors_colours_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


## The sentence context an opened 2D script hands the grammar.
static func _context() -> Dictionary:
	return {
		"self_object": "Player",
		"script_object": "Player",
		"self_class": "Node2D",
		"engine_properties": {"position": true, "rotation": true, "modulate": true, "velocity": true},
		"variable_types": {"facing": "Vector2", "fade": "float"}
	}


## Gate one: the grammar answering on its own, value by value.
static func _grammar_values() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	for expression: String in EXPRESSION_READINGS:
		ok = _check("value %s" % expression, EventSheetSentence.expression_text(expression, context),
			str(EXPRESSION_READINGS[expression])) and ok
	for code: String in STATEMENT_READINGS:
		ok = _check("statement %s" % code, _joined_segments(EventSheetSentence.statement(code, context)),
			str(STATEMENT_READINGS[code])) and ok
	return ok


## One statement reading as "object ▸ sentence".
static func _joined_segments(reading: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() else text.strip_edges()


## Writes the source, opens it as a sheet, and returns every cell reading.
static func _open_and_read() -> PackedStringArray:
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


## The promise every reading here rests on: each one is a lens over a value the row already holds,
## so opening the file and saving it untouched puts back every byte.
static func _round_trip() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)
