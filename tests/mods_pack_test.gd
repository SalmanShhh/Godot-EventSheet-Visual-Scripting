# Godot EventSheets - the Mods pack, driven over real files.
#
# Mod support is a promise about somebody else's files, so almost nothing here is read off a
# descriptor: a folder of fixtures is written under user://, the shipped director is pointed at it,
# and what it does is pinned by value.
#
#   1. THE MANIFEST, BOTH SPELLINGS. A mod.json a modder wrote in a text editor and a mod.tres a
#      modder saved from ModManifest must arrive as the SAME record, because everything downstream
#      is written against one shape and would otherwise quietly know which was used.
#   2. THE DATA-ONLY REFUSAL. The whole difference between the two tiers is one question - does this
#      mod carry code - asked of the mod's OWN CONTENTS. It is asked here three ways: of a file list
#      with no disk in it (the index a pack file hands back), of a real .zip written by the test and
#      read without loading it, and of a folder mod whose manifest claims innocence while a .gd sits
#      in it.
#   3. LOAD ORDER. Named mods first in the order they were named, everything else behind them in
#      name order - the same on two machines, which is the only reason a load order is worth having.
#   4. THE ENABLE STATE THROUGH SETTINGS. A stub settings object stands in for the Game Settings
#      autoload, and the point is that the switched-off list survives being written and read back by
#      a fresh director, because that is what a player expects of a checkbox.
#   5. WHAT CANNOT BE DONE IS SAID. A pack file cannot be unloaded while the game runs, so the row
#      must refuse with that reason rather than half-doing it.
#   6. THE DOORS ONTO CONTENT. Mod Folder, Mod Folders and Mod Content Problems are what points the
#      folder-reading rows at a mod, so the duplicate two mods both bring is pinned as a sentence.
#   7. THE TEMPLATE THE EDITOR TOOL WRITES. It is what a game's modders read first, so its manifest
#      is read back through the pack that will read theirs, and the sentence about what a mod
#      carrying code costs the player is pinned here rather than trusted to survive an edit.
#
# There is no scene tree here: the director is built with .new(), never parented, and its _ready is
# called by hand. No fixture uses a pack file that would actually be loaded into this process -
# ProjectSettings.load_resource_pack cannot be undone, and a test that cannot be run twice is not a
# test. Values are pinned, never counts.
@tool
class_name ModsPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

## Loaded BY PATH so the test does not wait on the editor class cache having been regenerated for a
## newly added class name.
const PACK := "res://eventsheet_addons/mods/mods_addon.gd"
const MANIFEST_RESOURCE := "res://eventsheet_addons/mod_manifest_resource/mod_manifest.gd"

## Everything this test writes lives under here, and it is removed on the way in and on the way out.
const ROOT := "user://mods_pack_test"


## The Game Settings autoload as this pack talks to it: four methods, and a dictionary behind them.
## It is handed to the director directly rather than found in a tree, which is the reason
## `settings_node` is a plain member on the shipped pack.
class StubSettings:
	extends RefCounted
	var values: Dictionary = {}
	var declared: PackedStringArray = PackedStringArray()

	func set_setting(key: String, value: Variant) -> void:
		values[key] = value

	func setting_value(key: String) -> Variant:
		return values.get(key, "")

	func setting_is_declared(key: String) -> bool:
		return declared.has(key)

	func declare_setting(key: String, _default_value: Variant, _kind: String) -> void:
		declared.append(key)


