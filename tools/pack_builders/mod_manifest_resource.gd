# Pack builder - mod_manifest_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## ModManifest: what a mod says about itself, as a file.
##
## A mod folder needs a name to show in a list, a version so two of them can be told apart, an
## author to credit, a line about what it replaces, and one honest flag: whether it carries code.
## That is five fields, and every game that has ever supported mods has invented its own spelling
## of them.
##
## TWO SPELLINGS, ONE SHAPE. A modder writing by hand drops a `mod.json` in the folder, because
## JSON is what a modder outside Godot can write in any text editor. A modder working inside Godot
## saves a `mod.tres` from this class instead and fills the fields in the Inspector. The Mods pack
## reads both into the same record, so nothing downstream knows which was used.
##
## THE SCRIPTS FLAG IS A DECLARATION, NOT A GUARANTEE. It is what the mod SAYS about itself, and a
## data-only load checks the mod's actual contents as well - a pack file's own file list, a mod
## folder's own files - so a manifest claiming no code cannot smuggle any in.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "ModManifest"
	sheet.class_description = "What a mod says about itself, as a file: its name, its version, its author, what it replaces, and whether it carries code. Save one as mod.tres beside a mod's files, or write the same five fields as a mod.json - the Mods pack reads both into the same record."
	sheet.addon_category = "Mods"
	sheet.addon_tags = PackedStringArray(["mods", "resource", "files"])
	sheet.variables = {
		"mod_name": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "The name the mod is shown and addressed by - what a mod list prints and what Mod Is Loaded, Enable Mod and Unload Mod are given. Leave it blank and the folder's own name is used.",
				"header": "Mod", "header_color": "#5f9ea0",
				"info": "These five fields are the whole manifest. A modder outside Godot writes the same five into a mod.json instead."}},
		"version": {"type": "String", "default": "1.0", "exported": true,
			"attributes": {"tooltip": "The mod's own version, in whatever spelling its author uses. Shown beside the name in a mod list; nothing here compares two of them."}},
		"author": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "Who made it - the credit line a mod list shows."}},
		"replaces": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "What this mod replaces, in the author's own words (\"the sword icons\", \"res://data/items/sword.tres\"). Nothing reads it: it is the sentence a player reads before switching two mods on together."}},
		"scripts": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Tick this when the mod carries code. A data-only load refuses it, and a load that allows code says so in the row. Leaving it false does not hide code: the loader reads the mod's actual files as well."}}
	}
	var reading: RawCodeRow = RawCodeRow.new()
	reading.code = "\n".join(PackedStringArray([
		"# The JSON spelling of the same five fields, so a manifest filled in the Inspector can be",
		"# written out as the mod.json a modder outside Godot edits. The keys are the ones the Mods",
		"# pack reads, written here once so the two spellings cannot drift apart.",
		"func to_json_text() -> String:",
		"\treturn JSON.stringify({",
		"\t\t\"name\": mod_name,",
		"\t\t\"version\": version,",
		"\t\t\"author\": author,",
		"\t\t\"replaces\": replaces,",
		"\t\t\"scripts\": scripts,",
		"\t}, \"\\t\")"
	]))
	sheet.events.append(reading)
	return Lib.save_pack(sheet, "res://eventsheet_addons/mod_manifest_resource/mod_manifest")
