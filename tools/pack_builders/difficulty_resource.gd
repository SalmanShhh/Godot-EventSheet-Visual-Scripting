# Pack builder - difficulty_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Difficulty: what a word like Easy or Hard actually CHANGES, written down as a FILE. A difficulty
## is not a global enum and not an `if` in front of every damage row: it is a name, a line for the
## menu, and a dictionary of named factors the rows multiply by where they care.
##
## Everything follows from the file being the truth:
##   - the difficulties on offer are the .tres files in a folder, so ADDING one is adding a file and
##     nothing else has to be told;
##   - a factor is asked for BY NAME and answers 1.0 when the file has no such key, so a row can ask
##     for a factor before any difficulty mentions it and go on behaving exactly as it did;
##   - the keys are whatever your game means by them - damage_taken, enemy_count, timer_scale - and
##     nothing here ships a vocabulary of them;
##   - deleting a difficulty file cannot break a save: the chosen difficulty is an ordinary setting,
##     and a name nothing answers to simply leaves every factor at 1.0.
##
## THREE STARTERS SHIP BESIDE THIS CLASS and they are files to open, not a set to use: retune them,
## rename them, duplicate one into a fourth, or delete the ones your game has no use for.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "DifficultyResource"
	sheet.class_description = "One difficulty as a file: the word a player picks, the line a menu shows under it, and the named factors your rows multiply by. Drop it in a folder and the Settings pack's Difficulty Names lists it, with nothing to register anywhere."
	sheet.variables = {
		"difficulty_name": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "The word a player sees (\"Hard\"). Leave it blank and the file's own name is used.",
				"header": "Difficulty", "header_color": "#c8935a",
				"info": "Nothing in this file changes the game on its own. A factor changes something because a row multiplied by it - Difficulty Factor \"damage_taken\" where damage is dealt, \"enemy_count\" where a wave is sized. Keys nothing reads are simply unread."}},
		"description": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "The line the menu shows under the word - what this difficulty is for, in the player's terms."}},
		"factors": {"type": "Dictionary", "default": {}, "exported": true,
			"attributes": {"tooltip": "Factor name to the number this difficulty gives it. Any keys at all; a key no difficulty writes reads as 1.0. Each key also shows as its own field above."}}
	}
	var fields: RawCodeRow = RawCodeRow.new()
	fields.code = "\n".join(PackedStringArray([
		"# Every key of `factors` shows in the Inspector as a field of its own, named and typed by",
		"# what is stored under it - which is what makes a factor invented today an ordinary row in",
		"# every difficulty file tomorrow. Nothing is stored twice: the fields are editor-only views",
		"# onto the one exported dictionary.",
		"func _get_property_list() -> Array[Dictionary]:",
		"\tvar shown: Array[Dictionary] = []",
		"\tfor factor_name: String in factors:",
		"\t\tshown.append({\"name\": \"factors/%s\" % factor_name, \"type\": typeof(factors[factor_name]),",
		"\t\t\t\"usage\": PROPERTY_USAGE_EDITOR})",
		"\treturn shown",
		"",
		"func _get(property: StringName) -> Variant:",
		"\tvar field: String = str(property)",
		"\tif not field.begins_with(\"factors/\"):",
		"\t\treturn null",
		"\treturn factors.get(field.trim_prefix(\"factors/\"))",
		"",
		"func _set(property: StringName, value: Variant) -> bool:",
		"\tvar field: String = str(property)",
		"\tif not field.begins_with(\"factors/\"):",
		"\t\treturn false",
		"\tfactors[field.trim_prefix(\"factors/\")] = value",
		"\treturn true"
	]))
	sheet.events.append(fields)
	if not Lib.save_pack(sheet, "res://eventsheet_addons/difficulty_resource/difficulty",
		"res://eventsheet_addons/difficulty_resource/icon.svg"):
		return false
	# The three starters go out beside the class as the files to open. They are the three words most
	# games start from and no game has to keep: nothing in the plugin depends on any of them being
	# there, and Use Difficulty is happy with a folder of your own.
	return Lib.ship_files("difficulty_resource",
		"res://eventsheet_addons/difficulty_resource/difficulty", PackedStringArray(["tres"]))
