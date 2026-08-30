# Godot EventSheets - THE VERBATIM LEDGER: what the lines nothing claims actually LOOK like.
#
# A reading already says, line by line, which layer claimed it, and the plainest of those layers is
# "stays code" - general purpose includes the right to just be code, counted out loud. But a list of
# stays-code lines is a list, and a list is not a decision. What a person deciding where the next
# curated table should go needs is the SHAPE: the same statement said a hundred times across a
# project is one table entry waiting to be written, and a statement said once is nobody's table.
#
# THE SHAPE IS THE STATEMENT WITH THE AUTHOR'S OWN WORDS TAKEN OUT. Identifiers, numbers, strings and
# node paths are what makes one line different from the next; the punctuation and the language's own
# keywords are what makes them the same kind of line. So:
#
#     pop.chain().tween_callback(queue_free)        ->  name.name().name(name)
#     enum State {CLOSED, OPENING, OPEN, LOCKED}    ->  enum name{name,name,name,name}
#     velocity.y += JUMP_VELOCITY                   ->  name.name+=name
#     if not is_on_floor():                         ->  if not name():
#
# WHY THIS IS NOT A NEW ANALYSIS PASS. It rides the reading that already happens: the expensive half
# (import, compile, per-line claim) is EventSheetLiftReading, and this only ever looks at the text of
# the lines that reading already handed back as `code`. One left-to-right character scan per line, no
# regex, no backtracking, no second opinion about what a row is.
#
# THE NAME ATOM IS THE LIFTER'S OWN. What counts as an identifier here is the same definition every
# recogniser family matches with (EventForgeLiftGrammar.IDENTIFIER: a letter or underscore, then
# letters, digits and underscores). The scanner spells it as a character test rather than a regex
# because it runs per character rather than per line, and the suite pins the two against each other
# on a table of samples so the day one widens the other cannot quietly stay behind.
#
# WHAT IS KEPT VERBATIM, AND WHY:
#   - KEYWORDS. `if`, `and`, `func`, `enum`, `true`. These are the language's words, not the author's,
#     and blanking them would merge `if name:` with `while name:` - two different kinds of line.
#   - ANNOTATIONS. `@export`, `@rpc`. An annotation name comes from a fixed engine vocabulary, so it
#     tells a reader which kind of line this is exactly the way a keyword does.
#   - PUNCTUATION AND OPERATORS, character by character. `+=` needs no table: it falls out of `+`
#     followed by `=`.
#
# WHITESPACE IS DROPPED, and a single space is put back only between two word-like tokens (which is
# the only place it changes the meaning: `if not name` must not become `ifnotname`). So a project
# that spells `x=1` and a project that spells `x = 1` land in the same group instead of two, and the
# shape of a line does not depend on how its author felt about spaces.
#
# COMMENTS ARE NOT SHAPES. A comment inside a run of code is a note, not a statement, so it shapes to
# "" and is counted apart rather than being blanked into a shape nobody could act on.
#
# DETERMINISTIC ON EVERY MACHINE: a pure function of one line's characters, and a ranking that breaks
# ties on the shape's own text rather than on the order files came back from a directory walk.
@tool
class_name EventSheetReadingShapes
extends RefCounted

## The blanks. Lowercase words rather than symbols, because the shape is meant to be READ - in a
## Doctor line, in a tool's output, in a commit message - and `name.name().name(name)` says what it
## is where `#.#().#(#)` would have to be explained every time.
const BLANK_NAME: String = "name"
const BLANK_NUMBER: String = "number"
const BLANK_TEXT: String = "text"
const BLANK_NODE: String = "node"

## The language's own words, kept verbatim. GDScript's reserved words plus the three literal words
## (`true`, `false`, `null`), which are the language's spelling of a value rather than the author's
## name for one. Sorted, so a reader can find one and a diff that adds one is one line.
const KEYWORDS: PackedStringArray = ["and", "as", "assert", "await", "break", "breakpoint", "class",
	"class_name", "const", "continue", "elif", "else", "enum", "extends", "false", "for", "func",
	"if", "in", "is", "match", "not", "null", "or", "pass", "preload", "return", "self", "signal",
	"static", "super", "true", "var", "void", "when", "while"]


