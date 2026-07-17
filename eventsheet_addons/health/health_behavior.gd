## @ace_category("Health")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/health/icon.svg")
class_name SimpleHealthBehavior
extends Node
## Gives any Node2D a real health model: current health seeded from a max, damage and healing, a death latch, a resistance multiplier, and named shield/armour pools that intercept damage in priority order. Triggers fire on damage, death, and pool breaks so your sheet reacts without writing GDScript.

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("SimpleHealthBehavior behavior requires a Node2D parent.")

## @ace_trigger
## @ace_name("On Damaged")
signal on_damaged
## @ace_trigger
## @ace_name("On Death")
signal on_death
## @ace_trigger
## @ace_name("On Healed")
signal on_healed
## @ace_trigger
## @ace_name("On Health Changed")
signal on_health_changed
## @ace_trigger
## @ace_name("On Revived")
signal on_revived
## @ace_trigger
## @ace_name("On Health Pool Added")
signal on_health_pool_added
## @ace_trigger
## @ace_name("On Health Pool Absorbed")
signal on_health_pool_absorbed
## @ace_trigger
## @ace_name("On Health Pool Depleted")
signal on_health_pool_depleted

var current_health: float = 100.0
## queue_free the host the moment health reaches 0 (after On Death fires).
@export var destroy_on_death: bool = false
var health_absorption_rate: float = 1.0
var health_pools: Dictionary = {}
## Start invulnerable: takeDamage is a no-op while true.
@export var invulnerable: bool = false
var is_dead_flag: bool = false
var last_damage: float = 0.0
var last_heal: float = 0.0
var last_pool_damage_absorbed: float = 0.0
var last_trigger_pool_type: String = ""
## Starting max HP; current_health initialises to this.
@export_range(1, 10000, 1) var max_health: float = 100.0

## A named health pool (shield / armour) - typed so the absorption + decay hot paths read
## fields directly instead of float()-casting an untyped Dictionary entry every frame.
class HealthPool:
	var amount: float = 0.0
	var decay_rate: float = 0.0
	var absorption_rate: float = 1.0
	var last_absorbed: float = 0.0
	var priority: float = 0.0
func _get_pool(type: String) -> HealthPool:
	if not health_pools.has(type):
		health_pools[type] = HealthPool.new()
	return health_pools[type]

func _ready() -> void:
	current_health = max_health

func _process(delta: float) -> void:
	if health_pools.is_empty():
		return
	var depleted: Array = []
	for pool_name in _sorted_pool_keys():
		var pool: HealthPool = health_pools[pool_name]
		if pool.amount > 0.0 and pool.decay_rate > 0.0:
			pool.amount = maxf(0.0, pool.amount - pool.decay_rate * delta)
			if pool.amount <= 0.0:
				depleted.append(pool_name)
	for pool_name in depleted:
		last_trigger_pool_type = pool_name
		on_health_pool_depleted.emit()

## @ace_action
## @ace_featured
## @ace_name("Take Damage")
## @ace_category("Health")
## @ace_description("Applies damage; health pools absorb in ascending-priority order before real HP.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.take_damage({amount})")
func take_damage(amount: float) -> void:
	if amount <= 0.0 or invulnerable or is_dead_flag:
		return
	var remaining: float = amount
	for pool_name: String in _sorted_pool_keys():
		if remaining <= 0.0:
			break
		var pool: HealthPool = health_pools[pool_name]
		if pool.amount <= 0.0:
			continue
		var absorption: float = pool.absorption_rate
		var max_absorbable: float = (pool.amount / absorption) if absorption > 0.0 else INF
		var absorbed: float = minf(remaining, max_absorbable)
		pool.amount = maxf(0.0, pool.amount - absorbed * absorption)
		pool.last_absorbed = absorbed
		remaining -= absorbed
		last_trigger_pool_type = pool_name
		last_pool_damage_absorbed = absorbed
		on_health_pool_absorbed.emit()
		if pool.amount <= 0.0:
			on_health_pool_depleted.emit()
	if remaining <= 0.0:
		return
	var real_damage: float = remaining * health_absorption_rate
	last_damage = real_damage
	current_health -= real_damage
	if current_health <= 0.0:
		current_health = 0.0
		is_dead_flag = true
		on_death.emit()
		on_health_changed.emit()
		if destroy_on_death and host != null:
			host.call_deferred("queue_free")
	else:
		on_damaged.emit()
		on_health_changed.emit()

