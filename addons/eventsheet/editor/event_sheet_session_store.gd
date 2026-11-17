@tool
class_name EventSheetSessionStore
extends RefCounted
# Session restore: the open tabs survive an editor restart (user://eventsheets_session.cfg;
# eventsheets/editor/restore_session, default on). Extracted from event_sheet_dock.gd; the tab/sheet
# state it reads (_open_tabs, _active_tab_index, _current_sheet) and the load / activate / banner /
# status services it calls all stay on the dock, reached through the _dock back-reference. The dock keeps
# thin _persist_session / _restore_session delegates for its internal callers (startup, tab edits, the
# "Edit Events" unlock) and the session tests.

const SESSION_PATH := "user://eventsheets_session.cfg"

## The most tabs a restart brings back. A session saved with a hundred tabs open would otherwise spend the
## start of the editor opening a hundred sheets one after another; twenty is more than anyone reads at once,
## and the rest are one Recent click away. The tab the person was on is always among them.
const RESTORE_LIMIT := 20

var _dock: Control = null
# Persisting starts only after restore() has run: the dock's own startup (demo tab activation) would
# otherwise clobber the saved session before it's read.
var _session_tracking: bool = false


func init(dock: Control) -> void:
	_dock = dock


## Saved-tab paths + the active index. Unsaved sheets (no path) are skipped - there's no file to reopen.
func persist() -> void:
	if not _session_tracking:
		return
	_dock._sync_active_tab_state()
	var paths: PackedStringArray = PackedStringArray()
	# Paths the user has unlocked for editing (clicked "Edit Events" on a .gd preview), so a sheet
	# they were editing comes back editable next restart instead of re-locked as a preview.
	var editable_paths: PackedStringArray = PackedStringArray()
	var active_in_saved: int = -1
	var seen: Dictionary = {}
	for index in _dock._open_tabs.size():
		var tab_path: String = str(_dock._open_tabs[index].get("path", ""))
		if tab_path.is_empty():
			continue
		# One file is one saved tab, however many tabs hold it: the same file written six times came back
		# as six tabs.
		var key: String = same_file_key(tab_path)
		if seen.has(key):
			if index == _dock._active_tab_index:
				active_in_saved = int(seen[key])
			continue
		seen[key] = paths.size()
		if index == _dock._active_tab_index:
			active_in_saved = paths.size()
		paths.append(tab_path)
		var tab_sheet: EventSheetResource = _dock._open_tabs[index].get("sheet") as EventSheetResource
		if tab_sheet != null and not tab_sheet.read_only:
			editable_paths.append(tab_path)
	var session: ConfigFile = ConfigFile.new()
	session.set_value("session", "paths", paths)
	session.set_value("session", "editable", editable_paths)
	session.set_value("session", "active", active_in_saved)
	if session.save(SESSION_PATH) != OK:
		push_warning("EventSheets: couldn't save the tab session to %s - open tabs won't restore next launch." % SESSION_PATH)


## What two spellings of one file have in common: the path with its `./` and `..` folded away.
static func same_file_key(path: String) -> String:
	return path.simplify_path()


## The file of the tab in front, as `same_file_key` spells it ("" when it has none).
func _front_path() -> String:
	var index: int = _dock._active_tab_index
	if index < 0 or index >= _dock._open_tabs.size():
		return ""
	var tab_path: String = str(_dock._open_tabs[index].get("path", ""))
	return same_file_key(tab_path) if not tab_path.is_empty() else ""


## `paths` with each file once, in the order first seen, and the place `active` (an index into `paths`, or
## -1) has in the answer.
static func unique_paths(paths: PackedStringArray, active: int = -1) -> Dictionary:
	var kept: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	var active_at: int = -1
	for index: int in range(paths.size()):
		var key: String = same_file_key(paths[index])
		if not seen.has(key):
			seen[key] = kept.size()
			kept.append(paths[index])
		if index == active:
			active_at = int(seen[key])
	return {"paths": kept, "active": active_at}


