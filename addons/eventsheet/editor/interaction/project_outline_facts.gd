@tool
class_name EventSheetProjectOutline
extends RefCounted

# T13 - THE PROJECT BAR'S FACTS: the project read by KIND rather than by folder.
#
# Godot's FileSystem dock answers "where does this file live". This answers "what are the things in
# this project" - scenes, scripts, classes, base classes, behaviors, sounds, files - which is the
# question a reader coming from another event-sheet editor asks first, and the one no dock in Godot
# answers today.
#
# Everything here is DERIVED. There is no project file of its own, no registry and nothing to keep
# in step: the file lists come from the same recursive scan the translation sweep uses, the class
# list and the autoloads from the vocabulary scanner, the packs from the installed pack folder. The
# bar that draws this listens to the same `filesystem_changed` the rest of the plugin does and asks
# again; between two pings the answer is the cached one.
#
# The split between `outline_from` (pure, takes a scan) and `outline` (does the scan) is what lets a
# test pin the exact tree for a fixture project without a real res:// behind it.

## The sections, in the order the bar draws them. Frozen: a saved fold state names these.
const KIND_ORDER: PackedStringArray = [
	"scenes", "scripts", "classes", "base_classes", "behaviors", "sounds", "files"
]

## Godot's word for each section, then the word other event-sheet editors use for the same thing.
## Familiar Words (View menu) decides which of the two leads and which one is muted beside it.
const KIND_WORDS: Dictionary = {
	"scenes": ["Scenes", "layouts"],
	"scripts": ["Scripts", "event sheets"],
	"classes": ["Classes", "object types"],
	"base_classes": ["Base classes", "families"],
	"behaviors": ["Behaviors", "behaviors"],
	"sounds": ["Sounds", "sounds"],
	"files": ["Files", "files"],
}

## Audio a project plays. Anything else with a texture/font/data extension falls into FILES.
const SOUND_EXTENSIONS: Array = ["ogg", "wav", "mp3"]

## Where the installed behavior packs live - the same folder the vocabulary scans.
const PACKS_DIR: String = "res://eventsheet_addons"


## One section's heading. With Familiar Words OFF the Godot word leads and the other editor's word
## trails muted; with it ON the two swap, which is the whole promise of that toggle: the reader
## always sees BOTH words, and the one they think in comes first.
##
## "Base classes" defers to the shared word helper when the project has one (the word is a setting -
## Family / Base class / Kind / your own), and falls back to the literal when it does not.
static func heading_for(kind: String, familiar_words: bool) -> String:
	var words: Array = KIND_WORDS.get(kind, [kind.capitalize(), kind])
	var godot_word: String = str(words[0])
	var familiar_word: String = str(words[1])
	if kind == "base_classes":
		var chosen: String = _family_word(familiar_words)
		if not chosen.is_empty():
			return chosen
	if godot_word == familiar_word:
		return EventSheetL10n.translate(godot_word)
	if familiar_words:
		return "%s  (%s)" % [EventSheetL10n.translate(familiar_word).capitalize(),
			EventSheetL10n.translate(godot_word).to_lower()]
	return "%s  (%s)" % [EventSheetL10n.translate(godot_word), EventSheetL10n.translate(familiar_word)]


## The project's own word for a base class, when the setting that owns it has shipped. "" otherwise,
## which leaves the heading on the literal pair above. Probed by PATH so this file never names a
## class that may not exist yet and the boot path stays lazy.
static func _family_word(familiar_words: bool) -> String:
	const HELPER_PATH: String = "res://addons/eventsheet/editor/interaction/family_word.gd"
	if not ResourceLoader.exists(HELPER_PATH):
		return ""
	var helper: Script = load(HELPER_PATH) as Script
	if helper == null or not helper.has_method("heading_for"):
		return ""
	return str(helper.call("heading_for", familiar_words))


## The raw material the outline is built from, all of it read rather than stored:
##   {"scenes", "scripts", "sounds", "others": PackedStringArray,
##    "classes": Array[{name, path}], "autoloads": Dictionary singleton -> path,
##    "packs": PackedStringArray}
## `root` is a parameter so a test can point the whole thing at a fixture folder.
static func scan(root: String = "res://", packs_dir: String = PACKS_DIR) -> Dictionary:
	var scenes: PackedStringArray = EventSheetTranslationScan.files_under(root, ["tscn"])
	var scripts: PackedStringArray = EventSheetTranslationScan.files_under(root, ["gd"])
	var sounds: PackedStringArray = EventSheetTranslationScan.files_under(root, SOUND_EXTENSIONS)
	var others: PackedStringArray = EventSheetTranslationScan.files_under(
		root, ["png", "svg", "ttf", "otf", "json", "csv", "gdshader", "tres"])
	return {
		"scenes": scenes,
		"scripts": scripts,
		"sounds": sounds,
		"others": others,
		"classes": _declared_classes(scripts),
		"autoloads": _autoload_paths(),
		"packs": _pack_names(packs_dir),
	}


