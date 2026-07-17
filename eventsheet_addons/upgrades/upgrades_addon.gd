## @ace_tags(incremental, idle, upgrade)
## @ace_category("Upgrades")
@icon("res://eventsheet_addons/upgrades/icon.svg")
class_name UpgradesAddon
extends Node
## The stacking buff engine an incremental game is built from, shipped as the Upgrades autoload singleton. Register upgrades by string id with cost curves, max levels, per-level effects, and tags, then buy levels, read the stacked effect, and roll every tagged upgrade into one number.

## @ace_trigger
## @ace_name("On Upgrade Bought")
## @ace_category("Upgrades")
signal on_upgrade_bought
## @ace_trigger
## @ace_name("On Purchase Failed")
## @ace_category("Upgrades")
signal on_purchase_failed

# id -> {base_cost, cost_growth, max_level (-1 = unlimited), per_level, mode ("add"/"mult"), tag, level}.
var _upgrades: Dictionary = {}
# Last-purchase context, read via getters INSIDE On Upgrade Bought / On Purchase Failed.
var _last_cost: float = 0.0
var _last_id: String = ""
var _last_ok: bool = false

## @ace_action
## @ace_featured
## @ace_name("Define Upgrade")
## @ace_category("Upgrades")
## @ace_description("Creates (or resets) an upgrade: base cost, cost growth per level, max level (-1 = unlimited), effect per level, mode ("add" or "mult"), and a tag to group it for Total Multiplier / Total Bonus.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.define_upgrade({id}, {base_cost}, {cost_growth}, {max_level}, {per_level}, {mode}, {tag})")
func define_upgrade(id: String, base_cost: float, cost_growth: float, max_level: int, per_level: float, mode: String, tag: String) -> void:
	_upgrades[id] = {"base_cost": base_cost, "cost_growth": cost_growth, "max_level": max_level, "per_level": per_level, "mode": mode, "tag": tag, "level": 0}

## @ace_action
## @ace_name("Set Effect")
## @ace_category("Upgrades")
## @ace_description("Retunes an existing upgrade's per-level effect and mode without touching its level (for live balancing).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.set_effect({id}, {per_level}, {mode})")
func set_effect(id: String, per_level: float, mode: String) -> void:
	var record: Dictionary = _ensure(id)
	record.per_level = per_level
	record.mode = mode

## @ace_action
## @ace_featured
## @ace_name("Try Purchase")
## @ace_category("Upgrades")
## @ace_description("Buys the next level if `budget` covers Cost Of and it is not maxed. On success records Last Cost and fires On Upgrade Bought (Spend Last Cost from your wallet); otherwise fires On Purchase Failed. Never touches the wallet itself.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.try_purchase({id}, {budget})")
func try_purchase(id: String, budget: float) -> void:
	var cost: float = _cost_of(id)
	if cost < 0.0 or budget < cost:
		_last_ok = false
		_last_id = id
		on_purchase_failed.emit()
		return
	_ensure(id).level += 1
	_last_cost = cost
	_last_id = id
	_last_ok = true
	on_upgrade_bought.emit()

## @ace_action
## @ace_name("Grant Level")
## @ace_category("Upgrades")
## @ace_description("Adds one free level (a reward), up to the max. No cost, no budget check.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.grant_level({id})")
func grant_level(id: String) -> void:
	var record: Dictionary = _ensure(id)
	if not _is_maxed(record):
		record.level += 1

## @ace_action
## @ace_name("Set Level")
## @ace_category("Upgrades")
## @ace_description("Forces an upgrade's level (for a load or cheat), clamped to 0 and the max.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.set_level({id}, {level})")
func set_level(id: String, level: int) -> void:
	var record: Dictionary = _ensure(id)
	var capped: int = maxi(level, 0)
	if int(record.max_level) >= 0:
		capped = mini(capped, int(record.max_level))
	record.level = capped

## @ace_action
## @ace_name("Reset")
## @ace_category("Upgrades")
## @ace_description("Sets every upgrade back to level 0 (keeps the definitions) - for a prestige wipe.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.reset_upgrades()")
func reset_upgrades() -> void:
	for id: String in _upgrades:
		_upgrades[id].level = 0

## @ace_condition
## @ace_name("Is Maxed")
## @ace_category("Upgrades")
## @ace_description("Whether an upgrade is at its max level.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.is_maxed({id})")
func is_maxed(id: String) -> bool:
	return _upgrades.has(id) and _is_maxed(_upgrades[id])

## @ace_condition
## @ace_name("Owns")
## @ace_category("Upgrades")
## @ace_description("Whether an upgrade has at least one level.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.owns({id})")
func owns(id: String) -> bool:
	return _upgrades.has(id) and int(_upgrades[id].level) > 0

