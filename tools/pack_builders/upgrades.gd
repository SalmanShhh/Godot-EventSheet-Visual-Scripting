# Pack builder - upgrades (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Upgrades: the stacking one-time and repeatable buffs an incremental game is built from, as an AUTOLOAD
## sheet. Define an upgrade by id with a base cost, a cost growth per level, a max level, an effect per
## level, an effect mode (add or mult), and a tag. Try Purchase spends against a budget you pass (the
## wallet stays external - it fires On Upgrade Bought or On Purchase Failed and records Last Cost for you
## to Spend). Effect Of gives one upgrade's stacked value; Total Multiplier(tag) multiplies every mult-mode
## upgrade sharing a tag and Total Bonus(tag) sums the add-mode ones - so "all production upgrades" compose
## into one number. Plain Godot, zero plugin dependency.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "Upgrades"
	sheet.host_class = "Node"
	sheet.custom_class_name = "UpgradesAddon"
	sheet.class_description = "The stacking buff engine an incremental game is built from, shipped as the Upgrades autoload singleton. Register upgrades by string id with cost curves, max levels, per-level effects, and tags, then buy levels, read the stacked effect, and roll every tagged upgrade into one number."
	sheet.addon_category = "Upgrades"
	sheet.addon_tags = PackedStringArray(["incremental", "idle", "upgrade"])
	var about: CommentRow = CommentRow.new()
	about.text = "Upgrades: register as the Upgrades autoload. Define Upgrade sets an upgrade's cost curve, max level, per-level effect, mode (add or mult), and tag. Try Purchase(id, budget) buys the next level if it fits the budget, firing On Upgrade Bought (read Last Cost, then Spend it) or On Purchase Failed. Total Multiplier(tag) and Total Bonus(tag) roll every upgrade with a tag into one number. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Upgrade Bought\")",
		"## @ace_category(\"Upgrades\")",
		"signal on_upgrade_bought",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Purchase Failed\")",
		"## @ace_category(\"Upgrades\")",
		"signal on_purchase_failed",
		"",
		"# id -> {base_cost, cost_growth, max_level (-1 = unlimited), per_level, mode (\"add\"/\"mult\"), tag, level}.",
		"var _upgrades: Dictionary = {}",
		"# Last-purchase context, read via getters INSIDE On Upgrade Bought / On Purchase Failed.",
		"var _last_cost: float = 0.0",
		"var _last_id: String = \"\"",
		"var _last_ok: bool = false",
		"",
		"func _ensure(id: String) -> Dictionary:",
		"\tif not _upgrades.has(id):",
		"\t\t_upgrades[id] = {\"base_cost\": 10.0, \"cost_growth\": 1.0, \"max_level\": 1, \"per_level\": 1.0, \"mode\": \"add\", \"tag\": \"\", \"level\": 0}",
		"\treturn _upgrades[id]",
		"",
		"# True when an upgrade is at its cap (max_level -1 means never).",
		"func _is_maxed(record: Dictionary) -> bool:",
		"\treturn int(record.max_level) >= 0 and int(record.level) >= int(record.max_level)",
		"",
		"# The next-level price, or -1 when maxed / undefined.",
		"func _cost_of(id: String) -> float:",
		"\tif not _upgrades.has(id):",
		"\t\treturn -1.0",
		"\tvar record: Dictionary = _upgrades[id]",
		"\tif _is_maxed(record):",
		"\t\treturn -1.0",
		"\treturn float(record.base_cost) * pow(float(record.cost_growth), int(record.level))",
		"",
		"# One upgrade's current stacked effect: level*per_level for add mode, per_level^level for mult mode.",
		"func _effect_of(id: String) -> float:",
		"\tif not _upgrades.has(id):",
		"\t\treturn 0.0",
		"\tvar record: Dictionary = _upgrades[id]",
		"\tif str(record.mode) == \"mult\":",
		"\t\treturn pow(float(record.per_level), int(record.level))",
		"\treturn float(record.level) * float(record.per_level)"
	]))
	sheet.events.append(block)

	# --- Setup ---
	Lib.append_function(sheet, "define_upgrade", "Define Upgrade", "Upgrades", "Creates (or resets) an upgrade: base cost, cost growth per level, max level (-1 = unlimited), effect per level, mode (\"add\" or \"mult\"), and a tag to group it for Total Multiplier / Total Bonus.",
		[["id", "String"], ["base_cost", "float"], ["cost_growth", "float"], ["max_level", "int"], ["per_level", "float"], ["mode", "String"], ["tag", "String"]], "\n".join(PackedStringArray([
			"_upgrades[id] = {\"base_cost\": base_cost, \"cost_growth\": cost_growth, \"max_level\": max_level, \"per_level\": per_level, \"mode\": mode, \"tag\": tag, \"level\": 0}"
		])))
	Lib.append_function(sheet, "set_effect", "Set Effect", "Upgrades", "Retunes an existing upgrade's per-level effect and mode without touching its level (for live balancing).",
		[["id", "String"], ["per_level", "float"], ["mode", "String"]], "\n".join(PackedStringArray([
			"var record: Dictionary = _ensure(id)",
			"record.per_level = per_level",
			"record.mode = mode"
		])))

	# --- Buying ---
	Lib.append_function(sheet, "try_purchase", "Try Purchase", "Upgrades", "Buys the next level if `budget` covers Cost Of and it is not maxed. On success records Last Cost and fires On Upgrade Bought (Spend Last Cost from your wallet); otherwise fires On Purchase Failed. Never touches the wallet itself.",
		[["id", "String"], ["budget", "float"]], "\n".join(PackedStringArray([
			"var cost: float = _cost_of(id)",
			"if cost < 0.0 or budget < cost:",
			"\t_last_ok = false",
			"\t_last_id = id",
			"\ton_purchase_failed.emit()",
			"\treturn",
			"_ensure(id).level += 1",
			"_last_cost = cost",
			"_last_id = id",
			"_last_ok = true",
			"on_upgrade_bought.emit()"
		])))
	Lib.append_function(sheet, "grant_level", "Grant Level", "Upgrades", "Adds one free level (a reward), up to the max. No cost, no budget check.",
		[["id", "String"]], "\n".join(PackedStringArray([
			"var record: Dictionary = _ensure(id)",
			"if not _is_maxed(record):",
			"\trecord.level += 1"
		])))
	Lib.append_function(sheet, "set_level", "Set Level", "Upgrades", "Forces an upgrade's level (for a load or cheat), clamped to 0 and the max.",
		[["id", "String"], ["level", "int"]], "\n".join(PackedStringArray([
			"var record: Dictionary = _ensure(id)",
			"var capped: int = maxi(level, 0)",
			"if int(record.max_level) >= 0:",
			"\tcapped = mini(capped, int(record.max_level))",
			"record.level = capped"
		])))
	Lib.append_function(sheet, "reset_upgrades", "Reset", "Upgrades", "Sets every upgrade back to level 0 (keeps the definitions) - for a prestige wipe.",
		[], "\n".join(PackedStringArray([
			"for id: String in _upgrades:",
			"\t_upgrades[id].level = 0"
		])))

	# --- Conditions ---
	Lib.condition(sheet, "is_maxed", "Is Maxed", "Upgrades", "Whether an upgrade is at its max level.",
		[["id", "String"]],
		"return _upgrades.has(id) and _is_maxed(_upgrades[id])")
	Lib.condition(sheet, "owns", "Owns", "Upgrades", "Whether an upgrade has at least one level.",
		[["id", "String"]],
		"return _upgrades.has(id) and int(_upgrades[id].level) > 0")
	Lib.condition(sheet, "purchase_succeeded", "Purchase Succeeded", "Upgrades", "Whether the last Try Purchase went through (read it right after, or in On Upgrade Bought).",
		[],
		"return _last_ok")

	# --- Expressions ---
	Lib.number(sheet, "cost_of", "Cost Of", "Upgrades", "The next level's price (-1 if maxed or undefined).",
		[["id", "String"]], "return _cost_of(id)", TYPE_FLOAT)
	Lib.number(sheet, "level_of", "Level Of", "Upgrades", "An upgrade's current level.",
		[["id", "String"]], "return int(_upgrades[id].level) if _upgrades.has(id) else 0", TYPE_INT)
	Lib.number(sheet, "max_level_of", "Max Level Of", "Upgrades", "An upgrade's max level (-1 = unlimited).",
		[["id", "String"]], "return int(_upgrades[id].max_level) if _upgrades.has(id) else 0", TYPE_INT)
	Lib.number(sheet, "effect_of", "Effect Of", "Upgrades", "An upgrade's current stacked effect (level*per_level for add mode, per_level^level for mult mode).",
		[["id", "String"]], "return _effect_of(id)", TYPE_FLOAT)
	Lib.number(sheet, "total_multiplier", "Total Multiplier", "Upgrades", "The product of every mult-mode upgrade sharing this tag (1.0 if none) - multiply production by it.",
		[["tag", "String"]], "\n".join(PackedStringArray([
			"var product: float = 1.0",
			"for id: String in _upgrades:",
			"\tvar record: Dictionary = _upgrades[id]",
			"\tif str(record.tag) == tag and str(record.mode) == \"mult\":",
			"\t\tproduct *= _effect_of(id)",
			"return product"
		])), TYPE_FLOAT)
	Lib.number(sheet, "total_bonus", "Total Bonus", "Upgrades", "The sum of every add-mode upgrade sharing this tag (0.0 if none) - add it to a base value.",
		[["tag", "String"]], "\n".join(PackedStringArray([
			"var total: float = 0.0",
			"for id: String in _upgrades:",
			"\tvar record: Dictionary = _upgrades[id]",
			"\tif str(record.tag) == tag and str(record.mode) == \"add\":",
			"\t\ttotal += _effect_of(id)",
			"return total"
		])), TYPE_FLOAT)
	Lib.number(sheet, "last_cost", "Last Cost", "Upgrades", "What the last Try Purchase cost - Spend this from your wallet.",
		[], "return _last_cost", TYPE_FLOAT)
	Lib.number(sheet, "last_upgrade", "Last Upgrade", "Upgrades", "The id of the last upgrade bought or failed (read in the trigger).",
		[], "return _last_id", TYPE_STRING)
	Lib.number(sheet, "upgrade_count", "Upgrade Count", "Upgrades", "How many upgrades are defined.",
		[], "return _upgrades.size()", TYPE_INT)

	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"upgrades\": _upgrades.duplicate(true)",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_upgrades = (state.get(\"upgrades\", {}) as Dictionary).duplicate(true)"
	]))
	sheet.events.append(persistence)

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.feature_verbs(sheet, ["define_upgrade", "try_purchase", "effect_of"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/upgrades/upgrades_addon")
