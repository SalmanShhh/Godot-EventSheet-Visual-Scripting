@tool
class_name EventSheetAnnotationLine
extends RefCounted

# An annotation line is a comment that carries one of the plugin's words: `## @ace_category("Combat")`
# (two hashes, which Godot also shows as documentation) or `# @ace_category("Combat")` (one hash, which
# Godot keeps out of every Help page and Inspector tooltip). Every reader accepts both, for ever; new
# lines are written with one hash.
#
# One hash is also what an ordinary comment starts with, so a `#` line is an annotation only when it
# cannot be anything else: a known word, alone on the line or followed by a bracket that closes at the
# end of the line (or is still open, a value going on to the next line), with no prose after it. A
# comment such as `# @ace_hidden is what the old version used` stays a comment. Two hashes keep today's
# loose reading (any `## @ace_` word is an annotation, so a mistyped word is still reported).

## Every word the plugin writes or reads, without its `@ace_` prefix.
const WORDS: Array[String] = [
	"hidden", "deprecated", "succeeded_by", "category", "provider_id", "name", "description", "icon",
	"action", "condition", "expression", "trigger", "looping", "display_template", "codegen_template",
	"param_options", "param_autocomplete", "param_hint", "param", "tags", "expose_all", "featured",
	"family", "family_member", "family_var", "group", "region", "includes", "uses", "requires", "version",
	"author", "help", "lift_example", "test_sheet", "shared_sheet", "inline_capable", "source", "internal",
]

const PREFIX := "@ace_"
const TWO := "##"
const ONE := "#"

static var _known: Dictionary = {}


## Whether `body` (the text after the comment marker and its space, such as `@ace_name("Wave")`) is the
## annotation shape: a known word alone, or a known word and a bracket that closes at the end.
static func is_body(body: String) -> bool:
	if not body.begins_with(PREFIX):
		return false
	var end: int = PREFIX.length()
	while end < body.length() and (body[end] == "_" or (body[end] >= "a" and body[end] <= "z") or (body[end] >= "0" and body[end] <= "9")):
		end += 1
	if not _words().has(body.substr(PREFIX.length(), end - PREFIX.length())):
		return false
	var rest: String = body.substr(end)
	if rest.strip_edges().is_empty():
		return true
	if not rest.begins_with("("):
		return false
	var depth: int = 0
	var in_string: bool = false
	var index: int = 0
	while index < rest.length():
		var character: String = rest[index]
		if in_string:
			if character == "\\":
				index += 1
			elif character == "\"":
				in_string = false
		elif character == "\"":
			in_string = true
		elif character == "(":
			depth += 1
		elif character == ")":
			depth -= 1
			if depth == 0:
				return rest.substr(index + 1).strip_edges().is_empty()
		index += 1
	return true


static func _words() -> Dictionary:
	if _known.is_empty():
		for word: String in WORDS:
			_known[word] = true
	return _known


## The marker a line carries: "##" for `## @ace_`, "#" for a one-hash line that is an annotation, "" for
## every other line (indentation is ignored).
static func marker_of(line: String) -> String:
	var stripped: String = line.strip_edges()
	if stripped.begins_with("## " + PREFIX):
		return TWO
	if stripped.begins_with("# " + PREFIX) and is_body(stripped.substr(2)):
		return ONE
	return ""


## The text of an annotation line without its marker (`@ace_name("Wave")`), "" for any other line.
static func body_of(line: String) -> String:
	var marker: String = marker_of(line)
	if marker.is_empty():
		return ""
	return line.strip_edges().substr(marker.length() + 1)


static func is_annotation(line: String) -> bool:
	return not marker_of(line).is_empty()


## Whether this sheet's annotation lines are one-hash lines: a sheet built from rows, and a file that was
## read with one hash (or with none), are; a file that was read with two keeps two.
static func intends_hash(sheet: EventSheetResource) -> bool:
	if sheet == null:
		return true
	var spelling: String = sheet.annotation_spelling
	return spelling == ONE or (spelling.is_empty() and sheet.external_source_path.is_empty())


## Whether a compile of this sheet should turn its two-hash annotation lines into one-hash lines now. The
## importer asks for the two-hash form while it reads (see annotation_gate_canonical).
static func writes_hash(sheet: EventSheetResource) -> bool:
	return intends_hash(sheet) and not (sheet != null and sheet.annotation_gate_canonical)


