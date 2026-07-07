# Godot EventSheets - loot_table pack (weighted loot roller autoload) smoke + rules.
#
# Loads the COMPILED pack and rolls with a FIXED seed for determinism (the roller is pure math +
# signals; the OnReady randomize never runs on a bare .new(), so seeding is explicit here). Proves
# weighted picking, batch rolls, guarantees, hard pity, nested tables, and seed reproducibility.
@tool
class_name LootTableTest
extends RefCounted

const PACK := "res://eventsheet_addons/loot_table/loot_table_addon.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("loot_table pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var box: Node = script.new()
	var drops: Array = []
	var completes: Array = [0]
	var pity_fired: Array = [0]
	box.on_roll_result.connect(func() -> void: drops.append({"item": box.roll_item(), "tags": box.roll_tags(), "index": box.roll_index()}))
	box.on_roll_complete.connect(func() -> void: completes[0] += 1)
	box.on_pity_triggered.connect(func() -> void: pity_fired[0] += 1)

	box.set_seed(12345)
	box.create_table("chest")
	box.add_entry("chest", "gold", 70.0)
	box.add_entry("chest", "gem", 25.0)
	box.add_entry_full("chest", "crown", 5.0, 1.0, "rare")
	all_passed = _check("a table registers its entries", box.has_table("chest") and box.entry_count("chest") == 3, true) and all_passed

	# One roll fires one On Roll Result + one On Roll Complete.
	box.roll("chest")
	all_passed = _check("one roll drops one item and completes once",
		drops.size() == 1 and completes[0] == 1 and str(drops[0].item) in ["gold", "gem", "crown"], true) and all_passed

	# Weighted: the 70-weight item beats the 5-weight item over many rolls.
	drops.clear()
	box.roll_times("chest", 300)
	var gold_n: int = 0
	var crown_n: int = 0
	for d: Dictionary in drops:
		if str(d.item) == "gold":
			gold_n += 1
		elif str(d.item) == "crown":
			crown_n += 1
	all_passed = _check("a batch roll drops N items and completes once", drops.size() == 300 and completes[0] == 2, true) and all_passed
	all_passed = _check("higher weight drops far more often", gold_n > crown_n and gold_n > 100, true) and all_passed

	# Guarantee: at least one rare-tagged drop per batch.
	box.set_guarantee("chest", "rare", 1)
	drops.clear()
	box.roll_times("chest", 5)
	var got_rare: bool = false
	for d: Dictionary in drops:
		if str(d.tags).contains("rare"):
			got_rare = true
			break
	all_passed = _check("a guarantee forces a tagged drop into every batch", got_rare, true) and all_passed

	# Hard pity: a near-impossible legendary is GUARANTEED after a short miss streak.
	box.create_table("banner")
	box.add_entry("banner", "common", 100.0)
	box.add_entry_full("banner", "five_star", 1.0, 1.0, "legendary")
	box.set_pity("banner", "legendary", 2)
	pity_fired[0] = 0
	var legendary_drops: int = 0
	for _i: int in 12:
		drops.clear()
		box.roll("banner")
		if str(drops[0].tags).contains("legendary"):
			legendary_drops += 1
	all_passed = _check("hard pity fires and forces the tagged drop within a few rolls",
		pity_fired[0] >= 1 and legendary_drops >= 1, true) and all_passed

	# Nested table: a table reference rolls another table inline, still reporting the parent.
	box.create_table("coins")
	box.add_entry("coins", "silver", 1.0)
	box.add_entry("coins", "gold_coin", 1.0)
	box.create_table("boss")
	box.add_table_ref("boss", "coins", 100.0)
	box.add_entry("boss", "sword", 1.0)
	drops.clear()
	box.roll("boss")
	all_passed = _check("a nested table injects its result while reporting the parent table",
		drops.size() == 1 and str(drops[0].item) in ["silver", "gold_coin", "sword"] and box.roll_table() == "boss", true) and all_passed

	# Seed reproducibility: the same seed replays the exact drop (fresh un-guaranteed table).
	box.create_table("seedtest")
	box.add_entry("seedtest", "a", 1.0)
	box.add_entry("seedtest", "b", 1.0)
	box.add_entry("seedtest", "c", 1.0)
	box.set_seed(999)
	drops.clear()
	box.roll("seedtest")
	var first: String = str(drops[0].item)
	box.set_seed(999)
	drops.clear()
	box.roll("seedtest")
	all_passed = _check("a fixed seed reproduces the exact roll", str(drops[0].item), first) and all_passed

	box.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] loot_table_test: %s" % label)
		return true
	print("[FAIL] loot_table_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
