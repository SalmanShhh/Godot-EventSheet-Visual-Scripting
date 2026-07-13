# Pack builder - weapon_kit (one pack per file; run via tools/build_sample_behaviors.gd).
#
# Shooter state machine ported from the author's "WeaponKit" addon: ammo + reserve
# pools, fire-rate cooldown, single/auto/burst fire modes, and timed/instant reload with
# auto-reload. It owns NO projectile - Fire just manages ammo/cooldown and emits On Fire,
# so the sheet spawns the bullet/hitscan however it likes (parity-safe, engine-agnostic).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "WeaponKit"
	sheet.addon_tags = PackedStringArray(["combat", "shooter"])
	# The terse-provider showcase: one class-level category + the expose-all(node) opt-in
	# replace per-member @ace_category/@ace_codegen_template/type-marker annotations.
	# Members keep an @ace_name ONLY where the curated name differs from the humanized
	# identifier (pinned by weapon_kit_characterization_test).
	sheet.addon_category = "Weapon"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"max_ammo": {"type": "int", "default": 12, "exported": true,
			"attributes": {"tooltip": "Magazine size (rounds before a reload)."}},
		"current_ammo": {"type": "int", "default": 12, "exported": true,
			"attributes": {"tooltip": "Rounds loaded right now (set to your magazine size to start full)."}},
		"reserve_ammo": {"type": "int", "default": 96, "exported": true,
			"attributes": {"tooltip": "Spare rounds a reload draws from."}},
		"fire_rate": {"type": "float", "default": 8.0, "exported": true,
			"attributes": {"tooltip": "Shots per second (the cooldown between shots is 1 / fire_rate)."}},
		"reload_time": {"type": "float", "default": 1.2, "exported": true,
			"attributes": {"tooltip": "Seconds a reload takes."}},
		"fire_mode": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "0 = single, 1 = auto (both cooldown-gated), 2 = burst."}},
		"burst_count": {"type": "int", "default": 3, "exported": true,
			"attributes": {"tooltip": "Shots per burst when fire_mode = 2."}},
		"auto_reload": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "Reload automatically when the magazine runs dry."}},
		"infinite_reserve": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Reloads never spend reserve ammo."}},
		# ── Internal state ───────────────────────────────────────────────────────────
		"_cooldown": {"type": "float", "default": 0.0, "exported": false},
		"_reloading": {"type": "bool", "default": false, "exported": false},
		"_reload_timer": {"type": "float", "default": 0.0, "exported": false},
		"_burst_left": {"type": "int", "default": 0, "exported": false}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "Weapon Kit: ammo + reserve, fire-rate cooldown, single/auto/burst modes, and timed/instant reload. Call Fire (it manages ammo + cooldown and triggers On Fire - you spawn the bullet); call Reload. Read Ammo %, Reload Progress, etc. for HUD."
	sheet.events.append(about)

	# Triggers + conditions + expressions + private helpers (class-level annotated block).
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Fire\")",
		"signal fired",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Empty\")",
		"signal emptied",
		"",
		"## @ace_trigger",
		"signal reload_started",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Reload Complete\")",
		"signal reload_completed",
		"",
		"func can_fire() -> bool:",
		"\treturn not _reloading and _cooldown <= 0.0 and current_ammo > 0 and _burst_left <= 0",
		"",
		"func has_ammo() -> bool:",
		"\treturn current_ammo > 0",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Full\")",
		"func is_full() -> bool:",
		"\treturn current_ammo >= max_ammo",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Reloading\")",
		"func is_reloading() -> bool:",
		"\treturn _reloading",
		"",
		"func ammo_percent() -> float:",
		"\treturn (float(current_ammo) / float(maxi(max_ammo, 1))) * 100.0",
		"",
		"func reload_progress() -> float:",
		"\tif not _reloading:",
		"\t\treturn 1.0",
		"\treturn clampf(1.0 - _reload_timer / maxf(reload_time, 0.01), 0.0, 1.0)",
		"",
		"func cooldown_progress() -> float:",
		"\treturn clampf(1.0 - _cooldown * maxf(fire_rate, 0.01), 0.0, 1.0)",
		"",
		"# One round leaves the barrel: spend ammo, start the cooldown, trigger On Fire, and",
		"# fall through to empty/auto-reload when the magazine runs dry.",
		"func _fire_one() -> void:",
		"\tcurrent_ammo -= 1",
		"\t_cooldown = 1.0 / maxf(fire_rate, 0.01)",
		"\tfired.emit()",
		"\tif current_ammo <= 0:",
		"\t\t_burst_left = 0",
		"\t\temptied.emit()",
		"\t\tif auto_reload:",
		"\t\t\treload()",
		"",
		"# Move rounds from the reserve into the magazine (capped by reserve unless infinite).",
		"func _complete_reload() -> void:",
		"\tvar needed: int = max_ammo - current_ammo",
		"\tvar taken: int = needed if infinite_reserve else mini(needed, reserve_ammo)",
		"\tcurrent_ammo += taken",
		"\tif not infinite_reserve:",
		"\t\treserve_ammo -= taken",
		"\t_reloading = false",
		"\t_reload_timer = 0.0",
		"\treload_completed.emit()"
	]))
	sheet.events.append(block)

	# Core loop: tick the cooldown, finish a timed reload, and feed burst-mode follow-up shots.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var loop: RawCodeRow = RawCodeRow.new()
	loop.code = "\n".join(PackedStringArray([
		"_cooldown = maxf(_cooldown - delta, 0.0)",
		"if _reloading:",
		"\t_reload_timer = maxf(_reload_timer - delta, 0.0)",
		"\tif _reload_timer <= 0.0:",
		"\t\t_complete_reload()",
		"elif _burst_left > 0 and _cooldown <= 0.0:",
		"\tif current_ammo > 0:",
		"\t\t_burst_left -= 1",
		"\t\t_fire_one()",
		"\telse:",
		"\t\t_burst_left = 0"
	]))
	tick.actions.append(loop)
	sheet.events.append(tick)

	# ── Exposed actions ─────────────────────────────────────────────────────────────
	Lib.append_function(sheet, "fire", "Fire", "Weapon",
		"Fires if ready (not reloading, off cooldown, has ammo). In burst mode it kicks off a burst; if the magazine is empty it triggers On Empty (and auto-reloads when enabled).",
		[],
		"\n".join(PackedStringArray([
			"if _reloading or _cooldown > 0.0 or _burst_left > 0:",
			"\treturn",
			"if current_ammo <= 0:",
			"\temptied.emit()",
			"\tif auto_reload:",
			"\t\treload()",
			"\treturn",
			"if fire_mode == 2:",
			"\t_burst_left = maxi(burst_count, 1)",
			"\t_burst_left -= 1",
			"_fire_one()"
		])))
	Lib.append_function(sheet, "reload", "Reload", "Weapon",
		"Starts a timed reload (if not full and reserve has rounds).",
		[],
		"\n".join(PackedStringArray([
			"if _reloading or current_ammo >= max_ammo:",
			"\treturn",
			"if not infinite_reserve and reserve_ammo <= 0:",
			"\treturn",
			"_reloading = true",
			"_reload_timer = reload_time",
			"_burst_left = 0",
			"reload_started.emit()"
		])))
	Lib.append_function(sheet, "cancel_reload", "Cancel Reload", "Weapon",
		"Aborts an in-progress reload (no ammo gained).",
		[],
		"_reloading = false\n_reload_timer = 0.0")
	Lib.append_function(sheet, "instant_reload", "Instant Reload", "Weapon",
		"Refills the magazine immediately (no reload time).",
		[],
		"_reloading = false\n_complete_reload()")
	Lib.append_function(sheet, "add_ammo", "Add Ammo", "Weapon",
		"Adds rounds straight to the magazine (capped at the magazine size).",
		[["amount", "int"]],
		"current_ammo = mini(current_ammo + amount, max_ammo)")
	Lib.append_function(sheet, "add_reserve", "Add Reserve Ammo", "Weapon",
		"Adds spare rounds to the reserve pool (e.g. an ammo pickup).",
		[["amount", "int"]],
		"reserve_ammo += amount")
	Lib.append_function(sheet, "set_fire_rate", "Set Fire Rate", "Weapon",
		"Changes the shots-per-second.",
		[["rate", "float"]],
		"fire_rate = rate")
	Lib.append_function(sheet, "set_fire_mode", "Set Fire Mode", "Weapon",
		"0 = single, 1 = auto, 2 = burst.",
		[["mode", "int"]],
		"fire_mode = mode")
	Lib.append_function(sheet, "set_max_ammo", "Set Magazine Size", "Weapon",
		"Changes the magazine size.",
		[["size", "int"]],
		"max_ammo = maxi(size, 0)")

	# Save-state seam - deliberately unpublished; the Save System provides the user-facing verbs.
	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"# Transient combat state (_cooldown, _reloading, _burst_left) is deliberately skipped.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"ammo\": current_ammo,",
		"\t\t\"reserve\": reserve_ammo",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\tcurrent_ammo = int(state.get(\"ammo\", 12))",
		"\treserve_ammo = int(state.get(\"reserve\", 96))"
	]))
	sheet.events.append(persistence)

	return Lib.save_pack(sheet, "res://eventsheet_addons/weapon_kit/weapon_kit_behavior")
