# Godot EventSheets - the first group added to a .gd sheet writes its header where it reads as one.
#
# A `.gd` with no groups yet has no header line to sit beside, so the first group's
# `## @ace_group(...)` line needs a home. It used to be written straight under `extends`, where both
# Godot and the lift read it as the class's own doc comment: the sheet reopened with the header as its
# class description. In a file that opens with annotations (`@icon(...)` under the pack's `## @ace_`
# lines) it went to the very top, and a switchable group's flag `var` landed above `@icon`, which
# Godot refuses: the saved script did not parse.
#
# The header now goes under the class's opening lines and its doc block, past the blank line that
# closes them, on a line of its own. And a header that does sit under `extends` (a sheet-native
# compile writes it there) is no longer read as the class description.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")
const TEST_NAME := "first_group_header_place_test"
const FILE_PATH := "user://first_group_header_place_test.gd"

const PLAIN_SOURCE := "class_name HeaderPlaceProbe\nextends Node2D\n\nenum State { PLAYING, OVER }\n\nvar score: int = 0\n\n\nfunc _ready() -> void:\n\tscore = 1\n"
const PACK_SOURCE := "## @ace_category(\"Probe\")\n@icon(\"res://icon.svg\")\nclass_name HeaderPlacePack\nextends Node\n## Moves its host.\n\n## The node this behavior acts on.\nvar host: Node2D = null\n\n\nfunc _ready() -> void:\n\thost = get_parent() as Node2D\n"


static func run() -> bool:
	var plain: Dictionary = _add_group(PLAIN_SOURCE, false)
	var pack: Dictionary = _add_group(PACK_SOURCE, true)
	# A sheet-native compile writes its headers straight under `extends`.
	var native_sheet: EventSheetResource = EventSheetResource.new()
	native_sheet.host_class = "Node2D"
	var native_group: EventGroup = EventGroup.new()
	native_group.rename("Wave")
	native_group.events.append(_raw_event("print(1)"))
	native_sheet.events.append(native_group)
	var native_out: String = str(SheetCompiler.compile(native_sheet, FILE_PATH).get("output", ""))
	var native_back: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	return SUPPORT.pins(TEST_NAME, [
		["a plain file: the header sits on its own line under the opening",
			_head(str(plain.get("saved", "")), 6),
			["class_name HeaderPlaceProbe", "extends Node2D", "", "## @ace_group(uid=\"sweep\", name=\"Sweep\")", "", "enum State { PLAYING, OVER }"]],
		["a plain file: it reopens with no class description and the group",
			[str(plain.get("description", "?")), plain.get("group", [])], ["", ["Sweep", 1]]],
		["a plain file: the saved script parses", plain.get("parse", "?"), ""],
		["a pack file: the header and the flag go under the class doc, not above @icon",
			_head(str(pack.get("saved", "")), 9),
			["## @ace_category(\"Probe\")", "@icon(\"res://icon.svg\")", "class_name HeaderPlacePack", "extends Node",
				"## Moves its host.", "", "## @ace_group(uid=\"sweep\", name=\"Sweep\", toggleable=true)", "", "var __group_sweep_active: bool = true"]],
		["a pack file: the saved script parses", pack.get("parse", "?"), ""],
		["a pack file: it reopens with its own class description and the switchable group",
			[str(pack.get("description", "?")), pack.get("group", [])], ["Moves its host.", ["Sweep", 1]]],
		["a header under extends is not read as the class description",
			[native_out.contains("extends Node2D\n## @ace_group("), native_back.class_description if native_back != null else "?"],
			[true, ""]],
	])


## Opens `source` from a real file, wraps its first event in a new group (switchable when asked),
## saves over the file and opens it again: {saved, parse, description, group: [name, rows]}.
static func _add_group(source: String, switchable: bool) -> Dictionary:
	_write(FILE_PATH, source)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	var first: EventRow = null
	for entry: Variant in sheet.events:
		if entry is EventRow:
			first = entry as EventRow
			break
	if first == null:
		return {}
	var at: int = sheet.events.find(first)
	var group: EventGroup = EventGroup.new()
	group.rename("Sweep")
	group.runtime_toggleable = switchable
	sheet.events.remove_at(at)
	group.events.append(first)
	sheet.events.insert(at, group)
	SheetCompiler.compile(sheet, FILE_PATH)
	var saved: String = FileAccess.get_file_as_string(FILE_PATH)
	var reopened: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	var found: Array = []
	for group_found: EventGroup in EventSheetGroupFacts.collect(reopened.events):
		found = [group_found.display_name(), group_found.child_rows().size()]
	return {"saved": saved, "parse": _parse_error(saved), "description": reopened.class_description, "group": found}


static func _head(text: String, count: int) -> Array:
	var head: Array = []
	for line: String in text.split("\n").slice(0, count):
		head.append(line)
	return head


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## "" when `source` parses as a script, else the error it fails with. The class_name line is left
## out so the probe does not collide with a class the project already knows.
static func _parse_error(source: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		kept.append("" if line.begins_with("class_name ") else line)
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(kept)
	var error: int = script.reload()
	return "" if error == OK else error_string(error)


static func _raw_event(code: String) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var statement: RawCodeRow = RawCodeRow.new()
	statement.code = code
	event.actions.append(statement)
	return event
