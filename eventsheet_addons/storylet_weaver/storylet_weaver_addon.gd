## @ace_tags(narrative, storylet)
## @ace_category("Storylets")
## @ace_version(1.1.0)
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

# id -> {title, body, weight, cooldown, max_plays (-1=unlimited),
#        reqs:Array of {key,op,value,value_key(bool)}, choices:Array of {id,text,reqs,effects},
#        effects:Array of {op,key,value}, meta:Dictionary}.
var _lib: Dictionary = {}
# Flat quality store (the mirror of game state the requirements read).
var _qualities: Dictionary = {}
var _plays: Dictionary = {}
var _last_played: Dictionary = {}
# Ids in the order they were drawn (most recent LAST) - the recency requirement reads this.
var _selection_order: Array = []
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
	_lib[id] = _blank_story()
	_lib[id].title = title
	_lib[id].body = body

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
	_story(id).choices.append({"id": choice_id, "text": text, "reqs": [], "effects": []})

## @ace_action
## @ace_name("Add Choice Requirement")
## @ace_category("Storylets")
## @ace_description("A rule that must pass for this choice to be OFFERED, e.g. quality "gold" >= 10. Choices whose rules fail are hidden. Add the choice first with Add Choice.")
## @ace_param_options(op >=, >, <=, <, =, !=)
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.add_choice_requirement({id}, {choice_id}, {quality_key}, {op}, {value})")
func add_choice_requirement(id: String, choice_id: String, quality_key: String, op: String, value) -> void:
	var c: Dictionary = _choice(id, choice_id)
	if not c.is_empty():
		c.reqs.append({"key": quality_key, "op": op, "value": value})

## @ace_action
## @ace_name("Add Choice Effect")
## @ace_category("Storylets")
## @ace_description("A quality change applied automatically when this choice is picked - so a choice carries its own consequence instead of a per-choice branch. Add the choice first with Add Choice.")
## @ace_param_options(op { "key": "set", "label": "Set to" }, { "key": "inc", "label": "Increment by" }, { "key": "dec", "label": "Decrement by" }, { "key": "toggle", "label": "Toggle (0/1)" }, { "key": "delete", "label": "Delete key" })
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.add_choice_effect({id}, {choice_id}, {op}, {key}, {value})")
func add_choice_effect(id: String, choice_id: String, op: String, key: String, value) -> void:
	var c: Dictionary = _choice(id, choice_id)
	if not c.is_empty():
		c.effects.append({"op": op, "key": key, "value": value})

## @ace_action
## @ace_name("Add Effect")
## @ace_category("Storylets")
## @ace_description("A quality change applied automatically when this storylet is DRAWN - so a beat carries its own consequence. Define the storylet first.")
## @ace_param_options(op { "key": "set", "label": "Set to" }, { "key": "inc", "label": "Increment by" }, { "key": "dec", "label": "Decrement by" }, { "key": "toggle", "label": "Toggle (0/1)" }, { "key": "delete", "label": "Delete key" })
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.add_effect({id}, {op}, {key}, {value})")
func add_effect(id: String, op: String, key: String, value) -> void:
	_story(id).effects.append({"op": op, "key": key, "value": value})

## @ace_action
## @ace_name("Add Meta")
## @ace_category("Storylets")
## @ace_description("Attaches an arbitrary key-value to a storylet (a speaker, a portrait, a sound). Read it back with Active Meta / Storylet Meta - the engine never interprets it.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.add_meta({id}, {key}, {value})")
func add_meta(id: String, key: String, value) -> void:
	_story(id).meta[key] = value

## @ace_action
## @ace_name("Add Requirement (Key vs Key)")
## @ace_category("Storylets")
## @ace_description("A rule comparing one quality against ANOTHER quality's value, e.g. gold >= price - so a storylet reacts to a relationship between stats without hard-coding the number.")
## @ace_param_options(op >=, >, <=, <, =, !=)
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.add_requirement_key({id}, {quality_key}, {op}, {other_key})")
func add_requirement_key(id: String, quality_key: String, op: String, other_key: String) -> void:
	_story(id).reqs.append({"key": quality_key, "op": op, "value": other_key, "value_key": true})

## @ace_action
## @ace_name("Add Chance Requirement")
## @ace_category("Storylets")
## @ace_description("A probability gate: the storylet is eligible only percent% of the time, re-rolled on every Evaluate/Draw. Use it to make a beat show only sometimes.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.add_chance_requirement({id}, {percent})")
func add_chance_requirement(id: String, percent: float) -> void:
	_story(id).reqs.append({"op": "chance", "value": clampf(percent, 0.0, 100.0)})

