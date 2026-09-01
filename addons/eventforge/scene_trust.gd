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
## `.change_scene_to_file(` is here beside the loaders because travelling to a layout builds it the
## same way - the trust question is about the file, not about which verb reached for it. It is
## spelled with its DOT because it is a method on the tree and is always written on something
## (`get_tree().change_scene_to_file(...)`); the loaders are spelled without one because they are
## reached by their own name.
const LOAD_CALLS: PackedStringArray = [
	"load(", "ResourceLoader.load(", "ResourceLoader.load_threaded_request(",
	".change_scene_to_file(",
]

## The marks the reading of a `.tscn` is written with. A scene file is a run of TAGS - `[gd_scene]`,
## `[ext_resource ...]`, `[sub_resource ...]`, `[node ...]` - each of which carries `key=value`
## attributes, and a script named by one of the two resource tags is code the file brings with it.
const SCENE_HEAD := "[gd_scene"
const EXT_RESOURCE := "ext_resource"
const SUB_RESOURCE := "sub_resource"

## The attributes the answer is read off, and the tail every script type's name ends in - `Script`,
## `GDScript`, `CSharpScript`. Read as a tail rather than as a list, because a type this reading has
## never heard of is exactly the one a crafted file would name.
const TYPE_ATTRIBUTE := "type"
const PATH_ATTRIBUTE := "path"
const SCRIPT_TYPE_TAIL := "Script"

## The one spelling a path may climb out of the project with. A `res://` prefix is not a promise on
## its own: `res://../payload.gd` begins with it and names a file beside the project.
const CLIMB_OUT := ".."


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


## The path expressions a blob of code asks the data-only question about AND ACTS ON, exactly as they
## are written. A guard is only a guard over the file it NAMES: a line asking about one scene and
## building another is the unguarded build it looks like, which is the same rule the Files section's
## unguarded-read check states about its own question.
##
## AND ONLY WHERE THE ANSWER IS REQUIRED TO BE TRUE. `if not <question>:` and `if debug or
## <question>:` both mention the question and then run the body on the files it refused, so counting
## the mention would go quiet on exactly the code the finding exists for. A mention that is negated,
## or that stands beside an `or`, is therefore not an answer this reading credits.
static func guarded_paths(text: String) -> PackedStringArray:
	var asked: PackedStringArray = PackedStringArray()
	var mark: String = HELPER_NAME + "("
	var at: int = text.find(mark)
	while at >= 0:
		var argument: String = _first_argument(_arguments_after(text, at + mark.length()))
		if not argument.is_empty() and not asked.has(argument) and _stands_as_a_requirement(text, at):
			asked.append(argument)
		at = text.find(mark, at + mark.length())
	return asked


## True when the question asked at `at` really has to be answered yes for the code it guards to run.
## Read off the one line it is written on, which is the whole condition a `if`/`elif`/`while` holds.
static func _stands_as_a_requirement(text: String, at: int) -> bool:
	var began: int = text.rfind("\n", at) + 1
	var ended: int = text.find("\n", at)
	var line: String = text.substr(began, (text.length() if ended < 0 else ended) - began)
	var before: String = line.substr(0, at - began).strip_edges()
	if before.ends_with("not") and not _is_word_glyph(_glyph_before(before, before.length() - 3)):
		return false
	return not _holds_an_or(line)


## The glyph before `index` in a piece of text, or "" at its start. Named so the reading of a word
## boundary is the same one everywhere in this file.
static func _glyph_before(text: String, index: int) -> String:
	return text.substr(index - 1, 1) if index > 0 else ""


