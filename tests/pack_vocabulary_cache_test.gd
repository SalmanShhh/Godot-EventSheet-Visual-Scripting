# EventSheets - the pack vocabulary remembered on disk answers exactly what a fresh reflection does.
#
# THE CONTRACT: EventSheetPackVocabularyCache may answer a pack script's verbs without loading it,
# but only with definitions identical to the ones reflecting the script now would build - for every
# shipped pack, field for field and dump line for dump line - and it must stop trusting an entry the
# moment the script, a script it builds on or names, its autoload, or the file itself changes.
#
# Every run here points the cache at its own file under user://, so the project's real cache is
# never read, written or deleted by the suite.
@tool
class_name PackVocabularyCacheTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME: String = "pack_vocabulary_cache_test"
const TEST_CACHE: String = "user://eventsheets_pack_vocabulary_test.bin"
const PROBE_DIR: String = "user://pack_vocabulary_probe"
const BASE_PATH: String = "user://pack_vocabulary_probe/probe_base.gd"
const PROVIDER_PATH: String = "user://pack_vocabulary_probe/probe_provider.gd"
const NAMED_PATH: String = "user://pack_vocabulary_probe/probe_named.gd"

const BASE_SOURCE: String = """extends Node

## @ace_action
## @ace_name("Base Step")
## @ace_codegen_template("base_step()")
func base_step() -> void:
	pass
"""

const NAMED_SOURCE: String = """extends RefCounted

const LIMIT: int = 3
"""

const PROVIDER_SOURCE: String = """extends "res://pack_vocabulary_probe/probe_base.gd"

const Named = preload("user://pack_vocabulary_probe/probe_named.gd")

## @ace_action
## @ace_name("Jump High")
## @ace_codegen_template("jump()")
func jump(times: int = Named.LIMIT) -> void:
	pass
"""


static func run() -> bool:
	var saved_path: String = EventSheetPackVocabularyCache.cache_path
	EventSheetPackVocabularyCache.cache_path = TEST_CACHE
	EventSheetPackVocabularyCache.forget(true)
	var all_passed: bool = true
	all_passed = _every_pack_matches_a_fresh_reflection() and all_passed
	all_passed = _a_changed_input_is_never_trusted() and all_passed
	all_passed = _a_damaged_file_is_ignored() and all_passed
	EventSheetPackVocabularyCache.forget(true)
	EventSheetPackVocabularyCache.cache_path = saved_path
	EventSheetPackVocabularyCache.forget()
	return all_passed


## Every shipped pack: reflected and written once, then answered from the FILE alone in what is, to
## the cache, a new session - and the answer compared with a fresh reflection of the same script.
static func _every_pack_matches_a_fresh_reflection() -> bool:
	var paths: Array[String] = EventSheetAddonScanner.list_addon_scripts()
	EventSheetPackVocabularyCache.definitions_for(paths)
	EventSheetPackVocabularyCache.forget()
	var remembered_all: Array[ACEDefinition] = EventSheetPackVocabularyCache.definitions_for(paths)
	# Only a script whose surface is computed by code is reflected again; every other one came off disk.
	var computed: PackedStringArray = PackedStringArray()
	for path: String in paths:
		if _surface_is_computed(load(path) as Script):
			computed.append(path)
	var all_passed: bool = SUPPORT.check(TEST_NAME, "a second session reflects only computed surfaces",
		EventSheetPackVocabularyCache.last_reflected, computed)
	all_passed = SUPPORT.check(TEST_NAME, "every other pack is answered from the file",
		EventSheetPackVocabularyCache.last_remembered.size(), paths.size() - computed.size()) and all_passed
	var dump_pins: Dictionary = {}
	var field_pins: Dictionary = {}
	var fresh_all: Array[ACEDefinition] = []
	for path: String in paths:
		var fresh: Array[ACEDefinition] = EventSheetACEGenerator.new().reflect_script(load(path) as Script)
		fresh_all.append_array(fresh)
		dump_pins[path] = _dump_text(fresh)
		field_pins[path] = _field_text(fresh)
	var answer_dump: Callable = func(path: String) -> String:
		return _dump_text(EventSheetPackVocabularyCache.definitions_for([path] as Array[String]))
	var answer_fields: Callable = func(path: String) -> String:
		return _field_text(EventSheetPackVocabularyCache.definitions_for([path] as Array[String]))
	all_passed = SUPPORT.pin_table(TEST_NAME + " dump", dump_pins, answer_dump) and all_passed
	all_passed = SUPPORT.pin_table(TEST_NAME + " fields", field_pins, answer_fields) and all_passed
	all_passed = SUPPORT.check(TEST_NAME, "the whole fleet answers the fresh fleet, in order",
		_field_text(remembered_all), _field_text(fresh_all)) and all_passed
	# The registry stores the remembered definitions where the scanned sources used to be stored.
	var sources: Array[Object] = []
	for path: String in paths:
		var script: Script = load(path) as Script
		if script.can_instantiate():
			var instance: Variant = script.new()
			sources.append(instance if instance is Object else script)
		else:
			sources.append(script)
	var by_sources: EventSheetACERegistry = EventSheetACERegistry.new()
	by_sources.refresh_from_sources(sources, true)
	var by_cache: EventSheetACERegistry = EventSheetACERegistry.new()
	by_cache.refresh_from_sources([] as Array[Object], true, remembered_all)
	for source: Object in sources:
		if source is Node:
			(source as Node).free()
	all_passed = SUPPORT.check(TEST_NAME, "the registry lists the same verbs in the same order",
		_identifiers(by_cache.get_all_definitions()), _identifiers(by_sources.get_all_definitions())) and all_passed
	return all_passed


