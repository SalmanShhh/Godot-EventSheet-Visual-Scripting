# EventForge — EventGroupReference resource
# Row that references a reusable EventGroupResource.
@tool
extends Resource
class_name EventGroupReference

@export var enabled: bool = true
@export var resource: EventGroupResource = null
@export var target_group_uid: String = "" # Backwards-compatible alias.
@export var variable_overrides: Dictionary = {}
@export var collapsed: bool = false

## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "group_ref"
