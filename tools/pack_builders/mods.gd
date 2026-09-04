# Pack builder - mods (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Mods: the folder players put their own content in, as the Mods autoload.
##
## Godot can load a pack file at run time and let its files replace the game's own, and this plugin
## already reads folders of data assets - a folder of .tres files is content, the Folder Watcher
## notices one appearing, and the data-asset rows validate what is in it. Mod support is those two
## joined by a manifest, a load order, and a list the options screen can show.
##
## TWO TIERS, SAID PLAINLY. A DATA-ONLY load takes resources, scenes, textures and sounds: before it
## loads a pack file it reads that file's own list of contents and refuses it if any of them is a
## script or a library, and before it takes a mod folder it reads the folder's files and does the
## same. A SCRIPT load takes a mod that carries code, and only when the row says so, because code in
## a mod runs with everything the game itself can reach - the player's files, their network, their
## machine. There is no sandbox here, and none is claimed: Godot has none to offer.
##
## THE MANIFEST IS THE MOD'S OWN FILE. `mod.json` for a modder working in a text editor, `mod.tres`
## saved from ModManifest for one working in Godot; five fields either way. The pack ships no list of
## mods, no folder of anybody's mods, and no opinion about what a mod may contain.
##
## THE DOORS ARE THE ROWS ALREADY HERE. Mod Folder hands back where a loaded mod's files live, so
## Resources In Folder, the Skin Vault's and Loot Loader's own folders, and Data Folder Problems all
## read a mod's content with no new vocabulary at all.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("mods", "Node", "ModsAddon",
		"The folder players put their own content in, as the Mods autoload: load every mod in a folder in load order, ask what loaded and what did not, switch one off, and walk the list for an options screen. A data-only load reads a pack file's own contents and refuses one carrying code; a script mod loads only when the row says so, and runs with everything the game can reach.",
		Lib.manifest().autoload("Mods").category("Mods").tags(["mods", "files", "content", "modding"]))
	src.note("Mods (autoload): register as the Mods autoload, then load mods from any sheet. A mod is a folder with a mod.json in it, or a .pck / .zip pack file; the manifest names it and says whether it carries code. Data only reads a pack's own contents and refuses one carrying code - and a mod that does carry code runs with everything the game can reach, because Godot has no sandbox. This pack is an event sheet - extend it by editing it.")
	src.block("block_1")
	src.block("block_2")
	src.on_ready()

	# ── Loading ───────────────────────────────────────────────────────────────────────────
	src.verb("load_from", "Load Mods From",
		"Loads every mod in a folder, in load order: a subfolder with a manifest in it, or a .pck / .zip pack file. With Data Only on, a mod carrying code is refused and says so through On Mod Refused instead of loading. A mod switched off is skipped in silence, and On Mods Changed fires once at the end.",
		[["folder", "String"], ["data_only", "bool"]])
	_default(src.sheet, "folder", "\"user://mods\"")
	_default(src.sheet, "data_only", "true")
	src.verb("load_mod", "Load Mod",
		"Loads one mod by path - a mod folder or a pack file - with the same two tiers Load Mods From uses. A path with no mod at it is refused with that reason rather than passed over.",
		[["path", "String"], ["data_only", "bool"]])
	_default(src.sheet, "path", "\"user://mods/my_mod\"")
	_default(src.sheet, "data_only", "true")
	src.verb("unload_mod", "Unload Mod",
		"Takes a FOLDER mod back out of the loaded list, so the rows that read mod folders stop seeing it. A pack file cannot be unloaded: once Godot has loaded one, its files stay in the running game, so this row refuses with that reason and the way to do it is to switch the mod off and start again.",
		[["unloading_name", "String"]])
	_default(src.sheet, "unloading_name", "\"Big Swords\"")
	src.verb("set_load_order", "Set Load Order",
		"Says which mods load first, as a comma-separated list of names. Everything not named follows in name order, and later mods replace the files earlier ones brought - which is what a load order is for. It also re-lists what is already loaded, so the list an options screen shows and the order the next load uses are the same order.",
		[["names", "String"]])
	_default(src.sheet, "names", "\"Big Swords, Winter Skins\"")

	# ── Switched on, switched off ─────────────────────────────────────────────────────────
	src.verb("enable_mod", "Enable Mod",
		"Switches a mod back on. A mod is on unless it has been switched off, so this is the way back from Disable Mod rather than something every mod needs. The choice is remembered through the Settings autoload when the project has one.",
		[["enabling_name", "String"]])
	_default(src.sheet, "enabling_name", "\"Big Swords\"")
	src.verb("disable_mod", "Disable Mod",
		"Switches a mod off: it is skipped the next time mods are loaded, and a folder mod drops out of the loaded list at once. A pack file's files are already in the running game and stay until it starts again. The choice is remembered through the Settings autoload when the project has one.",
		[["disabling_name", "String"]])
	_default(src.sheet, "disabling_name", "\"Big Swords\"")

	# ── Questions ─────────────────────────────────────────────────────────────────────────
	src.condition("mod_is_loaded", "Mod Is Loaded",
		"Whether a mod of that name is loaded right now - the check in front of using what it brought.",
		[["wanted", "String"]])
	_default(src.sheet, "wanted", "\"Big Swords\"")
	src.expression("mod_count", "Mod Count",
		"How many mods are loaded - the number on the options screen's mods line.",
		[], TYPE_INT)
	src.expression("mod_name", "Mod Name",
		"The name of the mod the last Mods event was about - the one that just loaded, or the one that was just refused.",
		[], TYPE_STRING)
	src.expression("mod_version", "Mod Version",
		"The version of the mod the last Mods event was about, as its manifest spells it.",
		[], TYPE_STRING)
	src.expression("mod_author", "Mod Author",
		"The author of the mod the last Mods event was about - the credit line beside its name.",
		[], TYPE_STRING)
	src.expression("mod_reason", "Mod Reason",
		"Why the last refused mod was refused, in plain words a player can read, and nothing at all when none has been.",
		[], TYPE_STRING)

	# ── The doors onto a mod's content ────────────────────────────────────────────────────
	src.expression("mod_folder", "Mod Folder",
		"Where a loaded mod's files live, so Resources In Folder, a Skin Vault catalog, a loot table or Data Folder Problems can be pointed straight at it. A pack file has no folder of its own - its files replace the game's by path - so this is empty for one.",
		[["wanted", "String"]], TYPE_STRING)
	_default(src.sheet, "wanted", "\"Big Swords\"")
	src.expression("mod_folders", "Mod Folders",
		"The same folder inside every loaded folder mod, in load order, skipping the mods that do not have one - hand it \"items\" and it is every mod's items folder, ready for a loop that loads each one's data assets.",
		[["subfolder", "String"]], TYPE_ARRAY)
	_default(src.sheet, "subfolder", "\"items\"")
	src.expression("mod_content_problems", "Mod Content Problems",
		"Every structural problem in the loaded mods' content, one per line, and nothing at all when it is clean: a data asset that will not load, and a file two mods both bring, where the one loaded last wins. It is the Data Folder Problems check over the mod folders, so a broken mod is named rather than crashed on.",
		[["subfolder", "String"]], TYPE_STRING)
	_default(src.sheet, "subfolder", "\"items\"")

	Lib.verb_sentences(src.sheet, {
		"load_from": "Load mods from [b]{folder}[/b], data only [b]{data_only}[/b]",
		"load_mod": "Load mod [b]{path}[/b], data only [b]{data_only}[/b]",
		"unload_mod": "Unload mod [b]{unloading_name}[/b]",
		"set_load_order": "Set load order [b]{names}[/b]",
		"enable_mod": "Enable mod [b]{enabling_name}[/b]",
		"disable_mod": "Disable mod [b]{disabling_name}[/b]",
		"mod_is_loaded": "Mod [b]{wanted}[/b] is loaded",
		"mod_folder": "folder of mod [b]{wanted}[/b]",
		"mod_folders": "every mod's [b]{subfolder}[/b] folder",
		"mod_content_problems": "mod problems in [b]{subfolder}[/b]",
	})
	# The three a new user should meet first: load the folder, ask what is in it, and read where a
	# mod's files are so the rows that read folders can be pointed at them.
	Lib.feature_verbs(src.sheet, ["load_from", "mod_is_loaded", "mod_folder"])
	return Lib.publish(src, "res://eventsheet_addons/mods/mods_addon")


## Pre-fills the last-declared verb's parameter default, so a dropped row opens with a usable value
## instead of an empty field (authoring-time metadata only - defaults never appear in the compiled
## .gd of a game that uses the row).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value