## A probe provider that builds on a base script and names a third: each of the three, the content
## at an unchanged length, and the autoload it is registered as, sends it back to a fresh reflection,
## and every answer equals what reflecting the script right now gives.
static func _a_changed_input_is_never_trusted() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROBE_DIR))
	_write(BASE_PATH, BASE_SOURCE)
	_write(NAMED_PATH, NAMED_SOURCE)
	_write(PROVIDER_PATH, PROVIDER_SOURCE.replace("res://pack_vocabulary_probe/", PROBE_DIR + "/"))
	var probe: Array[String] = [PROVIDER_PATH]
	var reflected: PackedStringArray = PackedStringArray(probe)
	EventSheetPackVocabularyCache.forget(true)
	var rows: Array = []
	_ask(rows, "a first answer reflects", "last_reflected", reflected)
	_ask(rows, "the same session remembers", "last_remembered", reflected)
	EventSheetPackVocabularyCache.forget()
	_ask(rows, "the next session remembers from the file", "last_remembered", reflected)

	# Same length, same second: only the content hash can tell.
	_write(PROVIDER_PATH, FileAccess.get_file_as_string(PROVIDER_PATH).replace("Jump High", "Leap High"))
	_reload(PROVIDER_PATH)
	_ask(rows, "a same-length edit is reflected", "last_reflected", reflected)
	EventSheetPackVocabularyCache.forget()
	_ask(rows, "and the next session reads the edit back", "last_remembered", reflected)
	rows.append(["the edited name is the one answered", _names(EventSheetPackVocabularyCache.definitions_for(probe))
		.contains("Leap High"), true])

	# The base script it builds on.
	_write(BASE_PATH, BASE_SOURCE.replace("Base Step", "Base Stride") + "\n")
	_reload(BASE_PATH)
	_reload(PROVIDER_PATH)
	_ask(rows, "an edited base script is reflected", "last_reflected", reflected)

	# A script it only names: its constant is the parameter's default.
	_write(NAMED_PATH, NAMED_SOURCE.replace("3", "7") + "\n")
	_reload(NAMED_PATH)
	_reload(PROVIDER_PATH)
	_ask(rows, "an edited named script is reflected", "last_reflected", reflected)
	rows.append(["and its constant reaches the default", _defaults(EventSheetPackVocabularyCache.definitions_for(probe)), "7"])

	# Registered as an autoload: its verbs call the singleton, so the entry is not the same entry.
	ProjectSettings.set_setting("autoload/VocabularyProbe", "*" + PROVIDER_PATH)
	_ask(rows, "becoming an autoload is reflected", "last_reflected", reflected)
	ProjectSettings.set_setting("autoload/VocabularyProbe", null)
	_ask(rows, "and ceasing to be one", "last_reflected", reflected)

	# A script that computes its own surface is never remembered.
	_write(PROVIDER_PATH, FileAccess.get_file_as_string(PROVIDER_PATH)
		+ "\n\nfunc _get_property_list() -> Array[Dictionary]:\n\treturn []\n")
	_reload(PROVIDER_PATH)
	_ask(rows, "a computed surface is reflected", "last_reflected", reflected)
	_ask(rows, "and reflected again every time", "last_reflected", reflected)
	for path: String in [PROVIDER_PATH, BASE_PATH, NAMED_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_DIR))
	return SUPPORT.pins(TEST_NAME, rows)


## Asks the cache for the probe once and adds two rows: how it was answered (`which` names the
## static that must hold the probe), and that the answer is what a fresh reflection gives now.
static func _ask(rows: Array, label: String, which: String, expected: PackedStringArray) -> void:
	var answered: Array[ACEDefinition] = EventSheetPackVocabularyCache.definitions_for([PROVIDER_PATH] as Array[String])
	rows.append([label, _how_answered(which), expected])
	var fresh: Array[ACEDefinition] = EventSheetACEGenerator.new().reflect_script(load(PROVIDER_PATH) as Script)
	rows.append([label + " - the answer is the fresh one", _field_text(answered), _field_text(fresh)])


