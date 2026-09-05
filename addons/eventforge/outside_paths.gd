# EventForge - which paths in a script came from OUTSIDE the game, and where they end up.
#
# A game that opens a door for its players - a drop on the window, a file chooser, a watched folder,
# an unpacked archive - is holding paths it did not write. That is fine, and it is the whole point of
# those doors. What is not fine is handing one of those paths to a call that BUILDS what the file
# describes: `load()`, `ResourceLoader.load()`, the threaded pair, `change_scene_to_file()` - or to
# `ProjectSettings.load_resource_pack()`, which builds nothing at that moment and is wider than all of
# them together, because it MOUNTS the pack into `res://` and by default replaces the game's own files
# with the ones inside it.
#
# WHY THOSE CALLS ARE DIFFERENT. A `.tscn`, a `.tres` and a `.res` may name a script, and loading one
# builds the objects it describes with that script attached. So a scene or a resource file that came
# from somewhere else can carry code, and loading it can run a stranger's code with everything the
# game itself can reach: the player's files, their network, their machine. Reading the same file as an
# IMAGE, as TEXT or as a TABLE cannot do that, because those readers answer with pixels, characters
# and rows and never with behaviour.
#
# WHAT THIS FILE IS. A pure reading of one script's text: which names hold an outside path, and which
# statements hand one to a loader. It answers in exact lines, so the Doctor can quote the statement a
# reader has to look at rather than the file it is somewhere in.
#
# HOW FAR THE TRACE REACHES, said plainly because a check that overstates its reach is worse than no
# check. It follows NAMES within one file: a parameter of an outside-content handler, anything
# assigned from one - written plainly or as `self.chosen`, which is the same name said two ways -
# anything a `for` walks out of one, and any path written under a folder the same file watches or
# unpacks into, whether that folder is written as a literal or held in a name this file bound to one.
# It keeps one set of names per FILE rather than one per function, so a name that is tainted anywhere
# is tainted everywhere in that file - which finds the very common shape where one handler stores the
# path on the object and another loads it, at the price of a name reused for two unrelated things in
# two functions reading as tainted in both. It does NOT follow a path across files, into an array
# element it cannot see the name of, or through a call into a function whose body it then walks. A
# quiet file is therefore not a proof; a loud one is a line to look at - and the finding says so, so
# a reader is never left thinking silence was an all-clear.
#
# AND FOUR SHAPES IT IS QUIET ABOUT ON PURPOSE, written down because a limit nobody wrote down reads
# as a limit that is not there:
#
#   AN UNPACK WITH NO MAKE-FOLDER LINE   The folder an archive lands in is read off the
#                                        `make_dir_recursive_absolute` line beside the reader, which
#                                        is how every row this plugin emits writes one. A
#                                        hand-written unpack into a folder that already exists has
#                                        no such line, so this file learns no folder from it.
#   A PROGRAM RATHER THAN A FILE         `OS.execute`, `OS.create_process` and `OS.shell_open` hand a
#                                        path to the operating system, which runs it. That is wider
#                                        than any loader here and it is not a load, so the loaders
#                                        below do not name it and the finding says so in words.
#   TEXT TURNED INTO CODE BY HAND        `GDScript.new()` with `source_code` set from a file read and
#                                        `reload()` called makes code out of characters with no
#                                        loader involved at all.
#   ANOTHER FILE'S DOOR                  The trace is per file, so a path a door opened in one script
#                                        and a load written in another are two halves this never
#                                        joins.
#
# NOTHING HERE IS A LIST OF ROW IDS. The seeds are the SIGNALS and the HANDLER NAMES the doors are
# spelled with, so the same reading answers for a sheet's emitted script and for the hand-written code
# a person typed themselves - which is the only way the finding can appear on both.
@tool
class_name EventForgeOutsidePaths
extends RefCounted

## The signals a door raises with an outside path in them. A function connected to one of these, in
## the file being read, has outside paths in its parameters.
const OUTSIDE_SIGNALS: PackedStringArray = [
	"files_dropped", "file_appeared", "file_changed", "file_removed", "file_selected",
]

