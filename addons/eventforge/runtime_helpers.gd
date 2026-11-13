@tool
extends RefCounted

# The single runtime scripts a few built-in rows call by class name - `EventForgeFreeSpot` for a spawn
# at a free spot, `EventForgePooledNodes` for a retire, the bus, world look, haptics and sequencer
# scripts - which live as loose files at the top of eventsheet_addons/, not inside any pack folder.
#
# A project that took the plugin from addons/ has no such files, so a row calling one would emit a
# call to a class that does not exist. The plugin carries them in addons/eventsheet_library/_runtime/
# (a folder Godot never imports) and this file copies the ones a piece of code names into the
# project's eventsheet_addons/ the moment a row needing them is applied, the way a pack's
# `@ace_requires` brings its helpers. Nothing here runs at boot; it is loaded by path when asked.
#
# Every function takes the library and project folders as parameters with the real ones as defaults,
# so a test hands it folders of its own under user:// and the rule it pins is the rule the editor runs.

## Where the plugin carries the helpers, inside the library so updating the plugin updates them.
const LIBRARY_DIR := "res://addons/eventsheet_library/_runtime"
## Where a project keeps them: the folder packs live in, at its top level.
const PROJECT_DIR := "res://eventsheet_addons"
## The matching pattern for a global class declaration.
const _DECLARATION := "(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)"


## class_name -> file name for every helper script in `library_dir`.
static func class_files(library_dir: String = LIBRARY_DIR) -> Dictionary:
	var out: Dictionary = {}
	var pattern: RegEx = RegEx.create_from_string(_DECLARATION)
	for file_name: String in DirAccess.get_files_at(library_dir):
		if file_name.get_extension() != "gd":
			continue
		var found: RegExMatch = pattern.search(FileAccess.get_file_as_string(library_dir.path_join(file_name)))
		if found != null:
			out[found.get_string(1)] = file_name
	return out


## The helper files `text` names (a codegen template, emitted code, a row's parameter), each once and
## sorted, with the helpers those helpers name in turn. Whole-word match, so `EventForgeFreeSpotX`
## is not `EventForgeFreeSpot`.
static func files_named_in(text: String, library_dir: String = LIBRARY_DIR) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if text.is_empty():
		return out
	var index: Dictionary = class_files(library_dir)
	var queue: PackedStringArray = PackedStringArray([text])
	while not queue.is_empty():
		var current: String = queue[0]
		queue.remove_at(0)
		for helper_class: String in index.keys():
			var file_name: String = str(index[helper_class])
			if out.has(file_name) or not _names_class(current, helper_class):
				continue
			out.append(file_name)
			queue.append(FileAccess.get_file_as_string(library_dir.path_join(file_name)))
	out.sort()
	return out


## The subset of `files` the project does not hold yet.
static func missing_in_project(files: PackedStringArray, project_dir: String = PROJECT_DIR) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for file_name: String in files:
		if not FileAccess.file_exists(project_dir.path_join(file_name)):
			out.append(file_name)
	return out


## Copies `files` from the library into the project (the `.uid` sidecar beside each, so the id a
## scene names it by is kept). A file the project already has is left exactly as it is. Returns the
## file names it copied.
static func copy_into_project(files: PackedStringArray, library_dir: String = LIBRARY_DIR,
		project_dir: String = PROJECT_DIR) -> PackedStringArray:
	var copied: PackedStringArray = PackedStringArray()
	for file_name: String in missing_in_project(files, project_dir):
		DirAccess.make_dir_recursive_absolute(project_dir)
		if DirAccess.copy_absolute(library_dir.path_join(file_name), project_dir.path_join(file_name)) != OK:
			continue
		var sidecar: String = file_name + ".uid"
		if FileAccess.file_exists(library_dir.path_join(sidecar)):
			DirAccess.copy_absolute(library_dir.path_join(sidecar), project_dir.path_join(sidecar))
		copied.append(file_name)
	return copied


## `files_named_in` then `copy_into_project`: the one call a row's apply makes. Returns what it copied.
static func ensure_for_text(text: String, library_dir: String = LIBRARY_DIR,
		project_dir: String = PROJECT_DIR) -> PackedStringArray:
	var wanted: PackedStringArray = files_named_in(text, library_dir)
	if wanted.is_empty():
		return wanted
	return copy_into_project(wanted, library_dir, project_dir)


## The helper files a script's source calls that the project does not hold. The Doctor
## asks this of each sheet's code.
static func lacking_for_text(text: String, library_dir: String = LIBRARY_DIR,
		project_dir: String = PROJECT_DIR) -> PackedStringArray:
	return missing_in_project(files_named_in(text, library_dir), project_dir)


static func _names_class(text: String, class_name_text: String) -> bool:
	var at: int = text.find(class_name_text)
	while at >= 0:
		var before_ok: bool = at == 0 or not _is_word_char(text.unicode_at(at - 1))
		var end: int = at + class_name_text.length()
		var after_ok: bool = end >= text.length() or not _is_word_char(text.unicode_at(end))
		if before_ok and after_ok:
			return true
		at = text.find(class_name_text, at + 1)
	return false


static func _is_word_char(code: int) -> bool:
	return code == 95 or (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
