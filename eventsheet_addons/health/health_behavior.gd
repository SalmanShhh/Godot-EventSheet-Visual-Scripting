## @ace_category("Health")
## @ace_expose_all(node)
## @ace_version(1.0.0)
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

## Starting max HP; current_health initialises to this.
@export_range(1, 10000, 1) var max_health: float = 100.0
## Start invulnerable: takeDamage is a no-op while true.
@export var invulnerable: bool = false
## queue_free the host the moment health reaches 0 (after On Death fires).
@export var destroy_on_death: bool = false
var current_health: float = 100.0
var is_dead_flag: bool = false
var last_damage: float = 0.0
var last_heal: float = 0.0
var health_absorption_rate: float = 1.0
var health_pools: Dictionary = {}
var last_trigger_pool_type: String = ""
var last_pool_damage_absorbed: float = 0.0
var _invincible_until: int = 0
## How long a hit still counts as an assist. Anyone who damaged this node within this many seconds of its death is listed by Assists Of.
@export_range(0, 120, 0.5) var assist_seconds: float = 8.0
var last_hit_from: Node = null
var assist_hits: Dictionary = {}
## Flat damage taken off every typed hit, after the type resistance and before a critical. A hit that got past resistance never lands for less than Minimum Damage, so armour blunts hits rather than ending them.
@export_range(0, 1000, 0.5) var armour: float = 0.0
## The least a hit that got past resistance can land for, however much armour there is. Without it, enough armour quietly makes a node unkillable by anything small.
@export_range(0, 100, 0.5) var minimum_damage: float = 1.0
## How often a typed hit on this node lands as a critical: 0 never, 1 every time.
@export_range(0, 1, 0.01) var crit_chance: float = 0.0
## What a critical multiplies the damage by, after armour has come off.
@export_range(1, 20, 0.1) var crit_multiplier: float = 2.0
var resistances: Dictionary = {}
var last_damage_type: String = ""
var last_damage_dealt: float = 0.0
var last_damage_before_mitigation: float = 0.0
var last_hit_was_crit: bool = false

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
# WHO IS RESPONSIBLE, walked to the far end of the ownership chain. A hit arrives from the
# bullet, the bullet belongs to the turret and the turret to the player, so the credit belongs
# to the player: each step reads the node metadata key `owner` that Claim writes, and stops at
# the first node that carries none. The walk is bounded because a chain that somehow points at
# itself must still answer rather than hang - eight is far past any real chain.
func _root_owner(node: Node) -> Node:
	var walker: Node = node
	for _step: int in 8:
		if not is_instance_valid(walker) or not walker.has_meta(&"owner"):
			break
		walker = walker.get_meta(&"owner") as Node
	return walker

func _ready() -> void:
	current_health = max_health
	# A node with no shield or armour has nothing to count down, so it pays for no frame.
	# Any action that gives it a decaying pool turns the tick back on.
	set_process(false)

func _process(delta: float) -> void:
	if health_pools.is_empty():
		set_process(false)
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
	# Asked LAST, so a pool granted by an On Health Pool Depleted handler this very frame
	# keeps the tick alive: once nothing is decaying, the countdown switches itself off.
	set_process(_any_pool_decaying())

## @ace_action
## @ace_featured
## @ace_name("Take Damage")
## @ace_category("Health")
## @ace_description("Applies damage; health pools absorb in ascending-priority order before real HP. Ignored entirely while invincible (no HP lost, no On Damaged).")
## @ace_display_template("Take [b]{amount}[/b] damage")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.take_damage({amount})")
func take_damage(amount: float) -> void:
	if amount <= 0.0 or invulnerable or is_dead_flag or is_invincible():
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
## @ace_display_template("Heal [b]{amount}[/b] HP")
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
## @ace_display_template("Set health to [b]{amount}[/b]")
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
## @ace_display_template("Set max health to [b]{amount}[/b]")
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
## @ace_display_template("Set invulnerable to [b]{state}[/b]")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_invulnerable({state})")
func set_invulnerable(state: bool) -> void:
	invulnerable = state

