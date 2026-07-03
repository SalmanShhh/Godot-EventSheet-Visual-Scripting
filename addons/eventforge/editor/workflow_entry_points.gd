# Godot EventSheets — Godot-native entry points (headless cores)
#
# The "meet Godot devs where they already click" arc: these are the testable cores
# behind the Scene-dock "Attach Event Sheet", the FileSystem/script-editor "Open as
# Event Sheet" and the Inspector's "Edit Event Sheet" button. The editor glue
# (EventSheetContextMenu, EventSheetEditButtonPlugin, plugin.gd) stays thin.
@tool
class_name EventSheetWorkflow
extends RefCounted


## The "Attach Script" reflex for sheets: creates a sheet whose host_class matches
## the node, saves it beside the scene (suffix, never overwrite), compiles its pair
## and attaches the generated script to the node — one right-click from node to
## editable sheet. Returns {ok, message, sheet_path}.
static func create_sheet_for_node(node: Node, directory: String) -> Dictionary:
	if node == null:
		return {"ok": false, "message": "Select a node first.", "sheet_path": ""}
	if node.get_script() != null:
		return {"ok": false, "message": "%s already has a script — open it as a sheet instead (GDScript-backed sheets) or remove it first." % node.name, "sheet_path": ""}
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = node.get_class()
	var base_name: String = str(node.name).to_snake_case()
	if base_name.is_empty():
		base_name = "sheet"
	# path_join handles trailing slashes itself; trim_suffix would mangle the
	# root forms ("user://" → "user:/").
	var sheet_path: String = directory.path_join(base_name + "_sheet.tres")
	var suffix: int = 2
	while FileAccess.file_exists(sheet_path):
		sheet_path = directory.path_join("%s_sheet-%d.tres" % [base_name, suffix])
		suffix += 1
	if ResourceSaver.save(sheet, sheet_path) != OK:
		return {"ok": false, "message": "Couldn't save the sheet to %s." % sheet_path, "sheet_path": ""}
	var saved: EventSheetResource = ResourceLoader.load(sheet_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	saved.take_over_path(sheet_path)
	var compile_result: Dictionary = SheetCompiler.compile(saved, "")
	if not bool(compile_result.get("success", false)):
		return {"ok": false, "message": "The new sheet didn't compile: %s" % str(compile_result.get("errors")), "sheet_path": sheet_path}
	node.set_script(load(SheetCompiler._resolve_output_path(saved, "")))
	return {"ok": true, "message": "Event sheet attached to %s — it opens in the EventSheet workspace." % node.name, "sheet_path": sheet_path}


## What the "Open as Event Sheet" context entries accept: sheet .tres files and any
## .gd (GDScript-backed sheets open arbitrary scripts losslessly).
static func is_openable_as_sheet(path: String) -> bool:
	var extension: String = path.get_extension().to_lower()
	if extension == "gd":
		return true
	if extension == "tres":
		return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) is EventSheetResource
	return false
