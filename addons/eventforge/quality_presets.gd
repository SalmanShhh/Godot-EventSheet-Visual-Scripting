# EventForge - the quality presets, which are a FOLDER.
#
# A graphics quality word (Low, Medium, High) is not a setting of its own: it is a set of values over
# settings that already exist. So there is no registry here and no list to keep - the choices ARE the
# .tres files in res://settings/quality/, and everything that offers them (the Apply Quality field,
# the options page, the label a player reads) does the same thing: list the folder.
#
# What this file adds on top of listing is the three answers the folder cannot give on its own:
#
#   THE WORD          a preset's own name, or its file name capitalised, so a file dropped in the
#                     folder by hand is already a proper choice.
#   MEMBERSHIP        which settings a preset should answer for. A graphics setting DECLARED in the
#                     project belongs in every preset file, so `missing_fields` says which keys a
#                     file has not answered yet and `fill_missing` adds them with the declared
#                     default. That is what makes "declare motion_blur and every preset grows a
#                     motion_blur field" true without anyone editing three files.
#   THE STARTER SET   the three words a project expects to find. Written on request, never behind
#                     anyone's back, and only where the pack that defines the resource is installed.
#
# Everything here is PURE over paths and dictionaries apart from the two writers, which say so in
# their names. The resource class itself belongs to the Quality Preset pack rather than to the
# plugin, and is reached by path and duck-typed, so a project without that pack gets an honest "the
# pack is not installed" rather than a crash.
@tool
class_name EventSheetQualityPresets
extends RefCounted

## Where the words live. One folder, named once, so the field, the menu and the game agree.
const FOLDER: String = "res://settings/quality"

## The pack that defines the resource. Reached by path, never by class name: the plugin must not
## depend on a pack being installed, and this is the one question whose answer is "it is not".
const RESOURCE_SCRIPT: String = "res://eventsheet_addons/quality_preset_resource/quality_preset.gd"

## The three words a project starts with, and what each one stands for. Values over the graphics
## settings the Video page declares first; a project that declares more grows them through
## `fill_missing` rather than by editing this table.
const STARTER_PRESETS: Array[Dictionary] = [
	{"word": "Low", "rank": 0, "values": {"msaa": 0, "resolution_scale": 0.7, "debanding": false, "shadow_size": 1024}},
	{"word": "Medium", "rank": 1, "values": {"msaa": 2, "resolution_scale": 1.0, "debanding": true, "shadow_size": 2048}},
	{"word": "High", "rank": 2, "values": {"msaa": 4, "resolution_scale": 1.0, "debanding": true, "shadow_size": 4096}}
]


## Every preset file, lightest first by its own Rank and by path within a rank, so two machines list
## them the same way. Empty when the folder does not exist yet, which is what a project that has
## never asked for a preset looks like.
static func preset_paths() -> PackedStringArray:
	var found: Array[Dictionary] = []
	var folder: DirAccess = DirAccess.open(FOLDER)
	if folder == null:
		return PackedStringArray()
	for file_name: String in folder.get_files():
		var plain: String = file_name.trim_suffix(".remap")
		if not plain.ends_with(".tres"):
			continue
		var path: String = "%s/%s" % [FOLDER, plain]
		found.append({"path": path, "rank": rank_of(path)})
	found.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left["rank"]) == int(right["rank"]):
			return str(left["path"]) < str(right["path"])
		return int(left["rank"]) < int(right["rank"]))
	var paths: PackedStringArray = PackedStringArray()
	for entry: Dictionary in found:
		paths.append(str(entry["path"]))
	return paths


## The word one preset goes by: its own name if it gave itself one, otherwise its file name with a
## capital - which is what anyone naming a file "low.tres" already meant.
static func word_for(path: String) -> String:
	var preset: Resource = _load(path)
	var named: String = str(preset.get("preset_name")).strip_edges() if preset != null else ""
	if not named.is_empty():
		return named
	var stem: String = path.get_file().get_basename()
	return stem.substr(0, 1).to_upper() + stem.substr(1) if not stem.is_empty() else path


## What one preset stands for, as setting name to value. {} for a file that is not a preset - asked
## by property rather than by class so nothing here has to name the pack's type.
static func values_of(path: String) -> Dictionary:
	var preset: Resource = _load(path)
	var held: Variant = preset.get("values") if preset != null else null
	return held if held is Dictionary else {}


## How heavy a preset is, 0 lightest. This is the order "one step lower" walks.
static func rank_of(path: String) -> int:
	var preset: Resource = _load(path)
	return int(preset.get("rank")) if preset != null else 0


