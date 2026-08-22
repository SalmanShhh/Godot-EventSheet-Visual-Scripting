# Pack builder - skill_tree_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## SkillTreeResource: a whole skill tree - nodes, prerequisites, costs, levels and what each node
## grants - as ONE .tres data asset you fill in the Inspector. This is the data half of the Upgrades
## pack's tree words: instead of a hand-written dictionary of unlocked ids and a loop over a requires
## list, a designer edits one grid and the Upgrades autoload answers Is Unlocked / Can Unlock /
## Unlock / Respec from it. Variants (a mage tree beside a warrior tree, a hard-mode price list) are
## other .tres files. A plain Resource (extends Resource), so it works with Godot's own Inspector and
## file system with no plugin at runtime, and opens as a TABLE SHEET in the editor.
##
## Because Inspector table cells hold scalars (a cell cannot nest an array), everything a skill needs
## lives in ONE row - the same table-drawer shape PriceTableResource and LootTableResource use. The
## two list-shaped columns are comma-separated text: `requires` names the ids that must be unlocked
## first, and `grants` names the stat modifiers unlocking applies.
##
## The `grants` grammar is the StatForge modifier written as words: `<stat> <op><amount>` with an
## optional ` per level`, several separated by `;`. `x` (or `*`) multiplies, `+` and `-` add, `=`
## overrides. So `speed x1.1 per level; jump +5` is a 10%-per-level speed buff and a flat jump bonus.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "SkillTreeResource"
	sheet.addon_version = "1.0.0"
	sheet.class_description = "A skill tree as a data asset: every node's id, name, cost in skill points, the nodes it requires first, how many levels it can take, and the stat modifiers it grants. Load it into the Upgrades autoload with Load Skill Tree - the data-driven alternative to a hand-written unlocked table and a requires loop."
	sheet.addon_category = "Upgrades"
	sheet.addon_tags = PackedStringArray(["skill", "progression", "resource"])
	sheet.variables = {
		"tree_name": {"type": "String", "default": "skills", "exported": true,
			"attributes": {"group": "Identity",
				"tooltip": "A readable name for this tree (\"Warrior\", \"Ship upgrades\"), read back with the Tree Name expression for a screen's title."}},
		"starting_points": {"type": "int", "default": 0, "exported": true,
			"attributes": {"group": "Identity",
				"tooltip": "How many skill points a fresh save begins with. Load Skill Tree hands this to the points counter, so a tree that opens with three free picks needs no extra row.",
				"range": {"min": "0", "max": "999", "step": "1"}}},
		"skills": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Skills",
				"tooltip": "One row per node of the tree. `id` is the string every action, condition and expression addresses (keep it short and unique). `name` is what the player reads. `cost` is what unlocking one level costs in skill points. `requires` names the ids that must be unlocked first, separated by commas (blank = a root node). `max_level` is how many times it can be taken (1 = a one-off perk). `grants` is what unlocking applies to a StatForge stack, written as `stat op amount` with an optional ` per level` and several separated by `;` - `x` or `*` multiplies, `+` and `-` add, `=` overrides, so `speed x1.1 per level` is a 10%-per-level speed buff. `column` and `row` place the node on a skill-tree screen; leave both at -1 to have the screen lay the tree out by depth.",
				"drawer": "table", "table_columns": [
					{"name": "id", "type": "String"},
					{"name": "name", "type": "String"},
					{"name": "cost", "type": "int"},
					{"name": "requires", "type": "String"},
					{"name": "max_level", "type": "int"},
					{"name": "grants", "type": "String"},
					{"name": "column", "type": "int"},
					{"name": "row", "type": "int"}]}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/skill_tree_resource/skill_tree_resource")
