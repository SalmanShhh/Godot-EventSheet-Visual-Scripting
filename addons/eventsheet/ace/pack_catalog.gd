@tool
class_name EventSheetPackCatalog
extends RefCounted

# One list of the packs this project has installed, with everything a reader needs to decide
# about one: what it is called, what it does in a line, which shelf it belongs on, its version,
# whether it is switched on, and whether its shape can be written straight into a script instead
# of attached as a node.
#
# Everything here is derived from the pack's own file - there is no manifest to keep in step.
# The one thing that is NOT in the file is the enabled flag, because it is a decision about this
# project rather than about the pack: it lives in ProjectSettings so it travels with the repo,
# and a disabled pack's scripts leave the scan, which is what takes its actions out of the
# picker.

const PACKS_ROOT := "res://eventsheet_addons"
const DISABLED_SETTING := "eventsheets/addons/disabled_packs"

## The annotation a pack writes when its shape can be written into an ordinary script instead of
## attached as a node. Additive - a pack that says nothing is attachable only.
const INLINE_ANNOTATION := "@ace_inline_capable"
## The annotation naming where a pack's published source lives, so "check for updates" has
## somewhere to look.
const SOURCE_ANNOTATION := "@ace_source"


## Every installed pack, sorted by folder name, each as
## {"dir", "path", "name", "pitch", "category", "version", "enabled", "inline_capable",
##  "source", "icon", "guide"}.
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
	var disabled: PackedStringArray = disabled_packs()
	for entry: String in names:
		var pack: Dictionary = describe(entry)
		if pack.is_empty():
			continue
		pack["enabled"] = not disabled.has(entry)
		out.append(pack)
	return out


## One pack, by folder name. Empty when the folder holds no pack script.
static func describe(pack_dir: String) -> Dictionary:
	var folder: String = PACKS_ROOT.path_join(pack_dir)
	var script_path: String = main_script_for(pack_dir)
	if script_path.is_empty():
		return {}
	var source: String = FileAccess.get_file_as_string(script_path)
	var guide: String = folder.path_join("guide.md")
	return {
		"dir": pack_dir,
		"path": script_path,
		"name": _display_name(source, pack_dir),
		"pitch": _pitch(source),
		"category": _annotation_argument(source, "@ace_category"),
		"version": _annotation_argument(source, "@ace_version"),
		"enabled": true,
		"inline_capable": source.contains("## %s" % INLINE_ANNOTATION),
		"source": _annotation_argument(source, SOURCE_ANNOTATION),
		"icon": _annotation_argument(source, "@ace_icon"),
		"guide": guide if FileAccess.file_exists(guide) else "",
	}


## The pack's own script: <dir>/<dir>.gd when it exists (the scaffolder's shape), else the first
## .gd in the folder that declares a class_name, else the first .gd at all.
static func main_script_for(pack_dir: String) -> String:
	var folder: String = PACKS_ROOT.path_join(pack_dir)
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


# --- enabled / disabled -----------------------------------------------------------------------


## The pack folders switched off in this project.
static func disabled_packs() -> PackedStringArray:
	return PackedStringArray(ProjectSettings.get_setting(DISABLED_SETTING, PackedStringArray()))


static func is_enabled(pack_dir: String) -> bool:
	return not disabled_packs().has(pack_dir)


## Switches one pack on or off. A disabled pack's scripts leave the scan, so its actions leave
## the picker; sheets already using them still open, and the Doctor says so.
static func set_enabled(pack_dir: String, enabled: bool) -> void:
	var disabled: PackedStringArray = disabled_packs()
	var index: int = disabled.find(pack_dir)
	if enabled and index >= 0:
		disabled.remove_at(index)
	elif not enabled and index < 0:
		disabled.append(pack_dir)
	else:
		return
	disabled.sort()
	ProjectSettings.set_setting(DISABLED_SETTING, disabled if not disabled.is_empty() else null)
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		ProjectSettings.save()


## True when this script belongs to a pack that is switched off - the one question the scanner
## asks about every path it finds.
static func is_disabled_path(script_path: String) -> bool:
	var prefix: String = "%s/" % PACKS_ROOT
	if not script_path.begins_with(prefix):
		return false
	var rest: String = script_path.substr(prefix.length())
	var slash: int = rest.find("/")
	var pack_dir: String = rest if slash < 0 else rest.substr(0, slash)
	return disabled_packs().has(pack_dir)


# --- reading the pack's own words --------------------------------------------------------------


static func _display_name(source: String, pack_dir: String) -> String:
	var annotated: String = _annotation_argument(source, "@ace_name")
	if not annotated.is_empty():
		return annotated
	var class_line: RegEx = RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var found: RegExMatch = class_line.search(source)
	if found != null:
		return _humanize(found.get_string(1))
	return _humanize(pack_dir)


## The one-line pitch: the pack's own @ace_description when it has one, else the first sentence
## of its top doc comment. Never the whole comment - a card has one line.
static func _pitch(source: String) -> String:
	var described: String = _annotation_argument(source, "@ace_description")
	if not described.is_empty():
		return described
	for line: String in source.split("\n"):
		var text: String = line.strip_edges()
		if text.begins_with("## @") or text.begins_with("# @"):
			continue
		if text.begins_with("##"):
			var body: String = text.substr(2).strip_edges()
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
