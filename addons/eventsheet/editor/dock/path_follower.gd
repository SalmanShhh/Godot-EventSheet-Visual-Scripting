@tool
extends RefCounted

# Keeps the open sheet tabs honest about their files when the files move without the editor's own say.
# The FileSystem dock renames, moves and deletes files (and whole folders) behind an open tab, and a tab
# that kept the old path used to write to it on the next Save: the old file came back beside the renamed
# one, the scene kept using the renamed one, and the edits went to a file nothing used.
#
# This does what Godot's own script editor does:
#   * a RENAME or MOVE retargets the tab - the unsaved edits and the undo history stay, and the tab,
#     the saved session, the recently-closed list and the backup ring all follow to the new path;
#   * a DELETE closes a tab with nothing unsaved, quietly; a tab with unsaved edits stays open with
#     those edits, a copy of them goes into the backup ring, and the tab lets go of the dead path so a
#     Save asks where to write instead of recreating the old file.
#
# One walk over the OPEN tabs per event, never over the project: a folder move carrying many open sheets
# is one pass and one session write. Loaded by path from the dock's thin delegates, so the editor's boot
# path never carries it. The known-sheets record has its own follower (known_sheets.gd); this one is
# about what is open on screen.

## Where a path ends up when a file or folder moves, one rule for the tabs and the project's indexes.
const MOVED_PATH: GDScript = preload("res://addons/eventforge/importer/moved_path.gd")

var _dock: Control = null
## Moves waiting for the next read of the project's files, the read in flight, and the last status sentence
## said before the files' own sentence arrives.
var _queued_moves: Array = []
var _read_scheduled: bool = false
var _read_running: bool = false
var _last_head: String = ""
var _last_head_was_notice: bool = false


func init(dock: Control) -> void:
	_dock = dock


## The path `path` becomes when `old_path` moves to `new_path`: a file maps only itself, a folder maps
## everything under it. `path` itself when nothing moved it.
static func mapped(path: String, old_path: String, new_path: String, is_folder: bool) -> String:
	return MOVED_PATH.mapped(path, old_path, new_path, is_folder)


## True when `path` is the removed file, or lies under the removed folder.
static func is_removed(path: String, removed: String, is_folder: bool) -> bool:
	if path.is_empty() or removed.is_empty():
		return false
	var key: String = path.simplify_path()
	if is_folder:
		return key.begins_with(removed.simplify_path().trim_suffix("/") + "/")
	return key == removed.simplify_path()


## Whether a tab's path names a real file that could be gone: a built-in resource inside a scene
## ("scene.tscn::Sub_1") and an unsaved sheet (no path) have no file of their own to lose.
static func names_a_file(path: String) -> bool:
	if path.is_empty() or path.contains("::"):
		return false
	return path.begins_with("res://") or path.begins_with("user://")


## One entry for the dock's single delegate: the kind of change and the path(s) it names.
func handle(event: String, first: String, second: String) -> int:
	match event:
		"moved":
			return file_moved(first, second)
		"folder_moved":
			return folder_moved(first, second)
		"removed":
			return file_removed(first)
		"folder_removed":
			return folder_removed(first)
		"missing":
			return check_missing()
	return 0


## A file moved or renamed. Returns how many tabs followed it.
func file_moved(old_path: String, new_path: String) -> int:
	return _retarget(old_path, new_path, false)


## A folder moved or renamed: every open tab under it follows.
func folder_moved(old_folder: String, new_folder: String) -> int:
	return _retarget(old_folder, new_folder, true)


## A file deleted. Returns how many tabs it touched (closed or let go of the path).
func file_removed(path: String) -> int:
	return _remove(func(candidate: String) -> bool: return is_removed(candidate, path, false))


func folder_removed(folder: String) -> int:
	return _remove(func(candidate: String) -> bool: return is_removed(candidate, folder, true))


## The editor's file list changed (an import, a rescan, a change made outside Godot): any open tab whose
## file is no longer there is treated as deleted. A walk over the open tabs and one lookup each.
func check_missing() -> int:
	return _remove(func(candidate: String) -> bool:
		return names_a_file(candidate) and not FileAccess.file_exists(candidate))


# ── Rename and move ──────────────────────────────────────────────────────────


