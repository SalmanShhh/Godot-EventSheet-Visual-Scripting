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


## The two spellings GDScript itself gives a comment, and the ONE fact that separates them: a line
## opening `##` is documentation (the engine renders it for a `class_name` script), a line opening a
## single `#` is private to the file. There is no second field recording which one this row is - the
## marker it writes IS the answer, so the row, the emitted line and everything that reads them can
## never disagree.
const DOC_MARKER := "## "

## The ordinary private marker. Stored as the EMPTY string rather than as these two characters,
## because every authored comment and every generated file has always used it and writing it out
## would change bytes in files nobody edited.
const PRIVATE_MARKER := "# "

## The words that open a note somebody means to come back to. Surfaced once as a chip in the project
## view; they are never documentation, whichever marker they were written with.
const TASK_WORDS: PackedStringArray = ["TODO", "FIXME"]


## Whether this comment is DOCUMENTATION - a `##` line. False for the ordinary `#` form, which is the
## default and what an unmarked row emits.
func is_documentation() -> bool:
	return emit_marker().begins_with("##")


## Makes this row documentation, or makes it private, by rewriting the only thing that decides it.
##
## BYTE-EXACTNESS: a row already on the wanted side is left completely alone, so re-ticking a box on
## a comment lifted as `##` (no trailing space) does not silently respell it as `## `. Only a row
## that actually changes sides gets the canonical marker for its new side, and going private stores
## the empty string, which is the spelling every existing sheet and pack already has.
func set_documentation(documentation: bool) -> void:
	if is_documentation() == documentation:
		return
	source_marker = DOC_MARKER if documentation else ""


## The line this row actually writes, for the echo beside it - the marker it emits followed by one
## line of its text. The echo is built from `emit_marker()` rather than from a second formatting rule,
## so an echo that disagreed with the file would be impossible to write.
func echo_line(line_index: int = 0) -> String:
	var lines: PackedStringArray = text.split("\n")
	var line: String = lines[line_index] if line_index >= 0 and line_index < lines.size() else ""
	return (emit_marker() + line).rstrip(" \t") if line.strip_edges().is_empty() else emit_marker() + line


## The task word this note opens with (`TODO` / `FIXME`), or "" when it opens with neither. A task is
## a thing to do rather than a thing to read, so it is listed as a chip and never as prose.
func task_word() -> String:
	var trimmed: String = text.strip_edges()
	for word: String in TASK_WORDS:
		if trimmed == word or trimmed.begins_with(word + ":") or trimmed.begins_with(word + " ") \
				or trimmed.begins_with(word + "(") or trimmed.begins_with(word + "-"):
			return word
	return ""


## Whether this row is a line of the file. An authored comment with nothing written in it is not -
## it is an empty row somebody has not filled in yet, and emitting it would leave a stray `# ` in the
## generated script. A comment that came from an opened file IS, even when it says nothing: the bare
## `#` that separates two paragraphs of a note is a real line, and dropping it silently failed the
## round-trip and left the whole function it sat in reading as code.
func writes_a_line() -> bool:
	return enabled and (not text.strip_edges().is_empty() or not source_marker.is_empty())


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