## @ace_condition
## @ace_name("Purchase Succeeded")
## @ace_category("Upgrades")
## @ace_description("Whether the last Try Purchase went through (read it right after, or in On Upgrade Bought).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.purchase_succeeded()")
func purchase_succeeded() -> bool:
	return _last_ok

## @ace_expression
## @ace_name("Cost Of")
## @ace_category("Upgrades")
## @ace_description("The next level's price (-1 if maxed or undefined).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.cost_of({id})")
func cost_of(id: String) -> float:
	return _cost_of(id)

## @ace_expression
## @ace_name("Level Of")
## @ace_category("Upgrades")
## @ace_description("An upgrade's current level.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.level_of({id})")
func level_of(id: String) -> int:
	return int(_upgrades[id].level) if _upgrades.has(id) else 0

## @ace_expression
## @ace_name("Max Level Of")
## @ace_category("Upgrades")
## @ace_description("An upgrade's max level (-1 = unlimited).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.max_level_of({id})")
func max_level_of(id: String) -> int:
	return int(_upgrades[id].max_level) if _upgrades.has(id) else 0

## @ace_expression
## @ace_featured
## @ace_name("Effect Of")
## @ace_category("Upgrades")
## @ace_description("An upgrade's current stacked effect (level*per_level for add mode, per_level^level for mult mode).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.effect_of({id})")
func effect_of(id: String) -> float:
	return _effect_of(id)

## @ace_expression
## @ace_name("Total Multiplier")
## @ace_category("Upgrades")
## @ace_description("The product of every mult-mode upgrade sharing this tag (1.0 if none) - multiply production by it.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.total_multiplier({tag})")
func total_multiplier(tag: String) -> float:
	var product: float = 1.0
	for id: String in _upgrades:
		var record: Dictionary = _upgrades[id]
		if str(record.tag) == tag and str(record.mode) == "mult":
			product *= _effect_of(id)
	return product

## @ace_expression
## @ace_name("Total Bonus")
## @ace_category("Upgrades")
## @ace_description("The sum of every add-mode upgrade sharing this tag (0.0 if none) - add it to a base value.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.total_bonus({tag})")
func total_bonus(tag: String) -> float:
	var total: float = 0.0
	for id: String in _upgrades:
		var record: Dictionary = _upgrades[id]
		if str(record.tag) == tag and str(record.mode) == "add":
			total += _effect_of(id)
	return total

## @ace_expression
## @ace_name("Last Cost")
## @ace_category("Upgrades")
## @ace_description("What the last Try Purchase cost - Spend this from your wallet.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.last_cost()")
func last_cost() -> float:
	return _last_cost

## @ace_expression
## @ace_name("Last Upgrade")
## @ace_category("Upgrades")
## @ace_description("The id of the last upgrade bought or failed (read in the trigger).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.last_upgrade()")
func last_upgrade() -> String:
	return _last_id

## @ace_expression
## @ace_name("Upgrade Count")
## @ace_category("Upgrades")
## @ace_description("How many upgrades are defined.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.upgrade_count()")
func upgrade_count() -> int:
	return _upgrades.size()

func _ensure(id: String) -> Dictionary:
	if not _upgrades.has(id):
		_upgrades[id] = {"base_cost": 10.0, "cost_growth": 1.0, "max_level": 1, "per_level": 1.0, "mode": "add", "tag": "", "level": 0}
	return _upgrades[id]

func _is_maxed(record: Dictionary) -> bool:
	# True when an upgrade is at its cap (max_level -1 means never).
	return int(record.max_level) >= 0 and int(record.level) >= int(record.max_level)

func _cost_of(id: String) -> float:
	# The next-level price, or -1 when maxed / undefined.
	if not _upgrades.has(id):
		return -1.0
	var record: Dictionary = _upgrades[id]
	if _is_maxed(record):
		return -1.0
	return float(record.base_cost) * pow(float(record.cost_growth), int(record.level))

func _effect_of(id: String) -> float:
	# One upgrade's current stacked effect: level*per_level for add mode, per_level^level for mult mode.
	if not _upgrades.has(id):
		return 0.0
	var record: Dictionary = _upgrades[id]
	if str(record.mode) == "mult":
		return pow(float(record.per_level), int(record.level))
	return float(record.level) * float(record.per_level)

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	return {
		"upgrades": _upgrades.duplicate(true)
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_upgrades = (state.get("upgrades", {}) as Dictionary).duplicate(true)

# Upgrades: register as the Upgrades autoload. Define Upgrade sets an upgrade's cost curve, max level, per-level effect, mode (add or mult), and tag. Try Purchase(id, budget) buys the next level if it fits the budget, firing On Upgrade Bought (read Last Cost, then Spend it) or On Purchase Failed. Total Multiplier(tag) and Total Bonus(tag) roll every upgrade with a tag into one number. This pack is an event sheet - extend it by editing it.
