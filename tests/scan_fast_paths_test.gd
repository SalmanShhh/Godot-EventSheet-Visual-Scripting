# The sentence grammar's three line scanners (where the first top-level operator is, where the first
# call opens, where an argument list splits) answer by a string search when the text has nothing to
# be careful about, and by the character-by-character walk when it has. Every whole-file reading asks
# them of every line, so the search is what keeps a rebuild from costing seconds on a large sheet; this
# pins that it never answers differently from the walk:
#   1. over every code line the showcases and a large pack write, for every operator the readings ask;
#   2. over lines built to be awkward: quotes before, inside and after the operator, brackets that
#      close and ones that do not, an operator made of brackets, an empty one, escapes.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "scan_fast_paths_test"
const SHEETS: Array[String] = [
	"res://demo/showcase/boomer_level/boomer_level.gd",
	"res://demo/showcase/combo_fighter/combo_fighter.gd",
	"res://demo/showcase/quest_fsm/quest_fsm.gd",
	"res://eventsheet_addons/juice/juice_behavior.gd",
]
const OPERATORS: PackedStringArray = [" = ", " := ", " + ", ",", " and ", " or ", ".", " > ", " >= ", " < ", " <= ",
	"==", " if ", " else ", ":", "(", ")", "[", "\"", "'", "", "->", " in "]
const AWKWARD: PackedStringArray = [
	"x = 1", "x = \"a = b\"", "f(a = b) = c", "\"q\" = (1 = 2) = 3", "a = 'it''s' = b", "[1, 2] = [3, 4]",
	"a \\\" = b", "\"unterminated = b", "(unbalanced = b", "a = b)) = c", "{\"k\": 1} = d", "", " ", "=",
	"a, b, c", "f(a, b), c", "\"a, b\", c", "[a, b], {c: d}, e", "a,,b", ",", "a,", ",a", "f(", "f()", "f(a)(b)",
	"say(\"hi (there)\") + y", "'(' + z", "name.method(arg)", "a.b.c(d.e)", "no operators at all",
]


static func run() -> bool:
	var lines: PackedStringArray = PackedStringArray(AWKWARD)
	for path: String in SHEETS:
		if not FileAccess.file_exists(path):
			continue
		var sheet: EventSheetResource = SUPPORT.reopen(FileAccess.get_file_as_string(path), true, path)
		for line: String in EventSheetViewportReadingRows.ordered_code_lines(sheet):
			lines.append(line.strip_edges())
		for line: String in EventSheetViewportReadingRows.behavior_code_lines(sheet):
			lines.append(line.strip_edges())
	var index_misses: PackedStringArray = PackedStringArray()
	var paren_misses: PackedStringArray = PackedStringArray()
	var split_misses: PackedStringArray = PackedStringArray()
	for text: String in lines:
		for operator: String in OPERATORS:
			if EventSheetSentence.top_level_index(text, operator) != EventSheetSentence._top_level_index_walk(text, operator):
				index_misses.append("%s | %s" % [text, operator])
		if EventSheetSentence._first_open_paren(text) != _first_open_paren_walk(text):
			paren_misses.append(text)
		if EventSheetSentence._split_arguments(text) != _split_arguments_walk(text):
			split_misses.append(text)
	print("%s: %d lines checked" % [P, lines.size()])
	return SUPPORT.pins(P, [
		["lines were checked", lines.size() > 200, true],
		["the first top-level operator is where the walk finds it", index_misses, PackedStringArray()],
		["the first call opens where the walk finds it", paren_misses, PackedStringArray()],
		["an argument list splits where the walk splits it", split_misses, PackedStringArray()],
	])


## The walk the search stands in for, as it was written before: the first `(` outside a string.
static func _first_open_paren_walk(text: String) -> int:
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if character == "\"" or character == "'":
			index = EventSheetSentence._string_end(text, index) + 1
			continue
		if character == "(":
			return index
		index += 1
	return -1


## The argument split as it was written before: every comma outside a string and a bracket.
static func _split_arguments_walk(inner: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if inner.strip_edges().is_empty():
		return out
	var depth: int = 0
	var start: int = 0
	var index: int = 0
	while index < inner.length():
		var character: String = inner[index]
		if character == "\"" or character == "'":
			index = EventSheetSentence._string_end(inner, index) + 1
			continue
		if character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif character == "," and depth == 0:
			out.append(inner.substr(start, index - start).strip_edges())
			start = index + 1
		index += 1
	out.append(inner.substr(start).strip_edges())
	return out
