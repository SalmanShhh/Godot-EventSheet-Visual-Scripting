@tool
class_name EventSheetPackCatalog
extends RefCounted

# One list of the packs this project has installed, with everything a reader needs to decide
# about one: what it is called, what it does in a line, which shelf it belongs on, its version,
# and whether its shape can be written straight into a script instead of attached as a node.
#
# Everything here is derived from the pack's own file - there is no manifest to keep in step. A
# pack is a folder of ordinary scripts under eventsheet_addons/: it is installed by being there
# and removed by deleting the folder, so every pack on disk is in the list and in the picker.

const PACKS_ROOT := "res://eventsheet_addons"
## The project setting older versions wrote to switch a pack off. Nothing reads it to decide what
## is scanned any more; the Doctor notes a project that still carries it, so it can be deleted.
const DISABLED_SETTING := "eventsheets/addons/disabled_packs"

## The annotation a pack writes when its shape can be written into an ordinary script instead of
## attached as a node. Additive - a pack that says nothing is attachable only.
const INLINE_ANNOTATION := "@ace_inline_capable"
## The annotation naming where a pack's published source lives, so a reader knows where to look
## for a newer version.
const SOURCE_ANNOTATION := "@ace_source"


## Every installed pack, sorted by folder name, each as
## {"dir", "path", "name", "pitch", "category", "version", "enabled", "inline_capable",
##  "source", "icon", "guide"}. "enabled" is always true and stays only so a caller that reads it
## keeps working: a pack on disk is a pack in use.
static func packs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(PACKS_ROOT):
		return out
	var directories: PackedStringArray = DirAccess.get_directories_at(PACKS_ROOT)
	var names: Array[String] = []
	for entry: String in directories:
		if not entry.begins_with("."):
			names.append(entry)
	names.sort()
	for entry: String in names:
		var pack: Dictionary = describe(entry)
		if pack.is_empty():
			continue
		out.append(pack)
	return out


## One pack, by folder name. Empty when the folder holds no pack script.
static func describe(pack_dir: String) -> Dictionary:
	var folder: String = PACKS_ROOT.path_join(pack_dir)
	var script_path: String = main_script_for(pack_dir)
	if script_path.is_empty():
		return {}
	var source: String = FileAccess.get_file_as_string(script_path)
	# Only the CLASS-LEVEL annotations describe the pack. A member's own `## @ace_name(...)` a
	# hundred lines down describes one action, and reading the first match in the whole file made
	# every pack introduce itself as whichever action happened to be declared first.
	var header: String = _class_header(source)
	var guide: String = folder.path_join("guide.md")
	return {
		"dir": pack_dir,
		"path": script_path,
		"name": _display_name(header, pack_dir),
		"pitch": _pitch(source),
		"category": _annotation_argument(header, "@ace_category"),
		"version": version_of(script_path),
		"enabled": true,
		"inline_capable": header.contains(INLINE_ANNOTATION),
		"source": _annotation_argument(header, SOURCE_ANNOTATION),
		"icon": _annotation_argument(header, "@ace_icon"),
		"guide": guide if FileAccess.file_exists(guide) else "",
	}


## What version ONE pack script says it is, read off its class header, or "" when it does not say.
##
## By SCRIPT PATH rather than by folder name, so a caller holding a pack somewhere other than the
## packs folder - a version being compared before it is taken, a fixture in a test, a folder an
## update has just written - asks the same rule rather than writing a second one that agrees with
## this until the day it does not.
static func version_of(script_path: String) -> String:
	if script_path.strip_edges().is_empty() or not FileAccess.file_exists(script_path):
		return ""
	return _annotation_argument(_class_header(FileAccess.get_file_as_string(script_path)),
		"@ace_version")


## Everything above (and including) the `extends` line - the region where an annotation is about
## the pack rather than about one of its members.
static func _class_header(source: String) -> String:
	var lines: PackedStringArray = source.split("\n")
	var kept: PackedStringArray = PackedStringArray()
	for line: String in lines:
		kept.append(line)
		if line.strip_edges().begins_with("extends "):
			break
	return "\n".join(kept)


## The pack's own script: <dir>/<dir>.gd when it exists (the scaffolder's shape), else the first
## .gd in the folder that declares a class_name, else the first .gd at all.
##
## `root` is where the pack folder sits, and is the packs folder for every real question. It is a
## parameter only so a caller holding a pack somewhere else - a version being compared before it is
## taken, a fixture in a test - asks the SAME rule rather than writing a second one that agrees
## with this until the day it does not.
static func main_script_for(pack_dir: String, root: String = PACKS_ROOT) -> String:
	var folder: String = root.path_join(pack_dir)
	var preferred: String = folder.path_join("%s.gd" % pack_dir)
	if FileAccess.file_exists(preferred):
		return preferred
	var candidates: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.get_extension() == "gd":
			candidates.append(folder.path_join(file_name))
	candidates.sort()
	for candidate: String in candidates:
		if FileAccess.get_file_as_string(candidate).contains("class_name "):
			return candidate
	return candidates[0] if not candidates.is_empty() else ""


