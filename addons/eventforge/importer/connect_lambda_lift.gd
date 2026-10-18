# Godot EventSheets - `signal.connect(func(): …)` read as an event, and written back as it was.
#
# The second measured lift wall. A handler written as a named function already opens as a trigger
# event: `_ready` wires it, the lift reads the connect line, and the function becomes the event's
# rows. A handler written as a LAMBDA in the connect call - which is how most people wire a button
# or a timer once they know they can - had no name to find, so the whole `_ready` stayed code.
#
# WHAT IS READ AND WHAT IS KEPT. The signal, the emitter and the lambda's own parameters are read,
# because they are what the event row says. Everything else is KEPT VERBATIM - the receiver
# spelling (`$Timer`, `%Health`, `get_node("UI/Bar")`, a bare member), the author's spacing, the
# single-line-versus-block shape - so re-emitting is exactly substituting the body back in. That is
# the whole reason this can be gated byte-for-byte rather than approximately.
#
# WHERE IT SITS. A lambda at the top of `_ready` becomes an event of its own beside On ready, because
# emission writes connections at the top of `_ready`. One anywhere else - lower in `_ready`, or in any
# other function - is the same event read IN PLACE: nested at the statement's own position, so it is
# written back exactly there and the file keeps its order.
#
# WHAT IS REFUSED, and refusing is not a failure: anything this cannot re-spell stays the statement
# it already is. A body that cannot be read, an inline form without the ordinary space after the
# colon, a blank line inside the body, a call with more after the lambda. The file still opens; those
# lines simply stay code, which is what they were.
#
# WHY THIS IS NOT A LIFT-TABLE ENTRY, now that the table takes a run of statements as well as one.
# A table entry claims a fixed list of whole statements and hands back a row with a template on it.
# This claims a statement and then a REGION: the body between the connect line and its closing paren,
# bounded by indentation, whose lines are not this family's to read at all - they are lifted as the
# event's own rows, and this hands back the two halves of the spelling to put back around them
# afterwards (see emitted_lines, which the compiler calls on the way out). There is no row here, no
# template, and no statement count; a pattern list has nothing to say about any of it.
#
# PURE + STATIC: text in, plain values out. It never sees a sheet, a row or an editor.
@tool
class_name EventForgeConnectLambdaLift
extends RefCounted

## The receiver spellings a connect line may name, all kept verbatim. The same set the named-handler
## connect reader admits, for the same reason: widening it to any call chain would start claiming
## lines this reading has no words for.
const _SOURCE_PATTERN: String = "get_node\\(\"[^\"]+\"\\)|\\$[A-Za-z0-9_/]+|%[A-Za-z0-9_]+|[A-Za-z_][A-Za-z0-9_]*"

## One statement, matched: the prefix through `func(…):` or `func(…) -> Type:` (group 1), the emitter
## (2), the signal (3), the lambda's parameters (4), and whatever follows the colon on the same line (5).
const _STATEMENT_PATTERN: String = "^(\\t+(?:(%s)\\.)?([A-Za-z_][A-Za-z0-9_]*)\\.connect\\(func\\(([^)]*)\\)(?: -> [A-Za-z_][A-Za-z0-9_.\\[\\]]*)?:)(.*)$"


