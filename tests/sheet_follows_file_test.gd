# EventForge - an open sheet follows its file when the FileSystem dock renames, moves or deletes it.
#
# The editor used to keep the old path on the tab: after a rename the next Save wrote the OLD file back
# (two copies, the scene using the renamed one, the edits going to a file nothing used), and after a
# folder rename Save could not write at all. These pin what Godot's own script editor does instead: a
# rename or move retargets the tab with its unsaved edits, and a delete closes a clean tab but never
# loses unsaved work. The path-following funnel is driven directly with real files, because a test
# cannot reach the FileSystem dock.
@tool
class_name SheetFollowsFileTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "sheet_follows_file_test"
const FOLLOWER := preload("res://addons/eventsheet/editor/dock/path_follower.gd")


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
	var passed: bool = _pure_rows()
	passed = _rename_keeps_the_tab_and_its_edits() and passed
	passed = _folder_move_carries_every_tab_under_it() and passed
	passed = _delete_closes_clean_tabs_and_keeps_unsaved_work() and passed
	passed = _file_gone_outside_godot() and passed
	passed = _resource_sheet_follows() and passed
	passed = _backup_ring_follows() and passed
	passed = _known_sheets_funnel_tells_the_dock() and passed
	passed = _save_after_the_file_vanished() and passed
	return passed


static func _pure_rows() -> bool:
	return SUPPORT.pins(TEST_NAME, [
		["a file maps itself", FOLLOWER.mapped("res://a/x.gd", "res://a/x.gd", "res://a/y.gd", false), "res://a/y.gd"],
		["a file maps no other file", FOLLOWER.mapped("res://a/z.gd", "res://a/x.gd", "res://a/y.gd", false), "res://a/z.gd"],
		["a folder maps what is under it", FOLLOWER.mapped("res://a/x.gd", "res://a", "res://b/a", true), "res://b/a/x.gd"],
		["a folder maps deep paths", FOLLOWER.mapped("res://a/s/x.gd", "res://a/", "res://c/", true), "res://c/s/x.gd"],
		["a folder does not map a sibling with the same prefix", FOLLOWER.mapped("res://ab/x.gd", "res://a", "res://c", true), "res://ab/x.gd"],
		["a path with no file maps to itself", FOLLOWER.mapped("", "res://a", "res://c", true), ""],
		["a removed file is that file", FOLLOWER.is_removed("res://a/x.gd", "res://a/x.gd", false), true],
		["a removed folder holds its files", FOLLOWER.is_removed("res://a/x.gd", "res://a", true), true],
		["a removed folder does not hold a sibling", FOLLOWER.is_removed("res://ab/x.gd", "res://a", true), false],
		["an unsaved sheet names no file", FOLLOWER.names_a_file(""), false],
		["a built-in resource names no file", FOLLOWER.names_a_file("res://s.tscn::Sub_1"), false],
		["a project file names a file", FOLLOWER.names_a_file("res://a/x.gd"), true],
	])


static func _editor() -> EventSheetEditor:
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor.setup(EventSheetResource.new())
	# The blank first tab is not under test: start with no tabs so the indexes below are the sheets'.
	editor._open_tabs.clear()
	editor._active_tab_index = -1
	return editor


static func _write(path: String, text: String = "extends Node\n") -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


## A script sheet on a real file, open in a tab. `unsaved` adds a comment row that is not on disk.
static func _open_script_sheet(editor: EventSheetEditor, path: String, unsaved: bool) -> EventSheetResource:
	_write(path)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = path
	var comment: CommentRow = CommentRow.new()
	comment.text = "UNSAVED" if unsaved else "SAVED"
	sheet.events.append(comment)
	editor._open_sheet_in_tab(sheet, path)
	editor._dirty = unsaved
	editor._sync_active_tab_state()
	return sheet


static func _paths(editor: EventSheetEditor) -> Array:
	var paths: Array = []
	for tab: Dictionary in editor._open_tabs:
		paths.append(str(tab.get("path", "")))
	return paths


