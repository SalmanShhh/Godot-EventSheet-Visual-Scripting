# Including a shared sheet in the open sheet is ONE undo step, like every other sheet edit. Adding the
# include from Add > Include sheet... changes the script's own file (its `extends` line, or a helper it keeps
# and forwards to); Ctrl+Z writes the file back exactly as it was, Ctrl+Shift+Z writes the include again,
# the sheet is saved after each so no step leaves it dirty, and the Include lines the head draws follow the
# file. Including a sheet from the Includes window (a sheet resource's own list) is one step too, and so is
# taking one off the list.
@tool
class_name IncludeUndoTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME: String = "include_undo_test"
const HELPER: String = "res://tests/fixtures/shared_sheets/fixture_pause_handling.gd"
const BASE: String = "res://tests/fixtures/shared_sheets/fixture_damage_rules.gd"
const PLAIN: String = "extends Node\n\n\nfunc _process(delta: float) -> void:\n\tpass\n"


static func run() -> bool:
	var ok: bool = true
	ok = _test_a_helper_include_is_one_step() and ok
	ok = _test_a_base_include_is_one_step() and ok
	ok = _test_the_includes_window_edits_are_one_step_each() and ok
	return ok


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _opened(path: String) -> Array:
	var manager: EventSheetEditorTest.FakeEditorUndoRedoManager = EventSheetEditorTest.FakeEditorUndoRedoManager.new()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(manager)
	dock._load_sheet_from_path(path)
	dock._ace_apply._unlock_preview_for_edit()
	return [dock, manager]


static func _include_line_count(dock: EventSheetDock) -> int:
	var found: int = 0
	var view: EventSheetViewport = dock._active_view()
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.row_uid.begins_with("include_line_"):
			found += 1
	return found


static func _one_step(label: String, shared: String, expected_text: String) -> bool:
	var ok: bool = true
	var path: String = SUPPORT.own_path("includer_%s.gd" % label)
	_write(path, PLAIN)
	var opened: Array = _opened(path)
	var dock: EventSheetDock = opened[0] as EventSheetDock
	var manager: EventSheetEditorTest.FakeEditorUndoRedoManager = opened[1] as EventSheetEditorTest.FakeEditorUndoRedoManager
	var result: Dictionary = dock._shared_sheets.include_shared_sheet(shared)
	ok = SUPPORT.pin_value(TEST_NAME, "%s: the include is written" % label, bool(result.get("ok", false)), true) and ok
	var included: String = FileAccess.get_file_as_string(path)
	ok = SUPPORT.pin_value(TEST_NAME, "%s: the file names the shared sheet" % label, included.contains(expected_text), true) and ok
	ok = SUPPORT.pin_value(TEST_NAME, "%s: there is a step to undo" % label, manager.has_undo(), true) and ok
	ok = SUPPORT.pin_value(TEST_NAME, "%s: the sheet is not left dirty" % label, dock._dirty, false) and ok
	ok = SUPPORT.pin_value(TEST_NAME, "%s: the head draws one Include line" % label, _include_line_count(dock), 1) and ok
	manager.undo()
	ok = SUPPORT.pin_value(TEST_NAME, "%s: ONE undo writes the file back as it was" % label, FileAccess.get_file_as_string(path), PLAIN) and ok
	ok = SUPPORT.pin_value(TEST_NAME, "%s: and that was the only step" % label, manager.has_undo(), false) and ok
	ok = SUPPORT.pin_value(TEST_NAME, "%s: undo leaves the sheet saved" % label, dock._dirty, false) and ok
	ok = SUPPORT.pin_value(TEST_NAME, "%s: the Include line is gone" % label, _include_line_count(dock), 0) and ok
	manager.redo()
	ok = SUPPORT.pin_value(TEST_NAME, "%s: ONE redo writes the include again, byte for byte" % label, FileAccess.get_file_as_string(path), included) and ok
	ok = SUPPORT.pin_value(TEST_NAME, "%s: redo leaves the sheet saved" % label, dock._dirty, false) and ok
	ok = SUPPORT.pin_value(TEST_NAME, "%s: the Include line is back" % label, _include_line_count(dock), 1) and ok
	manager.undo()
	manager.redo()
	ok = SUPPORT.pin_value(TEST_NAME, "%s: a second round trip is the same bytes" % label, FileAccess.get_file_as_string(path), included) and ok
	dock.free()
	return ok


static func _test_a_helper_include_is_one_step() -> bool:
	return _one_step("helper", HELPER, "_fixture_pause_handling")


static func _test_a_base_include_is_one_step() -> bool:
	return _one_step("base", BASE, "extends FixtureDamageRules")


static func _test_the_includes_window_edits_are_one_step_each() -> bool:
	var ok: bool = true
	var first: String = SUPPORT.own_path("library_one.tres")
	var second: String = SUPPORT.own_path("library_two.tres")
	for path: String in [first, second]:
		var library: EventSheetResource = EventSheetResource.new()
		library.host_class = "Node"
		ResourceSaver.save(library, path)
	var manager: EventSheetEditorTest.FakeEditorUndoRedoManager = EventSheetEditorTest.FakeEditorUndoRedoManager.new()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(manager)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	dock.setup(sheet)
	dock._includes._add_include(first)
	dock._includes._add_include(second)
	ok = SUPPORT.pin_value(TEST_NAME, "two adds make two includes", Array(dock._current_sheet.includes), [first, second]) and ok
	manager.undo()
	ok = SUPPORT.pin_value(TEST_NAME, "one undo takes back one add", Array(dock._current_sheet.includes), [first]) and ok
	manager.redo()
	ok = SUPPORT.pin_value(TEST_NAME, "one redo puts it back", Array(dock._current_sheet.includes), [first, second]) and ok
	dock._includes._include_list = Tree.new()
	dock._includes._include_list.columns = 2
	dock._includes._include_list.create_item()
	dock._includes._refresh_include_list(1)
	dock._includes._include_move(-1)
	ok = SUPPORT.pin_value(TEST_NAME, "a move reorders", Array(dock._current_sheet.includes), [second, first]) and ok
	manager.undo()
	ok = SUPPORT.pin_value(TEST_NAME, "one undo takes back the move", Array(dock._current_sheet.includes), [first, second]) and ok
	manager.redo()
	dock._includes._refresh_include_list(0)
	dock._includes._include_remove_selected()
	ok = SUPPORT.pin_value(TEST_NAME, "a remove takes the selected one off", Array(dock._current_sheet.includes), [first]) and ok
	manager.undo()
	ok = SUPPORT.pin_value(TEST_NAME, "one undo puts the removed one back", Array(dock._current_sheet.includes), [second, first]) and ok
	dock.free()
	return ok
