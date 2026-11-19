@tool
extends RefCounted

# What the plugin itself has written down about a file's path, followed when the FileSystem dock renames or
# moves that file (path_follower.gd calls this in the same moment the open tabs follow).
#
# The plugin keeps a file's path in four kinds of place besides the tab, and each one follows:
#   * the editor's per-project memory keyed by a sheet's path: the regions folded, how far a sheet is
#     collapsed, the functions locked, the look chosen for a script, the last test result, where the boxes of
#     the sheet map were put, and the files a saved workspace opens;
#   * the paths a sheet stores in its own fields (the sheets it includes, the scripts it registers as
#     providers, its icon) in every OPEN sheet, which is changed in memory and left unsaved;
#   * the same fields in every sheet FILE of the project that is not open, respelled in place, one line of
#     the file, after the file's backup is taken;
#   * and, said but not touched, the user's own GDScript: a `preload("res://old.gd")` in code the user wrote
#     is theirs and Godot's to handle, so the files that still name the old path are counted and the reader
#     is told where to look.
#
# Loaded by path from the follower, so the editor's boot path never carries it.

const FOLLOWER := preload("res://addons/eventsheet/editor/dock/path_follower.gd")
const CLAIM := preload("res://addons/eventforge/compiler/generated_script_claim.gd")
const SECTION: String = "eventsheets"
## Per-project memory whose value is a dictionary keyed by a file's path.
const PATH_KEYED: PackedStringArray = ["region_folds", "collapse_state", "function_locks", "sheet_looks", "test_results", "sheet_map_layout"]
## The fields of a sheet file that hold a path, as a line of the file begins them.
const SHEET_FIELDS: PackedStringArray = ["includes", "ace_provider_scripts", "custom_class_icon"]
## Folders the walks never enter: the engine's cache and the plugin's own shipped code.
const SKIPPED: PackedStringArray = ["res://.godot", "res://addons/eventforge", "res://addons/eventsheet", "res://addons/eventsheet_library", "res://eventsheet_addons"]


## `store` with every key under the moved path renamed, keeping its value. A key that would land on one that
## exists is left where it is (the new name already has memory of its own). `store` is not changed.
static func rekeyed(store: Dictionary, old_path: String, new_path: String, is_folder: bool) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in store:
		var mapped: String = FOLLOWER.mapped(str(key), old_path, new_path, is_folder)
		if mapped != str(key) and not store.has(mapped):
			out[mapped] = store[key]
		else:
			out[key] = store[key]
	return out


## A list of paths with the moved ones renamed.
static func remapped(paths: Variant, old_path: String, new_path: String, is_folder: bool) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for path: Variant in paths:
		out.append(FOLLOWER.mapped(str(path), old_path, new_path, is_folder))
	return out


## Moves the editor's per-project memory of a file to its new path. Returns how many stores changed.
static func follow_editor_memory(old_path: String, new_path: String, is_folder: bool) -> int:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return 0
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var changed_stores: int = 0
	for key: String in PATH_KEYED:
		var stored: Variant = settings.get_project_metadata(SECTION, key, {})
		if not (stored is Dictionary):
			continue
		var moved: Dictionary = rekeyed(stored as Dictionary, old_path, new_path, is_folder)
		if moved.hash() != (stored as Dictionary).hash():
			settings.set_project_metadata(SECTION, key, moved)
			changed_stores += 1
	var workspaces: Variant = settings.get_project_metadata(SECTION, "workspaces", {})
	if workspaces is Dictionary:
		var edited: Dictionary = (workspaces as Dictionary).duplicate(true)
		var touched: bool = false
		for workspace_name: Variant in edited:
			var entry: Variant = edited[workspace_name]
			if not (entry is Dictionary) or not (entry as Dictionary).has("paths"):
				continue
			var before: PackedStringArray = remapped((entry as Dictionary)["paths"], "", "", false)
			var after: PackedStringArray = remapped((entry as Dictionary)["paths"], old_path, new_path, is_folder)
			if before != after:
				(entry as Dictionary)["paths"] = after
				touched = true
		if touched:
			settings.set_project_metadata(SECTION, "workspaces", edited)
			changed_stores += 1
	return changed_stores