## The handler names the doors are spelled with when nothing connects them in the same file: the ask
## door's answer is CALLED by name from the line that opens the chooser, and a person writing this by
## hand writes these same names because they are the ones the engine and the packs suggest.
const OUTSIDE_HANDLERS: PackedStringArray = [
	"_on_files_dropped", "_on_file_chosen", "_on_file_appeared", "_on_file_changed",
	"_on_file_removed", "_on_file_selected", "_on_file_dropped",
]

## The verb that starts a watch, whose first argument names a folder the game does not control.
const WATCH_CALL: String = "watch_folder("

## The two marks an unpack is spelled with: the reader, and the line that makes the folder every entry
## is written under. The folder in that line is the folder the archive's contents land in.
const UNPACK_MARK: String = "ZIPReader"
const MAKE_DIR_CALL: String = "DirAccess.make_dir_recursive_absolute("

## The one call in this list that does not build anything at the moment it runs.
## `ProjectSettings.load_resource_pack` MOUNTS a `.pck` or a `.zip` into `res://`, and with its second
## argument left at its default it REPLACES the game's own files with the ones inside it. Nothing is
## built there and everything after it may be: the pack's scripts, scenes and resources ARE `res://`
## from then on, which is the one place the rest of this plugin treats as the game's own by
## construction. So a stranger's pack handed to it is the widest door in the file, which is why it is
## named on its own - the finding says one more true thing about a line that holds it.
const PACK_MOUNT_CALL: String = "ProjectSettings.load_resource_pack("

## The calls that can build an object from a file, and can therefore attach a script named inside it.
## `preload(` is not one: it takes a constant path, which is a file the game shipped with by
## construction. `Image.load_from_file` and the audio readers are not one either, and are the doors
## this check points at.
##
## LOADING IS NOT THE ONLY VERB THAT BUILDS ONE. Travelling to a layout builds the scene it names
## exactly as loading it does, and the threaded pair is one call that ASKS and another that hands the
## object over, so both halves are here. The one spelled with a leading DOT is a method written on
## something - `get_tree().change_scene_to_file(...)` - and the dot is the boundary: whatever the
## receiver is, the name after it is the whole name.
const LOADER_CALLS: PackedStringArray = [
	"ResourceLoader.load(", "ResourceLoader.load_threaded_request(",
	"ResourceLoader.load_threaded_get(", "load(",
	".change_scene_to_file(", PACK_MOUNT_CALL,
]

## How many rounds the name trace runs before it stops. A chain of assignments is short in real code,
## and a fixed ceiling is what keeps the answer a pure function of the text rather than of how long
## anybody was willing to wait.
const TRACE_ROUNDS: int = 8


## Every statement of this source that hands an outside path to a loader, trimmed, in the order they
## appear. The whole reading, and the only function the Doctor needs.
static func loading_outside_lines(source: String) -> PackedStringArray:
	var statements: PackedStringArray = statements_of(source)
	var tainted: Dictionary = _outside_names(statements)
	var folders: PackedStringArray = outside_folders(statements)
	var found: PackedStringArray = PackedStringArray()
	for line: String in statements:
		for call_text: String in LOADER_CALLS:
			var at: int = _call_at(line, call_text)
			if at < 0:
				continue
			var arguments: String = arguments_after(line, at + call_text.length())
			if _is_outside(arguments, tainted, folders):
				found.append(line)
				break
	return found