## The shape of one statement: its own text with the author's words blanked. "" when the line holds
## no statement at all (a blank line, or a comment inside a run of code).
static func shape_of(statement: String) -> String:
	var text: String = _without_comment(statement).strip_edges()
	if text.is_empty():
		return ""
	var shape: String = ""
	var index: int = 0
	# Two different questions, and conflating them is the classic `%` bug: `word_like` decides
	# whether a space has to be put back, `after_value` decides whether a `%` is a unique-name node
	# or a modulo sign.
	var word_like: bool = false
	var after_value: bool = false
	while index < text.length():
		var character: String = text[index]
		if character == " " or character == "\t":
			index += 1
			continue
		var token: String = ""
		var token_is_word: bool = true
		var token_is_value: bool = true
		if character == "\"" or character == "'":
			index = _string_end(text, index)
			token = BLANK_TEXT
		elif character == "$" or (character == "%" and not after_value
				and _opens_a_node_path(text, index + 1)):
			index += 1
			# `$"Node Name"` is one node written with a quoted path, so the quotes are followed to
			# their end rather than being read as a string sitting next to a `$`.
			if index < text.length() and (text[index] == "\"" or text[index] == "'"):
				index = _string_end(text, index)
			else:
				while index < text.length() and _is_path_character(text[index]):
					index += 1
			token = BLANK_NODE
		elif character == "@":
			var annotation_start: int = index
			index += 1
			while index < text.length() and _is_name_character(text[index]):
				index += 1
			token = text.substr(annotation_start, index - annotation_start)
		elif _is_digit(character):
			var number_start: int = index
			index = _number_end(text, index)
			token = BLANK_NUMBER
			# The digits themselves are gone; the substr is taken only so an unterminated scan can
			# never hand back an empty token and stall the loop.
			if index <= number_start:
				index = number_start + 1
		elif _is_name_character(character):
			var name_start: int = index
			while index < text.length() and _is_name_character(text[index]):
				index += 1
			var word: String = text.substr(name_start, index - name_start)
			token = word if KEYWORDS.has(word) else BLANK_NAME
			# A keyword is a word for spacing, but it is not a VALUE: `not %Unique` has to keep
			# reading the `%` as a node.
			token_is_value = not KEYWORDS.has(word)
		else:
			index += 1
			token = character
			token_is_word = false
			# A closing bracket ends a value, so `f(a) % 2` is modulo. Every other punctuation mark
			# leaves the next `%` in unary position, where it is a node path.
			token_is_value = character == ")" or character == "]"
		if token_is_word and word_like:
			shape += " "
		shape += token
		word_like = token_is_word
		after_value = token_is_value
	return shape