## @ace_action
## @ace_name("Add Recency Requirement")
## @ace_category("Storylets")
## @ace_description("An anti-repeat (or must-be-recent) gate by DRAW history: eligible only when this storylet was / was not among the last N drawn storylets.")
## @ace_param_options(mode { "key": "not_recent", "label": "was NOT drawn recently" }, { "key": "recent", "label": "was drawn recently" })
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.add_recency_requirement({id}, {mode}, {within})")
func add_recency_requirement(id: String, mode: String, within: int) -> void:
	_story(id).reqs.append({"op": mode, "value": within})

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
## @ace_description("Resolves the active storylet's choice by id: applies that choice's effects, fires On Choice Made, then clears the active storylet. Only an ELIGIBLE choice resolves. React inside On Choice Made.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.choose({choice_id})")
func choose(choice_id: String) -> void:
	if _active.is_empty():
		return
	var picked: Dictionary = _choice(_active, choice_id)
	if picked.is_empty() or not _choice_ok(picked, _active):
		return
	for eff: Dictionary in picked.get("effects", []):
		_apply_effect(eff)
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
## @ace_name("Load From Resource")
## @ace_category("Storylets")
## @ace_description("Registers a whole storybook from a StoryletResource asset (a .tres you fill in the Inspector) in one step, instead of a wall of Define Storylet actions. Additive: it defines each storylet and adds its requirements, choices, effects and meta, so you can still tweak the library with the discrete actions afterwards.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.load_from_resource({resource})")
func load_from_resource(resource: Resource) -> void:
	if resource == null:
		return
	for row: Dictionary in _rows(resource, "storylets"):
		var sid: String = str(row.get("id", ""))
		if sid.is_empty():
			continue
		define_storylet(sid, str(row.get("title", "")), str(row.get("body", "")))
		_lib[sid].weight = maxf(_num(row.get("weight", 1.0)), 0.0)
		_lib[sid].cooldown = maxf(_num(row.get("cooldown", 0.0)), 0.0)
		_lib[sid].max_plays = _num(row.get("max_plays", -1.0))
	# Rows reference a storylet (or a choice on it) by id; a row naming an undefined storylet is
	# skipped rather than conjuring a blank one.
	for row: Dictionary in _rows(resource, "requirements"):
		if _lib.has(str(row.get("storylet", ""))):
			_lib[str(row.get("storylet", ""))].reqs.append(_req_from_row(row))
	for row: Dictionary in _rows(resource, "choices"):
		if _lib.has(str(row.get("storylet", ""))):
			add_choice(str(row.get("storylet", "")), str(row.get("choice_id", "")), str(row.get("text", "")))
	for row: Dictionary in _rows(resource, "choice_requirements"):
		var cr: Dictionary = _choice(str(row.get("storylet", "")), str(row.get("choice_id", "")))
		if not cr.is_empty():
			cr.reqs.append(_req_from_row(row))
	for row: Dictionary in _rows(resource, "effects"):
		if _lib.has(str(row.get("storylet", ""))):
			_lib[str(row.get("storylet", ""))].effects.append(_effect_from_row(row))
	for row: Dictionary in _rows(resource, "choice_effects"):
		var ce: Dictionary = _choice(str(row.get("storylet", "")), str(row.get("choice_id", "")))
		if not ce.is_empty():
			ce.effects.append(_effect_from_row(row))
	for row: Dictionary in _rows(resource, "meta"):
		if _lib.has(str(row.get("storylet", ""))):
			_lib[str(row.get("storylet", ""))].meta[str(row.get("key", ""))] = row.get("value", "")

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
## @ace_description("Clears every play count, cooldown, and the recency draw-history (e.g. on New Game).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.reset_all_history()")
func reset_all_history() -> void:
	_plays.clear()
	_last_played.clear()
	_selection_order.clear()

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
## @ace_description("How many ELIGIBLE choices the active storylet offers (choices whose requirements fail are not counted).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.active_choice_count()")
func active_choice_count() -> int:
	return _active_choices().size()

