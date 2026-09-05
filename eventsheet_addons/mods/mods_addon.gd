## @ace_tags(mods, files, content, modding)
## @ace_category("Mods")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/mods/icon.svg")
class_name ModsAddon
extends Node
## The folder players put their own content in, as the Mods autoload: load every mod in a folder in load order, ask what loaded and what did not, switch one off, and walk the list for an options screen. A data-only load reads a pack file's own contents and refuses one carrying code; a script mod loads only when the row says so, and runs with everything the game can reach.

## Fires once per mod that loaded, in load order. Mod Name and Mod Version answer about it.
## @ace_trigger
## @ace_name("On Mod Loaded")
signal mod_loaded(loaded_name: String, loaded_version: String)
## Fires once per mod that did NOT load, with the reason in plain words - it carries code and the
## row asked for data only, its files could not be read, there is no mod at that path, or it is a
## pack file and something asked to unload it. Mod Name and Mod Reason answer about it.
## @ace_trigger
## @ace_name("On Mod Refused")
signal mod_refused(refused_name: String, reason: String)
## Fires once after anything changes what is loaded or what is switched on - the moment a mod list
## on the options screen should be redrawn.
## @ace_trigger
## @ace_name("On Mods Changed")
signal mods_changed

## Where Load Mods From looks by default, and the folder a mod's own folder is expected under.
## Prefer user:// - a folder under res:// is packed into the export and a player cannot put
## anything in it once the game ships.
@export var mods_folder: String = "user://mods"
## The setting the switched-off mods are remembered under, when the project has the Game Settings
## autoload registered as Settings. A mod is ON unless its name is in that list, so a mod the
## player has never seen arrives enabled.
@export var settings_key: String = "disabled_mods"
## Warns about a folder that is not there, a mod folder with no manifest in it, a pack file whose
## own file list could not be read, and a name two mods both claim. On while you build, off for
## release.
@export var debug_mode: bool = false

## The Game Settings autoload, when the project has one. Resolved the first time the enabled state
## is written or read, and left null in a project that has no settings autoload - the enable rows
## then still work, for the session, and simply remember nothing. It is a plain member rather than
## a lookup buried in a function so a test (and a project with its settings under another name) can
## hand this director the object it should talk to.
var settings_node: Object = null

## What a mod is made of, once its manifest has been read: name, version, author, replaces, whether
## it declares that it carries code, which kind it is ("folder" or "pack"), the path it came from
## and the folder its files live in. Plain data, so it rides a loop, a print and a save unchanged.
var _mods: Array[Dictionary] = []

## The names Set Load Order named, in the order it named them. Everything else follows in name
## order, so a partial order is a partial order rather than a reshuffle.
var _order: PackedStringArray = PackedStringArray()

## The mods that are switched OFF, by name. Absent means on.
var _disabled: Dictionary = {}

## The mod the last event was about: what Mod Name, Mod Version, Mod Author and Mod Reason answer.
var _about: Dictionary = {"name": "", "version": "", "author": "", "reason": ""}

## The file extensions that are CODE. A mod carrying any of these can run anything the game itself
## can, which is the whole difference between the two tiers.
const CODE_EXTENSIONS: Array[String] = [
	"gd", "gdc", "gde", "cs", "gdextension", "gdnlib", "gdns", "dll", "so", "dylib", "wasm"]

## Every extension the engine reads as a RESOURCE TABLE: a scene or a resource, saved as text or in
## the binary form. A file with one of these names is not code by its name, and it may carry code
## all the same - a scene holding a script written inside it, a node property whose value the engine
## resolves by loading a path or by compiling source carried in the file, a resource naming a
## script beside it. Godot builds all of that the moment the file is loaded, so a mod carrying one
## runs a stranger's code while every file in it is called data. These are therefore READ rather
## than merely named, which is the difference between the tier's promise and its name.
##
## THE LIST IS THE ENGINE'S OWN, ASKED AT RUN TIME. Godot recognises a couple of dozen of these -
## `.material`, `.mesh`, `.theme`, `.shape`, `.stylebox`, `.translation` beside the familiar four -
## and a list typed out here is a hole shaped exactly like whichever ones it forgot: a
## StandardMaterial3D saved as `evil.material` with a script set on it, named by a scene the mod
## also ships, was cleared as data because nothing here had heard of that extension. So the answer
## comes from the resource loader itself, which means it is the list of the engine the game actually
## ships with rather than the list of the engine this was written against. Asked once and kept,
## because it cannot change while the game runs.
var _resource_extension_cache: PackedStringArray = PackedStringArray()

## The two heads a resource table written as TEXT begins with. A file that begins with neither is
## the binary form, or something else entirely, and its table cannot be read as text at all - an
## unreadable file is not a file that has been cleared.
const RESOURCE_HEADS: Array[String] = ["[gd_scene", "[gd_resource"]

## The two tags a resource table names other resources with, and the tail every script type's name
## ends in - `Script`, `GDScript`, `CSharpScript`. Read as a tail rather than as a list, because a
## script type this reading has never heard of is exactly the one a crafted file would name.
const RESOURCE_TAGS: Array[String] = ["ext_resource", "sub_resource"]
const SCRIPT_TYPE_TAIL: String = "Script"

## The two constructors a resource file's own VALUES may be written with that BUILD something. A
## body line carries no tag at all: `script = Resource("user://payload.gd")` is a property the
## engine resolves by loading that path, and `script = Object(GDScript,"script/source":"...")` is
## one it resolves by compiling the source carried in the line. `ExtResource(` and `SubResource(`
## are the honest pair and are deliberately not here - each names an entry in the file's own table,
## which the tag reading has already answered for. Both are matched on a WORD BOUNDARY, which is
## exactly what keeps those two out: `ExtResource(` holds `Resource(` with a letter in front of it.
const BUILDING_MAKERS: Array[String] = ["Object(", "Resource("]

## The one glyph a resource tag may not carry, and the one spelling a path may climb out of a
## folder with. Godot's saver writes no escape into a tag while its parser decodes every escape it
## finds in one, so a type spelled with an escape in the middle of it is `GDScript` to the engine
## and something else to a reading that compares the letters as written. And `res://../payload.gd`
## begins with `res://` and names a file beside the project. Neither is second-guessed.
const ESCAPE_GLYPH: String = "\\"
const CLIMB_OUT: String = ".."

