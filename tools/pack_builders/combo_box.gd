# Pack builder - combo_box (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## ComboBox: a headless input-sequence detector as an AUTOLOAD sheet (ComboBox). It keeps a rolling
## buffer of named input TOKENS, matches the buffer against your registered SEQUENCES after every
## input, and fires On Combo Matched when a sequence completes. It reads no hardware input itself -
## you Press Input with a token string from your own keyboard / gamepad / touch / network events, so
## it works with any input source. All UI (hit sparks, combo counters, input displays) is your work,
## driven by the triggers. Ported to be Godot-native and beginner-friendly:
##  - Discrete typed ACEs (Register Combo with a comma-separated sequence) instead of hand-written JSON.
##  - Timing windows are in SECONDS (Godot's unit), driven by an internal clock, not milliseconds.
##  - Per-gap timing (each pair of inputs must be close enough), wildcards ("*"), interleave-tolerant
##    matching by default with an optional strict mode, tags for batch enable/disable, and priority.
##  - One combo wins per input - the highest priority, then the longest - so a sub-combo does not also
##    fire when the longer combo it is part of completes.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "ComboBox"
	sheet.host_class = "Node"
	sheet.custom_class_name = "ComboBoxAddon"
	sheet.class_description = "A headless input-sequence detector: feed it named tokens with Press Input, it matches them against the sequences you register, and On Combo Matched fires the moment one completes. Works with any input source - keys, gamepad, swipes, even AI - because it reads no hardware itself."
	sheet.addon_category = "ComboBox"
	sheet.addon_tags = PackedStringArray(["input", "combo"])
	sheet.variables = {
		"buffer_length": {"type": "int", "default": 12, "exported": true,
			"attributes": {"tooltip": "How many recent inputs to remember. Older inputs drop off so stale history cannot complete a combo.", "range": {"min": "2", "max": "64", "step": "1"}}},
		"default_timing": {"type": "float", "default": 0.5, "exported": true,
			"attributes": {"tooltip": "Default seconds allowed between two inputs of a combo (0 = no time limit). A combo can override this.", "range": {"min": "0.0", "max": "5.0", "step": "0.05"}}},
		"debug_logging": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Print every input, buffer state, and match to the Output panel while tuning."}}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "ComboBox: register as the ComboBox autoload. Register Combos (a comma-separated token sequence), then Press Input a token from your own input events - it matches the rolling buffer and fires On Combo Matched. Timing is in seconds; \"*\" is a wildcard. It detects; you react. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Combo Matched\")",
		"## @ace_category(\"ComboBox\")",
		"signal on_combo_matched()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Combo Failed\")",
		"## @ace_category(\"ComboBox\")",
		"signal on_combo_failed()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Partial Progress\")",
		"## @ace_category(\"ComboBox\")",
		"signal on_partial_progress()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Buffer Cleared\")",
		"## @ace_category(\"ComboBox\")",
		"signal on_buffer_cleared()",
		"",
		"# id -> {sequence:PackedStringArray, timing:float(-1 = use default), strict:bool, tags:PackedStringArray, priority:int, enabled:bool}.",
		"var _combos: Dictionary = {}",
		"# Rolling window of the recent inputs, oldest first: each is {token:String, time:float}.",
		"var _buffer: Array = []",
		"# id -> {count:int, time:float}: how deep each combo is matched and when it last advanced (for partial UI + timeout).",
		"var _progress: Dictionary = {}",
		"# The partial matches from the last input (for the Partial Match expressions).",
		"var _partials: Array = []",
		"# A monotonic seconds clock, ticked in OnProcess, stamped onto each input.",
		"var _clock: float = 0.0",
		"# Last-event context (read via getter expressions inside the matching trigger).",
		"var _matched_id: String = \"\"",
		"var _matched_tags: String = \"\"",
		"var _match_time: float = 0.0",
		"var _failed_id: String = \"\"",
		"var _fail_index: int = 0",
		"var _cleared_count: int = 0",
		"",
		"# A registered token pattern matches an input if it is the wildcard \"*\" or the exact token.",
		"func _token_matches(pattern: String, token: String) -> bool:",
		"\treturn pattern == \"*\" or pattern == token",
		"",
		"# Resolves a combo's timing window: its own if set (>= 0), otherwise the global default.",
		"func _resolve(timing: float) -> float:",
		"\treturn timing if timing >= 0.0 else default_timing",
		"",
		"# Does the buffer END with the first `count` tokens of `seq`, anchored at the newest input, with",
		"# each consecutive matched pair within `window` seconds (window <= 0 = no limit)? Non-strict skips",
		"# unrelated inputs in between (so a stray neutral input does not break a motion); strict forbids it.",
		"func _match_prefix(seq: PackedStringArray, count: int, window: float, strict: bool) -> bool:",
		"\tif count <= 0 or _buffer.is_empty():",
		"\t\treturn false",
		"\tvar bi: int = _buffer.size() - 1",
		"\tif not _token_matches(seq[count - 1], str(_buffer[bi].token)):",
		"\t\treturn false",
		"\tvar later_time: float = float(_buffer[bi].time)",
		"\tbi -= 1",
		"\tvar sj: int = count - 2",
		"\twhile sj >= 0:",
		"\t\tvar found: bool = false",
		"\t\twhile bi >= 0:",
		"\t\t\tvar earlier: Dictionary = _buffer[bi]",
		"\t\t\tif window > 0.0 and later_time - float(earlier.time) > window:",
		"\t\t\t\treturn false",
		"\t\t\tif _token_matches(seq[sj], str(earlier.token)):",
		"\t\t\t\tlater_time = float(earlier.time)",
		"\t\t\t\tbi -= 1",
		"\t\t\t\tfound = true",
		"\t\t\t\tbreak",
		"\t\t\telif strict:",
		"\t\t\t\treturn false",
		"\t\t\telse:",
		"\t\t\t\tbi -= 1",
		"\t\tif not found:",
		"\t\t\treturn false",
		"\t\tsj -= 1",
		"\treturn true",
		"",
		"# The heart: after each input, find each enabled combo's deepest matched prefix, pick the single",
		"# best FULL match (priority, then length, then registration order), track partials, and detect",
		"# combos that were progressing and just broke.",
		"func _evaluate() -> void:",
		"\t_partials.clear()",
		"\tvar best_full: String = \"\"",
		"\tvar best_priority: int = -2147483648",
		"\tvar best_length: int = -1",
		"\tvar best_order: int = 2147483647",
		"\tvar partial_changed: bool = false",
		"\tvar order: int = 0",
		"\tfor id: String in _combos:",
		"\t\tvar combo: Dictionary = _combos[id]",
		"\t\tvar this_order: int = order",
		"\t\torder += 1",
		"\t\tif not bool(combo.enabled):",
		"\t\t\tcontinue",
		"\t\tvar seq: PackedStringArray = combo.sequence",
		"\t\tvar n: int = seq.size()",
		"\t\tif n == 0:",
		"\t\t\tcontinue",
		"\t\tvar window: float = _resolve(combo.timing)",
		"\t\tvar best_p: int = 0",
		"\t\tfor p: int in range(n, 0, -1):",
		"\t\t\tif _match_prefix(seq, p, window, combo.strict):",
		"\t\t\t\tbest_p = p",
		"\t\t\t\tbreak",
		"\t\tvar prev: int = int(_progress.get(id, {}).get(\"count\", 0))",
		"\t\tif best_p == n:",
		"\t\t\t_progress[id] = {\"count\": 0, \"time\": _clock}",
		"\t\t\tif combo.priority > best_priority or (combo.priority == best_priority and (n > best_length or (n == best_length and this_order < best_order))):",
		"\t\t\t\tbest_full = id",
		"\t\t\t\tbest_priority = combo.priority",
		"\t\t\t\tbest_length = n",
		"\t\t\t\tbest_order = this_order",
		"\t\telif best_p > 0:",
		"\t\t\t_progress[id] = {\"count\": best_p, \"time\": _clock}",
		"\t\t\t_partials.append({\"id\": id, \"progress\": best_p, \"length\": n})",
		"\t\t\tif best_p != prev:",
		"\t\t\t\tpartial_changed = true",
		"\t\telse:",
		"\t\t\t_progress[id] = {\"count\": 0, \"time\": _clock}",
		"\t\t\tif prev > 0:",
		"\t\t\t\t_failed_id = id",
		"\t\t\t\t_fail_index = prev",
		"\t\t\t\ton_combo_failed.emit()",
		"\tif best_full != \"\":",
		"\t\tvar won: Dictionary = _combos[best_full]",
		"\t\t_matched_id = best_full",
		"\t\t_matched_tags = \",\".join(won.tags as PackedStringArray)",
		"\t\t_match_time = _clock",
		"\t\tif debug_logging:",
		"\t\t\tprint(\"[ComboBox] matched \", best_full)",
		"\t\ton_combo_matched.emit()",
		"\tif partial_changed:",
		"\t\ton_partial_progress.emit()",
		"",
		"# Ticks the clock and expires any partial whose timing window elapsed with no further input,",
		"# firing On Combo Failed so a stalled motion can be reset in the UI. Driven by OnProcess.",
		"func _advance(delta: float) -> void:",
		"\t_clock += delta",
		"\tfor id: String in _progress.keys():",
		"\t\tvar state: Dictionary = _progress[id]",
		"\t\tif int(state.count) <= 0 or not _combos.has(id):",
		"\t\t\tcontinue",
		"\t\tvar window: float = _resolve(_combos[id].timing)",
		"\t\tif window > 0.0 and _clock - float(state.time) > window:",
		"\t\t\tvar reached: int = int(state.count)",
		"\t\t\tstate.count = 0",
		"\t\t\t_failed_id = id",
		"\t\t\t_fail_index = reached",
		"\t\t\ton_combo_failed.emit()"
	]))
	sheet.events.append(block)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "_advance(delta)"
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# --- Registration ---
	Lib.append_function(sheet, "register_combo", "Register Combo", "ComboBox", "Registers (or replaces) a combo: a unique id and its sequence as comma-separated tokens (for example \"down,forward,punch\"). timing_window is the seconds allowed between inputs (-1 = use the default, 0 = no time limit). Use \"*\" as a token to match any input.",
		[["id", "String"], ["sequence", "String"], ["timing_window", "float"]],
		"var seq: PackedStringArray = PackedStringArray()\nfor raw: String in sequence.split(\",\", false):\n\tvar trimmed: String = raw.strip_edges()\n\tif not trimmed.is_empty():\n\t\tseq.append(trimmed)\n_combos[id] = {\"sequence\": seq, \"timing\": timing_window, \"strict\": false, \"tags\": PackedStringArray(), \"priority\": 0, \"enabled\": true}\n_progress.erase(id)")
	_default(sheet, "timing_window", "-1")
	Lib.append_function(sheet, "set_combo_tags", "Set Combo Tags", "ComboBox", "Tags a registered combo with comma-separated tags, so you can enable or disable it in batches (for example \"ground_move\").",
		[["id", "String"], ["tags", "String"]],
		"if not _combos.has(id):\n\treturn\nvar tag_list: PackedStringArray = PackedStringArray()\nfor raw: String in tags.split(\",\", false):\n\tvar trimmed: String = raw.strip_edges()\n\tif not trimmed.is_empty():\n\t\ttag_list.append(trimmed)\n_combos[id].tags = tag_list")
	Lib.append_function(sheet, "set_combo_priority", "Set Combo Priority", "ComboBox", "Sets a combo's priority. When more than one combo completes on the same input, the highest priority wins (ties go to the longest, then to the first registered).",
		[["id", "String"], ["priority", "int"]],
		"if _combos.has(id):\n\t_combos[id].priority = priority")
	Lib.append_function(sheet, "set_combo_strict", "Set Combo Strict", "ComboBox", "When strict is on, the combo's inputs must be adjacent in the buffer (no unrelated input allowed between them). Off (the default) tolerates stray inputs in between, like a fighting-game motion.",
		[["id", "String"], ["strict", "bool"]],
		"if _combos.has(id):\n\t_combos[id].strict = strict")

	# --- Configuration ---
	Lib.append_function(sheet, "set_default_timing", "Set Default Timing", "ComboBox", "Sets the default seconds allowed between inputs, used by any combo whose own timing window is -1.",
		[["seconds", "float"]],
		"default_timing = maxf(seconds, 0.0)")
	Lib.append_function(sheet, "set_buffer_length", "Set Buffer Length", "ComboBox", "Sets how many recent inputs to remember. Older inputs drop off, so stale history cannot complete a combo.",
		[["length", "int"]],
		"buffer_length = maxi(length, 2)\nwhile _buffer.size() > buffer_length:\n\t_buffer.remove_at(0)")

	# --- Input ---
	Lib.append_function(sheet, "press_input", "Press Input", "ComboBox", "Pushes one input token into the buffer and checks every combo. Call this from your own input events (a key, a gamepad button, a swipe, a network packet). Fires On Combo Matched / On Partial Progress / On Combo Failed as needed.",
		[["token", "String"]],
		"_buffer.append({\"token\": token, \"time\": _clock})\nwhile _buffer.size() > buffer_length:\n\t_buffer.remove_at(0)\nif debug_logging:\n\tprint(\"[ComboBox] input \", token, \" buffer=\", _buffer.size())\n_evaluate()")
	Lib.append_function(sheet, "clear_buffer", "Clear Buffer", "ComboBox", "Empties the buffer and resets all partial progress (fires On Buffer Cleared). Call it on a context change - entering a cutscene or menu - so old inputs cannot leak into new combos.",
		[],
		"_cleared_count = _buffer.size()\n_buffer.clear()\n_progress.clear()\non_buffer_cleared.emit()")

	# --- Management ---
	Lib.append_function(sheet, "enable_combo", "Enable Combo", "ComboBox", "Enables a combo so it takes part in matching.",
		[["id", "String"]],
		"if _combos.has(id):\n\t_combos[id].enabled = true")
	Lib.append_function(sheet, "disable_combo", "Disable Combo", "ComboBox", "Disables a combo so it is skipped in matching (its registration is kept).",
		[["id", "String"]],
		"if _combos.has(id):\n\t_combos[id].enabled = false")
	Lib.append_function(sheet, "enable_combos_by_tag", "Enable Combos By Tag", "ComboBox", "Enables every combo carrying a tag (for example all \"air_move\" combos).",
		[["tag", "String"]],
		"for id: String in _combos:\n\tif tag in (_combos[id].tags as PackedStringArray):\n\t\t_combos[id].enabled = true")
	Lib.append_function(sheet, "disable_combos_by_tag", "Disable Combos By Tag", "ComboBox", "Disables every combo carrying a tag.",
		[["tag", "String"]],
		"for id: String in _combos:\n\tif tag in (_combos[id].tags as PackedStringArray):\n\t\t_combos[id].enabled = false")
	Lib.append_function(sheet, "remove_combo", "Remove Combo", "ComboBox", "Permanently removes a combo from the registry.",
		[["id", "String"]],
		"_combos.erase(id)\n_progress.erase(id)")

	# --- Conditions ---
	_condition(sheet, "has_combo", "Has Combo", "ComboBox", "Whether a combo id is registered.", [["id", "String"]],
		"return _combos.has(id)")
	_condition(sheet, "is_combo_enabled", "Is Combo Enabled", "ComboBox", "Whether a combo is registered and enabled.", [["id", "String"]],
		"return _combos.has(id) and bool(_combos[id].enabled)")
	_condition(sheet, "is_buffer_empty", "Is Buffer Empty", "ComboBox", "Whether the input buffer has no tokens.", [],
		"return _buffer.is_empty()")
	_condition(sheet, "combo_has_tag", "Combo Has Tag", "ComboBox", "Whether a combo carries a tag.", [["id", "String"], ["tag", "String"]],
		"return _combos.has(id) and tag in (_combos[id].tags as PackedStringArray)")

	# --- Expressions: match context ---
	_expr(sheet, "matched_id", "Matched Id", "ComboBox", "The id of the combo that just matched (inside On Combo Matched).", [],
		"return _matched_id", TYPE_STRING)
	_expr(sheet, "matched_tags", "Matched Tags", "ComboBox", "The matched combo's tags as a comma-separated string (inside On Combo Matched).", [],
		"return _matched_tags", TYPE_STRING)
	_expr(sheet, "match_time", "Match Time", "ComboBox", "The clock time in seconds when the combo matched (inside On Combo Matched).", [],
		"return _match_time", TYPE_FLOAT)
	_expr(sheet, "failed_id", "Failed Id", "ComboBox", "The id of the combo that just failed (inside On Combo Failed).", [],
		"return _failed_id", TYPE_STRING)
	_expr(sheet, "fail_index", "Fail Index", "ComboBox", "How many inputs deep the failed combo had reached before it broke (inside On Combo Failed).", [],
		"return _fail_index", TYPE_INT)

	# --- Expressions: buffer ---
	_expr(sheet, "buffer_length_now", "Buffer Length", "ComboBox", "How many tokens are in the buffer right now.", [],
		"return _buffer.size()", TYPE_INT)
	_expr(sheet, "buffer_token", "Buffer Token", "ComboBox", "The token at a buffer index (0 = oldest); \"\" if out of range.", [["index", "int"]],
		"return str(_buffer[index].token) if index >= 0 and index < _buffer.size() else \"\"", TYPE_STRING)
	_expr(sheet, "buffer_time", "Buffer Time", "ComboBox", "The clock time in seconds of the token at a buffer index (0 if out of range).", [["index", "int"]],
		"return float(_buffer[index].time) if index >= 0 and index < _buffer.size() else 0.0", TYPE_FLOAT)
	_expr(sheet, "cleared_count", "Cleared Count", "ComboBox", "How many tokens were in the buffer when it was last cleared (inside On Buffer Cleared).", [],
		"return _cleared_count", TYPE_INT)

	# --- Expressions: partial matches ---
	_expr(sheet, "partial_count", "Partial Count", "ComboBox", "How many combos are part-way matched after the last input (inside On Partial Progress).", [],
		"return _partials.size()", TYPE_INT)
	_expr(sheet, "partial_id", "Partial Id", "ComboBox", "The id of the part-way combo at an index (use with Partial Count to loop).", [["index", "int"]],
		"return str(_partials[index].id) if index >= 0 and index < _partials.size() else \"\"", TYPE_STRING)
	_expr(sheet, "partial_progress", "Partial Progress", "ComboBox", "How many inputs of the part-way combo at an index are matched so far.", [["index", "int"]],
		"return int(_partials[index].progress) if index >= 0 and index < _partials.size() else 0", TYPE_INT)
	_expr(sheet, "partial_length", "Partial Length", "ComboBox", "The total length of the part-way combo at an index (pair with Partial Progress for a fill bar).", [["index", "int"]],
		"return int(_partials[index].length) if index >= 0 and index < _partials.size() else 0", TYPE_INT)

	# --- Expressions: registry ---
	_expr(sheet, "combo_count", "Combo Count", "ComboBox", "How many combos are registered.", [],
		"return _combos.size()", TYPE_INT)
	_expr(sheet, "combo_id_at", "Combo Id At", "ComboBox", "The registered combo id at an index (use with Combo Count to list them).", [["index", "int"]],
		"return str(_combos.keys()[index]) if index >= 0 and index < _combos.size() else \"\"", TYPE_STRING)

	return Lib.save_pack(sheet, "res://eventsheet_addons/combo_box/combo_box_addon")


## Pre-fills the last-appended ACE's parameter default, so the dialog opens with a usable value
## (authoring-time metadata only - defaults never appear in the compiled .gd).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


static func _condition(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = TYPE_BOOL
	sheet.functions.append(fn)


static func _expr(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String, ret: int) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = ret
	sheet.functions.append(fn)
