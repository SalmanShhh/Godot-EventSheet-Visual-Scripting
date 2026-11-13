# Godot EventSheets - the loose runtime scripts a few rows call (free spot, retire, bus mix...).
#
# A project made from addons/ alone holds none of them, so a row calling one would emit a call to a
# class that does not exist. Pinned by VALUE against a small library and project written under
# user:// (every function takes its folders as parameters), plus the real tree: the library carries
# every script the shipped-folders file names, and every class a built-in row's template names is
# one the library can supply.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const HELPERS := preload("res://addons/eventforge/runtime_helpers.gd")
const SHIPPED := preload("res://addons/eventforge/shipped_pack_folders.gd")
const P := "runtime_helpers_test"
const ROOT := "user://runtime_helpers_test"
const LIB := ROOT + "/library"
const PROJECT := ROOT + "/project"


static func run() -> bool:
	_clear(ROOT)
	_write(LIB.path_join("spot.gd"), "class_name FreeSpotX\nextends RefCounted\nvar p: OtherHelper = null\n")
	_write(LIB.path_join("spot.gd.uid"), "uid://spot1\n")
	_write(LIB.path_join("other.gd"), "class_name OtherHelper\nextends RefCounted\n")
	_write(LIB.path_join("alone.gd"), "class_name AloneHelper\nextends RefCounted\n")
	var row_text: String = "var at: Vector2 = FreeSpotX.find(self)"
	var named: PackedStringArray = HELPERS.files_named_in(row_text, LIB)
	var lacking_before: PackedStringArray = HELPERS.lacking_for_text(row_text, LIB, PROJECT)
	var copied: PackedStringArray = HELPERS.ensure_for_text(row_text, LIB, PROJECT)
	_write(PROJECT.path_join("alone.gd"), "# the project's own\n")
	var ok: bool = SUPPORT.pins(P, [
		["a class named in a row brings its file, then the helper that file names", named, PackedStringArray(["other.gd", "spot.gd"])],
		["a longer identifier is not the class", HELPERS.files_named_in("FreeSpotXY.find()", LIB), PackedStringArray()],
		["before anything is copied both are lacking", lacking_before, PackedStringArray(["other.gd", "spot.gd"])],
		["ensure copies them", copied, PackedStringArray(["other.gd", "spot.gd"])],
		["the file arrives", FileAccess.file_exists(PROJECT.path_join("spot.gd")), true],
		["its uid sidecar arrives with it", FileAccess.get_file_as_string(PROJECT.path_join("spot.gd.uid")), "uid://spot1\n"],
		["after that nothing is lacking", HELPERS.lacking_for_text(row_text, LIB, PROJECT), PackedStringArray()],
		["a second ensure copies nothing", HELPERS.ensure_for_text(row_text, LIB, PROJECT), PackedStringArray()],
		["a file the project holds is never overwritten",
			HELPERS.copy_into_project(PackedStringArray(["alone.gd"]), LIB, PROJECT), PackedStringArray()],
		["...and keeps its own text", FileAccess.get_file_as_string(PROJECT.path_join("alone.gd")), "# the project's own\n"],
	])
	# The real tree.
	var library_classes: Dictionary = HELPERS.class_files()
	var shipped_files: Array = library_classes.values()
	shipped_files.sort()
	var manifest: Array = SHIPPED.HELPER_FILES.duplicate()
	manifest.sort()
	var in_templates: PackedStringArray = PackedStringArray()
	for module: String in ["spawn_aces", "removal_aces", "audio_server_aces", "world_look_aces", "vibration_aces", "sequencer_aces"]:
		in_templates.append_array(HELPERS.files_named_in(
			FileAccess.get_file_as_string("res://addons/eventforge/registration/modules/%s.gd" % module)))
	ok = SUPPORT.pins(P, [
		["the library's helpers are exactly the shipped manifest", shipped_files, manifest],
		["the free-spot row's module brings free_spot.gd",
			HELPERS.files_named_in(FileAccess.get_file_as_string("res://addons/eventforge/registration/modules/spawn_aces.gd")).has("free_spot.gd"), true],
		["the rows' modules ask for helpers the library has", in_templates.size() > 0, true],
	]) and ok
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
