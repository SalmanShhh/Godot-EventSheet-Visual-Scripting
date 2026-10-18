# Godot EventSheets - a group that is off and cannot be switched keeps its rows in a .gd sheet.
#
# A `.tres` sheet's generated script leaves such a group out of the game, and that is harmless there:
# the `.tres` still holds the rows. A `.gd` sheet has no other copy, so leaving the group out of the
# compile dropped its rows from the file on save - only its header line survived, and the file reopened
# as an empty group that was on. The rows are now written behind a constant `false` guard, so they stay
# in the file and still never run, and the header says the group is off.
#
# Every case is the editor's own round on a REAL file: open it, edit, save over it, open it again, and
# save the reopened sheet untouched.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")
const TEST_NAME := "off_group_kept_in_gd_test"
const FILE_PATH := "user://off_group_kept_in_gd_test.gd"
const RESAVE_PATH := "user://off_group_kept_in_gd_test_resave.gd"
const SAVE_AS_PATH := "user://off_group_kept_in_gd_test_save_as.gd"


static func run() -> bool:
	var base: String = _base_file()
	var all_passed: bool = SUPPORT.pins(TEST_NAME, [
		["the base file parses", _parse_error(base), ""],
		["opened and saved untouched it is byte for byte the same", str(_cycle(base, []).get("saved", "")), base],
	])
	var turned_off: Dictionary = _cycle(base, [["Wave One", "enabled", false]])
	var saved: String = str(turned_off.get("saved", ""))
	var reopened: EventSheetResource = turned_off.get("reopened") as EventSheetResource
	all_passed = SUPPORT.pins(TEST_NAME, [
		["off: the header says the group is off",
			_lines_starting(saved, "## @ace_group(uid=\"wave_one\""),
			["## @ace_group(uid=\"wave_one\", name=\"Wave One\", enabled=false)"]],
		["off: its rows are still in the file, behind a guard that never opens",
			[saved.contains("\tif false:\n\t\tscore += 1"), saved.contains("\tif false:\n\t\tprint(score)"),
				saved.contains("\tif false:\n\t\tscore -= 1")], [true, true, true]],
		["off: no breadcrumb takes the rows' place", saved.contains("rows omitted"), false],
		["off: the saved script parses", _parse_error(saved), ""],
		["off: it reopens as the same off group with its rows",
			_state(_group(reopened, "Wave One")), {"enabled": false, "runtime_toggleable": false, "rows": 3}],
		["off: the group inside it reopens with its row", _state(_group(reopened, "Inner")),
			{"enabled": true, "runtime_toggleable": false, "rows": 1}],
		["off: and saves again byte for byte", str(turned_off.get("resaved", "")), saved],
	]) and all_passed
	# On again: the file is the one the sheet wrote before it was ever turned off.
	_write(FILE_PATH, saved)
	var back_on_sheet: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	var back_on_group: EventGroup = _group(back_on_sheet, "Wave One")
	if back_on_group != null:
		back_on_group.enabled = true
	SheetCompiler.compile(back_on_sheet, FILE_PATH)
	all_passed = SUPPORT.pins(TEST_NAME, [
		["on again: the file is back to what it was", FileAccess.get_file_as_string(FILE_PATH), base],
	]) and all_passed
	# A switchable group inside an off one is held off with it, and its flag is not declared.
	var nested: Dictionary = _cycle(base, [["Wave One", "enabled", false], ["Inner", "runtime_toggleable", true]])
	var nested_saved: String = str(nested.get("saved", ""))
	var nested_reopened: EventSheetResource = nested.get("reopened") as EventSheetResource
	all_passed = SUPPORT.pins(TEST_NAME, [
		["nested switchable: its row is behind the outer group's false guard",
			nested_saved.contains("\tif false:\n\t\tscore -= 1"), true],
		["nested switchable: the saved script parses", _parse_error(nested_saved), ""],
		["nested switchable: reopens switchable, inside the off group",
			[_state(_group(nested_reopened, "Inner")), _state(_group(nested_reopened, "Wave One"))],
			[{"enabled": true, "runtime_toggleable": true, "rows": 1},
				{"enabled": false, "runtime_toggleable": false, "rows": 3}]],
		["nested switchable: and saves again byte for byte", str(nested.get("resaved", "")), nested_saved],
	]) and all_passed
	# Save As .gd from a sheet that never had a file: the new file is the sheet, so it keeps the rows.
	var fresh: EventSheetResource = _base_sheet()
	_group(fresh, "Wave One").enabled = false
	SheetCompiler.compile(fresh, SAVE_AS_PATH, true)
	var save_as: String = FileAccess.get_file_as_string(SAVE_AS_PATH)
	var save_as_reopened: EventSheetResource = GDScriptImporter.new().import_external(SAVE_AS_PATH)
	# And a .tres sheet's generated companion still leaves the group out of the game, as before.
	var companion: String = str(SheetCompiler.echo(fresh).get("output", ""))
	all_passed = SUPPORT.pins(TEST_NAME, [
		["save as .gd: the rows are in the file", save_as.contains("\tif false:\n\t\tscore += 1"), true],
		["save as .gd: the file parses", _parse_error(save_as), ""],
		["save as .gd: reopens as the off group with its rows",
			_state(_group(save_as_reopened, "Wave One")), {"enabled": false, "runtime_toggleable": false, "rows": 3}],
		["a .tres companion still leaves the off group out",
			[companion.contains("score += 1"), companion.contains("(disabled group \"Wave One\"")], [false, true]],
	]) and all_passed
	# A stateful condition (Every X Seconds) on a row of the off group: its bookkeeping line sits behind
	# the same guard as the row, so the timer does not count while the group is off.
	var stateful: EventSheetResource = _base_sheet()
	var wave: EventGroup = _group(stateful, "Wave One")
	wave.events.append(_every_event())
	wave.enabled = false
	SheetCompiler.compile(stateful, SAVE_AS_PATH, true)
	var stateful_saved: String = FileAccess.get_file_as_string(SAVE_AS_PATH)
	var stateful_reopened: EventSheetResource = GDScriptImporter.new().import_external(SAVE_AS_PATH)
	_write(RESAVE_PATH, stateful_saved)
	stateful_reopened.external_source_path = RESAVE_PATH
	SheetCompiler.compile(stateful_reopened, RESAVE_PATH)
	all_passed = SUPPORT.pins(TEST_NAME, [
		["stateful: the bookkeeping is behind the group's false guard",
			stateful_saved.contains("\t# @group:wave_one\n\tif false:\n\t\t__every_t1 += get_process_delta_time()\n\t# @group:wave_one\n\tif false and __every_t1 >= maxf(2.0, 0.001):\n"), true],
		["stateful: no bookkeeping line runs outside it", stateful_saved.contains("\n\t__every_t1 +="), false],
		["stateful: the saved script parses", _parse_error(stateful_saved), ""],
		["stateful: it reopens inside the off group", _state(_group(stateful_reopened, "Wave One")),
			{"enabled": false, "runtime_toggleable": false, "rows": 5}],
		["stateful: and saves again byte for byte", FileAccess.get_file_as_string(RESAVE_PATH), stateful_saved],
	]) and all_passed
	return all_passed


