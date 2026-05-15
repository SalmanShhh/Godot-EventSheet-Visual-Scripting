# EventForge — RawCodeRow resource
# Passthrough GDScript row for unparseable imported code.
@tool
extends Resource
class_name RawCodeRow

@export var enabled: bool = true
@export_multiline var code: String = ""
@export var source_line: int = 0

## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "raw"
