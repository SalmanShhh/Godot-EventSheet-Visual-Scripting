## @ace_tags(stats, rpg, data)
## @ace_category("StatForge")
## @ace_requires(StatSheetResource)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/stat_forge/icon.svg")
class_name StatForge
extends Node
## Real, modifiable stats for any node: every modifier that touches its numbers is a named buff that adds, multiplies, or overrides one stat, optionally tagged, sourced, and auto-expiring. Reading the computed result is always one expression - Stat Total.

## @ace_hidden
## The node this behavior acts on. Empty: its parent.
@export var acts_on: Node = null

## The node this behavior acts on (Acts on, or else its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = acts_on if acts_on != null else get_parent() as Node
	if host == null:
		push_warning("Stat Forge needs a parent node: put it under one, or set Acts on.")

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

# --- Choices (the stored words are the promise: saved scenes keep them) ---
## Stop at the min/max boundary.
const OVERFLOW_MODE_CLAMP := "clamp"
## Loop around the min/max range.
const OVERFLOW_MODE_WRAP := "wrap"
## Apply no limit.
const OVERFLOW_MODE_NONE := "none"

# --- Designer knobs (tune in the Inspector) ---
## Temporary buffs count down automatically every frame. Off: drive time yourself with Advance Timers (turn-based games advance per turn).
@export var auto_tick: bool = true:
	set(value):
		auto_tick = value
		# Every write lands here - a sheet's Set Auto Tick action, the Inspector, another script -
		# so the timers follow the knob whoever turned it. The predicate is the tick's own:
		# auto-ticking with nothing counting down is still idle. Safe before the node exists,
		# because the buff table is a typed Dictionary and reads as an empty one until it is
		# initialized, never as a null.
		set_physics_process(value and _any_buff_timer_running())
## What happens when a computed total leaves the min/max range: clamp stops at the boundary, wrap loops around, none applies no limit.
@export_enum("clamp", "wrap", "none") var overflow_mode: String = "clamp"
# @inspector_side_by_side
## The smallest allowed stat total (clamp/wrap modes).
@export var min_value: float = -99999.0
## The largest allowed stat total (clamp/wrap modes).
@export var max_value: float = 99999.0

# --- Internal state ---
## One buff on a stat: what it changes, by how much, and how long it has left.
class StatBuff extends RefCounted:
	## The stat the buff changes.
	var stat: String = ""
	## The amount: added, multiplied in, or the override.
	var value: float = 0.0
	## How the value applies: add, multiply or override.
	var mode: String = "add"
	## The tags the buff answers to, for removing or switching groups of buffs together.
	var tags: Array[String] = []
	## Who applied the buff, for removing everything one source applied.
	var source: String = ""
	## False while the buff is switched off: it stays in the stack but adds nothing.
	var active: bool = true
	## Seconds left on the countdown; -1 for a buff that never runs out.
	var time_left: float = -1.0
	## The seconds the countdown started from; 0 for none.
	var duration: float = 0.0
	## True while the countdown is frozen.
	var paused: bool = false

	# The buff as a saved state holds it.
	func to_dict() -> Dictionary:
		return {"stat": stat, "value": value, "mode": mode, "tags": tags.duplicate(), "source": source, "active": active, "time_left": time_left, "duration": duration, "paused": paused}

	# A buff read back from a saved state; a key the record lacks keeps the value a fresh buff has.
	static func from_dict(data: Dictionary) -> StatBuff:
		var buff: StatBuff = StatBuff.new()
		buff.stat = str(data.get("stat", ""))
		buff.value = float(data.get("value", 0.0))
		buff.mode = str(data.get("mode", "add"))
		for tag: Variant in data.get("tags", []) as Array:
			buff.tags.append(str(tag))
		buff.source = str(data.get("source", ""))
		buff.active = bool(data.get("active", true))
		buff.time_left = float(data.get("time_left", -1.0))
		buff.duration = float(data.get("duration", 0.0))
		buff.paused = bool(data.get("paused", false))
		return buff

