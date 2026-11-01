# Godot EventSheets - the lifted sheet of a .gd, remembered between opens.
#
# Opening a .gd as a sheet is a raw read and then the lift: every function reverse-matched against the
# vocabulary and the whole sheet recompiled to byte-verify it. The lift is linear in the file
# (about 2.6 ms a source line - 9 s for the 3,580-line pathfinding pack) and its answer is a pure
# function of the file's text and of the code and vocabulary that read it. This keeps that answer in
# `.godot/` as a binary resource, so the second open of an unchanged file reads it back (66 ms for
# the pathfinding pack) instead of lifting again.
#
# THE LOSSLESS CONTRACT IS WHAT MAKES THIS SAFE, AND IT IS CHECKED, NOT ASSUMED. A remembered sheet is
# used only when
#   * its key matches: the md5 of the source, the compiler version, the engine, the stamp of every
#     script of the importer, the compiler, the vocabulary and the packs (name and modified time),
#     and how many ACEs the vocabulary holds - so a changed byte, a version bump, an edited lifter or a
#     pack that adds a verb all force a fresh lift; and
#   * it RE-EMITS BYTE FOR BYTE to the source it is being opened for. A remembered sheet that
#     disagrees is deleted and distrusted for the rest of the session, and the file is lifted fresh.
# A file changed outside the editor has another md5, so it lifts again; nothing here looks at a
# modified time of the .gd. A corrupt, foreign or half-written entry reads as a miss.
@tool
extends RefCounted

## Where the entries live: `.godot/` is the project's disposable cache folder, one binary resource per
## source file, named by the md5 of its path. A test points this at user:// so a run leaves no entry
## in the project.
static var cache_dir: String = "res://.godot/eventsheets_lift_cache/"
## Off, every open lifts fresh (and nothing is written).
static var enabled: bool = true
## How many entries a read used, and how many it threw away because they did not re-emit the source.
static var hits: int = 0
static var discarded: int = 0
## path -> key a remembered sheet failed the byte check for, in this session: not trusted again.
static var _distrusted: Dictionary = {}
static var _code_stamp_value: String = ""
static var _code_stamp_built: bool = false

const IMPORTER_PATH: String = "res://addons/eventforge/importer/gdscript_importer.gd"
const FORMAT: int = 1
const META_KEY: String = "eventsheets_lift_cache_key"
## The folders whose scripts decide what a lift answers: the importer and lifter, the compiler that
## byte-verifies it, the vocabulary it reverse-matches, and the packs that add to that vocabulary.
const STAMPED_ROOTS: PackedStringArray = ["res://addons/eventforge/", "res://addons/eventsheet/ace/",
	"res://eventsheet_addons/"]


## The remembered lifted sheet for `path`, or null (a miss: nothing remembered, another key, a bad file,
## or a sheet that did not re-emit the source). `source` is the file's text as read for this open.
static func fetch(path: String, source: String) -> EventSheetResource:
	if not enabled:
		return null
	var key: String = key_for(source, "", path)
	if _distrusted.get(path, "") == key:
		return null
	var entry_path: String = entry_path_for(path)
	if not FileAccess.file_exists(entry_path):
		return null
	# Anything that is not a binary resource at all (a half-written or foreign file) is a miss without
	# asking the engine to parse it and complain.
	var head: PackedByteArray = FileAccess.get_file_as_bytes(entry_path).slice(0, 4)
	if head.get_string_from_ascii() != "RSRC" and head.get_string_from_ascii() != "RSCC":
		_discard(path, key, entry_path, false)
		return null
	var loaded: Resource = ResourceLoader.load(entry_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var sheet: EventSheetResource = loaded as EventSheetResource
	if sheet == null or str(sheet.get_meta(META_KEY, "")) != key:
		_discard(path, key, entry_path, false)
		return null
	sheet.remove_meta(META_KEY)
	# A loaded resource carries the ENTRY's path (and its parts "<entry>::<id>"), where a fresh lift
	# carries none. Left on, the sheet answered "which file am I" with a file in `.godot/` to every
	# reader that asks resource_path (the secret marks are keyed by it, an unnamed compile writes its
	# output beside it), so it is taken off everything the entry held.
	_forget_entry_paths(sheet, sheet.resource_path, {})
	sheet.external_source_path = path
	load(IMPORTER_PATH)._recover_autoload_identity(sheet, path)
	# The binding check: the remembered sheet must write the file back exactly.
	if str(SheetCompiler.echo(sheet, true).get("output", "")) != source:
		_discard(path, key, entry_path, true)
		return null
	hits += 1
	return sheet


## Remembers a lifted sheet. Written beside its place and moved in, so a reader in another process
## sees the old entry or the new one and never half of one.
static func store(path: String, source: String, sheet: EventSheetResource) -> void:
	if not enabled or sheet == null:
		return
	var folder: String = ProjectSettings.globalize_path(cache_dir)
	if not DirAccess.dir_exists_absolute(folder):
		if DirAccess.make_dir_recursive_absolute(folder) != OK:
			return
	var key: String = key_for(source, "", path)
	sheet.set_meta(META_KEY, key)
	var entry_path: String = entry_path_for(path)
	var side_path: String = "%s%s.%d.tmp.res" % [cache_dir, path.md5_text(), OS.get_process_id()]
	var saved: Error = ResourceSaver.save(sheet, side_path)
	sheet.remove_meta(META_KEY)
	if saved != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(side_path))
		return
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(side_path), ProjectSettings.globalize_path(entry_path)) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(side_path))


