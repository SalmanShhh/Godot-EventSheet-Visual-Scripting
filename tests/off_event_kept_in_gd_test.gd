# Godot EventSheets - an event switched off in a .gd sheet stays in the file.
#
# An event that is off was left out of the compile. A `.tres` sheet still holds it, but a `.gd`
# sheet has no other copy: unticking an event's box and saving deleted it from the file, and the
# reopened sheet had no such event at all. In a sheet that is its own `.gd` an event that is off is
# now written behind a constant false guard under a `# @off` line, so it stays in the file and never
# runs, and the lift reads the pair back as the same event, switched off.
#
# Every case is the editor's own round on a REAL file: open it, switch one event off, save over it,
# parse it, open it again, and save the reopened sheet untouched.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")
const TEST_NAME := "off_event_kept_in_gd_test"
const FILE_PATH := "user://off_event_kept_in_gd_test.gd"
const RESAVE_PATH := "user://off_event_kept_in_gd_test_resave.gd"

const SOURCE := """extends Node2D

## @ace_group(uid="calm", name="Calm", toggleable=true)

var score: int = 0
var lives: int = 3
var __group_calm_active: bool = true


func _ready() -> void:
	print("ready")


func _process(delta: float) -> void:
	if score > 10:
		score = 0
	if score > 5 or lives < 1:
		print("busy")
	if lives > 2:
		lives -= 1
	else:
		lives = 3
	if score > 1:
		score += 1
		if lives > 1:
			print("both")
	# @group:calm
	if __group_calm_active and lives > 0:
		print("calm")


func tally() -> void:
	score += 1
	if score > 3:
		print("three")
"""


static func run() -> bool:
	var all_passed: bool = SUPPORT.pins(TEST_NAME, [
		["opened and saved untouched it is byte for byte the same", str(_cycle(Callable()).get("saved", "")), SOURCE],
	])
	# Each case: label, which event to switch off, the lines the save must hold, and the event's row
	# read back from the reopened sheet.
	var cases: Array = [
		["the only event of a handler", func(sheet: EventSheetResource) -> EventRow: return _top(sheet, "OnReady", 0),
			"func _ready() -> void:\n\t# @off\n\tif false:\n\t\tprint(\"ready\")\n",
			func(sheet: EventSheetResource) -> EventRow: return _top(sheet, "OnReady", 0)],
		["a conditioned event", func(sheet: EventSheetResource) -> EventRow: return _top(sheet, "OnProcess", 0),
			"\t# @off\n\tif false and score > 10:\n\t\tscore = 0\n",
			func(sheet: EventSheetResource) -> EventRow: return _top(sheet, "OnProcess", 0)],
		["an Or event", func(sheet: EventSheetResource) -> EventRow: return _top(sheet, "OnProcess", 1),
			"\t# @off\n\tif false and (score > 5 or lives < 1):\n\t\tprint(\"busy\")\n",
			func(sheet: EventSheetResource) -> EventRow: return _top(sheet, "OnProcess", 1)],
		["an else row", func(sheet: EventSheetResource) -> EventRow: return _top(sheet, "OnProcess", 3),
			"\t\tlives -= 1\n\t# @off\n\telif false:\n\t\tlives = 3\n",
			func(sheet: EventSheetResource) -> EventRow: return _top(sheet, "OnProcess", 3)],
		["a sub-event", func(sheet: EventSheetResource) -> EventRow: return _top(sheet, "OnProcess", 4).sub_events[0],
			"\t\tscore += 1\n\t\t# @off\n\t\tif false and lives > 1:\n\t\t\tprint(\"both\")\n",
			func(sheet: EventSheetResource) -> EventRow: return _top(sheet, "OnProcess", 4).sub_events[0] as EventRow],
		["an event in a switchable group", func(sheet: EventSheetResource) -> EventRow: return _grouped(sheet),
			"\t# @group:calm\n\t# @off\n\tif false and __group_calm_active and lives > 0:\n\t\tprint(\"calm\")\n",
			func(sheet: EventSheetResource) -> EventRow: return _grouped(sheet)],
		["an event in a function's body", func(sheet: EventSheetResource) -> EventRow: return _in_function(sheet),
			"\tscore += 1\n\t# @off\n\tif false and score > 3:\n\t\tprint(\"three\")\n",
			func(sheet: EventSheetResource) -> EventRow: return _in_function(sheet)],
	]
	for case: Array in cases:
		all_passed = _check_case(case) and all_passed
	# On again, the file is the one it was.
	var off_once: Dictionary = _cycle(func(sheet: EventSheetResource) -> void: _top(sheet, "OnProcess", 0).enabled = false)
	_write(FILE_PATH, str(off_once.get("saved", "")))
	var back_on: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	var back_on_event: EventRow = _top(back_on, "OnProcess", 0)
	if back_on_event != null:
		back_on_event.enabled = true
	SheetCompiler.compile(back_on, FILE_PATH)
	# A .tres sheet's generated companion still leaves an event that is off out of the game.
	_write(FILE_PATH, SOURCE)
	var tres_like: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	_top(tres_like, "OnProcess", 0).enabled = false
	tres_like.external_source_path = ""
	var companion: String = str(SheetCompiler.echo(tres_like).get("output", ""))
	return SUPPORT.pins(TEST_NAME, [
		["on again: the file is back to what it was", FileAccess.get_file_as_string(FILE_PATH), SOURCE],
		["a .tres companion still leaves an event that is off out", [companion.contains("score = 0"), companion.contains("# @off")], [false, false]],
	]) and all_passed


