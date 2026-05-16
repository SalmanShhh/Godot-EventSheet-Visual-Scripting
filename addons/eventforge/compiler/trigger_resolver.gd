# EventForge — Trigger resolver
# Maps EventForge trigger IDs to generated GDScript function signatures.
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
		"OnAreaEntered":
			return {"function_name": "_on_area_entered", "args": "area: Area2D"}
		"OnTimeout":
			return {"function_name": "_on_timeout", "args": ""}
		"OnAnimationFinished":
			return {"function_name": "_on_animation_finished", "args": "anim_name: StringName"}
		"OnSignal":
			var signal_name: String = str(event.trigger_params.get("signal_name", "eventforge_signal"))
			return {"function_name": "_on_%s" % signal_name, "args": ""}
		_:
			return {"function_name": "", "args": ""}
