# Godot EventSheets - Import tool seam
#
# THE SEAM behind the On File Imported trigger. When Godot finishes (re)importing assets, this hook
# finds the project's Editor Tool scripts that declared the trigger and calls their handler with the
# paths that just landed - so a sheet can rename what a designer dropped in, check an atlas for the
# wrong filter, or write a manifest of everything under res://art.
#
# It is deliberately the SAME shape as the project-export bake step, because the two answer the same
# question in the same way and a reader who has learned one has learned both: the trigger compiles to
# a plain, named function - `func _on_files_imported(paths: PackedStringArray)` - and this hook calls
# that by name. Both sides stay plain GDScript, so the generated script has zero plugin dependency and
# with the plugin uninstalled the function simply sits there unused. Crucially, a plain function also
# READS BACK: an opened tool lifts its handler straight to an On File Imported event, where a signal
# connection spelled through EditorInterface would have stranded the whole handler as a code block.
#
# Discovery reads the COMPILED SCRIPTS, not the sheet resources, for the reason the export hook does:
# `.gd` is the default sheet format, so an index built from `.tres` files would silently skip most
# real projects. The emitted script either declares the handler or it does not.
#
# The safety rules are the export hook's rules, for the same reasons: reflect before constructing (a
# text match reaches files that only mention the name in a comment), never instantiate a Node-hosted
# script (an orphan node would leak into the editor with nothing to free it), run in sorted path order
# so two tools that touch the same file behave the same on every machine, and print every run.
#
# Unlike an export, an import is NOT a moment the editor holds open for us, so a handler that awaits
# is merely late rather than truncated - it is still reported, because a tool that pauses has stopped
# being a reaction to the import that triggered it.
@tool
extends RefCounted

## The function name On File Imported compiles to. Part of the public seam: rename it and every
## already-generated tool script goes quiet, so it is frozen like an ace_id.
const HOOK_FUNCTION: String = "_on_files_imported"

## Folders that never hold a user's editor tools - the import cache and plugin code (this plugin
## included), so the scan stays proportional to the game's own files.
const SKIPPED_ROOTS: Array[String] = ["res://.godot", "res://addons"]

var _filesystem: EditorFileSystem = null


## Connects to the editor's reimport signal. Safe to call twice - the second call is a no-op.
func attach(filesystem: EditorFileSystem) -> void:
	if filesystem == null or _filesystem != null:
		return
	_filesystem = filesystem
	if not _filesystem.resources_reimported.is_connected(_on_resources_reimported):
		_filesystem.resources_reimported.connect(_on_resources_reimported)


func detach() -> void:
	if _filesystem == null:
		return
	if _filesystem.resources_reimported.is_connected(_on_resources_reimported):
		_filesystem.resources_reimported.disconnect(_on_resources_reimported)
	_filesystem = null


func _on_resources_reimported(resources: PackedStringArray) -> void:
	var report: Dictionary = run_import_tools(resources)
	# Silence when nothing opted in: an import happens constantly, and a line per import from a
	# project with no import tools would be noise nobody asked for.
	if int(report.get("ran", 0)) == 0 and int(report.get("skipped", 0)) == 0:
		return
	print("[Godot EventSheets] import hook: %d editor tool(s) ran, %d skipped." % [
		int(report.get("ran", 0)), int(report.get("skipped", 0))])


## Runs every Editor Tool script that declared the On File Imported trigger, handing each the paths
## that were just imported. Returns {ran, skipped, unfinished, scripts} - `scripts` lists what
## actually ran, in the order it ran. Static + headless-safe so tests exercise the exact pass the
## editor takes.
static func run_import_tools(paths: PackedStringArray, root: String = "res://") -> Dictionary:
	var report: Dictionary = {"ran": 0, "skipped": 0, "unfinished": 0, "scripts": PackedStringArray()}
	# Built as a local and stored back at the end: a PackedStringArray is a VALUE, so appending to one
	# fetched out of a Dictionary appends to a copy and the report would come back empty.
	var ran_paths: PackedStringArray = PackedStringArray()
	for script_path: String in find_import_tools(root):
		var script: Script = load(script_path) as Script
		if script == null or not script.can_instantiate():
			report["skipped"] = int(report["skipped"]) + 1
			push_warning("[Godot EventSheets] import hook: %s could not be instantiated - skipped." % script_path)
			continue
		if not _declares_hook(script):
			report["skipped"] = int(report["skipped"]) + 1
			push_warning("[Godot EventSheets] import hook: %s mentions %s but declares no such function, so it was skipped." % [script_path, HOOK_FUNCTION])
			continue
		var base_type: String = script.get_instance_base_type()
		if ClassDB.class_exists(base_type) and ClassDB.is_parent_class(base_type, "Node"):
			report["skipped"] = int(report["skipped"]) + 1
			push_warning("[Godot EventSheets] import hook: %s is a %s script, so it was skipped - On File Imported belongs on an Import Tool sheet (Sheet Type > Import tool)." % [script_path, base_type])
			continue
		var instance: Object = script.new() as Object
		if instance == null:
			report["skipped"] = int(report["skipped"]) + 1
			push_warning("[Godot EventSheets] import hook: %s produced no instance - skipped. (An EditorScript can only be built while an editor is running.)" % script_path)
			continue
		print("[Godot EventSheets] import hook: running %s" % script_path)
		var outcome: Variant = instance.call(HOOK_FUNCTION, paths)
		report["ran"] = int(report["ran"]) + 1
		ran_paths.append(script_path)
		if outcome is Object and (outcome as Object).get_class() == "GDScriptFunctionState":
			report["unfinished"] = int(report["unfinished"]) + 1
			push_warning("[Godot EventSheets] import hook: %s paused on an await, so the rest of it runs after the editor has moved on from this import. Keep an import reaction synchronous." % script_path)
	report["scripts"] = ran_paths
	return report


## True when the script really has the handler, asked of the SCRIPT rather than an instance -
## `Script.has_method` answers for the Script OBJECT (reload, get_source_code...), so the method list
## is what carries the scripted functions.
static func _declares_hook(script: Script) -> bool:
	for method: Dictionary in script.get_script_method_list():
		if str(method.get("name", "")) == HOOK_FUNCTION:
			return true
	return false


## Every `.gd` under `root` whose text declares the import handler, sorted so the run order is the
## same everywhere. Declaring the handler IS the opt-in, so the text test is exactly that one line.
static func find_import_tools(root: String = "res://") -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var directories: Array[String] = [root]
	while not directories.is_empty():
		var current: String = directories.pop_back()
		var skip: bool = false
		for skipped_root: String in SKIPPED_ROOTS:
			if current.begins_with(skipped_root):
				skip = true
				break
		if skip:
			continue
		var dir: DirAccess = DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while not entry.is_empty():
			var entry_path: String = current.path_join(entry)
			if dir.current_is_dir():
				if not entry.begins_with("."):
					directories.append(entry_path)
			elif entry.get_extension() == "gd":
				if FileAccess.get_file_as_string(entry_path).contains("func %s(" % HOOK_FUNCTION):
					found.append(entry_path)
			entry = dir.get_next()
		dir.list_dir_end()
	found.sort()
	return found
