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
		"OnPostTick":
			# Godot's "post-tick": SceneTree.process_frame fires ONCE after every node's _process this
			# frame — for logic that must run after everything else updated (a camera that follows after
			# movement, end-of-frame cleanup). Connected on get_tree() (the "@tree" global source), not self.
			return _signal_backed("_on_post_tick", "", "process_frame", "@tree")
		"OnPhysicsPostTick":
			# The physics-tick sibling: SceneTree.physics_frame, after every _physics_process this step.
			return _signal_backed("_on_physics_post_tick", "", "physics_frame", "@tree")
		"OnCloseRequested":
			# The window's close button (X) / an app-quit request — for save-on-quit or a confirm dialog.
			# Connected on the root window (the "@window" global source), not self.
			return _signal_backed("_on_close_requested", "", "close_requested", "@window")
		"OnBodyEntered":
			return _signal_backed("_on%s_body_entered" % source_token, "body: Node", "body_entered", source_path)
		"OnAreaEntered":
			return _signal_backed("_on%s_area_entered" % source_token, "area: Area2D", "area_entered", source_path)
		"OnBodyExited":
			return _signal_backed("_on%s_body_exited" % source_token, "body: Node", "body_exited", source_path)
		"OnAreaExited":
			return _signal_backed("_on%s_area_exited" % source_token, "area: Area2D", "area_exited", source_path)
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
		"OnTreeEntered":
			return _signal_backed("_on%s_tree_entered" % source_token, "", "tree_entered", source_path)
		"OnTreeExiting":
			return _signal_backed("_on%s_tree_exiting" % source_token, "", "tree_exiting", source_path)
		"OnTreeExited":
			return _signal_backed("_on%s_tree_exited" % source_token, "", "tree_exited", source_path)
		"OnRenamed":
			return _signal_backed("_on%s_renamed" % source_token, "", "renamed", source_path)
		"OnChildEnteredTree":
			return _signal_backed("_on%s_child_entered_tree" % source_token, "node: Node", "child_entered_tree", source_path)
		"OnSignal":
			var signal_name: String = str(event.trigger_params.get("signal_name", "eventforge_signal"))
			return _signal_backed("_on%s_%s" % [source_token, signal_name], str(event.trigger_params.get("args", "")).strip_edges(), signal_name, source_path)
		_:
			# Custom signal triggers from reflection providers/addons ("signal:<name>").
			if event.trigger_id.begins_with("signal:"):
				var custom_signal: String = event.trigger_id.trim_prefix("signal:")
				return _signal_backed("_on%s_%s" % [source_token, custom_signal], event.trigger_args, custom_signal, source_path)
			return {"function_name": "", "args": "", "signal_name": "", "source_path": ""}

# ── Trigger tempo (glance layer, spec §11) ───────────────────────────────────────────────────────
# The four TEMPO classes a trigger id falls into — HOW OFTEN the event runs, the #1 comprehension +
# perf fact, surfaced as a coloured badge on the row. Co-located with resolve_trigger ON PURPOSE so the
# two id censuses can never drift; trigger_tempo_exhaustiveness_test asserts every id resolve_trigger
# recognises also has a tempo class.
const TEMPO_EVERY_TICK := "every_tick"  # ⟳ runs every frame — the hot path
const TEMPO_INPUT := "input"            # ⌨ an input event
const TEMPO_ONCE := "once"              # ▶ runs once (setup)
const TEMPO_SIGNAL := "signal"          # ➜ reacts to a signal — the honest default

## Classifies a trigger id into its tempo class. Every-tick = per-frame lifecycle + the post-tick twins;
## input = the input handlers; once = _ready / editor-run; everything else — signal-backed triggers,
## "signal:<name>" custom signals, and any UNKNOWN id — is a signal (the honest default, matching the
## shipped green ➜ badge so unclassified ids never look broken).
static func tempo_class_for(trigger_id: String) -> String:
	match trigger_id:
		"OnProcess", "OnPhysicsProcess", "OnPostTick", "OnPhysicsPostTick":
			return TEMPO_EVERY_TICK
		"OnInput", "OnUnhandledInput":
			return TEMPO_INPUT
		"OnReady", "OnEditorRun":
			return TEMPO_ONCE
		_:
			return TEMPO_SIGNAL

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
	var normalized: bool = false
	for character in source_path.to_lower():
		# Underscores are legitimate identifier chars (snake_cased autoloads like `event_bus`), so
		# they pass through WITHOUT counting as normalization — only genuinely illegal chars do.
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9") or character == "_":
			token += character
		else:
			token += "_"
			normalized = true
	# A path with illegal chars can collapse onto a clean token ("A/B" and "A_B" both -> "_a_b"),
	# which would emit two same-named handler funcs (a parse error). Disambiguate ONLY the
	# illegal-char path with a short stable suffix of the raw path, so the clean source keeps its
	# readable handler name and distinct sources never collide.
	if normalized:
		token += "_" + str(abs(hash(source_path))).substr(0, 4)
	return "_" + token
