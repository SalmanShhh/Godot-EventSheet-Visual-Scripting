# Godot EventSheets - every variable a shipped pack declares says what it is for.
#
# A behaviour pack is read as a sheet, and each class-level variable or constant it declares is a
# row there; the `##` lines above it are the row's note, the text a hover card shows and the
# Inspector tooltip of an exported one. A pack variable with no note is a row nobody can read
# without opening the code, so the rule is: EVERY variable and constant a shipped pack declares has
# a one-line description, and an enum a pack declares (a state machine) describes the machine above
# it and each state beside its member.
#
# The walk reads the shipped pack scripts as text, the way the importer sees them: a declaration at
# column 0, its description the `##` block above it (skipping Inspector section lines and `## @ace_`
# tags, which are not prose) or a `##` trailing it. A line inside a triple-quoted string is text, not
# a declaration. The same rule runs over the packs on disk and over small synthetic sources, so the
# test fails for the reason it names rather than passing because nothing was looked at.
@tool
class_name PackVariableDescriptionsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SHIPPED := preload("res://addons/eventforge/shipped_pack_folders.gd")
const PACK_ROOT := "res://eventsheet_addons"

## The longest a description may be. A note is a line on a row and a tooltip, so it is brief; a
## paragraph of design rationale belongs in a plain `#` comment above it.
const LONGEST := 160

## Pack variables that may go without a description, each with the reason. Empty: none needs to.
const ALLOWED: Dictionary = {}

## Packs whose rows are also read back through the real importer, three with a state or mode and
## three without, to prove the note survives the reading and not only the text.
const READ_BACK := ["state_machine", "follow", "time_slicer", "anchor", "checkpoint", "big_number"]


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_the_rule_on_small_sources() and all_passed
	all_passed = _test_every_shipped_pack() and all_passed
	all_passed = _test_the_notes_survive_the_reading() and all_passed
	return all_passed


static func _test_the_rule_on_small_sources() -> bool:
	var described: String = "## How fast it moves.\n@export var speed: float = 1.0\n"
	var bare: String = "@export var speed: float = 1.0\nvar _hits: int = 0\n"
	var beside_a_group: String = "## How fast it moves.\n@export_group(\"Motion\")\n@export var speed: float = 1.0\n"
	var trailing: String = "const LIMIT: int = 3  ## Most it may hold.\n"
	var too_long: String = "## %s\nvar _x: int = 0\n" % "word ".repeat(40)
	var in_a_string: String = "const _CODE: String = \"\"\"\nconst float fade = 1.0;\n\"\"\"\n"
	var one_machine: String = "enum State {\n\tIDLE,\n\tRUN,\n}\n"
	var machine_described: String = "## What the object is doing.\nenum State {\n\t## Standing still.\n\tIDLE,\n\t## Moving.\n\tRUN,\n}\n"
	var machine_half: String = "## What the object is doing.\nenum State {\n\t## Standing still.\n\tIDLE,\n\tRUN,\n}\n"
	return SUPPORT.pins("pack_variable_descriptions_test", [
		["a described variable raises nothing", _problems_in(described), PackedStringArray()],
		["two bare variables are both named", _problems_in(bare), PackedStringArray(["speed has no description", "_hits has no description"])],
		["a note above an Inspector group line counts", _problems_in(beside_a_group), PackedStringArray()],
		["a trailing note counts", _problems_in(trailing), PackedStringArray()],
		["a paragraph is not brief", _problems_in(too_long), PackedStringArray(["_x description is %d characters, more than %d" % ["word ".repeat(40).strip_edges().length(), LONGEST]])],
		["a line inside a triple-quoted string is not a declaration", _problems_in(in_a_string), PackedStringArray(["_CODE has no description"])],
		["a machine with no notes is named, machine and every state", _problems_in(one_machine), PackedStringArray(["enum State has no description", "state IDLE has no description", "state RUN has no description"])],
		["a machine with every note raises nothing", _problems_in(machine_described), PackedStringArray()],
		["a machine missing one state names that state", _problems_in(machine_half), PackedStringArray(["state RUN has no description"])],
	])


static func _test_every_shipped_pack() -> bool:
	var problems: PackedStringArray = problems_under(PACK_ROOT)
	return SUPPORT.check("pack_variable_descriptions_test", "every variable, machine and state in every shipped pack is described", problems, PackedStringArray())


