# EventSheets - "who uses this behaviour" reads a user's own addons. The scan skipped every folder
# under `addons/`, so an addon of the user's that reached for a pack showed the pack as unused and
# Tidy behaviours ticked it. Only this plugin's own folders stay out.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "pack_usage_addons_test"
const ROOT := "user://pack_usage_addons_test"


static func run() -> bool:
	_clear(ROOT)
	_write(ROOT.path_join("addons/my_addon/mine.gd"), "extends Node\nvar p: Painter = null\n")
	_write(ROOT.path_join("addons/eventsheet/ours.gd"), "extends Node\nvar p: Painter = null\n")
	_write(ROOT.path_join("addons/eventforge/ours.gd"), "extends Node\nvar p: Painter = null\n")
	_write(ROOT.path_join("addons/eventsheet_library/painter/painter.gd"), "class_name Painter\nextends Node\n")
	_write(ROOT.path_join("eventsheet_addons/painter/painter.gd"), "class_name Painter\nextends Node\n")
	var paths: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetPackLibrary.usage_corpus(ROOT):
		paths.append(str(entry["path"]).trim_prefix(ROOT + "/"))
	paths.sort()
	var result: bool = SUPPORT.check(P, "a user's addon is read; this plugin's own folders are not", paths,
		PackedStringArray(["addons/my_addon/mine.gd", "eventsheet_addons/painter/painter.gd"]))
	_clear(ROOT)
	return result


static func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _clear(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for sub: String in DirAccess.get_directories_at(folder):
		_clear(folder.path_join(sub))
	for file: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
