# Godot EventSheets - an action or condition switched off in a .gd sheet stays in the file.
#
# A cell whose box was unticked (Toggle Cell Enabled) was left out of the compile. A `.tres` sheet
# still holds it, but a `.gd` sheet has no other copy, so saving deleted the action or condition
# from the file. In a sheet that is its own `.gd`:
#   - an action that is off is written as its own lines behind `# @off: `, comments that never run;
#   - a condition that is off stays in the header as a term whose answer it cannot change -
#     `(true or <it>)` among And terms, `(false and <it>)` among Or terms, and `(true or <it>)` for
#     every term when all of an Or event's conditions are off (it then runs as an event with none).
# The lift reads each back as the same cell, switched off. Every case is a REAL file: opened, one
# cell switched off, saved over itself, parsed, opened again and saved again byte for byte.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")
const TEST_NAME := "off_cell_kept_in_gd_test"
const FILE_PATH := "user://off_cell_kept_in_gd_test.gd"
const RESAVE_PATH := "user://off_cell_kept_in_gd_test_resave.gd"

const SOURCE := """extends Node2D

var score: int = 0
var lives: int = 3


func _process(delta: float) -> void:
	if score > 10:
		score = 0
		lives += 1
	if lives > 5:
		lives = 5
	if score > 5 and lives > 0:
		print("both")
	if score > 5 or lives < 1:
		print("either")
"""


static func run() -> bool:
	var all_passed: bool = SUPPORT.pins(TEST_NAME, [
		["opened and saved untouched it is byte for byte the same", str(_cycle(0, "", -1).get("saved", "")), SOURCE],
	])
	# Each case: label, the event (n-th of _process), "action" or "condition" and which one, the lines
	# the save must hold, and the switched-off state of that event's cells when it is opened again.
	var cases: Array = [
		["an action among others", 0, "action", 0,
			"\tif score > 10:\n\t\t# @off: score = 0\n\t\tlives += 1\n", [[true], [false, true]]],
		["an event's only action", 1, "action", 0,
			"\tif lives > 5:\n\t\t# @off: lives = 5\n\t\tpass\n", [[true], [false]]],
		["an And condition", 2, "condition", 0,
			"\tif (true or score > 5) and lives > 0:\n\t\tprint(\"both\")\n", [[false, true], [true]]],
		["an Or condition", 3, "condition", 1,
			"\tif score > 5 or (false and lives < 1):\n\t\tprint(\"either\")\n", [[true, false], [true]]],
		["every Or condition", 3, "both", -1,
			"\tif (true or score > 5) or (true or lives < 1):\n\t\tprint(\"either\")\n", [[false, false], [true]]],
	]
	for case: Array in cases:
		var round_trip: Dictionary = _cycle(int(case[1]), str(case[2]), int(case[3]))
		var saved: String = str(round_trip.get("saved", ""))
		all_passed = SUPPORT.pins(TEST_NAME, [
			["%s: the save keeps it where it never runs" % case[0], saved.contains(str(case[4])), true],
			["%s: the saved script parses" % case[0], _parse_error(saved), ""],
			["%s: it reopens as the same cells, that one off" % case[0],
				_cell_state(_event(round_trip.get("reopened"), int(case[1]))), case[5]],
			["%s: and saves again byte for byte" % case[0], str(round_trip.get("resaved", "")), saved],
		]) and all_passed
	all_passed = _check_block_action() and all_passed
	all_passed = _check_stateful_condition() and all_passed
	# A .tres sheet's generated companion still leaves a cell that is off out.
	_write(FILE_PATH, SOURCE)
	var companion_sheet: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	_switch_off(_event(companion_sheet, 0), "action", 0)
	_switch_off(_event(companion_sheet, 2), "condition", 0)
	companion_sheet.external_source_path = ""
	var companion: String = str(SheetCompiler.echo(companion_sheet).get("output", ""))
	return SUPPORT.pins(TEST_NAME, [
		["a .tres companion still leaves cells that are off out",
			[companion.contains("# @off"), companion.contains("true or")], [false, false]],
	]) and all_passed


