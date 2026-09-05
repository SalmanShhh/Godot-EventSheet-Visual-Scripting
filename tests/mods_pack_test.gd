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
#      mod carry code - asked of the mod's OWN CONTENTS. It is asked here five ways: of a file list
#      with no disk in it (the index a pack file hands back), of a real .zip written by the test and
#      read without loading it, of a folder mod whose manifest claims innocence while a .gd sits in
#      it, of the TEXT of every scene and resource a mod holds (a `.tscn` is not code by its name
#      and may carry a script all the same), and of a real .pck this test packs itself - the byte
#      reader is the whole decision for a pack mod, and a fixture that is only ever a sentence
#      proves nothing about it.
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

## The file a crafted mod's script writes if anything ever builds it. Its ABSENCE is the assertion:
## a data-only load that has to run a stranger's code to find out whether it may is not a tier.
const MARKER := "user://mods_pack_test/probe/crafted_ran.txt"

## And the one a script carried inside a BINARY resource writes, for the same assertion.
const BINARY_MARKER := "user://mods_pack_test/probe/binary_ran.txt"


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
	passed = _a_scene_carrying_a_script_is_not_data(script) and passed
	passed = _a_script_hidden_in_a_scene_is_still_a_script(script) and passed
	passed = _a_binary_resource_is_not_cleared_by_its_extension(script) and passed
	passed = _a_crafted_manifest_never_gets_to_run(script) and passed
	passed = _a_real_pack_file_is_read_off_its_own_bytes(script) and passed
	passed = _a_mod_tres_that_is_not_a_manifest_keeps_its_folders_name(script) and passed
	passed = _the_load_order_tie_is_the_same_twice(script) and passed
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


## A `.tscn` and a `.tres` are not code by their name, and either may carry code all the same: a
## script written inside the file, a property whose value the engine resolves by loading a path or
## by compiling source carried in the line, a table naming a file from somewhere else. Deciding the
## tier by extension alone let every one of those through while calling it data, so the reading is
## pinned here sentence by sentence - including the two spellings that must NOT be refused, because
## a check that refuses everything is not a check.
static func _a_scene_carrying_a_script_is_not_data(script: GDScript) -> bool:
	var director: Node = script.new()
	var mine: String = "user://mods/mine"
	var clean: String = director._resource_reason("world.tscn", _scene_text([
		"[ext_resource type=\"Texture2D\" path=\"res://art/tree.png\" id=\"1\"]",
		"[node name=\"Tree\" type=\"Sprite2D\"]",
		"texture = ExtResource(\"1\")"]), mine)
	var written_inside: String = director._resource_reason("world.tscn", _scene_text([
		"[sub_resource type=\"GDScript\" id=\"GDScript_1\"]",
		"script/source = \"extends Node\""]), mine)
	var spaced: String = director._resource_reason("world.tscn", _scene_text([
		"[sub_resource type = \"CSharpScript\" id = \"S_1\"]"]), mine)
	var made: String = director._resource_reason("world.tscn", _scene_text([
		"[node name=\"Tree\" type=\"Node2D\"]",
		"script = Object(GDScript,\"script/source\":\"extends Node\")"]), mine)
	var loaded: String = director._resource_reason("world.tscn", _scene_text([
		"[node name=\"Tree\" type=\"Node2D\"]",
		"script = Resource(\"user://payload.gd\")"]), mine)
	var own_script: String = director._resource_reason("mod.tres",
		"[gd_resource type=\"Resource\" format=3]\n"
		+ "[ext_resource type=\"Script\" path=\"res://game/manifest.gd\" id=\"1\"]\n",
		mine)
	var elsewhere: String = director._resource_reason("world.tscn", _scene_text([
		"[ext_resource type=\"PackedScene\" path=\"user://elsewhere/x.tscn\" id=\"1\"]"]),
		mine)
	var beside_it: String = director._resource_reason("world.tscn", _scene_text([
		"[ext_resource type=\"Texture2D\" path=\"user://mods/mine/art.png\" id=\"1\"]"]),
		mine)
	var in_folder: String = director._resource_reason("world.tscn", _scene_text([
		"[ext_resource type=\"Script\" path=\"user://mods/mine/hack.gd\" id=\"1\"]"]),
		mine)
	var claimed_other: String = director._resource_reason("world.tscn", _scene_text([
		"[ext_resource type=\"Texture2D\" path=\"user://mods/mine/hack.gd\" id=\"1\"]"]),
		mine)
	var binary: String = director._resource_reason("world.scn", "RSRC binary bytes", mine)
	var escaped: String = director._resource_reason("world.tscn", _scene_text([
		"[sub_resource type=\"GD\\u0053cript\" id=\"1\"]"]), mine)
	director.free()
	return SUPPORT.pins("mods_pack_test", [
		["a scene of nodes and pictures is data", clean, ""],
		["a script written inside the file is not", written_inside,
			"world.tscn carries a script, and this row loads data only"],
		["nor is one whose tag is spelled with spaces around the =", spaced,
			"world.tscn carries a script, and this row loads data only"],
		["a property value that compiles source is refused", made,
			"world.tscn carries a value that builds something, and this row loads data only"],
		["so is one that loads a path", loaded,
			"world.tscn carries a value that builds something, and this row loads data only"],
		["a manifest naming the game's own class is data, which is how a mod.tres is saved",
			own_script, ""],
		["a table naming a file from outside the mod is refused", elsewhere,
			"world.tscn names user://elsewhere/x.tscn, which is outside the mod, and this row loads data only"],
		["and one naming the mod's own file is not", beside_it, ""],
		["but a script the mod brought with it is refused, inside the mod or not", in_folder,
			"world.tscn names the script user://mods/mine/hack.gd, and this row loads data only"],
		["and a tag claiming another type over a code file is refused by the file's own name",
			claimed_other, "world.tscn names the script user://mods/mine/hack.gd, and this row loads data only"],
		["a file that cannot be read as text is refused rather than cleared", binary,
			"world.scn is saved in a form this row cannot read, so it cannot be cleared of code"],
		["and so is a type spelled with an escape the engine would decode", escaped,
			"world.tscn holds an escape inside a resource tag, so it cannot be cleared of code"],
	])


