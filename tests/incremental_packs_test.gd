# EventForge - runtime behaviour of the incremental/idle addon suite.
#
# The drift audit proves the packs round-trip; this proves the MATH is right. It loads the compiled
# .gd of each pack, instantiates it, and pins concrete values through the verified formulas: the
# geometric cost curve and closed-form Buy Max, the order-of-magnitude off-by-one fix (1e6 -> "M", not
# "K"), the Decimal type past a float's ceiling, prestige gain + no-double-award, upgrade stacking, and
# milestone reward aggregation. Pins VALUES, never counts.
@tool
class_name IncrementalPacksTest
extends RefCounted

const BIG_NUMBER := "res://eventsheet_addons/big_number/big_number_addon.gd"
const IDLE_GENERATOR := "res://eventsheet_addons/idle_generator/idle_generator_behavior.gd"
const PRESTIGE := "res://eventsheet_addons/prestige/prestige_addon.gd"
const UPGRADES := "res://eventsheet_addons/upgrades/upgrades_addon.gd"
const MILESTONES := "res://eventsheet_addons/milestones/milestones_addon.gd"
const CLICK_POWER := "res://eventsheet_addons/click_power/click_power_addon.gd"
const BOOSTS := "res://eventsheet_addons/boosts/boosts_addon.gd"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_big_number() and all_passed
	all_passed = _test_idle_generator() and all_passed
	all_passed = _test_prestige() and all_passed
	all_passed = _test_upgrades() and all_passed
	all_passed = _test_milestones() and all_passed
	all_passed = _test_click_power() and all_passed
	all_passed = _test_boosts() and all_passed
	return all_passed


static func _test_big_number() -> bool:
	var passed: bool = true
	var big: Node = load(BIG_NUMBER).new()

	# The order-of-magnitude off-by-one: floor(log(x)/log(10)) undercounts at exact powers of ten.
	passed = _check("oom 1000 = 3", big.order_of_magnitude(1000.0), 3) and passed
	passed = _check("oom 1e6 = 6", big.order_of_magnitude(1000000.0), 6) and passed
	passed = _check("oom 1e9 = 9", big.order_of_magnitude(1000000000.0), 9) and passed
	passed = _check("oom 999 = 2", big.order_of_magnitude(999.0), 2) and passed

	# Short-scale suffix bands (a million is M, not K - the classic bug).
	passed = _check("500 has no suffix", big.fmt_short(500.0, 0), "500") and passed
	passed = _check("1.5K", big.fmt_short(1500.0, 1).ends_with("K"), true) and passed
	passed = _check("1.5M", big.fmt_short(1500000.0, 1).ends_with("M"), true) and passed
	passed = _check("1.2B", big.fmt_short(1234567890.0, 1).ends_with("B"), true) and passed
	passed = _check("suffix_for 6 = M", big.suffix_for(6), "M") and passed
	passed = _check("suffix_for 9 = B", big.suffix_for(9), "B") and passed

	# Time, ordinals, commas.
	passed = _check("time 3725", big.fmt_time(3725.0), "1h 2m 5s") and passed
	passed = _check("time 90", big.fmt_time(90.0), "1m 30s") and passed
	passed = _check("ordinal 1", big.fmt_ordinal(1), "1st") and passed
	passed = _check("ordinal 2", big.fmt_ordinal(2), "2nd") and passed
	passed = _check("ordinal 11", big.fmt_ordinal(11), "11th") and passed
	passed = _check("ordinal 21", big.fmt_ordinal(21), "21st") and passed
	passed = _check("comma 1234567", big.fmt_comma(1234567.0), "1,234,567") and passed

	# The Decimal type: arithmetic and compares past a float's 1.8e308 ceiling.
	passed = _check("dec round-trip 1000", _near(big.dec_to(big.dec_from(1000.0)), 1000.0, 0.001), true) and passed
	passed = _check("dec add 100+50", _near(big.dec_to(big.dec_add(big.dec_from(100.0), big.dec_from(50.0))), 150.0, 0.001), true) and passed
	passed = _check("dec compare 5 vs 3", big.dec_compare(big.dec_from(5.0), big.dec_from(3.0)), 1) and passed
	# 1e200 * 1e200 = 1e400 - impossible as a float, trivial as a Decimal.
	var huge: Array = big.dec_mul(big.dec_from(1e200), big.dec_from(1e200))
	passed = _check("1e400 > 1e300 (past float ceiling)", big.dec_greater(huge, big.dec_from(1e300)), true) and passed
	passed = _check("Format Big 1.5e100", big.dec_format(big.dec_make(1.5, 100.0), 2).ends_with("e100"), true) and passed
	# Power in log space must not overflow the mantissa to INF (which _dnorm turns into zero).
	passed = _check("dec pow 2^10 = 1024", _near(big.dec_to(big.dec_pow(big.dec_from(2.0), 10.0)), 1024.0, 0.5), true) and passed
	passed = _check("dec pow 9^400 stays huge", big.dec_greater(big.dec_pow(big.dec_from(9.0), 400.0), big.dec_from(1e300)), true) and passed
	# Compare must order by true value, not exponent-first, when exponents are fractional (1e2.9 < 900).
	passed = _check("dec compare fractional exp", big.dec_compare(big.dec_make(1.0, 2.9), big.dec_make(9.0, 2.0)), -1) and passed

	big.free()
	return passed


