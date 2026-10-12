# EventSheets - the reflected pack vocabulary, remembered on disk between editor sessions.
#
# WHY. Every pack script under eventsheet_addons/ publishes its verbs by reflection: the script is
# loaded (which compiles it) and its signals, properties and methods are read against its `## @ace_*`
# annotations. On this project's own fleet that is ~180 compiles plus ~4,600 definitions, several
# seconds that every editor session paid again on its first sheet tab although the packs had not
# changed since the last one. This remembers the definitions in `.godot/` and answers from them
# without loading the script at all, re-reflecting only the scripts that did change.
#
# THE ANSWER IS ALWAYS THE FRESH ANSWER. A remembered entry is used only when everything a fresh
# reflection would read is still what it was when the entry was written:
#   - the script's own bytes (modified time, length AND content hash - a same-second save that kept
#     the length is still caught, in this session and the next),
#   - every script it builds on (its base-script chain: inherited members are reflected too),
#   - every script its source, or a base's source, NAMES (a class_name or a res:// path: an
#     exported property typed with another class's enum takes its hint from that file),
#   - the autoload it is registered as, if any (an autoload's verbs call the singleton by name),
#   - and, for the whole file, the plugin version, the engine version, and the code that does the
#     reflecting (the generator, the analyzer and every script they name).
# Any difference and the entry is not trusted: the script is loaded and reflected exactly as before,
# and the new answer replaces the old one. A file that cannot be read whole, or was written by
# another format, is ignored in its entirety.
#
# WHAT IS NEVER REMEMBERED. A script whose published surface is computed by running code rather
# than declared - one that defines `_get_property_list` or the `_eventforge_register` hook, itself or
# in a base - is reflected fresh every time, because nothing on disk can say whether that code would
# answer differently today. So is a script whose definitions do not come back from the file equal to
# what went in (an object or a callable inside one).
#
# DEFINITIONS STAY IMMUTABLE. An entry is decoded into new ACEDefinition objects once per session
# and then shared by every refresh and every tab, exactly like the reflections the registry already
# keeps in memory; nothing here writes to a definition after it is built.
@tool
class_name EventSheetPackVocabularyCache
extends RefCounted

## Where the remembered vocabulary lives. `.godot/` is the project's own disposable cache folder:
## never committed, safe to delete, rebuilt on the next open.
const CACHE_PATH: String = "res://.godot/eventsheets_pack_vocabulary.bin"

## Bumped when the layout of the file below changes. A file of another format is ignored whole.
const FORMAT: int = 1

## The first bytes of the file, so a stray file at that path is never decoded as a vocabulary.
const MAGIC: String = "ESPV"

## Source text that marks a surface computed by code, which is never remembered.
const COMPUTED_SURFACE_MARKERS: PackedStringArray = ["_get_property_list", "_eventforge_register"]

## path -> {"stamp", "md5", "deps", "autoload", "definitions": Array[ACEDefinition]} for every
## script answered this session.
static var _entries: Dictionary = {}
## path -> the same entry in its stored form, read from disk and not yet asked for this session.
static var _stored: Dictionary = {}
## Whether the file on disk has been read this session. Set only by _read_disk, which does the read.
static var _disk_read: bool = false
## What the reflecting code looked like when this session first asked - see _code_stamp.
static var _code_stamp_value: String = ""
static var _code_stamp_built: bool = false
## class_name -> script path, built only when a script has to be reflected.
static var _class_paths: Dictionary = {}
static var _class_paths_built: bool = false
## Where this session reads and writes the file. CACHE_PATH, except in a test that must not touch
## the project's own copy.
static var cache_path: String = CACHE_PATH
## How the last call was answered, for tests and probes: the paths answered from memory or disk,
## and the paths that had to be loaded and reflected.
static var last_remembered: PackedStringArray = PackedStringArray()
static var last_reflected: PackedStringArray = PackedStringArray()
## The two patterns the dependency scan reads a source with, compiled on first use.
static var _identifier_pattern: RegEx = null
static var _path_pattern: RegEx = null
## The definition's own fields, read off the class on first use.
static var _fields: PackedStringArray = PackedStringArray()


