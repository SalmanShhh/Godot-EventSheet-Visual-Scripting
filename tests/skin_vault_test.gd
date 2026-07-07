# Godot EventSheets - skin_vault pack (cosmetic ownership autoload) smoke + rules.
#
# Loads the COMPILED pack and drives it directly (pure Dictionary state + signals; the OnReady
# randomize never runs on a bare .new(), so the RNG is seeded here for determinism). Proves roll /
# grant / revoke, the purchase handshake, tier-based hard pity, pool-empty, and owned-set save/load.
@tool
class_name SkinVaultTest
extends RefCounted

const PACK := "res://eventsheet_addons/skin_vault/skin_vault_addon.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("skin_vault pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var sv: Node = script.new()
	sv._rng.seed = 42
	var rolled: Array = [0]
	var unlocked: Array = [0]
	var requested: Array = [0]
	var cancelled: Array = [0]
	var revoked: Array = [0]
	var pool_empty: Array = [0]
	sv.on_skin_rolled.connect(func() -> void: rolled[0] += 1)
	sv.on_skin_unlocked.connect(func() -> void: unlocked[0] += 1)
	sv.on_purchase_requested.connect(func() -> void: requested[0] += 1)
	sv.on_purchase_cancelled.connect(func() -> void: cancelled[0] += 1)
	sv.on_skin_revoked.connect(func() -> void: revoked[0] += 1)
	sv.on_pool_empty.connect(func() -> void: pool_empty[0] += 1)

	sv.register_rarity("common", 100.0, 0)
	sv.register_rarity("epic", 5.0, 2)
	sv.register_skin("cap", "Baseball Cap", "common", 50.0, "hat")
	sv.register_skin("crown", "Golden Crown", "epic", 500.0, "hat,rare")
	all_passed = _check("registering builds the catalog",
		sv.total_skins() == 2 and sv.is_registered("cap") and not sv.is_owned("cap") and sv.is_unlockable("cap"), true) and all_passed

	# Roll grants an unowned skin and fires both triggers.
	sv.roll("")
	all_passed = _check("a roll grants a skin and fires On Skin Rolled + On Skin Unlocked",
		rolled[0] == 1 and unlocked[0] == 1 and sv.owned_count() == 1 and sv.is_owned(sv.rolled_id()) and sv.unlock_method() == "roll", true) and all_passed

	# Grant is free + idempotent; Revoke removes.
	sv.grant("crown")
	all_passed = _check("Grant unlocks with method grant", sv.is_owned("crown") and sv.unlock_method() == "grant", true) and all_passed
	var unlocked_before: int = unlocked[0]
	sv.grant("crown")
	all_passed = _check("granting an owned skin does nothing", unlocked[0] == unlocked_before, true) and all_passed
	sv.revoke("crown")
	all_passed = _check("Revoke removes the skin and fires On Skin Revoked",
		not sv.is_owned("crown") and revoked[0] == 1 and sv.revoked_id() == "crown", true) and all_passed

	# Purchase handshake: request carries the cost; confirm grants, cancel does not.
	sv.purchase("crown")
	all_passed = _check("Purchase fires On Purchase Requested carrying the cost",
		requested[0] == 1 and sv.requested_id() == "crown" and is_equal_approx(sv.requested_cost(), 500.0) and not sv.is_owned("crown"), true) and all_passed
	sv.confirm_purchase("crown")
	all_passed = _check("Confirm Purchase grants with method purchase", sv.is_owned("crown") and sv.unlock_method() == "purchase", true) and all_passed
	sv.register_skin("visor", "Visor", "common", 20.0, "hat")
	sv.purchase("visor")
	sv.cancel_purchase("visor")
	all_passed = _check("Cancel Purchase fires On Purchase Cancelled and grants nothing",
		cancelled[0] == 1 and not sv.is_owned("visor"), true) and all_passed

	# Pool empty: owning everything makes a roll fire On Pool Empty.
	sv.grant("cap")
	sv.grant("visor")
	all_passed = _check("owning every skin empties the pool", sv.is_pool_empty("") and sv.pool_count("") == 0, true) and all_passed
	sv.roll("")
	all_passed = _check("rolling an empty pool fires On Pool Empty", pool_empty[0] == 1, true) and all_passed

	# Hard pity: an epic is GUARANTEED within threshold+1 rolls even against long odds.
	_reset(sv)
	sv._rng.seed = 7
	sv.enable_pity = true
	sv.pity_threshold = 2
	sv.pity_rarity = "epic"
	sv.register_rarity("common", 100.0, 0)
	sv.register_rarity("epic", 1.0, 2)
	for i: int in 6:
		sv.register_skin("c%d" % i, "Common %d" % i, "common", 10.0, "")
	sv.register_skin("legend", "Legend", "epic", 1.0, "")
	for _r: int in 3:
		sv.roll("")
	all_passed = _check("hard pity guarantees the epic within threshold+1 rolls", sv.is_owned("legend"), true) and all_passed

	# Save/load the owned set round-trips through a comma-separated string.
	_reset(sv)
	sv.register_rarity("common", 100.0, 0)
	sv.register_skin("a", "A", "common", 0.0, "")
	sv.register_skin("b", "B", "common", 0.0, "")
	sv.grant("a")
	sv.grant("b")
	var saved: String = sv.owned_ids()
	sv._owned.clear()
	all_passed = _check("clearing loses ownership", sv.owned_count() == 0, true) and all_passed
	sv.load_owned(saved)
	all_passed = _check("Load Owned restores the owned set from the saved string",
		sv.owned_count() == 2 and sv.is_owned("a") and sv.is_owned("b"), true) and all_passed

	sv.free()
	return all_passed


static func _reset(sv: Node) -> void:
	sv._rarities.clear()
	sv._skins.clear()
	sv._owned.clear()
	sv._pity = 0


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] skin_vault_test: %s" % label)
		return true
	print("[FAIL] skin_vault_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
