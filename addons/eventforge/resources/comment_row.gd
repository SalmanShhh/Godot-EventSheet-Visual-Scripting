# EventForge — CommentRow resource
# Non-executing comment row preserved during compilation/import.
@tool
extends Resource
class_name CommentRow

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

## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "comment"
