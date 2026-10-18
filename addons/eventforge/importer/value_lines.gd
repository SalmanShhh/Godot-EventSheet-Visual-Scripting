# Godot EventSheets - a value written over several lines, read on one.
#
#	var top_speed: float = (base_speed
#		* boost
#		+ wind)
#
# is one variable row whose value reads `(base_speed * boost + wind)`. The row holds the value on ONE
# line - that is what it shows and what an edit changes - and remembers the lines it was written over
# beside it, as {"one_line": the joined text, "written": the text as the file has it}. Writing the row
# out puts the written lines back for as long as the value still reads as the one line they were
# joined into; once somebody edits it, the edit is written as they typed it.
#
# Joining never changes what the lines say. Inside open brackets, or after a `\`, GDScript reads a
# line break as a space, so the lines are joined with one space - none after an opening bracket or
# before a closing one - and the indentation of each continued line is dropped. Lines that cannot be
# joined that way are refused: a comment inside them (joined, it would swallow the rest), or a
# triple-quoted string, whose line breaks are part of the value.
#
# PURE + STATIC: text in, plain values out.
@tool
class_name EventForgeValueLines
extends RefCounted


## The lines of one statement joined onto one: {"text": the one line, "written": the lines as written,
## "map": where each character of the one line came from in the written text}. {} when they cannot be
## read on one line without changing what they say.
static func join(lines: PackedStringArray) -> Dictionary:
	if lines.size() < 2:
		return {}
	var written: String = "\n".join(lines)
	if written.contains("\"\"\"") or written.contains("'''"):
		return {}
	var text: String = ""
	var map: PackedInt32Array = PackedInt32Array()
	var line_start: int = 0
	for line_index: int in lines.size():
		var line: String = lines[line_index]
		if _has_comment(line):
			return {}
		var first: int = 0
		if line_index > 0:
			while first < line.length() and (line[first] == "\t" or line[first] == " "):
				first += 1
		var last: int = line.length()
		if line_index < lines.size() - 1 and line.ends_with("\\"):
			last -= 1
		while last > first and (line[last - 1] == " " or line[last - 1] == "\t"):
			last -= 1
		if line_index > 0 and last > first:
			var opens: bool = not text.is_empty() and (text[text.length() - 1] in "([{")
			if not opens and not (line[first] in ")]}"):
				text += " "
				map.append(line_start - 1)  # the line break the space stands for
		for column: int in range(first, last):
			text += line[column]
			map.append(line_start + column)
		line_start += line.length() + 1
	return {"text": text, "written": written, "map": map}


## The written text that `part` - a piece of the joined line, found once in it - was joined from, or ""
## when the piece is not in the line exactly once.
static func written_part(joined: Dictionary, part: String) -> String:
	var text: String = str(joined.get("text", ""))
	var at: int = text.find(part)
	if part.is_empty() or at < 0 or text.find(part, at + 1) >= 0:
		return ""
	var map: PackedInt32Array = joined.get("map", PackedInt32Array())
	var start: int = map[at]
	return str(joined.get("written", "")).substr(start, map[at + part.length() - 1] - start + 1)


## The layout one value keeps: {"one_line", "written"} when `part` of the joined line was written over
## several lines, {} when it sits on one line as written (there is nothing to keep).
static func layout_of(joined: Dictionary, part: String) -> Dictionary:
	var written: String = written_part(joined, part)
	if written.is_empty() or written == part:
		return {}
	return {"one_line": part, "written": written}


## What `value` is written as: the lines it was written over while it still reads as the one line they
## were joined into, and the value itself once it has been edited.
static func written(value: String, layout: Dictionary) -> String:
	if layout.is_empty() or value != str(layout.get("one_line", "")):
		return value
	return str(layout.get("written", value))


## A layout after a text edit (a rename, a Replace All) went through both of its texts: the new one,
## or {} when the edited lines no longer join into the edited one line - the edit reached across a
## line break - so the value is written as it now reads, on one line.
static func rewritten(layout: Dictionary, rewrite: Callable) -> Dictionary:
	var one_line: String = str(rewrite.call(str(layout.get("one_line", ""))))
	var written_text: String = str(rewrite.call(str(layout.get("written", ""))))
	var joined: Dictionary = join(written_text.split("\n"))
	if joined.is_empty() or str(joined["text"]) != one_line:
		return {}
	return {"one_line": one_line, "written": written_text}


## How many entries a list or table literal holds (`[a, b, c]` gives 3, a trailing comma allowed), or
## -1 when `value` is not one literal list or table.
static func entry_count(value: String) -> int:
	var text: String = value.strip_edges()
	if text.length() < 2 or not ((text.begins_with("[") and text.ends_with("]")) or (text.begins_with("{") and text.ends_with("}"))):
		return -1
	var depth: int = 0
	var quote: String = ""
	var entries: int = 0
	var since_comma: bool = false
	var index: int = 1
	while index < text.length() - 1:
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\":
				index += 1
			elif character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
			since_comma = true
		elif character in "([{":
			depth += 1
			since_comma = true
		elif character in ")]}":
			depth -= 1
			if depth < 0:
				return -1  # the opening bracket closed early: two literals, not one
		elif character == "," and depth == 0:
			entries += 1
			since_comma = false
		elif character != " " and character != "\t":
			since_comma = true
		index += 1
	return entries + (1 if since_comma else 0)


## Whether a line carries a `#` comment: a `#` outside every string on it.
static func _has_comment(line: String) -> bool:
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
			return true
		index += 1
	return false
