# EventForge - CommentRow resource
# Non-executing comment row preserved during compilation/import.
@tool
class_name CommentRow
extends Resource

enum CommentStyle {
	NORMAL,
	NOTE,
	TODO,
	WARNING,
	SECTION
}

@export var enabled: bool = true
@export var text: String = ""
@export var style: CommentStyle = CommentStyle.NORMAL
@export var color_tag: String = ""
## Per-comment background tint (event-sheet-style colored comments). Alpha 0 = theme default.
@export var custom_color: Color = Color(0, 0, 0, 0)
## The exact marker this comment was written with, when it came from an opened .gd - "# " for the
## ordinary form, but also "#" with no space, or "## " for a doc-style note. Emission writes this
## back verbatim so an imported comment reproduces its source line byte-for-byte. EMPTY means the
## ordinary "# " form, which is what every authored comment and every generated file uses, so
## existing sheets and packs are unaffected.
@export var source_marker: String = ""


## The marker emission should write before each line of `text`.
func emit_marker() -> String:
	return source_marker if not source_marker.is_empty() else "# "


## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "comment"


## Words that open a note, never a statement - a line starting with one is prose whatever follows it.
const PROSE_OPENERS: Array[String] = ["TODO", "FIXME", "NOTE", "HACK", "XXX", "BUG", "WARNING"]

## Compiled once and shared: code_text runs for every action of every row the canvas paints.
static var _assign_regex: RegEx = null
static var _call_regex: RegEx = null

## Statement keywords that stand alone or open a block.
const STATEMENT_OPENERS: Array[String] = [
	"if ", "elif ", "else:", "for ", "while ", "match ", "return", "await ", "var ", "const ",
	"pass", "break", "continue", "emit_signal(", "queue_free("
]


## The CODE a comment's text is, or "" when the text is prose.
##
## A .gd file has no separate place to record that a row is switched off: commenting the line out IS
## how it is done, and that is the storage this reads. So a comment whose text is a statement (an
## assignment, a call, an `if`/`for` header) is a row somebody disabled, while a sentence stays the
## note it is. Deliberately conservative - a line that is not clearly code stays a comment, because
## reading a genuine note as a switched-off row is the worse mistake of the two.
static func code_text(text: String) -> String:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty() or trimmed.contains("\n"):
		return ""
	for opener: String in PROSE_OPENERS:
		if trimmed.begins_with(opener):
			return ""
	for opener: String in STATEMENT_OPENERS:
		if trimmed == opener.trim_suffix(" ").trim_suffix(":") or trimmed.begins_with(opener):
			return trimmed
	# Compiled ONCE: this runs for every action of every row the canvas paints, and building two
	# RegEx objects per line put a regex compile on the paint path.
	if _assign_regex == null:
		_assign_regex = RegEx.new()
		if _assign_regex.compile("^([A-Za-z_$%][A-Za-z0-9_$%.\\[\\]\"']*)\\s*(=|\\+=|-=|\\*=|/=|%=|\\|=|&=)\\s*(\\S.*)$") != OK:
			return ""
		_call_regex = RegEx.new()
		if _call_regex.compile("^[A-Za-z_$%][A-Za-z0-9_$%.\\[\\]\"']*\\(.*\\)$") != OK:
			return ""
	var assign_match: RegExMatch = _assign_regex.search(trimmed)
	if assign_match != null and _reads_as_expression(assign_match.get_string(3)):
		return trimmed
	if _call_regex.search(trimmed) != null:
		return trimmed
	return ""


## Whether the right side of an `=` is an EXPRESSION rather than the rest of a sentence. Prose like
## `Speed = how fast the player runs` is an assignment by shape only; a value either has no spaces at
## all, or carries the punctuation an expression is made of.
static func _reads_as_expression(value: String) -> bool:
	var trimmed: String = value.strip_edges()
	if trimmed.is_empty():
		return false
	if not trimmed.contains(" "):
		return true
	for character: String in trimmed:
		if character in "()+-*/%<>=!,.\"'[]":
			return true
	return false
