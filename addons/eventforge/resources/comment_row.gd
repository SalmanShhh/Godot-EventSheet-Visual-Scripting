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
