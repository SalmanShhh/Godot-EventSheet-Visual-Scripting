# Godot EventSheets - the Doctor's Class Name Clashes section.
#
# Godot keeps ONE list of class names for a whole project. When two scripts declare the same
# `class_name`, the one Godot reads first owns the name and the other stops parsing ("hides a global
# script class"). This plugin declares several hundred names and its shipped behaviours a hundred and
# seventy more, so a game's own `NavAgent3D` or `EventRow` can land on one by accident. This section
# says so, naming both files, before the editor does it in a way that is hard to trace:
#
#   a name the plugin's own code declares   an error - the plugin cannot compile while it stands
#   a name a behaviour already in the       an error - one of the two scripts is dead
#   project declares
#   a name only the plugin's library holds  a warning - nothing is broken yet, but Add to project
#                                           will refuse that behaviour until the class is renamed
#
# Names are frozen, so the cure is always the reader's own class: rename it. Nothing is written.
#
# It has no class_name of its own (that would be one more name to clash) and registers by path,
# through the same seam a pack's check uses.
@tool
extends "res://addons/eventforge/doctor_section.gd"

## The id the section is registered under and the id each finding is filed as.
const CHECK_ID := "class-name-clash"
const THIS_SCRIPT := "res://addons/eventforge/class_name_clash_doctor.gd"
## Where the plugin's own scripts live: a class declared under either folder is the plugin's.
const PLUGIN_FOLDERS: Array[String] = ["res://addons/eventforge/", "res://addons/eventsheet/"]
const _DECLARATION := "(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)"

## How much of each plugin file is read to find its class_name.
const HEAD_BYTES := 8192

## The plugin's class names, read the first time they are asked for.
static var _plugin_names: Dictionary = {}


## Registers the section, replacing any earlier registration.
static func ensure_registered() -> void:
	EventSheetProjectDoctor.register_check(CHECK_ID, Callable(load(THIS_SCRIPT), "check"))


## The section, with the contract every registered check has: append findings, never write inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var pattern: RegEx = RegEx.create_from_string(_DECLARATION)
	var user_classes: Dictionary = {}
	for script_path: String in EventSheetProjectDoctor._project_scripts():
		if _is_shipped(script_path):
			continue
		var source: String = EventSheetProjectDoctor.source_of(script_path)
		if not source.contains("class_name"):
			continue
		var found: RegExMatch = pattern.search(source)
		if found != null:
			user_classes[script_path] = found.get_string(1)
	# A project with no class_name of its own has nothing to compare: the plugin's names are only read
	# when there is something to compare them with.
	if user_classes.is_empty():
		return
	var library_names: Dictionary = {}
	var held_packs: Dictionary = {}
	if EventSheetPackLibrary.exists():
		var index: Dictionary = EventSheetPackLibrary.class_index()
		for declared: String in index:
			var folder: String = str(index[declared])
			library_names[declared] = folder
			if EventSheetPackLibrary.in_project(folder):
				held_packs[declared] = PACK_DIRECTORY.path_join(folder)
	var helpers: Dictionary = load("res://addons/eventforge/runtime_helpers.gd").class_files()
	for declared: String in helpers:
		library_names[declared] = str(helpers[declared])
		if FileAccess.file_exists(PACK_DIRECTORY.path_join(str(helpers[declared]))):
			held_packs[declared] = PACK_DIRECTORY.path_join(str(helpers[declared]))
	findings.append_array(report(user_classes, plugin_names(), held_packs, library_names))


## class_name -> file for every script of the plugin itself, read straight off disk (the global class
## list is no use here: it holds only the file that owns a name, and in a clash that may be the
## reader's). Read once per session - the plugin's files only change when it is updated.
static func plugin_names() -> Dictionary:
	if not _plugin_names.is_empty():
		return _plugin_names
	var pattern: RegEx = RegEx.create_from_string(_DECLARATION)
	for folder: String in PLUGIN_FOLDERS:
		_read_names(folder.trim_suffix("/"), pattern, _plugin_names)
	return _plugin_names


static func _read_names(folder: String, pattern: RegEx, out: Dictionary) -> void:
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.get_extension() != "gd":
			continue
		# Only the top of the file is read: a class_name comes before any code, after the header
		# comment, and the whole of the plugin is some seventeen megabytes.
		var file: FileAccess = FileAccess.open(folder.path_join(file_name), FileAccess.READ)
		if file == null:
			continue
		var found: RegExMatch = pattern.search(file.get_buffer(HEAD_BYTES).get_string_from_utf8())
		if found != null:
			out[found.get_string(1)] = folder.path_join(file_name)
	for child: String in DirAccess.get_directories_at(folder):
		_read_names(folder.path_join(child), pattern, out)


## The findings, pure over what was read: `user_classes` is the reader's script -> its class name,
## `plugin_names` and `held_packs` are class name -> the file declaring it (the plugin's own, and the
## shipped behaviours already in the project), `library_names` is class name -> the library folder or
## helper file that carries it. A test hands each its own table.
static func report(user_classes: Dictionary, plugin_names: Dictionary, held_packs: Dictionary,
		library_names: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var paths: Array = user_classes.keys()
	paths.sort()
	for path: String in paths:
		var declared: String = str(user_classes[path])
		if plugin_names.has(declared) and str(plugin_names[declared]) != path:
			findings.append(_finding("error", CHECK_ID, path, EventSheetL10n.translate(
				"%s declares the class %s, and so does the plugin's own %s. Godot keeps one class per name, so the plugin cannot load while both exist. Rename your class.") % [
				path.get_file(), declared, str(plugin_names[declared])], declared))
		elif held_packs.has(declared) and str(held_packs[declared]) != path:
			findings.append(_finding("error", CHECK_ID, path, EventSheetL10n.translate(
				"%s declares the class %s, and so does %s, a behaviour in this project. Godot keeps one class per name, so one of the two scripts does not load. Rename your class, or remove the behaviour.") % [
				path.get_file(), declared, str(held_packs[declared])], declared))
		elif library_names.has(declared):
			findings.append(_finding("warning", CHECK_ID, path, EventSheetL10n.translate(
				"%s declares the class %s, a name the plugin's behaviour %s also uses. Nothing is broken yet, but Add to project will refuse that behaviour while your class has the name.") % [
				path.get_file(), declared, str(library_names[declared])], declared))
	return findings