static func run() -> bool:
	var passed: bool = true
	var script: GDScript = load(PACK)
	passed = _check("the mods pack loads + parses", script != null, true) and passed
	var manifest_script: GDScript = load(MANIFEST_RESOURCE)
	passed = _check("the mod manifest resource loads + parses", manifest_script != null, true) and passed
	if script == null or manifest_script == null:
		return passed
	_clear()
	_write_fixtures(manifest_script)
	passed = _both_manifest_spellings_arrive_as_one_record(script) and passed
	passed = _code_is_decided_by_the_files_not_the_claim(script) and passed
	passed = _a_zip_is_read_without_being_loaded(script) and passed
	passed = _data_only_takes_the_data_mods_and_names_the_rest(script) and passed
	passed = _the_script_tier_takes_the_one_it_refused(script) and passed
	passed = _load_order_puts_the_named_ones_first(script) and passed
	passed = _the_switched_off_list_survives_a_new_director(script) and passed
	passed = _a_pack_file_says_it_cannot_be_unloaded(script) and passed
	passed = _the_doors_onto_a_mods_content(script) and passed
	passed = _the_template_is_a_folder_a_modder_can_copy(script) and passed
	passed = _the_template_never_writes_over_somebodys_mod() and passed
	_clear()
	return passed


# ── 1. The manifest ───────────────────────────────────────────────────────────────────────────


## A mod.json and a mod.tres are two spellings of five fields. They are read here from two real
## folders and compared field by field, because a difference between them would be invisible until
## somebody's mod list showed one mod with no author.
static func _both_manifest_spellings_arrive_as_one_record(script: GDScript) -> bool:
	var director: Node = script.new()
	var written: Dictionary = director._manifest_at(ROOT.path_join("mods/big_swords"))
	var saved: Dictionary = director._manifest_at(ROOT.path_join("mods/winter_skins"))
	var nameless: Dictionary = director._manifest_at(ROOT.path_join("mods/nameless"))
	var nothing: Dictionary = director._manifest_at(ROOT.path_join("mods/not_a_mod"))
	director.free()
	return SUPPORT.pins("mods_pack_test", [
		["a mod.json gives its five fields", [written.get("name"), written.get("version"),
			written.get("author"), written.get("replaces"), written.get("scripts")],
			["Big Swords", "2.1", "Ada", "the sword icons", false]],
		["and says which kind of mod it is", str(written.get("kind")), "folder"],
		["a mod.tres gives the same five", [saved.get("name"), saved.get("version"),
			saved.get("author"), saved.get("replaces"), saved.get("scripts")],
			["Winter Skins", "0.4", "Bo", "the winter tiles", false]],
		["a manifest with no name in it is named after its folder",
			str(nameless.get("name")), "nameless"],
		["and a folder with no manifest at all is not a mod", nothing.is_empty(), true]
	])


# ── 2. The data-only question ─────────────────────────────────────────────────────────────────


## The whole tier decision, over a list of paths, with no disk in it. The `.remap` line is the one
## that matters: an exported project stores `thing.gd.remap` beside `thing.gdc`, so a reader that
## only looks at the last extension passes a pack full of code as clean.
static func _code_is_decided_by_the_files_not_the_claim(script: GDScript) -> bool:
	var director: Node = script.new()
	var carried: PackedStringArray = director._code_in(PackedStringArray([
		"res://mod/items/blade.tres", "res://mod/art/blade.png", "res://mod/cheat.gd",
		"res://mod/hook.gd.remap", "res://mod/native.dll", "res://mod/song.ogg"]))
	var clean: PackedStringArray = director._code_in(PackedStringArray([
		"res://mod/items/blade.tres", "res://mod/art/blade.png"]))
	var honest: String = director._code_reason({"scripts": true, "kind": "folder", "folder": ""})
	var quiet_folder: String = director._code_reason({"scripts": false, "kind": "folder",
		"folder": ROOT.path_join("mods/codey")})
	var data_folder: String = director._code_reason({"scripts": false, "kind": "folder",
		"folder": ROOT.path_join("mods/big_swords")})
	director.free()
	return SUPPORT.pins("mods_pack_test", [
		["every code file in a pack's own index is found, remaps included", Array(carried),
			["res://mod/cheat.gd", "res://mod/hook.gd.remap", "res://mod/native.dll"]],
		["and a list of data is a list of data", Array(clean), []],
		["a mod that admits it gets the plainer sentence", honest,
			"its manifest says it carries code, and this row loads data only"],
		["a manifest claiming no code cannot hide a .gd in the folder", quiet_folder,
			"it carries 1 code file(s), starting with cheat.gd, and this row loads data only"],
		["and a folder of data is refused nothing", data_folder, ""]
	])


