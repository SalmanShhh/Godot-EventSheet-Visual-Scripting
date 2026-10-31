# Godot EventSheets - Godot-native entry points (headless cores)
#
# The "meet Godot devs where they already click" arc: these are the testable cores
# behind the Scene-dock "Attach Event Sheet", the FileSystem/script-editor "Open as
# Event Sheet" and the Inspector's "Edit Event Sheet" button. The editor glue
# (EventSheetContextMenu, EventSheetEditButtonPlugin, plugin.gd) stays thin.
@tool
class_name EventSheetWorkflow
extends RefCounted

## The `extends` line of a script, at the start of a line: its class name, when it names one.
static var _EXTENDS: RegEx = RegEx.create_from_string("(?m)^extends\\s+([A-Za-z_][A-Za-z0-9_]*)")
## click_opens_as_sheet's answers: path -> [modified time, answer].
static var _click_answers: Dictionary = {}


## The "Attach Script" reflex for sheets: creates a sheet whose host_class matches the node, writes it
## beside the scene as a single hand-editable .gd (the .gd IS the sheet - the default format, no .tres
## companion, exactly like Create New > Event Sheet), and attaches that .gd to the node - one right-click
## from a bare node to an editable event sheet. Returns {ok, message, sheet_path}.
static func create_sheet_for_node(node: Node, directory: String) -> Dictionary:
	if node == null:
		return {"ok": false, "message": "Select a node first.", "sheet_path": ""}
	if node.get_script() != null:
		return {"ok": false, "message": "%s already has a script - open it as a sheet instead (GDScript-backed sheets) or remove it first." % node.name, "sheet_path": ""}
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = node.get_class()
	var base_name: String = str(node.name).to_snake_case()
	if base_name.is_empty():
		base_name = "node"
	# Reuse the Create-New writer: a banner-less .gd that IS the sheet (suffix on collision, never
	# overwrite). No .tres and no regenerated companion - an attached sheet is a plain editable script
	# from the first frame, consistent with every other way a sheet is born.
	var result: Dictionary = write_sheet_file(sheet, directory, base_name + "_sheet")
	if not bool(result.get("ok", false)):
		return result
	node.set_script(load(str(result.get("sheet_path"))))
	return {"ok": true, "message": "Event sheet attached to %s - it opens in the EventSheet workspace." % node.name, "sheet_path": str(result.get("sheet_path"))}


## What the "Open as Event Sheet" context entries accept: sheet .tres files, any .gd (GDScript-backed
## sheets open arbitrary scripts losslessly), and a .tscn, which opens as the read-only reading of
## the whole scene - every script it uses, under its own object bar.
static func is_openable_as_sheet(path: String) -> bool:
	var extension: String = path.get_extension().to_lower()
	if extension == "gd" or extension == "tscn":
		return true
	if extension == "tres":
		if ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) is EventSheetResource:
			return true
		# A .tres that is a DATA ASSET opens too - as a table, one row per field. Loaded through
		# the same static core the table view uses, so the menu entry and the view never disagree
		# about what is openable.
		return EventSheetDataTable.is_data_asset(path)
	# A FOLDER of data assets of one type opens as ONE grid - a row per asset, a column per
	# field. Anything else about a folder (mixed types, no assets) is not a table, and offering to
	# open it as one would promise a grid nobody could draw.
	if extension.is_empty() and DirAccess.dir_exists_absolute(path):
		return EventSheetDataTable.is_one_type_folder(path)
	return false


## Whether a click on the script at `path` opens it as a sheet while "Open Scripts as Event Sheets" is
## ticked, or leaves it to the Script editor, as the setting's own hover says. The sheet opens any
## `.gd` when asked to (Open as Event Sheet), but a click hands it only a script it reads: not an
## editor script (one that extends an Editor class, such as an EditorScript run from the Script
## editor's File menu, or an EditorPlugin), and not a file that does not save back byte for byte. A
## path with no file yet is the sheet's. The answer is kept per file until the file changes, because
## the Inspector asks again on every selection.
static func click_opens_as_sheet(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	var stamp: int = FileAccess.get_modified_time(path)
	var known: Array = _click_answers.get(path, [])
	if known.size() == 2 and int(known[0]) == stamp:
		return bool(known[1])
	var source: String = FileAccess.get_file_as_string(path)
	var answer: bool = not extends_editor_class(source) and EventSheets.round_trips(source)
	_click_answers[path] = [stamp, answer]
	return answer


## True when a script's `extends` names one of the editor's own classes (EditorScript, EditorPlugin,
## EditorInspectorPlugin ...): code that runs the editor, not a game object a sheet describes.
static func extends_editor_class(source: String) -> bool:
	var found: RegExMatch = _EXTENDS.search(source)
	return found != null and found.get_string(1).begins_with("Editor")


## The file a typed name becomes in `directory`, before any collision suffix: get_file() drops any
## path parts and "../" traversal (so a name can never escape the chosen folder), a trailing ".gd" is
## stripped so "player.gd" becomes player.gd and not player.gd.gd, then snake_case with a safe
## fallback. The New Event Sheet window names this file before Create, so both spell it here.
static func sheet_file_path(directory: String, base_name: String) -> String:
	var raw_name: String = str(base_name).get_file()
	if raw_name.get_extension().to_lower() == "gd":
		raw_name = raw_name.get_basename()
	var stem: String = raw_name.to_snake_case()
	if stem.is_empty():
		stem = "event_sheet"
	# path_join handles trailing slashes itself; trim_suffix would mangle the root forms
	# ("res://" -> "res:/").
	return directory.path_join(stem + ".gd")


## The FileSystem "Create New > Event Sheet" core: compiles a starter sheet straight to a
## hand-editable .gd in the chosen folder (suffix, never overwrite), so the .gd IS the sheet -
## the default format, no .tres. Pure + headless: the editable reopen, filesystem rescan and
## workspace open are the editor glue's job. Returns {ok, message, sheet_path}, the same shape
## create_sheet_for_node returns so the plugin reads both identically.
static func write_sheet_file(sheet: EventSheetResource, directory: String, base_name: String) -> Dictionary:
	if sheet == null:
		return {"ok": false, "message": "No sheet to create.", "sheet_path": ""}
	var sheet_path: String = sheet_file_path(directory, base_name)
	var wanted_file: String = sheet_path.get_file()
	# The suffix joins with an underscore, never a hyphen: the stem has to stay a valid identifier
	# so a class_name derived from the file name can still match it.
	var suffix: int = 2
	while FileAccess.file_exists(sheet_path):
		sheet_path = directory.path_join("%s_%d.gd" % [wanted_file.get_basename(), suffix])
		suffix += 1
	# omit_generated_banner = true: this .gd is the user's own hand-editable source of truth,
	# NOT a regenerated companion, so it must not carry the "regenerated on every compile"
	# banner. A non-empty output path is used verbatim (it bypasses the generated-name
	# resolver), and compile() writes the bytes itself - the core never touches FileAccess.
	var compile_result: Dictionary = SheetCompiler.compile(sheet, sheet_path, true)
	if not bool(compile_result.get("success", false)):
		return {"ok": false, "message": "The new sheet didn't compile: %s" % str(compile_result.get("errors")), "sheet_path": sheet_path}
	if sheet_path.get_file() != wanted_file:
		return {"ok": true, "renamed": true, "sheet_path": sheet_path,
			"message": "%s was taken, so the new event sheet is %s." % [wanted_file, sheet_path.get_file()]}
	return {"ok": true, "renamed": false, "message": "Created event sheet %s." % sheet_path.get_file(), "sheet_path": sheet_path}
