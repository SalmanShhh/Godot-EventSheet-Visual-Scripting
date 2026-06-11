# Godot EventSheets — Live Values debugger bridge (debugging rung 2)
# Captures the throttled "eventsheets:live_values" messages that debug-compiled sheets
# send from _process (see SheetCompiler — emit_live_values), and forwards them to the
# editor as a name->value dictionary. Registered by the plugin entry point.
@tool
extends EditorDebuggerPlugin
class_name EventSheetLiveValuesDebugger

## Emitted on the editor side whenever a running game streams a values frame.
signal values_received(values: Dictionary)

func _has_capture(capture: String) -> bool:
	return capture == "eventsheets"

func _capture(message: String, data: Array, _session_id: int) -> bool:
	if message != "eventsheets:live_values":
		return false
	values_received.emit(parse_payload(data))
	return true

## Flat [name, value, name, value, …] pairs -> {name: value}. Tolerates odd lengths
## (a trailing unpaired name is dropped rather than erroring mid-session).
static func parse_payload(data: Array) -> Dictionary:
	var values: Dictionary = {}
	var index: int = 0
	while index + 1 < data.size():
		values[str(data[index])] = data[index + 1]
		index += 2
	return values