## Forgets everything remembered in this folder and everything this session distrusts.
static func clear() -> void:
	_distrusted.clear()
	var folder: String = ProjectSettings.globalize_path(cache_dir)
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))


## The key a remembered sheet must carry to be used for `source`, the text of the file at `path`.
static func key_for(source: String, code_stamp: String = "", path: String = "") -> String:
	var stamp: String = code_stamp if not code_stamp.is_empty() else code_stamp_now()
	return "%d|%s|%s|%d|%s|%s" % [FORMAT, source.md5_text(), SheetCompiler.VERSION, ACERegistry.descriptor_count(),
		scene_stamp(path), stamp]


## What the project's SCENES tell the lift about the file at `path`, as a digest: the signal handlers a
## .tscn wires to it (lifted as triggers, with no connect line in the file), the nodes wearing a shader
## material it turns dials on, and the class of every node it names (the gate on a light row). None of
## it is in the file's text, so a scene edited, added or deleted between two opens of an unchanged file
## lifts it again instead of handing back what the old scene said. Asked of the same readers the lift
## asks, so the key holds exactly what the lift would read.
static func scene_stamp(path: String) -> String:
	if path.is_empty():
		return ""
	return ("%s|%s|%s" % [str(EventSheetSceneConnections.for_script(path)),
		str(EventSheetSceneEffects.wearers_of_script(path)),
		str(EventSheetSceneLights.classes_for_script(path))]).md5_text()


static func entry_path_for(path: String) -> String:
	return "%s%s.res" % [cache_dir, path.md5_text()]


## What the code that decides a lift is, once per session: the engine, and the name and modified time
## of every script under the stamped roots.
static func code_stamp_now() -> String:
	if _code_stamp_built:
		return _code_stamp_value
	var files: PackedStringArray = PackedStringArray()
	for root: String in STAMPED_ROOTS:
		_collect_scripts(root, files)
	files.sort()
	_code_stamp_value = stamp_of(files)
	_code_stamp_built = true
	return _code_stamp_value


## A digest of these files' names and modified times. Public so a test can change a file and ask
## again; `code_stamp_now` is this over the stamped roots.
static func stamp_of(files: PackedStringArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_MD5)
	var info: Dictionary = Engine.get_version_info()
	context.update(("%s|%s" % [info.get("hash", ""), info.get("string", "")]).to_utf8_buffer())
	for file_path: String in files:
		context.update(("%s|%d\n" % [file_path, FileAccess.get_modified_time(file_path)]).to_utf8_buffer())
	return context.finish().hex_encode()


## Drops the once-per-session stamp, for a test or a tool that has just edited a script.
static func forget_code_stamp() -> void:
	_code_stamp_built = false
	_code_stamp_value = ""


static func _collect_scripts(folder: String, into: PackedStringArray) -> void:
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() == "gd":
			into.append(folder.path_join(file))
	for sub: String in DirAccess.get_directories_at(folder):
		if sub.begins_with("."):
			continue
		_collect_scripts(folder.path_join(sub), into)


## Clears the entry's path off `value` and every resource inside it that the entry itself held,
## through arrays and dictionaries, each once. A resource from a file of its own (a texture, a
## script) keeps its path: only `entry_path` and its "::" parts are taken off.
static func _forget_entry_paths(value: Variant, entry_path: String, seen: Dictionary) -> void:
	if value is Array:
		for item: Variant in value:
			_forget_entry_paths(item, entry_path, seen)
		return
	if value is Dictionary:
		for item: Variant in (value as Dictionary).values():
			_forget_entry_paths(item, entry_path, seen)
		return
	if not (value is Resource):
		return
	var resource: Resource = value
	if seen.has(resource.get_instance_id()):
		return
	seen[resource.get_instance_id()] = true
	if not resource.resource_path.is_empty():
		if resource.resource_path != entry_path and not resource.resource_path.begins_with(entry_path + "::"):
			return
		resource.resource_path = ""
	for property: Dictionary in resource.get_property_list():
		if int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE \
				and int(property.get("type", TYPE_NIL)) in [TYPE_OBJECT, TYPE_ARRAY, TYPE_DICTIONARY]:
			_forget_entry_paths(resource.get(str(property.get("name", ""))), entry_path, seen)


static func _discard(path: String, key: String, entry_path: String, distrust: bool) -> void:
	discarded += 1
	if distrust:
		_distrusted[path] = key
	DirAccess.remove_absolute(ProjectSettings.globalize_path(entry_path))
