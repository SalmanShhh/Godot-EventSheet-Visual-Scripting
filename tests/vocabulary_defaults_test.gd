@tool
class_name VocabularyDefaultsTest
extends RefCounted

# EventForge - the Godot-words-by-default contract.
#
# Everything a reader sees by default is Godot's own word; the words other event-sheet editors use
# survive in exactly two places - the picker's search, and the opt-in Familiar preset on the Words
# page. Four promises:
#   1. the default vocabulary is the Godot preset, for a reader who never chose;
#   2. every lifecycle and tick reading says Godot's callback name by default and the other
#      editors' word in the Familiar preset;
#   3. typing EITHER word finds the same row in the picker;
#   4. no default string a reader meets uses "layout" to mean a scene.

const SUPPORT := preload("res://tests/support.gd")

## Where "layout" means something other than a scene: a Control or UI layout, an audio bus layout, an
## anchors preset, text direction, and the sheet's own canvas layout. Every entry is a phrase that
## may appear inside a user-visible string.
const LAYOUT_ALLOWED: PackedStringArray = [
	"bus layout", "layout preset", "Mirror Layout", "Layout Is Mirrored", "layout is mirrored",
	"Reset Layout", "layout direction", "layout for the language", "laid out", "layout of the",
	"settings-file layout", "Control layout", "the layout the", "keyboard layout", "grid layout",
	"layout mode", "page layout", "container layout", "UI layout", "the layout of",
	"layout view", "layout to X", "Layout To X", "layout change", "layout_", "Layout Edges stay",
	"branch layouts", "console layouts", "layout by", "layout with", "layouts on", "layout and",
	"layout, ", "layout engine", "layout pass", "buses the current layout", "a layout that overflows",
	"Layout preset",
]

## Whole strings that are the engine's own Control "Layout" group heading in an Inspector.
const LAYOUT_ALLOWED_EXACT: PackedStringArray = ["Layout"]


static func run() -> bool:
	var ok: bool = true
	ok = _default_is_godot() and ok
	ok = _callbacks_read_both_ways() and ok
	ok = _search_finds_both_words() and ok
	ok = _no_default_says_layout_for_a_scene() and ok
	return ok


## 1. A reader who never chose is on the Godot preset, and the Welcome answers switch nobody.
static func _default_is_godot() -> bool:
	var ok: bool = SUPPORT.check("vocabulary_defaults_test", "the default preset is Godot's",
		EventSheetWords.preset(), EventSheetWords.PRESET_GODOT)
	for choice: String in EventSheetWelcomeWindow.CAME_FROM_CHOICES:
		ok = SUPPORT.check("vocabulary_defaults_test", "the Welcome answer '%s' sets the Godot words" % choice,
			EventSheetWelcomeWindow.choice_settings(choice)["words"], EventSheetWords.PRESET_GODOT) and ok
	return ok


## 2. The lifecycle and tick readings, per preset.
static func _callbacks_read_both_ways() -> bool:
	var rows: Array = []
	for pair: Array in [
		["OnProcess", "On process", "Every tick"],
		["OnPhysicsProcess", "On physics process", "Every physics tick"],
	]:
		rows.append(["%s, Godot" % pair[0], EventSheetViewportReadingRows.tick_trigger_words(str(pair[0]), "", false), pair[1]])
		rows.append(["%s, Familiar" % pair[0], EventSheetViewportReadingRows.tick_trigger_words(str(pair[0]), "", true), pair[2]])
	for entry: Array in [
		["OnReady", true, "On ready", "On start of layout"],
		["OnReady", false, "On ready", "On ready"],
		["OnEnterTree", false, "On enter tree", "On created"],
		["OnExitTree", true, "On exit tree", "On end of layout"],
		["OnExitTree", false, "On exit tree", "On destroyed"],
	]:
		var godot: Dictionary = EventSheetViewportReadingRows.lifecycle_trigger_reading(
			str(entry[0]), "X", bool(entry[1]), "Player", false)
		var familiar: Dictionary = EventSheetViewportReadingRows.lifecycle_trigger_reading(
			str(entry[0]), "X", bool(entry[1]), "Player", true)
		rows.append(["%s scene root %s, Godot" % [entry[0], entry[1]], str(godot.get("text", "")), entry[2]])
		rows.append(["%s scene root %s, Familiar" % [entry[0], entry[1]], str(familiar.get("text", "")), entry[3]])
	var ok: bool = true
	for row: Array in rows:
		ok = SUPPORT.check("vocabulary_defaults_test", str(row[0]), row[1], row[2]) and ok
	# The Words page lists them, so it controls them.
	for key: String in ["scene_ready", "scene_exit", "node_enter", "node_exit", "every_tick", "every_physics_tick"]:
		ok = SUPPORT.check("vocabulary_defaults_test", "the Words page lists %s" % key,
			EventSheetWords.keys().has(key), true) and ok
	return ok


