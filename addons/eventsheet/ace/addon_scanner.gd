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
##
## Cached on the addon directories' own modification times: a directory's mtime changes when
## a file or folder is added, removed or renamed inside it (not when a file's CONTENTS change,
## which is fine - the listing is paths, and every consumer that reads content keys on the
## file's mtime itself). Without this, every consumer that refreshes per keystroke - the
## expression picker's Self section, the registry, the Doctor - paid a full recursive walk of
## ~90 pack folders (~160 ms) on each call. Pack directories are shallow, so stat-ing them for
## the key costs a few milliseconds and the walk runs once per real change.
static func list_addon_scripts() -> Array[String]:
	var key: String = _listing_key()
	if not key.is_empty() and _listing_cache_key == key:
		return _listing_cache.duplicate()
	var scripts: Array[String] = []
	for root in ADDON_DIRS:
		_collect_scripts(root, scripts)
	# A pack switched off in the Addon manager leaves the scan entirely, which is what takes its
	# actions out of the picker. Its files stay on disk and its sheets still open - only the
	# vocabulary goes, and the Doctor names any sheet still using it.
	var enabled_only: Array[String] = []
	for script_path: String in scripts:
		if not EventSheetPackCatalog.is_disabled_path(script_path):
			enabled_only.append(script_path)
	scripts = enabled_only
	scripts.sort()
	_listing_cache = scripts
	_listing_cache_key = key
	return scripts.duplicate()


static var _listing_cache: Array[String] = []
static var _listing_cache_key: String = ""


## The mtimes of every addon root and its immediate subdirectories, joined - the shape of the
## fleet. Empty when a root is missing, which disables caching rather than caching an absence.
static func _listing_key() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for root: String in ADDON_DIRS:
		var dir: DirAccess = DirAccess.open(root)
		if dir == null:
			return ""
		parts.append("%s|%d" % [root, FileAccess.get_modified_time(root)])
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while not entry.is_empty():
			if dir.current_is_dir() and not entry.begins_with("."):
				var sub: String = root.path_join(entry)
				parts.append("%s|%d" % [sub, FileAccess.get_modified_time(sub)])
			entry = dir.get_next()
		dir.list_dir_end()
	# Switching a pack off changes the listing without touching a directory's mtime, so the
	# disabled set is part of the key - otherwise the picker kept the pack's actions until the
	# next unrelated file change.
	parts.append("disabled|%s" % ",".join(EventSheetPackCatalog.disabled_packs()))
	return "
".join(parts)


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
