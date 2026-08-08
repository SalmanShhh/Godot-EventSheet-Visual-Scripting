# EventForge - CollectionDeclRow resource
#
# A function-local multi-line collection declaration, held as STRUCTURE instead of text:
#
#	var waves := {
#		"calm": 3,
#		"busy": 8,
#	}
#
# is one "Declare waves" action whose entries are rows of their own - readable, individually
# editable, and reorderable - with no bracket lines on the canvas at all. The brackets exist in
# the FILE (emit_lines() writes them back), just never as rows.
#
# THE BYTE GATE LIVES IN parse(): a literal is only claimed when re-emitting the structured
# model reproduces the source lines exactly, so the head and closer are stored verbatim and the
# entries must be canonical (one tab deep, comma-terminated, one per line). Anything else - a
# nested multi-line value, a missing trailing comma, an inline comment - stays as per-line
# verbatim rows, and the lossless round-trip is never at risk.
#
# Every field is @export because sheet snapshots duplicate resources, and duplicate() copies
# exported properties only - a plain var here would silently vanish on the first undo.
@tool
class_name CollectionDeclRow
extends Resource

@export var enabled: bool = true
## The declaration line, verbatim (depth-stripped): `var waves := {`.
@export var head: String = ""
## The closing bracket line, verbatim: `}` or `]`.
@export var close: String = "}"
## Dictionary keys, verbatim ("" for an array entry). Parallel to entry_values.
@export var entry_keys: PackedStringArray = PackedStringArray()
## Entry value expressions, verbatim.
@export var entry_values: PackedStringArray = PackedStringArray()


## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "collection_decl"


func is_dictionary() -> bool:
	return head.strip_edges().ends_with("{")


## The declared variable's name, parsed from the head (`var waves := {` -> "waves").
func variable_name() -> String:
	var name_regex: RegEx = RegEx.create_from_string("^var ([A-Za-z_][A-Za-z0-9_]*)")
	var found: RegExMatch = name_regex.search(head.strip_edges())
	return found.get_string(1) if found != null else "?"


## The exact source lines this row emits, shared by the compiler and the parse() byte gate -
## one function so the two can never disagree.
func emit_lines() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	out.append(head)
	for entry_index: int in entry_values.size():
		var key: String = entry_keys[entry_index] if entry_index < entry_keys.size() else ""
		if key.is_empty():
			out.append("\t%s," % entry_values[entry_index])
		else:
			out.append("\t%s: %s," % [key, entry_values[entry_index]])
	out.append(close)
	return out


## Writes (entry_index >= 0) or appends (entry_index -1) one entry. Refuses what would break
## the one-entry-per-line emission shape: a blank value, an embedded newline, or a dictionary
## entry with no key. Keys hold SOURCE text, quotes included, so `"calm"` and a bare constant
## are both legal and neither is guessed at. The single mutation path shared by the entry
## dialog, the inline value edit, and the public API.
func set_entry(entry_index: int, key_text: String, value_text: String) -> bool:
	var key: String = key_text.strip_edges()
	var value: String = value_text.strip_edges().trim_suffix(",").strip_edges()
	if value.is_empty() or value.contains("\n"):
		return false
	if is_dictionary():
		if key.is_empty() or key.contains("\n"):
			return false
	else:
		key = ""
	if entry_index >= 0 and entry_index < entry_values.size():
		entry_keys[entry_index] = key
		entry_values[entry_index] = value
	else:
		entry_keys.append(key)
		entry_values.append(value)
	return true


## Writes one entry from a whole edited LINE - the inline edit hands back `"calm" = 12` (or a
## bare value for an array), and either side may have changed. Dictionary lines split on the
## first top-level ` = `, with `: ` accepted too so pasting source form also works. Refusals
## match set_entry's; the display indent is stripped, so leading spaces never leak into a key.
func set_entry_text(entry_index: int, line_text: String) -> bool:
	var text: String = line_text.strip_edges()
	if not is_dictionary():
		return set_entry(entry_index, "", text)
	var split_at: int = _top_level_find(text, " = ")
	var value_from: int = split_at + 3
	if split_at < 0:
		split_at = _top_level_find(text, ": ")
		value_from = split_at + 2
	if split_at < 0:
		return false
	return set_entry(entry_index, text.substr(0, split_at), text.substr(value_from))


## Parses depth-stripped literal lines into a structured row, or null when the shape is not
## canonical. The final emit_lines() comparison IS the byte gate: whatever this cannot
## reproduce exactly is not claimed, so a fussy source stays verbatim rather than corrupt.
static func parse(lines: PackedStringArray) -> CollectionDeclRow:
	if lines.size() < 3:
		return null
	var head_text: String = lines[0]
	if head_text.begins_with("\t") or head_text.begins_with(" ") or not head_text.begins_with("var "):
		return null
	var stripped_head: String = head_text.strip_edges()
	if not (stripped_head.ends_with("{") or stripped_head.ends_with("[")):
		return null
	var row: CollectionDeclRow = CollectionDeclRow.new()
	row.head = head_text
	row.close = lines[lines.size() - 1]
	var wants_key: bool = stripped_head.ends_with("{")
	for line_index: int in range(1, lines.size() - 1):
		var line: String = lines[line_index]
		# Exactly one tab deep: a deeper line is a nested multi-line value, whose per-entry
		# model this row deliberately does not pretend to have.
		if not line.begins_with("\t") or line.begins_with("\t\t"):
			return null
		var body: String = line.substr(1)
		if not body.ends_with(","):
			return null
		body = body.substr(0, body.length() - 1)
		if body.strip_edges() != body or body.is_empty():
			return null
		if wants_key:
			var colon: int = _top_level_colon(body)
			if colon < 0 or body.substr(colon, 2) != ": ":
				return null
			var key: String = body.substr(0, colon)
			var value: String = body.substr(colon + 2)
			if key.is_empty() or value.is_empty() or key.strip_edges() != key or value.strip_edges() != value:
				return null
			row.entry_keys.append(key)
			row.entry_values.append(value)
		else:
			row.entry_keys.append("")
			row.entry_values.append(body)
	if row.emit_lines() != lines:
		return null
	return row


## The index of the first `:` at bracket/quote depth 0, or -1.
static func _top_level_colon(text: String) -> int:
	return _top_level_find(text, ":")


## The index of the first `separator` at bracket/quote depth 0, or -1 - a key or value can hold
## the separator inside strings or nested brackets, so a plain find() would split wrongly.
static func _top_level_find(text: String, separator: String) -> int:
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
		elif depth == 0 and quote.is_empty() and text.substr(index, separator.length()) == separator:
			return index
		index += 1
	return -1
