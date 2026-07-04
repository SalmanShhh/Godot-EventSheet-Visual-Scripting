# EventSheet - Zero-config ACE addon scanner
# Drop a provider script (or a folder of scripts) into res://eventsheet_addons/ and its
# annotated members become project-wide ACEs automatically. No manifest, no JSON, no
# per-sheet setup: all metadata derives from the script itself (class_name → provider name,
# top doc comment → description, @ace_* annotations → everything else).
@tool
class_name EventSheetAddonScanner
extends RefCounted

const ADDON_DIRS: Array[String] = ["res://eventsheet_addons/"]


## All .gd scripts under the addon directories (recursive), sorted for determinism.
static func list_addon_scripts() -> Array[String]:
	var scripts: Array[String] = []
	for root in ADDON_DIRS:
		_collect_scripts(root, scripts)
	scripts.sort()
	return scripts


static func _collect_scripts(dir_path: String, into: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_scripts(full_path, into)
		elif entry.get_extension() == "gd":
			into.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
