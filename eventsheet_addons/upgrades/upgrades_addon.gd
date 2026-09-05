## @ace_tags(incremental, idle, upgrade)
## @ace_category("Upgrades")
## @ace_requires(SkillTreeResource)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/upgrades/icon.svg")
class_name UpgradesAddon
extends Node
## The stacking buff engine an incremental game is built from, shipped as the Upgrades autoload singleton. Register upgrades by string id with cost curves, max levels, per-level effects, and tags, then buy levels, read the stacked effect, and roll every tagged upgrade into one number.

## @ace_trigger
## @ace_name("On Upgrade Bought")
## @ace_category("Upgrades")
signal on_upgrade_bought
## @ace_trigger
## @ace_name("On Purchase Failed")
## @ace_category("Upgrades")
signal on_purchase_failed
## @ace_trigger
## @ace_name("On Skill Unlocked")
## @ace_category("Upgrades")
signal on_skill_unlocked
## @ace_trigger
## @ace_name("On Unlock Refused")
## @ace_category("Upgrades")
signal on_unlock_refused

# id -> {base_cost, cost_growth, max_level (-1 = unlimited), per_level, mode ("add"/"mult"), tag, level}.
var _upgrades: Dictionary = {}
# Last-purchase context, read via getters INSIDE On Upgrade Bought / On Purchase Failed.
var _last_cost: float = 0.0
var _last_id: String = ""
var _last_ok: bool = false

# The source every grant a skill applies is tagged with, so Respec can take all of them back
# in one call without touching a buff the game put there for another reason.
const SKILL_SOURCE: String = "skill_tree"

# The loaded SkillTreeResource (.tres). Null until Load Skill Tree runs, and every tree word
# answers honestly (false / 0 / "") while it is.
var _tree: Resource = null
# Skill id -> how many levels of it are unlocked. A one-off perk sits at 1.
var _unlocked: Dictionary = {}
# Unspent skill points, unless a Currency Ledger account holds them instead.
var _skill_points: int = 0
# When set, points live in this Currency Ledger account rather than in the number above.
var _points_account: String = ""
# The skill Unlock last touched - read it inside On Skill Unlocked / On Unlock Refused.
var _last_skill: String = ""
# The node whose StatForge stack an unlocked skill's grants are applied to (optional).
var _stats: Node = null
# The Currency Ledger autoload, when a points account was named and the singleton is there.
func _points_ledger() -> Node:
	if _points_account.is_empty() or not is_inside_tree():
		return null
	var ledger: Node = get_node_or_null("/root/CurrencyLedger")
	if ledger == null or not ledger.has_method("balance"):
		return null
	return ledger

## @ace_action
## @ace_featured
## @ace_name("Define Upgrade")
## @ace_category("Upgrades")
## @ace_description("Creates (or resets) an upgrade: base cost, cost growth per level, max level (-1 = unlimited), effect per level, mode ("add" or "mult"), and a tag to group it for Total Multiplier / Total Bonus.")
## @ace_display_template("Define upgrade [b]{id}[/b]: base cost [b]{base_cost}[/b] growing [b]{cost_growth}[/b]x, max level [b]{max_level}[/b], [b]{per_level}[/b] per level ([b]{mode}[/b])")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.define_upgrade({id}, {base_cost}, {cost_growth}, {max_level}, {per_level}, {mode}, {tag})")
func define_upgrade(id: String, base_cost: float, cost_growth: float, max_level: int, per_level: float, mode: String, tag: String) -> void:
	_upgrades[id] = {"base_cost": base_cost, "cost_growth": cost_growth, "max_level": max_level, "per_level": per_level, "mode": mode, "tag": tag, "level": 0}

## @ace_action
## @ace_name("Set Effect")
## @ace_category("Upgrades")
## @ace_description("Retunes an existing upgrade's per-level effect and mode without touching its level (for live balancing).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.set_effect({id}, {per_level}, {mode})")
func set_effect(id: String, per_level: float, mode: String) -> void:
	var record: Dictionary = _ensure(id)
	record.per_level = per_level
	record.mode = mode

