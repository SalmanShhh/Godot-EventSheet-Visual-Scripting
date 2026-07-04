# Godot EventSheets - SignalRow resource
# A class-level signal declared as a sheet row (the enum-row pattern): compiles to the
# canonical `signal name` / `signal name(damage: int)` line, verify-lifts back, renders
# as a keyword-badged row, and feeds the signal pickers (On Signal / Emit Signal) and
# trigger connection validation.
@tool
class_name SignalRow
extends Resource

@export var enabled: bool = true
@export var signal_name: String = "my_signal"
## Parameter declarations in order ("damage" or "damage: int").
@export var params: PackedStringArray = PackedStringArray()

## When true the signal also publishes as a TRIGGER ACE: the compiler prefixes the declaration with
## `## @ace_trigger` (+ optional @ace_name / @ace_category), so a behaviour can declare a code-free
## trigger signal as a row instead of a hand-written GDScript block. Off = a plain `signal` line.
@export var trigger: bool = false
## Optional display name for the trigger ACE (`## @ace_name`); defaults to the signal name.
@export var ace_name: String = ""
## Optional picker category for the trigger ACE (`## @ace_category`).
@export var ace_category: String = ""


## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "signal"
