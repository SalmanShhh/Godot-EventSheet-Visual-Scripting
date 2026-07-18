## @ace_tags(input, combo)
## @ace_category("ComboBox")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/combo_box/icon.svg")
class_name ComboBoxAddon
extends Node
## A headless input-sequence detector: feed it named tokens with Press Input, it matches them against the sequences you register, and On Combo Matched fires the moment one completes. Works with any input source - keys, gamepad, swipes, even AI - because it reads no hardware itself.

## @ace_trigger
## @ace_name("On Combo Matched")
## @ace_category("ComboBox")
signal on_combo_matched
## @ace_trigger
## @ace_name("On Combo Failed")
## @ace_category("ComboBox")
signal on_combo_failed
## @ace_trigger
## @ace_name("On Partial Progress")
## @ace_category("ComboBox")
signal on_partial_progress
## @ace_trigger
## @ace_name("On Buffer Cleared")
## @ace_category("ComboBox")
signal on_buffer_cleared

## How many recent inputs to remember. Older inputs drop off so stale history cannot complete a combo.
@export_range(2, 64, 1) var buffer_length: int = 12
## Print every input, buffer state, and match to the Output panel while tuning.
@export var debug_logging: bool = false
## Default seconds allowed between two inputs of a combo (0 = no time limit). A combo can override this.
@export_range(0.0, 5.0, 0.05) var default_timing: float = 0.5

# id -> {sequence:PackedStringArray, timing:float(-1 = use default), strict:bool, tags:PackedStringArray, priority:int, enabled:bool}.
var _combos: Dictionary = {}
# Rolling window of the recent inputs, oldest first: each is {token:String, time:float}.
var _buffer: Array = []
# id -> {count:int, time:float}: how deep each combo is matched and when it last advanced (for partial UI + timeout).
var _progress: Dictionary = {}
# The partial matches from the last input (for the Partial Match expressions).
var _partials: Array = []
# A monotonic seconds clock, ticked in OnProcess, stamped onto each input.
var _clock: float = 0.0
# Last-event context (read via getter expressions inside the matching trigger).
var _matched_id: String = ""
var _matched_tags: String = ""
var _match_time: float = 0.0
var _failed_id: String = ""
var _fail_index: int = 0
var _cleared_count: int = 0

func _process(delta: float) -> void:
	_advance(delta)

## @ace_action
## @ace_featured
## @ace_name("Register Combo")
## @ace_category("ComboBox")
## @ace_description("Registers (or replaces) a combo: a unique id and its sequence as comma-separated tokens (for example "down,forward,punch"). timing_window is the seconds allowed between inputs (-1 = use the default, 0 = no time limit). Use "*" as a token to match any input.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.register_combo({id}, {sequence}, {timing_window})")
func register_combo(id: String, sequence: String, timing_window: float) -> void:
	var seq: PackedStringArray = PackedStringArray()
	for raw: String in sequence.split(",", false):
		var trimmed: String = raw.strip_edges()
		if not trimmed.is_empty():
			seq.append(trimmed)
	_combos[id] = {"sequence": seq, "timing": timing_window, "strict": false, "tags": PackedStringArray(), "priority": 0, "enabled": true}
	_progress.erase(id)

## @ace_action
## @ace_name("Set Combo Tags")
## @ace_category("ComboBox")
## @ace_description("Tags a registered combo with comma-separated tags, so you can enable or disable it in batches (for example "ground_move").")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.set_combo_tags({id}, {tags})")
func set_combo_tags(id: String, tags: String) -> void:
	if not _combos.has(id):
		return
	var tag_list: PackedStringArray = PackedStringArray()
	for raw: String in tags.split(",", false):
		var trimmed: String = raw.strip_edges()
		if not trimmed.is_empty():
			tag_list.append(trimmed)
	_combos[id].tags = tag_list

## @ace_action
## @ace_name("Set Combo Priority")
## @ace_category("ComboBox")
## @ace_description("Sets a combo's priority. When more than one combo completes on the same input, the highest priority wins (ties go to the longest, then to the first registered).")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.set_combo_priority({id}, {priority})")
func set_combo_priority(id: String, priority: int) -> void:
	if _combos.has(id):
		_combos[id].priority = priority

## @ace_action
## @ace_name("Set Combo Strict")
## @ace_category("ComboBox")
## @ace_description("When strict is on, the combo's inputs must be adjacent in the buffer (no unrelated input allowed between them). Off (the default) tolerates stray inputs in between, like a fighting-game motion.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.set_combo_strict({id}, {strict})")
func set_combo_strict(id: String, strict: bool) -> void:
	if _combos.has(id):
		_combos[id].strict = strict