## A .zip is read through Godot's own archive reader, which is what lets a data-only row refuse one
## WITHOUT loading it - and a pack that has been loaded can never be taken back out, so reading it
## first is the only order that works.
static func _a_zip_is_read_without_being_loaded(script: GDScript) -> bool:
	var director: Node = script.new()
	var index: Dictionary = director._pack_index(ROOT.path_join("mods/zippy.zip"))
	var paths: Array = Array(index.get("paths", PackedStringArray()))
	paths.sort()
	var reason: String = director._code_reason({"scripts": false, "kind": "pack",
		"path": ROOT.path_join("mods/zippy.zip")})
	var unreadable: Dictionary = director._pack_index(ROOT.path_join("mods/rubbish.pck"))
	var unreadable_reason: String = director._code_reason({"scripts": false, "kind": "pack",
		"path": ROOT.path_join("mods/rubbish.pck")})
	director.free()
	return SUPPORT.pins("mods_pack_test", [
		["a zip hands back its own file list", paths,
			["res://zippy/cheat.gd", "res://zippy/items/blade.tres"]],
		["and the code in it is the reason it is refused", reason,
			"it carries 1 code file(s), starting with res://zippy/cheat.gd, and this row loads data only"],
		["a file that is not a pack is not read as one", bool(unreadable.get("read")), false],
		["and a list that could not be read is a refusal, not a pass", unreadable_reason,
			"its file list could not be read, so a data-only row cannot tell whether it carries code"]
	])


# ── 3. Loading ────────────────────────────────────────────────────────────────────────────────


## The row a player's options screen is built on: load the folder, take what is data, and say in
## plain words why each of the others did not come.
static func _data_only_takes_the_data_mods_and_names_the_rest(script: GDScript) -> bool:
	var director: Node = script.new()
	var loaded: Array = []
	var refused: Array = []
	var changed: Array = []
	director.mod_loaded.connect(func(loaded_name: String, _version: String) -> void:
		loaded.append(loaded_name))
	director.mod_refused.connect(func(refused_name: String, reason: String) -> void:
		refused.append("%s: %s" % [refused_name, reason]))
	director.mods_changed.connect(func() -> void: changed.append(true))
	director.load_from(ROOT.path_join("mods"), true)
	var names: Array = []
	for record: Dictionary in director.each_mod():
		names.append(record.get("name"))
	var last_reason: String = director.mod_reason()
	director.free()
	return SUPPORT.pins("mods_pack_test", [
		["the data mods load, in load order", loaded, ["Big Swords", "nameless", "Winter Skins"]],
		["For Each Mod walks exactly what loaded", names,
			["Big Swords", "nameless", "Winter Skins"]],
		["the mod carrying a .gd is refused by name", refused.has(
			"Codey: it carries 1 code file(s), starting with cheat.gd, and this row loads data only"),
			true],
		["so is the zip carrying one", refused.has(
			"zippy: it carries 1 code file(s), starting with res://zippy/cheat.gd, and this row loads data only"),
			true],
		["and the pack file that is not a pack file", refused.has(
			"rubbish: its file list could not be read, so a data-only row cannot tell whether it carries code"),
			true],
		["Mod Reason answers about the last one refused", last_reason.is_empty(), false],
		["and On Mods Changed fires once for the whole folder", changed.size(), 1]
	])


