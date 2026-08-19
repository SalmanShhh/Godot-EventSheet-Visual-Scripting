# Godot EventSheets - a multi-line table or list used as a VALUE, read as one row of named chips.
#
# THE SHAPE THIS IS ABOUT. A statement whose last thing on the line is an opening `{` or `[` carries
# its value over the lines that follow:
#
#	return {
#		"row_index": _editing_row_index,
#		"kind": kind
#	}
#
# The importer splits that into one verbatim row per LINE, which is honest storage and unreadable
# reading: the head says half a sentence, each entry line says nothing on its own, and the closing
# bracket is a row that says nothing at all. Measured over the plugin's own source, entries and their
# orphan closers were the single largest thing still rendering as bare code.
#
# So a run of sibling rows that together form exactly one such statement reads as ONE row: the
# statement's own sentence, the word `table` or `list` where the literal sat, and each entry as a
# named chip. The rows are UNTOUCHED - this is a view, exactly like the tween-chain and continuation
# collapses - so the file still holds every line and the byte round-trip cannot move.
#
# The declaration form of the same shape (`var waves := {` at the head of a body) is already held as
# structure by CollectionDeclRow; this is the other half, for a literal handed to `return`, to a
# signal, to `append`, or to any other call.
@tool
class_name EventSheetValueLiteralRows
extends RefCounted

## Where the literal sat in the flattened statement. Deliberately not an identifier and not a
## bracket: the sentence grammar carries it through as an opaque value, and nothing in the spelling
## lens can respell it into something the row builder would fail to find again.
const LITERAL_TOKEN := "⟦⟧"

## How many chips a folded row shows before it says how many are left. Three is the count the
## declaration rows already fold at, and a row that shows more stops being one line.
const FOLD_AT := 3


## The literal runs in one row list, as {"consumed": {index: true}, "leads": {index: info}} - the
## same shape every other multi-row collapse in the row builder reports, so the action loop skips a
## consumed row without advancing its line index and draws a lead once.
##
## `info` carries {statement, open, entries, indices, source} where `statement` is the whole run on
## one line with the literal replaced by LITERAL_TOKEN, `open` is "{" or "[", and `entries` is the
## parsed entry list (see parse_entries).
static func groups(actions: Array) -> Dictionary:
	var consumed: Dictionary = {}
	var leads: Dictionary = {}
	var index: int = 0
	while index < actions.size():
		var found: Dictionary = _run_at(actions, index)
		if found.is_empty():
			index += 1
			continue
		leads[index] = found
		for consumed_index: int in (found.get("indices", PackedInt32Array()) as PackedInt32Array):
			if consumed_index != index:
				consumed[consumed_index] = true
		index = int(found.get("end", index + 1))
	return {"consumed": consumed, "leads": leads}


## The run that STARTS at `start`, or {} when the row there does not open a multi-line literal.
##
## Every row of the run must be a single-line, enabled RawCodeRow, the brackets must balance exactly
## on the last row of the run, and that last row must carry nothing but closing brackets - the
## orphan `}` / `})` / `],` line the reader sees today. Anything else is left alone: a run this
## cannot account for keeps the per-line rows it already had, which is never wrong, only verbose.
static func _run_at(actions: Array, start: int) -> Dictionary:
	var head: RawCodeRow = actions[start] as RawCodeRow
	if head == null or not head.enabled or head.code.contains("\n"):
		return {}
	var head_text: String = head.code.strip_edges()
	if not (head_text.ends_with("{") or head_text.ends_with("[")):
		return {}
	var depth: int = bracket_delta(head.code)
	if depth <= 0:
		return {}
	var lines: PackedStringArray = PackedStringArray()
	var rows: PackedInt32Array = PackedInt32Array()
	var indices: PackedInt32Array = PackedInt32Array([start])
	var scan: int = start + 1
	while scan < actions.size() and depth > 0:
		var entry_row: RawCodeRow = actions[scan] as RawCodeRow
		if entry_row == null or not entry_row.enabled or entry_row.code.contains("\n"):
			return {}
		# A comment written among the entries is a person's own words about the table, and folding it
		# into a chip would turn a note into an entry the file does not have. The run is left alone.
		if entry_row.code.strip_edges().begins_with("#"):
			return {}
		depth += bracket_delta(entry_row.code)
		indices.append(scan)
		if depth > 0:
			lines.append(entry_row.code.strip_edges())
			rows.append(scan)
		scan += 1
	if depth != 0 or lines.is_empty():
		return {}
	var closer: RawCodeRow = actions[scan - 1] as RawCodeRow
	if closer == null or not is_closer_line(closer.code):
		return {}
	var open_bracket: String = "{" if head_text.ends_with("{") else "["
	return {
		"statement": _flattened(head.code, closer.code.strip_edges()),
		"open": open_bracket,
		"entries": parse_entries(lines, rows),
		"indices": indices,
		"end": scan
	}


