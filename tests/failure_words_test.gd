# EventSheets - a file Godot would not write is told in words. A failed save, copy, delete or web
# request used to print "(error 31)"; each now names the file, gives Godot's own words for the cause
# and says what to try next.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "failure_words_test"
const WORDS_PATH := "res://addons/eventforge/failure_words.gd"


static func run() -> bool:
	var words: GDScript = load(WORDS_PATH)
	# A real failure: a path inside a folder that does not exist.
	var missing: String = "user://no_such_folder_for_failure_words/sheet.tres"
	FileAccess.open(missing, FileAccess.WRITE)
	var err: int = FileAccess.get_open_error()
	var saved: String = words.save_failed(missing, err)
	var deleted: String = words.delete_failed("res://gone.tres", ERR_FILE_NO_PERMISSION)
	var copied: String = words.copy_failed("user://slot.json", ERR_FILE_CANT_WRITE)
	var reached: String = words.request_failed("https://example.invalid/v1", ERR_CANT_CONNECT)
	var rows: Array = [
		["a failed save is not zero", err != OK, true],
		["save names the file", saved.contains(missing), true],
		["save gives Godot's own words", saved.contains(error_string(err)), true],
		["save says what to do", saved.contains("then try again"), true],
		["save prints no bare number", saved.contains("(error "), false],
		["delete names the file", deleted.contains("gone.tres"), true],
		["delete gives Godot's own words", deleted.contains(error_string(ERR_FILE_NO_PERMISSION)), true],
		["delete says nothing was removed", deleted.contains("Nothing was removed"), true],
		["copy names where it was going", copied.contains("slot.json"), true],
		["copy says the original is untouched", copied.contains("original is untouched"), true],
		["a request names the address", reached.contains("example.invalid"), true],
		["a request says nothing was sent", reached.contains("Nothing was sent"), true],
	]
	# No source file the plugin ships may print "(error %d)" again.
	rows.append(["no message prints a bare engine number", _files_with_bare_numbers(), []])
	return SUPPORT.pins(P, rows)


## The editor and API files whose user-facing strings carry "(error %d)".
static func _files_with_bare_numbers() -> Array:
	var found: Array = []
	for root: String in ["res://addons/eventsheet", "res://addons/eventforge"]:
		_walk(root, found)
	found.sort()
	return found


static func _walk(folder: String, found: Array) -> void:
	for sub: String in DirAccess.get_directories_at(folder):
		if sub == "registration" or sub == "importer":
			continue
		_walk(folder.path_join(sub), found)
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() != "gd":
			continue
		if FileAccess.get_file_as_string(folder.path_join(file)).contains("(error %d)"):
			found.append(folder.path_join(file))
