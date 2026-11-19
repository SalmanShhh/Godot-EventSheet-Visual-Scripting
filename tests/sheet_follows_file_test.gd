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
	# The backup rings this test makes live in its own folder, so a run leaves nothing in the shared one.
	EventSheetBackups.root_override = SUPPORT.own_folder("follow_backups")
	var passed: bool = _all()
	EventSheetBackups.root_override = ""
	return passed


static func _all() -> bool:
	var passed: bool = _pure_rows()
	passed = _rename_keeps_the_tab_and_its_edits() and passed
	passed = _folder_move_carries_every_tab_under_it() and passed
	passed = _delete_closes_clean_tabs_and_keeps_unsaved_work() and passed
	passed = _file_gone_outside_godot() and passed
	passed = _resource_sheet_follows() and passed
	passed = _backup_ring_follows() and passed
	passed = _known_sheets_funnel_tells_the_dock() and passed
	passed = _save_after_the_file_vanished() and passed
	passed = _gone_file_notice_is_a_quiet_amber_that_stays() and passed
	passed = _resource_sheet_script_follows_a_rename() and passed
	passed = _resource_sheet_script_follows_a_move_and_a_second_rename() and passed
	passed = _resource_sheet_script_is_left_alone_when_it_cannot_follow() and passed
	passed = _the_plain_script_beside_a_sheet_follows_too() and passed
	passed = _a_followed_tab_is_named_by_the_rule_a_fresh_one_is() and passed
	passed = _what_the_plugin_wrote_down_follows_the_file() and passed
	passed = _a_batch_of_moves_reads_the_project_once_and_answers_each_alone() and passed
	passed = _a_file_moved_twice_in_one_batch_is_followed_to_its_last_place() and passed
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
		["the head bar keeps the name the work had", EventSheetViewportRowBuilder.head_bar_name(dirty_sheet), "dirty.gd"],
		["the head's name band keeps it too", EventSheetHeadBands.facts(dirty_sheet, "").get("file_name"), "dirty.gd"],
		["the tab keeps the name", EventSheetDock._format_sheet_title(dirty_sheet, ""), "dirty"],
		["the path hint still says there is no file", EventSheetDock._format_sheet_path_hint(dirty_sheet, ""), "Unsaved (in-memory)"],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(EventSheetBackups.backups_root()))


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


## The sentence that says a file is gone but the edits are still here is a notice, not a failure: no red,
## no warning sign in front of it, its own amber font colour, and it never fades. The next ordinary
## message takes the ordinary colour back.
static func _gone_file_notice_is_a_quiet_amber_that_stays() -> bool:
	var editor: EventSheetEditor = _editor()
	var path: String = SUPPORT.own_path("follow_notice/notice_probe.gd")
	_open_script_sheet(editor, path, true)
	DirAccess.remove_absolute(path)
	editor.follow_file_event("removed", path)
	var label: Label = editor._status_label
	var said: String = label.text if label != null else "(no status label)"
	var painted: bool = label != null and label.has_theme_color_override("font_color")
	var faded: bool = editor._status_fade_tween != null
	var alpha: float = label.modulate.a if label != null else 0.0
	var tint: Color = label.modulate if label != null else Color.BLACK
	editor._set_status("Saved.")
	var ordinary_again: bool = label != null and not label.has_theme_color_override("font_color")
	_drop_ring(path)
	editor.free()
	return SUPPORT.pins(TEST_NAME, [
		["the sentence says what is gone and what is kept", said.begins_with("notice_probe.gd is gone, but your unsaved changes are still here."), true],
		["no warning sign leads it", said.begins_with("⚠"), false],
		["it has a font colour of its own", painted, true],
		["it is not the error red", tint == EventSheetActiveTheme.chrome().status_error_color, false],
		["it is at full strength", alpha, 1.0],
		["nothing is set to fade it", faded, false],
		["the next ordinary message takes the ordinary colour back", ordinary_again, true],
	])