static func _test_the_notes_survive_the_reading() -> bool:
	var missing: PackedStringArray = PackedStringArray()
	var rows_seen: int = 0
	for pack_name: String in READ_BACK:
		var folder: String = "%s/%s" % [PACK_ROOT, pack_name]
		for file_name: String in _scripts_in(folder):
			var path: String = "%s/%s" % [folder, file_name]
			var sheet: EventSheetResource = SUPPORT.reopen(FileAccess.get_file_as_string(path), true, path)
			if sheet == null:
				missing.append("%s did not open as a sheet" % path)
				continue
			for row: Variant in sheet.events:
				if not (row is LocalVariable):
					continue
				rows_seen += 1
				var variable: LocalVariable = row
				var attributes: Dictionary = variable.attributes if variable.attributes is Dictionary else {}
				var note: String = str(attributes.get("tooltip", variable.description)).strip_edges()
				if note.is_empty():
					missing.append("%s.%s has no note on its row" % [pack_name, variable.name])
	return SUPPORT.pins("pack_variable_descriptions_test", [
		["every variable row of the six packs carries a note", missing, PackedStringArray()],
		["the six packs gave variable rows to check", rows_seen > 20, true],
	])


## Every problem under `root`, a folder of pack folders. Public so a harness can point it at a
## copy of the packs from before a change and see the rule fail.
static func problems_under(root: String) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	for pack_name: String in SHIPPED.FOLDERS:
		var folder: String = "%s/%s" % [root, pack_name]
		for file_name: String in _scripts_in(folder):
			var source: String = FileAccess.get_file_as_string("%s/%s" % [folder, file_name])
			for problem: String in _problems_in(source):
				if ALLOWED.has("%s.%s" % [pack_name, problem.get_slice(" ", 0)]):
					continue
				problems.append("%s/%s: %s" % [pack_name, file_name, problem])
	return problems


static func _scripts_in(folder: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.ends_with(".gd"):
			names.append(file_name)
	names.sort()
	return names


## What is wrong with one script's variables, constants and enums, one sentence each.
static func _problems_in(source: String) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var lines: PackedStringArray = source.split("\n")
	var declaration: RegEx = RegEx.create_from_string("^(?:@[^\\n]*?\\s)?(?:static\\s+)?(?:var|const)\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var enum_head: RegEx = RegEx.create_from_string("^enum\\s*([A-Za-z_][A-Za-z0-9_]*)?\\s*\\{")
	var note: String = ""
	var in_string: bool = false
	var index: int = 0
	while index < lines.size():
		var line: String = lines[index]
		var was_in_string: bool = in_string
		if line.count("\"\"\"") % 2 == 1:
			in_string = not in_string
		if was_in_string:
			index += 1
			continue
		if line.begins_with("##"):
			var text: String = line.substr(2).strip_edges()
			if not text.begins_with("@ace_"):
				note = (note + " " + text).strip_edges()
			index += 1
			continue
		if line.begins_with("#"):
			index += 1
			continue
		if line.begins_with("@export_group") or line.begins_with("@export_subgroup") or line.begins_with("@export_category"):
			index += 1
			continue
		var enum_match: RegExMatch = enum_head.search(line)
		if enum_match != null:
			var enum_name: String = enum_match.get_string(1)
			if note.is_empty():
				problems.append("enum %s has no description" % enum_name)
			index = _check_enum_members(lines, index, problems)
			note = ""
			index += 1
			continue
		var found: RegExMatch = declaration.search(line)
		if found != null:
			var variable_name: String = found.get_string(1)
			var described: String = note
			if described.is_empty() and line.contains("##"):
				described = line.get_slice("##", 1).strip_edges()
			if described.is_empty():
				problems.append("%s has no description" % variable_name)
			elif described.length() > LONGEST:
				problems.append("%s description is %d characters, more than %d" % [variable_name, described.length(), LONGEST])
		note = ""
		index += 1
	return problems


## Walks the member lines of an enum that opens on `start`, naming each member with no `##` above
## it. Returns the index of the closing line.
static func _check_enum_members(lines: PackedStringArray, start: int, problems: PackedStringArray) -> int:
	var member_note: String = ""
	var index: int = start
	if lines[start].contains("}"):
		problems.append("an enum on one line cannot describe its states")
		return start
	index += 1
	while index < lines.size():
		var line: String = lines[index].strip_edges()
		if line.begins_with("}"):
			break
		if line.begins_with("##"):
			member_note = (member_note + " " + line.substr(2)).strip_edges()
		elif not line.is_empty() and not line.begins_with("#"):
			var member: String = line.get_slice("=", 0).get_slice(",", 0).strip_edges()
			if member_note.is_empty():
				problems.append("state %s has no description" % member)
			member_note = ""
		index += 1
	return index