## True when a condition offers an alternative rather than stating a requirement: an `or` written
## outside every bracket and every string literal on the line. An `or` INSIDE brackets belongs to a
## term of the condition, and the question standing beside that term is still required. A trailing
## COMMENT is not part of the condition at all, so the reading stops there - otherwise a guarded line
## with the word "or" in the note beside it would be read as a guard that is not one.
static func _holds_an_or(line: String) -> bool:
	var depth: int = 0
	var index: int = 0
	while index < line.length():
		var character: String = line[index]
		if character == "#":
			return false
		if character == "\"":
			var close_at: int = line.find("\"", index + 1)
			index = line.length() if close_at < 0 else close_at + 1
			continue
		if character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif depth == 0 and character == "o" and line.substr(index, 2) == "or" \
				and not _is_word_glyph(_glyph_before(line, index)) \
				and not _is_word_glyph(line.substr(index + 2, 1)):
			return true
		index += 1
	return false


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
## IT READS TAGS, NOT LINES, because that is what Godot's own text parser reads. A tag is `[` at the
## start of a line through to the `]` that closes it, and between those two the engine tokenises:
## `type = "Script"` with spaces around the `=` is the same tag as `type="Script"`, and a tag may run
## over more than one line. A reading built on `entry.contains("type=\"Script\"")` answers TRUE for
## both of those spellings while the engine loads the script they name, which is a guard that is not
## one. So the tag is gathered (quotes respected, so a `]` inside a value does not end it early), its
## name is read, and its attributes are parsed as the pairs they are.
##
## WHAT MAKES IT ANSWER FALSE, and every one of them is a thing the reader would want to know:
##   a file this cannot read     - missing, unreadable, or a binary `.scn` whose table is not text.
##                                 An unreadable file is not a file that has been cleared.
##   a tag it cannot parse       - one that never closes, one with a nameless attribute, one with no
##                                 type. Something unfamiliar is not something that has been cleared.
##   a script written INSIDE it  - a `[sub_resource]` whose type ends in `Script` is source code
##                                 carried in the scene file itself, in any language the engine has.
##   anything it points AT from  - EVERY `[ext_resource]` must name a path under `res://` that does
##   outside the project           not climb out of it. Not only scripts: a scene file may name
##                                 another SCENE or a `.tres`, and those carry tables of their own
##                                 which this reading does not open. Refusing the whole family is
##                                 what lets the answer mean "nothing from outside comes in with it"
##                                 instead of "no script is named on this page".
##
## A TRUE ANSWER IS ABOUT THIS FILE AND THE PLACES IT NAMES. It does not open the res:// files it
## points at, because those are the game's own - which is what a game IS.
##
## THE `uid=` ATTRIBUTE IS NOT READ, and does not need to be. Godot's text loader prefers a uid over
## the path beside it, but a uid only resolves through the project's own registry - which is built
## from the project's own files - so a tag whose PATH is under res:// names this project's code
## whichever of the two the engine follows, and a tag whose path is not answers false before the
## question of which one wins can arise.
static func helper_body() -> Array:
	return [
		"	var scene_text: String = FileAccess.get_file_as_string(scene_path)",
		"	if not scene_text.begins_with(%s):" % _as_literal(SCENE_HEAD),
		"		return false",
		"	var scene_lines: PackedStringArray = scene_text.split(\"\\n\")",
		"	var line_index: int = 0",
		"	while line_index < scene_lines.size():",
		"		var tag: String = scene_lines[line_index].strip_edges()",
		"		line_index += 1",
		"		if not tag.begins_with(\"[\"):",
		"			continue",
		"		var closed_at: int = -1",
		"		while closed_at < 0:",
		"			var quoted: bool = false",
		"			var scan: int = 0",
		"			while scan < tag.length():",
		"				if tag[scan] == \"\\\"\":",
		"					quoted = not quoted",
		"				elif tag[scan] == \"]\" and not quoted:",
		"					break",
		"				scan += 1",
		"			if scan < tag.length():",
		"				closed_at = scan",
		"			elif line_index >= scene_lines.size():",
		"				return false",
		"			else:",
		"				tag += \" \" + scene_lines[line_index].strip_edges()",
		"				line_index += 1",
		"		var head: String = tag.substr(1, closed_at - 1).strip_edges()",
		"		var named_at: int = head.find(\" \")",
		"		var tag_name: String = head if named_at < 0 else head.substr(0, named_at)",
		"		if tag_name != %s and tag_name != %s:" % [
			_as_literal(EXT_RESOURCE), _as_literal(SUB_RESOURCE)],
		"			continue",
		"		var rest: String = \"\" if named_at < 0 else head.substr(named_at + 1)",
		"		var fields: Dictionary = {}",
		"		var cursor: int = 0",
		"		while cursor < rest.length():",
		"			while cursor < rest.length() and rest[cursor] == \" \":",
		"				cursor += 1",
		"			var key_at: int = cursor",
		"			while cursor < rest.length() and rest[cursor] != \"=\" and rest[cursor] != \" \":",
		"				cursor += 1",
		"			var field: String = rest.substr(key_at, cursor - key_at)",
		"			while cursor < rest.length() and (rest[cursor] == \" \" or rest[cursor] == \"=\"):",
		"				cursor += 1",
		"			var value: String = \"\"",
		"			if cursor < rest.length() and rest[cursor] == \"\\\"\":",
		"				var ends_at: int = rest.find(\"\\\"\", cursor + 1)",
		"				if ends_at < 0:",
		"					return false",
		"				value = rest.substr(cursor + 1, ends_at - cursor - 1)",
		"				cursor = ends_at + 1",
		"			else:",
		"				var value_at: int = cursor",
		"				while cursor < rest.length() and rest[cursor] != \" \":",
		"					cursor += 1",
		"				value = rest.substr(value_at, cursor - value_at)",
		"			if field.is_empty():",
		"				return false",
		"			fields[field] = value",
		"		var kind: String = str(fields.get(%s, \"\"))" % _as_literal(TYPE_ATTRIBUTE),
		"		if kind.is_empty():",
		"			return false",
		"		if tag_name == %s:" % _as_literal(SUB_RESOURCE),
		"			if kind.ends_with(%s):" % _as_literal(SCRIPT_TYPE_TAIL),
		"				return false",
		"			continue",
		"		var place: String = str(fields.get(%s, \"\"))" % _as_literal(PATH_ATTRIBUTE),
		"		if place.contains(%s) or not place.begins_with(%s):" % [
			_as_literal(CLIMB_OUT), _as_literal(EventForgeFilePlaces.RES_SCHEME)],
		"			return false",
		"	return true",
	]


## One of the marks above as the GDScript literal that names it. The marks a scene file is written
## with carry double quotes of their own (`type="Script"`), and a mark spliced into an emitted string
## without escaping them closes that string half way through - a parse error in somebody's game,
## written by the plugin, which is exactly the kind of thing a shared spelling exists to prevent.
static func _as_literal(text: String) -> String:
	return "\"%s\"" % text.replace("\\", "\\\\").replace("\"", "\\\"")


## Where a call starts in a line at or after `from`, or -1. A call spelled with its own leading DOT
## is a method written on something, and the dot is the boundary: whatever the receiver is, the name
## after it is the whole name. A call spelled without one is reached by its own name, so it only
## counts when nothing runs into it from the left - which is what keeps `preload(`, a method called
## `reload(`, and somebody's own `MyResourceLoader.load(` out of the answer.
static func _call_at(line: String, call_text: String, from: int = 0) -> int:
	var at: int = line.find(call_text, from)
	while at >= 0:
		var before: String = _glyph_before(line, at)
		if call_text.begins_with(".") or (not _is_word_glyph(before) and before != "."):
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