static func _rename_keeps_the_tab_and_its_edits() -> bool:
	var editor: EventSheetEditor = _editor()
	if not SUPPORT.pin_value(TEST_NAME, "the dock takes path events", editor.has_method("follow_file_event"), true):
		editor.free()
		return false
	var old_path: String = SUPPORT.own_path("follow_rename/probe_sheet.gd")
	var new_path: String = SUPPORT.own_path("follow_rename/probe_sheet_renamed.gd")
	var other_path: String = SUPPORT.own_path("follow_rename/other.gd")
	var sheet: EventSheetResource = _open_script_sheet(editor, old_path, true)
	var other: EventSheetResource = _open_script_sheet(editor, other_path, false)
	editor._activate_tab(0)
	DirAccess.rename_absolute(old_path, new_path)
	var followed: int = editor.follow_file_event("moved", old_path, new_path)
	var state: Dictionary = editor.get_open_sheets_state()
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["one tab followed", followed, 1],
		["the tab list names the new path", _paths(editor), [new_path, other_path]],
		["the sheet's own file is the new path", sheet.external_source_path, new_path],
		["the live path is the new path", editor._current_sheet_path, new_path],
		["the open-tabs state names the new path", str((state["open"] as Array)[0]["path"]), new_path],
		["the unsaved edit is still in the sheet", sheet.events.size(), 1],
		["the tab is still unsaved", editor._dirty, true],
		["the same tab is still in front", editor._current_sheet == sheet, true],
		["the other tab was not touched", other.external_source_path, other_path],
		["the old file is not recreated", FileAccess.file_exists(old_path), false],
		["a second event for the same move follows nothing", editor.follow_file_event("moved", old_path, new_path), 0],
	])
	editor.free()
	return passed


static func _folder_move_carries_every_tab_under_it() -> bool:
	var editor: EventSheetEditor = _editor()
	var folder: String = SUPPORT.own_folder("follow_folder/a")
	var target: String = SUPPORT.own_path("follow_folder/b")
	var inside: Array[String] = []
	for index: int in range(5):
		var path: String = "%s/sheet_%d.gd" % [folder, index]
		_open_script_sheet(editor, path, index == 2)
		inside.append(path)
	var outside: String = SUPPORT.own_path("follow_folder/outside.gd")
	_open_script_sheet(editor, outside, false)
	editor._activate_tab(2)
	DirAccess.make_dir_recursive_absolute(target)
	DirAccess.rename_absolute(folder, target + "/a")
	var followed: int = editor.follow_file_event("folder_moved", folder, target + "/a")
	var moved: Array = []
	for index: int in range(5):
		moved.append("%s/a/sheet_%d.gd" % [target, index])
	moved.append(outside)
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["every open tab under the folder followed", followed, 5],
		["the tab list names the new paths", _paths(editor), moved],
		["the tab in front kept its unsaved edit", editor._dirty, true],
		["the live path is under the new folder", editor._current_sheet_path, "%s/a/sheet_2.gd" % target],
		["the file outside the folder was left alone", (editor._open_tabs[5]["sheet"] as EventSheetResource).external_source_path, outside],
	])
	editor.free()
	return passed


static func _delete_closes_clean_tabs_and_keeps_unsaved_work() -> bool:
	var editor: EventSheetEditor = _editor()
	var clean_path: String = SUPPORT.own_path("follow_delete/clean.gd")
	var dirty_path: String = SUPPORT.own_path("follow_delete/dirty.gd")
	var keep_path: String = SUPPORT.own_path("follow_delete/keep.gd")
	_open_script_sheet(editor, clean_path, false)
	var dirty_sheet: EventSheetResource = _open_script_sheet(editor, dirty_path, true)
	_open_script_sheet(editor, keep_path, false)
	editor._activate_tab(2)
	DirAccess.remove_absolute(clean_path)
	var closed: int = editor.follow_file_event("removed", clean_path)
	var after_clean: Array = _paths(editor)
	var kept_front: bool = (editor._open_tabs[editor._active_tab_index]["sheet"] as EventSheetResource).external_source_path == keep_path
	DirAccess.remove_absolute(dirty_path)
	EventSheetBackups.backup_sheet(dirty_path)
	var touched: int = editor.follow_file_event("removed", dirty_path)
	var written: Dictionary = EventSheetCompiler.compile(dirty_sheet, "")
	var rings: PackedStringArray = EventSheetBackups.list_backups(dirty_path)
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["the clean tab was closed", closed, 1],
		["the others stayed", after_clean, [dirty_path, keep_path]],
		["the tab in front stayed in front", kept_front, true],
		["the unsaved tab was touched", touched, 1],
		["the unsaved tab is still open", _paths(editor).size(), 2],
		["the unsaved tab let go of the dead path", _paths(editor)[0], ""],
		["the sheet no longer names the dead file", dirty_sheet.external_source_path, ""],
		["the unsaved edit is still there", dirty_sheet.events.size(), 1],
		["the tab is still marked unsaved", bool(editor._open_tabs[0]["dirty"]), true],
		["a compile writes nothing at the dead path", FileAccess.file_exists(dirty_path), false],
		["the compile said it had no file to write", bool(written.get("success", false)) and not FileAccess.file_exists(dirty_path), true],
		["a copy of the unsaved work went into the backup ring", rings.size() >= 1, true],
	])
	_drop_ring(dirty_path)
	editor.free()
	return passed


