# EventForge - the engine's own parse errors for an opened script, as line + message.
#
# An event sheet marks a broken event red with the reason. When a .gd opened as a sheet does not
# compile, the same has to be true of the rows built from the offending lines - and the reason must be
# the ENGINE'S, not a second checker of our own that could disagree with the one that actually refuses
# to run the game.
#
# Godot does not bind its parse diagnostics to scripting: `GDScript.reload()` returns nothing richer
# than "Parse error", and the line and message only ever reach the error stream. `ResourceLoader.load`
# is no better, and a detached in-memory `GDScript` cannot resolve the project's `class_name` globals
# at all, so it reports a healthy file as broken. What DOES give both facts, exactly as the engine
# words them, is asking a second Godot to parse the file and reading what it prints:
#
#     <godot> --headless --path <project> --check-only --script <file>
#
# The project path is load-bearing - without it the global class cache is not loaded and every
# `class_name` in the file reports as an undeclared type. Exit code 0 means "this file is fine", and
# the run costs a few hundred milliseconds, so it belongs on the open job's worker thread and never on
# the paint path. Results are cached per path + modification time, so reopening a tab is free.
#
# The errors are stored on the sheet under PARSE_ERRORS_META and read back through errors_for /
# error_count - the row builder flags the rows the lines belong to, and the head bar counts them.
@tool
class_name EventSheetParseErrors
extends RefCounted

## Sheet metadata key holding [{line: int, message: String}] for the opened file, newest check wins.
const PARSE_ERRORS_META: String = "__parse_errors"

## path -> {"mtime": int, "errors": Array}. A file the user has not touched is never re-checked.
static var _cache: Dictionary = {}


## The engine's parse errors for a res:// script, as [{line: int, message: String}] sorted by line.
## Empty means the file parses - which is also what an unreachable checker returns, because a reading
## that invents errors is worse than one that shows none.
static func check_file(path: String) -> Array:
	if not path.begins_with("res://") or not FileAccess.file_exists(path):
		return []
	var modified_time: int = FileAccess.get_modified_time(path)
	var cached: Dictionary = _cache.get(path, {}) as Dictionary
	if not cached.is_empty() and int(cached.get("mtime", -1)) == modified_time:
		return (cached.get("errors", []) as Array).duplicate(true)
	var executable: String = OS.get_executable_path()
	if executable.is_empty():
		return []
	var output: Array = []
	var arguments: PackedStringArray = PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--check-only",
		"--script", ProjectSettings.globalize_path(path),
	])
	var exit_code: int = OS.execute(executable, arguments, output, true, false)
	var errors: Array = []
	if exit_code != 0:
		errors = parse_output("\n".join(PackedStringArray(output)), path)
	_cache[path] = {"mtime": modified_time, "errors": errors}
	return errors.duplicate(true)


## The [{line, message}] a check run's output describes, for `path` only. Split out from check_file so
## the shape of the engine's report is pinnable without spawning anything. The two lines that matter:
##
##     SCRIPT ERROR: Parse Error: <message>
##        at: GDScript::reload (res://thing.gd:7)
##
## A message whose `at:` names another file is that file's problem (a broken dependency), and is
## dropped: flagging a row here for a line number belonging to some other script would point the
## reader at innocent code.
static func parse_output(text: String, path: String) -> Array:
	var errors: Array = []
	var seen: Dictionary = {}
	var pending_message: String = ""
	var location: RegEx = RegEx.create_from_string("^\\s*at: .*\\((.+):(\\d+)\\)\\s*$")
	if location == null:
		return errors
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()
		var marker: int = line.find("Parse Error: ")
		if marker != -1 and line.begins_with("SCRIPT ERROR"):
			pending_message = line.substr(marker + "Parse Error: ".length()).strip_edges()
			continue
		if pending_message.is_empty():
			continue
		var location_match: RegExMatch = location.search(raw_line)
		if location_match == null:
			continue
		var reported_path: String = location_match.get_string(1).strip_edges()
		var line_number: int = int(location_match.get_string(2))
		if _same_file(reported_path, path) and line_number > 0:
			var key: String = "%d|%s" % [line_number, pending_message]
			if not seen.has(key):
				seen[key] = true
				errors.append({"line": line_number, "message": pending_message})
		pending_message = ""
	errors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("line", 0)) < int(b.get("line", 0))
	)
	return errors


## Remembers a check's result on the sheet, so the row builder and the head bar read one answer.
static func store_on_sheet(sheet: EventSheetResource, errors: Array) -> void:
	if sheet == null:
		return
	sheet.set_meta(PARSE_ERRORS_META, errors.duplicate(true))


## The stored [{line, message}] for a sheet - [] when it was never checked or parses cleanly.
static func errors_for(sheet: EventSheetResource) -> Array:
	if sheet == null or not sheet.has_meta(PARSE_ERRORS_META):
		return []
	var stored: Variant = sheet.get_meta(PARSE_ERRORS_META)
	return (stored as Array).duplicate(true) if stored is Array else []


## How many parse errors the opened file has. The head bar's count - "N errors - the game will not run
## this script" - reads this and nothing else.
static func error_count(sheet: EventSheetResource) -> int:
	return errors_for(sheet).size()


## Row diagnostics for the viewport, as [{uid, message, suggestion}] - each error's line resolved to
## the most specific row that emitted it, through the source map the compiler already keeps. Because
## an opened file re-emits byte-identically, a line of the generated output IS that line of the file.
static func row_diagnostics(errors: Array, source_map: Array) -> Array:
	var diagnostics: Array = []
	var seen: Dictionary = {}
	for entry: Variant in errors:
		if not (entry is Dictionary):
			continue
		var line: int = int((entry as Dictionary).get("line", 0))
		var message: String = str((entry as Dictionary).get("message", ""))
		for map_entry: Variant in EventSheetLineRowMapper.entries_for_line(source_map, line):
			var uid: String = str((map_entry as Dictionary).get("uid", ""))
			if uid.is_empty() or seen.has(uid):
				continue
			seen[uid] = true
			diagnostics.append({"uid": uid, "message": message, "suggestion": ""})
			break
	return diagnostics


## Two paths naming the same script. The engine reports res:// paths when the project is loaded, but a
## globalized path is possible too, so both spellings are compared on the resolved absolute form.
static func _same_file(reported_path: String, path: String) -> bool:
	if reported_path == path:
		return true
	return ProjectSettings.globalize_path(reported_path).simplify_path() == ProjectSettings.globalize_path(path).simplify_path()