## One threshold rule: the stat it watches, the edge, which way counts, and whether it can fire again.
class ThresholdRule extends RefCounted:
	## The stat whose total is watched.
	var stat: String = ""
	## The edge the total has to cross.
	var value: float = 0.0
	## Which crossing counts: rising, falling or both.
	var direction: String = "rising"
	## True when the rule re-arms by itself once the stat is back across.
	var repeating: bool = true
	## True while the rule can fire; a one-shot rule is spent after it does.
	var armed: bool = true

	# The rule as a saved state holds it.
	func to_dict() -> Dictionary:
		return {"stat": stat, "value": value, "direction": direction, "repeating": repeating, "armed": armed}

	# A rule read back from a saved state; a key the record lacks keeps the value a fresh rule has.
	static func from_dict(data: Dictionary) -> ThresholdRule:
		var rule: ThresholdRule = ThresholdRule.new()
		rule.stat = str(data.get("stat", ""))
		rule.value = float(data.get("value", 0.0))
		rule.direction = str(data.get("direction", "rising"))
		rule.repeating = bool(data.get("repeating", true))
		rule.armed = bool(data.get("armed", true))
		return rule

# buff id -> StatBuff. Ids are unique per node: re-adding replaces.
## Active buffs by id, each with its stat, amount and time left.
var _buffs: Dictionary = {}
## Base value of each stat before any buff.
var _bases: Dictionary = {}
# rule id -> ThresholdRule
## Threshold rules by id, each watching one stat's total for a crossing.
var _rules: Dictionary = {}
## Each stat's total as of the last change, used to spot what changed.
var _last_totals: Dictionary = {}
## Id of the buff that expired most recently.
var _last_expired: String = ""
## Name of the rule that was applied most recently.
var _last_rule: String = ""

func _ready() -> void:
	# A node with no timed buff has nothing to count down, so it pays for no frame. Add Buff
	# with a duration turns the timers back on.
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if auto_tick:
		advance_timers(delta)
	# Asked LAST, so a buff applied by an On Buff Expired handler this very frame keeps the
	# timers alive: once no countdown is left, they switch themselves off.
	set_physics_process(auto_tick and _any_buff_timer_running())

## The stat computation: (base + active adds) * active multipliers - unless active
## OVERRIDE buffs exist, where the HIGHEST override wins outright. Overflow applies
## last (clamp / wrap / none).
## @ace_expression
## @ace_name("Stat Total")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.stat_total({stat})")
func stat_total(stat: String) -> float:
	var total: float = float(_bases.get(stat, 0.0))
	var multiplier: float = 1.0
	var best_override: float = -INF
	var has_override: bool = false
	for buff: StatBuff in _buffs.values():
		if buff.stat != stat or not buff.active:
			continue
		match buff.mode:
			"add":
				total += buff.value
			"multiply":
				multiplier *= buff.value
			"override":
				has_override = true
				best_override = maxf(best_override, buff.value)
	var result: float = best_override if has_override else total * multiplier
	match overflow_mode:
		OVERFLOW_MODE_CLAMP:
			result = clampf(result, min_value, max_value)
		OVERFLOW_MODE_WRAP:
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
	var buff: StatBuff = _buffs.get(buff_id, null) as StatBuff
	return buff.value if buff != null else 0.0

## Seconds left on a timed buff (-1 = permanent or unknown).
## @ace_expression
## @ace_name("Buff Time Left")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.buff_time_left({buff_id})")
func buff_time_left(buff_id: String) -> float:
	var buff: StatBuff = _buffs.get(buff_id, null) as StatBuff
	return buff.time_left if buff != null else -1.0

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
	for buff: StatBuff in _buffs.values():
		if buff.tags.has(tag):
			count += 1
	return count

## The buff that expired most recently - read it inside On Buff Expired.
## @ace_expression
## @ace_name("Last Expired Buff")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.last_expired_buff()")
func last_expired_buff() -> String:
	return _last_expired

## The rule that fired most recently - read it inside On Threshold Crossed.
## @ace_expression
## @ace_name("Last Threshold Rule")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.last_threshold_rule()")
func last_threshold_rule() -> String:
	return _last_rule

