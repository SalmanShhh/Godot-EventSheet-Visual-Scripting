## @ace_tags(incremental, idle, clicker)
## @ace_category("Click Power")
@icon("res://eventsheet_addons/click_power/icon.svg")
class_name ClickPowerAddon
extends Node
## The manual-tap income at the heart of a clicker: Do Click works out what a tap earns (base, flat bonus, a share of production, crits) and fires On Click and On Crit. It computes what a tap is worth - you read Last Click and add it to your own wallet.

## @ace_trigger
## @ace_name("On Click")
## @ace_category("Click Power")
signal on_click
## @ace_trigger
## @ace_name("On Crit")
## @ace_category("Click Power")
signal on_crit

# Tuning: yield = (base + flat_bonus + cps_fraction * current_cps) * multiplier, crit optional.
var _base_click: float = 1.0
var _multiplier: float = 1.0
var _flat_bonus: float = 0.0
var _cps_fraction: float = 0.0
var _crit_chance: float = 0.0
var _crit_multiplier: float = 10.0
# Last-click context (read after Do Click / inside On Click).
var _last_amount: float = 0.0
var _last_crit: bool = false
var _total_clicks: int = 0
# Crit rolls; randomize() once so runs differ.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

## @ace_action
## @ace_name("Configure")
## @ace_category("Click Power")
## @ace_description("Sets the base value of one click.")
## @ace_icon("res://eventsheet_addons/click_power/icon.svg")
## @ace_codegen_template("ClickPower.configure({base_click})")
func configure(base_click: float) -> void:
	_base_click = base_click

## @ace_action
## @ace_name("Set Multiplier")
## @ace_category("Click Power")
## @ace_description("Sets the click multiplier - feed it your composed prestige x upgrade x boost value.")
## @ace_icon("res://eventsheet_addons/click_power/icon.svg")
## @ace_codegen_template("ClickPower.set_multiplier({multiplier})")
func set_multiplier(multiplier: float) -> void:
	_multiplier = multiplier

## @ace_action
## @ace_name("Set Flat Bonus")
## @ace_category("Click Power")
## @ace_description("Adds a flat amount to every click before the multiplier (from an upgrade).")
## @ace_icon("res://eventsheet_addons/click_power/icon.svg")
## @ace_codegen_template("ClickPower.set_flat_bonus({bonus})")
func set_flat_bonus(bonus: float) -> void:
	_flat_bonus = bonus

## @ace_action
## @ace_name("Set CPS Fraction")
## @ace_category("Click Power")
## @ace_description("Makes each click also worth this fraction of current production per second (Cookie-Clicker's "clicking is worth X% of CpS"; 0 = off).")
## @ace_icon("res://eventsheet_addons/click_power/icon.svg")
## @ace_codegen_template("ClickPower.set_cps_fraction({fraction})")
func set_cps_fraction(fraction: float) -> void:
	_cps_fraction = fraction

## @ace_action
## @ace_name("Set Crit")
## @ace_category("Click Power")
## @ace_description("Sets the crit chance (0 to 1) and its multiplier (e.g. 10 for a lucky x10 click).")
## @ace_icon("res://eventsheet_addons/click_power/icon.svg")
## @ace_codegen_template("ClickPower.set_crit({chance}, {multiplier})")
func set_crit(chance: float, multiplier: float) -> void:
	_crit_chance = clampf(chance, 0.0, 1.0)
	_crit_multiplier = multiplier

## @ace_action
## @ace_featured
## @ace_name("Do Click")
## @ace_category("Click Power")
## @ace_description("Resolves one tap: computes the yield (pass your current total production per second, or 0), rolls a crit, records Last Click / Was Crit, and fires On Click (and On Crit). Then Add Last Click to your wallet.")
## @ace_icon("res://eventsheet_addons/click_power/icon.svg")
## @ace_codegen_template("ClickPower.do_click({current_cps})")
func do_click(current_cps: float) -> void:
	var amount: float = _yield(current_cps)
	_last_crit = _crit_chance > 0.0 and _rng.randf() < _crit_chance
	if _last_crit:
		amount *= _crit_multiplier
	_last_amount = amount
	_total_clicks += 1
	on_click.emit()
	if _last_crit:
		on_crit.emit()

## @ace_condition
## @ace_name("Was Crit")
## @ace_category("Click Power")
## @ace_description("Whether the last click critted (read after Do Click / inside On Click).")
## @ace_icon("res://eventsheet_addons/click_power/icon.svg")
## @ace_codegen_template("ClickPower.was_crit()")
func was_crit() -> bool:
	return _last_crit

## @ace_expression
## @ace_name("Click Yield")
## @ace_category("Click Power")
## @ace_description("What one click earns right now, without a crit (pass current production per second, or 0) - for a "per click" label.")
## @ace_icon("res://eventsheet_addons/click_power/icon.svg")
## @ace_codegen_template("ClickPower.click_yield({current_cps})")
func click_yield(current_cps: float) -> float:
	return _yield(current_cps)

## @ace_expression
## @ace_featured
## @ace_name("Last Click")
## @ace_category("Click Power")
## @ace_description("What the last Do Click earned (after any crit) - Add this to your wallet.")
## @ace_icon("res://eventsheet_addons/click_power/icon.svg")
## @ace_codegen_template("ClickPower.last_click()")
func last_click() -> float:
	return _last_amount

## @ace_expression
## @ace_name("Total Clicks")
## @ace_category("Click Power")
## @ace_description("How many clicks have been resolved.")
## @ace_icon("res://eventsheet_addons/click_power/icon.svg")
## @ace_codegen_template("ClickPower.total_clicks()")
func total_clicks() -> int:
	return _total_clicks

## @ace_expression
## @ace_name("Click Multiplier")
## @ace_category("Click Power")
## @ace_description("The current click multiplier.")
## @ace_icon("res://eventsheet_addons/click_power/icon.svg")
## @ace_codegen_template("ClickPower.click_multiplier()")
func click_multiplier() -> float:
	return _multiplier

## @ace_expression
## @ace_name("Crit Chance")
## @ace_category("Click Power")
## @ace_description("The current crit chance, 0 to 1.")
## @ace_icon("res://eventsheet_addons/click_power/icon.svg")
## @ace_codegen_template("ClickPower.crit_chance()")
func crit_chance() -> float:
	return _crit_chance

func _yield(current_cps: float) -> float:
	# The deterministic (no-crit) yield of one click at the given current production per second.
	return (_base_click + _flat_bonus + _cps_fraction * current_cps) * _multiplier

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	return {
		"base_click": _base_click,
		"multiplier": _multiplier,
		"flat_bonus": _flat_bonus,
		"cps_fraction": _cps_fraction,
		"crit_chance": _crit_chance,
		"crit_multiplier": _crit_multiplier,
		"total_clicks": _total_clicks
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_base_click = float(state.get("base_click", 1.0))
	_multiplier = float(state.get("multiplier", 1.0))
	_flat_bonus = float(state.get("flat_bonus", 0.0))
	_cps_fraction = float(state.get("cps_fraction", 0.0))
	_crit_chance = float(state.get("crit_chance", 0.0))
	_crit_multiplier = float(state.get("crit_multiplier", 10.0))
	_total_clicks = int(state.get("total_clicks", 0))

# Click Power: register as the ClickPower autoload. Do Click(current_cps) works out one tap's yield - (base + flat bonus + cps fraction * current_cps) * multiplier, then a possible crit - records it as Last Click and fires On Click / On Crit; you Add Last Click to your wallet. Click Yield previews the no-crit value for a label. This pack is an event sheet - extend it by editing it.