func _retarget(old_path: String, new_path: String, is_folder: bool) -> int:
	if _dock == null or old_path.is_empty() or new_path.is_empty() or old_path == new_path:
		return 0
	_dock._sync_active_tab_state()
	# The project's two scene indexes follow the move in place, whether or not a tab is open on the file:
	# they are the same entries under their new names, so nothing is read and no frame waits for the project.
	EventSheetViewportRowBuilder.note_path_moved(old_path, new_path, is_folder)
	EventSheetSceneConnections.note_path_moved(old_path, new_path, is_folder)
	var script_fate: Dictionary = {} if is_folder else _follow_generated_script(old_path, new_path)
	var followed: int = 0
	var last_name: String = ""
	var pairs: Array = []
	var changed_tabs: Array[Dictionary] = []
	for tab: Dictionary in _dock._open_tabs:
		var moved_from: String = str(tab.get("path", ""))
		var sheet: EventSheetResource = tab.get("sheet") as EventSheetResource
		var tab_to: String = mapped(moved_from, old_path, new_path, is_folder)
		var source_to: String = mapped(sheet.external_source_path, old_path, new_path, is_folder) if sheet != null else ""
		var resource_to: String = mapped(sheet.resource_path, old_path, new_path, is_folder) if sheet != null else ""
		var changed: bool = tab_to != moved_from
		if sheet != null:
			changed = changed or source_to != sheet.external_source_path or resource_to != sheet.resource_path
		if not changed:
			continue
		followed += 1
		changed_tabs.append(tab)
		if sheet != null:
			if source_to != sheet.external_source_path:
				sheet.external_source_path = source_to
			if resource_to != sheet.resource_path:
				sheet.take_over_path(resource_to)
		tab["path"] = tab_to
		tab["mtime"] = FileAccess.get_modified_time(tab_to) if FileAccess.file_exists(tab_to) else 0
		last_name = tab_to.get_file()
		if moved_from != tab_to and not moved_from.is_empty():
			pairs.append([moved_from, tab_to])
	var tail: String = _follow_references(old_path, new_path, is_folder)
	if followed == 0:
		_last_head = ""
		if not _say_script_fate(script_fate, "", tail) and not tail.is_empty():
			_dock._set_status(tail)
		return 0
	var active: int = _dock._active_tab_index
	if active >= 0 and active < _dock._open_tabs.size():
		var front: Dictionary = _dock._open_tabs[active]
		_dock._current_sheet_path = str(front.get("path", ""))
		_dock._external_mtime = int(front.get("mtime", _dock._external_mtime))
	# Anything else keyed by the old path follows too.
	for pair: Array in pairs:
		EventSheetBackups.follow(str(pair[0]), str(pair[1]))
		var at: int = _dock._recent_closed_paths.find(str(pair[0]))
		if at >= 0:
			_dock._recent_closed_paths[at] = str(pair[1])
	# A tab's title can be the name of the scene object the script sits on; the index of the scenes followed
	# the move above, so the followed tab is named by the same rule as one opened now. The editor rewrites
	# those scenes for the new path a moment later and then reports its files changed, which is when the
	# dock has the index read again off the main thread.
	_dock._refresh_tab_bar()
	_dock._refresh_title_strip()
	_rebuild_views(changed_tabs)
	_dock._persist_session()
	if followed == 1:
		if not _say_script_fate(script_fate, last_name, tail):
			_say_head(EventSheetL10n.translate("The open sheet follows %s to its new place.") % last_name, tail)
	else:
		_say_head(EventSheetL10n.translate("%d open sheets follow their files to their new place.") % followed, tail)
	return followed


## The reading a tab holds names its file in the head band, so a tab whose file changed reads again: the
## tab in front rebuilds its rows the way any edit does (the undo history is the editor's and stays), the
## others drop the reading they were holding and rebuild when they are shown.
func _rebuild_views(tabs: Array[Dictionary]) -> void:
	var front: int = _dock._active_tab_index
	var rebuild_front: bool = false
	for index: int in range(_dock._open_tabs.size()):
		if not tabs.has(_dock._open_tabs[index]):
			continue
		if index == front:
			rebuild_front = true
		else:
			_dock._tab_state.invalidate(index)
	if rebuild_front:
		_dock._refresh_after_edit()