## Loops the event's actions once per applied buff id (a LOOPING condition: adding it
## creates the loop) - read details per pass with Buff Value / Buff Time Left.
## @ace_looping(buff_id)
## @ace_name("For Each Buff")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.each_buff()")
func each_buff() -> Array:
	return _buffs.keys()

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
	var buff: StatBuff = _buffs.get(buff_id, null) as StatBuff
	return buff != null and buff.active

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
	for buff: StatBuff in _buffs.values():
		if buff.source == source:
			return true
	return false

## The beginner-friendly stat compare (Stat Total works in any expression too).
## @ace_condition
## @ace_name("Stat Is At Least")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.stat_is_at_least({stat}, {value})")
func stat_is_at_least(stat: String, value: float) -> bool:
	return stat_total(stat) >= value

## The one action that runs the whole system: a named buff targeting a stat with a
## value and a mode (add / multiply / override - highest override wins). Tags are
## comma-separated labels for bulk ops, source names who applied it, duration in
## seconds expires it (0 = permanent). Re-adding an id REPLACES that buff.
## @ace_action
## @ace_name("Add Buff")
## @ace_param_options(mode add=Add to the stat, multiply=Multiply the stat, override=Override the stat)
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.add_buff({buff_id}, {stat}, {value}, "{mode}", {tags}, {source}, {duration})")
func add_buff(buff_id: String, stat: String, value: float, mode: String = "add", tags: String = "", source: String = "", duration: float = 0.0) -> void:
	if buff_id.is_empty() or stat.is_empty() or not mode in ["add", "multiply", "override"]:
		return
	var tag_list: Array[String] = []
	for tag: String in tags.split(",", false):
		tag_list.append(tag.strip_edges())
	var buff: StatBuff = StatBuff.new()
	buff.stat = stat
	buff.value = value
	buff.mode = mode
	buff.tags = tag_list
	buff.source = source
	buff.time_left = duration if duration > 0.0 else -1.0
	buff.duration = duration
	_buffs[buff_id] = buff
	if duration > 0.0:
		# A timed buff is a countdown, so the auto-tick comes back on to run it.
		set_physics_process(auto_tick)
	buff_added.emit(buff_id, stat)
	_check_thresholds()

## Removes one buff by id (a no-op when absent).
## @ace_action
## @ace_name("Remove Buff")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.remove_buff({buff_id})")
func remove_buff(buff_id: String) -> void:
	if not _buffs.has(buff_id):
		return
	var stat: String = (_buffs[buff_id] as StatBuff).stat
	_buffs.erase(buff_id)
	buff_removed.emit(buff_id, stat)
	_check_thresholds()

## Removes every buff carrying the tag - unequip all "equipment" in one action.
## @ace_action
## @ace_name("Remove Buffs By Tag")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.remove_buffs_by_tag({tag})")
func remove_buffs_by_tag(tag: String) -> void:
	for buff_id: String in _buffs.keys().duplicate():
		if (_buffs[buff_id] as StatBuff).tags.has(tag):
			remove_buff(buff_id)

## Removes every buff a source applied - clear one enemy's curses when it dies.
## @ace_action
## @ace_name("Remove Buffs By Source")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.remove_buffs_by_source({source})")
func remove_buffs_by_source(source: String) -> void:
	for buff_id: String in _buffs.keys().duplicate():
		if (_buffs[buff_id] as StatBuff).source == source:
			remove_buff(buff_id)

## Empties the whole stack (bases stay).
## @ace_action
## @ace_name("Clear Buffs")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.clear_buffs()")
func clear_buffs() -> void:
	_buffs.clear()
	_check_thresholds()

## Sets a stat's base value - the number the buff math starts from.
## @ace_action
## @ace_name("Set Stat Base")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.set_stat_base({stat}, {value})")
func set_stat_base(stat: String, value: float) -> void:
	_bases[stat] = value
	_check_thresholds()

## Turns one buff on or off WITHOUT removing it - inactive buffs stay in the stack
## but contribute nothing (a stance toggle, a disabled rune).
## @ace_action
## @ace_name("Set Buff Active")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.set_buff_active({buff_id}, {active})")
func set_buff_active(buff_id: String, active: bool) -> void:
	if _buffs.has(buff_id):
		(_buffs[buff_id] as StatBuff).active = active
		_check_thresholds()

