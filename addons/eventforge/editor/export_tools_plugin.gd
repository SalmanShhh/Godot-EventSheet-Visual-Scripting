# Godot EventSheets - Project-export bake step
#
# THE SEAM behind the On Project Export trigger. When an export starts, this hook finds the project's
# Editor Tool scripts that declared the trigger and calls their handler, so a sheet can stamp a build
# number, bake a data file, or strip debug content at exactly the moment the export begins.
#
# Why it calls a FUNCTION rather than running the whole tool: On Editor Run compiles to `_run()`, the
# entry point File > Run invokes, and a tool usually wants a different (or smaller) job at export
# time than the one a human presses Run for. On Project Export therefore compiles to its own plain
# handler - `func _on_project_export(is_debug: bool, features: PackedStringArray)` - and this hook
# calls that by name. Both sides stay plain GDScript: the generated script has zero plugin
# dependency, and with the plugin uninstalled the function simply sits there unused.
#
# Why discovery reads the COMPILED SCRIPTS and not the sheet resources: `.gd` is the default sheet
# format, so a sheet index built from `.tres` files would silently skip most real projects. The
# emitted script is where the truth is - it either declares the handler or it does not.
#
# Safety rules this hook holds to, because it runs user code during an export:
#   - nothing is CONSTRUCTED until reflection says the script really declares the handler. Discovery
#     is a text match, so a file that only mentions the name in a comment or a string gets this far;
#     building it to ask would run its _init for nothing and leak it when its host is a plain Object.
#     Every skip is a warning naming the file, so nobody is left wondering why their tool stayed quiet;
#   - a NODE-hosted script is never instantiated. `new()` on a Node script would leak an orphan node
#     into the editor with nothing to free it, and a bake step belongs on an Editor Tool sheet
#     anyway. The test is the script's real instance base type, not a text match;
#   - a handler that AWAITS cannot be waited for. The engine hands back a GDScriptFunctionState the
#     moment it suspends and the exporter carries on packaging, so anything after the await may miss
#     the build entirely. That is reported as a warning plus an `unfinished` count rather than
#     counted as a clean run - a bake step should stay synchronous;
#   - tools run in sorted path order, so two tools that touch the same file behave the same way on
#     every machine and in CI;
#   - every run is printed. An error inside a tool is a normal GDScript error: it aborts that one
#     call and the export continues, which is what you want when the bake step is optional polish.
#
# Ordering: the plugin registers the export-integrity hook first and this one second, and Godot calls
# export plugins in registration order - so every sheet has been recompiled to a fresh script by the
# time a bake step runs. A tool therefore never executes a stale version of itself.
#
# One engine constraint worth knowing: `EditorScript` can only be instantiated while an editor is
# running. That is always true during an export (an export IS an editor session, including the
# headless `--export-release` one CI uses), but it means a plain `--script` run cannot exercise this
# path - a null instance is reported as a skip rather than pretending to have run.
@tool
extends EditorExportPlugin

## The function name On Project Export compiles to. Part of the public seam: rename it and every
## already-generated tool script goes quiet, so it is frozen like an ace_id.
const HOOK_FUNCTION: String = "_on_project_export"

## Folders that never hold a user's editor tools. `.godot` is the import cache, `addons` is plugin
## code (this plugin included), and skipping both keeps the scan proportional to the game's own files.
const SKIPPED_ROOTS: Array[String] = ["res://.godot", "res://addons"]


func _get_name() -> String:
	return "GodotEventSheetsExportTools"


func _export_begin(features: PackedStringArray, is_debug: bool, _path: String, _flags: int) -> void:
	var report: Dictionary = run_export_tools(features, is_debug)
	print("[Godot EventSheets] export bake step: %d editor tool(s) ran, %d skipped." % [
		int(report.get("ran", 0)), int(report.get("skipped", 0))])
	if int(report.get("unfinished", 0)) > 0:
		print("[Godot EventSheets] export bake step: %d tool(s) paused on an await and did not finish before the export continued." % int(report.get("unfinished", 0)))


