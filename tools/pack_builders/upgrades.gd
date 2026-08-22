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
	sheet.addon_requires = PackedStringArray(["SkillTreeResource"])
	var about: CommentRow = CommentRow.new()
	about.text = "Upgrades: register as the Upgrades autoload. Define Upgrade sets an upgrade's cost curve, max level, per-level effect, mode (add or mult), and tag. Try Purchase(id, budget) buys the next level if it fits the budget, firing On Upgrade Bought (read Last Cost, then Spend it) or On Purchase Failed. Total Multiplier(tag) and Total Bonus(tag) roll every upgrade with a tag into one number. The SKILL TREE half answers from a SkillTreeResource (.tres): Load Skill Tree, then Is Unlocked / Requires / Can Unlock / Can Afford / Unlock / Respec, with skill points held here or in a Currency Ledger account. This pack is an event sheet - extend it by editing it."
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

	# --- The skill-tree half: a data asset of nodes, prerequisites and points ---
	# Levels and cost curves are the incremental half above. A skill TREE adds three things the
	# curve has no room for: a prerequisite list, a currency spent on unlocking, and what a node
	# GRANTS. All three live in one SkillTreeResource (.tres) the designer fills in, so the shape a
	# game would otherwise hand-write - an unlocked dictionary, a points number and a loop over a
	# requires list - is one Load Skill Tree row and five verbs.
	var tree_block: RawCodeRow = RawCodeRow.new()
	tree_block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Skill Unlocked\")",
		"## @ace_category(\"Upgrades\")",
		"signal on_skill_unlocked",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Unlock Refused\")",
		"## @ace_category(\"Upgrades\")",
		"signal on_unlock_refused",
		"",
		"# The source every grant a skill applies is tagged with, so Respec can take all of them back",
		"# in one call without touching a buff the game put there for another reason.",
		"const SKILL_SOURCE: String = \"skill_tree\"",
		"",
		"# The loaded SkillTreeResource (.tres). Null until Load Skill Tree runs, and every tree word",
		"# answers honestly (false / 0 / \"\") while it is.",
		"var _tree: Resource = null",
		"# Skill id -> how many levels of it are unlocked. A one-off perk sits at 1.",
		"var _unlocked: Dictionary = {}",
		"# Unspent skill points, unless a Currency Ledger account holds them instead.",
		"var _skill_points: int = 0",
		"# When set, points live in this Currency Ledger account rather than in the number above.",
		"var _points_account: String = \"\"",
		"# The skill Unlock last touched - read it inside On Skill Unlocked / On Unlock Refused.",
		"var _last_skill: String = \"\"",
		"# The node whose StatForge stack an unlocked skill's grants are applied to (optional).",
		"var _stats: Node = null",
		"",
		"# One skill row of the loaded tree; {} when no tree is loaded or the id is not one of its ids.",
		"func _skill_row(id: String) -> Dictionary:",
		"\tif _tree == null:",
		"\t\treturn {}",
		"\tvar rows: Variant = _tree.get(\"skills\")",
		"\tif not (rows is Array):",
		"\t\treturn {}",
		"\tfor entry: Variant in rows as Array:",
		"\t\tif entry is Dictionary and str((entry as Dictionary).get(\"id\", \"\")) == id:",
		"\t\t\treturn entry as Dictionary",
		"\treturn {}",
		"",
		"# The ids a skill needs unlocked first, in the order the asset's comma-separated cell lists them.",
		"func _requires_of(id: String) -> PackedStringArray:",
		"\tvar out: PackedStringArray = PackedStringArray()",
		"\tfor part: String in str(_skill_row(id).get(\"requires\", \"\")).split(\",\"):",
		"\t\tvar required: String = part.strip_edges()",
		"\t\tif not required.is_empty() and not out.has(required):",
		"\t\t\tout.append(required)",
		"\treturn out",
		"",
		"# The Currency Ledger autoload, when a points account was named and the singleton is there.",
		"func _points_ledger() -> Node:",
		"\tif _points_account.is_empty() or not is_inside_tree():",
		"\t\treturn null",
		"\tvar ledger: Node = get_node_or_null(\"/root/CurrencyLedger\")",
		"\tif ledger == null or not ledger.has_method(\"balance\"):",
		"\t\treturn null",
		"\treturn ledger",
		"",
		"# The unspent points, wherever they are kept.",
		"func _points() -> int:",
		"\tvar ledger: Node = _points_ledger()",
		"\tif ledger != null:",
		"\t\treturn int(ledger.balance(_points_account))",
		"\treturn _skill_points",
		"",
		"func _set_points(value: int) -> void:",
		"\tvar ledger: Node = _points_ledger()",
		"\tif ledger != null:",
		"\t\tledger.set_amount(_points_account, float(value))",
		"\t\treturn",
		"\t_skill_points = maxi(value, 0)",
		"",
		"func _earn_points(amount: int) -> void:",
		"\tvar ledger: Node = _points_ledger()",
		"\tif ledger != null:",
		"\t\tledger.add(_points_account, float(amount))",
		"\t\treturn",
		"\t_skill_points = maxi(_skill_points + amount, 0)",
		"",
		"func _spend_points(amount: int) -> void:",
		"\tvar ledger: Node = _points_ledger()",
		"\tif ledger != null:",
		"\t\tledger.spend(_points_account, float(amount))",
		"\t\treturn",
		"\t_skill_points = maxi(_skill_points - amount, 0)",
		"",
		"# What one level of a skill costs in points (0 when the id is not in the tree).",
		"func _skill_cost(id: String) -> int:",
		"\treturn int(_skill_row(id).get(\"cost\", 0))",
		"",
		"# How many levels a skill can take. A blank or zero cell means a one-off perk.",
		"func _skill_max_level(id: String) -> int:",
		"\treturn maxi(int(_skill_row(id).get(\"max_level\", 1)), 1)",
		"",
		"# The three questions an unlock has to answer yes to: the id is in the tree, it is not already",
		"# at its cap, every id it requires is unlocked, and the points are there.",
		"func _can_unlock(id: String) -> bool:",
		"\tif _skill_row(id).is_empty():",
		"\t\treturn false",
		"\tif int(_unlocked.get(id, 0)) >= _skill_max_level(id):",
		"\t\treturn false",
		"\tfor required: String in _requires_of(id):",
		"\t\tif int(_unlocked.get(required, 0)) <= 0:",
		"\t\t\treturn false",
		"\treturn _points() >= _skill_cost(id)",
		"",
		"# One `grants` cell as modifier rows: {stat, mode, amount, per_level}. The grammar is the",
		"# StatForge modifier written as words - `<stat> <op><amount>` with an optional ` per level`,",
		"# several separated by `;`. `x` and `*` multiply, `+` and `-` add, `=` overrides.",
		"func _grants_of(id: String) -> Array:",
		"\tvar rows: Array = []",
		"\tfor part: String in str(_skill_row(id).get(\"grants\", \"\")).split(\";\"):",
		"\t\tvar text: String = part.strip_edges()",
		"\t\tif text.is_empty():",
		"\t\t\tcontinue",
		"\t\tvar per_level: bool = text.to_lower().ends_with(\" per level\")",
		"\t\tif per_level:",
		"\t\t\ttext = text.substr(0, text.length() - 10).strip_edges()",
		"\t\tvar split_at: int = text.rfind(\" \")",
		"\t\tif split_at <= 0:",
		"\t\t\tcontinue",
		"\t\tvar stat: String = text.substr(0, split_at).strip_edges()",
		"\t\tvar amount_text: String = text.substr(split_at + 1).strip_edges()",
		"\t\tvar mode: String = \"add\"",
		"\t\tif amount_text.begins_with(\"x\") or amount_text.begins_with(\"*\"):",
		"\t\t\tmode = \"multiply\"",
		"\t\t\tamount_text = amount_text.substr(1)",
		"\t\telif amount_text.begins_with(\"=\"):",
		"\t\t\tmode = \"override\"",
		"\t\t\tamount_text = amount_text.substr(1)",
		"\t\telif amount_text.begins_with(\"+\"):",
		"\t\t\tamount_text = amount_text.substr(1)",
		"\t\tif stat.is_empty() or not amount_text.is_valid_float():",
		"\t\t\tcontinue",
		"\t\trows.append({\"stat\": stat, \"mode\": mode, \"amount\": float(amount_text), \"per_level\": per_level})",
		"\treturn rows",
		"",
		"# Pushes one skill's grants onto the stats node as StatForge buffs - one buff per stat, keyed",
		"# by skill and stat so the next level REPLACES the last one rather than stacking beside it.",
		"# Does nothing when no stats node was named, which is the whole opt-out.",
		"func _apply_grants(id: String) -> void:",
		"\tif _stats == null or not is_instance_valid(_stats) or not _stats.has_method(\"add_buff\"):",
		"\t\treturn",
		"\tvar level: int = int(_unlocked.get(id, 0))",
		"\tif level <= 0:",
		"\t\treturn",
		"\tfor grant: Dictionary in _grants_of(id):",
		"\t\tvar amount: float = float(grant[\"amount\"])",
		"\t\tif bool(grant[\"per_level\"]):",
		"\t\t\tamount = pow(amount, level) if str(grant[\"mode\"]) == \"multiply\" else amount * float(level)",
		"\t\t_stats.add_buff(\"skill:%s:%s\" % [id, str(grant[\"stat\"])], str(grant[\"stat\"]), amount,",
		"\t\t\t\tstr(grant[\"mode\"]), \"skill\", SKILL_SOURCE, 0.0)"
	]))
	sheet.events.append(tree_block)

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

	# --- Skill tree: actions ---
	Lib.append_function(sheet, "load_skill_tree", "Load Skill Tree", "Upgrades", "Points the tree words at a SkillTreeResource (.tres). Clears whatever was unlocked and hands the asset's Starting Points to the points counter, so one row opens a fresh tree.",
		[["tree", "Resource"]], "\n".join(PackedStringArray([
			"_tree = tree",
			"_unlocked.clear()",
			"if _tree == null:",
			"\treturn",
			"var starting: Variant = _tree.get(\"starting_points\")",
			"if starting != null:",
			"\t_set_points(int(starting))"
		])))
	Lib.append_function(sheet, "set_skill_points", "Set Skill Points", "Upgrades", "Forces the unspent skill points to a value (for a load or a cheat). Clamped at 0.",
		[["points", "int"]], "_set_points(maxi(points, 0))")
	Lib.append_function(sheet, "earn_skill_points", "Earn Skill Points", "Upgrades", "Adds skill points - the level-up reward. Goes into the Currency Ledger account when one was named.",
		[["points", "int"]], "_earn_points(maxi(points, 0))")
	Lib.append_function(sheet, "use_points_account", "Use Points Account", "Upgrades", "Keeps skill points in a Currency Ledger account of this id instead of here, so the HUD, the save file and the shop all read one balance. Blank goes back to the built-in counter.",
		[["account_id", "String"]], "_points_account = account_id.strip_edges()")
	Lib.append_function(sheet, "apply_grants_to", "Apply Grants To", "Upgrades", "Names the node whose StatForge stack an unlocked skill's grants are applied to, and re-applies everything already unlocked. Without it a tree still unlocks - it just grants nothing.",
		[["stats", "Node"]], "\n".join(PackedStringArray([
			"_stats = stats",
			"for id: String in _unlocked:",
			"\t_apply_grants(id)"
		])))
	Lib.append_function(sheet, "unlock_skill", "Unlock", "Upgrades", "Takes one level of a skill: spends its cost, records the level, applies its grants and fires On Skill Unlocked. Refuses (On Unlock Refused) when a required skill is still locked, the skill is capped, or the points are short.",
		[["id", "String"]], "\n".join(PackedStringArray([
			"_last_skill = id",
			"if not _can_unlock(id):",
			"\ton_unlock_refused.emit()",
			"\treturn",
			"_spend_points(_skill_cost(id))",
			"_unlocked[id] = int(_unlocked.get(id, 0)) + 1",
			"_apply_grants(id)",
			"on_skill_unlocked.emit()"
		])))
	Lib.append_function(sheet, "respec", "Respec", "Upgrades", "Refunds every point spent on the tree, clears every unlock and takes back every grant it applied - one action, so a respec button is one row.",
		[], "\n".join(PackedStringArray([
			"var refund: int = 0",
			"for id: String in _unlocked:",
			"\trefund += _skill_cost(id) * int(_unlocked[id])",
			"_unlocked.clear()",
			"if _stats != null and is_instance_valid(_stats) and _stats.has_method(\"remove_buffs_by_source\"):",
			"\t_stats.remove_buffs_by_source(SKILL_SOURCE)",
			"_earn_points(refund)"
		])))

	# --- Skill tree: conditions ---
	Lib.condition(sheet, "is_skill_unlocked", "Is Unlocked", "Upgrades", "Whether a skill has been taken at least once - the perk test a game asks wherever the perk matters.",
		[["id", "String"]],
		"return int(_unlocked.get(id, 0)) > 0")
	Lib.condition(sheet, "can_unlock_skill", "Can Unlock", "Upgrades", "Whether every skill this one requires is unlocked, it is not already capped, and the points are there.",
		[["id", "String"]],
		"return _can_unlock(id)")
	Lib.condition(sheet, "can_afford_skill", "Can Afford", "Upgrades", "Whether the unspent points cover this skill's cost, ignoring its prerequisites.",
		[["id", "String"]],
		"return _points() >= _skill_cost(id)")
	Lib.condition(sheet, "skill_requires", "Requires", "Upgrades", "Whether the tree says this skill needs that one unlocked first.",
		[["id", "String"], ["required_id", "String"]],
		"return _requires_of(id).has(required_id.strip_edges())")

	# --- Skill tree: expressions ---
	Lib.number(sheet, "skill_points_left", "Skill Points", "Upgrades", "The unspent skill points - the number a tree screen's \"points left\" label shows.",
		[], "return _points()", TYPE_INT)
	Lib.number(sheet, "skill_cost_of", "Skill Cost", "Upgrades", "What one level of a skill costs in points (0 when the id is not in the tree).",
		[["id", "String"]], "return _skill_cost(id)", TYPE_INT)
	Lib.number(sheet, "skill_level_of", "Skill Level", "Upgrades", "How many levels of a skill are unlocked (0 = locked).",
		[["id", "String"]], "return int(_unlocked.get(id, 0))", TYPE_INT)
	Lib.number(sheet, "skill_max_level_of", "Skill Max Level", "Upgrades", "How many levels a skill can take (1 for a one-off perk).",
		[["id", "String"]], "return _skill_max_level(id)", TYPE_INT)
	Lib.number(sheet, "skill_name_of", "Skill Name", "Upgrades", "A skill's readable name from the asset (\"\" when the id is not in the tree).",
		[["id", "String"]], "return str(_skill_row(id).get(\"name\", \"\"))", TYPE_STRING)
	Lib.number(sheet, "skill_requires_text", "Skill Requires", "Upgrades", "The ids a skill needs first, comma-separated as the asset wrote them (\"\" for a root skill).",
		[["id", "String"]], "return \", \".join(_requires_of(id))", TYPE_STRING)
	Lib.number(sheet, "skill_grants_text", "Skill Grants", "Upgrades", "What a skill grants, as the asset's own words - the line a tree screen shows on hover.",
		[["id", "String"]], "return str(_skill_row(id).get(\"grants\", \"\"))", TYPE_STRING)
	Lib.number(sheet, "skill_column_of", "Skill Column", "Upgrades", "A skill's column on a tree screen, or -1 when the asset leaves the layout to the screen.",
		[["id", "String"]], "return int(_skill_row(id).get(\"column\", -1))", TYPE_INT)
	Lib.number(sheet, "skill_row_of", "Skill Row", "Upgrades", "A skill's row on a tree screen, or -1 when the asset leaves the layout to the screen.",
		[["id", "String"]], "return int(_skill_row(id).get(\"row\", -1))", TYPE_INT)
	Lib.number(sheet, "skill_depth_of", "Skill Depth", "Upgrades", "How many prerequisites deep a skill sits - 0 for a root, 1 for its children, and so on. A screen with no column/row in its asset lays the tree out by this.",
		[["id", "String"]], "\n".join(PackedStringArray([
			"var depth: int = 0",
			"var frontier: PackedStringArray = _requires_of(id)",
			"var guard: int = 0",
			"while not frontier.is_empty() and guard < 64:",
			"\tguard += 1",
			"\tdepth += 1",
			"\tvar next: PackedStringArray = PackedStringArray()",
			"\tfor required: String in frontier:",
			"\t\tfor deeper: String in _requires_of(required):",
			"\t\t\tif not next.has(deeper):",
			"\t\t\t\tnext.append(deeper)",
			"\tfrontier = next",
			"return depth"
		])), TYPE_INT)
	Lib.number(sheet, "skill_id_at", "Skill Id At", "Upgrades", "The skill id at a position in the asset's own order (\"\" out of range) - what a screen walks to build its nodes.",
		[["index", "int"]], "\n".join(PackedStringArray([
			"if _tree == null:",
			"\treturn \"\"",
			"var rows: Variant = _tree.get(\"skills\")",
			"if not (rows is Array) or index < 0 or index >= (rows as Array).size():",
			"\treturn \"\"",
			"return str(((rows as Array)[index] as Dictionary).get(\"id\", \"\"))"
		])), TYPE_STRING)
	Lib.number(sheet, "skill_count", "Skill Count", "Upgrades", "How many skills the loaded tree holds (0 when none is loaded).",
		[], "\n".join(PackedStringArray([
			"if _tree == null:",
			"\treturn 0",
			"var rows: Variant = _tree.get(\"skills\")",
			"return (rows as Array).size() if rows is Array else 0"
		])), TYPE_INT)
	Lib.number(sheet, "unlocked_skill_count", "Unlocked Count", "Upgrades", "How many skills have at least one level - the \"12 of 30\" a tree screen prints.",
		[], "return _unlocked.size()", TYPE_INT)
	Lib.number(sheet, "last_skill_id", "Last Skill", "Upgrades", "The skill Unlock last touched - read it inside On Skill Unlocked or On Unlock Refused.",
		[], "return _last_skill", TYPE_STRING)
	Lib.number(sheet, "skill_tree_name", "Tree Name", "Upgrades", "The loaded tree's readable name (\"\" when none is loaded) - a tree screen's title.",
		[], "return str(_tree.get(\"tree_name\")) if _tree != null and _tree.get(\"tree_name\") != null else \"\"", TYPE_STRING)

	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"upgrades\": _upgrades.duplicate(true),",
		"\t\t\"unlocked\": _unlocked.duplicate(true),",
		"\t\t\"skill_points\": _skill_points",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_upgrades = (state.get(\"upgrades\", {}) as Dictionary).duplicate(true)",
		"\t_unlocked = (state.get(\"unlocked\", {}) as Dictionary).duplicate(true)",
		"\t_skill_points = int(state.get(\"skill_points\", 0))",
		"\tfor id: String in _unlocked:",
		"\t\t_apply_grants(id)"
	]))
	sheet.events.append(persistence)

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.verb_sentences(sheet, {
		"define_upgrade": "Define upgrade [b]{id}[/b]: base cost [b]{base_cost}[/b] growing [b]{cost_growth}[/b]x, max level [b]{max_level}[/b], [b]{per_level}[/b] per level ([b]{mode}[/b])",
		"effect_of": "Effect of [b]{id}[/b]",
		"try_purchase": "Try purchase [b]{id}[/b] with budget [b]{budget}[/b]",
		"unlock_skill": "Unlock [b]{id}[/b]",
		"is_skill_unlocked": "[b]{id}[/b] is unlocked",
		"can_unlock_skill": "[b]{id}[/b] can be unlocked",
		"skill_requires": "[b]{id}[/b] requires [b]{required_id}[/b]",
		"load_skill_tree": "Load skill tree [i]{tree}[/i]",
	})
	Lib.feature_verbs(sheet, ["define_upgrade", "try_purchase", "effect_of", "unlock_skill"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/upgrades/upgrades_addon")
