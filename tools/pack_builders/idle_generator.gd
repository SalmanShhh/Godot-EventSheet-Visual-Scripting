# Pack builder - idle_generator (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Idle Generator: a producer/building for incremental games - the thing you buy more of to make more
## stuff. Attach it to a node (one node per generator type: cursor, farm, factory). Every unit costs more
## than the last on a geometric curve (cost = base_cost * cost_growth^owned, the Cookie-Clicker 1.15
## default), so the buy math is a closed-form geometric series, not a loop: Next Cost, Cost For(n), Max
## Affordable(budget), and Cost To Buy Max are exact even at huge counts. It stays decoupled from the
## wallet - the Buy actions record what they cost (Last Cost) and it is your sheet that Spends from
## Currency Ledger. Two production models: continuous (Output Per Second, for Cookie-Clicker CpS) and an
## optional fill-and-collect cycle (set Cycle Time > 0, then Collect on On Cycle Complete, for AdVenture-
## Capitalist buildings and managers). Verified plain Godot, zero plugin dependency.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "IdleGeneratorBehavior"
	sheet.class_description = "A buy-more-to-make-more producer for incremental games - the cursor, farm, or factory you buy in bulk. Costs grow on a geometric curve with exact closed-form bulk buying (Buy One / Buy Amount / Buy Max), a continuous output per second, and an optional fill-and-collect cycle mode; it records what a buy cost but spending from your wallet stays your sheet's job."
	sheet.addon_category = "Idle Generator"
	sheet.addon_tags = PackedStringArray(["incremental", "idle", "economy"])
	sheet.variables = {
		"base_cost": {"type": "float", "default": 10.0, "exported": true, "attributes": {"tooltip": "Cost of the FIRST unit. Each further unit costs cost_growth times more."}},
		"cost_growth": {"type": "float", "default": 1.15, "exported": true, "attributes": {"tooltip": "How much each unit multiplies the price (1.15 = +15% each, the genre default). 1.0 = flat price."}},
		"base_output": {"type": "float", "default": 1.0, "exported": true, "attributes": {"tooltip": "Output of ONE unit - per second in continuous mode, or per cycle when Cycle Time > 0."}},
		"output_multiplier": {"type": "float", "default": 1.0, "exported": true, "attributes": {"tooltip": "A multiplier over the whole generator's output - feed it your composed prestige x upgrade x boost multiplier."}},
		"owned": {"type": "int", "default": 0, "exported": true, "attributes": {"tooltip": "How many are owned. Set a starting count here, or leave 0 and buy them in play."}},
		"cycle_time": {"type": "float", "default": 0.0, "exported": true, "attributes": {"tooltip": "0 = continuous production (Output Per Second). Above 0 = a fill-and-collect cycle this many seconds long (AdVenture-Capitalist style); read Pending and call Collect."}},
		"_cycle_progress": {"type": "float", "default": 0.0, "exported": false},
		"_pending": {"type": "float", "default": 0.0, "exported": false},
		"last_spent": {"type": "float", "default": 0.0, "exported": false},
		"last_bought": {"type": "int", "default": 0, "exported": false},
		"last_collected": {"type": "float", "default": 0.0, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Idle Generator: a buy-more-to-make-more building. Cost climbs geometrically (base_cost * cost_growth^owned); Buy One / Buy Amount / Buy Max compute the exact geometric-series price and record it as Last Cost for your sheet to Spend. Continuous mode gives Output Per Second; set Cycle Time > 0 for a fill-and-collect building that fires On Cycle Complete. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	# Triggers + the private geometric-cost helpers (un-exposed). base_cost / cost_growth / owned are the
	# member vars above; the closed forms read them directly.
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Purchased\")",
		"signal on_purchased",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Cycle Complete\")",
		"signal on_cycle_complete",
		"",
		"# Total cost to buy `count` more units from the current owned count - the geometric series",
		"# base*r^owned*(r^count-1)/(r-1). Guards count<=0 (free) and r~1 (flat price = linear).",
		"func _cost_for_n(count: int) -> float:",
		"\tif count <= 0:",
		"\t\treturn 0.0",
		"\t# Costs must never fall: a growth below 1 makes the series converge, and Buy Max's verify",
		"\t# loop would spin forever once the budget exceeds that finite total. Treat sub-1 growth as flat.",
		"\tvar growth: float = maxf(cost_growth, 1.0)",
		"\tif absf(growth - 1.0) < 1e-12:",
		"\t\treturn base_cost * float(count)",
		"\treturn base_cost * pow(growth, owned) * (pow(growth, count) - 1.0) / (growth - 1.0)",
		"",
		"# The most units affordable for `budget`. Closed form, then a +/-1 verify against the real cost",
		"# to correct float drift at exact-cost boundaries (usually 0-1 steps). 0 if the next unit is too dear.",
		"func _max_affordable(budget: float) -> int:",
		"\tif base_cost <= 0.0:",
		"\t\treturn 0",
		"\tvar growth: float = maxf(cost_growth, 1.0)",
		"\tif budget < base_cost * pow(growth, owned):",
		"\t\treturn 0",
		"\tif absf(growth - 1.0) < 1e-12:",
		"\t\treturn int(floor(budget / base_cost))",
		"\tvar count: int = int(floor(log(1.0 + budget * (growth - 1.0) / (base_cost * pow(growth, owned))) / log(growth)))",
		"\twhile count > 0 and _cost_for_n(count) > budget:",
		"\t\tcount -= 1",
		"\twhile _cost_for_n(count + 1) <= budget:",
		"\t\tcount += 1",
		"\treturn maxi(count, 0)"
	]))
	sheet.events.append(block)

	# Cycle mode: advance the fill timer, bank a lump per completed cycle, fire On Cycle Complete.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if cycle_time <= 0.0 or owned <= 0:",
		"\treturn",
		"_cycle_progress += delta",
		"while _cycle_progress >= cycle_time:",
		"\t_cycle_progress -= cycle_time",
		"\t_pending += float(owned) * base_output * output_multiplier",
		"\ton_cycle_complete.emit()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# --- Actions ---
	Lib.append_function(sheet, "buy_one", "Buy One", "Idle Generator", "Adds one unit and records its price as Last Cost (Spend that from your wallet). Guard with Can Afford Next first.",
		[], "\n".join(PackedStringArray([
			"last_spent = _cost_for_n(1)",
			"owned += 1",
			"last_bought = 1",
			"on_purchased.emit()"
		])))
	Lib.append_function(sheet, "buy_amount", "Buy Amount", "Idle Generator", "Adds `count` units at once and records the total price as Last Cost.",
		[["count", "int"]], "\n".join(PackedStringArray([
			"if count <= 0:",
			"\treturn",
			"last_spent = _cost_for_n(count)",
			"owned += count",
			"last_bought = count",
			"on_purchased.emit()"
		])))
	Lib.append_function(sheet, "buy_max", "Buy Max", "Idle Generator", "Buys as many as `budget` affords, recording the exact total as Last Cost and the count as Last Bought. Buys nothing if not even one is affordable.",
		[["budget", "float"]], "\n".join(PackedStringArray([
			"var count: int = _max_affordable(budget)",
			"if count <= 0:",
			"\tlast_bought = 0",
			"\tlast_spent = 0.0",
			"\treturn",
			"last_spent = _cost_for_n(count)",
			"owned += count",
			"last_bought = count",
			"on_purchased.emit()"
		])))
	Lib.append_function(sheet, "set_owned", "Set Owned", "Idle Generator", "Forces the owned count to a value (clamped to 0). Does not record a cost.",
		[["count", "int"]],
		"owned = maxi(count, 0)")
	Lib.append_function(sheet, "grant", "Grant", "Idle Generator", "Adds free units - a reward or a starting bonus (no cost recorded).",
		[["count", "int"]],
		"owned += maxi(count, 0)")
	Lib.append_function(sheet, "set_output_multiplier", "Set Output Multiplier", "Idle Generator", "Sets the overall output multiplier - feed it your composed prestige x upgrade x boost value.",
		[["multiplier", "float"]],
		"output_multiplier = multiplier")
	Lib.append_function(sheet, "collect", "Collect", "Idle Generator", "Cycle mode: hands you the banked output as Last Collected and clears the pending pile. Call it on On Cycle Complete (or from a manager) and credit Last Collected to your wallet.",
		[], "\n".join(PackedStringArray([
			"last_collected = _pending",
			"_pending = 0.0"
		])))
	Lib.append_function(sheet, "reset_generator", "Reset", "Idle Generator", "Clears owned, pending output, and cycle progress - for a prestige wipe.",
		[], "\n".join(PackedStringArray([
			"owned = 0",
			"_pending = 0.0",
			"_cycle_progress = 0.0"
		])))

	# --- Conditions ---
	Lib.condition(sheet, "can_afford_next", "Can Afford Next", "Idle Generator", "Whether `budget` covers the next single unit's price.",
		[["budget", "float"]],
		"return budget >= _cost_for_n(1)")
	Lib.condition(sheet, "is_owned", "Is Owned", "Idle Generator", "Whether at least one unit is owned.",
		[],
		"return owned > 0")

	# --- Expressions ---
	Lib.number(sheet, "owned_count", "Owned", "Idle Generator", "How many units are owned.",
		[], "return owned", TYPE_INT)
	Lib.number(sheet, "next_cost", "Next Cost", "Idle Generator", "The price of the next single unit.",
		[], "return _cost_for_n(1)", TYPE_FLOAT)
	Lib.number(sheet, "cost_for", "Cost For", "Idle Generator", "The total price to buy `count` more units right now.",
		[["count", "int"]], "return _cost_for_n(count)", TYPE_FLOAT)
	Lib.number(sheet, "max_affordable", "Max Affordable", "Idle Generator", "How many units `budget` can buy.",
		[["budget", "float"]], "return _max_affordable(budget)", TYPE_INT)
	Lib.number(sheet, "cost_to_buy_max", "Cost To Buy Max", "Idle Generator", "The exact total spent if you Buy Max with `budget`.",
		[["budget", "float"]], "return _cost_for_n(_max_affordable(budget))", TYPE_FLOAT)
	Lib.number(sheet, "output_per_second", "Output Per Second", "Idle Generator", "Current production per second (owned * base_output * multiplier; in cycle mode, the lump divided by cycle time).",
		[], "\n".join(PackedStringArray([
			"var raw: float = float(owned) * base_output * output_multiplier",
			"return raw / cycle_time if cycle_time > 0.0 else raw"
		])), TYPE_FLOAT)
	Lib.number(sheet, "production_over", "Production Over", "Idle Generator", "How much is produced over `seconds` at the current rate - pass delta to credit each frame.",
		[["seconds", "float"]], "return output_per_second() * seconds", TYPE_FLOAT)
	Lib.number(sheet, "pending_output", "Pending", "Idle Generator", "Cycle mode: output banked and waiting for Collect.",
		[], "return _pending", TYPE_FLOAT)
	Lib.number(sheet, "cycle_progress", "Cycle Progress", "Idle Generator", "Cycle mode: how full the current cycle is, 0 to 1 (0 in continuous mode).",
		[], "return _cycle_progress / cycle_time if cycle_time > 0.0 else 0.0", TYPE_FLOAT)
	Lib.number(sheet, "last_cost", "Last Cost", "Idle Generator", "What the last Buy cost - Spend this from your wallet.",
		[], "return last_spent", TYPE_FLOAT)
	Lib.number(sheet, "last_bought_count", "Last Bought", "Idle Generator", "How many units the last Buy added (0 if Buy Max could not afford any).",
		[], "return last_bought", TYPE_INT)
	Lib.number(sheet, "last_collected_amount", "Last Collected", "Idle Generator", "How much the last Collect handed you.",
		[], "return last_collected", TYPE_FLOAT)

	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"owned\": owned,",
		"\t\t\"cycle_progress\": _cycle_progress,",
		"\t\t\"pending\": _pending,",
		"\t\t\"output_multiplier\": output_multiplier",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\towned = int(state.get(\"owned\", 0))",
		"\t_cycle_progress = float(state.get(\"cycle_progress\", 0.0))",
		"\t_pending = float(state.get(\"pending\", 0.0))",
		"\toutput_multiplier = float(state.get(\"output_multiplier\", 1.0))"
	]))
	sheet.events.append(persistence)

	return Lib.save_pack(sheet, "res://eventsheet_addons/idle_generator/idle_generator_behavior")