## @ace_action
## @ace_name("Grant Invincibility")
## @ace_category("Health")
## @ace_description("Opens an invincibility window for the given seconds: Take Damage is ignored (no HP lost, no On Damaged) until it closes. Pair it with the Flash pack for the classic i-frame flicker.")
## @ace_display_template("Grant [b]{seconds}[/b] s of invincibility")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.grant_invincibility({seconds})")
func grant_invincibility(seconds: float) -> void:
	_invincible_until = Time.get_ticks_msec() + int(maxf(seconds, 0.0) * 1000.0)

## @ace_condition
## @ace_name("Is Invincible")
## @ace_category("Health")
## @ace_description("True while an invincibility window granted by Grant Invincibility is still open.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.is_invincible()")
func is_invincible() -> bool:
	return Time.get_ticks_msec() < _invincible_until

## @ace_action
## @ace_name("Set Health Absorption Rate")
## @ace_category("Health")
## @ace_description("Damage multiplier for real HP (resistance); 0 = invulnerable.")
## @ace_display_template("Set health absorption rate to [b]{rate}[/b]")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_health_absorption_rate({rate})")
func set_health_absorption_rate(rate: float) -> void:
	health_absorption_rate = maxf(0.0, rate)
	invulnerable = (rate == 0.0)

## @ace_action
## @ace_name("Add Health Pool")
## @ace_category("Health")
## @ace_description("Adds to a named health pool (shield/armour).")
## @ace_display_template("Add [b]{amount}[/b] to the [b]{type}[/b] pool")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.add_health_pool({type}, {amount})")
func add_health_pool(type: String, amount: float) -> void:
	if amount <= 0.0:
		return
	var pool: HealthPool = _get_pool(type)
	pool.amount = pool.amount + amount
	# A pool that might decay needs the frame back; the tick stops itself once none does.
	set_process(true)
	last_trigger_pool_type = type
	on_health_pool_added.emit()

## @ace_action
## @ace_name("Set Health Pool")
## @ace_category("Health")
## @ace_description("Sets a health pool amount (fires Added only when it increases).")
## @ace_display_template("Set the [b]{type}[/b] pool to [b]{amount}[/b]")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_health_pool({type}, {amount})")
func set_health_pool(type: String, amount: float) -> void:
	var pool: HealthPool = _get_pool(type)
	var new_amount: float = maxf(0.0, amount)
	# A pool that might decay needs the frame back; the tick stops itself once none does.
	set_process(true)
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
## @ace_display_template("Clear the [b]{type}[/b] pool")
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
## @ace_display_template("Set [b]{type}[/b] pool decay rate to [b]{rate}[/b]")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_health_pool_decay_rate({type}, {rate})")
func set_health_pool_decay_rate(type: String, rate: float) -> void:
	_get_pool(type).decay_rate = maxf(0.0, rate)
	# A pool that might decay needs the frame back; the tick stops itself once none does.
	set_process(true)

## @ace_action
## @ace_name("Set Health Pool Absorption Rate")
## @ace_category("Health")
## @ace_description("Sets a pool's absorption multiplier (how hard it spends to soak damage).")
## @ace_display_template("Set [b]{type}[/b] pool absorption rate to [b]{rate}[/b]")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_health_pool_absorption_rate({type}, {rate})")
func set_health_pool_absorption_rate(type: String, rate: float) -> void:
	_get_pool(type).absorption_rate = maxf(0.0, rate)

## @ace_action
## @ace_name("Set Health Pool Rates")
## @ace_category("Health")
## @ace_description("Sets a pool's decay and absorption rates at once.")
## @ace_display_template("Set [b]{type}[/b] pool rates to decay [b]{decay_rate}[/b], absorption [b]{absorption_rate}[/b]")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_health_pool_rates({type}, {decay_rate}, {absorption_rate})")
func set_health_pool_rates(type: String, decay_rate: float, absorption_rate: float) -> void:
	var pool: HealthPool = _get_pool(type)
	pool.decay_rate = maxf(0.0, decay_rate)
	pool.absorption_rate = maxf(0.0, absorption_rate)
	# A pool that might decay needs the frame back; the tick stops itself once none does.
	set_process(true)

