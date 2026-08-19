@tool
class_name ReadingRowNotesTest
extends RefCounted

# U3. A note on one action is how a sheet comments a single step, and a trailing `# ...` is how
# GDScript writes exactly that. Until this batch the note was swallowed into whatever value the lift
# put the end of the line in ("Subtract 1  # ouch from hp"), and a TODO was invisible outside the
# code. Three things now:
#
#   * a trailing `# note` reads as a muted note at the END of its row, on every path a row is drawn
#     through - the sentence path, the picked-ACE path and the local-declaration path;
#   * a TODO / FIXME / HACK / NOTE line written directly above a step is a note ON that step (every
#     other comment line stays the comment row it has always been);
#   * the same markers are counted by the Doctor and gathered under a "To do" folder in the Outline.
#
# Everything here is a lens over text the row already holds, so the byte round-trip is untouched -
# which is the last gate below.

const SOURCE_PATH := "user://eventforge_reading_row_notes.gd"

const SOURCE: String = """extends Node2D

signal died

var hp: int = 100
var target: Vector2 = Vector2.ZERO
var speed: float = 100.0

## Moves the player toward the cursor.
func chase() -> void:
	position = position.move_toward(target, speed)  # TODO tweak
	hp -= 1  # ouch
	# FIXME: this double-fires on respawn
	died.emit()
	var pad = 4  # room to breathe
	print(pad)
"""

## Every reading the opened file must contain. The note is drawn as its own trailing piece, so a row
## with one reads as the sentence plus the note - which is what these pin.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	"Node2D ▸ Set position to position.move_toward(target, speed)   💬 TODO tweak",
	"System ▸ Subtract 1 from hp   💬 ouch",
	"System ▸ Signal On Died   💬 FIXME: this double-fires on respawn",
	"💬 room to breathe"
])

## Readings the file must NOT contain: the note inside the value, and the FIXME still standing on its
## own after it was attached to the step below it.
static var FORBIDDEN_READINGS: PackedStringArray = PackedStringArray([
	"System ▸ Subtract 1  # ouch from hp",
	"= 4  # room to breathe",
	"FIXME: this double-fires on respawn"
])

## One line, split into [code, note]. The note is "" when the line carries none.
static var TRAILING_SPLITS: Dictionary = {
	"hp -= 1  # ouch": ["hp -= 1", "ouch"],
	"\tposition = target  # TODO tweak": ["\tposition = target", "TODO tweak"],
	"hp -= 1": ["hp -= 1", ""],
	# A `#` inside a literal is content somebody typed, and a colour is the commonest way to type one.
	"modulate = Color(\"#ff0000\")": ["modulate = Color(\"#ff0000\")", ""],
	"label = \"score # \" + str(n)": ["label = \"score # \" + str(n)", ""],
	# A line that is ONLY a comment stays a comment: there is no statement for a note to be about.
	"# just a note": ["# just a note", ""],
	# A `#` with nothing after it says nothing.
	"hp -= 1  #": ["hp -= 1  #", ""]
}

## One comment line, and the marker it opens with ("" for none).
static var TASK_MARKERS: Dictionary = {
	"# TODO tweak": "TODO",
	"# FIXME: this double-fires": "FIXME",
	"#HACK: works for now": "HACK",
	"# NOTE": "NOTE",
	"# todo lowercase is prose": "",
	"# tidy this up": "",
	"# TODOS are not TODO": ""
}


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	var readings: PackedStringArray = _open_and_read()
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	for forbidden: String in FORBIDDEN_READINGS:
		ok = _check("no row still reads \"%s\"" % forbidden, readings.has(forbidden), false) and ok
	ok = _doctor_values() and ok
	ok = _round_trip() and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] reading_row_notes_test: %s" % label)
		return true
	print("[FAIL] reading_row_notes_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


## Gate one: the split and the marker test, value by value. Both are pure.
static func _grammar_values() -> bool:
	var ok: bool = true
	for line: String in TRAILING_SPLITS:
		var split: PackedStringArray = EventSheetSentence.trailing_comment(line)
		var expected: Array = TRAILING_SPLITS[line]
		ok = _check("split %s" % line, [split[0], split[1]], expected) and ok
	for comment: String in TASK_MARKERS:
		ok = _check("marker %s" % comment, EventSheetSentence.task_note_marker(comment),
			str(TASK_MARKERS[comment])) and ok
	return ok


## The Doctor half: the same markers, found on a line of a file, with the marker named.
static func _doctor_values() -> bool:
	var ok: bool = true
	var found: Dictionary = EventSheetProjectDoctor.task_note_in("\tqueue_free()  # TODO pool this")
	ok = _check("the doctor names the marker", str(found.get("marker", "")), "TODO") and ok
	ok = _check("the doctor keeps the note's words", str(found.get("text", "")), "TODO pool this") and ok
	ok = _check("a doc comment is not a task note",
		EventSheetProjectDoctor.task_note_in("## What this does.").is_empty(), true) and ok
	ok = _check("a marker inside a literal is not a task note",
		EventSheetProjectDoctor.task_note_in("var s = \"# TODO\"").is_empty(), true) and ok
	ok = _check("an ordinary comment is not a task note",
		EventSheetProjectDoctor.task_note_in("# tidy this up").is_empty(), true) and ok
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


## The promise every reading here rests on: both lines are still in the file, so opening it and
## saving it puts back every byte.
static func _round_trip() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)
