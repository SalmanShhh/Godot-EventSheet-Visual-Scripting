# EventForge - the save-state seam (save_state/load_state on every stateful pack) and
# the Save System's multi-format backends. Pins: (1) symmetric round-trips per pack
# (mutate -> save_state -> load into a fresh instance -> identical re-snapshot),
# (2) behavioral readbacks after load (stat math, timer countdown), (3) all four file
# formats (config/json/binary/csv) restoring exact Variants, (4) the Save Node State
# walk over behavior children, (5) the seam surviving pack emission as @ace_hidden.
@tool
class_name SaveStateTest
extends RefCounted

const STATEFUL_PACKS: Dictionary = {
	"stat_forge": "res://eventsheet_addons/stat_forge/stat_forge_behavior.gd",
	"health": "res://eventsheet_addons/health/health_behavior.gd",
	"currency_ledger": "res://eventsheet_addons/currency_ledger/currency_ledger_addon.gd",
	"skin_vault": "res://eventsheet_addons/skin_vault/skin_vault_addon.gd",
	"timer": "res://eventsheet_addons/timer/timer_behavior.gd",
	"state_machine": "res://eventsheet_addons/state_machine/state_machine_behavior.gd",
	"idle_generator": "res://eventsheet_addons/idle_generator/idle_generator_behavior.gd",
	"click_power": "res://eventsheet_addons/click_power/click_power_addon.gd",
	"boosts": "res://eventsheet_addons/boosts/boosts_addon.gd",
	"upgrades": "res://eventsheet_addons/upgrades/upgrades_addon.gd",
	"prestige": "res://eventsheet_addons/prestige/prestige_addon.gd",
	"milestones": "res://eventsheet_addons/milestones/milestones_addon.gd",
	"weapon_kit": "res://eventsheet_addons/weapon_kit/weapon_kit_behavior.gd",
	"storylet_weaver": "res://eventsheet_addons/storylet_weaver/storylet_weaver_addon.gd",
	"loot_table": "res://eventsheet_addons/loot_table/loot_table_addon.gd",
	"advanced_random": "res://eventsheet_addons/advanced_random/advanced_random_addon.gd",
	"proc_room": "res://eventsheet_addons/proc_room/proc_room_addon.gd",
	"abilities": "res://eventsheet_addons/abilities/abilities_behavior.gd"
}


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _seam_round_trips() and all_passed
	all_passed = _behavioral_readbacks() and all_passed
	all_passed = _format_round_trips() and all_passed
	all_passed = _node_state_walk() and all_passed
	all_passed = _emission_survival() and all_passed
	return all_passed


## Every stateful pack: mutate, snapshot, restore into a FRESH instance, and require the
## fresh instance's own snapshot to be identical. Catches missing keys, bad coercions,
## and shared-reference bugs (a non-duplicated dict would alias, not restore).
static func _seam_round_trips() -> bool:
	var all_passed: bool = true
	for pack: String in STATEFUL_PACKS:
		var first: Node = (load(str(STATEFUL_PACKS[pack])) as GDScript).new()
		_mutate(pack, first)
		var snapshot: Dictionary = first.call("save_state")
		all_passed = _check("%s snapshot is not empty" % pack, snapshot.is_empty(), false) and all_passed
		var second: Node = (load(str(STATEFUL_PACKS[pack])) as GDScript).new()
		second.call("load_state", snapshot.duplicate(true))
		all_passed = _check("%s restores to an identical snapshot" % pack, second.call("save_state"), snapshot) and all_passed
		first.free()
		second.free()
	return all_passed