## @ace_action
## @ace_featured
## @ace_name("Heal")
## @ace_category("Health")
## @ace_description("Restores health up to max_health.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.heal({amount})")
func heal(amount: float) -> void:
	if is_dead_flag:
		return
	last_heal = amount
	current_health = minf(current_health + amount, max_health)
	on_healed.emit()
	on_health_changed.emit()

## @ace_action
## @ace_name("Set Health")
## @ace_category("Health")
## @ace_description("Sets current health directly, firing damage/heal/death as appropriate.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_health_value({amount})")
func set_health_value(amount: float) -> void:
	if is_dead_flag:
		return
	var new_value: float = maxf(0.0, minf(amount, max_health))
	var old_value: float = current_health
	if new_value == old_value:
		return
	current_health = new_value
	if new_value <= 0.0:
		is_dead_flag = true
		last_damage = old_value - new_value
		on_death.emit()
		on_health_changed.emit()
		if destroy_on_death and host != null:
			host.call_deferred("queue_free")
	elif new_value < old_value:
		last_damage = old_value - new_value
		on_damaged.emit()
		on_health_changed.emit()
	else:
		last_heal = new_value - old_value
		on_healed.emit()
		on_health_changed.emit()

## @ace_action
## @ace_name("Set Max Health")
## @ace_category("Health")
## @ace_description("Sets max health (clamps current down if needed).")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_max_health_value({amount})")
func set_max_health_value(amount: float) -> void:
	max_health = maxf(1.0, amount)
	if current_health > max_health:
		current_health = max_health
		on_health_changed.emit()

## @ace_action
## @ace_name("Set Invulnerable")
## @ace_category("Health")
## @ace_description("Toggles invulnerability (takeDamage no-op while true).")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_invulnerable({state})")
func set_invulnerable(state: bool) -> void:
	invulnerable = state

## @ace_action
## @ace_name("Set Health Absorption Rate")
## @ace_category("Health")
## @ace_description("Damage multiplier for real HP (resistance); 0 = invulnerable.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_health_absorption_rate({rate})")
func set_health_absorption_rate(rate: float) -> void:
	health_absorption_rate = maxf(0.0, rate)
	invulnerable = (rate == 0.0)

## @ace_action
## @ace_name("Add Health Pool")
## @ace_category("Health")
## @ace_description("Adds to a named health pool (shield/armour).")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.add_health_pool({type}, {amount})")
func add_health_pool(type: String, amount: float) -> void:
	if amount <= 0.0:
		return
	var pool: HealthPool = _get_pool(type)
	pool.amount = pool.amount + amount
	last_trigger_pool_type = type
	on_health_pool_added.emit()

## @ace_action
## @ace_name("Set Health Pool")
## @ace_category("Health")
## @ace_description("Sets a health pool amount (fires Added only when it increases).")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_health_pool({type}, {amount})")
func set_health_pool(type: String, amount: float) -> void:
	var pool: HealthPool = _get_pool(type)
	var new_amount: float = maxf(0.0, amount)
	if new_amount > pool.amount:
		pool.amount = new_amount
		last_trigger_pool_type = type
		on_health_pool_added.emit()
	else:
		pool.amount = new_amount

## @ace_action
## @ace_name("Clear Health Pool")
## @ace_category("Health")
## @ace_description("Zeroes one named health pool.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.clear_health_pool({type})")
func clear_health_pool(type: String) -> void:
	if health_pools.has(type):
		(health_pools[type] as HealthPool).amount = 0.0

