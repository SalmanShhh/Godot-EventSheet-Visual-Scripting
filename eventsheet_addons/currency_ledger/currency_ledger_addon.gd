## @ace_tags(economy, currency)
## @ace_category("Currency")
@icon("res://eventsheet_addons/currency_ledger/icon.svg")
class_name CurrencyLedgerAddon
extends Node

## @ace_trigger
## @ace_name("On Amount Changed")
## @ace_category("Currency")
signal on_amount_changed
## @ace_trigger
## @ace_name("On Spend Failed")
## @ace_category("Currency")
signal on_spend_failed
## @ace_trigger
## @ace_name("On Cap Hit")
## @ace_category("Currency")
signal on_cap_hit
## @ace_trigger
## @ace_name("On Daily Cap Hit")
## @ace_category("Currency")
signal on_daily_cap_hit
## @ace_trigger
## @ace_name("On Offline Gain")
## @ace_category("Currency")
signal on_offline_gain

# Live economy: id -> {amount, min, max (-1=none), daily_cap (-1=none), daily_earned, offline_rate}.
var _wallet: Dictionary = {}
# Last-event context, read via the getter expressions INSIDE the matching On-event handler.
var _evt_id: String = ""
var _evt_new: float = 0.0
var _evt_prev: float = 0.0
var _evt_delta: float = 0.0
var _fail_id: String = ""
var _fail_requested: float = 0.0
var _fail_current: float = 0.0
var _offline_id: String = ""
var _offline_gain: float = 0.0

## @ace_action
## @ace_name("Define Currency")
## @ace_category("Currency")
## @ace_description("Creates (or resets) a currency with a starting amount and a max (-1 = no cap). Min is 0 and there's no daily cap until you set one.")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.define_currency({id}, {starting_amount}, {max_amount})")
func define_currency(id: String, starting_amount: float, max_amount: float) -> void:
	var start: float = starting_amount
	if max_amount >= 0.0:
		start = minf(start, max_amount)
	_wallet[id] = {"amount": start, "min": 0.0, "max": max_amount, "daily_cap": -1.0, "daily_earned": 0.0, "offline_rate": 0.0}

## @ace_action
## @ace_name("Set Max")
## @ace_category("Currency")
## @ace_description("Changes the hard cap (-1 = no cap). If the current amount is above the new cap it clamps down.")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.set_max({id}, {max_amount})")
func set_max(id: String, max_amount: float) -> void:
	var r: Dictionary = _ensure(id)
	r.max = max_amount
	if max_amount >= 0.0 and r.amount > max_amount:
		var prev: float = r.amount
		r.amount = max_amount
		_changed(id, prev, r.amount)

## @ace_action
## @ace_name("Set Daily Cap")
## @ace_category("Currency")
## @ace_description("Caps how much can be EARNED (added) per day (-1 = no daily cap). You decide when a day rolls over by calling Reset Daily Caps.")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.set_daily_cap({id}, {daily_cap})")
func set_daily_cap(id: String, daily_cap: float) -> void:
	_ensure(id).daily_cap = daily_cap

## @ace_action
## @ace_name("Allow Debt")
## @ace_category("Currency")
## @ace_description("Lets a currency go negative down to this floor (e.g. -50). Use it for hunger, heat, or overdraft. Default floor is 0 (no debt).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.allow_debt({id}, {minimum})")
func allow_debt(id: String, minimum: float) -> void:
	_ensure(id).min = minimum

## @ace_action
## @ace_name("Set Offline Rate")
## @ace_category("Currency")
## @ace_description("Passive income per real second, used by Apply Offline Gain (0 = off).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.set_offline_rate({id}, {rate_per_second})")
func set_offline_rate(id: String, rate_per_second: float) -> void:
	_ensure(id).offline_rate = rate_per_second

## @ace_action
## @ace_name("Add")
## @ace_category("Currency")
## @ace_description("Adds a SIGNED amount (negative subtracts) and clamps to the currency's min and max. Positive amounts also respect the daily cap. Fires On Amount Changed, plus On Cap Hit / On Daily Cap Hit if a limit bit.")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.add({id}, {amount})")
func add(id: String, amount: float) -> void:
	var r: Dictionary = _ensure(id)
	var prev: float = r.amount
	if amount <= 0.0:
		r.amount = maxf(r.amount + amount, r.min)
		_changed(id, prev, r.amount)
		return
	var allowed: float = amount
	var daily_hit: bool = false
	if r.daily_cap >= 0.0:
		var room: float = maxf(r.daily_cap - r.daily_earned, 0.0)
		if allowed > room:
			allowed = room
			daily_hit = true
	var cap_hit: bool = false
	var target: float = r.amount + allowed
	if r.max >= 0.0 and target > r.max:
		target = r.max
		cap_hit = true
	r.amount = target
	r.daily_earned += maxf(r.amount - prev, 0.0)
	_changed(id, prev, r.amount)
	if daily_hit:
		_evt_id = id
		on_daily_cap_hit.emit()
	if cap_hit:
		_evt_id = id
		on_cap_hit.emit()

