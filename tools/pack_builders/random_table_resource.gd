# Pack builder - random_table_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## RandomTableResource: a weighted random table as a .tres asset you edit in the Inspector - the
## data-driven way to author odds. Fill a grid of value / weight rows, save it, and draw from it with
## Advanced Random's Pick From Table (which reads the resource and picks in proportion to weight). It is a
## plain Resource with exported fields, so a designer tunes drop rates by editing numbers in a grid, not
## events, and the same table can be reused anywhere.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "RandomTableResource"
	sheet.class_description = "A weighted random table as a data asset. Fill the entries grid (value + weight) in the Inspector, save as a .tres, and draw from it with Advanced Random's Pick From Table."
	sheet.variables = {
		"entries": {"type": "Array", "default": [], "exported": true,
			"attributes": {"tooltip": "One row per outcome: its value (any string - an item id, a name, a scene path) and weight (higher = commoner).", "drawer": "table", "table_columns": [{"name": "value", "type": "String"}, {"name": "weight", "type": "float"}]}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/random_table_resource/random_table_resource")
