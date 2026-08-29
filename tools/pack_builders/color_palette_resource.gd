# Pack builder - color_palette_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## ColorPaletteResource: several colour SETS in one .tres asset, so a player who cannot tell two
## colours apart can pick a set that they can. Each set is one column of colours; `role_names` says
## what each position in that column means, and every set fills the same roles in the same order.
## The Use Palette action loads one of these assets, and the palette parameter's editor draws the
## sets side by side, so the choice is made by LOOKING rather than by reading file names.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "ColorPaletteResource"
	sheet.class_description = "Several colour sets in one data asset - one set per kind of colour vision, each filling the same roles in the same order. Load it with the Use Palette action; the palette parameter draws every set side by side."
	sheet.variables = {
		"palette_name": {"type": "String", "default": "palette", "exported": true,
			"attributes": {"tooltip": "A label for your own reference (nothing reads it).",
				"header": "Colour Palette", "header_color": "#7bc96f",
				"info": "One entry in Set Names per set, one entry in Set Colors per set, and every set holds one colour per entry in Role Names, in that order."}},
		"role_names": {"type": "PackedStringArray", "default": [], "exported": true,
			"attributes": {"tooltip": "What each position in a set means (\"Danger\", \"Safe\", \"Neutral\"). Every set fills these roles in this order."}},
		"set_colors": {"type": "Array[PackedColorArray]", "default": [], "exported": true,
			"attributes": {"tooltip": "One colour array per set, in the same order as Set Names. Inside an array the colours follow Role Names."}},
		"set_names": {"type": "PackedStringArray", "default": [], "exported": true,
			"attributes": {"tooltip": "One name per colour set (\"Default\", \"Deuteranopia\", \"Protanopia\"). This is the name the player picks."}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/color_palette_resource/color_palette_resource",
		"res://eventsheet_addons/color_palette_resource/icon.svg")