## One case, pinned: the lines the save wrote, that it parses, that the reopened event is the same
## event and off, and that saving the reopened sheet untouched changes nothing.
static func _check_case(case: Array) -> bool:
	var label: String = str(case[0])
	var pick: Callable = case[1]
	var round_trip: Dictionary = _cycle(func(sheet: EventSheetResource) -> void: (pick.call(sheet) as EventRow).enabled = false)
	var saved: String = str(round_trip.get("saved", ""))
	var reopened: EventRow = (case[3] as Callable).call(round_trip.get("reopened")) as EventRow
	return SUPPORT.pins(TEST_NAME, [
		["%s: the save keeps it behind a guard that never opens" % label, saved.contains(str(case[2])), true],
		["%s: the saved script parses" % label, _parse_error(saved), ""],
		["%s: it reopens as the same event, off" % label,
			[reopened.enabled, _words(reopened)] if reopened != null else [], [false, _words((case[1] as Callable).call(_opened()))]],
		["%s: and saves again byte for byte" % label, str(round_trip.get("resaved", "")), saved],
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


## SOURCE opened fresh, untouched.
static func _opened() -> EventSheetResource:
	_write(FILE_PATH, SOURCE)
	return GDScriptImporter.new().import_external(FILE_PATH)


## An event's conditions and actions as the code they write, so two readings of one event compare.
static func _words(event: EventRow) -> Array:
	if event == null:
		return []
	var words: Array = [event.condition_mode]
	for condition: ACECondition in event.conditions:
		words.append(ConditionCodegen.generate_condition(condition, ""))
	for action: Variant in event.actions:
		words.append(ActionCodegen.generate_action(action, "", "") if action is ACEAction else str((action as RawCodeRow).code) if action is RawCodeRow else action.get_class())
	return words


## The n-th top-level event (groups looked through) whose trigger is `trigger_id`.
static func _top(sheet: EventSheetResource, trigger_id: String, nth: int) -> EventRow:
	if sheet == null:
		return null
	var seen: int = 0
	for entry: Variant in sheet.events:
		if entry is EventRow and (entry as EventRow).trigger_id == trigger_id:
			if seen == nth:
				return entry as EventRow
			seen += 1
	return null


static func _grouped(sheet: EventSheetResource) -> EventRow:
	if sheet == null:
		return null
	for group: EventGroup in EventSheetGroupFacts.collect(sheet.events):
		for row: Variant in group.child_rows():
			if row is EventRow:
				return row as EventRow
	return null


## The conditioned event in tally()'s body.
static func _in_function(sheet: EventSheetResource) -> EventRow:
	if sheet == null:
		return null
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == "tally":
			for row: Variant in SheetCompiler._function_body_rows(entry as EventFunction):
				if row is EventRow and not (row as EventRow).conditions.is_empty():
					return row as EventRow
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