## @ace_action
## @ace_featured
## @ace_name("Try Purchase")
## @ace_category("Upgrades")
## @ace_description("Buys the next level if `budget` covers Cost Of and it is not maxed. On success records Last Cost and fires On Upgrade Bought (Spend Last Cost from your wallet); otherwise fires On Purchase Failed. Never touches the wallet itself.")
## @ace_display_template("Try purchase [b]{id}[/b] with budget [b]{budget}[/b]")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.try_purchase({id}, {budget})")
func try_purchase(id: String, budget: float) -> void:
	var cost: float = _cost_of(id)
	if cost < 0.0 or budget < cost:
		_last_ok = false
		_last_id = id
		on_purchase_failed.emit()
		return
	_ensure(id).level += 1
	_last_cost = cost
	_last_id = id
	_last_ok = true
	on_upgrade_bought.emit()

## @ace_action
## @ace_name("Grant Level")
## @ace_category("Upgrades")
## @ace_description("Adds one free level (a reward), up to the max. No cost, no budget check.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.grant_level({id})")
func grant_level(id: String) -> void:
	var record: Dictionary = _ensure(id)
	if not _is_maxed(record):
		record.level += 1

## @ace_action
## @ace_name("Set Level")
## @ace_category("Upgrades")
## @ace_description("Forces an upgrade's level (for a load or cheat), clamped to 0 and the max.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.set_level({id}, {level})")
func set_level(id: String, level: int) -> void:
	var record: Dictionary = _ensure(id)
	var capped: int = maxi(level, 0)
	if int(record.max_level) >= 0:
		capped = mini(capped, int(record.max_level))
	record.level = capped

## @ace_action
## @ace_name("Reset")
## @ace_category("Upgrades")
## @ace_description("Sets every upgrade back to level 0 (keeps the definitions) - for a prestige wipe.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.reset_upgrades()")
func reset_upgrades() -> void:
	for id: String in _upgrades:
		_upgrades[id].level = 0

## @ace_condition
## @ace_name("Is Maxed")
## @ace_category("Upgrades")
## @ace_description("Whether an upgrade is at its max level.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.is_maxed({id})")
func is_maxed(id: String) -> bool:
	return _upgrades.has(id) and _is_maxed(_upgrades[id])

## @ace_condition
## @ace_name("Owns")
## @ace_category("Upgrades")
## @ace_description("Whether an upgrade has at least one level.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.owns({id})")
func owns(id: String) -> bool:
	return _upgrades.has(id) and int(_upgrades[id].level) > 0

## @ace_condition
## @ace_name("Purchase Succeeded")
## @ace_category("Upgrades")
## @ace_description("Whether the last Try Purchase went through (read it right after, or in On Upgrade Bought).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.purchase_succeeded()")
func purchase_succeeded() -> bool:
	return _last_ok

## @ace_expression
## @ace_name("Cost Of")
## @ace_category("Upgrades")
## @ace_description("The next level's price (-1 if maxed or undefined).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.cost_of({id})")
func cost_of(id: String) -> float:
	return _cost_of(id)

## @ace_expression
## @ace_name("Level Of")
## @ace_category("Upgrades")
## @ace_description("An upgrade's current level.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.level_of({id})")
func level_of(id: String) -> int:
	return int(_upgrades[id].level) if _upgrades.has(id) else 0

## @ace_expression
## @ace_name("Max Level Of")
## @ace_category("Upgrades")
## @ace_description("An upgrade's max level (-1 = unlimited).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.max_level_of({id})")
func max_level_of(id: String) -> int:
	return int(_upgrades[id].max_level) if _upgrades.has(id) else 0

## @ace_expression
## @ace_featured
## @ace_name("Effect Of")
## @ace_category("Upgrades")
## @ace_description("An upgrade's current stacked effect (level*per_level for add mode, per_level^level for mult mode).")
## @ace_display_template("Effect of [b]{id}[/b]")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.effect_of({id})")
func effect_of(id: String) -> float:
	return _effect_of(id)

## @ace_expression
## @ace_name("Total Multiplier")
## @ace_category("Upgrades")
## @ace_description("The product of every mult-mode upgrade sharing this tag (1.0 if none) - multiply production by it.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.total_multiplier({tag})")
func total_multiplier(tag: String) -> float:
	var product: float = 1.0
	for id: String in _upgrades:
		var record: Dictionary = _upgrades[id]
		if str(record.tag) == tag and str(record.mode) == "mult":
			product *= _effect_of(id)
	return product

## @ace_expression
## @ace_name("Total Bonus")
## @ace_category("Upgrades")
## @ace_description("The sum of every add-mode upgrade sharing this tag (0.0 if none) - add it to a base value.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.total_bonus({tag})")
func total_bonus(tag: String) -> float:
	var total: float = 0.0
	for id: String in _upgrades:
		var record: Dictionary = _upgrades[id]
		if str(record.tag) == tag and str(record.mode) == "add":
			total += _effect_of(id)
	return total

