# Godot EventSheets - what a project's tilesets declare, read as TEXT.
#
# Two questions, asked by three readers who must never disagree: which custom data layers exist in
# this project, and which terrains. The tile rows' Data and Terrain fields complete from these
# lists, and the Doctor's tilemap section names a row asking for a key or a terrain set no tileset
# here declares.
#
# WHY TEXT, AND NOT `load()`. A TileSet is as often embedded in a `.tscn` as saved as a `.tres`, and
# reaching an embedded one through `load()` means instancing the scene - which builds nodes, runs
# @tool scripts and costs orders of magnitude more than the answer is worth. Both files store the
# same resource in the same text format, and the two facts wanted here are plain property lines in
# it, so ONE regex over the file's text answers for both and never touches the resource system:
#
#     custom_data_layer_0/name = "surface"
#     terrain_set_0/terrain_1/name = "Dirt"
#
# The consequence is stated rather than hidden: a tileset saved in the BINARY `.res` format is not
# read, and neither is one built at run time. Both are answered the same way - the completion list
# is shorter and the Doctor says nothing - because a list that is missing an entry must never turn
# into a finding claiming the entry does not exist. `has_any_tileset` is what the Doctor asks first
# for exactly that reason: a project this file cannot read anything from is a project it has no
# business reporting on.
#
# NOTHING IS WRITTEN. The walk is bounded and SORTED - CI runs the suite on a filesystem whose own
# walk order is its business - so two runs over an unchanged project answer with the same list in
# the same order.
#
# NOTHING IS REMEMBERED BETWEEN QUESTIONS EITHER, unless a caller says so. One Doctor run asks three
# questions of this file - is there a tileset, what data keys, how many terrain sets - and each one
# walked the project and read the full text of every `.tscn` and `.tres` in it, so a project's files
# were read three times over to answer three questions about the same bytes. A caller that is about
# to ask a run of them opens with `remember()` and closes with `forget()`, and in between each file
# is read once. Outside that pair nothing is held at all, which is what keeps the answer to "what
# does this project declare" the answer for the project as it is NOW rather than as it was when
# some earlier caller looked.
@tool
class_name EventForgeTileSetFacts
extends RefCounted

## Where the walk stops. A project with more files than this is not read further: the list is a
## convenience, and an editor that stalls opening a dialog is not one.
const FILE_LIMIT: int = 4000

## The file kinds a text-format resource can arrive in. A `.res` is the binary twin of `.tres` and
## is deliberately not read - see the header.
const TEXT_RESOURCE_EXTENSIONS: PackedStringArray = ["tres", "tscn"]

## The line a custom data layer writes, and the line a terrain writes. Spelled as the engine's own
## property names, because that is what the saved file holds.
const DATA_LAYER_PATTERN := "custom_data_layer_([0-9]+)/name = \"([^\"]*)\""
const TERRAIN_PATTERN := "terrain_set_([0-9]+)/terrain_([0-9]+)/name = \"([^\"]*)\""

## The key the walk itself is held under while a caller is remembering. A path can never collide
## with it: every path this file holds begins with `res://`.
const WALK_KEY := "the walk"

## What one caller is holding for the length of its own run: path -> that file's text, plus the walk
## under WALK_KEY. Empty and unused unless `remember()` has been called.
static var _held: Dictionary = {}
static var _holding: bool = false


## Read every file once until `forget()`. For a caller about to ask several of these questions in a
## row - the Doctor's Tilemap section asks three - which otherwise walks the project and reads every
## text resource in it once per question.
static func remember() -> void:
	_holding = true
	_held = {}


## Stop holding, and let go of what was held. Always called by whoever called `remember()`, so the
## next caller sees the project as it is rather than as it was.
static func forget() -> void:
	_holding = false
	_held = {}


## Every custom data layer name any tileset in this project declares, sorted and without repeats.
static func project_data_keys() -> PackedStringArray:
	var seen: Dictionary = {}
	for path: String in project_files_with_tilesets():
		for key: String in data_keys(source_of(path)):
			seen[key] = true
	var keys: Array = seen.keys()
	keys.sort()
	return PackedStringArray(keys)


