## @ace_tags(stats, rpg, data)
## @ace_category("StatForge")
@icon("res://eventsheet_addons/stat_forge/icon.svg")
class_name StatForge
extends Node
## Real, modifiable stats for any node: every modifier that touches its numbers is a named buff that adds, multiplies, or overrides one stat, optionally tagged, sourced, and auto-expiring. Reading the computed result is always one expression - Stat Total.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("StatForge behavior requires a Node parent.")

## @ace_trigger
## @ace_name("On Buff Added")
signal buff_added(buff_id: String, stat: String)
## @ace_trigger
## @ace_name("On Buff Removed")
signal buff_removed(buff_id: String, stat: String)
## @ace_trigger
## @ace_name("On Buff Expired")
signal buff_expired(buff_id: String, stat: String)
## @ace_trigger
## @ace_name("On Threshold Crossed")
signal threshold_crossed(rule_id: String, stat: String, total: float)

# --- Designer knobs (tune in the Inspector) ---
## Temporary buffs count down automatically every frame. Off: drive time yourself
## with Advance Timers (turn-based games advance per turn).
@export var auto_tick: bool = true
## What happens when a computed total leaves the min/max range: clamp stops at the
## boundary, wrap loops around, none applies no limit.
@export_enum("clamp", "wrap", "none") var overflow_mode: String = "clamp"
## The smallest allowed stat total (clamp/wrap modes).
@export var min_value: float = -99999.0
## The largest allowed stat total (clamp/wrap modes).
@export var max_value: float = 99999.0

# --- Internal state ---
# buff id -> {stat, value, mode, tags: Array[String], source, active, time_left (-1 =
# permanent), duration, paused}. Ids are unique per node: re-adding replaces.
var _buffs: Dictionary = {}
var _bases: Dictionary = {}
# rule id -> {stat, value, direction, repeating, armed}
var _rules: Dictionary = {}
var _last_totals: Dictionary = {}
var _last_expired: String = ""
var _last_rule: String = ""

func _physics_process(delta: float) -> void:
	if auto_tick:
		advance_timers(delta)

## @ace_expression
## @ace_name("Stat Total")
## @ace_description("The stat computation: (base + active adds) * active multipliers - unless active OVERRIDE buffs exist, where the HIGHEST override wins outright. Overflow applies last (clamp / wrap / none).")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.stat_total({stat})")
func stat_total(stat: String) -> float:
	var total: float = float(_bases.get(stat, 0.0))
	var multiplier: float = 1.0
	var best_override: float = -INF
	var has_override: bool = false
	for buff: Dictionary in _buffs.values():
		if str(buff["stat"]) != stat or not bool(buff["active"]):
			continue
		match str(buff["mode"]):
			"add":
				total += float(buff["value"])
			"multiply":
				multiplier *= float(buff["value"])
			"override":
				has_override = true
				best_override = maxf(best_override, float(buff["value"]))
	var result: float = best_override if has_override else total * multiplier
	match overflow_mode:
		"clamp":
			result = clampf(result, min_value, max_value)
		"wrap":
			if max_value > min_value:
				result = fposmod(result - min_value, max_value - min_value) + min_value
	return result

## @ace_expression
## @ace_name("Stat Base")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.stat_base({stat})")
func stat_base(stat: String) -> float:
	return float(_bases.get(stat, 0.0))

## @ace_expression
## @ace_name("Buff Value")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.buff_value({buff_id})")
func buff_value(buff_id: String) -> float:
	return float((_buffs.get(buff_id, {}) as Dictionary).get("value", 0.0))

## @ace_expression
## @ace_name("Buff Time Left")
## @ace_description("Seconds left on a timed buff (-1 = permanent or unknown).")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.buff_time_left({buff_id})")
func buff_time_left(buff_id: String) -> float:
	return float((_buffs.get(buff_id, {}) as Dictionary).get("time_left", -1.0))

## @ace_expression
## @ace_name("Buff Count")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.buff_count()")
func buff_count() -> int:
	return _buffs.size()

## @ace_expression
## @ace_name("Buff Count With Tag")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.buff_count_with_tag({tag})")
func buff_count_with_tag(tag: String) -> int:
	var count: int = 0
	for buff: Dictionary in _buffs.values():
		if (buff["tags"] as Array).has(tag):
			count += 1
	return count

