# EventForge - the data-driven Simple Abilities loader and the Advanced Random shared-random toggle.
#
# Two additive features: an AbilitySetResource loads a whole loadout into a Simple Abilities behavior,
# and the procedural packs gained a Use Advanced Random action that routes their draws through the shared
# AdvancedRandom autoload (falling back safely to their own generator when it is absent - which is the
# case for a bare .new() with no /root). Pins that the loader reads the resource correctly and that the
# toggle exists and never crashes generation.
@tool
class_name RandomIntegrationTest
extends RefCounted

const ABILITY_SET := "res://eventsheet_addons/ability_set_resource/ability_set_resource.gd"
const ABILITIES := "res://eventsheet_addons/abilities/abilities_behavior.gd"
const PROC_ROOM := "res://eventsheet_addons/proc_room/proc_room_addon.gd"
const LOOT_TABLE := "res://eventsheet_addons/loot_table/loot_table_addon.gd"
const SKIN_VAULT := "res://eventsheet_addons/skin_vault/skin_vault_addon.gd"
const STORYLETS := "res://eventsheet_addons/storylet_weaver/storylet_weaver_addon.gd"
const ADVANCED_RANDOM := "res://eventsheet_addons/advanced_random/advanced_random_addon.gd"
const RANDOM_TABLE := "res://eventsheet_addons/random_table_resource/random_table_resource.gd"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_ability_set_loading() and all_passed
	all_passed = _test_shared_random_toggle() and all_passed
	all_passed = _test_pick_from_table() and all_passed
	return all_passed


static func _test_pick_from_table() -> bool:
	var passed: bool = true
	# A RandomTableResource is a plain Resource with an `entries` Array of {value, weight} rows;
	# Advanced Random's Pick From Table reads it dynamically and picks in proportion to weight.
	var table: Resource = load(RANDOM_TABLE).new()
	table.entries = [{"value": "gold", "weight": 10.0}, {"value": "gem", "weight": 1.0}]
	var random: Node = load(ADVANCED_RANDOM).new()
	random.set_random_seed(1)
	var picked: String = random.pick_from_table(table)
	passed = _check("pick_from_table returns a listed value", picked == "gold" or picked == "gem", true) and passed
	passed = _check("pick_from_table null is empty", random.pick_from_table(null), "") and passed
	var empty_table: Resource = load(RANDOM_TABLE).new()
	passed = _check("pick_from_table empty is empty", random.pick_from_table(empty_table), "") and passed
	# A zero-weight row must NEVER be drawn (the strict-accumulate weighted pick). With a 0-weight
	# "never" ahead of a positive "always", every draw is "always".
	var guarded: Resource = load(RANDOM_TABLE).new()
	guarded.entries = [{"value": "never", "weight": 0.0}, {"value": "always", "weight": 1.0}]
	var all_always: bool = true
	for i: int in 50:
		if random.pick_from_table(guarded) != "always":
			all_always = false
	passed = _check("zero-weight row is never picked", all_always, true) and passed
	random.free()
	return passed


static func _test_ability_set_loading() -> bool:
	var passed: bool = true
	# An AbilitySetResource is a plain Resource with an `abilities` Array of rows.
	var resource: Resource = load(ABILITY_SET).new()
	resource.abilities = [
		{"id": "dash", "cooldown": 2.0, "max_stacks": 3, "temporary": 0.0, "tags": "movement,active"},
		{"id": "shield", "cooldown": 5.0, "max_stacks": 1, "temporary": 0.0, "tags": "defense"},
		{"id": "rage", "cooldown": 0.0, "max_stacks": 1, "temporary": 8.0, "tags": ""}
	]
	var behaviour: Node = load(ABILITIES).new()
	behaviour.load_ability_set(resource)
	passed = _check("loaded 3 abilities", behaviour.get_ability_count(), 3) and passed
	passed = _check("dash exists", behaviour.has_ability("dash"), true) and passed
	passed = _check("dash has 3 max stacks", behaviour.get_max_stacks("dash"), 3) and passed
	passed = _check("dash starts with full stacks", behaviour.get_stacks("dash"), 3) and passed
	passed = _check("dash tagged movement", behaviour.ability_has_tag("dash", "movement"), true) and passed
	passed = _check("dash tagged active", behaviour.ability_has_tag("dash", "active"), true) and passed
	passed = _check("shield tagged defense", behaviour.ability_has_tag("shield", "defense"), true) and passed
	# A temporary ability carries its expiration.
	passed = _check("rage is temporary (8s)", _near(behaviour.get_max_expiration_time("rage"), 8.0, 0.001), true) and passed
	# A row with no id is skipped, and a null resource is a safe no-op.
	behaviour.load_ability_set(null)
	passed = _check("null resource is safe", behaviour.get_ability_count(), 3) and passed
	# Reset Cooldown refreshes a spent ability (readiness is charge-based): spend dash to 0 charges
	# (not ready), then Reset Cooldown grants a charge back so it is ready again - the kill-refresh idiom.
	behaviour.set_stacks("dash", 0)
	passed = _check("dash not ready at 0 charges", behaviour.is_ready("dash"), false) and passed
	behaviour.reset_cooldown("dash")
	passed = _check("reset cooldown grants a charge", behaviour.get_stacks("dash") >= 1, true) and passed
	passed = _check("dash ready after reset cooldown", behaviour.is_ready("dash"), true) and passed
	behaviour.free()
	return passed


static func _test_shared_random_toggle() -> bool:
	var passed: bool = true
	# Enabling shared random on a bare instance (no /root/AdvancedRandom) must fall back to the local
	# generator, so generation still works and nothing crashes. Every proc pack exposes the toggle.
	var proc: Node = load(PROC_ROOM).new()
	proc.use_advanced_random(true)
	proc.register_room_type("room", 1.0, 0, -1, -1)
	proc.generate("seed-x", 4, 2)
	passed = _check("ProcRoom still generates with shared flag on", proc.total_rooms() > 0, true) and passed
	proc.use_advanced_random(false)
	proc.generate("seed-x", 4, 2)
	passed = _check("ProcRoom generates with shared flag off", proc.total_rooms() > 0, true) and passed
	proc.free()

	# The other three packs expose the same toggle - calling it must not error.
	var loot: Node = load(LOOT_TABLE).new()
	loot.use_advanced_random(true)
	passed = _check("LootBox toggle callable", loot.has_method("use_advanced_random"), true) and passed
	loot.free()

	var skins: Node = load(SKIN_VAULT).new()
	skins.use_advanced_random(true)
	passed = _check("SkinVault toggle callable", skins.has_method("use_advanced_random"), true) and passed
	skins.free()

	var story: Node = load(STORYLETS).new()
	story.use_advanced_random(true)
	passed = _check("Storylets toggle callable", story.has_method("use_advanced_random"), true) and passed
	story.free()
	return passed


static func _near(actual: float, expected: float, tolerance: float) -> bool:
	return absf(actual - expected) <= tolerance


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] random_integration_test: %s" % label)
		return true
	print("[FAIL] random_integration_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
