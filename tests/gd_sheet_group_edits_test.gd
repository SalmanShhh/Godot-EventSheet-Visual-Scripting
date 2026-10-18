# Godot EventSheets - editing a group in a script that is its own sheet reaches the file.
#
# A `.gd` opened in the editor compiles on the opened-file path, where the groups' `## @ace_group(...)`
# header lines ride verbatim in the rows the file opened with. Before the header pass, every change to
# a lifted group (colour, description, folded, who runs it, which mode, rename, Active On Start, Can
# Be Switched At Runtime) was silently left out of the save, and switching a group on wrote
# `if __group_x_active:` with no member declaring it - a script that does not parse.
#
# Every case here is the editor's own round: a REAL file on disk is opened, one group is edited, the
# sheet is saved over the file, and the file is opened again. Each pins the header lines and the flag
# lines the save wrote, that the saved script parses, that the reopened group is the edited one, and
# that saving the reopened sheet untouched writes the same bytes again.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")
const TEST_NAME := "gd_sheet_group_edits_test"
const FILE_PATH := "user://gd_sheet_group_edits_test.gd"
const RESAVE_PATH := "user://gd_sheet_group_edits_test_resave.gd"


static func run() -> bool:
	var base: String = _base_file()
	var all_passed: bool = SUPPORT.pins(TEST_NAME, [
		["the file a grouped sheet writes parses", _parse_error(base), ""],
		["opened and saved untouched it is byte for byte the same", str(_cycle(base, []).get("saved", "")), base],
	])
	var wave_header: String = "## @ace_group(uid=\"wave_one\", name=\"Wave One\""
	var calm_header: String = "## @ace_group(uid=\"calm\", name=\"Calm\", toggleable=true)"
	var inner_header: String = "## @ace_group(uid=\"inner\", name=\"Inner\", parent=\"wave_one\")"
	# Each case: label, the edits ([group, field, value] - "rename", "delete" and "add" are the menu's
	# own doors), the header lines and flag lines the save writes, and the group the reopened file holds.
	var cases: Array = [
		["a new colour", [["Wave One", "custom_color", Color("#336699")]],
			[wave_header + ", color=\"#336699\")", inner_header, calm_header],
			["var __group_calm_active: bool = true"],
			"Wave One", {"header_color": "#336699"}],
		["a description", [["Wave One", "description", "Spawns the first wave"]],
			[wave_header + ", description=\"Spawns the first wave\")", inner_header, calm_header],
			["var __group_calm_active: bool = true"],
			"Wave One", {"description": "Spawns the first wave"}],
		["folded", [["Inner", "collapsed", true]],
			[wave_header + ")", "## @ace_group(uid=\"inner\", name=\"Inner\", parent=\"wave_one\", collapsed=true)", calm_header],
			["var __group_calm_active: bool = true"],
			"Inner", {"collapsed": true}],
		["runs on the host", [["Wave One", "runs_on", EventGroup.RUNS_ON_HOST]],
			[wave_header + ", runs_on=\"host\")", inner_header, calm_header],
			["var __group_calm_active: bool = true"],
			"Wave One", {"runs_on": "host"}],
		["runs in one mode", [["Wave One", "runs_in", "Game Over"]],
			[wave_header + ", runs_in=\"Game Over\")", inner_header, calm_header],
			["var __group_calm_active: bool = true"],
			"Wave One", {"runs_in": "Game Over"}],
		["switched on at runtime", [["Wave One", "runtime_toggleable", true]],
			[wave_header + ", toggleable=true)", inner_header, calm_header],
			["var __group_calm_active: bool = true", "var __group_wave_one_active: bool = true"],
			"Wave One", {"runtime_toggleable": true, "enabled": true}],
		["switchable and off at start", [["Wave One", "runtime_toggleable", true], ["Wave One", "enabled", false]],
			[wave_header + ", toggleable=true, enabled=false)", inner_header, calm_header],
			["var __group_calm_active: bool = true", "var __group_wave_one_active: bool = false"],
			"Wave One", {"runtime_toggleable": true, "enabled": false}],
		["a switchable group turned off at start", [["Calm", "enabled", false]],
			[wave_header + ")", inner_header, "## @ace_group(uid=\"calm\", name=\"Calm\", toggleable=true, enabled=false)"],
			["var __group_calm_active: bool = false"],
			"Calm", {"runtime_toggleable": true, "enabled": false}],
		["a switchable group that can no longer be switched", [["Calm", "runtime_toggleable", false]],
			[wave_header + ")", inner_header, "## @ace_group(uid=\"calm\", name=\"Calm\")"],
			[],
			"Calm", {"runtime_toggleable": false}],
		["a renamed group", [["Wave One", "rename", "Boss Wave"]],
			["## @ace_group(uid=\"boss_wave\", name=\"Boss Wave\")", "## @ace_group(uid=\"inner\", name=\"Inner\", parent=\"boss_wave\")", calm_header],
			["var __group_calm_active: bool = true"],
			"Boss Wave", {"rows": 3}],
		["a renamed switchable group takes its flag along", [["Calm", "rename", "Quiet Time"]],
			[wave_header + ")", inner_header, "## @ace_group(uid=\"quiet_time\", name=\"Quiet Time\", toggleable=true)"],
			["var __group_quiet_time_active: bool = true"],
			"Quiet Time", {"runtime_toggleable": true, "rows": 1}],
		["a deleted group", [["Calm", "delete", null]],
			[wave_header + ")", inner_header],
			[],
			"Wave One", {"rows": 3}],
		["a switchable group added", [["Late Game", "add", null]],
			[wave_header + ")", inner_header, calm_header, "## @ace_group(uid=\"late_game\", name=\"Late Game\", toggleable=true)"],
			["var __group_calm_active: bool = true", "var __group_late_game_active: bool = true"],
			"Late Game", {"runtime_toggleable": true, "rows": 1}],
	]
	for case: Array in cases:
		all_passed = _check_case(base, case) and all_passed
	return all_passed