## The four bytes a Godot pack file opens with, as one little-endian number - "GDPC".
const PACK_MAGIC: int = 0x43504447

## The newest pack format this reader understands. A file that says a higher number is not read at
## all, and a data-only row refuses it rather than guessing at its contents.
const PACK_FORMAT_MAX: int = 4

## The two bits a pack's own flags word may set. An encrypted DIRECTORY cannot be read without the
## game's key, so its file list is not a list this row has. `relative` says every file's place is
## measured from the base the header gives rather than from the front of the file - which is how
## the engine writes a pack today, and taking the places as written finds the wrong bytes.
const PACK_DIRECTORY_ENCRYPTED: int = 1
const PACK_PLACES_ARE_RELATIVE: int = 2

## The format from which the file list is written at a place of its own near the END of the pack
## rather than straight after the header, and file paths inside it are written without their
## `res://`. Both are read here, because a pack a player downloads was written by whichever engine
## the game that made it shipped with.
const PACK_FORMAT_WITH_DIRECTORY: int = 4

## The bit a pack entry's flags word sets when the exporter encrypted that file. Its bytes cannot
## be read without the game's own key, and a file that cannot be read is not one that has been
## cleared of code.
const PACK_ENTRY_ENCRYPTED: int = 1

## The most bytes of one scene or resource this reading will take in at once. A table big enough to
## matter is a table somebody built to be read instead of the mod, and a refusal is the safe answer
## either way.
const MOST_RESOURCE_BYTES: int = 32 * 1024 * 1024
## Every mod a folder holds, in load order: a subfolder with a manifest is a folder mod, a .pck or
## .zip in it is a pack mod. Named mods come first in the order Set Load Order named them, and the
## rest follow in name order - ignoring case and reading digits as numbers, so the order is the one
## a player would have written down, and the same one on two machines.
## @ace_hidden
func _mods_in(folder: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(folder):
		if debug_mode:
			push_warning("Mods: there is no folder at %s, so nothing was loaded from it." % folder)
		return found
	var paths: PackedStringArray = PackedStringArray()
	for sub_name: String in DirAccess.get_directories_at(folder):
		paths.append(folder.path_join(sub_name))
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.get_extension().to_lower() in ["pck", "zip"]:
			paths.append(folder.path_join(file_name))
	paths.sort()
	for path: String in paths:
		var record: Dictionary = _manifest_at(path)
		if not record.is_empty():
			found.append(record)
	var order: Array = Array(_order)
	var behind: int = order.size() + 1
	found.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_at: int = order.find(str(first.get("name", "")))
		var second_at: int = order.find(str(second.get("name", "")))
		if first_at != second_at:
			return (first_at if first_at >= 0 else behind) < (second_at if second_at >= 0 else behind)
		return str(first.get("name", "")).naturalnocasecmp_to(str(second.get("name", ""))) < 0)
	return found
## The settings autoload, found once. A director that is not in a tree yet (a test, or a tool)
## keeps whatever was handed to it instead of asking the tree for a node it has no way to reach.
## @ace_hidden
func _settings() -> Object:
	if settings_node != null:
		return settings_node
	if is_inside_tree():
		settings_node = get_node_or_null("/root/Settings")
	return settings_node

## Runs this event's actions once per LOADED mod, in load order - the mod list on the options
## screen, as one row. Read the current one as `mod`, then take `mod.name`, `mod.version`,
## `mod.author`, `mod.kind` ("folder" or "pack") and `mod.folder` straight off it.
## @ace_looping(mod)
## @ace_name("For Each Mod")
## @ace_category("Mods")
func each_mod() -> Array:
	return _mods.duplicate()

func _ready() -> void:
	# The player's own choice about what is switched off outlives the session, so it is read back
	# before any row asks to load anything.
	_recall_disabled()

## @ace_action
## @ace_featured
## @ace_name("Load Mods From")
## @ace_category("Mods")
## @ace_description("Loads every mod in a folder, in load order: a subfolder with a manifest in it, or a .pck / .zip pack file. With Data Only on, a mod carrying code is refused and says so through On Mod Refused instead of loading. A mod switched off is skipped in silence, and On Mods Changed fires once at the end.")
## @ace_display_template("Load mods from [b]{folder}[/b], data only [b]{data_only}[/b]")
## @ace_icon("res://eventsheet_addons/mods/icon.svg")
## @ace_codegen_template("Mods.load_from({folder}, {data_only})")
func load_from(folder: String, data_only: bool) -> void:
	for record: Dictionary in _mods_in(folder):
		_load_record(record, data_only)
	mods_changed.emit()

## @ace_action
## @ace_name("Load Mod")
## @ace_category("Mods")
## @ace_description("Loads one mod by path - a mod folder or a pack file - with the same two tiers Load Mods From uses. A path with no mod at it is refused with that reason rather than passed over.")
## @ace_display_template("Load mod [b]{path}[/b], data only [b]{data_only}[/b]")
## @ace_icon("res://eventsheet_addons/mods/icon.svg")
## @ace_codegen_template("Mods.load_mod({path}, {data_only})")
func load_mod(path: String, data_only: bool) -> void:
	var record: Dictionary = _manifest_at(path)
	if record.is_empty():
		_refuse(path.get_file(), "there is no mod at %s" % path)
		mods_changed.emit()
		return
	_load_record(record, data_only)
	mods_changed.emit()

## @ace_action
## @ace_name("Unload Mod")
## @ace_category("Mods")
## @ace_description("Takes a FOLDER mod back out of the loaded list, so the rows that read mod folders stop seeing it. A pack file cannot be unloaded: once Godot has loaded one, its files stay in the running game, so this row refuses with that reason and the way to do it is to switch the mod off and start again.")
## @ace_display_template("Unload mod [b]{unloading_name}[/b]")
## @ace_icon("res://eventsheet_addons/mods/icon.svg")
## @ace_codegen_template("Mods.unload_mod({unloading_name})")
func unload_mod(unloading_name: String) -> void:
	var at: int = _index_of(unloading_name)
	if at < 0:
		_refuse(unloading_name, "no mod called \"%s\" is loaded" % unloading_name)
		return
	if str(_mods[at].get("kind", "")) == "pack":
		# Godot has no way to take a loaded resource pack back out of the running game, so this row
		# says so instead of pretending. Switching it off and restarting is the way.
		_refuse(unloading_name, "it is a pack file, and a pack file cannot be unloaded while the game runs - switch it off and start again")
		return
	_mods.remove_at(at)
	_about = {"name": unloading_name, "version": "", "author": "", "reason": ""}
	mods_changed.emit()

