# Godot EventSheets — Live Values debugger bridge (debugging rung 2)
# Captures the throttled "eventsheets:live_values" messages that debug-compiled sheets
# send from _process (see SheetCompiler — emit_live_values), and forwards them to the
# editor as a name->value dictionary. Registered by the plugin entry point.
@tool
extends EditorDebuggerPlugin
class_name EventSheetLiveValuesDebugger

## Emitted on the editor side whenever a running game streams a values frame.
signal values_received(values: Dictionary)
## Emitted whenever a running game streams the set of event UIDs that fired since the last tick
## (debugging rung 3 — live event trace). The editor highlights those rows.
signal fired_events_received(uids: PackedStringArray)
## Emitted when the running game is about to pause at a sheet breakpoint: the generated code
## announces its row uid right before the `breakpoint` statement (core debugger messages never reach
## editor plugins, so the code reports its own location), and the editor reveals that row.
signal paused_row_received(uid: String)

var _last_session_id: int = -1

func _has_capture(capture: String) -> bool:
	return capture == "eventsheets"

func _capture(message: String, data: Array, session_id: int) -> bool:
	_last_session_id = session_id
	if message == "eventsheets:live_values":
		values_received.emit(parse_payload(data))
		return true
	if message == "eventsheets:fired_events":
		fired_events_received.emit(parse_fired(data))
		return true
	if message == "eventsheets:paused_row":
		paused_row_received.emit(parse_paused(data))
		return true
	return false

## The paused-row payload is a single event uid; empty on a malformed message (fails closed —
## the dock's reveal treats "" as a no-op). Static like the other parsers so tests can drive it
## without an editor (EditorDebuggerPlugin cannot be instantiated headless).
static func parse_paused(data: Array) -> String:
	return str(data[0]) if data.size() > 0 else ""

## The fired-events payload is the PackedStringArray of event UIDs (received as an Array).
static func parse_fired(data: Array) -> PackedStringArray:
	var uids: PackedStringArray = PackedStringArray()
	for entry: Variant in data:
		uids.append(str(entry))
	return uids

## Edit-back: pushes a value change into the running game (the streaming session).
func send_set_value(variable_name: String, value: Variant) -> bool:
	if _last_session_id < 0:
		return false
	var session: EditorDebuggerSession = get_session(_last_session_id)
	if session == null or not session.is_active():
		return false
	session.send_message("eventsheets:set_value", [variable_name, value])
	return true

## "3.5" -> 3.5, "true" -> true, "Vector2(1, 2)" -> vector… plain words stay strings
## (str_to_var yields null for them).
static func parse_edited_value(text: String) -> Variant:
	var parsed: Variant = str_to_var(text)
	return parsed if parsed != null or text.strip_edges() == "null" else text

## Flat [name, value, name, value, …] pairs -> {name: value}. Tolerates odd lengths
## (a trailing unpaired name is dropped rather than erroring mid-session).
static func parse_payload(data: Array) -> Dictionary:
	var values: Dictionary = {}
	var index: int = 0
	while index + 1 < data.size():
		values[str(data[index])] = data[index + 1]
		index += 2
	return values