## The shelves the Add behavior dialog groups by: every category any installed pack declares,
## sorted, with the packs that declare none under "Other".
static func categories(pack_list: Array[Dictionary]) -> PackedStringArray:
	var seen: Dictionary = {}
	for pack: Dictionary in pack_list:
		var category: String = str(pack.get("category", "")).strip_edges()
		seen[category if not category.is_empty() else "Other"] = true
	var out: PackedStringArray = PackedStringArray(seen.keys())
	out.sort()
	return out


## The packs matching a category and a search string. An empty category means every shelf; the
## search reads the name, the pitch and the folder, so "jump" finds Platformer.
static func filtered(pack_list: Array[Dictionary], category: String, query: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var wanted: String = category.strip_edges()
	var needle: String = query.strip_edges().to_lower()
	for pack: Dictionary in pack_list:
		var shelf: String = str(pack.get("category", "")).strip_edges()
		if shelf.is_empty():
			shelf = "Other"
		if not wanted.is_empty() and shelf != wanted:
			continue
		if not needle.is_empty():
			var haystack: String = "%s %s %s" % [pack.get("name", ""), pack.get("pitch", ""), pack.get("dir", "")]
			if not haystack.to_lower().contains(needle):
				continue
		out.append(pack)
	return out


# --- the retired on/off switch ----------------------------------------------------------------
# These four kept their shapes so a caller written against them still resolves, and each now
# answers what is true: there is no switch, every pack on disk is scanned.


## Deprecated: always empty. Every pack on disk is in use; the old setting's own value is
## `legacy_disabled_setting()`, read only by the Doctor's note about it.
static func disabled_packs() -> PackedStringArray:
	return PackedStringArray()


## Deprecated: always true. Delete a pack's folder to stop using it.
static func is_enabled(_pack_dir: String) -> bool:
	return true


## Deprecated: does nothing. Delete a pack's folder to stop using it; version control undoes it.
static func set_enabled(_pack_dir: String, _enabled: bool) -> void:
	pass


## Deprecated: always false, because no pack is switched off.
static func is_disabled_path(_script_path: String) -> bool:
	return false


## What an older project's switched-off setting still lists, or empty when it carries none. Only
## the Doctor asks, to say the setting is ignored now and may be deleted.
static func legacy_disabled_setting() -> PackedStringArray:
	return PackedStringArray(ProjectSettings.get_setting(DISABLED_SETTING, PackedStringArray()))


# --- reading the pack's own words --------------------------------------------------------------


## The pack's name: its own class-level @ace_name when it declares one, else its folder read as
## words. The folder rather than the class_name, because a folder is what the reader named and a
## class_name carries the plumbing ("SimpleHealthBehavior" for a pack called Health).
static func _display_name(header: String, pack_dir: String) -> String:
	var annotated: String = _annotation_argument(header, "@ace_name")
	if not annotated.is_empty():
		return annotated
	return _humanize(pack_dir)


## The one-line pitch: the first sentence of the pack's own class doc comment - the `##` block
## that sits directly under `extends`. Never the whole comment: a card has one line.
static func _pitch(source: String) -> String:
	var lines: PackedStringArray = source.split("\n")
	var reached_class: bool = false
	for line: String in lines:
		var text: String = line.strip_edges()
		if text.begins_with("extends "):
			reached_class = true
			continue
		if not reached_class:
			continue
		if text.is_empty() or text.begins_with("@"):
			continue
		if not text.begins_with("##"):
			break
		var body: String = text.substr(2).strip_edges()
		if body.begins_with("@"):
			continue
		if not body.is_empty():
			var stop: int = body.find(". ")
			return body if stop < 0 else body.substr(0, stop)
	return ""


## The quoted (or bare) argument of a `## @ace_x(...)` line, or "" when the pack writes none.
static func _annotation_argument(source: String, annotation: String) -> String:
	var pattern: RegEx = RegEx.create_from_string("(?m)^\\s*#+\\s*%s\\(\\s*\"?([^\")]*)\"?\\s*\\)" % annotation.replace("@", "@"))
	var found: RegExMatch = pattern.search(source)
	if found == null:
		return ""
	return found.get_string(1).strip_edges()


static func _humanize(identifier: String) -> String:
	var words: PackedStringArray = identifier.replace("_", " ").strip_edges().split(" ", false)
	var out: PackedStringArray = PackedStringArray()
	for word: String in words:
		out.append(word.substr(0, 1).to_upper() + word.substr(1))
	return " ".join(out)
