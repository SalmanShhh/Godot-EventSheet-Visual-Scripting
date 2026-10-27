@tool
class_name EventSheetPackLibrary
extends RefCounted

# The behaviour library: every pack the plugin ships, waiting in a folder Godot cannot see.
#
# A project holds only the behaviours it asked for, as ordinary folders under eventsheet_addons/. The
# rest sit in addons/eventsheet_library/, and that folder holds a `.gdignore` file, so Godot never
# imports it: none of its classes reach Create Node, the class list, the picker, an import or an
# exported game, and the editor boots no slower for it. This file reads the library straight from
# disk, and only when something asks - the Add behaviour window, the Welcome's "What are you
# making?", the Doctor's Tidy behaviours and the picker's empty search. Nothing here runs at boot.
#
# Adding a behaviour is copying its folder in; removing one is sending its folder to the system
# trash. There is no switch and no list to keep in step: a pack in the project is a folder there.
#
# Every function takes the library and project folders as parameters with the real ones as defaults,
# so a test hands it a library and a project of its own under user:// and the rule it pins is the
# rule the editor runs.

## Where the library lives, inside the plugin so updating the plugin updates it.
const LIBRARY_ROOT := "res://addons/eventsheet_library"
## Where a project's own behaviours live. The same folder EventSheetPackCatalog lists.
const PROJECT_ROOT := "res://eventsheet_addons"
## The file that makes Godot skip a folder: no import, no class registration, no export.
const IGNORE_FILE := ".gdignore"
## Files a folder copy leaves behind: Godot writes them itself on import, for this machine only.
const GENERATED_EXTENSIONS: PackedStringArray = ["import", "translation"]
## The fewest behaviours a kit lists. A tag fewer packs share is a detail of one pack, not a kind of
## game somebody is making.
const KIT_SMALLEST := 4
## The files a project's own work is read from when the question is "who uses this behaviour".
const USAGE_EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres"]

static var _class_index_cache: Dictionary = {}
static var _search_index_cache: Dictionary = {}


## True when the plugin carries a library: the folder and its `.gdignore` are both there.
static func exists(root: String = LIBRARY_ROOT) -> bool:
	return DirAccess.dir_exists_absolute(root) and FileAccess.file_exists(root.path_join(IGNORE_FILE))


## Every pack folder in the library, sorted by name.
static func folders(root: String = LIBRARY_ROOT) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(root):
		return out
	for entry: String in DirAccess.get_directories_at(root):
		if not entry.begins_with("."):
			out.append(entry)
	out.sort()
	return out


## Every library pack, described the way the project's own packs are (EventSheetPackCatalog), plus
## "tags" (its `@ace_tags`) and "state" - "project" when the project already holds a folder of that
## name, else "library".
static func packs(root: String = LIBRARY_ROOT, project_root: String = PROJECT_ROOT) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pack_dir: String in folders(root):
		var pack: Dictionary = EventSheetPackCatalog.describe(pack_dir, root)
		if pack.is_empty():
			continue
		pack["tags"] = tags_of(str(pack.get("path", "")))
		pack["data"] = is_data_script(str(pack.get("path", "")))
		pack["state"] = "project" if in_project(pack_dir, project_root) else "library"
		out.append(pack)
	return out


