## @ace_tags(ai, decision)
## @ace_category("Utility AI")
@icon("res://eventsheet_addons/utility_ai/icon.svg")
class_name UtilityBrain
extends Node
## Scoring-based AI decisions that replace brittle if/else state machines. Register candidate actions, give each a few considerations (world-state inputs mapped through response curves), feed inputs with Set Input, call Evaluate, and the highest-scoring action wins and fires triggers your sheet reacts to.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("UtilityBrain behavior requires a Node parent.")

## @ace_trigger
## @ace_name("On Decision Made")
## @ace_category("Utility AI")
signal on_decision_made
## @ace_trigger
## @ace_name("On Action Started")
## @ace_category("Utility AI")
signal on_action_started
## @ace_trigger
## @ace_name("On Action Changed")
## @ace_category("Utility AI")
signal on_action_changed
## @ace_trigger
## @ace_name("On Action Completed")
## @ace_category("Utility AI")
signal on_action_completed
## @ace_trigger
## @ace_name("On Action Interrupted")
## @ace_category("Utility AI")
signal on_action_interrupted
## @ace_trigger
## @ace_name("On Cooldown Started")
## @ace_category("Utility AI")
signal on_cooldown_started
## @ace_trigger
## @ace_name("On Cooldown Ended")
## @ace_category("Utility AI")
signal on_cooldown_ended
## @ace_trigger
## @ace_name("On No Valid Action")
## @ace_category("Utility AI")
signal on_no_valid_action

# --- Designer knobs (tune the FEEL in the Inspector) ---
## How the winner is chosen. "highest" always takes the top score (predictable); "weighted_random" samples among the top few by score (varied, less robotic).
@export_enum("highest", "weighted_random") var selection_mode: String = "highest"
## Weighted-random only: how many of the highest-scoring actions to sample from.
@export_range(1, 10, 1) var weighted_top_n: int = 3
## Bonus added to the action already running, so the brain does not flip-flop between near-tied actions (0 = off).
@export_range(0.0, 1.0, 0.01) var inertia_bonus: float = 0.1
## Actions scoring below this are ignored; if nothing clears it, On No Valid Action fires.
@export_range(0.0, 1.0, 0.01) var min_score: float = 0.05
## Score given to an action with NO considerations - a natural low fallback (register an "idle" with none).
@export_range(0.0, 1.0, 0.01) var fallback_score: float = 0.1
## Smooths many-consideration actions so multiplying lots of 0-1 factors does not unfairly deflate them.
@export var score_compensation: bool = true
## How many past actions to remember (for the Action History expression and anti-repeat logic).
@export_range(1, 32, 1) var history_length: int = 5

# --- Internal state ---
# action name -> {cooldown:float, interruptible:bool, enabled:bool, priority:float, considerations:Array}.
# Each consideration is {input:String, curve:String, weight:float, center:float, slope:float}.
var _actions: Dictionary = {}
# World-state inputs, read at evaluation time; an unset key reads as 0.
var _world: Dictionary = {}
# action name -> remaining cooldown seconds (present only while cooling down).
var _cooldowns: Dictionary = {}
# Last-evaluated score per action (for the Action Score expression).
var _scores: Dictionary = {}
var _current: String = ""
var _previous: String = ""
var _decision_score: float = 0.0
# The action whose cooldown most recently started or ended (On Cooldown Started/Ended context).
var _cooldown_action: String = ""
# Recent started actions, most-recent first (index 0 = current).
var _history: PackedStringArray = PackedStringArray()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func _process(delta: float) -> void:
	for name: String in _cooldowns.keys():
		_cooldowns[name] = float(_cooldowns[name]) - delta
		if float(_cooldowns[name]) <= 0.0:
			_cooldowns.erase(name)
			_cooldown_action = name
			on_cooldown_ended.emit()

## @ace_action
## @ace_name("Add Action")
## @ace_category("Utility AI")
## @ace_description("Registers a candidate action the brain can choose. cooldown = seconds it rests after Mark Action Complete (0 = none); interruptible = whether Interrupt can cancel it; priority = an overall weight multiplier (1 = normal).")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.add_action({action_name}, {cooldown}, {interruptible}, {priority})")
func add_action(action_name: String, cooldown: float, interruptible: bool, priority: float) -> void:
	_actions[action_name] = {"cooldown": maxf(cooldown, 0.0), "interruptible": interruptible, "enabled": true, "priority": maxf(priority, 0.0), "considerations": []}

