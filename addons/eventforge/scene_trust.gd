# EventForge - the trust line a scene file draws, and the ONE reading of it.
#
# A `.tscn` is a text file that names things, and one of the things it may name is a SCRIPT. Building
# it - `load(path).instantiate()`, `change_scene_to_file(path)` - attaches that script and runs it,
# with everything this game can reach: the player's files, their network, their machine. For a scene
# the project ships with that is exactly right and is what a game IS. For a scene that arrived from
# somewhere else - the player's own folder, a level pack somebody sent them, a file this game itself
# wrote out and cannot vouch for afterwards - it is a stranger's code running as this game.
#
# Nothing in the engine says so, because nothing is wrong: the line is correct GDScript and it does
# precisely what it says. So this file is what says it, and it says it in one place because four
# readers ask the same two questions:
#
#   WHICH LINES BUILD A SCENE FROM A PATH THIS PROJECT CANNOT VOUCH FOR - the Doctor's Files
#   section over the project's scripts, and the canvas over the lines ONE row emits.
#
#   WHICH LINES ASK FIRST - the Scene File Is Data-Only condition, wherever it was written, read off
#   the call it compiles to rather than off a list of row ids, so a question typed by hand counts.
#
# IT ONLY EVER READS THE TEXT, exactly as EventForgeFilePlaces does and for the same reason: a path
# field holds a GDScript expression, and a path built out of pieces or held in a name is one this
# file has nothing to say about. Every answer below is therefore raised on a quoted LITERAL only.
# A quiet reading is not a proof, and the finding that uses it says so out loud.
#
# WHAT IT DELIBERATELY DOES NOT CLAIM. A `.tres` from outside can name a script too, and a path that
# came in through one of the game's own doors is followed by EventForgeOutsidePaths for the Files
# section's own outside-content finding. This file is about SCENE files with a place that can be read
# off the line, which is the half a sheet row can be asked about and repaired in one gesture.
@tool
class_name EventForgeSceneTrust
extends RefCounted

## The function the Scene File Is Data-Only condition compiles to - written into the file once by the
## compiler, the first time any row asks the question. Frozen alongside the row's template: the
## Doctor, the row-state reader and the one-click door all recognise the guard by this call.
const HELPER_NAME := "__eventsheets_scene_is_data_only"

## The row that asks the question, and the parameter that carries the file it asks about. Named here
## so the finding, the one-click door and the tests all spell the guard the same way.
const GUARD_ACE_ID := "SceneFileIsDataOnly"
const GUARD_PARAM := "path"

## The row that writes one, and the parameter that carries the file it writes. The other half of the
## same story: a scene this game saved into the player's folder is a scene it must ask about before
## it builds it again.
const SAVE_ACE_ID := "SaveBranchAsSceneFile"
const SAVE_PATH_PARAM := "path"

## What a scene file is called. Godot writes `.tscn` from the editor and `.scn` when a scene is saved
## in the binary form; both name a resource table that may hold a script.
const SCENE_EXTENSIONS: PackedStringArray = [".tscn", ".scn"]

## The calls that BUILD what a file describes. `preload(` is deliberately not one: it takes a
## constant path, so a preloaded scene is a file the game shipped with by construction.
## `change_scene_to_file(` is here beside the loaders because travelling to a layout builds it the
## same way - the trust question is about the file, not about which verb reached for it.
const LOAD_CALLS: PackedStringArray = [
	"load(", "ResourceLoader.load(", "ResourceLoader.load_threaded_request(",
	"change_scene_to_file(",
]

## The two marks the emitted guard is written with, and the two the reading of a `.tscn` looks for.
## A scene file's resource table is a run of `[ext_resource ...]` and `[sub_resource ...]` headers at
## the top of the file, and a script in either of them is code the file brings with it.
const SCENE_HEAD := "[gd_scene"
const EXT_RESOURCE := "[ext_resource"
const SUB_RESOURCE := "[sub_resource"
const SCRIPT_TYPE := "type=\"Script\""
const GDSCRIPT_TYPE := "type=\"GDScript\""
const PATH_ATTRIBUTE := "path=\""


