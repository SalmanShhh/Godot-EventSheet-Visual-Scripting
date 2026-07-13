## @ace_tags(incremental, idle, prestige)
## @ace_category("Prestige")
@icon("res://eventsheet_addons/behavior.svg")
class_name PrestigeAddon
extends Node

## @ace_trigger
## @ace_name("On Prestige")
## @ace_category("Prestige")
signal on_prestige

# Earnings THIS run - drives the gain and resets to 0 on Do Prestige (so points never double-award).
var _run_earned: float = 0.0
# All-time earnings - never reset; for achievements and lifetime stats.
var _total_earned: float = 0.0
# Banked prestige currency and how many times the player has prestiged.
var _points: float = 0.0
var _level: int = 0
# Tuning: gain = floor((run_earned / requirement) ^ exponent); multiplier = 1 + points * bonus.
var _requirement: float = 1000000.0
var _exponent: float = 0.5
var _bonus_per_point: float = 0.02
# Points banked by the most recent Do Prestige (read inside On Prestige).
var _last_gain: int = 0

## @ace_action
## @ace_name("Configure")
## @ace_category("Prestige")
## @ace_description("Sets the requirement (run earnings before you gain a point), the exponent (curve; 0.5 = square-root, the usual), and the bonus each banked point adds to Prestige Multiplier.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("Prestige.configure({requirement}, {exponent}, {bonus_per_point})")
func configure(requirement: float, exponent: float, bonus_per_point: float) -> void:
	_requirement = maxf(requirement, 0.0)
	_exponent = exponent
	_bonus_per_point = bonus_per_point

## @ace_action
## @ace_name("Track Earned")
## @ace_category("Prestige")
## @ace_description("Records earnings toward prestige - call it wherever the player earns the prestige currency. Feeds both the run total (drives the gain) and the all-time Total Earned.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("Prestige.track_earned({amount})")
func track_earned(amount: float) -> void:
	var gained: float = maxf(amount, 0.0)
	_run_earned += gained
	_total_earned += gained

## @ace_action
## @ace_name("Do Prestige")
## @ace_category("Prestige")
## @ace_description("Banks the current Prestige Gain, raises the prestige level, and clears the run total. Does nothing if the gain is 0. Reset your currencies and generators in the same event, reading Prestige Gain first.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("Prestige.do_prestige()")
func do_prestige() -> void:
	var gain: int = _gain()
	if gain <= 0:
		return
	_points += float(gain)
	_level += 1
	_last_gain = gain
	_run_earned = 0.0
	on_prestige.emit()

## @ace_action
## @ace_name("Set Points")
## @ace_category("Prestige")
## @ace_description("Forces banked prestige points to a value (for a load or a cheat menu).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("Prestige.set_points({points})")
func set_points(points: float) -> void:
	_points = maxf(points, 0.0)

## @ace_action
## @ace_name("Hard Reset")
## @ace_category("Prestige")
## @ace_description("Wipes EVERYTHING - points, level, run and all-time earnings. A full new-game, not a prestige.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("Prestige.hard_reset()")
func hard_reset() -> void:
	_run_earned = 0.0
	_total_earned = 0.0
	_points = 0.0
	_level = 0
	_last_gain = 0

## @ace_condition
## @ace_name("Can Prestige")
## @ace_category("Prestige")
## @ace_description("Whether prestiging now would bank at least one point.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("Prestige.can_prestige()")
func can_prestige() -> bool:
	return _gain() > 0

## @ace_expression
## @ace_name("Prestige Gain")
## @ace_category("Prestige")
## @ace_description("How many prestige points the current run would bank right now.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("Prestige.prestige_gain()")
func prestige_gain() -> int:
	return _gain()

## @ace_expression
## @ace_name("Prestige Points")
## @ace_category("Prestige")
## @ace_description("Banked prestige currency.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("Prestige.prestige_points()")
func prestige_points() -> float:
	return _points

## @ace_expression
## @ace_name("Prestige Level")
## @ace_category("Prestige")
## @ace_description("How many times the player has prestiged.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("Prestige.prestige_level()")
func prestige_level() -> int:
	return _level