## @ace_action
## @ace_name("Spend")
## @ace_category("Currency")
## @ace_description("Subtracts the amount only if it can be afforded; otherwise nothing changes and On Spend Failed fires (read Failed Id / Requested Amount / Available Amount there).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.spend({id}, {amount})")
func spend(id: String, amount: float) -> void:
	var current: float = _wallet[id].amount if _wallet.has(id) else 0.0
	if current < amount:
		_fail_id = id
		_fail_requested = amount
		_fail_current = current
		on_spend_failed.emit()
		return
	var r: Dictionary = _wallet[id]
	var prev: float = r.amount
	r.amount = maxf(r.amount - amount, r.min)
	_changed(id, prev, r.amount)

## @ace_action
## @ace_name("Set Amount")
## @ace_category("Currency")
## @ace_description("Forces the amount to a value, clamped to the currency's min and max. Fires On Amount Changed.")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.set_amount({id}, {amount})")
func set_amount(id: String, amount: float) -> void:
	var r: Dictionary = _ensure(id)
	var prev: float = r.amount
	var target: float = maxf(amount, r.min)
	if r.max >= 0.0:
		target = minf(target, r.max)
	r.amount = target
	_changed(id, prev, r.amount)

## @ace_action
## @ace_name("Reset Daily Caps")
## @ace_category("Currency")
## @ace_description("Zeroes the earned-today counter for every currency (call this at your day rollover).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.reset_daily_caps()")
func reset_daily_caps() -> void:
	for id: String in _wallet:
		_wallet[id].daily_earned = 0.0

## @ace_action
## @ace_name("Apply Offline Gain")
## @ace_category("Currency")
## @ace_description("Credits offline_rate * seconds to the currency (respecting caps) and fires On Offline Gain. One call - no separate Add needed.")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.apply_offline_gain({id}, {elapsed_seconds})")
func apply_offline_gain(id: String, elapsed_seconds: float) -> void:
	var r: Dictionary = _ensure(id)
	var gain: float = r.offline_rate * maxf(elapsed_seconds, 0.0)
	if gain <= 0.0:
		return
	add(id, gain)
	_offline_id = id
	_offline_gain = gain
	on_offline_gain.emit()

## @ace_condition
## @ace_name("Has Currency")
## @ace_category("Currency")
## @ace_description("Whether a currency with this id has been defined or touched.")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.has_currency({id})")
func has_currency(id: String) -> bool:
	return _wallet.has(id)

## @ace_condition
## @ace_name("Can Afford")
## @ace_category("Currency")
## @ace_description("Whether the current balance is at least the amount.")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.can_afford({id}, {amount})")
func can_afford(id: String, amount: float) -> bool:
	return balance(id) >= amount

## @ace_condition
## @ace_name("Is At Cap")
## @ace_category("Currency")
## @ace_description("Whether the balance is at its max (false when there's no cap).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.is_at_cap({id})")
func is_at_cap(id: String) -> bool:
	var r: Dictionary = _wallet.get(id, {})
	return r.get("max", -1.0) >= 0.0 and r.get("amount", 0.0) >= r.get("max", -1.0)

## @ace_condition
## @ace_name("Is Daily Cap Reached")
## @ace_category("Currency")
## @ace_description("Whether today's earnings have hit the daily cap (false when there's none).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.is_daily_cap_reached({id})")
func is_daily_cap_reached(id: String) -> bool:
	var r: Dictionary = _wallet.get(id, {})
	return r.get("daily_cap", -1.0) >= 0.0 and r.get("daily_earned", 0.0) >= r.get("daily_cap", -1.0)

## @ace_condition
## @ace_name("Is In Debt")
## @ace_category("Currency")
## @ace_description("Whether the balance is below zero (only possible after Allow Debt).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.is_in_debt({id})")
func is_in_debt(id: String) -> bool:
	return balance(id) < 0.0

## @ace_expression
## @ace_name("Balance")
## @ace_category("Currency")
## @ace_description("The current amount of a currency (0 if undefined).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.balance({id})")
func balance(id: String) -> float:
	return _wallet[id].amount if _wallet.has(id) else 0.0

## @ace_expression
## @ace_name("Cap")
## @ace_category("Currency")
## @ace_description("The hard cap of a currency (-1 if none).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.cap({id})")
func cap(id: String) -> float:
	return _wallet[id].max if _wallet.has(id) else -1.0

## @ace_expression
## @ace_name("Daily Cap")
## @ace_category("Currency")
## @ace_description("The daily earn cap (-1 if none).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.daily_cap({id})")
func daily_cap(id: String) -> float:
	return _wallet[id].daily_cap if _wallet.has(id) else -1.0

## @ace_expression
## @ace_name("Daily Earned")
## @ace_category("Currency")
## @ace_description("How much has been earned today.")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.daily_earned({id})")
func daily_earned(id: String) -> float:
	return _wallet[id].daily_earned if _wallet.has(id) else 0.0

