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
## Whether this session has swept the folder yet (see `prune`).
static var _pruned: bool = false

const IMPORTER_PATH: String = "res://addons/eventforge/importer/gdscript_importer.gd"
const FORMAT: int = 1
const INDEX_FILE: String = "index.json"
## The caps `prune` holds the folder to. Measured by opening every .gd under eventsheet_addons/ (181
## files) with the cache on: 181 entries, 9.7 MB in all, 53 KB on average, 623 KB the largest. So a
## project of several times the shipped library fits: 1,000 entries and 64 MB (about 6.6 runs of the
## whole shipped set) never evicts a live project, and still bounds the folder for good.
const MAX_ENTRIES: int = 1000
const MAX_BYTES: int = 64 * 1024 * 1024
## A tmp file older than this belongs to a process that died mid-write.
const STALE_TMP_SECONDS: int = 86400
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
	_prune_once()
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
	if str(EventSheetCompiler.echo(sheet, true).get("output", "")) != source:
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
	_prune_once()
	var key: String = key_for(source, "", path)
	sheet.set_meta(META_KEY, key)
	var entry_path: String = entry_path_for(path)
	var side_path: String = "%s%s.%d.tmp.res" % [cache_dir, path.md5_text(), OS.get_process_id()]
	var saved: Error = ResourceSaver.save(sheet, side_path)
	sheet.remove_meta(META_KEY)
	if saved != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(side_path))
		return
	# The index row goes in before the entry does, so an entry is never in the folder without a name.
	var index: Dictionary = _read_index()
	index[path.md5_text()] = path
	_write_index(index)
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(side_path), ProjectSettings.globalize_path(entry_path)) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(side_path))


## Sweeps the folder: drops every entry whose source file no longer exists (renamed or deleted), every
## entry the index cannot name a source for, tmp files a dead process left, and then the oldest
## entries beyond `max_entries` or `max_bytes`. Returns how many entry files it removed. Off, it
## touches nothing. The index (md5 of a path -> the path) is what lets an entry, which is named only
## by a digest, be checked against the disk.
static func prune(max_entries: int = MAX_ENTRIES, max_bytes: int = MAX_BYTES) -> int:
	if not enabled:
		return 0
	var folder: String = ProjectSettings.globalize_path(cache_dir)
	if not DirAccess.dir_exists_absolute(folder):
		return 0
	var index: Dictionary = _read_index()
	var kept: Array = []
	var removed: int = 0
	var now: int = int(Time.get_unix_time_from_system())
	for file: String in DirAccess.get_files_at(folder):
		var full: String = folder.path_join(file)
		if file.ends_with(".tmp.res"):
			if now - FileAccess.get_modified_time(full) > STALE_TMP_SECONDS:
				DirAccess.remove_absolute(full)
			continue
		if file.get_extension() != "res":
			continue
		var source: String = str(index.get(file.get_basename(), ""))
		if source.is_empty() or not FileAccess.file_exists(source):
			DirAccess.remove_absolute(full)
			index.erase(file.get_basename())
			removed += 1
			continue
		kept.append({"id": file.get_basename(), "full": full, "time": FileAccess.get_modified_time(full),
			"size": FileAccess.get_file_as_bytes(full).size()})
	kept.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["time"]) < int(b["time"]))
	var total: int = 0
	for entry: Dictionary in kept:
		total += int(entry["size"])
	var count: int = kept.size()
	for entry: Dictionary in kept:
		if count <= max_entries and total <= max_bytes:
			break
		DirAccess.remove_absolute(str(entry["full"]))
		index.erase(str(entry["id"]))
		count -= 1
		total -= int(entry["size"])
		removed += 1
	# Index rows whose entry is gone (a row is written before its entry is moved in) go too.
	for id: String in index.keys():
		if not FileAccess.file_exists("%s%s.res" % [cache_dir, id]):
			index.erase(id)
	_write_index(index)
	return removed


## The first use in a session sweeps once, so a long-lived project's folder is checked a session at a
## time and never on every open.
static func _prune_once() -> void:
	if _pruned or not enabled:
		return
	_pruned = true
	prune()


static func _index_path() -> String:
	return cache_dir + INDEX_FILE


static func _read_index() -> Dictionary:
	if not FileAccess.file_exists(_index_path()):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_index_path()))
	return parsed if parsed is Dictionary else {}


## Written beside its place and moved in, like an entry, so a reader sees the old index or the new.
static func _write_index(index: Dictionary) -> void:
	var side_path: String = "%s%s.%d.tmp.res" % [cache_dir, INDEX_FILE, OS.get_process_id()]
	var file: FileAccess = FileAccess.open(side_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(index))
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(side_path), ProjectSettings.globalize_path(_index_path())) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(side_path))


## Forgets everything remembered in this folder and everything this session distrusts.
static func clear() -> void:
	_distrusted.clear()
	_pruned = false
	var folder: String = ProjectSettings.globalize_path(cache_dir)
	if not DirAccess.dir_exists_absolute(folder):
		return
	for file: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))


## The key a remembered sheet must carry to be used for `source`, the text of the file at `path`.
static func key_for(source: String, code_stamp: String = "", path: String = "") -> String:
	var stamp: String = code_stamp if not code_stamp.is_empty() else code_stamp_now()
	return "%d|%s|%s|%d|%s|%s" % [FORMAT, source.md5_text(), EventSheetCompiler.VERSION, ACERegistry.descriptor_count(),
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
