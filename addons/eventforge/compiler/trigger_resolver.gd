# EventForge — Trigger resolver
# Maps EventForge trigger IDs to generated GDScript function signatures, and — for
# signal-backed triggers — to the signal that must be connected in `_ready` (the compiler
# emits the connection; handlers used to be generated but never connected). Custom signal
# triggers from reflection providers use the "signal:<name>" id convention, with their
# argument signature baked onto the event as `trigger_args` at apply time.
@tool
extends RefCounted
class_name TriggerResolver

## Returns a stable trigger-group key. The source path is part of the key because the same
## signal from different source nodes needs different handlers.
static func get_trigger_key(event: EventRow) -> String:
	return "%s::%s::%s" % [event.trigger_provider_id, event.trigger_id, event.trigger_source_path]

## Resolves trigger metadata for code generation:
## - function_name/args: the handler signature to emit
## - signal_name: non-empty for signal-backed triggers (the compiler emits
##   `<source>.<signal_name>.connect(<function_name>)` in `_ready`)
## - source_path: the node whose signal fires ("" = self); baked into the handler name so
##   "On landed (Platform)" and "On landed (Boss)" coexist.
static func resolve_trigger(event: EventRow) -> Dictionary:
	var source_path: String = event.trigger_source_path.strip_edges()
	var source_token: String = _identifier_for_source(source_path)
	match event.trigger_id:
		"OnReady":
			return _lifecycle("_ready", "")
		"OnProcess":
			return _lifecycle("_process", "delta: float")
		"OnPhysicsProcess":
			return _lifecycle("_physics_process", "delta: float")
		"OnInput":
			return _lifecycle("_input", "event: InputEvent")
		"OnUnhandledInput":
			return _lifecycle("_unhandled_input", "event: InputEvent")
		"OnEditorRun":
			return _lifecycle("_run", "")
		"OnBodyEntered":
			return _signal_backed("_on%s_body_entered" % source_token, "body: Node", "body_entered", source_path)
		"OnAreaEntered":
			return _signal_backed("_on%s_area_entered" % source_token, "area: Area2D", "area_entered", source_path)
		"OnTimeout":
			return _signal_backed("_on%s_timeout" % source_token, "", "timeout", source_path)
		"OnAnimationFinished":
			return _signal_backed("_on%s_animation_finished" % source_token, "anim_name: StringName", "animation_finished", source_path)
		"OnButtonPressed":
			return _signal_backed("_on%s_pressed" % source_token, "", "pressed", source_path)
		"OnButtonToggled":
			return _signal_backed("_on%s_toggled" % source_token, "toggled_on: bool", "toggled", source_path)
		"OnParticlesFinished":
			return _signal_backed("_on%s_finished" % source_token, "", "finished", source_path)
		"OnSignal":
			var signal_name: String = str(event.trigger_params.get("signal_name", "eventforge_signal"))
			return _signal_backed("_on%s_%s" % [source_token, signal_name], "", signal_name, source_path)
		_:
			# Custom signal triggers from reflection providers/addons ("signal:<name>").
			if event.trigger_id.begins_with("signal:"):
				var custom_signal: String = event.trigger_id.trim_prefix("signal:")
				return _signal_backed("_on%s_%s" % [source_token, custom_signal], event.trigger_args, custom_signal, source_path)
			return {"function_name": "", "args": "", "signal_name": "", "source_path": ""}

static func _lifecycle(function_name: String, args: String) -> Dictionary:
	return {"function_name": function_name, "args": args, "signal_name": "", "source_path": ""}

static func _signal_backed(function_name: String, args: String, signal_name: String, source_path: String) -> Dictionary:
	return {"function_name": function_name, "args": args, "signal_name": signal_name, "source_path": source_path}

## "" → "" (self keeps the classic handler names); "Platform" → "_platform";
## "Enemies/Boss" → "_enemies_boss" — a safe identifier fragment for handler names.
static func _identifier_for_source(source_path: String) -> String:
	if source_path.is_empty():
		return ""
	# Autoload sources ("autoload:EventBus") token on the singleton name alone,
	# snake-cased for readable handlers (_on_event_bus_game_paused).
	if source_path.begins_with("autoload:"):
		source_path = source_path.trim_prefix("autoload:").to_snake_case()
	var token: String = ""
	for character in source_path.to_lower():
		token += character if (character >= "a" and character <= "z") or (character >= "0" and character <= "9") else "_"
	return "_" + token
