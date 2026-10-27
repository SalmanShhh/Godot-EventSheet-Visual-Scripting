# EventForge - the parameters a written handler never reads, spelled the way Godot asks for them.
#
# A trigger's handler takes the arguments its callback or signal hands over - `delta` every frame,
# the `body` that touched, the `event` that arrived - whether or not the events under it read them.
# Godot reports every one an event does not read as "The parameter is never used", once per handler,
# in every project that runs the sheet; and the cure Godot names is the one used here: a parameter
# the body never reads is written `_delta`. The name the trigger gives it stays the name the sheet
# shows, so the moment an event starts reading it, the next save writes it plain again.
#
# THE COMPILER marks the head line of every handler it writes from a trigger, and once the whole file
# is in place `finish` spells each marked head against the body under it: the body is not known
# when the head is written, and the passes after it (Distance Travelled's per-frame line, the debug
# plumbing) can still add a reader. The mark never reaches the output.
#
# THE LIFTER reads a head back with `normalize`: a parameter written `_name` that the body does not
# read becomes `name` again, which is what the trigger calls it and what the compiler will
# underscore. A head that leaves an unread parameter WITHOUT the underscore is somebody's own
# spelling of their own file, and it is kept exactly as written - that is what the round trip
# promises - so `follows` says whether the compiler may spell this head or must copy it.
#
# "Reads" is a whole-word search of the body's code lines, comments left out. It errs only one way:
# a name that merely appears inside a string still counts as read, which keeps the warning and never
# breaks a line. An underscore is never written onto a name the body does read.
#
# DELIBERATELY NO `class_name`: the compiler and the lifter reach it with a const preload.
@tool
extends RefCounted

## Rides at the end of a head line the compiler wrote for a trigger handler until `finish` spells it.
const MARK: String = "\u001f"

## Words a stripped name may not become: an underscore in front of one of these is the only way to
## have it as a parameter at all, so it is never taken off.
const RESERVED: PackedStringArray = [
	"and", "as", "assert", "await", "break", "breakpoint", "class", "class_name", "const", "continue",
	"elif", "else", "enum", "extends", "false", "for", "func", "if", "in", "is", "match", "namespace",
	"not", "null", "or", "pass", "preload", "return", "self", "signal", "static", "super", "trait",
	"true", "var", "void", "when", "while", "yield", "PI", "TAU", "INF", "NAN",
]

## Column-0 words that open the NEXT top-level declaration, and so end a function's body.
const TOP_LEVEL_OPENERS: PackedStringArray = [
	"func ", "static func ", "static var ", "class ", "class_name ", "var ", "const ", "enum ",
	"signal ", "@", "extends ",
]


## The head line with the mark on, for `finish` to spell later. A head with no parameters has
## nothing to spell and is returned as it is.
static func mark(header: String) -> String:
	if _params_span(header) == Vector2i.ZERO or header.ends_with(MARK):
		return header
	return header + MARK


## Spells every marked head in `lines` against the body under it and takes the marks off. Called on
## the finished file, just before it is joined.
static func finish(lines: PackedStringArray) -> void:
	for index: int in range(lines.size()):
		var line: String = lines[index]
		if not line.ends_with(MARK):
			continue
		var header: String = line.trim_suffix(MARK)
		lines[index] = spell(header, body_after(lines, index))


## The lines of the body under the head at `head_index`: everything up to the next top-level
## declaration. A comment at column 0 does not end it, and is not read anyway.
static func body_after(lines: PackedStringArray, head_index: int) -> PackedStringArray:
	var body: PackedStringArray = PackedStringArray()
	for index: int in range(head_index + 1, lines.size()):
		var line: String = lines[index]
		if _opens_top_level(line):
			break
		body.append(line)
	return body


## `header` with each parameter the body never reads written with a leading underscore. A name that
## already starts with one is left alone.
static func spell(header: String, body: PackedStringArray) -> String:
	var span: Vector2i = _params_span(header)
	if span == Vector2i.ZERO:
		return header
	var code: String = _code_of(body)
	var params: Array = _split_params(header.substr(span.x, span.y - span.x))
	var rewritten: PackedStringArray = PackedStringArray()
	for param: String in params:
		var name: String = _name_of(param)
		if name.is_empty() or name.begins_with("_") or _reads(code, name):
			rewritten.append(param)
		else:
			rewritten.append(_renamed(param, "_" + name))
	return header.substr(0, span.x) + ",".join(rewritten) + header.substr(span.y)