## @ace_action
## @ace_name("Set Load Order")
## @ace_category("Mods")
## @ace_description("Says which mods load first, as a comma-separated list of names. Everything not named follows in name order, and later mods replace the files earlier ones brought - which is what a load order is for. It also re-lists what is already loaded, so the list an options screen shows and the order the next load uses are the same order.")
## @ace_display_template("Set load order [b]{names}[/b]")
## @ace_icon("res://eventsheet_addons/mods/icon.svg")
## @ace_codegen_template("Mods.set_load_order({names})")
func set_load_order(names: String) -> void:
	_order = PackedStringArray()
	for wanted: String in names.split(",", false):
		var trimmed: String = wanted.strip_edges()
		if not trimmed.is_empty():
			_order.append(trimmed)
	# The mods already loaded are re-listed the same way, so For Each Mod and the next Load Mods
	# From agree about the order rather than showing two of them - down to the tie, which falls
	# back to the same name order a folder is read in. Array.sort_custom is not stable, so a
	# comparator answering false on every tie is free to swap two unnamed mods on each call, and
	# "everything not named follows in name order" would be true of the folder and not of this.
	var order: Array = Array(_order)
	var behind: int = order.size() + 1
	_mods.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_at: int = order.find(str(first.get("name", "")))
		var second_at: int = order.find(str(second.get("name", "")))
		if first_at != second_at:
			return (first_at if first_at >= 0 else behind) < (second_at if second_at >= 0 else behind)
		return str(first.get("name", "")).naturalnocasecmp_to(str(second.get("name", ""))) < 0)
	mods_changed.emit()

## @ace_action
## @ace_name("Enable Mod")
## @ace_category("Mods")
## @ace_description("Switches a mod back on. A mod is on unless it has been switched off, so this is the way back from Disable Mod rather than something every mod needs. The choice is remembered through the Settings autoload when the project has one.")
## @ace_display_template("Enable mod [b]{enabling_name}[/b]")
## @ace_icon("res://eventsheet_addons/mods/icon.svg")
## @ace_codegen_template("Mods.enable_mod({enabling_name})")
func enable_mod(enabling_name: String) -> void:
	_disabled.erase(enabling_name)
	_remember_disabled()
	mods_changed.emit()

## @ace_action
## @ace_name("Disable Mod")
## @ace_category("Mods")
## @ace_description("Switches a mod off: it is skipped the next time mods are loaded, and a folder mod drops out of the loaded list at once. A pack file's files are already in the running game and stay until it starts again. The choice is remembered through the Settings autoload when the project has one.")
## @ace_display_template("Disable mod [b]{disabling_name}[/b]")
## @ace_icon("res://eventsheet_addons/mods/icon.svg")
## @ace_codegen_template("Mods.disable_mod({disabling_name})")
func disable_mod(disabling_name: String) -> void:
	_disabled[disabling_name] = true
	_remember_disabled()
	var at: int = _index_of(disabling_name)
	# A folder mod is simply not read any more. A pack file's files are already in the running
	# game's filesystem and stay there until it starts again, which the guide says out loud.
	if at >= 0 and str(_mods[at].get("kind", "")) == "folder":
		_mods.remove_at(at)
	mods_changed.emit()

## @ace_condition
## @ace_featured
## @ace_name("Mod Is Loaded")
## @ace_category("Mods")
## @ace_description("Whether a mod of that name is loaded right now - the check in front of using what it brought.")
## @ace_display_template("Mod [b]{wanted}[/b] is loaded")
## @ace_icon("res://eventsheet_addons/mods/icon.svg")
## @ace_codegen_template("Mods.mod_is_loaded({wanted})")
func mod_is_loaded(wanted: String) -> bool:
	return _index_of(wanted) >= 0

## @ace_expression
## @ace_name("Mod Count")
## @ace_category("Mods")
## @ace_description("How many mods are loaded - the number on the options screen's mods line.")
## @ace_icon("res://eventsheet_addons/mods/icon.svg")
## @ace_codegen_template("Mods.mod_count()")
func mod_count() -> int:
	return _mods.size()

## @ace_expression
## @ace_name("Mod Name")
## @ace_category("Mods")
## @ace_description("The name of the mod the last Mods event was about - the one that just loaded, or the one that was just refused.")
## @ace_icon("res://eventsheet_addons/mods/icon.svg")
## @ace_codegen_template("Mods.mod_name()")
func mod_name() -> String:
	return str(_about.get("name", ""))

## @ace_expression
## @ace_name("Mod Version")
## @ace_category("Mods")
## @ace_description("The version of the mod the last Mods event was about, as its manifest spells it.")
## @ace_icon("res://eventsheet_addons/mods/icon.svg")
## @ace_codegen_template("Mods.mod_version()")
func mod_version() -> String:
	return str(_about.get("version", ""))

## @ace_expression
## @ace_name("Mod Author")
## @ace_category("Mods")
## @ace_description("The author of the mod the last Mods event was about - the credit line beside its name.")
## @ace_icon("res://eventsheet_addons/mods/icon.svg")
## @ace_codegen_template("Mods.mod_author()")
func mod_author() -> String:
	return str(_about.get("author", ""))

## @ace_expression
## @ace_name("Mod Reason")
## @ace_category("Mods")
## @ace_description("Why the last refused mod was refused, in plain words a player can read, and nothing at all when none has been.")
## @ace_icon("res://eventsheet_addons/mods/icon.svg")
## @ace_codegen_template("Mods.mod_reason()")
func mod_reason() -> String:
	return str(_about.get("reason", ""))