## @ace_expression
## @ace_name("Last Expired Buff")
## @ace_description("The buff that expired most recently - read it inside On Buff Expired.")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.last_expired_buff()")
func last_expired_buff() -> String:
	return _last_expired

## @ace_expression
## @ace_name("Last Threshold Rule")
## @ace_description("The rule that fired most recently - read it inside On Threshold Crossed.")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.last_threshold_rule()")
func last_threshold_rule() -> String:
	return _last_rule

## @ace_condition
## @ace_name("Has Buff")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.has_buff({buff_id})")
func has_buff(buff_id: String) -> bool:
	return _buffs.has(buff_id)

## @ace_condition
## @ace_name("Buff Is Active")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.buff_is_active({buff_id})")
func buff_is_active(buff_id: String) -> bool:
	return bool((_buffs.get(buff_id, {}) as Dictionary).get("active", false))

## @ace_condition
## @ace_name("Has Buffs With Tag")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.has_buffs_with_tag({tag})")
func has_buffs_with_tag(tag: String) -> bool:
	return buff_count_with_tag(tag) > 0

## @ace_condition
## @ace_name("Has Buffs From Source")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.has_buffs_from_source({source})")
func has_buffs_from_source(source: String) -> bool:
	for buff: Dictionary in _buffs.values():
		if str(buff["source"]) == source:
			return true
	return false

## @ace_condition
## @ace_name("Stat Is At Least")
## @ace_description("The beginner-friendly stat compare (Stat Total works in any expression too).")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.stat_is_at_least({stat}, {value})")
func stat_is_at_least(stat: String, value: float) -> bool:
	return stat_total(stat) >= value

## @ace_action
## @ace_name("Add Buff")
## @ace_description("The one verb that runs the whole system: a named buff targeting a stat with a value and a mode (add / multiply / override - highest override wins). Tags are comma-separated labels for bulk ops, source names who applied it, duration in seconds expires it (0 = permanent). Re-adding an id REPLACES that buff.")
## @ace_param_options(mode add, multiply, override)
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.add_buff({buff_id}, {stat}, {value}, {mode}, {tags}, {source}, {duration})")
func add_buff(buff_id: String, stat: String, value: float, mode: String = "add", tags: String = "", source: String = "", duration: float = 0.0) -> void:
	if buff_id.is_empty() or stat.is_empty() or not mode in ["add", "multiply", "override"]:
		return
	var tag_list: Array[String] = []
	for tag: String in tags.split(",", false):
		tag_list.append(tag.strip_edges())
	_buffs[buff_id] = {"stat": stat, "value": value, "mode": mode, "tags": tag_list, "source": source, "active": true, "time_left": duration if duration > 0.0 else -1.0, "duration": duration, "paused": false}
	buff_added.emit(buff_id, stat)
	_check_thresholds()

## @ace_action
## @ace_name("Remove Buff")
## @ace_description("Removes one buff by id (a no-op when absent).")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.remove_buff({buff_id})")
func remove_buff(buff_id: String) -> void:
	if not _buffs.has(buff_id):
		return
	var stat: String = str((_buffs[buff_id] as Dictionary)["stat"])
	_buffs.erase(buff_id)
	buff_removed.emit(buff_id, stat)
	_check_thresholds()

## @ace_action
## @ace_name("Remove Buffs By Tag")
## @ace_description("Removes every buff carrying the tag - unequip all "equipment" in one action.")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.remove_buffs_by_tag({tag})")
func remove_buffs_by_tag(tag: String) -> void:
	for buff_id: String in _buffs.keys().duplicate():
		if ((_buffs[buff_id] as Dictionary)["tags"] as Array).has(tag):
			remove_buff(buff_id)

## @ace_action
## @ace_name("Remove Buffs By Source")
## @ace_description("Removes every buff a source applied - clear one enemy's curses when it dies.")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.remove_buffs_by_source({source})")
func remove_buffs_by_source(source: String) -> void:
	for buff_id: String in _buffs.keys().duplicate():
		if str((_buffs[buff_id] as Dictionary)["source"]) == source:
			remove_buff(buff_id)