## One editing round, pinned: the header and flag lines the save wrote, that it parses, what the group
## reads as when the file is opened again, and that saving that untouched changes nothing.
static func _check_case(base: String, case: Array) -> bool:
	var label: String = str(case[0])
	var round_trip: Dictionary = _cycle(base, case[1])
	var saved: String = str(round_trip.get("saved", ""))
	var reopened: EventSheetResource = round_trip.get("reopened") as EventSheetResource
	var expected_state: Dictionary = case[5]
	var reopened_group: EventGroup = _group(reopened, str(case[4]))
	return SUPPORT.pins(TEST_NAME, [
		["%s: the header lines" % label, _lines_starting(saved, "## @ace_group("), case[2]],
		["%s: the switch flags" % label, _lines_starting(saved, "var __group_"), case[3]],
		["%s: the saved script parses" % label, _parse_error(saved), ""],
		["%s: reopens as the edited group" % label, _state(reopened_group, expected_state.keys()), expected_state],
		["%s: and saves again byte for byte" % label, str(round_trip.get("resaved", "")), saved],
	])


## The sheet every case starts from, written the way a grouped sheet writes itself: an outer group
## holding a nested one, a switchable group, a mode enum (for runs in) and a score.
static func _base_file() -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var modes: EnumRow = EnumRow.new()
	modes.enum_name = "Mode"
	modes.members = PackedStringArray(["PLAY", "GAME_OVER"])
	sheet.events.append(modes)
	var mode_member: RawCodeRow = RawCodeRow.new()
	mode_member.code = "var mode: Mode = Mode.PLAY"
	sheet.events.append(mode_member)
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
	calm.runtime_toggleable = true
	calm.events.append(_raw_event("score = 0"))
	sheet.events.append(calm)
	return str(SheetCompiler.compile(sheet, FILE_PATH).get("output", ""))


## Writes `base` to the file, opens it, applies `edits`, saves the sheet over the file and opens the
## file again: {saved, reopened, resaved}.
static func _cycle(base: String, edits: Array) -> Dictionary:
	_write(FILE_PATH, base)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	for edit: Array in edits:
		_apply(sheet, edit)
	SheetCompiler.compile(sheet, FILE_PATH)
	var saved: String = FileAccess.get_file_as_string(FILE_PATH)
	var reopened: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	_write(RESAVE_PATH, saved)
	reopened.external_source_path = RESAVE_PATH
	SheetCompiler.compile(reopened, RESAVE_PATH)
	return {"saved": saved, "reopened": reopened, "resaved": FileAccess.get_file_as_string(RESAVE_PATH)}


## One edit: [group name, field, value], or the doors "rename" (value = the new name), "delete" (the
## group and its rows) and "add" (a new switchable group of that name holding one event).
static func _apply(sheet: EventSheetResource, edit: Array) -> void:
	var group_name: String = str(edit[0])
	match str(edit[1]):
		"rename":
			_group(sheet, group_name).rename(str(edit[2]))
		"delete":
			sheet.events.erase(_group(sheet, group_name))
		"add":
			var added: EventGroup = EventGroup.new()
			added.rename(group_name)
			added.runtime_toggleable = true
			added.events.append(_raw_event("score *= 2"))
			sheet.events.append(added)
		_:
			_group(sheet, group_name).set(str(edit[1]), edit[2])


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


## The fields of a group the cases ask about, by name; "rows" is how many rows it holds.
static func _state(group: EventGroup, keys: Array) -> Dictionary:
	var state: Dictionary = {}
	if group == null:
		return state
	for key: Variant in keys:
		match str(key):
			"header_color":
				state[key] = group.header_color()
			"rows":
				state[key] = group.child_rows().size()
			_:
				state[key] = group.get(str(key))
	return state


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