## @ace_expression
## @ace_featured
## @ace_name("Mod Folder")
## @ace_category("Mods")
## @ace_description("Where a loaded mod's files live, so Resources In Folder, a Skin Vault catalog, a loot table or Data Folder Problems can be pointed straight at it. A pack file has no folder of its own - its files replace the game's by path - so this is empty for one.")
## @ace_display_template("folder of mod [b]{wanted}[/b]")
## @ace_icon("res://eventsheet_addons/mods/icon.svg")
## @ace_codegen_template("Mods.mod_folder({wanted})")
func mod_folder(wanted: String) -> String:
	var at: int = _index_of(wanted)
	if at < 0:
		return ""
	return str(_mods[at].get("folder", ""))

## @ace_expression
## @ace_name("Mod Folders")
## @ace_category("Mods")
## @ace_description("The same folder inside every loaded folder mod, in load order, skipping the mods that do not have one - hand it "items" and it is every mod's items folder, ready for a loop that loads each one's data assets.")
## @ace_display_template("every mod's [b]{subfolder}[/b] folder")
## @ace_icon("res://eventsheet_addons/mods/icon.svg")
## @ace_codegen_template("Mods.mod_folders({subfolder})")
func mod_folders(subfolder: String) -> Array:
	var folders: Array = []
	for record: Dictionary in _mods:
		var folder: String = str(record.get("folder", ""))
		if folder.is_empty():
			continue
		var reading: String = folder if subfolder.strip_edges().is_empty() else folder.path_join(subfolder)
		if DirAccess.dir_exists_absolute(reading):
			folders.append(reading)
	return folders

## @ace_expression
## @ace_name("Mod Content Problems")
## @ace_category("Mods")
## @ace_description("Every structural problem in the loaded mods' content, one per line, and nothing at all when it is clean: a data asset that will not load, and a file two mods both bring, where the one loaded last wins. It is the Data Folder Problems check over the mod folders, so a broken mod is named rather than crashed on.")
## @ace_display_template("mod problems in [b]{subfolder}[/b]")
## @ace_icon("res://eventsheet_addons/mods/icon.svg")
## @ace_codegen_template("Mods.mod_content_problems({subfolder})")
func mod_content_problems(subfolder: String) -> String:
	var problems: PackedStringArray = PackedStringArray()
	var claimed: Dictionary = {}
	for record: Dictionary in _mods:
		var folder: String = str(record.get("folder", ""))
		if folder.is_empty():
			continue
		var reading: String = folder if subfolder.strip_edges().is_empty() else folder.path_join(subfolder)
		if not DirAccess.dir_exists_absolute(reading):
			continue
		var file_names: PackedStringArray = DirAccess.get_files_at(reading)
		file_names.sort()
		for file_name: String in file_names:
			var plain: String = file_name.trim_suffix(".remap")
			if not plain.get_extension().to_lower() in ["tres", "res"]:
				continue
			if load(reading.path_join(plain)) == null:
				problems.append("%s: %s could not be loaded" % [record.get("name", ""), plain])
				continue
			if claimed.has(plain):
				problems.append("%s: %s is also in %s, and the one loaded last wins" % [
					record.get("name", ""), plain, claimed[plain]])
				continue
			claimed[plain] = str(record.get("name", ""))
	return "\n".join(problems)

## One mod's record, made from whatever the manifest gave and filled in for whatever it did not.
## @ace_hidden
func _record(declared: Dictionary, path: String, kind: String, folder: String) -> Dictionary:
	var declared_name: String = str(declared.get("name", "")).strip_edges()
	if declared_name.is_empty():
		declared_name = path.get_file().get_basename()
	return {
		"name": declared_name,
		"version": str(declared.get("version", "")),
		"author": str(declared.get("author", "")),
		"replaces": str(declared.get("replaces", "")),
		"scripts": bool(declared.get("scripts", false)),
		"kind": kind,
		"path": path,
		"folder": folder,
	}

## The manifest at a path, or an empty record when there is no mod there. A FOLDER mod declares
## itself in mod.json, or in a mod.tres a ModManifest resource was saved as. A PACK file declares
## itself in a .json beside it, or in a mod.json inside it when it is a .zip - and when it declares
## nothing at all, the file's own name is the mod's name.
## @ace_hidden
func _manifest_at(path: String) -> Dictionary:
	if DirAccess.dir_exists_absolute(path):
		var json_path: String = path.path_join("mod.json")
		if FileAccess.file_exists(json_path):
			return _record(_read_json(json_path), path, "folder", path)
		for extension: String in [".tres", ".res"]:
			var resource_path: String = path.path_join("mod" + extension)
			if ResourceLoader.exists(resource_path):
				return _record(_read_resource(resource_path, path), path, "folder", path)
		if debug_mode:
			push_warning("Mods: %s holds no mod.json and no mod.tres, so it is not read as a mod." % path)
		return {}
	if not FileAccess.file_exists(path):
		return {}
	if not path.get_extension().to_lower() in ["pck", "zip"]:
		return {}
	var beside: String = path.get_basename() + ".json"
	if FileAccess.file_exists(beside):
		return _record(_read_json(beside), path, "pack", "")
	if path.get_extension().to_lower() == "zip":
		var inside: Dictionary = _read_json_in_zip(path, "mod.json")
		if not inside.is_empty():
			return _record(inside, path, "pack", "")
	return _record({}, path, "pack", "")

## One manifest file read as plain data. A file that is not readable JSON, or is JSON that is not a
## record, gives nothing back rather than half a mod.
## @ace_hidden
func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	if debug_mode:
		push_warning("Mods: %s is not a JSON record, so the mod's name comes from its folder instead." % path)
	return {}