## @ace_expression
## @ace_name("Last Cost")
## @ace_category("Upgrades")
## @ace_description("What the last Try Purchase cost - Spend this from your wallet.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.last_cost()")
func last_cost() -> float:
	return _last_cost

## @ace_expression
## @ace_name("Last Upgrade")
## @ace_category("Upgrades")
## @ace_description("The id of the last upgrade bought or failed (read in the trigger).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.last_upgrade()")
func last_upgrade() -> String:
	return _last_id

## @ace_expression
## @ace_name("Upgrade Count")
## @ace_category("Upgrades")
## @ace_description("How many upgrades are defined.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.upgrade_count()")
func upgrade_count() -> int:
	return _upgrades.size()

## @ace_action
## @ace_name("Load Skill Tree")
## @ace_category("Upgrades")
## @ace_description("Points the tree words at a SkillTreeResource (.tres). Clears whatever was unlocked and hands the asset's Starting Points to the points counter, so one row opens a fresh tree.")
## @ace_display_template("Load skill tree [i]{tree}[/i]")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.load_skill_tree({tree})")
func load_skill_tree(tree: Resource) -> void:
	_tree = tree
	_unlocked.clear()
	if _tree == null:
		return
	var starting: Variant = _tree.get("starting_points")
	if starting != null:
		_set_points(int(starting))

## @ace_action
## @ace_name("Set Skill Points")
## @ace_category("Upgrades")
## @ace_description("Forces the unspent skill points to a value (for a load or a cheat). Clamped at 0.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.set_skill_points({points})")
func set_skill_points(points: int) -> void:
	_set_points(maxi(points, 0))

## @ace_action
## @ace_name("Earn Skill Points")
## @ace_category("Upgrades")
## @ace_description("Adds skill points - the level-up reward. Goes into the Currency Ledger account when one was named.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.earn_skill_points({points})")
func earn_skill_points(points: int) -> void:
	_earn_points(maxi(points, 0))

## @ace_action
## @ace_name("Use Points Account")
## @ace_category("Upgrades")
## @ace_description("Keeps skill points in a Currency Ledger account of this id instead of here, so the HUD, the save file and the shop all read one balance. Blank goes back to the built-in counter.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.use_points_account({account_id})")
func use_points_account(account_id: String) -> void:
	_points_account = account_id.strip_edges()

## @ace_action
## @ace_name("Apply Grants To")
## @ace_category("Upgrades")
## @ace_description("Names the node whose StatForge stack an unlocked skill's grants are applied to, and re-applies everything already unlocked. Without it a tree still unlocks - it just grants nothing.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.apply_grants_to({stats})")
func apply_grants_to(stats: Node) -> void:
	_stats = stats
	for id: String in _unlocked:
		_apply_grants(id)

## @ace_action
## @ace_featured
## @ace_name("Unlock")
## @ace_category("Upgrades")
## @ace_description("Takes one level of a skill: spends its cost, records the level, applies its grants and fires On Skill Unlocked. Refuses (On Unlock Refused) when a required skill is still locked, the skill is capped, or the points are short.")
## @ace_display_template("Unlock [b]{id}[/b]")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.unlock_skill({id})")
func unlock_skill(id: String) -> void:
	_last_skill = id
	if not _can_unlock(id):
		on_unlock_refused.emit()
		return
	_spend_points(_skill_cost(id))
	_unlocked[id] = int(_unlocked.get(id, 0)) + 1
	_apply_grants(id)
	on_skill_unlocked.emit()

## @ace_action
## @ace_name("Respec")
## @ace_category("Upgrades")
## @ace_description("Refunds every point spent on the tree, clears every unlock and takes back every grant it applied - one action, so a respec button is one row.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.respec()")
func respec() -> void:
	var refund: int = 0
	for id: String in _unlocked:
		refund += _skill_cost(id) * int(_unlocked[id])
	_unlocked.clear()
	if _stats != null and is_instance_valid(_stats) and _stats.has_method("remove_buffs_by_source"):
		_stats.remove_buffs_by_source(SKILL_SOURCE)
	_earn_points(refund)

## @ace_condition
## @ace_name("Is Unlocked")
## @ace_category("Upgrades")
## @ace_description("Whether a skill has been taken at least once - the perk test a game asks wherever the perk matters.")
## @ace_display_template("[b]{id}[/b] is unlocked")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.is_skill_unlocked({id})")
func is_skill_unlocked(id: String) -> bool:
	return int(_unlocked.get(id, 0)) > 0