static func _test_idle_generator() -> bool:
	var passed: bool = true
	var gen: Node = load(IDLE_GENERATOR).new()
	gen.base_cost = 10.0
	gen.cost_growth = 1.15
	gen.base_output = 1.0
	gen.output_multiplier = 1.0
	gen.owned = 0

	# Geometric cost: first unit is base_cost; two units is 10 + 11.5 = 21.5.
	passed = _check("next cost = base", _near(gen.next_cost(), 10.0, 0.001), true) and passed
	passed = _check("cost for 2 = 21.5", _near(gen.cost_for(2), 21.5, 0.001), true) and passed
	# Closed-form Buy Max: budget 100 at base 10, growth 1.15 -> 6 units for 87.537.
	passed = _check("max affordable(100) = 6", gen.max_affordable(100.0), 6) and passed
	passed = _check("cost to buy max(100) ~= 87.54", _near(gen.cost_to_buy_max(100.0), 87.537, 0.01), true) and passed
	passed = _check("can afford next 10", gen.can_afford_next(10.0), true) and passed
	passed = _check("cannot afford next 9", gen.can_afford_next(9.0), false) and passed

	# Buying records the price and grows the count.
	gen.buy_max(100.0)
	passed = _check("buy max owned = 6", gen.owned, 6) and passed
	passed = _check("last bought = 6", gen.last_bought_count(), 6) and passed
	passed = _check("last cost ~= 87.54", _near(gen.last_cost(), 87.537, 0.01), true) and passed

	# Continuous production: 6 owned * 1 output * 1 multiplier = 6/sec.
	passed = _check("output/sec = 6", _near(gen.output_per_second(), 6.0, 0.001), true) and passed
	passed = _check("production over 0.5s = 3", _near(gen.production_over(0.5), 3.0, 0.001), true) and passed

	# Flat-price generator (growth 1.0) must not divide by zero.
	var flat: Node = load(IDLE_GENERATOR).new()
	flat.base_cost = 5.0
	flat.cost_growth = 1.0
	flat.owned = 0
	passed = _check("flat cost for 4 = 20", _near(flat.cost_for(4), 20.0, 0.001), true) and passed
	passed = _check("flat max affordable(20) = 4", flat.max_affordable(20.0), 4) and passed
	flat.free()

	# A sub-1 growth would make the cost series converge and hang Buy Max; it is clamped to flat instead.
	# (This test completing at all proves there is no infinite loop.)
	var discount: Node = load(IDLE_GENERATOR).new()
	discount.base_cost = 10.0
	discount.cost_growth = 0.5
	discount.owned = 0
	passed = _check("discount growth clamps to flat, max(100)=10", discount.max_affordable(100.0), 10) and passed
	discount.free()

	gen.free()
	return passed


