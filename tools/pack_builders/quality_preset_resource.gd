# Pack builder - quality_preset_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## QualityPreset: one graphics quality word - Low, Medium, High - as a FILE. The word is not a
## setting of its own and is never saved anywhere: it is a set of values over settings that already
## exist, so picking one writes msaa, resolution scale and debanding exactly as nudging those three
## by hand would, and a save file carries the three values rather than the word.
##
## Everything follows from the file being the truth:
##   - the choices are the .tres files in res://settings/quality/, so ADDING a preset is adding a
##     file and nothing else has to be told;
##   - a graphics option declared later grows a field in every preset file, because the fields ARE
##     the keys of `values` and the plugin fills in the ones a preset has not answered yet;
##   - "Custom" is worked out by comparing the values in force against each file, never stored, so
##     the word cannot fall out of step with what the game is actually doing;
##   - deleting a preset file cannot break anyone's save - their values still load, and the label
##     simply reads Custom.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "QualityPreset"
	sheet.class_description = "One graphics quality word as a file - the values it stands for, over settings that already exist. Drop it in res://settings/quality/ and it joins the Apply Quality dropdown, the options menu and the quality label without being registered anywhere."
	sheet.variables = {
		"preset_name": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "The word a player sees (\"Medium\"). Leave it blank and the file's own name is used.",
				"header": "Quality Preset", "header_color": "#7bc96f",
				"info": "Settings holds the values; this file just says which values one word stands for. Every key of Values is a setting declared somewhere in your game."}},
		"rank": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "How heavy this preset is - 0 lightest. \"One step lower\" walks this order, so give low/medium/high 0/1/2."}},
		"values": {"type": "Dictionary", "default": {}, "exported": true,
			"attributes": {"tooltip": "Setting name to the value this preset gives it. Each key also shows as its own field above."}}
	}
	var fields: RawCodeRow = RawCodeRow.new()
	fields.code = "\n".join(PackedStringArray([
		"# Every key of `values` shows in the Inspector as a field of its own, named and typed by what",
		"# is stored under it. That is what makes a graphics option declared today an ordinary row in",
		"# every preset file tomorrow: the plugin adds the key, and the field is there. Nothing is",
		"# stored twice - the fields are editor-only views onto the one exported dictionary.",
		"func _get_property_list() -> Array[Dictionary]:",
		"\tvar shown: Array[Dictionary] = []",
		"\tfor setting_name: String in values:",
		"\t\tshown.append({\"name\": \"settings/%s\" % setting_name, \"type\": typeof(values[setting_name]),",
		"\t\t\t\"usage\": PROPERTY_USAGE_EDITOR})",
		"\treturn shown",
		"",
		"func _get(property: StringName) -> Variant:",
		"\tvar field: String = str(property)",
		"\tif not field.begins_with(\"settings/\"):",
		"\t\treturn null",
		"\treturn values.get(field.trim_prefix(\"settings/\"))",
		"",
		"func _set(property: StringName, value: Variant) -> bool:",
		"\tvar field: String = str(property)",
		"\tif not field.begins_with(\"settings/\"):",
		"\t\treturn false",
		"\tvalues[field.trim_prefix(\"settings/\")] = value",
		"\treturn true"
	]))
	sheet.events.append(fields)
	return Lib.save_pack(sheet, "res://eventsheet_addons/quality_preset_resource/quality_preset",
		"res://eventsheet_addons/quality_preset_resource/icon.svg")
