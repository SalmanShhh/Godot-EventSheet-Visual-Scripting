# Pack builder - quest_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## QuestResource: one quest - its id, the title the player reads, its objectives, an optional next
## quest, and a note about the reward - as a .tres data asset you fill in the Inspector. This is the
## data-driven half of the Quest pack: instead of building a quest out of actions, a designer edits an
## objectives grid (a name and how many are needed), saves the .tres, and the Quests autoload starts it
## in one step with Start Quest. Chaining a questline is typing the next quest's id in Next Quest.
## A plain Resource (extends Resource), so it works with Godot's own Inspector and file system with no
## plugin at runtime.
##
## Because Inspector table cells hold scalars (a cell cannot nest an array), the objectives live in one
## grid of name + needed rows - the same table-drawer shape LootTableResource uses for its entries.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "QuestResource"
	sheet.addon_version = "1.0.0"
	sheet.class_description = "One quest as a data asset: its id, title, objectives (name + how many are needed), an optional next quest to chain into, and a reward note. Start it with the Quests autoload's Start Quest action - the data-driven alternative to building a quest out of actions."
	sheet.addon_category = "Quest"
	sheet.addon_tags = PackedStringArray(["quest", "objective", "resource"])
	sheet.variables = {
		"next_quest": {"type": "String", "default": "", "exported": true,
			"attributes": {"group": "Chain",
				"tooltip": "Optional: the quest id to start automatically the moment this one completes - how a questline is chained. Register that quest first (Register Quest) so the autoload knows its objectives. Leave blank to end here."}},
		"quest_id": {"type": "String", "default": "quest", "exported": true,
			"attributes": {"group": "Identity",
				"tooltip": "The id this quest is tracked under - every Quest action, condition and expression addresses it by this string. Keep it short and unique (\"bridge_repair\")."}},
		"title": {"type": "String", "default": "", "exported": true,
			"attributes": {"group": "Identity",
				"tooltip": "The name the player reads in the quest log. Read it back with the Quest Title expression."}},
		"objectives": {"type": "Array", "default": [], "exported": true,
			"attributes": {"group": "Objectives",
				"tooltip": "One row per objective: its name (the string Advance Objective addresses) and how many are needed to finish it. The quest completes when EVERY row reaches its needed count. A quest with no rows never completes on its own - abandon it or complete the questline another way.",
				"drawer": "table", "table_columns": [
					{"name": "name", "type": "String"},
					{"name": "needed", "type": "int"}]}},
		"reward_note": {"type": "String", "default": "", "exported": true,
			"attributes": {"group": "Reward",
				"tooltip": "A plain-language note about the payout (\"200 gold and the river key\"), shown in your own UI via the Quest Reward Note expression. The engine never grants it for you - hand it out in On Quest Completed."}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/quest_resource/quest_resource")