## @ace_condition
## @ace_name("Can Unlock")
## @ace_category("Upgrades")
## @ace_description("Whether every skill this one requires is unlocked, it is not already capped, and the points are there.")
## @ace_display_template("[b]{id}[/b] can be unlocked")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.can_unlock_skill({id})")
func can_unlock_skill(id: String) -> bool:
	return _can_unlock(id)

## @ace_condition
## @ace_name("Can Afford")
## @ace_category("Upgrades")
## @ace_description("Whether the unspent points cover this skill's cost, ignoring its prerequisites.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.can_afford_skill({id})")
func can_afford_skill(id: String) -> bool:
	return _points() >= _skill_cost(id)

## @ace_condition
## @ace_name("Requires")
## @ace_category("Upgrades")
## @ace_description("Whether the tree says this skill needs that one unlocked first.")
## @ace_display_template("[b]{id}[/b] requires [b]{required_id}[/b]")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.skill_requires({id}, {required_id})")
func skill_requires(id: String, required_id: String) -> bool:
	return _requires_of(id).has(required_id.strip_edges())

## @ace_expression
## @ace_name("Skill Points")
## @ace_category("Upgrades")
## @ace_description("The unspent skill points - the number a tree screen's "points left" label shows.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.skill_points_left()")
func skill_points_left() -> int:
	return _points()

## @ace_expression
## @ace_name("Skill Cost")
## @ace_category("Upgrades")
## @ace_description("What one level of a skill costs in points (0 when the id is not in the tree).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.skill_cost_of({id})")
func skill_cost_of(id: String) -> int:
	return _skill_cost(id)

## @ace_expression
## @ace_name("Skill Level")
## @ace_category("Upgrades")
## @ace_description("How many levels of a skill are unlocked (0 = locked).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.skill_level_of({id})")
func skill_level_of(id: String) -> int:
	return int(_unlocked.get(id, 0))

## @ace_expression
## @ace_name("Skill Max Level")
## @ace_category("Upgrades")
## @ace_description("How many levels a skill can take (1 for a one-off perk).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.skill_max_level_of({id})")
func skill_max_level_of(id: String) -> int:
	return _skill_max_level(id)

## @ace_expression
## @ace_name("Skill Name")
## @ace_category("Upgrades")
## @ace_description("A skill's readable name from the asset ("" when the id is not in the tree).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.skill_name_of({id})")
func skill_name_of(id: String) -> String:
	return str(_skill_row(id).get("name", ""))

## @ace_expression
## @ace_name("Skill Requires")
## @ace_category("Upgrades")
## @ace_description("The ids a skill needs first, comma-separated as the asset wrote them ("" for a root skill).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.skill_requires_text({id})")
func skill_requires_text(id: String) -> String:
	return ", ".join(_requires_of(id))

## @ace_expression
## @ace_name("Skill Grants")
## @ace_category("Upgrades")
## @ace_description("What a skill grants, as the asset's own words - the line a tree screen shows on hover.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.skill_grants_text({id})")
func skill_grants_text(id: String) -> String:
	return str(_skill_row(id).get("grants", ""))

## @ace_expression
## @ace_name("Skill Column")
## @ace_category("Upgrades")
## @ace_description("A skill's column on a tree screen, or -1 when the asset leaves the layout to the screen.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.skill_column_of({id})")
func skill_column_of(id: String) -> int:
	return int(_skill_row(id).get("column", -1))

## @ace_expression
## @ace_name("Skill Row")
## @ace_category("Upgrades")
## @ace_description("A skill's row on a tree screen, or -1 when the asset leaves the layout to the screen.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.skill_row_of({id})")
func skill_row_of(id: String) -> int:
	return int(_skill_row(id).get("row", -1))

## @ace_expression
## @ace_name("Skill Depth")
## @ace_category("Upgrades")
## @ace_description("How many prerequisites deep a skill sits - 0 for a root, 1 for its children, and so on. A screen with no column/row in its asset lays the tree out by this.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.skill_depth_of({id})")
func skill_depth_of(id: String) -> int:
	var depth: int = 0
	var frontier: PackedStringArray = _requires_of(id)
	var guard: int = 0
	while not frontier.is_empty() and guard < 64:
		guard += 1
		depth += 1
		var next: PackedStringArray = PackedStringArray()
		for required: String in frontier:
			for deeper: String in _requires_of(required):
				if not next.has(deeper):
					next.append(deeper)
		frontier = next
	return depth