## @ace_action
## @ace_name("Set Default Timing")
## @ace_category("ComboBox")
## @ace_description("Sets the default seconds allowed between inputs, used by any combo whose own timing window is -1.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.set_default_timing({seconds})")
func set_default_timing(seconds: float) -> void:
	default_timing = maxf(seconds, 0.0)

## @ace_action
## @ace_name("Set Buffer Length")
## @ace_category("ComboBox")
## @ace_description("Sets how many recent inputs to remember. Older inputs drop off, so stale history cannot complete a combo.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.set_buffer_length({length})")
func set_buffer_length(length: int) -> void:
	buffer_length = maxi(length, 2)
	while _buffer.size() > buffer_length:
		_buffer.remove_at(0)

## @ace_action
## @ace_featured
## @ace_name("Press Input")
## @ace_category("ComboBox")
## @ace_description("Pushes one input token into the buffer and checks every combo. Call this from your own input events (a key, a gamepad button, a swipe, a network packet). Fires On Combo Matched / On Partial Progress / On Combo Failed as needed.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.press_input({token})")
func press_input(token: String) -> void:
	_buffer.append({"token": token, "time": _clock})
	while _buffer.size() > buffer_length:
		_buffer.remove_at(0)
	if debug_logging:
		print("[ComboBox] input ", token, " buffer=", _buffer.size())
	_evaluate()

## @ace_action
## @ace_name("Clear Buffer")
## @ace_category("ComboBox")
## @ace_description("Empties the buffer and resets all partial progress (fires On Buffer Cleared). Call it on a context change - entering a cutscene or menu - so old inputs cannot leak into new combos.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.clear_buffer()")
func clear_buffer() -> void:
	_cleared_count = _buffer.size()
	_buffer.clear()
	_progress.clear()
	on_buffer_cleared.emit()

## @ace_action
## @ace_name("Enable Combo")
## @ace_category("ComboBox")
## @ace_description("Enables a combo so it takes part in matching.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.enable_combo({id})")
func enable_combo(id: String) -> void:
	if _combos.has(id):
		_combos[id].enabled = true

## @ace_action
## @ace_name("Disable Combo")
## @ace_category("ComboBox")
## @ace_description("Disables a combo so it is skipped in matching (its registration is kept).")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.disable_combo({id})")
func disable_combo(id: String) -> void:
	if _combos.has(id):
		_combos[id].enabled = false

## @ace_action
## @ace_name("Enable Combos By Tag")
## @ace_category("ComboBox")
## @ace_description("Enables every combo carrying a tag (for example all "air_move" combos).")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.enable_combos_by_tag({tag})")
func enable_combos_by_tag(tag: String) -> void:
	for id: String in _combos:
		if tag in (_combos[id].tags as PackedStringArray):
			_combos[id].enabled = true

## @ace_action
## @ace_name("Disable Combos By Tag")
## @ace_category("ComboBox")
## @ace_description("Disables every combo carrying a tag.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.disable_combos_by_tag({tag})")
func disable_combos_by_tag(tag: String) -> void:
	for id: String in _combos:
		if tag in (_combos[id].tags as PackedStringArray):
			_combos[id].enabled = false

## @ace_action
## @ace_name("Remove Combo")
## @ace_category("ComboBox")
## @ace_description("Permanently removes a combo from the registry.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.remove_combo({id})")
func remove_combo(id: String) -> void:
	_combos.erase(id)
	_progress.erase(id)

## @ace_condition
## @ace_name("Has Combo")
## @ace_category("ComboBox")
## @ace_description("Whether a combo id is registered.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.has_combo({id})")
func has_combo(id: String) -> bool:
	return _combos.has(id)

## @ace_condition
## @ace_name("Is Combo Enabled")
## @ace_category("ComboBox")
## @ace_description("Whether a combo is registered and enabled.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.is_combo_enabled({id})")
func is_combo_enabled(id: String) -> bool:
	return _combos.has(id) and bool(_combos[id].enabled)

## @ace_condition
## @ace_name("Is Buffer Empty")
## @ace_category("ComboBox")
## @ace_description("Whether the input buffer has no tokens.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.is_buffer_empty()")
func is_buffer_empty() -> bool:
	return _buffer.is_empty()