## @ace_action
## @ace_name("Clear All Health Pools")
## @ace_category("Health")
## @ace_description("Zeroes every health pool.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.clear_all_health_pools()")
func clear_all_health_pools() -> void:
	for pool_name: String in health_pools.keys():
		(health_pools[pool_name] as HealthPool).amount = 0.0

## @ace_action
## @ace_name("Set Health Pool Decay Rate")
## @ace_category("Health")
## @ace_description("Sets a pool's per-second decay rate.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_health_pool_decay_rate({type}, {rate})")
func set_health_pool_decay_rate(type: String, rate: float) -> void:
	_get_pool(type).decay_rate = maxf(0.0, rate)

## @ace_action
## @ace_name("Set Health Pool Absorption Rate")
## @ace_category("Health")
## @ace_description("Sets a pool's absorption multiplier (how hard it spends to soak damage).")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_health_pool_absorption_rate({type}, {rate})")
func set_health_pool_absorption_rate(type: String, rate: float) -> void:
	_get_pool(type).absorption_rate = maxf(0.0, rate)

## @ace_action
## @ace_name("Set Health Pool Rates")
## @ace_category("Health")
## @ace_description("Sets a pool's decay and absorption rates at once.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_health_pool_rates({type}, {decay_rate}, {absorption_rate})")
func set_health_pool_rates(type: String, decay_rate: float, absorption_rate: float) -> void:
	var pool: HealthPool = _get_pool(type)
	pool.decay_rate = maxf(0.0, decay_rate)
	pool.absorption_rate = maxf(0.0, absorption_rate)

## @ace_action
## @ace_name("Set Health Pool Priority")
## @ace_category("Health")
## @ace_description("Sets a pool's absorption priority (lower absorbs first).")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_health_pool_priority({type}, {priority})")
func set_health_pool_priority(type: String, priority: float) -> void:
	_get_pool(type).priority = priority

## @ace_action
## @ace_name("Setup Health Pool")
## @ace_category("Health")
## @ace_description("Creates/configures a health pool in one call.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.setup_health_pool({type}, {amount}, {decay_rate}, {absorption_rate}, {priority})")
func setup_health_pool(type: String, amount: float, decay_rate: float, absorption_rate: float, priority: float) -> void:
	var pool: HealthPool = _get_pool(type)
	pool.amount = maxf(0.0, amount)
	pool.decay_rate = maxf(0.0, decay_rate)
	pool.absorption_rate = maxf(0.0, absorption_rate)
	pool.priority = priority

## @ace_action
## @ace_name("Revive")
## @ace_category("Health")
## @ace_description("Clears death and restores health (amount<=0 → full).")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.revive({amount})")
func revive(amount: float) -> void:
	is_dead_flag = false
	current_health = minf(amount, max_health) if amount > 0.0 else max_health
	on_revived.emit()
	on_health_changed.emit()

## @ace_condition
## @ace_name("Is Dead")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.is_dead()")
func is_dead() -> bool:
	return is_dead_flag

## @ace_condition
## @ace_name("Is Invulnerable")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.is_invulnerable()")
func is_invulnerable() -> bool:
	return invulnerable

## @ace_condition
## @ace_name("Has Any Health Pool")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.has_any_health_pool()")
func has_any_health_pool() -> bool:
	for pool_name: String in health_pools.keys():
		if (health_pools[pool_name] as HealthPool).amount > 0.0:
			return true
	return false

## @ace_condition
## @ace_name("Has Health Pool")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.has_health_pool({type})")
func has_health_pool(type: String) -> bool:
	return health_pools.has(type) and (health_pools[type] as HealthPool).amount > 0.0

## @ace_condition
## @ace_name("Health Pool Is Type")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.is_health_pool_type({type})")
func is_health_pool_type(type: String) -> bool:
	return last_trigger_pool_type == type

## @ace_expression
## @ace_name("Current Health")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.current_health_value()")
func current_health_value() -> float:
	return current_health

## @ace_expression
## @ace_name("Max Health")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.max_health_value()")
func max_health_value() -> float:
	return max_health