## @ace_expression
## @ace_name("Skill Id At")
## @ace_category("Upgrades")
## @ace_description("The skill id at a position in the asset's own order ("" out of range) - what a screen walks to build its nodes.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.skill_id_at({index})")
func skill_id_at(index: int) -> String:
	if _tree == null:
		return ""
	var rows: Variant = _tree.get("skills")
	if not (rows is Array) or index < 0 or index >= (rows as Array).size():
		return ""
	return str(((rows as Array)[index] as Dictionary).get("id", ""))

## @ace_expression
## @ace_name("Skill Count")
## @ace_category("Upgrades")
## @ace_description("How many skills the loaded tree holds (0 when none is loaded).")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.skill_count()")
func skill_count() -> int:
	if _tree == null:
		return 0
	var rows: Variant = _tree.get("skills")
	return (rows as Array).size() if rows is Array else 0

## @ace_expression
## @ace_name("Unlocked Count")
## @ace_category("Upgrades")
## @ace_description("How many skills have at least one level - the "12 of 30" a tree screen prints.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.unlocked_skill_count()")
func unlocked_skill_count() -> int:
	return _unlocked.size()

## @ace_expression
## @ace_name("Last Skill")
## @ace_category("Upgrades")
## @ace_description("The skill Unlock last touched - read it inside On Skill Unlocked or On Unlock Refused.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.last_skill_id()")
func last_skill_id() -> String:
	return _last_skill

## @ace_expression
## @ace_name("Tree Name")
## @ace_category("Upgrades")
## @ace_description("The loaded tree's readable name ("" when none is loaded) - a tree screen's title.")
## @ace_icon("res://eventsheet_addons/upgrades/icon.svg")
## @ace_codegen_template("Upgrades.skill_tree_name()")
func skill_tree_name() -> String:
	return str(_tree.get("tree_name")) if _tree != null and _tree.get("tree_name") != null else ""

func _ensure(id: String) -> Dictionary:
	if not _upgrades.has(id):
		_upgrades[id] = {"base_cost": 10.0, "cost_growth": 1.0, "max_level": 1, "per_level": 1.0, "mode": "add", "tag": "", "level": 0}
	return _upgrades[id]

func _is_maxed(record: Dictionary) -> bool:
	# True when an upgrade is at its cap (max_level -1 means never).
	return int(record.max_level) >= 0 and int(record.level) >= int(record.max_level)

func _cost_of(id: String) -> float:
	# The next-level price, or -1 when maxed / undefined.
	if not _upgrades.has(id):
		return -1.0
	var record: Dictionary = _upgrades[id]
	if _is_maxed(record):
		return -1.0
	return float(record.base_cost) * pow(float(record.cost_growth), int(record.level))

func _effect_of(id: String) -> float:
	# One upgrade's current stacked effect: level*per_level for add mode, per_level^level for mult mode.
	if not _upgrades.has(id):
		return 0.0
	var record: Dictionary = _upgrades[id]
	if str(record.mode) == "mult":
		return pow(float(record.per_level), int(record.level))
	return float(record.level) * float(record.per_level)

func _skill_row(id: String) -> Dictionary:
	# One skill row of the loaded tree; {} when no tree is loaded or the id is not one of its ids.
	if _tree == null:
		return {}
	var rows: Variant = _tree.get("skills")
	if not (rows is Array):
		return {}
	for entry: Variant in rows as Array:
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == id:
			return entry as Dictionary
	return {}

func _requires_of(id: String) -> PackedStringArray:
	# The ids a skill needs unlocked first, in the order the asset's comma-separated cell lists them.
	var out: PackedStringArray = PackedStringArray()
	for part: String in str(_skill_row(id).get("requires", "")).split(","):
		var required: String = part.strip_edges()
		if not required.is_empty() and not out.has(required):
			out.append(required)
	return out

func _points() -> int:
	# The unspent points, wherever they are kept.
	var ledger: Node = _points_ledger()
	if ledger != null:
		return int(ledger.balance(_points_account))
	return _skill_points

func _set_points(value: int) -> void:
	var ledger: Node = _points_ledger()
	if ledger != null:
		ledger.set_amount(_points_account, float(value))
		return
	_skill_points = maxi(value, 0)

func _earn_points(amount: int) -> void:
	var ledger: Node = _points_ledger()
	if ledger != null:
		ledger.add(_points_account, float(amount))
		return
	_skill_points = maxi(_skill_points + amount, 0)

