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

var _dock: Control = null
# Persisting starts only after restore() has run: the dock's own startup (demo tab activation) would
# otherwise clobber the saved session before it's read.
var _session_tracking: bool = false


func init(dock: Control) -> void:
	_dock = dock


## Saved-tab paths + the active index. Unsaved sheets (no path) are skipped — there's no file to reopen.
func persist() -> void:
	if not _session_tracking:
		return
	_dock._sync_active_tab_state()
	var paths: PackedStringArray = PackedStringArray()
	# Paths the user has unlocked for editing (clicked "Edit Events" on a .gd preview), so a sheet
	# they were editing comes back editable next restart instead of re-locked as a preview.
	var editable_paths: PackedStringArray = PackedStringArray()
	var active_in_saved: int = -1
	for index in _dock._open_tabs.size():
		var tab_path: String = str(_dock._open_tabs[index].get("path", ""))
		if tab_path.is_empty():
			continue
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
	session.save(SESSION_PATH)


## Reopens last session's tabs (missing files skipped silently — a deleted sheet shouldn't block
## startup), then turns persistence on.
func restore() -> void:
	# Setting off = sessions fully dormant (no restore, no writes); the last saved session survives
	# untouched for whenever it's re-enabled.
	if not bool(ProjectSettings.get_setting("eventsheets/editor/restore_session", true)):
		return
	var session: ConfigFile = ConfigFile.new()
	if session.load(SESSION_PATH) == OK:
		var paths: PackedStringArray = PackedStringArray(session.get_value("session", "paths", PackedStringArray()))
		var editable_paths: PackedStringArray = PackedStringArray(session.get_value("session", "editable", PackedStringArray()))
		var active: int = int(session.get_value("session", "active", -1))
		var opened: int = 0
		for sheet_path: String in paths:
			if FileAccess.file_exists(sheet_path):
				_dock._load_sheet_from_path(sheet_path)
				opened += 1
				# Restore the prior "Edit Events" unlock so the sheet isn't re-locked on restart.
				if sheet_path in editable_paths and _dock._current_sheet != null and _dock._current_sheet.read_only:
					_dock._current_sheet.read_only = false
					_dock._refresh_preview_banner()
		if active >= 0 and active < paths.size():
			var active_path: String = paths[active]
			for index in _dock._open_tabs.size():
				if str(_dock._open_tabs[index].get("path", "")) == active_path:
					_dock._activate_tab(index)
					break
		if opened > 0:
			_dock._set_status("Session restored: %d sheet(s)." % opened)
	_session_tracking = true
	persist()