## A resource sheet saved to `path` and compiled the way a Save compiles it: its script beside it, with the
## compiler's own header, a uid file, and the script loaded (so it is cached, as a scene holds it).
static func _compiled_resource_sheet(path: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	var comment: CommentRow = CommentRow.new()
	comment.text = "saved row"
	sheet.events.append(comment)
	ResourceSaver.save(sheet, path)
	var loaded: EventSheetResource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource
	loaded.take_over_path(path)
	EventSheetCompiler.compile(loaded, "")
	var script: String = path.get_basename() + "_generated.gd"
	var id: int = ResourceUID.create_id()
	ResourceUID.add_id(id, script)
	_write(script + ".uid", ResourceUID.id_to_text(id) + "\n")
	return loaded


static func _uid_of(script: String) -> int:
	return ResourceUID.text_to_id(FileAccess.get_file_as_string(script + ".uid").strip_edges())


static func _generated_files(folder: String) -> Array:
	var found: Array = []
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with("_generated.gd"):
			found.append(file)
	found.sort()
	return found


static func _forget_uid(id: int) -> void:
	if ResourceUID.has_id(id):
		ResourceUID.remove_id(id)


## Renaming only a resource sheet carries the script it compiled with it: the file, its uid file, the
## header that names the sheet, the uid's place, and the script a scene already holds. Nothing is left
## under the old name, and the next Save writes into the one script instead of making a second.
static func _resource_sheet_script_follows_a_rename() -> bool:
	var editor: EventSheetEditor = _editor()
	var old_path: String = SUPPORT.own_path("follow_script_rename/probe.tres")
	var new_path: String = SUPPORT.own_path("follow_script_rename/probe_renamed.tres")
	var old_script: String = old_path.get_basename() + "_generated.gd"
	var new_script: String = new_path.get_basename() + "_generated.gd"
	var sheet: EventSheetResource = _compiled_resource_sheet(old_path)
	var held: GDScript = load(old_script) as GDScript
	var uid: int = _uid_of(old_script)
	var body: String = FileAccess.get_file_as_string(old_script)
	editor._open_sheet_in_tab(sheet, old_path)
	DirAccess.rename_absolute(old_path, new_path)
	editor.follow_file_event("moved", old_path, new_path)
	var said: String = editor._status_label.text
	var moved_body: String = FileAccess.get_file_as_string(new_script)
	EventSheetCompiler.compile(sheet, "")
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["the script is under the new name", FileAccess.file_exists(new_script), true],
		["nothing is left under the old name", FileAccess.file_exists(old_script), false],
		["its uid file went with it", FileAccess.file_exists(new_script + ".uid"), true],
		["no uid file is left behind", FileAccess.file_exists(old_script + ".uid"), false],
		["the uid is the same one", _uid_of(new_script), uid],
		["the uid now answers to the new place", ResourceUID.get_id_path(uid), new_script],
		["the header names the renamed sheet", moved_body.contains("\n# Source: %s\n" % new_path), true],
		["the rest of the script is untouched", moved_body.replace(new_path, old_path), body],
		["a script a scene holds takes the new path", held.resource_path, new_script],
		["the status says the script went with the sheet", said, "The open sheet follows probe_renamed.tres to its new place, and its script probe_renamed_generated.gd goes with it."],
		["Save writes into the one script", _generated_files(new_path.get_base_dir()), ["probe_renamed_generated.gd"]],
	])
	_forget_uid(uid)
	editor.free()
	return passed


## A move to another folder takes the script there too, and a second rename straight after still finds the
## script provably the sheet's (the first one rewrote the header). With no tab open the sentence names the
## script alone.
static func _resource_sheet_script_follows_a_move_and_a_second_rename() -> bool:
	var editor: EventSheetEditor = _editor()
	var first: String = SUPPORT.own_path("follow_script_move/a/probe.tres")
	var second: String = SUPPORT.own_path("follow_script_move/b/probe.tres")
	var third: String = SUPPORT.own_path("follow_script_move/b/probe_again.tres")
	_compiled_resource_sheet(first)
	var uid: int = _uid_of(first.get_basename() + "_generated.gd")
	DirAccess.make_dir_recursive_absolute(second.get_base_dir())
	DirAccess.rename_absolute(first, second)
	editor.follow_file_event("moved", first, second)
	var after_move: bool = FileAccess.file_exists(second.get_basename() + "_generated.gd")
	var said: String = editor._status_label.text
	DirAccess.rename_absolute(second, third)
	editor.follow_file_event("moved", second, third)
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["the script moved to the other folder", after_move, true],
		["with no tab open the sentence names the script", said, "The script probe_generated.gd followed its sheet to its new place."],
		["the old folder holds no script", _generated_files(first.get_base_dir()), []],
		["a second rename moves it again", _generated_files(third.get_base_dir()), ["probe_again_generated.gd"]],
		["the uid is still the same one", _uid_of(third.get_basename() + "_generated.gd"), uid],
	])
	_forget_uid(uid)
	editor.free()
	return passed