## The second tier, said out loud: a mod that carries code loads only when the row asks for it, and
## then it is code running with everything the game can reach. A FOLDER mod is used here on purpose -
## a pack file would be loaded into this process and could never be taken back out.
static func _the_script_tier_takes_the_one_it_refused(script: GDScript) -> bool:
	var director: Node = script.new()
	director.load_mod(ROOT.path_join("mods/codey"), false)
	var loaded_it: bool = director.mod_is_loaded("Codey")
	var counted: int = director.mod_count()
	director.free()
	var refuser: Node = script.new()
	refuser.load_mod(ROOT.path_join("mods/codey"), true)
	var refused_it: bool = refuser.mod_is_loaded("Codey")
	var nowhere: Node = script.new()
	nowhere.load_mod(ROOT.path_join("mods/nowhere_at_all"), true)
	var nowhere_reason: String = nowhere.mod_reason()
	refuser.free()
	nowhere.free()
	return SUPPORT.pins("mods_pack_test", [
		["a script mod loads when the row allows code", loaded_it, true],
		["and it is the only mod loaded", counted, 1],
		["the same mod is refused when the row does not", refused_it, false],
		["a path with no mod at it says so rather than passing quietly", nowhere_reason,
			"there is no mod at %s" % ROOT.path_join("mods/nowhere_at_all")]
	])


## Named mods first, in the order they were named; everything else behind them in name order. Set
## after the fact, it re-lists what is already loaded, so the options screen and the next load agree.
static func _load_order_puts_the_named_ones_first(script: GDScript) -> bool:
	var director: Node = script.new()
	director.set_load_order("Winter Skins, Big Swords")
	director.load_from(ROOT.path_join("mods"), true)
	var ordered: Array = []
	for record: Dictionary in director.each_mod():
		ordered.append(record.get("name"))
	director.set_load_order("nameless")
	var relisted: Array = []
	for record: Dictionary in director.each_mod():
		relisted.append(record.get("name"))
	director.free()
	return SUPPORT.pins("mods_pack_test", [
		["the named mods load first, in the order they were named", ordered,
			["Winter Skins", "Big Swords", "nameless"]],
		["and setting the order again re-lists what is already loaded", relisted,
			["nameless", "Winter Skins", "Big Swords"]]
	])


# ── 4. Switched on, switched off ──────────────────────────────────────────────────────────────


## The player's checkbox. It is written through the settings autoload, read back by a director that
## has never seen it, and honoured by the next load - which is the whole of what "remembered" means
## here. A project with no settings autoload still switches mods off, for the session, and says
## nothing about it.
static func _the_switched_off_list_survives_a_new_director(script: GDScript) -> bool:
	var settings: StubSettings = StubSettings.new()
	var director: Node = script.new()
	director.settings_node = settings
	director.disable_mod("Big Swords")
	var written: String = str(settings.values.get("disabled_mods", ""))
	var declared_it: bool = settings.declared.has("disabled_mods")
	director.free()

	var fresh: Node = script.new()
	fresh.settings_node = settings
	fresh._ready()
	fresh.load_from(ROOT.path_join("mods"), true)
	var skipped: bool = fresh.mod_is_loaded("Big Swords")
	var still_there: bool = fresh.mod_is_loaded("Winter Skins")
	fresh.enable_mod("Big Swords")
	var after_enable: String = str(settings.values.get("disabled_mods", ""))
	fresh.free()

	var alone: Node = script.new()
	alone.disable_mod("Big Swords")
	alone.load_from(ROOT.path_join("mods"), true)
	var alone_skipped: bool = alone.mod_is_loaded("Big Swords")
	alone.free()
	return SUPPORT.pins("mods_pack_test", [
		["switching a mod off writes it into the settings", written, "Big Swords"],
		["and declares the setting when the project has not", declared_it, true],
		["a fresh director reads the list back and skips it", skipped, false],
		["while the mods the player kept still load", still_there, true],
		["switching it back on empties the list again", after_enable, ""],
		["and a project with no settings autoload still honours the choice for the session",
			alone_skipped, false]
	])