## @ace_action
## @ace_name("Add Consideration")
## @ace_category("Utility AI")
## @ace_description("Adds a scoring factor to an action: it reads a world-state input (0-1) and maps it through a response curve to a 0-1 score. An action's considerations all multiply together, so any near-zero factor vetoes it. weight sharpens (>1) or softens (<1) this factor; center + slope tune the logistic / threshold / bell curves.")
## @ace_param_options(curve linear, inverse, quadratic, inverse_quadratic, logistic, threshold, bell)
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.add_consideration({action_name}, {input_key}, {curve}, {weight}, {curve_center}, {curve_slope})")
func add_consideration(action_name: String, input_key: String, curve: String, weight: float, curve_center: float, curve_slope: float) -> void:
	if not _actions.has(action_name):
		return
	(_actions[action_name].considerations as Array).append({"input": input_key, "curve": curve, "weight": maxf(weight, 0.0), "center": curve_center, "slope": curve_slope})

## @ace_action
## @ace_name("Remove Action")
## @ace_category("Utility AI")
## @ace_description("Removes an action (and any cooldown on it). Clears the current action if it was the one running.")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.remove_action({action_name})")
func remove_action(action_name: String) -> void:
	_actions.erase(action_name)
	_cooldowns.erase(action_name)
	if _current == action_name:
		_current = ""

## @ace_action
## @ace_name("Set Action Enabled")
## @ace_category("Utility AI")
## @ace_description("Enables or disables an action without removing it (a disabled action is never chosen).")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.set_action_enabled({action_name}, {enabled})")
func set_action_enabled(action_name: String, enabled: bool) -> void:
	if _actions.has(action_name):
		_actions[action_name].enabled = enabled

## @ace_action
## @ace_name("Set Input")
## @ace_category("Utility AI")
## @ace_description("Writes a world-state value considerations read by key (usually normalized 0-1, e.g. hp_ratio). Push these right before Evaluate; an unset key reads as 0.")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.set_input({key}, {value})")
func set_input(key: String, value: float) -> void:
	_world[key] = value

## @ace_action
## @ace_name("Clear Inputs")
## @ace_category("Utility AI")
## @ace_description("Clears all world-state inputs on this brain.")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.clear_inputs()")
func clear_inputs() -> void:
	_world.clear()

## @ace_action
## @ace_name("Evaluate")
## @ace_category("Utility AI")
## @ace_description("Scores every enabled, off-cooldown action from the current world state and picks a winner. Fires On Decision Made (plus On Action Changed + On Action Started when the choice changes), or On No Valid Action if nothing clears the minimum score. Call it on a timer or after a stimulus.")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.evaluate()")
func evaluate() -> void:
	var candidates: Array = []
	for name: String in _actions:
		var action: Dictionary = _actions[name]
		if not bool(action.enabled) or _cooldowns.has(name):
			continue
		var s: float = _score_action(name)
		# Inertia is an anti-jitter tie-breaker for the running action - it only nudges an already-
		# viable action, never rescues one its own considerations have vetoed below the threshold.
		if name == _current and s >= min_score:
			s += inertia_bonus
		_scores[name] = s
		if s < min_score:
			continue
		candidates.append({"name": name, "score": s})
	if candidates.is_empty():
		_decision_score = 0.0
		on_no_valid_action.emit()
		return
	var winner: String = ""
	if selection_mode == "weighted_random":
		winner = _weighted_pick(candidates)
	else:
		var best: float = -1.0
		for entry: Dictionary in candidates:
			if entry.score > best:
				best = entry.score
				winner = str(entry.name)
	_decision_score = float(_scores.get(winner, 0.0))
	_decide(winner, false)

## @ace_action
## @ace_name("Force Action")
## @ace_category("Utility AI")
## @ace_description("Overrides the decision and starts an action directly (fires On Decision Made + On Action Started). Use it for cutscenes, scripted beats, or an emergency fallback, then return to Evaluate.")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.force_action({action_name})")
func force_action(action_name: String) -> void:
	if not _actions.has(action_name):
		return
	_decision_score = 0.0
	_decide(action_name, true)

