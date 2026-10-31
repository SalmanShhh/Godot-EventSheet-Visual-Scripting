## @ace_tags(quest, objective, resource)
## @ace_category("Quest")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/quest_resource/icon.svg")
class_name QuestResource
extends Resource
## One quest as a data asset: its id, title, objectives (name + how many are needed), an optional next quest to chain into, and a reward note. Start it with the Quests autoload's Start Quest action - the data-driven alternative to building a quest out of actions.

## Quest id started automatically when this one completes; blank ends the line.
@export_group("Chain")
@export var next_quest: String = ""
## Unique id the quest is tracked by, such as bridge_repair.
@export_group("Identity")
@export var quest_id: String = "quest"
## The name the player reads in the quest log. Read it back with the Quest Title expression.
@export var title: String = ""
## One row per objective: its name and how many are needed.
@export_group("Objectives")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:name=String,needed=int") var objectives: Array = []
## Plain note about the payout, shown by your own UI; the pack never grants it.
@export_group("Reward")
@export var reward_note: String = ""
