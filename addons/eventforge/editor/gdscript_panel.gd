# EventForge — GDScript panel (stub)
@tool
extends CodeEdit
class_name GDScriptPanel

## Sets the displayed source text.
func set_source(code: String) -> void:
	text = code
