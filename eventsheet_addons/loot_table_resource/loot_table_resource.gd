@icon("res://eventsheet_addons/loot_table_resource/icon.svg")
class_name LootTableResource
extends Resource
## A loot table's drops as a data asset. Fill the entries grid in the Inspector, save as a .tres, and load it with the LootBox Load From Resource action or the Loot Table Loader behavior.

## One row per possible drop: the item id, its weight (higher = commoner), and comma-separated tags.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:item=String,weight=float,tags=String") var entries: Array = []
## Optional: a tag to guarantee after a streak of misses (leave blank for no pity).
@export var pity_tag: String = ""
## How many misses before the pity tag is guaranteed (0 = off).
@export_range(0, 500, 1) var pity_threshold: int = 0
## The name this table registers under in the LootBox when loaded.
@export var table_name: String = "loot"