## @ace_action
## @ace_name("Mark Action Complete")
## @ace_category("Utility AI")
## @ace_description("Marks the running action finished: fires On Action Completed, starts its cooldown if it has one, then re-evaluates. Call it when your gameplay finishes performing the action (it already re-evaluates, so do not also call Evaluate).")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.mark_complete()")
func mark_complete() -> void:
	if _current == "":
		return
	var name: String = _current
	on_action_completed.emit()
	var cd: float = float(_actions[name].cooldown) if _actions.has(name) else 0.0
	if cd > 0.0:
		_cooldowns[name] = cd
		_cooldown_action = name
		on_cooldown_started.emit()
	evaluate()

## @ace_action
## @ace_name("Interrupt Action")
## @ace_category("Utility AI")
## @ace_description("Stops the running action if it is interruptible (fires On Action Interrupted) and re-evaluates. A non-interruptible action is left alone.")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.interrupt()")
func interrupt() -> void:
	if _current == "" or not _actions.has(_current):
		return
	if not bool(_actions[_current].interruptible):
		return
	on_action_interrupted.emit()
	evaluate()

## @ace_action
## @ace_name("Set Action Cooldown")
## @ace_category("Utility AI")
## @ace_description("Starts (or, with seconds <= 0, clears) a cooldown on an action - so it cannot be chosen until the timer expires. Fires On Cooldown Started.")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.set_cooldown({action_name}, {seconds})")
func set_cooldown(action_name: String, seconds: float) -> void:
	if seconds <= 0.0:
		_cooldowns.erase(action_name)
	else:
		_cooldowns[action_name] = seconds
		_cooldown_action = action_name
		on_cooldown_started.emit()

## @ace_action
## @ace_name("Clear Cooldowns")
## @ace_category("Utility AI")
## @ace_description("Clears every active cooldown on this brain (e.g. a refresh powerup).")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.clear_cooldowns()")
func clear_cooldowns() -> void:
	_cooldowns.clear()

## @ace_condition
## @ace_name("Is Running")
## @ace_category("Utility AI")
## @ace_description("Whether the brain's current action is this one.")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.is_running({action_name})")
func is_running(action_name: String) -> bool:
	return _current == action_name

## @ace_condition
## @ace_name("Has Action")
## @ace_category("Utility AI")
## @ace_description("Whether an action is registered on this brain.")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.has_action({action_name})")
func has_action(action_name: String) -> bool:
	return _actions.has(action_name)

## @ace_condition
## @ace_name("Is Action Enabled")
## @ace_category("Utility AI")
## @ace_description("Whether an action is registered and enabled.")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.is_action_enabled({action_name})")
func is_action_enabled(action_name: String) -> bool:
	return _actions.has(action_name) and bool(_actions[action_name].enabled)

## @ace_condition
## @ace_name("Is On Cooldown")
## @ace_category("Utility AI")
## @ace_description("Whether an action is currently cooling down.")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.is_on_cooldown({action_name})")
func is_on_cooldown(action_name: String) -> bool:
	return _cooldowns.has(action_name)

## @ace_condition
## @ace_name("Was Last Action")
## @ace_category("Utility AI")
## @ace_description("Whether the previous action (before the current one) was this one - for anti-repeat / transition logic.")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.was_last_action({action_name})")
func was_last_action(action_name: String) -> bool:
	return _previous == action_name

## @ace_condition
## @ace_name("Is Idle")
## @ace_category("Utility AI")
## @ace_description("Whether the brain has no current action (nothing chosen yet, or the last evaluation found none valid).")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.is_idle()")
func is_idle() -> bool:
	return _current == ""

## @ace_expression
## @ace_name("Current Action")
## @ace_category("Utility AI")
## @ace_description("The id of the action running now ("" if none).")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.current_action()")
func current_action() -> String:
	return _current

## @ace_expression
## @ace_name("Previous Action")
## @ace_category("Utility AI")
## @ace_description("The id of the action that ran before the current one.")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.previous_action()")
func previous_action() -> String:
	return _previous

## @ace_expression
## @ace_name("Decision Score")
## @ace_category("Utility AI")
## @ace_description("The winning action's score from the most recent Evaluate.")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.decision_score()")
func decision_score() -> float:
	return _decision_score

## @ace_expression
## @ace_name("Action Score")
## @ace_category("Utility AI")
## @ace_description("An action's score from the most recent Evaluate (0 if it was not scored).")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.action_score({action_name})")
func action_score(action_name: String) -> float:
	return float(_scores.get(action_name, 0.0))

