# Pack builder - floating_text_styles_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## FloatingTextStyles: the ways a number pops out of a thing you hit, as a file the game owns.
##
## A damage number, a heal, a coin, a critical - the same pop with different manners. Every game
## spells that handful differently and renames it twice before release, so a list of them inside the
## plugin would be a list of somebody else's game. There is none: the styles are an ordinary
## resource, the names are yours, and adding one is typing it into an array in the Inspector.
##
## SIX LISTS READ IN STEP. `style_names` says what the manners are called, and the five beside it say
## how each is drawn - position by position, so the third name's size is the third size. A name with
## no entry yet reads as the plain default rather than failing, because a set half-filled while it is
## being written must still work.
##
## THE COLOUR HAS A SECOND DOOR. A style listed in `colour_from_damage_type` takes its colour from
## the hit rather than from this file, which is what lets a fire number be orange and an ice one blue
## without a colour being typed into either row. `colour_of` takes that colour as its second argument
## and simply prefers it for those styles - so a project with no damage types at all passes nothing,
## gets the file's own colours, and never notices the door is there.
##
## ONE STARTER SHIPS, beside this script: normal, crit and heal. It is a file to edit, rename,
## duplicate or delete, and it is the only opinion this plugin will ever have about what a damage
## number should look like.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "FloatingTextStyles"
	sheet.class_description = "The ways a number pops out of a thing you hit, as a file you own: the name of each manner and the size, colour, rise, shake and lifetime it is drawn with. A style may take its colour from the damage instead, so a fire number is orange without a colour being typed into the row."
	sheet.addon_category = "UI"
	sheet.addon_tags = PackedStringArray(["text", "damage", "hud", "resource"])
	sheet.variables = {
		"set_name": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "A label for your own reference (nothing reads it). Leave it blank and the file's own name is the set's name.",
				"header": "Floating Text Styles", "header_color": "#e0793f",
				"info": "One entry in Style Names per manner, and its size, colour, rise, shake and lifetime in the same position in the five lists below. A name with no entry yet is drawn plain."}},
		"style_names": {"type": "PackedStringArray", "default": [], "exported": true,
			"attributes": {"tooltip": "What the manners are called (\"normal\", \"crit\", \"heal\"). These are the words a pop row names."}},
		"sizes": {"type": "PackedFloat32Array", "default": [], "exported": true,
			"attributes": {"tooltip": "How much bigger than the ordinary label each manner is drawn. 1 is the size you designed, 1.6 is a critical."}},
		"colors": {"type": "PackedColorArray", "default": [], "exported": true,
			"attributes": {"tooltip": "The colour each manner is drawn in. Ignored for a style listed in Colour From Damage Type, which takes the hit's colour instead."}},
		"rises": {"type": "PackedFloat32Array", "default": [], "exported": true,
			"attributes": {"tooltip": "How far the number floats upward before it goes, in pixels."}},
		"shakes": {"type": "PackedFloat32Array", "default": [], "exported": true,
			"attributes": {"tooltip": "How hard the number shakes on its way up, in pixels. 0 is a clean rise."}},
		"lifetimes": {"type": "PackedFloat32Array", "default": [], "exported": true,
			"attributes": {"tooltip": "How long each manner stays on screen, in seconds."}},
		"colour_from_damage_type": {"type": "PackedStringArray", "default": [], "exported": true,
			"attributes": {"tooltip": "The style names whose colour comes from the DAMAGE rather than from this file - the door a typed-damage game opens so a fire number is orange and an ice one blue. Leave it empty and every style keeps its own colour."}}
	}
	var reading: RawCodeRow = RawCodeRow.new()
	reading.code = "\n".join(PackedStringArray([
		"# The lists are read IN STEP - the third name's size is the third size - so a set stays one",
		"# thing to edit rather than a dictionary whose keys drift out of the order they are shown in.",
		"# Every answer is total: a name this set has never heard of reads as the plain default rather",
		"# than an error, because a set being written is half-filled most of the time.",
		"func has_style(style_name: String) -> bool:",
		"\treturn Array(style_names).has(style_name)",
		"",
		"func size_of(style_name: String) -> float:",
		"\treturn _number(sizes, style_name, 1.0)",
		"",
		"func rise_of(style_name: String) -> float:",
		"\treturn _number(rises, style_name, 24.0)",
		"",
		"func shake_of(style_name: String) -> float:",
		"\treturn _number(shakes, style_name, 0.0)",
		"",
		"func lifetime_of(style_name: String) -> float:",
		"\treturn _number(lifetimes, style_name, 0.7)",
		"",
		"# The second door: a style listed in colour_from_damage_type prefers the colour it was HANDED",
		"# over the one written here, so one file can hold the manners while the damage types hold the",
		"# palette. A caller with no damage colour passes nothing and gets this file's own answer.",
		"func colour_of(style_name: String, damage_colour: Color = Color.WHITE) -> Color:",
		"\tif Array(colour_from_damage_type).has(style_name):",
		"\t\treturn damage_colour",
		"\tvar at: int = Array(style_names).find(style_name)",
		"\tif at < 0 or at >= colors.size():",
		"\t\treturn Color.WHITE",
		"\treturn colors[at]",
		"",
		"# One reader for the five number lists, so a list that has not been filled in yet answers with",
		"# the default that list means rather than with a zero nobody chose.",
		"func _number(list: PackedFloat32Array, style_name: String, fallback: float) -> float:",
		"\tvar at: int = Array(style_names).find(style_name)",
		"\tif at < 0 or at >= list.size():",
		"\t\treturn fallback",
		"\treturn list[at]"
	]))
	sheet.events.append(reading)
	if not Lib.save_pack(sheet, "res://eventsheet_addons/floating_text_styles_resource/floating_text_styles"):
		return false
	# The one starter goes out beside the class as the file to edit: three manners every game that
	# hits anything already has, and no rarity, element or school of magic belonging to anybody's game.
	return Lib.ship_files("floating_text_styles_resource",
		"res://eventsheet_addons/floating_text_styles_resource/floating_text_styles", PackedStringArray(["tres"]))