## @ace_action
## @ace_name("Clear Buffs")
## @ace_description("Empties the whole stack (bases stay).")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.clear_buffs()")
func clear_buffs() -> void:
	_buffs.clear()
	_check_thresholds()

## @ace_action
## @ace_name("Set Stat Base")
## @ace_description("Sets a stat's base value - the number the buff math starts from.")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.set_stat_base({stat}, {value})")
func set_stat_base(stat: String, value: float) -> void:
	_bases[stat] = value
	_check_thresholds()

## @ace_action
## @ace_name("Set Buff Active")
## @ace_description("Turns one buff on or off WITHOUT removing it - inactive buffs stay in the stack but contribute nothing (a stance toggle, a disabled rune).")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.set_buff_active({buff_id}, {active})")
func set_buff_active(buff_id: String, active: bool) -> void:
	if _buffs.has(buff_id):
		(_buffs[buff_id] as Dictionary)["active"] = active
		_check_thresholds()

## @ace_action
## @ace_name("Set Buffs Active By Tag")
## @ace_description("Bulk activation by tag - silence every "aura" buff in an antimagic zone.")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.set_buffs_active_by_tag({tag}, {active})")
func set_buffs_active_by_tag(tag: String, active: bool) -> void:
	for buff: Dictionary in _buffs.values():
		if (buff["tags"] as Array).has(tag):
			buff["active"] = active
	_check_thresholds()

## @ace_action
## @ace_name("Set Buff Value")
## @ace_description("Changes a live buff's value in place (a stacking poison that deepens).")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.set_buff_value({buff_id}, {value})")
func set_buff_value(buff_id: String, value: float) -> void:
	if _buffs.has(buff_id):
		(_buffs[buff_id] as Dictionary)["value"] = value
		_check_thresholds()

## @ace_action
## @ace_name("Refresh Buff")
## @ace_description("Restarts a timed buff's countdown (re-drinking the potion refreshes, not stacks).")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.refresh_buff({buff_id}, {duration})")
func refresh_buff(buff_id: String, duration: float) -> void:
	if _buffs.has(buff_id) and duration > 0.0:
		var buff: Dictionary = _buffs[buff_id]
		buff["time_left"] = duration
		buff["duration"] = duration

## @ace_action
## @ace_name("Set Buff Timer Paused")
## @ace_description("Freezes/unfreezes one buff's countdown (cutscenes, pause-adjacent states).")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.set_buff_timer_paused({buff_id}, {paused})")
func set_buff_timer_paused(buff_id: String, paused: bool) -> void:
	if _buffs.has(buff_id):
		(_buffs[buff_id] as Dictionary)["paused"] = paused

## @ace_action
## @ace_name("Advance Timers")
## @ace_description("Advances every unpaused timer by the given seconds - the manual clock for turn-based games (turn ends: Advance Timers 1).")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.advance_timers({seconds})")
func advance_timers(seconds: float) -> void:
	var expired: Array[String] = []
	for buff_id: String in _buffs:
		var buff: Dictionary = _buffs[buff_id]
		if float(buff["time_left"]) < 0.0 or bool(buff["paused"]):
			continue
		buff["time_left"] = float(buff["time_left"]) - seconds
		if float(buff["time_left"]) <= 0.0:
			expired.append(buff_id)
	for buff_id: String in expired:
		var stat: String = str((_buffs[buff_id] as Dictionary)["stat"])
		_buffs.erase(buff_id)
		_last_expired = buff_id
		buff_expired.emit(buff_id, stat)
	if not expired.is_empty():
		_check_thresholds()

## @ace_action
## @ace_name("Add Threshold Rule")
## @ace_description("Watches a stat and fires On Threshold Crossed when its total crosses the value. Direction rising / falling / both; a repeating rule re-arms once the stat is back across, a one-shot stays spent until Re-Arm Threshold Rule.")
## @ace_param_options(direction rising, falling, both)
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.add_threshold_rule({rule_id}, {stat}, {value}, {direction}, {repeating})")
func add_threshold_rule(rule_id: String, stat: String, value: float, direction: String = "rising", repeating: bool = true) -> void:
	if rule_id.is_empty() or stat.is_empty() or not direction in ["rising", "falling", "both"]:
		return
	_rules[rule_id] = {"stat": stat, "value": value, "direction": direction, "repeating": repeating, "armed": true}
	_last_totals[stat] = stat_total(stat)