## The word for the values in force RIGHT NOW: the preset every one of whose values matches, or
## "Custom" when none does. Derived by comparison and never stored, so the label cannot lie - and so
## that deleting a preset file changes what a player's setup is CALLED and nothing else about it.
##
## `values_in_force` is setting name to value, which is what the Settings autoload holds.
static func word_in_force(values_in_force: Dictionary, paths: PackedStringArray = PackedStringArray()) -> String:
	for path: String in (preset_paths() if paths.is_empty() else paths):
		var wanted: Dictionary = values_of(path)
		if wanted.is_empty():
			continue
		var all_match: bool = true
		for setting_name: String in wanted:
			if values_in_force.get(setting_name) != wanted[setting_name]:
				all_match = false
				break
		if all_match:
			return word_for(path)
	return "Custom"


## The declared settings a preset file has not answered for yet. A graphics option declared in the
## project belongs in every preset - that is what makes a preset a macro over the settings rather
## than a fixed engine schema - so this is the difference, in declaration order.
static func missing_fields(preset_values: Dictionary, declared: PackedStringArray) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	for setting_name: String in declared:
		if not preset_values.has(setting_name):
			missing.append(setting_name)
	return missing


## The same difference the other way: keys a preset answers for that nothing declares any more. Kept
## rather than deleted (a value nobody asked about is harmless, and a setting may be declared by a
## sheet this reader has not opened), so this is a REPORT and not a cleanup.
static func unknown_fields(preset_values: Dictionary, declared: PackedStringArray) -> PackedStringArray:
	var unknown: PackedStringArray = PackedStringArray()
	for setting_name: Variant in preset_values.keys():
		if not declared.has(str(setting_name)):
			unknown.append(str(setting_name))
	return unknown


## A preset's values with every missing declared setting filled in from `defaults`, in declaration
## order after the ones it already had. Pure: hands back a new dictionary and touches nothing.
static func fill_missing(preset_values: Dictionary, declared: PackedStringArray, defaults: Dictionary) -> Dictionary:
	var grown: Dictionary = preset_values.duplicate(true)
	for setting_name: String in missing_fields(preset_values, declared):
		grown[setting_name] = defaults.get(setting_name)
	return grown


## The path a "New preset…" would take, next to the one being duplicated: the same name with a
## number after it, first number that is free. Pure over the paths it is handed, so a test can ask
## it without a folder.
static func next_free_path(from_path: String, taken: PackedStringArray) -> String:
	var stem: String = from_path.get_file().get_basename()
	if stem.is_empty():
		stem = "preset"
	for attempt: int in range(2, 100):
		var candidate: String = "%s/%s_%d.tres" % [FOLDER, stem, attempt]
		if not taken.has(candidate):
			return candidate
	return "%s/%s_new.tres" % [FOLDER, stem]


## Whether the pack that defines the resource is installed. The one honest answer a project without
## it can be given - a field that offers presets says so and offers the install rather than failing.
static func pack_installed() -> bool:
	return ResourceLoader.exists(RESOURCE_SCRIPT)


# ── the two writers ─────────────────────────────────────────────────────────────


## Writes one preset file. Returns "" on success and the reason otherwise, so a caller can show the
## reason rather than guess. Never called on its own account: a person pressed something.
static func write_preset(path: String, word: String, rank: int, values: Dictionary) -> String:
	if not pack_installed():
		return "The Quality Preset pack is not installed - add eventsheet_addons/quality_preset_resource/ first."
	if not DirAccess.dir_exists_absolute(FOLDER) and DirAccess.make_dir_recursive_absolute(FOLDER) != OK:
		return "Could not make %s." % FOLDER
	var script: GDScript = load(RESOURCE_SCRIPT)
	if script == null:
		return "The Quality Preset pack would not load."
	var preset: Resource = script.new()
	preset.set("preset_name", word)
	preset.set("rank", rank)
	preset.set("values", values.duplicate(true))
	var saved: int = ResourceSaver.save(preset, path)
	return "" if saved == OK else "Could not write %s (error %d)." % [path, saved]


## Writes the three starter words, skipping any that already exist. Returns "" on success and the
## reason otherwise. This is what an empty folder's "New preset…" does, so a project meets Low,
## Medium and High rather than one nameless file.
static func write_starter_presets() -> String:
	for starter: Dictionary in STARTER_PRESETS:
		var path: String = "%s/%s.tres" % [FOLDER, str(starter["word"]).to_lower()]
		if ResourceLoader.exists(path):
			continue
		var problem: String = write_preset(path, str(starter["word"]), int(starter["rank"]), starter["values"])
		if not problem.is_empty():
			return problem
	return ""


## One preset file, or null. Loaded through ResourceLoader.exists first so a stale path in a row
## costs a question rather than an error in the output log.
static func _load(path: String) -> Resource:
	return load(path) if ResourceLoader.exists(path) else null
