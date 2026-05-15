# EventForge — CommentRow resource
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

## Returns the stable row kind identifier.
func get_row_kind() -> String:
return "comment"
