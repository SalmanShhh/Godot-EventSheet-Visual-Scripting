# Godot EventSheets — health pack (typed HealthPool inner class) behavioral equivalence.
#
# The health pack's named pools (shields/armour) were untyped Dictionary entries read via float()
# casts at ~20 sites; they're now a typed HealthPool inner class. This loads the COMPILED pack and
# drives the real absorption / decay / death paths to prove (a) the inner class emits + parses and
# (b) damage absorption, pool decay, and death are byte-for-byte unchanged.
@tool
extends RefCounted
class_name HealthPackTest

const PACK := "res://eventsheet_addons/health/health_behavior.gd"

static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("health pack loads + parses (HealthPool inner class emits)", script != null, true) and all_passed
	if script == null:
		return all_passed

	var h: Node = script.new()  # no _ready (not in tree): current_health stays at its literal default 100
	all_passed = _check("starts at full health", h.current_health_value(), 100.0) and all_passed

	h.take_damage(30.0)
	all_passed = _check("plain damage lowers HP", h.current_health_value(), 70.0) and all_passed
	all_passed = _check("not dead after a scratch", h.is_dead(), false) and all_passed

	# A shield pool absorbs before real HP.
	h.add_health_pool("shield", 50.0)
	all_passed = _check("pool registered (typed)", h.has_health_pool("shield") and h.health_pool_value("shield") == 50.0, true) and all_passed
	h.take_damage(20.0)
	all_passed = _check("pool soaks the hit, HP untouched", h.current_health_value(), 70.0) and all_passed
	all_passed = _check("pool drained by the absorbed amount", h.health_pool_value("shield"), 30.0) and all_passed
	h.take_damage(40.0)
	all_passed = _check("pool depletes then overflow hits HP", h.health_pool_value("shield") == 0.0 and h.current_health_value() == 60.0, true) and all_passed

	# Pool decay over time (the OnProcess tick).
	h.setup_health_pool("armor", 10.0, 5.0, 1.0, 1.0)  # amount 10, decay 5/s
	h._process(1.0)
	all_passed = _check("pool decays per second", h.health_pool_value("armor"), 5.0) and all_passed

	# Death.
	h.take_damage(100.0)
	all_passed = _check("lethal damage kills + zeroes HP", h.is_dead() == true and h.current_health_value() == 0.0, true) and all_passed

	# Revive restores.
	h.revive(0.0)
	all_passed = _check("revive clears death + refills", h.is_dead() == false and h.current_health_value() == 100.0, true) and all_passed

	h.free()
	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] health_pack_test: %s" % label)
		return true
	print("[FAIL] health_pack_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
