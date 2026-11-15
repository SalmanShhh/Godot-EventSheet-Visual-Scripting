# EventSheets - a sheet saved as a resource (.tres) gets the "changed outside the editor" question a
# script sheet always had. A .tres changed by a merge or another tool, with the tab open and unsaved,
# was written over by the next Save; the backup ring kept the old bytes but nobody was asked.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "resource_sheet_watch_test"
const PATH := "user://resource_sheet_watch_probe.tres"


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass


static func run() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {"hp": {"type": "int", "default": 1, "exported": false}}
	ResourceSaver.save(sheet, PATH)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._load_sheet_from_path(PATH)
	var watcher: RefCounted = editor._external_watcher
	var rows: Array = [
		["the open .tres is the file the tab watches", watcher.watched_path(), PATH],
		["a freshly opened .tres is not 'changed'", watcher.sheet_changed_on_disk(), false],
	]
	# Another tool writes the file: new content, and a different stamp (mtime has whole-second grain).
	var other: EventSheetResource = EventSheetResource.new()
	other.variables = {"hp": {"type": "int", "default": 7, "exported": false}}
	ResourceSaver.save(other, PATH)
	editor._external_mtime = 1
	rows.append(["a change made outside is seen", watcher.sheet_changed_on_disk(), true])
	# With unsaved edits the question keeps them by default and says so.
	editor._dirty = true
	watcher.prompt_external_reload_if_changed()
	var dialog: ConfirmationDialog = watcher._external_reload_dialog
	rows.append(["the question is asked for the .tres", dialog != null and dialog.title.begins_with("resource_sheet_watch_probe.tres changed outside"), true])
	rows.append(["and keeps the edits by default", dialog.ok_button_text if dialog != null else "", "Keep mine"])
	# Taking the file on disk keeps this version in Sheet Backups first, then loads the disk one.
	for old_backup: String in EventSheetBackups.list_backups(PATH):
		DirAccess.remove_absolute(old_backup)
	editor._current_sheet.variables = {"hp": {"type": "int", "default": 99, "exported": false}}
	var taken: bool = watcher.use_file_on_disk()
	var kept: PackedStringArray = EventSheetBackups.list_backups(PATH)
	var hp: Variant = (editor._current_sheet.variables.get("hp", {}) as Dictionary).get("default", -1)
	rows.append_array([
		["taking the file on disk goes ahead", taken, true],
		["the version in the editor is kept in Sheet Backups first",
			FileAccess.get_file_as_string(kept[0]).contains("99") if not kept.is_empty() else "no backup", true],
		["the sheet now shows what is on disk", hp, 7],
		["and is no longer 'changed'", watcher.sheet_changed_on_disk(), false],
		["and is clean", editor._dirty, false],
	])
	editor.free()
	for made: String in EventSheetBackups.list_backups(PATH):
		DirAccess.remove_absolute(made)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	return SUPPORT.pins(P, rows)
