# Pack builder - prestige (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Prestige: the reset-for-a-permanent-multiplier loop at the heart of every incremental game, as an
## AUTOLOAD sheet. Feed it what the player earns this run with Track Earned; it previews the prestige
## points they would bank (floor((run earned / requirement) ^ exponent), the classic chip formula) and,
## on Do Prestige, banks the points, bumps the prestige level, and clears the RUN total so points are
## never double-awarded - while a separate all-time Total Earned keeps growing for achievements. Prestige
## Multiplier turns banked points into the permanent boost you multiply production by. It never resets
## your currencies or generators; you do that in the same event, reading Prestige Gain first. Plain Godot,
## zero plugin dependency.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "Prestige"
	sheet.host_class = "Node"
	sheet.custom_class_name = "PrestigeAddon"
	sheet.class_description = "The reset-for-a-permanent-multiplier loop of incremental games as the Prestige autoload: Track Earned feeds the run, the square-root chip formula previews the gain, and Do Prestige banks the points, raises the level, and clears the run total. It only tracks the prestige currency - resetting your wallets and generators stays your job in the same event."
	sheet.addon_category = "Prestige"
	sheet.addon_tags = PackedStringArray(["incremental", "idle", "prestige"])
	var about: CommentRow = CommentRow.new()
	about.text = "Prestige: register as the Prestige autoload. Configure a requirement + exponent + bonus per point once, Track Earned as the player earns this run, then Do Prestige to bank points (Prestige Gain), raise the level, and reset the run. Prestige Multiplier = 1 + points * bonus is the permanent boost. Do Prestige clears the RUN total (no double-award); Total Earned is the all-time tally. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Prestige\")",
		"## @ace_category(\"Prestige\")",
		"signal on_prestige",
		"",
		"# Earnings THIS run - drives the gain and resets to 0 on Do Prestige (so points never double-award).",
		"var _run_earned: float = 0.0",
		"# All-time earnings - never reset; for achievements and lifetime stats.",
		"var _total_earned: float = 0.0",
		"# Banked prestige currency and how many times the player has prestiged.",
		"var _points: float = 0.0",
		"var _level: int = 0",
		"# Tuning: gain = floor((run_earned / requirement) ^ exponent); multiplier = 1 + points * bonus.",
		"var _requirement: float = 1000000.0",
		"var _exponent: float = 0.5",
		"var _bonus_per_point: float = 0.02",
		"# Points banked by the most recent Do Prestige (read inside On Prestige).",
		"var _last_gain: int = 0",
		"",
		"# Prestige points the current run would bank. Guards requirement<=0 (divide by zero) and",
		"# below-requirement (ratio < 1) up front so it is correct for any exponent, and clamps an",
		"# overflowed pow() so int(floor(...)) is never fed INF/NAN.",
		"func _gain() -> int:",
		"\tif _requirement <= 0.0 or _run_earned < _requirement:",
		"\t\treturn 0",
		"\tvar raw: float = pow(_run_earned / _requirement, _exponent)",
		"\t# Also saturate a FINITE value above int64 range: at the default exponent 0.5 this is reached",
		"\t# around 1e46 run earnings, and int(floor(over_range)) would wrap to a large NEGATIVE int64.",
		"\tif is_inf(raw) or is_nan(raw) or raw >= 9223372036854775807.0:",
		"\t\treturn 9223372036854775807",
		"\treturn int(floor(raw))",
		"",
		"# The run earnings needed to reach a given number of points (the inverse of _gain).",
		"func _earned_for(points: int) -> float:",
		"\tif points <= 0:",
		"\t\treturn 0.0",
		"\tif _exponent <= 0.0:",
		"\t\treturn _requirement",
		"\treturn _requirement * pow(float(points), 1.0 / _exponent)"
	]))
	sheet.events.append(block)

	# --- Setup ---
	Lib.append_function(sheet, "configure", "Configure", "Prestige", "Sets the requirement (run earnings before you gain a point), the exponent (curve; 0.5 = square-root, the usual), and the bonus each banked point adds to Prestige Multiplier.",
		[["requirement", "float"], ["exponent", "float"], ["bonus_per_point", "float"]], "\n".join(PackedStringArray([
			"_requirement = maxf(requirement, 0.0)",
			"_exponent = exponent",
			"_bonus_per_point = bonus_per_point"
		])))
	Lib.append_function(sheet, "track_earned", "Track Earned", "Prestige", "Records earnings toward prestige - call it wherever the player earns the prestige currency. Feeds both the run total (drives the gain) and the all-time Total Earned.",
		[["amount", "float"]], "\n".join(PackedStringArray([
			"var gained: float = maxf(amount, 0.0)",
			"_run_earned += gained",
			"_total_earned += gained"
		])))

	# --- The reset ---
	Lib.append_function(sheet, "do_prestige", "Do Prestige", "Prestige", "Banks the current Prestige Gain, raises the prestige level, and clears the run total. Does nothing if the gain is 0. Reset your currencies and generators in the same event, reading Prestige Gain first.",
		[], "\n".join(PackedStringArray([
			"var gain: int = _gain()",
			"if gain <= 0:",
			"\treturn",
			"_points += float(gain)",
			"_level += 1",
			"_last_gain = gain",
			"_run_earned = 0.0",
			"on_prestige.emit()"
		])))
	Lib.append_function(sheet, "set_points", "Set Points", "Prestige", "Forces banked prestige points to a value (for a load or a cheat menu).",
		[["points", "float"]],
		"_points = maxf(points, 0.0)")
	Lib.append_function(sheet, "hard_reset", "Hard Reset", "Prestige", "Wipes EVERYTHING - points, level, run and all-time earnings. A full new-game, not a prestige.",
		[], "\n".join(PackedStringArray([
			"_run_earned = 0.0",
			"_total_earned = 0.0",
			"_points = 0.0",
			"_level = 0",
			"_last_gain = 0"
		])))

	# --- Conditions ---
	Lib.condition(sheet, "can_prestige", "Can Prestige", "Prestige", "Whether prestiging now would bank at least one point.",
		[],
		"return _gain() > 0")

	# --- Expressions ---
	Lib.number(sheet, "prestige_gain", "Prestige Gain", "Prestige", "How many prestige points the current run would bank right now.",
		[], "return _gain()", TYPE_INT)
	Lib.number(sheet, "prestige_points", "Prestige Points", "Prestige", "Banked prestige currency.",
		[], "return _points", TYPE_FLOAT)
	Lib.number(sheet, "prestige_level", "Prestige Level", "Prestige", "How many times the player has prestiged.",
		[], "return _level", TYPE_INT)
	Lib.number(sheet, "prestige_multiplier", "Prestige Multiplier", "Prestige", "The permanent production multiplier from banked points: 1 + points * bonus.",
		[], "return 1.0 + _points * _bonus_per_point", TYPE_FLOAT)
	Lib.number(sheet, "run_earned", "Run Earned", "Prestige", "Earnings this run (resets on Do Prestige).",
		[], "return _run_earned", TYPE_FLOAT)
	Lib.number(sheet, "total_earned", "Total Earned", "Prestige", "All-time earnings (never resets).",
		[], "return _total_earned", TYPE_FLOAT)
	Lib.number(sheet, "last_gain", "Last Gain", "Prestige", "Points banked by the most recent Do Prestige (read inside On Prestige).",
		[], "return _last_gain", TYPE_INT)
	Lib.number(sheet, "requirement", "Requirement", "Prestige", "The run earnings needed before the first point.",
		[], "return _requirement", TYPE_FLOAT)
	Lib.number(sheet, "earned_for_next", "Earned For Next Point", "Prestige", "The run earnings needed to reach the next prestige point.",
		[], "\n".join(PackedStringArray([
			"var current: int = _gain()",
			"if current >= 9223372036854775807:",
			"\treturn INF",
			"return _earned_for(current + 1)"
		])), TYPE_FLOAT)
	Lib.number(sheet, "progress_to_next", "Progress To Next", "Prestige", "How close this run is to the next point, 0 to 1 (for a progress bar).",
		[], "\n".join(PackedStringArray([
			"var current: int = _gain()",
			"if current >= 9223372036854775807:",
			"\treturn 1.0",
			"var lower: float = _earned_for(current) if current > 0 else 0.0",
			"var upper: float = _earned_for(current + 1)",
			"if upper <= lower:",
			"\treturn 0.0",
			"return clampf((_run_earned - lower) / (upper - lower), 0.0, 1.0)"
		])), TYPE_FLOAT)

	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"# Tuning vars (requirement/exponent/bonus) are NOT saved - sheets re-Configure on ready.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"run_earned\": _run_earned,",
		"\t\t\"total_earned\": _total_earned,",
		"\t\t\"points\": _points,",
		"\t\t\"level\": _level",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_run_earned = float(state.get(\"run_earned\", 0.0))",
		"\t_total_earned = float(state.get(\"total_earned\", 0.0))",
		"\t_points = float(state.get(\"points\", 0.0))",
		"\t_level = int(state.get(\"level\", 0))"
	]))
	sheet.events.append(persistence)

	return Lib.save_pack(sheet, "res://eventsheet_addons/prestige/prestige_addon")