## An every-frame event gated by Every X Seconds, its uid baked the way the dock bakes it.
static func _every_event() -> EventRow:
	var every: ACECondition = ACECondition.new()
	every.provider_id = "Core"
	every.ace_id = "EveryXSeconds"
	every.codegen_template = "__every_t1 >= maxf({seconds}, 0.001)"
	every.member_declaration = "var __every_t1: float = 0.0"
	every.codegen_prelude = "__every_t1 += get_process_delta_time()"
	every.codegen_on_true = "__every_t1 = fmod(__every_t1, maxf({seconds}, 0.001))"
	every.params = {"seconds": "2.0"}
	var event: EventRow = _raw_event("print(\"tick\")")
	event.conditions.append(every)
	return event


## The sheet every case starts from: a score, an outer group holding a nested one, and a group beside.
static func _base_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var score: LocalVariable = LocalVariable.new()
	score.name = "score"
	score.type_name = "int"
	score.default_value = 0
	sheet.events.append(score)
	var inner: EventGroup = EventGroup.new()
	inner.rename("Inner")
	inner.events.append(_raw_event("score -= 1"))
	var wave: EventGroup = EventGroup.new()
	wave.rename("Wave One")
	wave.events.append(_raw_event("score += 1"))
	wave.events.append(_raw_event("print(score)"))
	wave.events.append(inner)
	sheet.events.append(wave)
	var calm: EventGroup = EventGroup.new()
	calm.rename("Calm")
	calm.events.append(_raw_event("score = 0"))
	sheet.events.append(calm)
	return sheet


static func _base_file() -> String:
	return str(SheetCompiler.compile(_base_sheet(), FILE_PATH).get("output", ""))


## Writes `base` to the file, opens it, applies `edits` ([group, field, value]), saves the sheet over
## the file and opens the file again: {saved, reopened, resaved}.
static func _cycle(base: String, edits: Array) -> Dictionary:
	_write(FILE_PATH, base)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	for edit: Array in edits:
		var group: EventGroup = _group(sheet, str(edit[0]))
		if group != null:
			group.set(str(edit[1]), edit[2])
	SheetCompiler.compile(sheet, FILE_PATH)
	var saved: String = FileAccess.get_file_as_string(FILE_PATH)
	var reopened: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	_write(RESAVE_PATH, saved)
	reopened.external_source_path = RESAVE_PATH
	SheetCompiler.compile(reopened, RESAVE_PATH)
	return {"saved": saved, "reopened": reopened, "resaved": FileAccess.get_file_as_string(RESAVE_PATH)}


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


static func _lines_starting(text: String, prefix: String) -> Array:
	var found: Array = []
	for line: String in text.split("\n"):
		if line.begins_with(prefix):
			found.append(line)
	return found


## Whether a group is on, whether it can be switched, and how many rows it holds.
static func _state(group: EventGroup) -> Dictionary:
	if group == null:
		return {}
	return {"enabled": group.enabled, "runtime_toggleable": group.runtime_toggleable, "rows": group.child_rows().size()}


## The group of that name anywhere in the sheet, or null.
static func _group(sheet: EventSheetResource, group_name: String) -> EventGroup:
	if sheet == null:
		return null
	for group: EventGroup in EventSheetGroupFacts.collect(sheet.events):
		if group.display_name() == group_name:
			return group
	return null


## An every-frame event carrying one plain statement.
static func _raw_event(code: String) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var statement: RawCodeRow = RawCodeRow.new()
	statement.code = code
	event.actions.append(statement)
	return event
