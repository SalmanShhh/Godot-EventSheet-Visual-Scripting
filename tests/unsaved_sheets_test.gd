# EventForge - unsaved sheets at quit, Save All and save-before-run.
#
# Godot asks the plugin two questions: "what do you hold that is not saved?" (_get_unsaved_status,
# worded into Godot's own quit dialog) and "save it" (_save_external_data, called by Save All, by
# save-before-run and by Save & Quit). The helper that answers both reads the dock's tabs; this test
# drives it against real files, and pins that the plugin defines both hooks.
@tool
class_name UnsavedSheetsTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const HELPER_PATH: String = "res://addons/eventsheet/editor/dock/unsaved_sheets.gd"
const PLUGIN_PATH: String = "res://addons/eventforge/plugin.gd"
const FIRST: String = "user://unsaved_sheets_first.gd"
const SECOND: String = "user://unsaved_sheets_second.gd"
const SOURCE: String = "extends Node\n\n\nfunc _ready() -> void:\n\tprint(\"hi\")\n"


static func run() -> bool:
	var ok: bool = true
	ok = _check("the plugin answers Godot's unsaved question",
		FileAccess.get_file_as_string(PLUGIN_PATH).contains("func _get_unsaved_status("), true) and ok
	ok = _check("the plugin answers Godot's save question",
		FileAccess.get_file_as_string(PLUGIN_PATH).contains("func _save_external_data("), true) and ok
	if not ResourceLoader.exists(HELPER_PATH):
		return _check("the helper exists", false, true)
	var helper: GDScript = load(HELPER_PATH)

	_write(FIRST, SOURCE)
	_write(SECOND, SOURCE)
	var dock: EventSheetEditor = EventSheetEditor.new()
	dock._load_sheet_from_path(FIRST)
	dock._preview_glue._on_preview_edit_requested()
	_add_comment(dock, "first edit")
	dock._load_sheet_from_path(SECOND)
	dock._preview_glue._on_preview_edit_requested()
	_add_comment(dock, "second edit")
	ok = _check("two tabs are open", dock.get_open_tab_count() >= 2, true) and ok

	# Godot's dialog names every unsaved sheet, the one in front and the one behind it.
	var text: String = helper.status_text(dock)
	ok = _check("the status names the sheet in front", text.contains("unsaved_sheets_second.gd"), true) and ok
	ok = _check("the status names the sheet behind it", text.contains("unsaved_sheets_first.gd"), true) and ok

	# A tab that was never saved has no file to write to: it is named with the reason, never skipped.
	var untitled: EventSheetResource = EventSheetResource.new()
	untitled.host_class = "Node"
	dock._open_tabs.append({"sheet": untitled, "path": "", "dirty": true})
	text = helper.status_text(dock)
	ok = _check("a never-saved sheet is named with its reason", text.contains("never been saved"), true) and ok

	var failed: PackedStringArray = helper.save_dirty_tabs(dock)
	ok = _check("both files with a place on disk are written",
		FileAccess.get_file_as_string(FIRST).contains("first edit")
		and FileAccess.get_file_as_string(SECOND).contains("second edit"), true) and ok
	ok = _check("the never-saved sheet is reported, not skipped", failed.size(), 1) and ok
	ok = _check("the report names the sheet and says what to do", failed[0].contains("Save As"), true) and ok
	ok = _check("the sheet that was in front is in front again", dock._current_sheet.external_source_path, SECOND) and ok

	# Once only the never-saved sheet is left, Godot is told about that and nothing else.
	text = helper.status_text(dock)
	ok = _check("saved sheets leave the status", text.contains("unsaved_sheets_first.gd"), false) and ok
	dock._open_tabs.pop_back()
	ok = _check("nothing unsaved says nothing", helper.status_text(dock), "") and ok
	ok = _check("nothing unsaved saves nothing", helper.save_dirty_tabs(dock).size(), 0) and ok

	# A file that holds merge markers refuses to be saved: that is named too, and the file is untouched.
	var conflicted: String = "user://unsaved_sheets_conflict.gd"
	_write(conflicted, SOURCE)
	dock._load_sheet_from_path(conflicted)
	dock._preview_glue._on_preview_edit_requested()
	_add_comment(dock, "conflicted edit")
	_write(conflicted, SOURCE + "\n<<<<<<< HEAD\nvar a = 1\n=======\nvar a = 2\n>>>>>>> other\n")
	var before: String = FileAccess.get_file_as_string(conflicted)
	failed = helper.save_dirty_tabs(dock)
	ok = _check("a sheet that cannot be saved is named", failed.size(), 1) and ok
	ok = _check("the name is the file", failed[0].contains("unsaved_sheets_conflict.gd"), true) and ok
	ok = _check("a refused save leaves the file as it was", FileAccess.get_file_as_string(conflicted), before) and ok

	dock.free()
	for path: String in [FIRST, SECOND, conflicted]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return ok


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _add_comment(dock: EventSheetEditor, text: String) -> void:
	dock._perform_undoable_sheet_edit("Add a note", func() -> bool:
		var comment: CommentRow = CommentRow.new()
		comment.text = text
		dock._current_sheet.events.append(comment)
		return true)
	dock._mark_dirty("Add a note")


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("unsaved_sheets_test", label, actual, expected)
