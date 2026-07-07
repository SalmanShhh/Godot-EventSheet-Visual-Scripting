# Godot EventSheets - currency_ledger pack (economy autoload) smoke + rules.
#
# Loads the COMPILED pack and drives the wallet directly (it is pure Dictionary math + signals,
# no live tree needed). Proves the unified min/max money model: Add is signed and clamps, Spend
# fails atomically, caps + daily caps fire their signals, Allow Debt permits negatives, and Apply
# Offline Gain credits in one call.
@tool
class_name CurrencyLedgerTest
extends RefCounted

const PACK := "res://eventsheet_addons/currency_ledger/currency_ledger_addon.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("currency_ledger pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var ledger: Node = script.new()
	var changed: Array = [0]
	var spend_failed: Array = [0]
	var cap_hits: Array = [0]
	var daily_hits: Array = [0]
	var offline: Array = [0]
	ledger.on_amount_changed.connect(func() -> void: changed[0] += 1)
	ledger.on_spend_failed.connect(func() -> void: spend_failed[0] += 1)
	ledger.on_cap_hit.connect(func() -> void: cap_hits[0] += 1)
	ledger.on_daily_cap_hit.connect(func() -> void: daily_hits[0] += 1)
	ledger.on_offline_gain.connect(func() -> void: offline[0] += 1)

	# Define + earn + spend.
	ledger.define_currency("gold", 100.0, -1.0)
	all_passed = _check("define sets the starting balance", is_equal_approx(ledger.balance("gold"), 100.0), true) and all_passed
	ledger.add("gold", 50.0)
	all_passed = _check("add earns", is_equal_approx(ledger.balance("gold"), 150.0), true) and all_passed
	all_passed = _check("add fires On Amount Changed with the delta", changed[0] == 1 and is_equal_approx(ledger.amount_delta(), 50.0), true) and all_passed
	all_passed = _check("can afford what you have", ledger.can_afford("gold", 150.0) and not ledger.can_afford("gold", 151.0), true) and all_passed
	ledger.spend("gold", 60.0)
	all_passed = _check("spend deducts", is_equal_approx(ledger.balance("gold"), 90.0), true) and all_passed
	ledger.spend("gold", 999.0)
	all_passed = _check("an unaffordable spend fails, changes nothing, fires On Spend Failed",
		spend_failed[0] == 1 and is_equal_approx(ledger.balance("gold"), 90.0)
		and ledger.failed_id() == "gold" and is_equal_approx(ledger.requested_amount(), 999.0)
		and is_equal_approx(ledger.available_amount(), 90.0), true) and all_passed

	# add auto-creates a currency at 0; negative add subtracts.
	ledger.add("wood", 10.0)
	ledger.add("wood", -3.0)
	all_passed = _check("add auto-defines and a negative add subtracts", is_equal_approx(ledger.balance("wood"), 7.0), true) and all_passed
	ledger.add("wood", -999.0)
	all_passed = _check("a negative add never dips below the default floor of 0", is_equal_approx(ledger.balance("wood"), 0.0), true) and all_passed

	# Hard cap clamps + fires On Cap Hit.
	ledger.define_currency("gems", 90.0, 100.0)
	ledger.add("gems", 50.0)
	all_passed = _check("a hard cap clamps the balance and fires On Cap Hit",
		is_equal_approx(ledger.balance("gems"), 100.0) and cap_hits[0] == 1 and ledger.is_at_cap("gems"), true) and all_passed

	# Daily earn cap.
	ledger.define_currency("energy", 0.0, -1.0)
	ledger.set_daily_cap("energy", 30.0)
	ledger.add("energy", 20.0)
	ledger.add("energy", 20.0)  # only 10 of this 20 is allowed today
	all_passed = _check("the daily cap limits earnings and fires On Daily Cap Hit",
		is_equal_approx(ledger.balance("energy"), 30.0) and daily_hits[0] == 1 and ledger.is_daily_cap_reached("energy"), true) and all_passed
	ledger.reset_daily_caps()
	ledger.add("energy", 20.0)
	all_passed = _check("resetting daily caps lets earning resume", is_equal_approx(ledger.balance("energy"), 50.0), true) and all_passed

	# Allow Debt lets a currency go negative.
	ledger.define_currency("hunger", 10.0, -1.0)
	ledger.allow_debt("hunger", -20.0)
	ledger.add("hunger", -25.0)
	all_passed = _check("Allow Debt permits a negative balance down to the floor",
		is_equal_approx(ledger.balance("hunger"), -15.0) and ledger.is_in_debt("hunger"), true) and all_passed

	# Apply Offline Gain credits in ONE call.
	ledger.define_currency("ore", 0.0, -1.0)
	ledger.set_offline_rate("ore", 2.0)
	ledger.apply_offline_gain("ore", 5.0)
	all_passed = _check("Apply Offline Gain credits rate*seconds and fires On Offline Gain",
		is_equal_approx(ledger.balance("ore"), 10.0) and offline[0] == 1
		and ledger.offline_id() == "ore" and is_equal_approx(ledger.offline_gain(), 10.0), true) and all_passed

	# Formatting + counting.
	all_passed = _check("Format Amount abbreviates with a suffix", ledger.format_amount(12500.0, 1), "12.5K") and all_passed
	all_passed = _check("Format Amount leaves small values plain", ledger.format_amount(42.0, 0), "42") and all_passed
	all_passed = _check("Currency Count + Currency Id At enumerate the wallet",
		ledger.currency_count() == 6 and ledger.has_currency("gold") and not ledger.has_currency("nope"), true) and all_passed

	ledger.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] currency_ledger_test: %s" % label)
		return true
	print("[FAIL] currency_ledger_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
