# Godot EventSheets - a function written inside a call, read as the one step that call is.
#
# `enemies.sort_custom(func(a, b) -> bool:` and the lines under it are ONE statement. The call is the
# step and the function handed to it is one of its values - the rule it sorts by, the test it filters
# with, the work it puts off - so the row reads as the call, like any other call, and the function is
# a single chip in it: its parameters and its first line. The lines themselves are one hover away,
# exactly as the file has them. A pure view: the row keeps its code and the file keeps its bytes.
#
# A function handed to `connect` is not read here. It is an event of its own, the signal its trigger,
# and the importer reads it where the connect sits.
@tool
class_name EventSheetInlineFunctions
extends RefCounted


## The statement `code` with the function written inside it folded onto one line, or "" when `code`
## is not one statement handing a function written over several lines to a call.
##
## The function's header has to end its line (`func(a, b) -> bool:`); its body is the lines under it,
## up to the bracket that closes the call it was handed to, or the comma before the call's next
## argument. The arguments written around it are put on one line as they read.
## `func(a, b): a.position.x < b.position.x` is the chip for a one-line body (a `return` says nothing
## the chip does not), and the first statement and `…` for a longer one. `keep_return` keeps the
## word, so the fold is exactly the one-line twin a reading of `sort_custom` or `reduce` knows.
static func folded(code: String, keep_return: bool = false) -> String:
	if not code.contains("\n"):
		return ""
	var opens_at: int = _function_start(code)
	if opens_at < 0:
		return ""
	var params_close: int = _closing(code, opens_at + 4)
	var header_end: int = code.find("\n", opens_at)
	if params_close < 0 or header_end < 0 or params_close > header_end:
		return ""
	var header_tail: String = code.substr(params_close + 1, header_end - params_close - 1).strip_edges()
	if header_tail != ":" and not (header_tail.begins_with("->") and header_tail.ends_with(":")):
		return ""
	var head: String = code.substr(0, opens_at)
	var call_depth: int = _open_brackets(head)
	if call_depth <= 0:
		return ""
	var rest: String = code.substr(header_end + 1)
	var ends_at: int = _function_end(rest, call_depth)
	if ends_at < 0:
		return ""
	var tail: String = rest.substr(ends_at)
	# One function per fold, and nothing after the call: a statement that opens a block of its own
	# (`if items.any(func…):`) is a branch, not a step.
	if tail.contains("func(") or _opens_block(tail, call_depth):
		return ""
	var body: PackedStringArray = statements(rest.substr(0, ends_at))
	if body.is_empty():
		return ""
	var shown: String = body[0]
	if body.size() == 1 and shown.begins_with("return ") and not keep_return:
		shown = shown.substr(7)
	elif body.size() > 1:
		shown += " …"
	var params: String = code.substr(opens_at + 5, params_close - opens_at - 5)
	var lead: String = _one_line(head).strip_edges(false, true)
	if lead.ends_with(","):
		lead += " "
	return "%sfunc(%s): %s%s" % [lead, ", ".join(parameter_names(params)), shown, _one_line(tail)]