## The whole run on ONE line, with the literal itself replaced by LITERAL_TOKEN: `return {` plus a
## closing `}` becomes `return ⟦⟧`, and `spans.append(_make_span(text, KEYWORD, {` plus `}))`
## becomes `spans.append(_make_span(text, KEYWORD, ⟦⟧))`. That is the sentence the row reads as,
## with a hole where the chips go.
static func _flattened(head_code: String, closer_text: String) -> String:
	var indent: String = head_code.substr(0, head_code.length() - head_code.lstrip("\t ").length())
	var head_text: String = head_code.strip_edges()
	# The head's trailing opener and the closer's matching bracket are the literal's own two ends;
	# whatever else the closer carries (the `)` of the call the literal was an argument to, a
	# trailing comma) belongs to the statement and is kept.
	var tail: String = closer_text.substr(1) if closer_text.length() > 0 else ""
	return "%s%s%s%s" % [indent, head_text.substr(0, head_text.length() - 1), LITERAL_TOKEN, tail]


## The entries of a literal, as [{key, value, row, open, nested}] in source order.
##
## `key` is "" for a list entry and holds the SOURCE text of a table key (quotes included, so a
## quoted key and a bare constant are both shown as written). `row` is the action index the entry
## line came from, which is what lets a chip edit rewrite that one row. A nested `{` / `[` value
## carries its own entry list in `nested` and an empty `value`; anything else that opens a bracket
## over several lines is folded into ONE entry whose value is the lines joined, because a wrapped
## call is not a table and pretending otherwise would invent entries the file does not have.
static func parse_entries(lines: PackedStringArray, rows: PackedInt32Array) -> Array:
	var entries: Array = []
	var index: int = 0
	while index < lines.size():
		var text: String = lines[index]
		var delta: int = bracket_delta(text)
		if delta <= 0:
			entries.append(_flat_entry(text, rows[index]))
			index += 1
			continue
		var depth: int = delta
		var inner_lines: PackedStringArray = PackedStringArray()
		var inner_rows: PackedInt32Array = PackedInt32Array()
		var scan: int = index + 1
		while scan < lines.size() and depth > 0:
			depth += bracket_delta(lines[scan])
			if depth > 0:
				inner_lines.append(lines[scan])
				inner_rows.append(rows[scan])
			scan += 1
		if text.ends_with("{") or text.ends_with("["):
			var key: String = ""
			var colon: int = top_level_find(text, ": ")
			if colon >= 0:
				key = text.substr(0, colon)
			entries.append({
				"key": key,
				"value": "",
				"row": rows[index],
				"open": "{" if text.ends_with("{") else "[",
				"nested": parse_entries(inner_lines, inner_rows)
			})
		else:
			# A wrapped call, not a nested literal: one entry, the lines joined with a space.
			var joined: String = text
			for inner_index: int in inner_lines.size():
				joined += " " + inner_lines[inner_index]
			if scan - 1 < lines.size():
				joined += " " + lines[scan - 1]
			entries.append(_flat_entry(joined, rows[index]))
		index = maxi(scan, index + 1)
	return entries


## One entry line -> {key, value, row, open, nested}. A table entry splits on the first top-level
## `: `; a list entry keeps the whole text as its value. The trailing comma is punctuation the file
## needs and the reader does not, so it comes off.
static func _flat_entry(text: String, row: int) -> Dictionary:
	var body: String = text
	while body.ends_with(",") or body.ends_with(" "):
		body = body.substr(0, body.length() - 1)
	var colon: int = top_level_find(body, ": ")
	if colon < 0:
		return {"key": "", "value": body, "row": row, "open": "", "nested": []}
	return {
		"key": body.substr(0, colon),
		"value": body.substr(colon + 2),
		"row": row,
		"open": "",
		"nested": []
	}


## True when a line carries nothing but closing brackets and commas - the orphan `}` / `})` / `],`
## that ends a literal split one row per line.
static func is_closer_line(line: String) -> bool:
	var text: String = line.strip_edges()
	if text.is_empty():
		return false
	for character: String in text:
		if not (character in "}]),"):
			return false
	return true


## The net bracket depth one line adds, ignoring string literals and anything after a `#`. Written
## here rather than borrowed so this file stays a self-contained model the tests can drive without
## a viewport, a theme, or a row builder.
static func bracket_delta(line: String) -> int:
	var depth: int = 0
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
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		index += 1
	return depth


## The index of the first `separator` at bracket/quote depth 0, or -1 - a key or a value can hold
## the separator inside a string or a nested bracket, so a plain find() would split in the wrong
## place.
static func top_level_find(text: String, separator: String) -> int:
	var depth: int = 0
	var quote: String = ""
	var index: int = 0
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
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif depth == 0 and text.substr(index, separator.length()) == separator:
			return index
		index += 1
	return -1


