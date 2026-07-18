## @ace_tags(narrative, storylet)
## @ace_category("Storylets")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/storylet_weaver/icon.svg")
class_name StoryletsAddon
extends Node
## A quality-based narrative engine, shipped as the Storylets autoload singleton. Register many small storylets that each carry their own requirements, then call Draw to get the best eligible one - adding a story beat is one more storylet, not surgery on a giant if/else web.

## @ace_trigger
## @ace_name("On Storylet Drawn")
## @ace_category("Storylets")
signal on_storylet_drawn
## @ace_trigger
## @ace_name("On Choice Made")
## @ace_category("Storylets")
signal on_choice_made
## @ace_trigger
## @ace_name("On None Available")
## @ace_category("Storylets")
signal on_none_available

# id -> {title, body, weight, cooldown, max_plays (-1=unlimited), reqs:Array of {key,op,value}, choices:Array of {id,text}}.
var _lib: Dictionary = {}
# Flat quality store (the mirror of game state the requirements read).
var _qualities: Dictionary = {}
var _plays: Dictionary = {}
var _last_played: Dictionary = {}
var _available: Array = []
var _active: String = ""
var _chosen: String = ""
# Internal monotonic clock (seconds), ticked in _process so cooldowns need no wiring.
var _clock: float = 0.0
var _use_shared: bool = false

func _process(delta: float) -> void:
	_clock += delta

## @ace_action
## @ace_featured
## @ace_name("Define Storylet")
## @ace_category("Storylets")
## @ace_description("Registers (or replaces) a storylet: an id plus the title + body text your game shows.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.define_storylet({id}, {title}, {body})")
func define_storylet(id: String, title: String, body: String) -> void:
	_lib[id] = {"title": title, "body": body, "weight": 1.0, "cooldown": 0.0, "max_plays": -1.0, "reqs": [], "choices": []}

## @ace_action
## @ace_name("Set Storylet Weight")
## @ace_category("Storylets")
## @ace_description("How strongly this storylet is preferred when several are eligible (higher = picked first / likelier).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.set_storylet_weight({id}, {weight})")
func set_storylet_weight(id: String, weight: float) -> void:
	_story(id).weight = maxf(weight, 0.0)

## @ace_action
## @ace_name("Set Storylet Cooldown")
## @ace_category("Storylets")
## @ace_description("Seconds this storylet is ineligible after it plays (0 = no cooldown).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.set_storylet_cooldown({id}, {seconds})")
func set_storylet_cooldown(id: String, seconds: float) -> void:
	_story(id).cooldown = maxf(seconds, 0.0)

## @ace_action
## @ace_name("Set Max Plays")
## @ace_category("Storylets")
## @ace_description("How many times it may ever play (-1 = unlimited, 1 = a one-shot).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.set_storylet_max_plays({id}, {max_plays})")
func set_storylet_max_plays(id: String, max_plays: float) -> void:
	_story(id).max_plays = max_plays

## @ace_action
## @ace_name("Add Requirement")
## @ace_category("Storylets")
## @ace_description("A rule this storylet needs to be eligible, e.g. quality "courage" >= 3. A missing quality counts as 0 (or "").")
## @ace_param_options(op >=, >, <=, <, =, !=)
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.add_requirement({id}, {quality_key}, {op}, {value})")
func add_requirement(id: String, quality_key: String, op: String, value) -> void:
	_story(id).reqs.append({"key": quality_key, "op": op, "value": value})

## @ace_action
## @ace_name("Add Choice")
## @ace_category("Storylets")
## @ace_description("Adds a labelled choice the player can pick on this storylet (resolve it with Choose).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.add_choice({id}, {choice_id}, {text})")
func add_choice(id: String, choice_id: String, text: String) -> void:
	_story(id).choices.append({"id": choice_id, "text": text})

## @ace_action
## @ace_name("Set Quality")
## @ace_category("Storylets")
## @ace_description("Stores a quality value (a number like courage=3, or text like location="tavern"). Requirements read these.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.set_quality({key}, {value})")
func set_quality(key: String, value) -> void:
	_qualities[key] = value