## A script that is not provably the sheet's own output, a new name that is taken, and a folder move
## (which carries both files itself) all leave every file exactly where it is.
static func _resource_sheet_script_is_left_alone_when_it_cannot_follow() -> bool:
	var editor: EventSheetEditor = _editor()
	var by_hand: String = SUPPORT.own_path("follow_script_alone/hand/probe.tres")
	var by_hand_script: String = by_hand.get_basename() + "_generated.gd"
	ResourceSaver.save(EventSheetResource.new(), by_hand)
	_write(by_hand_script, "extends Node\n\n\nfunc _ready() -> void:\n\tpass\n")
	var by_hand_new: String = by_hand.get_base_dir() + "/probe_renamed.tres"
	DirAccess.rename_absolute(by_hand, by_hand_new)
	editor.follow_file_event("moved", by_hand, by_hand_new)
	var hand_said: String = editor._status_label.text

	var taken: String = SUPPORT.own_path("follow_script_alone/taken/probe.tres")
	var taken_new: String = taken.get_base_dir() + "/probe_renamed.tres"
	_compiled_resource_sheet(taken)
	var taken_script: String = taken.get_basename() + "_generated.gd"
	var taken_text: String = FileAccess.get_file_as_string(taken_script)
	var occupant: String = taken_new.get_basename() + "_generated.gd"
	_write(occupant, "extends Node\n# not the sheet's\n")
	DirAccess.rename_absolute(taken, taken_new)
	editor.follow_file_event("moved", taken, taken_new)
	var taken_said: String = editor._status_label.text

	var folder: String = SUPPORT.own_folder("follow_script_alone/folder")
	var inside: String = folder + "/probe.tres"
	_compiled_resource_sheet(inside)
	var inside_script: String = inside.get_basename() + "_generated.gd"
	editor.follow_file_event("folder_moved", folder, folder + "_elsewhere")
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["a hand-written script of that name stays", FileAccess.get_file_as_string(by_hand_script).begins_with("extends Node"), true],
		["and nothing is said about it", hand_said.contains("script"), false],
		["a taken new name leaves the old script where it was", FileAccess.get_file_as_string(taken_script), taken_text],
		["and leaves the other file's words as they were", FileAccess.get_file_as_string(occupant), "extends Node\n# not the sheet's\n"],
		["the sentence names the script left behind", taken_said.begins_with("The sheet was renamed but its script probe_generated.gd was not."), true],
		["that sentence is a quiet notice, not an error", taken_said.begins_with("⚠"), false],
		["a folder move event moves no script by itself", FileAccess.file_exists(inside_script), true],
	])
	editor.free()
	return passed


## The plain `<name>.gd` the Run, Reload and Enable plugin buttons write is the plugin's own output when its
## header names the sheet, so it goes with the sheet; a hand-written one of that name stays where it is.
static func _the_plain_script_beside_a_sheet_follows_too() -> bool:
	var editor: EventSheetEditor = _editor()
	var old_path: String = SUPPORT.own_path("follow_plain/door.tres")
	var new_path: String = SUPPORT.own_path("follow_plain/gate.tres")
	var sheet: EventSheetResource = _compiled_resource_sheet(old_path)
	var plain: String = old_path.get_basename() + ".gd"
	EventSheetCompiler.compile(sheet, plain)
	var mine: String = old_path.get_basename() + "_generated.gd"
	var other_old: String = SUPPORT.own_path("follow_plain_hand/door.tres")
	_compiled_resource_sheet(other_old)
	var hand: String = other_old.get_basename() + ".gd"
	_write(hand, "extends Node\n# written by hand\n")
	editor._open_sheet_in_tab(sheet, old_path)
	DirAccess.rename_absolute(old_path, new_path)
	editor.follow_file_event("moved", old_path, new_path)
	var other_new: String = SUPPORT.own_path("follow_plain_hand/gate.tres")
	DirAccess.rename_absolute(other_old, other_new)
	editor.follow_file_event("moved", other_old, other_new)
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["the plain script followed the sheet", FileAccess.file_exists(new_path.get_basename() + ".gd"), true],
		["nothing of it is left under the old name", FileAccess.file_exists(plain), false],
		["its header names the renamed sheet", FileAccess.get_file_as_string(new_path.get_basename() + ".gd").contains("\n# Source: %s\n" % new_path), true],
		["the generated script followed as before", FileAccess.file_exists(new_path.get_basename() + "_generated.gd") and not FileAccess.file_exists(mine), true],
		["a hand-written script of the sheet's name stays", FileAccess.get_file_as_string(hand), "extends Node\n# written by hand\n"],
	])
	_forget_uid(_uid_of(new_path.get_basename() + "_generated.gd") if FileAccess.file_exists(new_path.get_basename() + "_generated.gd.uid") else -1)
	editor.free()
	return passed


