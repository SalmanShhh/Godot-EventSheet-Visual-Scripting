# EventForge — RawCodeRow resource
@tool
extends Resource
class_name RawCodeRow

@export var enabled: bool = true
@export_multiline var code: String = ""

## Returns the stable row kind identifier.
func get_row_kind() -> String:
return "raw"