## Every definition the scripts at `paths` publish, in path order - each script's own definitions
## in the order a fresh reflection lists them. A path that is missing or is not a script adds
## nothing, as before.
static func definitions_for(paths: Array[String]) -> Array[ACEDefinition]:
	_read_disk()
	last_remembered = PackedStringArray()
	last_reflected = PackedStringArray()
	var output: Array[ACEDefinition] = []
	var stat_memo: Dictionary = {}
	var autoloads: Dictionary = _autoload_names()
	var changed: bool = false
	for path: String in paths:
		if path.strip_edges().is_empty() or not ResourceLoader.exists(path):
			continue
		var entry: Dictionary = _entries.get(path, {})
		if not entry.is_empty() and _entry_holds(entry, path, autoloads, stat_memo):
			output.append_array(entry["definitions"])
			last_remembered.append(path)
			continue
		var stored: Dictionary = _stored.get(path, {})
		if not stored.is_empty():
			_stored.erase(path)
			if _entry_holds(stored, path, autoloads, stat_memo):
				var decoded: Array[ACEDefinition] = _decode_definitions(stored["definitions"])
				var promoted: Dictionary = stored.duplicate()
				promoted["encoded"] = stored["definitions"]
				promoted["definitions"] = decoded
				_entries[path] = promoted
				output.append_array(decoded)
				last_remembered.append(path)
				continue
			changed = true
		var reflected: Dictionary = _reflect(path, autoloads)
		last_reflected.append(path)
		output.append_array(reflected.get("definitions", [] as Array[ACEDefinition]))
		if bool(reflected.get("rememberable", false)):
			_entries[path] = reflected
			changed = true
		elif _entries.erase(path):
			changed = true
	if changed:
		_write_disk()
	return output


## Forgets everything remembered in this session and, with `delete_file`, the file on disk too. The
## next call reads the disk afresh.
static func forget(delete_file: bool = false) -> void:
	_entries.clear()
	_stored.clear()
	_disk_read = false
	_code_stamp_built = false
	_code_stamp_value = ""
	_class_paths_built = false
	_class_paths.clear()
	if delete_file and FileAccess.file_exists(cache_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_path))


# ── Whether a remembered entry still holds ────────────────────────────────────────────────────


## Whether an entry still describes the script at `path`: its own stamp and content hash, its
## autoload, and the stamp of every file it depends on, all as they were when it was written.
static func _entry_holds(entry: Dictionary, path: String, autoloads: Dictionary, stat_memo: Dictionary) -> bool:
	if str(entry.get("stamp", "")) != _file_stamp(path, stat_memo):
		return false
	if str(entry.get("autoload", "")) != str(autoloads.get(path, "")):
		return false
	if str(entry.get("md5", "")) != FileAccess.get_md5(path):
		return false
	for dep: Variant in entry.get("deps", PackedStringArray()):
		var separator: int = str(dep).rfind("|")
		var dep_path: String = str(dep).substr(0, separator)
		if _file_stamp(dep_path, stat_memo) != str(dep).substr(separator + 1):
			return false
	return true


## A file's modified time and length, as one string. "missing" for a file that is not there, so a
## deleted dependency differs from every stamp it was written with.
static func _file_stamp(path: String, stat_memo: Dictionary) -> String:
	if stat_memo.has(path):
		return stat_memo[path]
	var stamp: String = "missing"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file != null:
		stamp = "%d:%d" % [FileAccess.get_modified_time(path), file.get_length()]
	stat_memo[path] = stamp
	return stamp


## Script path -> autoload name, read the way the generator reads it: the first `autoload/` setting
## whose path, without the singleton star, is the script's own.
static func _autoload_names() -> Dictionary:
	var names: Dictionary = {}
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = str(property_info.get("name", ""))
		if not setting_name.begins_with("autoload/"):
			continue
		var autoload_path: String = str(ProjectSettings.get_setting(setting_name, "")).trim_prefix("*")
		if not names.has(autoload_path):
			names[autoload_path] = setting_name.trim_prefix("autoload/")
	return names


# ── Reflecting one script ─────────────────────────────────────────────────────────────────────


