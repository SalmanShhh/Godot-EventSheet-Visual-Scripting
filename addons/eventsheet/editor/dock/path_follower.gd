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

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


## The path `path` becomes when `old_path` moves to `new_path`: a file maps only itself, a folder maps
## everything under it. `path` itself when nothing moved it.
static func mapped(path: String, old_path: String, new_path: String, is_folder: bool) -> String:
	if path.is_empty() or old_path.is_empty():
		return path
	var key: String = path.simplify_path()
	if is_folder:
		var from: String = old_path.simplify_path().trim_suffix("/") + "/"
		if key.begins_with(from):
			return new_path.simplify_path().trim_suffix("/") + "/" + key.trim_prefix(from)
		return path
	return new_path.simplify_path() if key == old_path.simplify_path() else path


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
	if followed == 0:
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
	_dock._refresh_tab_bar()
	_dock._refresh_title_strip()
	_rebuild_views(changed_tabs)
	_dock._persist_session()
	if followed == 1:
		_dock._set_status(EventSheetL10n.translate("The open sheet follows %s to its new place.") % last_name)
	else:
		_dock._set_status(EventSheetL10n.translate("%d open sheets follow their files to their new place.") % followed)
	if not is_folder:
		_note_left_behind_script(old_path, new_path)
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


## A sheet saved as a resource writes its script beside it, named for the sheet. Renaming only the sheet
## leaves that script under the old name, and scenes keep running it while the next Save writes a new one
## under the new name - so the reader is told, once, to rename the script too.
func _note_left_behind_script(old_path: String, new_path: String) -> void:
	if old_path.get_extension() != "tres":
		return
	var old_script: String = old_path.get_basename() + "_generated.gd"
	var new_script: String = new_path.get_basename() + "_generated.gd"
	if FileAccess.file_exists(old_script) and not FileAccess.file_exists(new_script):
		_dock._set_status_notice(EventSheetL10n.translate("The sheet was renamed but its script %s was not. Rename the script too, or scenes keep running the old one.") % old_script.get_file())


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
