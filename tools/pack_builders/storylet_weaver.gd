# Pack builder - storylet_weaver (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Storylet Weaver: quality-based narrative (QBN) as an AUTOLOAD sheet (Storylets). Instead of one
## giant branching web of if/else, you register many small self-contained STORYLETS, each declaring
## its own requirements against a flat "qualities" store; call Draw to get the best eligible one.
## Ported from the Construct 3 addon, Godot-native + beginner-friendly:
##  - Build storylets with discrete typed ACEs (Define Storylet / Add Requirement / Add Choice), NOT
##    the JSON-string blobs the C3 version used.
##  - A MISSING quality reads as 0 (numeric) or "" (text) - so `courage >= 3` on an unset quality is
##    simply false, instead of the C3 addon's surprising "every op except != fails" rule.
##  - Cooldowns run off an internal game clock that ticks automatically (delta each frame), so
##    "once per 30 seconds" just works with no clock wiring.
##  - Draw = evaluate + pick + activate in one call (the 5-second path); Evaluate + the available list
##    are still there for menus.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "Storylets"
	sheet.host_class = "Node"
	sheet.custom_class_name = "StoryletsAddon"
	sheet.class_description = "A quality-based narrative engine, shipped as the Storylets autoload singleton. Register many small storylets that each carry their own requirements, then call Draw to get the best eligible one - adding a story beat is one more storylet, not surgery on a giant if/else web."
	sheet.addon_category = "Storylets"
	sheet.addon_tags = PackedStringArray(["narrative", "storylet"])
	var about: CommentRow = CommentRow.new()
	about.text = "Storylet Weaver: register as the Storylets autoload. Define small story fragments with Add Requirement rules, mirror your game state into qualities with Set Quality, then Draw to get the best eligible storylet and react with On Storylet Drawn. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Storylet Drawn\")",
		"## @ace_category(\"Storylets\")",
		"signal on_storylet_drawn()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Choice Made\")",
		"## @ace_category(\"Storylets\")",
		"signal on_choice_made()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On None Available\")",
		"## @ace_category(\"Storylets\")",
		"signal on_none_available()",
		"",
		"# id -> {title, body, weight, cooldown, max_plays (-1=unlimited), reqs:Array of {key,op,value}, choices:Array of {id,text}}.",
		"var _lib: Dictionary = {}",
		"# Flat quality store (the mirror of game state the requirements read).",
		"var _qualities: Dictionary = {}",
		"var _plays: Dictionary = {}",
		"var _last_played: Dictionary = {}",
		"var _available: Array = []",
		"var _active: String = \"\"",
		"var _chosen: String = \"\"",
		"# Internal monotonic clock (seconds), ticked in _process so cooldowns need no wiring.",
		"var _clock: float = 0.0",
		"var _use_shared: bool = false",
		"",
		"# Randomness source: the shared AdvancedRandom autoload when Use Advanced Random is on and the",
		"# pack is installed, otherwise Godot's own randf() (the default - unchanged behaviour).",
		"func _rand_float() -> float:",
		"\tif _use_shared and is_inside_tree():",
		"\t\tvar shared: Node = get_node_or_null(\"/root/AdvancedRandom\")",
		"\t\tif shared != null:",
		"\t\t\treturn shared.random_value()",
		"\treturn randf()",
		"",
		"func _story(id: String) -> Dictionary:",
		"\tif not _lib.has(id):",
		"\t\t_lib[id] = {\"title\": \"\", \"body\": \"\", \"weight\": 1.0, \"cooldown\": 0.0, \"max_plays\": -1.0, \"reqs\": [], \"choices\": []}",
		"\treturn _lib[id]",
		"",
		"func _num(v: Variant) -> float:",
		"\tif v is float or v is int:",
		"\t\treturn float(v)",
		"\tif v is String and (v as String).is_valid_float():",
		"\t\treturn (v as String).to_float()",
		"\treturn 0.0",
		"",
		"func _text(v: Variant) -> String:",
		"\treturn \"\" if v == null else str(v)",
		"",
		"# One requirement against the current qualities. Missing quality = 0 / \"\".",
		"func _req_ok(req: Dictionary) -> bool:",
		"\tvar have: Variant = _qualities.get(req.key, null)",
		"\tvar want: Variant = req.value",
		"\tvar textual: bool = want is String and not (want as String).is_valid_float()",
		"\tmatch str(req.op):",
		"\t\t\"=\":",
		"\t\t\treturn _text(have) == _text(want) if textual else is_equal_approx(_num(have), _num(want))",
		"\t\t\"!=\":",
		"\t\t\treturn _text(have) != _text(want) if textual else not is_equal_approx(_num(have), _num(want))",
		"\t\t\">\":",
		"\t\t\treturn _num(have) > _num(want)",
		"\t\t\">=\":",
		"\t\t\treturn _num(have) >= _num(want)",
		"\t\t\"<\":",
		"\t\t\treturn _num(have) < _num(want)",
		"\t\t\"<=\":",
		"\t\t\treturn _num(have) <= _num(want)",
		"\treturn true",
		"",
		"# Whether a storylet passes ALL requirements, its play limit, and its cooldown right now.",
		"func _eligible(id: String) -> bool:",
		"\tvar s: Dictionary = _lib[id]",
		"\tif s.max_plays >= 0.0 and _plays.get(id, 0) >= int(s.max_plays):",
		"\t\treturn false",
		"\tif s.cooldown > 0.0 and _last_played.has(id) and _clock - _last_played[id] < s.cooldown:",
		"\t\treturn false",
		"\tfor req: Dictionary in s.reqs:",
		"\t\tif not _req_ok(req):",
		"\t\t\treturn false",
		"\treturn true",
		"",
		"# Marks a storylet as played now: records the play + cooldown start + active, fires the trigger.",
		"func _activate(id: String) -> void:",
		"\t_plays[id] = _plays.get(id, 0) + 1",
		"\t_last_played[id] = _clock",
		"\t_active = id",
		"\ton_storylet_drawn.emit()"
	]))
	sheet.events.append(block)
	# Tick the internal clock so cooldowns elapse without the user wiring one.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "_clock += delta"
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# --- Authoring ---
	Lib.append_function(sheet, "define_storylet", "Define Storylet", "Storylets", "Registers (or replaces) a storylet: an id plus the title + body text your game shows.",
		[["id", "String"], ["title", "String"], ["body", "String"]],
		"_lib[id] = {\"title\": title, \"body\": body, \"weight\": 1.0, \"cooldown\": 0.0, \"max_plays\": -1.0, \"reqs\": [], \"choices\": []}")
	Lib.append_function(sheet, "set_storylet_weight", "Set Storylet Weight", "Storylets", "How strongly this storylet is preferred when several are eligible (higher = picked first / likelier).",
		[["id", "String"], ["weight", "float"]],
		"_story(id).weight = maxf(weight, 0.0)")
	Lib.append_function(sheet, "set_storylet_cooldown", "Set Storylet Cooldown", "Storylets", "Seconds this storylet is ineligible after it plays (0 = no cooldown).",
		[["id", "String"], ["seconds", "float"]],
		"_story(id).cooldown = maxf(seconds, 0.0)")
	Lib.append_function(sheet, "set_storylet_max_plays", "Set Max Plays", "Storylets", "How many times it may ever play (-1 = unlimited, 1 = a one-shot).",
		[["id", "String"], ["max_plays", "float"]],
		"_story(id).max_plays = max_plays")
	var req_fn: EventFunction = Lib.exposed_function("add_requirement", "Add Requirement", "Storylets", "A rule this storylet needs to be eligible, e.g. quality \"courage\" >= 3. A missing quality counts as 0 (or \"\").",
		[["id", "String"], ["quality_key", "String"], ["op", "String"], ["value", "Variant"]],
		"_story(id).reqs.append({\"key\": quality_key, \"op\": op, \"value\": value})")
	_op_options(req_fn, "op")
	sheet.functions.append(req_fn)
	Lib.append_function(sheet, "add_choice", "Add Choice", "Storylets", "Adds a labelled choice the player can pick on this storylet (resolve it with Choose).",
		[["id", "String"], ["choice_id", "String"], ["text", "String"]],
		"_story(id).choices.append({\"id\": choice_id, \"text\": text})")

	# --- Qualities (the game-state mirror) ---
	Lib.append_function(sheet, "set_quality", "Set Quality", "Storylets", "Stores a quality value (a number like courage=3, or text like location=\"tavern\"). Requirements read these.",
		[["key", "String"], ["value", "Variant"]],
		"_qualities[key] = value")
	Lib.append_function(sheet, "increment_quality", "Increment Quality", "Storylets", "Adds to a numeric quality (creating it at 0 if new).",
		[["key", "String"], ["amount", "float"]],
		"_qualities[key] = _num(_qualities.get(key, 0.0)) + amount")
	Lib.append_function(sheet, "clear_quality", "Clear Quality", "Storylets", "Removes a quality key.",
		[["key", "String"]],
		"_qualities.erase(key)")

	# --- Evaluate, draw, resolve ---
	Lib.append_function(sheet, "evaluate", "Evaluate", "Storylets", "Rebuilds the available list: every eligible storylet, ordered by weight (highest first). Use the Available expressions to show a menu.",
		[],
		"\n".join(PackedStringArray([
			"_available.clear()",
			"for id: String in _lib:",
			"\tif _eligible(id):",
			"\t\t_available.append(id)",
			"_available.sort_custom(func(a: String, b: String) -> bool: return _lib[a].weight > _lib[b].weight)"
		])))
	Lib.append_function(sheet, "draw", "Draw", "Storylets", "Evaluates, then activates the highest-weight eligible storylet and fires On Storylet Drawn (or On None Available if nothing qualifies).",
		[],
		"evaluate()\nif _available.is_empty():\n\ton_none_available.emit()\n\treturn\n_activate(str(_available[0]))")
	Lib.append_function(sheet, "draw_weighted", "Draw Weighted", "Storylets", "Like Draw, but picks randomly among the eligible storylets in proportion to their weight (for variety).",
		[],
		"\n".join(PackedStringArray([
			"evaluate()",
			"if _available.is_empty():",
			"\ton_none_available.emit()",
			"\treturn",
			"var total: float = 0.0",
			"for id: String in _available:",
			"\ttotal += maxf(_lib[id].weight, 0.0)",
			"if total <= 0.0:",
			"\t_activate(str(_available[0]))",
			"\treturn",
			"var r: float = _rand_float() * total",
			"for id: String in _available:",
			"\tr -= maxf(_lib[id].weight, 0.0)",
			"\tif r <= 0.0:",
			"\t\t_activate(id)",
			"\t\treturn",
			"_activate(str(_available[_available.size() - 1]))"
		])))
	Lib.append_function(sheet, "choose", "Choose", "Storylets", "Resolves the active storylet's choice by id (fires On Choice Made, then clears the active storylet). React inside On Choice Made.",
		[["choice_id", "String"]],
		"if _active.is_empty():\n\treturn\n_chosen = choice_id\non_choice_made.emit()\n_active = \"\"")
	Lib.append_function(sheet, "use_advanced_random", "Use Advanced Random", "Storylets", "When on, Draw Weighted picks using the shared AdvancedRandom autoload instead of Godot's own randf(), so one seed drives your whole game's randomness. When off (the default) it uses randf(). Needs the Advanced Random pack installed (it safely falls back if not).",
		[["enabled", "bool"]],
		"_use_shared = enabled")
	Lib.append_function(sheet, "dismiss", "Dismiss", "Storylets", "Clears the active storylet without making a choice (the play still counted).",
		[],
		"_active = \"\"")
	Lib.append_function(sheet, "reset_play_count", "Reset Play Count", "Storylets", "Lets a one-shot or limited storylet play again.",
		[["id", "String"]],
		"_plays.erase(id)\n_last_played.erase(id)")
	Lib.append_function(sheet, "reset_all_history", "Reset All History", "Storylets", "Clears every play count + cooldown (e.g. on New Game).",
		[],
		"_plays.clear()\n_last_played.clear()")

	# --- Conditions ---
	_condition(sheet, "has_active", "Has Active Storylet", "Storylets", "Whether a storylet is currently active (drawn, not yet resolved).", [],
		"return not _active.is_empty()")
	_condition(sheet, "is_available", "Is Available", "Storylets", "Whether a storylet is in the current available list (call Evaluate first).", [["id", "String"]],
		"return id in _available")
	_condition(sheet, "has_quality", "Has Quality", "Storylets", "Whether a quality key has been set.", [["key", "String"]],
		"return _qualities.has(key)")
	_condition(sheet, "has_been_played", "Has Been Played", "Storylets", "Whether a storylet has played at least once.", [["id", "String"]],
		"return _plays.get(id, 0) > 0")
	_condition(sheet, "is_on_cooldown", "Is On Cooldown", "Storylets", "Whether a storylet is still cooling down.", [["id", "String"]],
		"var s: Dictionary = _lib.get(id, {})\nreturn s.get(\"cooldown\", 0.0) > 0.0 and _last_played.has(id) and _clock - _last_played[id] < s.get(\"cooldown\", 0.0)")
	_condition(sheet, "is_library_empty", "Is Library Empty", "Storylets", "Whether no storylets are registered.", [],
		"return _lib.is_empty()")

	# --- Expressions: qualities ---
	_expr(sheet, "quality_number", "Quality Number", "Storylets", "A quality as a number (0 if unset).", [["key", "String"]],
		"return _num(_qualities.get(key, 0.0))", TYPE_FLOAT)
	_expr(sheet, "quality_text", "Quality Text", "Storylets", "A quality as text (\"\" if unset).", [["key", "String"]],
		"return _text(_qualities.get(key, \"\"))", TYPE_STRING)
	# --- Expressions: available list ---
	_expr(sheet, "available_count", "Available Count", "Storylets", "How many storylets are eligible (after Evaluate/Draw).", [],
		"return _available.size()", TYPE_INT)
	_expr(sheet, "available_id", "Available Id", "Storylets", "The eligible storylet id at a position (\"\" out of range).", [["index", "int"]],
		"return str(_available[index]) if index >= 0 and index < _available.size() else \"\"", TYPE_STRING)
	_expr(sheet, "available_title", "Available Title", "Storylets", "The title of the eligible storylet at a position.", [["index", "int"]],
		"return str(_lib[_available[index]].title) if index >= 0 and index < _available.size() else \"\"", TYPE_STRING)
	# --- Expressions: active storylet ---
	_expr(sheet, "active_id", "Active Id", "Storylets", "The active storylet id (\"\" if none).", [],
		"return _active", TYPE_STRING)
	_expr(sheet, "active_title", "Active Title", "Storylets", "The active storylet's title.", [],
		"return str(_lib[_active].title) if _lib.has(_active) else \"\"", TYPE_STRING)
	_expr(sheet, "active_body", "Active Body", "Storylets", "The active storylet's body text.", [],
		"return str(_lib[_active].body) if _lib.has(_active) else \"\"", TYPE_STRING)
	_expr(sheet, "active_choice_count", "Choice Count", "Storylets", "How many choices the active storylet offers.", [],
		"return int(_lib[_active].choices.size()) if _lib.has(_active) else 0", TYPE_INT)
	_expr(sheet, "choice_id_at", "Choice Id At", "Storylets", "The choice id at a position on the active storylet.", [["index", "int"]],
		"if not _lib.has(_active):\n\treturn \"\"\nvar c: Array = _lib[_active].choices\nreturn str(c[index].id) if index >= 0 and index < c.size() else \"\"", TYPE_STRING)
	_expr(sheet, "choice_text_at", "Choice Text At", "Storylets", "The choice label at a position on the active storylet.", [["index", "int"]],
		"if not _lib.has(_active):\n\treturn \"\"\nvar c: Array = _lib[_active].choices\nreturn str(c[index].text) if index >= 0 and index < c.size() else \"\"", TYPE_STRING)
	_expr(sheet, "chosen_id", "Chosen Id", "Storylets", "The choice just picked (inside On Choice Made).", [],
		"return _chosen", TYPE_STRING)
	# --- Expressions: history ---
	_expr(sheet, "play_count", "Play Count", "Storylets", "How many times a storylet has played.", [["id", "String"]],
		"return _plays.get(id, 0)", TYPE_INT)
	_expr(sheet, "cooldown_remaining", "Cooldown Remaining", "Storylets", "Seconds left on a storylet's cooldown (0 if ready).", [["id", "String"]],
		"var s: Dictionary = _lib.get(id, {})\nif s.get(\"cooldown\", 0.0) <= 0.0 or not _last_played.has(id):\n\treturn 0.0\nreturn maxf(s.cooldown - (_clock - _last_played[id]), 0.0)", TYPE_FLOAT)
	_expr(sheet, "storylet_count", "Storylet Count", "Storylets", "How many storylets are registered.", [],
		"return _lib.size()", TYPE_INT)

	# Save-state seam - deliberately unpublished; the Save System provides the user-facing verbs.
	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"qualities\": _qualities.duplicate(true),",
		"\t\t\"plays\": _plays.duplicate(true)",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_qualities = (state.get(\"qualities\", {}) as Dictionary).duplicate(true)",
		"\t_plays = (state.get(\"plays\", {}) as Dictionary).duplicate(true)"
	]))
	sheet.events.append(persistence)

	return Lib.save_pack(sheet, "res://eventsheet_addons/storylet_weaver/storylet_weaver_addon")


## Gives the requirement op parameter a friendly comparison dropdown.
static func _op_options(fn: EventFunction, param_id: String) -> void:
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = [">=", ">", "<=", "<", "=", "!="]
			parameter.default_value = ">="


static func _condition(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = TYPE_BOOL
	sheet.functions.append(fn)


static func _expr(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String, ret: int) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = ret
	sheet.functions.append(fn)