## A fresh reflection of one script, with everything needed to know later whether it still holds.
static func _reflect(path: String, autoloads: Dictionary) -> Dictionary:
	var resource: Resource = load(path)
	if not (resource is Script):
		return {}
	var script: Script = resource as Script
	var definitions: Array[ACEDefinition] = EventSheetACEGenerator.new().reflect_script(script)
	var reflected: Dictionary = {"definitions": definitions, "rememberable": false}
	# The chain of scripts it builds on, itself first: their members are reflected too, and their
	# sources name the files their types come from.
	var chain: Array[String] = []
	var base: Script = script
	while base != null:
		if not base.resource_path.is_empty() and not chain.has(base.resource_path):
			chain.append(base.resource_path)
		base = base.get_base_script()
	var named: Dictionary = {}
	for chain_path: String in chain:
		var source: String = FileAccess.get_file_as_string(chain_path)
		for marker: String in COMPUTED_SURFACE_MARKERS:
			if source.contains(marker):
				return reflected
		for named_path: String in _paths_named_in(source):
			named[named_path] = true
	for chain_path: String in chain:
		named[chain_path] = true
	named.erase(path)
	var encoded: Array = []
	for definition: ACEDefinition in definitions:
		encoded.append(_encode_definition(definition))
	# Only what comes back from the file equal to what went in may be remembered: an object would come
	# back as an id, a callable as nothing.
	if bytes_to_var(var_to_bytes(encoded)) != encoded:
		return reflected
	var stat_memo: Dictionary = {}
	var deps: PackedStringArray = PackedStringArray()
	var dep_paths: Array = named.keys()
	dep_paths.sort()
	for dep_path: Variant in dep_paths:
		deps.append("%s|%s" % [dep_path, _file_stamp(str(dep_path), stat_memo)])
	reflected["rememberable"] = true
	reflected["stamp"] = _file_stamp(path, stat_memo)
	reflected["md5"] = FileAccess.get_md5(path)
	reflected["deps"] = deps
	reflected["autoload"] = str(autoloads.get(path, ""))
	reflected["encoded"] = encoded
	return reflected


## Every script a source names: a global class_name it mentions, or a res:// or user:// .gd path it spells.
static func _paths_named_in(source: String) -> PackedStringArray:
	if not _class_paths_built:
		for info: Dictionary in ProjectSettings.get_global_class_list():
			_class_paths[str(info.get("class", ""))] = str(info.get("path", ""))
		_class_paths_built = true
	var found: Dictionary = {}
	for match_found: RegExMatch in _identifier_regex().search_all(source):
		var named: String = match_found.get_string()
		if _class_paths.has(named):
			found[_class_paths[named]] = true
	for match_found: RegExMatch in _path_regex().search_all(source):
		found[match_found.get_string()] = true
	return PackedStringArray(found.keys())


static func _identifier_regex() -> RegEx:
	if _identifier_pattern == null:
		_identifier_pattern = RegEx.create_from_string("\\b[A-Z][A-Za-z0-9_]*\\b")
	return _identifier_pattern


static func _path_regex() -> RegEx:
	if _path_pattern == null:
		_path_pattern = RegEx.create_from_string("(?:res|user)://[^\"'\\s]+\\.gd\\b")
	return _path_pattern


# ── A definition as plain data ────────────────────────────────────────────────────────────────