## @ace_expression
## @ace_name("Prestige Multiplier")
## @ace_category("Prestige")
## @ace_description("The permanent production multiplier from banked points: 1 + points * bonus.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("Prestige.prestige_multiplier()")
func prestige_multiplier() -> float:
	return 1.0 + _points * _bonus_per_point

## @ace_expression
## @ace_name("Run Earned")
## @ace_category("Prestige")
## @ace_description("Earnings this run (resets on Do Prestige).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("Prestige.run_earned()")
func run_earned() -> float:
	return _run_earned

## @ace_expression
## @ace_name("Total Earned")
## @ace_category("Prestige")
## @ace_description("All-time earnings (never resets).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("Prestige.total_earned()")
func total_earned() -> float:
	return _total_earned

## @ace_expression
## @ace_name("Last Gain")
## @ace_category("Prestige")
## @ace_description("Points banked by the most recent Do Prestige (read inside On Prestige).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("Prestige.last_gain()")
func last_gain() -> int:
	return _last_gain

## @ace_expression
## @ace_name("Requirement")
## @ace_category("Prestige")
## @ace_description("The run earnings needed before the first point.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("Prestige.requirement()")
func requirement() -> float:
	return _requirement

## @ace_expression
## @ace_name("Earned For Next Point")
## @ace_category("Prestige")
## @ace_description("The run earnings needed to reach the next prestige point.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("Prestige.earned_for_next()")
func earned_for_next() -> float:
	var current: int = _gain()
	if current >= 9223372036854775807:
		return INF
	return _earned_for(current + 1)

## @ace_expression
## @ace_name("Progress To Next")
## @ace_category("Prestige")
## @ace_description("How close this run is to the next point, 0 to 1 (for a progress bar).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("Prestige.progress_to_next()")
func progress_to_next() -> float:
	var current: int = _gain()
	if current >= 9223372036854775807:
		return 1.0
	var lower: float = _earned_for(current) if current > 0 else 0.0
	var upper: float = _earned_for(current + 1)
	if upper <= lower:
		return 0.0
	return clampf((_run_earned - lower) / (upper - lower), 0.0, 1.0)

func _gain() -> int:
	# Prestige points the current run would bank. Guards requirement<=0 (divide by zero) and
	# below-requirement (ratio < 1) up front so it is correct for any exponent, and clamps an
	# overflowed pow() so int(floor(...)) is never fed INF/NAN.
	if _requirement <= 0.0 or _run_earned < _requirement:
		return 0
	var raw: float = pow(_run_earned / _requirement, _exponent)
	# Also saturate a FINITE value above int64 range: at the default exponent 0.5 this is reached
	# around 1e46 run earnings, and int(floor(over_range)) would wrap to a large NEGATIVE int64.
	if is_inf(raw) or is_nan(raw) or raw >= 9223372036854775807.0:
		return 9223372036854775807
	return int(floor(raw))

func _earned_for(points: int) -> float:
	# The run earnings needed to reach a given number of points (the inverse of _gain).
	if points <= 0:
		return 0.0
	if _exponent <= 0.0:
		return _requirement
	return _requirement * pow(float(points), 1.0 / _exponent)

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	# Tuning vars (requirement/exponent/bonus) are NOT saved - sheets re-Configure on ready.
	return {
		"run_earned": _run_earned,
		"total_earned": _total_earned,
		"points": _points,
		"level": _level
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_run_earned = float(state.get("run_earned", 0.0))
	_total_earned = float(state.get("total_earned", 0.0))
	_points = float(state.get("points", 0.0))
	_level = int(state.get("level", 0))

# Prestige: register as the Prestige autoload. Configure a requirement + exponent + bonus per point once, Track Earned as the player earns this run, then Do Prestige to bank points (Prestige Gain), raise the level, and reset the run. Prestige Multiplier = 1 + points * bonus is the permanent boost. Do Prestige clears the RUN total (no double-award); Total Earned is the all-time tally. This pack is an event sheet - extend it by editing it.
