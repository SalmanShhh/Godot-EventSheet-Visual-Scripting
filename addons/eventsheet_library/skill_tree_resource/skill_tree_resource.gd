## @ace_tags(skill, progression, resource)
## @ace_category("Upgrades")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/skill_tree_resource/icon.svg")
class_name SkillTreeResource
extends Resource
## A skill tree as a data asset: every node's id, name, cost in skill points, the nodes it requires first, how many levels it can take, and the stat modifiers it grants. Load it into the Upgrades autoload with Load Skill Tree - the data-driven alternative to a hand-written unlocked table and a requires loop.

## Skill points a fresh save begins with.
@export_group("Identity")
@export_range(0, 999, 1) var starting_points: int = 0
## A readable name for this tree ("Warrior", "Ship upgrades"), read back with the Tree Name expression for a screen's title.
@export var tree_name: String = "skills"
## One row per skill: id, name, cost, requirements, max level and what it grants.
@export_group("Skills")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:id=String,name=String,cost=int,requires=String,max_level=int,grants=String,column=int,row=int") var skills: Array = []