static func _how_answered(which: String) -> PackedStringArray:
	return EventSheetPackVocabularyCache.last_reflected if which == "last_reflected" 		else EventSheetPackVocabularyCache.last_remembered


## A file that is damaged, or written by another format, is never decoded: everything is reflected.
static func _a_damaged_file_is_ignored() -> bool:
	var probe: Array[String] = ["res://eventsheet_addons/demo_health_addon.gd"]
	EventSheetPackVocabularyCache.forget(true)
	EventSheetPackVocabularyCache.definitions_for(probe)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(TEST_CACHE)
	var rows: Array = []
	var damaged: PackedByteArray = bytes.duplicate()
	damaged[damaged.size() - 3] = (damaged[damaged.size() - 3] + 1) % 256
	_write_bytes(TEST_CACHE, damaged)
	EventSheetPackVocabularyCache.forget()
	EventSheetPackVocabularyCache.definitions_for(probe)
	rows.append(["a payload that fails its hash is ignored", EventSheetPackVocabularyCache.last_reflected,
		PackedStringArray(probe)])
	var other_format: PackedByteArray = bytes.duplicate()
	other_format.encode_u32(EventSheetPackVocabularyCache.MAGIC.length(), EventSheetPackVocabularyCache.FORMAT + 1)
	_write_bytes(TEST_CACHE, other_format)
	EventSheetPackVocabularyCache.forget()
	EventSheetPackVocabularyCache.definitions_for(probe)
	rows.append(["another format is ignored", EventSheetPackVocabularyCache.last_reflected, PackedStringArray(probe)])
	_write_bytes(TEST_CACHE, bytes.slice(0, 10))
	EventSheetPackVocabularyCache.forget()
	EventSheetPackVocabularyCache.definitions_for(probe)
	rows.append(["a short file is ignored", EventSheetPackVocabularyCache.last_reflected, PackedStringArray(probe)])
	EventSheetPackVocabularyCache.forget()
	EventSheetPackVocabularyCache.definitions_for(probe)
	rows.append(["and the rewritten file is trusted again", EventSheetPackVocabularyCache.last_remembered,
		PackedStringArray(probe)])
	return SUPPORT.pins(TEST_NAME, rows)


static func _surface_is_computed(script: Script) -> bool:
	var base: Script = script
	while base != null:
		var source: String = FileAccess.get_file_as_string(base.resource_path)
		if source.contains("_get_property_list") or source.contains("_eventforge_register"):
			return true
		base = base.get_base_script()
	return false


## The registry dump's lines for these definitions, which is what a sheet written against them
## depends on.
static func _dump_text(definitions: Array[ACEDefinition]) -> String:
	var built: Dictionary = {}
	for definition: ACEDefinition in definitions:
		var entry: Dictionary = EventForgeSuccessors.entry_of(definition)
		if not entry.is_empty():
			built[str(entry["key"])] = entry
	return EventForgeRegistryDump.text(built)


## Every field of every definition, in order, spelled with its type (var_to_str writes a typed
## array as Array[String](...)), so a value that comes back with another type differs.
static func _field_text(definitions: Array[ACEDefinition]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in definitions:
		var fields: PackedStringArray = PackedStringArray()
		for property_info: Dictionary in definition.get_property_list():
			if int(property_info.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var field: String = str(property_info.get("name", ""))
				fields.append("%s=%s" % [field, var_to_str(definition.get(field))])
		lines.append(" | ".join(fields))
	return "\n".join(lines)


static func _identifiers(definitions: Array[ACEDefinition]) -> PackedStringArray:
	var identifiers: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in definitions:
		identifiers.append(definition.get_identifier())
	return identifiers


static func _names(definitions: Array[ACEDefinition]) -> String:
	var names: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in definitions:
		names.append(definition.display_name)
	names.sort()
	return ",".join(names)


static func _defaults(definitions: Array[ACEDefinition]) -> String:
	for definition: ACEDefinition in definitions:
		if definition.display_name.ends_with("High"):
			for parameter: Variant in definition.parameters:
				return str((parameter as Dictionary).get("default_value", ""))
	return ""


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


## A script edited on disk, compiled again so the next load() sees the edit rather than the copy
## the resource cache still holds.
static func _reload(path: String) -> void:
	var script: GDScript = load(path) as GDScript
	if script != null:
		script.source_code = FileAccess.get_file_as_string(path)
		script.reload(true)