## The paths in a sheet's own fields, followed to the new place. Returns how many it changed; the sheet is
## changed in memory only, so the caller marks it unsaved.
static func follow_in_sheet(sheet: EventSheetResource, old_path: String, new_path: String, is_folder: bool) -> int:
	if sheet == null:
		return 0
	var changed: int = 0
	for list: Array in [sheet.includes, sheet.ace_provider_scripts]:
		for index: int in range(list.size()):
			var mapped: String = FOLLOWER.mapped(str(list[index]), old_path, new_path, is_folder)
			if mapped != str(list[index]):
				list[index] = mapped
				changed += 1
	var icon: String = FOLLOWER.mapped(sheet.custom_class_icon, old_path, new_path, is_folder)
	if icon != sheet.custom_class_icon:
		sheet.custom_class_icon = icon
		changed += 1
	return changed


## The text of a sheet file with the moved path respelled on the lines that hold a path, and nothing else
## touched: every other byte, line ending included, stays as it was. A file that names the path nowhere
## comes back unchanged.
static func respelled(text: String, old_path: String, new_path: String, is_folder: bool) -> String:
	var from: String = "\"%s" % (old_path.simplify_path().trim_suffix("/") + "/" if is_folder else old_path.simplify_path())
	var to: String = "\"%s" % (new_path.simplify_path().trim_suffix("/") + "/" if is_folder else new_path.simplify_path())
	if not is_folder:
		from += "\""
		to += "\""
	if not text.contains(from):
		return text
	var lines: PackedStringArray = text.split("\n")
	for index: int in range(lines.size()):
		for field: String in SHEET_FIELDS:
			if lines[index].begins_with(field + " = "):
				lines[index] = lines[index].replace(from, to)
	return "\n".join(lines)


## One walk over the project's scripts and sheet files for the moved path: {"sheets": sheet files that hold
## it in a path field and are not open (`skip` names the open ones), "scripts": scripts of the user's that
## still name it}. A script the plugin compiled is its own output and is not the user's.
static func scan(old_path: String, new_path: String, is_folder: bool, skip: PackedStringArray, root: String = "res://") -> Dictionary:
	var job: ScanJob = begin_scan([{"old": old_path, "new": new_path, "folder": is_folder}], skip, root)
	return job.finish()[0]


## Starts the same walk for a BATCH of moves on the engine's worker threads and returns at once: the main
## thread is never held while the files are read. `moves` is a list of {"old", "new", "folder"}. Every file
## is read once however many moves are asked about. Poll `ScanJob.is_done()`, then take `finish()`, which
## answers one {"sheets", "scripts"} per move, in the order asked.
static func begin_scan(moves: Array, skip: PackedStringArray, root: String = "res://") -> ScanJob:
	var job: ScanJob = ScanJob.new()
	job.moves = moves
	job.skip = skip
	job.root = root
	job.refs = load("res://addons/eventsheet/editor/dock/path_references.gd")
	for move: Dictionary in moves:
		var old_path: String = str(move["old"])
		job.needles.append(old_path.simplify_path().trim_suffix("/") + "/" if bool(move["folder"]) else old_path.simplify_path())
	job.common = needles_in_common(job.needles)
	job.task_id = WorkerThreadPool.add_task(job.run, false, "event sheet path scan")
	return job


## The longest start every needle has in common.
static func needles_in_common(needles: PackedStringArray) -> String:
	if needles.is_empty():
		return ""
	var prefix: String = needles[0]
	for needle: String in needles:
		while not needle.begins_with(prefix):
			prefix = prefix.left(prefix.length() - 1)
	return prefix


