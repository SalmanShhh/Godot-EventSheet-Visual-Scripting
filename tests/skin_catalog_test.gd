# Godot EventSheets - data-driven cosmetics: SkinCatalogResource + SkinVault "Load Catalog".
#
# Proves the data-driven path: a SkinCatalogResource (a Custom Resource you would fill in the Inspector)
# loaded into the SkinVault autoload in one call registers its whole catalog of rarities and skins. Also
# that loading a null resource is safe (the missing-resource case the Skin Catalog Loader behavior guards
# with its Inspector required warning).
@tool
class_name SkinCatalogTest
extends RefCounted

const SKINVAULT := "res://eventsheet_addons/skin_vault/skin_vault_addon.gd"
const RES := "res://eventsheet_addons/skin_catalog_resource/skin_catalog_resource.gd"


static func run() -> bool:
	var all_passed: bool = true
	var sv_script: GDScript = load(SKINVAULT)
	var res_script: GDScript = load(RES)
	all_passed = _check("SkinVault + SkinCatalogResource load + parse", sv_script != null and res_script != null, true) and all_passed
	if sv_script == null or res_script == null:
		return all_passed

	var sv: Node = sv_script.new()
	var res: Resource = res_script.new()
	res.set("rarities", [
		{"name": "common", "weight": 100.0, "tier": 0},
		{"name": "epic", "weight": 5.0, "tier": 2}
	])
	res.set("skins", [
		{"id": "cap", "name": "Baseball Cap", "rarity": "common", "cost": 50.0, "tags": "hat"},
		{"id": "crown", "name": "Golden Crown", "rarity": "epic", "cost": 500.0, "tags": "hat,rare"}
	])

	sv.load_catalog(res)
	all_passed = _check("Load Catalog registers every skin from the resource",
		sv.total_skins() == 2 and sv.is_registered("cap") and sv.is_registered("crown"), true) and all_passed
	all_passed = _check("Load Catalog carries each skin's rarity and cost",
		sv.skin_rarity("crown") == "epic" and is_equal_approx(sv.skin_cost("cap"), 50.0), true) and all_passed

	# Loading no resource is safe (the Skin Catalog Loader flags this in the Inspector instead).
	sv.load_catalog(null)
	all_passed = _check("Load Catalog with no resource is safe and keeps the catalog",
		sv.total_skins() == 2, true) and all_passed

	sv.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] skin_catalog_test: %s" % label)
		return true
	print("[FAIL] skin_catalog_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
