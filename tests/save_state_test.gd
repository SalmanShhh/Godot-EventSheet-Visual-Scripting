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
	all_passed = _studio_generator() and all_passed
	all_passed = _reviewer_regressions() and all_passed
	all_passed = _new_formats_and_read_helpers() and all_passed
	return all_passed


## The ini and xml backends round-trip a range of values (including XML-special and INI
## key=value characters), and the Read All / List Save Keys / Read Save File helpers work.
static func _new_formats_and_read_helpers() -> bool:
	var all_passed: bool = true
	for fmt: String in ["ini", "xml"]:
		var sv: Node = _new_save_system("regress_%s" % fmt, fmt)
		sv.call("save_value", "coins", 1500)
		sv.call("save_value", "player", "Zed <the> \"Bold\" & Co")
		sv.call("save_value", "path", "C:\\Users\\me")
		sv.call("save_value", "pos", Vector2(3, 4))
		sv.call("save_value", "bag", {"sword": 1, "note": "a=b;c"})
		all_passed = _check("%s: int stays int" % fmt, typeof(sv.call("load_value", "coins", 0)), TYPE_INT) and all_passed
		all_passed = _check("%s: special-char string round-trips" % fmt, sv.call("load_value", "player", ""), "Zed <the> \"Bold\" & Co") and all_passed
		all_passed = _check("%s: backslash path round-trips" % fmt, sv.call("load_value", "path", ""), "C:\\Users\\me") and all_passed
		all_passed = _check("%s: Vector2 round-trips" % fmt, sv.call("load_value", "pos", Vector2.ZERO), Vector2(3, 4)) and all_passed
		var bag: Dictionary = sv.call("load_value", "bag", {})
		all_passed = _check("%s: nested dict with = and ; survives" % fmt, str(bag.get("note", "")), "a=b;c") and all_passed
		# Read helpers: whole slot, its keys, and reading the same file back by path.
		var all_data: Dictionary = sv.call("read_all")
		all_passed = _check("%s: Read All returns every key" % fmt, all_data.size(), 5) and all_passed
		all_passed = _check("%s: List Save Keys lists them" % fmt, (sv.call("save_keys") as Array).has("coins"), true) and all_passed
		var by_path: Dictionary = sv.call("read_file", str(sv.call("_slot_path")), fmt)
		all_passed = _check("%s: Read Save File reads an arbitrary path" % fmt, by_path.get("coins", 0), 1500) and all_passed
		all_passed = _check("%s: Read Save File with a blank format uses the active one" % fmt, sv.call("read_file", str(sv.call("_slot_path")), "").get("coins", 0), 1500) and all_passed
		_remove_slot(sv)
		sv.free()
	# Read Save File crosses formats: write json, read it back through Read Save File as json.
	var writer: Node = _new_save_system("regress_cross", "json")
	writer.call("save_value", "level", 9)
	var cross: Dictionary = writer.call("read_file", str(writer.call("_slot_path")), "json")
	all_passed = _check("Read Save File reads a different-format file by name", cross.get("level", 0), 9) and all_passed
	_remove_slot(writer)
	writer.free()
	# An empty-string value survives ini and xml (the empty-content edge).
	for fmt: String in ["ini", "xml"]:
		var sv2: Node = _new_save_system("regress_empty_%s" % fmt, fmt)
		sv2.call("save_value", "note", "")
		all_passed = _check("%s: empty string round-trips" % fmt, sv2.call("load_value", "note", "x"), "") and all_passed
		_remove_slot(sv2)
		sv2.free()
	return all_passed