## Gives each pack state that differs from its defaults, through public surface where
## it is cheap and by direct member writes where the ACE verbs need a scene tree.
static func _mutate(pack: String, node: Node) -> void:
	match pack:
		"stat_forge":
			node.call("set_stat_base", "speed", 100.0)
			node.call("add_buff", "boots", "speed", 20.0, "add", "gear", "shop", 0.0)
		"health":
			node.set("current_health", 37.5)
			node.set("is_dead_flag", false)
		"currency_ledger":
			node.set("_wallet", {"gold": 120.0, "gems": 3.0})
		"skin_vault":
			node.set("_owned", {"crimson": true})
			node.set("_pity", 7)
		"timer":
			node.set("remaining", 2.5)
			node.set("running", true)
			node.set("duration", 4.0)
		"state_machine":
			node.set("state", "attack")
		"idle_generator":
			node.set("owned", 5)
			node.set("output_multiplier", 2.0)
			node.set("_pending", 1.5)
		"click_power":
			node.set("_total_clicks", 42)
			node.set("_multiplier", 3.0)
		"boosts":
			node.set("_boosts", {"haste": {"multiplier": 2.0, "remaining": 5.0, "tag": "speed"}})
		"upgrades":
			node.set("_upgrades", {"dmg": {"level": 3, "base_cost": 10.0, "growth": 1.5}})
		"prestige":
			node.set("_points", 10.0)
			node.set("_level", 2)
			node.set("_total_earned", 999.0)
		"milestones":
			node.set("_milestones", {"first_win": {"threshold": 3.0, "reached": true, "value": 5.0}})
		"weapon_kit":
			node.set("current_ammo", 3)
			node.set("reserve_ammo", 10)
		"storylet_weaver":
			node.set("_qualities", {"trust": 3.0})
			node.set("_plays", {"intro": 2})
		"loot_table":
			node.set("_pity", {"chest": 4})
		"advanced_random":
			var rng: RandomNumberGenerator = node.get("_rng")
			rng.seed = 12345
			rng.randi()
			node.set("_bags", {"tiles": ["a", "b"]})
		"proc_room":
			node.set("_rooms", {"r1": {"type": "start", "depth": 0}})
			node.set("_current", "r1")
			node.set("_seed", "abc")
		"abilities":
			node.call("_ensure_ability", "dash")


## The snapshot must restore BEHAVIOR, not just bytes: stat math and timer countdown
## read back correctly on the restored instance.
static func _behavioral_readbacks() -> bool:
	var all_passed: bool = true
	var forge: Node = (load(str(STATEFUL_PACKS["stat_forge"])) as GDScript).new()
	forge.set("auto_tick", false)
	forge.call("set_stat_base", "speed", 100.0)
	forge.call("add_buff", "boots", "speed", 20.0, "add", "gear", "shop", 0.0)
	forge.call("add_buff", "haste", "speed", 1.5, "multiply", "", "potion", 0.0)
	var forge_state: Dictionary = forge.call("save_state")
	var restored_forge: Node = (load(str(STATEFUL_PACKS["stat_forge"])) as GDScript).new()
	restored_forge.set("auto_tick", false)
	restored_forge.call("load_state", forge_state)
	all_passed = _check("restored StatForge recomputes (base + add) * multiply", restored_forge.call("stat_total", "speed"), 180.0) and all_passed
	forge.free()
	restored_forge.free()
	var ticking: Node = (load(str(STATEFUL_PACKS["timer"])) as GDScript).new()
	ticking.set("remaining", 2.5)
	ticking.set("running", true)
	var timer_state: Dictionary = ticking.call("save_state")
	var restored_timer: Node = (load(str(STATEFUL_PACKS["timer"])) as GDScript).new()
	restored_timer.call("load_state", timer_state)
	all_passed = _check("restored Timer keeps its countdown", restored_timer.get("remaining"), 2.5) and all_passed
	all_passed = _check("restored Timer keeps running", restored_timer.get("running"), true) and all_passed
	ticking.free()
	restored_timer.free()
	return all_passed