## @ace_expression
## @ace_name("Action History")
## @ace_category("Utility AI")
## @ace_description("A past action by index, most-recent first (0 = current). "" past the end.")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.action_history({index})")
func action_history(index: int) -> String:
	return _history[index] if index >= 0 and index < _history.size() else ""

## @ace_expression
## @ace_name("Action Count")
## @ace_category("Utility AI")
## @ace_description("How many actions are registered on this brain.")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.action_count()")
func action_count() -> int:
	return _actions.size()

## @ace_expression
## @ace_name("Cooldown Remaining")
## @ace_category("Utility AI")
## @ace_description("Seconds left on an action's cooldown (0 if not cooling down).")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.cooldown_remaining({action_name})")
func cooldown_remaining(action_name: String) -> float:
	return float(_cooldowns.get(action_name, 0.0))

## @ace_expression
## @ace_name("Cooldown Action")
## @ace_category("Utility AI")
## @ace_description("The action whose cooldown just started or ended (inside On Cooldown Started / On Cooldown Ended).")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.cooldown_action()")
func cooldown_action() -> String:
	return _cooldown_action

## @ace_expression
## @ace_name("Get Input")
## @ace_category("Utility AI")
## @ace_description("The current value of a world-state input (0 if unset).")
## @ace_icon("res://eventsheet_addons/utility_ai/icon.svg")
## @ace_codegen_template("$UtilityBrain.get_input({key})")
func get_input(key: String) -> float:
	return float(_world.get(key, 0.0))

func _curve_score(curve: String, x: float, center: float, slope: float) -> float:
	# Maps a world-state input (clamped 0-1) through a named response curve to a 0-1 score.
	var v: float = clampf(x, 0.0, 1.0)
	match curve:
		"linear": return v
		"inverse": return 1.0 - v
		"quadratic": return v * v
		"inverse_quadratic": return 1.0 - v * v
		"logistic": return 1.0 / (1.0 + exp(-maxf(slope, 0.001) * 10.0 * (v - center)))
		"threshold": return 1.0 if v >= center else 0.0
		"bell":
			var d: float = (v - center) / maxf(slope, 0.001)
			return exp(-d * d)
		_: return v

func _score_action(name: String) -> float:
	# An action's score: the product of its considerations (with the geometric-mean make-up
	# compensation), times its priority. A consideration-less action returns the flat fallback.
	var action: Dictionary = _actions[name]
	var cons: Array = action.considerations
	if cons.is_empty():
		return fallback_score * float(action.priority)
	var score: float = 1.0
	for c: Dictionary in cons:
		var raw: float = _curve_score(c.curve, float(_world.get(c.input, 0.0)), c.center, c.slope)
		score *= pow(clampf(raw, 0.0, 1.0), maxf(c.weight, 0.0))
	if score_compensation and cons.size() > 1:
		var mod: float = 1.0 - 1.0 / float(cons.size())
		score += (1.0 - score) * mod * score
	return score * float(action.priority)

func _push_history(name: String) -> void:
	# Records a newly-started action at the front of the bounded history ring.
	_history.insert(0, name)
	while _history.size() > history_length:
		_history.remove_at(_history.size() - 1)

func _decide(name: String, force_start: bool) -> void:
	# Commits a chosen action: always On Decision Made; On Action Changed + On Action Started when
	# the choice differs from what is running (or, for a forced action, whenever force_start is set).
	on_decision_made.emit()
	if name != _current:
		_previous = _current
		_current = name
		_push_history(name)
		on_action_changed.emit()
		on_action_started.emit()
	elif force_start:
		on_action_started.emit()

func _weighted_pick(candidates: Array) -> String:
	# Weighted-random winner: sort by score, keep the top N, sample proportional to score.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	var n: int = mini(weighted_top_n, candidates.size())
	var total: float = 0.0
	for i: int in n:
		total += float(candidates[i].score)
	if total <= 0.0:
		return str(candidates[0].name)
	var r: float = _rng.randf() * total
	var acc: float = 0.0
	for i: int in n:
		acc += float(candidates[i].score)
		if r <= acc:
			return str(candidates[i].name)
	return str(candidates[n - 1].name)

# UtilityBrain: attach one to each AI node. Add Actions, give each a few Considerations (an input mapped through a curve), Set Input every so often, then Evaluate. The best-scoring action wins and fires On Decision Made / On Action Started - your sheet performs it, then calls Mark Action Complete. This pack is an event sheet - extend it by editing it.