## The line with a one-hash annotation written as two, so code that reads `## @ace_` reads it unchanged.
## Every other line comes back as it is.
static func canonical(line: String) -> String:
	if marker_of(line) != ONE:
		return line
	var at: int = line.find("# " + PREFIX)
	return line.substr(0, at) + "#" + line.substr(at)


## The line with a two-hash annotation written as one. Only a line that is an annotation in the one-hash
## spelling too (a known word, a closed bracket) is changed; a mistyped word keeps its two hashes.
static func hashed(line: String) -> String:
	var stripped: String = line.strip_edges()
	if not stripped.begins_with("## " + PREFIX) or not is_body(stripped.substr(3)):
		return line
	var at: int = line.find("## " + PREFIX)
	return line.substr(0, at) + line.substr(at + 1)


## The lines with every two-hash annotation written as one, in place (see `hashed`): the lines of a code block
## as a one-hash file spells them.
static func hashed_lines(lines: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for line: String in lines:
		out.append(hashed(line))
	return out


## The source with every one-hash annotation written as two. Text without one comes back untouched.
static func canonical_text(source: String) -> String:
	if not source.contains("# " + PREFIX):
		return source
	var lines: PackedStringArray = source.split("\n")
	for index: int in range(lines.size()):
		lines[index] = canonical(lines[index])
	return "\n".join(lines)


## The text with every two-hash annotation written as one. With `doc_last`, a one-hash annotation that follows
## the `##` description lines of the same member moves above them: Godot reads a member's documentation from the
## `##` lines directly above it, and one ordinary comment line between the two drops the documentation, so the
## words go first and the description stays next to the member.
static func hashed_text(text: String, doc_last: bool = false) -> String:
	if not text.contains("## " + PREFIX):
		return text
	var lines: PackedStringArray = text.split("\n")
	for index: int in range(lines.size()):
		lines[index] = hashed(lines[index])
	if doc_last:
		lines = _annotations_before_docs(lines)
	return "\n".join(lines)


## Within each run of comment lines that sits directly above a declaration, the annotation lines that come
## after a description line are moved to just before the first description line, in their own order. A run
## with nothing out of order, or one that a blank line separates from what follows (a class description and
## the words under it), is untouched.
static func _annotations_before_docs(lines: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var index: int = 0
	while index < lines.size():
		if not lines[index].strip_edges().begins_with("#"):
			out.append(lines[index])
			index += 1
			continue
		var end: int = index
		while end < lines.size() and lines[end].strip_edges().begins_with("#"):
			end += 1
		var run: PackedStringArray = lines.slice(index, end)
		var above_a_declaration: bool = end < lines.size() and not lines[end].strip_edges().is_empty()
		var first_doc: int = -1
		var moved: bool = false
		for at: int in range(run.size()):
			var stripped: String = run[at].strip_edges()
			if stripped.begins_with("##") and not stripped.begins_with("## " + PREFIX):
				if first_doc < 0:
					first_doc = at
			elif first_doc >= 0 and stripped.begins_with("# " + PREFIX) and is_body(stripped.substr(2)):
				moved = true
		if not moved or not above_a_declaration:
			out.append_array(run)
		else:
			var annotations: PackedStringArray = PackedStringArray()
			var rest: PackedStringArray = PackedStringArray()
			for at: int in range(run.size()):
				var stripped: String = run[at].strip_edges()
				if at >= first_doc and stripped.begins_with("# " + PREFIX) and is_body(stripped.substr(2)):
					annotations.append(run[at])
				else:
					rest.append(run[at])
			out.append_array(rest.slice(0, first_doc))
			out.append_array(annotations)
			out.append_array(rest.slice(first_doc))
		index = end
	return out


## How a file spells its annotations: "##", "#", "mixed" when it has both, "none" when it has neither. A
## two-hash line counts only when it is an annotation in the one-hash spelling too, so a mistyped word (which
## keeps its two hashes whatever the file does) never makes a one-hash file look mixed.
static func spelling_of(source: String) -> String:
	if not source.contains(PREFIX):
		return "none"
	var two: bool = false
	var one: bool = false
	for line: String in source.split("\n"):
		var marker: String = marker_of(line)
		if marker == TWO and is_body(line.strip_edges().substr(3)):
			two = true
		elif marker == ONE:
			one = true
	if two and one:
		return "mixed"
	if two:
		return TWO
	if one:
		return ONE
	return "none"
