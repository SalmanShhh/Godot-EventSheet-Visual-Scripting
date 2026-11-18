# Godot EventSheets - the library's class index reads a script only as far as its class_name.
#
# The Project Doctor asks which library folder declares which class, and read every script of the
# library whole to answer (about five megabytes, a quarter of a second in one frame). The declaration
# sits in a script's first lines, so the file is now read a line at a time and left once it is found.
# The pins hold the answer to the whole-file reading it replaces: the same table for the shipped
# library, and for fixture files that put the declaration first, late, twice, after CRLF endings, in
# a comment and nowhere.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "pack_class_index_test"


static func run() -> bool:
	var root: String = SUPPORT.own_folder("class_index_library")
	_write(root, "a_first/a.gd", "class_name AlphaFirst\nextends Node\n")
	_write(root, "b_late/b.gd", "extends Node\n" + "## filler\n".repeat(80) + "class_name BetaLate\n")
	_write(root, "c_twice/c.gd", "class_name GammaOne\nclass_name GammaTwo\n")
	_write(root, "d_crlf/d.gd", "# header\r\nclass_name DeltaCrlf\r\nextends Node\r\n")
	_write(root, "e_comment/e.gd", "# class_name NotMe\n\tclass_name AlsoNotMe\nvar x := \"class_name NorMe\"\n")
	_write(root, "f_none/f.gd", "extends Node\n")
	_write(root, "g_nested/inner/g.gd", "@tool\nclass_name EpsilonNested\n")
	_write(root, "h_dup/h.gd", "class_name AlphaFirst\n")
	var rows: Array = [
		["fixture library: the same table as reading every file whole", EventSheetPackLibrary.class_index(root), _whole_file_index(root)],
		["read in turns it is the same table", _in_turns(root), EventSheetPackLibrary.class_index(root)],
		["a declaration after eighty lines is found", str(EventSheetPackLibrary.class_index(root).get("BetaLate", "")), "b_late"],
		["a name declared twice goes to the first folder", str(EventSheetPackLibrary.class_index(root).get("AlphaFirst", "")), "a_first"],
		["a comment, an indented line and a string declare nothing", EventSheetPackLibrary.class_index(root).has("NotMe") or EventSheetPackLibrary.class_index(root).has("AlsoNotMe") or EventSheetPackLibrary.class_index(root).has("NorMe"), false],
		["only the first declaration of a file counts", EventSheetPackLibrary.class_index(root).has("GammaTwo"), false],
	]
	if EventSheetPackLibrary.exists():
		rows.append(["the shipped library: the same table as reading every file whole", EventSheetPackLibrary.class_index(), _whole_file_index(EventSheetPackLibrary.LIBRARY_ROOT)])
	return SUPPORT.pins(P, rows)


static func _write(root: String, relative: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(root.path_join(relative).get_base_dir())
	var file: FileAccess = FileAccess.open(root.path_join(relative), FileAccess.WRITE)
	file.store_string(text)
	file.close()


## The table the index used to be: every script read whole, the first declaration of each kept.
static func _whole_file_index(root: String) -> Dictionary:
	var index: Dictionary = {}
	var pattern: RegEx = RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	for pack_dir: String in EventSheetPackLibrary.folders(root):
		for script_path: String in EventSheetPackLibrary._scripts_in(root.path_join(pack_dir)):
			var found: RegExMatch = pattern.search(FileAccess.get_file_as_string(script_path))
			if found != null and not index.has(found.get_string(1)):
				index[found.get_string(1)] = pack_dir
	return index


## The table read a script at a time, counting the turns it gives away.
static func _in_turns(root: String) -> Dictionary:
	# Called by name: it is a coroutine, and a test cannot await. It never gives a turn away here, so it answers at once.
	return Callable(EventSheetPackLibrary, "class_index_in_turns").call(func(_read: int) -> void: pass, root + "/")
