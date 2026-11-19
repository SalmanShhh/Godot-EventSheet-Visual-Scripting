# EventForge - keeps the icons of a project's packs and the picker's section icons drawn in the
# editor's own icon colours.
#
# Godot draws its own icons in one ink and recolours them for a light theme; it does the same for an
# icon of ours only when the icon's import says so (editor/convert_colors_with_editor_theme). The repo
# ships that import beside every icon, but a pack added to a project from the behaviour library
# arrives without one (the library never carries Godot's import files), so the editor imports it with
# the flag off and the icon stays pale on a light theme. This turns the flag on, and lists the
# icons to be imported again when the editor's theme changes, because the colours are baked at import.
#
# Loaded by path from the plugin, so nothing names it and the editor never compiles it unless asked.
@tool
extends RefCounted

const SHIPPED := preload("res://addons/eventforge/shipped_pack_folders.gd")
const PACK_ROOT: String = "res://eventsheet_addons"
const SECTION_ROOT: String = "res://addons/eventsheet/icons/sections"
const FLAG_OFF: String = "editor/convert_colors_with_editor_theme=false"
const FLAG_ON: String = "editor/convert_colors_with_editor_theme=true"
const SCALE_OFF: String = "editor/scale_with_editor_scale=false"
const SCALE_ON: String = "editor/scale_with_editor_scale=true"


## The icons of the shipped packs this project holds: each shipped pack folder's icon.svg and icon_3d.svg.
## A folder under eventsheet_addons/ the plugin does not ship is the user's own pack and is never touched.
static func pack_icon_paths(root: String = PACK_ROOT) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	# A project with no behaviours yet has no such folder: nothing to look after, and nothing to print.
	if not DirAccess.dir_exists_absolute(root):
		return out
	for folder: String in DirAccess.get_directories_at(root):
		if not SHIPPED.FOLDERS.has(folder):
			continue
		for file_name: String in ["icon.svg", "icon_3d.svg"]:
			var path: String = "%s/%s/%s" % [root, folder, file_name]
			if FileAccess.file_exists(path):
				out.append(path)
	return out


## Every icon of ours the editor bakes colours into: the packs' and the picker sections'.
static func all_icon_paths() -> PackedStringArray:
	var out: PackedStringArray = pack_icon_paths()
	for file_name: String in DirAccess.get_files_at(SECTION_ROOT):
		if file_name.ends_with(".svg"):
			out.append("%s/%s" % [SECTION_ROOT, file_name])
	return out


## Turns the flag on in the import of each icon whose import has it off, and returns those icons: they
## are what the editor has to import again. An icon with no import yet is left to the editor.
static func follow_the_editor_theme(paths: PackedStringArray) -> PackedStringArray:
	var changed: PackedStringArray = PackedStringArray()
	for path: String in paths:
		var import_path: String = path + ".import"
		if not FileAccess.file_exists(import_path):
			continue
		var text: String = FileAccess.get_file_as_string(import_path)
		if not text.contains(FLAG_OFF):
			continue
		var file: FileAccess = FileAccess.open(import_path, FileAccess.WRITE)
		if file == null:
			continue
		file.store_string(text.replace(FLAG_OFF, FLAG_ON).replace(SCALE_OFF, SCALE_ON))
		file.close()
		changed.append(path)
	return changed


# ---- Looking after the imports without holding the editor --------------------------------------
#
# The editor tells the plugin the project's files changed after EVERY save of anything, and each ping
# used to list the pack folders and read every icon's import as text on the main thread (about 100 ms
# for the shipped packs, growing with the packs), to find that nothing was owed. Now what a ping needs
# is asked of the disk on a worker thread and only the answer comes back, and a pack icon's import is
# read as text only when its modified time is not the one already checked, so a ping with nothing
# changed reads none.

## How many imports `scan` has read as text. Only here so a test can see that a ping read none.
static var reads: int = 0
## Each icon's import path and the modified time at which its import was last found already following
## the editor theme. An import is read again only when its time differs from the one kept here.
static var _checked: Dictionary = {}
## The worker's task id while a scan is running, otherwise -1.
static var _task: int = -1
## True when a ping came in while a scan was running; one more scan follows it.
static var _again: bool = false
## What the finished scan found, for the frame that lands it.
static var _found: Dictionary = {}


## What is owed, read from the disk and nothing else: the icons whose import still has the flag off, and
## `checked` with every import it found in order. An icon with no import yet is left to the editor and
## is not remembered, so it is looked at again once the editor has made one. Safe off the main thread.
static func scan(checked: Dictionary, root: String = PACK_ROOT) -> Dictionary:
	var owed: PackedStringArray = PackedStringArray()
	var now: Dictionary = checked.duplicate()
	if not DirAccess.dir_exists_absolute(root):
		return {"owed": owed, "checked": now}
	for folder: String in DirAccess.get_directories_at(root):
		if not SHIPPED.FOLDERS.has(folder):
			continue
		for file_name: String in ["icon.svg", "icon_3d.svg"]:
			var icon: String = "%s/%s/%s" % [root, folder, file_name]
			var stamp: int = FileAccess.get_modified_time(icon + ".import")
			if stamp == 0 or int(now.get(icon, 0)) == stamp:
				continue
			reads += 1
			if FileAccess.get_file_as_string(icon + ".import").contains(FLAG_OFF):
				owed.append(icon)
				now.erase(icon)
			else:
				now[icon] = stamp
	return {"owed": owed, "checked": now}


## Asks for a scan on a worker and lands the answer from a frame of the main loop (never a deferred
## call: a reimport opens a dialog the editor refuses while it flushes those). A ping that arrives while
## one scan runs makes one more follow it. The flag is turned on and the icons reimported there, on the
## main thread, and only when the scan found something owed.
static func follow_in_background(file_system: EditorFileSystem) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if _task >= 0:
		_again = true
		return
	_task = WorkerThreadPool.add_task(_scan_task.bind(_checked.duplicate()))
	tree.process_frame.connect(_land.bind(file_system))


static func _scan_task(checked: Dictionary) -> void:
	_found = scan(checked)


static func _land(file_system: EditorFileSystem) -> void:
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	(Engine.get_main_loop() as SceneTree).process_frame.disconnect(_land.bind(file_system))
	_checked = _found.get("checked", _checked)
	var changed: PackedStringArray = follow_the_editor_theme(_found.get("owed", PackedStringArray()))
	if not changed.is_empty() and is_instance_valid(file_system):
		if file_system.is_scanning():
			file_system.filesystem_changed.connect(file_system.reimport_files.bind(changed), CONNECT_ONE_SHOT)
		else:
			file_system.reimport_files(changed)
	if _again:
		_again = false
		follow_in_background(file_system)