## @ace_condition
## @ace_name("Combo Has Tag")
## @ace_category("ComboBox")
## @ace_description("Whether a combo carries a tag.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.combo_has_tag({id}, {tag})")
func combo_has_tag(id: String, tag: String) -> bool:
	return _combos.has(id) and tag in (_combos[id].tags as PackedStringArray)

## @ace_expression
## @ace_name("Matched Id")
## @ace_category("ComboBox")
## @ace_description("The id of the combo that just matched (inside On Combo Matched).")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.matched_id()")
func matched_id() -> String:
	return _matched_id

## @ace_expression
## @ace_name("Matched Tags")
## @ace_category("ComboBox")
## @ace_description("The matched combo's tags as a comma-separated string (inside On Combo Matched).")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.matched_tags()")
func matched_tags() -> String:
	return _matched_tags

## @ace_expression
## @ace_name("Match Time")
## @ace_category("ComboBox")
## @ace_description("The clock time in seconds when the combo matched (inside On Combo Matched).")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.match_time()")
func match_time() -> float:
	return _match_time

## @ace_expression
## @ace_name("Failed Id")
## @ace_category("ComboBox")
## @ace_description("The id of the combo that just failed (inside On Combo Failed).")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.failed_id()")
func failed_id() -> String:
	return _failed_id

## @ace_expression
## @ace_name("Fail Index")
## @ace_category("ComboBox")
## @ace_description("How many inputs deep the failed combo had reached before it broke (inside On Combo Failed).")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.fail_index()")
func fail_index() -> int:
	return _fail_index

## @ace_expression
## @ace_name("Buffer Length")
## @ace_category("ComboBox")
## @ace_description("How many tokens are in the buffer right now.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.buffer_length_now()")
func buffer_length_now() -> int:
	return _buffer.size()

## @ace_expression
## @ace_name("Buffer Token")
## @ace_category("ComboBox")
## @ace_description("The token at a buffer index (0 = oldest); "" if out of range.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.buffer_token({index})")
func buffer_token(index: int) -> String:
	return str(_buffer[index].token) if index >= 0 and index < _buffer.size() else ""

## @ace_expression
## @ace_name("Buffer Time")
## @ace_category("ComboBox")
## @ace_description("The clock time in seconds of the token at a buffer index (0 if out of range).")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.buffer_time({index})")
func buffer_time(index: int) -> float:
	return float(_buffer[index].time) if index >= 0 and index < _buffer.size() else 0.0

## @ace_expression
## @ace_name("Cleared Count")
## @ace_category("ComboBox")
## @ace_description("How many tokens were in the buffer when it was last cleared (inside On Buffer Cleared).")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.cleared_count()")
func cleared_count() -> int:
	return _cleared_count

## @ace_expression
## @ace_name("Partial Count")
## @ace_category("ComboBox")
## @ace_description("How many combos are part-way matched after the last input (inside On Partial Progress).")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.partial_count()")
func partial_count() -> int:
	return _partials.size()

## @ace_expression
## @ace_name("Partial Id")
## @ace_category("ComboBox")
## @ace_description("The id of the part-way combo at an index (use with Partial Count to loop).")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.partial_id({index})")
func partial_id(index: int) -> String:
	return str(_partials[index].id) if index >= 0 and index < _partials.size() else ""

## @ace_expression
## @ace_name("Partial Progress")
## @ace_category("ComboBox")
## @ace_description("How many inputs of the part-way combo at an index are matched so far.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.partial_progress({index})")
func partial_progress(index: int) -> int:
	return int(_partials[index].progress) if index >= 0 and index < _partials.size() else 0

## @ace_expression
## @ace_name("Partial Length")
## @ace_category("ComboBox")
## @ace_description("The total length of the part-way combo at an index (pair with Partial Progress for a fill bar).")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.partial_length({index})")
func partial_length(index: int) -> int:
	return int(_partials[index].length) if index >= 0 and index < _partials.size() else 0

## @ace_expression
## @ace_name("Combo Count")
## @ace_category("ComboBox")
## @ace_description("How many combos are registered.")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.combo_count()")
func combo_count() -> int:
	return _combos.size()

## @ace_expression
## @ace_name("Combo Id At")
## @ace_category("ComboBox")
## @ace_description("The registered combo id at an index (use with Combo Count to list them).")
## @ace_icon("res://eventsheet_addons/combo_box/icon.svg")
## @ace_codegen_template("ComboBox.combo_id_at({index})")
func combo_id_at(index: int) -> String:
	return str(_combos.keys()[index]) if index >= 0 and index < _combos.size() else ""