# ── A resource sheet's script follows it ─────────────────────────────────────

## The proof that a script is the compiler's own output for a sheet lives in one place, shared with the
## compiler's own write (it must never write over a script it cannot prove it made).
const CLAIM: GDScript = preload("res://addons/eventforge/compiler/generated_script_claim.gd")
## The script a resource sheet compiles to is named for the sheet, and sits beside it.
const SCRIPT_SUFFIX: String = CLAIM.SCRIPT_SUFFIX


## True when `script_path` is a script the compiler wrote for the sheet at `sheet_path`. A hand-written
## script that merely shares the name never passes.
static func is_output_of(script_path: String, sheet_path: String) -> bool:
	return CLAIM.is_output_of(script_path, sheet_path)


## A sheet saved as a resource writes its script beside it, named for the sheet. When only the sheet is
## renamed or moved, the script goes with it - its uid file too, so scenes that hold the script keep finding
## it - but only when it is provably this sheet's own output and the new name is free. Anything else is left
## exactly where it was. {"moved": the script's new path, "left": the old script's file name}; both empty
## when the sheet has no script of this kind.
func _follow_generated_script(old_path: String, new_path: String) -> Dictionary:
	var fate: Dictionary = {"moved": "", "left": ""}
	if old_path.get_extension() != "tres" or new_path.get_extension() != "tres":
		return fate
	# The two scripts a resource sheet writes beside itself: the generated one, and the plain one the Run,
	# Reload and Enable plugin buttons write. Either is carried along only when it is provably this sheet's.
	for suffix: String in [SCRIPT_SUFFIX, ".gd"]:
		var old_script: String = old_path.get_basename() + suffix
		var new_script: String = new_path.get_basename() + suffix
		if old_script == new_script or not is_output_of(old_script, old_path):
			continue
		if FileAccess.file_exists(new_script) or FileAccess.file_exists(new_script + ".uid") or not _move_script_pair(old_script, new_script):
			if str(fate["left"]).is_empty():
				fate["left"] = old_script.get_file()
			continue
		_after_script_moved(old_script, new_script, old_path, new_path)
		if str(fate["moved"]).is_empty():
			fate["moved"] = new_script
	return fate


## The script and its uid file, together or not at all.
func _move_script_pair(old_script: String, new_script: String) -> bool:
	var from: String = ProjectSettings.globalize_path(old_script)
	var to: String = ProjectSettings.globalize_path(new_script)
	if DirAccess.rename_absolute(from, to) != OK:
		return false
	if FileAccess.file_exists(old_script + ".uid") and DirAccess.rename_absolute(from + ".uid", to + ".uid") != OK:
		DirAccess.rename_absolute(to, from)
		return false
	return true


## What the editor and the scenes need to hear once the script has moved: its uid now answers to the new
## place, a script already loaded (a scene open in the editor holds it) takes the new path so saving that
## scene writes the new one, the header's "# Source:" line names the renamed sheet, and the file list rescans.
func _after_script_moved(old_script: String, new_script: String, old_sheet: String, new_sheet: String) -> void:
	var id: int = ResourceUID.text_to_id(FileAccess.get_file_as_string(new_script + ".uid").strip_edges())
	if id != ResourceUID.INVALID_ID and ResourceUID.has_id(id):
		ResourceUID.set_id(id, new_script)
	if ResourceLoader.has_cached(old_script):
		var loaded: Resource = ResourceLoader.load(old_script, "", ResourceLoader.CACHE_MODE_REUSE)
		if loaded != null:
			loaded.take_over_path(new_script)
	var text: String = FileAccess.get_file_as_string(new_script)
	var line: String = "