## All four backends round-trip exact Variants: config/binary natively, json through the
## {"__var": ...} wrapper (ints legitimately come back as floats there - pinned), csv
## through var_to_str/str_to_var with c_escape keeping every value on one row.
static func _format_round_trips() -> bool:
	var all_passed: bool = true
	for fmt: String in ["config", "json", "binary", "csv"]:
		var sv: Node = (load("res://eventsheet_addons/save_system/save_system_addon.gd") as GDScript).new()
		sv.set("save_directory", "user://")
		sv.set("file_pattern", "test_seam_%s_{slot}.dat" % fmt)
		sv.set("format", fmt)
		sv.call("save_value", "hp", 42.5)
		sv.call("save_value", "pos", Vector2(3.0, 4.0))
		sv.call("save_value", "bag", {"sword": 1, "name": "zed"})
		all_passed = _check("%s: float round-trips" % fmt, sv.call("load_value", "hp", 0.0), 42.5) and all_passed
		all_passed = _check("%s: Vector2 round-trips exactly" % fmt, sv.call("load_value", "pos", Vector2.ZERO), Vector2(3.0, 4.0)) and all_passed
		var bag: Dictionary = sv.call("load_value", "bag", {})
		all_passed = _check("%s: nested dict text survives" % fmt, str(bag.get("name", "")), "zed") and all_passed
		if fmt == "json":
			# JSON has one honest caveat: numbers inside plain dicts parse back as floats.
			all_passed = _check("json: nested int comes back as float (documented)", bag.get("sword", 0), 1.0) and all_passed
		else:
			all_passed = _check("%s: nested int keeps its type" % fmt, bag.get("sword", 0), 1) and all_passed
		DirAccess.remove_absolute(sv.call("_slot_path"))
		sv.free()
	# Spreadsheet workflow: a hand-authored CSV (bare numbers and words, no var_to_str
	# quoting) still loads - numbers parse, unquoted words fall back to raw text.
	var hand: FileAccess = FileAccess.open("user://test_seam_hand_0.dat", FileAccess.WRITE)
	hand.store_string("gold,150\nhero,Zed\n")
	hand.close()
	var reader: Node = (load("res://eventsheet_addons/save_system/save_system_addon.gd") as GDScript).new()
	reader.set("save_directory", "user://")
	reader.set("file_pattern", "test_seam_hand_{slot}.dat")
	reader.set("format", "csv")
	all_passed = _check("hand-authored csv: bare number parses", reader.call("load_value", "gold", 0), 150) and all_passed
	all_passed = _check("hand-authored csv: bare word stays text", reader.call("load_value", "hero", ""), "Zed") and all_passed
	DirAccess.remove_absolute(reader.call("_slot_path"))
	reader.free()
	return all_passed


## Save Node State walks the node plus every behavior child exposing the seam, keyed by
## child name, and Load Node State routes each snapshot back to the same child.
static func _node_state_walk() -> bool:
	var all_passed: bool = true
	var sv: Node = (load("res://eventsheet_addons/save_system/save_system_addon.gd") as GDScript).new()
	sv.set("save_directory", "user://")
	sv.set("file_pattern", "test_seam_walk_{slot}.cfg")
	var player: Node = Node.new()
	player.name = "Player"
	var countdown: Node = (load(str(STATEFUL_PACKS["timer"])) as GDScript).new()
	countdown.name = "Timer"
	player.add_child(countdown)
	var machine: Node = (load(str(STATEFUL_PACKS["state_machine"])) as GDScript).new()
	machine.name = "StateMachine"
	player.add_child(machine)
	countdown.set("remaining", 1.25)
	countdown.set("running", true)
	machine.set("state", "dodge")
	sv.call("save_node_state", player, "player1")
	countdown.set("remaining", 0.0)
	countdown.set("running", false)
	machine.set("state", "idle")
	sv.call("load_node_state", player, "player1")
	all_passed = _check("walk restores the Timer child", countdown.get("remaining"), 1.25) and all_passed
	all_passed = _check("walk restores running", countdown.get("running"), true) and all_passed
	all_passed = _check("walk restores the StateMachine child", machine.get("state"), "dodge") and all_passed
	DirAccess.remove_absolute(sv.call("_slot_path"))
	player.free()
	sv.free()
	return all_passed


## The lesson that keeps on giving: verify the seam SURVIVED pack emission (a lift that
## eats the functions would pass has_method tests on the builder side and ship nothing).
static func _emission_survival() -> bool:
	var all_passed: bool = true
	for pack: String in STATEFUL_PACKS:
		var emitted: String = FileAccess.get_file_as_string(str(STATEFUL_PACKS[pack]))
		all_passed = _check("%s emits save_state" % pack, emitted.contains("func save_state() -> Dictionary:"), true) and all_passed
		all_passed = _check("%s emits load_state" % pack, emitted.contains("func load_state("), true) and all_passed
		all_passed = _check("%s keeps the seam out of the picker" % pack, emitted.count("## @ace_hidden") >= 2, true) and all_passed
	var save_system: String = FileAccess.get_file_as_string("res://eventsheet_addons/save_system/save_system_addon.gd")
	for marker: String in ["func save_node_state", "func load_group_state", "func save_singleton_state", "__persist", "persist_group"]:
		all_passed = _check("save_system emits %s" % marker, save_system.contains(marker), true) and all_passed
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] save_state_test: %s" % label)
		return true
	print("[FAIL] save_state_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