## Bulk activation by tag - silence every "aura" buff in an antimagic zone.
## @ace_action
## @ace_name("Set Buffs Active By Tag")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.set_buffs_active_by_tag({tag}, {active})")
func set_buffs_active_by_tag(tag: String, active: bool) -> void:
	for buff: StatBuff in _buffs.values():
		if buff.tags.has(tag):
			buff.active = active
	_check_thresholds()

## Changes a live buff's value in place (a stacking poison that deepens).
## @ace_action
## @ace_name("Set Buff Value")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.set_buff_value({buff_id}, {value})")
func set_buff_value(buff_id: String, value: float) -> void:
	if _buffs.has(buff_id):
		(_buffs[buff_id] as StatBuff).value = value
		_check_thresholds()

## Restarts a timed buff's countdown (re-drinking the potion refreshes, not stacks).
## @ace_action
## @ace_name("Refresh Buff")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.refresh_buff({buff_id}, {duration})")
func refresh_buff(buff_id: String, duration: float) -> void:
	if _buffs.has(buff_id) and duration > 0.0:
		var buff: StatBuff = _buffs[buff_id]
		buff.time_left = duration
		buff.duration = duration
		# A restarted countdown needs the frame back; the timers stop once none is running.
		set_physics_process(auto_tick)

## Freezes/unfreezes one buff's countdown (cutscenes, pause-adjacent states).
## @ace_action
## @ace_name("Set Buff Timer Paused")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.set_buff_timer_paused({buff_id}, {paused})")
func set_buff_timer_paused(buff_id: String, paused: bool) -> void:
	if _buffs.has(buff_id):
		(_buffs[buff_id] as StatBuff).paused = paused
		if not paused:
			# Unfreezing a countdown needs the frame back; the timers stop once none runs.
			set_physics_process(auto_tick)

## Advances every unpaused timer by the given seconds - the manual clock for
## turn-based games (turn ends: Advance Timers 1).
## @ace_action
## @ace_name("Advance Timers")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.advance_timers({seconds})")
func advance_timers(seconds: float) -> void:
	var expired: Array[String] = []
	for buff_id: String in _buffs:
		var buff: StatBuff = _buffs[buff_id]
		if buff.time_left < 0.0 or buff.paused:
			continue
		buff.time_left -= seconds
		if buff.time_left <= 0.0:
			expired.append(buff_id)
	for buff_id: String in expired:
		var stat: String = (_buffs[buff_id] as StatBuff).stat
		_buffs.erase(buff_id)
		_last_expired = buff_id
		buff_expired.emit(buff_id, stat)
	if not expired.is_empty():
		_check_thresholds()

## Watches a stat and fires On Threshold Crossed when its total crosses the value.
## Direction rising / falling / both; a repeating rule re-arms once the stat is back
## across, a one-shot stays spent until Re-Arm Threshold Rule.
## @ace_action
## @ace_name("Add Threshold Rule")
## @ace_param_options(direction rising=Rising past the value, falling=Falling past the value, both=Either direction)
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.add_threshold_rule({rule_id}, {stat}, {value}, "{direction}", {repeating})")
func add_threshold_rule(rule_id: String, stat: String, value: float, direction: String = "rising", repeating: bool = true) -> void:
	if rule_id.is_empty() or stat.is_empty() or not direction in ["rising", "falling", "both"]:
		return
	var rule: ThresholdRule = ThresholdRule.new()
	rule.stat = stat
	rule.value = value
	rule.direction = direction
	rule.repeating = repeating
	_rules[rule_id] = rule
	_last_totals[stat] = stat_total(stat)

## @ace_action
## @ace_name("Remove Threshold Rule")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.remove_threshold_rule({rule_id})")
func remove_threshold_rule(rule_id: String) -> void:
	_rules.erase(rule_id)