# Source: %s
" % old_sheet
	var at: int = text.find(line)
	if at >= 0:
		var file: FileAccess = FileAccess.open(new_script, FileAccess.WRITE)
		if file != null:
			file.store_string(text.substr(0, at) + "
# Source: %s
" % new_sheet + text.substr(at + line.length()))
			file.close()
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		_refresh_open_script_tab()
		EditorInterface.get_resource_filesystem().scan.call_deferred()


## A script open in Godot's own script editor keeps showing the text it was opened with, so after the header
## was respelled it still named the old sheet, and saving that tab would have written the old line back.
## Godot's script editor has its own way to read open files again (the one it runs when the editor window
## is focused): it reloads a tab whose file changed on disk, and asks the reader first when that tab holds
## edits of theirs. It is asked once the rename has settled.
func _refresh_open_script_tab() -> void:
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	if script_editor != null:
		script_editor.reload_open_files.call_deferred()


## Says what became of a renamed resource sheet's script in one quiet sentence. `sheet_name` is the open
## sheet's new file name, or empty when no tab follows it. Returns whether a sentence was said.
func _say_script_fate(fate: Dictionary, sheet_name: String, tail: String = "") -> bool:
	var moved: String = str(fate.get("moved", ""))
	var left: String = str(fate.get("left", ""))
	if not moved.is_empty():
		if sheet_name.is_empty():
			_say_head(EventSheetL10n.translate("The script %s followed its sheet to its new place.") % moved.get_file(), tail)
		else:
			_say_head(EventSheetL10n.translate("The open sheet follows %s to its new place, and its script %s goes with it.") % [sheet_name, moved.get_file()], tail)
		return true
	if not left.is_empty():
		_say_head(EventSheetL10n.translate("The sheet was renamed but its script %s was not. Rename the script too, or scenes keep running the old one.") % left, tail, true)
		return true
	return false


## Two sentences on one status line, or the first alone when there is no second.
static func _joined(first: String, second: String) -> String:
	return first if second.is_empty() else "%s %s" % [first, second]


## What else the plugin wrote down about the moved file follows it (path_references.gd): the editor's memory
## of the file, the paths in the open sheets and in the sheet files that are not open. Returns the sentence
## to add to the status line: the sheets that followed, and how many of the user's own scripts still name
## the old path. "" when there is nothing to say, and also when the project's files are still being read:
## inside a running editor that read happens off the main thread and the sentence arrives on the status line
## when it ends (several moves in one moment share one read of the project).
func _follow_references(old_path: String, new_path: String, is_folder: bool) -> String:
	var extension: String = old_path.get_extension()
	if not is_folder and extension != "gd" and extension != "tres":
		return ""
	var references: GDScript = load("res://addons/eventsheet/editor/dock/path_references.gd")
	references.follow_editor_memory(old_path, new_path, is_folder)
	var followed_sheets: int = 0
	var open_paths: PackedStringArray = PackedStringArray()
	for tab: Dictionary in _dock._open_tabs:
		open_paths.append(str(tab.get("path", "")))
		var tab_sheet: EventSheetResource = tab.get("sheet") as EventSheetResource
		# A sheet read from a script keeps these lists in memory only (the file holds none of them), so
		# following them there is not an edit the reader has to save.
		if references.follow_in_sheet(tab_sheet, old_path, new_path, is_folder) > 0 and tab_sheet.external_source_path.is_empty():
			tab["dirty"] = true
			followed_sheets += 1
			if _dock._active_tab_index >= 0 and _dock._open_tabs[_dock._active_tab_index] == tab:
				_dock._dirty = true
	# The project's files are only read for a path inside the project: nothing in it can name another place.
	if not old_path.begins_with("res://"):
		return _reference_sentence(followed_sheets, 0)
	var move: Dictionary = {"old": old_path, "new": new_path, "folder": is_folder}
	if not _dock.is_inside_tree():
		var found: Dictionary = references.scan(old_path, new_path, is_folder, open_paths)
		followed_sheets += references.write_sheets(found["sheets"], old_path, new_path, is_folder)
		return _reference_sentence(followed_sheets, (found["scripts"] as Array).size())
	_queued_moves.append({"move": move, "open": open_paths, "followed": followed_sheets})
	if not _read_scheduled:
		_read_scheduled = true
		_start_read.call_deferred()
	return ""


## The two sentences about what followed: the sheets that name the old path, and the user's own scripts
## that still do.
func _reference_sentence(followed_sheets: int, script_count: int) -> String:
	var sentences: PackedStringArray = PackedStringArray()
	if followed_sheets > 0:
		sentences.append(EventSheetL10n.translate("%d sheet(s) that name it follow it too.") % followed_sheets)
	var references: GDScript = load("res://addons/eventsheet/editor/dock/path_references.gd")
	var leftover: String = references.leftover_sentence(script_count)
	if not leftover.is_empty():
		sentences.append(leftover)
	return " ".join(sentences)


## Starts one read of the project for every move queued so far (the FileSystem dock reports a selection of
## many files as many moves in the same moment).
func _start_read() -> void:
	_read_scheduled = false
	if _queued_moves.is_empty() or _read_running or not is_instance_valid(_dock):
		return
	var batch: Array = _queued_moves
	_queued_moves = []
	var moves: Array = []
	var skip: PackedStringArray = PackedStringArray()
	for entry: Dictionary in batch:
		moves.append(entry["move"])
		skip.append_array(entry["open"] as PackedStringArray)
	var references: GDScript = load("res://addons/eventsheet/editor/dock/path_references.gd")
	moves = chained(moves)
	_read_running = true
	_finish_read(references, references.begin_scan(moves, skip), batch, moves)


## The moves of one batch with each one's destination followed through the moves after it, so a file moved
## from A to B and then from B to C is carried to C by the sheets that named A (the files are read once, after
## both moves, and a sheet respelled to B would be left naming a path that is no longer there). The move out of
## B stays in the list for the sheets that named B. Moves that do not meet are returned as they were.
static func chained(moves: Array) -> Array:
	var followed: Array = []
	for at: int in range(moves.size()):
		var move: Dictionary = (moves[at] as Dictionary).duplicate()
		for later: int in range(at + 1, moves.size()):
			var next: Dictionary = moves[later]
			var destination: String = str(move["new"])
			# A folder the later move carries away is that folder itself, which `mapped` leaves alone (it maps
			# what lies under a folder), so the destination that IS the folder is named here.
			if bool(next["folder"]) and destination.simplify_path() == str(next["old"]).simplify_path():
				destination = str(next["new"])
			else:
				destination = mapped(destination, str(next["old"]), str(next["new"]), bool(next["folder"]))
			move["new"] = destination
		followed.append(move)
	return followed


func _finish_read(references: GDScript, job: Object, batch: Array, moves: Array) -> void:
	while is_instance_valid(_dock) and _dock.is_inside_tree() and not job.is_done():
		await _dock.get_tree().process_frame
	var results: Array = job.finish()
	_read_running = false
	if not is_instance_valid(_dock):
		return
	var followed_sheets: int = 0
	var script_paths: Dictionary = {}
	for index: int in range(batch.size()):
		var move: Dictionary = moves[index]
		followed_sheets += int(batch[index]["followed"])
		var sheets: Array = results[index]["sheets"]
		# A sheet opened while the files were being read holds the old spelling in memory: it follows in
		# memory like any open sheet, and its file is left for its own Save.
		for tab: Dictionary in _dock._open_tabs:
			if sheets.has(str(tab.get("path", ""))):
				sheets.erase(str(tab.get("path", "")))
				var tab_sheet: EventSheetResource = tab.get("sheet") as EventSheetResource
				if references.follow_in_sheet(tab_sheet, str(move["old"]), str(move["new"]), bool(move["folder"])) > 0:
					tab["dirty"] = true
		followed_sheets += references.write_sheets(sheets, str(move["old"]), str(move["new"]), bool(move["folder"]))
		for script_path: Variant in results[index]["scripts"]:
			script_paths[script_path] = true
	var tail: String = _reference_sentence(followed_sheets, script_paths.size())
	if not tail.is_empty():
		_say_tail(tail)
	if not _queued_moves.is_empty():
		_start_read()


## Says a sentence with the files' own sentence after it, and remembers it, so a files' sentence that arrives
## later can be put after it.
func _say_head(head: String, tail: String, notice: bool = false) -> void:
	_last_head = head
	_last_head_was_notice = notice
	if notice:
		_dock._set_status_notice(_joined(head, tail))
	else:
		_dock._set_status(_joined(head, tail))


## Puts the sentence that arrived late on the status line: after the sentence it belongs to when that is
## still showing, alone when something else has replaced it.
func _say_tail(tail: String) -> void:
	var label: Label = _dock._status_label
	if _last_head.is_empty() or label == null or not label.text.ends_with(_last_head):
		_dock._set_status(tail)
	elif _last_head_was_notice:
		_dock._set_status_notice(_joined(_last_head, tail))
	else:
		_dock._set_status(_joined(_last_head, tail))


# ── Delete ───────────────────────────────────────────────────────────────────


func _remove(gone: Callable) -> int:
	if _dock == null or _dock._open_tabs.is_empty():
		return 0
	# Cheap first: nothing open lies on a removed path, so nothing is synced, closed or written.
	var hit: bool = false
	for tab: Dictionary in _dock._open_tabs:
		if _tab_is_gone(tab, gone):
			hit = true
			break
	if not hit:
		return 0
	_dock._sync_active_tab_state()
	var front_id: String = _dock._tab_state.active_tab_id()
	var kept: Array[Dictionary] = []
	var closed: int = 0
	var rescued: int = 0
	var rescued_name: String = ""
	var rescued_tabs: Array[Dictionary] = []
	var closed_front: bool = false
	var front_index: int = _dock._active_tab_index
	var kept_before_front: int = 0
	for index: int in range(_dock._open_tabs.size()):
		var tab: Dictionary = _dock._open_tabs[index]
		if not _tab_is_gone(tab, gone):
			kept.append(tab)
			if index < front_index:
				kept_before_front += 1
			continue
		var sheet: EventSheetResource = tab.get("sheet") as EventSheetResource
		if bool(tab.get("dirty", false)) and sheet != null:
			# Unsaved edits are the user's work: the tab stays, a copy goes into the backup ring while the
			# old path still names the ring, and the tab lets go of the file so Save asks where to write.
			var old_file: String = str(tab.get("path", ""))
			_dock._external_watcher.keep_sheet_in_backups(sheet, old_file if not old_file.is_empty() else sheet.external_source_path)
			sheet.gone_file_path = old_file if not old_file.is_empty() else sheet.external_source_path
			sheet.external_source_path = ""
			if not sheet.resource_path.is_empty():
				sheet.resource_path = ""
			tab["path"] = ""
			tab["mtime"] = 0
			rescued += 1
			rescued_tabs.append(tab)
			rescued_name = old_file.get_file()
			kept.append(tab)
			if index < front_index:
				kept_before_front += 1
		else:
			closed += 1
			if str(tab.get("id", "")) == front_id and not front_id.is_empty():
				closed_front = true
	if closed == 0 and rescued == 0:
		return 0
	_dock._open_tabs.assign(kept)
	if closed > 0:
		_dock._active_tab_index = -1
		if kept.is_empty():
			_dock.setup(null)
		elif closed_front:
			_dock._activate_tab(mini(kept_before_front, kept.size() - 1))
		else:
			_dock._active_tab_index = _dock._tab_state.index_of_tab_id(front_id)
			if _dock._active_tab_index < 0:
				_dock._activate_tab(0)
	elif _dock._active_tab_index >= 0 and _dock._active_tab_index < _dock._open_tabs.size():
		var front: Dictionary = _dock._open_tabs[_dock._active_tab_index]
		_dock._current_sheet_path = str(front.get("path", ""))
		_dock._external_mtime = int(front.get("mtime", 0))
	_forget_dead_recents()
	_dock._refresh_tab_bar()
	_dock._refresh_title_strip()
	_rebuild_views(rescued_tabs)
	_dock._persist_session()
	if rescued > 0:
		_dock._set_status_notice(EventSheetL10n.translate("%s is gone, but your unsaved changes are still here. Save As keeps them in a new file.") % rescued_name)
	elif closed == 1:
		_dock._set_status(EventSheetL10n.translate("A sheet's file was deleted, so its tab was closed."))
	else:
		_dock._set_status(EventSheetL10n.translate("%d sheets' files were deleted, so their tabs were closed.") % closed)
	return closed + rescued


func _tab_is_gone(tab: Dictionary, gone: Callable) -> bool:
	var tab_path: String = str(tab.get("path", ""))
	if not tab_path.is_empty():
		return bool(gone.call(tab_path))
	return false


## The recently-closed list offers to reopen a file: a deleted one is not offered.
func _forget_dead_recents() -> void:
	var live: Array[String] = []
	for path: String in _dock._recent_closed_paths:
		if not names_a_file(path) or FileAccess.file_exists(path):
			live.append(path)
	_dock._recent_closed_paths = live
