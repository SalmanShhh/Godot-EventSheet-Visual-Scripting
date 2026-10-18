# Godot EventSheets - a comment switched off in a .gd sheet stays in the file.
#
# A comment row that is off (Toggle Row Enabled) was left out of the compile, so in a `.gd` sheet -
# the sheet's only copy - saving deleted the note from the file. In a sheet that is its own `.gd` a
# comment that is off is now written behind `# @off: `, and the lift reads it back as the same
# comment, switched off: a note at the sheet's top level and a note among an event's actions alike.
#
# Every case is a REAL file: opened, one comment switched off, saved over itself, parsed, opened
# again and saved again byte for byte.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")
const TEST_NAME := "off_comment_kept_in_gd_test"
const FILE_PATH := "user://off_comment_kept_in_gd_test.gd"
const RESAVE_PATH := "user://off_comment_kept_in_gd_test_resave.gd"

const SOURCE := """extends Node2D

var score: int = 0


func _process(delta: float) -> void:
	if score > 10:
		# Reset once it gets too big.
		score = 0

# A note at the end of the sheet.
"""


static func run() -> bool:
	var untouched: Dictionary = _cycle(Callable())
	var top: Dictionary = _cycle(func(sheet: EventSheetResource) -> void: _top_comment(sheet).enabled = false)
	var in_event: Dictionary = _cycle(func(sheet: EventSheetResource) -> void: _event_comment(sheet).enabled = false)
	var top_saved: String = str(top.get("saved", ""))
	var event_saved: String = str(in_event.get("saved", ""))
	# On again, the file is the one it was.
	_write(FILE_PATH, top_saved)
	var back_on: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	var back_on_comment: CommentRow = _top_comment(back_on, false)
	if back_on_comment != null:
		back_on_comment.enabled = true
	SheetCompiler.compile(back_on, FILE_PATH)
	var on_again: String = FileAccess.get_file_as_string(FILE_PATH)
	return SUPPORT.pins(TEST_NAME, [
		["opened and saved untouched it is byte for byte the same", str(untouched.get("saved", "")), SOURCE],
		["a sheet's own comment, off: kept behind the marker", top_saved.ends_with("\n# @off: A note at the end of the sheet.\n"), true],
		["and it reopens as that comment, off", _state(_top_comment(top.get("reopened"), false)), [false, "A note at the end of the sheet."]],
		["and saves again byte for byte", str(top.get("resaved", "")), top_saved],
		["a comment among an event's actions, off: kept behind the marker",
			event_saved.contains("\tif score > 10:\n\t\t# @off: Reset once it gets too big.\n\t\tscore = 0\n"), true],
		["and it reopens as that comment, off", _state(_event_comment(in_event.get("reopened"), false)), [false, "Reset once it gets too big."]],
		["and saves again byte for byte too", str(in_event.get("resaved", "")), event_saved],
		["both saved scripts parse", [_parse_error(top_saved), _parse_error(event_saved)], ["", ""]],
		["on again, the file is back to what it was", on_again, SOURCE],
	])


## Writes SOURCE, opens it, applies `edit` (none for an invalid Callable), saves over the file and
## opens it again: {saved, reopened, resaved}.
static func _cycle(edit: Callable) -> Dictionary:
	_write(FILE_PATH, SOURCE)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	if edit.is_valid():
		edit.call(sheet)
	SheetCompiler.compile(sheet, FILE_PATH)
	var saved: String = FileAccess.get_file_as_string(FILE_PATH)
	var reopened: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	_write(RESAVE_PATH, saved)
	reopened.external_source_path = RESAVE_PATH
	SheetCompiler.compile(reopened, RESAVE_PATH)
	return {"saved": saved, "reopened": reopened, "resaved": FileAccess.get_file_as_string(RESAVE_PATH)}


## The sheet's own (top-level) comment row; `on_only` asks for one that is on.
static func _top_comment(sheet: Variant, on_only: bool = true) -> CommentRow:
	if not (sheet is EventSheetResource):
		return null
	for entry: Variant in (sheet as EventSheetResource).events:
		if entry is CommentRow and (not on_only or (entry as CommentRow).enabled):
			return entry as CommentRow
	return null


## The comment row among the _process event's actions.
static func _event_comment(sheet: Variant, on_only: bool = true) -> CommentRow:
	if not (sheet is EventSheetResource):
		return null
	for entry: Variant in (sheet as EventSheetResource).events:
		if entry is EventRow:
			for action: Variant in (entry as EventRow).actions:
				if action is CommentRow and (not on_only or (action as CommentRow).enabled):
					return action as CommentRow
	return null


static func _state(comment: CommentRow) -> Array:
	return [comment.enabled, comment.text] if comment != null else []


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## "" when `source` parses as a script, else the error it fails with.
static func _parse_error(source: String) -> String:
	var script: GDScript = GDScript.new()
	script.source_code = source
	var error: int = script.reload()
	return "" if error == OK else error_string(error)