## A manifest saved as a resource (a ModManifest .tres), read into the same plain record the JSON
## form gives, so nothing downstream knows which spelling a mod used.
##
## IT IS NEVER LOADED. The manifest is read BEFORE the tier is even known - it is the file that says
## what the mod is called - and `load()` on a resource file BUILDS what the file describes, script
## and all. Reading it first and loading it second is not enough either: a refusal that arrives after
## the load has run is a refusal a stranger's `_init` has already outlived. So the five fields are
## taken out of the file's own TEXT, by the same reading that decides whether the file may be taken
## at all, and a data-only load calls `load()` on nothing a mod brought.
##
## A manifest saved in the BINARY form cannot be read as text, so it says nothing; `mod.json` and a
## text `mod.tres` are the two spellings, and they are the two the template tool writes. A file that
## is readable and is not a manifest at all carries none of the five names, and the record falls back
## to the folder's own name rather than to the word "<null>" - which is what `str(null)` put there
## while this was asking a BUILT object for properties it did not have.
## @ace_hidden
func _read_resource(path: String, own_folder: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var refusal: String = _resource_reason(path.get_file(), text, own_folder)
	if not refusal.is_empty():
		if debug_mode:
			push_warning("Mods: %s was not read as a manifest - %s." % [path, refusal])
		return {}
	var written: Dictionary = _resource_values(text)
	return {
		"name": str(written.get("mod_name", "")),
		"version": str(written.get("version", "")),
		"author": str(written.get("author", "")),
		"replaces": str(written.get("replaces", "")),
		"scripts": str(written.get("scripts", "")) == "true",
	}

## The `[resource]` section's own property lines, as the text each was written with. A quoted value
## comes back without its quotes and everything else exactly as spelled, so `true` is four letters
## the caller compares - which is what keeps a hand-typed `scripts = 1` from quietly meaning false.
##
## Values the engine would BUILD - `ExtResource("1_x")`, `Resource("...")` - are read as the text
## they are and never resolved. The script line of a manifest saved from a class is exactly one of
## those, and it is not one of the five names asked for.
## @ace_hidden
func _resource_values(text: String) -> Dictionary:
	var values: Dictionary = {}
	var reading: bool = false
	for line: String in text.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("["):
			# A `.tres` keeps its own properties in the `[resource]` section; every line before it
			# belongs to the tables the reading above has already judged.
			reading = trimmed.begins_with("[resource")
			continue
		if not reading or trimmed.is_empty() or trimmed.begins_with(";"):
			continue
		var equals_at: int = trimmed.find("=")
		if equals_at <= 0:
			continue
		var field: String = trimmed.substr(0, equals_at).strip_edges()
		var value: String = trimmed.substr(equals_at + 1).strip_edges()
		if value.begins_with("\""):
			var ends_at: int = value.find("\"", 1)
			if ends_at < 0:
				continue
			value = value.substr(1, ends_at - 1)
		if not field.is_empty():
			values[field] = value
	return values

## One file read out of a .zip as JSON, without loading the archive as a resource pack - which
## matters, because a pack that has been loaded cannot be unloaded again.
## @ace_hidden
func _read_json_in_zip(path: String, inner: String) -> Dictionary:
	var reader: ZIPReader = ZIPReader.new()
	if reader.open(path) != OK:
		return {}
	var found: Dictionary = {}
	if reader.file_exists(inner):
		var parsed: Variant = JSON.parse_string(reader.read_file(inner).get_string_from_utf8())
		if parsed is Dictionary:
			found = parsed
	reader.close()
	return found

## Every file a pack file holds, WITHOUT loading it: `read` says whether the list could be trusted
## at all, `paths` is what was in it, and `entries` is the same list with the place and size of each
## file's bytes - which is what lets a scene or a resource inside a pack be READ rather than merely
## named. A .zip is read with Godot's own archive reader; a .pck is read out of the file table the
## exporter wrote at the front of it.
## @ace_hidden
func _pack_index(path: String) -> Dictionary:
	if path.get_extension().to_lower() == "zip":
		var reader: ZIPReader = ZIPReader.new()
		if reader.open(path) != OK:
			return {"read": false, "paths": PackedStringArray()}
		var files: PackedStringArray = PackedStringArray()
		for inner: String in reader.get_files():
			# An archive lists its folders as well as its files, and a folder is not something that
			# can carry code - so the index says files, the way its name promises.
			if not inner.ends_with("/"):
				files.append(inner)
		reader.close()
		return {"read": true, "paths": files, "entries": []}
	return _pck_index(path)

## The file table of a .pck, read off the file's own bytes. Anything this reader is not sure of - a
## file that does not open, a magic number that is not a pack's, a format newer than it knows, an
## encrypted directory, a count that cannot be right, or an entry pointing at bytes the file does
## not have - comes back as `read: false`, which a data-only row treats as a refusal. The safe
## failure is refusing a mod that was fine; the unsafe one is passing a mod full of code, so this
## never guesses.
##
## THE TABLE HAS MOVED, TWICE, AND THE SHAPE OF A PATH WITH IT. Format 2 added a flags word and a
## base every file's place may be measured from. Format 4 moved the file list itself to a place of
## its own near the end of the pack, and writes each path without its `res://`. A reader that knows
## only the old shape does not read a modern pack WRONGLY - it refuses it, which for a data-only
## row reads as "its file list could not be read" for every pack file a player ever has. So both
## shapes are read, and a path that arrives without a scheme is given the one it had.
##
## THE LAST CHECK IS ARITHMETIC RATHER THAN SPELLING: every entry must point at bytes this file
## actually holds. A table read the wrong way produces places that run off the end of the file,
## which is how a mis-read is noticed instead of being reported as a pack full of nothing.
## @ace_hidden
func _pck_index(path: String) -> Dictionary:
	var refused: Dictionary = {"read": false, "paths": PackedStringArray(), "entries": []}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return refused
	var pack_bytes: int = file.get_length()
	if file.get_32() != PACK_MAGIC:
		return refused
	var format_version: int = file.get_32()
	if format_version < 1 or format_version > PACK_FORMAT_MAX:
		return refused
	file.get_32()
	file.get_32()
	file.get_32()
	var pack_flags: int = 0
	var file_base: int = 0
	if format_version >= 2:
		pack_flags = file.get_32()
		file_base = file.get_64()
	if pack_flags & PACK_DIRECTORY_ENCRYPTED != 0:
		return refused
	if format_version >= PACK_FORMAT_WITH_DIRECTORY:
		var directory_at: int = file.get_64()
		if directory_at <= 0 or directory_at >= pack_bytes:
			return refused
		file.seek(directory_at)
	else:
		for _reserved: int in 16:
			file.get_32()
	var count: int = file.get_32()
	if count < 0 or count > 1000000:
		return refused
	var relative: bool = pack_flags & PACK_PLACES_ARE_RELATIVE != 0
	var paths: PackedStringArray = PackedStringArray()
	var entries: Array[Dictionary] = []
	for _entry: int in count:
		var length: int = file.get_32()
		if length <= 0 or length > 4096 or file.eof_reached():
			return refused
		var entry_path: String = _path_of_bytes(file.get_buffer(length))
		var offset: int = file.get_64() + (file_base if relative else 0)
		var size: int = file.get_64()
		file.get_buffer(16)
		var flags: int = file.get_32() if format_version >= 2 else 0
		if entry_path.is_empty() or offset < 0 or size < 0 or offset + size > pack_bytes:
			return refused
		if not entry_path.contains("://"):
			entry_path = "res://" + entry_path
		paths.append(entry_path)
		entries.append({"path": entry_path, "offset": offset, "size": size, "flags": flags})
	file.close()
	return {"read": true, "paths": paths, "entries": entries}

## One path out of a pack's table. Paths are written padded out to a round number of bytes with
## zeros, and a zero is not a character a path is spelled with - so the padding comes off before
## the letters are read rather than travelling on inside the name.
## @ace_hidden
func _path_of_bytes(raw: PackedByteArray) -> String:
	var written: PackedByteArray = raw
	while written.size() > 0 and written[written.size() - 1] == 0:
		written.remove_at(written.size() - 1)
	return written.get_string_from_utf8().strip_edges()

## Why one resource file inside a mod may not be taken by a data-only row, in plain words, or ""
## when it may. THE OTHER HALF OF THE DATA-ONLY DECISION: the list of names above answers about the
## files that are code by their extension, and this answers about the files that are not.
##
## It only ever reads the TEXT, and it refuses everything it cannot read as text - a binary `.scn`
## or `.res`, a tag that never closes, a tag with no type, a tag spelled with an escape. Something
## unfamiliar is not something that has been cleared, and the safe failure is refusing a mod that
## was fine.
##
## WHAT MAKES IT REFUSE, and every one of them is a way a file called data runs code:
##   a script written INSIDE it    - a `[sub_resource]` whose type ends in `Script` is source code
##                                   carried in the file itself, in any language the engine has.
##   a script named BESIDE it      - an `[ext_resource]` whose type ends in `Script`, or which names
##                                   a file that is code by its extension, is a file the engine loads
##                                   and attaches when this one is built. Under `res://` it is the
##                                   GAME's own script - which is how a mod's `sword.tres` names the
##                                   Resource class of yours it is an instance of, and the reason the
##                                   tier is worth having - and anywhere else, the mod's own folder
##                                   included, it is refused.
##   a value that BUILDS something - `Object(GDScript,"script/source":"...")` and
##                                   `Resource("user://payload.gd")` are property values the
##                                   engine's own value parser resolves by compiling and by loading.
##   a path that leaves the mod    - an `[ext_resource]` may name another scene or resource, whose
##                                   own table this reading has not opened. `res://` is the game's
##                                   own files, which is what a game IS, and the mod's own folder
##                                   is the mod; anything else is refused. That is what lets a
##                                   cleared mod mean "nothing from elsewhere comes in with it"
##                                   rather than "no script is written on this page".
##
## AND IT IS ABOUT CODE THE FILE CARRIES, NOT ABOUT WHAT IT ASKS YOUR OWN CODE TO DO. A cleared
## scene may still hold a connection naming one of your own methods, or an animation track that
## calls one at a keyframe. None of that brings a stranger's code in; each of them can reach yours.
## A mod is somebody else's DATA, so what it can reach is worth the same thought as any other input.
## @ace_hidden
func _resource_reason(name: String, text: String, own_folder: String) -> String:
	var inside: String = own_folder
	if not inside.is_empty() and not inside.ends_with("/"):
		inside += "/"
	var readable: bool = false
	for head: String in RESOURCE_HEADS:
		readable = readable or text.begins_with(head)
	if not readable:
		return "%s is saved in a form this row cannot read, so it cannot be cleared of code" % name
	for maker: String in BUILDING_MAKERS:
		var maker_at: int = text.find(maker)
		while maker_at >= 0:
			var lead: String = text.substr(maker_at - 1, 1) if maker_at > 0 else ""
			if lead.to_lower() == lead.to_upper() and not lead.is_valid_int() and lead != "_":
				return "%s carries a value that builds something, and this row loads data only" % name
			maker_at = text.find(maker, maker_at + maker.length())
	var lines: PackedStringArray = text.split("\n")
	var at: int = 0
	while at < lines.size():
		var tag: String = lines[at].strip_edges()
		at += 1
		if not tag.begins_with("["):
			continue
		var closed_at: int = _tag_closes_at(tag)
		while closed_at < 0:
			if at >= lines.size():
				return "%s holds a tag that never closes, so it cannot be cleared of code" % name
			tag += " " + lines[at].strip_edges()
			at += 1
			closed_at = _tag_closes_at(tag)
		var head: String = tag.substr(1, closed_at - 1).strip_edges()
		var named_at: int = head.find(" ")
		var tag_name: String = head if named_at < 0 else head.substr(0, named_at)
		if not RESOURCE_TAGS.has(tag_name):
			continue
		if head.contains(ESCAPE_GLYPH):
			return "%s holds an escape inside a resource tag, so it cannot be cleared of code" % name
		var fields: Dictionary = _tag_fields("" if named_at < 0 else head.substr(named_at + 1))
		if fields.is_empty():
			return "%s holds a tag this row cannot read, so it cannot be cleared of code" % name
		var kind: String = str(fields.get("type", ""))
		if kind.is_empty():
			return "%s holds a tag with no type, so it cannot be cleared of code" % name
		if tag_name == "sub_resource":
			# Source code written INSIDE the file, in whatever language the engine has.
			if kind.ends_with(SCRIPT_TYPE_TAIL):
				return "%s carries a script, and this row loads data only" % name
			continue
		var place: String = str(fields.get("path", ""))
		if place.is_empty() or place.contains(CLIMB_OUT):
			return "%s names a file this row cannot place, so it cannot be cleared of code" % name
		# res:// is the game's own files, which is what a game IS - and a code file a PACK mod
		# brings to res:// was already refused by name before this reading was reached. A script
		# named under res:// is therefore the game's own, which is how a manifest saved as a
		# resource names the class it was saved from, and how a mod's `sword.tres` names the
		# Resource class of yours it is an instance of. That last one is the whole point of the
		# tier, so the carve-out stays and is deliberately narrow: it is res:// or nothing.
		if place.begins_with("res://"):
			continue
		if inside.is_empty() or not place.begins_with(inside):
			return "%s names %s, which is outside the mod, and this row loads data only" % [name, place]
		# INSIDE THE MOD IS NOT A PLACE A SCRIPT MAY BE NAMED FROM EITHER. The place check above
		# lets a mod's scene name the mod's own textures and resources, which is what a mod is made
		# of - but a file the mod brought is a file a stranger wrote, so an ext_resource of a script
		# type, or one naming a file that is code by its extension whatever type it claims to be, is
		# refused here rather than waved through as "inside the mod". A folder mod's own `.gd` is
		# refused by name a step earlier, and this is the same refusal for the tag that would have
		# loaded it BEFORE that walk ever ran - which is exactly what a crafted manifest did.
		if kind.ends_with(SCRIPT_TYPE_TAIL) or _names_code(place):
			return "%s names the script %s, and this row loads data only" % [name, place]
	return ""

## Every extension the engine itself reads as a resource or a scene - the files this row opens and
## reads rather than merely names. See the note beside the cache above.
## @ace_hidden
func _resource_extensions() -> PackedStringArray:
	if _resource_extension_cache.is_empty():
		_resource_extension_cache = ResourceLoader.get_recognized_extensions_for_type("Resource")
	return _resource_extension_cache

## True when a path is CODE by its own extension, whatever a tag claims its type is. The type is a
## word in a file a stranger wrote; the extension is what the engine will compile.
## @ace_hidden
func _names_code(place: String) -> bool:
	return place.get_file().trim_suffix(".remap").get_extension().to_lower() in CODE_EXTENSIONS

## Where a tag closes, or -1 when it does not close on the text so far. Quotes are respected, so a
## `]` inside a value does not end a tag early, and a tag written over more than one line is
## gathered rather than cut in half.
## @ace_hidden
func _tag_closes_at(tag: String) -> int:
	var quoted: bool = false
	var scan: int = 0
	while scan < tag.length():
		if tag[scan] == "\"":
			quoted = not quoted
		elif tag[scan] == "]" and not quoted:
			return scan
		scan += 1
	return -1

## A tag's attributes as the pairs they are, or an empty dictionary when one of them cannot be
## read. `type = "Script"` with spaces around the `=` is the same tag as `type="Script"`, which is
## exactly why this is parsed rather than searched for as a substring.
## @ace_hidden
func _tag_fields(rest: String) -> Dictionary:
	var fields: Dictionary = {}
	var cursor: int = 0
	while cursor < rest.length():
		while cursor < rest.length() and rest[cursor] == " ":
			cursor += 1
		if cursor >= rest.length():
			break
		var key_at: int = cursor
		while cursor < rest.length() and rest[cursor] != "=" and rest[cursor] != " ":
			cursor += 1
		var field: String = rest.substr(key_at, cursor - key_at)
		while cursor < rest.length() and (rest[cursor] == " " or rest[cursor] == "="):
			cursor += 1
		var value: String = ""
		if cursor < rest.length() and rest[cursor] == "\"":
			var ends_at: int = rest.find("\"", cursor + 1)
			if ends_at < 0:
				return {}
			value = rest.substr(cursor + 1, ends_at - cursor - 1)
			cursor = ends_at + 1
		else:
			var value_at: int = cursor
			while cursor < rest.length() and rest[cursor] != " ":
				cursor += 1
			value = rest.substr(value_at, cursor - value_at)
		if field.is_empty():
			return {}
		fields[field] = value
	return fields

## The code files in a list of paths - the whole data-only decision, over a list, with no disk in
## it. Everything that reads a mod's contents ends here.
## @ace_hidden
func _code_in(paths: PackedStringArray) -> PackedStringArray:
	var carried: PackedStringArray = PackedStringArray()
	for path: String in paths:
		if path.get_file().trim_suffix(".remap").get_extension().to_lower() in CODE_EXTENSIONS:
			carried.append(path)
	return carried

## Every file in a folder and the folders under it, up to a sane depth - what a folder mod's own
## contents are, for the same code question a pack file answers from its table.
## @ace_hidden
func _files_under(folder: String, depth: int = 6) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if depth <= 0 or not DirAccess.dir_exists_absolute(folder):
		return found
	for file_name: String in DirAccess.get_files_at(folder):
		found.append(folder.path_join(file_name))
	for sub_name: String in DirAccess.get_directories_at(folder):
		found.append_array(_files_under(folder.path_join(sub_name), depth - 1))
	return found

## Why this mod may not be loaded by a data-only row, in plain words, or "" when it may. The pack
## file's own table and the folder's own files are the answer - not the manifest's `scripts` flag,
## which is what the mod SAYS about itself and is checked first only so a mod that admits it gets
## the plainer sentence.
##
## TWO QUESTIONS, NOT ONE. A file that is code BY ITS NAME - a `.gd`, a `.dll` - is found in the
## list of names. A file that is a resource table by its name may carry code all the same, so every
## scene and every resource the mod holds is READ as well. Deciding by extension alone was a
## data-only tier a `.tscn` with a script written inside it walked straight through.
## @ace_hidden
func _code_reason(record: Dictionary) -> String:
	if bool(record.get("scripts", false)):
		return "its manifest says it carries code, and this row loads data only"
	if str(record.get("kind", "")) == "pack":
		var pack_path: String = str(record.get("path", ""))
		var index: Dictionary = _pack_index(pack_path)
		if not bool(index.get("read", false)):
			return "its file list could not be read, so a data-only row cannot tell whether it carries code"
		var carried: PackedStringArray = _code_in(index.get("paths", PackedStringArray()))
		if not carried.is_empty():
			return "it carries %d code file(s), starting with %s, and this row loads data only" % [
				carried.size(), carried[0]]
		if pack_path.get_extension().to_lower() == "zip":
			return _zip_resource_reason(pack_path)
		return _pck_resource_reason(pack_path, index.get("entries", []) as Array)
	var folder: String = str(record.get("folder", ""))
	var in_folder: PackedStringArray = _code_in(_files_under(folder))
	if not in_folder.is_empty():
		return "it carries %d code file(s), starting with %s, and this row loads data only" % [
			in_folder.size(), in_folder[0].get_file()]
	return _folder_resource_reason(folder)

## The first refusal among a folder mod's own scenes and resources, or "" when every one of them
## reads as data. Sorted, so two machines refusing the same mod name the same file.
## @ace_hidden
func _folder_resource_reason(folder: String) -> String:
	var paths: PackedStringArray = _files_under(folder)
	paths.sort()
	for path: String in paths:
		if not _resource_extensions().has(path.get_extension().to_lower()):
			continue
		var reason: String = _resource_reason(path.get_file(),
			FileAccess.get_file_as_string(path), folder)
		if not reason.is_empty():
			return reason
	return ""

## The same question of a .zip, whose entries Godot's own archive reader hands over without the
## archive ever being mounted - which matters, because a pack that has been loaded cannot be
## unloaded again.
## @ace_hidden
func _zip_resource_reason(path: String) -> String:
	var reader: ZIPReader = ZIPReader.new()
	if reader.open(path) != OK:
		return "its archive could not be opened, so a data-only row cannot tell whether it carries code"
	var inner_paths: PackedStringArray = PackedStringArray()
	for inner: String in reader.get_files():
		if not inner.ends_with("/") and _resource_extensions().has(inner.get_extension().to_lower()):
			inner_paths.append(inner)
	inner_paths.sort()
	var reason: String = ""
	for inner: String in inner_paths:
		reason = _resource_reason(inner.get_file(),
			reader.read_file(inner).get_string_from_utf8(), "")
		if not reason.is_empty():
			break
	reader.close()
	return reason

## The same question of a .pck, read straight off the file's own bytes at the places its table
## gives. An entry the exporter encrypted cannot be read without the game's key, and an entry that
## cannot be read is not one that has been cleared.
## @ace_hidden
func _pck_resource_reason(path: String, entries: Array) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "its file could not be opened, so a data-only row cannot tell whether it carries code"
	var wanted: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if _resource_extensions().has(str(entry.get("path", "")).get_extension().to_lower()):
			wanted.append(entry)
	wanted.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return str(first.get("path", "")) < str(second.get("path", "")))
	var reason: String = ""
	for entry: Dictionary in wanted:
		var name: String = str(entry.get("path", "")).get_file()
		if int(entry.get("flags", 0)) & PACK_ENTRY_ENCRYPTED != 0:
			reason = "%s is encrypted, so it cannot be cleared of code" % name
			break
		var size: int = int(entry.get("size", 0))
		if size < 0 or size > MOST_RESOURCE_BYTES:
			reason = "%s is too big for this row to read, so it cannot be cleared of code" % name
			break
		file.seek(int(entry.get("offset", 0)))
		reason = _resource_reason(name, file.get_buffer(size).get_string_from_utf8(), "")
		if not reason.is_empty():
			break
	file.close()
	return reason

