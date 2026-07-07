# Pack builder - skin_catalog_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## SkinCatalogResource: a Custom Resource that holds a whole cosmetics catalog as a .tres asset you fill
## in the Inspector - the data-driven way to author SkinVault's rarities and skins. Instead of a string
## of Register Rarity / Register Skin actions, you edit two grids in the Inspector, save it as a .tres,
## and load it in one step (the SkinVault "Load Catalog" action, or the Skin Catalog Loader behavior).
## It is a plain Resource with exported fields, so it works with Godot's own Inspector and file system.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "SkinCatalogResource"
	sheet.class_description = "A cosmetics catalog as a data asset for the SkinVault pack. Fill the rarities and skins grids in the Inspector, save as a .tres, and load it with the SkinVault Load Catalog action or the Skin Catalog Loader behavior."
	sheet.variables = {
		"rarities": {"type": "Array", "default": [], "exported": true,
			"attributes": {"tooltip": "One row per rarity: its name, a roll weight (higher = commoner), and a tier rank (higher = rarer; pity guarantees a tier at or above the pity rarity).", "drawer": "table", "table_columns": [{"name": "name", "type": "String"}, {"name": "weight", "type": "float"}, {"name": "tier", "type": "int"}]}},
		"skins": {"type": "Array", "default": [], "exported": true,
			"attributes": {"tooltip": "One row per skin: a unique id, a display name, its rarity (must match a rarity above), a cost (0 = not purchasable), and comma-separated tags.", "drawer": "table", "table_columns": [{"name": "id", "type": "String"}, {"name": "name", "type": "String"}, {"name": "rarity", "type": "String"}, {"name": "cost", "type": "float"}, {"name": "tags", "type": "String"}]}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/skin_catalog_resource/skin_catalog_resource")
