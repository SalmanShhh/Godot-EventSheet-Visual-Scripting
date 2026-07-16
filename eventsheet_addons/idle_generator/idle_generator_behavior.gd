## @ace_tags(incremental, idle, economy)
## @ace_category("Idle Generator")
@icon("res://eventsheet_addons/idle_generator/icon.svg")
class_name IdleGeneratorBehavior
extends Node

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("IdleGeneratorBehavior behavior requires a Node parent.")

## @ace_trigger
## @ace_name("On Purchased")
signal on_purchased
## @ace_trigger
## @ace_name("On Cycle Complete")
signal on_cycle_complete

var _cycle_progress: float = 0.0
var _pending: float = 0.0
## Cost of the FIRST unit. Each further unit costs cost_growth times more.
@export var base_cost: float = 10.0
## Output of ONE unit - per second in continuous mode, or per cycle when Cycle Time > 0.
@export var base_output: float = 1.0
## How much each unit multiplies the price (1.15 = +15% each, the genre default). 1.0 = flat price.
@export var cost_growth: float = 1.15
## 0 = continuous production (Output Per Second). Above 0 = a fill-and-collect cycle this many seconds long (AdVenture-Capitalist style); read Pending and call Collect.
@export var cycle_time: float = 0.0
var last_bought: int = 0
var last_collected: float = 0.0
var last_spent: float = 0.0
## A multiplier over the whole generator's output - feed it your composed prestige x upgrade x boost multiplier.
@export var output_multiplier: float = 1.0
## How many are owned. Set a starting count here, or leave 0 and buy them in play.
@export var owned: int = 0

func _process(delta: float) -> void:
	if cycle_time <= 0.0 or owned <= 0:
		return
	_cycle_progress += delta
	while _cycle_progress >= cycle_time:
		_cycle_progress -= cycle_time
		_pending += float(owned) * base_output * output_multiplier
		on_cycle_complete.emit()

## @ace_action
## @ace_name("Buy One")
## @ace_category("Idle Generator")
## @ace_description("Adds one unit and records its price as Last Cost (Spend that from your wallet). Guard with Can Afford Next first.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.buy_one()")
func buy_one() -> void:
	last_spent = _cost_for_n(1)
	owned += 1
	last_bought = 1
	on_purchased.emit()

## @ace_action
## @ace_name("Buy Amount")
## @ace_category("Idle Generator")
## @ace_description("Adds `count` units at once and records the total price as Last Cost.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.buy_amount({count})")
func buy_amount(count: int) -> void:
	if count <= 0:
		return
	last_spent = _cost_for_n(count)
	owned += count
	last_bought = count
	on_purchased.emit()

## @ace_action
## @ace_name("Buy Max")
## @ace_category("Idle Generator")
## @ace_description("Buys as many as `budget` affords, recording the exact total as Last Cost and the count as Last Bought. Buys nothing if not even one is affordable.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.buy_max({budget})")
func buy_max(budget: float) -> void:
	var count: int = _max_affordable(budget)
	if count <= 0:
		last_bought = 0
		last_spent = 0.0
		return
	last_spent = _cost_for_n(count)
	owned += count
	last_bought = count
	on_purchased.emit()

## @ace_action
## @ace_name("Set Owned")
## @ace_category("Idle Generator")
## @ace_description("Forces the owned count to a value (clamped to 0). Does not record a cost.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.set_owned({count})")
func set_owned(count: int) -> void:
	owned = maxi(count, 0)

## @ace_action
## @ace_name("Grant")
## @ace_category("Idle Generator")
## @ace_description("Adds free units - a reward or a starting bonus (no cost recorded).")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.grant({count})")
func grant(count: int) -> void:
	owned += maxi(count, 0)

## @ace_action
## @ace_name("Set Output Multiplier")
## @ace_category("Idle Generator")
## @ace_description("Sets the overall output multiplier - feed it your composed prestige x upgrade x boost value.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.set_output_multiplier({multiplier})")
func set_output_multiplier(multiplier: float) -> void:
	output_multiplier = multiplier

## @ace_action
## @ace_name("Collect")
## @ace_category("Idle Generator")
## @ace_description("Cycle mode: hands you the banked output as Last Collected and clears the pending pile. Call it on On Cycle Complete (or from a manager) and credit Last Collected to your wallet.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.collect()")
func collect() -> void:
	last_collected = _pending
	_pending = 0.0

## @ace_action
## @ace_name("Reset")
## @ace_category("Idle Generator")
## @ace_description("Clears owned, pending output, and cycle progress - for a prestige wipe.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.reset_generator()")
func reset_generator() -> void:
	owned = 0
	_pending = 0.0
	_cycle_progress = 0.0

## @ace_condition
## @ace_name("Can Afford Next")
## @ace_category("Idle Generator")
## @ace_description("Whether `budget` covers the next single unit's price.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.can_afford_next({budget})")
func can_afford_next(budget: float) -> bool:
	return budget >= _cost_for_n(1)

## @ace_condition
## @ace_name("Is Owned")
## @ace_category("Idle Generator")
## @ace_description("Whether at least one unit is owned.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.is_owned()")
func is_owned() -> bool:
	return owned > 0

## @ace_expression
## @ace_name("Owned")
## @ace_category("Idle Generator")
## @ace_description("How many units are owned.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.owned_count()")
func owned_count() -> int:
	return owned