## Every stays-code line of ONE reading, as {"path", "number", "text", "shape"} in file order.
## `reading` is what EventSheetLiftReading.read handed back; nothing is re-read or re-parsed here.
static func stays_code_lines(reading: Dictionary, path: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry: Variant in reading.get("lines", []) as Array:
		var line: Dictionary = entry as Dictionary
		if str(line.get("layer", "")) != EventSheetLiftReading.LAYER_CODE:
			continue
		var text: String = str(line.get("text", ""))
		found.append({"path": path, "number": int(line.get("number", 0)), "text": text,
			"shape": shape_of(text)})
	return found


## The ranked census over a flat list of stays-code lines:
##   {"lines", "notes", "shapes", "one_offs"}
##
## `shapes` holds the shapes said MORE THAN ONCE, worst first - count descending, then the shape's
## own text ascending, so the ranking is the same on every machine whatever order the files arrived
## in. Each carries {"shape", "count", "lines"} with its lines in the order they were handed in.
##
## `one_offs` is the honest tail: lines whose shape nothing else in the corpus repeats. They are kept
## as lines so a caller can count them and name a few, and they are deliberately NOT ranked - a list
## of two hundred groups of one is noise wearing a ledger's clothes.
##
## `notes` counts the stays-code lines that hold no statement (comments inside a run of code). They
## are not shapes and they are not one-offs; they are said apart so the three numbers add up to the
## line count a reader can check against the layer tally.
static func census(lines: Array) -> Dictionary:
	var by_shape: Dictionary = {}
	var order: PackedStringArray = PackedStringArray()
	var notes: int = 0
	for entry: Variant in lines:
		var line: Dictionary = entry as Dictionary
		var shape: String = str(line.get("shape", ""))
		if shape.is_empty():
			notes += 1
			continue
		if not by_shape.has(shape):
			by_shape[shape] = [] as Array
			order.append(shape)
		(by_shape[shape] as Array).append(line)
	var repeated: Array[Dictionary] = []
	var one_offs: Array[Dictionary] = []
	for shape: String in order:
		var held: Array = by_shape[shape] as Array
		if held.size() == 1:
			one_offs.append(held[0] as Dictionary)
			continue
		repeated.append({"shape": shape, "count": held.size(), "lines": held})
	repeated.sort_custom(_ranked)
	return {"lines": lines.size(), "notes": notes, "shapes": repeated, "one_offs": one_offs}


## Commonest first, and ties broken on the shape's own text. Never on discovery order: a directory
## walk hands files back in filesystem order (near-alphabetical on NTFS, hash order on ext4), and a
## ledger whose rows swap places between machines is a ledger nobody can pin.
static func _ranked(left: Dictionary, right: Dictionary) -> bool:
	var left_count: int = int(left.get("count", 0))
	var right_count: int = int(right.get("count", 0))
	if left_count != right_count:
		return left_count > right_count
	return str(left.get("shape", "")) < str(right.get("shape", ""))


# ── the scan ────────────────────────────────────────────────────────────────────


## The line with its trailing comment taken off. Asked before anything else, and it has to know about
## strings: `print("# not a comment")` keeps its whole argument.
static func _without_comment(text: String) -> String:
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if character == "\"" or character == "'":
			index = _string_end(text, index)
			continue
		if character == "#":
			return text.substr(0, index)
		index += 1
	return text


## One past the end of the string literal starting at `start`. An UNTERMINATED literal (the opening
## line of a triple-quoted block, which arrives here on its own) ends at the end of the line, which
## is the honest answer: there is no more of it on this line.
static func _string_end(text: String, start: int) -> int:
	var quote: String = text[start]
	var triple: String = quote + quote + quote
	if text.substr(start, 3) == triple:
		var closing: int = text.find(triple, start + 3)
		return text.length() if closing < 0 else closing + 3
	var index: int = start + 1
	while index < text.length():
		if text[index] == "\\":
			index += 2
			continue
		if text[index] == quote:
			return index + 1
		index += 1
	return text.length()


## One past the end of the number starting at `start`: an integer, a float, an exponent, a hex or
## binary literal, and the digit separators Godot allows inside all of them.
static func _number_end(text: String, start: int) -> int:
	var index: int = start
	if text.substr(start, 2).to_lower() == "0x" or text.substr(start, 2).to_lower() == "0b":
		index = start + 2
		while index < text.length() and _is_name_character(text[index]):
			index += 1
		return index
	while index < text.length() and (_is_digit(text[index]) or text[index] == "_"):
		index += 1
	# A dot is part of the number only when a digit follows it, so `2.0` is one number while the dot
	# in `get_child_count()` never swallows what comes after it.
	if index < text.length() and text[index] == "." and _is_digit_at(text, index + 1):
		index += 1
		while index < text.length() and (_is_digit(text[index]) or text[index] == "_"):
			index += 1
	if index < text.length() and (text[index] == "e" or text[index] == "E"):
		var exponent: int = index + 1
		if exponent < text.length() and (text[exponent] == "+" or text[exponent] == "-"):
			exponent += 1
		if _is_digit_at(text, exponent):
			index = exponent
			while index < text.length() and _is_digit(text[index]):
				index += 1
	return index


## The lifter's own idea of what may appear inside a name (EventForgeLiftGrammar.IDENTIFIER's tail),
## spelled as a character test because this runs per character.
static func _is_name_character(character: String) -> bool:
	return character == "_" or (character >= "a" and character <= "z") \
		or (character >= "A" and character <= "Z") or _is_digit(character)


## Whether a unique-name node path can start here: a name, or the quote of a written-out path. The
## test that tells `%Player` from `count % 2` when a `%` turns up in unary position.
static func _opens_a_node_path(text: String, index: int) -> bool:
	if index < 0 or index >= text.length():
		return false
	var character: String = text[index]
	return character == "_" or character == "\"" or character == "'" \
		or (character >= "a" and character <= "z") or (character >= "A" and character <= "Z")


## What may appear inside a node path after the `$` or `%`: a name, plus the separator a scene path
## is written with. `$Hero/SpringBehavior` is one node, not a name divided by a name.
static func _is_path_character(character: String) -> bool:
	return _is_name_character(character) or character == "/"


static func _is_digit(character: String) -> bool:
	return character >= "0" and character <= "9"


static func _is_digit_at(text: String, index: int) -> bool:
	return index >= 0 and index < text.length() and _is_digit(text[index])
