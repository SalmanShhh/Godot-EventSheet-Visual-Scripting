# EventSheet - the project's OWN code as vocabulary.
#
# Lists the classes a user's project publishes - global `class_name` scripts and registered
# autoloads - so their members can be offered as verbs with ZERO setup: no annotations, no
# moving files into eventsheet_addons/, no wizard. Member derivation itself is not repeated
# here: EventSheetClassDBSource already reflects any class (engine or user script) from its
# SCRIPT-level member lists, which is also why nothing in this path ever instantiates - a
# non-@tool script cannot be instantiated in the editor process, so instance reflection
# would list nothing exactly where the picker runs.
#
# What is deliberately NOT listed (the anti-flooding contract - a picker that dumps every
# public method of every script is worse than no feature at all):
#   • anything under res://addons/ - this plugin and every other plugin,
#   • anything under res://eventsheet_addons/ - packs already publish through the scanner,
#   • `_`-prefixed class names, the project's own privacy convention,
#   • loose scripts without a `class_name`, unless the user opts their folder in through
#     the extra-paths setting (a path-derived identity is weaker than a declared one, so it
#     is never the default door).
@tool
class_name EventSheetProjectScanner
extends RefCounted

## Opt-in extra folders/scripts (PackedStringArray). Empty by default: the declared-class
## and autoload sets are the safe automatic surface; this covers class_name-less code.
const EXTRA_PATHS_SETTING: String = "eventsheets/vocabulary/extra_paths"

const _PLUGIN_PREFIX: String = "res://addons/"
const _PACK_PREFIX: String = "res://eventsheet_addons/"

## Cached scan + the cheap signature it was built from (membership changes when the class
## list or the autoload/extra-path settings change - member CONTENT is cached downstream).
static var _cache: Array = []
static var _cache_signature: String = ""


## Every class this project publishes, deterministic and deduped. Entries are
## {name: String, path: String, kind: "class"|"autoload", autoload: String} - `autoload`
## is the singleton name for autoload entries (the emission target) and "" otherwise.
static func list_project_classes() -> Array:
	var signature: String = _current_signature()
	if signature == _cache_signature:
		return _cache.duplicate(true)
	var by_path: Dictionary = {}
	var bases: Dictionary = base_map()
	for class_info: Dictionary in ProjectSettings.get_global_class_list():
		var path: String = str(class_info.get("path", ""))
		var declared: String = str(class_info.get("class", ""))
		if not is_project_script_path(path) or not is_publishable_class_name(declared):
			continue
		if not is_scene_class(str(class_info.get("base", "")), bases):
			continue
		# A script that already carries `@ace_*` annotations publishes through the provider
		# system with the author's OWN names, kinds and hidden marks. Reflecting it again here
		# would list every public member a second time and quietly defeat `@ace_hidden`, so
		# annotated scripts belong to their annotations, not to this scan.
		if is_annotated_provider(path):
			continue
		by_path[path] = {"name": declared, "path": path, "kind": "class", "autoload": ""}
	# Autoloads win over the plain-class entry for the same script: a singleton emits
	# `Name.member()` with no target param, which is a different (and better) shape.
	for autoload_entry: Dictionary in list_autoloads():
		by_path[str(autoload_entry.get("path"))] = autoload_entry
	for extra_path: String in _extra_script_paths():
		if by_path.has(extra_path) or not is_project_script_path(extra_path):
			continue
		# Opting a folder in is an explicit statement of intent, so this path deliberately
		# skips BOTH automatic filters: the Node-derived rule, and the requirement for a
		# declared class_name. The latter is the whole stated purpose of the setting - a
		# class_name-less script falls back to its PascalCase file name, the same identity
		# the provider system already assigns such scripts.
		var extra_name: String = class_name_for_path(extra_path)
		if extra_name.is_empty():
			extra_name = extra_path.get_file().get_basename().to_pascal_case()
		if is_publishable_class_name(extra_name):
			by_path[extra_path] = {"name": extra_name, "path": extra_path, "kind": "class", "autoload": ""}
	var out: Array = []
	for path: Variant in by_path.keys():
		out.append(by_path[path])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	_cache = out
	_cache_signature = signature
	return out.duplicate(true)


## Registered autoloads whose script is GDScript, as scan entries. The singleton name is the
## setting's suffix (what game code types), while `name` prefers the script's own class_name
## so the picker labels it the way the author named it.
static func list_autoloads() -> Array:
	var out: Array = []
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var setting: String = str(property_info.get("name", ""))
		if not setting.begins_with("autoload/"):
			continue
		var path: String = str(ProjectSettings.get_setting(setting, "")).trim_prefix("*")
		if not path.ends_with(".gd") or not is_project_script_path(path):
			continue
		var singleton: String = setting.trim_prefix("autoload/")
		var declared: String = class_name_for_path(path)
		out.append({"name": declared if not declared.is_empty() else singleton,
			"path": path, "kind": "autoload", "autoload": singleton})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	return out