## @ace_expression
## @ace_name("Next Cost")
## @ace_category("Idle Generator")
## @ace_description("The price of the next single unit.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.next_cost()")
func next_cost() -> float:
	return _cost_for_n(1)

## @ace_expression
## @ace_name("Cost For")
## @ace_category("Idle Generator")
## @ace_description("The total price to buy `count` more units right now.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.cost_for({count})")
func cost_for(count: int) -> float:
	return _cost_for_n(count)

## @ace_expression
## @ace_name("Max Affordable")
## @ace_category("Idle Generator")
## @ace_description("How many units `budget` can buy.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.max_affordable({budget})")
func max_affordable(budget: float) -> int:
	return _max_affordable(budget)

## @ace_expression
## @ace_name("Cost To Buy Max")
## @ace_category("Idle Generator")
## @ace_description("The exact total spent if you Buy Max with `budget`.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.cost_to_buy_max({budget})")
func cost_to_buy_max(budget: float) -> float:
	return _cost_for_n(_max_affordable(budget))

## @ace_expression
## @ace_name("Output Per Second")
## @ace_category("Idle Generator")
## @ace_description("Current production per second (owned * base_output * multiplier; in cycle mode, the lump divided by cycle time).")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.output_per_second()")
func output_per_second() -> float:
	var raw: float = float(owned) * base_output * output_multiplier
	return raw / cycle_time if cycle_time > 0.0 else raw

## @ace_expression
## @ace_name("Production Over")
## @ace_category("Idle Generator")
## @ace_description("How much is produced over `seconds` at the current rate - pass delta to credit each frame.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.production_over({seconds})")
func production_over(seconds: float) -> float:
	return output_per_second() * seconds

## @ace_expression
## @ace_name("Pending")
## @ace_category("Idle Generator")
## @ace_description("Cycle mode: output banked and waiting for Collect.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.pending_output()")
func pending_output() -> float:
	return _pending

## @ace_expression
## @ace_name("Cycle Progress")
## @ace_category("Idle Generator")
## @ace_description("Cycle mode: how full the current cycle is, 0 to 1 (0 in continuous mode).")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.cycle_progress()")
func cycle_progress() -> float:
	return _cycle_progress / cycle_time if cycle_time > 0.0 else 0.0

## @ace_expression
## @ace_name("Last Cost")
## @ace_category("Idle Generator")
## @ace_description("What the last Buy cost - Spend this from your wallet.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.last_cost()")
func last_cost() -> float:
	return last_spent

## @ace_expression
## @ace_name("Last Bought")
## @ace_category("Idle Generator")
## @ace_description("How many units the last Buy added (0 if Buy Max could not afford any).")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.last_bought_count()")
func last_bought_count() -> int:
	return last_bought

## @ace_expression
## @ace_name("Last Collected")
## @ace_category("Idle Generator")
## @ace_description("How much the last Collect handed you.")
## @ace_icon("res://eventsheet_addons/idle_generator/icon.svg")
## @ace_codegen_template("$IdleGeneratorBehavior.last_collected_amount()")
func last_collected_amount() -> float:
	return last_collected

func _cost_for_n(count: int) -> float:
	# Total cost to buy `count` more units from the current owned count - the geometric series
	# base*r^owned*(r^count-1)/(r-1). Guards count<=0 (free) and r~1 (flat price = linear).
	if count <= 0:
		return 0.0
	# Costs must never fall: a growth below 1 makes the series converge, and Buy Max's verify
	# loop would spin forever once the budget exceeds that finite total. Treat sub-1 growth as flat.
	var growth: float = maxf(cost_growth, 1.0)
	if absf(growth - 1.0) < 1e-12:
		return base_cost * float(count)
	return base_cost * pow(growth, owned) * (pow(growth, count) - 1.0) / (growth - 1.0)

func _max_affordable(budget: float) -> int:
	# The most units affordable for `budget`. Closed form, then a +/-1 verify against the real cost
	# to correct float drift at exact-cost boundaries (usually 0-1 steps). 0 if the next unit is too dear.
	if base_cost <= 0.0:
		return 0
	var growth: float = maxf(cost_growth, 1.0)
	if budget < base_cost * pow(growth, owned):
		return 0
	if absf(growth - 1.0) < 1e-12:
		return int(floor(budget / base_cost))
	var count: int = int(floor(log(1.0 + budget * (growth - 1.0) / (base_cost * pow(growth, owned))) / log(growth)))
	while count > 0 and _cost_for_n(count) > budget:
		count -= 1
	while _cost_for_n(count + 1) <= budget:
		count += 1
	return maxi(count, 0)

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	return {
		"owned": owned,
		"cycle_progress": _cycle_progress,
		"pending": _pending,
		"output_multiplier": output_multiplier
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	owned = int(state.get("owned", 0))
	_cycle_progress = float(state.get("cycle_progress", 0.0))
	_pending = float(state.get("pending", 0.0))
	output_multiplier = float(state.get("output_multiplier", 1.0))

# Idle Generator: a buy-more-to-make-more building. Cost climbs geometrically (base_cost * cost_growth^owned); Buy One / Buy Amount / Buy Max compute the exact geometric-series price and record it as Last Cost for your sheet to Spend. Continuous mode gives Output Per Second; set Cycle Time > 0 for a fill-and-collect building that fires On Cycle Complete. This pack is an event sheet - extend it by editing it.