## @ace_expression
## @ace_name("Health Percent")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.health_percent()")
func health_percent() -> float:
	return (current_health / max_health) * 100.0 if max_health != 0.0 else 0.0

## @ace_expression
## @ace_name("Health Absorption Rate")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.health_absorption_rate_value()")
func health_absorption_rate_value() -> float:
	return health_absorption_rate

## @ace_expression
## @ace_name("Last Damage")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.last_damage_value()")
func last_damage_value() -> float:
	return last_damage

## @ace_expression
## @ace_name("Last Heal")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.last_heal_value()")
func last_heal_value() -> float:
	return last_heal

## @ace_expression
## @ace_name("Health Pool")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.health_pool_value({type})")
func health_pool_value(type: String) -> float:
	return (health_pools[type] as HealthPool).amount if health_pools.has(type) else 0.0

## @ace_expression
## @ace_name("Health Pool Decay Rate")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.health_pool_decay_rate_value({type})")
func health_pool_decay_rate_value(type: String) -> float:
	return (health_pools[type] as HealthPool).decay_rate if health_pools.has(type) else 0.0

## @ace_expression
## @ace_name("Health Pool Absorption Rate")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.health_pool_absorption_rate_value({type})")
func health_pool_absorption_rate_value(type: String) -> float:
	return (health_pools[type] as HealthPool).absorption_rate if health_pools.has(type) else 1.0

## @ace_expression
## @ace_name("Health Pool Priority")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.health_pool_priority_value({type})")
func health_pool_priority_value(type: String) -> float:
	return (health_pools[type] as HealthPool).priority if health_pools.has(type) else 0.0

## @ace_expression
## @ace_name("Last Pool Damage Absorbed")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.last_pool_damage_absorbed_value()")
func last_pool_damage_absorbed_value() -> float:
	return last_pool_damage_absorbed

## @ace_expression
## @ace_name("Last Health Pool Type")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.last_health_pool_type_value()")
func last_health_pool_type_value() -> String:
	return last_trigger_pool_type

func _sorted_pool_keys() -> Array:
	var keys: Array = health_pools.keys()
	var indexed: Array = []
	for i: int in keys.size():
		indexed.append([keys[i], (health_pools[keys[i]] as HealthPool).priority, i])
	indexed.sort_custom(func(a, b): return a[1] < b[1] if a[1] != b[1] else a[2] < b[2])
	var out: Array = []
	for entry: Array in indexed:
		out.append(entry[0])
	return out

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only -
	# HealthPool objects flatten to plain dicts on save and rebuild on load.
	var pools: Dictionary = {}
	for pool_name: String in health_pools.keys():
		var pool: HealthPool = health_pools[pool_name]
		pools[pool_name] = {"amount": pool.amount, "decay_rate": pool.decay_rate, "absorption_rate": pool.absorption_rate, "priority": pool.priority}
	return {
		"current_health": current_health,
		"max_health": max_health,
		"pools": pools,
		"dead": is_dead_flag,
		"invulnerable": invulnerable
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	max_health = float(state.get("max_health", 100.0))
	current_health = float(state.get("current_health", 100.0))
	is_dead_flag = bool(state.get("dead", false))
	invulnerable = bool(state.get("invulnerable", false))
	health_pools.clear()
	var pools: Dictionary = (state.get("pools", {}) as Dictionary)
	for pool_name: String in pools.keys():
		var data: Dictionary = pools[pool_name]
		var pool: HealthPool = HealthPool.new()
		pool.amount = float(data.get("amount", 0.0))
		pool.decay_rate = float(data.get("decay_rate", 0.0))
		pool.absorption_rate = float(data.get("absorption_rate", 1.0))
		pool.priority = float(data.get("priority", 0.0))
		health_pools[pool_name] = pool

# Simple Health behavior (event-sheet parity): damage/heal/death with a damage-absorption (resistance) multiplier, plus named health pools (shields/armour) that intercept damage in ascending-priority order, decay over time, and fire their own triggers. current_health seeds to max_health On Ready.
