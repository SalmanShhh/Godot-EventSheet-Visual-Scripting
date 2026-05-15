# EventForge — EventGroupReference resource
@tool
extends Resource
class_name EventGroupReference

@export var enabled: bool = true
@export var target_group_uid: String = ""

## Returns the stable row kind identifier.
func get_row_kind() -> String:
return "group_ref"