## Where a loaded mod sits in the list, or -1.
## @ace_hidden
func _index_of(wanted: String) -> int:
	for at: int in _mods.size():
		if str(_mods[at].get("name", "")) == wanted:
			return at
	return -1

## Loads one mod that has already been read, or refuses it and says why. A mod that is switched off
## is skipped in silence: it is not a refusal, it is a choice the player made.
## @ace_hidden
func _load_record(record: Dictionary, data_only: bool) -> void:
	var loading_name: String = str(record.get("name", ""))
	if _disabled.get(loading_name, false):
		return
	if _index_of(loading_name) >= 0:
		if debug_mode:
			push_warning("Mods: two mods are called \"%s\"; the first one loaded keeps the name." % loading_name)
		_refuse(loading_name, "another mod is already loaded under that name")
		return
	if data_only:
		var reason: String = _code_reason(record)
		if not reason.is_empty():
			_refuse(loading_name, reason)
			return
	if str(record.get("kind", "")) == "pack":
		if not ProjectSettings.load_resource_pack(str(record.get("path", "")), true):
			_refuse(loading_name, "Godot could not load the pack file at %s" % record.get("path", ""))
			return
	_mods.append(record)
	_about = {
		"name": loading_name,
		"version": str(record.get("version", "")),
		"author": str(record.get("author", "")),
		"reason": "",
	}
	mod_loaded.emit(loading_name, str(record.get("version", "")))