func _spend_points(amount: int) -> void:
	var ledger: Node = _points_ledger()
	if ledger != null:
		ledger.spend(_points_account, float(amount))
		return
	_skill_points = maxi(_skill_points - amount, 0)

func _skill_cost(id: String) -> int:
	# What one level of a skill costs in points (0 when the id is not in the tree).
	return int(_skill_row(id).get("cost", 0))

func _skill_max_level(id: String) -> int:
	# How many levels a skill can take. A blank or zero cell means a one-off perk.
	return maxi(int(_skill_row(id).get("max_level", 1)), 1)

func _can_unlock(id: String) -> bool:
	# The three questions an unlock has to answer yes to: the id is in the tree, it is not already
	# at its cap, every id it requires is unlocked, and the points are there.
	if _skill_row(id).is_empty():
		return false
	if int(_unlocked.get(id, 0)) >= _skill_max_level(id):
		return false
	for required: String in _requires_of(id):
		if int(_unlocked.get(required, 0)) <= 0:
			return false
	return _points() >= _skill_cost(id)

func _grants_of(id: String) -> Array:
	# One `grants` cell as modifier rows: {stat, mode, amount, per_level}. The grammar is the
	# StatForge modifier written as words - `<stat> <op><amount>` with an optional ` per level`,
	# several separated by `;`. `x` and `*` multiply, `+` and `-` add, `=` overrides.
	var rows: Array = []
	for part: String in str(_skill_row(id).get("grants", "")).split(";"):
		var text: String = part.strip_edges()
		if text.is_empty():
			continue
		var per_level: bool = text.to_lower().ends_with(" per level")
		if per_level:
			text = text.substr(0, text.length() - 10).strip_edges()
		var split_at: int = text.rfind(" ")
		if split_at <= 0:
			continue
		var stat: String = text.substr(0, split_at).strip_edges()
		var amount_text: String = text.substr(split_at + 1).strip_edges()
		var mode: String = "add"
		if amount_text.begins_with("x") or amount_text.begins_with("*"):
			mode = "multiply"
			amount_text = amount_text.substr(1)
		elif amount_text.begins_with("="):
			mode = "override"
			amount_text = amount_text.substr(1)
		elif amount_text.begins_with("+"):
			amount_text = amount_text.substr(1)
		if stat.is_empty() or not amount_text.is_valid_float():
			continue
		rows.append({"stat": stat, "mode": mode, "amount": float(amount_text), "per_level": per_level})
	return rows

func _apply_grants(id: String) -> void:
	# Pushes one skill's grants onto the stats node as StatForge buffs - one buff per stat, keyed
	# by skill and stat so the next level REPLACES the last one rather than stacking beside it.
	# Does nothing when no stats node was named, which is the whole opt-out.
	if _stats == null or not is_instance_valid(_stats) or not _stats.has_method("add_buff"):
		return
	var level: int = int(_unlocked.get(id, 0))
	if level <= 0:
		return
	for grant: Dictionary in _grants_of(id):
		var amount: float = float(grant["amount"])
		if bool(grant["per_level"]):
			amount = pow(amount, level) if str(grant["mode"]) == "multiply" else amount * float(level)
		_stats.add_buff("skill:%s:%s" % [id, str(grant["stat"])], str(grant["stat"]), amount,
				str(grant["mode"]), "skill", SKILL_SOURCE, 0.0)

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	return {
		"upgrades": _upgrades.duplicate(true),
		"unlocked": _unlocked.duplicate(true),
		"skill_points": _skill_points
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_upgrades = (state.get("upgrades", {}) as Dictionary).duplicate(true)
	_unlocked = (state.get("unlocked", {}) as Dictionary).duplicate(true)
	_skill_points = int(state.get("skill_points", 0))
	for id: String in _unlocked:
		_apply_grants(id)

# Upgrades: register as the Upgrades autoload. Define Upgrade sets an upgrade's cost curve, max level, per-level effect, mode (add or mult), and tag. Try Purchase(id, budget) buys the next level if it fits the budget, firing On Upgrade Bought (read Last Cost, then Spend it) or On Purchase Failed. Total Multiplier(tag) and Total Bonus(tag) roll every upgrade with a tag into one number. The SKILL TREE half answers from a SkillTreeResource (.tres): Load Skill Tree, then Is Unlocked / Requires / Can Unlock / Can Afford / Unlock / Respec, with skill points held here or in a Currency Ledger account. This pack is an event sheet - extend it by editing it.
