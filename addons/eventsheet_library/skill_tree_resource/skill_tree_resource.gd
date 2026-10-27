## @ace_tags(skill, progression, resource)
## @ace_category("Upgrades")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/skill_tree_resource/icon.svg")
class_name SkillTreeResource
extends Resource
## A skill tree as a data asset: every node's id, name, cost in skill points, the nodes it requires first, how many levels it can take, and the stat modifiers it grants. Load it into the Upgrades autoload with Load Skill Tree - the data-driven alternative to a hand-written unlocked table and a requires loop.

## How many skill points a fresh save begins with. Load Skill Tree hands this to the points counter, so a tree that opens with three free picks needs no extra row.
@export_group("Identity")
@export_range(0, 999, 1) var starting_points: int = 0
## A readable name for this tree ("Warrior", "Ship upgrades"), read back with the Tree Name expression for a screen's title.
@export var tree_name: String = "skills"
## One row per node of the tree. `id` is the string every action, condition and expression addresses (keep it short and unique). `name` is what the player reads. `cost` is what unlocking one level costs in skill points. `requires` names the ids that must be unlocked first, separated by commas (blank = a root node). `max_level` is how many times it can be taken (1 = a one-off perk). `grants` is what unlocking applies to a StatForge stack, written as `stat op amount` with an optional ` per level` and several separated by `;` - `x` or `*` multiplies, `+` and `-` add, `=` overrides, so `speed x1.1 per level` is a 10%-per-level speed buff. `column` and `row` place the node on a skill-tree screen; leave both at -1 to have the screen lay the tree out by depth.
@export_group("Skills")
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:id=String,name=String,cost=int,requires=String,max_level=int,grants=String,column=int,row=int") var skills: Array = []