## Records a refusal and raises it. The reason is a sentence a player can read, because it is what
## the options screen puts beside the mod's name.
## @ace_hidden
func _refuse(refused: String, reason: String) -> void:
	_about = {"name": refused, "version": "", "author": "", "reason": reason}
	mod_refused.emit(refused, reason)

## Writes the switched-off list into the settings autoload, when the project has one.
## @ace_hidden
func _remember_disabled() -> void:
	var settings: Object = _settings()
	if settings == null or not settings.has_method("set_setting"):
		return
	var names: Array = _disabled.keys()
	names.sort()
	var written: PackedStringArray = PackedStringArray()
	for switched_off: String in names:
		if _disabled[switched_off]:
			written.append(switched_off)
	if settings.has_method("setting_is_declared") and not settings.setting_is_declared(settings_key):
		if settings.has_method("declare_setting"):
			settings.declare_setting(settings_key, "", "text")
	settings.set_setting(settings_key, ",".join(written))

## Reads the switched-off list back out of the settings autoload. Called once when the director is
## ready, so the rows that load mods already know what the player switched off last time.
## @ace_hidden
func _recall_disabled() -> void:
	var settings: Object = _settings()
	if settings == null or not settings.has_method("setting_value"):
		return
	_disabled = {}
	for switched_off: String in str(settings.setting_value(settings_key)).split(",", false):
		var trimmed: String = switched_off.strip_edges()
		if not trimmed.is_empty():
			_disabled[trimmed] = true

# Mods (autoload): register as the Mods autoload, then load mods from any sheet. A mod is a folder with a mod.json in it, or a .pck / .zip pack file; the manifest names it and says whether it carries code. Data only reads a pack's own contents and refuses one carrying code - and a mod that does carry code runs with everything the game can reach, because Godot has no sandbox. This pack is an event sheet - extend it by editing it.