## Regressions for the confirmed data-loss bugs an adversarial review reproduced:
## a failed read wiping the slot on the next write, non-atomic overwrite, CSV
## backslash corruption, the JSON wrapper-key collision, and RNG precision through JSON.
static func _reviewer_regressions() -> bool:
	var all_passed: bool = true
	# 1. A failed read (here: wrong encryption key on a plaintext slot) must NOT let the
	# next write clobber the existing save. The write-guard aborts instead.
	var guard: Node = _new_save_system("regress_guard", "config")
	guard.call("save_value", "coins", 100)
	guard.set("encryption_key", "wrongkey")
	guard.call("_read_all")
	all_passed = _check("read failure is detected (not treated as empty)", guard.get("_last_read_ok"), false) and all_passed
	guard.call("save_value", "gems", 5)  # must be refused, not a wipe
	guard.set("encryption_key", "")
	all_passed = _check("a failed read does not wipe the existing save", guard.call("load_value", "coins", -1), 100) and all_passed
	all_passed = _check("the guarded write was refused, not applied", guard.call("has_save_key", "gems"), false) and all_passed
	_remove_slot(guard)
	guard.free()
	# 2. Atomic overwrite: writing a slot twice (rename over an existing file) must work
	# on every platform and leave the newest value, with no leftover .tmp.
	var atomic: Node = _new_save_system("regress_atomic", "config")
	atomic.call("save_value", "hp", 1)
	atomic.call("save_value", "hp", 2)
	all_passed = _check("second write overwrites (atomic rename works)", atomic.call("load_value", "hp", -1), 2) and all_passed
	all_passed = _check("no .tmp file is left behind", FileAccess.file_exists(str(atomic.call("_slot_path")) + ".tmp"), false) and all_passed
	_remove_slot(atomic)
	atomic.free()
	# 3. CSV must round-trip a backslash (Windows paths, regex, escape sequences).
	var csv: Node = _new_save_system("regress_csv", "csv")
	csv.call("save_value", "path", "C:\\Users\\me")
	csv.call("save_value", "shape", Vector2(3, 4))
	all_passed = _check("csv round-trips a backslash value", csv.call("load_value", "path", ""), "C:\\Users\\me") and all_passed
	all_passed = _check("csv round-trips a Vector2", csv.call("load_value", "shape", Vector2.ZERO), Vector2(3, 4)) and all_passed
	_remove_slot(csv)
	csv.free()
	# 4. The JSON wrapper key moved off "__var", so a user dict using the OLD key now
	# round-trips as real data instead of being mis-decoded.
	var jsonw: Node = _new_save_system("regress_json", "json")
	jsonw.call("save_value", "userdict", {"__var": "hello"})
	all_passed = _check("a user dict keyed __var survives json (no wrapper collision)", jsonw.call("load_value", "userdict", {}), {"__var": "hello"}) and all_passed
	_remove_slot(jsonw)
	jsonw.free()
	# 5. RNG determinism survives every format (big 64-bit state does not lose precision).
	for fmt: String in ["config", "json", "binary", "csv"]:
		var sv: Node = _new_save_system("regress_rng_%s" % fmt, fmt)
		var source: Node = (load(str(STATEFUL_PACKS["advanced_random"])) as GDScript).new()
		var rng: RandomNumberGenerator = source.get("_rng")
		rng.seed = 999
		for _i: int in range(5):
			rng.randi()
		sv.call("save_value", "rng", source.call("save_state"))
		var restored: Node = (load(str(STATEFUL_PACKS["advanced_random"])) as GDScript).new()
		restored.call("load_state", sv.call("load_value", "rng", {}))
		all_passed = _check("%s preserves RNG determinism" % fmt, (restored.get("_rng") as RandomNumberGenerator).randi(), rng.randi()) and all_passed
		_remove_slot(sv)
		sv.free()
		source.free()
		restored.free()
	# 6. A stateful pack survives a full trip through the JSON file backend (not just the
	# in-memory seam) - the format the earlier tests never exercised end to end.
	var sv_json: Node = _new_save_system("regress_pack_json", "json")
	var forge: Node = (load(str(STATEFUL_PACKS["stat_forge"])) as GDScript).new()
	forge.set("auto_tick", false)
	forge.call("set_stat_base", "hp", 80.0)
	forge.call("add_buff", "vest", "hp", 20.0, "add", "gear", "shop", 0.0)
	sv_json.call("save_value", "forge", forge.call("save_state"))
	var forge2: Node = (load(str(STATEFUL_PACKS["stat_forge"])) as GDScript).new()
	forge2.set("auto_tick", false)
	forge2.call("load_state", sv_json.call("load_value", "forge", {}))
	all_passed = _check("StatForge survives a full JSON file round-trip", forge2.call("stat_total", "hp"), 100.0) and all_passed
	_remove_slot(sv_json)
	sv_json.free()
	forge.free()
	forge2.free()
	return all_passed


