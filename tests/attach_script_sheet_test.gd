# EventSheets - Attach to Node works on a behaviour sheet that is a script. The sheet's own file is
# the script to attach, but the check asked only for a resource path, which a script sheet never has,
# so Attach answered "Save the sheet first" for a sheet that had just been saved - on the default sheet
# format, every time.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "attach_script_sheet_test"
const PATH := "user://attach_script_sheet_probe.gd"
const SOURCE := "class_name AttachScriptSheetProbe\nextends Node\n\nvar host: Node2D = null\n"


static func run() -> bool:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(SOURCE)
	file.close()
	var sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external(PATH, false)
	if sheet == null:
		return SUPPORT.check(P, "the probe script opens as a sheet", false, true)
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.read_only = false
	var host: Node2D = Node2D.new()
	host.name = "Hero"
	var result: Dictionary = EventSheetAuthorLoop.attach_behavior(sheet, host)
	var child: Node = host.get_child(0) if host.get_child_count() > 0 else null
	var rows: Array = [
		["the script sheet attaches", bool(result.get("ok", false)), true],
		["it is parented under the host", host.get_child_count(), 1],
		["and carries the sheet's own file as its script", child.get_script().resource_path if child != null and child.get_script() != null else "", PATH],
		["the file is exactly what it was", FileAccess.get_file_as_string(PATH), SOURCE],
	]
	host.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	return SUPPORT.pins(P, rows)
