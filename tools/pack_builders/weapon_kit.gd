# Pack builder - weapon_kit (one pack per file; run via tools/build_sample_behaviors.gd).
#
# Shooter state machine ported from the author's "WeaponKit" addon: ammo + reserve
# pools, fire-rate cooldown, single/auto/burst fire modes, and timed/instant reload with
# auto-reload. It owns NO projectile - Fire just manages ammo/cooldown and emits On Fire,
# so the sheet spawns the bullet/hitscan however it likes (parity-safe, engine-agnostic).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("weapon_kit", "Node2D", "WeaponKit",
		"Turns any Node2D into a gun: a magazine and reserve pool, a fire-rate cooldown, single / auto / burst modes, and timed or instant reloads with optional auto-reload. Fire spends a round and fires On Fire - inside that trigger you spawn the bullet or cast the hitscan however your game likes.",
		Lib.manifest().behavior().category("Weapon").tags(["combat", "shooter"]).expose_all_verbs_on_a_node())
	src.sheet.variables = {
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
	src.note("Weapon Kit: ammo + reserve, fire-rate cooldown, single/auto/burst modes, and timed/instant reload. Call Fire (it manages ammo + cooldown and triggers On Fire - you spawn the bullet); call Reload. Read Ammo %, Reload Progress, etc. for HUD.")
	src.block("block_1")
	src.on_ready()
	src.on_process()
	src.block("block_2")
	src.verb("fire", "Fire",
		"Fires if ready (not reloading, off cooldown, has ammo). In burst mode it kicks off a burst; if the magazine is empty it triggers On Empty (and auto-reloads when enabled).",
		[])
	src.verb("reload", "Reload",
		"Starts a timed reload (if not full and reserve has rounds).",
		[])
	src.verb("cancel_reload", "Cancel Reload",
		"Aborts an in-progress reload (no ammo gained).",
		[])
	src.verb("instant_reload", "Instant Reload",
		"Refills the magazine immediately (no reload time).",
		[])
	src.verb("add_ammo", "Add Ammo",
		"Adds rounds straight to the magazine (capped at the magazine size).",
		[["amount", "int"]])
	src.verb("add_reserve", "Add Reserve Ammo",
		"Adds spare rounds to the reserve pool (e.g. an ammo pickup).",
		[["amount", "int"]])
	src.verb("set_fire_rate", "Set Fire Rate",
		"Changes the shots-per-second.",
		[["rate", "float"]])
	src.verb("set_fire_mode", "Set Fire Mode",
		"0 = single, 1 = auto, 2 = burst.",
		[["mode", "int"]])
	src.verb("set_max_ammo", "Set Magazine Size",
		"Changes the magazine size.",
		[["size", "int"]])
	# WHOSE SHOT IT WAS. The pack owns no projectile, so the sheet spawns it - and this is the one
	# row that tells the world whose it is, writing the node metadata key `owner` the Ownership rows
	# read. The shot points at the weapon and the weapon at whoever is holding it, so the chain
	# credits the person even though this pack has never heard of them.
	src.verb("claim_shot", "Claim Shot",
		"Marks a round this weapon just sent out as belonging to the weapon. Drop it beside the spawn inside On Fire: friendly fire is then refused by Hit Is Not My Owner, and Take Damage From credits the kill to whoever the weapon itself belongs to rather than to the bullet.",
		[["shot", "Node"]])
	Lib.feature_verbs(src.sheet, ["fire", "reload"])
	return Lib.publish(src, "res://eventsheet_addons/weapon_kit/weapon_kit_behavior")
