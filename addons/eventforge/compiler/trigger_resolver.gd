# EventForge — Trigger resolver
# Maps EventForge trigger IDs to generated GDScript function signatures.
@tool
extends RefCounted
class_name TriggerResolver

const SIGNAL_TRIGGER_ID: String = "OnSignal"
const SUPPORTED_TRIGGER_SIGNATURES: Dictionary = {
	"OnReady": {"function_name": "_ready", "args": ""},
	"OnProcess": {"function_name": "_process", "args": "delta: float"},
	"OnPhysicsProcess": {"function_name": "_physics_process", "args": "delta: float"}
}

## Returns a stable trigger-group key from an event row.
static func get_trigger_key(event: EventRow) -> String:
	if event.trigger_id == SIGNAL_TRIGGER_ID:
		return "%s::%s::%s" % [
			event.trigger_provider_id,
			event.trigger_id,
			_sanitize_signal_name(str(event.trigger_params.get("signal_name", "")))
		]
	return "%s::%s" % [event.trigger_provider_id, event.trigger_id]

## Resolves trigger metadata for code generation.
static func resolve_trigger(event: EventRow) -> Dictionary:
	if event == null:
		return {"function_name": "", "args": ""}
	if event.trigger_id == SIGNAL_TRIGGER_ID:
		return {
			"function_name": "_on_%s" % _sanitize_signal_name(str(event.trigger_params.get("signal_name", ""))),
			"args": ""
		}
	if SUPPORTED_TRIGGER_SIGNATURES.has(event.trigger_id):
		return (SUPPORTED_TRIGGER_SIGNATURES[event.trigger_id] as Dictionary).duplicate(true)
	return {"function_name": "", "args": ""}

## Returns whether trigger belongs to the first translation-matrix slice.
static func is_supported_in_slice(event: EventRow) -> bool:
	return not str(resolve_trigger(event).get("function_name", "")).is_empty()

## Returns a deterministic warning for unsupported triggers.
static func unsupported_warning(event: EventRow) -> String:
	return "Unsupported trigger in first translation-matrix slice: %s::%s (event %s)" % [
		event.trigger_provider_id,
		event.trigger_id,
		event.event_uid
	]

## Normalizes signal names for deterministic function identifiers.
static func _sanitize_signal_name(raw_name: String) -> String:
	var name: String = raw_name.strip_edges()
	if name.begins_with("\"") and name.ends_with("\"") and name.length() >= 2:
		name = name.substr(1, name.length() - 2)
	if name.is_empty():
		return "eventforge_signal"
	var output: String = ""
	for i: int in range(name.length()):
		var chr: String = name.substr(i, 1)
		var code: int = name.unicode_at(i)
		var is_alpha: bool = (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var is_digit: bool = (code >= 48 and code <= 57)
		if is_alpha or is_digit:
			output += chr.to_lower()
		elif chr == "_":
			output += "_"
		else:
			output += "_"
	while output.contains("__"):
		output = output.replace("__", "_")
	while output.begins_with("_"):
		output = output.substr(1)
	while output.ends_with("_"):
		output = output.left(output.length() - 1)
	if output.is_empty():
		return "eventforge_signal"
	if output.unicode_at(0) >= 48 and output.unicode_at(0) <= 57:
		output = "signal_%s" % output
	return output