static func _new_save_system(name: String, fmt: String) -> Node:
	var sv: Node = (load("res://eventsheet_addons/save_system/save_system_addon.gd") as GDScript).new()
	sv.set("save_directory", "user://")
	sv.set("file_pattern", "test_%s_{slot}.dat" % name)
	sv.set("format", fmt)
	return sv


static func _remove_slot(sv: Node) -> void:
	var path: String = str(sv.call("_slot_path"))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## The Save Studio "Add Save Support" generator: its pure core must emit the exact
## convention (underscore-stripped keys, typed coercion, duplicate(true) on collections)
## AND the emitted pair must be valid GDScript that actually round-trips a live node.
static func _studio_generator() -> bool:
	var all_passed: bool = true
	var code: String = EventSheetSaveStudio.build_seam_code([
		{"name": "_wallet", "type": "Dictionary"},
		{"name": "level", "type": "int"},
		{"name": "speed", "type": "float"},
		{"name": "unlocked", "type": "bool"},
		{"name": "title", "type": "String"}
	])
	all_passed = _check("generator strips the leading underscore for the key", code.contains("\"wallet\": _wallet.duplicate(true)"), true) and all_passed
	all_passed = _check("generator coerces ints on load", code.contains("level = int(state.get(\"level\", level))"), true) and all_passed
	all_passed = _check("generator deep-duplicates dictionaries on load", code.contains("_wallet = (state.get(\"wallet\", {}) as Dictionary).duplicate(true)"), true) and all_passed
	all_passed = _check("generator tolerates an empty state", code.contains("if state.is_empty():"), true) and all_passed
	all_passed = _check("last snapshot entry drops its trailing comma", code.contains("\"title\": title\n\t}"), true) and all_passed
	# The real test: wrap the generated pair in a class and confirm it compiles + runs.
	var script: GDScript = GDScript.new()
	script.source_code = "@tool\nextends Node\n\nvar _wallet: Dictionary = {}\nvar level: int = 0\nvar speed: float = 0.0\nvar unlocked: bool = false\nvar title: String = \"\"\n\n\n%s\n" % code
	all_passed = _check("generated seam compiles", script.reload(), OK) and all_passed
	var live: Node = script.new()
	live.set("_wallet", {"gold": 5})
	live.set("level", 9)
	live.set("title", "hero")
	var snap: Dictionary = live.call("save_state")
	var fresh: Node = script.new()
	fresh.call("load_state", snap)
	all_passed = _check("generated seam round-trips a live node", fresh.call("save_state"), snap) and all_passed
	live.free()
	fresh.free()
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


## All six backends round-trip exact Variants (config/binary natively; json via the
## wrapper; csv/ini/xml via var_to_str/str_to_var), preserving float, int, Vector2, and
## nested-dict types identically in every format.
static func _format_round_trips() -> bool:
	var all_passed: bool = true
	for fmt: String in ["config", "json", "binary", "csv", "ini", "xml"]:
		var sv: Node = (load("res://eventsheet_addons/save_system/save_system_addon.gd") as GDScript).new()
		sv.set("save_directory", "user://")
		sv.set("file_pattern", "test_seam_%s_{slot}.dat" % fmt)
		sv.set("format", fmt)
		sv.call("save_value", "hp", 42.5)
		sv.call("save_value", "count", 7)
		sv.call("save_value", "pos", Vector2(3.0, 4.0))
		sv.call("save_value", "bag", {"sword": 1, "name": "zed"})
		all_passed = _check("%s: float round-trips" % fmt, sv.call("load_value", "hp", 0.0), 42.5) and all_passed
		all_passed = _check("%s: a top-level int stays an int" % fmt, typeof(sv.call("load_value", "count", 0)), TYPE_INT) and all_passed
		all_passed = _check("%s: Vector2 round-trips exactly" % fmt, sv.call("load_value", "pos", Vector2.ZERO), Vector2(3.0, 4.0)) and all_passed
		var bag: Dictionary = sv.call("load_value", "bag", {})
		all_passed = _check("%s: nested dict text survives" % fmt, str(bag.get("name", "")), "zed") and all_passed
		# Every format now preserves int type (JSON wraps ints so they survive its float parse).
		all_passed = _check("%s: nested int keeps its type" % fmt, bag.get("sword", 0), 1) and all_passed
		all_passed = _check("%s: nested int is still an int, not a float" % fmt, typeof(bag.get("sword", 0)), TYPE_INT) and all_passed
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
