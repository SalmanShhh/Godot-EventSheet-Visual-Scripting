# Godot EventSheets - the words a pack verb's choice takes are named, and the names are the words.
#
# A verb whose parameter is a dropdown of words (`ease`, `side`, `mode`, `direction`) takes the word as text,
# because shipped rows and saved scenes pass text. A script that calls the verb by hand had to type the word
# and a typo did nothing. Each such pack now holds a constant per word. This walks every shipped pack and
# pins, for each choice parameter a verb declares:
#   - the pack holds a constant whose text is each of the parameter's words
#   - that constant has a note above it (every pack member is described)
#   - a constant a builder named for the parameter reads `PARAMETER_WORD` in capitals, with the word it stands for
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "pack_choice_constants_test"
const PACKS := "res://eventsheet_addons/"


static func run() -> bool:
	var annotation: RegEx = RegEx.create_from_string("^# @ace_param_options\\((\\w+) (.*)\\)$")
	var constant_line: RegEx = RegEx.create_from_string("^const ([A-Z][A-Z0-9_]*)(?:: String)? :?= \"([^\"]*)\"")
	var checked: int = 0
	var failures: PackedStringArray = PackedStringArray()
	for path: String in _pack_scripts(PACKS):
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		var constants: Dictionary = {}
		var noted: Dictionary = {}
		for index: int in range(lines.size()):
			var found: RegExMatch = constant_line.search(lines[index])
			if found != null:
				constants[found.get_string(2)] = found.get_string(1)
				noted[found.get_string(1)] = index > 0 and lines[index - 1].begins_with("##")
		for line: String in lines:
			var parsed: RegExMatch = annotation.search(line)
			if parsed != null:
				checked += 1
				for word: String in _words(parsed.get_string(2)):
					if not constants.has(word):
						failures.append("%s: no constant holds the word '%s' of %s" % [path.get_file(), word, parsed.get_string(1)])
					elif not bool(noted[constants[word]]):
						failures.append("%s: %s has no note above it" % [path.get_file(), constants[word]])
					elif str(constants[word]).begins_with(parsed.get_string(1).to_upper() + "_") and \
							str(constants[word]) != _name(parsed.get_string(1), word):
						failures.append("%s: %s should be %s" % [path.get_file(), constants[word], _name(parsed.get_string(1), word)])
	var rows: Array = [
		["every choice parameter of every pack was looked at", checked > 0, true],
		["every word of every choice parameter has a documented constant", failures, PackedStringArray()],
	]
	return SUPPORT.pins(TEST_NAME, rows)


## The words an `@ace_param_options` list offers: `word=note, word=note` or `word, word`.
static func _words(list: String) -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	for piece: String in list.split(", "):
		var word: String = piece.get_slice("=", 0).strip_edges()
		if _is_word(word) and not words.has(word):
			words.append(word)
	return words


## `PARAMETER_WORD` in capitals, anything that is not a letter or a digit written as one underscore.
static func _name(parameter: String, word: String) -> String:
	var spelled: String = ("%s_%s" % [parameter, word]).to_upper()
	var out: String = ""
	for character: String in spelled:
		out += character if (character >= "A" and character <= "Z") or (character >= "0" and character <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.trim_suffix("_")


static func _pack_scripts(folder: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.ends_with(".gd"):
			found.append(folder.path_join(file_name))
	for child: String in DirAccess.get_directories_at(folder):
		found.append_array(_pack_scripts(folder.path_join(child)))
	found.sort()
	return found


## A choice that is a word. A number or an operator (`>=`) is not named by a constant.
static func _is_word(word: String) -> bool:
	return not word.is_empty() and RegEx.create_from_string("^[A-Za-z][A-Za-z0-9 _-]*$").search(word) != null
