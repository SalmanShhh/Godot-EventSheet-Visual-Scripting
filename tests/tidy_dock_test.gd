# Godot EventSheets - Tidy this script, driven through the dock.
#
# The window plans on a copy and shows the lines before anything is written; Apply is ONE undo step through
# the funnel, then the ordinary save, which takes the ordinary backup of the file first. Undo puts the old
# spelling back in the sheet, a second Tidy says so plainly, and nothing is written by merely opening the
# window or by cancelling it.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SCRIPT_TEST := preload("res://tests/tidy_script_test.gd")
const P := "tidy_dock_test"


static func run() -> bool:
	var ok: bool = true
	ok = _test_apply_is_one_undo_step_and_a_normal_save(ok)
	ok = _test_nothing_to_tidy_says_so(ok)
	ok = _test_a_sheet_that_moved_under_the_window_is_not_written(ok)
	ok = _test_the_menu_has_the_entry(ok)
	return ok


static func _open(text: String, name: String) -> Array:
	var path: String = SUPPORT.own_path(name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var dock: EventSheetEditor = EventSheetEditor.new()
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock._load_sheet_from_path(path)
	return [dock, path]


static func _status(dock: EventSheetEditor) -> String:
	return str(dock._status_label.text).replace("⚠  ", "")


static func _test_apply_is_one_undo_step_and_a_normal_save(ok: bool) -> bool:
	var opened: Array = _open(SCRIPT_TEST.TWO_HASH, "tidy_dock_words.gd")
	var dock: EventSheetEditor = opened[0]
	var path: String = opened[1]
	dock.open_tidy_dialog()
	var plan: Dictionary = dock._tidy_dialog._plan
	ok = SUPPORT.check(P, "the window opens on the plan: eight lines, none left out",
		[(plan["changes"] as Array).size(), int(plan["left"])], [8, 0]) and ok
	ok = SUPPORT.check(P, "opening the window writes nothing", FileAccess.get_file_as_string(path), SCRIPT_TEST.TWO_HASH) and ok
	ok = SUPPORT.check(P, "the summary counts the lines and says one step undoes them",
		dock._tidy_dialog.summary_text(plan), "8 lines would be rewritten in one step you can undo.") and ok
	var backups_before: int = EventSheetBackups.list_backups(path).size()
	dock._tidy_dialog.confirm()
	ok = SUPPORT.check(P, "Apply writes the tidied file through the ordinary save",
		FileAccess.get_file_as_string(path), SCRIPT_TEST.ONE_HASH) and ok
	ok = SUPPORT.check(P, "and the save took the ordinary backup of the old file first",
		EventSheetBackups.list_backups(path).size() > backups_before, true) and ok
	ok = SUPPORT.check(P, "the status line says how many lines were tidied",
		_status(dock), "8 lines tidied and saved. Undo puts the sheet back; the old file is in the sheet backups.") and ok
	dock._undo_redo_adapter.undo()
	ok = SUPPORT.check(P, "ONE undo puts the old spelling back in the sheet",
		SUPPORT.compile_output(dock._current_sheet, path.replace("tidy_dock_words", "tidy_dock_words_probe")), SCRIPT_TEST.TWO_HASH) and ok
	ok = SUPPORT.check(P, "the sheet is the two-hash sheet again", dock._current_sheet.annotation_spelling, "##") and ok
	dock._undo_redo_adapter.redo()
	ok = SUPPORT.check(P, "and redo brings the tidy back",
		SUPPORT.compile_output(dock._current_sheet, path.replace("tidy_dock_words", "tidy_dock_words_probe")), SCRIPT_TEST.ONE_HASH) and ok
	_forget_backups(path)
	dock.free()
	return ok


## The ordinary save keeps backups in the shared user folder; a test takes its own away again.
static func _forget_backups(path: String) -> void:
	for backup: String in EventSheetBackups.list_backups(path):
		DirAccess.remove_absolute(backup)
	DirAccess.remove_absolute(EventSheetBackups.backup_dir_for(path))
	# Only an empty folder can be removed, so backups that are somebody's own are never touched.
	DirAccess.remove_absolute(EventSheetBackups.BACKUPS_ROOT)


static func _test_nothing_to_tidy_says_so(ok: bool) -> bool:
	var opened: Array = _open(SCRIPT_TEST.TIDIED, "tidy_dock_none.gd")
	var dock: EventSheetEditor = opened[0]
	dock.open_tidy_dialog()
	ok = SUPPORT.check(P, "a script with nothing to tidy says so plainly", _status(dock), "Nothing to tidy.") and ok
	ok = SUPPORT.check(P, "and opens no window", dock._tidy_dialog._dialog == null, true) and ok
	dock.free()
	var again: Array = _open(SCRIPT_TEST.OLD_FORM, "tidy_dock_twice.gd")
	var second: EventSheetEditor = again[0]
	second.open_tidy_dialog()
	second._tidy_dialog.confirm()
	ok = SUPPORT.check(P, "the fold lands in the saved file", FileAccess.get_file_as_string(again[1]), SCRIPT_TEST.TIDIED) and ok
	second.open_tidy_dialog()
	ok = SUPPORT.check(P, "a second Tidy of the same sheet is a no-op and says so", _status(second), "Nothing to tidy.") and ok
	_forget_backups(again[1])
	second.free()
	return ok


static func _test_a_sheet_that_moved_under_the_window_is_not_written(ok: bool) -> bool:
	var opened: Array = _open(SCRIPT_TEST.OLD_FORM, "tidy_dock_moved.gd")
	var dock: EventSheetEditor = opened[0]
	dock.open_tidy_dialog()
	# The reader edits the sheet while the window is open: the guard's number changes.
	for entry: Variant in dock._current_sheet.events:
		if entry is EventRow:
			for condition: Variant in (entry as EventRow).conditions:
				if condition is ACECondition and (condition as ACECondition).params.has("seconds"):
					(condition as ACECondition).params["seconds"] = "3.0"
	dock._current_sheet.annotation_spelling = "##"
	var before_file: String = FileAccess.get_file_as_string(opened[1])
	dock._tidy_dialog.confirm()
	ok = SUPPORT.check(P, "a plan that no longer matches the sheet writes nothing", FileAccess.get_file_as_string(opened[1]), before_file) and ok
	ok = SUPPORT.check(P, "and the reader is told why they are reading it again", _status(dock),
		"This sheet changed while the window was open, so nothing was written - here is what it says now.") and ok
	_forget_backups(opened[1])
	dock.free()
	return ok


static func _test_the_menu_has_the_entry(ok: bool) -> bool:
	var dock: EventSheetEditor = EventSheetEditor.new()
	var found: bool = false
	for popup: Node in dock.find_children("EventSheetSheetMenu", "PopupMenu", true, false):
		for index: int in (popup as PopupMenu).item_count:
			if (popup as PopupMenu).get_item_id(index) == 28:
				found = (popup as PopupMenu).get_item_text(index) == "Tidy This Script…"
	ok = SUPPORT.check(P, "Sheet has Tidy This Script after Name Raw Calls", found, true) and ok
	dock.free()
	return ok
