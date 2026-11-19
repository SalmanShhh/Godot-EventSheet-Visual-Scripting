# Godot EventSheets - how a comment's own brackets are read.
# A leaf with no class_name, loaded by path the first time a comment line holds a bracket, so the first open does not
# compile it. A comment is the user's own words: only a tag CLOSED later in the text is markup, so `items[i]`, `[0, 1]`,
# a lone `[url]` and an unclosed `[color=red]` are drawn as typed, and a closing tag with nothing open is text too.
@tool
extends RefCounted


## True when the tag read from `raw_text` (its bracket closing at `close_index`) is markup under that rule.
static func is_paired_tag(tag: String, raw_text: String, close_index: int, bold_depth: int, italic_depth: int, colors_open: int) -> bool:
	var after: String = raw_text.substr(close_index + 1).to_lower()
	match tag:
		"b":
			return after.contains("[/b]")
		"i":
			return after.contains("[/i]")
		"/b":
			return bold_depth > 0
		"/i":
			return italic_depth > 0
		"/color":
			return colors_open > 0
	return tag.begins_with("color=") and after.contains("[/color]")


## A comment line as italic segments (Reading Mode's caption look), read by the same rule: wrapping the line in
## italic tags would pair with an `items[i]` inside it.
static func italic_segments(line: String, color: Color) -> Array[Dictionary]:
	var segments: Array[Dictionary] = EventSheetBBCodeLite.parse(line, color, true)
	for segment: Dictionary in segments:
		segment["italic"] = true
	return segments
