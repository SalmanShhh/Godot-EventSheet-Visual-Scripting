# Pack builder - currency_ledger (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Currency Ledger: a data-driven economy as an AUTOLOAD sheet. Register named currencies
## (gold, gems, energy, xp...) by string id, then earn and spend from ANY sheet. Ported from
## the Construct 3 addon, but Godot-native + beginner-friendly:
##  - ONE clean money model (the C3 debt/non-negative contradiction is gone): every currency has
##    a min (default 0) and max (-1 = no cap); Add takes a SIGNED amount and clamps to [min, max];
##    Spend fails if you can't afford it; Allow Debt sets a negative min for hunger/heat/etc.
##  - Discrete typed ACEs instead of the JSON-blob registration the C3 version used.
##  - Apply Offline Gain CREDITS the gain in one call (C3's two-step calculate-then-add footgun is gone).
##  - Parameterless trigger signals + "changed / spend-failed / offline" getter expressions read INSIDE
##    the matching On-event handler - the same shape the plugin's own packs use.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "CurrencyLedger"
	sheet.host_class = "Node"
	sheet.custom_class_name = "CurrencyLedgerAddon"
	sheet.class_description = "A data-driven economy: register named currencies (gold, gems, energy, reputation), then earn and spend them with single rows. It holds the numbers, enforces caps and floors, and fires a trigger on every meaningful change so your HUD and unlocks react instead of polling."
	sheet.addon_category = "Currency"
	sheet.addon_tags = PackedStringArray(["economy", "currency"])
	var about: CommentRow = CommentRow.new()
	about.text = "Currency Ledger: register as the CurrencyLedger autoload, then earn and spend named currencies from any sheet. Add takes a signed amount and clamps to each currency's min (0 by default) and max (none by default); Spend fails when you can't afford it. React with On Amount Changed / On Spend Failed. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Amount Changed\")",
		"## @ace_category(\"Currency\")",
		"signal on_amount_changed()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Spend Failed\")",
		"## @ace_category(\"Currency\")",
		"signal on_spend_failed()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Cap Hit\")",
		"## @ace_category(\"Currency\")",
		"signal on_cap_hit()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Daily Cap Hit\")",
		"## @ace_category(\"Currency\")",
		"signal on_daily_cap_hit()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Offline Gain\")",
		"## @ace_category(\"Currency\")",
		"signal on_offline_gain()",
		"",
		"# Live economy: id -> {amount, min, max (-1=none), daily_cap (-1=none), daily_earned, offline_rate}.",
		"var _wallet: Dictionary = {}",
		"# Last-event context, read via the getter expressions INSIDE the matching On-event handler.",
		"var _evt_id: String = \"\"",
		"var _evt_new: float = 0.0",
		"var _evt_prev: float = 0.0",
		"var _evt_delta: float = 0.0",
		"var _fail_id: String = \"\"",
		"var _fail_requested: float = 0.0",
		"var _fail_current: float = 0.0",
		"var _offline_id: String = \"\"",
		"var _offline_gain: float = 0.0",
		"",
		"# Returns the stored record, creating a default one (min 0, no cap) on first touch so",
		"# add(\"gold\", 5) just works even without an explicit Define Currency.",
		"func _ensure(id: String) -> Dictionary:",
		"\tif not _wallet.has(id):",
		"\t\t_wallet[id] = {\"amount\": 0.0, \"min\": 0.0, \"max\": -1.0, \"daily_cap\": -1.0, \"daily_earned\": 0.0, \"offline_rate\": 0.0}",
		"\treturn _wallet[id]",
		"",
		"# Records the change context and fires On Amount Changed.",
		"func _changed(id: String, previous: float, current: float) -> void:",
		"\t_evt_id = id",
		"\t_evt_prev = previous",
		"\t_evt_new = current",
		"\t_evt_delta = current - previous",
		"\ton_amount_changed.emit()"
	]))
	sheet.events.append(block)

	# --- Setup ---
	Lib.append_function(sheet, "define_currency", "Define Currency", "Currency", "Creates (or resets) a currency with a starting amount and a max (-1 = no cap). Min is 0 and there's no daily cap until you set one.",
		[["id", "String"], ["starting_amount", "float"], ["max_amount", "float"]],
		"var start: float = starting_amount\nif max_amount >= 0.0:\n\tstart = minf(start, max_amount)\n_wallet[id] = {\"amount\": start, \"min\": 0.0, \"max\": max_amount, \"daily_cap\": -1.0, \"daily_earned\": 0.0, \"offline_rate\": 0.0}")
	Lib.append_function(sheet, "set_max", "Set Max", "Currency", "Changes the hard cap (-1 = no cap). If the current amount is above the new cap it clamps down.",
		[["id", "String"], ["max_amount", "float"]],
		"var r: Dictionary = _ensure(id)\nr.max = max_amount\nif max_amount >= 0.0 and r.amount > max_amount:\n\tvar prev: float = r.amount\n\tr.amount = max_amount\n\t_changed(id, prev, r.amount)")
	Lib.append_function(sheet, "set_daily_cap", "Set Daily Cap", "Currency", "Caps how much can be EARNED (added) per day (-1 = no daily cap). You decide when a day rolls over by calling Reset Daily Caps.",
		[["id", "String"], ["daily_cap", "float"]],
		"_ensure(id).daily_cap = daily_cap")
	Lib.append_function(sheet, "allow_debt", "Allow Debt", "Currency", "Lets a currency go negative down to this floor (e.g. -50). Use it for hunger, heat, or overdraft. Default floor is 0 (no debt).",
		[["id", "String"], ["minimum", "float"]],
		"_ensure(id).min = minimum")
	Lib.append_function(sheet, "set_offline_rate", "Set Offline Rate", "Currency", "Passive income per real second, used by Apply Offline Gain (0 = off).",
		[["id", "String"], ["rate_per_second", "float"]],
		"_ensure(id).offline_rate = rate_per_second")

	# --- Transactions ---
	Lib.append_function(sheet, "add", "Add", "Currency", "Adds a SIGNED amount (negative subtracts) and clamps to the currency's min and max. Positive amounts also respect the daily cap. Fires On Amount Changed, plus On Cap Hit / On Daily Cap Hit if a limit bit.",
		[["id", "String"], ["amount", "float"]],
		"\n".join(PackedStringArray([
			"var r: Dictionary = _ensure(id)",
			"var prev: float = r.amount",
			"if amount <= 0.0:",
			"\tr.amount = maxf(r.amount + amount, r.min)",
			"\t_changed(id, prev, r.amount)",
			"\treturn",
			"var allowed: float = amount",
			"var daily_hit: bool = false",
			"if r.daily_cap >= 0.0:",
			"\tvar room: float = maxf(r.daily_cap - r.daily_earned, 0.0)",
			"\tif allowed > room:",
			"\t\tallowed = room",
			"\t\tdaily_hit = true",
			"var cap_hit: bool = false",
			"var target: float = r.amount + allowed",
			"if r.max >= 0.0 and target > r.max:",
			"\ttarget = r.max",
			"\tcap_hit = true",
			"r.amount = target",
			"r.daily_earned += maxf(r.amount - prev, 0.0)",
			"_changed(id, prev, r.amount)",
			"if daily_hit:",
			"\t_evt_id = id",
			"\ton_daily_cap_hit.emit()",
			"if cap_hit:",
			"\t_evt_id = id",
			"\ton_cap_hit.emit()"
		])))
	Lib.append_function(sheet, "spend", "Spend", "Currency", "Subtracts the amount only if it can be afforded; otherwise nothing changes and On Spend Failed fires (read Failed Id / Requested Amount / Available Amount there).",
		[["id", "String"], ["amount", "float"]],
		"\n".join(PackedStringArray([
			"var current: float = _wallet[id].amount if _wallet.has(id) else 0.0",
			"if current < amount:",
			"\t_fail_id = id",
			"\t_fail_requested = amount",
			"\t_fail_current = current",
			"\ton_spend_failed.emit()",
			"\treturn",
			"var r: Dictionary = _wallet[id]",
			"var prev: float = r.amount",
			"r.amount = maxf(r.amount - amount, r.min)",
			"_changed(id, prev, r.amount)"
		])))
	Lib.append_function(sheet, "set_amount", "Set Amount", "Currency", "Forces the amount to a value, clamped to the currency's min and max. Fires On Amount Changed.",
		[["id", "String"], ["amount", "float"]],
		"var r: Dictionary = _ensure(id)\nvar prev: float = r.amount\nvar target: float = maxf(amount, r.min)\nif r.max >= 0.0:\n\ttarget = minf(target, r.max)\nr.amount = target\n_changed(id, prev, r.amount)")
	Lib.append_function(sheet, "reset_daily_caps", "Reset Daily Caps", "Currency", "Zeroes the earned-today counter for every currency (call this at your day rollover).",
		[],
		"for id: String in _wallet:\n\t_wallet[id].daily_earned = 0.0")
	Lib.append_function(sheet, "apply_offline_gain", "Apply Offline Gain", "Currency", "Credits offline_rate * seconds to the currency (respecting caps) and fires On Offline Gain. One call - no separate Add needed.",
		[["id", "String"], ["elapsed_seconds", "float"]],
		"var r: Dictionary = _ensure(id)\nvar gain: float = r.offline_rate * maxf(elapsed_seconds, 0.0)\nif gain <= 0.0:\n\treturn\nadd(id, gain)\n_offline_id = id\n_offline_gain = gain\non_offline_gain.emit()")

	# --- Conditions ---
	_condition(sheet, "has_currency", "Has Currency", "Currency", "Whether a currency with this id has been defined or touched.", [["id", "String"]],
		"return _wallet.has(id)")
	_condition(sheet, "can_afford", "Can Afford", "Currency", "Whether the current balance is at least the amount.", [["id", "String"], ["amount", "float"]],
		"return balance(id) >= amount")
	_condition(sheet, "is_at_cap", "Is At Cap", "Currency", "Whether the balance is at its max (false when there's no cap).", [["id", "String"]],
		"var r: Dictionary = _wallet.get(id, {})\nreturn r.get(\"max\", -1.0) >= 0.0 and r.get(\"amount\", 0.0) >= r.get(\"max\", -1.0)")
	_condition(sheet, "is_daily_cap_reached", "Is Daily Cap Reached", "Currency", "Whether today's earnings have hit the daily cap (false when there's none).", [["id", "String"]],
		"var r: Dictionary = _wallet.get(id, {})\nreturn r.get(\"daily_cap\", -1.0) >= 0.0 and r.get(\"daily_earned\", 0.0) >= r.get(\"daily_cap\", -1.0)")
	_condition(sheet, "is_in_debt", "Is In Debt", "Currency", "Whether the balance is below zero (only possible after Allow Debt).", [["id", "String"]],
		"return balance(id) < 0.0")

	# --- Expressions: balances + config ---
	_number(sheet, "balance", "Balance", "Currency", "The current amount of a currency (0 if undefined).", [["id", "String"]],
		"return _wallet[id].amount if _wallet.has(id) else 0.0", TYPE_FLOAT)
	_number(sheet, "cap", "Cap", "Currency", "The hard cap of a currency (-1 if none).", [["id", "String"]],
		"return _wallet[id].max if _wallet.has(id) else -1.0", TYPE_FLOAT)
	_number(sheet, "daily_cap", "Daily Cap", "Currency", "The daily earn cap (-1 if none).", [["id", "String"]],
		"return _wallet[id].daily_cap if _wallet.has(id) else -1.0", TYPE_FLOAT)
	_number(sheet, "daily_earned", "Daily Earned", "Currency", "How much has been earned today.", [["id", "String"]],
		"return _wallet[id].daily_earned if _wallet.has(id) else 0.0", TYPE_FLOAT)
	_number(sheet, "debt_floor", "Debt Floor", "Currency", "The minimum a currency may reach (0 unless Allow Debt was used).", [["id", "String"]],
		"return _wallet[id].min if _wallet.has(id) else 0.0", TYPE_FLOAT)
	_number(sheet, "currency_count", "Currency Count", "Currency", "How many currencies are defined.", [],
		"return _wallet.size()", TYPE_INT)
	_number(sheet, "currency_id_at", "Currency Id At", "Currency", "The currency id at a position (for menus); \"\" out of range.", [["index", "int"]],
		"var ids: Array = _wallet.keys()\nreturn str(ids[index]) if index >= 0 and index < ids.size() else \"\"", TYPE_STRING)
	_number(sheet, "format_amount", "Format Amount", "Currency", "A short display string with a K/M/B/T suffix (e.g. 12500 -> \"12.5K\").", [["value", "float"], ["decimals", "int"]],
		"\n".join(PackedStringArray([
			"var mag: float = absf(value)",
			"var scaled: float = value",
			"var suffix: String = \"\"",
			"if mag >= 1000000000000.0:",
			"\tscaled = value / 1000000000000.0",
			"\tsuffix = \"T\"",
			"elif mag >= 1000000000.0:",
			"\tscaled = value / 1000000000.0",
			"\tsuffix = \"B\"",
			"elif mag >= 1000000.0:",
			"\tscaled = value / 1000000.0",
			"\tsuffix = \"M\"",
			"elif mag >= 1000.0:",
			"\tscaled = value / 1000.0",
			"\tsuffix = \"K\"",
			"return String.num(scaled, maxi(decimals, 0)) + suffix if not suffix.is_empty() else String.num(value, maxi(decimals, 0))"
		])), TYPE_STRING)

	# --- Expressions: On Amount Changed context ---
	_number(sheet, "changed_id", "Changed Id", "Currency", "The currency that changed (inside On Amount Changed).", [],
		"return _evt_id", TYPE_STRING)
	_number(sheet, "new_amount", "New Amount", "Currency", "The amount after the change (inside On Amount Changed).", [],
		"return _evt_new", TYPE_FLOAT)
	_number(sheet, "previous_amount", "Previous Amount", "Currency", "The amount before the change (inside On Amount Changed).", [],
		"return _evt_prev", TYPE_FLOAT)
	_number(sheet, "amount_delta", "Amount Delta", "Currency", "The signed change (inside On Amount Changed).", [],
		"return _evt_delta", TYPE_FLOAT)
	# --- Expressions: On Spend Failed context ---
	_number(sheet, "failed_id", "Failed Id", "Currency", "The currency of the failed spend (inside On Spend Failed).", [],
		"return _fail_id", TYPE_STRING)
	_number(sheet, "requested_amount", "Requested Amount", "Currency", "The amount that was asked for (inside On Spend Failed).", [],
		"return _fail_requested", TYPE_FLOAT)
	_number(sheet, "available_amount", "Available Amount", "Currency", "What was actually available (inside On Spend Failed).", [],
		"return _fail_current", TYPE_FLOAT)
	# --- Expressions: On Offline Gain context ---
	_number(sheet, "offline_id", "Offline Id", "Currency", "The currency credited (inside On Offline Gain).", [],
		"return _offline_id", TYPE_STRING)
	_number(sheet, "offline_gain", "Offline Gain", "Currency", "The amount credited offline (inside On Offline Gain).", [],
		"return _offline_gain", TYPE_FLOAT)

	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"wallet\": _wallet.duplicate(true)",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_wallet = (state.get(\"wallet\", {}) as Dictionary).duplicate(true)"
	]))
	sheet.events.append(persistence)

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.feature_verbs(sheet, ["define_currency", "add", "spend"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/currency_ledger/currency_ledger_addon")


## Appends a bool-returning exposed function (a Condition).
static func _condition(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = TYPE_BOOL
	sheet.functions.append(fn)


## Appends a value-returning exposed function (an Expression) with the given return type.
static func _number(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String, ret: int) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = ret
	sheet.functions.append(fn)