## A scan of the project's files that runs off the main thread. The listing and the reading both happen in
## the worker: one task lists the folders, then a group task spreads the reading over every worker thread.
class ScanJob extends RefCounted:
	var moves: Array = []
	var needles: PackedStringArray = PackedStringArray()
	var skip: PackedStringArray = PackedStringArray()
	var root: String = "res://"
	## This script itself, which an inner class reaches its static helpers through.
	var refs: GDScript = null
	var task_id: int = -1
	var files: PackedStringArray = PackedStringArray()
	## The longest start every needle shares ("" when they share none).
	var common: String = ""
	## One slot per file, written only by the thread that reads that file: [[move index, "sheet" or "script"], ...].
	var slots: Array = []
	var _finished: bool = false


	func run() -> void:
		var pending: PackedStringArray = PackedStringArray([root])
		while not pending.is_empty():
			var directory_path: String = pending[pending.size() - 1]
			pending.remove_at(pending.size() - 1)
			var directory: DirAccess = DirAccess.open(directory_path)
			if directory == null:
				continue
			directory.list_dir_begin()
			var entry: String = directory.get_next()
			while not entry.is_empty():
				var full_path: String = directory_path.path_join(entry)
				if directory.current_is_dir():
					if not entry.begins_with(".") and not SKIPPED.has(full_path):
						pending.append(full_path)
				else:
					var extension: String = entry.get_extension()
					if extension == "gd" or extension == "tres":
						files.append(full_path)
				entry = directory.get_next()
		slots.resize(files.size())
		if files.is_empty():
			return
		WorkerThreadPool.wait_for_group_task_completion(WorkerThreadPool.add_group_task(_read_one, files.size(), -1, false, "event sheet path scan files"))


	func _read_one(index: int) -> void:
		var full_path: String = files[index]
		var text: String = FileAccess.get_file_as_string(full_path)
		var hits: Array = []
		# Moves in one batch usually share their folder: a file that lacks that stretch names none of them.
		if not common.is_empty() and not text.contains(common):
			slots[index] = hits
			return
		for at: int in range(needles.size()):
			if not text.contains(needles[at]):
				continue
			var move: Dictionary = moves[at]
			if full_path == str(move["new"]):
				continue
			var kind: String = _classify(full_path, text, move)
			if not kind.is_empty():
				hits.append([at, kind])
		slots[index] = hits


	func _classify(full_path: String, text: String, move: Dictionary) -> String:
		if full_path.get_extension() == "tres":
			# Only an event sheet holds a path field the plugin wrote; a resource of the user's own that happens to
			# have a property of the same name is theirs and is left alone.
			if not skip.has(full_path) and refs.is_sheet_text(text) and refs.respelled(text, str(move["old"]), str(move["new"]), bool(move["folder"])) != text:
				return "sheet"
			return ""
		return "script" if CLAIM.source_of(full_path).is_empty() else ""


	func is_done() -> bool:
		return _finished or WorkerThreadPool.is_task_completed(task_id)


	## Waits for the worker when it is not done yet, then answers one {"sheets", "scripts"} per move.
	func finish() -> Array:
		if not _finished:
			WorkerThreadPool.wait_for_task_completion(task_id)
			_finished = true
		var out: Array = []
		for _move: Dictionary in moves:
			out.append({"sheets": [], "scripts": []})
		for index: int in range(files.size()):
			for hit: Array in (slots[index] as Array):
				(out[int(hit[0])][("sheets" if str(hit[1]) == "sheet" else "scripts")] as Array).append(files[index])
		return out


## Respells the moved path in each sheet file named. The file's bytes go into the backup ring first, so
## Tools > Sheet Backups can put it back. Returns how many files were written.
static func write_sheets(paths: Array, old_path: String, new_path: String, is_folder: bool) -> int:
	var written: int = 0
	for path: String in paths:
		var text: String = FileAccess.get_file_as_string(path)
		var spelled: String = respelled(text, old_path, new_path, is_folder)
		if spelled == text:
			continue
		EventSheetBackups.backup_sheet(path)
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			continue
		file.store_string(spelled)
		file.close()
		written += 1
	return written


## The one quiet sentence about the user's own scripts that still name the old path, or "" when none do.
static func leftover_sentence(count: int) -> String:
	if count <= 0:
		return ""
	return EventSheetL10n.translate("Scripts of yours that still name the old path: %d. Tools > Find in Project lists them.") % count


## True when the text of a .tres is an event sheet: its first lines name the sheet class or its script, as
## the export pass reads them.
static func is_sheet_text(text: String) -> bool:
	var head: String = text.left(600)
	return head.contains("EventSheetResource") or head.contains("event_sheet.gd")