static func _test_prestige() -> bool:
	var passed: bool = true
	var pr: Node = load(PRESTIGE).new()
	pr.configure(1000000.0, 0.5, 0.02)
	pr.track_earned(1000000000.0)
	# floor(sqrt(1e9 / 1e6)) = floor(sqrt(1000)) = 31.
	passed = _check("prestige gain = 31", pr.prestige_gain(), 31) and passed
	passed = _check("can prestige", pr.can_prestige(), true) and passed
	passed = _check("multiplier before = 1", _near(pr.prestige_multiplier(), 1.0, 0.001), true) and passed

	pr.do_prestige()
	passed = _check("points = 31 after", _near(pr.prestige_points(), 31.0, 0.001), true) and passed
	passed = _check("level = 1", pr.prestige_level(), 1) and passed
	passed = _check("multiplier = 1.62", _near(pr.prestige_multiplier(), 1.62, 0.001), true) and passed
	passed = _check("run reset to 0", _near(pr.run_earned(), 0.0, 0.001), true) and passed
	passed = _check("total earned persists", _near(pr.total_earned(), 1000000000.0, 1.0), true) and passed
	passed = _check("gain 0 after reset", pr.prestige_gain(), 0) and passed

	# No double-award: prestiging again with no new earnings banks nothing.
	pr.do_prestige()
	passed = _check("no double award", _near(pr.prestige_points(), 31.0, 0.001), true) and passed
	passed = _check("level still 1", pr.prestige_level(), 1) and passed

	# A finite gain above int64 range must saturate positive, not wrap negative (default 0.5 reaches this
	# near 1e46 run earnings) - otherwise can_prestige would go false and the game could never prestige.
	var big_pr: Node = load(PRESTIGE).new()
	big_pr.configure(1000000.0, 0.5, 0.02)
	big_pr.track_earned(1e46)
	passed = _check("huge gain saturates positive", big_pr.prestige_gain() > 0, true) and passed
	passed = _check("can still prestige at huge scale", big_pr.can_prestige(), true) and passed
	big_pr.free()

	pr.free()
	return passed


static func _test_upgrades() -> bool:
	var passed: bool = true
	var up: Node = load(UPGRADES).new()
	up.define_upgrade("dmg", 10.0, 1.5, 3, 2.0, "mult", "combat")
	passed = _check("cost of dmg = 10", _near(up.cost_of("dmg"), 10.0, 0.001), true) and passed

	up.try_purchase("dmg", 5.0)
	passed = _check("fail on low budget", up.purchase_succeeded(), false) and passed
	passed = _check("level still 0", up.level_of("dmg"), 0) and passed

	up.try_purchase("dmg", 100.0)
	passed = _check("bought on budget", up.purchase_succeeded(), true) and passed
	passed = _check("level = 1", up.level_of("dmg"), 1) and passed
	passed = _check("last cost = 10", _near(up.last_cost(), 10.0, 0.001), true) and passed
	# mult mode: effect = per_level^level = 2^1 = 2.
	passed = _check("effect = 2", _near(up.effect_of("dmg"), 2.0, 0.001), true) and passed
	passed = _check("total mult combat = 2", _near(up.total_multiplier("combat"), 2.0, 0.001), true) and passed

	# Buy to max, then it caps.
	up.try_purchase("dmg", 100.0)
	up.try_purchase("dmg", 100.0)
	passed = _check("maxed at 3", up.is_maxed("dmg"), true) and passed
	passed = _check("cost -1 when maxed", _near(up.cost_of("dmg"), -1.0, 0.001), true) and passed

	# Add mode aggregates as a sum.
	up.define_upgrade("hp", 5.0, 1.0, -1, 10.0, "add", "def")
	up.grant_level("hp")
	up.grant_level("hp")
	passed = _check("add effect = 20", _near(up.effect_of("hp"), 20.0, 0.001), true) and passed
	passed = _check("total bonus def = 20", _near(up.total_bonus("def"), 20.0, 0.001), true) and passed

	up.free()
	return passed