## A script with no class_name is named after the scene object it drives, which is read from an index of the
## project's scene files. A rename follows in that index at once, in place: the followed tab is named for the
## scene object the way a tab opened now is, without the index being read from every scene in the project
## while the frame waits (the editor rewrites those scenes a moment later and has the index read again).
static func _a_followed_tab_is_named_by_the_rule_a_fresh_one_is() -> bool:
	var editor: EventSheetEditor = _editor()
	var folder: String = SUPPORT.own_folder("follow_title")
	var old_path: String = _write(folder + "/hero.gd")
	var new_path: String = folder + "/hero_brain.gd"
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = old_path
	editor._open_sheet_in_tab(sheet, old_path)
	# An index built before the rename: a scene whose root is the script, and no scene for any other.
	var entry: Dictionary = {"scene_path": "res://scenes/hero_scene.tscn", "root_name": "Hero"}
	EventSheetViewportRowBuilder._script_scene_all = {old_path: [entry]}
	EventSheetViewportRowBuilder._script_scene_cache = {old_path: entry}
	EventSheetViewportRowBuilder._script_scene_scanned = true
	var named_before: String = EventSheetDock._format_sheet_title(sheet, old_path)
	DirAccess.rename_absolute(old_path, new_path)
	editor.follow_file_event("moved", old_path, new_path)
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["the tab was named for the scene object before the rename", named_before, "Hero"],
		["a followed tab is named for it still", EventSheetDock._format_sheet_title(sheet, new_path), "Hero"],
		["the index holds the scene under the new path", EventSheetViewportRowBuilder.scene_using_script(new_path), entry],
		["and nothing under the old", EventSheetViewportRowBuilder.scene_using_script(old_path), {}],
	])
	EventSheetViewportRowBuilder.clear_scene_script_index()
	editor.free()
	return passed


