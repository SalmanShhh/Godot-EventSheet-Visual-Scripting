# Godot EventSheets - adding a behaviour must not bring a class name the project already uses.
#
# Godot keeps one list of class names for the whole project. A second script declaring a name in it
# fails to parse ("hides a global script class"), so the Behaviour library checks the names a pack
# would bring against Godot's own list BEFORE copying and says which name and which file.
#
# Pinned by VALUE against a small library written under user:// and a hand-made class list, the same
# shape ProjectSettings.get_global_class_list() returns.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "pack_class_clash_test"
const ROOT := "user://pack_class_clash_test"
const LIB := ROOT + "/library"
const PROJECT := ROOT + "/eventsheet_addons"


static func run() -> bool:
	_clear(ROOT)
	EventSheetPackLibrary.forget()
	_write(LIB.path_join(".gdignore"), "")
	_write(LIB.path_join("nav/nav.gd"), "class_name NavThing\nextends Node\n")
	_write(LIB.path_join("nav/extra/helper.gd"), "# no name here\nclass_name NavHelper\nextends RefCounted\n")
	_write(LIB.path_join("plain/plain.gd"), "extends Node\n")
	var user_list: Array = [{"class": "NavThing", "path": "res://game/my_nav.gd", "base": "Node"}]
	var own_copy: Array = [{"class": "NavThing", "path": PROJECT + "/nav/nav.gd", "base": "Node"}]
	var found: Array[Dictionary] = EventSheetPackLibrary.clashes(PackedStringArray(["nav"]), LIB, PROJECT, user_list)
	var both: Array[Dictionary] = EventSheetPackLibrary.clashes(PackedStringArray(["nav"]), LIB, PROJECT,
		[{"class": "NavHelper", "path": "res://a.gd"}, {"class": "NavThing", "path": "res://b.gd"}])
	var message: String = EventSheetPackLibrary.clash_message(found)
	var ok: bool = SUPPORT.pins(P, [
		["the names a pack folder brings are read off its class_name lines, subfolders included",
			EventSheetPackLibrary.declared_classes(PackedStringArray(["nav"]), LIB).keys(), ["NavHelper", "NavThing"]],
		["a name the project's own file holds is a clash, naming that file",
			found.map(func(row: Dictionary) -> Array: return [row["name"], row["folder"], row["file"]]),
			[["NavThing", "nav", "res://game/my_nav.gd"]]],
		["several clashes are listed by name order", both.map(func(row: Dictionary) -> String: return str(row["name"])),
			["NavHelper", "NavThing"]],
		["no clash when the project holds no such name",
			EventSheetPackLibrary.clashes(PackedStringArray(["nav"]), LIB, PROJECT, [{"class": "Other", "path": "res://o.gd"}]), []],
		["the pack's own earlier copy is not a clash",
			EventSheetPackLibrary.clashes(PackedStringArray(["nav"]), LIB, PROJECT, own_copy), []],
		["a pack with no class_name never clashes",
			EventSheetPackLibrary.clashes(PackedStringArray(["plain"]), LIB, PROJECT, user_list), []],
		["the message names the class and the file", [message.contains("NavThing"), message.contains("res://game/my_nav.gd")], [true, true]],
		["the message says what to do", message.contains("Rename your class, or do not add this behaviour."), true],
		["no clash says nothing", EventSheetPackLibrary.clash_message([] as Array[Dictionary]), ""],
	])
	_clear(ROOT)
	return ok


static func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for child: String in DirAccess.get_directories_at(path):
		_clear(path.path_join(child))
	DirAccess.remove_absolute(path)
