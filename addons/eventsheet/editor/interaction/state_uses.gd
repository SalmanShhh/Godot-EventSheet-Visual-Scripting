# Godot EventSheets - where a state is used OUTSIDE the sheet that declares it.
#
# A state is an enum member, and an enum member can be named from other files: a second script that
# says `Player.State.RUN`, a script that extends the declaring class and says `State.RUN`. Renaming or
# removing a state in the States window is therefore a PROJECT-WIDE edit, and the window lists those
# files first - file, how many places, and the first lines - so nothing outside the open sheet changes
# without being looked at.
#
# This file is the pure half: it reads script text and rewrites script text, and touches no file. The
# States window decides what to do with the answer and writes the files through the dock's one undoable
# edit, so the open sheet and every file it changed come back with one Undo.
#
# WHICH FILES COUNT, and why only these. A bare `State.RUN` in an unrelated script is that script's own
# enum, so it is never touched. A file uses this machine's state only when it says the member through
# the declaring class (`Player.State.RUN`), or extends that class and so inherits the enum
# (`extends Player` then `State.RUN`). The declaring file itself is the open sheet's business, and a
# behaviour pack's script is never rewritten (a rebuild would take the change back).
@tool
class_name EventSheetStateUses
extends RefCounted

## How many example lines a file's entry keeps for the list.
const PREVIEW_LINES: int = 3
## The project walk and the behaviour-pack folder, reached by path so that asking about a state's users
## is the only thing that ever compiles them: opening a sheet never does.
const FIND_REFERENCES_PATH: String = "res://addons/eventsheet/editor/dock/find_references.gd"
const PACK_ROOT: String = "res://eventsheet_addons/"


## Every project script that names one of `members` of `enum_name` through `declaring_class`: [{path,
## members: {member: count}, count, lines: [line numbers], preview: [text]}], path-ordered. `sources` is
## {path: text}, handed in so a test supplies its own corpus; `skip` is every path that must stay out (the
## declaring file under its names). A script that names none is not listed.
static func scan(sources: Dictionary, declaring_class: String, enum_name: String,
		members: PackedStringArray, skip: Dictionary = {}) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if declaring_class.strip_edges().is_empty() or enum_name.is_empty() or members.is_empty():
		return found
	var paths: Array = sources.keys()
	paths.sort()
	for path: Variant in paths:
		if skip.has(path):
			continue
		var text: String = str(sources[path])
		var pattern: RegEx = reference_pattern(declaring_class, enum_name, members, extends_class(text, declaring_class))
		var matches: Array[RegExMatch] = pattern.search_all(text)
		if matches.is_empty():
			continue
		var counted: Dictionary = {}
		var lines: PackedInt32Array = PackedInt32Array()
		var preview: PackedStringArray = PackedStringArray()
		var source_lines: PackedStringArray = text.split("\n")
		for hit: RegExMatch in matches:
			var member: String = hit.get_string(2)
			counted[member] = int(counted.get(member, 0)) + 1
			var line_no: int = text.substr(0, hit.get_start()).count("\n") + 1
			if not lines.has(line_no):
				lines.append(line_no)
				if preview.size() < PREVIEW_LINES:
					preview.append(source_lines[line_no - 1].strip_edges())
		found.append({"path": str(path), "members": counted, "count": matches.size(), "lines": lines, "preview": preview})
	return found


## True when `text` has a line `extends <declaring_class>` (the class by name), so it inherits the enum.
static func extends_class(text: String, declaring_class: String) -> bool:
	var pattern: RegEx = RegEx.new()
	pattern.compile("(?m)^\\s*extends\\s+%s\\b" % declaring_class)
	return pattern.search(text) != null


## The reference pattern: group 1 is what comes before the enum word, group 2 the member. Through the class
## it is `Class.Enum.MEMBER`; in a script that extends the class `Enum.MEMBER` counts as well.
static func reference_pattern(declaring_class: String, enum_name: String, members: PackedStringArray,
		inherits: bool) -> RegEx:
	var escaped: PackedStringArray = PackedStringArray()
	for member: String in members:
		escaped.append(member)
	var alternatives: String = "|".join(escaped)
	var lead: String = "\\b%s\\.%s" % [declaring_class, enum_name]
	var source: String = "(%s)\\.(%s)\\b" % [lead, alternatives]
	if inherits:
		source = "((?:\\b%s\\.)?%s)\\.(%s)\\b" % [declaring_class, enum_name, alternatives]
	var pattern: RegEx = RegEx.new()
	pattern.compile(source)
	return pattern


## `text` with every reference to `from` said as `to`: {"text", "hits"}. Same files, same reading as scan.
static func rewrite(text: String, declaring_class: String, enum_name: String, from: String, to: String) -> Dictionary:
	var pattern: RegEx = reference_pattern(declaring_class, enum_name, PackedStringArray([from]),
		extends_class(text, declaring_class))
	var hits: int = pattern.search_all(text).size()
	if hits == 0:
		return {"text": text, "hits": 0}
	return {"text": pattern.sub(text, "$1." + to, true), "hits": hits}


## Reads every project script as {path: text}, leaving out the plugin folders and the behaviour packs.
## The cost is a walk and a read of each `.gd`; the States window asks only when a rename or removal is
## being worked out, never on open.
static func read_project(paths: PackedStringArray = PackedStringArray()) -> Dictionary:
	var sources: Dictionary = {}
	var listed: PackedStringArray = paths if not paths.is_empty() else load(FIND_REFERENCES_PATH).call("project_scripts")
	for path: String in listed:
		if path.begins_with(PACK_ROOT):
			continue
		sources[path] = FileAccess.get_file_as_string(path)
	return sources


## What the window says about one scan: "player_ui.gd (3 places)", one entry per file, the open file never
## among them. Ordered like the scan.
static func list_lines(uses: Array[Dictionary]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in uses:
		var count: int = int(entry["count"])
		lines.append("%s - %s" % [str(entry["path"]).get_file(),
			EventSheetL10n.translate("1 place") if count == 1 else EventSheetL10n.translate("%d places") % count])
	return lines
