# EventForge — GDScript panel
@tool
extends CodeEdit
class_name GDScriptPanel

func _ready() -> void:
	editable = false
	set_draw_line_numbers(true)
	set_line_wrapping_mode(TextEdit.LINE_WRAPPING_NONE)

## Sets the displayed source text.
func set_source(code: String) -> void:
	text = code
	set_caret_line(0)
	set_caret_column(0)