## Reads a written head back. {"header": the head with every `_name` the body does not read written
## `name`, "follows": whether every parameter the body does not read was underscored - true means
## `spell` of the returned head gives back the head as written, so the compiler may spell it.
static func normalize(header: String, body: PackedStringArray) -> Dictionary:
	var span: Vector2i = _params_span(header)
	if span == Vector2i.ZERO:
		return {"header": header, "follows": true}
	var code: String = _code_of(body)
	var follows: bool = true
	var rewritten: PackedStringArray = PackedStringArray()
	for param: String in _split_params(header.substr(span.x, span.y - span.x)):
		var name: String = _name_of(param)
		if name.is_empty() or _reads(code, name):
			rewritten.append(param)
			continue
		var bare: String = name.substr(1)
		if not name.begins_with("_"):
			follows = false
			rewritten.append(param)
		elif bare.is_empty() or bare.begins_with("_") or RESERVED.has(bare) or _reads(code, bare) \
				or not bare.is_valid_ascii_identifier():
			# Kept as written: `__x` and `_class` stay what they are, and so does an `_x` whose plain
			# name the body already reads as something else.
			rewritten.append(param)
		else:
			rewritten.append(_renamed(param, bare))
	var normalized: String = header.substr(0, span.x) + ",".join(rewritten) + header.substr(span.y)
	# The compiler must give back exactly what was written, or the head is copied instead.
	if follows and spell(normalized, body) != header:
		follows = false
	return {"header": normalized if follows else header, "follows": follows}


## The same head with a single leading underscore taken off every parameter name, for telling which
## trigger a head belongs to before its body has been read.
static func strip_underscores(header: String) -> String:
	var span: Vector2i = _params_span(header)
	if span == Vector2i.ZERO:
		return header
	var rewritten: PackedStringArray = PackedStringArray()
	for param: String in _split_params(header.substr(span.x, span.y - span.x)):
		var name: String = _name_of(param)
		var bare: String = name.substr(1)
		if name.begins_with("_") and not bare.is_empty() and not bare.begins_with("_"):
			rewritten.append(_renamed(param, bare))
		else:
			rewritten.append(param)
	return header.substr(0, span.x) + ",".join(rewritten) + header.substr(span.y)


## [start, end) of the text between a `func` head's parentheses, or ZERO when the line is not a head
## or has no parameters.
static func _params_span(header: String) -> Vector2i:
	var stripped: String = header.trim_prefix("static ")
	if not stripped.begins_with("func "):
		return Vector2i.ZERO
	var open: int = header.find("(")
	if open < 0:
		return Vector2i.ZERO
	var depth: int = 0
	for index: int in range(open, header.length()):
		var character: String = header[index]
		if character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
			if depth == 0:
				if header.substr(open + 1, index - open - 1).strip_edges().is_empty():
					return Vector2i.ZERO
				return Vector2i(open + 1, index)
	return Vector2i.ZERO


## The parameter list split at its top-level commas, each piece exactly as written (spaces kept).
static func _split_params(text: String) -> Array:
	var pieces: Array = []
	var depth: int = 0
	var start: int = 0
	var quote: String = ""
	for index: int in range(text.length()):
		var character: String = text[index]
		if not quote.is_empty():
			if character == quote:
				quote = ""
			continue
		if character == "\"" or character == "'":
			quote = character
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif character == "," and depth == 0:
			pieces.append(text.substr(start, index - start))
			start = index + 1
	pieces.append(text.substr(start))
	return pieces


## The parameter's own name: the identifier it opens with.
static func _name_of(param: String) -> String:
	var text: String = param.strip_edges()
	var length: int = 0
	while length < text.length() and (text[length] == "_" or text[length].is_valid_ascii_identifier() \
			or (length > 0 and text[length].is_valid_int())):
		length += 1
	return text.substr(0, length)


## `param` with its name (the identifier it opens with) replaced by `new_name`, every other byte kept.
static func _renamed(param: String, new_name: String) -> String:
	var leading: int = param.length() - param.strip_edges(true, false).length()
	return param.substr(0, leading) + new_name + param.substr(leading + _name_of(param).length())


static func _opens_top_level(line: String) -> bool:
	if line.is_empty() or line.begins_with("\t") or line.begins_with(" ") or line.begins_with("#"):
		return false
	for opener: String in TOP_LEVEL_OPENERS:
		if line.begins_with(opener):
			return true
	return false


## The body's code as one text, comment-only lines left out.
static func _code_of(body: PackedStringArray) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in body:
		if line.strip_edges().begins_with("#"):
			continue
		kept.append(line)
	return "\n".join(kept)


static func _reads(code: String, name: String) -> bool:
	var word: RegEx = RegEx.create_from_string("(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % name)
	return word.search(code) != null