## An action whose template is a block (a loop with its body under it) switched off: read one line at
## a time, its first line is no action, so the whole run used to stay comments that could never be
## switched back on. It reopens as the block it is - a GDScript row, off - and on again it writes the
## loop it was.
static func _check_block_action() -> bool:
	_write(FILE_PATH, SOURCE)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	var block: ACEAction = ACEAction.new()
	block.provider_id = "Core"
	block.ace_id = "FreeChildren"
	block.codegen_template = "for child in get_children():\n\tchild.queue_free()"
	block.enabled = false
	_event(sheet, 0).actions.append(block)
	SheetCompiler.compile(sheet, FILE_PATH)
	var saved: String = FileAccess.get_file_as_string(FILE_PATH)
	var reopened: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	var read_back: Variant = _event(reopened, 0).actions.back() if _event(reopened, 0) != null else null
	var read_as: Array = [read_back is RawCodeRow, read_back.get("enabled"), read_back.get("code")] if read_back != null else []
	_write(RESAVE_PATH, saved)
	reopened.external_source_path = RESAVE_PATH
	SheetCompiler.compile(reopened, RESAVE_PATH)
	var resaved: String = FileAccess.get_file_as_string(RESAVE_PATH)
	if read_back is RawCodeRow:
		(read_back as RawCodeRow).enabled = true
	SheetCompiler.compile(reopened, RESAVE_PATH)
	var back_on: String = FileAccess.get_file_as_string(RESAVE_PATH)
	return SUPPORT.pins(TEST_NAME, [
		["a block action: the save keeps its lines where they never run",
			saved.contains("\t\tlives += 1\n\t\t# @off: for child in get_children():\n\t\t# @off: \tchild.queue_free()\n"), true],
		["a block action: the saved script parses", _parse_error(saved), ""],
		["a block action: it reopens as the block, off", read_as, [true, false, "for child in get_children():\n\tchild.queue_free()"]],
		["a block action: and saves again byte for byte", resaved, saved],
		["a block action: on again, it writes the loop", back_on.contains("\t\tlives += 1\n\t\tfor child in get_children():\n\t\t\tchild.queue_free()\n"), true],
		["a block action: and that parses", _parse_error(back_on), ""],
	])


## A condition that keeps state of its own (Every X Seconds) has no term to stay in while it is off,
## so the save leaves it out - and says so, naming it, rather than dropping it without a word.
static func _check_stateful_condition() -> bool:
	_write(FILE_PATH, SOURCE)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	var every: ACECondition = ACECondition.new()
	every.provider_id = "Core"
	every.ace_id = "EveryXSeconds"
	every.codegen_template = "__every_t1 >= maxf({seconds}, 0.001)"
	every.member_declaration = "var __every_t1: float = 0.0"
	every.codegen_prelude = "__every_t1 += get_process_delta_time()"
	every.codegen_on_true = "__every_t1 = fmod(__every_t1, maxf({seconds}, 0.001))"
	every.params = {"seconds": "2.0"}
	every.enabled = false
	_event(sheet, 0).conditions.append(every)
	var result: Dictionary = SheetCompiler.compile(sheet, FILE_PATH)
	var naming: Array = []
	for warning: Variant in result.get("warnings", []):
		if str(warning).begins_with("Condition Core/EveryXSeconds is off"):
			naming.append(str(warning))
	return SUPPORT.pins(TEST_NAME, [
		["a stateful condition that is off: the save says it was left out", naming.size(), 1],
		["a stateful condition that is off: and the file is the one it was", FileAccess.get_file_as_string(FILE_PATH), SOURCE],
	])


## Writes SOURCE, opens it, switches off one cell of the n-th _process event, saves over the file and
## opens it again: {saved, reopened, resaved}. An empty `kind` edits nothing.
static func _cycle(nth: int, kind: String, which: int) -> Dictionary:
	_write(FILE_PATH, SOURCE)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	if not kind.is_empty():
		_switch_off(_event(sheet, nth), kind, which)
	SheetCompiler.compile(sheet, FILE_PATH)
	var saved: String = FileAccess.get_file_as_string(FILE_PATH)
	var reopened: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	_write(RESAVE_PATH, saved)
	reopened.external_source_path = RESAVE_PATH
	SheetCompiler.compile(reopened, RESAVE_PATH)
	return {"saved": saved, "reopened": reopened, "resaved": FileAccess.get_file_as_string(RESAVE_PATH)}


## The cell the Toggle Cell Enabled door switches: an action, a condition, or "both" conditions.
static func _switch_off(event: EventRow, kind: String, which: int) -> void:
	if event == null:
		return
	match kind:
		"action":
			(event.actions[which] as ACEAction).enabled = false
		"condition":
			event.conditions[which].enabled = false
		"both":
			for condition: ACECondition in event.conditions:
				condition.enabled = false


## [conditions' enabled flags, actions' enabled flags] of an event.
static func _cell_state(event: EventRow) -> Array:
	if event == null:
		return []
	var conditions: Array = []
	for condition: ACECondition in event.conditions:
		conditions.append(condition.enabled)
	var actions: Array = []
	for action: Variant in event.actions:
		actions.append(bool(action.get("enabled")))
	return [conditions, actions]


static func _event(sheet: Variant, nth: int) -> EventRow:
	if not (sheet is EventSheetResource):
		return null
	var seen: int = 0
	for entry: Variant in (sheet as EventSheetResource).events:
		if entry is EventRow and (entry as EventRow).trigger_id == "OnProcess":
			if seen == nth:
				return entry as EventRow
			seen += 1
	return null


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
