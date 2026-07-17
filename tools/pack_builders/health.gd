# Pack builder - health (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Simple Health behavior (event-sheet parity - ported from the Simple Health addon).
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "SimpleHealthBehavior"
	sheet.class_description = "Gives any Node2D a real health model: current health seeded from a max, damage and healing, a death latch, a resistance multiplier, and named shield/armour pools that intercept damage in priority order. Triggers fire on damage, death, and pool breaks so your sheet reacts without writing GDScript."
	sheet.addon_category = "Health"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"max_health": {"type": "float", "default": 100.0, "exported": true, "attributes": {"tooltip": "Starting max HP; current_health initialises to this.", "range": {"min": "1", "max": "10000", "step": "1"}}},
		"invulnerable": {"type": "bool", "default": false, "exported": true, "attributes": {"tooltip": "Start invulnerable: takeDamage is a no-op while true."}},
		"destroy_on_death": {"type": "bool", "default": false, "exported": true, "attributes": {"tooltip": "queue_free the host the moment health reaches 0 (after On Death fires)."}},
		"current_health": {"type": "float", "default": 100.0, "exported": false},
		"is_dead_flag": {"type": "bool", "default": false, "exported": false},
		"last_damage": {"type": "float", "default": 0.0, "exported": false},
		"last_heal": {"type": "float", "default": 0.0, "exported": false},
		"health_absorption_rate": {"type": "float", "default": 1.0, "exported": false},
		"health_pools": {"type": "Dictionary", "default": {}, "exported": false},
		"last_trigger_pool_type": {"type": "String", "default": "", "exported": false},
		"last_pool_damage_absorbed": {"type": "float", "default": 0.0, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Simple Health behavior (event-sheet parity): damage/heal/death with a damage-absorption (resistance) multiplier, plus named health pools (shields/armour) that intercept damage in ascending-priority order, decay over time, and fire their own triggers. current_health seeds to max_health On Ready."
	sheet.events.append(about)

	# Triggers (signals) + conditions + expressions + non-exposed helpers, all as
	# ## @ace_*-annotated class-level GDScript (mirrors line_of_sight.gd / sine_3d.gd).
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## A named health pool (shield / armour) - typed so the absorption + decay hot paths read",
		"## fields directly instead of float()-casting an untyped Dictionary entry every frame.",
		"class HealthPool:",
		"\tvar amount: float = 0.0",
		"\tvar decay_rate: float = 0.0",
		"\tvar absorption_rate: float = 1.0",
		"\tvar last_absorbed: float = 0.0",
		"\tvar priority: float = 0.0",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Damaged\")",
		"signal on_damaged",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Death\")",
		"signal on_death",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Healed\")",
		"signal on_healed",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Health Changed\")",
		"signal on_health_changed",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Revived\")",
		"signal on_revived",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Health Pool Added\")",
		"signal on_health_pool_added",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Health Pool Absorbed\")",
		"signal on_health_pool_absorbed",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Health Pool Depleted\")",
		"signal on_health_pool_depleted",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Dead\")",
		"func is_dead() -> bool:",
		"\treturn is_dead_flag",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Invulnerable\")",
		"func is_invulnerable() -> bool:",
		"\treturn invulnerable",
		"",
		"## @ace_condition",
		"## @ace_name(\"Has Any Health Pool\")",
		"func has_any_health_pool() -> bool:",
		"\tfor pool_name: String in health_pools.keys():",
		"\t\tif (health_pools[pool_name] as HealthPool).amount > 0.0:",
		"\t\t\treturn true",
		"\treturn false",
		"",
		"## @ace_condition",
		"## @ace_name(\"Has Health Pool\")",
		"func has_health_pool(type: String) -> bool:",
		"\treturn health_pools.has(type) and (health_pools[type] as HealthPool).amount > 0.0",
		"",
		"## @ace_condition",
		"## @ace_name(\"Health Pool Is Type\")",
		"func is_health_pool_type(type: String) -> bool:",
		"\treturn last_trigger_pool_type == type",
		"",
		"## @ace_expression",
		"## @ace_name(\"Current Health\")",
		"func current_health_value() -> float:",
		"\treturn current_health",
		"",
		"## @ace_expression",
		"## @ace_name(\"Max Health\")",
		"func max_health_value() -> float:",
		"\treturn max_health",
		"",
		"## @ace_expression",
		"## @ace_name(\"Health Percent\")",
		"func health_percent() -> float:",
		"\treturn (current_health / max_health) * 100.0 if max_health != 0.0 else 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Health Absorption Rate\")",
		"func health_absorption_rate_value() -> float:",
		"\treturn health_absorption_rate",
		"",
		"## @ace_expression",
		"## @ace_name(\"Last Damage\")",
		"func last_damage_value() -> float:",
		"\treturn last_damage",
		"",
		"## @ace_expression",
		"## @ace_name(\"Last Heal\")",
		"func last_heal_value() -> float:",
		"\treturn last_heal",
		"",
		"## @ace_expression",
		"## @ace_name(\"Health Pool\")",
		"func health_pool_value(type: String) -> float:",
		"\treturn (health_pools[type] as HealthPool).amount if health_pools.has(type) else 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Health Pool Decay Rate\")",
		"func health_pool_decay_rate_value(type: String) -> float:",
		"\treturn (health_pools[type] as HealthPool).decay_rate if health_pools.has(type) else 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Health Pool Absorption Rate\")",
		"func health_pool_absorption_rate_value(type: String) -> float:",
		"\treturn (health_pools[type] as HealthPool).absorption_rate if health_pools.has(type) else 1.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Health Pool Priority\")",
		"func health_pool_priority_value(type: String) -> float:",
		"\treturn (health_pools[type] as HealthPool).priority if health_pools.has(type) else 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Last Pool Damage Absorbed\")",
		"func last_pool_damage_absorbed_value() -> float:",
		"\treturn last_pool_damage_absorbed",
		"",
		"## @ace_expression",
		"## @ace_name(\"Last Health Pool Type\")",
		"func last_health_pool_type_value() -> String:",
		"\treturn last_trigger_pool_type",
		"",
		"func _get_pool(type: String) -> HealthPool:",
		"\tif not health_pools.has(type):",
		"\t\thealth_pools[type] = HealthPool.new()",
		"\treturn health_pools[type]",
		"",
		"func _sorted_pool_keys() -> Array:",
		"\tvar keys: Array = health_pools.keys()",
		"\tvar indexed: Array = []",
		"\tfor i: int in keys.size():",
		"\t\tindexed.append([keys[i], (health_pools[keys[i]] as HealthPool).priority, i])",
		"\tindexed.sort_custom(func(a, b): return a[1] < b[1] if a[1] != b[1] else a[2] < b[2])",
		"\tvar out: Array = []",
		"\tfor entry: Array in indexed:",
		"\t\tout.append(entry[0])",
		"\treturn out"
	]))
	sheet.events.append(block)

	# Seed current_health to max_health once at runtime (the generated literal default
	# can't reference max_health). OnReady runs once.
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var on_ready_body: RawCodeRow = RawCodeRow.new()
	on_ready_body.code = "\n".join(PackedStringArray([
		"current_health = max_health"
	]))
	on_ready.actions.append(on_ready_body)
	sheet.events.append(on_ready)

	# Per-frame health-pool decay.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if health_pools.is_empty():",
		"\treturn",
		"var depleted: Array = []",
		"for pool_name in _sorted_pool_keys():",
		"\tvar pool: HealthPool = health_pools[pool_name]",
		"\tif pool.amount > 0.0 and pool.decay_rate > 0.0:",
		"\t\tpool.amount = maxf(0.0, pool.amount - pool.decay_rate * delta)",
		"\t\tif pool.amount <= 0.0:",
		"\t\t\tdepleted.append(pool_name)",
		"for pool_name in depleted:",
		"\tlast_trigger_pool_type = pool_name",
		"\ton_health_pool_depleted.emit()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# Actions (EventFunction with expose_as_ace=true → auto-generated codegen templates).
	Lib.append_function(sheet, "take_damage", "Take Damage", "Health",
		"Applies damage; health pools absorb in ascending-priority order before real HP.",
		[["amount", "float"]], "\n".join(PackedStringArray([
		"if amount <= 0.0 or invulnerable or is_dead_flag:",
		"\treturn",
		"var remaining: float = amount",
		"for pool_name: String in _sorted_pool_keys():",
		"\tif remaining <= 0.0:",
		"\t\tbreak",
		"\tvar pool: HealthPool = health_pools[pool_name]",
		"\tif pool.amount <= 0.0:",
		"\t\tcontinue",
		"\tvar absorption: float = pool.absorption_rate",
		"\tvar max_absorbable: float = (pool.amount / absorption) if absorption > 0.0 else INF",
		"\tvar absorbed: float = minf(remaining, max_absorbable)",
		"\tpool.amount = maxf(0.0, pool.amount - absorbed * absorption)",
		"\tpool.last_absorbed = absorbed",
		"\tremaining -= absorbed",
		"\tlast_trigger_pool_type = pool_name",
		"\tlast_pool_damage_absorbed = absorbed",
		"\ton_health_pool_absorbed.emit()",
		"\tif pool.amount <= 0.0:",
		"\t\ton_health_pool_depleted.emit()",
		"if remaining <= 0.0:",
		"\treturn",
		"var real_damage: float = remaining * health_absorption_rate",
		"last_damage = real_damage",
		"current_health -= real_damage",
		"if current_health <= 0.0:",
		"\tcurrent_health = 0.0",
		"\tis_dead_flag = true",
		"\ton_death.emit()",
		"\ton_health_changed.emit()",
		"\tif destroy_on_death and host != null:",
		"\t\thost.call_deferred(\"queue_free\")",
		"else:",
		"\ton_damaged.emit()",
		"\ton_health_changed.emit()"
	])))

	Lib.append_function(sheet, "heal", "Heal", "Health",
		"Restores health up to max_health.",
		[["amount", "float"]], "\n".join(PackedStringArray([
		"if is_dead_flag:",
		"\treturn",
		"last_heal = amount",
		"current_health = minf(current_health + amount, max_health)",
		"on_healed.emit()",
		"on_health_changed.emit()"
	])))

	Lib.append_function(sheet, "set_health_value", "Set Health", "Health",
		"Sets current health directly, firing damage/heal/death as appropriate.",
		[["amount", "float"]], "\n".join(PackedStringArray([
		"if is_dead_flag:",
		"\treturn",
		"var new_value: float = maxf(0.0, minf(amount, max_health))",
		"var old_value: float = current_health",
		"if new_value == old_value:",
		"\treturn",
		"current_health = new_value",
		"if new_value <= 0.0:",
		"\tis_dead_flag = true",
		"\tlast_damage = old_value - new_value",
		"\ton_death.emit()",
		"\ton_health_changed.emit()",
		"\tif destroy_on_death and host != null:",
		"\t\thost.call_deferred(\"queue_free\")",
		"elif new_value < old_value:",
		"\tlast_damage = old_value - new_value",
		"\ton_damaged.emit()",
		"\ton_health_changed.emit()",
		"else:",
		"\tlast_heal = new_value - old_value",
		"\ton_healed.emit()",
		"\ton_health_changed.emit()"
	])))

	Lib.append_function(sheet, "set_max_health_value", "Set Max Health", "Health",
		"Sets max health (clamps current down if needed).",
		[["amount", "float"]], "\n".join(PackedStringArray([
		"max_health = maxf(1.0, amount)",
		"if current_health > max_health:",
		"\tcurrent_health = max_health",
		"\ton_health_changed.emit()"
	])))

	Lib.append_function(sheet, "set_invulnerable", "Set Invulnerable", "Health",
		"Toggles invulnerability (takeDamage no-op while true).",
		[["state", "bool"]], "\n".join(PackedStringArray([
		"invulnerable = state"
	])))

	Lib.append_function(sheet, "set_health_absorption_rate", "Set Health Absorption Rate", "Health",
		"Damage multiplier for real HP (resistance); 0 = invulnerable.",
		[["rate", "float"]], "\n".join(PackedStringArray([
		"health_absorption_rate = maxf(0.0, rate)",
		"invulnerable = (rate == 0.0)"
	])))

	Lib.append_function(sheet, "add_health_pool", "Add Health Pool", "Health",
		"Adds to a named health pool (shield/armour).",
		[["type", "String"], ["amount", "float"]], "\n".join(PackedStringArray([
		"if amount <= 0.0:",
		"\treturn",
		"var pool: HealthPool = _get_pool(type)",
		"pool.amount = pool.amount + amount",
		"last_trigger_pool_type = type",
		"on_health_pool_added.emit()"
	])))

	Lib.append_function(sheet, "set_health_pool", "Set Health Pool", "Health",
		"Sets a health pool amount (fires Added only when it increases).",
		[["type", "String"], ["amount", "float"]], "\n".join(PackedStringArray([
		"var pool: HealthPool = _get_pool(type)",
		"var new_amount: float = maxf(0.0, amount)",
		"if new_amount > pool.amount:",
		"\tpool.amount = new_amount",
		"\tlast_trigger_pool_type = type",
		"\ton_health_pool_added.emit()",
		"else:",
		"\tpool.amount = new_amount"
	])))

	Lib.append_function(sheet, "clear_health_pool", "Clear Health Pool", "Health",
		"Zeroes one named health pool.",
		[["type", "String"]], "\n".join(PackedStringArray([
		"if health_pools.has(type):",
		"\t(health_pools[type] as HealthPool).amount = 0.0"
	])))

	Lib.append_function(sheet, "clear_all_health_pools", "Clear All Health Pools", "Health",
		"Zeroes every health pool.",
		[], "\n".join(PackedStringArray([
		"for pool_name: String in health_pools.keys():",
		"\t(health_pools[pool_name] as HealthPool).amount = 0.0"
	])))

	Lib.append_function(sheet, "set_health_pool_decay_rate", "Set Health Pool Decay Rate", "Health",
		"Sets a pool's per-second decay rate.",
		[["type", "String"], ["rate", "float"]], "\n".join(PackedStringArray([
		"_get_pool(type).decay_rate = maxf(0.0, rate)"
	])))

	Lib.append_function(sheet, "set_health_pool_absorption_rate", "Set Health Pool Absorption Rate", "Health",
		"Sets a pool's absorption multiplier (how hard it spends to soak damage).",
		[["type", "String"], ["rate", "float"]], "\n".join(PackedStringArray([
		"_get_pool(type).absorption_rate = maxf(0.0, rate)"
	])))

	Lib.append_function(sheet, "set_health_pool_rates", "Set Health Pool Rates", "Health",
		"Sets a pool's decay and absorption rates at once.",
		[["type", "String"], ["decay_rate", "float"], ["absorption_rate", "float"]], "\n".join(PackedStringArray([
		"var pool: HealthPool = _get_pool(type)",
		"pool.decay_rate = maxf(0.0, decay_rate)",
		"pool.absorption_rate = maxf(0.0, absorption_rate)"
	])))

	Lib.append_function(sheet, "set_health_pool_priority", "Set Health Pool Priority", "Health",
		"Sets a pool's absorption priority (lower absorbs first).",
		[["type", "String"], ["priority", "float"]], "\n".join(PackedStringArray([
		"_get_pool(type).priority = priority"
	])))

	Lib.append_function(sheet, "setup_health_pool", "Setup Health Pool", "Health",
		"Creates/configures a health pool in one call.",
		[["type", "String"], ["amount", "float"], ["decay_rate", "float"], ["absorption_rate", "float"], ["priority", "float"]], "\n".join(PackedStringArray([
		"var pool: HealthPool = _get_pool(type)",
		"pool.amount = maxf(0.0, amount)",
		"pool.decay_rate = maxf(0.0, decay_rate)",
		"pool.absorption_rate = maxf(0.0, absorption_rate)",
		"pool.priority = priority"
	])))

	Lib.append_function(sheet, "revive", "Revive", "Health",
		"Clears death and restores health (amount<=0 → full).",
		[["amount", "float"]], "\n".join(PackedStringArray([
		"is_dead_flag = false",
		"current_health = minf(amount, max_health) if amount > 0.0 else max_health",
		"on_revived.emit()",
		"on_health_changed.emit()"
	])))

	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only -",
		"# HealthPool objects flatten to plain dicts on save and rebuild on load.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\tvar pools: Dictionary = {}",
		"\tfor pool_name: String in health_pools.keys():",
		"\t\tvar pool: HealthPool = health_pools[pool_name]",
		"\t\tpools[pool_name] = {\"amount\": pool.amount, \"decay_rate\": pool.decay_rate, \"absorption_rate\": pool.absorption_rate, \"priority\": pool.priority}",
		"\treturn {",
		"\t\t\"current_health\": current_health,",
		"\t\t\"max_health\": max_health,",
		"\t\t\"pools\": pools,",
		"\t\t\"dead\": is_dead_flag,",
		"\t\t\"invulnerable\": invulnerable",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\tmax_health = float(state.get(\"max_health\", 100.0))",
		"\tcurrent_health = float(state.get(\"current_health\", 100.0))",
		"\tis_dead_flag = bool(state.get(\"dead\", false))",
		"\tinvulnerable = bool(state.get(\"invulnerable\", false))",
		"\thealth_pools.clear()",
		"\tvar pools: Dictionary = (state.get(\"pools\", {}) as Dictionary)",
		"\tfor pool_name: String in pools.keys():",
		"\t\tvar data: Dictionary = pools[pool_name]",
		"\t\tvar pool: HealthPool = HealthPool.new()",
		"\t\tpool.amount = float(data.get(\"amount\", 0.0))",
		"\t\tpool.decay_rate = float(data.get(\"decay_rate\", 0.0))",
		"\t\tpool.absorption_rate = float(data.get(\"absorption_rate\", 1.0))",
		"\t\tpool.priority = float(data.get(\"priority\", 0.0))",
		"\t\thealth_pools[pool_name] = pool"
	]))
	sheet.events.append(persistence)

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.feature_verbs(sheet, ["take_damage", "heal"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/health/health_behavior")