static func _file_gone_outside_godot() -> bool:
	var editor: EventSheetEditor = _editor()
	var gone: String = SUPPORT.own_path("follow_outside/gone.gd")
	var here: String = SUPPORT.own_path("follow_outside/here.gd")
	_open_script_sheet(editor, gone, false)
	_open_script_sheet(editor, here, false)
	var nothing: int = editor.follow_file_event("missing")
	DirAccess.remove_absolute(gone)
	var closed: int = editor.follow_file_event("missing")
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["a file list change with every file present closes nothing", nothing, 0],
		["a file gone from disk closes its tab", closed, 1],
		["the other tab stays", _paths(editor), [here]],
	])
	editor.free()
	return passed


static func _resource_sheet_follows() -> bool:
	var editor: EventSheetEditor = _editor()
	var old_path: String = SUPPORT.own_path("follow_tres/probe.tres")
	var new_path: String = SUPPORT.own_path("follow_tres/probe_renamed.tres")
	var sheet: EventSheetResource = EventSheetResource.new()
	ResourceSaver.save(sheet, old_path)
	var loaded: EventSheetResource = ResourceLoader.load(old_path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource
	loaded.take_over_path(old_path)
	editor._open_sheet_in_tab(loaded, old_path)
	DirAccess.rename_absolute(old_path, new_path)
	editor.follow_file_event("moved", old_path, new_path)
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["a resource sheet's own path is the new path", loaded.resource_path, new_path],
		["a resource sheet's tab names the new path", _paths(editor), [new_path]],
		["the live path is the new path", editor._current_sheet_path, new_path],
		["the compile target follows the rename", EventSheetCompiler._resolve_output_path(loaded, ""), new_path.get_basename() + "_generated.gd"],
	])
	editor.free()
	return passed


static func _backup_ring_follows() -> bool:
	var old_path: String = SUPPORT.own_path("follow_ring/ring_probe_old.gd")
	var new_path: String = SUPPORT.own_path("follow_ring/ring_probe_new.gd")
	_write(old_path, "extends Node\n# one\n")
	var made: String = EventSheetBackups.backup_sheet(old_path)
	EventSheetBackups.follow(old_path, new_path)
	var rings: PackedStringArray = EventSheetBackups.list_backups(new_path)
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["the backup was made", made.is_empty(), false],
		["the old name has no ring left", EventSheetBackups.list_backups(old_path).size(), 0],
		["the new name holds the older save", rings.size(), 1],
	])
	_drop_ring(new_path)
	return passed


## Removes a file's backup ring folder, and the ring root when that leaves it empty, so the shared user
## folder is as it was.
static func _drop_ring(sheet_path: String) -> void:
	for ring: String in EventSheetBackups.list_backups(sheet_path):
		DirAccess.remove_absolute(ring)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(EventSheetBackups.backup_dir_for(sheet_path)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(EventSheetBackups.BACKUPS_ROOT))


## The FileSystem dock's events reach the open tabs through the known-sheets funnel the plugin already
## calls, so there is one place a rename is heard.
static func _known_sheets_funnel_tells_the_dock() -> bool:
	var known: GDScript = preload("res://addons/eventforge/known_sheets.gd")
	var editor: EventSheetEditor = _editor()
	var old_path: String = SUPPORT.own_path("follow_funnel/a.gd")
	var new_path: String = SUPPORT.own_path("follow_funnel/b.gd")
	var sheet: EventSheetResource = _open_script_sheet(editor, old_path, true)
	known.path_listener = editor.follow_file_event
	known.note_moved(old_path, new_path)
	known.path_listener = Callable()
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["the funnel the plugin calls retargets the open tab", sheet.external_source_path, new_path],
		["and the tab list follows", _paths(editor), [new_path]],
	])
	editor.free()
	return passed


## Save on a tab whose file vanished before any rescan said so writes nothing: the old file is never
## brought back, and the work stays open without a path.
static func _save_after_the_file_vanished() -> bool:
	var editor: EventSheetEditor = _editor()
	var path: String = SUPPORT.own_path("follow_save/vanished.gd")
	var sheet: EventSheetResource = _open_script_sheet(editor, path, true)
	editor._external_mtime = FileAccess.get_modified_time(path)
	DirAccess.remove_absolute(path)
	editor._sheet_io._on_save_requested()
	var came_back: bool = FileAccess.file_exists(path)
	if came_back:
		DirAccess.remove_absolute(path)
	_drop_ring(path)
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["Save does not bring a vanished file back", came_back, false],
		["the sheet let go of the dead path", sheet.external_source_path, ""],
		["the unsaved edit is still there", sheet.events.size(), 1],
	])
	editor.free()
	return passed
