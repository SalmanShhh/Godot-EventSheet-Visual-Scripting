# EventForge — Trigger resolver
@tool
extends RefCounted
class_name TriggerResolver

## Returns a stable trigger-group key from an event row.
static func get_trigger_key(event: EventRow) -> String:
return "%s::%s" % [event.trigger_provider_id, event.trigger_id]

## Resolves trigger metadata for code generation.
static func resolve_trigger(event: EventRow) -> Dictionary:
match event.trigger_id:
"OnReady":
return {"function_name": "_ready", "args": ""}
"OnProcess":
return {"function_name": "_process", "args": "delta: float"}
"OnPhysicsProcess":
return {"function_name": "_physics_process", "args": "delta: float"}
"OnBodyEntered":
return {"function_name": "_on_body_entered", "args": "body: Node"}
"OnSignal":
return {"function_name": "_on_eventforge_signal", "args": "signal_name: String"}
_:
return {"function_name": "", "args": ""}