## The statements of a function body, each on one line: a statement whose brackets are still open,
## or that ends in `\`, goes on into the line below it. Notes and blank lines are not statements.
static func statements(body: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var current: String = ""
	for line: String in body.split("\n"):
		var stripped: String = line.strip_edges()
		if current.is_empty() and (stripped.is_empty() or stripped.begins_with("#")):
			continue
		current = stripped if current.is_empty() else _one_line("%s\n%s" % [current, stripped])
		if _open_brackets(current) <= 0 and not current.ends_with("\\"):
			found.append(current)
			current = ""
	if not current.is_empty():
		found.append(current)
	return found


## The names a function's parameter list gives, without their types or defaults.
static func parameter_names(params: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for parameter: String in params.split(","):
		var name: String = parameter.strip_edges()
		for separator: String in [":", "="]:
			var at: int = name.find(separator)
			if at >= 0:
				name = name.substr(0, at).strip_edges()
		if not name.is_empty():
			names.append(name)
	return names


## `text` written on one line: each line break and the indent after it become one space, or nothing
## beside a bracket, and a `\` that only continued the line is dropped.
static func _one_line(text: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	var joined: String = lines[0]
	for index: int in range(1, lines.size()):
		var piece: String = lines[index].strip_edges()
		if joined.ends_with("\\"):
			joined = joined.trim_suffix("\\").strip_edges(false, true)
		if piece.is_empty():
			continue
		var tight: bool = joined.ends_with("(") or joined.ends_with("[") or joined.ends_with("{") \
			or piece.begins_with(")") or piece.begins_with("]") or piece.begins_with("}") or joined.is_empty()
		joined += piece if tight else " " + piece
	return joined


## Where the first `func(` outside a string literal or a note opens a function whose header ends its
## line, or -1.
static func _function_start(code: String) -> int:
	var quote: String = ""
	var index: int = 0
	while index < code.length():
		var character: String = code[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote or character == "\n":
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "#":
			var line_end: int = code.find("\n", index)
			if line_end < 0:
				return -1
			index = line_end
			continue
		elif code.substr(index, 5) == "func(" and (index == 0 or not _is_word(code[index - 1])):
			var params_close: int = _closing(code, index + 4)
			var line_end: int = code.find("\n", index)
			if params_close > 0 and line_end > params_close:
				var header_tail: String = code.substr(params_close + 1, line_end - params_close - 1).strip_edges()
				if header_tail == ":" or (header_tail.begins_with("->") and header_tail.ends_with(":")):
					return index
		index += 1
	return -1


## The index of the bracket closing the one opened at `open_at`, or -1. Quote-aware.
static func _closing(text: String, open_at: int) -> int:
	var depth: int = 0
	var quote: String = ""
	var index: int = open_at
	while index < text.length():
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character in ["(", "[", "{"]:
			depth += 1
		elif character in [")", "]", "}"]:
			depth -= 1
			if depth == 0:
				return index
		index += 1
	return -1


## How many brackets `text` leaves open. Quote- and note-aware.
static func _open_brackets(text: String) -> int:
	var depth: int = 0
	var quote: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote or character == "\n":
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "#":
			var line_end: int = text.find("\n", index)
			if line_end < 0:
				break
			index = line_end
			continue
		elif character in ["(", "[", "{"]:
			depth += 1
		elif character in [")", "]", "}"]:
			depth -= 1
		index += 1
	return depth


## Where a function body that sits `call_depth` brackets deep ends in `text`: the bracket that closes
## the call, or the comma before the call's next argument. -1 when neither is there. Quote- and
## note-aware, so a bracket inside a string or after a `#` never ends it.
static func _function_end(text: String, call_depth: int) -> int:
	var depth: int = call_depth
	var quote: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote or character == "\n":
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "#":
			var line_end: int = text.find("\n", index)
			if line_end < 0:
				return -1
			index = line_end
			continue
		elif character in ["(", "[", "{"]:
			depth += 1
		elif character in [")", "]", "}"]:
			depth -= 1
			if depth < call_depth:
				return index
		elif character == "," and depth == call_depth:
			return index
		index += 1
	return -1


## True when `tail` - what follows a function, `call_depth` brackets deep - closes every bracket and
## then opens a block with a `:`.
static func _opens_block(tail: String, call_depth: int) -> bool:
	var depth: int = call_depth
	var quote: String = ""
	for character: String in tail:
		if not quote.is_empty():
			if character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character in ["(", "[", "{"]:
			depth += 1
		elif character in [")", "]", "}"]:
			depth -= 1
		elif character == ":" and depth <= 0:
			return true
	return false


static func _is_word(character: String) -> bool:
	return character == "_" or (character >= "a" and character <= "z") or (character >= "A" and character <= "Z") \
		or (character >= "0" and character <= "9")