## @ace_action
## @ace_name("Set Health Pool Priority")
## @ace_category("Health")
## @ace_description("Sets a pool's absorption priority (lower absorbs first).")
## @ace_display_template("Set [b]{type}[/b] pool priority to [b]{priority}[/b]")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_health_pool_priority({type}, {priority})")
func set_health_pool_priority(type: String, priority: float) -> void:
	_get_pool(type).priority = priority

## @ace_action
## @ace_name("Setup Health Pool")
## @ace_category("Health")
## @ace_description("Creates/configures a health pool in one call.")
## @ace_display_template("Setup [b]{type}[/b] pool: [b]{amount}[/b] HP, decay [b]{decay_rate}[/b], absorption [b]{absorption_rate}[/b], priority [b]{priority}[/b]")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.setup_health_pool({type}, {amount}, {decay_rate}, {absorption_rate}, {priority})")
func setup_health_pool(type: String, amount: float, decay_rate: float, absorption_rate: float, priority: float) -> void:
	var pool: HealthPool = _get_pool(type)
	pool.amount = maxf(0.0, amount)
	pool.decay_rate = maxf(0.0, decay_rate)
	pool.absorption_rate = maxf(0.0, absorption_rate)
	pool.priority = priority
	# A pool that might decay needs the frame back; the tick stops itself once none does.
	set_process(true)

## @ace_action
## @ace_name("Revive")
## @ace_category("Health")
## @ace_description("Clears death and restores health (amount<=0 → full).")
## @ace_display_template("Revive with [b]{amount}[/b] HP")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.revive({amount})")
func revive(amount: float) -> void:
	is_dead_flag = false
	current_health = minf(amount, max_health) if amount > 0.0 else max_health
	on_revived.emit()
	on_health_changed.emit()

## @ace_action
## @ace_name("Take Damage From")
## @ace_category("Health")
## @ace_description("Damage that remembers who dealt it. Records the source first - walked up the ownership chain, so a bullet credits whoever fired it rather than the bullet - and then applies exactly the damage Take Damage would. Killer Of, Assists Of and Killed By Me read what this writes.")
## @ace_display_template("Take [b]{amount}[/b] damage from [i]{from}[/i]")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.take_damage_from({amount}, {from})")
func take_damage_from(amount: float, from: Node) -> void:
	_credit_hit(from)
	take_damage(amount)

## @ace_expression
## @ace_name("Last Hit From")
## @ace_category("Health")
## @ace_description("Who last damaged this node, as the person rather than the projectile - the boss's next target, the health bar's attacker name, the direction a hit came from. Reads as nothing until something has damaged it through Take Damage From.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.last_hit_from_value()")
func last_hit_from_value() -> Node:
	return last_hit_from

## @ace_expression
## @ace_name("Killer Of")
## @ace_category("Health")
## @ace_description("Who killed this node, or nothing while it is still alive. It is already written when On Death fires, so a row under that trigger can score the kill, name the killer on the death screen, or hand the bounty over without an extra step.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.killer_of()")
func killer_of() -> Node:
	return last_hit_from if is_dead_flag else null

## @ace_expression
## @ace_name("Assists Of")
## @ace_category("Health")
## @ace_description("Everyone else who damaged this node recently, as a list, with the killer left out and each helper listed once however many times they hit. Recently means the Assist Seconds property in the Inspector. The assist column of a results screen, in one row.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.assists_of()")
func assists_of() -> Array:
	var cutoff: int = Time.get_ticks_msec() - int(maxf(assist_seconds, 0.0) * 1000.0)
	var helpers: Array = []
	for who: Variant in assist_hits.keys():
		if who == last_hit_from or not is_instance_valid(who):
			continue
		if int(assist_hits[who]) >= cutoff:
			helpers.append(who)
	return helpers