## @ace_action
## @ace_name("Increment Quality")
## @ace_category("Storylets")
## @ace_description("Adds to a numeric quality (creating it at 0 if new).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.increment_quality({key}, {amount})")
func increment_quality(key: String, amount: float) -> void:
	_qualities[key] = _num(_qualities.get(key, 0.0)) + amount

## @ace_action
## @ace_name("Clear Quality")
## @ace_category("Storylets")
## @ace_description("Removes a quality key.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.clear_quality({key})")
func clear_quality(key: String) -> void:
	_qualities.erase(key)

## @ace_action
## @ace_name("Evaluate")
## @ace_category("Storylets")
## @ace_description("Rebuilds the available list: every eligible storylet, ordered by weight (highest first). Use the Available expressions to show a menu.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.evaluate()")
func evaluate() -> void:
	_available.clear()
	for id: String in _lib:
		if _eligible(id):
			_available.append(id)
	_available.sort_custom(func(a: String, b: String) -> bool: return _lib[a].weight > _lib[b].weight)

## @ace_action
## @ace_featured
## @ace_name("Draw")
## @ace_category("Storylets")
## @ace_description("Evaluates, then activates the highest-weight eligible storylet and fires On Storylet Drawn (or On None Available if nothing qualifies).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.draw()")
func draw() -> void:
	evaluate()
	if _available.is_empty():
		on_none_available.emit()
		return
	_activate(str(_available[0]))

## @ace_action
## @ace_name("Draw Weighted")
## @ace_category("Storylets")
## @ace_description("Like Draw, but picks randomly among the eligible storylets in proportion to their weight (for variety).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.draw_weighted()")
func draw_weighted() -> void:
	evaluate()
	if _available.is_empty():
		on_none_available.emit()
		return
	var total: float = 0.0
	for id: String in _available:
		total += maxf(_lib[id].weight, 0.0)
	if total <= 0.0:
		_activate(str(_available[0]))
		return
	var r: float = _rand_float() * total
	for id: String in _available:
		r -= maxf(_lib[id].weight, 0.0)
		if r <= 0.0:
			_activate(id)
			return
	_activate(str(_available[_available.size() - 1]))

## @ace_action
## @ace_name("Choose")
## @ace_category("Storylets")
## @ace_description("Resolves the active storylet's choice by id (fires On Choice Made, then clears the active storylet). React inside On Choice Made.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.choose({choice_id})")
func choose(choice_id: String) -> void:
	if _active.is_empty():
		return
	_chosen = choice_id
	on_choice_made.emit()
	_active = ""

## @ace_action
## @ace_name("Use Advanced Random")
## @ace_category("Storylets")
## @ace_description("When on, Draw Weighted picks using the shared AdvancedRandom autoload instead of Godot's own randf(), so one seed drives your whole game's randomness. When off (the default) it uses randf(). Needs the Advanced Random pack installed (it safely falls back if not).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.use_advanced_random({enabled})")
func use_advanced_random(enabled: bool) -> void:
	_use_shared = enabled

## @ace_action
## @ace_name("Dismiss")
## @ace_category("Storylets")
## @ace_description("Clears the active storylet without making a choice (the play still counted).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.dismiss()")
func dismiss() -> void:
	_active = ""

## @ace_action
## @ace_name("Reset Play Count")
## @ace_category("Storylets")
## @ace_description("Lets a one-shot or limited storylet play again.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.reset_play_count({id})")
func reset_play_count(id: String) -> void:
	_plays.erase(id)
	_last_played.erase(id)

## @ace_action
## @ace_name("Reset All History")
## @ace_category("Storylets")
## @ace_description("Clears every play count + cooldown (e.g. on New Game).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.reset_all_history()")
func reset_all_history() -> void:
	_plays.clear()
	_last_played.clear()

## @ace_condition
## @ace_name("Has Active Storylet")
## @ace_category("Storylets")
## @ace_description("Whether a storylet is currently active (drawn, not yet resolved).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.has_active()")
func has_active() -> bool:
	return not _active.is_empty()

## @ace_condition
## @ace_name("Is Available")
## @ace_category("Storylets")
## @ace_description("Whether a storylet is in the current available list (call Evaluate first).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.is_available({id})")
func is_available(id: String) -> bool:
	return id in _available

