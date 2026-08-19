@tool
class_name ReadingPatternsSceneTreeTest
extends RefCounted

# U2 / U4 / U5. The long tail of shapes a Godot script writes that an event sheet already has rows
# for, and that used to open as the code they are:
#
#   U2  a `match` pattern that binds a name, destructures a list or picks a table apart reads as the
#       condition it is, with the names it binds as chips; a range that counts down or steps says
#       which values the body sees
#   U4  a pure-data inner class is a Data type bar, and `new` / `duplicate` / `is` are three words
#   U5  the scene-tree idioms - the child named X, the layout, a unique name, X's path, and copying a
#       node already in the scene, which is Clone object rather than Create object
#
# Three gates, in the order they matter: the grammar's own values, the whole path (a hand-written
# file opened as a sheet and walked row by row), and the byte round-trip every one of these rests on.
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason its sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions.

const SOURCE_PATH := "user://eventforge_reading_patterns_scene_tree.gd"

const SOURCE: String = """extends Node2D

class Stats:
	var hp := 10
	var atk := 2

var event: Array = []
var hp: int = 100
var enemy: Node2D = null

func _process(_delta: float) -> void:
	var stats := Stats.new()
	var backup = stats.duplicate()
	var copy = enemy.duplicate()
	get_parent().add_child(copy)
	var hud = find_child("HUD")
	var boss = get_tree().current_scene.get_node("Boss")
	var bar = %HealthBar
	var path = enemy.get_path()
	print(stats, backup, hud, boss, bar, path)
	match event:
		["move", var x, var y]:
			position = Vector2(x, y)
		{"type": "hit", "amount": var a}:
			hp -= a
		var other when other is String:
			print(other)
		_:
			pass
	for i in range(10, 0, -1):
		print(i)
	for i in range(0, 100, 10):
		print(i)
"""

## Every reading the opened file must contain, one per shape this batch claims.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	# U4 - the data type and the three words. A local's starting value is drawn as its own span, so
	# the reading arrives with the `=` the declaration row puts in front of it.
	"Data type Stats",
	"= a new Stats",
	"= a copy of stats",
	# U5 - the scene tree
	"= the child named HUD",
	"= Boss in the layout",
	"= HealthBar (unique name)",
	"= enemy's path",
	"System ▸ Clone object enemy (→ copy, next to it)",
	# U2 - the patterns, as the Else-if chain M37 built
	"System ▸ event is a list of 3 starting \"move\"",
	"System ▸ event is a table with type = \"hit\"",
	"System ▸ event is text",
	"amount → a",
	# U2 - the two loop shapes
	"System ▸ For \"i\" from 10 down to 1",
	"System ▸ For \"i\" from 0 to 90 step 10"
])

## Readings the file must NOT contain: the code each shape replaced.
static var FORBIDDEN_READINGS: PackedStringArray = PackedStringArray([
	"class Stats",
	"System ▸ Repeat 10, 0, -1 times (loopindex i)",
	"System ▸ Repeat 0, 100, 10 times (loopindex i)",
	"[\"move\", var x, var y]",
	"{\"type\": \"hit\", \"amount\": var a}",
	"var other when other is String"
])

## U2 - one match pattern, one condition sentence, over the subject `event`. The value is
## "sentence | chip, chip" so the bindings are pinned as well as the words.
static var PATTERN_READINGS: Dictionary = {
	"[\"move\", var x, var y]": "event is a list of 3 starting \"move\" | x, y",
	"[var a, var b]": "event is a list of 2 | a, b",
	"[\"quit\"]": "event is a list of 1 starting \"quit\" | ",
	"{\"type\": \"hit\", \"amount\": var a}": "event is a table with type = \"hit\" | amount → a",
	"{\"type\": \"hit\", \"from\": \"boss\"}": "event is a table with type = \"hit\" and from = \"boss\" | ",
	"{\"type\": var kind}": "event is a table | type → kind",
	"var other when other is String": "event is text | other",
	"var other when other > 5": "event > 5 | other",
	"var other": " | other",
	"_": " | "
}

## The patterns that say more than a reading can, and so keep the exact text they were written as.
static var REFUSED_PATTERNS: PackedStringArray = PackedStringArray([
	"[\"move\", ..]", "[var x, \"move\"]", "[compute()]", "{\"k\": compute()}", "var 1bad"
])

## U4 / U5 - one value expression, one reading.
static var EXPRESSION_READINGS: Dictionary = {
	"Stats.new()": "a new Stats",
	"stats.duplicate()": "a copy of stats",
	"stats.duplicate(true)": "a copy of stats",
	"find_child(\"HUD\")": "the child named HUD",
	"hud.find_child(\"Bar\")": "hud's child named Bar",
	"get_tree().current_scene": "the layout",
	"get_tree().current_scene.get_node(\"Boss\")": "Boss in the layout",
	"%HealthBar": "HealthBar (unique name)",
	"enemy.get_path()": "enemy's path",
	# The three other things a `%` is, all left exactly as they were written.
	"\"Score: %d\" % score": "\"Score: \" & score",
	"a % b": "a % b",
	"randi() % n": "randi() % n"
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
		print("[PASS] reading_patterns_scene_tree_test: %s" % label)
		return true
	print("[FAIL] reading_patterns_scene_tree_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


static func _context() -> Dictionary:
	return {
		"self_object": "Player",
		"script_object": "Player",
		"self_class": "Node2D",
		"engine_properties": {"position": true, "modulate": true},
		"variable_types": {"event": "Array", "hp": "int"}
	}


## Gate one: the grammar answering on its own, value by value.
static func _grammar_values() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	for pattern: String in PATTERN_READINGS:
		var reading: Dictionary = EventSheetSentence.match_pattern_reading("event", pattern, context)
		var chips: PackedStringArray = reading.get("chips", PackedStringArray()) as PackedStringArray
		ok = _check("pattern %s" % pattern,
			"%s | %s" % [str(reading.get("text", "")), ", ".join(chips)],
			str(PATTERN_READINGS[pattern])) and ok
	for refused: String in REFUSED_PATTERNS:
		ok = _check("pattern %s keeps its own text" % refused,
			EventSheetSentence.match_pattern_reading("event", refused, context).is_empty(), true) and ok
	for expression: String in EXPRESSION_READINGS:
		ok = _check("value %s" % expression, EventSheetSentence.expression_text(expression, context),
			str(EXPRESSION_READINGS[expression])) and ok
	return ok


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


## The promise every reading here rests on: opening the file and saving it puts back every byte.
static func _round_trip() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)
