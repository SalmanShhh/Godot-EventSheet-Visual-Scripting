# Pack builder - damage_type_set_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## DamageTypeSet: the kinds of damage a game deals, as a file the game owns.
##
## Fire, ice, poison, holy, bleed, psychic - every game has a different handful, and the handful
## changes twice before release. A list of them inside the plugin would be a list of somebody else's
## game, so there is none: the set is an ordinary resource, the names are yours, and adding a kind is
## typing it into an array in the Inspector.
##
## TWO LISTS READ IN STEP. `type_names` says what the kinds are called and `type_colors` says what
## colour each is drawn in, position by position, so the third name's colour is the third colour. A
## name with no colour yet reads white rather than failing, because a set half-filled while it is
## being written must still work.
##
## WHAT READS IT. The type field of the Health pack's typed-damage rows offers these names while you
## author; the HUD Kit's Pop Floating Text As takes the colour from here so a fire number is orange
## without a colour being typed into the row; and the Doctor uses it to notice a row dealing a kind
## no set in the project has heard of. NONE of them require it - a project with no set at all deals
## typed damage perfectly well and simply gets no suggestions and no colours.
##
## ONE STARTER SHIPS, beside this script: physical, fire, ice and poison, in four plain colours. It
## is a file to edit, rename, duplicate or delete, and it is the only opinion this plugin will ever
## have about what damage is made of.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "DamageTypeSet"
	sheet.class_description = "The kinds of damage your game deals, as a file you own: the names and the colour each one is drawn in. The Health pack's typed-damage rows suggest these names, the HUD Kit takes a floating number's colour from them, and nothing here is required - a game with no set still deals typed damage."
	sheet.addon_category = "Health"
	sheet.addon_tags = PackedStringArray(["damage", "health", "resource"])
	sheet.variables = {
		"set_name": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "A label for your own reference (nothing reads it). Leave it blank and the file's own name is the set's name.",
				"header": "Damage Types", "header_color": "#e0793f",
				"info": "One entry in Type Names per kind of damage, and the colour in the same position in Type Colors. A name with no colour yet is drawn white."}},
		"type_names": {"type": "PackedStringArray", "default": [], "exported": true,
			"attributes": {"tooltip": "The kinds of damage this game deals (\"fire\", \"ice\", \"bleed\"). These are the words the typed-damage rows offer while you author."}},
		"type_colors": {"type": "PackedColorArray", "default": [], "exported": true,
			"attributes": {"tooltip": "One colour per name, in the same order as Type Names. A floating damage number takes its colour from here."}}
	}
	var reading: RawCodeRow = RawCodeRow.new()
	reading.code = "\n".join(PackedStringArray([
		"# The two lists are read IN STEP - the third name's colour is the third colour - so a set",
		"# stays one thing to edit rather than a dictionary whose keys drift out of the order they",
		"# are shown in. Both answers are total: a name this set has never heard of is white and",
		"# false rather than an error, because a set being written is half-filled most of the time.",
		"func colour_of(type_name: String) -> Color:",
		"\tvar at: int = Array(type_names).find(type_name)",
		"\tif at < 0 or at >= type_colors.size():",
		"\t\treturn Color.WHITE",
		"\treturn type_colors[at]",
		"",
		"func has_type(type_name: String) -> bool:",
		"\treturn Array(type_names).has(type_name)"
	]))
	sheet.events.append(reading)
	if not Lib.save_pack(sheet, "res://eventsheet_addons/damage_type_set_resource/damage_type_set"):
		return false
	# The one starter goes out beside the class as the file to edit: four ordinary kinds in four
	# plain colours, and no monster, element or school of magic belonging to anybody's game.
	return Lib.ship_files("damage_type_set_resource",
		"res://eventsheet_addons/damage_type_set_resource/damage_type_set", PackedStringArray(["tres"]))