## At most `limit` of the saved tabs, in their order, the active one always among them. Returns the same
## shape as `unique_paths`: the chosen paths and where the active one is in them.
static func capped(paths: PackedStringArray, active: int, limit: int = RESTORE_LIMIT) -> Dictionary:
	if paths.size() <= limit or limit <= 0:
		return {"paths": paths, "active": active}
	var chosen: PackedStringArray = paths.slice(0, limit)
	var active_at: int = active
	if active >= limit and active < paths.size():
		# The tab the person was on takes the last place, so it is open even though it was saved late.
		chosen[limit - 1] = paths[active]
		active_at = limit - 1
	return {"paths": chosen, "active": active_at if active_at < chosen.size() else -1}


## Returns once the dock has no script being read in the background (at once when none is, which is
## always the case in a headless run that joins the read itself).
func _wait_for_open_job() -> void:
	while is_instance_valid(_dock) and _dock.is_inside_tree() and _dock._sheet_io != null \
			and _dock._sheet_io.get("_open_job") != null:
		await _dock.get_tree().process_frame


## Reopens last session's tabs (missing files skipped silently - a deleted sheet shouldn't block
## startup), then turns persistence on.
func restore() -> void:
	# Setting off = sessions fully dormant (no restore, no writes); the last saved session survives
	# untouched for whenever it's re-enabled.
	if not bool(ProjectSettings.get_setting("eventsheets/editor/restore_session", true)):
		return
	var session: ConfigFile = ConfigFile.new()
	if session.load(SESSION_PATH) == OK:
		var saved_paths: PackedStringArray = PackedStringArray(session.get_value("session", "paths", PackedStringArray()))
		var editable_paths: PackedStringArray = PackedStringArray(session.get_value("session", "editable", PackedStringArray()))
		# A session written by an older version may name one file many times: each file opens once, and a
		# very long session brings back only its first tabs (and always the one that was in front).
		var unique: Dictionary = unique_paths(saved_paths, int(session.get_value("session", "active", -1)))
		var limited: Dictionary = capped(unique["paths"] as PackedStringArray, int(unique["active"]))
		var paths: PackedStringArray = limited["paths"] as PackedStringArray
		var active: int = int(limited["active"])
		var dropped: int = (unique["paths"] as PackedStringArray).size() - paths.size()
		var opened: int = 0
		# Whatever was in front when the restore began, and each tab it opens in turn: when the sheet in
		# front is none of those, the person opened something themselves while this was still working, and
		# the tab they chose is not taken away at the end.
		var in_front: String = _front_path()
		var person_chose: bool = false
		for sheet_path: String in paths:
			if FileAccess.file_exists(sheet_path):
				if _front_path() != in_front:
					person_chose = true
				_dock._load_sheet_from_path(sheet_path)
				in_front = _front_path()
				opened += 1
				# Restore the prior "Edit Events" unlock so the sheet isn't re-locked on restart -
				# but never over a file a merge left markers in. The block is a fact of the file as
				# it is NOW, and an unlock remembered from before the merge must not reopen it.
				if sheet_path in editable_paths and _dock._current_sheet != null \
						and _dock._current_sheet.read_only \
						and not _dock._current_sheet.blocked_by_conflict():
					_dock._current_sheet.read_only = false
					_dock._preview_glue._refresh_preview_banner()
				# A script's events are read by a background job, and opening the next script drops the
				# job still running (the newer open wins). Restoring several tabs back to back therefore
				# left every tab but the last one as raw function blocks for good; each is let finish
				# before the next opens, so a restored tab reads exactly as a freshly opened one does.
				await _wait_for_open_job()
		if not is_instance_valid(_dock):
			return
		if _front_path() != in_front:
			person_chose = true
		if not person_chose and active >= 0 and active < paths.size():
			var active_path: String = paths[active]
			for index in _dock._open_tabs.size():
				if str(_dock._open_tabs[index].get("path", "")) == active_path:
					_dock._activate_tab(index)
					break
		if opened > 0:
			_dock._set_status("Session restored: %d sheet(s)." % opened if dropped <= 0 \
				else "Session restored: %d sheet(s); %d more were open last time and are not reopened." % [opened, dropped])
	_session_tracking = true
	persist()