## @ace_condition
## @ace_name("Killed By Me")
## @ace_category("Health")
## @ace_description("True when this node is dead and the kill traces back to the node asking - the your-kill pop, the personal score, the achievement that only counts your own. The asker is walked up the ownership chain too, so a kill by your turret still counts as yours.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.killed_by_me({who})")
func killed_by_me(who: Node) -> bool:
	return is_dead_flag and last_hit_from != null and last_hit_from == _root_owner(who)

## @ace_action
## @ace_name("Take Damage Of Type")
## @ace_category("Health")
## @ace_description("Damage that knows what kind it is and who dealt it. Resistance comes off as a percentage, then armour as flat points (never below Minimum Damage), then a critical multiplies what got through, and the pools and health of Take Damage finish the job. The report - Last Damage Type, Last Damage Dealt, Last Damage Before Mitigation, Last Hit Was A Crit - is written before On Damaged fires, so a row under that trigger reads it with no expression.")
## @ace_display_template("Take [b]{amount}[/b] damage of [b]{type}[/b] from [i]{from}[/i]")
## @ace_param_hint(type damage_type)
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.take_typed_damage({amount}, {type}, {from})")
func take_typed_damage(amount: float, type: String, from: Node) -> void:
	if amount <= 0.0 or invulnerable or is_dead_flag or is_invincible():
		return
	_credit_hit(from)
	last_damage_type = type
	last_damage_before_mitigation = amount
	var after_resist: float = amount * maxf(0.0, 1.0 - float(resistances.get(type, 0.0)))
	var landed: float = after_resist - armour
	# Armour blunts a hit; it never makes one free. Anything that got past resistance lands for
	# at least the minimum, so stacking armour cannot quietly turn a node immortal - while a hit
	# resistance ate entirely stays eaten, which is what immunity has to mean.
	landed = maxf(landed, minimum_damage) if after_resist > 0.0 else 0.0
	last_hit_was_crit = landed > 0.0 and crit_chance > 0.0 and randf() < crit_chance
	if last_hit_was_crit:
		landed *= crit_multiplier
	last_damage_dealt = landed
	# Handed to the row this pack already had, so the pools, the death latch, destroy-on-death and
	# On Damaged all happen in exactly one place and behave exactly as they always did.
	take_damage(landed)

## @ace_action
## @ace_name("Resist")
## @ace_category("Health")
## @ace_description("Takes a percentage off every hit of one kind - 50 for half damage, 100 for none at all. Set it once on the enemy and every fireball in the game already respects it. A negative percentage is a weakness, which is what Weak To says more plainly.")
## @ace_display_template("Resist [b]{type}[/b] by [b]{percent}[/b] percent")
## @ace_param_hint(type damage_type)
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.resist({type}, {percent})")
func resist(type: String, percent: float) -> void:
	resistances[type] = minf(percent, 100.0) / 100.0

## @ace_action
## @ace_name("Immune To")
## @ace_category("Health")
## @ace_description("Makes one kind of damage do nothing at all - no health lost, no pool spent and no On Damaged. The same as resisting it by 100, said the way a designer says it.")
## @ace_display_template("Immune to [b]{type}[/b]")
## @ace_param_hint(type damage_type)
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.immune_to({type})")
func immune_to(type: String) -> void:
	resistances[type] = 1.0

## @ace_action
## @ace_name("Weak To")
## @ace_category("Health")
## @ace_description("Takes extra damage from one kind - 50 for half again, 100 for double. The ice enemy the fire spell was made for, in one row on the enemy rather than a branch on every spell.")
## @ace_display_template("Weak to [b]{type}[/b] by [b]{percent}[/b] percent")
## @ace_param_hint(type damage_type)
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.weak_to({type}, {percent})")
func weak_to(type: String, percent: float) -> void:
	resistances[type] = -maxf(percent, 0.0) / 100.0

## @ace_action
## @ace_name("Set Armour")
## @ace_category("Health")
## @ace_description("Sets the flat points taken off every typed hit after resistance. A hit that got past resistance still lands for at least Minimum Damage, so armour is a blunting rather than a wall.")
## @ace_display_template("Set armour to [b]{amount}[/b]")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_armour({amount})")
func set_armour(amount: float) -> void:
	armour = maxf(0.0, amount)