## Re-arms a spent one-shot rule so it can fire again.
## @ace_action
## @ace_name("Re-Arm Threshold Rule")
## @ace_icon("res://eventsheet_addons/stat_forge/icon.svg")
## @ace_codegen_template("$StatForge.rearm_threshold_rule({rule_id})")
func rearm_threshold_rule(rule_id: String) -> void:
	if _rules.has(rule_id):
		(_rules[rule_id] as ThresholdRule).armed = true

## Applies a StatSheetResource (.tres): its bases set stat bases, its buff rows Add
## Buff one by one IN ORDER - whole loadouts, classes, and difficulty presets as data.
## @ace_action
## @ace_name("Load Stat Sheet")
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

## Crossing detection: compares each watched stat's total to its last-seen value and
## fires armed rules whose boundary sits between them. Runs after every mutation and
## every timer expiry, so thresholds never miss a change.
## @ace_hidden
func _check_thresholds() -> void:
	if _rules.is_empty():
		return
	var new_totals: Dictionary = {}
	for rule_id: String in _rules:
		var rule: ThresholdRule = _rules[rule_id]
		var stat: String = rule.stat
		if not new_totals.has(stat):
			new_totals[stat] = stat_total(stat)
		var now: float = float(new_totals[stat])
		var before: float = float(_last_totals.get(stat, now))
		var edge: float = rule.value
		var rose: bool = before < edge and now >= edge
		var fell: bool = before > edge and now <= edge
		var crossed: bool = (rose and rule.direction != "falling") or (fell and rule.direction != "rising")
		if crossed and rule.armed:
			if not rule.repeating:
				rule.armed = false
			_last_rule = rule_id
			threshold_crossed.emit(rule_id, stat, now)
	for stat: String in new_totals:
		_last_totals[stat] = new_totals[stat]

## Whether any buff still has a countdown running. A stack of permanent buffs changes
## nothing frame to frame, so it is worth no frame - Stat Total is computed when asked,
## never accumulated by the tick.
## @ace_hidden
func _any_buff_timer_running() -> bool:
	for buff: StatBuff in _buffs.values():
		if buff.time_left > 0.0 and not buff.paused:
			return true
	return false

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	var saved_buffs: Dictionary = {}
	for buff_id: Variant in _buffs:
		saved_buffs[buff_id] = (_buffs[buff_id] as StatBuff).to_dict()
	var saved_rules: Dictionary = {}
	for rule_id: Variant in _rules:
		saved_rules[rule_id] = (_rules[rule_id] as ThresholdRule).to_dict()
	return {
		"bases": _bases.duplicate(true),
		"buffs": saved_buffs,
		"rules": saved_rules,
		"last_totals": _last_totals.duplicate(true)
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_bases = (state.get("bases", {}) as Dictionary).duplicate(true)
	_buffs.clear()
	var saved_buffs: Dictionary = state.get("buffs", {}) as Dictionary
	for buff_id: Variant in saved_buffs:
		_buffs[buff_id] = StatBuff.from_dict(saved_buffs[buff_id] as Dictionary)
	_rules.clear()
	var saved_rules: Dictionary = state.get("rules", {}) as Dictionary
	for rule_id: Variant in saved_rules:
		_rules[rule_id] = ThresholdRule.from_dict(saved_rules[rule_id] as Dictionary)
	# Restoring the last-seen totals keeps threshold rules from spuriously re-firing
	# on the first change after a load.
	_last_totals = (state.get("last_totals", {}) as Dictionary).duplicate(true)
	# Restored buffs resume mid-countdown, so the timers come back on; they switch off
	# again on the first frame nothing is counting down.
	set_physics_process(auto_tick)

# StatForge behavior: stats as a per-node buff stack. Add Buff targets a stat with a value and a mode - add / multiply / override (highest override wins) - with optional TAGS, a SOURCE, and a DURATION that expires on its own. Stat Total computes (base + adds) * multipliers, clamped or wrapped by the overflow knobs. Remove by id, tag, or source; pause and refresh timers; threshold rules fire On Threshold Crossed when a stat crosses a value. Load whole loadouts from a StatSheetResource (.tres). Two actions run an RPG stat; the rest scales with your game. This pack is an event sheet - extend it by editing it.