## @ace_expression
## @ace_name("Debt Floor")
## @ace_category("Currency")
## @ace_description("The minimum a currency may reach (0 unless Allow Debt was used).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.debt_floor({id})")
func debt_floor(id: String) -> float:
	return _wallet[id].min if _wallet.has(id) else 0.0

## @ace_expression
## @ace_name("Currency Count")
## @ace_category("Currency")
## @ace_description("How many currencies are defined.")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.currency_count()")
func currency_count() -> int:
	return _wallet.size()

## @ace_expression
## @ace_name("Currency Id At")
## @ace_category("Currency")
## @ace_description("The currency id at a position (for menus); "" out of range.")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.currency_id_at({index})")
func currency_id_at(index: int) -> String:
	var ids: Array = _wallet.keys()
	return str(ids[index]) if index >= 0 and index < ids.size() else ""

## @ace_expression
## @ace_name("Format Amount")
## @ace_category("Currency")
## @ace_description("A short display string with a K/M/B/T suffix (e.g. 12500 -> "12.5K").")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.format_amount({value}, {decimals})")
func format_amount(value: float, decimals: int) -> String:
	var mag: float = absf(value)
	var scaled: float = value
	var suffix: String = ""
	if mag >= 1000000000000.0:
		scaled = value / 1000000000000.0
		suffix = "T"
	elif mag >= 1000000000.0:
		scaled = value / 1000000000.0
		suffix = "B"
	elif mag >= 1000000.0:
		scaled = value / 1000000.0
		suffix = "M"
	elif mag >= 1000.0:
		scaled = value / 1000.0
		suffix = "K"
	return String.num(scaled, maxi(decimals, 0)) + suffix if not suffix.is_empty() else String.num(value, maxi(decimals, 0))

## @ace_expression
## @ace_name("Changed Id")
## @ace_category("Currency")
## @ace_description("The currency that changed (inside On Amount Changed).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.changed_id()")
func changed_id() -> String:
	return _evt_id

## @ace_expression
## @ace_name("New Amount")
## @ace_category("Currency")
## @ace_description("The amount after the change (inside On Amount Changed).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.new_amount()")
func new_amount() -> float:
	return _evt_new

## @ace_expression
## @ace_name("Previous Amount")
## @ace_category("Currency")
## @ace_description("The amount before the change (inside On Amount Changed).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.previous_amount()")
func previous_amount() -> float:
	return _evt_prev

## @ace_expression
## @ace_name("Amount Delta")
## @ace_category("Currency")
## @ace_description("The signed change (inside On Amount Changed).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.amount_delta()")
func amount_delta() -> float:
	return _evt_delta

## @ace_expression
## @ace_name("Failed Id")
## @ace_category("Currency")
## @ace_description("The currency of the failed spend (inside On Spend Failed).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.failed_id()")
func failed_id() -> String:
	return _fail_id

## @ace_expression
## @ace_name("Requested Amount")
## @ace_category("Currency")
## @ace_description("The amount that was asked for (inside On Spend Failed).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.requested_amount()")
func requested_amount() -> float:
	return _fail_requested

## @ace_expression
## @ace_name("Available Amount")
## @ace_category("Currency")
## @ace_description("What was actually available (inside On Spend Failed).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.available_amount()")
func available_amount() -> float:
	return _fail_current

## @ace_expression
## @ace_name("Offline Id")
## @ace_category("Currency")
## @ace_description("The currency credited (inside On Offline Gain).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.offline_id()")
func offline_id() -> String:
	return _offline_id

## @ace_expression
## @ace_name("Offline Gain")
## @ace_category("Currency")
## @ace_description("The amount credited offline (inside On Offline Gain).")
## @ace_icon("res://eventsheet_addons/currency_ledger/icon.svg")
## @ace_codegen_template("CurrencyLedger.offline_gain()")
func offline_gain() -> float:
	return _offline_gain

func _ensure(id: String) -> Dictionary:
	# Returns the stored record, creating a default one (min 0, no cap) on first touch so
	# add("gold", 5) just works even without an explicit Define Currency.
	if not _wallet.has(id):
		_wallet[id] = {"amount": 0.0, "min": 0.0, "max": -1.0, "daily_cap": -1.0, "daily_earned": 0.0, "offline_rate": 0.0}
	return _wallet[id]

func _changed(id: String, previous: float, current: float) -> void:
	# Records the change context and fires On Amount Changed.
	_evt_id = id
	_evt_prev = previous
	_evt_new = current
	_evt_delta = current - previous
	on_amount_changed.emit()

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	return {
		"wallet": _wallet.duplicate(true)
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_wallet = (state.get("wallet", {}) as Dictionary).duplicate(true)

# Currency Ledger: register as the CurrencyLedger autoload, then earn and spend named currencies from any sheet. Add takes a signed amount and clamps to each currency's min (0 by default) and max (none by default); Spend fails when you can't afford it. React with On Amount Changed / On Spend Failed. This pack is an event sheet - extend it by editing it.