## @ace_condition
## @ace_name("Has Quality")
## @ace_category("Storylets")
## @ace_description("Whether a quality key has been set.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.has_quality({key})")
func has_quality(key: String) -> bool:
	return _qualities.has(key)

## @ace_condition
## @ace_name("Has Been Played")
## @ace_category("Storylets")
## @ace_description("Whether a storylet has played at least once.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.has_been_played({id})")
func has_been_played(id: String) -> bool:
	return _plays.get(id, 0) > 0

## @ace_condition
## @ace_name("Is On Cooldown")
## @ace_category("Storylets")
## @ace_description("Whether a storylet is still cooling down.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.is_on_cooldown({id})")
func is_on_cooldown(id: String) -> bool:
	var s: Dictionary = _lib.get(id, {})
	return s.get("cooldown", 0.0) > 0.0 and _last_played.has(id) and _clock - _last_played[id] < s.get("cooldown", 0.0)

## @ace_condition
## @ace_name("Is Library Empty")
## @ace_category("Storylets")
## @ace_description("Whether no storylets are registered.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.is_library_empty()")
func is_library_empty() -> bool:
	return _lib.is_empty()

## @ace_expression
## @ace_name("Quality Number")
## @ace_category("Storylets")
## @ace_description("A quality as a number (0 if unset).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.quality_number({key})")
func quality_number(key: String) -> float:
	return _num(_qualities.get(key, 0.0))

## @ace_expression
## @ace_name("Quality Text")
## @ace_category("Storylets")
## @ace_description("A quality as text ("" if unset).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.quality_text({key})")
func quality_text(key: String) -> String:
	return _text(_qualities.get(key, ""))

## @ace_expression
## @ace_name("Available Count")
## @ace_category("Storylets")
## @ace_description("How many storylets are eligible (after Evaluate/Draw).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.available_count()")
func available_count() -> int:
	return _available.size()

## @ace_expression
## @ace_name("Available Id")
## @ace_category("Storylets")
## @ace_description("The eligible storylet id at a position ("" out of range).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.available_id({index})")
func available_id(index: int) -> String:
	return str(_available[index]) if index >= 0 and index < _available.size() else ""

## @ace_expression
## @ace_name("Available Title")
## @ace_category("Storylets")
## @ace_description("The title of the eligible storylet at a position.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.available_title({index})")
func available_title(index: int) -> String:
	return str(_lib[_available[index]].title) if index >= 0 and index < _available.size() else ""

## @ace_expression
## @ace_name("Active Id")
## @ace_category("Storylets")
## @ace_description("The active storylet id ("" if none).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.active_id()")
func active_id() -> String:
	return _active

## @ace_expression
## @ace_name("Active Title")
## @ace_category("Storylets")
## @ace_description("The active storylet's title.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.active_title()")
func active_title() -> String:
	return str(_lib[_active].title) if _lib.has(_active) else ""

## @ace_expression
## @ace_name("Active Body")
## @ace_category("Storylets")
## @ace_description("The active storylet's body text.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.active_body()")
func active_body() -> String:
	return str(_lib[_active].body) if _lib.has(_active) else ""

## @ace_expression
## @ace_name("Choice Count")
## @ace_category("Storylets")
## @ace_description("How many choices the active storylet offers.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.active_choice_count()")
func active_choice_count() -> int:
	return int(_lib[_active].choices.size()) if _lib.has(_active) else 0

## @ace_expression
## @ace_name("Choice Id At")
## @ace_category("Storylets")
## @ace_description("The choice id at a position on the active storylet.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.choice_id_at({index})")
func choice_id_at(index: int) -> String:
	if not _lib.has(_active):
		return ""
	var c: Array = _lib[_active].choices
	return str(c[index].id) if index >= 0 and index < c.size() else ""

## @ace_expression
## @ace_name("Choice Text At")
## @ace_category("Storylets")
## @ace_description("The choice label at a position on the active storylet.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.choice_text_at({index})")
func choice_text_at(index: int) -> String:
	if not _lib.has(_active):
		return ""
	var c: Array = _lib[_active].choices
	return str(c[index].text) if index >= 0 and index < c.size() else ""