## Every `class_name` the scanned scripts declare, as [{name, path, base}] sorted by name. Read from
## the file text rather than from ClassDB so a fixture folder answers exactly like a real project.
static func _declared_classes(scripts: PackedStringArray) -> Array:
	var found: Array = []
	for path: String in scripts:
		var source: String = FileAccess.get_file_as_string(path)
		if source.is_empty():
			continue
		var declared: String = ""
		var base: String = ""
		for line: String in source.split("\n"):
			var stripped: String = line.strip_edges()
			if stripped.begins_with("class_name "):
				declared = stripped.substr(11).strip_edges().split(" ")[0]
			elif stripped.begins_with("extends "):
				base = stripped.substr(8).strip_edges().split(" ")[0]
			if not declared.is_empty() and not base.is_empty():
				break
		if declared.is_empty():
			continue
		found.append({"name": declared, "path": path, "base": base})
	found.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("name", "")) < str(right.get("name", "")))
	return found


## singleton name -> script path, for the "autoload ·" note on a script entry. Empty outside a real
## project (a fixture scan has no autoloads, and that is the right answer).
static func _autoload_paths() -> Dictionary:
	var found: Dictionary = {}
	for setting: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = str(setting.get("name", ""))
		if not setting_name.begins_with("autoload/"):
			continue
		var value: String = str(ProjectSettings.get_setting(setting_name, ""))
		found[setting_name.substr(9)] = value.trim_prefix("*")
	return found


