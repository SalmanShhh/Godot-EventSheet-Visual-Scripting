# Godot EventSheets - one listing of the project's folders, held for the length of one Project Doctor audit.
#
# Every directory of the project with the files directly in it, as [[directory path, PackedStringArray of
# file names], ...]. While the Doctor holds one (see `ProjectFiles.hold`), every walk of the project is a filter over
# it instead of a trip over the directories: the same answer without the disk. It is made by `list_everything`,
# which is plain disk reading on fresh `DirAccess` handles, so it may run on a worker thread.
#
# DELIBERATELY NO `class_name`, and kept out of `project_files.gd` itself, so the editor's first open compiles
# none of it: the Doctor loads it by path.
@tool
extends RefCounted

var _entries: Array = []


func _init(entries: Array = []) -> void:
	_entries = entries


## Every directory of the project (the dot-directories stepped over, nothing else) with the names of the files
## in it.
static func list_everything() -> Array:
	var listing: Array = []
	var pending: PackedStringArray = PackedStringArray(["res://"])
	while not pending.is_empty():
		var directory_path: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory == null:
			continue
		var files: PackedStringArray = PackedStringArray()
		directory.list_dir_begin()
		var entry: String = directory.get_next()
		while not entry.is_empty():
			if directory.current_is_dir():
				if not entry.begins_with("."):
					pending.append(directory_path.path_join(entry))
			else:
				files.append(entry)
			entry = directory.get_next()
		directory.list_dir_end()
		listing.append([directory_path, files])
	return listing


## Whether a directory path has a folder named in `skipped` anywhere along it.
static func inside_skipped(directory_path: String, skipped: PackedStringArray) -> bool:
	if skipped.is_empty():
		return false
	for part: String in directory_path.trim_prefix("res://").split("/", false):
		if skipped.has(part):
			return true
	return false


## The files that `keeps` says yes to, for the directories `into` says yes to (a Callable taking the directory
## path), in path order.
func files_where(into: Callable, keeps: Callable) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for entry: Variant in _entries:
		var directory_path: String = (entry as Array)[0]
		if not bool(into.call(directory_path)):
			continue
		for file_name: String in ((entry as Array)[1] as PackedStringArray):
			var full_path: String = directory_path.path_join(file_name)
			if keeps.call(full_path):
				found.append(full_path)
	found.sort()
	return found


## `ProjectFiles.walk` over the held listing: the files `keeps` says yes to, stepping over any directory named
## in `skipped_directories`.
func walk(skipped_directories: PackedStringArray, keeps: Callable) -> PackedStringArray:
	return files_where(func(directory_path: String) -> bool:
		return not inside_skipped(directory_path, skipped_directories), keeps)