static func _test_milestones() -> bool:
	var passed: bool = true
	var ms: Node = load(MILESTONES).new()
	ms.define_milestone("m1", 1000.0, 0.05)
	passed = _check("not reached at start", ms.is_reached("m1"), false) and passed
	ms.update_progress("m1", 500.0)
	passed = _check("progress 0.5", _near(ms.progress("m1"), 0.5, 0.001), true) and passed
	passed = _check("still not reached", ms.is_reached("m1"), false) and passed
	ms.update_progress("m1", 1000.0)
	passed = _check("reached at threshold", ms.is_reached("m1"), true) and passed
	passed = _check("reached count 1", ms.reached_count(), 1) and passed
	passed = _check("total reward = 0.05", _near(ms.total_reward(), 0.05, 0.0001), true) and passed
	passed = _check("last reached m1", ms.last_reached(), "m1") and passed

	ms.define_milestone("m2", 5000.0, 0.10)
	ms.update_progress("m2", 2500.0)
	passed = _check("total reward still 0.05", _near(ms.total_reward(), 0.05, 0.0001), true) and passed
	passed = _check("nearest unreached m2", ms.nearest_unreached(), "m2") and passed

	# A reached milestone is permanent - progress stays full even if the tracked value later drops.
	ms.update_progress("m1", 10.0)
	passed = _check("reached milestone stays at full progress", _near(ms.progress("m1"), 1.0, 0.001), true) and passed
	passed = _check("still reached after value drop", ms.is_reached("m1"), true) and passed

	ms.free()
	return passed


static func _test_click_power() -> bool:
	var passed: bool = true
	var cp: Node = load(CLICK_POWER).new()
	cp.configure(1.0)
	cp.set_multiplier(2.0)
	passed = _check("yield (1)*2 = 2", _near(cp.click_yield(0.0), 2.0, 0.001), true) and passed
	cp.set_flat_bonus(3.0)
	passed = _check("yield (1+3)*2 = 8", _near(cp.click_yield(0.0), 8.0, 0.001), true) and passed
	cp.set_cps_fraction(0.1)
	passed = _check("yield with cps = 28", _near(cp.click_yield(100.0), 28.0, 0.001), true) and passed

	# No crit chance -> deterministic click equal to the previewed yield.
	cp.do_click(0.0)
	passed = _check("no crit", cp.was_crit(), false) and passed
	passed = _check("last click = yield", _near(cp.last_click(), 8.0, 0.001), true) and passed
	passed = _check("total clicks = 1", cp.total_clicks(), 1) and passed

	cp.free()
	return passed


static func _test_boosts() -> bool:
	var passed: bool = true
	var bo: Node = load(BOOSTS).new()
	bo.start_boost("frenzy", 7.0, 77.0)
	passed = _check("frenzy active", bo.is_active("frenzy"), true) and passed
	passed = _check("total mult = 7", _near(bo.total_multiplier(), 7.0, 0.001), true) and passed
	passed = _check("time left = 77", _near(bo.time_left("frenzy"), 77.0, 0.001), true) and passed

	bo.start_tagged_boost("prod", 2.0, 10.0, "production")
	passed = _check("total mult = 14", _near(bo.total_multiplier(), 14.0, 0.001), true) and passed
	passed = _check("tag mult = 2", _near(bo.multiplier_for_tag("production"), 2.0, 0.001), true) and passed
	passed = _check("active count = 2", bo.active_count(), 2) and passed

	bo.stop_boost("frenzy")
	passed = _check("frenzy stopped", bo.is_active("frenzy"), false) and passed
	passed = _check("total mult = 2 after stop", _near(bo.total_multiplier(), 2.0, 0.001), true) and passed
	bo.clear_boosts()
	passed = _check("none active", bo.any_active(), false) and passed

	bo.free()
	return passed


static func _near(actual: float, expected: float, tolerance: float) -> bool:
	return absf(actual - expected) <= tolerance


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] incremental_packs_test: %s" % label)
		return true
	print("[FAIL] incremental_packs_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