## The installed behavior packs, by folder name. Sorted so the bar is stable between rebuilds.
static func _pack_names(packs_dir: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(packs_dir):
		return names
	for pack_dir: String in DirAccess.get_directories_at(packs_dir):
		names.append(pack_dir)
	names.sort()
	return names


## The outline itself: {kind: Array[{label, kind, path, note}]} for every kind in KIND_ORDER, in
## that order. Pure - hand it a scan and it always answers the same thing.
##
## `coverage_by_path` is the one thing FileSystem cannot show and this bar can: how much of a script
## already reads as events. It is passed in rather than measured here, because measuring means
## opening every .gd in the project, and a hidden bar must cost nothing.
static func outline_from(scanned: Dictionary, coverage_by_path: Dictionary = {}) -> Dictionary:
	var autoloads: Dictionary = scanned.get("autoloads", {})
	var by_path: Dictionary = {}
	for singleton: Variant in autoloads:
		by_path[str(autoloads[singleton])] = str(singleton)
	var classes: Array = scanned.get("classes", [])
	var class_by_path: Dictionary = {}
	for entry: Variant in classes:
		class_by_path[str((entry as Dictionary).get("path", ""))] = str((entry as Dictionary).get("name", ""))
	var built: Dictionary = {}
	built["scenes"] = _file_entries(scanned.get("scenes", PackedStringArray()), "scene")
	var scripts: Array = []
	for path: String in scanned.get("scripts", PackedStringArray()):
		var label: String = str(class_by_path.get(path, path.get_file().get_basename().capitalize()))
		var note: String = path.get_file()
		if by_path.has(path):
			label = str(by_path[path])
			note = "%s · %s" % [EventSheetL10n.translate("autoload"), path.get_file()]
		var coverage: String = str(coverage_by_path.get(path, ""))
		if not coverage.is_empty():
			note = "%s · %s" % [note, coverage]
		scripts.append({"label": label, "kind": "script", "path": path, "note": note})
	built["scripts"] = scripts
	var class_entries: Array = []
	for entry: Variant in classes:
		var record: Dictionary = entry
		class_entries.append({
			"label": str(record.get("name", "")), "kind": "class",
			"path": str(record.get("path", "")), "note": str(record.get("path", "")).get_file()
		})
	built["classes"] = class_entries
	built["base_classes"] = base_class_entries(classes)
	var behaviors: Array = []
	for pack: String in scanned.get("packs", PackedStringArray()):
		behaviors.append({"label": pack.capitalize(), "kind": "behavior",
			"path": "%s/%s" % [PACKS_DIR, pack], "note": pack})
	built["behaviors"] = behaviors
	built["sounds"] = _file_entries(scanned.get("sounds", PackedStringArray()), "sound")
	built["files"] = _folder_entries(scanned.get("others", PackedStringArray()))
	return built


## Which classes something else extends, and who extends them - the inheritance the project already
## has, read as one line each ("Enemy  Slime · Bat"). A base nothing extends is not a base class.
static func base_class_entries(classes: Array) -> Array:
	var children: Dictionary = {}
	var declared: Dictionary = {}
	for entry: Variant in classes:
		declared[str((entry as Dictionary).get("name", ""))] = str((entry as Dictionary).get("path", ""))
	for entry: Variant in classes:
		var record: Dictionary = entry
		var base: String = str(record.get("base", ""))
		if base.is_empty() or not declared.has(base):
			continue
		if not children.has(base):
			children[base] = PackedStringArray()
		var list: PackedStringArray = children[base]
		list.append(str(record.get("name", "")))
		children[base] = list
	var bases: Array = children.keys()
	bases.sort()
	var entries: Array = []
	for base_name: Variant in bases:
		var kids: PackedStringArray = children[base_name]
		entries.append({"label": str(base_name), "kind": "base_class",
			"path": str(declared.get(base_name, "")), "note": " · ".join(kids)})
	return entries


static func _file_entries(paths: PackedStringArray, kind: String) -> Array:
	var entries: Array = []
	for path: String in paths:
		entries.append({"label": path.get_file().get_basename().capitalize(), "kind": kind,
			"path": path, "note": path.get_file()})
	return entries


## FILES is deliberately folders, not files: the point of the section is "and there is also art,
## data and shaders over there", not a second FileSystem dock.
static func _folder_entries(paths: PackedStringArray) -> Array:
	var counts: Dictionary = {}
	for path: String in paths:
		var folder: String = path.get_base_dir()
		counts[folder] = int(counts.get(folder, 0)) + 1
	var folders: Array = counts.keys()
	folders.sort()
	var entries: Array = []
	for folder: Variant in folders:
		var count: int = int(counts[folder])
		entries.append({
			"label": str(folder).get_file() if not str(folder).get_file().is_empty() else str(folder),
			"kind": "folder", "path": str(folder),
			"note": EventSheetL10n.translate("1 file") if count == 1
				else EventSheetL10n.translate("%d files") % count
		})
	return entries


## The outline for the real project.
static func outline(root: String = "res://", packs_dir: String = PACKS_DIR,
		coverage_by_path: Dictionary = {}) -> Dictionary:
	return outline_from(scan(root, packs_dir), coverage_by_path)


## True when an entry survives the filter box - matched on the name AND the note, so typing an
## extension finds every file of it.
static func matches_filter(entry: Dictionary, filter_text: String) -> bool:
	var needle: String = filter_text.strip_edges().to_lower()
	if needle.is_empty():
		return true
	return ("%s %s" % [str(entry.get("label", "")), str(entry.get("note", ""))]).to_lower().contains(needle)


## Where a DOUBLE-CLICK on an entry goes. The bar owns no action of its own: every route names
## something Godot or the plugin already does, and the caller dispatches it.
##   scene       -> the 2D/3D editor, with the scene-as-sheet offered beside it
##   script      -> a sheet, or Godot's script editor, per the reader's default
##   class       -> Object properties
##   base_class  -> Object properties for the base
##   behavior    -> that pack's reference page in the Manual
##   sound/folder-> Godot's FileSystem dock
static func route_for(entry: Dictionary, script_opens_as_sheet: bool = true) -> String:
	match str(entry.get("kind", "")):
		"scene":
			return "scene_editor"
		"script":
			return "sheet" if script_opens_as_sheet else "script_editor"
		"class", "base_class":
			return "object_properties"
		"behavior":
			return "pack_reference"
	return "file_system"


## What DRAGGING an entry onto the canvas means, in the sheet's own words. "" for an entry the sheet
## has no gesture for, which is how the bar refuses a drop rather than inventing one.
static func drag_intent_for(entry: Dictionary) -> String:
	match str(entry.get("kind", "")):
		"class", "base_class":
			return "start_event"
		"sound":
			return "play_sound"
		"scene":
			return "go_to_layout"
	return ""

# ── Doctor badges ─────────────────────────────────────────────────────────────────────────────
#
# The bar never RUNS the Doctor: a scan of the whole project on every rebuild is exactly the cost
# this panel promised not to have. It shows what the last run found, handed to it by whoever ran it.

static var _doctor_by_path: Dictionary = {}


## Records a Doctor run's findings for the bar to badge with. Called by whoever ran it.
static func set_doctor_findings(findings: Array) -> void:
	_doctor_by_path = badge_map(findings)


static func clear_doctor_findings() -> void:
	_doctor_by_path = {}


## path -> {"errors": int, "warnings": int} for one findings list. Pure, so a test pins the badge
## without a project behind it.
static func badge_map(findings: Array) -> Dictionary:
	var by_path: Dictionary = {}
	for entry: Variant in findings:
		var finding: Dictionary = entry
		var path: String = str(finding.get("path", ""))
		if path.is_empty():
			continue
		if not by_path.has(path):
			by_path[path] = {"errors": 0, "warnings": 0}
		var counts: Dictionary = by_path[path]
		match str(finding.get("severity", "")):
			"error":
				counts["errors"] = int(counts["errors"]) + 1
			"warning":
				counts["warnings"] = int(counts["warnings"]) + 1
		by_path[path] = counts
	return by_path


## The badge one entry wears: "●" for an error, "▲" for a warning, "" when the last Doctor run had
## nothing to say about it (or has not happened).
static func badge_for(entry: Dictionary) -> String:
	var counts: Variant = _doctor_by_path.get(str(entry.get("path", "")))
	if not (counts is Dictionary):
		return ""
	if int((counts as Dictionary).get("errors", 0)) > 0:
		return "●"
	if int((counts as Dictionary).get("warnings", 0)) > 0:
		return "▲"
	return ""