## The scene paths one line builds, as the expressions they are written as, in the order they appear.
## Only a quoted literal naming a scene file: a path built out of pieces is one this reading has
## nothing to say about, and a `.tres` or a `.png` is not the question this file asks.
static func loaded_scene_paths(line: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for call_text: String in LOAD_CALLS:
		var at: int = _call_at(line, call_text)
		while at >= 0:
			var argument: String = _first_argument(
				_arguments_after(line, at + call_text.length()))
			if names_a_scene(argument) and not found.has(argument):
				found.append(argument)
			at = _call_at(line, call_text, at + call_text.length())
	return found


## The scene paths one line builds that this project CANNOT vouch for: everything but `res://`, which
## is the game's own files and is the one place a scene is this project's own by construction.
## A path whose place cannot be read off the literal is not here - saying nothing is the honest
## answer, and it is the answer the finding's own wording promises.
static func untrusted_scene_paths(line: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for path_expression: String in loaded_scene_paths(line):
		var place: String = EventForgeFilePlaces.place_of(path_expression)
		if place == EventForgeFilePlaces.PLACE_USER \
				or place == EventForgeFilePlaces.PLACE_ABSOLUTE:
			found.append(path_expression)
	return found


## The path expressions a blob of code asks the data-only question about, exactly as they are
## written. A guard is only a guard over the file it NAMES: a line asking about one scene and
## building another is the unguarded build it looks like, which is the same rule the Files section's
## unguarded-read check states about its own question.
static func guarded_paths(text: String) -> PackedStringArray:
	var asked: PackedStringArray = PackedStringArray()
	var mark: String = HELPER_NAME + "("
	var at: int = text.find(mark)
	while at >= 0:
		var argument: String = _first_argument(_arguments_after(text, at + mark.length()))
		if not argument.is_empty() and not asked.has(argument):
			asked.append(argument)
		at = text.find(mark, at + mark.length())
	return asked


## True when a path expression is a quoted literal naming a scene file. The extension is read off the
## literal because that is what makes the answer provable: `load(name + ".tscn")` may well be a
## scene, and nothing here can say which one.
static func names_a_scene(path_expression: String) -> bool:
	var literal: String = EventForgeFilePlaces.literal_of(path_expression)
	if literal.is_empty():
		return false
	var lowered: String = literal.to_lower()
	for extension: String in SCENE_EXTENSIONS:
		if lowered.ends_with(extension):
			return true
	return false


## The cheapest possible first question, asked of a whole file before any of the above is: does this
## text build anything from a path at all. A project whose scripts never load a scene pays one
## substring test each.
static func says_enough(source: String) -> bool:
	for call_text: String in LOAD_CALLS:
		if source.contains(call_text):
			return true
	return false


## The head line of the function the condition compiles to - the ONE spelling of it, shared by the
## compiler that writes it and the tests that pin it.
static func helper_head() -> String:
	return "func %s(scene_path: String) -> bool:" % HELPER_NAME


## The body of that function: the scene file's own resource table, read as TEXT, with nothing built.
##
## THREE ANSWERS OF FALSE, and each of them is a thing the reader would want to know:
##   a file this cannot read      - missing, unreadable, or a binary `.scn` whose table is not text.
##                                  An unreadable file is not a file that has been cleared.
##   a script written INSIDE it   - a `[sub_resource type="GDScript"]` block is source code carried
##                                  in the scene file itself.
##   a script it points AT from   - an `[ext_resource type="Script"]` whose path is not under res://.
##   outside the project            A scene naming this project's own scripts is this project's code
##                                  running, which is what a game is; one naming a script beside
##                                  itself in the player's folder is not.
##
## IT READS THE ONE FILE IT IS GIVEN. A scene may name another scene, and that one has a table of its
## own. So a true answer is about this file, said plainly on the row, rather than a promise about
## everything the file might reach.
static func helper_body() -> Array:
	return [
		"	var scene_text: String = FileAccess.get_file_as_string(scene_path)",
		"	if not scene_text.begins_with(%s):" % _as_literal(SCENE_HEAD),
		"		return false",
		"	for scene_line: String in scene_text.split(\"\\n\"):",
		"		var entry: String = scene_line.strip_edges()",
		"		if entry.begins_with(%s) and entry.contains(%s):" % [
			_as_literal(SUB_RESOURCE), _as_literal(GDSCRIPT_TYPE)],
		"			return false",
		"		if not entry.begins_with(%s) or not entry.contains(%s):" % [
			_as_literal(EXT_RESOURCE), _as_literal(SCRIPT_TYPE)],
		"			continue",
		"		var at: int = entry.find(%s)" % _as_literal(PATH_ATTRIBUTE),
		"		if at < 0 or not entry.substr(at + %d).begins_with(%s):" % [
			PATH_ATTRIBUTE.length(), _as_literal(EventForgeFilePlaces.RES_SCHEME)],
		"			return false",
		"	return true",
	]


## One of the marks above as the GDScript literal that names it. The marks a scene file is written
## with carry double quotes of their own (`type="Script"`), and a mark spliced into an emitted string
## without escaping them closes that string half way through - a parse error in somebody's game,
## written by the plugin, which is exactly the kind of thing a shared spelling exists to prevent.
static func _as_literal(text: String) -> String:
	return "\"%s\"" % text.replace("\\", "\\\\").replace("\"", "\\\"")


## Where a call starts in a line at or after `from`, or -1. A bare `load(` is only a loader when
## nothing runs into it from the left, which is what keeps `preload(` and a method called
## `reload(` out of the answer.
static func _call_at(line: String, call_text: String, from: int = 0) -> int:
	var at: int = line.find(call_text, from)
	while at >= 0:
		var before: String = line.substr(at - 1, 1) if at > 0 else ""
		if call_text.contains(".") or (not _is_word_glyph(before) and before != "."):
			return at
		at = line.find(call_text, at + call_text.length())
	return -1


static func _is_word_glyph(glyph: String) -> bool:
	if glyph.is_empty():
		return false
	return glyph == "_" or glyph.is_valid_int() or glyph.to_lower() != glyph.to_upper()


## The text between a call's opening bracket and its matching close, so a nested call inside the
## arguments does not end them early.
static func _arguments_after(line: String, from: int) -> String:
	var depth: int = 1
	var index: int = from
	while index < line.length():
		var character: String = line[index]
		if character == "(":
			depth += 1
		elif character == ")":
			depth -= 1
			if depth == 0:
				return line.substr(from, index - from)
		index += 1
	return line.substr(from)


## The first argument of an argument list, trimmed, with a call or a list inside it kept in one
## piece and a comma inside a string literal left alone.
static func _first_argument(arguments: String) -> String:
	var depth: int = 0
	var index: int = 0
	while index < arguments.length():
		var character: String = arguments[index]
		if character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif character == "\"":
			var close_at: int = arguments.find("\"", index + 1)
			index = arguments.length() if close_at < 0 else close_at
		elif character == "," and depth == 0:
			return arguments.substr(0, index).strip_edges()
		index += 1
	return arguments.strip_edges()