## The folders this file watches or unpacks into, as the expressions they are written as. A path
## written under one of these is a path whose contents somebody else chose.
static func outside_folders(statements: PackedStringArray) -> PackedStringArray:
	var folders: PackedStringArray = PackedStringArray()
	var unpacking: bool = false
	for line: String in statements:
		var watch_at: int = line.find(WATCH_CALL)
		if watch_at >= 0:
			var watched: String = _first_argument(arguments_after(line, watch_at + WATCH_CALL.length()))
			if not watched.is_empty() and not folders.has(watched):
				folders.append(watched)
				# A FOLDER MAY BE HELD IN A NAME. `var folder = "user://mods"` on one line and
				# `watch_folder(folder, 2.0)` on another is the same watch as the literal one, and a
				# path written under it is as much somebody else's content either way. So a folder
				# named by a plain identifier is followed back to the literal that name was bound to
				# in this same file - the name alone says nothing about which folder it is.
				var bound: String = _literal_bound_to(watched, statements)
				if not bound.is_empty() and not folders.has(bound):
					folders.append(bound)
		if line.contains(UNPACK_MARK):
			unpacking = true
		var make_at: int = line.find(MAKE_DIR_CALL)
		if unpacking and make_at >= 0:
			var into: String = _first_argument(arguments_after(line, make_at + MAKE_DIR_CALL.length()))
			unpacking = false
			if not into.is_empty() and not into.contains(".get_base_dir()") and not folders.has(into):
				folders.append(into)
				# AND AN UNPACK FOLDER MAY BE HELD IN A NAME TOO, exactly as a watched one may:
				# `var target := "user://unpacked"` on one line and the make-folder line on another
				# is the same folder said twice. The watch above followed the name back to the
				# literal it was bound to and this did not, so `load("user://unpacked/main.tscn")`
				# went unread whenever the folder was written as a name.
				var bound: String = _literal_bound_to(into, statements)
				if not bound.is_empty() and not folders.has(bound):
					folders.append(bound)
	return folders


## The quoted literal one plain name is bound to in this file, or "" when the name is not a plain one,
## is never bound to a literal, or is bound to two different ones - in which case there is no single
## answer and guessing at one would be worse than saying nothing.
static func _literal_bound_to(name_text: String, statements: PackedStringArray) -> String:
	if name_text.is_empty() or not _is_plain_name(name_text):
		return ""
	var found: String = ""
	for line: String in statements:
		var equals_at: int = _assignment_at(line)
		if equals_at < 0:
			continue
		var left: String = line.substr(0, equals_at).strip_edges().trim_suffix(":")
		left = left.trim_prefix("var ").trim_prefix("const ").trim_prefix("self.").split(":")[0].strip_edges()
		if left != name_text:
			continue
		var right: String = line.substr(equals_at + 1).strip_edges()
		if EventForgeFilePlaces.literal_of(right).is_empty():
			continue
		if not found.is_empty() and found != right:
			return ""
		found = right
	return found


## True when a connect's argument is a lambda written on the spot rather than a name: it opens on the
## keyword and its own bracket follows, which is the one spelling GDScript has for it.
static func _is_lambda(text: String) -> bool:
	if not text.begins_with("func"):
		return false
	var rest: String = text.substr(4).strip_edges()
	return rest.begins_with("(")