## The things the plugin itself wrote a file's path into follow it: the editor's memory keyed by the path,
## the sheets a sheet includes (open and on disk), and the user's own scripts are counted, never rewritten.
static func _what_the_plugin_wrote_down_follows_the_file() -> bool:
	var refs: GDScript = load("res://addons/eventsheet/editor/dock/path_references.gd")
	var rekeyed: Dictionary = refs.rekeyed({"res://a/x.gd": 2, "res://b/y.gd": 3, "res://a/z.gd": 4}, "res://a/x.gd", "res://a/x2.gd", false)
	var folder_rekeyed: Dictionary = refs.rekeyed({"res://a/x.gd": 2, "res://ab/y.gd": 3}, "res://a", "res://c", true)
	var clash: Dictionary = refs.rekeyed({"res://a/x.gd": 2, "res://a/x2.gd": 9}, "res://a/x.gd", "res://a/x2.gd", false)
	var lines: String = "[resource]\nincludes = Array[String]([\"res://a/x.tres\", \"res://a/y.tres\"])\nace_provider_scripts = Array[String]([\"res://a/x.tres\"])\nnote = \"res://a/x.tres\"\n"
	var respelled: String = refs.respelled(lines, "res://a/x.tres", "res://a/w.tres", false)
	var folder_respelled: String = refs.respelled(lines, "res://a", "res://c", true)
	var in_memory: EventSheetResource = EventSheetResource.new()
	in_memory.includes = ["res://a/x.tres", "res://a/y.tres"]
	in_memory.ace_provider_scripts = ["res://a/p.gd"]
	in_memory.custom_class_icon = "res://a/i.svg"
	var changed_in_memory: int = refs.follow_in_sheet(in_memory, "res://a", "res://b", true)
	# Files on disk: a sheet that includes the renamed one, a script that preloads it, a script the plugin
	# compiled (never the user's), and an open sheet that is skipped.
	var root: String = SUPPORT.own_folder("follow_refs")
	var sheet_head: String = "[gd_resource type=\"Resource\" script_class=\"EventSheetResource\" format=3]\n\n[resource]\n"
	var includer: String = _write(root + "/includer.tres", sheet_head + "includes = Array[String]([\"res://lib/door.tres\"])\n")
	var open_one: String = _write(root + "/open_one.tres", sheet_head + "includes = Array[String]([\"res://lib/door.tres\"])\n")
	# A resource of the user's own with a property of the same name is theirs, not a sheet.
	var other_text: String = "[gd_resource type=\"Resource\" script_class=\"Loadout\" format=3]\n\n[resource]\nincludes = Array[String]([\"res://lib/door.tres\"])\n"
	var other_kind: String = _write(root + "/loadout.tres", other_text)
	var user_script: String = _write(root + "/user.gd", "extends Node\nconst Door := preload(\"res://lib/door.tres\")\n")
	var compiled: String = _write(root + "/made.gd", "# AUTO-GENERATED by EventForge v0.20.0\n# Source: res://lib/door.tres\nextends Node\n")
	var found: Dictionary = refs.scan("res://lib/door.tres", "res://lib/gate.tres", false, PackedStringArray([open_one]), root)
	var written: int = refs.write_sheets(found["sheets"], "res://lib/door.tres", "res://lib/gate.tres", false)
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["a key under the moved file follows it", rekeyed, {"res://a/x2.gd": 2, "res://b/y.gd": 3, "res://a/z.gd": 4}],
		["a folder carries every key under it, and not a sibling that shares the prefix", folder_rekeyed, {"res://c/x.gd": 2, "res://ab/y.gd": 3}],
		["a key never lands on one that exists", clash, {"res://a/x.gd": 2, "res://a/x2.gd": 9}],
		["a sheet's path fields are respelled and nothing else", respelled, lines.replace("[\"res://a/x.tres\", \"res://a/y.tres\"]", "[\"res://a/w.tres\", \"res://a/y.tres\"]").replace("Array[String]([\"res://a/x.tres\"])", "Array[String]([\"res://a/w.tres\"])")],
		["a moved folder respells the paths under it", folder_respelled.contains("\"res://c/x.tres\", \"res://c/y.tres\"") and folder_respelled.contains("note = \"res://a/x.tres\""), true],
		["an open sheet follows in memory", changed_in_memory, 4],
		["and holds the new paths", [in_memory.includes[0], in_memory.ace_provider_scripts[0], in_memory.custom_class_icon], ["res://b/x.tres", "res://b/p.gd", "res://b/i.svg"]],
		["a sheet file that is not open is found", found["sheets"], [includer]],
		["a script of the user's that names the old path is counted", found["scripts"], [user_script]],
		["a script the plugin compiled is not the user's", (found["scripts"] as Array).has(compiled), false],
		["one sheet file was written", written, 1],
		["it names the new place", FileAccess.get_file_as_string(includer), sheet_head + "includes = Array[String]([\"res://lib/gate.tres\"])\n"],
		["a resource of another kind is not found and is not written", [(found["sheets"] as Array).has(other_kind), FileAccess.get_file_as_string(other_kind)], [false, other_text]],
		["the user's script was not touched", FileAccess.get_file_as_string(user_script), "extends Node\nconst Door := preload(\"res://lib/door.tres\")\n"],
		["the open sheet's file was not touched", FileAccess.get_file_as_string(open_one), sheet_head + "includes = Array[String]([\"res://lib/door.tres\"])\n"],
		["nothing to say when no script names it", refs.leftover_sentence(0), ""],
		["one sentence says how many scripts still name it and where to look", refs.leftover_sentence(2), "Scripts of yours that still name the old path: 2. Tools > Find in Project lists them."],
	])
	_drop_ring(includer)
	return passed


## Several moves reported in one moment share one read of the project's files, and each is answered exactly
## as if it had been asked alone (the same files, in the same order), on worker threads or not.
static func _a_batch_of_moves_reads_the_project_once_and_answers_each_alone() -> bool:
	var refs: GDScript = load("res://addons/eventsheet/editor/dock/path_references.gd")
	var root: String = SUPPORT.own_folder("follow_batch")
	var sheet_head: String = "[gd_resource type=\"Resource\" script_class=\"EventSheetResource\" format=3]