## @ace_action
## @ace_name("Set Crit")
## @ace_category("Health")
## @ace_description("Sets how often a typed hit on this node lands as a critical and what it multiplies by. Chance runs 0 to 1; a multiplier below 1 is raised to 1, because a critical that hurt less would read as a bug in every game ever made.")
## @ace_display_template("Set crit [b]{chance}[/b] at [b]{multiplier}[/b] times damage")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.set_crit({chance}, {multiplier})")
func set_crit(chance: float, multiplier: float) -> void:
	crit_chance = clampf(chance, 0.0, 1.0)
	crit_multiplier = maxf(1.0, multiplier)

## @ace_expression
## @ace_name("Last Damage Type")
## @ace_category("Health")
## @ace_description("What kind the last hit was - the word the row dealt it with. Empty until something has damaged this node through Take Damage Of Type.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.last_damage_type_value()")
func last_damage_type_value() -> String:
	return last_damage_type

## @ace_expression
## @ace_name("Last Damage Dealt")
## @ace_category("Health")
## @ace_description("What the last typed hit came to after resistance, armour and the critical - the number a floating damage label should show.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.last_damage_dealt_value()")
func last_damage_dealt_value() -> float:
	return last_damage_dealt

## @ace_expression
## @ace_name("Last Damage Before Mitigation")
## @ace_category("Health")
## @ace_description("What the last typed hit was worth before this node resistance, armour and critical touched it. Paired with Last Damage Dealt it is how a sheet shows an absorbed or a resisted label without doing the arithmetic twice.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.last_damage_before_mitigation_value()")
func last_damage_before_mitigation_value() -> float:
	return last_damage_before_mitigation

## @ace_condition
## @ace_name("Last Hit Was A Crit")
## @ace_category("Health")
## @ace_description("Whether the last typed hit rolled a critical. Under On Damaged this is the row that makes the number bigger, the shake harder and the sound sharper.")
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.last_hit_was_a_crit()")
func last_hit_was_a_crit() -> bool:
	return last_hit_was_crit

## @ace_condition
## @ace_name("Damage Type Is")
## @ace_category("Health")
## @ace_description("Whether the last hit was of one particular kind - burning after fire, freezing after ice, nothing after physical. Under On Damaged it is how one trigger branches into as many reactions as the game has kinds.")
## @ace_param_hint(type damage_type)
## @ace_icon("res://eventsheet_addons/health/icon.svg")
## @ace_codegen_template("$SimpleHealthBehavior.damage_type_is({type})")
func damage_type_is(type: String) -> bool:
	return last_damage_type == type

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

func _any_pool_decaying() -> bool:
	# Whether any pool still has something to decay. Health itself never changes on its own -
	# damage, healing and invincibility are all answered the moment they are asked - so a
	# decaying shield is the only reason this behavior needs a frame at all.
	for pool_name: String in health_pools.keys():
		var pool: HealthPool = health_pools[pool_name]
		if pool.amount > 0.0 and pool.decay_rate > 0.0:
			return true
	return false

func _credit_hit(from: Node) -> void:
	# Records who is responsible for a hit, BEFORE the hit is applied - which is what lets a row
	# under On Death read Killer Of, because the credit is already written when the signal fires.
	# A hit on something already dead credits nobody, so the killer is not overwritten by whatever
	# lands on the corpse afterwards.
	if is_dead_flag:
		return
	var source: Node = _root_owner(from)
	if source == null:
		return
	last_hit_from = source
	assist_hits[source] = Time.get_ticks_msec()

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
	# Restored pools may be mid-decay, so the tick comes back on; it stops itself again
	# on the first frame nothing is decaying.
	set_process(true)

# Simple Health behavior (event-sheet parity): damage/heal/death with a damage-absorption (resistance) multiplier, plus named health pools (shields/armour) that intercept damage in ascending-priority order, decay over time, and fire their own triggers. Grant Invincibility opens a timed i-frame window - damage is ignored while invincible, and On Damaged does not fire. current_health seeds to max_health On Ready.