## A FILE IS NOT CLEARED BY AN EXTENSION NOBODY LISTED. Godot reads a couple of dozen extensions as
## a resource, and this row knew four of them - so a StandardMaterial3D saved as `evil.material`
## with a script set on it, named by a scene the mod also ships, was never read at all and the mod
## cleared as data. The list is the resource loader's own now, so the file is opened, found to be
## bytes no text reading can clear, and refused by name.
static func _a_binary_resource_is_not_cleared_by_its_extension(script: GDScript) -> bool:
	var director: Node = script.new()
	var folder: String = ROOT.path_join("probe/binary")
	var known: bool = director._resource_extensions().has("material")
	var scene_reason: String = director._resource_reason("world.tscn",
		FileAccess.get_file_as_string(folder.path_join("world.tscn")), folder)
	var reason: String = director._code_reason({"scripts": false, "kind": "folder", "folder": folder})
	director.free()
	# The same probe rule as the crafted manifest: building the file proves it really does bring a
	# stranger's script into the game, so the refusal above is refusing something.
	var built: Resource = load(folder.path_join("evil.material"))
	var brought_a_script: bool = built != null and built.get_script() != null
	built = null
	DirAccess.remove_absolute(BINARY_MARKER)
	return SUPPORT.pins("mods_pack_test", [
		["the extensions read are the engine's own, not four written down here", known, true],
		["the scene naming the mod's own material is data", scene_reason, ""],
		["and the material it names is refused, because no text reading can clear it", reason,
			"evil.material is saved in a form this row cannot read, so it cannot be cleared of code"],
		["building it does bring a script in, so this is a real probe", brought_a_script, true],
	])


