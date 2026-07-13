# Pack builder - stat_sheet_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## StatSheetResource: a whole stat loadout as a .tres asset - base values and buff rows
## edited as Inspector grids, applied in one StatForge "Load Stat Sheet" action. Author a
## class (Knight.tres), an enemy tier (EliteGoblin.tres), or a difficulty preset
## (Nightmare.tres) once and hand it to designers: the grids, headers, and hints below are
## the Inspector Designer controls that keep the asset self-explanatory.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "StatSheetResource"
	sheet.class_description = "A stat loadout as a data asset: base values plus buff rows, edited as Inspector grids and applied with StatForge's Load Stat Sheet action. Author classes, enemy tiers, and difficulty presets as .tres files."
	sheet.variables = {
		"sheet_name": {"type": "String", "default": "loadout", "exported": true,
			"attributes": {"tooltip": "A label for your own reference (StatForge does not read it).",
				"header": "Stat Sheet", "header_color": "#7bc96f",
				"info": "Applied by StatForge > Load Stat Sheet: bases set the starting numbers, then the buff rows are added top to bottom."}},
		"bases": {"type": "Array", "default": [], "exported": true,
			"attributes": {"tooltip": "The starting value of each stat before any buffs (speed 100, hp 50...).",
				"drawer": "table", "table_columns": [{"name": "stat", "type": "String"}, {"name": "value", "type": "float"}]}},
		"buffs": {"type": "Array", "default": [], "exported": true,
			"attributes": {"tooltip": "One row per buff, applied top to bottom. mode: add / multiply / override (highest override wins). tags: comma-separated labels for bulk removal. source: who applied it. duration: seconds until it expires (0 = permanent).",
				"drawer": "table", "table_columns": [{"name": "buff_id", "type": "String"}, {"name": "stat", "type": "String"}, {"name": "value", "type": "float"}, {"name": "mode", "type": "String"}, {"name": "tags", "type": "String"}, {"name": "source", "type": "String"}, {"name": "duration", "type": "float"}]}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/stat_sheet_resource/stat_sheet_resource")
