# Godot EventSheets — abilities pack (typed AbilityData inner class) behavioral equivalence.
#
# Each ability's runtime state (cooldown/stacks/enabled/active/expiration/tags/data) was an untyped
# Dictionary read via float()/int()/bool() casts at ~40 sites; it's now a typed AbilityData inner
# class. This loads the COMPILED pack and drives the real cooldown-regen / stack / expiry / tag paths
# to prove the inner class emits + parses and the behaviour is unchanged.
@tool
class_name AbilitiesPackTest
extends RefCounted

const PACK := "res://eventsheet_addons/abilities/abilities_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("abilities pack loads + parses (AbilityData inner class emits)", script != null, true) and all_passed
	if script == null:
		return all_passed

	var ab: Node = script.new()

	# Cooldown ability, reset instantly → ready.
	ab.create_ability_with_cooldown("dash", 2.0, true)
	all_passed = _check("reset-instantly ability is ready", ab.is_ready("dash"), true) and all_passed
	all_passed = _check("ready ability has no cooldown", ab.get_cooldown_remaining("dash"), 0.0) and all_passed

	# Charge ability: activate consumes a stack and starts regen; a second of process regenerates it.
	ab.create_ability_with_stacks("blink", 1.0, 3, true)
	all_passed = _check("charge ability starts full", ab.get_stacks("blink"), 3) and all_passed
	ab.activate_ability("blink")
	all_passed = _check("activate consumes a charge", ab.get_stacks("blink"), 2) and all_passed
	all_passed = _check("activate starts the regen cooldown", is_equal_approx(ab.get_cooldown_remaining("blink"), 1.0), true) and all_passed
	ab._process(1.0)
	all_passed = _check("a charge regenerates after its cooldown", ab.get_stacks("blink"), 3) and all_passed
	all_passed = _check("cooldown clears at full charges", ab.get_cooldown_remaining("blink"), 0.0) and all_passed

	# Temporary ability auto-expires.
	ab.create_temporary_ability("guard", 1.0)
	all_passed = _check("temporary ability exists", ab.has_ability("guard"), true) and all_passed
	ab._process(1.0)
	all_passed = _check("temporary ability auto-expires", ab.has_ability("guard"), false) and all_passed

	# Tags (typed Array on AbilityData).
	ab.create_ability("fireball")
	ab.add_tag("fireball", "fire")
	all_passed = _check("ability carries its tag", ab.ability_has_tag("fireball", "fire"), true) and all_passed
	all_passed = _check("tag query counts it", ab.count_abilities_by_tag("fire"), 1) and all_passed

	ab.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] abilities_pack_test: %s" % label)
		return true
	print("[FAIL] abilities_pack_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
