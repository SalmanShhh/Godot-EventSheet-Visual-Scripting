# Writes the behaviour library: every shipped pack folder under eventsheet_addons/, copied byte for
# byte into addons/eventsheet_library/, beside a `.gdignore` so Godot never imports it. Run:
#   godot --headless --path . --script tools/build_library.gd
#   godot --headless --path . --script tools/build_library.gd -- --check
#
# WHY TWO COPIES. This repository is a project that holds every pack: its tests, its showcases and
# its drift gates all read the packs where a game reads them, in eventsheet_addons/, imported and
# registered. A user's project holds only the packs it asked for, copied in from the library the
# plugin carries inside addons/. The pack builders keep writing eventsheet_addons/ (the source of
# truth, compiler output as before); the library is derived from it here, so the two cannot drift
# apart without this gate saying so.
#
# WHAT IS COPIED. The folders `addons/eventforge/shipped_pack_folders.gd` names - the folders the
# pack builders publish - with every file in them except what Godot writes itself on import
# (`.import`, `.translation`). The `.uid` sidecars travel with them, so a pack copied into a project
# keeps the id a scene already names it by. The single runtime scripts at the root of
# eventsheet_addons/ are not packs and are not in the library.
#
# --check writes nothing: it prints `library packs=N drifted=N`, names each drifted path, and exits
# 1 on drift. Without it the library is rewritten to match, and `library packs=N wrote=N` names how
# many paths that put right.
@tool
extends SceneTree

const SHIPPED := preload("res://addons/eventforge/shipped_pack_folders.gd")
const LIBRARY := preload("res://addons/eventsheet/ace/pack_library.gd")
const SOURCE_ROOT := "res://eventsheet_addons"


func _init() -> void:
	var check_only: bool = OS.get_cmdline_user_args().has("--check")
	var drifted: PackedStringArray = drift(SOURCE_ROOT, LIBRARY.LIBRARY_ROOT, PackedStringArray(SHIPPED.FOLDERS), not check_only)
	for path: String in drifted:
		print("LIBRARY DRIFT: %s" % path)
	if check_only:
		print("library packs=%d drifted=%d" % [SHIPPED.FOLDERS.size(), drifted.size()])
	else:
		print("library packs=%d wrote=%d" % [SHIPPED.FOLDERS.size(), drifted.size()])
	quit(1 if check_only and not drifted.is_empty() else 0)


## Every path where the library differs from the packs it mirrors, relative to the library, sorted:
## a file missing or changed, a file or folder the library holds that the packs do not, and a missing
## `.gdignore`. With `write` each difference is put right as it is found, and the list still names
## what was put right.
static func drift(source_root: String, library_root: String, pack_folders: PackedStringArray, write: bool) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if write:
		DirAccess.make_dir_recursive_absolute(library_root)
	var ignore_path: String = library_root.path_join(LIBRARY.IGNORE_FILE)
	if not FileAccess.file_exists(ignore_path):
		out.append(LIBRARY.IGNORE_FILE)
		if write:
			FileAccess.open(ignore_path, FileAccess.WRITE).close()
	for folder: String in pack_folders:
		_compare_tree(source_root.path_join(folder), library_root.path_join(folder), folder, write, out)
	if DirAccess.dir_exists_absolute(library_root):
		for stray: String in DirAccess.get_directories_at(library_root):
			if not pack_folders.has(stray):
				out.append(stray + "/")
				if write:
					_remove_tree(library_root.path_join(stray))
		for stray_file: String in DirAccess.get_files_at(library_root):
			if stray_file != LIBRARY.IGNORE_FILE:
				out.append(stray_file)
				if write:
					DirAccess.remove_absolute(library_root.path_join(stray_file))
	out.sort()
	return out


static func _compare_tree(source: String, mirror: String, label: String, write: bool, out: PackedStringArray) -> void:
	if write:
		DirAccess.make_dir_recursive_absolute(mirror)
	var wanted: Dictionary = {}
	for file_name: String in DirAccess.get_files_at(source):
		if LIBRARY.GENERATED_EXTENSIONS.has(file_name.get_extension()):
			continue
		wanted[file_name] = true
		var from_path: String = source.path_join(file_name)
		var to_path: String = mirror.path_join(file_name)
		if FileAccess.file_exists(to_path) and FileAccess.get_file_as_bytes(to_path) == FileAccess.get_file_as_bytes(from_path):
			continue
		out.append(label.path_join(file_name))
		if write:
			DirAccess.copy_absolute(from_path, to_path)
	var wanted_dirs: Dictionary = {}
	for child: String in DirAccess.get_directories_at(source):
		wanted_dirs[child] = true
		_compare_tree(source.path_join(child), mirror.path_join(child), label.path_join(child), write, out)
	if not DirAccess.dir_exists_absolute(mirror):
		return
	for extra: String in DirAccess.get_files_at(mirror):
		if not wanted.has(extra) and not LIBRARY.GENERATED_EXTENSIONS.has(extra.get_extension()):
			out.append(label.path_join(extra))
			if write:
				DirAccess.remove_absolute(mirror.path_join(extra))
	for extra_dir: String in DirAccess.get_directories_at(mirror):
		if not wanted_dirs.has(extra_dir):
			out.append(label.path_join(extra_dir) + "/")
			if write:
				_remove_tree(mirror.path_join(extra_dir))


static func _remove_tree(path: String) -> void:
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for child: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)