## @ace_expression
## @ace_name("Chosen Id")
## @ace_category("Storylets")
## @ace_description("The choice just picked (inside On Choice Made).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.chosen_id()")
func chosen_id() -> String:
	return _chosen

## @ace_expression
## @ace_name("Play Count")
## @ace_category("Storylets")
## @ace_description("How many times a storylet has played.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.play_count({id})")
func play_count(id: String) -> int:
	return _plays.get(id, 0)

## @ace_expression
## @ace_name("Cooldown Remaining")
## @ace_category("Storylets")
## @ace_description("Seconds left on a storylet's cooldown (0 if ready).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.cooldown_remaining({id})")
func cooldown_remaining(id: String) -> float:
	var s: Dictionary = _lib.get(id, {})
	if s.get("cooldown", 0.0) <= 0.0 or not _last_played.has(id):
		return 0.0
	return maxf(s.cooldown - (_clock - _last_played[id]), 0.0)

## @ace_expression
## @ace_name("Storylet Count")
## @ace_category("Storylets")
## @ace_description("How many storylets are registered.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.storylet_count()")
func storylet_count() -> int:
	return _lib.size()

func _rand_float() -> float:
	# Randomness source: the shared AdvancedRandom autoload when Use Advanced Random is on and the
	# pack is installed, otherwise Godot's own randf() (the default - unchanged behaviour).
	if _use_shared and is_inside_tree():
		var shared: Node = get_node_or_null("/root/AdvancedRandom")
		if shared != null:
			return shared.random_value()
	return randf()

func _story(id: String) -> Dictionary:
	if not _lib.has(id):
		_lib[id] = {"title": "", "body": "", "weight": 1.0, "cooldown": 0.0, "max_plays": -1.0, "reqs": [], "choices": []}
	return _lib[id]

func _num(v) -> float:
	if v is float or v is int:
		return float(v)
	if v is String and (v as String).is_valid_float():
		return (v as String).to_float()
	return 0.0

func _text(v) -> String:
	return "" if v == null else str(v)

func _req_ok(req: Dictionary) -> bool:
	# One requirement against the current qualities. Missing quality = 0 / "".
	var have: Variant = _qualities.get(req.key, null)
	var want: Variant = req.value
	var textual: bool = want is String and not (want as String).is_valid_float()
	match str(req.op):
		"=":
			return _text(have) == _text(want) if textual else is_equal_approx(_num(have), _num(want))
		"!=":
			return _text(have) != _text(want) if textual else not is_equal_approx(_num(have), _num(want))
		">":
			return _num(have) > _num(want)
		">=":
			return _num(have) >= _num(want)
		"<":
			return _num(have) < _num(want)
		"<=":
			return _num(have) <= _num(want)
	return true

func _eligible(id: String) -> bool:
	# Whether a storylet passes ALL requirements, its play limit, and its cooldown right now.
	var s: Dictionary = _lib[id]
	if s.max_plays >= 0.0 and _plays.get(id, 0) >= int(s.max_plays):
		return false
	if s.cooldown > 0.0 and _last_played.has(id) and _clock - _last_played[id] < s.cooldown:
		return false
	for req: Dictionary in s.reqs:
		if not _req_ok(req):
			return false
	return true

func _activate(id: String) -> void:
	# Marks a storylet as played now: records the play + cooldown start + active, fires the trigger.
	_plays[id] = _plays.get(id, 0) + 1
	_last_played[id] = _clock
	_active = id
	on_storylet_drawn.emit()

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	return {
		"qualities": _qualities.duplicate(true),
		"plays": _plays.duplicate(true)
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_qualities = (state.get("qualities", {}) as Dictionary).duplicate(true)
	_plays = (state.get("plays", {}) as Dictionary).duplicate(true)

# Storylet Weaver: register as the Storylets autoload. Define small story fragments with Add Requirement rules, mirror your game state into qualities with Set Quality, then Draw to get the best eligible storylet and react with On Storylet Drawn. This pack is an event sheet - extend it by editing it.
