# Godot EventSheets - the per-process scratch folder a test keeps its files in.
#
# Every process started on this project shares one user folder, so a test that writes or deletes a
# fixed name there can be broken by a neighbour. `EventSheetTestSupport.scratch(name)` hands out a
# path in a folder named for the process; this pins that the folder is this process's own, that it
# is made ready for a write, and that two names never share a path.
@tool
class_name ScratchFolderTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "scratch_folder_test"


static func run() -> bool:
	var root: String = SUPPORT.scratch_root()
	var file_path: String = SUPPORT.scratch("a/b/note.txt")
	var written: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	var wrote: bool = written != null
	if wrote:
		written.store_string("held")
		written.close()
	var passed: bool = SUPPORT.pins(NAME, [
		["the folder is named for this process", root.ends_with("_%d" % OS.get_process_id()), true],
		["it sits at the top of the user folder", root.begins_with("user://eventforge_tests_"), true],
		["a scratch path is inside it", file_path.begins_with(root + "/"), true],
		["a nested name can be written at once", wrote, true],
		["two names are two paths", SUPPORT.scratch("one") != SUPPORT.scratch("two"), true],
	])
	DirAccess.remove_absolute(file_path)
	return passed
