## @ace_tags(quest, objective, resource)
## @ace_category("Quest")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/quest_resource/icon.svg")
class_name QuestResource
extends Resource
## One quest as a data asset: its id, title, objectives (name + how many are needed), an optional next quest to chain into, and a reward note. Start it with the Quests autoload's Start Quest action - the data-driven alternative to building a quest out of actions.

## Optional: the quest id to start automatically the moment this one completes - how a questline is chained. Register that quest first (Register Quest) so the autoload knows its objectives. Leave blank to end here.
@export_group("Chain")
@export var next_quest: String = ""
## The id this quest is tracked under - every Quest action, condition and expression addresses it by this string. Keep it short and unique ("bridge_repair").
@export_group("Identity")
@export var quest_id: String = "quest"
## The name the player reads in the quest log. Read it back with the Quest Title expression.
@export var title: String = ""
## One row per objective: its name (the string Advance Objective addresses) and how many are needed to finish it. The quest completes when EVERY row reaches its needed count. A quest with no rows never completes on its own - abandon it or complete the questline another way.
@export_group("Objectives")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:name=String,needed=int") var objectives: Array = []
## A plain-language note about the payout ("200 gold and the river key"), shown in your own UI via the Quest Reward Note expression. The engine never grants it for you - hand it out in On Quest Completed.
@export_group("Reward")
@export var reward_note: String = ""