## @ace_expression
## @ace_name("Choice Id At")
## @ace_category("Storylets")
## @ace_description("The id of the eligible choice at a position on the active storylet.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.choice_id_at({index})")
func choice_id_at(index: int) -> String:
	var c: Array = _active_choices()
	return str(c[index].id) if index >= 0 and index < c.size() else ""

## @ace_expression
## @ace_name("Choice Text At")
## @ace_category("Storylets")
## @ace_description("The label of the eligible choice at a position on the active storylet.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.choice_text_at({index})")
func choice_text_at(index: int) -> String:
	var c: Array = _active_choices()
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
## @ace_name("Forecast Storylet Effects")
## @ace_category("Storylets")
## @ace_description("A readable preview of the quality changes a storylet applies when drawn, e.g. "gold -10, gate_open = 1". Never changes anything - put it on a button.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.forecast_storylet_effects({id})")
func forecast_storylet_effects(id: String) -> String:
	return _forecast(_lib[id].get("effects", [])) if _lib.has(id) else ""

## @ace_expression
## @ace_name("Forecast Choice Effects")
## @ace_category("Storylets")
## @ace_description("A readable preview of the quality changes a choice applies when picked. Pass Active Id() for the current storylet. Never changes anything.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.forecast_choice_effects({id}, {choice_id})")
func forecast_choice_effects(id: String, choice_id: String) -> String:
	var c: Dictionary = _choice(id, choice_id)
	return _forecast(c.get("effects", [])) if not c.is_empty() else ""

## @ace_expression
## @ace_name("Active Meta")
## @ace_category("Storylets")
## @ace_description("A meta value on the active storylet ("" if unset).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.active_meta({key})")
func active_meta(key: String) -> String:
	return str(_lib[_active].meta.get(key, "")) if _lib.has(_active) else ""

## @ace_expression
## @ace_name("Storylet Meta")
## @ace_category("Storylets")
## @ace_description("A meta value on any registered storylet by id, without drawing it ("" if unset).")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.storylet_meta({id}, {key})")
func storylet_meta(id: String, key: String) -> String:
	return str(_lib[id].meta.get(key, "")) if _lib.has(id) else ""

## @ace_expression
## @ace_name("Available Meta")
## @ace_category("Storylets")
## @ace_description("A meta value on the eligible storylet at a position in the available list.")
## @ace_icon("res://eventsheet_addons/storylet_weaver/icon.svg")
## @ace_codegen_template("Storylets.available_meta({index}, {key})")
func available_meta(index: int, key: String) -> String:
	if index < 0 or index >= _available.size():
		return ""
	return str(_lib[_available[index]].meta.get(key, ""))

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

func _blank_story() -> Dictionary:
	return {"title": "", "body": "", "weight": 1.0, "cooldown": 0.0, "max_plays": -1.0, "reqs": [], "choices": [], "effects": [], "meta": {}}

func _story(id: String) -> Dictionary:
	if not _lib.has(id):
		_lib[id] = _blank_story()
	return _lib[id]

func _choice(id: String, choice_id: String) -> Dictionary:
	# The draft choice with this id on a storylet, or an empty dict.
	for c: Dictionary in _story(id).choices:
		if str(c.id) == choice_id:
			return c
	return {}

func _num(v) -> float:
	if v is float or v is int:
		return float(v)
	if v is String and (v as String).is_valid_float():
		return (v as String).to_float()
	return 0.0

func _text(v) -> String:
	return "" if v == null else str(v)

func _req_ok(req: Dictionary, id: String) -> bool:
	# One requirement against the current qualities. Missing quality = 0 / "". `id` is the storylet
	# being evaluated (recency reads it). chance re-rolls each call; recency reads the draw history;
	# a key-vs-key rule (value_key) compares the quality against ANOTHER quality's current value.
	match str(req.op):
		"chance":
			return _rand_float() * 100.0 < _num(req.value)
		"recent", "not_recent":
			var within: int = int(_num(req.value))
			var recent: bool = _selection_order.slice(maxi(_selection_order.size() - within, 0)).has(id)
			return recent if str(req.op) == "recent" else not recent
	var have: Variant = _qualities.get(req.key, null)
	var want: Variant = _qualities.get(req.value, null) if bool(req.get("value_key", false)) else req.value
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
		if not _req_ok(req, id):
			return false
	return true