func _token_matches(pattern: String, token: String) -> bool:
	# A registered token pattern matches an input if it is the wildcard "*" or the exact token.
	return pattern == "*" or pattern == token

func _resolve(timing: float) -> float:
	# Resolves a combo's timing window: its own if set (>= 0), otherwise the global default.
	return timing if timing >= 0.0 else default_timing

func _match_prefix(seq: PackedStringArray, count: int, window: float, strict: bool) -> bool:
	# Does the buffer END with the first `count` tokens of `seq`, anchored at the newest input, with
	# each consecutive matched pair within `window` seconds (window <= 0 = no limit)? Non-strict skips
	# unrelated inputs in between (so a stray neutral input does not break a motion); strict forbids it.
	if count <= 0 or _buffer.is_empty():
		return false
	var bi: int = _buffer.size() - 1
	if not _token_matches(seq[count - 1], str(_buffer[bi].token)):
		return false
	var later_time: float = float(_buffer[bi].time)
	bi -= 1
	var sj: int = count - 2
	while sj >= 0:
		var found: bool = false
		while bi >= 0:
			var earlier: Dictionary = _buffer[bi]
			if window > 0.0 and later_time - float(earlier.time) > window:
				return false
			if _token_matches(seq[sj], str(earlier.token)):
				later_time = float(earlier.time)
				bi -= 1
				found = true
				break
			elif strict:
				return false
			else:
				bi -= 1
		if not found:
			return false
		sj -= 1
	return true

func _evaluate() -> void:
	# The heart: after each input, find each enabled combo's deepest matched prefix, pick the single
	# best FULL match (priority, then length, then registration order), track partials, and detect
	# combos that were progressing and just broke.
	_partials.clear()
	var best_full: String = ""
	var best_priority: int = -2147483648
	var best_length: int = -1
	var best_order: int = 2147483647
	var partial_changed: bool = false
	var order: int = 0
	for id: String in _combos:
		var combo: Dictionary = _combos[id]
		var this_order: int = order
		order += 1
		if not bool(combo.enabled):
			continue
		var seq: PackedStringArray = combo.sequence
		var n: int = seq.size()
		if n == 0:
			continue
		var window: float = _resolve(combo.timing)
		var best_p: int = 0
		for p: int in range(n, 0, -1):
			if _match_prefix(seq, p, window, combo.strict):
				best_p = p
				break
		var prev: int = int(_progress.get(id, {}).get("count", 0))
		if best_p == n:
			_progress[id] = {"count": 0, "time": _clock}
			if combo.priority > best_priority or (combo.priority == best_priority and (n > best_length or (n == best_length and this_order < best_order))):
				best_full = id
				best_priority = combo.priority
				best_length = n
				best_order = this_order
		elif best_p > 0:
			_progress[id] = {"count": best_p, "time": _clock}
			_partials.append({"id": id, "progress": best_p, "length": n})
			if best_p != prev:
				partial_changed = true
		else:
			_progress[id] = {"count": 0, "time": _clock}
			if prev > 0:
				_failed_id = id
				_fail_index = prev
				on_combo_failed.emit()
	if best_full != "":
		var won: Dictionary = _combos[best_full]
		_matched_id = best_full
		_matched_tags = ",".join(won.tags as PackedStringArray)
		_match_time = _clock
		if debug_logging:
			print("[ComboBox] matched ", best_full)
		on_combo_matched.emit()
	if partial_changed:
		on_partial_progress.emit()

func _advance(delta: float) -> void:
	# Ticks the clock and expires any partial whose timing window elapsed with no further input,
	# firing On Combo Failed so a stalled motion can be reset in the UI. Driven by OnProcess.
	_clock += delta
	for id: String in _progress.keys():
		var state: Dictionary = _progress[id]
		if int(state.count) <= 0 or not _combos.has(id):
			continue
		var window: float = _resolve(_combos[id].timing)
		if window > 0.0 and _clock - float(state.time) > window:
			var reached: int = int(state.count)
			state.count = 0
			_failed_id = id
			_fail_index = reached
			on_combo_failed.emit()

# ComboBox: register as the ComboBox autoload. Register Combos (a comma-separated token sequence), then Press Input a token from your own input events - it matches the rolling buffer and fires On Combo Matched. Timing is in seconds; "*" is a wildcard. It detects; you react. This pack is an event sheet - extend it by editing it.