## THE MANIFEST IS NEVER BUILT. A `mod.tres` naming a script in the mod's own folder used to be
## handed to `load()` so its five fields could be asked of the object that came back - and building
## it is what RAN the script, so the stranger's `_init` had written its file by the time the walk
## that refuses the mod even started. The manifest is read as text now, and the tag naming the script
## is refused as well, so this asks for both: the mod is refused, and the marker is not there.
static func _a_crafted_manifest_never_gets_to_run(script: GDScript) -> bool:
	var director: Node = script.new()
	var record: Dictionary = director._manifest_at(ROOT.path_join("probe/crafted"))
	var refusal: String = director._code_reason(record)
	director.load_mod(ROOT.path_join("probe/crafted"), true)
	var reason: String = director.mod_reason()
	var loaded: int = director.mod_count()
	var marker_written: bool = FileAccess.file_exists(MARKER)
	director.free()
	# THE PROBE HAS TO BE A REAL ONE. Building that same manifest - which is what asking a loaded
	# object for its fields costs - runs the script and writes the marker, so "the marker is not
	# there" means the reading refused it rather than that the fixture was inert.
	var built: Resource = load(ROOT.path_join("probe/crafted/mod.tres"))
	var marker_after_building: bool = FileAccess.file_exists(MARKER)
	built = null
	DirAccess.remove_absolute(MARKER)
	var refused_for: String = "it carries 1 code file(s), starting with hack.gd, and this row loads data only"
	return SUPPORT.pins("mods_pack_test", [
		["a manifest naming a script is not read as a manifest, so the mod keeps its folder's name",
			str(record.get("name", "")), "crafted"],
		["the mod is refused for the code it brought", refusal, refused_for],
		["the row that loads it says the same", reason, refused_for],
		["and nothing was loaded", loaded, 0],
		["the script the manifest named never ran", marker_written, false],
		["and building that same manifest by hand does run it, so this is a real probe",
			marker_after_building, true],
	])


## The same question asked of a real folder on disk: a mod whose manifest says it carries no code,
## which carries no `.gd` at all, and whose one scene has a script written inside it.
static func _a_script_hidden_in_a_scene_is_still_a_script(script: GDScript) -> bool:
	var director: Node = script.new()
	var hidden: String = director._code_reason({"scripts": false, "kind": "folder",
		"folder": ROOT.path_join("probe/sneaky")})
	var honest: String = director._code_reason({"scripts": false, "kind": "folder",
		"folder": ROOT.path_join("mods/big_swords")})
	var two_code: String = director._code_reason({"scripts": false, "kind": "folder",
		"folder": ROOT.path_join("probe/two_code")})
	director.free()
	return SUPPORT.pins("mods_pack_test", [
		["a folder with no code file in it can still be refused, by what its scene carries",
			hidden, "world.tscn carries a script, and this row loads data only"],
		["and a folder of plain resources is still refused nothing", honest, ""],
		["a refusal that names one of several code files names the first in NAME order",
			two_code, "it carries 2 code file(s), starting with alpha.gd, and this row loads data only"],
	])


## THE BYTE READER, over a pack file this test packs itself. The whole data-only decision for a
## pack mod rests on reading the table Godot's exporter writes at the front of a `.pck` and then
## reading the bytes it points at - and a fixture that is only ever a sentence proves that a
## non-pack is refused, never that a real one is read. A wrong offset here would refuse every pack
## in the world while the suite stayed green.
static func _a_real_pack_file_is_read_off_its_own_bytes(script: GDScript) -> bool:
	var director: Node = script.new()
	var data_index: Dictionary = director._pack_index(ROOT.path_join("probe/tidy.pck"))
	var paths: Array = Array(data_index.get("paths", PackedStringArray()))
	paths.sort()
	var data_reason: String = director._code_reason({"scripts": false, "kind": "pack",
		"path": ROOT.path_join("probe/tidy.pck")})
	var sneaky_reason: String = director._code_reason({"scripts": false, "kind": "pack",
		"path": ROOT.path_join("probe/sneaky.pck")})
	var codey_reason: String = director._code_reason({"scripts": false, "kind": "pack",
		"path": ROOT.path_join("probe/codey.pck")})
	director.free()
	return SUPPORT.pins("mods_pack_test", [
		["a real pack file's own table is read", bool(data_index.get("read")), true],
		["and it is the files that were put in it", paths,
			["res://tidy/items/blade.tres", "res://tidy/world.tscn"]],
		["a pack of data is refused nothing", data_reason, ""],
		["a pack whose scene carries a script is refused by that scene", sneaky_reason,
			"world.tscn carries a script, and this row loads data only"],
		["and a pack carrying a code file is still refused by its name", codey_reason,
			"it carries 1 code file(s), starting with res://codey/cheat.gd, and this row loads data only"],
	])