## The fields a definition carries, read off the class itself so a field added later is stored
## without anyone remembering to list it here.
static func _definition_fields() -> PackedStringArray:
	if _fields.is_empty():
		for property_info: Dictionary in ACEDefinition.new().get_property_list():
			if int(property_info.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				_fields.append(str(property_info.get("name", "")))
	return _fields


static func _encode_definition(definition: ACEDefinition) -> Dictionary:
	var encoded: Dictionary = {}
	for field: String in _definition_fields():
		encoded[field] = definition.get(field)
	return encoded


static func _decode_definitions(encoded_list: Array) -> Array[ACEDefinition]:
	var definitions: Array[ACEDefinition] = []
	for encoded: Variant in encoded_list:
		var definition: ACEDefinition = ACEDefinition.new()
		for field: Variant in (encoded as Dictionary):
			definition.set(str(field), (encoded as Dictionary)[field])
		definitions.append(definition)
	return definitions


# ── The file ──────────────────────────────────────────────────────────────────────────────────


## What the reflecting code is: the plugin and engine versions plus the stamp of the generator, the
## analyzer, this file and every script those name. Derived from their sources, so a helper the
## generator starts calling joins the stamp without a list to keep.
static func _code_stamp() -> String:
	if _code_stamp_built:
		return _code_stamp_value
	var roots: Array[String] = [
		(EventSheetACEGenerator as Script).resource_path,
		(EventSheetSemanticAnalyzer as Script).resource_path,
		(EventSheetPackVocabularyCache as Script).resource_path,
	]
	var files: Dictionary = {}
	for root: String in roots:
		files[root] = true
		for named: String in _paths_named_in(FileAccess.get_file_as_string(root)):
			files[named] = true
	var sorted: Array = files.keys()
	sorted.sort()
	var stat_memo: Dictionary = {}
	var parts: PackedStringArray = PackedStringArray([str(FORMAT), SheetCompiler.VERSION,
		str(Engine.get_version_info().get("hash", "")), str(Engine.get_version_info().get("string", ""))])
	for file_path: Variant in sorted:
		parts.append("%s|%s" % [file_path, _file_stamp(str(file_path), stat_memo)])
	_code_stamp_value = "\n".join(parts)
	_code_stamp_built = true
	return _code_stamp_value


## Reads the file once per session into _stored. Anything wrong with it - missing, short, another
## format, a payload whose hash does not match, a different reflecting code - leaves _stored empty.
static func _read_disk() -> void:
	if _disk_read:
		return
	_stored.clear()
	var payload: Variant = _read_payload()
	if payload is Dictionary and str((payload as Dictionary).get("code", "")) == _code_stamp():
		var entries: Variant = (payload as Dictionary).get("entries", {})
		if entries is Dictionary:
			_stored = entries
	_disk_read = true


static func _read_payload() -> Variant:
	if not FileAccess.file_exists(cache_path):
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(cache_path)
	var head: int = MAGIC.length() + 4 + 16
	if bytes.size() <= head or bytes.slice(0, MAGIC.length()).get_string_from_ascii() != MAGIC:
		return null
	if bytes.decode_u32(MAGIC.length()) != FORMAT:
		return null
	var body: PackedByteArray = bytes.slice(head)
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_MD5)
	hashing.update(body)
	if hashing.finish() != bytes.slice(MAGIC.length() + 4, head):
		return null
	return bytes_to_var(body)


## Writes every entry this session holds plus the stored ones it has not asked about yet. Written
## to a side file and moved into place, so a reader in another process sees the old file or the
## new one, never half of one.
static func _write_disk() -> void:
	var entries: Dictionary = _stored.duplicate()
	for path: Variant in _entries:
		var entry: Dictionary = _entries[path]
		entries[path] = {"stamp": entry["stamp"], "md5": entry["md5"], "deps": entry["deps"],
			"autoload": entry["autoload"], "definitions": entry["encoded"]}
	for path: Variant in entries.keys():
		if not FileAccess.file_exists(str(path)):
			entries.erase(path)
	var body: PackedByteArray = var_to_bytes({"code": _code_stamp(), "entries": entries})
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_MD5)
	hashing.update(body)
	var bytes: PackedByteArray = MAGIC.to_ascii_buffer()
	var format_bytes: PackedByteArray = PackedByteArray()
	format_bytes.resize(4)
	format_bytes.encode_u32(0, FORMAT)
	bytes.append_array(format_bytes)
	bytes.append_array(hashing.finish())
	bytes.append_array(body)
	var target: String = ProjectSettings.globalize_path(cache_path)
	if not DirAccess.dir_exists_absolute(target.get_base_dir()):
		return
	var side_path: String = "%s.%d.tmp" % [target, OS.get_process_id()]
	var file: FileAccess = FileAccess.open(side_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(bytes)
	file.close()
	if DirAccess.rename_absolute(side_path, target) != OK:
		DirAccess.remove_absolute(target)
		if DirAccess.rename_absolute(side_path, target) != OK:
			DirAccess.remove_absolute(side_path)