## 3. Either word reaches the row: the Godot word through the row's own name, the other editor's
## through the synonym table or the alias table.
static func _search_finds_both_words() -> bool:
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var ok: bool = true
	for entry: Array in [
		["OnReady", ["on ready", "on start of layout", "start of scene"]],
		["OnProcess", ["on process", "every tick", "every frame"]],
		["OnPhysicsProcess", ["on physics process", "every physics tick"]],
		["OnEnterTree", ["on enter tree", "on created"]],
		["OnExitTree", ["on exit tree", "on destroyed", "on end of layout"]],
		["ChangeScene", ["change scene", "go to layout", "goto layout"]],
		["ReloadScene", ["reload scene", "restart layout"]],
		["QueueFree", ["queue free", "destroy"]],
	]:
		var definition: ACEDefinition = registry.find_definition("Core", str(entry[0]))
		if definition == null:
			ok = SUPPORT.check("vocabulary_defaults_test", "%s is registered" % entry[0], false, true) and ok
			continue
		for query: String in (entry[1] as Array):
			ok = SUPPORT.check("vocabulary_defaults_test", "typing '%s' finds %s" % [query, entry[0]],
				_finds(query, definition), true) and ok
	return ok


static func _finds(query: String, definition: ACEDefinition) -> bool:
	if ACEPickerDialog._score_match(query, definition) > 0:
		return true
	for mapped: String in ACEPickerDialog._c3_synonym_queries(query):
		if ACEPickerDialog._score_match(mapped, definition) > 0:
			return true
	return ACEPickerDialog.alias_query_keys(query).has("%s::%s" % [definition.provider_id, definition.id])


## 4. No default string says layout for a scene. Two sweeps: every shipped descriptor's wording, and
## every literal handed to translate() in the editor and the compiler's own sources.
static func _no_default_says_layout_for_a_scene() -> bool:
	var offenders: PackedStringArray = PackedStringArray()
	var pattern: RegEx = RegEx.create_from_string("(?i)\\blayouts?\\b")
	for descriptor: ACEDescriptor in ACERegistry.get_builtin_descriptors():
		var strings: PackedStringArray = [descriptor.display_name, descriptor.list_name, descriptor.description]
		for param: ACEParam in descriptor.params:
			strings.append(param.display_name)
			strings.append(param.description)
		for text: String in strings:
			if _says_layout_for_a_scene(pattern, text):
				offenders.append("%s: %s" % [descriptor.ace_id, text.left(60)])
	var call_pattern: RegEx = RegEx.create_from_string("translate\\(\"((?:[^\"\\\\]|\\\\.)*)\"")
	for root: String in ["res://addons/eventsheet", "res://addons/eventforge"]:
		for path: String in _gd_files(root):
			var source: String = FileAccess.get_file_as_string(path)
			if not source.to_lower().contains("layout"):
				continue
			for found: RegExMatch in call_pattern.search_all(source):
				if _says_layout_for_a_scene(pattern, found.get_string(1)):
					offenders.append("%s: %s" % [path.get_file(), found.get_string(1).left(60)])
	return SUPPORT.check("vocabulary_defaults_test", "no default string says layout for a scene",
		offenders, PackedStringArray())


static func _says_layout_for_a_scene(pattern: RegEx, text: String) -> bool:
	if pattern.search(text) == null:
		return false
	if LAYOUT_ALLOWED_EXACT.has(text):
		return false
	for allowed: String in LAYOUT_ALLOWED:
		if text.contains(allowed):
			return false
	return true


static func _gd_files(root: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for name: String in DirAccess.get_files_at(root):
		if name.ends_with(".gd"):
			out.append("%s/%s" % [root, name])
	for sub: String in DirAccess.get_directories_at(root):
		out.append_array(_gd_files("%s/%s" % [root, sub]))
	return out
