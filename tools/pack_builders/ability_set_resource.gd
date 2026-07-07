# Pack builder - ability_set_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## AbilitySetResource: a Custom Resource that holds a character's whole loadout as a .tres asset you fill in
## the Inspector - the data-driven way to define abilities. Instead of a string of Create Ability actions,
## you edit a grid of id / cooldown / max stacks / temporary / tags in the Inspector, save it as a .tres,
## and drop it on a Simple Abilities behavior (its Ability Set slot) or call Load Ability Set to swap
## loadouts at runtime. It is a plain Resource with exported fields, so it works with Godot's own Inspector
## and file system with no plugin at runtime.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "AbilitySetResource"
	sheet.class_description = "A character's ability loadout as a data asset. Fill the abilities grid in the Inspector, save as a .tres, and drop it on a Simple Abilities behavior's Ability Set slot (or call Load Ability Set) to create the whole set on ready."
	sheet.variables = {
		"abilities": {"type": "Array", "default": [], "exported": true,
			"attributes": {"tooltip": "One row per ability: its id, cooldown in seconds, max stacks (charges), temporary duration (0 = permanent), and comma-separated tags.", "drawer": "table", "table_columns": [{"name": "id", "type": "String"}, {"name": "cooldown", "type": "float"}, {"name": "max_stacks", "type": "int"}, {"name": "temporary", "type": "float"}, {"name": "tags", "type": "String"}]}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/ability_set_resource/ability_set_resource")