## Reads the connect-lambda statement starting at `index`, or {} when that line is not one.
##
## The answer:
##   {"open", "close", "inline", "signal", "source", "params", "body_start", "body_end", "next"}
## `open`/`close` are the kept spelling (emission puts the body between them); `body_start` and
## `body_end` bound the body INSIDE `lines`, already at the indent the body grammar expects, and
## `next` is the line after the whole statement. An inline body has no lines of its own, so
## `body_start == body_end` and the statement text rides in `inline_body` instead. A `glued` close is
## the last body line's own final `)`, which body_lines takes off before the body is read.
static func match_statement(lines: PackedStringArray, index: int) -> Dictionary:
	if index < 0 or index >= lines.size():
		return {}
	var statement: RegEx = RegEx.create_from_string(_STATEMENT_PATTERN % _SOURCE_PATTERN)
	var found: RegExMatch = statement.search(lines[index])
	if found == null:
		return {}
	var open: String = found.get_string(1)
	var depth: int = open.length() - open.lstrip("\t").length()
	var parts: Dictionary = {
		"signal": found.get_string(3),
		"source": _plain_source(found.get_string(2)),
		"params": found.get_string(4),
		"depth": depth,
	}
	var tail: String = found.get_string(5)
	if tail.is_empty():
		# The block form: indented body lines, then the paren that closes `connect(` - alone on the
		# statement's indent, or glued to the end of the last body line, which is how most hand-written
		# connects spell it. The brackets are counted to tell the two apart, so a `)` that closes
		# something inside the body is never taken for it.
		var close: String = "%s)" % "\t".repeat(depth)
		var open_brackets: int = 1
		var cursor: int = index + 1
		while cursor < lines.size() and lines[cursor] != close:
			if not lines[cursor].begins_with("\t".repeat(depth + 1)):
				return {}
			open_brackets += _bracket_delta(lines[cursor])
			if open_brackets <= 0:
				break
			cursor += 1
		if cursor >= lines.size() or cursor == index + 1:
			return {}
		if lines[cursor] == close:
			if open_brackets != 1:
				return {}
			parts.merge({"open": open, "close": close, "inline": false, "glued": false, "inline_body": "",
				"body_start": index + 1, "body_end": cursor, "next": cursor + 1})
			return parts
		# Glued: this line ends the call, so it has to end in that paren and nothing after it.
		if open_brackets != 0 or not lines[cursor].ends_with(")"):
			return {}
		parts.merge({"open": open, "close": ")", "inline": false, "glued": true, "inline_body": "",
			"body_start": index + 1, "body_end": cursor + 1, "next": cursor + 1})
		return parts
	# The single-line form: one space, one statement, one closing paren. A different spacing is a
	# spelling this cannot reproduce, so it is left alone rather than normalised.
	if not tail.begins_with(" ") or not tail.ends_with(")") or tail.length() < 3:
		return {}
	parts.merge({"open": "%s " % open, "close": ")", "inline": true, "glued": false,
		"inline_body": tail.substr(1, tail.length() - 2),
		"body_start": index + 1, "body_end": index + 1, "next": index + 1})
	return parts


## The kept spelling, without the parts that are read as row values - what a row stores so emission
## can put the body back between them.
static func spelling_of(parts: Dictionary) -> Dictionary:
	return {"open": str(parts.get("open", "")), "close": str(parts.get("close", "")),
		"inline": bool(parts.get("inline", false)), "glued": bool(parts.get("glued", false))}


## The body of a block-form statement as the body grammar reads it: the lines between the open and
## the close, with a glued close taken off the last of them.
static func body_lines(lines: PackedStringArray, parts: Dictionary) -> PackedStringArray:
	var body: PackedStringArray = lines.slice(int(parts.get("body_start", 0)), int(parts.get("body_end", 0)))
	if bool(parts.get("glued", false)) and not body.is_empty():
		body[body.size() - 1] = body[body.size() - 1].trim_suffix(")")
	return body


## The statement written back out: the kept spelling with `body_lines` (the event's own emitted body,
## at the indent the source used) substituted in.
##
## An inline statement whose body no longer fits on one line - which is what editing the row can do -
## is written as the block form instead. Rewriting the shape is the honest answer there: the two
## spellings mean the same thing, and the alternative is dropping the wiring on the floor.
static func emitted_lines(spelling: Dictionary, body_lines: PackedStringArray) -> PackedStringArray:
	var open: String = str(spelling.get("open", ""))
	var depth: int = open.length() - open.lstrip("\t").length()
	var body: PackedStringArray = body_lines
	if body.is_empty():
		body = PackedStringArray(["%spass" % "\t".repeat(depth + 1)])
	var written: PackedStringArray = PackedStringArray()
	if bool(spelling.get("inline", false)) and body.size() == 1:
		written.append("%s%s%s" % [open, body[0].strip_edges(), str(spelling.get("close", ""))])
		return written
	written.append(open.rstrip(" ") if bool(spelling.get("inline", false)) else open)
	written.append_array(body)
	if bool(spelling.get("glued", false)):
		written[written.size() - 1] += ")"
		return written
	written.append("%s)" % "\t".repeat(depth) if bool(spelling.get("inline", false)) \
		else str(spelling.get("close", "")))
	return written


## How many brackets `line` opens, less how many it closes, outside string literals and notes.
static func _bracket_delta(line: String) -> int:
	var delta: int = 0
	var quote: String = ""
	var index: int = 0
	while index < line.length():
		var character: String = line[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "#":
			break
		elif character in ["(", "[", "{"]:
			delta += 1
		elif character in [")", "]", "}"]:
			delta -= 1
		index += 1
	return delta


## The emitter as a row would name it: `$Timer` and `get_node("UI/Bar")` both mean the node path,
## and a bare identifier means itself. Only ever used for what the row SAYS - the line written back
## is the kept spelling, never this.
static func _plain_source(source: String) -> String:
	if source.begins_with("get_node("):
		return source.trim_prefix("get_node(\"").trim_suffix("\")")
	return source.trim_prefix("$").trim_prefix("%")