## A `mod.tres` that is not a ModManifest at all answers about none of the five fields. `str(null)`
## is the four letters "<null>", so a plain resource saved under that name became a mod CALLED
## "<null>" - and the rule that a blank name falls back to the folder's own never fired.
static func _a_mod_tres_that_is_not_a_manifest_keeps_its_folders_name(script: GDScript) -> bool:
	var director: Node = script.new()
	var record: Dictionary = director._manifest_at(ROOT.path_join("probe/odd_tres"))
	director.free()
	return SUPPORT.pins("mods_pack_test", [
		["a resource that is not a manifest is named after its folder",
			str(record.get("name")), "odd_tres"],
		["and says nothing rather than the word null", [str(record.get("version")),
			str(record.get("author")), str(record.get("replaces"))], ["", "", ""]],
	])


## Set Load Order re-lists what is already loaded, and the row says everything not named follows in
## name order. Array.sort_custom is not stable, so a comparator answering false on every tie was
## free to swap two unnamed mods on each call - the same list, sorted twice, in two orders.
static func _the_load_order_tie_is_the_same_twice(script: GDScript) -> bool:
	var director: Node = script.new()
	director._mods = [{"name": "Zebra"}, {"name": "apple"}, {"name": "Mint"},
		{"name": "cherry"}, {"name": "Dawn"}] as Array[Dictionary]
	director.set_load_order("Mint, cherry")
	var once: Array = []
	for record: Dictionary in director.each_mod():
		once.append(record.get("name"))
	director.set_load_order("Mint, cherry")
	var twice: Array = []
	for record: Dictionary in director.each_mod():
		twice.append(record.get("name"))
	director.free()
	return SUPPORT.pins("mods_pack_test", [
		["the named ones lead, and the rest follow in name order", once,
			["Mint", "cherry", "apple", "Dawn", "Zebra"]],
		["and the same list sorted again is the same list", twice, once],
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
## after the fact, it re-lists what is already loaded, so the options screen and the next load
## agree - down to the tie, which is name order there too rather than whatever order the list
## happened to be in.
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
		["and setting the order again re-lists what is already loaded, ties and all", relisted,
			["nameless", "Big Swords", "Winter Skins"]]
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

	# A mod with no code file in it at all, whose one scene has a script written inside it. This is
	# the folder a tier decided by file extension took as data.
	_write(ROOT.path_join("probe/sneaky/mod.json"), JSON.stringify({
		"name": "Sneaky", "version": "1.0", "scripts": false}, "\t"))
	_write(ROOT.path_join("probe/sneaky/world.tscn"), _scene_text([
		"[sub_resource type=\"GDScript\" id=\"GDScript_1\"]",
		"script/source = \"extends Node\""]))

	# Two code files, written in the order that is NOT their sorted order, so the file the refusal
	# names is the walk's answer rather than the disk's.
	_write(ROOT.path_join("probe/two_code/mod.json"), JSON.stringify({
		"name": "Two", "version": "1.0", "scripts": false}, "\t"))
	_write(ROOT.path_join("probe/two_code/zebra.gd"), "extends Node\n")
	_write(ROOT.path_join("probe/two_code/alpha.gd"), "extends Node\n")

	# A BINARY resource with a script on it, and a scene that names it. Neither file is a `.gd`, and
	# `.material` was not one of the four extensions this reading used to know, so the mod cleared as
	# data and the engine built both. The script lives OUTSIDE the mod, so the mod's own file walk
	# cannot be what refuses it.
	# It extends the material class it is saved as, because `.material` is the extension the engine
	# recognises for THAT class - a plain Resource saved under that name is not saved at all.
	_write(ROOT.path_join("hostile/evil_material.gd"),
		"extends StandardMaterial3D\n\n\nfunc _init() -> void:\n"
		+ "\tvar marker: FileAccess = FileAccess.open(\"%s\", FileAccess.WRITE)\n" % BINARY_MARKER
		+ "\tif marker != null:\n\t\tmarker.store_string(\"ran\")\n\t\tmarker.close()\n")
	_write(ROOT.path_join("probe/binary/mod.json"), JSON.stringify({
		"name": "Binary", "version": "1.0", "scripts": false}, "\t"))
	var evil_script: GDScript = load(ROOT.path_join("hostile/evil_material.gd"))
	if evil_script != null:
		ResourceSaver.save(evil_script.new(), ROOT.path_join("probe/binary/evil.material"))
	_write(ROOT.path_join("probe/binary/world.tscn"), _scene_text([
		"[ext_resource type=\"Material\" path=\"%s\" id=\"1\"]" % ROOT.path_join("probe/binary/evil.material"),
		"[node name=\"Thing\" type=\"MeshInstance3D\"]",
		"material_override = ExtResource(\"1\")"]))
	# Building the fixture ran it once, which is the whole point of it. The marker starts absent.
	DirAccess.remove_absolute(BINARY_MARKER)

	# A crafted mod: a mod.tres naming a script in the mod's own folder, and a script that writes a
	# file the moment anything builds it. Hand-written rather than saved, because the whole point is
	# a file no honest tool would write.
	_write(ROOT.path_join("probe/crafted/hack.gd"), "extends Resource\n\n\nfunc _init() -> void:\n"
		+ "\tvar marker: FileAccess = FileAccess.open(\"%s\", FileAccess.WRITE)\n" % MARKER
		+ "\tif marker != null:\n\t\tmarker.store_string(\"ran\")\n\t\tmarker.close()\n")
	_write(ROOT.path_join("probe/crafted/mod.tres"),
		"[gd_resource type=\"Resource\" load_steps=2 format=3]\n\n"
		+ "[ext_resource type=\"Script\" path=\"%s\" id=\"1_h\"]\n\n" % ROOT.path_join("probe/crafted/hack.gd")
		+ "[resource]\nscript = ExtResource(\"1_h\")\nmod_name = \"Crafted\"\nversion = \"9.9\"\n")

	# A mod.tres that is not a ModManifest: every field it is asked for answers null.
	_make_folder(ROOT.path_join("probe/odd_tres"))
	ResourceSaver.save(Resource.new(), ROOT.path_join("probe/odd_tres/mod.tres"))

	# Three REAL pack files, packed here rather than described: one of data, one whose scene hides a
	# script, one carrying a code file by name.
	_write(ROOT.path_join("packed/blade.tres"), "[gd_resource type=\"Resource\" format=3]\n")
	_write(ROOT.path_join("packed/tidy.tscn"), _scene_text([
		"[node name=\"Tree\" type=\"Node2D\"]"]))
	_write(ROOT.path_join("packed/sneaky.tscn"), _scene_text([
		"[sub_resource type=\"GDScript\" id=\"GDScript_1\"]",
		"script/source = \"extends Node\""]))
	_write(ROOT.path_join("packed/cheat.gd"), "extends Node\n")
	_pack(ROOT.path_join("probe/tidy.pck"), {
		"res://tidy/items/blade.tres": ROOT.path_join("packed/blade.tres"),
		"res://tidy/world.tscn": ROOT.path_join("packed/tidy.tscn")})
	_pack(ROOT.path_join("probe/sneaky.pck"), {
		"res://sneaky/items/blade.tres": ROOT.path_join("packed/blade.tres"),
		"res://sneaky/world.tscn": ROOT.path_join("packed/sneaky.tscn")})
	_pack(ROOT.path_join("probe/codey.pck"), {
		"res://codey/cheat.gd": ROOT.path_join("packed/cheat.gd")})


## One resource file's text, head and all. Written through one helper so a fixture and an
## expectation cannot drift apart over a header line.
static func _scene_text(lines: PackedStringArray) -> String:
	return "[gd_scene format=3]\n\n" + "\n".join(lines) + "\n"


## A real `.pck`, written by the engine's own packer from files already on disk. Nothing loads it -
## a resource pack cannot be taken back out of a running process, so a test that mounted one could
## not be run twice.
static func _pack(pack_path: String, files: Dictionary) -> void:
	_make_folder(pack_path.get_base_dir())
	var packer: PCKPacker = PCKPacker.new()
	if packer.pck_start(pack_path) != OK:
		return
	var inner_paths: Array = files.keys()
	inner_paths.sort()
	for inner: String in inner_paths:
		packer.add_file(inner, str(files[inner]))
	packer.flush()


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
