# Godot EventSheets — SignalRow resource
# A class-level signal declared as a sheet row (the enum-row pattern): compiles to the
# canonical `signal name` / `signal name(damage: int)` line, verify-lifts back, renders
# as a keyword-badged row, and feeds the signal pickers (On Signal / Emit Signal) and
# trigger connection validation.
@tool
extends Resource
class_name SignalRow

@export var enabled: bool = true
@export var signal_name: String = "my_signal"
## Parameter declarations in order ("damage" or "damage: int").
@export var params: PackedStringArray = PackedStringArray()

## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "signal"
