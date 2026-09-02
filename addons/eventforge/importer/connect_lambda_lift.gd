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
# WHAT IS REFUSED, and refusing is not a failure: anything this cannot re-spell stays the statement
# it already is. A lambda that is not the first thing in `_ready` (emission writes connections at
# the top of it, so lifting one from the middle would move it), a body that reads as more than one
# event, an inline form without the ordinary space after the colon. The file still opens; those
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

## One statement, matched: the prefix through `func(…):` (group 1), the emitter (2), the signal (3),
## the lambda's parameters (4), and whatever follows the colon on the same line (5).
const _STATEMENT_PATTERN: String = "^(\\t+(?:(%s)\\.)?([A-Za-z_][A-Za-z0-9_]*)\\.connect\\(func\\(([^)]*)\\):)(.*)$"


## Reads the connect-lambda statement starting at `index`, or {} when that line is not one.
##
## The answer:
##   {"open", "close", "inline", "signal", "source", "params", "body_start", "body_end", "next"}
## `open`/`close` are the kept spelling (emission puts the body between them); `body_start` and
## `body_end` bound the body INSIDE `lines`, already at the indent the body grammar expects, and
## `next` is the line after the whole statement. An inline body has no lines of its own, so
## `body_start == body_end` and the statement text rides in `inline_body` instead.
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
		# The block form: indented body lines, then the closing paren alone on the statement's indent.
		var close: String = "%s)" % "\t".repeat(depth)
		var cursor: int = index + 1
		while cursor < lines.size() and lines[cursor] != close:
			if not lines[cursor].begins_with("\t".repeat(depth + 1)):
				return {}
			cursor += 1
		if cursor >= lines.size() or cursor == index + 1:
			return {}
		parts.merge({"open": open, "close": close, "inline": false, "inline_body": "",
			"body_start": index + 1, "body_end": cursor, "next": cursor + 1})
		return parts
	# The single-line form: one space, one statement, one closing paren. A different spacing is a
	# spelling this cannot reproduce, so it is left alone rather than normalised.
	if not tail.begins_with(" ") or not tail.ends_with(")") or tail.length() < 3:
		return {}
	parts.merge({"open": "%s " % open, "close": ")", "inline": true,
		"inline_body": tail.substr(1, tail.length() - 2),
		"body_start": index + 1, "body_end": index + 1, "next": index + 1})
	return parts


## The kept spelling, without the parts that are read as row values - what a row stores so emission
## can put the body back between them.
static func spelling_of(parts: Dictionary) -> Dictionary:
	return {"open": str(parts.get("open", "")), "close": str(parts.get("close", "")),
		"inline": bool(parts.get("inline", false))}


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
	written.append("%s)" % "\t".repeat(depth) if bool(spelling.get("inline", false)) \
		else str(spelling.get("close", "")))
	return written


## The emitter as a row would name it: `$Timer` and `get_node("UI/Bar")` both mean the node path,
## and a bare identifier means itself. Only ever used for what the row SAYS - the line written back
## is the kept spelling, never this.
static func _plain_source(source: String) -> String:
	if source.begins_with("get_node("):
		return source.trim_prefix("get_node(\"").trim_suffix("\")")
	return source.trim_prefix("$").trim_prefix("%")
