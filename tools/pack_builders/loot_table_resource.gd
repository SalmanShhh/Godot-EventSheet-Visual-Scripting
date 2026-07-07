# Pack builder - loot_table_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## LootTableResource: a Custom Resource that holds a loot table's data as a .tres asset you fill in the
## Inspector - the data-driven way to author drops. Instead of building a table with a string of Add
## Entry actions, you edit a grid of item / weight / tags in the Inspector, save it as a .tres, and load
## it in one step (the LootBox "Load From Resource" action, or the Loot Table Loader behavior). It is a
## plain Resource (extends Resource) with exported fields, so it works with Godot's own Inspector and
## file system with no plugin at runtime.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "LootTableResource"
	sheet.class_description = "A loot table's drops as a data asset. Fill the entries grid in the Inspector, save as a .tres, and load it with the LootBox Load From Resource action or the Loot Table Loader behavior."
	sheet.variables = {
		"table_name": {"type": "String", "default": "loot", "exported": true,
			"attributes": {"tooltip": "The name this table registers under in the LootBox when loaded."}},
		"entries": {"type": "Array", "default": [], "exported": true,
			"attributes": {"tooltip": "One row per possible drop: the item id, its weight (higher = commoner), and comma-separated tags.", "drawer": "table", "table_columns": [{"name": "item", "type": "String"}, {"name": "weight", "type": "float"}, {"name": "tags", "type": "String"}]}},
		"pity_tag": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "Optional: a tag to guarantee after a streak of misses (leave blank for no pity)."}},
		"pity_threshold": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "How many misses before the pity tag is guaranteed (0 = off).", "range": {"min": "0", "max": "500", "step": "1"}}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/loot_table_resource/loot_table_resource")