func _apply_effect(eff: Dictionary) -> void:
	# Applies one effect to the qualities store (the storylet/choice's declared consequence).
	var key: String = str(eff.get("key", ""))
	if key.is_empty():
		return
	match str(eff.get("op", "set")):
		"set":
			_qualities[key] = eff.get("value", 0)
		"inc":
			_qualities[key] = _num(_qualities.get(key, 0.0)) + _num(eff.get("value", 0))
		"dec":
			_qualities[key] = _num(_qualities.get(key, 0.0)) - _num(eff.get("value", 0))
		"toggle":
			_qualities[key] = 0.0 if _num(_qualities.get(key, 0.0)) != 0.0 else 1.0
		"delete":
			_qualities.erase(key)

func _forecast(effects: Array) -> String:
	# A readable one-line preview of a list of effects, e.g. "gold -10, gate_open = 1". Never mutates.
	var parts: PackedStringArray = PackedStringArray()
	for eff: Dictionary in effects:
		var key: String = str(eff.get("key", ""))
		match str(eff.get("op", "set")):
			"set":
				parts.append("%s = %s" % [key, str(eff.get("value", 0))])
			"inc":
				parts.append("%s +%s" % [key, str(eff.get("value", 0))])
			"dec":
				parts.append("%s -%s" % [key, str(eff.get("value", 0))])
			"toggle":
				parts.append("toggle %s" % key)
			"delete":
				parts.append("clear %s" % key)
	return ", ".join(parts)

func _choice_ok(choice: Dictionary, id: String) -> bool:
	# Whether a choice's own requirements pass right now (only eligible choices are shown/pickable).
	for req: Dictionary in choice.get("reqs", []):
		if not _req_ok(req, id):
			return false
	return true

func _active_choices() -> Array:
	# The active storylet's choices that pass their requirements, in order.
	if not _lib.has(_active):
		return []
	var out: Array = []
	for c: Dictionary in _lib[_active].choices:
		if _choice_ok(c, _active):
			out.append(c)
	return out

func _rows(resource: Object, field: String) -> Array:
	# A grid field off a StoryletResource (or any duck-typed resource), as an Array of row dicts.
	var v: Variant = resource.get(field)
	return v if v is Array else []

func _op_symbol(op: String) -> String:
	# A StoryletResource op column stores a WORD token (a table dropdown cannot hold ">=", whose "="
	# is a reserved marker char), so map it to the symbol the eligibility check uses. A symbol that
	# arrives verbatim passes straight through.
	match op:
		"gte": return ">="
		"gt": return ">"
		"lte": return "<="
		"lt": return "<"
		"eq": return "="
		"neq": return "!="
	return op

func _req_from_row(row: Dictionary) -> Dictionary:
	# Turns one Requirements-grid row into a requirement dict the eligibility check understands -
	# a comparison (optionally key-vs-key), a chance gate, or a recency gate.
	var op: String = str(row.get("op", "gte"))
	match op:
		"chance":
			return {"op": "chance", "value": _num(row.get("value", 0))}
		"recent", "not_recent":
			return {"op": op, "value": int(_num(row.get("value", 0)))}
	var req: Dictionary = {"key": str(row.get("key", "")), "op": _op_symbol(op), "value": row.get("value", "")}
	if bool(row.get("value_is_key", false)):
		req["value_key"] = true
	return req

func _effect_from_row(row: Dictionary) -> Dictionary:
	# Turns one Effects-grid row into an effect dict.
	return {"op": str(row.get("op", "set")), "key": str(row.get("key", "")), "value": row.get("value", "")}

func _activate(id: String) -> void:
	# Marks a storylet as played now: records the play + cooldown start + active + draw history,
	# applies its on-draw effects, and fires the trigger.
	_plays[id] = _plays.get(id, 0) + 1
	_last_played[id] = _clock
	_selection_order.append(id)
	for eff: Dictionary in _lib[id].get("effects", []):
		_apply_effect(eff)
	_active = id
	on_storylet_drawn.emit()

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	return {
		"qualities": _qualities.duplicate(true),
		"plays": _plays.duplicate(true),
		"selection_order": _selection_order.duplicate()
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_qualities = (state.get("qualities", {}) as Dictionary).duplicate(true)
	_plays = (state.get("plays", {}) as Dictionary).duplicate(true)
	_selection_order = (state.get("selection_order", []) as Array).duplicate()

# Storylet Weaver: register as the Storylets autoload. Define small story fragments with Add Requirement rules, mirror your game state into qualities with Set Quality, then Draw to get the best eligible storylet and react with On Storylet Drawn. This pack is an event sheet - extend it by editing it.