## What Godot cannot do, said in the row rather than discovered by a player. A resource pack that has
## been loaded is part of the running game's filesystem until it starts again.
static func _a_pack_file_says_it_cannot_be_unloaded(script: GDScript) -> bool:
	var director: Node = script.new()
	director._mods.append({"name": "Zippy", "kind": "pack", "path": "user://zippy.zip", "folder": ""})
	director._mods.append({"name": "Big Swords", "kind": "folder", "path": "", "folder": ""})
	director.unload_mod("Zippy")
	var pack_reason: String = director.mod_reason()
	var pack_still_loaded: bool = director.mod_is_loaded("Zippy")
	director.unload_mod("Big Swords")
	var folder_gone: bool = director.mod_is_loaded("Big Swords")
	director.unload_mod("Never Was")
	var missing_reason: String = director.mod_reason()
	director.free()
	return SUPPORT.pins("mods_pack_test", [
		["a pack file refuses to be unloaded, and says why", pack_reason,
			"it is a pack file, and a pack file cannot be unloaded while the game runs - switch it off and start again"],
		["so it is still loaded afterwards", pack_still_loaded, true],
		["a folder mod does come back out", folder_gone, false],
		["and unloading a mod nobody loaded says that instead", missing_reason,
			"no mod called \"Never Was\" is loaded"]
	])


# ── 5. The doors onto a mod's content ─────────────────────────────────────────────────────────


## Mod Folder, Mod Folders and Mod Content Problems are the whole of the additive door: they hand a
## path to the rows that already read folders of data assets, so a mod's items are read by Resources
## In Folder and checked by the same structural questions Data Folder Problems asks.
static func _the_doors_onto_a_mods_content(script: GDScript) -> bool:
	var director: Node = script.new()
	director.load_from(ROOT.path_join("mods"), true)
	var one: String = director.mod_folder("Big Swords")
	var absent: String = director.mod_folder("Never Was")
	var every: Array = director.mod_folders("items")
	var problems: String = director.mod_content_problems("items")
	director.free()
	return SUPPORT.pins("mods_pack_test", [
		["a loaded mod says where its files are", one, ROOT.path_join("mods/big_swords")],
		["a mod nobody loaded has no folder", absent, ""],
		["every mod's items folder comes back in load order, skipping those without one", every,
			[ROOT.path_join("mods/big_swords/items"), ROOT.path_join("mods/winter_skins/items")]],
		["and a file two mods both bring is named, with the winner", problems,
			"Winter Skins: blade.tres is also in Big Swords, and the one loaded last wins"]
	])


# ── 6. The template the editor tool writes ────────────────────────────────────


## The template is the first thing a game's modders read, so it is written here and then read back
## THROUGH THE PACK - the same _manifest_at that will read theirs. A template the loader cannot read
## is worse than none, and this is the only place the two ends meet.
static func _the_template_is_a_folder_a_modder_can_copy(script: GDScript) -> bool:
	var folder: String = ROOT.path_join("template")
	var receipt: Dictionary = EventSheetModTemplateTool.export_template(folder, {
		"name": "Example Mod", "version": "1.0", "author": "Ada",
		"replaces": "nothing yet", "scripts": false}, "items", true)
	var director: Node = script.new()
	var read_back: Dictionary = director._manifest_at(folder)
	director.free()
	var saved: Resource = load(folder.path_join("mod.tres"))
	var readme: String = FileAccess.get_file_as_string(folder.path_join("README.txt"))
	return SUPPORT.pins("mods_pack_test", [
		["the template is written whole", Array(receipt.get("written", PackedStringArray())),
			[folder.path_join("mod.json"), folder.path_join("README.txt"),
				folder.path_join("mod.tres")]],
		["and nothing went wrong", str(receipt.get("problem", "")), ""],
		["the loader reads the template as a mod", [read_back.get("name"), read_back.get("author"),
			read_back.get("scripts")], ["Example Mod", "Ada", false]],
		["the resource spelling carries the same name", str(saved.get("mod_name")), "Example Mod"],
		["the suggested content folder is there to put things in",
			DirAccess.dir_exists_absolute(folder.path_join("items")), true],
		["and the README says what a mod carrying code costs the player, without promising a sandbox",
			readme.contains("Godot has no sandbox to put it in"), true],
		["the receipt names the files rather than counting them",
			EventSheetModTemplateTool.receipt_words(receipt),
			"Wrote a mod template into %s (mod.json, README.txt, mod.tres)." % folder]
	])


