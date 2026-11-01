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


## How many of the references `rewrite` would change in `text` are a TEST of the state - a comparison
## (`== Player.State.JUMP`, `!=`) or a `match` branch - rather than a state being set. A removal moves every
## reference to the default, so such a test starts asking about the default instead: a change of what the
## code does, which the window names before Apply.
static func comparisons(text: String, declaring_class: String, enum_name: String, member: String) -> int:
	var pattern: RegEx = reference_pattern(declaring_class, enum_name, PackedStringArray([member]),
		extends_class(text, declaring_class))
	var counted: int = 0
	for hit: RegExMatch in pattern.search_all(text):
		var line_start: int = text.rfind("\n", hit.get_start()) + 1
		var line_end: int = text.find("\n", hit.get_end())
		if line_end < 0:
			line_end = text.length()
		var before: String = text.substr(line_start, hit.get_start() - line_start).strip_edges()
		var after: String = text.substr(hit.get_end(), line_end - hit.get_end()).strip_edges()
		if before.ends_with("==") or before.ends_with("!=") or after.begins_with("==") or after.begins_with("!=") \
				or (before.is_empty() and after.begins_with(":")):
			counted += 1
	return counted


## The scenes and resources (`files`, {path: text} of `.tscn` / `.tres`) that store this machine's variable
## as a number for a node running `script_path`: a line `<variable> = <int>` in a file that names the script.
## An enum member's number is its place in the list, so removing a state from the middle makes every later
## state's number mean the one before it in those files. Path-ordered.
static func stored_numbers(files: Dictionary, script_path: String, variable: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if script_path.is_empty() or variable.is_empty():
		return found
	var stored: RegEx = RegEx.new()
	stored.compile("(?m)^%s = -?\\d+\\s*$" % variable)
	var paths: Array = files.keys()
	paths.sort()
	for path: Variant in paths:
		var text: String = str(files[path])
		if text.contains("path=\"%s\"" % script_path) and stored.search(text) != null:
			found.append(str(path))
	return found


## Reads every project scene and resource as {path: text}, leaving out the plugin folders and the behaviour
## packs. Asked only while a removal is being worked out in the States window, never on open.
static func read_project_scenes(root: String = "res://") -> Dictionary:
	var files: Dictionary = {}
	var directories: Array[String] = [root]
	while not directories.is_empty():
		var current: String = directories.pop_back()
		if current.begins_with("res://addons") or current.begins_with(PACK_ROOT.trim_suffix("/")):
			continue
		var dir: DirAccess = DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while not entry.is_empty():
			var entry_path: String = current.path_join(entry)
			if dir.current_is_dir():
				if not entry.begins_with("."):
					directories.append(entry_path)
			elif entry.get_extension() in ["tscn", "tres"]:
				files[entry_path] = FileAccess.get_file_as_string(entry_path)
			entry = dir.get_next()
		dir.list_dir_end()
	return files