## The project's packs and the library's together, as the Add behaviour window lists them: every
## project pack marked "project", then every library pack the project does not hold, marked
## "library". A pack the project holds is always its own copy, never the library's.
static func combined(project_packs: Array[Dictionary], library_packs: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var held: Dictionary = {}
	for pack: Dictionary in project_packs:
		var own: Dictionary = pack.duplicate()
		own["state"] = "project"
		held[str(own.get("dir", ""))] = true
		out.append(own)
	for pack: Dictionary in library_packs:
		if held.has(str(pack.get("dir", ""))):
			continue
		var waiting: Dictionary = pack.duplicate()
		waiting["state"] = "library"
		out.append(waiting)
	return out


## True when the project holds a folder of this name.
static func in_project(pack_dir: String, project_root: String = PROJECT_ROOT) -> bool:
	return not pack_dir.is_empty() and DirAccess.dir_exists_absolute(project_root.path_join(pack_dir))


## True for a pack whose script is data rather than a node - it extends an engine class that is not
## a Node (Resource, RefCounted). Such a pack is read by a sheet and arrives with the packs that
## need it, so it is never a kit's answer by itself.
static func is_data_script(script_path: String) -> bool:
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return false
	var found: RegExMatch = RegEx.create_from_string("(?m)^extends\\s+([A-Za-z_][A-Za-z0-9_]*)").search(
		FileAccess.get_file_as_string(script_path))
	if found == null:
		return false
	var base: String = found.get_string(1)
	return ClassDB.class_exists(base) and base != "Node" and not ClassDB.is_parent_class(base, "Node")


## A pack's `@ace_tags`, read off its class header.
static func tags_of(script_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return out
	var header: String = EventSheetPackCatalog._class_header(FileAccess.get_file_as_string(script_path))
	var found: RegExMatch = RegEx.create_from_string("(?m)^\\s*#+\\s*@ace_tags\\(([^)]*)\\)").search(header)
	if found == null:
		return out
	for tag: String in found.get_string(1).split(","):
		if not tag.strip_edges().is_empty():
			out.append(tag.strip_edges())
	return out


# --- what a pack drags along -------------------------------------------------------------------


## Every entry a pack folder's scripts name in `## @ace_requires(...)`, in file order, once each.
static func requirement_entries(folder_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var pattern: RegEx = RegEx.create_from_string("(?m)^\\s*#+\\s*@ace_requires\\(([^)]*)\\)")
	for script_path: String in _scripts_in(folder_path):
		for found: RegExMatch in pattern.search_all(FileAccess.get_file_as_string(script_path)):
			for entry: String in found.get_string(1).split(","):
				var said: String = entry.strip_edges().trim_prefix("\"").trim_suffix("\"")
				if not said.is_empty() and not out.has(said):
					out.append(said)
	return out


## class_name -> the library folder that declares it, for every script in every library folder.
## Read once per library per session: the library only changes when the plugin is updated.
static func class_index(root: String = LIBRARY_ROOT) -> Dictionary:
	if _class_index_cache.has(root):
		return _class_index_cache[root]
	var index: Dictionary = {}
	var pattern: RegEx = RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	for pack_dir: String in folders(root):
		for script_path: String in _scripts_in(root.path_join(pack_dir)):
			var found: RegExMatch = pattern.search(FileAccess.get_file_as_string(script_path))
			if found != null and not index.has(found.get_string(1)):
				index[found.get_string(1)] = pack_dir
	_class_index_cache[root] = index
	return index


## The library folders a pack needs, read from its own `@ace_requires` and theirs in turn - a class
## name is the folder declaring that class, `pack:folder` is that folder. An engine class or an
## `autoload:` entry is not a folder, so it brings nothing. The pack itself is not in the list.
static func needs(pack_dir: String, root: String = LIBRARY_ROOT) -> PackedStringArray:
	var index: Dictionary = class_index(root)
	var out: PackedStringArray = PackedStringArray()
	var queue: PackedStringArray = PackedStringArray([pack_dir])
	while not queue.is_empty():
		var current: String = queue[0]
		queue.remove_at(0)
		for entry: String in requirement_entries(root.path_join(current)):
			var folder: String = entry.trim_prefix("pack:").strip_edges() if entry.begins_with("pack:") else str(index.get(entry, ""))
			if folder.is_empty() or folder == pack_dir or out.has(folder):
				continue
			if not DirAccess.dir_exists_absolute(root.path_join(folder)):
				continue
			out.append(folder)
			queue.append(folder)
	return out


## The folders adding `pack_dir` copies in: the pack, then what it needs, leaving out every folder
## the project already holds - a folder that exists is never overwritten.
static func folders_to_add(pack_dir: String, root: String = LIBRARY_ROOT,
		project_root: String = PROJECT_ROOT) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var wanted: PackedStringArray = PackedStringArray([pack_dir])
	wanted.append_array(needs(pack_dir, root))
	for folder: String in wanted:
		if not in_project(folder, project_root) and not out.has(folder):
			out.append(folder)
	return out


# --- copying in and taking out -----------------------------------------------------------------


## Copies library folders into the project, one by one. A folder the project already holds is
## left exactly as it is and listed under "kept": the project's copy is the reader's, and an update
## of the plugin never reaches into it. Returns {"ok", "copied", "kept", "message"}.
static func copy_into_project(wanted: PackedStringArray, root: String = LIBRARY_ROOT,
		project_root: String = PROJECT_ROOT) -> Dictionary:
	var copied: PackedStringArray = PackedStringArray()
	var kept: PackedStringArray = PackedStringArray()
	for folder: String in wanted:
		var source: String = root.path_join(folder)
		if not DirAccess.dir_exists_absolute(source):
			return {"ok": false, "copied": copied, "kept": kept,
				"message": EventSheetL10n.translate("%s is not in the library.") % folder}
		if in_project(folder, project_root):
			kept.append(folder)
			continue
		var error: Error = _copy_tree(source, project_root.path_join(folder))
		if error != OK:
			return {"ok": false, "copied": copied, "kept": kept,
				"message": EventSheetL10n.translate("%s could not be copied into the project (%s).") % [folder, error_string(error)]}
		copied.append(folder)
	return {"ok": true, "copied": copied, "kept": kept, "message": ""}


## Sends one project folder to the system trash, where it can be restored from. Never deletes
## outright: when the trash refuses, the folder stays and the error says so.
static func send_to_trash(pack_dir: String, project_root: String = PROJECT_ROOT) -> Error:
	if pack_dir.is_empty() or pack_dir.contains("/") or pack_dir.contains("\\") or pack_dir.begins_with("."):
		return ERR_INVALID_PARAMETER
	var folder: String = project_root.path_join(pack_dir)
	if not DirAccess.dir_exists_absolute(folder):
		return ERR_DOES_NOT_EXIST
	return OS.move_to_trash(ProjectSettings.globalize_path(folder))


static func _copy_tree(source: String, destination: String) -> Error:
	var made: Error = DirAccess.make_dir_recursive_absolute(destination)
	if made != OK:
		return made
	for file_name: String in DirAccess.get_files_at(source):
		if GENERATED_EXTENSIONS.has(file_name.get_extension()):
			continue
		var copy_error: Error = DirAccess.copy_absolute(source.path_join(file_name), destination.path_join(file_name))
		if copy_error != OK:
			return copy_error
	for child: String in DirAccess.get_directories_at(source):
		var nested: Error = _copy_tree(source.path_join(child), destination.path_join(child))
		if nested != OK:
			return nested
	return OK


static func _scripts_in(folder_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(folder_path):
		return out
	for file_name: String in DirAccess.get_files_at(folder_path):
		if file_name.get_extension() == "gd":
			out.append(folder_path.path_join(file_name))
	for child: String in DirAccess.get_directories_at(folder_path):
		out.append_array(_scripts_in(folder_path.path_join(child)))
	out.sort()
	return out


# --- who uses a behaviour ----------------------------------------------------------------------


## The project's own files as lines, read once for every usage question asked of them: every
## `.gd`, `.tscn` and `.tres` under `scan_root`, leaving out `.godot`, the plugin's `addons/` and
## hidden folders. The project's packs ARE read, because one pack needing another is a use.
static func usage_corpus(scan_root: String = "res://") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_collect_usage(scan_root, out)
	return out


static func _collect_usage(folder: String, out: Array[Dictionary]) -> void:
	for file_name: String in DirAccess.get_files_at(folder):
		if USAGE_EXTENSIONS.has(file_name.get_extension()):
			var path: String = folder.path_join(file_name)
			out.append({"path": path, "lines": FileAccess.get_file_as_string(path).split("\n")})
	for child: String in DirAccess.get_directories_at(folder):
		if child.begins_with(".") or (folder == "res://" and child == "addons"):
			continue
		if FileAccess.file_exists(folder.path_join(child).path_join(IGNORE_FILE)):
			continue
		_collect_usage(folder.path_join(child), out)


## What a project file must say to be using a pack: the pack folder's own path, a class its scripts
## declare, or the node its rows reach (`$PlatformerMovement` - the name each row's template uses).
static func usage_pattern(pack_dir: String, project_root: String = PROJECT_ROOT) -> RegEx:
	var words: PackedStringArray = PackedStringArray()
	var class_pattern: RegEx = RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var node_pattern: RegEx = RegEx.create_from_string("@ace_codegen_template\\(\"[^\\n]*?\\$([A-Za-z_][A-Za-z0-9_]*)")
	for script_path: String in _scripts_in(project_root.path_join(pack_dir)):
		var source: String = FileAccess.get_file_as_string(script_path)
		var declared: RegExMatch = class_pattern.search(source)
		if declared != null and not words.has("\\b%s\\b" % declared.get_string(1)):
			words.append("\\b%s\\b" % declared.get_string(1))
		for reached: RegExMatch in node_pattern.search_all(source):
			var node_word: String = "[$%%]%s\\b" % reached.get_string(1)
			if not words.has(node_word):
				words.append(node_word)
	words.append(_escaped(project_root.get_file().path_join(pack_dir) + "/"))
	return RegEx.create_from_string("|".join(words))


## Every project file that uses a pack, as {"path", "rows"} - rows being the lines that mention it -
## sorted by path. The pack's own folder is not a user of itself.
static func users(pack_dir: String, corpus: Array[Dictionary], project_root: String = PROJECT_ROOT) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pattern: RegEx = usage_pattern(pack_dir, project_root)
	var own_folder: String = project_root.path_join(pack_dir) + "/"
	for entry: Dictionary in corpus:
		var path: String = str(entry.get("path", ""))
		if path.begins_with(own_folder):
			continue
		var rows: int = 0
		for line: String in entry.get("lines", PackedStringArray()):
			if pattern.search(line) != null:
				rows += 1
		if rows > 0:
			out.append({"path": path, "rows": rows})
	# An autoload is a use as well, and it lives in project.godot rather than in a file of the game.
	var autoload_folder: String = own_folder
	for property: Dictionary in ProjectSettings.get_property_list():
		var setting: String = str(property.get("name", ""))
		if setting.begins_with("autoload/") and str(ProjectSettings.get_setting(setting, "")).trim_prefix("*").begins_with(autoload_folder):
			out.append({"path": "res://project.godot", "rows": 1})
			break
	out.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return str(first["path"]) < str(second["path"]))
	return out


## The project's packs as the Tidy behaviours window lists them: {"dir", "name", "users", "in_library"}
## for each, used ones and unused alike, by folder name.
static func tidy_rows(project_packs: Array[Dictionary], corpus: Array[Dictionary],
		root: String = LIBRARY_ROOT, project_root: String = PROJECT_ROOT) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var library: PackedStringArray = folders(root)
	for pack: Dictionary in project_packs:
		var pack_dir: String = str(pack.get("dir", ""))
		out.append({"dir": pack_dir, "name": str(pack.get("name", pack_dir)),
			"users": users(pack_dir, corpus, project_root), "in_library": library.has(pack_dir)})
	# A pack used only by packs nothing uses is unused too: Abilities going takes Ability Set
	# Resource's only reader with it. Walked until nothing more drops out.
	var dropped: bool = true
	while dropped:
		dropped = false
		var unused: Dictionary = {}
		for row: Dictionary in out:
			if (row["users"] as Array).is_empty():
				unused[project_root.path_join(str(row["dir"])) + "/"] = true
		for row: Dictionary in out:
			var kept: Array[Dictionary] = []
			for entry: Dictionary in row["users"]:
				var path: String = str(entry.get("path", ""))
				var from_unused: bool = false
				for folder: String in unused:
					from_unused = from_unused or path.begins_with(folder)
				if not from_unused:
					kept.append(entry)
			if kept.size() != (row["users"] as Array).size():
				row["users"] = kept
				dropped = true
	return out


## The line under a row in Tidy behaviours: "unused", or "used by player.gd, enemy.gd".
static func used_by_text(found_users: Array) -> String:
	if found_users.is_empty():
		return EventSheetL10n.translate("unused")
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in found_users:
		names.append(str(entry.get("path", "")).get_file())
	return EventSheetL10n.translate("used by %s") % ", ".join(names)


static func _escaped(text: String) -> String:
	var out: String = ""
	for character: String in text:
		out += ("\\" + character) if "\\^$.|?*+()[]{}".contains(character) else character
	return out


# --- kits: "What are you making?" ---------------------------------------------------------------


## The Welcome's kits, derived from the packs' own `@ace_tags`: one kit per tag that at least
## KIT_SMALLEST library packs carry, named by the tag exactly as written, listing those packs. A data
## pack (`is_data_script`) is never listed: it comes along with the packs that need it. Two
## tags carrying the very same packs make one kit (the first in name order names it). Largest first,
## then by name. Each kit is {"tag", "dirs", "names"}.
static func kits(library_packs: Array[Dictionary]) -> Array[Dictionary]:
	var by_tag: Dictionary = {}
	var names: Dictionary = {}
	for pack: Dictionary in library_packs:
		names[str(pack.get("dir", ""))] = str(pack.get("name", ""))
		if bool(pack.get("data", false)):
			continue
		for tag: String in pack.get("tags", PackedStringArray()):
			# A PackedStringArray is copied on read, so the grown list is written back.
			var tagged: PackedStringArray = by_tag.get(tag, PackedStringArray())
			tagged.append(str(pack.get("dir", "")))
			by_tag[tag] = tagged
	var tags: Array = by_tag.keys()
	tags.sort()
	var seen_sets: Dictionary = {}
	var out: Array[Dictionary] = []
	for tag: String in tags:
		var dirs: PackedStringArray = by_tag[tag]
		dirs.sort()
		var key: String = ",".join(dirs)
		if dirs.size() < KIT_SMALLEST or seen_sets.has(key):
			continue
		seen_sets[key] = true
		var listed: PackedStringArray = PackedStringArray()
		for pack_dir: String in dirs:
			listed.append(str(names.get(pack_dir, pack_dir)))
		out.append({"tag": tag, "dirs": dirs, "names": listed})
	out.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_size: int = (first["dirs"] as PackedStringArray).size()
		var second_size: int = (second["dirs"] as PackedStringArray).size()
		return first_size > second_size or (first_size == second_size and str(first["tag"]) < str(second["tag"])))
	return out


## Every folder ticking these kits copies in: each kit's packs and what they need, once each, minus
## what the project already holds.
static func kit_folders(chosen: Array[Dictionary], root: String = LIBRARY_ROOT,
		project_root: String = PROJECT_ROOT) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for kit: Dictionary in chosen:
		for pack_dir: String in kit.get("dirs", PackedStringArray()):
			for folder: String in folders_to_add(pack_dir, root, project_root):
				if not out.has(folder):
					out.append(folder)
	return out


# --- the picker's empty search ------------------------------------------------------------------


## The library packs whose words match `query`, for a picker search that found nothing in the
## project: {"dir", "name", "said"} where "said" is the action, condition or expression name that
## matched (or the pack's pitch when its own name did). Packs the project holds are never offered.
## The words are the ones the picker searches: each member's `@ace_name`.
static func search(query: String, root: String = LIBRARY_ROOT, project_root: String = PROJECT_ROOT) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var needle: String = query.strip_edges().to_lower()
	if needle.is_empty() or not exists(root):
		return out
	for entry: Dictionary in _search_index(root):
		var pack_dir: String = str(entry.get("dir", ""))
		if in_project(pack_dir, project_root):
			continue
		var said: String = ""
		for verb: String in entry.get("verbs", PackedStringArray()):
			if verb.to_lower().contains(needle):
				said = verb
				break
		if said.is_empty() and str(entry.get("name", "")).to_lower().contains(needle):
			said = str(entry.get("pitch", ""))
		if not said.is_empty() or str(entry.get("name", "")).to_lower().contains(needle):
			out.append({"dir": pack_dir, "name": str(entry.get("name", "")), "said": said})
	return out


static func _search_index(root: String) -> Array:
	if _search_index_cache.has(root):
		return _search_index_cache[root]
	var index: Array = []
	var name_pattern: RegEx = RegEx.create_from_string("(?m)^\\s*##\\s*@ace_name\\(\"([^\"]+)\"\\)")
	for pack: Dictionary in packs(root, "res://"):
		var verbs: PackedStringArray = PackedStringArray()
		for script_path: String in _scripts_in(root.path_join(str(pack.get("dir", "")))):
			var source: String = FileAccess.get_file_as_string(script_path)
			var body: String = source.substr(EventSheetPackCatalog._class_header(source).length())
			for found: RegExMatch in name_pattern.search_all(body):
				if not verbs.has(found.get_string(1)):
					verbs.append(found.get_string(1))
		index.append({"dir": str(pack.get("dir", "")), "name": str(pack.get("name", "")),
			"pitch": str(pack.get("pitch", "")), "verbs": verbs})
	_search_index_cache[root] = index
	return index


## Forgets what was read, for a test that rewrites a library under the same path.
static func forget() -> void:
	_class_index_cache.clear()
	_search_index_cache.clear()