[resource]
"
	for index: int in range(40):
		_write("%s/part_%02d.gd" % [root, index], "extends Node
" + ("const A := preload(\"res://lib/%02d.tres\")
" % index if index % 7 == 0 else "var x: int = %d
" % index))
	var includer: String = _write(root + "/includer.tres", sheet_head + "includes = Array[String]([\"res://lib/00.tres\", \"res://lib/03.tres\"])
")
	var elsewhere: String = _write(root + "/elsewhere.tres", sheet_head + "includes = Array[String]([\"res://lib/03.tres\"])
")
	var moves: Array = [
		{"old": "res://lib/00.tres", "new": "res://lib/zero.tres", "folder": false},
		{"old": "res://lib/03.tres", "new": "res://lib/three.tres", "folder": false},
		{"old": "res://lib/14.tres", "new": "res://lib/fourteen.tres", "folder": false},
		{"old": "res://lib/none.tres", "new": "res://lib/nothing.tres", "folder": false},
		{"old": "res://lib", "new": "res://moved", "folder": true},
	]
	var skip: PackedStringArray = PackedStringArray([elsewhere])
	var together: Array = refs.begin_scan(moves, skip, root).finish()
	var alone: Array = []
	for move: Dictionary in moves:
		alone.append(refs.scan(move["old"], move["new"], move["folder"], skip, root))
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["every move in a batch is answered as if asked alone", together, alone],
		["a move that names a script and a sheet finds both", [(together[0]["sheets"] as Array).size(), (together[0]["scripts"] as Array).size()], [1, 1]],
		["a move nothing names finds nothing", together[3], {"sheets": [], "scripts": []}],
		["a folder move finds every file naming a path under it", [(together[4]["sheets"] as Array).size(), (together[4]["scripts"] as Array).size()], [1, 6]],
		["an open sheet is never listed", (together[1]["sheets"] as Array).has(elsewhere), false],
		["the shared start of the needles", refs.needles_in_common(PackedStringArray(["res://lib/00.tres", "res://lib/03.tres"])), "res://lib/0"],
		["no needles share nothing", refs.needles_in_common(PackedStringArray()), ""],
	])
	return passed


## A file moved from A to B and then from B to C in the same moment: the project is read once, after both
## moves, so a sheet naming A has to be carried to C, not left naming B (a path nothing is at any more).
static func _a_file_moved_twice_in_one_batch_is_followed_to_its_last_place() -> bool:
	var refs: GDScript = load("res://addons/eventsheet/editor/dock/path_references.gd")
	var root: String = SUPPORT.own_folder("follow_chain")
	var sheet_head: String = "[gd_resource type=\"Resource\" script_class=\"EventSheetResource\" format=3]\n\n[resource]\n"
	var names_a: String = _write(root + "/names_a.tres", sheet_head + "includes = Array[String]([\"res://lib/a.tres\"])\n")
	var names_b: String = _write(root + "/names_b.tres", sheet_head + "includes = Array[String]([\"res://lib/b.tres\"])\n")
	var moves: Array = [
		{"old": "res://lib/a.tres", "new": "res://lib/b.tres", "folder": false},
		{"old": "res://lib/b.tres", "new": "res://lib/c.tres", "folder": false},
	]
	var carried: Array = FOLLOWER.chained(moves)
	var found: Array = refs.begin_scan(carried, PackedStringArray(), root).finish()
	for at: int in range(carried.size()):
		refs.write_sheets(found[at]["sheets"], str(carried[at]["old"]), str(carried[at]["new"]), bool(carried[at]["folder"]))
	var folder_chain: Array = FOLLOWER.chained([
		{"old": "res://a", "new": "res://b", "folder": true},
		{"old": "res://b", "new": "res://c", "folder": true},
		{"old": "res://c/x.gd", "new": "res://c/y.gd", "folder": false},
	])
	return SUPPORT.pins(TEST_NAME, [
		["the first move is carried to the last place the file went", [carried[0]["old"], carried[0]["new"]], ["res://lib/a.tres", "res://lib/c.tres"]],
		["the second move stays for the sheets that named the middle", [carried[1]["old"], carried[1]["new"]], ["res://lib/b.tres", "res://lib/c.tres"]],
		["moves that never meet are left as they were", FOLLOWER.chained([moves[0], {"old": "res://x.gd", "new": "res://y.gd", "folder": false}])[0]["new"], "res://lib/b.tres"],
		["the moves passed in are not changed", moves[0]["new"], "res://lib/b.tres"],
		["a sheet that named the first path names the last", FileAccess.get_file_as_string(names_a), sheet_head + "includes = Array[String]([\"res://lib/c.tres\"])\n"],
		["a sheet that named the middle path names the last", FileAccess.get_file_as_string(names_b), sheet_head + "includes = Array[String]([\"res://lib/c.tres\"])\n"],
		["a folder moved twice and a file in it renamed lands every move on its last place", [folder_chain[0]["new"], folder_chain[1]["new"], folder_chain[2]["new"]], ["res://c", "res://c", "res://c/y.gd"]],
	])