## The parameter names a function head declares, read off the text between its brackets. Used for a
## lambda, whose head is written inside the call it is handed to; the same splitting the named
## handlers above go through, so a typed or defaulted parameter reads the same either way.
static func _parameters_of(head: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var open_at: int = head.find("(")
	if open_at < 0:
		return names
	for argument: String in _split_arguments(arguments_after(head, open_at + 1)):
		var parameter: String = argument.split(":")[0].split("=")[0].strip_edges()
		if not parameter.is_empty() and not names.has(parameter):
			names.append(parameter)
	return names


## True for a bare identifier - no dots, no brackets, no spaces.
static func _is_plain_name(text: String) -> bool:
	if text.is_empty():
		return false
	for index: int in range(text.length()):
		var glyph: String = text[index]
		if glyph == "_" or glyph.is_valid_int() or glyph.to_lower() != glyph.to_upper():
			continue
		return false
	return true


## Every non-blank, non-comment statement of a source, trimmed. The same unit the rest of the Files
## section reads, so a line quoted by one check is spelled the way the others would quote it.
static func statements_of(source: String) -> PackedStringArray:
	var statements: PackedStringArray = PackedStringArray()
	for raw_line: String in source.split("\n"):
		var line: String = raw_line.strip_edges()
		if not line.is_empty() and not line.begins_with("#"):
			statements.append(line)
	return statements


## The text between a call's opening bracket and its matching close, so a nested call inside the
## arguments does not end them early.
static func arguments_after(line: String, from: int) -> String:
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


## The names in this file that hold a path from outside the game, as a set. Seeded from the doors and
## grown by assignment until nothing new is learned or the ceiling is reached.
static func _outside_names(statements: PackedStringArray) -> Dictionary:
	var tainted: Dictionary = {}
	for name_text: String in _door_parameters(statements):
		tainted[name_text] = true
	var folders: PackedStringArray = outside_folders(statements)
	for round_index: int in range(TRACE_ROUNDS):
		var before: int = tainted.size()
		for line: String in statements:
			var learned: String = _name_taught_by(line, tainted, folders)
			if not learned.is_empty():
				tainted[learned] = true
		if tainted.size() == before:
			break
	return tainted


## The parameter names of every function in this file that answers a door: one connected to a door's
## signal, one spelled with a door's own handler name, or a LAMBDA written into the connect call
## itself.
##
## A LAMBDA IS A HANDLER WITH NO NAME. `files_dropped.connect(func(files): load(files[0]))` is the
## shortest way anybody writes this and it is the one shape the reading missed: the lambda's TEXT was
## stored as if it were a handler name, and no `func ` line in the file ever matched it, so the whole
## trace started from nothing. Its own parameter list is read instead, right where it is written -
## which is also all that is needed, because whatever a lambda does with its parameters it does on
## the same line or on the indented lines under it, and those are statements of this file like any
## other.
static func _door_parameters(statements: PackedStringArray) -> PackedStringArray:
	var handlers: Dictionary = {}
	for handler_name: String in OUTSIDE_HANDLERS:
		handlers[handler_name] = true
	var names: PackedStringArray = PackedStringArray()
	for line: String in statements:
		for signal_name: String in OUTSIDE_SIGNALS:
			var mark: String = "%s.connect(" % signal_name
			var at: int = line.find(mark)
			if at < 0:
				continue
			var connected: String = _first_argument(arguments_after(line, at + mark.length()))
			if connected.is_empty():
				continue
			if _is_lambda(connected):
				for parameter: String in _parameters_of(connected):
					if not names.has(parameter):
						names.append(parameter)
				continue
			var pieces: PackedStringArray = connected.split(".")
			handlers[pieces[pieces.size() - 1].strip_edges()] = true
	for line: String in statements:
		if not line.begins_with("func "):
			continue
		var open_at: int = line.find("(")
		if open_at < 0:
			continue
		var declared: String = line.substr(5, open_at - 5).strip_edges()
		if not handlers.has(declared):
			continue
		for argument: String in _split_arguments(arguments_after(line, open_at + 1)):
			var parameter: String = argument.split(":")[0].split("=")[0].strip_edges()
			if not parameter.is_empty() and not names.has(parameter):
				names.append(parameter)
	return names


## The name one statement teaches, or "" when it teaches none: an assignment or a `for` whose right
## side is an outside path. Only a name that is not already known is returned, so the rounds above
## stop as soon as nothing is new.
static func _name_taught_by(line: String, tainted: Dictionary, folders: PackedStringArray) -> String:
	if line.begins_with("for "):
		var in_at: int = line.find(" in ")
		if in_at < 0:
			return ""
		var walked: String = line.substr(4, in_at - 4).split(":")[0].strip_edges()
		var over: String = line.substr(in_at + 4).trim_suffix(":").strip_edges()
		if walked.is_empty() or tainted.has(walked) or not _is_outside(over, tainted, folders):
			return ""
		return walked
	var equals_at: int = _assignment_at(line)
	if equals_at < 0:
		return ""
	var left: String = line.substr(0, equals_at).strip_edges()
	var right: String = line.substr(equals_at + 1).strip_edges()
	left = left.trim_prefix("var ").trim_prefix("const ").split(":")[0].strip_edges()
	# `self.chosen = path` is the very shape this trace exists for - one handler stores the path on
	# the object and another loads it - and `self.` is this object, so the name it writes is a name
	# of this file. Any OTHER dotted left side is somebody else's object and is left alone.
	left = left.trim_prefix("self.")
	if left.is_empty() or left.contains(" ") or left.contains(".") or left.contains("["):
		return ""
	if tainted.has(left) or not _is_outside(right, tainted, folders):
		return ""
	return left


## Where the `=` of a plain assignment is, or -1 for a statement that is not one. The compound forms
## (`+=`, `==`, `!=`, `<=`, `>=`, `:=`) are stepped over, except `:=` which IS a declaration and is
## reported as the assignment it is.
static func _assignment_at(line: String) -> int:
	var index: int = 0
	var depth: int = 0
	while index < line.length():
		var character: String = line[index]
		if character == "(" or character == "[":
			depth += 1
		elif character == ")" or character == "]":
			depth -= 1
		elif character == "\"":
			var close_at: int = line.find("\"", index + 1)
			index = line.length() if close_at < 0 else close_at
		elif character == "=" and depth == 0:
			var after: String = line.substr(index + 1, 1)
			var before: String = line.substr(index - 1, 1) if index > 0 else ""
			if after != "=" and not before in ["=", "!", "<", ">", "+", "-", "*", "/", "%"]:
				return index
		index += 1
	return -1


## True when this expression is, or is built from, a path from outside the game: it names a tainted
## name, or it is written under a folder this file watches or unpacks into.
static func _is_outside(expression: String, tainted: Dictionary, folders: PackedStringArray) -> bool:
	# `self.` is this object, so `self.chosen` names the same thing `chosen` does. It is dropped
	# before the reading below, whose dot rule is there to keep SOMEBODY ELSE'S property out.
	var text: String = expression.replace("self.", "")
	for name_text: Variant in tainted.keys():
		if _mentions(text, str(name_text)):
			return true
	for folder: String in folders:
		if _mentions(text, folder) or text.contains(folder):
			return true
		var literal: String = EventForgeFilePlaces.literal_of(folder)
		if not literal.is_empty() and text.contains("\"%s/" % literal.trim_suffix("/")):
			return true
	return false


## True when a piece of text names this identifier as a WHOLE word, so `path` is not found inside
## `file_path` and a folder expression is not found inside a longer one.
##
## A DOT IN FRONT DISQUALIFIES IT. `config.path` is somebody else's property that happens to share a
## name with a tainted one, and reading it as the tainted name is how a check about outside content
## ends up on a line that has none.
static func _mentions(text: String, word: String) -> bool:
	if word.is_empty():
		return false
	var at: int = text.find(word)
	while at >= 0:
		var before: String = text.substr(at - 1, 1) if at > 0 else ""
		var after: String = text.substr(at + word.length(), 1)
		if before != "." and not _is_word_glyph(before) and not _is_word_glyph(after):
			return true
		at = text.find(word, at + word.length())
	return false


static func _is_word_glyph(glyph: String) -> bool:
	if glyph.is_empty():
		return false
	return glyph == "_" or glyph.is_valid_int() or glyph.to_lower() != glyph.to_upper()


## Where a call starts in a line, or -1. A bare `load(` is only a loader when nothing runs into it
## from the left, which is what keeps `preload(` and `Image.load_from_file(` out of the answer.
static func _call_at(line: String, call_text: String) -> int:
	var at: int = line.find(call_text)
	while at >= 0:
		var before: String = line.substr(at - 1, 1) if at > 0 else ""
		if call_text.contains(".") or (not _is_word_glyph(before) and before != "."):
			return at
		at = line.find(call_text, at + call_text.length())
	return -1


## The first argument of an argument list, trimmed.
static func _first_argument(arguments: String) -> String:
	var parts: PackedStringArray = _split_arguments(arguments)
	return "" if parts.is_empty() else parts[0]


## An argument list split on its top-level commas, so a call or a list inside it stays in one piece.
static func _split_arguments(arguments: String) -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var start: int = 0
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
			parts.append(arguments.substr(start, index - start).strip_edges())
			start = index + 1
		index += 1
	var last: String = arguments.substr(start).strip_edges()
	if not last.is_empty():
		parts.append(last)
	return parts