## The chip one entry reads as, already spelled the way the row's other names are: `"row_index":
## _editing_row_index` reads `row index = editing row index`, a list entry reads as its value alone,
## and a nested literal reads as its own word plus its own chips inside braces.
##
## `humanize` is the Familiar Words switch: off, every name is shown exactly as the file writes it.
static func chip_text(entry: Dictionary, humanize: bool) -> String:
	var value: String = str(entry.get("value", ""))
	if not (entry.get("nested", []) as Array).is_empty():
		var inner: PackedStringArray = PackedStringArray()
		for nested_entry: Variant in (entry.get("nested", []) as Array):
			inner.append(chip_text(nested_entry as Dictionary, humanize))
		var word: String = "table" if str(entry.get("open", "{")) == "{" else "list"
		value = "%s (%s)" % [EventSheetL10n.translate(word), ", ".join(inner)]
	else:
		value = spelled(value, humanize)
	var key: String = str(entry.get("key", ""))
	if key.is_empty():
		return value
	return "%s = %s" % [key_text(key, humanize), value]


## A table key, as a NAME rather than as a value: `"row_index"` reads `row index`. The quotes are
## how GDScript spells a key and say nothing to a reader - a sheet writes the name of a thing. A key
## that is not a plain quoted identifier (an expression, a constant) is left exactly as written.
static func key_text(key: String, humanize: bool) -> String:
	if not humanize:
		return key
	var trimmed: String = key.strip_edges()
	if trimmed.length() >= 2 and (trimmed.begins_with("\"") or trimmed.begins_with("'")) \
			and trimmed.ends_with(trimmed[0]):
		var inner: String = trimmed.substr(1, trimmed.length() - 2)
		if inner.is_valid_identifier():
			return inner.replace("_", " ")
	return spelled(trimmed, humanize)


## One key or value, spelled for reading: a quoted string keeps its quotes and reads its CONTENT as
## words (a key written `"replace_action"` is a name somebody chose, not prose), and anything else
## goes through the ordinary expression lens so a chain reads possessively.
static func spelled(text: String, humanize: bool) -> String:
	if not humanize:
		return text
	var trimmed: String = text.strip_edges()
	if trimmed.length() >= 2 and (trimmed.begins_with("\"") or trimmed.begins_with("'")) \
			and trimmed.ends_with(trimmed[0]):
		var quote: String = trimmed[0]
		var inner: String = trimmed.substr(1, trimmed.length() - 2)
		if inner.is_valid_identifier():
			return "%s%s%s" % [quote, inner.replace("_", " "), quote]
		return trimmed
	return EventSheetViewportLenses.humanize_expression(trimmed)


## The whole literal as one line of text - what a folded row shows on hover, so a row that says
## "3 more" never hides anything.
static func full_text(entries: Array, open_bracket: String, humanize: bool) -> String:
	var chips: PackedStringArray = PackedStringArray()
	for entry: Variant in entries:
		chips.append(chip_text(entry as Dictionary, humanize))
	var word: String = "table" if open_bracket == "{" else "list"
	return "%s: %s" % [EventSheetL10n.translate(word), " · ".join(chips)]


## Applies one edited chip back to the ROW the entry came from, rewriting that entry in place and
## leaving every other line of the file alone. The indexes ride in edit_kind
## ("literal_entry_line:<action>:<entry row>") because the span-edit signal carries no metadata.
##
## The edited text is put back in the file's own spelling: the row keeps its indentation and its
## trailing comma, so a chip edit changes exactly the characters between them. An edit that would
## break the one-entry-per-line shape (an embedded newline, an empty value) is refused, which is the
## same promise the declaration entries make.
static func apply_entry_edit(source: Resource, edit_kind: String, value: String) -> bool:
	var parts: PackedStringArray = edit_kind.split(":")
	if parts.size() != 3 or source == null:
		return false
	var row_index: int = int(parts[2])
	var actions: Array = []
	if source is EventRow:
		actions = (source as EventRow).actions
	if row_index < 0 or row_index >= actions.size():
		return false
	var row: RawCodeRow = actions[row_index] as RawCodeRow
	if row == null or row.code.contains("\n"):
		return false
	var text: String = value.strip_edges()
	if text.is_empty() or text.contains("\n"):
		return false
	var indent: String = row.code.substr(0, row.code.length() - row.code.lstrip("\t ").length())
	var comma: String = "," if row.code.strip_edges().ends_with(",") else ""
	# The chip is written `key = value`; the file writes `key: value`. Only the first top-level
	# separator is a split point, so a value holding one of its own is safe.
	var separator: int = top_level_find(text, " = ")
	if separator >= 0:
		text = "%s: %s" % [text.substr(0, separator), text.substr(separator + 3)]
	row.code = "%s%s%s" % [indent, text, comma]
	return true