## True when a script publishes its own vocabulary through `## @ace_*` annotations. Anchored
## on the annotation FORM (a `##` line whose first token is an @ace_ directive) so a passing
## mention in prose does not count.
static func is_annotated_provider(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("##") and stripped.trim_prefix("##").strip_edges().begins_with("@ace_"):
			return true
	return false


## class_name -> its declared base, for resolving a custom base chain to an engine class.
static func base_map() -> Dictionary:
	var bases: Dictionary = {}
	for class_info: Dictionary in ProjectSettings.get_global_class_list():
		bases[str(class_info.get("class", ""))] = str(class_info.get("base", ""))
	return bases


## True when a class ultimately derives from Node - the things a sheet ACTS ON in a scene.
##
## This is the anti-flooding filter that matters, and it was chosen from measurement, not
## taste: scanning this project's declared classes yields 429 candidates, of which 21 are
## Node-derived. The 408 dropped are test classes, tool scripts, data Resources and plain
## RefCounted helpers - none of which a user picks an ACTION on. Data classes stay reachable
## where they belong (expressions, variables, the Self section); this filter only decides
## who earns an object card. A custom base chain (`Enemy extends BaseActor`) resolves by
## walking `bases` to the first engine class; the hop cap keeps a malformed cycle harmless.
static func is_scene_class(declared_base: String, bases: Dictionary) -> bool:
	var base: String = declared_base.strip_edges()
	var hops: int = 0
	while bases.has(base) and hops < 32:
		base = str(bases[base])
		hops += 1
	return ClassDB.class_exists(base) and ClassDB.is_parent_class(base, "Node")


## True when a script path belongs to the USER's project rather than to a plugin or to the
## bundled packs. Static + pure, so the exclusion contract is unit-testable without a
## project. (Also rejects non-.gd and empty input, so callers need no second guard.)
static func is_project_script_path(path: String) -> bool:
	var trimmed: String = path.strip_edges()
	if trimmed.is_empty() or not trimmed.ends_with(".gd"):
		return false
	if trimmed.begins_with(_PLUGIN_PREFIX) or trimmed.begins_with(_PACK_PREFIX):
		return false
	return trimmed.begins_with("res://")


## A class name is publishable when it is non-empty and not `_`-prefixed (the project's own
## privacy convention, mirrored from members). Static + pure.
static func is_publishable_class_name(declared: String) -> bool:
	var trimmed: String = declared.strip_edges()
	return not trimmed.is_empty() and not trimmed.begins_with("_")


## The class name a script declares, or "" when it declares none. Reads the SOURCE rather
## than loading the script: the scan runs over every project script, and parsing one line is
## far cheaper than a resource load (and cannot execute anything).
static func class_name_for_path(path: String) -> String:
	if not ResourceLoader.exists(path):
		return ""
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("class_name "):
			return stripped.trim_prefix("class_name ").get_slice(" ", 0).get_slice("extends", 0).strip_edges()
		if stripped.begins_with("func ") or stripped.begins_with("var "):
			break  # past the header - no class_name here
	return ""


## Tests only: forget the cached scan (the next call rebuilds).
static func reset_for_tests() -> void:
	_cache = []
	_cache_signature = ""


## Cheap membership signature: the class list and the settings that decide WHICH scripts are
## in scope. Member content is not part of it - that is EventSheetClassDBSource's cache.
static func _current_signature() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for class_info: Dictionary in ProjectSettings.get_global_class_list():
		parts.append("%s=%s" % [str(class_info.get("class", "")), str(class_info.get("path", ""))])
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var setting: String = str(property_info.get("name", ""))
		if setting.begins_with("autoload/"):
			parts.append("%s=%s" % [setting, str(ProjectSettings.get_setting(setting, ""))])
	parts.append_array(_extra_script_paths())
	return "|".join(parts)


## Every script named by the opt-in setting: listed .gd files directly, plus a recursive
## sweep of any listed folder.
static func _extra_script_paths() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for entry: Variant in ProjectSettings.get_setting(EXTRA_PATHS_SETTING, PackedStringArray()):
		var path: String = str(entry).strip_edges()
		if path.is_empty():
			continue
		if path.ends_with(".gd"):
			out.append(path)
		else:
			_collect_scripts(path, out)
	out.sort()
	return out


static func _collect_scripts(dir_path: String, into: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_scripts(full_path, into)
		elif entry.get_extension() == "gd":
			into.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
