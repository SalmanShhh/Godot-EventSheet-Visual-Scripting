# EventForge — Trigger resolver
# Maps EventForge trigger IDs to generated GDScript function signatures.
@tool
extends RefCounted
class_name TriggerResolver

const TRIGGER_CONDITION_IDS: PackedStringArray = [
	"OnReady",
	"OnProcess",
	"OnPhysicsProcess",
	"OnSignal",
	"OnBodyEntered"
]

## Returns a stable trigger-group key from an event row.
static func get_trigger_key(event: EventRow) -> String:
	var trigger_provider_id: String = get_trigger_provider_id(event)
	var trigger_id: String = get_trigger_id(event)
	if trigger_id.is_empty():
		return "Core::OnProcess"

	match trigger_id:
		"OnSignal":
			var params: Dictionary = get_trigger_params(event)
			return "%s::%s::%s::%s" % [
				trigger_provider_id,
				trigger_id,
				_normalize_target_node(str(params.get("target_node", ""))),
				str(params.get("signal_name", "eventforge_signal")).strip_edges()
			]
		_:
			return "%s::%s" % [trigger_provider_id, trigger_id]

## Resolves trigger metadata for code generation.
static func resolve_trigger(event: EventRow) -> Dictionary:
	var trigger_id: String = get_trigger_id(event)
	if trigger_id.is_empty():
		trigger_id = "OnProcess"
	match trigger_id:
		"OnReady":
			return {"function_name": "_ready", "args": ""}
		"OnProcess":
			return {"function_name": "_process", "args": "delta: float"}
		"OnPhysicsProcess":
			return {"function_name": "_physics_process", "args": "delta: float"}
		"OnBodyEntered":
			return {"function_name": "_on_body_entered", "args": "body: Node"}
		"OnSignal":
			var params: Dictionary = get_trigger_params(event)
			var signal_name: String = str(params.get("signal_name", "eventforge_signal")).strip_edges()
			var target_node: String = _normalize_target_node(str(params.get("target_node", "")))
			var function_name: String = "_ef_on_%s_%s" % [
				_sanitize_identifier(target_node),
				_sanitize_identifier(signal_name)
			]
			return {
				"function_name": function_name,
				"args": "",
				"connect_in_ready": true,
				"connection_line": "%s.%s.connect(%s)" % [_target_expression(target_node), signal_name, function_name]
			}
		_:
			return {"function_name": "", "args": ""}

static func get_trigger_id(event: EventRow) -> String:
	if event == null:
		return ""
	if not event.trigger_id.is_empty():
		return event.trigger_id
	if event.trigger != null:
		return event.trigger.ace_id
	return ""

static func get_trigger_provider_id(event: EventRow) -> String:
	if event == null:
		return "Core"
	if not event.trigger_provider_id.is_empty():
		return event.trigger_provider_id
	if event.trigger != null and not event.trigger.provider_id.is_empty():
		return event.trigger.provider_id
	return "Core"

static func get_trigger_params(event: EventRow) -> Dictionary:
	if event == null:
		return {}
	if not event.trigger_params.is_empty():
		return event.trigger_params
	if event.trigger != null:
		if not event.trigger.params.is_empty():
			return event.trigger.params
		return event.trigger.parameters
	return {}

static func has_trigger_condition(event: EventRow) -> bool:
	return not get_trigger_id(event).is_empty()

static func is_trigger_condition_id(ace_id: String) -> bool:
	return TRIGGER_CONDITION_IDS.has(ace_id)

static func _normalize_target_node(target_node: String) -> String:
	var normalized: String = target_node.strip_edges()
	if normalized.is_empty() or normalized == "." or normalized.to_lower() == "self":
		return "self"
	return normalized

static func _sanitize_identifier(text: String) -> String:
	var sanitized: String = text.strip_edges().to_lower()
	for character: String in ["/", "\\", ":", ".", "-", " ", "\"", "'", "[", "]", "(", ")", "{", "}"]:
		sanitized = sanitized.replace(character, "_")
	while sanitized.contains("__"):
		sanitized = sanitized.replace("__", "_")
	sanitized = sanitized.strip_edges().trim_prefix("_").trim_suffix("_")
	if sanitized.is_empty():
		return "event"
	if sanitized.substr(0, 1).is_valid_int():
		sanitized = "event_%s" % sanitized
	return sanitized

static func _target_expression(target_node: String) -> String:
	if target_node == "self":
		return "self"
	return "get_node(%s)" % _string_literal(target_node)

static func _string_literal(text: String) -> String:
	return "\"%s\"" % text.replace("\\", "\\\\").replace("\"", "\\\"")