## Every terrain any tileset in this project declares, as {set, index, name, path}, sorted by set
## then index then name. The set and the index are what a row's fields actually take - a terrain is
## addressed by number, and the name is what a reader recognises it by.
static func project_terrains() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for path: String in project_files_with_tilesets():
		for terrain: Dictionary in terrains(source_of(path)):
			var entry: Dictionary = terrain.duplicate()
			entry["path"] = path
			found.append(entry)
	found.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left["set"]) != int(right["set"]):
			return int(left["set"]) < int(right["set"])
		if int(left["index"]) != int(right["index"]):
			return int(left["index"]) < int(right["index"])
		return str(left["name"]) < str(right["name"]))
	return found


## How many terrain SETS the project's tilesets go up to - the highest set number any of them
## declares, plus one, or 0 when none declares any. What a row asking for terrain set 3 is measured
## against.
static func project_terrain_set_count() -> int:
	var highest: int = -1
	for terrain: Dictionary in project_terrains():
		highest = maxi(highest, int(terrain["set"]))
	return highest + 1


## True when this project holds a text-format file declaring a tileset at all. The Doctor asks this
## before it says anything: a project whose tilesets are all binary or all built at run time is one
## this reader knows nothing about, and silence is the only honest report.
static func has_any_tileset() -> bool:
	return not project_files_with_tilesets().is_empty()


## Every project file whose text declares a tileset, in sorted path order. The substring test comes
## first and is deliberately looser than the reads behind it: it only decides what is worth a regex.
static func project_files_with_tilesets() -> PackedStringArray:
	if _holding and _held.has(WALK_KEY):
		return _held[WALK_KEY]
	var found: PackedStringArray = PackedStringArray()
	for path: String in _text_resource_files():
		var source: String = source_of(path)
		if source.contains("custom_data_layer_") or source.contains("terrain_set_"):
			found.append(path)
	if _holding:
		_held[WALK_KEY] = found
	return found


## The custom data layer names one file's text declares, in the order the file declares them and
## without repeats. Pure over a string, so a test hands it a tileset it wrote itself.
static func data_keys(source: String) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	var matcher: RegEx = RegEx.create_from_string(DATA_LAYER_PATTERN)
	for found: RegExMatch in matcher.search_all(source):
		var key: String = found.get_string(2)
		if not key.is_empty() and not keys.has(key):
			keys.append(key)
	return keys


## The terrains one file's text declares, as {set, index, name}. Pure over a string, for the same
## reason the keys are.
static func terrains(source: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var matcher: RegEx = RegEx.create_from_string(TERRAIN_PATTERN)
	for hit: RegExMatch in matcher.search_all(source):
		found.append({
			"set": int(hit.get_string(1)), "index": int(hit.get_string(2)),
			"name": hit.get_string(3)
		})
	return found


## One file's text, or "" when it cannot be opened. Never throws and never warns: a file that has
## gone since the walk listed it is simply one this reader says nothing about.
static func source_of(path: String) -> String:
	if _holding and _held.has(path):
		return str(_held[path])
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = "" if file == null else file.get_as_text()
	if _holding:
		_held[path] = text
	return text


## Every text-format resource and scene in the project, sorted, bounded, and skipping this plugin's
## own folder - the editor's demo tilesets are not the reader's game.
static func _text_resource_files() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var pending: Array[String] = ["res://"]
	while not pending.is_empty() and found.size() < FILE_LIMIT:
		var directory: String = pending.pop_front()
		var handle: DirAccess = DirAccess.open(directory)
		if handle == null:
			continue
		var directories: PackedStringArray = handle.get_directories()
		directories.sort()
		for sub_directory: String in directories:
			if sub_directory.begins_with(".") or sub_directory == "addons":
				continue
			pending.append(directory.path_join(sub_directory))
		var files: PackedStringArray = handle.get_files()
		files.sort()
		for file_name: String in files:
			if not TEXT_RESOURCE_EXTENSIONS.has(file_name.get_extension().to_lower()):
				continue
			found.append(directory.path_join(file_name))
			if found.size() >= FILE_LIMIT:
				break
	found.sort()
	return found
