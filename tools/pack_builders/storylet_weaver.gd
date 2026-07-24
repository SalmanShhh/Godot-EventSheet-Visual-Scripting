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
	# 1.1.0: ported the recently-updated C3 addon's data-driven layer - effects + forecasts, meta
	# payloads, per-choice requirements/effects, and the chance / recency / key-vs-key requirements.
	sheet.addon_version = "1.1.0"
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
		"# id -> {title, body, weight, cooldown, max_plays (-1=unlimited),",
		"#        reqs:Array of {key,op,value,value_key(bool)}, choices:Array of {id,text,reqs,effects},",
		"#        effects:Array of {op,key,value}, meta:Dictionary}.",
		"var _lib: Dictionary = {}",
		"# Flat quality store (the mirror of game state the requirements read).",
		"var _qualities: Dictionary = {}",
		"var _plays: Dictionary = {}",
		"var _last_played: Dictionary = {}",
		"# Ids in the order they were drawn (most recent LAST) - the recency requirement reads this.",
		"var _selection_order: Array = []",
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
		"func _blank_story() -> Dictionary:",
		"\treturn {\"title\": \"\", \"body\": \"\", \"weight\": 1.0, \"cooldown\": 0.0, \"max_plays\": -1.0, \"reqs\": [], \"choices\": [], \"effects\": [], \"meta\": {}}",
		"",
		"func _story(id: String) -> Dictionary:",
		"\tif not _lib.has(id):",
		"\t\t_lib[id] = _blank_story()",
		"\treturn _lib[id]",
		"",
		"# The draft choice with this id on a storylet, or an empty dict.",
		"func _choice(id: String, choice_id: String) -> Dictionary:",
		"\tfor c: Dictionary in _story(id).choices:",
		"\t\tif str(c.id) == choice_id:",
		"\t\t\treturn c",
		"\treturn {}",
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
		"# One requirement against the current qualities. Missing quality = 0 / \"\". `id` is the storylet",
		"# being evaluated (recency reads it). chance re-rolls each call; recency reads the draw history;",
		"# a key-vs-key rule (value_key) compares the quality against ANOTHER quality's current value.",
		"func _req_ok(req: Dictionary, id: String) -> bool:",
		"\tmatch str(req.op):",
		"\t\t\"chance\":",
		"\t\t\treturn _rand_float() * 100.0 < _num(req.value)",
		"\t\t\"recent\", \"not_recent\":",
		"\t\t\tvar within: int = int(_num(req.value))",
		"\t\t\tvar recent: bool = _selection_order.slice(maxi(_selection_order.size() - within, 0)).has(id)",
		"\t\t\treturn recent if str(req.op) == \"recent\" else not recent",
		"\tvar have: Variant = _qualities.get(req.key, null)",
		"\tvar want: Variant = _qualities.get(req.value, null) if bool(req.get(\"value_key\", false)) else req.value",
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
		"\t\tif not _req_ok(req, id):",
		"\t\t\treturn false",
		"\treturn true",
		"",
		"# Applies one effect to the qualities store (the storylet/choice's declared consequence).",
		"func _apply_effect(eff: Dictionary) -> void:",
		"\tvar key: String = str(eff.get(\"key\", \"\"))",
		"\tif key.is_empty():",
		"\t\treturn",
		"\tmatch str(eff.get(\"op\", \"set\")):",
		"\t\t\"set\":",
		"\t\t\t_qualities[key] = eff.get(\"value\", 0)",
		"\t\t\"inc\":",
		"\t\t\t_qualities[key] = _num(_qualities.get(key, 0.0)) + _num(eff.get(\"value\", 0))",
		"\t\t\"dec\":",
		"\t\t\t_qualities[key] = _num(_qualities.get(key, 0.0)) - _num(eff.get(\"value\", 0))",
		"\t\t\"toggle\":",
		"\t\t\t_qualities[key] = 0.0 if _num(_qualities.get(key, 0.0)) != 0.0 else 1.0",
		"\t\t\"delete\":",
		"\t\t\t_qualities.erase(key)",
		"",
		"# A readable one-line preview of a list of effects, e.g. \"gold -10, gate_open = 1\". Never mutates.",
		"func _forecast(effects: Array) -> String:",
		"\tvar parts: PackedStringArray = PackedStringArray()",
		"\tfor eff: Dictionary in effects:",
		"\t\tvar key: String = str(eff.get(\"key\", \"\"))",
		"\t\tmatch str(eff.get(\"op\", \"set\")):",
		"\t\t\t\"set\":",
		"\t\t\t\tparts.append(\"%s = %s\" % [key, str(eff.get(\"value\", 0))])",
		"\t\t\t\"inc\":",
		"\t\t\t\tparts.append(\"%s +%s\" % [key, str(eff.get(\"value\", 0))])",
		"\t\t\t\"dec\":",
		"\t\t\t\tparts.append(\"%s -%s\" % [key, str(eff.get(\"value\", 0))])",
		"\t\t\t\"toggle\":",
		"\t\t\t\tparts.append(\"toggle %s\" % key)",
		"\t\t\t\"delete\":",
		"\t\t\t\tparts.append(\"clear %s\" % key)",
		"\treturn \", \".join(parts)",
		"",
		"# Whether a choice's own requirements pass right now (only eligible choices are shown/pickable).",
		"func _choice_ok(choice: Dictionary, id: String) -> bool:",
		"\tfor req: Dictionary in choice.get(\"reqs\", []):",
		"\t\tif not _req_ok(req, id):",
		"\t\t\treturn false",
		"\treturn true",
		"",
		"# The active storylet's choices that pass their requirements, in order.",
		"func _active_choices() -> Array:",
		"\tif not _lib.has(_active):",
		"\t\treturn []",
		"\tvar out: Array = []",
		"\tfor c: Dictionary in _lib[_active].choices:",
		"\t\tif _choice_ok(c, _active):",
		"\t\t\tout.append(c)",
		"\treturn out",
		"",
		"# A grid field off a StoryletResource (or any duck-typed resource), as an Array of row dicts.",
		"func _rows(resource: Object, field: String) -> Array:",
		"\tvar v: Variant = resource.get(field)",
		"\treturn v if v is Array else []",
		"",
		"# A StoryletResource op column stores a WORD token (a table dropdown cannot hold \">=\", whose \"=\"",
		"# is a reserved marker char), so map it to the symbol the eligibility check uses. A symbol that",
		"# arrives verbatim passes straight through.",
		"func _op_symbol(op: String) -> String:",
		"\tmatch op:",
		"\t\t\"gte\": return \">=\"",
		"\t\t\"gt\": return \">\"",
		"\t\t\"lte\": return \"<=\"",
		"\t\t\"lt\": return \"<\"",
		"\t\t\"eq\": return \"=\"",
		"\t\t\"neq\": return \"!=\"",
		"\treturn op",
		"",
		"# Turns one Requirements-grid row into a requirement dict the eligibility check understands -",
		"# a comparison (optionally key-vs-key), a chance gate, or a recency gate.",
		"func _req_from_row(row: Dictionary) -> Dictionary:",
		"\tvar op: String = str(row.get(\"op\", \"gte\"))",
		"\tmatch op:",
		"\t\t\"chance\":",
		"\t\t\treturn {\"op\": \"chance\", \"value\": _num(row.get(\"value\", 0))}",
		"\t\t\"recent\", \"not_recent\":",
		"\t\t\treturn {\"op\": op, \"value\": int(_num(row.get(\"value\", 0)))}",
		"\tvar req: Dictionary = {\"key\": str(row.get(\"key\", \"\")), \"op\": _op_symbol(op), \"value\": row.get(\"value\", \"\")}",
		"\tif bool(row.get(\"value_is_key\", false)):",
		"\t\treq[\"value_key\"] = true",
		"\treturn req",
		"",
		"# Turns one Effects-grid row into an effect dict.",
		"func _effect_from_row(row: Dictionary) -> Dictionary:",
		"\treturn {\"op\": str(row.get(\"op\", \"set\")), \"key\": str(row.get(\"key\", \"\")), \"value\": row.get(\"value\", \"\")}",
		"",
		"# Marks a storylet as played now: records the play + cooldown start + active + draw history,",
		"# applies its on-draw effects, and fires the trigger.",
		"func _activate(id: String) -> void:",
		"\t_plays[id] = _plays.get(id, 0) + 1",
		"\t_last_played[id] = _clock",
		"\t_selection_order.append(id)",
		"\tfor eff: Dictionary in _lib[id].get(\"effects\", []):",
		"\t\t_apply_effect(eff)",
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
		"_lib[id] = _blank_story()\n_lib[id].title = title\n_lib[id].body = body")
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
		"_story(id).choices.append({\"id\": choice_id, \"text\": text, \"reqs\": [], \"effects\": []})")
	var choice_req_fn: EventFunction = Lib.exposed_function("add_choice_requirement", "Add Choice Requirement", "Storylets", "A rule that must pass for this choice to be OFFERED, e.g. quality \"gold\" >= 10. Choices whose rules fail are hidden. Add the choice first with Add Choice.",
		[["id", "String"], ["choice_id", "String"], ["quality_key", "String"], ["op", "String"], ["value", "Variant"]],
		"var c: Dictionary = _choice(id, choice_id)\nif not c.is_empty():\n\tc.reqs.append({\"key\": quality_key, \"op\": op, \"value\": value})")
	_op_options(choice_req_fn, "op")
	sheet.functions.append(choice_req_fn)
	var choice_eff_fn: EventFunction = Lib.exposed_function("add_choice_effect", "Add Choice Effect", "Storylets", "A quality change applied automatically when this choice is picked - so a choice carries its own consequence instead of a per-choice branch. Add the choice first with Add Choice.",
		[["id", "String"], ["choice_id", "String"], ["op", "String"], ["key", "String"], ["value", "Variant"]],
		"var c: Dictionary = _choice(id, choice_id)\nif not c.is_empty():\n\tc.effects.append({\"op\": op, \"key\": key, \"value\": value})")
	_effect_op_options(choice_eff_fn, "op")
	sheet.functions.append(choice_eff_fn)

	# --- Effects & meta (data-driven consequences + arbitrary payload) ---
	var effect_fn: EventFunction = Lib.exposed_function("add_effect", "Add Effect", "Storylets", "A quality change applied automatically when this storylet is DRAWN - so a beat carries its own consequence. Define the storylet first.",
		[["id", "String"], ["op", "String"], ["key", "String"], ["value", "Variant"]],
		"_story(id).effects.append({\"op\": op, \"key\": key, \"value\": value})")
	_effect_op_options(effect_fn, "op")
	sheet.functions.append(effect_fn)
	Lib.append_function(sheet, "add_meta", "Add Meta", "Storylets", "Attaches an arbitrary key-value to a storylet (a speaker, a portrait, a sound). Read it back with Active Meta / Storylet Meta - the engine never interprets it.",
		[["id", "String"], ["key", "String"], ["value", "Variant"]],
		"_story(id).meta[key] = value")

	# --- Richer requirements (chance / recency / key-vs-key) ---
	var key_req_fn: EventFunction = Lib.exposed_function("add_requirement_key", "Add Requirement (Key vs Key)", "Storylets", "A rule comparing one quality against ANOTHER quality's value, e.g. gold >= price - so a storylet reacts to a relationship between stats without hard-coding the number.",
		[["id", "String"], ["quality_key", "String"], ["op", "String"], ["other_key", "String"]],
		"_story(id).reqs.append({\"key\": quality_key, \"op\": op, \"value\": other_key, \"value_key\": true})")
	_op_options(key_req_fn, "op")
	sheet.functions.append(key_req_fn)
	Lib.append_function(sheet, "add_chance_requirement", "Add Chance Requirement", "Storylets", "A probability gate: the storylet is eligible only percent% of the time, re-rolled on every Evaluate/Draw. Use it to make a beat show only sometimes.",
		[["id", "String"], ["percent", "float"]],
		"_story(id).reqs.append({\"op\": \"chance\", \"value\": clampf(percent, 0.0, 100.0)})")
	var recency_fn: EventFunction = Lib.exposed_function("add_recency_requirement", "Add Recency Requirement", "Storylets", "An anti-repeat (or must-be-recent) gate by DRAW history: eligible only when this storylet was / was not among the last N drawn storylets.",
		[["id", "String"], ["mode", "String"], ["within", "int"]],
		"_story(id).reqs.append({\"op\": mode, \"value\": within})")
	_recency_options(recency_fn, "mode")
	sheet.functions.append(recency_fn)

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
	Lib.append_function(sheet, "choose", "Choose", "Storylets", "Resolves the active storylet's choice by id: applies that choice's effects, fires On Choice Made, then clears the active storylet. Only an ELIGIBLE choice resolves. React inside On Choice Made.",
		[["choice_id", "String"]],
		"\n".join(PackedStringArray([
			"if _active.is_empty():",
			"\treturn",
			"var picked: Dictionary = _choice(_active, choice_id)",
			"if picked.is_empty() or not _choice_ok(picked, _active):",
			"\treturn",
			"for eff: Dictionary in picked.get(\"effects\", []):",
			"\t_apply_effect(eff)",
			"_chosen = choice_id",
			"on_choice_made.emit()",
			"_active = \"\""
		])))
	Lib.append_function(sheet, "use_advanced_random", "Use Advanced Random", "Storylets", "When on, Draw Weighted picks using the shared AdvancedRandom autoload instead of Godot's own randf(), so one seed drives your whole game's randomness. When off (the default) it uses randf(). Needs the Advanced Random pack installed (it safely falls back if not).",
		[["enabled", "bool"]],
		"_use_shared = enabled")
	Lib.append_function(sheet, "load_from_resource", "Load From Resource", "Storylets", "Registers a whole storybook from a StoryletResource asset (a .tres you fill in the Inspector) in one step, instead of a wall of Define Storylet actions. Additive: it defines each storylet and adds its requirements, choices, effects and meta, so you can still tweak the library with the discrete actions afterwards.",
		[["resource", "Resource"]],
		"\n".join(PackedStringArray([
			"if resource == null:",
			"\treturn",
			"for row: Dictionary in _rows(resource, \"storylets\"):",
			"\tvar sid: String = str(row.get(\"id\", \"\"))",
			"\tif sid.is_empty():",
			"\t\tcontinue",
			"\tdefine_storylet(sid, str(row.get(\"title\", \"\")), str(row.get(\"body\", \"\")))",
			"\t_lib[sid].weight = maxf(_num(row.get(\"weight\", 1.0)), 0.0)",
			"\t_lib[sid].cooldown = maxf(_num(row.get(\"cooldown\", 0.0)), 0.0)",
			"\t_lib[sid].max_plays = _num(row.get(\"max_plays\", -1.0))",
			"# Rows reference a storylet (or a choice on it) by id; a row naming an undefined storylet is",
			"# skipped rather than conjuring a blank one.",
			"for row: Dictionary in _rows(resource, \"requirements\"):",
			"\tif _lib.has(str(row.get(\"storylet\", \"\"))):",
			"\t\t_lib[str(row.get(\"storylet\", \"\"))].reqs.append(_req_from_row(row))",
			"for row: Dictionary in _rows(resource, \"choices\"):",
			"\tif _lib.has(str(row.get(\"storylet\", \"\"))):",
			"\t\tadd_choice(str(row.get(\"storylet\", \"\")), str(row.get(\"choice_id\", \"\")), str(row.get(\"text\", \"\")))",
			"for row: Dictionary in _rows(resource, \"choice_requirements\"):",
			"\tvar cr: Dictionary = _choice(str(row.get(\"storylet\", \"\")), str(row.get(\"choice_id\", \"\")))",
			"\tif not cr.is_empty():",
			"\t\tcr.reqs.append(_req_from_row(row))",
			"for row: Dictionary in _rows(resource, \"effects\"):",
			"\tif _lib.has(str(row.get(\"storylet\", \"\"))):",
			"\t\t_lib[str(row.get(\"storylet\", \"\"))].effects.append(_effect_from_row(row))",
			"for row: Dictionary in _rows(resource, \"choice_effects\"):",
			"\tvar ce: Dictionary = _choice(str(row.get(\"storylet\", \"\")), str(row.get(\"choice_id\", \"\")))",
			"\tif not ce.is_empty():",
			"\t\tce.effects.append(_effect_from_row(row))",
			"for row: Dictionary in _rows(resource, \"meta\"):",
			"\tif _lib.has(str(row.get(\"storylet\", \"\"))):",
			"\t\t_lib[str(row.get(\"storylet\", \"\"))].meta[str(row.get(\"key\", \"\"))] = row.get(\"value\", \"\")"
		])))
	Lib.append_function(sheet, "dismiss", "Dismiss", "Storylets", "Clears the active storylet without making a choice (the play still counted).",
		[],
		"_active = \"\"")
	Lib.append_function(sheet, "reset_play_count", "Reset Play Count", "Storylets", "Lets a one-shot or limited storylet play again.",
		[["id", "String"]],
		"_plays.erase(id)\n_last_played.erase(id)")
	Lib.append_function(sheet, "reset_all_history", "Reset All History", "Storylets", "Clears every play count, cooldown, and the recency draw-history (e.g. on New Game).",
		[],
		"_plays.clear()\n_last_played.clear()\n_selection_order.clear()")

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
	_expr(sheet, "active_choice_count", "Choice Count", "Storylets", "How many ELIGIBLE choices the active storylet offers (choices whose requirements fail are not counted).", [],
		"return _active_choices().size()", TYPE_INT)
	_expr(sheet, "choice_id_at", "Choice Id At", "Storylets", "The id of the eligible choice at a position on the active storylet.", [["index", "int"]],
		"var c: Array = _active_choices()\nreturn str(c[index].id) if index >= 0 and index < c.size() else \"\"", TYPE_STRING)
	_expr(sheet, "choice_text_at", "Choice Text At", "Storylets", "The label of the eligible choice at a position on the active storylet.", [["index", "int"]],
		"var c: Array = _active_choices()\nreturn str(c[index].text) if index >= 0 and index < c.size() else \"\"", TYPE_STRING)
	_expr(sheet, "chosen_id", "Chosen Id", "Storylets", "The choice just picked (inside On Choice Made).", [],
		"return _chosen", TYPE_STRING)
	# --- Expressions: effect forecasts (read-only "what will this do") ---
	_expr(sheet, "forecast_storylet_effects", "Forecast Storylet Effects", "Storylets", "A readable preview of the quality changes a storylet applies when drawn, e.g. \"gold -10, gate_open = 1\". Never changes anything - put it on a button.", [["id", "String"]],
		"return _forecast(_lib[id].get(\"effects\", [])) if _lib.has(id) else \"\"", TYPE_STRING)
	_expr(sheet, "forecast_choice_effects", "Forecast Choice Effects", "Storylets", "A readable preview of the quality changes a choice applies when picked. Pass Active Id() for the current storylet. Never changes anything.", [["id", "String"], ["choice_id", "String"]],
		"var c: Dictionary = _choice(id, choice_id)\nreturn _forecast(c.get(\"effects\", [])) if not c.is_empty() else \"\"", TYPE_STRING)
	# --- Expressions: meta ---
	_expr(sheet, "active_meta", "Active Meta", "Storylets", "A meta value on the active storylet (\"\" if unset).", [["key", "String"]],
		"return str(_lib[_active].meta.get(key, \"\")) if _lib.has(_active) else \"\"", TYPE_STRING)
	_expr(sheet, "storylet_meta", "Storylet Meta", "Storylets", "A meta value on any registered storylet by id, without drawing it (\"\" if unset).", [["id", "String"], ["key", "String"]],
		"return str(_lib[id].meta.get(key, \"\")) if _lib.has(id) else \"\"", TYPE_STRING)
	_expr(sheet, "available_meta", "Available Meta", "Storylets", "A meta value on the eligible storylet at a position in the available list.", [["index", "int"], ["key", "String"]],
		"if index < 0 or index >= _available.size():\n\treturn \"\"\nreturn str(_lib[_available[index]].meta.get(key, \"\"))", TYPE_STRING)
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
		"\t\t\"plays\": _plays.duplicate(true),",
		"\t\t\"selection_order\": _selection_order.duplicate()",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_qualities = (state.get(\"qualities\", {}) as Dictionary).duplicate(true)",
		"\t_plays = (state.get(\"plays\", {}) as Dictionary).duplicate(true)",
		"\t_selection_order = (state.get(\"selection_order\", []) as Array).duplicate()"
	]))
	sheet.events.append(persistence)

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.feature_verbs(sheet, ["define_storylet", "draw"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/storylet_weaver/storylet_weaver_addon")


## Gives the requirement op parameter a friendly comparison dropdown.
static func _op_options(fn: EventFunction, param_id: String) -> void:
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = [">=", ">", "<=", "<", "=", "!="]
			parameter.default_value = ">="


## The effect operation dropdown: the friendly label is shown, the stored token drives _apply_effect.
static func _effect_op_options(fn: EventFunction, param_id: String) -> void:
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = [
				{"key": "set", "label": "Set to"},
				{"key": "inc", "label": "Increment by"},
				{"key": "dec", "label": "Decrement by"},
				{"key": "toggle", "label": "Toggle (0/1)"},
				{"key": "delete", "label": "Delete key"},
			]
			parameter.default_value = "set"


## The recency mode dropdown: "was NOT drawn recently" (anti-repeat) or "was drawn recently".
static func _recency_options(fn: EventFunction, param_id: String) -> void:
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = [
				{"key": "not_recent", "label": "was NOT drawn recently"},
				{"key": "recent", "label": "was drawn recently"},
			]
			parameter.default_value = "not_recent"


static func _condition(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = TYPE_BOOL
	sheet.functions.append(fn)


static func _expr(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String, ret: int) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = ret
	sheet.functions.append(fn)
