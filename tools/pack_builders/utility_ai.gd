# Pack builder - utility_ai (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## UtilityBrain: a scoring-based decision engine as a per-node BEHAVIOR (attach one to each enemy,
## companion, or NPC). It replaces brittle if/else state machines: you register candidate ACTIONS,
## give each a few CONSIDERATIONS (a world-state input mapped through a response curve to a 0-1
## score), feed the current world state, then call Evaluate - the highest-scoring action wins and
## fires triggers your sheet reacts to. Ported from the Construct 3 UtilityAI addon, made Godot-native
## and beginner-friendly:
##  - Per-node, so the NODE is the agent: every "agent id" argument the C3 addon threaded through
##    every action/condition/expression is gone. One brain, one enemy.
##  - Discrete typed ACEs (Add Action / Add Consideration) instead of the JSON-blob registration the
##    C3 version used - no hand-written JSON, no consideration-id typos to silently drop a factor.
##  - Response curves are a friendly named dropdown (linear / inverse / quadratic / logistic /
##    threshold / bell) with center + slope knobs, instead of raw curve math in a JSON string.
##  - A consideration-less action scores a constant fallback, so registering an "idle" action IS the
##    always-have-a-fallback best practice, with nothing extra to wire.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "UtilityBrain"
	sheet.addon_category = "Utility AI"
	sheet.addon_tags = PackedStringArray(["ai", "decision"])
	var about: CommentRow = CommentRow.new()
	about.text = "UtilityBrain: attach one to each AI node. Add Actions, give each a few Considerations (an input mapped through a curve), Set Input every so often, then Evaluate. The best-scoring action wins and fires On Decision Made / On Action Started - your sheet performs it, then calls Mark Action Complete. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune the FEEL in the Inspector) ---",
		"## How the winner is chosen. \"highest\" always takes the top score (predictable); \"weighted_random\" samples among the top few by score (varied, less robotic).",
		"@export_enum(\"highest\", \"weighted_random\") var selection_mode: String = \"highest\"",
		"## Weighted-random only: how many of the highest-scoring actions to sample from.",
		"@export_range(1, 10, 1) var weighted_top_n: int = 3",
		"## Bonus added to the action already running, so the brain does not flip-flop between near-tied actions (0 = off).",
		"@export_range(0.0, 1.0, 0.01) var inertia_bonus: float = 0.1",
		"## Actions scoring below this are ignored; if nothing clears it, On No Valid Action fires.",
		"@export_range(0.0, 1.0, 0.01) var min_score: float = 0.05",
		"## Score given to an action with NO considerations - a natural low fallback (register an \"idle\" with none).",
		"@export_range(0.0, 1.0, 0.01) var fallback_score: float = 0.1",
		"## Smooths many-consideration actions so multiplying lots of 0-1 factors does not unfairly deflate them.",
		"@export var score_compensation: bool = true",
		"## How many past actions to remember (for the Action History expression and anti-repeat logic).",
		"@export_range(1, 32, 1) var history_length: int = 5",
		"",
		"# --- Internal state ---",
		"# action name -> {cooldown:float, interruptible:bool, enabled:bool, priority:float, considerations:Array}.",
		"# Each consideration is {input:String, curve:String, weight:float, center:float, slope:float}.",
		"var _actions: Dictionary = {}",
		"# World-state inputs, read at evaluation time; an unset key reads as 0.",
		"var _world: Dictionary = {}",
		"# action name -> remaining cooldown seconds (present only while cooling down).",
		"var _cooldowns: Dictionary = {}",
		"# Last-evaluated score per action (for the Action Score expression).",
		"var _scores: Dictionary = {}",
		"var _current: String = \"\"",
		"var _previous: String = \"\"",
		"var _decision_score: float = 0.0",
		"# The action whose cooldown most recently started or ended (On Cooldown Started/Ended context).",
		"var _cooldown_action: String = \"\"",
		"# Recent started actions, most-recent first (index 0 = current).",
		"var _history: PackedStringArray = PackedStringArray()",
		"var _rng: RandomNumberGenerator = RandomNumberGenerator.new()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Decision Made\")",
		"## @ace_category(\"Utility AI\")",
		"signal on_decision_made()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Action Started\")",
		"## @ace_category(\"Utility AI\")",
		"signal on_action_started()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Action Changed\")",
		"## @ace_category(\"Utility AI\")",
		"signal on_action_changed()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Action Completed\")",
		"## @ace_category(\"Utility AI\")",
		"signal on_action_completed()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Action Interrupted\")",
		"## @ace_category(\"Utility AI\")",
		"signal on_action_interrupted()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Cooldown Started\")",
		"## @ace_category(\"Utility AI\")",
		"signal on_cooldown_started()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Cooldown Ended\")",
		"## @ace_category(\"Utility AI\")",
		"signal on_cooldown_ended()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On No Valid Action\")",
		"## @ace_category(\"Utility AI\")",
		"signal on_no_valid_action()",
		"",
		"# Maps a world-state input (clamped 0-1) through a named response curve to a 0-1 score.",
		"func _curve_score(curve: String, x: float, center: float, slope: float) -> float:",
		"\tvar v: float = clampf(x, 0.0, 1.0)",
		"\tmatch curve:",
		"\t\t\"linear\": return v",
		"\t\t\"inverse\": return 1.0 - v",
		"\t\t\"quadratic\": return v * v",
		"\t\t\"inverse_quadratic\": return 1.0 - v * v",
		"\t\t\"logistic\": return 1.0 / (1.0 + exp(-maxf(slope, 0.001) * 10.0 * (v - center)))",
		"\t\t\"threshold\": return 1.0 if v >= center else 0.0",
		"\t\t\"bell\":",
		"\t\t\tvar d: float = (v - center) / maxf(slope, 0.001)",
		"\t\t\treturn exp(-d * d)",
		"\t\t_: return v",
		"",
		"# An action's score: the product of its considerations (with the geometric-mean make-up",
		"# compensation), times its priority. A consideration-less action returns the flat fallback.",
		"func _score_action(name: String) -> float:",
		"\tvar action: Dictionary = _actions[name]",
		"\tvar cons: Array = action.considerations",
		"\tif cons.is_empty():",
		"\t\treturn fallback_score * float(action.priority)",
		"\tvar score: float = 1.0",
		"\tfor c: Dictionary in cons:",
		"\t\tvar raw: float = _curve_score(c.curve, float(_world.get(c.input, 0.0)), c.center, c.slope)",
		"\t\tscore *= pow(clampf(raw, 0.0, 1.0), maxf(c.weight, 0.0))",
		"\tif score_compensation and cons.size() > 1:",
		"\t\tvar mod: float = 1.0 - 1.0 / float(cons.size())",
		"\t\tscore += (1.0 - score) * mod * score",
		"\treturn score * float(action.priority)",
		"",
		"# Records a newly-started action at the front of the bounded history ring.",
		"func _push_history(name: String) -> void:",
		"\t_history.insert(0, name)",
		"\twhile _history.size() > history_length:",
		"\t\t_history.remove_at(_history.size() - 1)",
		"",
		"# Commits a chosen action: always On Decision Made; On Action Changed + On Action Started when",
		"# the choice differs from what is running (or, for a forced action, whenever force_start is set).",
		"func _decide(name: String, force_start: bool) -> void:",
		"\ton_decision_made.emit()",
		"\tif name != _current:",
		"\t\t_previous = _current",
		"\t\t_current = name",
		"\t\t_push_history(name)",
		"\t\ton_action_changed.emit()",
		"\t\ton_action_started.emit()",
		"\telif force_start:",
		"\t\ton_action_started.emit()",
		"",
		"# Weighted-random winner: sort by score, keep the top N, sample proportional to score.",
		"func _weighted_pick(candidates: Array) -> String:",
		"\tcandidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)",
		"\tvar n: int = mini(weighted_top_n, candidates.size())",
		"\tvar total: float = 0.0",
		"\tfor i: int in n:",
		"\t\ttotal += float(candidates[i].score)",
		"\tif total <= 0.0:",
		"\t\treturn str(candidates[0].name)",
		"\tvar r: float = _rng.randf() * total",
		"\tvar acc: float = 0.0",
		"\tfor i: int in n:",
		"\t\tacc += float(candidates[i].score)",
		"\t\tif r <= acc:",
		"\t\t\treturn str(candidates[i].name)",
		"\treturn str(candidates[n - 1].name)"
	]))
	sheet.events.append(block)
	# Seed the RNG once (weighted-random mode). Tests set _rng.seed directly for determinism.
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "_rng.randomize()"
	on_ready.actions.append(ready_body)
	sheet.events.append(on_ready)
	# Per-frame: tick active cooldowns down; fire On Cooldown Ended as each expires. Iterating a keys()
	# snapshot makes erasing mid-loop safe.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"for name: String in _cooldowns.keys():",
		"\t_cooldowns[name] = float(_cooldowns[name]) - delta",
		"\tif float(_cooldowns[name]) <= 0.0:",
		"\t\t_cooldowns.erase(name)",
		"\t\t_cooldown_action = name",
		"\t\ton_cooldown_ended.emit()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# --- Setup ---
	Lib.append_function(sheet, "add_action", "Add Action", "Utility AI", "Registers a candidate action the brain can choose. cooldown = seconds it rests after Mark Action Complete (0 = none); interruptible = whether Interrupt can cancel it; priority = an overall weight multiplier (1 = normal).",
		[["action_name", "String"], ["cooldown", "float"], ["interruptible", "bool"], ["priority", "float"]],
		"_actions[action_name] = {\"cooldown\": maxf(cooldown, 0.0), \"interruptible\": interruptible, \"enabled\": true, \"priority\": maxf(priority, 0.0), \"considerations\": []}")
	_default(sheet, "cooldown", "0.0")
	_default(sheet, "interruptible", "true")
	_default(sheet, "priority", "1.0")
	Lib.append_function(sheet, "add_consideration", "Add Consideration", "Utility AI", "Adds a scoring factor to an action: it reads a world-state input (0-1) and maps it through a response curve to a 0-1 score. An action's considerations all multiply together, so any near-zero factor vetoes it. weight sharpens (>1) or softens (<1) this factor; center + slope tune the logistic / threshold / bell curves.",
		[["action_name", "String"], ["input_key", "String"], ["curve", "String"], ["weight", "float"], ["curve_center", "float"], ["curve_slope", "float"]],
		"if not _actions.has(action_name):\n\treturn\n(_actions[action_name].considerations as Array).append({\"input\": input_key, \"curve\": curve, \"weight\": maxf(weight, 0.0), \"center\": curve_center, \"slope\": curve_slope})")
	_param_options(sheet, "curve", ["linear", "inverse", "quadratic", "inverse_quadratic", "logistic", "threshold", "bell"])
	_default(sheet, "curve", "linear")
	_default(sheet, "weight", "1.0")
	_default(sheet, "curve_center", "0.5")
	_default(sheet, "curve_slope", "1.0")
	Lib.append_function(sheet, "remove_action", "Remove Action", "Utility AI", "Removes an action (and any cooldown on it). Clears the current action if it was the one running.",
		[["action_name", "String"]],
		"_actions.erase(action_name)\n_cooldowns.erase(action_name)\nif _current == action_name:\n\t_current = \"\"")
	Lib.append_function(sheet, "set_action_enabled", "Set Action Enabled", "Utility AI", "Enables or disables an action without removing it (a disabled action is never chosen).",
		[["action_name", "String"], ["enabled", "bool"]],
		"if _actions.has(action_name):\n\t_actions[action_name].enabled = enabled")

	# --- World state ---
	Lib.append_function(sheet, "set_input", "Set Input", "Utility AI", "Writes a world-state value considerations read by key (usually normalized 0-1, e.g. hp_ratio). Push these right before Evaluate; an unset key reads as 0.",
		[["key", "String"], ["value", "float"]],
		"_world[key] = value")
	Lib.append_function(sheet, "clear_inputs", "Clear Inputs", "Utility AI", "Clears all world-state inputs on this brain.",
		[],
		"_world.clear()")

	# --- Decisioning ---
	Lib.append_function(sheet, "evaluate", "Evaluate", "Utility AI", "Scores every enabled, off-cooldown action from the current world state and picks a winner. Fires On Decision Made (plus On Action Changed + On Action Started when the choice changes), or On No Valid Action if nothing clears the minimum score. Call it on a timer or after a stimulus.",
		[],
		"\n".join(PackedStringArray([
			"var candidates: Array = []",
			"for name: String in _actions:",
			"\tvar action: Dictionary = _actions[name]",
			"\tif not bool(action.enabled) or _cooldowns.has(name):",
			"\t\tcontinue",
			"\tvar s: float = _score_action(name)",
			"\t# Inertia is an anti-jitter tie-breaker for the running action - it only nudges an already-",
			"\t# viable action, never rescues one its own considerations have vetoed below the threshold.",
			"\tif name == _current and s >= min_score:",
			"\t\ts += inertia_bonus",
			"\t_scores[name] = s",
			"\tif s < min_score:",
			"\t\tcontinue",
			"\tcandidates.append({\"name\": name, \"score\": s})",
			"if candidates.is_empty():",
			"\t_decision_score = 0.0",
			"\ton_no_valid_action.emit()",
			"\treturn",
			"var winner: String = \"\"",
			"if selection_mode == \"weighted_random\":",
			"\twinner = _weighted_pick(candidates)",
			"else:",
			"\tvar best: float = -1.0",
			"\tfor entry: Dictionary in candidates:",
			"\t\tif entry.score > best:",
			"\t\t\tbest = entry.score",
			"\t\t\twinner = str(entry.name)",
			"_decision_score = float(_scores.get(winner, 0.0))",
			"_decide(winner, false)"
		])))
	Lib.append_function(sheet, "force_action", "Force Action", "Utility AI", "Overrides the decision and starts an action directly (fires On Decision Made + On Action Started). Use it for cutscenes, scripted beats, or an emergency fallback, then return to Evaluate.",
		[["action_name", "String"]],
		"if not _actions.has(action_name):\n\treturn\n_decision_score = 0.0\n_decide(action_name, true)")
	Lib.append_function(sheet, "mark_complete", "Mark Action Complete", "Utility AI", "Marks the running action finished: fires On Action Completed, starts its cooldown if it has one, then re-evaluates. Call it when your gameplay finishes performing the action (it already re-evaluates, so do not also call Evaluate).",
		[],
		"if _current == \"\":\n\treturn\nvar name: String = _current\non_action_completed.emit()\nvar cd: float = float(_actions[name].cooldown) if _actions.has(name) else 0.0\nif cd > 0.0:\n\t_cooldowns[name] = cd\n\t_cooldown_action = name\n\ton_cooldown_started.emit()\nevaluate()")
	Lib.append_function(sheet, "interrupt", "Interrupt Action", "Utility AI", "Stops the running action if it is interruptible (fires On Action Interrupted) and re-evaluates. A non-interruptible action is left alone.",
		[],
		"if _current == \"\" or not _actions.has(_current):\n\treturn\nif not bool(_actions[_current].interruptible):\n\treturn\non_action_interrupted.emit()\nevaluate()")

	# --- Cooldowns ---
	Lib.append_function(sheet, "set_cooldown", "Set Action Cooldown", "Utility AI", "Starts (or, with seconds <= 0, clears) a cooldown on an action - so it cannot be chosen until the timer expires. Fires On Cooldown Started.",
		[["action_name", "String"], ["seconds", "float"]],
		"if seconds <= 0.0:\n\t_cooldowns.erase(action_name)\nelse:\n\t_cooldowns[action_name] = seconds\n\t_cooldown_action = action_name\n\ton_cooldown_started.emit()")
	Lib.append_function(sheet, "clear_cooldowns", "Clear Cooldowns", "Utility AI", "Clears every active cooldown on this brain (e.g. a refresh powerup).",
		[],
		"_cooldowns.clear()")

	# --- Conditions ---
	_condition(sheet, "is_running", "Is Running", "Utility AI", "Whether the brain's current action is this one.", [["action_name", "String"]],
		"return _current == action_name")
	_condition(sheet, "has_action", "Has Action", "Utility AI", "Whether an action is registered on this brain.", [["action_name", "String"]],
		"return _actions.has(action_name)")
	_condition(sheet, "is_action_enabled", "Is Action Enabled", "Utility AI", "Whether an action is registered and enabled.", [["action_name", "String"]],
		"return _actions.has(action_name) and bool(_actions[action_name].enabled)")
	_condition(sheet, "is_on_cooldown", "Is On Cooldown", "Utility AI", "Whether an action is currently cooling down.", [["action_name", "String"]],
		"return _cooldowns.has(action_name)")
	_condition(sheet, "was_last_action", "Was Last Action", "Utility AI", "Whether the previous action (before the current one) was this one - for anti-repeat / transition logic.", [["action_name", "String"]],
		"return _previous == action_name")
	_condition(sheet, "is_idle", "Is Idle", "Utility AI", "Whether the brain has no current action (nothing chosen yet, or the last evaluation found none valid).", [],
		"return _current == \"\"")

	# --- Expressions: decision state ---
	_expr(sheet, "current_action", "Current Action", "Utility AI", "The id of the action running now (\"\" if none).", [],
		"return _current", TYPE_STRING)
	_expr(sheet, "previous_action", "Previous Action", "Utility AI", "The id of the action that ran before the current one.", [],
		"return _previous", TYPE_STRING)
	_expr(sheet, "decision_score", "Decision Score", "Utility AI", "The winning action's score from the most recent Evaluate.", [],
		"return _decision_score", TYPE_FLOAT)
	_expr(sheet, "action_score", "Action Score", "Utility AI", "An action's score from the most recent Evaluate (0 if it was not scored).", [["action_name", "String"]],
		"return float(_scores.get(action_name, 0.0))", TYPE_FLOAT)
	_expr(sheet, "action_history", "Action History", "Utility AI", "A past action by index, most-recent first (0 = current). \"\" past the end.", [["index", "int"]],
		"return _history[index] if index >= 0 and index < _history.size() else \"\"", TYPE_STRING)

	# --- Expressions: registry + cooldowns + inputs ---
	_expr(sheet, "action_count", "Action Count", "Utility AI", "How many actions are registered on this brain.", [],
		"return _actions.size()", TYPE_INT)
	_expr(sheet, "cooldown_remaining", "Cooldown Remaining", "Utility AI", "Seconds left on an action's cooldown (0 if not cooling down).", [["action_name", "String"]],
		"return float(_cooldowns.get(action_name, 0.0))", TYPE_FLOAT)
	_expr(sheet, "cooldown_action", "Cooldown Action", "Utility AI", "The action whose cooldown just started or ended (inside On Cooldown Started / On Cooldown Ended).", [],
		"return _cooldown_action", TYPE_STRING)
	_expr(sheet, "get_input", "Get Input", "Utility AI", "The current value of a world-state input (0 if unset).", [["key", "String"]],
		"return float(_world.get(key, 0.0))", TYPE_FLOAT)

	return Lib.save_pack(sheet, "res://eventsheet_addons/utility_ai/utility_ai_addon")


## Pre-fills the last-appended ACE's parameter default, so the dialog opens with a usable value
## (authoring-time metadata only - defaults never appear in the compiled .gd).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


## Sets the dropdown options[] on the last-appended ACE's parameter, so e.g. curve becomes a
## named-curve picker instead of a free-text field.
static func _param_options(sheet: EventSheetResource, param_id: String, choices: Array) -> void:
	var typed: Array[String] = []
	for choice: Variant in choices:
		typed.append(str(choice))
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = typed


static func _condition(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = TYPE_BOOL
	sheet.functions.append(fn)


static func _expr(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String, ret: int) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = ret
	sheet.functions.append(fn)