## Runs every Editor Tool script that declared the On Project Export trigger.
## Returns {ran: int, skipped: int, unfinished: int, scripts: PackedStringArray} - `scripts` lists
## what actually ran, in the order it ran, and `unfinished` counts the handlers that paused on an
## `await` (see the coroutine note below). Static + headless-safe so tests (and a CI export)
## exercise the exact pass the editor takes.
static func run_export_tools(features: PackedStringArray, is_debug: bool, root: String = "res://") -> Dictionary:
	var report: Dictionary = {"ran": 0, "skipped": 0, "unfinished": 0, "scripts": PackedStringArray()}
	# Built as a local and stored back at the end: a PackedStringArray is a VALUE, so appending to one
	# fetched out of a Dictionary appends to a copy and the report would come back empty.
	var ran_paths: PackedStringArray = PackedStringArray()
	for script_path: String in find_export_tools(root):
		var script: Script = load(script_path) as Script
		if script == null or not script.can_instantiate():
			report["skipped"] = int(report["skipped"]) + 1
			push_warning("[Godot EventSheets] export bake step: %s could not be instantiated - skipped." % script_path)
			continue
		# Reflection BEFORE construction. Discovery is a text match, so a file that merely mentions the
		# handler name in a comment or a string reaches this loop; instantiating it to ask would run its
		# _init for nothing (and leak it, when its host is a plain Object with no reference counting).
		if not _declares_hook(script):
			report["skipped"] = int(report["skipped"]) + 1
			push_warning("[Godot EventSheets] export bake step: %s mentions %s but declares no such function, so it was skipped." % [script_path, HOOK_FUNCTION])
			continue
		var base_type: String = script.get_instance_base_type()
		if ClassDB.class_exists(base_type) and ClassDB.is_parent_class(base_type, "Node"):
			report["skipped"] = int(report["skipped"]) + 1
			push_warning("[Godot EventSheets] export bake step: %s is a %s script, so it was skipped - On Project Export belongs on an Editor Tool sheet (Sheet Type > Editor Tool)." % [script_path, base_type])
			continue
		var instance: Object = script.new() as Object
		if instance == null:
			report["skipped"] = int(report["skipped"]) + 1
			push_warning("[Godot EventSheets] export bake step: %s produced no instance - skipped. (An EditorScript can only be built while an editor is running.)" % script_path)
			continue
		print("[Godot EventSheets] export bake step: running %s" % script_path)
		var outcome: Variant = instance.call(HOOK_FUNCTION, is_debug, features)
		report["ran"] = int(report["ran"]) + 1
		ran_paths.append(script_path)
		# A handler that awaits (Render Scene To Image waits for a drawn frame, for instance) hands back
		# a GDScriptFunctionState the moment it suspends, and the exporter does not wait: it packages the
		# files while the rest of that handler is still pending. Nothing here can hold the export open, so
		# say so plainly rather than reporting a tool as "ran" when half of it has not.
		if outcome is Object and (outcome as Object).get_class() == "GDScriptFunctionState":
			report["unfinished"] = int(report["unfinished"]) + 1
			push_warning("[Godot EventSheets] export bake step: %s paused on an await, and an export cannot wait - anything after that await may not be in the exported build. Keep a bake step synchronous (a rendered thumbnail belongs in a File > Run tool)." % script_path)
	report["scripts"] = ran_paths
	return report


## True when the script really has the handler, asked of the SCRIPT rather than an instance -
## `Script.has_method` answers for the Script OBJECT (reload, get_source_code…), so the method list is
## what carries the scripted functions. It includes inherited ones, so a handler on a parent script
## answers here too; discovery is still a text scan, so the file that DECLARES it is the one found.
static func _declares_hook(script: Script) -> bool:
	for method: Dictionary in script.get_script_method_list():
		if str(method.get("name", "")) == HOOK_FUNCTION:
			return true
	return false


## Every `.gd` under `root` whose text declares the export handler, sorted so the run order is the
## same everywhere. Declaring the handler IS the opt-in, so the text test is exactly that one line -
## the alternative (loading every script in the project to reflect on it) costs far more than reading
## the files, and whether the script is a legal host is settled at run time from its real base type.
static func find_export_tools(root: String = "res://") -> PackedStringArray:
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
