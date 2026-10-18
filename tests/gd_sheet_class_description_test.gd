# Godot EventSheets - a class description edited in a .gd sheet reaches the file.
#
# The lift reads a `.gd` sheet's class description from the `##` block right under `extends`, but
# the opened-file save wrote that block back exactly as it opened, so an edit made in the Sheet Type
# dialog (or the head band) was dropped on save and gone on reopen. The save now rewrites the block
# when it no longer reads as the sheet's description, adds one when the file had none, and removes it
# when the description is cleared. An untouched block keeps its own spelling byte for byte.
#
# Every case is a REAL file: opened, edited, saved over itself, parsed, opened again, saved again.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")
const TEST_NAME := "gd_sheet_class_description_test"
const FILE_PATH := "user://gd_sheet_class_description_test.gd"
const RESAVE_PATH := "user://gd_sheet_class_description_test_resave.gd"

const WITH_BLOCK := "extends Node2D\n## Catches stars.\n## Two lines of it.\n\nvar score: int = 0\n\n\nfunc _ready() -> void:\n\tscore = 1\n"
const WITHOUT_BLOCK := "class_name DescriptionProbe\nextends Node2D\n\nvar score: int = 0\n\n\nfunc _ready() -> void:\n\tscore = 1\n"
const MEMBER_DOC := "extends Node2D\n## How many stars were caught.\nvar score: int = 0\n\n\nfunc _ready() -> void:\n\tscore = 1\n"
const ODD_SPELLING := "extends Node2D\n##Catches stars.\n\nvar score: int = 0\n"


static func run() -> bool:
	var edited: Dictionary = _cycle(WITH_BLOCK, "Catches falling stars.")
	var added: Dictionary = _cycle(WITHOUT_BLOCK, "A probe.\n\nWith a second paragraph.")
	var beside_doc: Dictionary = _cycle(MEMBER_DOC, "A probe.")
	var cleared: Dictionary = _cycle(WITH_BLOCK, "")
	var untouched: Dictionary = _cycle(ODD_SPELLING, null)
	return SUPPORT.pins(TEST_NAME, [
		["an edited description replaces the block", _head(edited, 3), ["extends Node2D", "## Catches falling stars.", ""]],
		["and reopens as the edit", edited.get("description"), "Catches falling stars."],
		["and saves again byte for byte", edited.get("resaved"), edited.get("saved")],
		["a description added to a file with none goes under extends, a blank line after it",
			_head(added, 7), ["class_name DescriptionProbe", "extends Node2D", "## A probe.", "##", "## With a second paragraph.", "", "var score: int = 0"]],
		["and reopens as written", added.get("description"), "A probe.\n\nWith a second paragraph."],
		["added beside a member's doc comment, it leaves that comment on its member",
			_head(beside_doc, 5), ["extends Node2D", "## A probe.", "", "## How many stars were caught.", "var score: int = 0"]],
		["and reopens as the class description", beside_doc.get("description"), "A probe."],
		["a cleared description takes its block away", _head(cleared, 3), ["extends Node2D", "", "var score: int = 0"]],
		["and reopens with none", cleared.get("description"), ""],
		["every saved script parses",
			[edited.get("parse"), added.get("parse"), beside_doc.get("parse"), cleared.get("parse")], ["", "", "", ""]],
		["an untouched block keeps its own spelling", untouched.get("saved"), ODD_SPELLING],
	])


## Writes `source`, opens it, sets the class description to `description` (null leaves it alone),
## saves over the file and opens it again: {saved, parse, description, resaved}.
static func _cycle(source: String, description: Variant) -> Dictionary:
	_write(FILE_PATH, source)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	if description != null:
		sheet.class_description = str(description)
	SheetCompiler.compile(sheet, FILE_PATH)
	var saved: String = FileAccess.get_file_as_string(FILE_PATH)
	var reopened: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	_write(RESAVE_PATH, saved)
	reopened.external_source_path = RESAVE_PATH
	SheetCompiler.compile(reopened, RESAVE_PATH)
	return {"saved": saved, "parse": _parse_error(saved), "description": reopened.class_description,
		"resaved": FileAccess.get_file_as_string(RESAVE_PATH)}


static func _head(round_trip: Dictionary, count: int) -> Array:
	var head: Array = []
	for line: String in str(round_trip.get("saved", "")).split("\n").slice(0, count):
		head.append(line)
	return head


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## "" when `source` parses as a script, else the error it fails with (class_name left out so the probe
## cannot collide with a class the project knows).
static func _parse_error(source: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		kept.append("" if line.begins_with("class_name ") else line)
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(kept)
	var error: int = script.reload()
	return "" if error == OK else error_string(error)
