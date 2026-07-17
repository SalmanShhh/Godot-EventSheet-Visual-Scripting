# Pack builder - click_power (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Click Power: the manual-tap income at the heart of a clicker, as an AUTOLOAD sheet. Do Click computes
## what one tap earns - (base + flat bonus + a fraction of current production) times a multiplier - rolls a
## crit, records the result as Last Click for you to credit, and fires On Click (and On Crit). Click Yield
## previews the same value without rolling, for the "per click" label. The wallet stays external: read Last
## Click and Add it to your currency. Configure the base, multiplier, crit chance/size, and how much of your
## per-second production each click also grants (the Cookie-Clicker "clicking is worth X% of CpS" rule).
## Plain Godot, zero plugin dependency.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "ClickPower"
	sheet.host_class = "Node"
	sheet.custom_class_name = "ClickPowerAddon"
	sheet.class_description = "The manual-tap income at the heart of a clicker: Do Click works out what a tap earns (base, flat bonus, a share of production, crits) and fires On Click and On Crit. It computes what a tap is worth - you read Last Click and add it to your own wallet."
	sheet.addon_category = "Click Power"
	sheet.addon_tags = PackedStringArray(["incremental", "idle", "clicker"])
	var about: CommentRow = CommentRow.new()
	about.text = "Click Power: register as the ClickPower autoload. Do Click(current_cps) works out one tap's yield - (base + flat bonus + cps fraction * current_cps) * multiplier, then a possible crit - records it as Last Click and fires On Click / On Crit; you Add Last Click to your wallet. Click Yield previews the no-crit value for a label. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Click\")",
		"## @ace_category(\"Click Power\")",
		"signal on_click",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Crit\")",
		"## @ace_category(\"Click Power\")",
		"signal on_crit",
		"",
		"# Tuning: yield = (base + flat_bonus + cps_fraction * current_cps) * multiplier, crit optional.",
		"var _base_click: float = 1.0",
		"var _multiplier: float = 1.0",
		"var _flat_bonus: float = 0.0",
		"var _cps_fraction: float = 0.0",
		"var _crit_chance: float = 0.0",
		"var _crit_multiplier: float = 10.0",
		"# Last-click context (read after Do Click / inside On Click).",
		"var _last_amount: float = 0.0",
		"var _last_crit: bool = false",
		"var _total_clicks: int = 0",
		"# Crit rolls; randomize() once so runs differ.",
		"var _rng: RandomNumberGenerator = RandomNumberGenerator.new()",
		"",
		"# The deterministic (no-crit) yield of one click at the given current production per second.",
		"func _yield(current_cps: float) -> float:",
		"\treturn (_base_click + _flat_bonus + _cps_fraction * current_cps) * _multiplier"
	]))
	sheet.events.append(block)

	# Seed the crit RNG once.
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var on_ready_body: RawCodeRow = RawCodeRow.new()
	on_ready_body.code = "_rng.randomize()"
	on_ready.actions.append(on_ready_body)
	sheet.events.append(on_ready)

	# --- Setup ---
	Lib.append_function(sheet, "configure", "Configure", "Click Power", "Sets the base value of one click.",
		[["base_click", "float"]],
		"_base_click = base_click")
	Lib.append_function(sheet, "set_multiplier", "Set Multiplier", "Click Power", "Sets the click multiplier - feed it your composed prestige x upgrade x boost value.",
		[["multiplier", "float"]],
		"_multiplier = multiplier")
	Lib.append_function(sheet, "set_flat_bonus", "Set Flat Bonus", "Click Power", "Adds a flat amount to every click before the multiplier (from an upgrade).",
		[["bonus", "float"]],
		"_flat_bonus = bonus")
	Lib.append_function(sheet, "set_cps_fraction", "Set CPS Fraction", "Click Power", "Makes each click also worth this fraction of current production per second (Cookie-Clicker's \"clicking is worth X% of CpS\"; 0 = off).",
		[["fraction", "float"]],
		"_cps_fraction = fraction")
	Lib.append_function(sheet, "set_crit", "Set Crit", "Click Power", "Sets the crit chance (0 to 1) and its multiplier (e.g. 10 for a lucky x10 click).",
		[["chance", "float"], ["multiplier", "float"]], "\n".join(PackedStringArray([
			"_crit_chance = clampf(chance, 0.0, 1.0)",
			"_crit_multiplier = multiplier"
		])))

	# --- The click ---
	Lib.append_function(sheet, "do_click", "Do Click", "Click Power", "Resolves one tap: computes the yield (pass your current total production per second, or 0), rolls a crit, records Last Click / Was Crit, and fires On Click (and On Crit). Then Add Last Click to your wallet.",
		[["current_cps", "float"]], "\n".join(PackedStringArray([
			"var amount: float = _yield(current_cps)",
			"_last_crit = _crit_chance > 0.0 and _rng.randf() < _crit_chance",
			"if _last_crit:",
			"\tamount *= _crit_multiplier",
			"_last_amount = amount",
			"_total_clicks += 1",
			"on_click.emit()",
			"if _last_crit:",
			"\ton_crit.emit()"
		])))

	# --- Conditions ---
	Lib.condition(sheet, "was_crit", "Was Crit", "Click Power", "Whether the last click critted (read after Do Click / inside On Click).",
		[],
		"return _last_crit")

	# --- Expressions ---
	Lib.number(sheet, "click_yield", "Click Yield", "Click Power", "What one click earns right now, without a crit (pass current production per second, or 0) - for a \"per click\" label.",
		[["current_cps", "float"]], "return _yield(current_cps)", TYPE_FLOAT)
	Lib.number(sheet, "last_click", "Last Click", "Click Power", "What the last Do Click earned (after any crit) - Add this to your wallet.",
		[], "return _last_amount", TYPE_FLOAT)
	Lib.number(sheet, "total_clicks", "Total Clicks", "Click Power", "How many clicks have been resolved.",
		[], "return _total_clicks", TYPE_INT)
	Lib.number(sheet, "click_multiplier", "Click Multiplier", "Click Power", "The current click multiplier.",
		[], "return _multiplier", TYPE_FLOAT)
	Lib.number(sheet, "crit_chance", "Crit Chance", "Click Power", "The current crit chance, 0 to 1.",
		[], "return _crit_chance", TYPE_FLOAT)

	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"base_click\": _base_click,",
		"\t\t\"multiplier\": _multiplier,",
		"\t\t\"flat_bonus\": _flat_bonus,",
		"\t\t\"cps_fraction\": _cps_fraction,",
		"\t\t\"crit_chance\": _crit_chance,",
		"\t\t\"crit_multiplier\": _crit_multiplier,",
		"\t\t\"total_clicks\": _total_clicks",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_base_click = float(state.get(\"base_click\", 1.0))",
		"\t_multiplier = float(state.get(\"multiplier\", 1.0))",
		"\t_flat_bonus = float(state.get(\"flat_bonus\", 0.0))",
		"\t_cps_fraction = float(state.get(\"cps_fraction\", 0.0))",
		"\t_crit_chance = float(state.get(\"crit_chance\", 0.0))",
		"\t_crit_multiplier = float(state.get(\"crit_multiplier\", 10.0))",
		"\t_total_clicks = int(state.get(\"total_clicks\", 0))"
	]))
	sheet.events.append(persistence)

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.feature_verbs(sheet, ["do_click", "last_click"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/click_power/click_power_addon")