## A folder that already holds a manifest is somebody's mod. The tool refuses it whole rather than
## writing half a template over the top, and the refusal is the sentence the status bar shows.
static func _the_template_never_writes_over_somebodys_mod() -> bool:
	var folder: String = ROOT.path_join("mods/big_swords")
	var receipt: Dictionary = EventSheetModTemplateTool.export_template(folder, {"name": "Nope"})
	var nowhere: Dictionary = EventSheetModTemplateTool.export_template("  ", {"name": "Nope"})
	return SUPPORT.pins("mods_pack_test", [
		["a folder that is already a mod is refused, and says why",
			EventSheetModTemplateTool.receipt_words(receipt),
			"%s already holds a mod.json, so nothing was written - a folder that is already a mod is somebody's work." % folder],
		["and nothing was written into it", Array(receipt.get("written", PackedStringArray())), []],
		["a template with no folder to go in says that instead",
			str(nowhere.get("problem", "")), "Give the template a folder to be written into."]
	])


# ── Fixtures ──────────────────────────────────────────────────────────────────────────────────


## The folder a player would have: two mods of data, one carrying code behind an honest-looking
## manifest, one whose manifest names nothing, a folder that is not a mod at all, a .zip with a
## script in it, and a .pck that is not one.
static func _write_fixtures(manifest_script: GDScript) -> void:
	_write(ROOT.path_join("mods/big_swords/mod.json"), JSON.stringify({
		"name": "Big Swords", "version": "2.1", "author": "Ada",
		"replaces": "the sword icons", "scripts": false}, "\t"))
	_write_resource(ROOT.path_join("mods/big_swords/items/blade.tres"))
	_write_resource(ROOT.path_join("mods/big_swords/items/shield.tres"))

	var saved: Resource = manifest_script.new()
	saved.set("mod_name", "Winter Skins")
	saved.set("version", "0.4")
	saved.set("author", "Bo")
	saved.set("replaces", "the winter tiles")
	saved.set("scripts", false)
	_make_folder(ROOT.path_join("mods/winter_skins"))
	ResourceSaver.save(saved, ROOT.path_join("mods/winter_skins/mod.tres"))
	_write_resource(ROOT.path_join("mods/winter_skins/items/blade.tres"))

	_write(ROOT.path_join("mods/nameless/mod.json"), JSON.stringify({"version": "1.0"}, "\t"))

	_write(ROOT.path_join("mods/codey/mod.json"), JSON.stringify({
		"name": "Codey", "version": "1.0", "scripts": false}, "\t"))
	_write(ROOT.path_join("mods/codey/cheat.gd"), "extends Node\n")

	_write(ROOT.path_join("mods/not_a_mod/readme.txt"), "no manifest here\n")

	_make_folder(ROOT.path_join("mods"))
	var packer: ZIPPacker = ZIPPacker.new()
	if packer.open(ROOT.path_join("mods/zippy.zip")) == OK:
		for inner: String in ["res://zippy/items/blade.tres", "res://zippy/cheat.gd"]:
			packer.start_file(inner)
			packer.write_file("[gd_resource type=\"Resource\" format=3]\n".to_utf8_buffer())
			packer.close_file()
		packer.close()
	# A file that opens and is not a pack: the case a data-only row must refuse rather than read as
	# empty, because "I could not tell" and "there is nothing in it" are different answers.
	_write(ROOT.path_join("mods/rubbish.pck"), "this is not a pack file, it is a sentence\n")


static func _write_resource(path: String) -> void:
	_make_folder(path.get_base_dir())
	ResourceSaver.save(Resource.new(), path)


static func _write(path: String, text: String) -> void:
	_make_folder(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


static func _make_folder(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)


## Removes the fixture tree, on the way in as well as on the way out - a run that crashed half way
## through must not decide what the next one sees.
static func _clear(path: String = ROOT) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for sub_name: String in DirAccess.get_directories_at(path):
		_clear(path.path_join(sub_name))
	DirAccess.remove_absolute(path)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("mods_pack_test", label, actual, expected)
