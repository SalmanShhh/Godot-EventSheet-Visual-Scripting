# Godot EventSheets - data-driven loot: LootTableResource + LootBox "Load From Resource".
#
# Proves the data-driven path: a LootTableResource (a Custom Resource you would fill in the Inspector)
# loaded into the LootBox autoload in one call becomes a real, rollable table. Also that loading a null
# resource is safe (the missing-resource case the Loot Table Loader behavior guards with its Inspector
# required warning).
@tool
class_name LootResourceTest
extends RefCounted

const LOOTBOX := "res://eventsheet_addons/loot_table/loot_table_addon.gd"
const RES := "res://eventsheet_addons/loot_table_resource/loot_table_resource.gd"


static func run() -> bool:
	var all_passed: bool = true
	var lb_script: GDScript = load(LOOTBOX)
	var res_script: GDScript = load(RES)
	all_passed = _check("LootBox + LootTableResource load + parse", lb_script != null and res_script != null, true) and all_passed
	if lb_script == null or res_script == null:
		return all_passed

	var lb: Node = lb_script.new()
	var res: Resource = res_script.new()
	res.set("table_name", "chest")
	res.set("entries", [
		{"item": "gold", "weight": 70.0, "tags": ""},
		{"item": "gem", "weight": 30.0, "tags": "rare"}
	])
	res.set("pity_tag", "rare")
	res.set("pity_threshold", 5)

	lb.load_from_resource(res)
	all_passed = _check("Load From Resource registers the table and its entries",
		lb.has_table("chest") and lb.entry_count("chest") == 2, true) and all_passed
	all_passed = _check("Load From Resource carries the resource's pity into the table",
		lb.entry_has_tag("chest", "rare"), true) and all_passed

	# A seeded roll from the loaded table drops one of the resource's items.
	lb._rng.seed = 12345
	var got: Array = [""]
	lb.on_roll_result.connect(func() -> void: got[0] = lb.roll_item())
	lb.roll("chest")
	all_passed = _check("a roll from a loaded resource drops one of its items",
		got[0] == "gold" or got[0] == "gem", true) and all_passed

	# Loading no resource is safe (the Loot Table Loader flags this in the Inspector instead).
	lb.load_from_resource(null)
	all_passed = _check("Load From Resource with no resource is safe and keeps the existing table",
		lb.has_table("chest"), true) and all_passed

	lb.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] loot_resource_test: %s" % label)
		return true
	print("[FAIL] loot_resource_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