## @ace_action
## @ace_name("Remove Threshold Rule")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.remove_threshold_rule({rule_id})")
func remove_threshold_rule(rule_id: String) -> void:
	_rules.erase(rule_id)

## @ace_action
## @ace_name("Re-Arm Threshold Rule")
## @ace_description("Re-arms a spent one-shot rule so it can fire again.")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.rearm_threshold_rule({rule_id})")
func rearm_threshold_rule(rule_id: String) -> void:
	if _rules.has(rule_id):
		(_rules[rule_id] as Dictionary)["armed"] = true

## @ace_action
## @ace_name("Load Stat Sheet")
## @ace_description("Applies a StatSheetResource (.tres): its bases set stat bases, its buff rows Add Buff one by one IN ORDER - whole loadouts, classes, and difficulty presets as data.")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.load_stat_sheet({stat_sheet})")
func load_stat_sheet(stat_sheet: Resource) -> void:
	if stat_sheet == null:
		return
	var bases: Variant = stat_sheet.get("bases")
	if bases is Array:
		for row: Variant in bases:
			if row is Dictionary:
				set_stat_base(str((row as Dictionary).get("stat", "")), float((row as Dictionary).get("value", 0.0)))
	var buffs: Variant = stat_sheet.get("buffs")
	if buffs is Array:
		for row: Variant in buffs:
			if row is Dictionary:
				var entry: Dictionary = row
				add_buff(str(entry.get("buff_id", "")), str(entry.get("stat", "")), float(entry.get("value", 0.0)), str(entry.get("mode", "add")), str(entry.get("tags", "")), str(entry.get("source", "")), float(entry.get("duration", 0.0)))

## @ace_hidden
func _check_thresholds() -> void:
	if _rules.is_empty():
		return
	var new_totals: Dictionary = {}
	for rule_id: String in _rules:
		var rule: Dictionary = _rules[rule_id]
		var stat: String = str(rule["stat"])
		if not new_totals.has(stat):
			new_totals[stat] = stat_total(stat)
		var now: float = float(new_totals[stat])
		var before: float = float(_last_totals.get(stat, now))
		var edge: float = float(rule["value"])
		var rose: bool = before < edge and now >= edge
		var fell: bool = before > edge and now <= edge
		var crossed: bool = (rose and str(rule["direction"]) != "falling") or (fell and str(rule["direction"]) != "rising")
		if crossed and bool(rule["armed"]):
			if not bool(rule["repeating"]):
				rule["armed"] = false
			_last_rule = rule_id
			threshold_crossed.emit(rule_id, stat, now)
	for stat: String in new_totals:
		_last_totals[stat] = new_totals[stat]

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	return {
		"bases": _bases.duplicate(true),
		"buffs": _buffs.duplicate(true),
		"rules": _rules.duplicate(true),
		"last_totals": _last_totals.duplicate(true)
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_bases = (state.get("bases", {}) as Dictionary).duplicate(true)
	_buffs = (state.get("buffs", {}) as Dictionary).duplicate(true)
	_rules = (state.get("rules", {}) as Dictionary).duplicate(true)
	# Restoring the last-seen totals keeps threshold rules from spuriously re-firing
	# on the first change after a load.
	_last_totals = (state.get("last_totals", {}) as Dictionary).duplicate(true)

# StatForge behavior: stats as a per-node buff stack. Add Buff targets a stat with a value and a mode - add / multiply / override (highest override wins) - with optional TAGS, a SOURCE, and a DURATION that expires on its own. Stat Total computes (base + adds) * multipliers, clamped or wrapped by the overflow knobs. Remove by id, tag, or source; pause and refresh timers; threshold rules fire On Threshold Crossed when a stat crosses a value. Load whole loadouts from a StatSheetResource (.tres). Two verbs run an RPG stat; the rest scales with your game. This pack is an event sheet - extend it by editing it.
